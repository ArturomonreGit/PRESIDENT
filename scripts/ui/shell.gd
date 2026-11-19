extends Control
## Carcasa de la interfaz: menú lateral, cabecera con el botón CONTINUAR, contenido y panel contextual.

const SCREENS := {
	"home": preload("res://scripts/ui/screens/home_screen.gd"),
	"inbox": preload("res://scripts/ui/screens/inbox_screen.gd"),
	"agenda": preload("res://scripts/ui/screens/agenda_screen.gd"),
	"program": preload("res://scripts/ui/screens/program_screen.gd"),
	"polls": preload("res://scripts/ui/screens/polls_screen.gd"),
	"electorate": preload("res://scripts/ui/screens/electorate_screen.gd"),
	"militancy": preload("res://scripts/ui/screens/militancy_screen.gd"),
	"map": preload("res://scripts/ui/screens/map_screen.gd"),
	"finance": preload("res://scripts/ui/screens/finance_screen.gd"),
	"night": preload("res://scripts/ui/screens/night_screen.gd"),
	"results": preload("res://scripts/ui/screens/results_screen.gd"),
	"investiture": preload("res://scripts/ui/screens/investiture_screen.gd"),
	"cabinet": preload("res://scripts/ui/screens/cabinet_screen.gd"),
	"coalition": preload("res://scripts/ui/screens/coalition_screen.gd"),
	"government": preload("res://scripts/ui/screens/government_screen.gd"),
	"ministry": preload("res://scripts/ui/screens/ministry_screen.gd"),
	"parties": preload("res://scripts/ui/screens/parties_screen.gd"),
	"negotiation": preload("res://scripts/ui/screens/negotiation_screen.gd"),
	"meeting": preload("res://scripts/ui/screens/meeting_screen.gd"),
	"laws": preload("res://scripts/ui/screens/laws_screen.gd"),
	"plenary": preload("res://scripts/ui/screens/plenary_screen.gd"),
	"country": preload("res://scripts/ui/screens/country_screen.gd"),
	"panel": preload("res://scripts/ui/screens/panel_screen.gd"),
	"policies": preload("res://scripts/ui/screens/policies_screen.gd"),
}

## Pantallas que no aparecen en el menú pero se pueden abrir desde otras.
const HIDDEN_SCREENS := ["meeting"]

const NAV_LABELS := {
	"home": "Resumen", "inbox": "Bandeja", "agenda": "Agenda", "program": "Programa electoral", "polls": "Encuestas", "electorate": "Electorado", "militancy": "Militancia",
	"map": "Mapa electoral", "finance": "Finanzas", "night": "Noche electoral", "results": "Resultados",
	"investiture": "Investidura", "cabinet": "Consejo de Ministros", "coalition": "Mesa de coalición", "government": "Balance", "ministry": "Cartera y PGE", "parties": "Partidos",
	"negotiation": "Negociación", "meeting": "Reunión",
	"laws": "Taller de leyes", "plenary": "Pleno", "country": "País", "panel": "Mapa de efectos", "policies": "Medidas",
}

## Bloques del menú superior por fase: cada bloque agrupa varias pantallas (subpestañas).
const HUBS_BY_PHASE := {
	"campaign": [
		{"id": "home", "label": "Resumen", "screens": ["home"]},
		{"id": "campaign", "label": "Campaña", "screens": ["program", "agenda", "negotiation"]},
		{"id": "opinion", "label": "Opinión", "screens": ["polls", "electorate", "map", "parties"]},
		{"id": "country", "label": "País", "screens": ["country"]},
		{"id": "inbox", "label": "Bandeja", "screens": ["inbox"]},
		{"id": "finance", "label": "Partido", "screens": ["finance", "militancy"]},
	],
	"election_night": [
		{"id": "night", "label": "Noche electoral", "screens": ["night"]},
		{"id": "opinion", "label": "Opinión", "screens": ["polls", "parties"]},
		{"id": "inbox", "label": "Bandeja", "screens": ["inbox"]},
	],
	"results": [
		{"id": "home", "label": "Resumen", "screens": ["home"]},
		{"id": "results", "label": "Resultados", "screens": ["results", "map", "parties"]},
		{"id": "inbox", "label": "Bandeja", "screens": ["inbox"]},
		{"id": "finance", "label": "Finanzas", "screens": ["finance"]},
	],
	"investiture": [
		{"id": "home", "label": "Resumen", "screens": ["home"]},
		{"id": "investiture", "label": "Investidura", "screens": ["investiture", "negotiation"]},
		{"id": "opinion", "label": "Resultados", "screens": ["results", "parties"]},
		{"id": "inbox", "label": "Bandeja", "screens": ["inbox"]},
		{"id": "finance", "label": "Finanzas", "screens": ["finance"]},
	],
	"cabinet_design": [
		{"id": "home", "label": "Resumen", "screens": ["home"]},
		{"id": "gov", "label": "Gobierno", "screens": ["cabinet", "investiture", "negotiation"]},
		{"id": "opinion", "label": "Resultados", "screens": ["results"]},
		{"id": "inbox", "label": "Bandeja", "screens": ["inbox"]},
		{"id": "finance", "label": "Finanzas", "screens": ["finance"]},
	],
	"legislature": [
		{"id": "home", "label": "Resumen", "screens": ["home"]},
		{"id": "gov", "label": "Gobierno", "screens": ["policies", "ministry", "government", "cabinet", "coalition", "program", "negotiation", "panel"]},
		{"id": "parl", "label": "Parlamento", "screens": ["laws", "plenary"]},
		{"id": "country", "label": "País", "screens": ["country"]},
		{"id": "opinion", "label": "Opinión", "screens": ["polls", "electorate", "results", "parties"]},
		{"id": "inbox", "label": "Bandeja", "screens": ["inbox"]},
		{"id": "finance", "label": "Partido", "screens": ["finance", "militancy"]},
	],
}

var m: GameModel
var current := ""
var screen_node: Screen = null
var nav_buttons: Dictionary = {}

