class_name VoteBar
extends Control
## Barra de aritmética parlamentaria: escaños a favor, abstención y en contra por partido, con la línea de la mayoría.

var segments: Array = []   # {id, seats, color, state: yes|abstain|no, name}
var total := 350
var marker := 176

func _init() -> void:
	custom_minimum_size = Vector2(0, 72)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_data(segs: Array, majority: int = 176, seats_total: int = 350) -> void:
	segments = segs
	marker = majority
	total = seats_total
	queue_redraw()

func _draw() -> void:
	var h := 26.0
	var y := 16.0
	var w := size.x
	draw_rect(Rect2(0, y, w, h), Color("#E3E8F0"))
	var order := ["yes", "abstain", "no"]
	var x := 0.0
	for st in order:
		for s in segments:
			var sd: Dictionary = s
			if str(sd.get("state", "abstain")) != st:
				continue
			var seats := int(sd.get("seats", 0))
			if seats <= 0:
				continue
			var sw := w * float(seats) / float(total)
			var col: Color = sd.get("color", Color.GRAY)
			var alpha := 1.0 if st == "yes" else (0.5 if st == "abstain" else 0.28)
			draw_rect(Rect2(x, y, maxf(sw - 1.0, 1.0), h), Color(col.darkened(0.08), alpha))
			if sw >= 30.0:
				TV.text_tl(self, str(sd.get("name", "")), Vector2(x + 4.0, y + 5.0), 11, Color.WHITE if st == "yes" else UI.TEXT, true, HORIZONTAL_ALIGNMENT_LEFT, sw - 6.0)
			x += sw
		x += 0.0
	# Marca de mayoría absoluta
	var mx := w * float(marker) / float(total)
	draw_rect(Rect2(mx - 1.0, y - 8.0, 2.0, h + 16.0), Color("#C99A12"))
	TV.text_tl(self, "%d" % marker, Vector2(mx + 5.0, 0.0), 11, Color("#C99A12"))
	# Totales por estado
	var tally := {"yes": 0, "abstain": 0, "no": 0}
	for s in segments:
		var sd2: Dictionary = s
		tally[str(sd2.get("state", "abstain"))] = int(tally.get(str(sd2.get("state", "abstain")), 0)) + int(sd2.get("seats", 0))
	var lx := 0.0
	for pair in [["yes", "A favor", UI.GOOD], ["abstain", "Abstención", UI.MUTED], ["no", "En contra", UI.BAD]]:
		var txt := "%s %d" % [str(pair[1]), int(tally[str(pair[0])])]
		TV.text_tl(self, txt, Vector2(lx, y + h + 6.0), 12, pair[2] as Color)
		lx += TV.text_w(txt, 12) + 20.0
