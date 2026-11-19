class_name NightTopBar
extends Control
## Barra superior: ÚLTIMA HORA (titulares y avisos que entran deslizándose), objetivo 176 y reloj de la noche.

const LABEL_W := 176.0
const RIGHT_W := 330.0

var clock_text := "20:00"
var headline := ""
var headline_t := 0.0
var items: Array = []
var live_label := "ÚLTIMA HORA"
var _shift := 0.0
var _head_age := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func push_item(segs: Array) -> void:
	items.push_front({"segs": segs})
	while items.size() > 10:
		items.pop_back()
	_shift = -(TV.rich_width(segs, 16) + 30.0)

func show_headline(text: String, seconds: float = 7.0) -> void:
	headline = text
	headline_t = seconds
	_head_age = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_shift = lerpf(_shift, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	if absf(_shift) < 0.5:
		_shift = 0.0
	if headline_t > 0.0:
		headline_t -= delta
		_head_age += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), TV.PANEL)
	draw_rect(Rect2(0, h - 1, w, 1), TV.LINE)
	# Rótulo rojo
	draw_rect(Rect2(0, 0, LABEL_W, h), TV.RED)
	TV.text_tl(self, live_label, Vector2(0, (h - TV.font_h(16)) * 0.5), 16, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, LABEL_W)
	# Zona derecha: objetivo + TV + reloj
	var rx := w - RIGHT_W
	draw_rect(Rect2(rx, 0, 1, h), TV.LINE)
	TV.text_tl(self, "OBJETIVO", Vector2(rx + 18, (h - TV.font_h(15)) * 0.5), 15, TV.WHITE)
	TV.text_tl(self, str(Rules.MAJORITY), Vector2(rx + 18 + TV.text_w("OBJETIVO ", 15), (h - TV.font_h(15)) * 0.5), 15, TV.TEAL)
	TV.rrect(self, Rect2(rx + 150, (h - 22) * 0.5, 34, 22), TV.RED, 4.0)
	TV.text_tl(self, "TV", Vector2(rx + 150, (h - TV.font_h(12)) * 0.5), 12, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 34)
	TV.text_tl(self, clock_text, Vector2(rx, (h - TV.font_h(26)) * 0.5), 26, TV.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT, RIGHT_W - 18.0)
	# Zona central
	var ax := LABEL_W + 18.0
	var aw := rx - ax - 12.0
	if headline_t > 0.0 and headline != "":
		var a := clampf(minf(_head_age * 3.0, headline_t * 2.0), 0.0, 1.0)
		var txt := TV.fit(headline, 19, aw)
		TV.text_tl(self, txt, Vector2(ax + (1.0 - a) * 24.0, (h - TV.font_h(19)) * 0.5), 19, Color(TV.WHITE, a))
		return
	var x := ax + _shift
	for it in items:
		var segs: Array = (it as Dictionary)["segs"]
		var iw := TV.rich_width(segs, 16)
		if x + iw > ax + aw:
			break
		if x >= ax - 1.0:
			TV.rich_draw(self, segs, Vector2(x, 0), 16, h)
		x += iw + 30.0
