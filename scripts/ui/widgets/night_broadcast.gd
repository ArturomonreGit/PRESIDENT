class_name NightBroadcast
extends Control
## Retransmisión de la noche electoral a pantalla completa: barra de última hora, clasificación en directo,
## escenas que rotan como en un plató (resultados, mapa, hemiciclo, escaños en juego, evolución, "tú eliges"),
## avisos de vuelco, hitos de mayoría y control de velocidad. Toda la lógica del recuento vive en ElectionSim.

signal closed
signal view_results

const SPEEDS := [8.0, 5.0, 3.0, 2.0, 1.0, 0.5]
const SCENES := ["results", "map", "hemi", "contested", "evolution", "choose"]
const SCENE_NAMES := {"results": "Resultados", "map": "Mapa", "hemi": "Hemiciclo", "contested": "En juego", "evolution": "Evolución", "choose": "Tú eliges"}
const POLL_SECONDS := 8.0

var m: GameModel
var phase := "intro"
var playing := false
var speed_i := 2
var auto := true
var hold := false
var scene_id := ""
var scene: NightScene = null
var snap: Dictionary = {}
var rows: Array = []
var prev_totals: Dictionary = {}
var left_bloc := 0
var right_bloc := 0

var top: NightTopBar
var panel: NightPanel
var stage: Control
var scene_holder: Control
var pill: Control
var banner_layer: Control
var tabs: Dictionary = {}
var btn_play: NightButton
var btn_speed: NightButton
var btn_auto: NightButton
var prog: Control

var _acc := 0.0
var _intro_t := -1.0
var _last_leader := ""
var _last_leader_seats := 0
var _scene_t := 0.0
var _poll_t := 0.0
var _mode_t := 0.0
var _headline_i := 0
var _pill_queue: Array = []
var _pill_t := 0.0
var _pill_segs: Array = []
var _end_t := -1.0
var _scene_cycle := 0
var _comm_cache: Array = []
var _last_pick: Array = []
var _banner_tween: Tween = null

static func open(host: Control, model: GameModel) -> NightBroadcast:
	var b := NightBroadcast.new()
	b.m = model
	host.add_child(b)
	return b

# ---------------------------------------------------------------- construcción
func _ready() -> void:
	name = "NightBroadcast"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	m.election.ensure_night()
	_build_layout()
	prev_totals = (m.d("election_totals")).duplicate()
	_refresh_data()
	_apply_all()
	if m.election.night_finished():
		_enter_end(false)
	elif m.election.night_tick() > 0:
		_enter_count(false)
	else:
		_enter_intro()
	grab_focus()

func _build_layout() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("#14233D"))
	grad.set_color(1, Color("#04060C"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var bgr := TextureRect.new()
	bgr.texture = gt
	bgr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgr.stretch_mode = TextureRect.STRETCH_SCALE
	bgr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgr)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	top = NightTopBar.new()
	root.add_child(top)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	root.add_child(mid)
	panel = NightPanel.new()
	panel.player_id = m.pid()
	panel.mode_changed.connect(func(_mode: String) -> void: _apply_panel())
	mid.add_child(panel)
	stage = Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	mid.add_child(stage)
	scene_holder = Control.new()
	scene_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(scene_holder)
	pill = _Pill.new()
	pill.visible = false
	stage.add_child(pill)
	banner_layer = Control.new()
	banner_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(banner_layer)

	# Barra de control inferior
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 58)
	bar.add_theme_stylebox_override("panel", UI.box(TV.PANEL, TV.LINE, 0, 0, 14, 8))
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	btn_play = NightButton.new("play", "", 48)
	btn_play.pressed.connect(_on_play)
	row.add_child(btn_play)
	var slower := NightButton.new("minus", "", 40)
	slower.pressed.connect(func() -> void: _change_speed(-1))
	row.add_child(slower)
	btn_speed = NightButton.new("text", "3 s", 64)
	btn_speed.mouse_default_cursor_shape = Control.CURSOR_ARROW
	row.add_child(btn_speed)
	var faster := NightButton.new("plus", "", 40)
	faster.pressed.connect(func() -> void: _change_speed(1))
	row.add_child(faster)
	prog = _Prog.new()
	prog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(prog)
	for sid in SCENES:
		var t := NightButton.new("text", str(SCENE_NAMES[sid]), 104)
		t.pressed.connect(_on_tab.bind(str(sid)))
		row.add_child(t)
		tabs[sid] = t
	btn_auto = NightButton.new("text", "AUTO", 70)
	btn_auto.set_active(true)
	btn_auto.pressed.connect(func() -> void:
		auto = not auto
		btn_auto.set_active(auto))
	row.add_child(btn_auto)
	var skip := NightButton.new("skip", "", 48)
	skip.pressed.connect(_on_skip)
	row.add_child(skip)
	var close := NightButton.new("close", "", 48)
	close.pressed.connect(close_broadcast)
	row.add_child(close)

func close_broadcast() -> void:
	closed.emit()
	queue_free()

# ---------------------------------------------------------------- datos y ayudas para las escenas
func short(id: String) -> String:
	return m.party_short(id)

func color_of(id: String) -> Color:
	return m.party_color(id)

func bloc_of(id: String) -> String:
	var ideo: Dictionary = m.party_by_id(id).get("ideology", {})
	var eco := float(ideo.get("economic", 0.0))
	if eco >= 0.4:
		return "right"
	if eco <= -0.35:
		return "left"
	return ""

func scene_fraction() -> float:
	return clampf(_scene_t / _scene_len(), 0.0, 1.0)

func _scene_len() -> float:
	return clampf(float(SPEEDS[speed_i]) * 3.5, 7.0, 16.0)

func set_hold(v: bool) -> void:
	hold = v

func communities() -> Array:
	if _comm_cache.is_empty():
		var by: Dictionary = {}
		for c in m.constituencies:
			var cd: Dictionary = c
			var cn := str(cd.get("autonomous_community", ""))
			if not by.has(cn):
				by[cn] = {"name": cn, "seats": 0, "cids": []}
			by[cn]["seats"] = int(by[cn]["seats"]) + int(cd.get("seats", 0))
			(by[cn]["cids"] as Array).append(str(cd["id"]))
		for k in by.keys():
			_comm_cache.append(by[k])
	return _comm_cache

