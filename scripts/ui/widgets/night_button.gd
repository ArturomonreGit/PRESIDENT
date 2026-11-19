class_name NightButton
extends Control
## Botón de la retransmisión. Los iconos se dibujan (no dependen de glifos de la fuente).
## kind: play, pause, minus, plus, close, skip, text.

signal pressed

var kind := "text"
var label := ""
var active := false
var accent := TV.TEAL
var _hover := false

func _init(k: String = "text", l: String = "", w: float = 44.0) -> void:
	kind = k
	label = l
	custom_minimum_size = Vector2(w, 38)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()

func set_label(v: String) -> void:
	label = v
	queue_redraw()

func set_active(v: bool) -> void:
	active = v
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := TV.PANEL_HI if _hover else Color(TV.PANEL_HI, 0.55)
	TV.rrect(self, r, bg, 6.0, accent if active else TV.LINE, 1)
	var fg: Color = accent if active else (TV.WHITE if _hover else Color(TV.WHITE, 0.85))
	var c := size * 0.5
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -9), c + Vector2(-6, 9), c + Vector2(9, 0)]), fg)
		"pause":
			draw_rect(Rect2(c + Vector2(-7, -9), Vector2(5, 18)), fg)
			draw_rect(Rect2(c + Vector2(2, -9), Vector2(5, 18)), fg)
		"minus":
			draw_rect(Rect2(c + Vector2(-7, -1.5), Vector2(14, 3)), fg)
		"plus":
			draw_rect(Rect2(c + Vector2(-7, -1.5), Vector2(14, 3)), fg)
			draw_rect(Rect2(c + Vector2(-1.5, -7), Vector2(3, 14)), fg)
		"close":
			draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), fg, 3.0, true)
			draw_line(c + Vector2(-7, 7), c + Vector2(7, -7), fg, 3.0, true)
		"skip":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -8), c + Vector2(-9, 8), c + Vector2(3, 0)]), fg)
			draw_rect(Rect2(c + Vector2(5, -8), Vector2(4, 16)), fg)
		_:
			TV.text_tl(self, label, Vector2(0, (size.y - TV.font_h(14)) * 0.5), 14, fg, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
