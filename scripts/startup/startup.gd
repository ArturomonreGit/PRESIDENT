extends Control
## Menú de inicio: nueva partida, partidas guardadas y ajustes. Misma línea visual que la partida
## (barra azul marino, fondo degradado, bloques azules y paneles planos con banda).

const SETTINGS_PATH := "user://political_simulator_settings.cfg"
const MAP_SHADES := [Color("#9CC4EA"), Color("#8DB9E3"), Color("#A9CCEE"), Color("#82B1DF")]
const PHASE_NAMES := {"campaign": "Campaña", "election_night": "Noche electoral", "results": "Resultados", "investiture": "Investidura", "cabinet_design": "Formando Gobierno", "legislature": "Legislatura"}

var view: VBoxContainer
var _wrap: MarginContainer
var _section: Label
var _back: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	_apply_settings()
	_build_frame()
	show_home()

# ---------------------------------------------------------------- marco
func _build_frame() -> void:
	add_child(UI.gradient_bg())
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var bar := UI.nav_bar(68)
	root.add_child(bar)
	var row: HBoxContainer = bar.get_child(0)
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(40, 40)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_theme_stylebox_override("panel", UI.box(UI.D4_BLUE, UI.D4_BLUE_L, 6, 1, 0, 0))
	var mt := UI.label("PS", 17, Color.WHITE, true)
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(mt)
	row.add_child(mark)
	var brand := UI.label("POLITICAL SIMULATOR", 20, Color.WHITE, true)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(brand)
	_section = UI.label("", UI.FS_LEAD, Color("#9CC4EA"), true)
	_section.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_section)
	row.add_child(UI.fill())
	_back = UI.side_button("‹  Menú principal", show_home)
	_back.custom_minimum_size = Vector2(190, 38)
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_back)
	var ver := UI.label(Rules.version_label(), UI.FS_SMALL, Color("#9AA8BD"))
	ver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ver)
	_wrap = MarginContainer.new()
	_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_wrap)
	view = UI.vbox(12)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wrap.add_child(view)

func _reset_view(section: String = "", margin: int = 28) -> void:
	UI.clear_children(view)
	_section.text = ("›  " + section) if section != "" else ""
	_back.visible = section != ""
	for side_name in ["left", "right", "top", "bottom"]:
		_wrap.add_theme_constant_override("margin_" + side_name, margin)