func pick_communities(n: int) -> Array:
	var all := communities().duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.s.get("election_seed", 1)) + m.election.night_tick() * 7919 + _scene_cycle * 31
	var out: Array = []
	var guard := 0
	all = all.filter(func(c: Dictionary) -> bool: return int(c["seats"]) >= 3)
	while out.size() < n and not all.is_empty() and guard < 200:
		guard += 1
		var i := rng.randi_range(0, all.size() - 1)
		var cand: Dictionary = all[i]
		if _last_pick.has(str(cand["name"])) and all.size() > n + 3:
			continue
		out.append(cand)
		all.remove_at(i)
	_last_pick = []
	for o in out:
		_last_pick.append(str((o as Dictionary)["name"]))
	return out

func community_stats(cname: String) -> Dictionary:
	var seats := 0
	var counted := 0.0
	var total := 0.0
	var alloc_sum: Dictionary = {}
	for c in m.constituencies:
		var cd: Dictionary = c
		if str(cd.get("autonomous_community", "")) != cname:
			continue
		var ps: Dictionary = (snap["provinces"] as Dictionary).get(str(cd["id"]), {})
		var w := float(int(cd["seats"]))
		total += w
		counted += w * float(ps.get("frac", 0.0))
		seats += int(cd["seats"])
		for id in (ps.get("alloc", {}) as Dictionary).keys():
			alloc_sum[id] = int(alloc_sum.get(id, 0)) + int((ps["alloc"] as Dictionary)[id])
	var leader := ""
	var best := 0
	for id in alloc_sum.keys():
		if int(alloc_sum[id]) > best:
			best = int(alloc_sum[id])
			leader = str(id)
	return {"seats": seats, "frac": counted / maxf(total, 1.0), "leader": leader, "alloc": alloc_sum}

func province_rows(cname: String) -> Array:
	var out: Array = []
	for c in m.constituencies:
		var cd: Dictionary = c
		if str(cd.get("autonomous_community", "")) != cname:
			continue
		var ps: Dictionary = (snap["provinces"] as Dictionary).get(str(cd["id"]), {})
		out.append({"name": str(cd["name"]), "seats": int(cd["seats"]), "frac": float(ps.get("frac", 0.0)), "alloc": ps.get("alloc", {}), "votes": ps.get("votes", {}), "leader": str(ps.get("leader", ""))})
	return out

func majority_text() -> String:
	if rows.is_empty():
		return ""
	var top_row: Dictionary = rows[0]
	for r in rows:
		if int((r as Dictionary)["seats"]) > int(top_row["seats"]):
			top_row = r
	var n := int(top_row["seats"])
	if n <= 0:
		return ""
	if n >= Rules.MAJORITY:
		return "%s supera la mayoría absoluta con %d escaños" % [str(top_row["name"]), n]
	return "%s necesitaría %d escaños más para la mayoría absoluta (%d)" % [str(top_row["name"]), Rules.MAJORITY - n, Rules.MAJORITY]

func apply_map(map: NightMap) -> void:
	var colors: Dictionary = {}
	var tips: Dictionary = {}
	var announced: Dictionary = m.d("election_announced")
	for c in m.constituencies:
		var cd: Dictionary = c
		var cid := str(cd["id"])
		var ps: Dictionary = (snap["provinces"] as Dictionary).get(cid, {})
		var pname := str(cd["name"])
		if not bool(ps.get("started", false)):
			colors[pname] = TV.PENDING
			tips[pname] = "%s · %d escaños · sin datos" % [pname, int(cd["seats"])]
			continue
		var leader := str(ps["leader"])
		var col := color_of(leader)
		if not announced.has(cid) and not m.election.night_finished():
			col = col.lerp(TV.PENDING, 0.62)
		colors[pname] = col
		tips[pname] = "%s · %d escaños · %.0f%% escrutado · lidera %s" % [pname, int(cd["seats"]), float(ps["frac"]) * 100.0, short(leader)]
	map.set_target(colors)
	map.tooltips = tips

func apply_hemi(h: NightHemicycle) -> void:
	var totals: Dictionary = snap["totals"]
	var ids: Array = []
	var counted := 0
	for id in totals.keys():
		if int(totals[id]) > 0:
			ids.append(str(id))
			counted += int(totals[id])
	var entries: Array = []
	for id in ResultsScreen.economic_order(m, ids):
		entries.append({"id": str(id), "color": color_of(str(id)), "seats": int(totals[id])})
	h.total_seats = 350
	h.set_data(entries, 350 - counted, left_bloc, right_bloc)

# ---------------------------------------------------------------- actualización de datos
func _refresh_data() -> void:
	snap = m.election.snapshot()
	var totals: Dictionary = snap["totals"]
	var votes: Dictionary = snap["votes"]
	var vsum := 0.0
	for v in votes.values():
		vsum += float(v)
	rows = []
	left_bloc = 0
	right_bloc = 0
	for id in totals.keys():
		var sid := str(id)
		var seats := int(totals[id])
		var pct := float(votes.get(sid, 0)) / maxf(vsum, 1.0) * 100.0
		match bloc_of(sid):
			"left":
				left_bloc += seats
			"right":
				right_bloc += seats
		if seats <= 0 and pct < 0.45 and sid != m.pid():
			continue
		rows.append({"id": sid, "name": short(sid), "color": color_of(sid), "seats": seats, "pct": pct, "delta": seats - int(prev_totals.get(sid, seats))})
	_sort_rows()

func _sort_rows() -> void:
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["seats"]) != int(b["seats"]):
			return int(a["seats"]) > int(b["seats"])
		return float(a["pct"]) > float(b["pct"]))

func _apply_panel() -> void:
	_sort_rows()
	panel.left_bloc = left_bloc
	panel.right_bloc = right_bloc
	panel.majority = Rules.MAJORITY
	if not rows.is_empty():
		var lead: Dictionary = rows[0]
		panel.lead_name = str(lead["name"])
		panel.lead_seats = int(lead["seats"])
		panel.lead_color = lead["color"]
	panel.set_rows(rows, float(snap.get("scrutinized", 0.0)))

func _apply_all() -> void:
	_apply_panel()
	top.clock_text = TV.clock(m.election.night_tick())
	prog.set("value", float(snap.get("scrutinized", 0.0)))
	prog.queue_redraw()
	if scene != null:
		scene.refresh()

