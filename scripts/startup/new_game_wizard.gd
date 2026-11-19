class_name NewGameWizard
extends VBoxContainer
## Asistente de nueva partida: partido → (identidad → ideología) → personaje → resumen.
## Emite `finished(party)` con el diccionario de partido listo para SaveManager.create_new_game.

signal finished(party: Dictionary)
signal cancelled

const PALETTE := ["#D62839", "#E85D04", "#F2A900", "#8DB600", "#1B9E5A", "#0FA3B1", "#2563EB", "#5B4BDB", "#9B3DC9", "#D6336C", "#7A5C3E", "#3D4B5C"]
const MOTIFS := ["star", "sun", "bars", "leaf", "wave"]
const STEP_NAMES := {"party": "Partido", "identity": "Identidad", "ideology": "Ideología", "character": "Personaje", "summary": "Resumen"}
const STEP_TITLES := {"party": "Elige el partido que vas a dirigir", "identity": "Dale identidad a tu partido", "ideology": "Define tu ideología", "character": "Crea a tu líder", "summary": "Resumen de la partida"}

class AxisBar extends Control:
	var value := 0.0
	var left_text := ""
	var right_text := ""
	func _init(v: float, l: String, r: String) -> void:
		value = v
		left_text = l
		right_text = r
		custom_minimum_size = Vector2(0, 38)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := 10.0
		draw_rect(Rect2(0, y, size.x, 6), UI.PANEL3)
		var x := size.x * (0.5 + clampf(value, -1.0, 1.0) * 0.5)
		draw_rect(Rect2(minf(x, size.x * 0.5), y, absf(x - size.x * 0.5), 6), UI.D4_BLUE_L)
		draw_rect(Rect2(size.x * 0.5 - 1, y - 3, 2, 12), UI.FAINT)
		draw_circle(Vector2(x, y + 3), 8.0, UI.D4_BLUE_D)
		draw_circle(Vector2(x, y + 3), 3.5, Color.WHITE)
		var f := UI.regular_font()
		draw_string(f, Vector2(0, y + 26), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
		draw_string(f, Vector2(0, y + 26), right_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 11, UI.MUTED)

var step := "party"
var mode := "existing"
var party_id := "psoe"
var custom := {"name": "Nuevo Partido", "short": "NP", "motto": "", "color": "#2563EB", "motif": "star", "picks": [], "territory": ""}
var hero: Dictionary = Leader.default_character()
var mood := "neutral"
var history_mode := "realistic"
var _body: VBoxContainer
var _hint: Label = null
var _nav_next: Button = null
var _nav_problem: Label = null
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rng.randomize()
	hero = Leader.random_player(_rng)
	hero["name"] = ""
	hero["surname"] = ""

func _ready() -> void:
	render()

func _steps() -> Array:
	return ["party", "identity", "ideology", "character", "summary"] if mode == "custom" else ["party", "character", "summary"]

# ---------------------------------------------------------------- marco
func render() -> void:
	UI.clear_children(self)
	add_child(_stepper())
	# El cuerpo ocupa el alto disponible; el pie con «Atrás / Siguiente» queda siempre fijo y visible.
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(sc)
	_body = UI.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	match step:
		"party": _build_party()
		"identity": _build_identity()
		"ideology": _build_ideology()
		"character": _build_character()
		"summary": _build_summary()
	_build_nav()

## Barra superior del asistente: título y pasos numerados (los pasos ya hechos permiten volver).
func _stepper() -> Control:
	var band := PanelContainer.new()
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 16, 8))
	var row := UI.hbox(10)
	band.add_child(row)
	var t := UI.vbox(0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_child(UI.eyebrow("NUEVA PARTIDA", UI.D4_BLUE_D))
	t.add_child(UI.label(str(STEP_TITLES[step]), UI.FS_H2, UI.NAVY, true))
	row.add_child(t)
	row.add_child(UI.fill())
	var steps := _steps()
	var cur := steps.find(step)
	for i in range(steps.size()):
		var sid := str(steps[i])
		var done := i < cur
		var label := "%s  %s" % ["✓" if done else str(i + 1), str(STEP_NAMES[sid])]
		var jump := func() -> void:
			step = sid
			render()
		var b := UI.pill(label, i == cur, jump, false, UI.PILL_GO if done else UI.PILL)
		b.disabled = i > cur
		b.custom_minimum_size = Vector2(150, 36)
		row.add_child(b)
		if i < steps.size() - 1:
			var sep := UI.label("›", 22, UI.FAINT, true)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(sep)
	return band

func _rebuild_body() -> void:
	UI.clear_children(_body)
	match step:
		"party": _build_party()
		"identity": _build_identity()
		"ideology": _build_ideology()
		"character": _build_character()
		"summary": _build_summary()
	_refresh_nav()

## Recalcula el botón «Siguiente» y el aviso según el estado actual (se llama al escribir y al cambiar cualquier opción).
func _refresh_nav() -> void:
	if _nav_next == null or not is_instance_valid(_nav_next):
		return
	var problem := _problem()
	_nav_next.disabled = problem != ""
	if _nav_problem != null and is_instance_valid(_nav_problem):
		_nav_problem.text = problem
		_nav_problem.visible = problem != ""

func _build_nav() -> void:
	var band := PanelContainer.new()
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 16, 8))
	add_child(band)
	var row := UI.hbox(12)
	band.add_child(row)
	var steps := _steps()
	var idx := steps.find(step)
	var grey := Color("#8E9BB0")
	var back: Button
	if idx == 0:
		back = UI.pill("‹  Volver al menú", false, func() -> void: cancelled.emit(), true, grey)
	else:
		var go_back := func() -> void:
			step = str(steps[idx - 1])
			render()
		back = UI.pill("‹  Atrás", false, go_back, true, grey)
	back.custom_minimum_size = Vector2(190, 44)
	row.add_child(back)
	row.add_child(UI.fill())
	var problem := _problem()
	var pl := UI.label(problem, UI.FS_BODY, UI.WARN, true)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pl.visible = problem != ""
	row.add_child(pl)
	_nav_problem = pl
	_nav_next = null
	if step == "summary":
		var go := UI.pill("EMPEZAR LA CAMPAÑA  ›", false, func() -> void: finished.emit(build_party()), true, UI.PILL_GO)
		go.custom_minimum_size = Vector2(290, 44)
		row.add_child(go)
	else:
		var go_next := func() -> void:
			step = str(steps[idx + 1])
			render()
		var nb := UI.pill("SIGUIENTE  ›", false, go_next, true, UI.PILL_GO)
		nb.custom_minimum_size = Vector2(210, 44)
		nb.disabled = problem != ""
		row.add_child(nb)
		_nav_next = nb

