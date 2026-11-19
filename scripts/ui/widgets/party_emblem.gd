class_name PartyEmblem
extends Control
## Escudo simple y genérico de un partido (círculo de color, motivo e iniciales). Sin marcas reales.

var primary := Color("#2463B5")
var initials := "PS"
var motif := "star"

func set_identity(color: Color, text: String, motif_name: String) -> void:
	primary = color
	initials = text
	motif = motif_name
	queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	var c := size * 0.5
	var r := s * 0.5 - 1.0
	var light := primary.lightened(0.78)
	draw_circle(c, r, primary.darkened(0.18))
	draw_arc(c, r - 1.0, 0.0, TAU, 48, light, maxf(1.0, s * 0.04), true)
	var ink := light
	match motif:
		"sun":
			draw_circle(c + Vector2(0, -s * 0.08), s * 0.10, ink)
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var o := c + Vector2(0, -s * 0.08)
				draw_line(o + Vector2(cos(a), sin(a)) * s * 0.14, o + Vector2(cos(a), sin(a)) * s * 0.21, ink, maxf(1.0, s * 0.03), true)
		"bars":
			for i in range(3):
				var h := s * (0.20 + 0.07 * float(i % 2))
				draw_rect(Rect2(c.x - s * 0.17 + float(i) * s * 0.12, c.y - s * 0.08 - h * 0.5, s * 0.08, h), ink)
		"wave":
			for j in range(2):
				var pts := PackedVector2Array()
				for i in range(11):
					pts.append(Vector2(c.x - s * 0.2 + float(i) * s * 0.04, c.y - s * 0.12 + float(j) * s * 0.1 + sin(float(i) * 0.9 + float(j)) * s * 0.03))
				draw_polyline(pts, ink, maxf(1.2, s * 0.04), true)
		"leaf":
			var o2 := c + Vector2(0, -s * 0.08)
			draw_colored_polygon(PackedVector2Array([o2 + Vector2(0, -s * 0.15), o2 + Vector2(s * 0.12, 0), o2 + Vector2(0, s * 0.15), o2 + Vector2(-s * 0.12, 0)]), ink)
		_:
			var o3 := c + Vector2(0, -s * 0.08)
			var pts2 := PackedVector2Array()
			for i in range(10):
				var a2 := -PI * 0.5 + float(i) * PI / 5.0
				var rr := s * (0.17 if i % 2 == 0 else 0.07)
				pts2.append(o3 + Vector2(cos(a2), sin(a2)) * rr)
			draw_colored_polygon(pts2, ink)
	var font := UI.regular_font()
	var fs := int(clampf(s * 0.2, 8.0, 18.0))
	var tw := font.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + s * 0.30), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
