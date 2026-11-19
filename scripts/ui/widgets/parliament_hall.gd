class_name ParliamentHall
extends Hemicycle
## Hemiciclo del Pleno, animado: cada escaño se enciende con el sentido del voto de su grupo (ola de izquierda a derecha),
## los escaños del jugador palpitan mientras espera votar, la previsión se tiñe con suavidad, el grupo que habla se rodea con
## un aro, y al cerrar la votación cae un sello (APROBADA / RECHAZADA) con confeti o temblor.

const C_YES := Color("#12875A")
const C_NO := Color("#D0384A")
const C_ABS := Color("#9AA6B8")
const C_GOLD := Color("#F5B93A")

var votes: Dictionary = {}                ## id → voto ya revelado
var forecast: Dictionary = {}             ## id → voto previsto (tinte suave)
var player_id := ""
var pulse_id := ""                        ## grupo que palpita (el jugador, esperando su voto)
var speaker_id := ""                      ## grupo que está hablando ahora
var stamp := ""
var stamp_col := C_YES
var stamp_p := 0.0:
	set(v):
		stamp_p = v
		queue_redraw()
var shake := 0.0:
	set(v):
		shake = v
		queue_redraw()
var clock := 0.0
var _reveal_at: Dictionary = {}
var _parts: Array = []
var _hover_id := ""
var _cache_pos: Array = []
var _cache_key := Vector2.ZERO

func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(560, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)

func reset() -> void:
	votes = {}
	forecast = {}
	_reveal_at = {}
	_parts = []
	stamp = ""
	stamp_p = 0.0
	speaker_id = ""
	pulse_id = ""
	shake = 0.0
	queue_redraw()

## Revela el voto de un grupo (sus escaños se encienden en ola).
func reveal(id: String, vote: String, silent: bool = false) -> void:
	votes[id] = vote
	_reveal_at[id] = -10.0 if silent else clock
	if not silent:
		speaker_id = id
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_callback(_clear_speaker.bind(id))
	queue_redraw()

func _clear_speaker(id: String) -> void:
	if speaker_id == id:
		speaker_id = ""
		queue_redraw()

func set_forecast(f: Dictionary) -> void:
	forecast = f.duplicate()
	queue_redraw()

