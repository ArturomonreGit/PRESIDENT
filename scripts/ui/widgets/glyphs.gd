class_name Glyphs
extends RefCounted
## Iconos vectoriales dibujados por código (sin ficheros): uno por área de política. Se dibujan dentro de un círculo de radio `r`.

const OF_AREA := {
	"housing": "house", "tax": "percent", "indirect": "basket", "health": "cross", "education": "book", "science": "flask",
	"jobs": "briefcase", "industry": "factory", "energy": "bolt", "transport": "bus", "agriculture": "wheat",
	"security": "shield", "justice": "scales", "immigration": "globe", "defense": "star", "territory": "flag",
	"social": "people", "family": "heart",
}

static func of_area(area_id: String) -> String:
	return str(OF_AREA.get(area_id, "dot"))

static func area_color(area_id: String) -> Color:
	return Color(str(Policies.area(area_id).get("color", "#2563EB")))

## Dibuja el icono `kind` centrado en `c` con radio `r` (el icono ocupa ≈ 0,62·r).
static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
	var u := r * 0.62
	var w := maxf(1.2, u * 0.16)
	match kind:
		"house":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u, -0.1 * u), c + Vector2(0, -u), c + Vector2(u, -0.1 * u)]), col)
			ci.draw_rect(Rect2(c + Vector2(-0.68 * u, -0.1 * u), Vector2(1.36 * u, 1.05 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-0.18 * u, 0.35 * u), Vector2(0.36 * u, 0.6 * u)), Color(1, 1, 1, 0.85))
		"percent":
			ci.draw_circle(c + Vector2(-0.45 * u, -0.5 * u), 0.3 * u, col)
			ci.draw_circle(c + Vector2(0.45 * u, 0.5 * u), 0.3 * u, col)
			ci.draw_line(c + Vector2(0.65 * u, -0.8 * u), c + Vector2(-0.65 * u, 0.8 * u), col, w * 1.3, true)
		"basket":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u, -0.1 * u), c + Vector2(u, -0.1 * u), c + Vector2(0.7 * u, 0.9 * u), c + Vector2(-0.7 * u, 0.9 * u)]), col)
			ci.draw_arc(c + Vector2(0, -0.1 * u), 0.55 * u, PI, TAU, 14, col, w, true)
		"cross":
			ci.draw_rect(Rect2(c + Vector2(-0.3 * u, -u), Vector2(0.6 * u, 2 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-u, -0.3 * u), Vector2(2 * u, 0.6 * u)), col)
		"book":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u, -0.7 * u), c + Vector2(-0.05 * u, -0.45 * u), c + Vector2(-0.05 * u, 0.85 * u), c + Vector2(-u, 0.6 * u)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u, -0.7 * u), c + Vector2(0.05 * u, -0.45 * u), c + Vector2(0.05 * u, 0.85 * u), c + Vector2(u, 0.6 * u)]), col)
		"flask":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.25 * u, -u), c + Vector2(0.25 * u, -u), c + Vector2(0.25 * u, -0.25 * u), c + Vector2(0.85 * u, 0.8 * u), c + Vector2(-0.85 * u, 0.8 * u), c + Vector2(-0.25 * u, -0.25 * u)]), col)
			ci.draw_line(c + Vector2(-0.45 * u, -u), c + Vector2(0.45 * u, -u), col, w)
		"briefcase":
			ci.draw_rect(Rect2(c + Vector2(-u, -0.45 * u), Vector2(2 * u, 1.35 * u)), col)
			ci.draw_arc(c + Vector2(0, -0.45 * u), 0.4 * u, PI, TAU, 10, col, w, true)
			ci.draw_line(c + Vector2(-u, 0.15 * u), c + Vector2(u, 0.15 * u), Color(1, 1, 1, 0.8), w * 0.7)
		"factory":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u, 0.85 * u), c + Vector2(-u, -0.2 * u), c + Vector2(-0.35 * u, 0.2 * u), c + Vector2(-0.35 * u, -0.2 * u), c + Vector2(0.3 * u, 0.2 * u), c + Vector2(0.3 * u, 0.85 * u)]), col)
			ci.draw_rect(Rect2(c + Vector2(0.45 * u, -0.9 * u), Vector2(0.45 * u, 1.75 * u)), col)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.15 * u, -u), c + Vector2(-0.65 * u, 0.15 * u), c + Vector2(-0.05 * u, 0.15 * u), c + Vector2(-0.2 * u, u), c + Vector2(0.7 * u, -0.25 * u), c + Vector2(0.1 * u, -0.25 * u)]), col)
		"bus":
			ci.draw_rect(Rect2(c + Vector2(-u, -0.8 * u), Vector2(2 * u, 1.45 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-0.8 * u, -0.55 * u), Vector2(1.6 * u, 0.5 * u)), Color(1, 1, 1, 0.8))
			ci.draw_circle(c + Vector2(-0.5 * u, 0.8 * u), 0.22 * u, col)
			ci.draw_circle(c + Vector2(0.5 * u, 0.8 * u), 0.22 * u, col)
		"wheat":
			ci.draw_line(c + Vector2(0, 0.95 * u), c + Vector2(0, -0.6 * u), col, w)
			for i in range(3):
				var y := -0.55 * u + float(i) * 0.45 * u
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, y), c + Vector2(-0.6 * u, y - 0.35 * u), c + Vector2(-0.45 * u, y + 0.1 * u)]), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, y), c + Vector2(0.6 * u, y - 0.35 * u), c + Vector2(0.45 * u, y + 0.1 * u)]), col)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8 * u, -0.8 * u), c + Vector2(0, -u), c + Vector2(0.8 * u, -0.8 * u), c + Vector2(0.8 * u, 0.1 * u), c + Vector2(0, u), c + Vector2(-0.8 * u, 0.1 * u)]), col)
		"scales":
			ci.draw_line(c + Vector2(0, -0.9 * u), c + Vector2(0, 0.9 * u), col, w)
			ci.draw_line(c + Vector2(-0.9 * u, -0.5 * u), c + Vector2(0.9 * u, -0.5 * u), col, w)
			ci.draw_line(c + Vector2(-0.5 * u, 0.9 * u), c + Vector2(0.5 * u, 0.9 * u), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.9 * u, 0.1 * u), c + Vector2(-0.4 * u, 0.1 * u), c + Vector2(-0.65 * u, 0.4 * u)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.9 * u, 0.1 * u), c + Vector2(0.4 * u, 0.1 * u), c + Vector2(0.65 * u, 0.4 * u)]), col)
		"globe":
			ci.draw_arc(c, u, 0, TAU, 24, col, w, true)
			ci.draw_arc(c, u, 0, TAU, 2, col, w)
			ci.draw_line(c + Vector2(-u, 0), c + Vector2(u, 0), col, w * 0.8)
			ci.draw_line(c + Vector2(0, -u), c + Vector2(0, u), col, w * 0.8)
			ci.draw_arc(c, u, -PI * 0.5, PI * 0.5, 2, col, w * 0.5)
			ci.draw_arc(c + Vector2(-0.9 * u, 0), 1.1 * u, -0.9, 0.9, 12, col, w * 0.8, true)
			ci.draw_arc(c + Vector2(0.9 * u, 0), 1.1 * u, PI - 0.9, PI + 0.9, 12, col, w * 0.8, true)
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI * 0.5 + float(i) * PI / 5.0
				var rr := u if i % 2 == 0 else 0.42 * u
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"flag":
			ci.draw_line(c + Vector2(-0.75 * u, -u), c + Vector2(-0.75 * u, u), col, w * 1.1)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.75 * u, -0.9 * u), c + Vector2(0.85 * u, -0.55 * u), c + Vector2(-0.75 * u, 0.1 * u)]), col)
		"people":
			ci.draw_circle(c + Vector2(-0.4 * u, -0.45 * u), 0.33 * u, col)
			ci.draw_circle(c + Vector2(0.45 * u, -0.35 * u), 0.28 * u, col)
			ci.draw_arc(c + Vector2(-0.4 * u, 0.85 * u), 0.8 * u, PI, TAU, 12, col, w * 1.6, true)
			ci.draw_arc(c + Vector2(0.45 * u, 0.85 * u), 0.6 * u, PI, TAU, 12, col, w * 1.3, true)
		"heart":
			ci.draw_circle(c + Vector2(-0.38 * u, -0.3 * u), 0.46 * u, col)
			ci.draw_circle(c + Vector2(0.38 * u, -0.3 * u), 0.46 * u, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8 * u, -0.05 * u), c + Vector2(0.8 * u, -0.05 * u), c + Vector2(0, 0.95 * u)]), col)
		"leaf":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8 * u, 0.8 * u), c + Vector2(-0.6 * u, -0.3 * u), c + Vector2(0.2 * u, -0.9 * u), c + Vector2(0.85 * u, -0.85 * u), c + Vector2(0.7 * u, 0.0), c + Vector2(0.0 * u, 0.7 * u)]), col)
		"person":
			ci.draw_circle(c + Vector2(0, -0.45 * u), 0.38 * u, col)
			ci.draw_arc(c + Vector2(0, 0.95 * u), 0.85 * u, PI, TAU, 14, col, w * 1.8, true)
		"chart":
			ci.draw_rect(Rect2(c + Vector2(-0.9 * u, 0.1 * u), Vector2(0.45 * u, 0.8 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-0.2 * u, -0.4 * u), Vector2(0.45 * u, 1.3 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(0.5 * u, -0.9 * u), Vector2(0.45 * u, 1.8 * u)), col)
		"euro":
			ci.draw_arc(c + Vector2(0.1 * u, 0), 0.8 * u, 0.9, TAU - 0.9, 14, col, w * 1.3, true)
			ci.draw_line(c + Vector2(-0.8 * u, -0.25 * u), c + Vector2(0.35 * u, -0.25 * u), col, w)
			ci.draw_line(c + Vector2(-0.8 * u, 0.25 * u), c + Vector2(0.35 * u, 0.25 * u), col, w)
		_:
			ci.draw_circle(c, 0.4 * u, col)

## Icono de un grupo social: su inicial dentro del círculo.
static func initial(ci: CanvasItem, text: String, c: Vector2, r: float, col: Color) -> void:
	var f := UI.bold_font()
	var fs := int(maxf(9.0, r * 0.9))
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	ci.draw_string(f, c + Vector2(-sz.x * 0.5, sz.y * 0.28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