func _problem() -> String:
	match step:
		"identity":
			if str(custom["name"]).strip_edges() == "" or str(custom["short"]).strip_edges() == "":
				return "Pon nombre y siglas al partido."
		"ideology":
			if (custom["picks"] as Array).is_empty():
				return "Añade al menos una ideología."
			if Ideology.is_territorial(_picks()) and str(custom.get("territory", "")) == "":
				return "Elige la comunidad autónoma donde te presentas."
		"character":
			if Leader.full_name(hero) == "" or str(hero["name"]).strip_edges() == "" or str(hero["surname"]).strip_edges() == "":
				return "Dale nombre y apellidos a tu personaje."
			if Leader.points_spent(hero["stats"]) < Leader.STAT_POINTS:
				return "Te quedan %d puntos de atributos por repartir." % (Leader.STAT_POINTS - Leader.points_spent(hero["stats"]))
	return ""

# ---------------------------------------------------------------- utilidades
func _parties() -> Array:
	var list := DataStore.parties()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(Rules.BASE_POLL.get(str(a["id"]), 0.0)) > float(Rules.BASE_POLL.get(str(b["id"]), 0.0)))
	return list

func _party(id: String) -> Dictionary:
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == id:
			return p
	return {}

func _difficulty(poll: float) -> String:
	if poll >= 25.0: return "Favorito"
	if poll >= 10.0: return "Competitivo"
	if poll >= 2.0: return "Partido bisagra"
	return "Reto extremo"

func _diff_color(poll: float) -> Color:
	if poll >= 25.0: return UI.GOOD
	if poll >= 10.0: return UI.ACCENT
	if poll >= 2.0: return UI.WARN
	return UI.BAD

func _compat_label(c: float) -> String:
	if c >= 0.72: return "Muy afines"
	if c >= 0.5: return "Compatibles"
	if c >= 0.32: return "Distantes"
	if c >= 0.16: return "Opuestos"
	return "Incompatibles"

func _compat_color(c: float) -> Color:
	if c >= 0.5: return UI.GOOD
	if c >= 0.32: return UI.WARN
	return UI.BAD

func _emblem(color: Color, text: String, motif: String, px: float) -> PartyEmblem:
	var em := PartyEmblem.new()
	em.custom_minimum_size = Vector2(px, px)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	em.set_identity(color, text.substr(0, 3), motif)
	return em

func _pips(value: int, max_v: int, on_set: Callable, color: Color = UI.D4_BLUE) -> HBoxContainer:
	var row := UI.hbox(3)
	for i in range(1, max_v + 1):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(22, 22)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var on := i <= value
		b.add_theme_stylebox_override("normal", UI.box(color if on else UI.PANEL3, color.darkened(0.1) if on else UI.D4_LINE, 3, 1, 0, 0))
		b.add_theme_stylebox_override("hover", UI.box(color.lightened(0.2) if on else Color("#D6DEEB"), color, 3, 1, 0, 0))
		b.add_theme_stylebox_override("pressed", UI.box(color, color, 3, 1, 0, 0))
		b.pressed.connect(func() -> void: on_set.call(i))
		row.add_child(b)
	return row

func _arrows(text: String, on_prev: Callable, on_next: Callable, compact: bool = false) -> HBoxContainer:
	var row := UI.hbox(4 if compact else 6)
	var pb := UI.pill("‹", false, on_prev, false, UI.PILL_SUB)
	pb.custom_minimum_size = Vector2(32, 30)
	var nb := UI.pill("›", false, on_next, false, UI.PILL_SUB)
	nb.custom_minimum_size = Vector2(32, 30)
	var l := UI.label(text, UI.FS_SMALL if compact else UI.FS_BODY, UI.TEXT, true)
	l.custom_minimum_size = Vector2(80, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pb)
	row.add_child(l)
	row.add_child(nb)
	return row

func _swatches(colors: Array, current: String, on_pick: Callable) -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for i in range(colors.size()):
		var hexc := str(colors[i])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(28, 28)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var on := hexc.to_lower() == current.to_lower()
		b.add_theme_stylebox_override("normal", UI.box(Color(hexc), UI.TEXT if on else Color(1, 1, 1, 0.0), 14, 2 if on else 0, 0, 0))
		b.add_theme_stylebox_override("hover", UI.box(Color(hexc).lightened(0.12), UI.ACCENT, 14, 2, 0, 0))
		b.add_theme_stylebox_override("pressed", UI.box(Color(hexc), UI.TEXT, 14, 2, 0, 0))
		b.pressed.connect(func() -> void: on_pick.call(i, hexc))
		fl.add_child(b)
	return fl

func _text_field(value: String, placeholder: String, max_len: int, on_change: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void:
		on_change.call(t)
		_refresh_nav())
	return e

func _field_label(t: String) -> Label:
	return UI.label(t.to_upper(), UI.FS_TINY, UI.MUTED, true)

# ---------------------------------------------------------------- paso 1: partido
var party_filter := "all"

func _is_territorial_party(id: String) -> bool:
	return Rules.REGIONALIST_TERRITORY.has(id)

