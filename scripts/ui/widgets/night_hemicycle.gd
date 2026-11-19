class_name NightHemicycle
extends Hemicycle
## Hemiciclo de la noche electoral: escaños con volumen, destellos cuando cambian de partido,
## escaños pendientes en gris, línea de mayoría (176) y contador de bloques.

var left_bloc := 0
var right_bloc := 0
var counted := 0
var player_id := ""
var _cols: Array = []
var _prev: Array = []
var _flash := PackedFloat32Array()
var _positions: Array = []
var _pos_key := ""

func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(420, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

## entries = [{id, color, seats}] de izquierda a derecha; `pending` escaños sin asignar (se dibujan en el centro).
func set_data(new_entries: Array, pending: int, left: int, right: int) -> void:
	left_bloc = left
	right_bloc = right
	var list: Array = []
	var inserted := false
	var half := 0
	var total := 0
	for e in new_entries:
		total += int((e as Dictionary).get("seats", 0))
	for e in new_entries:
		var ed: Dictionary = e
		if not inserted and pending > 0 and half * 2 >= total:
			list.append({"id": "_pending", "color": TV.PENDING, "seats": pending})
			inserted = true
		list.append(ed)
		half += int(ed.get("seats", 0))
	if not inserted and pending > 0:
		list.append({"id": "_pending", "color": TV.PENDING, "seats": pending})
	counted = total
	var cols: Array = []
	for e in list:
		var ed2: Dictionary = e
		for _k in range(int(ed2.get("seats", 0))):
			cols.append(ed2["color"])
	if _flash.size() != cols.size():
		_flash.resize(cols.size())
		_flash.fill(0.0)
	for i in range(cols.size()):
		if i < _prev.size() and (_prev[i] as Color) != (cols[i] as Color):
			_flash[i] = 1.0
	_prev = cols.duplicate()
	_cols = cols
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var any := false
	for i in range(_flash.size()):
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta * 1.8)
			any = true
	if any:
		queue_redraw()

func _geometry() -> Dictionary:
	var strip := 96.0
	var outer := minf((size.x - 24.0) * 0.5, size.y - strip - 34.0)
	var inner := outer * 0.42
	var origin := Vector2(size.x * 0.5, size.y - strip)
	return {"outer": outer, "inner": inner, "origin": origin}

func _draw() -> void:
	var g := _geometry()
	var outer: float = g["outer"]
	var inner: float = g["inner"]
	var origin: Vector2 = g["origin"]
	if outer < 60.0:
		return
	var n := maxi(total_seats, 1)
	var key := "%d_%d_%d" % [n, int(outer), int(inner)]
	if key != _pos_key:
		_positions = _seat_positions(n, outer, inner)
		_pos_key = key
	var rows := clampf(round(sqrt(float(n)) * 0.46), 3.0, 12.0)
	var dot := clampf(((outer - inner) / rows) * 0.40, 2.0, 12.0)
	# Línea de mayoría
	var top_y := origin.y - outer - 18.0
	var yy := top_y + 8.0
	while yy < origin.y - inner * 0.55:
		draw_line(Vector2(origin.x, yy), Vector2(origin.x, minf(yy + 6.0, origin.y - inner * 0.55)), Color(TV.GOLD, 0.85), 2.0)
		yy += 12.0
	TV.text_tl(self, str(Rules.MAJORITY), Vector2(origin.x - 40, top_y - 12), 16, TV.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER, 80)
	for i in range(_positions.size()):
		var p: Dictionary = _positions[i]
		var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
		var col: Color = TV.PENDING
		if i < _cols.size():
			col = _cols[i]
		else:
			col = Color(TV.PENDING, 0.45)
		draw_circle(pos + Vector2(0, 1.2), dot, Color(0, 0, 0, 0.35))
		draw_circle(pos, dot, col)
		draw_circle(pos + Vector2(-dot * 0.28, -dot * 0.30), dot * 0.42, Color(1, 1, 1, 0.28))
		var fl := _flash[i] if i < _flash.size() else 0.0
		if fl > 0.01:
			draw_arc(pos, dot * (1.1 + (1.0 - fl) * 1.0), 0.0, TAU, 16, Color(1, 1, 1, fl), 2.0, true)
	# Centro: escaños escrutados
	TV.text_tl(self, str(counted), Vector2(origin.x - 100, origin.y - inner * 0.62), 54, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 200)
	TV.text_tl(self, "de %d escaños" % n, Vector2(origin.x - 100, origin.y - inner * 0.62 + 56), 17, TV.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, 200)
	# Estrado de la presidencia
	var bw := 150.0
	var by := origin.y + 20.0
	draw_colored_polygon(PackedVector2Array([Vector2(origin.x - bw * 0.5, by), Vector2(origin.x + bw * 0.5, by), Vector2(origin.x + bw * 0.38, by + 38), Vector2(origin.x - bw * 0.38, by + 38)]), Color(TV.PANEL_HI, 0.95))
	draw_polyline(PackedVector2Array([Vector2(origin.x - bw * 0.5, by), Vector2(origin.x + bw * 0.5, by), Vector2(origin.x + bw * 0.38, by + 38), Vector2(origin.x - bw * 0.38, by + 38), Vector2(origin.x - bw * 0.5, by)]), TV.LINE, 1.5, true)
	TV.text_tl(self, "Presidencia", Vector2(origin.x - bw * 0.5, by + 9), 15, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, bw)
	# Bloques
	var lx := origin.x - outer * 0.62
	var rx := origin.x + outer * 0.62
	TV.text_tl(self, str(left_bloc), Vector2(lx - 110, origin.y + 6), 44, Color("#FF5A63"), true, HORIZONTAL_ALIGNMENT_CENTER, 220)
	TV.text_tl(self, "Bloque de izquierdas", Vector2(lx - 130, origin.y + 56), 16, TV.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, 260)
	TV.text_tl(self, str(right_bloc), Vector2(rx - 110, origin.y + 6), 44, Color("#4DA8FF"), true, HORIZONTAL_ALIGNMENT_CENTER, 220)
	TV.text_tl(self, "Bloque de derechas", Vector2(rx - 130, origin.y + 56), 16, TV.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, 260)
