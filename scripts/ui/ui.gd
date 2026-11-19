class_name UI
extends RefCounted
## Sistema de diseño: paleta, estilos y fábricas de controles. Tema oscuro de gestión.

const BG := Color("#EEF1F6")
const SIDE := Color("#1C2636")          # barra lateral (oscura, como marco de la aplicación)
const SIDE_TEXT := Color("#E8EEF7")
const SIDE_MUTED := Color("#9AA8BD")
const TOP := Color("#FFFFFF")
const PANEL := Color("#FFFFFF")
const PANEL2 := Color("#F4F6FA")
const PANEL3 := Color("#E8ECF3")
const BORDER := Color("#D8DEE8")
const TEXT := Color("#1A2332")
const MUTED := Color("#5A6679")
const FAINT := Color("#8792A4")
const ACCENT := Color("#2563EB")
const GOOD := Color("#12875A")
const WARN := Color("#B7791F")
const BAD := Color("#D0384A")
const GOLD := Color("#C99A12")
const NAVY := Color("#14304F")          # barra superior (marco del juego)
const HEAD := Color("#2A6AA8")          # cabecera de las tarjetas
const D4_BLUE := Color("#2D8FDD")       # bloques azules estilo Democracy 4
const D4_BLUE_L := Color("#58B0EA")
const D4_BLUE_D := Color("#1F6FB8")
const D4_RED := Color("#F2481B")
const D4_LINE := Color("#BCCDE0")
const PILL := Color("#1A8FE3")          # botones de bloque (azul, como Democracy 4)
const PILL_ACTIVE := Color("#F2481B")   # bloque seleccionado (naranja)
const PILL_SUB := Color("#3E78C2")
const PILL_WARN := Color("#E6A117")
const PILL_GO := Color("#16A06B")
const SHADOW := Color(0.10, 0.16, 0.28, 0.08)

const FS_TINY := 11
const FS_SMALL := 12
const FS_BODY := 14
const FS_LEAD := 16
const FS_H2 := 20
const FS_H1 := 28

static var _bold: Font = null
static var _regular: Font = null

## Fuentes incluidas en el juego (Inter): nítidas a cualquier escala, a diferencia de la fuente por defecto del motor.
static func regular_font() -> Font:
	if _regular == null:
		_regular = load("res://assets/fonts/Inter-Regular.otf") as Font
	return _regular if _regular != null else ThemeDB.fallback_font

static func bold_font() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/Inter-SemiBold.otf") as Font
	return _bold if _bold != null else regular_font()

# ---------------------------------------------------------------- estilos
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, border_w: int = 1, pad_x: int = 14, pad_y: int = 12, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 2)
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = regular_font()
	t.default_font_size = FS_BODY
	# Botón base
	t.set_stylebox("normal", "Button", box(Color.WHITE, BORDER, 4, 1, 14, 8))
	t.set_stylebox("hover", "Button", box(Color("#F1F5FD"), ACCENT, 6, 1, 14, 8))
	t.set_stylebox("pressed", "Button", box(Color("#E3EBFB"), ACCENT, 6, 1, 14, 8))
	t.set_stylebox("disabled", "Button", box(Color("#F2F4F8"), Color("#E3E7EE"), 6, 1, 14, 8))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 6, 1, 14, 8))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", FAINT)
	# Campos de texto
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, box(Color.WHITE, BORDER, 6, 1, 10, 8))
		t.set_stylebox("focus", cls, box(Color.WHITE, ACCENT, 6, 1, 10, 8))
		t.set_stylebox("read_only", cls, box(PANEL2, BORDER, 6, 1, 10, 8))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_placeholder_color", cls, FAINT)
		t.set_color("caret_color", cls, ACCENT)
		t.set_color("selection_color", cls, Color(ACCENT, 0.25))
	# Desplegables
	t.set_stylebox("normal", "OptionButton", box(Color.WHITE, BORDER, 6, 1, 12, 8))
	t.set_stylebox("hover", "OptionButton", box(Color("#F1F5FD"), ACCENT, 6, 1, 12, 8))
	t.set_stylebox("pressed", "OptionButton", box(Color("#F1F5FD"), ACCENT, 6, 1, 12, 8))
	t.set_stylebox("disabled", "OptionButton", box(Color("#F2F4F8"), Color("#E3E7EE"), 6, 1, 12, 8))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", ACCENT)
	t.set_color("font_disabled_color", "OptionButton", FAINT)
	t.set_stylebox("panel", "PopupMenu", box(Color.WHITE, BORDER, 6, 1, 6, 6, true))
	t.set_stylebox("hover", "PopupMenu", box(Color("#E8F0FE"), Color(0, 0, 0, 0), 4, 0, 8, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_constant("v_separation", "PopupMenu", 8)
	# Casillas y deslizadores
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", ACCENT)
	t.set_color("font_color", "CheckButton", TEXT)
	var track := box(PANEL3, BORDER, 4, 1, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 4, 0, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.15), Color(0, 0, 0, 0), 4, 0, 0, 0))
	# Barras de desplazamiento
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 3, 3))
		t.set_stylebox("grabber", cls, box(Color("#C3CCDA"), Color(0, 0, 0, 0), 4, 0, 3, 3))
		t.set_stylebox("grabber_highlight", cls, box(Color("#A8B4C7"), Color(0, 0, 0, 0), 4, 0, 3, 3))
		t.set_stylebox("grabber_pressed", cls, box(ACCENT, Color(0, 0, 0, 0), 4, 0, 3, 3))
	# Etiquetas, tooltips, diálogos
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "TooltipPanel", box(Color("#1C2636"), Color("#1C2636"), 6, 1, 10, 6))
	t.set_color("font_color", "TooltipLabel", Color("#F2F5FA"))
	t.set_stylebox("panel", "AcceptDialog", box(Color.WHITE, BORDER, 10, 1, 16, 14, true))
	t.set_stylebox("panel", "Window", box(Color.WHITE, BORDER, 10, 1, 16, 14, true))
	return t