func _build_party() -> void:
	var split := UI.hbox(16)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	var right := UI.vbox(8)
	right.custom_minimum_size = Vector2(600, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	split.add_child(right)
	var top := UI.hbox(8)
	var intro := UI.label("Pulsa un partido para ver su ficha. Las encuestas de partida son ficticias.", UI.FS_BODY, UI.MUTED)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro.clip_text = true
	top.add_child(intro)
	for f in [["all", "Todos"], ["state", "Estatales"], ["regional", "Territoriales"]]:
		var fid := str(f[0])
		var set_filter := func() -> void:
			party_filter = fid
			render()
		var pill := UI.pill(str(f[1]), party_filter == fid, set_filter, false)
		pill.custom_minimum_size = Vector2(118, 32)
		top.add_child(pill)
	left.add_child(top)
	var grid := UI.grid(4, 10, 10)
	left.add_child(grid)
	for p in _parties():
		var pd: Dictionary = p
		var terr := _is_territorial_party(str(pd["id"]))
		if party_filter == "state" and terr:
			continue
		if party_filter == "regional" and not terr:
			continue
		grid.add_child(_party_card(pd))
	grid.add_child(_create_card())
	if mode == "existing":
		_party_detail(right)
	else:
		_custom_intro(right)

func _custom_intro(parent: Control) -> void:
	var c := UI.card(parent, "Partido propio", "Empiezas desde cero", UI.PILL_WARN)
	c.add_child(UI.wrap_label("Creas un proyecto nuevo: poca notoriedad, pocos recursos y todo por ganar. De tu identidad e ideología saldrá con quién podrás pactar y con quién no.", UI.FS_BODY, UI.MUTED))
	for it in [["1", "Identidad", "Nombre, siglas, color y símbolo."], ["2", "Ideología", "Mezcla de ideologías con su fuerza; se calcula tu posición."], ["3", "Personaje", "Tu líder: aspecto, trayectoria, rasgo y atributos."]]:
		var row := UI.hbox(12)
		var n := PanelContainer.new()
		n.custom_minimum_size = Vector2(30, 30)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.add_theme_stylebox_override("panel", UI.box(UI.D4_BLUE, UI.D4_BLUE_L, 15, 1, 0, 0))
		var nl := UI.label(str(it[0]), UI.FS_BODY, Color.WHITE, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_child(nl)
		row.add_child(n)
		var t := UI.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UI.label(str(it[1]), UI.FS_LEAD, UI.TEXT, true))
		t.add_child(UI.label(str(it[2]), UI.FS_SMALL, UI.MUTED))
		row.add_child(t)
		c.add_child(row)
	c.add_child(UI.hsep())
	c.add_child(UI.wrap_label("Si eliges una ideología territorial (regionalismo, independentismo…) solo te presentarás en una comunidad autónoma.", UI.FS_SMALL, UI.MUTED))

func _party_card(p: Dictionary) -> Control:
	var id := str(p["id"])
	var poll := float(Rules.BASE_POLL.get(id, 0.5))
	var active := mode == "existing" and party_id == id
	var col := Color(str(p["color"]))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 164)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL.lerp(col, 0.07) if active else UI.PANEL, UI.PILL_ACTIVE if active else UI.D4_LINE, 4, 3 if active else 1, 0, 0, active))
	b.add_theme_stylebox_override("hover", UI.box(UI.PANEL.lerp(col, 0.05), UI.D4_BLUE, 4, 2, 0, 0, true))
	b.add_theme_stylebox_override("pressed", UI.box(UI.PANEL.lerp(col, 0.10), UI.PILL_ACTIVE, 4, 3, 0, 0))
	b.pressed.connect(func() -> void:
		mode = "existing"
		party_id = id
		render())
	var stripe := ColorRect.new()
	stripe.color = col
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 7
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(stripe)
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 18
	inner.offset_top = 10
	inner.offset_right = -12
	inner.offset_bottom = -10
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UI.hbox(10)
	head.add_child(_emblem(col, str(p.get("short_name", id)), UI.motif_for(id), 54))
	var t := UI.vbox(0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UI.label(str(p["short_name"]), UI.FS_H2, UI.TEXT, true)
	nl.clip_text = true
	t.add_child(nl)
	var bl := UI.label(Ideology.bloc_name(p["ideology"], p["ideology_profile"]), UI.FS_SMALL, UI.MUTED)
	bl.clip_text = true
	bl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_child(bl)
	head.add_child(t)
	inner.add_child(head)
	var names: Array = []
	for pk in Ideology.infer_picks(p, 2):
		names.append(Ideology.name_of(str((pk as Dictionary)["id"])))
	var il := UI.label(" · ".join(names), UI.FS_SMALL, UI.FAINT)
	il.clip_text = true
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(il)
	inner.add_child(UI.fill())
	if _is_territorial_party(id):
		var tl := UI.label("Solo en " + _territory_text(id), UI.FS_SMALL, UI.WARN, true)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		inner.add_child(tl)
	var foot := UI.hbox(8)
	var pl := UI.label("%.1f %%" % poll, 24, UI.TEXT, true)
	foot.add_child(pl)
	foot.add_child(UI.fill())
	var dl := UI.label(_difficulty(poll).to_upper(), UI.FS_TINY, _diff_color(poll), true)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(dl)
	inner.add_child(foot)
	b.add_child(inner)
	_mouse_pass(inner)
	return b

func _mouse_pass(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c is Button):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mouse_pass(c)

func _create_card() -> Control:
	var active := mode == "custom"
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 164)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL.lerp(UI.PILL_ACTIVE, 0.07) if active else Color(1, 1, 1, 0.55), UI.PILL_ACTIVE if active else UI.D4_BLUE, 4, 3 if active else 2, 0, 0, active))
	b.add_theme_stylebox_override("hover", UI.box(Color.WHITE, UI.D4_BLUE_D, 4, 2, 0, 0, true))
	b.add_theme_stylebox_override("pressed", UI.box(UI.PANEL.lerp(UI.PILL_ACTIVE, 0.12), UI.PILL_ACTIVE, 4, 3, 0, 0))
	b.pressed.connect(func() -> void:
		mode = "custom"
		render())
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plus := UI.label("+", 40, UI.D4_BLUE, true)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(plus)
	var l := UI.label("CREAR PARTIDO PROPIO", UI.FS_BODY, UI.NAVY, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(l)
	var l2 := UI.label("Identidad, ideología y líder", UI.FS_SMALL, UI.MUTED)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(l2)
	b.add_child(inner)
	_mouse_pass(inner)
	return b

func _territory_text(id: String) -> String:
	var t: Dictionary = Rules.REGIONALIST_TERRITORY.get(id, {})
	return ", ".join(t.get("communities", []))

func _challenge_text(poll: float, id: String) -> String:
	var t := ""
	if poll >= 25.0:
		t = "Partes como favorito: el reto es ganar sin desgastarte y cerrar una investidura estable. Todos los focos estarán sobre ti."
	elif poll >= 10.0:
		t = "Partido competitivo: puedes dar la sorpresa, pero necesitarás pactos para gobernar. Cada punto de encuesta cuenta."
	elif poll >= 2.0:
		t = "Partido bisagra: tu poder está en decidir investiduras y leyes. Negocia caro y cuida tu identidad."
	else:
		t = "Reto extremo: sobrevivir, entrar en el Congreso y hacerte imprescindible con muy pocos recursos."
	if _is_territorial_party(id):
		t += " Solo te presentas en " + _territory_text(id) + ", así que tu voto se concentra en pocas circunscripciones."
	return t

func _party_detail(parent: Control) -> void:
	var p := _party(party_id)
	if p.is_empty():
		return
	var col := Color(str(p["color"]))
	var poll := float(Rules.BASE_POLL.get(party_id, 0.5))
	var c := UI.card(parent, "Ficha del partido", "", col)
	var top := UI.hbox(16)
	top.add_child(_emblem(col, str(p.get("short_name", party_id)), UI.motif_for(party_id), 92))
	var nm := UI.vbox(2)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.add_child(UI.label(str(p["name"]), UI.FS_H1, UI.NAVY, true))
	nm.add_child(UI.label(Ideology.bloc_name(p["ideology"], p["ideology_profile"]), UI.FS_LEAD, UI.MUTED))
	var tags := UI.hbox(6)
	if _is_territorial_party(party_id):
		tags.add_child(UI.chip("Solo en " + _territory_text(party_id), UI.WARN, true))
	else:
		tags.add_child(UI.chip("Ámbito estatal", UI.D4_BLUE_D, true))
	nm.add_child(tags)
	top.add_child(nm)
	c.add_child(top)
	c.add_child(UI.wrap_label(str(p.get("description", "")), UI.FS_BODY, UI.MUTED))
	var kr := UI.hbox(10)
	c.add_child(kr)
	UI.kpi(kr, "Intención de voto", "%.1f %%" % poll, "encuesta de partida", UI.D4_BLUE_D)
	UI.kpi(kr, "Dificultad", _difficulty(poll), "", _diff_color(poll))
	c.add_child(_field_label("Ideologías principales"))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for pk in Ideology.infer_picks(p, 5):
		fl.add_child(UI.chip("%s %s" % [Ideology.name_of(str((pk as Dictionary)["id"])), "●".repeat(int((pk as Dictionary)["strength"]))], col.darkened(0.15)))
	c.add_child(fl)
	var axes: Dictionary = p["ideology"]
	c.add_child(AxisBar.new(float(axes["economic"]), "Izquierda", "Derecha"))
	c.add_child(AxisBar.new(float(axes["social"]), "Progresista", "Conservador"))
	c.add_child(AxisBar.new(float(axes["territorial"]), "Centralista", "Descentralizador"))
	var rows: Array = []
	for o in DataStore.parties():
		var od: Dictionary = o
		if str(od["id"]) == party_id:
			continue
		rows.append({"id": str(od["id"]), "name": str(od.get("short_name", od["id"])), "color": str(od.get("color", "#888")), "compat": Ideology.compat(p, od)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["compat"]) > float(b["compat"]))
	var cols := UI.hbox(18)
	c.add_child(cols)
	var l := UI.vbox(5)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_child(_field_label("Con quién podrás pactar"))
	for it in rows.slice(0, 3):
		l.add_child(_compat_row(it as Dictionary))
	cols.add_child(l)
	var r := UI.vbox(5)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(_field_label("Incompatibles"))
	for it in rows.slice(rows.size() - 3, rows.size()):
		r.add_child(_compat_row(it as Dictionary))
	cols.add_child(r)
	var rc := UI.card(parent, "Tu reto", "", _diff_color(poll))
	rc.add_child(UI.wrap_label(_challenge_text(poll, party_id), UI.FS_BODY, UI.TEXT))

func _compat_row(it: Dictionary) -> Control:
	var row := UI.hbox(8)
	var sw := ColorRect.new()
	sw.color = Color(str(it["color"]))
	sw.custom_minimum_size = Vector2(5, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	var n := UI.label(str(it["name"]), UI.FS_BODY, UI.TEXT, true)
	n.custom_minimum_size = Vector2(76, 0)
	n.clip_text = true
	row.add_child(n)
	var c := float(it["compat"])
	var m := UI.meter(c, 1.0, _compat_color(c), 6)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(m)
	var tl := UI.label(_compat_label(c), UI.FS_SMALL, _compat_color(c), true)
	tl.custom_minimum_size = Vector2(84, 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(tl)
	return row

# ---------------------------------------------------------------- paso 2: identidad (partido propio)
func _build_identity() -> void:
	var main := UI.hbox(16)
	_body.add_child(main)
	var c := UI.card(main, "Identidad del partido", "Nombre, siglas, color y símbolo", UI.D4_BLUE_L)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(c.get_parent().get_parent().get_parent() as Control).size_flags_stretch_ratio = 1.3
	var poster_holder := UI.vbox(0)
	var update_preview := func() -> void:
		UI.clear_children(poster_holder)
		_poster(poster_holder)
	c.add_child(_field_label("Nombre del partido"))
	c.add_child(_text_field(str(custom["name"]), "Ej.: Nuevo Impulso Ciudadano", 40, func(t: String) -> void:
		custom["name"] = t
		update_preview.call()))
	var row := UI.hbox(12)
	var c1 := UI.vbox(4)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_child(_field_label("Siglas"))
	c1.add_child(_text_field(str(custom["short"]), "NIC", 8, func(t: String) -> void:
		custom["short"] = t
		update_preview.call()))
	row.add_child(c1)
	var c2 := UI.vbox(4)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.size_flags_stretch_ratio = 2.0
	c2.add_child(_field_label("Lema"))
	c2.add_child(_text_field(str(custom["motto"]), "Una frase que te defina", 60, func(t: String) -> void:
		custom["motto"] = t
		update_preview.call()))
	row.add_child(c2)
	c.add_child(row)
	c.add_child(UI.spacer(14))
	c.add_child(_field_label("Color"))
	c.add_child(_swatches(PALETTE, str(custom["color"]), func(_i: int, hexc: String) -> void:
		custom["color"] = hexc
		_rebuild_swatch_state()))
	c.add_child(UI.spacer(14))
	c.add_child(_field_label("Símbolo"))
	var mrow := UI.hbox(10)
	for mt in MOTIFS:
		var motif := str(mt)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(72, 72)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var on := motif == str(custom["motif"])
		b.add_theme_stylebox_override("normal", UI.box(UI.PANEL.lerp(UI.PILL_ACTIVE, 0.10) if on else UI.PANEL2, UI.PILL_ACTIVE if on else UI.D4_LINE, 4, 3 if on else 1, 0, 0))
		b.add_theme_stylebox_override("hover", UI.box(Color.WHITE, UI.D4_BLUE, 4, 2, 0, 0))
		b.pressed.connect(func() -> void:
			custom["motif"] = motif
			_rebuild_body())
		var em := _emblem(Color(str(custom["color"])), str(custom["short"]), motif, 52)
		em.position = Vector2(10, 10)
		em.size = Vector2(52, 52)
		em.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(em)
		mrow.add_child(b)
	c.add_child(mrow)
	var pv := UI.card(main, "Vista previa", "Así te verá el país", UI.PILL_WARN)
	(pv.get_parent().get_parent().get_parent() as Control).size_flags_stretch_ratio = 1.0
	pv.add_child(poster_holder)
	update_preview.call()

## Cartel del partido: fondo de color, emblema, siglas, nombre y lema.
func _poster(parent: Control) -> void:
	var col := Color(str(custom["color"]))
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(0, 520)
	pc.add_theme_stylebox_override("panel", UI.box(col.darkened(0.25), col.lightened(0.2), 6, 2, 28, 24, true))
	parent.add_child(pc)
	var v := UI.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(v)
	var em := _emblem(col.lightened(0.1), str(custom["short"]), str(custom["motif"]), 170)
	em.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(em)
	var sh := UI.label(str(custom["short"]).strip_edges().to_upper(), 64, Color.WHITE, true)
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sh)
	var nm := UI.label(str(custom["name"]), UI.FS_LEAD, Color(1, 1, 1, 0.9), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	v.add_child(nm)
	if str(custom["motto"]).strip_edges() != "":
		var mo := UI.label("«%s»" % str(custom["motto"]), UI.FS_BODY, Color(1, 1, 1, 0.75))
		mo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mo.clip_text = true
		v.add_child(mo)

func _rebuild_swatch_state() -> void:
	_rebuild_body()

# ---------------------------------------------------------------- paso 3: ideología
func _picks() -> Array:
	return custom["picks"]

func _pick_strength(id: String) -> int:
	for p in _picks():
		if str((p as Dictionary)["id"]) == id:
			return int((p as Dictionary)["strength"])
	return 0

func _set_strength(id: String, value: int) -> void:
	var picks := _picks()
	var used := Ideology.points_used(picks)
	for p in picks:
		var d: Dictionary = p
		if str(d["id"]) == id:
			var room := Ideology.BUDGET - (used - int(d["strength"]))
			d["strength"] = clampi(value, 1, mini(Ideology.MAX_STRENGTH, room))
	_rebuild_body()

func _add_pick(id: String) -> void:
	var picks := _picks()
	if picks.size() >= Ideology.MAX_PICKS or Ideology.points_used(picks) >= Ideology.BUDGET or _pick_strength(id) > 0:
		return
	picks.append({"id": id, "strength": mini(3, Ideology.BUDGET - Ideology.points_used(picks))})
	Sfx.play("click")
	_rebuild_body()

func _remove_pick(id: String) -> void:
	var picks := _picks()
	for i in range(picks.size()):
		if str((picks[i] as Dictionary)["id"]) == id:
			picks.remove_at(i)
			break
	_rebuild_body()

func _build_ideology() -> void:
	_body.add_child(UI.wrap_label("Elige las ideologías que definen tu proyecto y dales fuerza. Tienes %d puntos y hasta %d ideologías. De esta mezcla saldrá tu posición política: los partidos de la IA son fieles a la suya y no pactarán con quien se les oponga." % [Ideology.BUDGET, Ideology.MAX_PICKS], UI.FS_BODY, UI.MUTED))
	var cols := UI.hbox(14)
	_body.add_child(cols)
	# columna izquierda: catálogo
	var left := UI.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	cols.add_child(left)
	var cat := UI.card(left, "Ideologías disponibles", "Pulsa para añadir", UI.ACCENT)
	_hint = UI.wrap_label("Pasa el ratón sobre una ideología para ver qué defiende.", UI.FS_BODY, UI.MUTED)
	_hint.custom_minimum_size = Vector2(0, 48)
	for g in Ideology.groups():
		cat.add_child(_field_label(str(g)))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		for it in Ideology.CATALOG:
			var d: Dictionary = it
			if str(d["group"]) != str(g):
				continue
			var id := str(d["id"])
			var taken := _pick_strength(id) > 0
			var full := _picks().size() >= Ideology.MAX_PICKS or Ideology.points_used(_picks()) >= Ideology.BUDGET
			var add_it := func() -> void: _add_pick(id)
			var b := UI.pill(str(d["name"]), taken, add_it, true)
			b.add_theme_font_size_override("font_size", UI.FS_BODY)
			b.custom_minimum_size = Vector2(0, 42)
			b.disabled = full and not taken
			b.mouse_entered.connect(func() -> void:
				if _hint != null:
					_hint.text = "%s: %s" % [str(d["name"]), str(d["desc"])])
			fl.add_child(b)
		cat.add_child(fl)
	cat.add_child(_hint)
	if Ideology.is_territorial(_picks()):
		_territory_card(left)
	# columna derecha: tu ideología + análisis
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var used := Ideology.points_used(_picks())
	var mine := UI.card(right, "Tu ideología", "%d / %d puntos" % [used, Ideology.BUDGET], UI.GOOD)
	mine.add_child(UI.meter(float(used), float(Ideology.BUDGET), UI.GOOD if used < Ideology.BUDGET else UI.WARN, 6))
	if _picks().is_empty():
		mine.add_child(UI.wrap_label("Todavía no has añadido ninguna ideología.", UI.FS_BODY, UI.FAINT))
	for p in _picks():
		var d: Dictionary = p
		var id := str(d["id"])
		var row := UI.hbox(8)
		var nm := UI.label(Ideology.name_of(id), UI.FS_BODY, UI.TEXT, true)
		nm.custom_minimum_size = Vector2(160, 0)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		row.add_child(_pips(int(d["strength"]), Ideology.MAX_STRENGTH, func(v: int) -> void: _set_strength(id, v)))
		row.add_child(UI.fill())
		var rm_it := func() -> void: _remove_pick(id)
		var rm := UI.pill("✕", false, rm_it, false, Color("#8E9BB0"))
		rm.custom_minimum_size = Vector2(38, 30)
		row.add_child(rm)
		mine.add_child(row)
	var comp := Ideology.compose(_picks())
	_analysis_card(right, comp)

func _community_names() -> Array:
	var out: Array = []
	for c in DataStore.constituencies():
		var cn := str((c as Dictionary).get("autonomous_community", ""))
		if cn != "" and not out.has(cn):
			out.append(cn)
	out.sort()
	return out

## Los partidos regionalistas e independentistas empiezan presentándose en una sola comunidad.
func _territory_card(parent: Node) -> void:
	var c := UI.card(parent, "Ámbito territorial", "Obligatorio", UI.WARN)
	c.add_child(UI.wrap_label("Tu proyecto es territorial: al principio solo presentarás candidaturas en UNA comunidad autónoma. Más adelante podrás pagar para extenderte a otras.", UI.FS_SMALL, UI.MUTED))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for cn in _community_names():
		var cname := str(cn)
		var chosen := str(custom.get("territory", "")) == cname
		var pick_c := func() -> void:
			custom["territory"] = cname
			_rebuild_body()
		var b := UI.pill(cname, chosen, pick_c, false)
		b.custom_minimum_size = Vector2(0, 32)
		fl.add_child(b)
	c.add_child(fl)

func _analysis_card(parent: Node, comp: Dictionary) -> void:
	var c := UI.card(parent, "Qué significa", "", UI.WARN)
	if (comp["picks"] as Array).is_empty():
		c.add_child(UI.wrap_label("Añade ideologías para ver tu posición y tus afinidades.", UI.FS_BODY, UI.FAINT))
		return
	c.add_child(UI.label(str(comp["bloc"]), UI.FS_H2, UI.TEXT, true))
	var axes: Dictionary = comp["axes"]
	c.add_child(AxisBar.new(float(axes["economic"]), "Izquierda", "Derecha"))
	c.add_child(AxisBar.new(float(axes["social"]), "Progresista", "Conservador"))
	c.add_child(AxisBar.new(float(axes["territorial"]), "Centralista", "Descentralizador"))
	var coh := float(comp["coherence"])
	var crow := UI.hbox(8)
	crow.add_child(UI.label("Coherencia interna", UI.FS_SMALL, UI.MUTED, true))
	var cm := UI.meter(coh, 1.0, UI.GOOD if coh >= 0.8 else (UI.WARN if coh >= 0.55 else UI.BAD), 6)
	cm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(cm)
	crow.add_child(UI.label("%d%%" % int(round(coh * 100.0)), UI.FS_SMALL, UI.TEXT, true))
	c.add_child(crow)
	for cf in comp["conflicts"]:
		c.add_child(UI.wrap_label("Tensión: %s. Se nota en tu credibilidad inicial." % str((cf as Dictionary)["text"]), UI.FS_SMALL, UI.WARN))
	c.add_child(UI.hsep())
	var prev: Array = Ideology.preview(comp)
	var two := UI.hbox(18)
	c.add_child(two)
	var best := UI.vbox(5)
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.add_child(_field_label("Más afines"))
	for it in prev.slice(0, 4):
		best.add_child(_compat_row(it as Dictionary))
	two.add_child(best)
	var worst := UI.vbox(5)
	worst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worst.add_child(_field_label("Más opuestos"))
	for it in prev.slice(maxi(0, prev.size() - 4), prev.size()):
		worst.add_child(_compat_row(it as Dictionary))
	two.add_child(worst)

# ---------------------------------------------------------------- paso 4: personaje
const APPEARANCE := [
	["face", "Cara", "FACE_SHAPES"], ["eyes", "Ojos", "EYES"], ["brows", "Cejas", "BROWS"], ["nose", "Nariz", "NOSES"],
	["mouth", "Boca", "MOUTHS"], ["facial", "Vello facial", "FACIAL"], ["glasses", "Gafas", "GLASSES"], ["outfit", "Atuendo", "OUTFITS"],
	["feature", "Rasgo exagerado", "FEATURES"],
]

func _options_of(const_name: String) -> Array:
	match const_name:
		"FACE_SHAPES": return Leader.FACE_SHAPES
		"EYES": return Leader.EYES
		"BROWS": return Leader.BROWS
		"NOSES": return Leader.NOSES
		"MOUTHS": return Leader.MOUTHS
		"FACIAL": return Leader.FACIAL
		"GLASSES": return Leader.GLASSES
		"OUTFITS": return Leader.OUTFITS
		"FEATURES": return Leader.FEATURES
	return []

func _party_color_now() -> Color:
	if mode == "custom":
		return Color(str(custom["color"]))
	var p := _party(party_id)
	return Color(str(p.get("color", "#2563EB")))

func _build_character() -> void:
	_body.add_child(UI.wrap_label("Crea al personaje que dirigirá el partido y se presentará a las elecciones. Es una caricatura: más adelante podrás sustituirla por tus propias imágenes.", UI.FS_BODY, UI.MUTED))
	var cols := UI.hbox(14)
	_body.add_child(cols)
	# --- izquierda: retrato y aspecto
	var left := UI.vbox(12)
	left.custom_minimum_size = Vector2(470, 0)
	cols.add_child(left)
	var pc := UI.card(left, "Aspecto", "", UI.ACCENT)
	var portrait := LeaderPortrait.new()
	portrait.custom_minimum_size = Vector2(210, 210)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.setup(hero, _party_color_now(), mood)
	pc.add_child(portrait)
	var moods := UI.hbox(6)
	moods.alignment = BoxContainer.ALIGNMENT_CENTER
	for mp in [["neutral", "Serio"], ["happy", "Alegre"], ["angry", "Enfadado"], ["smug", "Chulo"], ["worried", "Agobiado"]]:
		var mk := str(mp[0])
		var set_mood := func() -> void:
			mood = mk
			portrait.set_mood(mk)
			_rebuild_body()
		var mb := UI.pill(str(mp[1]), mk == mood, set_mood, false)
		mb.custom_minimum_size = Vector2(0, 30)
		mb.add_theme_font_size_override("font_size", UI.FS_SMALL)
		moods.add_child(mb)
	pc.add_child(moods)
	var rnd_look := func() -> void:
		hero["appearance"] = Leader.randomize_appearance(_rng, str(hero["gender"]))
		_rebuild_body()
	pc.add_child(UI.pill("ASPECTO ALEATORIO", false, rnd_look, false, UI.PILL_SUB))
	var ap := hero["appearance"] as Dictionary
	pc.add_child(_field_label("Piel"))
	pc.add_child(_swatches(Leader.SKIN, str(Leader.SKIN[int(ap["skin"])]), func(i: int, _h: String) -> void:
		ap["skin"] = i
		_rebuild_body()))
	pc.add_child(_field_label("Pelo"))
	pc.add_child(_arrows(str(Leader.HAIR_STYLES[int(ap["hair"])]), func() -> void:
		ap["hair"] = (int(ap["hair"]) + Leader.HAIR_STYLES.size() - 1) % Leader.HAIR_STYLES.size()
		_rebuild_body(), func() -> void:
		ap["hair"] = (int(ap["hair"]) + 1) % Leader.HAIR_STYLES.size()
		_rebuild_body()))
	pc.add_child(_swatches(Leader.HAIR_COLOR, str(Leader.HAIR_COLOR[int(ap["hair_color"])]), func(i: int, _h: String) -> void:
		ap["hair_color"] = i
		_rebuild_body()))
	var agrid := UI.grid(2, 10, 4)
	pc.add_child(agrid)
	for item in APPEARANCE:
		var key := str(item[0])
		var opts := _options_of(str(item[2]))
		var cell := UI.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(_field_label(str(item[1])))
		cell.add_child(_arrows(str(opts[int(ap[key])]), func() -> void:
			ap[key] = (int(ap[key]) + opts.size() - 1) % opts.size()
			_rebuild_body(), func() -> void:
			ap[key] = (int(ap[key]) + 1) % opts.size()
			_rebuild_body(), true))
		agrid.add_child(cell)
	var ecell := UI.vbox(2)
	ecell.add_child(_field_label("Edad aparente"))
	ecell.add_child(_pips(int(round(float(ap["age_look"]) * 5.0)) + 0, 5, func(v: int) -> void:
		ap["age_look"] = float(v) / 5.0
		_rebuild_body()))
	agrid.add_child(ecell)
	# --- derecha: datos, trayectoria, rasgo, atributos
	var mid := UI.vbox(12)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var idc := UI.card(mid, "Quién eres", "", UI.GOOD)
	var nrow := UI.hbox(10)
	var n1 := UI.vbox(4)
	n1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n1.add_child(_field_label("Nombre"))
	n1.add_child(_text_field(str(hero["name"]), "Nombre", 20, func(t: String) -> void:
		hero["name"] = t))
	nrow.add_child(n1)
	var n2 := UI.vbox(4)
	n2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n2.add_child(_field_label("Apellidos"))
	n2.add_child(_text_field(str(hero["surname"]), "Apellidos", 30, func(t: String) -> void:
		hero["surname"] = t))
	nrow.add_child(n2)
	idc.add_child(nrow)
	var grow := UI.hbox(14)
	var gcol := UI.vbox(4)
	gcol.add_child(_field_label("Género"))
	var gb := UI.hbox(6)
	for gp in [["f", "Mujer"], ["m", "Hombre"], ["x", "Otro"]]:
		var gk := str(gp[0])
		var set_gender := func() -> void:
			hero["gender"] = gk
			_rebuild_body()
		gb.add_child(UI.pill(str(gp[1]), str(hero["gender"]) == gk, set_gender, false))
	gcol.add_child(gb)
	grow.add_child(gcol)
	var acol := UI.vbox(4)
	acol.add_child(_field_label("Edad"))
	acol.add_child(_arrows("%d años" % int(hero["age"]), func() -> void:
		hero["age"] = maxi(30, int(hero["age"]) - 1)
		_rebuild_body(), func() -> void:
		hero["age"] = mini(75, int(hero["age"]) + 1)
		_rebuild_body()))
	grow.add_child(acol)
	idc.add_child(grow)
	var roll_name := func() -> void:
		var r := Leader.random_player(_rng)
		hero["name"] = r["name"]
		hero["surname"] = r["surname"]
		hero["gender"] = r["gender"]
		_rebuild_body()
	idc.add_child(UI.pill("SORTEAR NOMBRE", false, roll_name, false, UI.PILL_SUB))
	var bc := UI.card(mid, "Trayectoria", "Tu oficio antes de la política", UI.WARN)
	var bg := UI.grid(2, 8, 8)
	bc.add_child(bg)
	for b in Leader.BACKGROUNDS:
		var bd: Dictionary = b
		var on := str(hero["background"]) == str(bd["id"])
		var set_bg := func() -> void:
			hero["background"] = str(bd["id"])
			_rebuild_body()
		var btn := UI.pill(str(bd["name"]), on, set_bg, false)
		btn.tooltip_text = str(bd["desc"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg.add_child(btn)
	bc.add_child(UI.wrap_label(str(Leader.background_by_id(str(hero["background"])).get("desc", "")), UI.FS_SMALL, UI.MUTED))
	var pk := UI.card(right, "Rasgo vital", "Lo que te distingue", UI.ACCENT)
	var pg := UI.grid(2, 8, 8)
	pk.add_child(pg)
	for p in Leader.PERKS:
		var pd: Dictionary = p
		var on2 := str(hero["perk"]) == str(pd["id"])
		var set_perk := func() -> void:
			hero["perk"] = str(pd["id"])
			_rebuild_body()
		var pb := UI.pill(str(pd["name"]), on2, set_perk, false)
		pb.tooltip_text = str(pd["desc"])
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pg.add_child(pb)
	pk.add_child(UI.wrap_label(str(Leader.perk_by_id(str(hero["perk"])).get("desc", "")), UI.FS_SMALL, UI.MUTED))
	var sc := UI.card(right, "Atributos", "%d puntos por repartir" % (Leader.STAT_POINTS - Leader.points_spent(hero["stats"])), UI.GOOD)
	for sd in Leader.STATS:
		var st: Dictionary = sd
		var key := str(st["id"])
		var row := UI.hbox(8)
		var nl := UI.vbox(0)
		nl.custom_minimum_size = Vector2(130, 0)
		nl.add_child(UI.label(str(st["name"]), UI.FS_BODY, UI.TEXT, true))
		row.add_child(nl)
		var base := int((hero["stats"] as Dictionary)[key])
		var dec_stat := func() -> void:
			(hero["stats"] as Dictionary)[key] = maxi(Leader.STAT_BASE, base - 1)
			_rebuild_body()
		var minus := UI.pill("−", false, dec_stat, false, UI.PILL_SUB)
		minus.custom_minimum_size = Vector2(36, 28)
		row.add_child(minus)
		row.add_child(_pips(Leader.stat(hero, key), 10, func(_v: int) -> void: pass, UI.PILL_GO))
		var inc_stat := func() -> void:
			if Leader.points_spent(hero["stats"]) < Leader.STAT_POINTS and base < Leader.STAT_MAX:
				(hero["stats"] as Dictionary)[key] = base + 1
			_rebuild_body()
		var plus := UI.pill("+", false, inc_stat, false, UI.PILL_SUB)
		plus.custom_minimum_size = Vector2(36, 28)
		row.add_child(plus)
		sc.add_child(row)
		var dl := UI.label(str(st["desc"]), UI.FS_TINY, UI.FAINT)
		sc.add_child(dl)
	sc.add_child(UI.label("El oficio y el rasgo vital modifican estos valores.", UI.FS_SMALL, UI.MUTED))

# ---------------------------------------------------------------- paso 5: resumen
func _build_summary() -> void:
	var party := build_party()
	var col := Color(str(party["color"]))
	var banner := PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bsb := UI.box(UI.NAVY, col, 4, 0, 22, 16, true)
	bsb.border_width_bottom = 6
	banner.add_theme_stylebox_override("panel", bsb)
	_body.add_child(banner)
	var top := UI.hbox(22)
	banner.add_child(top)
	var port := LeaderPortrait.new()
	port.custom_minimum_size = Vector2(150, 150)
	port.setup(hero, col, "smug")
	top.add_child(port)
	var info := UI.vbox(4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.eyebrow("VAS A DIRIGIR", Color("#9CC4EA")))
	info.add_child(UI.label(str(party["name"]), UI.FS_H1 + 8, Color.WHITE, true))
	info.add_child(UI.label("Dirigido por %s" % Leader.full_name(hero), UI.FS_H2, Color("#DCE8F6"), true))
	info.add_child(UI.label(Leader.tagline(hero), UI.FS_BODY, Color("#9CC4EA")))
	info.add_child(UI.label(Ideology.bloc_name(party["ideology"], party["ideology_profile"]), UI.FS_BODY, Color("#9CC4EA")))
	if str(party.get("motto", "")) != "":
		info.add_child(UI.label("«%s»" % str(party["motto"]), UI.FS_BODY, Color("#9CC4EA")))
	top.add_child(info)
	top.add_child(_emblem(col, str(party["short_name"]), str(party.get("motif", UI.motif_for(str(party["id"])))), 110))
	var cols := UI.hbox(14)
	_body.add_child(cols)
	var l := UI.vbox(12)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(l)
	var ic := UI.card(l, "Ideología", "", UI.ACCENT)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for pk in (party["ideology_picks"] as Array):
		var pd: Dictionary = pk
		fl.add_child(UI.chip("%s %s" % [Ideology.name_of(str(pd["id"])), "●".repeat(int(pd["strength"]))], col.darkened(0.15)))
	ic.add_child(fl)
	var axes: Dictionary = party["ideology"]
	ic.add_child(AxisBar.new(float(axes["economic"]), "Izquierda", "Derecha"))
	ic.add_child(AxisBar.new(float(axes["social"]), "Progresista", "Conservador"))
	ic.add_child(AxisBar.new(float(axes["territorial"]), "Centralista", "Descentralizador"))
	if (party.get("territory", []) as Array).size() > 0:
		ic.add_child(UI.label("Te presentas solo en: %s" % ", ".join(party["territory"]), UI.FS_BODY, UI.WARN, true))
	if mode == "custom":
		ic.add_child(UI.label("Coherencia interna: %d%%" % int(round(float(party["coherence"]) * 100.0)), UI.FS_SMALL, UI.MUTED))
	var sc := UI.card(l, "Atributos del personaje", "", UI.GOOD)
	for sd in Leader.STATS:
		var st: Dictionary = sd
		var row := UI.hbox(8)
		var n := UI.label(str(st["name"]), UI.FS_BODY, UI.TEXT)
		n.custom_minimum_size = Vector2(120, 0)
		row.add_child(n)
		var v := Leader.stat(hero, str(st["id"]))
		var m := UI.meter(float(v), 10.0, UI.GOOD, 6)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		row.add_child(UI.label("%d" % v, UI.FS_BODY, UI.TEXT, true))
		sc.add_child(row)
	var r := UI.vbox(12)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(r)
	var ac := UI.card(r, "Afinidades en el Congreso", "", UI.WARN)
	var me := {"ideology": party["ideology"], "ideology_profile": party["ideology_profile"]}
	var rows: Array = []
	for o in DataStore.parties():
		var od: Dictionary = o
		if str(od["id"]) == str(party["id"]):
			continue
		rows.append({"id": str(od["id"]), "name": str(od.get("short_name", od["id"])), "color": str(od.get("color", "#888")), "compat": Ideology.compat(me, od)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["compat"]) > float(b["compat"]))
	var two := UI.hbox(18)
	ac.add_child(two)
	var best := UI.vbox(5)
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.add_child(_field_label("Más afines"))
	for it in rows.slice(0, 6):
		best.add_child(_compat_row(it as Dictionary))
	two.add_child(best)
	var worst := UI.vbox(5)
	worst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worst.add_child(_field_label("Más opuestos"))
	for it in rows.slice(maxi(0, rows.size() - 6), rows.size()):
		worst.add_child(_compat_row(it as Dictionary))
	two.add_child(worst)
	var poll := 2.5 if mode == "custom" else float(Rules.BASE_POLL.get(party_id, 2.5))
	if (party.get("territory", []) as Array).size() > 0:
		poll = maxf(0.08, 7.0 * _share_of(party["territory"]))
	var dc := UI.card(r, "Punto de partida", "", UI.ACCENT)
	dc.add_child(UI.label("Intención de voto inicial: %.1f%% · %s" % [poll, _difficulty(poll)], UI.FS_BODY, UI.TEXT, true))
	dc.add_child(UI.wrap_label("42 días de campaña, luego noche electoral, investidura y cuatro años de legislatura.", UI.FS_SMALL, UI.MUTED))
	var hc := UI.card(r, "Historial del país", "Datos de los cinco años anteriores para las gráficas", UI.GOOD)
	var hrow := HFlowContainer.new()
	hrow.add_theme_constant_override("h_separation", 6)
	hrow.add_theme_constant_override("v_separation", 6)
	for hm in HistoryGen.MODES:
		var hid := str(hm)
		var set_hist := func() -> void:
			history_mode = hid
			render()
		hrow.add_child(UI.pill(str(HistoryGen.MODE_NAMES[hid]), history_mode == hid, set_hist))
	hc.add_child(hrow)
	hc.add_child(UI.wrap_label(str(HistoryGen.MODE_DESC[history_mode]), UI.FS_SMALL, UI.MUTED))

func _share_of(names: Array) -> float:
	var total := 0.0
	var part := 0.0
	for c in DataStore.constituencies():
		var cd: Dictionary = c
		var v := float(int(cd.get("seats", 4)) * 18000 + 12000)
		total += v
		if names.has(str(cd.get("autonomous_community", ""))):
			part += v
	return part / maxf(total, 1.0)

# ---------------------------------------------------------------- resultado
func build_party() -> Dictionary:
	var ch := hero.duplicate(true)
	ch["ai"] = false
	var out: Dictionary
	if mode == "custom":
		var comp := Ideology.compose(_picks())
		out = {
			"id": "custom_player", "name": str(custom["name"]).strip_edges(), "short_name": str(custom["short"]).strip_edges().to_upper().substr(0, 8),
			"color": str(custom["color"]), "is_custom": true, "motif": str(custom["motif"]), "motto": str(custom["motto"]),
			"description": "Partido de nueva creación: %s." % str(comp["bloc"]).to_lower(),
			"ideology": comp["axes"], "ideology_profile": comp["profile"], "ideology_picks": comp["picks"], "coherence": comp["coherence"],
		}
		if Ideology.is_territorial(comp["picks"]) and str(custom.get("territory", "")) != "":
			out["territory"] = [str(custom["territory"])]
	else:
		out = _party(party_id).duplicate(true)
		out["ideology_picks"] = Ideology.infer_picks(out, 5)
		out["coherence"] = 1.0
	out["character"] = ch
	out["leader"] = Leader.full_name(ch)
	out["history_mode"] = history_mode
	return out