var brand_box: HBoxContainer
var nav_row: HBoxContainer
var sub_row: HBoxContainer
var util_box: HBoxContainer
var header_title: Label
var header_sub: Label
var header_stats: HBoxContainer
var continue_btn: Button
var content_holder: VBoxContainer
var scroll: ScrollContainer
var rail_box: VBoxContainer
var rail_panel: PanelContainer
var margin_box: MarginContainer
var full_holder: Control
var modal_layer: Control
var toast_layer: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	var sm := get_node_or_null("/root/SaveManager")
	var data: Dictionary = {}
	if sm != null:
		data = sm.current_save
	if data.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/startup.tscn")
		return
	m = GameModel.new(data)
	_build_layout()
	if str(m.s.get("history_mode", "")) == "" and m.phase == "campaign" and m.day == 1 and m.eco.history().size() <= 1:
		await _generate_history(str(m.s.get("history_pending", "realistic")))
	refresh()
	go(default_screen())

## Pantalla de carga: reconstruye los cinco años anteriores paso a paso (cada paso cede el control para animar el progreso).
func _generate_history(mode_id: String) -> void:
	var gen := HistoryGen.new(m, mode_id)
	if gen.mode == "none":
		gen.generate()
		return
	var ov := LoadingOverlay.new()
	add_child(ov)
	var steps := gen.steps()
	ov.set_progress(0.0, "Preparando los datos del país…")
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(steps.size()):
		var st: Dictionary = steps[i]
		ov.set_progress(float(i) / float(steps.size()), str(st["label"]))
		await get_tree().process_frame
		(st["fn"] as Callable).call()
		await get_tree().process_frame
	ov.set_progress(1.0, "Listo")
	await get_tree().create_timer(0.35).timeout
	ov.queue_free()
	m.save_now()

func default_screen() -> String:
	if m.phase == "campaign" and not m.manifesto.locked():
		return "program"
	return "night" if m.phase == "election_night" else "home"

# ---------------------------------------------------------------- estructura
func _build_layout() -> void:
	add_child(UI.gradient_bg())
	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 0)
	add_child(main)

	var head := PanelContainer.new()
	head.custom_minimum_size = Vector2(0, 68)
	var head_box := UI.box(UI.NAVY, Color("#0C2037"), 0, 0, 20, 8)
	head_box.border_width_bottom = 3
	head.add_theme_stylebox_override("panel", head_box)
	main.add_child(head)
	var hrow := UI.hbox(16)
	head.add_child(hrow)
	brand_box = UI.hbox(10)
	brand_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(brand_box)
	nav_row = UI.hbox(8)
	nav_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hrow.add_child(nav_row)
	header_stats = UI.hbox(20)
	header_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(header_stats)
	continue_btn = UI.button("CONTINUAR", "primary", on_continue, 210)
	continue_btn.custom_minimum_size = Vector2(210, 44)
	continue_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	continue_btn.add_theme_font_size_override("font_size", 14)
	continue_btn.add_theme_stylebox_override("normal", UI.box(UI.PILL_GO, UI.PILL_GO.lightened(0.2), 22, 1, 18, 8))
	continue_btn.add_theme_stylebox_override("hover", UI.box(UI.PILL_GO.lightened(0.12), UI.PILL_GO.lightened(0.3), 22, 1, 18, 8))
	continue_btn.add_theme_stylebox_override("pressed", UI.box(UI.PILL_GO.darkened(0.15), UI.PILL_GO, 22, 1, 18, 8))
	hrow.add_child(continue_btn)

	var sub := PanelContainer.new()
	sub.custom_minimum_size = Vector2(0, 46)
	var sub_box := UI.box(Color("#CFE2F5"), Color("#9FBFE0"), 0, 0, 20, 6)
	sub_box.border_width_bottom = 1
	sub.add_theme_stylebox_override("panel", sub_box)
	main.add_child(sub)
	var srow := UI.hbox(12)
	sub.add_child(srow)
	var titles := UI.vbox(0)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.custom_minimum_size = Vector2(250, 0)
	srow.add_child(titles)
	header_title = UI.label("", UI.FS_SMALL, Color("#1F5A94"), true)
	header_sub = UI.label("", UI.FS_SMALL, Color("#3C5C80"))
	titles.add_child(header_title)
	titles.add_child(header_sub)
	sub_row = UI.hbox(6)
	sub_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_child(sub_row)
	util_box = UI.hbox(6)
	util_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(util_box)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	main.add_child(body)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	full_holder = Control.new()
	full_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	full_holder.clip_contents = true
	full_holder.visible = false
	body.add_child(full_holder)
	var margin := MarginContainer.new()
	margin_box = margin
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	content_holder = UI.vbox(0)
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content_holder)

	var rail := PanelContainer.new()
	rail_panel = rail
	rail.custom_minimum_size = Vector2(340, 0)
	var rail_box_style := UI.box(Color("#F4F8FD"), UI.D4_LINE, 0, 0, 16, 18)
	rail_box_style.border_width_left = 2
	rail.add_theme_stylebox_override("panel", rail_box_style)
	body.add_child(rail)
	var rail_scroll := ScrollContainer.new()
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(rail_scroll)
	rail_box = UI.vbox(12)
	rail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_scroll.add_child(rail_box)

	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	toast_layer = UI.vbox(8)
	toast_layer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toast_layer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast_layer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_layer.offset_right = -364
	toast_layer.offset_bottom = -24
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)

# ---------------------------------------------------------------- navegación
func hubs() -> Array:
	var list: Array = HUBS_BY_PHASE.get(m.phase, [{"id": "home", "label": "Resumen", "screens": ["home"]}, {"id": "inbox", "label": "Bandeja", "screens": ["inbox"]}])
	var out: Array = []
	for h in list:
		var hd: Dictionary = (h as Dictionary).duplicate()
		var scr: Array = (hd["screens"] as Array).duplicate()
		if m.exec.post_kind() == "none":
			# En la oposición no hay acceso al panel de gobierno ni a la cartera: gobierna la IA.
			scr.erase("ministry")
			scr.erase("panel")
			scr.erase("policies")
		hd["screens"] = scr
		out.append(hd)
	return out

