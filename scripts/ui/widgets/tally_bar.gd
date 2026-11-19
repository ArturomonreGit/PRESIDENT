class_name TallyBar
extends Control
## Barra de recuento del Pleno: tramos «a favor / abstención / en contra» que crecen animados y marca de la mayoría necesaria.

const C_YES := Color("#12875A")
const C_NO := Color("#D0384A")
const C_ABS := Color("#9AA6B8")

var yes := 0.0:
	set(v):
		yes = v
		queue_redraw()
var no := 0.0:
	set(v):
		no = v
		queue_redraw()
var abst := 0.0:
	set(v):
		abst = v
		queue_redraw()
var total := 350.0
var marker := 176.0           ## escaños necesarios para aprobar
var marker_label := "176"

func _init() -> void:
	custom_minimum_size = Vector2(0, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Anima el recuento hacia nuevos valores.
func animate_to(y: int, n: int, a: int, dur: float = 0.45) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "yes", float(y), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "no", float(n), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "abst", float(a), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var bar_h := 16.0
	var y0 := size.y - bar_h - 2.0
	var w := size.x
	draw_rect(Rect2(0, y0, w, bar_h), Color("#DCE4EE"), true)
	var x := 0.0
	for seg in [[yes, C_YES], [abst, C_ABS], [no, C_NO]]:
		var sw := w * clampf(float(seg[0]) / total, 0.0, 1.0)
		if sw > 0.5:
			draw_rect(Rect2(x, y0, sw, bar_h), seg[1] as Color, true)
		x += sw
	# marca de mayoría
	var mx := w * clampf(marker / total, 0.0, 1.0)
	draw_rect(Rect2(mx - 1.5, y0 - 8.0, 3.0, bar_h + 12.0), Color("#1A2332"), true)
	var f := UI.regular_font()
	var tw := f.get_string_size(marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f, Vector2(clampf(mx - tw * 0.5, 0.0, w - tw), y0 - 12.0), marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
