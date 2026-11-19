class_name MeterBar
extends Control
## Barra de progreso fina con marcador opcional (p. ej. la mayoría absoluta).

var value := 0.0:
	set(v):
		value = v
		queue_redraw()
var max_value := 100.0:
	set(v):
		max_value = maxf(v, 0.0001)
		queue_redraw()
var color := Color("#4DA8FF"):
	set(v):
		color = v
		queue_redraw()
var track_color := Color("#E1E6EE")
var marker := -1.0:
	set(v):
		marker = v
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(0, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := size.y * 0.5
	var w := size.x
	draw_rect(Rect2(0, 0, w, size.y), track_color, true)
	var fill_w := w * clampf(value / max_value, 0.0, 1.0)
	if fill_w > 0.5:
		draw_rect(Rect2(0, 0, fill_w, size.y), color, true)
	if marker >= 0.0:
		var x := w * clampf(marker / max_value, 0.0, 1.0)
		draw_rect(Rect2(x - 1, -2, 2, size.y + 4), Color("#1A2332"), true)
	if r < 0.0:
		return
