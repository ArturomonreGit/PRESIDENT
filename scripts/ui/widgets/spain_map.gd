class_name SpainMap
extends Control
## Mapa de las 52 circunscripciones. `fills` = {nombre_provincia: Color}. Emite clic y hover.
## Admite geometría con varios anillos por provincia ("polygons": islas, Baleares, Canarias) y recuadros
## ("insets", p. ej. Canarias). La geometría se triangula una sola vez y se dibuja como malla.

signal province_clicked(name: String)
signal province_hovered(name: String)

var fills: Dictionary = {}:
	set(v):
		fills = v
		queue_redraw()
var selected := ""
var hover_name := ""
var tooltips: Dictionary = {}
var _provinces: Array = []
var _insets: Array = []
var _view := Vector2(920, 620)
var _geo: Dictionary = {}          # nombre -> {rings:[PackedVector2Array], mesh:ArrayMesh, bbox:Rect2, center:Vector2, tiny:bool}
var _screen_rings: Dictionary = {} # nombre -> Array[PackedVector2Array] (pantalla)
var _screen_key := Vector2.ZERO

func _init() -> void:
	custom_minimum_size = Vector2(420, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_provinces = DataStore.map_provinces()
	_insets = DataStore.map_insets()
	_view = DataStore.map_view_size()
	_build_geometry()

func _build_geometry() -> void:
	_geo.clear()
	for item in _provinces:
		var prov: Dictionary = item
		var raw: Array = prov.get("polygons", [prov.get("polygon", [])])
		var rings: Array = []
		var verts := PackedVector2Array()
		var idx := PackedInt32Array()
		var bbox := Rect2()
		var first := true
		for r in raw:
			var ring := PackedVector2Array()
			for p in r:
				ring.append(Vector2(float(p[0]), float(p[1])))
			if ring.size() < 3:
				continue
			rings.append(ring)
			for v in ring:
				bbox = Rect2(v, Vector2.ZERO) if first else bbox.expand(v)
				first = false
			var tri := Geometry2D.triangulate_polygon(ring)
			if tri.is_empty():
				# anillo autointersecado tras simplificar: se usa su casco convexo como último recurso
				var hull := Geometry2D.convex_hull(ring)
				if hull.size() > 3:
					hull.remove_at(hull.size() - 1)
				tri = Geometry2D.triangulate_polygon(hull)
				var base0 := verts.size()
				verts.append_array(hull)
				for i in tri:
					idx.append(base0 + i)
				continue
			var base := verts.size()
			verts.append_array(ring)
			for i in tri:
				idx.append(base + i)
		var mesh: ArrayMesh = null
		if idx.size() >= 3:
			mesh = ArrayMesh.new()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_INDEX] = idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var c: Array = prov.get("center", [0, 0])
		_geo[str(prov["name"])] = {"rings": rings, "mesh": mesh, "bbox": bbox,
			"center": Vector2(float(c[0]), float(c[1])), "tiny": bool(prov.get("tiny", false))}

func _transform() -> Dictionary:
	var sc := minf(size.x / _view.x, size.y / _view.y)
	var off := (size - _view * sc) * 0.5
	return {"scale": sc, "offset": off}

func _to_screen(p: Array, tr: Dictionary) -> Vector2:
	return Vector2(float(p[0]), float(p[1])) * float(tr["scale"]) + (tr["offset"] as Vector2)

## Anillo principal de la provincia en coordenadas de pantalla (compatibilidad).
func _poly(prov: Dictionary, tr: Dictionary) -> PackedVector2Array:
	var rs := _rings(str(prov["name"]), tr)
	return rs[0] if not rs.is_empty() else PackedVector2Array()

