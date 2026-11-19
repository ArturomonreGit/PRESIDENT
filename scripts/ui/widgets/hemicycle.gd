class_name Hemicycle
extends Control
## Hemiciclo de escaños. `entries` = [{id, color, seats}] en orden de izquierda a derecha.
## Si `highlight` no está vacío, los partidos que no están en él se atenúan.

var entries: Array = []:
	set(v):
		entries = v
		queue_redraw()
var highlight: Array = []:
	set(v):
		highlight = v
		queue_redraw()
var total_seats := 350
var majority := 176
var center_title := ""
var center_sub := ""

func _init() -> void:
	custom_minimum_size = Vector2(300, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_center(title: String, sub: String) -> void:
	center_title = title
	center_sub = sub
	queue_redraw()

func _seat_positions(n: int, outer: float, inner: float) -> Array:
	var rows := clampi(int(round(sqrt(float(n)) * 0.46)), 3, 12)
	var radii: Array = []
	for i in range(rows):
		radii.append(inner + (outer - inner) * (float(i) + 0.5) / float(rows))
	var sum_r := 0.0
	for r in radii:
		sum_r += float(r)
	var counts: Array = []
	var assigned := 0
	for i in range(rows):
		var c := int(round(float(n) * float(radii[i]) / sum_r))
		counts.append(c)
		assigned += c
	counts[rows - 1] = int(counts[rows - 1]) + (n - assigned)
	var seats: Array = []
	for i in range(rows):
		var cnt: int = counts[i]
		for j in range(cnt):
			var t := (float(j) + 0.5) / float(cnt)
			seats.append({"angle": PI * (1.0 - t), "r": float(radii[i])})
	# Orden de izquierda (ángulo π) a derecha (ángulo 0).
	seats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["angle"]) - float(b["angle"])) > 0.0001:
			return float(a["angle"]) > float(b["angle"])
		return float(a["r"]) < float(b["r"]))
	return seats

func _draw() -> void:
	var total := 0
	for e in entries:
		total += int((e as Dictionary).get("seats", 0))
	if total <= 0:
		return
	var margin := 8.0
	var outer := minf((size.x - margin * 2.0) * 0.5, size.y - margin - 4.0)
	if outer < 40.0:
		return
	var inner := outer * 0.42
	var origin := Vector2(size.x * 0.5, size.y - margin)
	var positions := _seat_positions(total, outer, inner)
	var rows_gap := (outer - inner) / clampf(round(sqrt(float(total)) * 0.46), 3.0, 12.0)
	var dot := clampf(rows_gap * 0.42, 2.0, 11.0)
	var idx := 0
	for e in entries:
		var entry: Dictionary = e
		var col: Color = entry.get("color", Color.GRAY)
		var dim := not highlight.is_empty() and not highlight.has(str(entry.get("id", "")))
		if dim:
			col = Color(col.r, col.g, col.b, 0.22)
		for k in range(int(entry.get("seats", 0))):
			if idx >= positions.size():
				break
			var p: Dictionary = positions[idx]
			var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
			draw_circle(pos, dot, col)
			idx += 1
	# Marca de mayoría absoluta
	var font := UI.regular_font()
	if center_title != "":
		var fs := 26
		var tw := font.get_string_size(center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UI.bold_font(), origin + Vector2(-tw * 0.5, -inner * 0.38), center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
	if center_sub != "":
		var fs2 := 11
		var tw2 := font.get_string_size(center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(font, origin + Vector2(-tw2 * 0.5, -inner * 0.38 + 18), center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, UI.MUTED)