# ---------------------------------------------------------------- fábricas básicas
static func label(text: String, size: int = FS_BODY, color: Color = TEXT, is_bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold_font())
	return l

static func wrap_label(text: String, size: int = FS_BODY, color: Color = MUTED, is_bold: bool = false) -> Label:
	var l := label(text, size, color, is_bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func eyebrow(text: String, color: Color = ACCENT) -> Label:
	var l := label(text.to_upper(), FS_TINY, color, true)
	return l

static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func grid(columns: int, hsep: int = 10, vsep: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", vsep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

static func spacer(h: float = 0.0, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c

static func fill() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func hsep(color: Color = BORDER) -> Control:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

## Línea vertical fina para separar columnas.
static func vsep(color: Color = D4_LINE) -> Control:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(1, 1)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r

## Panel plano estilo Democracy 4: banda azul con el título y cuerpo blanco. Devuelve el VBox de contenido.
static func card(parent: Node, title: String = "", subtitle: String = "", accent: Color = Color(0, 0, 0, 0)) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", box(PANEL, D4_LINE, 4, 1, 0, 0))
	pc.clip_contents = true
	parent.add_child(pc)
	var outer := vbox(0)
	pc.add_child(outer)
	if title != "":
		var band := PanelContainer.new()
		band.add_theme_stylebox_override("panel", box(HEAD, Color(0, 0, 0, 0), 0, 0, 12, 6))
		outer.add_child(band)
		var head := hbox(8)
		band.add_child(head)
		if accent.a > 0.0:
			var bar := ColorRect.new()
			bar.color = accent.lightened(0.25)
			bar.custom_minimum_size = Vector2(4, 14)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(bar)
		var tl := label(title.to_upper(), FS_SMALL, Color.WHITE, true)
		head.add_child(tl)
		if subtitle != "":
			# El subtítulo se recorta con puntos suspensivos si no cabe (nunca ensancha la columna).
			var sl := label(subtitle, FS_SMALL, Color(1, 1, 1, 0.72))
			sl.clip_text = true
			sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sl.tooltip_text = subtitle
			sl.mouse_filter = Control.MOUSE_FILTER_PASS
			head.add_child(sl)
		else:
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", box(PANEL, Color(0, 0, 0, 0), 0, 0, 14, 10))
	outer.add_child(body)
	var col := vbox(7)
	body.add_child(col)
	return col

## Hace que una tarjeta creada con `card()` reparta el alto sobrante (se llama con el VBox que devuelve).
static func expand_card(body_col: Control) -> void:
	var n: Node = body_col
	for i in range(3):
		if n.get_parent() != null:
			n = n.get_parent()
	if n is Control:
		(n as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_col.size_flags_vertical = Control.SIZE_EXPAND_FILL

## Fila seleccionable de una lista maestro/detalle. Devuelve el HBox interior donde añadir el contenido.
static func select_row(parent: Node, selected: bool, on_press: Callable, accent: Color = ACCENT, height: float = 44.0) -> HBoxContainer:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", box(PANEL.lerp(accent, 0.10) if selected else PANEL, accent if selected else BORDER, 4, 2 if selected else 1, 10, 4))
	b.add_theme_stylebox_override("hover", box(PANEL.lerp(accent, 0.06), accent, 4, 1, 10, 4))
	b.add_theme_stylebox_override("pressed", box(PANEL.lerp(accent, 0.14), accent, 4, 2, 10, 4))
	b.pressed.connect(on_press)
	parent.add_child(b)
	var inner := hbox(8)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 10
	inner.offset_right = -10
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	return inner

## Marca como «ignorar ratón» todo el contenido de una fila para que el clic llegue al botón.
static func pass_clicks(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c is Button):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		pass_clicks(c)

## Tarjeta con fondo de color (para destacados).
static func hero(parent: Node, color_a: Color, color_b: Color) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := box(color_a, color_b, 12, 1, 18, 12)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var col := vbox(8)
	pc.add_child(col)
	return col

static func chip(text: String, color: Color = ACCENT, filled: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := box(color if filled else Color(color, 0.14), Color(color, 0.55), 10, 1, 8, 2)
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, FS_TINY, Color.WHITE if filled else color, true)
	pc.add_child(l)
	return pc

static func button(text: String, kind: String = "secondary", callback: Callable = Callable(), min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var base: Color
	var fg := Color.WHITE
	match kind:
		"primary": base = Color("#2563EB")
		"good": base = Color("#12875A")
		"warn": base = Color("#C27A12")
		"danger": base = Color("#D0384A")
		"ghost": base = Color(0, 0, 0, 0)
		_: base = PANEL3
	if kind == "ghost":
		b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), BORDER, 6, 1, 14, 8))
		b.add_theme_stylebox_override("hover", box(Color("#F1F5FD"), ACCENT, 6, 1, 14, 8))
		b.add_theme_color_override("font_color", MUTED)
	elif kind != "secondary":
		b.add_theme_stylebox_override("normal", box(base, base.lightened(0.15), 6, 1, 14, 8))
		b.add_theme_stylebox_override("hover", box(base.lightened(0.12), base.lightened(0.3), 6, 1, 14, 8))
		b.add_theme_stylebox_override("pressed", box(base.darkened(0.15), base, 6, 1, 14, 8))
		b.add_theme_color_override("font_color", fg)
		b.add_theme_color_override("font_hover_color", fg)
		b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_font_override("font", bold_font())
	b.pressed.connect(func() -> void: Sfx.play("confirm" if kind in ["primary", "good"] else "click"))
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

## Botón discreto para la barra lateral oscura.
static func side_button(text: String, callback: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.10), 6, 1, 12, 6))
	b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.25), 6, 1, 12, 6))
	b.add_theme_stylebox_override("pressed", box(Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.3), 6, 1, 12, 6))
	b.add_theme_color_override("font_color", SIDE_MUTED)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