## Etiqueta de una pantalla en el menú (el panel cambia de nombre según el cargo).
func nav_label(id: String) -> String:
	if id == "policies":
		return "Medidas de gobierno" if m.exec.post_kind() == "president" else "Mi ministerio"
	return str(NAV_LABELS.get(id, id))

func nav_ids() -> Array:
	var ids: Array = []
	for h in hubs():
		for sc in (h as Dictionary)["screens"]:
			if not ids.has(sc):
				ids.append(sc)
	return ids

func hub_of(screen_id: String) -> Dictionary:
	var sid := "negotiation" if screen_id == "meeting" else screen_id
	for h in hubs():
		if ((h as Dictionary)["screens"] as Array).has(sid):
			return h
	return {}

func go(id: String) -> void:
	if not SCREENS.has(id):
		id = "home"
	if id != current and current != "":
		Sfx.play("page", 0.8)
	if not nav_ids().has(id) and not HIDDEN_SCREENS.has(id):
		id = str(nav_ids()[0])
	current = id
	UI.clear_children(content_holder)
	UI.clear_children(full_holder)
	var node: Screen = (SCREENS[id] as GDScript).new()
	node.setup(self, m)
	node.fullscreen = node.wants_full()
	_host(node)
	screen_node = node
	node.build()
	scroll.scroll_vertical = 0
	_apply_fullscreen()
	refresh_chrome()

## Las pantallas normales van en el área con desplazamiento; las «de juego» ocupan el área útil completa, sin desplazamiento.
func _host(node: Screen) -> void:
	if node.fullscreen:
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
		node.offset_left = 8
		node.offset_top = 8
		node.offset_right = -8
		node.offset_bottom = -8
		full_holder.add_child(node)
	else:
		content_holder.add_child(node)

## Reconstruye la pantalla actual y el marco (tras una acción).
func _apply_fullscreen() -> void:
	var full := screen_node != null and is_instance_valid(screen_node) and screen_node.fullscreen
	rail_panel.visible = not full
	scroll.visible = not full
	full_holder.visible = full
	toast_layer.offset_right = -24 if full else -364

func refresh() -> void:
	if not nav_ids().has(current) and not HIDDEN_SCREENS.has(current) and current != "":
		go(default_screen())
		return
	if screen_node != null and is_instance_valid(screen_node):
		var keep := scroll.scroll_vertical
		screen_node.rebuild()
		_apply_fullscreen()
		scroll.set_deferred("scroll_vertical", keep)
	refresh_chrome()

func refresh_chrome() -> void:
	_build_nav()
	_build_header()
	_build_rail()

func phase_title() -> String:
	match m.phase:
		"campaign": return "Campaña electoral"
		"election_night": return "Noche electoral"
		"results": return "Resultados"
		"investiture": return "Investidura"
		"cabinet_design": return "Formación del Gobierno"
		"legislature": return "Legislatura"
	return ""

func phase_detail() -> String:
	match m.phase:
		"campaign": return "Día %d de %d · %d días para las elecciones" % [m.day, Rules.CAMPAIGN_LENGTH_DAYS, Rules.CAMPAIGN_LENGTH_DAYS - m.day]
		"election_night": return "Escrutinio en curso"
		"results": return "Elecciones del %s" % Rules.date_string(m.election_unix())
		"investiture": return "Intento %d de %d · %s votación" % [m.gov.attempts() + 1, Rules.MAX_INVESTITURE_ATTEMPTS, "primera" if m.gov.round_number() == 1 else "segunda"]
		"cabinet_design": return "El candidato ha sido investido"
		"legislature": return "Trimestre %d de %d" % [m.turn(), Rules.LEGISLATURE_TURNS]
	return ""

func refresh_chrome_nav() -> void:
	_build_nav()

func _build_nav() -> void:
	UI.clear_children(brand_box)
	UI.clear_children(nav_row)
	UI.clear_children(sub_row)
	UI.clear_children(util_box)
	nav_buttons.clear()
	brand_box.add_child(UI.leader_portrait(m, m.pid(), 46))
	var bt := UI.vbox(0)
	bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bt.add_child(UI.label(str(m.party.get("short_name", "Tu partido")), UI.FS_LEAD, Color.WHITE, true))
	bt.add_child(UI.label(m.leader_name(m.pid()), UI.FS_SMALL, Color("#9FB6D0")))
	brand_box.add_child(bt)
	var cur_hub := hub_of(current)
	for h in hubs():
		var hd: Dictionary = h
		var first := str((hd["screens"] as Array)[0])
		var text := str(hd["label"])
		var is_inbox := str(hd["id"]) == "inbox"
		if is_inbox and m.attention_count() > 0:
			text += "  %d" % m.attention_count()
		var active := not cur_hub.is_empty() and str(cur_hub["id"]) == str(hd["id"])
		var urgent := is_inbox and m.attention_count() > 0
		var b := UI.pill(text, active, go.bind(first), true, UI.PILL_WARN if urgent else UI.PILL)
		nav_row.add_child(b)
		nav_buttons[str(hd["id"])] = b
	if not cur_hub.is_empty() and (cur_hub["screens"] as Array).size() > 1:
		for sid in cur_hub["screens"]:
			var sid_s := str(sid)
			var active2 := sid_s == current or (sid_s == "negotiation" and current == "meeting")
			sub_row.add_child(UI.pill(nav_label(sid_s), active2, go.bind(sid_s), false, UI.PILL_SUB))

