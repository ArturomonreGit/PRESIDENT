class_name TV
extends RefCounted
## Paleta y utilidades de dibujo de la retransmisión de la noche electoral (estilo plató de televisión).

const BG := Color("#060A12")
const PANEL := Color("#0C1424")
const PANEL_HI := Color("#17233B")
const LINE := Color("#223049")
const TEAL := Color("#21C2B5")
const RED := Color("#E3262D")
const GOLD := Color("#F5C242")
const WHITE := Color("#F4F7FB")
const MUTED := Color("#8D9BB3")
const FAINT := Color("#55637C")
const PENDING := Color("#394152")
const UP := Color("#1F9D57")
const DOWN := Color("#D8383F")
const DARK := Color("#0B1220")

static var _sb: StyleBoxFlat = null

static func font() -> Font:
	return UI.regular_font()

static func bold() -> Font:
	return UI.bold_font()

static func font_h(size: int) -> float:
	return font().get_height(size)

static func text_w(s: String, size: int, is_bold: bool = true) -> float:
	var f: Font = bold() if is_bold else font()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Texto cuya esquina superior izquierda es `pos`. Con alineación centrada/derecha `width` es el ancho de la caja.
static func text_tl(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, is_bold: bool = true, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = bold() if is_bold else font()
	ci.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(size)), s, align, width, size, col)

static func fit(s: String, size: int, max_w: float, is_bold: bool = true) -> String:
	if text_w(s, size, is_bold) <= max_w:
		return s
	var out := s
	while out.length() > 1 and text_w(out + "…", size, is_bold) > max_w:
		out = out.substr(0, out.length() - 1)
	return out + "…"

static func rrect(ci: CanvasItem, rect: Rect2, col: Color, radius: float = 6.0, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
	_sb.bg_color = col
	_sb.set_corner_radius_all(int(radius))
	_sb.set_border_width_all(bw)
	_sb.border_color = border
	ci.draw_style_box(_sb, rect)

## Texto legible sobre un color de fondo.
static func ink(bg: Color) -> Color:
	var lum := 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	return DARK if lum > 0.68 else Color.WHITE

static func tri_up(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 1.05, r * 0.8), c + Vector2(-r * 1.05, r * 0.8)]), col)

static func tri_down(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(r * 1.05, -r * 0.8), c + Vector2(-r * 1.05, -r * 0.8)]), col)

# ---------------------------------------------------------------- formato español
static func int_es(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out

static func pct_es(v: float, dec: int = 1) -> String:
	return (("%." + str(dec) + "f") % v).replace(".", ",")

## Hora ficticia de la noche: cierre de colegios a las 20:00 y recuento completo hacia la medianoche.
static func clock(tick: int) -> String:
	var minutes := 20 * 60 + (0 if tick <= 0 else 5 + int(round(235.0 * float(tick) / float(ElectionSim.CUTS))))
	minutes = minutes % 1440
	return "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]

# ---------------------------------------------------------------- texto enriquecido
## segs = [{k:"t", s, c, b}, {k:"dot", c}, {k:"chip", s, c}]
static func _seg_w(seg: Dictionary, size: int) -> float:
	match str(seg.get("k", "t")):
		"dot":
			return float(size) * 0.8
		"chip":
			return text_w(str(seg["s"]), size, true) + 14.0
		_:
			return text_w(str(seg["s"]), size, bool(seg.get("b", false)))

static func rich_width(segs: Array, size: int, gap: float = 6.0) -> float:
	var w := 0.0
	for i in range(segs.size()):
		w += _seg_w(segs[i], size)
		if i < segs.size() - 1:
			w += gap
	return w

static func rich_draw(ci: CanvasItem, segs: Array, pos: Vector2, size: int, height: float, alpha: float = 1.0, gap: float = 6.0) -> float:
	var x := pos.x
	for i in range(segs.size()):
		var seg: Dictionary = segs[i]
		var w := _seg_w(seg, size)
		var col: Color = seg.get("c", WHITE)
		match str(seg.get("k", "t")):
			"dot":
				ci.draw_circle(Vector2(x + w * 0.5, pos.y + height * 0.5), float(size) * 0.3, Color(col, alpha))
			"chip":
				var ch := float(size) + 8.0
				rrect(ci, Rect2(x, pos.y + (height - ch) * 0.5, w, ch), Color(col, alpha), 4.0)
				text_tl(ci, str(seg["s"]), Vector2(x + 7.0, pos.y + (height - font_h(size)) * 0.5), size, Color(ink(col), alpha), true)
			_:
				text_tl(ci, str(seg["s"]), Vector2(x, pos.y + (height - font_h(size)) * 0.5), size, Color(col, alpha), bool(seg.get("b", false)))
		x += w + gap
	return x - pos.x - gap