static func kpi(parent: Node, title: String, value: String, sub: String = "", color: Color = TEXT, sub_color: Color = MUTED) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := box(PANEL, color if color != TEXT else D4_BLUE, 4, 0, 14, 10)
	sb.border_width_left = 5
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var col := vbox(2)
	pc.add_child(col)
	col.add_child(label(title.to_upper(), FS_TINY, MUTED, true))
	col.add_child(label(value, 24, color, true))
	if sub != "":
		col.add_child(label(sub, FS_SMALL, sub_color))
	return col

static func meter(value: float, max_value: float, color: Color, height: float = 8.0) -> MeterBar:
	var mb := MeterBar.new()
	mb.value = value
	mb.max_value = max_value
	mb.color = color
	mb.custom_minimum_size = Vector2(0, height)
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return mb

## Franja de color + etiqueta para identificar un partido.
static func party_tag(model: GameModel, id: String, size: int = FS_BODY, is_bold: bool = true) -> HBoxContainer:
	var h := hbox(7)
	var sw := ColorRect.new()
	sw.color = model.party_color(id)
	sw.custom_minimum_size = Vector2(5, size + 4)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	h.add_child(label(model.party_short(id), size, TEXT, is_bold))
	return h

static func leader_portrait(model: GameModel, id: String, px: float, mood: String = "neutral") -> LeaderPortrait:
	var lp := LeaderPortrait.new()
	lp.custom_minimum_size = Vector2(px, px)
	lp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lp.setup(model.leader_of(id), model.party_color(id), mood, "player" if model.is_player(id) else id)
	return lp

static func party_emblem(model: GameModel, id: String, px: float) -> PartyEmblem:
	var e := PartyEmblem.new()
	e.custom_minimum_size = Vector2(px, px)
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pdata := model.party_by_id(id)
	e.set_identity(model.party_color(id), str(pdata.get("short_name", id)).substr(0, 3), motif_for(id))
	return e

