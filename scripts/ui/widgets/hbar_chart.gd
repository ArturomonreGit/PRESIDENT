class_name HBarChart
extends Control
## Barras horizontales con etiqueta y valor. items = [{name, value, color, text}]. Con `diverging` admite valores negativos.

var items: Array = []:
	set(v):
		items = v
		custom_minimum_size.y = maxf(30.0, float(items.size()) * row_h + 4.0)
		queue_redraw()
var row_h := 26.0
var label_w := 200.0
var value_w := 78.0
var diverging := false
var max_value := 0.0   # 0 = automático

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	if items.is_empty():
		return
	var font := UI.regular_font()
	var bold := UI.bold_font()
	var hi := max_value
	var lo := 0.0
	if hi <= 0.0:
		for it in items:
			hi = maxf(hi, absf(float((it as Dictionary)["value"])))
	if diverging:
		for it in items:
			lo = minf(lo, float((it as Dictionary)["value"]))
	var track_x := label_w
	var track_w := maxf(40.0, size.x - label_w - value_w - 8.0)
	var neg_w := track_w * (absf(lo) / (hi + absf(lo))) if diverging and lo < 0.0 else 0.0
	var zero_x := track_x + neg_w
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var y := float(i) * row_h
		var v := float(it["value"])
		var col: Color = it.get("color", UI.ACCENT)
		draw_string(font, Vector2(0, y + row_h * 0.5 + 4.5), str(it["name"]), HORIZONTAL_ALIGNMENT_LEFT, label_w - 10.0, 12, UI.TEXT)
		var bh := row_h * 0.42
		var by := y + (row_h - bh) * 0.5
		draw_rect(Rect2(track_x, by, track_w, bh), Color(UI.BORDER, 0.55), true)
		var span := hi + absf(lo)
		var w := track_w * absf(v) / maxf(span, 0.0001)
		if diverging and v < 0.0:
			draw_rect(Rect2(zero_x - w, by, w, bh), it.get("neg_color", UI.BAD), true)
		else:
			draw_rect(Rect2(zero_x, by, maxf(w, 1.0), bh), col, true)
		var txt := str(it.get("text", "%.1f" % v))
		draw_string(bold, Vector2(track_x + track_w + 8.0, y + row_h * 0.5 + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, value_w, 12, UI.TEXT)
	if diverging and neg_w > 0.0:
		draw_line(Vector2(zero_x, 0), Vector2(zero_x, size.y), Color(UI.FAINT, 0.8), 1.0)