func _build_header() -> void:
	header_title.text = phase_title().to_upper()
	header_sub.text = "%s  ·  %s" % [m.date_label(), phase_detail()]
	UI.clear_children(header_stats)
	var trend := m.campaign.trend(m.pid())
	_stat("Intención de voto", "%.1f%%" % m.player_poll(), "%s %s" % [UI.signed(trend, 1), m.campaign.trend_label()], UI.delta_color(trend))
	if m.phase in ["campaign", "legislature"]:
		_stat("Confianza", "%.0f" % m.trust, "", Color.WHITE)
	if m.phase == "legislature":
		var istate := m.itrust.state()
		var icol := UI.GOOD if str(istate["tone"]) == "good" else (UI.WARN if str(istate["tone"]) == "warn" else UI.BAD)
		_stat("Partido", "%.0f" % m.itrust.value(), str(istate["name"]), icol)
	_stat("Fondos", Rules.money(m.funds), "", UI.WARN if m.funds < 60000.0 else UI.TEXT)
	var label := continue_label()
	continue_btn.text = label
	continue_btn.disabled = label == ""
	continue_btn.visible = label != ""

func _stat(title: String, value: String, delta: String, delta_color: Color) -> void:
	var v := UI.vbox(0)
	v.add_child(UI.label(title.to_upper(), UI.FS_TINY, Color("#8FA9C7"), true))
	var row := UI.hbox(6)
	row.add_child(UI.label(value, UI.FS_H2, Color.WHITE, true))
	if delta != "":
		var dl := UI.label(delta, UI.FS_SMALL, delta_color.lightened(0.35) if delta_color != UI.MUTED else Color("#9FB6D0"))
		dl.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(dl)
	v.add_child(row)
	header_stats.add_child(v)

func continue_label() -> String:
	match m.phase:
		"campaign":
			if not m.manifesto.locked():
				return "REDACTAR EL PROGRAMA"
			var pending := m.campaign.pending_today().size()
			if pending > 0:
				return "JUGAR ACTOS DE HOY (%d)" % pending
			if m.day >= Rules.CAMPAIGN_LENGTH_DAYS:
				return "IR A LA NOCHE ELECTORAL"
			return "CONTINUAR"
		"election_night":
			return "IR AL ESCRUTINIO"
		"results":
			return "INICIAR CONSULTAS"
		"investiture":
			return "VOTAR LA INVESTIDURA"
		"cabinet_design":
			return "CONSTITUIR EL GOBIERNO"
		"legislature":
			if m.congress.pending():
				return "IR AL PLENO (%d)" % m.congress.remaining()
			return "SIGUIENTE MES"
	return ""

