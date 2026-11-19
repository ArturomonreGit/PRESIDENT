class_name NightScreen
extends Screen
## Noche electoral. Esta pantalla es la puerta de entrada: abre la retransmisión a pantalla completa
## (NightBroadcast) y, si se cierra a medias, deja ver el estado del recuento y reanudarla.

static var auto_open := true
static var dismissed_cycle := -1

var overlay: NightBroadcast = null
var map: SpainMap
var live: VBoxContainer

func build() -> void:
	m.election.ensure_night()
	var tick := m.election.night_tick()
	var done := m.election.night_finished()
	var intro := UI.hero(self, Color(UI.ACCENT, 0.10), Color(UI.ACCENT, 0.4))
	intro.add_child(UI.eyebrow("Noche electoral"))
	intro.add_child(UI.label("Escrutinio finalizado" if done else ("Escrutinio en curso" if tick > 0 else "Se cierran los colegios"), UI.FS_H1, UI.TEXT, true))
	intro.add_child(UI.wrap_label("La noche se vive como en televisión: sondeo a pie de urna, recuento por cortes, vuelcos provincia a provincia, hemiciclo, mapa y escaños en juego. Los resultados provisionales se mueven hasta el último voto.", UI.FS_BODY, UI.MUTED))
	var controls := UI.hbox(10)
	var label := "Ver resultados" if done else ("Reanudar la retransmisión" if tick > 0 else "Abrir la retransmisión")
	controls.add_child(UI.button(label, "primary", _on_main, 260))
	if not done:
		controls.add_child(UI.button("Saltar al final", "ghost", _skip))
	controls.add_child(UI.fill())
	controls.add_child(UI.label("%.0f %% escrutado" % m.election.night_progress(), UI.FS_BODY, UI.MUTED))
	intro.add_child(controls)
	intro.add_child(UI.meter(m.election.night_progress(), 100.0, UI.ACCENT, 8))

	var cols := columns(1.35, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var mc := UI.card(left, "Circunscripciones", "color = partido que lidera el recuento", UI.ACCENT)
	map = SpainMap.new()
	map.custom_minimum_size = Vector2(500, 400)
	mc.add_child(map)
	var lc := UI.card(right, "Escaños en directo", "mayoría %d" % Rules.MAJORITY, UI.GOOD)
	live = UI.vbox(6)
	lc.add_child(live)
	_render()
	if auto_open and not done_or_dismissed() and DisplayServer.get_name() != "headless":
		call_deferred("open_broadcast")

func done_or_dismissed() -> bool:
	return dismissed_cycle == m.cycle

func _render() -> void:
	var snap := m.election.snapshot()
	var fills: Dictionary = {}
	var tips: Dictionary = {}
	for c in m.constituencies:
		var cd: Dictionary = c
		var ps: Dictionary = (snap["provinces"] as Dictionary).get(str(cd["id"]), {})
		var pname := str(cd["name"])
		if bool(ps.get("started", false)):
			fills[pname] = m.party_color(str(ps["leader"]))
			tips[pname] = "%s · lidera %s · %.0f%% escrutado" % [pname, m.party_short(str(ps["leader"])), float(ps["frac"]) * 100.0]
	map.fills = fills
	map.tooltips = tips
	UI.clear_children(live)
	var totals := m.d("election_totals")
	var ids: Array = totals.keys()
	ids.sort_custom(func(x, y) -> bool: return int(totals[x]) > int(totals[y]))
	for id in ids:
		var n := int(totals[id])
		if n <= 0 and not m.is_player(str(id)):
			continue
		var row := UI.hbox(8)
		var tag := UI.party_tag(m, str(id), UI.FS_BODY, m.is_player(str(id)))
		tag.custom_minimum_size = Vector2(110, 0)
		row.add_child(tag)
		var mb := UI.meter(float(n), 200.0, m.party_color(str(id)), 10)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mb.marker = float(Rules.MAJORITY)
		row.add_child(mb)
		var l := UI.label(str(n), UI.FS_LEAD, UI.TEXT, true)
		l.custom_minimum_size = Vector2(36, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
		live.add_child(row)
	if live.get_child_count() == 0:
		empty_note(live, "Aún no hay circunscripciones escrutadas.")

# ---------------------------------------------------------------- retransmisión
func open_broadcast() -> void:
	if not is_inside_tree() or shell.has_node("NightBroadcast"):
		return
	overlay = NightBroadcast.open(shell, m)
	overlay.closed.connect(_on_closed)
	overlay.view_results.connect(_finish)

func _on_closed() -> void:
	dismissed_cycle = m.cycle
	overlay = null
	if is_inside_tree() and shell.current == "night":
		rebuild()
		shell.refresh_chrome()

func _on_main() -> void:
	if m.election.night_finished():
		_finish()
	else:
		open_broadcast()

# ---------------------------------------------------------------- compatibilidad con las pruebas y el modo sin retransmisión
func _step() -> void:
	m.election.advance_night(1)
	_render()

func _skip() -> void:
	m.election.skip_night()
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	rebuild()

func _finish() -> void:
	var host: Node = shell.get_node_or_null("NightBroadcast")
	if host != null:
		host.queue_free()
	overlay = null
	m.election.finish_night()
	shell.go("results")
	shell.toast("Escrutinio completo.", "good")