## Columna centrada de ancho fijo para las vistas sencillas (guardados, ajustes).
func _center_column(width: float) -> VBoxContainer:
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_child(h)
	h.add_child(UI.fill())
	var col := UI.vbox(12)
	col.custom_minimum_size = Vector2(width, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	h.add_child(UI.fill())
	return col

# ---------------------------------------------------------------- inicio
func show_home() -> void:
	_reset_view("", 0)
	var saves := SaveManager.list_saves()
	var home := Control.new()
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_child(home)
	# --- mapa de fondo (derecha)
	var map := SpainMap.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_left = 540
	map.offset_right = -430
	map.offset_top = 70
	map.offset_bottom = -40
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fills := {}
	for p in DataStore.map_provinces():
		var nm := str((p as Dictionary)["name"])
		fills[nm] = MAP_SHADES[absi(hash(nm)) % MAP_SHADES.size()]
	map.fills = fills
	home.add_child(map)
	# --- columna del menú (izquierda)
	var left := UI.vbox(10)
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.anchor_right = 0.0
	left.offset_left = 84
	left.offset_right = 560
	left.offset_top = 0
	left.offset_bottom = 0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	home.add_child(left)
	left.add_child(UI.eyebrow("ESTRATEGIA POLÍTICA · ESPAÑA", UI.D4_BLUE_D))
	var title := UI.vbox(-16)
	title.add_child(UI.label("Political", 76, UI.NAVY, true))
	title.add_child(UI.label("Simulator", 76, UI.D4_BLUE_D, true))
	left.add_child(title)
	var rule := ColorRect.new()
	rule.color = UI.D4_RED
	rule.custom_minimum_size = Vector2(96, 6)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(rule)
	var tag := UI.wrap_label("Lidera un partido desde la campaña hasta el Consejo de Ministros: encuestas, pactos de investidura y cuatro años de legislatura.", UI.FS_LEAD, UI.MUTED)
	tag.custom_minimum_size = Vector2(460, 0)
	left.add_child(tag)
	left.add_child(UI.spacer(18))
	var last_sub := ""
	if not saves.is_empty():
		var last: Dictionary = saves[0]
		last_sub = str(last.get("save_name", "Partida"))
		var ph := str(PHASE_NAMES.get(str((last.get("game_state", {}) as Dictionary).get("phase", "")), ""))
		if ph != "":
			last_sub += " · " + ph
	left.add_child(UI.menu_block("Nueva partida", "Elige partido y crea a tu líder", "main", show_new))
	left.add_child(UI.menu_block("Continuar", last_sub if last_sub != "" else "Todavía no hay partidas", "blue", _continue_last, 460.0, not saves.is_empty()))
	left.add_child(UI.menu_block("Cargar partida", "%d guardada%s" % [saves.size(), "" if saves.size() == 1 else "s"], "blue", show_load))
	left.add_child(UI.menu_block("Ajustes", "Pantalla y resolución", "quiet", show_settings))
	left.add_child(UI.menu_block("Salir", "", "danger", _quit))
	left.add_child(UI.spacer(8))
	left.add_child(UI.label("%s · Escenario ficticio inspirado en la política española" % Rules.version_label(), UI.FS_SMALL, UI.MUTED))
	# --- panorama de partida (flotante sobre el mapa)
	var holder := VBoxContainer.new()
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.offset_left = -440
	holder.offset_right = -48
	holder.offset_top = 60
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(holder)
	_poll_card(holder)

func _poll_card(parent: Node) -> void:
	var c := UI.card(parent, "Panorama de partida", "Encuestas iniciales", UI.D4_BLUE_L)
	var rows: Array = []
	for p in DataStore.parties():
		var id := str((p as Dictionary)["id"])
		rows.append({"p": p, "poll": float(Rules.BASE_POLL.get(id, 0.0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["poll"]) > float(b["poll"]))
	var top := float((rows[0] as Dictionary)["poll"])
	for i in range(mini(9, rows.size())):
		var r: Dictionary = rows[i]
		var pd: Dictionary = r["p"]
		var row := UI.hbox(8)
		var sw := ColorRect.new()
		sw.color = Color(str(pd["color"]))
		sw.custom_minimum_size = Vector2(6, 18)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var nm := UI.label(str(pd["short_name"]), UI.FS_BODY, UI.TEXT, true)
		nm.custom_minimum_size = Vector2(92, 0)
		nm.clip_text = true
		row.add_child(nm)
		var m := UI.meter(float(r["poll"]), top, Color(str(pd["color"])), 8)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		var pl := UI.label("%.1f %%" % float(r["poll"]), UI.FS_BODY, UI.TEXT, true)
		pl.custom_minimum_size = Vector2(58, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pl)
		c.add_child(row)
	c.add_child(UI.label("Y %d formaciones más · encuestas ficticias" % maxi(0, rows.size() - 9), UI.FS_SMALL, UI.MUTED))

# ---------------------------------------------------------------- nueva partida
func show_new() -> void:
	_reset_view("Nueva partida", 22)
	var wiz := NewGameWizard.new()
	wiz.cancelled.connect(show_home)
	wiz.finished.connect(_start_game)
	view.add_child(wiz)

func _start_game(p: Dictionary) -> void:
	var res := SaveManager.create_new_game(p)
	if not bool(res.get("ok", false)):
		push_error("No se pudo crear la partida")
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func show_custom() -> void:
	show_new()

# ---------------------------------------------------------------- cargar
func show_load() -> void:
	_reset_view("Partidas guardadas", 28)
	var col := _center_column(1040)
	var saves := SaveManager.list_saves()
	var c := UI.card(col, "Partidas guardadas", "%d en total" % saves.size(), UI.D4_BLUE_L)
	if saves.is_empty():
		c.add_child(UI.wrap_label("Todavía no hay partidas guardadas. Empieza una nueva desde el menú principal.", UI.FS_LEAD, UI.MUTED))
		c.add_child(UI.button("Nueva partida", "good", show_new, 220))
		return
	UI.expand_card(c)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(sc)
	var lst := UI.vbox(8)
	lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lst)
	for s in saves:
		lst.add_child(_save_row(s as Dictionary))

func _save_row(s: Dictionary) -> Control:
	var pd: Dictionary = s.get("player_party", {})
	var col := Color(str(pd.get("color", "#6F7F90")))
	var pc := PanelContainer.new()
	var sb := UI.box(UI.PANEL2, UI.D4_LINE, 4, 1, 16, 10)
	sb.border_width_left = 6
	pc.add_theme_stylebox_override("panel", sb)
	var row := UI.hbox(14)
	pc.add_child(row)
	var em := PartyEmblem.new()
	em.custom_minimum_size = Vector2(48, 48)
	em.set_identity(col, str(pd.get("short_name", "PS")).substr(0, 3), UI.motif_for(str(pd.get("id", ""))))
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(em)
	var gs: Dictionary = s.get("game_state", {})
	var phase := str(gs.get("phase", "campaign"))
	var t := UI.vbox(2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_child(UI.label(str(s.get("save_name", "Partida")), UI.FS_LEAD, UI.TEXT, true))
	t.add_child(UI.label("%s · ciclo %d · %s" % [str(pd.get("name", "")), int(gs.get("cycle", 1)), str(s.get("current_date", ""))], UI.FS_SMALL, UI.MUTED))
	row.add_child(t)
	var chip := UI.chip(str(PHASE_NAMES.get(phase, phase)), UI.D4_BLUE_D)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var path := str(s.get("_path", ""))
	var load_b := UI.pill("CARGAR", false, func() -> void: _load(path), false, UI.PILL_GO)
	load_b.custom_minimum_size = Vector2(110, 34)
	row.add_child(load_b)
	var del_b := UI.pill("BORRAR", false, func() -> void:
		SaveManager.delete_save(path)
		show_load(), false, Color("#8E9BB0"))
	del_b.custom_minimum_size = Vector2(110, 34)
	row.add_child(del_b)
	return pc

func _load(path: String) -> void:
	var res := SaveManager.load_game(path)
	if res.is_empty():
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _continue_last() -> void:
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		show_new()
		return
	_load(str((saves[0] as Dictionary)["_path"]))

# ---------------------------------------------------------------- ajustes
func show_settings() -> void:
	_reset_view("Ajustes", 28)
	var col := _center_column(720)
	col.add_child(UI.spacer(40))
	var sc := UI.card(col, "Sonido", "", UI.D4_BLUE_L)
	DisplayPanel.build_sound(sc)
	var c := UI.card(col, "Pantalla", "", UI.D4_BLUE_L)
	DisplayPanel.build(c)
	var note := UI.wrap_label("Pulsa F11 en cualquier momento para alternar la pantalla completa. Esc abre el menú de pausa durante la partida.", UI.FS_SMALL, UI.MUTED)
	c.add_child(note)

func _apply_settings() -> void:
	pass

func _quit() -> void:
	get_tree().quit()
