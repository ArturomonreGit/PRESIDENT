class_name NightMap
extends SpainMap
## Mapa del escrutinio: las provincias cambian de color con una transición suave y las que "vuelcan"
## parpadean. Gris = sin datos; color apagado = recuento en curso; color pleno = ganador anunciado.

var target: Dictionary = {}
var pulse: Dictionary = {}
var emphasis: Array = []
var _shown: Dictionary = {}

func set_target(colors: Dictionary) -> void:
	target = colors

func flash(prov_name: String) -> void:
	pulse[prov_name] = 1.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var changed := false
	for k in target.keys():
		var tc: Color = target[k]
		var cur: Color = _shown.get(k, TV.PENDING)
		if cur != tc:
			var nc := cur.lerp(tc, clampf(delta * 7.0, 0.0, 1.0))
			if absf(nc.r - tc.r) + absf(nc.g - tc.g) + absf(nc.b - tc.b) < 0.01:
				nc = tc
			_shown[k] = nc
			changed = true
	for k in pulse.keys():
		pulse[k] = maxf(0.0, float(pulse[k]) - delta * 0.45)
		if float(pulse[k]) <= 0.0:
			pulse.erase(k)
		changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	var tr := _transform()
	var t := Time.get_ticks_msec() / 1000.0
	_draw_insets(tr)
	var later: Array = []
	for item in _provinces:
		var prov: Dictionary = item
		var pname := str(prov["name"])
		var col: Color = _shown.get(pname, target.get(pname, TV.PENDING))
		if not emphasis.is_empty() and not emphasis.has(pname):
			col = col.lerp(TV.BG, 0.65)
		var pl := float(pulse.get(pname, 0.0))
		if pl > 0.0:
			col = col.lerp(Color.WHITE, 0.35 * (0.5 + 0.5 * sin(t * 12.0)) * pl)
		if pname == hover_name:
			col = col.lightened(0.18)
		_paint_province(pname, col, tr, Color(TV.BG, 0.95), 1.2)
		if pl > 0.0:
			later.append({"name": pname, "a": pl})
	for l in later:
		var a: float = clampf(float((l as Dictionary)["a"]) * 1.4, 0.0, 1.0)
		for pts in _rings(str((l as Dictionary)["name"]), tr):
			var closed: PackedVector2Array = (pts as PackedVector2Array).duplicate()
			closed.append(pts[0])
			draw_polyline(closed, Color(1, 1, 1, a), 3.0, true)
