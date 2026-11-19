class_name LineChart
extends Control
## Gráfico de líneas multi-serie. series = [{id, name, color, values:[float], width}]. x_labels opcional.

var series: Array = []:
	set(v):
		series = v
		queue_redraw()
var x_labels: Array = []
var y_min := 0.0
var y_max := 40.0
var auto_range := true
var focus_id := ""
var show_end_labels := true
var value_fmt := "%.0f%%"
var allow_negative := false
var show_now := false  ## línea punteada «ahora» en el último punto
var hover_enabled := true  ## cursor interactivo: línea vertical y cuadro con los valores del punto
var ref_line := NAN  ## línea horizontal de referencia (p. ej. el valor de partida)
var ref_label := ""
var markers: Array = []  ## hitos [{i, text}]: línea vertical discontinua con su rótulo
var fill_first := false  ## sombrea el área bajo la primera serie
var selected := -1  ## punto elegido con un clic (línea vertical resaltada)
var _hover := -1
signal point_clicked(index: int)

## Longitud efectiva de una serie: `offset` (para las que empiezan más tarde, como la previsión) + valores.
static func _len(sd: Dictionary) -> int:
	return int(sd.get("offset", 0)) + (sd.get("values", []) as Array).size()

func _init() -> void:
	custom_minimum_size = Vector2(300, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func() -> void:
		_hover = -1
		queue_redraw())

func _count() -> int:
	var n := 0
	for s in series:
		n = maxi(n, _len(s as Dictionary))
	return n

