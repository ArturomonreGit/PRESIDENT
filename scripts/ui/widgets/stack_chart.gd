class_name StackChart
extends Control
## Áreas apiladas en el tiempo (composición: gasto por ministerio, sectores del PIB, reparto del voto…).
## items = [{id, name, color, values:[float]}] (mismo número de valores); x_labels opcional; en modo `normalize` cada punto suma 100.

var items: Array = []:
	set(v):
		items = v
		queue_redraw()
var x_labels: Array = []
var normalize := false
var value_fmt := "%.0f"
var markers: Array = []
var _hover := -1

func _init() -> void:
	custom_minimum_size = Vector2(300, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func() -> void:
		_hover = -1
		queue_redraw())

func _plot() -> Rect2:
	return Rect2(Vector2(46, 8), Vector2(maxf(10.0, size.x - 46 - 150), maxf(10.0, size.y - 8 - 24)))

func _n() -> int:
	var n := 0
	for it in items:
		n = maxi(n, ((it as Dictionary).get("values", []) as Array).size())
	return n

func _totals() -> Array:
	var n := _n()
	var out: Array = []
	for i in range(n):
		var t := 0.0
		for it in items:
			var vals: Array = (it as Dictionary).get("values", [])
			if i < vals.size():
				t += maxf(0.0, float(vals[i]))
		out.append(t)
	return out

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var rect := _plot()
	var n := _n()
	if n < 2:
		return
	var px := (event as InputEventMouseMotion).position.x
	var idx := clampi(int(round((px - rect.position.x) / rect.size.x * float(n - 1))), 0, n - 1)
	if px < rect.position.x - 4.0 or px > rect.end.x + 4.0:
		idx = -1
	if idx != _hover:
		_hover = idx
		queue_redraw()

func _draw() -> void:
	var rect := _plot()
	var font := UI.regular_font()
	var n := _n()
	if n < 2 or items.is_empty():
		draw_string(font, rect.position + Vector2(rect.size.x * 0.5 - 70, rect.size.y * 0.5), "Sin datos suficientes todavía", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
		return
	var totals := _totals()
	var ymax := 0.0
	for t in totals:
		ymax = maxf(ymax, float(t))
	if normalize:
		ymax = 100.0
	ymax = maxf(0.001, ymax * (1.0 if normalize else 1.06))
	for i in range(5):
		var f := float(i) / 4.0
		var y := rect.position.y + rect.size.y * (1.0 - f)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(UI.BORDER, 0.6), 1.0)
		draw_string(font, Vector2(2, y + 4), value_fmt % (ymax * f), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.FAINT)
	# Capas (de abajo arriba)
	var base: Array = []
	base.resize(n)
	base.fill(0.0)
	for it in items:
		var d: Dictionary = it
		var vals: Array = d.get("values", [])
		var col: Color = d.get("color", UI.ACCENT)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in range(n):
			var v := maxf(0.0, float(vals[i])) if i < vals.size() else 0.0
			var tot := maxf(0.0001, float(totals[i]))
			var vv := v / tot * 100.0 if normalize else v
			var x := rect.position.x + rect.size.x * float(i) / float(n - 1)
			var y0 := rect.position.y + rect.size.y * (1.0 - float(base[i]) / ymax)
			var y1 := rect.position.y + rect.size.y * (1.0 - (float(base[i]) + vv) / ymax)
			bot.append(Vector2(x, y0))
			top.append(Vector2(x, y1))
			base[i] = float(base[i]) + vv
		var poly := PackedVector2Array(top)
		for k in range(bot.size() - 1, -1, -1):
			poly.append(bot[k])
		draw_colored_polygon(poly, Color(col, 0.88))
		draw_polyline(top, col.darkened(0.15), 1.0, true)
	# Eje x
	if x_labels.size() >= 2:
		var prev := ""
		var last_x := -100.0
		var marks: Array = []
		for i in range(x_labels.size()):
			var lb := str(x_labels[i])
			if lb != prev:
				marks.append(i)
				prev = lb
		var stride := maxi(1, int(ceil(float(marks.size()) / 8.0)))
		for k in range(0, marks.size(), stride):
			var idx := int(marks[k])
			var x := rect.position.x + rect.size.x * float(idx) / float(maxi(1, n - 1))
			if x - last_x < 44.0:
				continue
			last_x = x
			draw_string(font, Vector2(x - 14, rect.end.y + 16), str(x_labels[idx]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.FAINT)
	for mk in markers:
		var mx := rect.position.x + rect.size.x * float(int((mk as Dictionary)["i"])) / float(maxi(1, n - 1))
		var my := rect.position.y
		while my < rect.end.y:
			draw_line(Vector2(mx, my), Vector2(mx, minf(my + 3.0, rect.end.y)), Color(1, 1, 1, 0.8), 1.0)
			my += 7.0
	# Leyenda a la derecha, en el orden de apilado (arriba = último)
	var ly := rect.position.y + 4.0
	for k2 in range(items.size() - 1, -1, -1):
		var d2: Dictionary = items[k2]
		draw_rect(Rect2(rect.end.x + 12, ly, 10, 10), d2.get("color", UI.ACCENT))
		var vals2: Array = d2.get("values", [])
		var cur := float(vals2[vals2.size() - 1]) if not vals2.is_empty() else 0.0
		draw_string(font, Vector2(rect.end.x + 27, ly + 9), "%s  %s" % [str(d2.get("name", "")), value_fmt % (cur / maxf(0.0001, float(totals[n - 1])) * 100.0 if normalize else cur)], HORIZONTAL_ALIGNMENT_LEFT, 120, 10, UI.TEXT)
		ly += 15.0
	if _hover >= 0 and _hover < n:
		var x2 := rect.position.x + rect.size.x * float(_hover) / float(n - 1)
		draw_line(Vector2(x2, rect.position.y), Vector2(x2, rect.end.y), Color(UI.TEXT, 0.5), 1.0)
		var lines: Array = []
		var head := str(x_labels[_hover]) if _hover < x_labels.size() else ""
		for k3 in range(items.size() - 1, -1, -1):
			var d3: Dictionary = items[k3]
			var vals3: Array = d3.get("values", [])
			if _hover < vals3.size():
				var v3 := float(vals3[_hover])
				lines.append({"t": "%s  %s" % [str(d3.get("name", "")), value_fmt % (v3 / maxf(0.0001, float(totals[_hover])) * 100.0 if normalize else v3)], "c": d3.get("color", UI.ACCENT)})
		var w := 0.0
		for l in lines:
			w = maxf(w, font.get_string_size(str((l as Dictionary)["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		w = maxf(w, font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 22.0
		var h := 12.0 + (16.0 if head != "" else 0.0) + 15.0 * lines.size()
		var bx := x2 + 12.0
		if bx + w > size.x - 2.0:
			bx = x2 - 12.0 - w
		draw_rect(Rect2(bx, rect.position.y + 4.0, w, h), Color("#1C2636", 0.94), true)
		var ty := rect.position.y + 18.0
		if head != "":
			draw_string(font, Vector2(bx + 9, ty), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9AA8BD"))
			ty += 16.0
		for l2 in lines:
			draw_rect(Rect2(bx + 8, ty - 8, 8, 8), (l2 as Dictionary)["c"])
			draw_string(font, Vector2(bx + 20, ty), str((l2 as Dictionary)["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E8EEF7"))
			ty += 15.0