# ---------------------------------------------------------------- fases
func _enter_intro() -> void:
	phase = "intro"
	playing = false
	btn_play.kind = "play"
	btn_play.queue_redraw()
	top.show_headline("Cierre de colegios: comienza la noche electoral", 9999.0)
	_show_scene("intro")
	# Arranque automático: no hace falta pulsar nada (Play o Espacio solo adelantan el momento).
	_intro_t = 3.5

func _enter_poll() -> void:
	phase = "poll"
	_intro_t = -1.0
	_poll_t = POLL_SECONDS
	top.show_headline("Primer sondeo a pie de urna: horquillas de escaños", POLL_SECONDS)
	_show_scene("poll")

func _enter_count(from_start: bool) -> void:
	phase = "count"
	playing = true
	_acc = 0.0
	btn_play.kind = "pause"
	btn_play.queue_redraw()
	top.headline_t = 0.0
	if from_start:
		top.show_headline("Empieza el escrutinio: los primeros votos, en directo", 6.0)
		_show_scene("results")
	else:
		_show_scene("map")
	_scene_t = 0.0

func _enter_end(animate: bool) -> void:
	phase = "end"
	playing = false
	btn_play.kind = "play"
	btn_play.queue_redraw()
	_show_scene("hemi")
	top.show_headline(majority_text() if majority_text() != "" else "Escrutinio finalizado", 9999.0)
	_end_t = 1.4 if animate else 0.2

func _show_final_banner() -> void:
	var leader := m.election.leading_party()
	var seats := m.seats_of(leader)
	Sfx.play("fanfare")
	var title := "ESCRUTINIO FINALIZADO"
	var sub := "%s gana las elecciones con %d escaños." % [short(leader), seats]
	if seats >= Rules.MAJORITY:
		sub += " Mayoría absoluta."
	else:
		sub += " Faltan %d para la mayoría absoluta." % (Rules.MAJORITY - seats)
	var mine := m.seats_of(m.pid())
	var target := int(m.d("objective").get("target_seats", 0))
	if target > 0:
		sub += "\nTu partido: %d escaños (objetivo: %d)." % [mine, target]
	show_banner(title, sub, color_of(leader), 0.0, [
		{"label": "VER RESULTADOS  ▶", "w": 280, "cb": func() -> void: view_results.emit()},
		{"label": "Seguir viendo", "w": 170, "cb": clear_banner},
	])

# ---------------------------------------------------------------- escenas
func _make_scene(id: String) -> NightScene:
	match id:
		"intro": return _SIntro.new()
		"poll": return _SPoll.new()
		"results": return _SResults.new()
		"map": return _SMap.new()
		"hemi": return _SHemi.new()
		"contested": return _SContested.new()
		"evolution": return _SEvolution.new()
		"choose": return _SChoose.new()
	return _SResults.new()

func _show_scene(id: String) -> void:
	if scene_id != id:
		Sfx.play("flip", 0.6)
	scene_id = id
	_scene_cycle += 1
	_scene_t = 0.0
	hold = false
	for k in tabs.keys():
		(tabs[k] as NightButton).set_active(str(k) == id)
	var old := scene
	var node := _make_scene(id)
	node.modulate.a = 0.0
	scene_holder.add_child(node)
	node.setup(self)
	scene = node
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.45)
	if old != null and is_instance_valid(old):
		var tw2 := create_tween()
		tw2.tween_property(old, "modulate:a", 0.0, 0.3)
		tw2.tween_callback(old.queue_free)

func _next_scene(step: int = 1) -> void:
	var i := SCENES.find(scene_id)
	i = (i + step + SCENES.size()) % SCENES.size() if i >= 0 else 0
	_show_scene(str(SCENES[i]))

func _on_tab(sid: String) -> void:
	if phase == "intro" or phase == "poll":
		return
	auto = false
	btn_auto.set_active(false)
	_show_scene(sid)

# ---------------------------------------------------------------- controles
func _on_play() -> void:
	match phase:
		"intro":
			_enter_poll()
		"poll":
			_enter_count(true)
		"count":
			playing = not playing
			btn_play.kind = "pause" if playing else "play"
			btn_play.queue_redraw()
		"end":
			_show_final_banner()

func _change_speed(dir: int) -> void:
	speed_i = clampi(speed_i + dir, 0, SPEEDS.size() - 1)
	var s: float = SPEEDS[speed_i]
	btn_speed.set_label(("%.1f s" % s).replace(".0", "") if s >= 1.0 else "%.1f s" % s)

func _on_skip() -> void:
	if phase == "end":
		return
	m.election.skip_night()
	prev_totals = (m.d("election_totals")).duplicate()
	_refresh_data()
	_apply_all()
	top.items.clear()
	_enter_end(true)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		match k:
			KEY_SPACE:
				_on_play()
			KEY_RIGHT:
				if phase == "count" or phase == "end":
					auto = false
					btn_auto.set_active(false)
					_next_scene(1)
			KEY_LEFT:
				if phase == "count" or phase == "end":
					auto = false
					btn_auto.set_active(false)
					_next_scene(-1)
			KEY_UP:
				_change_speed(1)
			KEY_DOWN:
				_change_speed(-1)
			_:
				return
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- bucle
func _process(delta: float) -> void:
	_mode_t += delta
	if phase == "intro" and _intro_t >= 0.0:
		_intro_t -= delta
		if _intro_t < 0.0:
			_enter_poll()
	if phase == "poll":
		_poll_t -= delta
		if _poll_t <= 0.0:
			_enter_count(true)
	if phase == "count" and playing:
		_acc += delta
		if _acc >= float(SPEEDS[speed_i]):
			_acc = 0.0
			_do_cut()
		_scene_t += delta
		if auto and not hold and _scene_t >= _scene_len():
			_next_scene(1)
	if _end_t >= 0.0:
		_end_t -= delta
		if _end_t < 0.0:
			_show_final_banner()
	_update_pill(delta)

func _do_cut() -> void:
	prev_totals = (m.d("election_totals")).duplicate()
	var events := m.election.advance_night(1)
	_refresh_data()
	_apply_all()
	_handle_events(events)
	_check_lead_change()
	if m.election.night_finished():
		_enter_end(true)
	else:
		_maybe_headline()