# ---------------------------------------------------------------- panel contextual
func _build_rail() -> void:
	UI.clear_children(rail_box)
	# Encuestas
	rail_box.add_child(UI.eyebrow("Encuestas" if m.phase in ["campaign", "legislature"] else "Intención de voto"))
	var rows := m.ranked_polls_with_player(7)
	for r in rows:
		var rd: Dictionary = r
		var id := str(rd["id"])
		var line := UI.hbox(8)
		var rk := UI.label("%d" % int(rd.get("rank", 0)), UI.FS_SMALL, UI.FAINT)
		rk.custom_minimum_size = Vector2(16, 0)
		line.add_child(rk)
		var tag := UI.party_tag(m, id, UI.FS_BODY, m.is_player(id))
		tag.custom_minimum_size = Vector2(84, 0)
		line.add_child(tag)
		var bar := UI.meter(float(rd["share"]), 40.0, m.party_color(id), 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var sh := UI.label("%.1f" % float(rd["share"]), UI.FS_BODY, UI.TEXT, m.is_player(id))
		sh.custom_minimum_size = Vector2(36, 0)
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(sh)
		var tr := m.campaign.trend(id)
		var tl := UI.label(UI.signed(tr, 1), UI.FS_SMALL, UI.delta_color(tr))
		tl.custom_minimum_size = Vector2(34, 0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(tl)
		rail_box.add_child(line)
	rail_box.add_child(UI.hsep())
	match m.phase:
		"campaign":
			_rail_campaign()
		"legislature":
			_rail_legislature()
		"investiture":
			_rail_investiture()
		_:
			_rail_results()

func _rail_campaign() -> void:
	var obj := m.d("objective")
	var proj := int(m.election.project_seats().get(m.pid(), 0))
	var target := int(obj.get("target_seats", 1))
	rail_box.add_child(UI.eyebrow("Objetivo de la dirección"))
	rail_box.add_child(UI.label("%d escaños" % target, UI.FS_H2, UI.TEXT, true))
	var delta := proj - target
	rail_box.add_child(UI.label("Proyección actual: %d (%s)" % [proj, UI.signed(float(delta), 0)], UI.FS_SMALL, UI.delta_color(float(delta), 0.5)))
	rail_box.add_child(UI.meter(float(proj), float(maxi(maxi(target, proj), 1)) * 1.1, UI.GOOD if proj >= target else UI.WARN, 8))
	rail_box.add_child(UI.hsep())
	rail_box.add_child(UI.eyebrow("Próximos actos"))
	var up := m.campaign.upcoming(4)
	if up.is_empty():
		rail_box.add_child(UI.wrap_label("Sin actos programados. Abre la agenda para planificar la semana.", UI.FS_SMALL, UI.MUTED))
	for e in up:
		var ev: Dictionary = e
		var col := Color(str((Rules.EVENT_TYPES.get(str(ev["type"]), {"color": "#8FA3B8"}) as Dictionary)["color"]))
		var row := UI.hbox(8)
		var bar := ColorRect.new()
		bar.color = col
		bar.custom_minimum_size = Vector2(3, 30)
		row.add_child(bar)
		var col2 := UI.vbox(0)
		col2.add_child(UI.label(str(ev["title"]), UI.FS_SMALL, UI.TEXT, true))
		col2.add_child(UI.label("Día %d · %02d:00 · %s" % [int(ev["day"]), int(ev["hour"]), str(ev["region"])], UI.FS_TINY, UI.MUTED))
		row.add_child(col2)
		rail_box.add_child(row)

func _rail_legislature() -> void:
	rail_box.add_child(UI.eyebrow("Estado de la legislatura"))
	_rail_meter("Apoyo al Gobierno", m.gov.approval(), UI.ACCENT)
	_rail_meter("Estabilidad de la mayoría", m.gov.stability(), UI.GOOD if m.gov.stability() > 40 else UI.BAD)
	_rail_meter("Economía", m.gov.economy(), UI.WARN)
	rail_box.add_child(UI.hsep())
	rail_box.add_child(UI.eyebrow("Tu papel"))
	var role := m.role()
	var txt := {"government": "Presidencia del Gobierno", "partner": "Socio de Gobierno", "opposition": "Oposición", "none": ""}
	rail_box.add_child(UI.label(str(txt.get(role, "")), UI.FS_LEAD, UI.TEXT, true))
	rail_box.add_child(UI.label("Iniciativas por registrar: %d" % m.gov.bills_left(), UI.FS_SMALL, UI.MUTED))
	rail_box.add_child(UI.hsep())
	rail_box.add_child(UI.eyebrow("Economía"))
	var bal := m.eco.balance_pct()
	rail_box.add_child(UI.label("Saldo público %s%% del PIB" % UI.signed(bal, 1), UI.FS_LEAD, UI.GOOD if bal >= 0.0 else UI.BAD, true))
	rail_box.add_child(UI.label("Deuda %s%% · satisfacción %s" % [String.num(m.eco.debt_pct(), 0), String.num(m.eco.avg_satisfaction(), 0)], UI.FS_SMALL, UI.MUTED))

func _rail_meter(title: String, value: float, color: Color) -> void:
	var row := UI.hbox(6)
	row.add_child(UI.label(title, UI.FS_SMALL, UI.MUTED))
	row.add_child(UI.fill())
	row.add_child(UI.label("%.0f" % value, UI.FS_SMALL, UI.TEXT, true))
	rail_box.add_child(row)
	rail_box.add_child(UI.meter(value, 100.0, color, 6))

func _rail_investiture() -> void:
	var est := m.gov.estimate_votes()
	rail_box.add_child(UI.eyebrow("Cómputo previsto"))
	rail_box.add_child(UI.label("%d votos a favor" % int(est["yes"]), UI.FS_H2, UI.GOOD if int(est["yes"]) >= Rules.MAJORITY else UI.TEXT, true))
	rail_box.add_child(UI.label("%d en contra · %d abstenciones" % [int(est["no"]), int(est["abstain"])], UI.FS_SMALL, UI.MUTED))
	var mb := UI.meter(float(est["yes"]), 350.0, UI.GOOD, 8)
	mb.marker = float(Rules.MAJORITY)
	rail_box.add_child(mb)
	rail_box.add_child(UI.label("Mayoría absoluta: %d" % Rules.MAJORITY, UI.FS_TINY, UI.FAINT))

func _rail_results() -> void:
	if m.d("election_totals").is_empty() or m.phase == "election_night":
		return
	rail_box.add_child(UI.eyebrow("Último resultado"))
	var ids: Array = m.d("election_totals").keys()
	ids.sort_custom(func(x, y) -> bool: return m.seats_of(str(x)) > m.seats_of(str(y)))
	for id in ids.slice(0, 6):
		var row := UI.hbox(8)
		var t := UI.party_tag(m, str(id), UI.FS_BODY, m.is_player(str(id)))
		t.custom_minimum_size = Vector2(110, 0)
		row.add_child(t)
		row.add_child(UI.fill())
		row.add_child(UI.label("%d" % m.seats_of(str(id)), UI.FS_BODY, UI.TEXT, true))
		rail_box.add_child(row)

# ---------------------------------------------------------------- avisos y diálogos
const MAX_TOASTS := 3

func toast(text: String, tone: String = "neutral", key: String = "") -> void:
	if text == "":
		return
	# Un aviso con la misma clave sustituye al anterior.
	if key != "":
		for c0 in toast_layer.get_children():
			if str(c0.get_meta("key", "")) == key:
				toast_layer.remove_child(c0)
				c0.queue_free()
	# Un aviso idéntico se refresca (con contador) en lugar de apilarse.
	for c in toast_layer.get_children():
		if str(c.get_meta("text", "")) == text:
			var n := int(c.get_meta("count", 1)) + 1
			c.set_meta("count", n)
			(c.get_meta("label") as Label).text = "%s  ×%d" % [text, n]
			var old: Tween = c.get_meta("tween")
			if old != null:
				old.kill()
			c.modulate.a = 1.0
			_toast_life(c as Control)
			return
	Sfx.play("day" if key == "advance" else ("deny" if tone in ["bad", "danger"] else ("confirm" if tone == "good" else "notify")), 0.7)
	while toast_layer.get_child_count() >= MAX_TOASTS:
		var first := toast_layer.get_child(0)
		toast_layer.remove_child(first)
		first.queue_free()
	var pc := PanelContainer.new()
	var col := UI.tone_color(tone)
	pc.add_theme_stylebox_override("panel", UI.box(Color.WHITE, col, 8, 1, 16, 12, true))
	pc.custom_minimum_size = Vector2(320, 0)
	var l := UI.wrap_label(text, UI.FS_BODY, UI.TEXT)
	l.custom_minimum_size = Vector2(300, 0)
	pc.add_child(l)
	pc.set_meta("text", text)
	pc.set_meta("key", key)
	pc.set_meta("label", l)
	pc.set_meta("count", 1)
	toast_layer.add_child(pc)
	_toast_life(pc)

func _toast_life(pc: Control) -> void:
	var tw := create_tween()
	pc.set_meta("tween", tw)
	tw.tween_interval(3.6)
	tw.tween_property(pc, "modulate:a", 0.0, 0.4)
	tw.tween_callback(pc.queue_free)

## Abre un cuadro modal y devuelve su VBox de contenido. Ciérralo con close_modal().
func modal(title: String, width: float = 560.0, subtitle: String = "") -> VBoxContainer:
	close_modal()
	var overlay := ColorRect.new()
	overlay.color = Color(0.08, 0.11, 0.17, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.name = "ModalOverlay"
	modal_layer.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.BORDER, 12, 1, 24, 20))
	center.add_child(panel)
	var col := UI.vbox(12)
	panel.add_child(col)
	col.add_child(UI.label(title, UI.FS_H2, UI.TEXT, true))
	if subtitle != "":
		col.add_child(UI.wrap_label(subtitle, UI.FS_BODY, UI.MUTED))
	return col

func close_modal() -> void:
	for c in modal_layer.get_children():
		modal_layer.remove_child(c)
		c.queue_free()

func confirm(title: String, text: String, ok_label: String, on_ok: Callable, kind: String = "primary") -> void:
	var col := modal(title, 520.0)
	col.add_child(UI.wrap_label(text, UI.FS_BODY, UI.MUTED))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Cancelar", "ghost", close_modal))
	row.add_child(UI.button(ok_label, kind, func() -> void:
		close_modal()
		on_ok.call()))
	col.add_child(row)

func info(title: String, text: String, tone: String = "neutral", then: Callable = Callable()) -> void:
	var col := modal(title, 520.0)
	col.add_child(UI.wrap_label(text, UI.FS_BODY, UI.TEXT))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Entendido", "primary", func() -> void:
		close_modal()
		if then.is_valid():
			then.call()))
	col.add_child(row)

