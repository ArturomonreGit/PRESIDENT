class_name PlenaryChamber
extends Hemicycle
## Hemiciclo del Pleno: cada escaño se ilumina con el sentido del voto de su grupo (verde sí, rojo no, gris abstención).

var states: Dictionary = {}:
	set(v):
		states = v
		queue_redraw()
var flash_id := ""
var flash_t := 1.0:
	set(v):
		flash_t = v
		queue_redraw()

const C_YES := Color("#12875A")
const C_NO := Color("#D0384A")
const C_ABS := Color("#A9B3C2")

func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(360, 200)

func flash(id: String) -> void:
	flash_id = id
	flash_t = 0.0
	var tw := create_tween()
	tw.tween_property(self, "flash_t", 1.0, 0.55)

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
		var id := str(entry.get("id", ""))
		var state := str(states.get(id, "pending"))
		var col: Color = entry.get("color", Color.GRAY)
		match state:
			"yes": col = C_YES
			"no": col = C_NO
			"abstain": col = C_ABS
			_: col = Color(col.r, col.g, col.b, 0.38)
		var r := dot
		if id == flash_id and flash_t < 1.0:
			r = dot * (1.0 + 0.7 * (1.0 - flash_t))
		for k in range(int(entry.get("seats", 0))):
			if idx >= positions.size():
				break
			var p: Dictionary = positions[idx]
			var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
			draw_circle(pos, r, col)
			idx += 1
	var font := UI.regular_font()
	if center_title != "":
		var fs := 26 if center_title.length() <= 5 else 16
		var tw := UI.bold_font().get_string_size(center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UI.bold_font(), origin + Vector2(-tw * 0.5, -inner * 0.38), center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
	if center_sub != "":
		var tw2 := font.get_string_size(center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, origin + Vector2(-tw2 * 0.5, -inner * 0.38 + 18), center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