## Avisa cuando otro partido pasa a liderar el recuento de escaños.
func _check_lead_change() -> void:
	if rows.is_empty():
		return
	var lead: Dictionary = rows[0]
	var id := str(lead["id"])
	var seats := int(lead["seats"])
	if seats <= 0:
		return
	if _last_leader != "" and id != _last_leader and m.election.night_tick() > 2:
		var old_name := short(_last_leader)
		Sfx.play("alert")
		top.show_headline("CAMBIO DE LÍDER: %s adelanta a %s con %d escaños" % [short(id), old_name, seats], 8.0)
		show_banner("%s ADELANTA A %s" % [short(id).to_upper(), old_name.to_upper()], "Pasa a liderar el recuento con %d escaños." % seats, color_of(id), 3.5)
	_last_leader = id
	_last_leader_seats = seats

func _handle_events(events: Array) -> void:
	for e in events:
		var ed: Dictionary = e
		match str(ed["type"]):
			"win":
				top.push_item([
					{"k": "t", "s": str(ed["name"]), "c": TV.WHITE, "b": true},
					{"k": "t", "s": "gana", "c": TV.MUTED},
					{"k": "chip", "s": short(str(ed["party"])), "c": color_of(str(ed["party"]))},
					{"k": "t", "s": "al %d%% escr." % int(round(float(ed["frac"]))), "c": TV.FAINT},
				])
			"flip":
				top.push_item([
					{"k": "t", "s": "VUELCO", "c": TV.GOLD, "b": true},
					{"k": "t", "s": str(ed["name"]), "c": TV.WHITE, "b": true},
					{"k": "t", "s": "gana", "c": TV.MUTED},
					{"k": "chip", "s": short(str(ed["party"])), "c": color_of(str(ed["party"]))},
				])
				Sfx.play("alert", 0.8)
				_queue_pill("VUELCO", str(ed["party"]), str(ed["from"]), str(ed["name"]), "le quita")
				_flash_province(str(ed["name"]))
			"regain":
				top.push_item([
					{"k": "chip", "s": short(str(ed["party"])), "c": color_of(str(ed["party"]))},
					{"k": "t", "s": "recupera", "c": TV.MUTED},
					{"k": "t", "s": str(ed["name"]), "c": TV.WHITE, "b": true},
				])
				_queue_pill("RECUPERA", str(ed["party"]), str(ed["from"]), str(ed["name"]), "recupera")
				_flash_province(str(ed["name"]))
			"majority":
				var pid := str(ed["party"])
				Sfx.play("fanfare")
				top.show_headline("%s alcanza la mayoría absoluta: %d escaños" % [short(pid), int(ed["seats"])], 9.0)
				show_banner("MAYORÍA ABSOLUTA", "%s suma %d escaños y supera los %d." % [short(pid), int(ed["seats"]), Rules.MAJORITY], color_of(pid), 6.0)
				if scene_id != "hemi":
					_show_scene("hemi")

func _flash_province(pname: String) -> void:
	if scene is _SMap:
		((scene as _SMap).map as NightMap).flash(pname)

func _maybe_headline() -> void:
	if top.headline_t > 0.0:
		return
	var tick := m.election.night_tick()
	if tick % 4 != 0:
		return
	var h := _compose_headline()
	if h != "":
		top.show_headline(h, 7.0)

func _compose_headline() -> String:
	if rows.is_empty():
		return ""
	var by_seats := rows.duplicate()
	by_seats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seats"]) > int(b["seats"]))
	var first: Dictionary = by_seats[0]
	if int(first["seats"]) <= 0:
		return ""
	var options: Array = [majority_text()]
	if by_seats.size() > 1:
		var second: Dictionary = by_seats[1]
		var diff := int(first["seats"]) - int(second["seats"])
		if diff <= 8:
			options.append("%s y %s, separados por %d escaños" % [str(first["name"]), str(second["name"]), diff])
		else:
			options.append("%s aventaja en %d escaños a %s" % [str(first["name"]), diff, str(second["name"])])
	if right_bloc >= Rules.MAJORITY:
		options.append("El bloque de derechas supera la mayoría absoluta con %d escaños" % right_bloc)
	elif right_bloc > 0:
		options.append("El bloque de derechas suma %d escaños, a %d de la mayoría" % [right_bloc, Rules.MAJORITY - right_bloc])
	if left_bloc >= Rules.MAJORITY:
		options.append("El bloque de izquierdas supera la mayoría absoluta con %d escaños" % left_bloc)
	elif left_bloc > 0:
		options.append("El bloque de izquierdas suma %d escaños, a %d de la mayoría" % [left_bloc, Rules.MAJORITY - left_bloc])
	var target := int(m.d("objective").get("target_seats", 0))
	if target > 0:
		options.append("%s lleva %d escaños; el objetivo de la dirección era %d" % [short(m.pid()), m.seats_of(m.pid()), target])
	options.append("Escrutado el %s%% del voto" % TV.pct_es(float(snap.get("scrutinized", 0.0)), 0))
	_headline_i += 1
	return str(options[_headline_i % options.size()])

# ---------------------------------------------------------------- aviso de vuelco
func _queue_pill(label: String, party: String, from: String, prov: String, verb: String) -> void:
	var segs: Array = [
		{"k": "chip", "s": label, "c": TV.RED},
		{"k": "dot", "c": color_of(party)},
		{"k": "t", "s": short(party), "c": TV.DARK, "b": true},
		{"k": "t", "s": verb, "c": Color("#3A465C")},
		{"k": "t", "s": prov, "c": TV.DARK, "b": true},
	]
	if from != "":
		segs.append({"k": "t", "s": "a", "c": Color("#3A465C")})
		segs.append({"k": "dot", "c": color_of(from)})
		segs.append({"k": "t", "s": short(from), "c": TV.DARK, "b": true})
	_pill_queue.append(segs)
	while _pill_queue.size() > 4:
		_pill_queue.pop_front()

func _update_pill(delta: float) -> void:
	var p := pill as _Pill
	if _pill_t > 0.0:
		_pill_t -= delta
		p.age += delta
		var slide := clampf(minf(p.age * 4.0, _pill_t * 4.0), 0.0, 1.0)
		p.position = Vector2((stage.size.x - p.size.x) * 0.5, -p.size.y + (p.size.y + 16.0) * slide)
		if _pill_t <= 0.0:
			p.visible = false
	elif not _pill_queue.is_empty() and (phase == "count" or phase == "end"):
		var segs: Array = _pill_queue.pop_front()
		p.segs = segs
		p.fit_size()
		p.age = 0.0
		p.visible = true
		_pill_t = 5.0
		p.position = Vector2((stage.size.x - p.size.x) * 0.5, -p.size.y)