func _open_display_settings() -> void:
	var col := modal("Pantalla", 560.0)
	DisplayPanel.build(col)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Cerrar", "primary", close_modal))
	col.add_child(row)

# ---------------------------------------------------------------- guardado y menú
func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		if get_node_or_null("PauseMenu") == null:
			PauseMenu.open(self)
			get_viewport().set_input_as_handled()

func open_pause_menu() -> void:
	PauseMenu.open(self)

func save_game() -> void:
	m.save_now()
	toast("Partida guardada.", "good")

func back_to_menu() -> void:
	m.save_now()
	get_tree().change_scene_to_file("res://scenes/startup.tscn")

# ---------------------------------------------------------------- botón CONTINUAR
## Si alguna decisión pendiente caduca hoy (último día para responder), avisa antes de avanzar. Devuelve true si ha frenado el avance.
func _guard_expiring(proceed: Callable) -> bool:
	if m.phase != "campaign" and m.phase != "legislature":
		return false
	var clock := m.day if m.phase == "campaign" else m.gov_month
	var last: Array = []
	for pm in m.pending_messages():
		var d: Dictionary = pm
		if d.has("expires_day") and int(d["expires_day"]) <= clock:
			last.append(str(d.get("title", "")))
	if last.is_empty():
		return false
	var lines := ""
	for i in range(mini(last.size(), 3)):
		lines += "\n· %s" % str(last[i])
	if last.size() > 3:
		lines += "\n· y %d más" % (last.size() - 3)
	var body := "Hoy es el último día para responder a %s. Si sigues, %s sin respuesta.%s" % ["esto" if last.size() == 1 else "estos asuntos", "caduca" if last.size() == 1 else "caducan", lines]
	confirm("Algo caduca hoy", body, "Continuar igualmente", proceed, "warn")
	return true

func on_continue() -> void:
	if _guard_expiring(_do_continue):
		return
	_do_continue()

func _do_continue() -> void:
	match m.phase:
		"campaign": _continue_campaign()
		"election_night":
			go("night")
			if screen_node != null and screen_node.has_method("open_broadcast"):
				screen_node.open_broadcast()
		"results": _start_consultations()
		"investiture": confirm_vote()
		"cabinet_design": _form_government()
		"legislature":
			if m.congress.pending():
				go("plenary")
			else:
				_next_month()

## Abre una mesa de negociación con un partido y navega a ella. La IA siempre llega con su propuesta (`agenda`).
## Si ya hay una mesa abierta con otro partido, pide confirmación antes de cerrarla.
func open_meeting(id: String, topic: String, extra: Dictionary = {}) -> void:
	if topic == "law_deal" and str(extra.get("law", "")) == "":
		_pick_law_for_deal(id)
		return
	var cur := m.diplomacy.current()
	if m.diplomacy.active() and str(cur.get("with", "")) == id and str(cur.get("topic", "")) == topic:
		MeetingScreen.return_to = current if current != "meeting" else MeetingScreen.return_to
		go("meeting")
		return
	if m.diplomacy.active() and str(cur.get("with", "")) != id:
		var go_on := func() -> void:
			m.diplomacy.leave()
			open_meeting(id, topic, extra)
		confirm("Ya tienes una mesa abierta", "Estás negociando con %s. Si abres otra mesa, esa se cierra sin acuerdo." % m.party_name(str(cur["with"])), "Cerrar y abrir la nueva", go_on, "warn")
		return
	var opts := extra.duplicate()
	if not opts.has("agenda"):
		opts["agenda"] = true
	var res := m.diplomacy.open(id, topic, opts)
	if not bool(res.get("ok", false)):
		toast(str(res.get("error", "No se puede abrir la mesa.")), "warn")
		return
	MeetingScreen.return_to = current if current != "meeting" else MeetingScreen.return_to
	go("meeting")