## Todos los anillos de la provincia en coordenadas de pantalla (con caché por tamaño).
func _rings(pname: String, tr: Dictionary) -> Array:
	var key := size
	if key != _screen_key:
		_screen_rings.clear()
		_screen_key = key
	if _screen_rings.has(pname):
		return _screen_rings[pname]
	var out: Array = []
	var g: Dictionary = _geo.get(pname, {})
	var sc := float(tr["scale"])
	var off: Vector2 = tr["offset"]
	for ring in g.get("rings", []):
		var pts := PackedVector2Array()
		for v in (ring as PackedVector2Array):
			pts.append(v * sc + off)
		out.append(pts)
	_screen_rings[pname] = out
	return out

func _mesh_transform(tr: Dictionary) -> Transform2D:
	var sc := float(tr["scale"])
	return Transform2D(0.0, Vector2(sc, sc), 0.0, tr["offset"] as Vector2)

## Dibuja una provincia: relleno (malla), contorno y marcador si es diminuta.
func _paint_province(pname: String, col: Color, tr: Dictionary, line_col: Color, line_w: float) -> void:
	var g: Dictionary = _geo.get(pname, {})
	if g.is_empty():
		return
	if g["mesh"] != null:
		draw_mesh(g["mesh"], null, _mesh_transform(tr), col)
	for pts in _rings(pname, tr):
		var closed: PackedVector2Array = (pts as PackedVector2Array).duplicate()
		closed.append(pts[0])
		draw_polyline(closed, line_col, line_w, true)
	if g["tiny"]:
		var c: Vector2 = (g["center"] as Vector2) * float(tr["scale"]) + (tr["offset"] as Vector2)
		draw_circle(c, 6.0, col)
		draw_arc(c, 6.0, 0.0, TAU, 20, line_col, line_w + 0.4, true)

func _draw_insets(tr: Dictionary) -> void:
	for item in _insets:
		var inset: Dictionary = item
		var r: Array = inset.get("rect", [0, 0, 0, 0])
		var sc := float(tr["scale"])
		var rect := Rect2(Vector2(float(r[0]), float(r[1])) * sc + (tr["offset"] as Vector2), Vector2(float(r[2]), float(r[3])) * sc)
		draw_rect(rect, Color(UI.TEXT, 0.05), true)
		draw_rect(rect, Color(UI.TEXT, 0.28), false, 1.0)
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, rect.position + Vector2(6, 14), str(inset.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.TEXT, 0.55))

func _draw() -> void:
	var tr := _transform()
	_draw_insets(tr)
	for item in _provinces:
		var name := str((item as Dictionary)["name"])
		var is_sel := name == selected
		var col: Color = fills.get(name, Color("#C9D2DF"))
		if name == hover_name:
			col = col.lightened(0.18)
		_paint_province(name, col, tr, UI.TEXT if is_sel else Color(1, 1, 1, 0.95), 2.0 if is_sel else 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _hit((event as InputEventMouseMotion).position)
		if hit != hover_name:
			hover_name = hit
			tooltip_text = str(tooltips.get(hit, hit)) if hit != "" else ""
			province_hovered.emit(hit)
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var hit2 := _hit((event as InputEventMouseButton).position)
		if hit2 != "":
			selected = hit2
			province_clicked.emit(hit2)
			queue_redraw()

func _hit(pos: Vector2) -> String:
	var tr := _transform()
	var sc := float(tr["scale"])
	var vp := (pos - (tr["offset"] as Vector2)) / maxf(sc, 0.0001)
	# provincias diminutas (Ceuta, Melilla): círculo de 9 px alrededor del centro
	for item in _provinces:
		var n := str((item as Dictionary)["name"])
		var g: Dictionary = _geo.get(n, {})
		if g.is_empty():
			continue
		if g["tiny"] and ((g["center"] as Vector2).distance_to(vp) * sc) <= 9.0:
			return n
	for item in _provinces:
		var n2 := str((item as Dictionary)["name"])
		var g2: Dictionary = _geo.get(n2, {})
		if g2.is_empty() or not (g2["bbox"] as Rect2).grow(2.0).has_point(vp):
			continue
		for ring in g2["rings"]:
			if Geometry2D.is_point_in_polygon(vp, ring):
				return n2
	return ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover_name != "":
		hover_name = ""
		queue_redraw()