# ---------------------------------------------------------------- carteles
func clear_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	for c in banner_layer.get_children():
		c.queue_free()

func show_banner(title: String, sub: String, col: Color, seconds: float, buttons: Array = []) -> void:
	clear_banner()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_layer.add_child(center)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(TV.PANEL, 0.97), col, 16, 3, 44, 32))
	center.add_child(pc)
	var v := UI.vbox(14)
	pc.add_child(v)
	var t := UI.label(title, 36, TV.WHITE, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UI.label(sub, 20, TV.WHITE, false)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	if not buttons.is_empty():
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 12)
		v.add_child(hb)
		for b in buttons:
			var bd: Dictionary = b
			var nb := NightButton.new("text", str(bd["label"]), float(bd.get("w", 160)))
			nb.accent = TV.TEAL
			nb.set_active(hb.get_child_count() == 0)
			nb.pressed.connect(bd["cb"])
			hb.add_child(nb)
	pc.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(pc, "modulate:a", 1.0, 0.4)
	if seconds > 0.0:
		_banner_tween.tween_interval(seconds)
		_banner_tween.tween_property(pc, "modulate:a", 0.0, 0.5)
		_banner_tween.tween_callback(center.queue_free)

# ================================================================= clases auxiliares
class _Pill extends Control:
	var segs: Array = []
	var age := 0.0

	func fit_size() -> void:
		size = Vector2(TV.rich_width(segs, 17) + 40.0, 40.0)

	func _draw() -> void:
		TV.rrect(self, Rect2(Vector2.ZERO, size), Color.WHITE, 20.0, Color(0, 0, 0, 0.12), 1)
		TV.rich_draw(self, segs, Vector2(20, 0), 17, size.y)

