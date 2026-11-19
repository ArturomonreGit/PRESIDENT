class_name Spark
extends Control
## Mini-gráfico de tendencia (sin ejes) para tarjetas y listas.

var values: Array = []:
	set(v):
		values = v
		queue_redraw()
var color := UI.ACCENT:
	set(v):
		color = v
		queue_redraw()
var ref := NAN  ## línea de referencia (valor inicial)

func _init() -> void:
	custom_minimum_size = Vector2(70, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if values.size() < 2:
		return
	var lo := 1e9
	var hi := -1e9
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if not is_nan(ref):
		lo = minf(lo, ref)
		hi = maxf(hi, ref)
	var span := maxf(0.0001, hi - lo)
	if hi - lo < 0.0001:
		lo -= 0.5
		hi += 0.5
		span = 1.0
	var pad := 2.0
	var pts := PackedVector2Array()
	for i in range(values.size()):
		var x := pad + (size.x - 2.0 * pad) * float(i) / float(values.size() - 1)
		var y := pad + (size.y - 2.0 * pad) * (1.0 - (float(values[i]) - lo) / span)
		pts.append(Vector2(x, y))
	if not is_nan(ref):
		var ry := pad + (size.y - 2.0 * pad) * (1.0 - (ref - lo) / span)
		draw_line(Vector2(pad, ry), Vector2(size.x - pad, ry), Color(UI.FAINT, 0.5), 1.0)
	draw_polyline(pts, color, 1.8, true)
	draw_circle(pts[pts.size() - 1], 2.4, color)