## Antes de negociar una ley hay que elegir cuál: ventana con tus borradores y leyes registradas y cómo las ve ese grupo.
func _pick_law_for_deal(id: String) -> void:
	var laws: Array = m.diplomacy.deal_laws()
	var col := modal("Pacto por una ley con %s" % m.party_short(id), 640.0, "Elige la ley cuyo apoyo quieres negociar. Verás qué cambios exigen y qué favor te piden a cambio.")
	if laws.is_empty():
		col.add_child(UI.wrap_label("No tienes ninguna ley en preparación. Crea un borrador en el Taller de leyes.", UI.FS_BODY, UI.MUTED))
	for l in laws:
		var law: Dictionary = l
		var st: Dictionary = m.laws.stance(law, id)
		var vote := str(st["vote"])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.BORDER, 10, 1, 14, 10))
		col.add_child(row)
		var h := UI.hbox(10)
		row.add_child(h)
		var t := UI.vbox(2)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UI.label(str(law["title"]), UI.FS_BODY, UI.TEXT, true))
		t.add_child(UI.label("%d medida%s · %s" % [(law["changes"] as Dictionary).size(), "" if (law["changes"] as Dictionary).size() == 1 else "s", "registrada" if m.laws.is_registered(str(law["id"])) else "borrador"], UI.FS_SMALL, UI.MUTED))
		h.add_child(t)
		h.add_child(UI.chip({"yes": "Votaría a favor", "no": "Votaría en contra", "abstain": "Dudoso"}[vote], {"yes": UI.GOOD, "no": UI.BAD, "abstain": UI.WARN}[vote], true))
		var lid := str(law["id"])
		h.add_child(UI.button("Negociar", "primary", func() -> void:
			close_modal()
			open_meeting(id, "law_deal", {"law": lid}), 100))
	var r := UI.hbox(8)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(UI.button("Cancelar", "ghost", close_modal))
	col.add_child(r)

func _continue_campaign() -> void:
	if not m.manifesto.locked():
		toast("Antes de empezar la campaña debes redactar y firmar tu programa electoral.", "warn")
		go("program")
		return
	if not m.campaign.pending_today().is_empty():
		play_pending()
		return
	var res := m.campaign.smart_continue()
	var stop := str(res.get("stop", ""))
	var days := int(res.get("days", 0))
	if stop == "election":
		confirm("Se cierra la campaña", "Es el último día de campaña. ¿Quieres pasar a la noche electoral? Ya no podrás cambiar nada.", "Ir a la noche electoral", func() -> void:
			m.election.begin_night()
			go("night"))
		return
	var reason := {"event": "tienes actos que jugar", "message": "hay un mensaje que requiere tu respuesta", "limit": "ha pasado tiempo sin novedades"}
	m.save_now()
	if days > 0:
		toast("%d día%s después: %s." % [days, "" if days == 1 else "s", str(reason.get(stop, ""))], "neutral", "advance")
	if stop == "message":
		go("inbox")
	elif stop == "event":
		go("agenda")
		refresh()
	else:
		refresh()

func _start_consultations() -> void:
	m.gov.begin_investiture()
	go("investiture")

func _form_government() -> void:
	var res := m.gov.form_government()
	if not bool(res.get("ok", false)):
		toast(str(res.get("error", "No se puede constituir el Gobierno.")), "bad")
		return
	go("home")
	toast("El Gobierno queda constituido.", "good")

func _next_month() -> void:
	if not m.gov.pending_event_message().is_empty():
		confirm("Asunto sin resolver", "Tienes una decisión pendiente en la Bandeja. Si continúas se aplicará la opción más pasiva.", "Continuar igualmente", _do_next_month, "warn")
		return
	_do_next_month()

func _do_next_month() -> void:
	var res := m.gov.advance_turn()
	if bool(res.get("elections", false)):
		go("home")
		info("Elecciones generales", "Se convocan nuevas elecciones. Arranca una nueva campaña electoral.", "warn")
	else:
		refresh()
		toast("Trimestre %d de legislatura." % m.turn(), "neutral")

# ---------------------------------------------------------------- votación de investidura
func confirm_vote() -> void:
	open_investiture_vote()

## Abre la pantalla especial de investidura (presentación, votación animada y resultado).
## Con `replay_session` repite una votación ya celebrada sin volver a votar.
func open_investiture_vote(replay_session: Dictionary = {}) -> InvestitureBroadcast:
	if has_node("InvestitureBroadcast"):
		return get_node("InvestitureBroadcast") as InvestitureBroadcast
	var b := InvestitureBroadcast.open(self, m, replay_session)
	b.finished.connect(_on_investiture_finished)
	return b

func _on_investiture_finished(res: Dictionary) -> void:
	var dissolved := bool(res.get("dissolved", false))
	if bool(res.get("passed", false)):
		go("cabinet")
	elif dissolved or m.phase == "campaign":
		go("home")
	else:
		go("investiture")
	refresh()

# ---------------------------------------------------------------- jugar actos
func play_pending() -> void:
	var list := m.campaign.pending_today()
	if list.is_empty():
		refresh()
		return
	play_event(list[0] as Dictionary, play_pending)

func play_event(ev: Dictionary, then: Callable = Callable()) -> void:
	var type_name := str(ev.get("type", ""))
	var info_dict: Dictionary = Rules.EVENT_TYPES.get(type_name, {})
	var col := modal(str(ev.get("title", type_name)), 580.0, "%s · %s · %02d:00" % [type_name, str(ev.get("region", "")), int(ev.get("hour", 9))])
	col.add_child(UI.wrap_label(str(info_dict.get("desc", "")), UI.FS_BODY, UI.MUTED))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	var finish := func(result: Dictionary) -> void:
		m.save_now()
		_show_event_result(result, then)
	if m.campaign.is_interview_type(type_name):
		row.add_child(UI.button("Delegar en el portavoz", "ghost", func() -> void:
			var before := m.player_poll()
			var r := m.campaign.resolve_auto(ev)
			r["poll_delta"] = m.player_poll() - before
			finish.call(r)))
		row.add_child(UI.button("Participar en persona", "primary", func() -> void:
			_run_interview(ev, then)))
	else:
		row.add_child(UI.button("Delegar", "ghost", func() -> void:
			var before := m.player_poll()
			var r := m.campaign.resolve_auto(ev)
			r["poll_delta"] = m.player_poll() - before
			finish.call(r)))
		row.add_child(UI.button("Celebrar el acto", "primary", func() -> void:
			var before2 := m.player_poll()
			var r2 := m.campaign.resolve_auto(ev)
			r2["poll_delta"] = m.player_poll() - before2
			finish.call(r2)))

func _run_interview(ev: Dictionary, then: Callable) -> void:
	play_studio(ev, then)

