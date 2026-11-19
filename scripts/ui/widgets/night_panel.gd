class_name NightPanel
extends Control
## Columna izquierda de la retransmisión: % escrutado y clasificación de partidos en directo
## (escaños o % de voto), con filas que se reordenan y cifras que "corren" hasta su valor.

signal mode_changed(mode: String)

const ROW_H := 38.0
const HEAD_H := 78.0

var mode := "seats"
var scrut := 0.0
var player_id := ""
## [{id, name, color, seats, pct, delta}]
var rows: Array = []
var _y: Dictionary = {}
var _shown: Dictionary = {}
var _shown_pct: Dictionary = {}
var left_bloc := 0
var right_bloc := 0
var majority := 176
var lead_name := ""
var lead_seats := 0
var lead_color := Color.WHITE
var _flash: Dictionary = {}
var _prev_seats: Dictionary = {}
var _mode_t := 1.0

func _init() -> void:
	custom_minimum_size = Vector2(336, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_mode(v: String) -> void:
	if v == mode:
		return
	mode = v
	_mode_t = 0.0
	for r in rows:
		_shown[str((r as Dictionary)["id"])] = _target(r)
	mode_changed.emit(mode)

func set_rows(new_rows: Array, new_scrut: float) -> void:
	scrut = new_scrut
	for r in new_rows:
		var id := str((r as Dictionary)["id"])
		var s := int((r as Dictionary)["seats"])
		if _prev_seats.has(id) and int(_prev_seats[id]) != s:
			_flash[id] = 1.0
		_prev_seats[id] = s
	rows = new_rows

func _target(r: Dictionary) -> float:
	return float(r["seats"]) if mode == "seats" else float(r["pct"])

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var k := clampf(delta * 8.0, 0.0, 1.0)
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var id := str(r["id"])
		var ty := HEAD_H + float(i) * ROW_H
		_y[id] = lerpf(float(_y.get(id, ty + 70.0)), ty, k)
		_shown[id] = lerpf(float(_shown.get(id, 0.0)), float(r["seats"]), clampf(delta * 6.0, 0.0, 1.0))
		_shown_pct[id] = lerpf(float(_shown_pct.get(id, 0.0)), float(r["pct"]), clampf(delta * 6.0, 0.0, 1.0))
	for id in _flash.keys():
		_flash[id] = maxf(0.0, float(_flash[id]) - delta * 1.5)
	_mode_t = minf(1.0, _mode_t + delta * 3.5)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(TV.PANEL, 0.94))
	draw_rect(Rect2(w - 1.0, 0, 1.0, size.y), TV.LINE)
	TV.text_tl(self, "ESCRUTADO", Vector2(14, 14), 11, TV.MUTED)
	TV.text_tl(self, TV.pct_es(scrut) + "%", Vector2(0, 8), 28, TV.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT, w - 14.0)
	draw_rect(Rect2(14, 50, w - 28, 3), TV.LINE)
	draw_rect(Rect2(14, 50, (w - 28) * clampf(scrut / 100.0, 0.0, 1.0), 3), TV.TEAL)
	var name_w := 118.0
	var seat_w := 62.0
	var delta_w := 44.0
	var pct_x := name_w + seat_w + delta_w
	TV.text_tl(self, "PARTIDO", Vector2(14, 58), 10, TV.FAINT)
	TV.text_tl(self, "ESCAÑOS", Vector2(name_w, 58), 10, TV.TEAL, true, HORIZONTAL_ALIGNMENT_RIGHT, seat_w - 8.0)
	TV.text_tl(self, "% VOTO", Vector2(pct_x, 58), 10, TV.MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT, w - pct_x - 12.0)
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var id := str(r["id"])
		var y := float(_y.get(id, HEAD_H + float(i) * ROW_H))
		var col: Color = r["color"]
		var h := ROW_H - 4.0
		TV.rrect(self, Rect2(0, y, name_w, h), col, 0.0)
		TV.rrect(self, Rect2(name_w, y, seat_w, h), col.darkened(0.55), 0.0)
		var nm := TV.fit(str(r["name"]), 16, name_w - 18.0)
		TV.text_tl(self, nm, Vector2(11, y + (h - TV.font_h(16)) * 0.5), 16, TV.ink(col))
		var v := float(_shown.get(id, 0.0))
		TV.text_tl(self, str(int(round(v))), Vector2(name_w, y + (h - TV.font_h(21)) * 0.5), 21, TV.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT, seat_w - 8.0)
		var d := int(r.get("delta", 0))
		var dx := name_w + seat_w
		var cy := y + h * 0.5
		if d != 0:
			draw_rect(Rect2(dx, y, delta_w, h), Color.WHITE)
			if d > 0:
				TV.tri_up(self, Vector2(dx + 12, cy), 5.0, TV.UP)
			else:
				TV.tri_down(self, Vector2(dx + 12, cy), 5.0, TV.DOWN)
			TV.text_tl(self, str(absi(d)), Vector2(dx + 22, cy - TV.font_h(14) * 0.5), 14, TV.UP if d > 0 else TV.DOWN)
		var pv := float(_shown_pct.get(id, 0.0))
		TV.text_tl(self, TV.pct_es(pv) + "%", Vector2(pct_x, cy - TV.font_h(16) * 0.5), 16, TV.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT, w - pct_x - 12.0)
		draw_rect(Rect2(0, y + h, w, 1), Color(TV.LINE, 0.5))
		if str(id) == player_id:
			draw_rect(Rect2(0, y, 4, h), TV.GOLD)
		var fl := float(_flash.get(id, 0.0))
		if fl > 0.01:
			draw_rect(Rect2(0, y, name_w + seat_w, h), Color(1, 1, 1, fl * 0.45))
	_draw_race(w)

## Carrera a la mayoría absoluta: barras de bloque y del primer partido con la línea de los 176.
func _draw_race(w: float) -> void:
	var h := 168.0
	var y0 := size.y - h
	if y0 < HEAD_H + float(rows.size()) * ROW_H + 6.0:
		return
	draw_rect(Rect2(0, y0, w, 1), TV.LINE)
	TV.text_tl(self, "CARRERA A LA MAYORÍA", Vector2(14, y0 + 10), 10, TV.MUTED)
	TV.text_tl(self, str(majority), Vector2(0, y0 + 8), 14, TV.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT, w - 14.0)
	var bx := 14.0
	var bw := w - 28.0
	var items: Array = [
		["Izquierda", left_bloc, Color("#E0555F")],
		["Derecha", right_bloc, Color("#4F8BE6")],
		[str(lead_name), lead_seats, lead_color],
	]
	for k in range(items.size()):
		var it: Array = items[k]
		var yy := y0 + 34.0 + float(k) * 40.0
		TV.text_tl(self, str(it[0]), Vector2(bx, yy), 12, TV.FAINT)
		TV.text_tl(self, str(it[1]), Vector2(0, yy - 2), 16, TV.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT, w - 14.0)
		var by := yy + 18.0
		draw_rect(Rect2(bx, by, bw, 8), TV.LINE)
		draw_rect(Rect2(bx, by, bw * clampf(float(it[1]) / 350.0, 0.0, 1.0), 8), it[2])
		var mx := bx + bw * float(majority) / 350.0
		draw_rect(Rect2(mx - 1.0, by - 4.0, 2.0, 16.0), TV.GOLD)
