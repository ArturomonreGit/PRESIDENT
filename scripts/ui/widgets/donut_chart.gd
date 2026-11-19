class_name DonutChart
extends Control
## Gráfico de anillo con leyenda. items = [{name, value, color, text}]; center_title / center_sub en el hueco.

var items: Array = []:
	set(v):
		items = v
		queue_redraw()
var center_title := ""
var center_sub := ""
var show_percent := true

func _init() -> void:
	custom_minimum_size = Vector2(300, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var total := 0.0
	for it in items:
		total += maxf(0.0, float((it as Dictionary)["value"]))
	if total <= 0.0:
		return
	var font := UI.regular_font()
	var bold := UI.bold_font()
	var d := minf(size.y - 8.0, size.x * 0.46)
	var r := d * 0.5
	var c := Vector2(r + 4.0, size.y * 0.5)
	var thick := r * 0.36
	var a := -PI * 0.5
	for it in items:
		var sd: Dictionary = it
		var frac := maxf(0.0, float(sd["value"])) / total
		var a1 := a + TAU * frac
		if frac > 0.0005:
			draw_arc(c, r - thick * 0.5, a, a1 - 0.012, maxi(8, int(48.0 * frac) + 6), sd.get("color", UI.ACCENT), thick, true)
		a = a1
	if center_title != "":
		var tw := bold.get_string_size(center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(bold, c + Vector2(-tw * 0.5, 2.0), center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.TEXT)
	if center_sub != "":
		var sw := font.get_string_size(center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, c + Vector2(-sw * 0.5, 18.0), center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
	# Leyenda
	var lx := c.x + r + 20.0
	var row_h := minf(24.0, (size.y - 8.0) / float(maxi(1, items.size())))
	var y0 := size.y * 0.5 - row_h * float(items.size()) * 0.5
	for i in range(items.size()):
		var sd2: Dictionary = items[i]
		var y := y0 + float(i) * row_h
		draw_rect(Rect2(lx, y + row_h * 0.5 - 5.0, 10, 10), sd2.get("color", UI.ACCENT), true)
		var label := str(sd2["name"])
		draw_string(font, Vector2(lx + 18.0, y + row_h * 0.5 + 4.5), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - lx - 90.0, 12, UI.TEXT)
		var txt := str(sd2.get("text", "%.1f%%" % (float(sd2["value"]) / total * 100.0)))
		var tw2 := bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(bold, Vector2(size.x - tw2 - 4.0, y + row_h * 0.5 + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.TEXT)