class _Prog extends Control:
	var value := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(160, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		draw_rect(Rect2(10, y - 3, size.x - 80, 6), TV.LINE)
		draw_rect(Rect2(10, y - 3, (size.x - 80) * clampf(value / 100.0, 0.0, 1.0), 6), TV.TEAL)
		TV.text_tl(self, TV.pct_es(value) + "%", Vector2(size.x - 68, y - TV.font_h(15) * 0.5), 15, TV.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT, 66)

# ---------------------------------------------------------------- escena: antes del cierre
class _SIntro extends NightScene:
	func build() -> void:
		title_text = ""

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var t := Time.get_ticks_msec() / 1000.0
		for i in range(3):
			var ph := fmod(t * 0.5 + float(i) / 3.0, 1.0)
			draw_arc(c, 120.0 + ph * 130.0, 0.0, TAU, 64, Color(TV.TEAL, (1.0 - ph) * 0.35), 2.0, true)
		draw_arc(c, 112.0, 0.0, TAU, 64, TV.TEAL, 3.0, true)
		TV.text_tl(self, "20:00", Vector2(c.x - 150, c.y - 40), 76, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 300)
		TV.text_tl(self, "CIERRE DE COLEGIOS", Vector2(0, c.y + 150), 30, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		TV.text_tl(self, "Elecciones generales · %s" % Rules.date_string(bc.m.election_unix()), Vector2(0, c.y + 192), 17, TV.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		var a := 0.5 + 0.5 * sin(t * 3.0)
		TV.text_tl(self, "Pulsa el botón de reproducir para comenzar la noche", Vector2(0, c.y + 238), 16, Color(TV.TEAL, 0.5 + 0.5 * a), true, HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ---------------------------------------------------------------- escena: sondeo
class _SPoll extends NightScene:
	var _t := 0.0
	var _data: Dictionary = {}

	func build() -> void:
		title_text = "SONDEO A PIE DE URNA"
		sub_text = "HORQUILLAS DE ESCAÑOS · ESTIMACIÓN AL CIERRE DE LOS COLEGIOS"
		_data = bc.m.election.exit_poll()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		super._draw()
		var ids: Array = _data.keys()
		ids.sort_custom(func(a, b) -> bool: return int(_data[a]["hi"]) > int(_data[b]["hi"]))
		var max_hi := float(Rules.MAJORITY)
		for id in ids:
			max_hi = maxf(max_hi, float(_data[id]["hi"]))
		max_hi *= 1.08
		var x0 := size.x * 0.12
		var x1 := size.x * 0.88
		var name_w := 130.0
		var bx := x0 + name_w + 16.0
		var bw := x1 - bx - 110.0
		var rh := 44.0
		var y := 150.0
		var shown := 0
		for id in ids:
			if y + rh > size.y - 20.0:
				break
			var delay := float(shown) * 0.18
			var k := clampf((_t - delay) * 1.6, 0.0, 1.0)
			k = 1.0 - pow(1.0 - k, 3.0)
			var col: Color = bc.color_of(str(id))
			var lo := float(_data[id]["lo"])
			var hi := float(_data[id]["hi"])
			TV.rrect(self, Rect2(x0, y + 4, name_w, rh - 12), col, 5.0)
			TV.text_tl(self, TV.fit(bc.short(str(id)), 17, name_w - 16.0), Vector2(x0 + 10, y + 4 + (rh - 12 - TV.font_h(17)) * 0.5), 17, TV.ink(col))
			draw_rect(Rect2(bx, y + rh * 0.5 - 3, bw, 6), Color(TV.LINE, 0.6))
			var lo_w := bw * lo / max_hi * k
			var hi_w := bw * hi / max_hi * k
			TV.rrect(self, Rect2(bx + lo_w, y + 10, maxf(hi_w - lo_w, 4.0), rh - 24), Color(col, 0.55), 4.0, col, 2)
			draw_rect(Rect2(bx, y + rh * 0.5 - 3, lo_w, 6), col)
			TV.text_tl(self, "%d - %d" % [int(lo), int(hi)], Vector2(bx + bw + 12, y + (rh - TV.font_h(20)) * 0.5 - 2), 20, Color(TV.WHITE, k), true)
			y += rh + 6.0
			shown += 1
		var mx := bx + bw * float(Rules.MAJORITY) / max_hi
		var yy := 142.0
		while yy < y - 4.0:
			draw_line(Vector2(mx, yy), Vector2(mx, minf(yy + 6.0, y)), Color(TV.GOLD, 0.8), 2.0)
			yy += 12.0
		TV.text_tl(self, "176", Vector2(mx - 30, 126), 14, TV.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER, 60)

# ---------------------------------------------------------------- escena: resultados
class _SResults extends NightScene:
	var _w: Dictionary = {}

	func build() -> void:
		title_text = "RESULTADOS"

	func refresh() -> void:
		sub_text = "ESCRUTADO %s%%" % TV.pct_es(float(bc.snap.get("scrutinized", 0.0)))
		queue_redraw()

	func _process(delta: float) -> void:
		for r in bc.rows:
			var id := str((r as Dictionary)["id"])
			_w[id] = lerpf(float(_w.get(id, 0.0)), float((r as Dictionary)["pct"]), clampf(delta * 5.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		super._draw()
		var list: Array = bc.rows.duplicate()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["pct"]) > float(b["pct"]))
		list = list.slice(0, 7)
		var x0 := size.x * 0.10
		var x1 := size.x * 0.90
		var name_w := 132.0
		var bx := x0 + name_w + 14.0
		var seat_w := 120.0
		var bw := x1 - bx - seat_w
		var max_pct := 10.0
		for r in list:
			max_pct = maxf(max_pct, float((r as Dictionary)["pct"]))
		max_pct *= 1.15
		TV.text_tl(self, "% VOTO", Vector2(bx, 136), 11, TV.FAINT)
		TV.text_tl(self, "ESCAÑOS", Vector2(x1 - seat_w, 136), 11, TV.FAINT, true, HORIZONTAL_ALIGNMENT_RIGHT, seat_w)
		var y := 156.0
		var rh := 54.0
		for r in list:
			var rd: Dictionary = r
			var id := str(rd["id"])
			var col: Color = rd["color"]
			TV.rrect(self, Rect2(x0, y, name_w, rh - 10), col, 5.0)
			TV.text_tl(self, TV.fit(str(rd["name"]), 19, name_w - 18.0), Vector2(x0 + 12, y + (rh - 10 - TV.font_h(19)) * 0.5), 19, TV.ink(col))
			if id == bc.m.pid():
				draw_rect(Rect2(x0, y, 4, rh - 10), TV.GOLD)
			var w := bw * float(_w.get(id, 0.0)) / max_pct
			draw_rect(Rect2(bx, y + 4, bw, rh - 18), Color(TV.LINE, 0.45))
			draw_rect(Rect2(bx, y + 4, maxf(w, 2.0), rh - 18), col)
			TV.text_tl(self, TV.pct_es(float(_w.get(id, 0.0))) + "%", Vector2(bx + maxf(w, 2.0) + 10, y + (rh - 10 - TV.font_h(17)) * 0.5), 17, TV.WHITE)
			TV.text_tl(self, str(int(rd["seats"])), Vector2(x1 - seat_w, y + (rh - 10 - TV.font_h(32)) * 0.5), 32, TV.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT, seat_w)
			y += rh
		# Camino a la mayoría
		var best_n := 0
		var best_col: Color = TV.MUTED
		for r in bc.rows:
			if int((r as Dictionary)["seats"]) > best_n:
				best_n = int((r as Dictionary)["seats"])
				best_col = (r as Dictionary)["color"]
		var my := minf(y + 22.0, size.y - 84.0)
		draw_rect(Rect2(x0, my, x1 - x0, 12), Color(TV.LINE, 0.7))
		draw_rect(Rect2(x0, my, (x1 - x0) * clampf(float(best_n) / 350.0, 0.0, 1.0), 12), best_col)
		var mxp := x0 + (x1 - x0) * float(Rules.MAJORITY) / 350.0
		draw_rect(Rect2(mxp - 1.5, my - 6, 3, 24), TV.GOLD)
		TV.text_tl(self, "MAYORÍA ABSOLUTA · 176", Vector2(mxp - 100, my + 20), 11, TV.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER, 200)
		TV.text_tl(self, bc.majority_text(), Vector2(x0, my + 40), 15, TV.MUTED, true)

# ---------------------------------------------------------------- escena: mapa
class _SMap extends NightScene:
	var map: NightMap

	func build() -> void:
		title_text = "MAPA DEL ESCRUTINIO"
		var mc := MarginContainer.new()
		mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mc.add_theme_constant_override("margin_top", 116)
		mc.add_theme_constant_override("margin_bottom", 70)
		mc.add_theme_constant_override("margin_left", 30)
		mc.add_theme_constant_override("margin_right", 30)
		mc.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(mc)
		map = NightMap.new()
		mc.add_child(map)

	func refresh() -> void:
		if map != null:
			bc.apply_map(map)
		sub_text = ""
		queue_redraw()

	func _draw() -> void:
		super._draw()
		var x := 34.0
		var y := size.y - 52.0
		var list: Array = bc.rows.duplicate()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seats"]) > int(b["seats"]))
		for r in list.slice(0, 6):
			var rd: Dictionary = r
			var segs: Array = [{"k": "dot", "c": rd["color"]}, {"k": "t", "s": str(rd["name"]), "c": TV.WHITE, "b": true}, {"k": "t", "s": str(int(rd["seats"])), "c": TV.MUTED}]
			x += TV.rich_draw(self, segs, Vector2(x, y), 15, 28.0) + 24.0
		var snap: Dictionary = bc.snap
		TV.text_tl(self, "%d de 52 circunscripciones completadas · %d en recuento" % [int(snap.get("done", 0)), int(snap.get("started", 0)) - int(snap.get("done", 0))], Vector2(0, size.y - 22), 13, TV.FAINT, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ---------------------------------------------------------------- escena: hemiciclo
class _SHemi extends NightScene:
	var hemi: NightHemicycle

	func build() -> void:
		title_text = "EL HEMICICLO"
		var mc := MarginContainer.new()
		mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mc.add_theme_constant_override("margin_top", 96)
		mc.add_theme_constant_override("margin_bottom", 8)
		mc.add_theme_constant_override("margin_left", 20)
		mc.add_theme_constant_override("margin_right", 20)
		mc.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(mc)
		hemi = NightHemicycle.new()
		hemi.player_id = bc.m.pid()
		mc.add_child(hemi)

	func refresh() -> void:
		if hemi != null:
			bc.apply_hemi(hemi)
		queue_redraw()

# ---------------------------------------------------------------- escena: escaños en juego
class _SContested extends NightScene:
	var _items: Array = []

	func build() -> void:
		title_text = "EN JUEGO"
		sub_text = "ESCAÑOS MÁS DISPUTADOS · VOTOS QUE SEPARAN UN CAMBIO DE ESCAÑO"

	func refresh() -> void:
		_items = bc.m.election.contested(5)
		queue_redraw()

	func _draw() -> void:
		super._draw()
		if _items.is_empty():
			TV.text_tl(self, "Aún es pronto para ver escaños en juego: faltan provincias por escrutar.", Vector2(0, size.y * 0.45), 18, TV.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			return
		var x0 := size.x * 0.10
		var w := size.x * 0.80
		var y := 146.0
		var rh := 78.0
		for it in _items:
			var d: Dictionary = it
			TV.rrect(self, Rect2(x0, y, w, rh - 12), Color(TV.PANEL_HI, 0.85), 8.0, TV.LINE, 1)
			TV.text_tl(self, TV.fit(str(d["name"]), 22, 240.0), Vector2(x0 + 20, y + 10), 22, TV.WHITE)
			TV.text_tl(self, "%d escaños" % int(d["seats"]), Vector2(x0 + 20, y + 38), 13, TV.MUTED)
			var segs: Array = [
				{"k": "chip", "s": bc.short(str(d["challenger"])), "c": bc.color_of(str(d["challenger"]))},
				{"k": "t", "s": "quiere el último escaño de", "c": TV.MUTED},
				{"k": "chip", "s": bc.short(str(d["holder"])), "c": bc.color_of(str(d["holder"]))},
			]
			TV.rich_draw(self, segs, Vector2(x0 + 290, y), 16, rh - 12)
			TV.text_tl(self, TV.int_es(int(d["need"])), Vector2(x0, y + 6), 30, TV.TEAL, true, HORIZONTAL_ALIGNMENT_RIGHT, w - 20)
			TV.text_tl(self, "votos de diferencia", Vector2(x0, y + 40), 12, TV.MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT, w - 20)
			y += rh

# ---------------------------------------------------------------- escena: evolución
class _SEvolution extends NightScene:
	var chart: LineChart

	func build() -> void:
		title_text = "EVOLUCIÓN DEL VOTO"
		sub_text = "% DE VOTO DE LOS PARTIDOS PRINCIPALES EN CADA CORTE DEL ESCRUTINIO"
		var mc := MarginContainer.new()
		mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mc.add_theme_constant_override("margin_top", 134)
		mc.add_theme_constant_override("margin_bottom", 50)
		mc.add_theme_constant_override("margin_left", 60)
		mc.add_theme_constant_override("margin_right", 60)
		mc.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(mc)
		chart = LineChart.new()
		chart.show_end_labels = true
		mc.add_child(chart)

	func refresh() -> void:
		var cuts: Array = []
		for c0 in bc.m.a("election_cuts"):
			if float((c0 as Dictionary)["p"]) >= 4.0:
				cuts.append(c0)
		var ids: Array = []
		for r in bc.rows:
			ids.append(str((r as Dictionary)["id"]))
		ids.sort_custom(func(a, b) -> bool:
			var sa := 0.0
			var sb := 0.0
			for r in bc.rows:
				if str((r as Dictionary)["id"]) == a:
					sa = float((r as Dictionary)["pct"])
				if str((r as Dictionary)["id"]) == b:
					sb = float((r as Dictionary)["pct"])
			return sa > sb)
		var series: Array = []
		for id in ids.slice(0, 5):
			var vals: Array = []
			for c in cuts:
				vals.append(float(((c as Dictionary)["sh"] as Dictionary).get(id, 0.0)))
			series.append({"id": id, "name": bc.short(id), "color": bc.color_of(id), "values": vals, "width": 3.0})
		var labels: Array = []
		for c in cuts:
			labels.append("%d%%" % int(round(float((c as Dictionary)["p"]))))
		chart.x_labels = labels
		chart.series = series
		queue_redraw()

# ---------------------------------------------------------------- escena: tú eliges
class _SChoose extends NightScene:
	var picks: Array = []
	var rects: Array = []
	var hover := -1
	var detail := ""
	var back_rect := Rect2()
	var _rows: Array = []

	func build() -> void:
		title_text = "TÚ ELIGES"
		sub_text = "PULSA UNA COMUNIDAD PARA VER SUS PROVINCIAS"
		mouse_filter = Control.MOUSE_FILTER_STOP
		picks = bc.pick_communities(6)

	func refresh() -> void:
		if detail != "":
			_rows = bc.province_rows(detail)
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()

	func _layout() -> void:
		rects.clear()
		var cw := minf(size.x * 0.27, 340.0)
		var ch := 118.0
		var gx := 22.0
		var gy := 22.0
		var tw := cw * 3.0 + gx * 2.0
		var x0 := (size.x - tw) * 0.5
		var y0 := size.y * 0.5 - ch - gy * 0.5 - 6.0
		for i in range(picks.size()):
			rects.append(Rect2(x0 + float(i % 3) * (cw + gx), y0 + float(floori(i / 3.0)) * (ch + gy), cw, ch))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var p := (event as InputEventMouseMotion).position
			var h := -1
			for i in range(rects.size()):
				if (rects[i] as Rect2).has_point(p):
					h = i
			if h != hover:
				hover = h
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var p2 := (event as InputEventMouseButton).position
			if detail != "":
				if back_rect.has_point(p2):
					detail = ""
					bc.set_hold(false)
					bc._scene_t = 0.0
				return
			for i in range(rects.size()):
				if (rects[i] as Rect2).has_point(p2):
					detail = str((picks[i] as Dictionary)["name"])
					_rows = bc.province_rows(detail)
					bc.set_hold(true)
					return

	func _initials(n: String) -> String:
		var words := n.split(" ", false)
		var out := ""
		for w in words:
			if (w as String).length() > 2:
				out += (w as String).substr(0, 1).to_upper()
		if out.length() < 2:
			out = n.substr(0, 2).to_upper()
		return out.substr(0, 2)

	func _draw() -> void:
		if detail == "":
			super._draw()
			_layout()
			for i in range(picks.size()):
				var cd: Dictionary = picks[i]
				var r: Rect2 = rects[i]
				var st: Dictionary = bc.community_stats(str(cd["name"]))
				var leader := str(st["leader"])
				var col: Color = bc.color_of(leader) if leader != "" else TV.PENDING
				var hv := i == hover
				TV.rrect(self, r, Color(TV.PANEL_HI, 0.92 if hv else 0.75), 10.0, TV.TEAL if hv else Color(TV.TEAL, 0.45), 2)
				draw_circle(r.position + Vector2(48, r.size.y * 0.5), 30.0, col)
				TV.text_tl(self, _initials(str(cd["name"])), Vector2(r.position.x + 18, r.position.y + r.size.y * 0.5 - TV.font_h(20) * 0.5), 20, TV.ink(col), true, HORIZONTAL_ALIGNMENT_CENTER, 60)
				TV.text_tl(self, TV.fit(str(cd["name"]), 21, r.size.x - 110.0), Vector2(r.position.x + 92, r.position.y + 22), 21, TV.WHITE)
				TV.text_tl(self, "%d escaños" % int(cd["seats"]), Vector2(r.position.x + 92, r.position.y + 52), 14, TV.MUTED)
				var f := float(st["frac"]) * 100.0
				TV.text_tl(self, ("escrutado %d%%" % int(round(f))) if f > 0.5 else "sin datos", Vector2(r.position.x + 92, r.position.y + 76), 13, TV.FAINT)
			# Barra de tiempo de la escena
			var fr: float = bc.scene_fraction()
			var by := size.y - 64.0
			draw_rect(Rect2(size.x * 0.25, by, size.x * 0.5, 4), Color(TV.LINE, 0.8))
			draw_rect(Rect2(size.x * 0.25, by, size.x * 0.5 * fr, 4), TV.GOLD)
			return
		# Vista de provincias de una comunidad
		TV.text_tl(self, detail.to_upper(), Vector2(0, 66), 28, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		back_rect = Rect2(28, 24, 230, 34)
		TV.rrect(self, back_rect, Color(TV.PANEL_HI, 0.8), 6.0, TV.LINE, 1)
		TV.text_tl(self, "Volver a las comunidades", Vector2(28, 31), 14, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 230)
		var x0 := size.x * 0.08
		var w := size.x * 0.84
		var y := 130.0
		var big := _rows.size() <= 2
		var rh := 236.0 if big else 64.0
		for pr in _rows:
			if y + rh > size.y - 4.0:
				break
			var p: Dictionary = pr
			var cardh := rh - 10.0
			TV.rrect(self, Rect2(x0, y, w, cardh), Color(TV.PANEL_HI, 0.85), 8.0, TV.LINE, 1)
			var f2 := float(p["frac"]) * 100.0
			var sub := ("%d escaños · escrutado %d%%" % [int(p["seats"]), int(round(f2))]) if f2 > 0.5 else "%d escaños · sin datos" % int(p["seats"])
			var votes: Dictionary = p["votes"]
			var vsum := 0.0
			for v in votes.values():
				vsum += float(v)
			var vids: Array = []
			for id in votes.keys():
				if str(id) != Rules.OTHERS_ID:
					vids.append(str(id))
			vids.sort_custom(func(a, b) -> bool: return int(votes[a]) > int(votes[b]))
			var alloc: Dictionary = p["alloc"]
			var aids: Array = alloc.keys()
			aids.sort_custom(func(a, b) -> bool: return int(alloc[a]) > int(alloc[b]))
			if big:
				TV.text_tl(self, str(p["name"]), Vector2(x0 + 22, y + 14), 26, TV.WHITE)
				TV.text_tl(self, sub, Vector2(x0 + 22, y + 48), 14, TV.MUTED)
				var step := minf(26.0, (w - 44.0) / maxf(float(p["seats"]), 1.0))
				var n := 0
				for id in aids:
					for _k in range(int(alloc[id])):
						draw_circle(Vector2(x0 + 22.0 + step * (float(n) + 0.5), y + 92.0), step * 0.36, bc.color_of(str(id)))
						n += 1
				for _j in range(int(p["seats"]) - n):
					draw_circle(Vector2(x0 + 22.0 + step * (float(n) + 0.5), y + 92.0), step * 0.36, Color(TV.PENDING, 0.6))
					n += 1
				var top_share := 1.0
				if not vids.is_empty():
					top_share = maxf(float(votes[vids[0]]) / maxf(vsum, 1.0) * 100.0, 1.0)
				var by := y + 120.0
				for k in range(mini(5, vids.size())):
					var id2: String = vids[k]
					var col: Color = bc.color_of(id2)
					var sh := float(votes[id2]) / maxf(vsum, 1.0) * 100.0
					TV.rrect(self, Rect2(x0 + 22, by, 90, 20), col, 4.0)
					TV.text_tl(self, TV.fit(bc.short(id2), 13, 80.0), Vector2(x0 + 30, by + 2), 13, TV.ink(col))
					var bw := (w - 22.0 - 130.0 - 100.0) * sh / top_share
					draw_rect(Rect2(x0 + 124, by + 3, maxf(bw, 2.0), 14), col)
					TV.text_tl(self, TV.pct_es(sh) + "%", Vector2(x0 + 124 + maxf(bw, 2.0) + 10, by + 1), 14, TV.WHITE)
					by += 22.0
			else:
				TV.text_tl(self, TV.fit(str(p["name"]), 20, 230.0), Vector2(x0 + 18, y + 8), 20, TV.WHITE)
				TV.text_tl(self, sub, Vector2(x0 + 18, y + 32), 12, TV.MUTED)
				var avail := w - 280.0 - 360.0
				var step2 := clampf(avail / maxf(float(p["seats"]), 1.0), 9.0, 19.0)
				var dx := x0 + 270.0
				var n2 := 0
				for id in aids:
					for _k in range(int(alloc[id])):
						draw_circle(Vector2(dx + float(n2) * step2, y + cardh * 0.5), step2 * 0.38, bc.color_of(str(id)))
						n2 += 1
				for _j in range(int(p["seats"]) - n2):
					draw_circle(Vector2(dx + float(n2) * step2, y + cardh * 0.5), step2 * 0.38, Color(TV.PENDING, 0.6))
					n2 += 1
				var sx := x0 + w - 18.0
				var k2 := 0
				for id in vids:
					if k2 >= 3:
						break
					var txt := TV.pct_es(float(votes[id]) / maxf(vsum, 1.0) * 100.0) + "%"
					var segs: Array = [{"k": "chip", "s": bc.short(str(id)), "c": bc.color_of(str(id))}, {"k": "t", "s": txt, "c": TV.WHITE, "b": true}]
					sx -= TV.rich_width(segs, 14)
					TV.rich_draw(self, segs, Vector2(sx, y), 14, cardh)
					sx -= 20.0
					k2 += 1
			y += rh
