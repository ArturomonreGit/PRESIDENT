class_name LeaderPortrait
extends Control
## Caricatura de un líder dibujada por código. Si existe `res://assets/portraits/<clave>.png` se usa esa imagen.
## Uso: portrait.setup(leader_dict, color_del_partido, "neutral", "clave_opcional").

var leader: Dictionary = {}
var party_color := Color("#4DA8FF")
var mood := "neutral"  # neutral, happy, angry, worried, smug
var key := ""
var framed := true
var _tex: Texture2D = null
var _tex_key := ""

func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(ch: Dictionary, col: Color, expression: String = "neutral", portrait_key: String = "") -> LeaderPortrait:
	leader = ch
	party_color = col
	mood = expression
	key = portrait_key
	_load_custom_texture()
	queue_redraw()
	return self

func set_mood(expression: String) -> void:
	if expression != mood:
		mood = expression
		queue_redraw()

func _load_custom_texture() -> void:
	if key == "" or key == _tex_key:
		return
	_tex_key = key
	_tex = null
	var path := "res://assets/portraits/%s.png" % key
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			_tex = res

# ---------------------------------------------------------------- utilidades de dibujo
func _ellipse(c: Vector2, rx: float, ry: float, n: float = 2.0, steps: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var t := TAU * float(i) / float(steps)
		var ct := cos(t)
		var st := sin(t)
		var x := signf(ct) * pow(absf(ct), 2.0 / n)
		var y := signf(st) * pow(absf(st), 2.0 / n)
		pts.append(c + Vector2(x * rx, y * ry))
	return pts

func _fill(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)

func _hex(list: Array, idx: int) -> Color:
	return Color(str(list[clampi(idx, 0, list.size() - 1)]))

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var origin := (size - Vector2(s, s)) * 0.5
	var u := func(x: float, y: float) -> Vector2: return origin + Vector2(x, y) * s
	var radius := int(s * 0.12)
	# Fondo del partido
	var bg := UI.box(party_color.darkened(0.35), Color(0, 0, 0, 0), radius, 0, 0, 0)
	draw_style_box(bg, Rect2(origin, Vector2(s, s)))
	draw_circle(u.call(0.5, 0.45), s * 0.46, Color(party_color.lightened(0.15), 0.35))
	if _tex != null:
		draw_texture_rect(_tex, Rect2(origin, Vector2(s, s)), false)
		_frame(origin, s, radius)
		return
	if leader.is_empty():
		_frame(origin, s, radius)
		return
	var a: Dictionary = leader.get("appearance", Leader.default_appearance())
	var skin := _hex(Leader.SKIN, int(a.get("skin", 1)))
	var skin_d := skin.darkened(0.18)
	var hair_c := _hex(Leader.HAIR_COLOR, int(a.get("hair_color", 1)))
	var age_look := float(a.get("age_look", 0.4))
	if age_look > 0.7:
		hair_c = hair_c.lerp(Color("#C9C2B8"), (age_look - 0.7) * 2.2)
	var feature := int(a.get("feature", 0))
	var face_shape := int(a.get("face", 0))
	var hair_style := int(a.get("hair", 1))
	var jacket := party_color.darkened(0.45)
	var cx := 0.5
	var head_c: Vector2 = u.call(cx, 0.43)
	var rx := 0.235
	var ry := 0.285
	match face_shape:
		1: rx = 0.245; ry = 0.27
		2: rx = 0.265; ry = 0.265
		3: rx = 0.215; ry = 0.31
	if feature == 5:
		rx *= 1.12
		ry *= 1.1
	var exp_n := 3.2 if face_shape == 1 else 2.2

	# ---- pelo trasero
	if hair_style == 4:  # melena
		_fill(_ellipse(u.call(cx, 0.58), s * (rx + 0.06), s * 0.34, 2.0), hair_c)
	elif hair_style == 7:  # afro
		_fill(_ellipse(u.call(cx, 0.32), s * (rx + 0.11), s * 0.30, 2.0), hair_c)
	elif hair_style == 5:  # coleta
		_fill(_ellipse(u.call(cx + rx + 0.06, 0.58), s * 0.05, s * 0.13, 2.0), hair_c)
	elif hair_style == 8:  # moño
		_fill(_ellipse(u.call(cx, 0.12), s * 0.075, s * 0.075, 2.0), hair_c)
	elif hair_style == 6:  # cresta
		_fill(PackedVector2Array([u.call(cx - 0.07, 0.24), u.call(cx - 0.04, 0.05), u.call(cx + 0.04, 0.05), u.call(cx + 0.07, 0.24)]), hair_c)

	# ---- cuerpo
	_fill(PackedVector2Array([u.call(0.06, 1.0), u.call(0.12, 0.86), u.call(0.34, 0.76), u.call(0.66, 0.76), u.call(0.88, 0.86), u.call(0.94, 1.0)]), jacket)
	_fill(PackedVector2Array([u.call(0.40, 0.755), u.call(0.60, 0.755), u.call(0.5, 0.97)]), Color("#F2F4F7"))
	var outfit := int(a.get("outfit", 0))
	if outfit != 1 and outfit != 2:
		_fill(PackedVector2Array([u.call(0.485, 0.77), u.call(0.515, 0.77), u.call(0.53, 0.93), u.call(0.5, 0.985), u.call(0.47, 0.93)]), party_color.lightened(0.1))
	if outfit == 3:
		draw_circle(u.call(0.34, 0.9), s * 0.018, party_color.lightened(0.45))
	_fill(PackedVector2Array([u.call(0.36, 0.78), u.call(0.5, 0.97), u.call(0.40, 0.995), u.call(0.30, 0.86)]), jacket.lightened(0.07))
	_fill(PackedVector2Array([u.call(0.64, 0.78), u.call(0.5, 0.97), u.call(0.60, 0.995), u.call(0.70, 0.86)]), jacket.lightened(0.07))
	# cuello
	_fill(PackedVector2Array([u.call(0.43, 0.62), u.call(0.57, 0.62), u.call(0.58, 0.79), u.call(0.5, 0.83), u.call(0.42, 0.79)]), skin_d)

	# ---- orejas
	var ear_r := 0.075 if feature == 3 else 0.042
	_fill(_ellipse(u.call(cx - rx - 0.005, 0.46), s * ear_r, s * ear_r * 1.25, 2.0, 20), skin_d)
	_fill(_ellipse(u.call(cx + rx + 0.005, 0.46), s * ear_r, s * ear_r * 1.25, 2.0, 20), skin_d)

	# ---- cabeza
	var head := _ellipse(head_c, s * rx, s * ry, exp_n)
	if feature == 2:
		for i in range(head.size()):
			if head[i].y > head_c.y + s * ry * 0.45:
				head[i].y = head_c.y + (head[i].y - head_c.y) * 1.16
				head[i].x = head_c.x + (head[i].x - head_c.x) * 0.9
	_fill(head, skin)
	draw_arc(head_c, s * rx * 0.92, 0.35, PI - 0.35, 16, Color(skin_d, 0.25), s * 0.012, true)

	# ---- pelo delantero
	match hair_style:
		0:
			draw_arc(u.call(0.42, 0.2), s * 0.07, 3.6, 5.0, 8, Color(1, 1, 1, 0.25), s * 0.012, true)
		9:
			_fill(_ellipse(u.call(cx - rx + 0.015, 0.33), s * 0.05, s * 0.095, 2.0, 16), hair_c)
			_fill(_ellipse(u.call(cx + rx - 0.015, 0.33), s * 0.05, s * 0.095, 2.0, 16), hair_c)
			_fill(_ellipse(u.call(cx, 0.17), s * 0.11, s * 0.04, 2.0, 16), hair_c)
		3:
			for i in range(9):
				var t := PI + PI * float(i) / 8.0
				draw_circle(head_c + Vector2(cos(t) * rx * 1.02, sin(t) * ry * 1.0) * s, s * 0.062, hair_c)
		7:
			_fill(_ellipse(u.call(cx, 0.22), s * (rx + 0.01), s * 0.11, 2.0), hair_c)
		6:
			_fill(_ellipse(u.call(cx, 0.22), s * (rx - 0.01), s * 0.075, 2.0), hair_c)
		2:
			_fill(_ellipse(u.call(cx - 0.02, 0.215), s * (rx + 0.01), s * 0.105, 2.0), hair_c)
			_fill(_ellipse(u.call(cx + 0.16, 0.26), s * 0.07, s * 0.06, 2.0, 16), hair_c)
		_:
			_fill(_ellipse(u.call(cx, 0.21), s * (rx + 0.005), s * 0.10, 2.0), hair_c)
			if hair_style == 4:
				_fill(_ellipse(u.call(cx - rx + 0.01, 0.4), s * 0.045, s * 0.15, 2.0, 16), hair_c)
				_fill(_ellipse(u.call(cx + rx - 0.01, 0.4), s * 0.045, s * 0.15, 2.0, 16), hair_c)
	# frente enorme: despeja un poco la línea del pelo
	if feature == 4 and hair_style != 0:
		_fill(_ellipse(u.call(cx, 0.255), s * (rx - 0.05), s * 0.045, 2.0, 20), skin)

	# ---- ojos
	var eye_t := int(a.get("eyes", 0))
	var ew := 0.052
	var eh := 0.048
	match eye_t:
		1: ew = 0.036; eh = 0.032
		2: ew = 0.05; eh = 0.026
		3: ew = 0.047; eh = 0.036
	var ey := 0.435
	for sign_x: float in [-1.0, 1.0]:
		var ec: Vector2 = u.call(cx + sign_x * 0.105, ey)
		_fill(_ellipse(ec, s * ew, s * eh, 2.0, 24), Color("#FBFBFB"))
		var look := Vector2(sign_x * -0.004, 0.003) * s
		draw_circle(ec + look, s * 0.0215, Color("#2A2220"))
		draw_circle(ec + look + Vector2(-0.006, -0.007) * s, s * 0.006, Color.WHITE)
		if eye_t == 3:
			draw_arc(ec + Vector2(0, eh * 1.25) * s * 0.0 + Vector2(0, s * eh * 1.05), s * ew * 0.85, 0.25, PI - 0.25, 12, Color(skin_d.darkened(0.2), 0.55), s * 0.01, true)
			_fill(_ellipse(ec + Vector2(0, -s * eh * 0.55), s * ew * 1.05, s * eh * 0.5, 2.0, 16), skin.darkened(0.04))
		if eye_t == 2:
			_fill(_ellipse(ec + Vector2(0, -s * eh * 0.9), s * ew * 1.1, s * eh * 0.9, 2.0, 16), skin.darkened(0.04))

	# ---- cejas
	var brow_t := int(a.get("brows", 0))
	var bw := 0.012 if brow_t == 0 else (0.024 if brow_t == 1 else 0.016)
	var tilt := 0.0
	match mood:
		"angry": tilt = 0.028
		"worried": tilt = -0.028
		"smug": tilt = 0.012
	for sign_x: float in [-1.0, 1.0]:
		var base_x := cx + sign_x * 0.105
		var inner: Vector2 = u.call(base_x - sign_x * 0.06, 0.365 + tilt * -1.0 * -1.0)
		var outer: Vector2 = u.call(base_x + sign_x * 0.06, 0.365 - tilt)
		if brow_t == 2:
			var mid: Vector2 = u.call(base_x, 0.345 - tilt * 0.3)
			draw_polyline(PackedVector2Array([inner, mid, outer]), hair_c.darkened(0.15), s * bw, true)
		else:
			draw_line(inner, outer, hair_c.darkened(0.15), s * bw, true)

	# ---- gafas
	var gl := int(a.get("glasses", 0))
	if gl > 0:
		var gcol := Color("#1D2128") if gl != 1 else Color("#3A3F48")
		var gw := 0.0125 if gl == 3 else 0.007
		for sign_x: float in [-1.0, 1.0]:
			var gc: Vector2 = u.call(cx + sign_x * 0.105, ey)
			var pts := _ellipse(gc, s * 0.074, s * (0.062 if gl == 1 else 0.052), 2.0 if gl == 1 else 3.6, 28)
			pts.append(pts[0])
			draw_polyline(pts, gcol, s * gw, true)
		draw_line(u.call(cx - 0.031, ey - 0.005), u.call(cx + 0.031, ey - 0.005), gcol, s * 0.008, true)
		draw_line(u.call(cx - 0.18, ey - 0.005), u.call(cx - 0.235, ey - 0.02), gcol, s * 0.007, true)
		draw_line(u.call(cx + 0.18, ey - 0.005), u.call(cx + 0.235, ey - 0.02), gcol, s * 0.007, true)

	# ---- nariz
	var nose_t := int(a.get("nose", 0))
	var nscale := 1.7 if feature == 1 else 1.0
	var nc: Vector2 = u.call(cx, 0.535)
	match nose_t:
		0: _fill(_ellipse(nc, s * 0.026 * nscale, s * 0.034 * nscale, 2.0, 16), skin_d.lightened(0.04))
		1: _fill(_ellipse(nc + Vector2(0, s * 0.008), s * 0.045 * nscale, s * 0.058 * nscale, 2.0, 20), skin_d.lightened(0.04))
		2:
			_fill(PackedVector2Array([nc + Vector2(-0.018, -0.06) * s * nscale, nc + Vector2(0.03, 0.01) * s * nscale, nc + Vector2(0.012, 0.05) * s * nscale, nc + Vector2(-0.034, 0.04) * s * nscale, nc + Vector2(-0.02, -0.01) * s * nscale]), skin_d.lightened(0.04))
		3: _fill(_ellipse(nc + Vector2(0, s * 0.012), s * 0.05 * nscale, s * 0.03 * nscale, 2.0, 16), skin_d.lightened(0.04))
	draw_circle(nc + Vector2(-0.016, 0.022) * s * nscale, s * 0.005, Color(skin_d.darkened(0.35), 0.8))
	draw_circle(nc + Vector2(0.016, 0.022) * s * nscale, s * 0.005, Color(skin_d.darkened(0.35), 0.8))

	# ---- boca
	var mouth_t := int(a.get("mouth", 0))
	var mc: Vector2 = u.call(cx, 0.63)
	var lip := Color("#8E3B3B") if skin.v > 0.6 else Color("#5E2323")
	var curve := 0.0
	match mood:
		"happy": curve = 0.025
		"angry": curve = -0.022
		"worried": curve = -0.012
		"smug": curve = 0.012
	match mouth_t:
		0:
			var pts2 := PackedVector2Array()
			for i in range(13):
				var t2 := float(i) / 12.0
				pts2.append(mc + Vector2(lerpf(-0.085, 0.085, t2), (sin(t2 * PI) * (0.03 + curve))) * s)
			draw_polyline(pts2, lip, s * 0.012, true)
		1:
			draw_line(mc + Vector2(-0.07, -curve * 0.6) * s, mc + Vector2(0.07, -curve * 0.6) * s, lip, s * 0.013, true)
		2:
			draw_polyline(PackedVector2Array([mc + Vector2(-0.07, 0.012) * s, mc + Vector2(0.0, 0.005) * s, mc + Vector2(0.08, -0.022 + curve * -0.5) * s]), lip, s * 0.013, true)
		3:
			var mouth := _ellipse(mc + Vector2(0, 0.01 * s), s * 0.095, s * (0.045 + maxf(curve, 0.0)), 2.0, 24)
			_fill(mouth, Color("#4A1818"))
			_fill(PackedVector2Array([mc + Vector2(-0.08, -0.012) * s, mc + Vector2(0.08, -0.012) * s, mc + Vector2(0.07, 0.014) * s, mc + Vector2(-0.07, 0.014) * s]), Color("#F8F8F8"))
		4:
			_fill(_ellipse(mc, s * 0.032, s * 0.02, 2.0, 16), lip)

	# ---- vello facial
	var facial := int(a.get("facial", 0))
	match facial:
		1:
			var beard := PackedVector2Array()
			for i in range(0, 17):
				var t3 := PI * 0.02 + (PI * 0.96) * float(i) / 16.0
				beard.append(head_c + Vector2(cos(t3) * rx * 0.99, sin(t3) * ry * 1.0 + 0.0) * s)
			var inner := PackedVector2Array()
			for i in range(16, -1, -1):
				var t4 := PI * 0.1 + (PI * 0.8) * float(i) / 16.0
				inner.append(head_c + Vector2(cos(t4) * rx * 0.72, sin(t4) * ry * 0.55 + 0.05) * s)
			_fill(beard + inner, hair_c)
		2:
			_fill(_ellipse(u.call(cx, 0.72), s * 0.05, s * 0.05, 2.0, 16), hair_c)
		3:
			draw_polyline(PackedVector2Array([mc + Vector2(-0.09, 0.0) * s - Vector2(0, 0.035 * s), mc + Vector2(0, -0.045) * s, mc + Vector2(0.09, -0.035) * s + Vector2(0, 0.0)]), hair_c, s * 0.022, true)
		4:
			var stub := PackedVector2Array()
			for i in range(0, 17):
				var t5 := PI * 0.05 + (PI * 0.9) * float(i) / 16.0
				stub.append(head_c + Vector2(cos(t5) * rx * 0.97, sin(t5) * ry * 0.97) * s)
			draw_colored_polygon(stub, Color(hair_c, 0.22)) if stub.size() >= 3 else null
	# ---- arrugas y rubor
	if age_look > 0.55:
		var wa := clampf((age_look - 0.55) * 1.6, 0.0, 0.5)
		draw_line(u.call(cx - 0.1, 0.285), u.call(cx + 0.1, 0.285), Color(skin_d.darkened(0.3), wa), s * 0.006, true)
		draw_line(u.call(cx - 0.07, 0.30), u.call(cx + 0.07, 0.30), Color(skin_d.darkened(0.3), wa), s * 0.005, true)
		draw_arc(u.call(cx - 0.13, 0.5), s * 0.06, 0.4, 1.2, 8, Color(skin_d.darkened(0.3), wa), s * 0.005, true)
		draw_arc(u.call(cx + 0.13, 0.5), s * 0.06, PI - 1.2, PI - 0.4, 8, Color(skin_d.darkened(0.3), wa), s * 0.005, true)
	draw_circle(u.call(cx - 0.16, 0.53), s * 0.034, Color(0.95, 0.4, 0.4, 0.16))
	draw_circle(u.call(cx + 0.16, 0.53), s * 0.034, Color(0.95, 0.4, 0.4, 0.16))
	_frame(origin, s, radius)

func _frame(origin: Vector2, s: float, radius: int) -> void:
	if not framed:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = party_color.lightened(0.1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, Rect2(origin, Vector2(s, s)))
