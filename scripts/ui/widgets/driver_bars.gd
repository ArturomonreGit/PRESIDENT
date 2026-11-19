class_name DriverBars
extends Control
## Barras horizontales con signo, centradas en cero: «qué empuja este indicador».
## rows = [{label, value, color, note}]. Positivo a la derecha, negativo a la izquierda.

var rows: Array = []:
	set(v):
		rows = v
		custom_minimum_size.y = maxf(30.0, float(rows.size()) * ROW_H + 4.0)
		queue_redraw()
var value_fmt := "%+.1f"
var label_w := 150.0
const ROW_H := 21.0

func _init() -> void:
	custom_minimum_size = Vector2(240, 30)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var font := UI.regular_font()
	var mx := 0.0001
	for r in rows:
		mx = maxf(mx, absf(float((r as Dictionary)["value"])))
	var left := label_w + 8.0
	var right := size.x - 52.0
	var cx := (left + right) * 0.5
	var half := (right - left) * 0.5
	draw_line(Vector2(cx, 0), Vector2(cx, size.y), Color(UI.BORDER, 0.9), 1.0)
	for i in range(rows.size()):
		var rd: Dictionary = rows[i]
		var y := 2.0 + float(i) * ROW_H
		var v := float(rd["value"])
		var col: Color = rd.get("color", UI.ACCENT)
		var w := half * absf(v) / mx
		var rect := Rect2(cx if v >= 0.0 else cx - w, y + 3.0, maxf(w, 1.0), ROW_H - 8.0)
		draw_rect(rect, col, true)
		var lbl := str(rd["label"])
		var fs := 12
		while fs > 9 and font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > label_w:
			fs -= 1
		if font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > label_w:
			while lbl.length() > 4 and font.get_string_size(lbl + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > label_w:
				lbl = lbl.substr(0, lbl.length() - 1)
			lbl += "…"
		draw_string(font, Vector2(0, y + ROW_H - 7.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, label_w, fs, UI.TEXT)
		draw_string(font, Vector2(right + 6.0, y + ROW_H - 7.0), (value_fmt % v).replace("-", "−"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col.darkened(0.15))
