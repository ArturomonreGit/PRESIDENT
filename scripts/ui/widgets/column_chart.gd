class_name ColumnChart
extends Control
## Columnas agrupadas (p. ej. ingresos y gastos por año). groups = [etiquetas]; series = [{name, color, values}].

var groups: Array = []:
	set(v):
		groups = v
		queue_redraw()
var series: Array = []:
	set(v):
		series = v
		queue_redraw()
var value_fmt := "%.0f"
var _hover := -1

func _init() -> void:
	custom_minimum_size = Vector2(300, 200)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func() -> void:
		_hover = -1
		queue_redraw())

func _plot() -> Rect2:
	return Rect2(Vector2(46, 8), Vector2(maxf(10.0, size.x - 54), maxf(10.0, size.y - 8 - 40)))

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion) or groups.is_empty():
		return
	var rect := _plot()
	var px := (event as InputEventMouseMotion).position.x
	var idx := clampi(int(floor((px - rect.position.x) / rect.size.x * float(groups.size()))), 0, groups.size() - 1)
	if px < rect.position.x or px > rect.end.x:
		idx = -1
	if idx != _hover:
		_hover = idx
		queue_redraw()

func _draw() -> void:
	var rect := _plot()
	var font := UI.regular_font()
	if groups.is_empty() or series.is_empty():
		draw_string(font, rect.position + Vector2(10, 40), "Sin datos suficientes todavía", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
		return
	var lo := 0.0
	var hi := 0.0
	for s in series:
		for v in (s as Dictionary).get("values", []):
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
	hi = maxf(0.001, hi * 1.08)
	var span := hi - lo
	for i in range(5):
		var f := float(i) / 4.0
		var y := rect.position.y + rect.size.y * (1.0 - f)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(UI.BORDER, 0.6), 1.0)
		draw_string(font, Vector2(2, y + 4), value_fmt % (lo + span * f), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.FAINT)
	var gw := rect.size.x / float(groups.size())
	var n := series.size()
	var bw := minf(34.0, (gw * 0.72) / float(n))
	var zero_y := rect.position.y + rect.size.y * (1.0 - (0.0 - lo) / span)
	for gi in range(groups.size()):
		var cx := rect.position.x + gw * (float(gi) + 0.5)
		if gi == _hover:
			draw_rect(Rect2(rect.position.x + gw * gi, rect.position.y, gw, rect.size.y), Color(UI.ACCENT, 0.06))
		for si in range(n):
			var sd: Dictionary = series[si]
			var vals: Array = sd.get("values", [])
			if gi >= vals.size():
				continue
			var v := float(vals[gi])
			var y := rect.position.y + rect.size.y * (1.0 - (v - lo) / span)
			var x := cx - bw * float(n) * 0.5 + bw * float(si)
			draw_rect(Rect2(x + 1.0, minf(y, zero_y), bw - 2.0, absf(zero_y - y)), sd.get("color", UI.ACCENT))
		draw_string(font, Vector2(cx - 20, rect.end.y + 16), str(groups[gi]), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, UI.MUTED)
	draw_line(Vector2(rect.position.x, zero_y), Vector2(rect.end.x, zero_y), Color(UI.MUTED, 0.6), 1.0)
	# Leyenda
	var lx := rect.position.x
	for sd2 in series:
		draw_rect(Rect2(lx, rect.end.y + 26, 10, 10), (sd2 as Dictionary).get("color", UI.ACCENT))
		draw_string(font, Vector2(lx + 14, rect.end.y + 35), str((sd2 as Dictionary).get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.TEXT)
		lx += 20.0 + font.get_string_size(str((sd2 as Dictionary).get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
	if _hover >= 0:
		var rows: Array = []
		for sd3 in series:
			var vals3: Array = (sd3 as Dictionary).get("values", [])
			if _hover < vals3.size():
				rows.append({"t": "%s  %s" % [str((sd3 as Dictionary).get("name", "")), value_fmt % float(vals3[_hover])], "c": (sd3 as Dictionary).get("color", UI.ACCENT)})
		var w := 0.0
		for r in rows:
			w = maxf(w, font.get_string_size(str((r as Dictionary)["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		w += 26.0
		var bx := rect.position.x + gw * (float(_hover) + 0.5) + 14.0
		if bx + w > size.x:
			bx = rect.position.x + gw * (float(_hover) + 0.5) - 14.0 - w
		var h := 28.0 + 15.0 * rows.size()
		draw_rect(Rect2(bx, rect.position.y + 4.0, w, h), Color("#1C2636", 0.94), true)
		draw_string(font, Vector2(bx + 9, rect.position.y + 20.0), str(groups[_hover]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9AA8BD"))
		var ty := rect.position.y + 36.0
		for r2 in rows:
			draw_rect(Rect2(bx + 8, ty - 8, 8, 8), (r2 as Dictionary)["c"])
			draw_string(font, Vector2(bx + 20, ty), str((r2 as Dictionary)["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E8EEF7"))
			ty += 15.0