static func motif_for(id: String) -> String:
	var key := id.to_lower()
	if key in ["psoe", "sumar", "erc", "podemos"]:
		return "sun"
	if key in ["pp", "upn", "cc", "salf"]:
		return "star"
	if key == "vox":
		return "bars"
	if key in ["bng", "ehbildu", "adelante"]:
		return "leaf"
	if key in ["pnv", "junts", "alianca"]:
		return "wave"
	return "star"

static func tone_color(tone: String) -> Color:
	match tone:
		"positive", "good": return GOOD
		"warning", "warn": return WARN
		"bad", "negative": return BAD
		_: return ACCENT

static func signed(value: float, decimals: int = 1) -> String:
	var fmt := "%+." + str(decimals) + "f"
	return (fmt % value).replace("-", "−")

static func delta_color(value: float, eps: float = 0.05) -> Color:
	if value > eps:
		return GOOD
	if value < -eps:
		return BAD
	return MUTED

static func clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Botón en forma de píldora para el menú: azul, y naranja si está seleccionado.
static func pill(text: String, active: bool, callback: Callable, big: bool = true, base: Color = PILL) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 40 if big else 28)
	var col := PILL_ACTIVE if active else base
	var r := 20 if big else 14
	var px := 22 if big else 14
	var py := 8 if big else 4
	b.add_theme_stylebox_override("normal", box(col, col.lightened(0.18), r, 1, px, py))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.1), col.lightened(0.3), r, 1, px, py))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.12), col, r, 1, px, py))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("disabled", box(Color("#A9B7C9"), Color("#BFCADA"), r, 1, px, py))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))
	b.add_theme_font_override("font", bold_font())
	b.add_theme_font_size_override("font_size", FS_LEAD if big else FS_BODY)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.pressed.connect(callback)
	return b

## Botón pequeño y discreto para las utilidades de la barra secundaria.
static func mini_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), BORDER, 6, 1, 10, 3))
	b.add_theme_stylebox_override("hover", box(Color("#F1F5FD"), ACCENT, 6, 1, 10, 3))
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_font_size_override("font_size", FS_SMALL)
	b.pressed.connect(callback)
	return b


## Fondo degradado azul claro común a todo el juego (menú, asistente y partida).
static func gradient_bg() -> TextureRect:
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color("#E6F0FA"))
	grad.set_color(1, Color("#BBD5EE"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

## Barra superior azul marino con filete inferior (la misma que usa la partida). Devuelve el panel; el contenido va en `.get_child(0)`.
static func nav_bar(height: float = 68.0) -> PanelContainer:
	var head := PanelContainer.new()
	head.custom_minimum_size = Vector2(0, height)
	var hb := box(NAVY, Color("#0C2037"), 0, 0, 24, 8)
	hb.border_width_bottom = 3
	head.add_theme_stylebox_override("panel", hb)
	var row := hbox(16)
	head.add_child(row)
	return head

## Botón de bloque grande del menú principal: título, subtítulo opcional y flecha. `kind`: main (verde), blue, danger.
static func menu_block(title: String, subtitle: String, kind: String, callback: Callable, width: float = 460.0, enabled: bool = true) -> Button:
	var base := PILL
	match kind:
		"main": base = PILL_GO
		"danger": base = Color("#8E9BB0")
		"quiet": base = PILL_SUB
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(width, 68 if subtitle != "" else 58)
	b.disabled = not enabled
	var mk := func(c: Color, edge: Color) -> StyleBoxFlat:
		var sb := box(c, edge, 4, 0, 0, 0, true)
		sb.border_width_left = 8
		sb.border_color = edge
		return sb
	b.add_theme_stylebox_override("normal", mk.call(base, base.lightened(0.28)))
	b.add_theme_stylebox_override("hover", mk.call(base.lightened(0.10), PILL_ACTIVE))
	b.add_theme_stylebox_override("pressed", mk.call(base.darkened(0.12), PILL_ACTIVE))
	b.add_theme_stylebox_override("disabled", mk.call(Color("#A9B7C9"), Color("#C4CFDD")))
	var inner := hbox(10)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 26
	inner.offset_right = -20
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var col := vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := label(title.to_upper(), 20, Color.WHITE, true)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tl)
	if subtitle != "":
		var sl := label(subtitle, FS_SMALL, Color(1, 1, 1, 0.82))
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sl)
	inner.add_child(col)
	var arrow := label("›", 30, Color(1, 1, 1, 0.9), true)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(arrow)
	b.pressed.connect(func() -> void: Sfx.play("confirm" if kind == "main" else "click"))
	if callback.is_valid():
		b.pressed.connect(callback)
	return b