## Sello final con confeti (aprobada) o temblor (rechazada).
func celebrate(text: String, passed: bool) -> void:
	stamp = text
	stamp_col = C_YES if passed else C_NO
	stamp_p = 0.0
	var tw := create_tween()
	tw.tween_property(self, "stamp_p", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if passed:
		_burst(90)
	else:
		shake = 1.0
		var tw2 := create_tween()
		tw2.tween_property(self, "shake", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _burst(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var origin := Vector2(size.x * 0.5, size.y * 0.55)
	for i in range(n):
		var ang := rng.randf_range(-PI * 0.95, -PI * 0.05)
		var sp := rng.randf_range(120.0, 420.0)
		_parts.append({"p": origin, "v": Vector2(cos(ang), sin(ang)) * sp, "life": rng.randf_range(1.0, 1.9), "age": 0.0,
			"c": [C_YES, C_GOLD, Color("#4DA8FF"), Color("#FFFFFF")][rng.randi() % 4], "r": rng.randf_range(2.0, 4.6)})

func _animating() -> bool:
	if pulse_id != "" or speaker_id != "" or not _parts.is_empty() or stamp_p < 1.0 and stamp != "":
		return true
	for id in _reveal_at.keys():
		if clock - float(_reveal_at[id]) < 1.1:
			return true
	return false

func _process(delta: float) -> void:
	clock += delta
	var i := _parts.size() - 1
	while i >= 0:
		var pt: Dictionary = _parts[i]
		pt["age"] = float(pt["age"]) + delta
		var v: Vector2 = pt["v"]
		v.y += 520.0 * delta
		pt["v"] = v
		pt["p"] = (pt["p"] as Vector2) + v * delta
		if float(pt["age"]) >= float(pt["life"]):
			_parts.remove_at(i)
		i -= 1
	if _animating() or not forecast.is_empty():
		queue_redraw()

func _layout() -> Dictionary:
	var margin := 10.0
	var outer := minf((size.x - margin * 2.0) * 0.5, size.y - margin - 14.0)
	var inner := outer * 0.4
	var origin := Vector2(size.x * 0.5, size.y - margin)
	var total := 0
	for e in entries:
		total += int((e as Dictionary).get("seats", 0))
	return {"outer": outer, "inner": inner, "origin": origin, "total": total}

func _positions(total: int, outer: float, inner: float) -> Array:
	var key := Vector2(float(total) * 1000.0 + outer, inner)
	if key != _cache_key or _cache_pos.is_empty():
		_cache_key = key
		_cache_pos = _seat_positions(total, outer, inner)
	return _cache_pos

func _vote_color(v: String) -> Color:
	match v:
		"yes": return C_YES
		"no": return C_NO
	return C_ABS

func _draw() -> void:
	var lay := _layout()
	var total: int = lay["total"]
	var outer: float = lay["outer"]
	if total <= 0 or outer < 40.0:
		return
	var inner: float = lay["inner"]
	var origin: Vector2 = lay["origin"]
	if shake > 0.0:
		origin += Vector2(sin(clock * 60.0) * 7.0 * shake, 0.0)
	var positions := _positions(total, outer, inner)
	var rows_gap := (outer - inner) / clampf(round(sqrt(float(total)) * 0.46), 3.0, 12.0)
	var dot := clampf(rows_gap * 0.44, 2.5, 13.0)
	var idx := 0
	var beat := 0.5 + 0.5 * sin(clock * 5.0)
	for e in entries:
		var entry: Dictionary = e
		var id := str(entry.get("id", ""))
		var seats := int(entry.get("seats", 0))
		var base: Color = entry.get("color", Color.GRAY)
		var pend := Color(base.r, base.g, base.b, 0.5)
		var voted := votes.has(id)
		var t0 := float(_reveal_at.get(id, -10.0))
		var fc := str(forecast.get(id, ""))
		var is_player := id == player_id
		for k in range(seats):
			if idx >= positions.size():
				break
			var p: Dictionary = positions[idx]
			var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
			var col := pend
			var r := dot
			if voted:
				var delay := float(k) / maxf(1.0, float(seats)) * 0.6
				var pr := clampf((clock - t0 - delay) / 0.3, 0.0, 1.0)
				col = pend.lerp(_vote_color(str(votes[id])), pr)
				col.a = lerpf(0.5, 1.0, pr)
				r = dot * (1.0 + 0.7 * sin(pr * PI))
			elif fc != "":
				col = Color(base.r, base.g, base.b, 0.9)
			if id == pulse_id and not voted:
				r = dot * (1.0 + 0.35 * beat)
				col = col.lerp(Color.WHITE, 0.25 * beat)
			draw_circle(pos, r, col)
			if fc != "" and not voted:
				draw_circle(pos, r * 0.46, _vote_color(fc))
			if is_player and not voted:
				draw_arc(pos, r + 1.2, 0.0, TAU, 12, Color(0.1, 0.17, 0.3, 0.55), 1.2, true)
			idx += 1
		# Aro del grupo que habla
		if id == speaker_id:
			_ring(id, origin, outer, inner, positions, dot)
	# Confeti
	for pt in _parts:
		var d: Dictionary = pt
		var a := clampf(1.0 - float(d["age"]) / float(d["life"]), 0.0, 1.0)
		var c: Color = d["c"]
		draw_circle(d["p"], float(d["r"]), Color(c.r, c.g, c.b, a))
	# Sello
	if stamp != "" and stamp_p > 0.0:
		var font := UI.bold_font()
		var fs := 54
		var tw := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sc := lerpf(1.9, 1.0, clampf(stamp_p, 0.0, 1.0))
		var ctr := origin + Vector2(0.0, -inner * 0.52)
		draw_set_transform(ctr, -0.09, Vector2(sc, sc))
		var box := Rect2(Vector2(-tw * 0.5 - 22.0, -fs * 0.5 - 14.0), Vector2(tw + 44.0, fs + 22.0))
		var a2 := clampf(stamp_p * 1.6, 0.0, 1.0)
		draw_rect(box, Color(1, 1, 1, 0.82 * a2), true)
		draw_rect(box, Color(stamp_col.r, stamp_col.g, stamp_col.b, a2), false, 5.0)
		draw_string(font, Vector2(-tw * 0.5, fs * 0.34), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(stamp_col.r, stamp_col.g, stamp_col.b, a2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif center_title != "":
		var f2 := UI.bold_font()
		var fs2 := 34 if center_title.length() <= 6 else 20
		var tw2 := f2.get_string_size(center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(f2, origin + Vector2(-tw2 * 0.5, -inner * 0.42), center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, UI.TEXT)
		if center_sub != "":
			var f3 := UI.regular_font()
			var tw3 := f3.get_string_size(center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(f3, origin + Vector2(-tw3 * 0.5, -inner * 0.42 + 22.0), center_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.MUTED)

## Aro alrededor de los escaños del grupo que habla.
func _ring(id: String, origin: Vector2, _outer: float, _inner: float, positions: Array, dot: float) -> void:
	var start := 0
	var cnt := 0
	var idx := 0
	for e in entries:
		var d: Dictionary = e
		if str(d.get("id", "")) == id:
			start = idx
			cnt = int(d.get("seats", 0))
			break
		idx += int(d.get("seats", 0))
	if cnt <= 0:
		return
	var pulse := 0.6 + 0.4 * sin(clock * 9.0)
	for k in range(cnt):
		if start + k >= positions.size():
			break
		var p: Dictionary = positions[start + k]
		var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
		draw_arc(pos, dot * 1.9, 0.0, TAU, 14, Color(0.1, 0.17, 0.3, 0.55 * pulse), 1.6, true)

# ---------------------------------------------------------------- ratón: quién se sienta ahí
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var lay := _layout()
	var total: int = lay["total"]
	if total <= 0:
		return
	var origin: Vector2 = lay["origin"]
	var positions := _positions(total, float(lay["outer"]), float(lay["inner"]))
	var mp: Vector2 = (event as InputEventMouseMotion).position
	var best := -1
	var bd := 1.0e9
	for i in range(positions.size()):
		var p: Dictionary = positions[i]
		var pos := origin + Vector2(cos(float(p["angle"])), -sin(float(p["angle"]))) * float(p["r"])
		var dd := pos.distance_squared_to(mp)
		if dd < bd:
			bd = dd
			best = i
	if best < 0 or bd > 400.0:
		tooltip_text = ""
		return
	var idx := 0
	for e in entries:
		var d: Dictionary = e
		var n := int(d.get("seats", 0))
		if best < idx + n:
			var id := str(d.get("id", ""))
			var v := str(votes.get(id, ""))
			var vt := {"yes": " · vota A FAVOR", "no": " · vota EN CONTRA", "abstain": " · se ABSTIENE"}
			tooltip_text = "%s · %d escaños%s" % [str(d.get("name", id)), n, str(vt.get(v, ""))]
			return
		idx += n