## Abre el plató (debate, entrevista, pódcast, rueda de prensa o sesión de control) a pantalla completa.
func play_studio(ev: Dictionary, then: Callable = Callable()) -> MediaStudio:
	close_modal()
	var studio := MediaStudio.open(self, m, ev)
	studio.finished.connect(func(res: Dictionary) -> void:
		m.save_now()
		refresh()
		if then.is_valid():
			if then.get_argument_count() > 0:
				then.call(res)
			else:
				then.call())
	return studio

## Acepta una oferta de la agenda mediática de la legislatura y entra al plató.
func start_media_offer(oid: int) -> void:
	var o := m.media.find(oid)
	if o.is_empty() or str(o.get("status", "")) != "open":
		return
	if not m.media.take_slot():
		toast("No te quedan huecos de agenda este trimestre.", "warn")
		return
	var ev := m.media.event_for(o)
	play_studio(ev, func(res: Dictionary) -> void:
		m.media.record(res)
		m.media.mark(oid, "done")
		refresh())

## Delegar una oferta en el portavoz (gratis, rinde menos).
func delegate_media_offer(oid: int) -> void:
	var res := m.media.delegate(oid)
	if res.is_empty():
		return
	m.save_now()
	toast(str(res.get("summary", "Delegada en el portavoz.")), "neutral")
	refresh()

## Si una acción de la Bandeja pidió abrir el plató, lo abre. Devuelve true si lo hizo.
func consume_studio_request() -> bool:
	if not m.s.has("open_studio"):
		return false
	var oid := int(m.s["open_studio"])
	m.s.erase("open_studio")
	start_media_offer(oid)
	return true

func _chip_row(chips: Array) -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for c in chips:
		var cd: Dictionary = c
		var d := float(cd["delta"])
		var unit := " pts" if str(cd.get("unit", "")) == "pts" else ""
		fl.add_child(UI.chip("%s %s%s" % [str(cd["label"]), UI.signed(d, 2 if unit != "" else 1), unit], UI.GOOD if d >= 0.0 else UI.BAD))
	return fl

func _show_event_result(result: Dictionary, then: Callable) -> void:
	var col := modal("Balance del acto", 600.0)
	if result.has("headline"):
		var hl: Dictionary = result["headline"]
		var tone_col := UI.GOOD if str(hl.get("tone", "")) == "positive" else (UI.BAD if str(hl.get("tone", "")) == "warning" else UI.MUTED)
		var hp := PanelContainer.new()
		hp.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, tone_col, 8, 1, 14, 10))
		var hv := UI.vbox(2)
		hv.add_child(UI.label(str(hl.get("outlet", "")).to_upper(), UI.FS_TINY, UI.MUTED, true))
		hv.add_child(UI.wrap_label("«%s»" % str(hl.get("text", "")), UI.FS_LEAD, UI.TEXT, true))
		hp.add_child(hv)
		col.add_child(hp)
	else:
		col.add_child(UI.wrap_label(str(result.get("summary", "")), UI.FS_LEAD, UI.TEXT))
	var pd := float(result.get("poll_delta", 0.0))
	var stats := UI.hbox(24)
	var v1 := UI.vbox(0)
	v1.add_child(UI.label("INTENCIÓN DE VOTO", UI.FS_TINY, UI.MUTED, true))
	v1.add_child(UI.label("%.2f%% (%s)" % [m.player_poll(), UI.signed(pd, 2)], UI.FS_H2, UI.delta_color(pd, 0.004), true))
	stats.add_child(v1)
	var v2 := UI.vbox(0)
	v2.add_child(UI.label("CONFIANZA · VISIBILIDAD", UI.FS_TINY, UI.MUTED, true))
	v2.add_child(UI.label("%.0f · %.0f" % [m.trust, m.visibility], UI.FS_H2, UI.TEXT, true))
	stats.add_child(v2)
	col.add_child(stats)
	if result.has("tally") and not (result["tally"] as Dictionary).is_empty():
		col.add_child(UI.label("CÓMO TE VEN AHORA", UI.FS_TINY, UI.MUTED, true))
		var chips: Array = []
		for k in (result["tally"] as Dictionary).keys():
			var dv := float((result["tally"] as Dictionary)[k])
			if absf(dv) >= 0.4:
				chips.append({"label": str(Encounters.IMAGE_DIMS.get(k, k)), "delta": dv})
		if not chips.is_empty():
			col.add_child(_chip_row(chips))
	if result.has("seg_tally"):
		var best_k := ""
		var worst_k := ""
		var best := 0.0
		var worst := 0.0
		for k2 in (result["seg_tally"] as Dictionary).keys():
			var sv := float((result["seg_tally"] as Dictionary)[k2])
			if sv > best:
				best = sv
				best_k = str(k2)
			if sv < worst:
				worst = sv
				worst_k = str(k2)
		if best_k != "" and best >= 0.8:
			col.add_child(UI.label("Conecta mejor con: %s" % str(Encounters.SEGMENTS[best_k]["name"]), UI.FS_SMALL, UI.GOOD, true))
		if worst_k != "" and worst <= -0.8:
			col.add_child(UI.label("Pierde fuelle entre: %s" % str(Encounters.SEGMENTS[worst_k]["name"]), UI.FS_SMALL, UI.BAD, true))
	if result.has("rel") and not (result["rel"] as Dictionary).is_empty():
		var rc: Array = []
		for k3 in (result["rel"] as Dictionary).keys():
			rc.append({"label": "Relación con %s" % m.party_short(str(k3)), "delta": float((result["rel"] as Dictionary)[k3])})
		col.add_child(_chip_row(rc))
	if result.has("raised"):
		col.add_child(UI.label("Recaudado: %s" % Rules.money(float(result["raised"])), UI.FS_BODY, UI.GOOD, true))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Continuar", "primary", func() -> void:
		close_modal()
		refresh()
		if then.is_valid():
			then.call()))
	col.add_child(row)