func _index_at(px: float) -> int:
	var rect := _plot_rect()
	var n := _count()
	if n < 2 or px < rect.position.x - 4.0 or px > rect.end.x + 4.0:
		return -1
	return clampi(int(round((px - rect.position.x) / rect.size.x * float(n - 1))), 0, n - 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var ci := _index_at((event as InputEventMouseButton).position.x)
		if ci >= 0 and point_clicked.get_connections().size() > 0:
			selected = ci
			queue_redraw()
			point_clicked.emit(ci)
		return
	if not hover_enabled or not (event is InputEventMouseMotion):
		return
	var idx := _index_at((event as InputEventMouseMotion).position.x)
	if idx != _hover:
		_hover = idx
		queue_redraw()

func _plot_rect() -> Rect2:
	return Rect2(Vector2(46, 10), Vector2(maxf(10.0, size.x - 46 - (66 if show_end_labels else 12)), maxf(10.0, size.y - 10 - 24)))

func _range() -> Vector2:
	if not auto_range:
		return Vector2(y_min, y_max)
	var lo := 1e9
	var hi := -1e9
	for s in series:
		for v in (s as Dictionary).get("values", []):
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
	if hi < lo:
		return Vector2(0, 10)
	var pad := maxf(1.0 if value_fmt == "%.0f%%" else 0.05, (hi - lo) * 0.12)
	var lo2 := floorf(lo - pad) if value_fmt == "%.0f%%" else lo - pad
	var hi2 := ceilf(hi + pad) if value_fmt == "%.0f%%" else hi + pad
	return Vector2(lo2 if allow_negative else maxf(0.0, lo2), hi2)

func _draw() -> void:
	var rect := _plot_rect()
	var rng := _range()
	var font := UI.regular_font()
	var span := maxf(0.001, rng.y - rng.x)
	var steps := 4
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := rect.position.y + rect.size.y * (1.0 - t)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(UI.BORDER, 0.6), 1.0)
		var val := rng.x + span * t
		draw_string(font, Vector2(2, y + 4), value_fmt % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.FAINT)
	var n := _count()
	if n < 2:
		draw_string(font, rect.position + Vector2(rect.size.x * 0.5 - 70, rect.size.y * 0.5), "Sin datos suficientes todavía", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
		return
	# Etiquetas de eje x: sólo donde cambia la etiqueta (p. ej. el mes) y a lo sumo unas siete.
	if x_labels.size() >= 2:
		var marks: Array = []
		var prev := ""
		for i in range(x_labels.size()):
			var lb := str(x_labels[i])
			if lb != prev:
				marks.append(i)
				prev = lb
		var stride := maxi(1, int(ceil(float(marks.size()) / 7.0)))
		var last_x := -100.0
		for k in range(0, marks.size(), stride):
			var idx := int(marks[k])
			var x := rect.position.x + rect.size.x * float(idx) / float(maxi(1, n - 1))
			if x - last_x < 44.0:
				continue
			last_x = x
			draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + 3), Color(UI.BORDER, 0.9), 1.0)
			draw_string(font, Vector2(x - 14, rect.end.y + 16), str(x_labels[idx]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.FAINT)
	if not is_nan(ref_line) and ref_line >= rng.x and ref_line <= rng.y:
		var ry := rect.position.y + rect.size.y * (1.0 - (ref_line - rng.x) / span)
		var rx := rect.position.x
		while rx < rect.end.x:
			draw_line(Vector2(rx, ry), Vector2(minf(rx + 3.0, rect.end.x), ry), Color(UI.MUTED, 0.7), 1.0)
			rx += 7.0
		if ref_label != "":
			draw_string(font, Vector2(rect.position.x + 4, ry - 3), ref_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.MUTED)
	if show_now:
		var nx := rect.position.x + rect.size.x
		var yy := rect.position.y
		while yy < rect.end.y:
			draw_line(Vector2(nx, yy), Vector2(nx, minf(yy + 4.0, rect.end.y)), Color(UI.MUTED, 0.8), 1.0)
			yy += 8.0
		draw_string(font, Vector2(nx - 34, rect.position.y + 10), "ahora", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.MUTED)
	if rng.x < 0.0 and rng.y > 0.0:
		var zy := rect.position.y + rect.size.y * (1.0 - (0.0 - rng.x) / span)
		draw_line(Vector2(rect.position.x, zy), Vector2(rect.end.x, zy), Color(UI.MUTED, 0.55), 1.2)
	var mrow := 0
	for mk in markers:
		var mkd: Dictionary = mk
		var mx := rect.position.x + rect.size.x * float(int(mkd["i"])) / float(maxi(1, n - 1))
		var my := rect.position.y
		while my < rect.end.y:
			draw_line(Vector2(mx, my), Vector2(mx, minf(my + 3.0, rect.end.y)), Color(UI.WARN, 0.75), 1.0)
			my += 7.0
		var txt := str(mkd["text"])
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var tx := mx + 4.0
		if tx + tw > rect.end.x:
			tx = mx - 4.0 - tw
		var ty2 := rect.position.y + 11.0 + float(mrow % 3) * 12.0
		mrow += 1
		draw_rect(Rect2(tx - 2.0, ty2 - 10.0, tw + 4.0, 13.0), Color(1, 1, 1, 0.82))
		draw_string(font, Vector2(tx, ty2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.WARN.darkened(0.15))
	var ends: Array = []
	var first_done := false
	for s in series:
		var sd: Dictionary = s
		var vals: Array = sd.get("values", [])
		var col: Color = sd.get("color", Color.WHITE)
		var is_focus := focus_id == "" or focus_id == str(sd.get("id", ""))
		var width := float(sd.get("width", 2.0)) * (1.0 if is_focus else 0.7)
		if not is_focus:
			col = Color(col, 0.35)
		var off := int(sd.get("offset", 0))
		var pts := PackedVector2Array()
		for i in range(vals.size()):
			var x := rect.position.x + rect.size.x * float(i + off) / float(maxi(1, n - 1))
			var y := rect.position.y + rect.size.y * (1.0 - (float(vals[i]) - rng.x) / span)
			pts.append(Vector2(x, clampf(y, rect.position.y, rect.end.y)))
		if pts.size() >= 2:
			if fill_first and not first_done:
				var poly := PackedVector2Array(pts)
				poly.append(Vector2(pts[pts.size() - 1].x, rect.end.y))
				poly.append(Vector2(pts[0].x, rect.end.y))
				draw_colored_polygon(poly, Color(col, 0.10))
			first_done = true
			if bool(sd.get("dashed", false)):
				for k in range(pts.size() - 1):
					var seg := pts[k + 1] - pts[k]
					var len_s := seg.length()
					var dir := seg / maxf(0.001, len_s)
					var pos_d := 0.0
					while pos_d < len_s:
						draw_line(pts[k] + dir * pos_d, pts[k] + dir * minf(pos_d + 5.0, len_s), col, width, true)
						pos_d += 10.0
			else:
				draw_polyline(pts, col, width, true)
			draw_circle(pts[pts.size() - 1], width + 1.0, col)
			ends.append({"y": pts[pts.size() - 1].y, "name": str(sd.get("name", "")), "color": col, "x": pts[pts.size() - 1].x})
	if show_end_labels:
		ends.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
		var last_y := -100.0
		for e in ends:
			var ed: Dictionary = e
			var y2 := maxf(float(ed["y"]), last_y + 12.0)
			last_y = y2
			draw_string(font, Vector2(rect.end.x + 8, y2 + 4), str(ed["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ed["color"])
	if selected >= 0 and selected < n:
		var sx := rect.position.x + rect.size.x * float(selected) / float(maxi(1, n - 1))
		draw_line(Vector2(sx, rect.position.y), Vector2(sx, rect.end.y), Color(UI.ACCENT, 0.9), 2.0)
	_draw_hover(rect, rng, span, n, font)

func _draw_hover(rect: Rect2, rng: Vector2, span: float, n: int, font: Font) -> void:
	if not hover_enabled or _hover < 0 or _hover >= n:
		return
	var x := rect.position.x + rect.size.x * float(_hover) / float(maxi(1, n - 1))
	draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(UI.TEXT, 0.35), 1.0)
	var rows: Array = []
	for s in series:
		var sd: Dictionary = s
		var vals: Array = sd.get("values", [])
		var hi_idx := _hover - int(sd.get("offset", 0))
		if hi_idx < 0 or hi_idx >= vals.size():
			continue
		var v := float(vals[hi_idx])
		var y := rect.position.y + rect.size.y * (1.0 - (v - rng.x) / span)
		var col: Color = sd.get("color", Color.WHITE)
		draw_circle(Vector2(x, clampf(y, rect.position.y, rect.end.y)), 4.0, Color.WHITE)
		draw_circle(Vector2(x, clampf(y, rect.position.y, rect.end.y)), 3.0, col)
		var fmt_s: String = str(sd.get("fmt", value_fmt))
		var raw: Array = sd.get("raw", [])
		if hi_idx < raw.size():
			rows.append({"text": "%s  %s" % [str(sd.get("name", "")), str(sd.get("raw_fmt", "%.2f")) % float(raw[hi_idx])], "color": col})
		else:
			rows.append({"text": "%s  %s" % [str(sd.get("name", "")), fmt_s % v], "color": col})
	if rows.is_empty():
		return
	var head := str(x_labels[_hover]) if _hover < x_labels.size() else ""
	var w := 0.0
	for r in rows:
		w = maxf(w, font.get_string_size(str((r as Dictionary)["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	w = maxf(w, font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 18.0
	var h := 8.0 + (16.0 if head != "" else 0.0) + 15.0 * rows.size()
	var bx := x + 12.0
	if bx + w > size.x - 2.0:
		bx = x - 12.0 - w
	var by := rect.position.y + 4.0
	draw_rect(Rect2(bx, by, w, h), Color("#1C2636", 0.94), true)
	var ty := by + 14.0
	if head != "":
		draw_string(font, Vector2(bx + 9, ty), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9AA8BD"))
		ty += 16.0
	for r in rows:
		draw_string(font, Vector2(bx + 9, ty), str((r as Dictionary)["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, (r as Dictionary)["color"].lightened(0.35))
		ty += 15.0
