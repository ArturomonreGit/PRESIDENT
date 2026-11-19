class_name VoteHemicycle
extends Hemicycle
## Hemiciclo de la votación de investidura: 350 escaños, uno por diputado.
## `votes` y `orders` son las cadenas reales de InvestitureVote ("y"/"n"/"a" por escaño, de izquierda a derecha);
## `revealed` cuántos escaños ya han votado. No calcula nada: solo dibuja lo que dice el modelo.
## Antes de la votación (`votes` vacío) cada escaño muestra la postura anunciada por su grupo en el centro.

const C_YES := Color("#22B573")
const C_NO := Color("#E5484D")
const C_ABS := Color("#F5C242")

var votes := "":
	set(v):
		votes = v
		queue_redraw()
var orders := "":
	set(v):
		orders = v
		queue_redraw()
var revealed := 0:
	set(v):
		revealed = clampi(v, 0, 350)
		queue_redraw()
var _seat_cols: Array = []

func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(560, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

static func vote_color(ch: String) -> Color:
	match ch:
		"y": return C_YES
		"n": return C_NO
		_: return C_ABS

func set_party_entries(list: Array) -> void:
	entries = list
	_seat_cols.clear()
	for e in list:
		var ed: Dictionary = e
		for _k in range(int(ed.get("seats", 0))):
			_seat_cols.append(ed.get("color", Color.GRAY))
	queue_redraw()

func _draw() -> void:
	var total := _seat_cols.size()
	if total <= 0:
		return
	var margin := 8.0
	var outer := minf((size.x - margin * 2.0) * 0.5, size.y - margin - 4.0)
	if outer < 40.0:
		return
	var inner := outer * 0.4
	var origin := Vector2(size.x * 0.5, size.y - margin)
	var positions := _seat_positions(total, outer, inner)
	var rows_gap := (outer - inner) / clampf(round(sqrt(float(total)) * 0.46), 3.0, 12.0)
	var dot := clampf(rows_gap * 0.46, 2.5, 12.0)
	var voting := votes.length() >= total
	for i in range(mini(total, positions.size())):
		var p: Dictionary = positions[i]
		var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
		var pc: Color = _seat_cols[i]
		if voting and i < revealed:
			draw_circle(pos, dot, pc)
			draw_circle(pos, dot * 0.68, vote_color(votes[i]))
			if i < orders.length() and orders[i] != votes[i]:
				draw_circle(pos, dot * 0.26, Color.WHITE)
			var age := revealed - i
			if age <= 7:
				draw_arc(pos, dot * (1.35 + 0.08 * float(age)), 0.0, TAU, 20, Color(1, 1, 1, 0.8 * (1.0 - float(age) / 8.0)), 1.6, true)
		elif voting:
			draw_circle(pos, dot, Color(pc, 0.30))
		else:
			draw_circle(pos, dot, pc)
			if i < orders.length():
				draw_circle(pos, dot * 0.42, vote_color(orders[i]))
	var font := UI.regular_font()
	if center_title != "":
		var fs := 44
		var tw := UI.bold_font().get_string_size(center_title, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(UI.bold_font(), origin + Vector2(-tw * 0.5, -inner * 0.42), center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TV.WHITE)
	if center_sub != "":
		var fs2 := 13
		var tw2 := font.get_string_size(center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(font, origin + Vector2(-tw2 * 0.5, -inner * 0.42 + 24), center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, TV.MUTED)
