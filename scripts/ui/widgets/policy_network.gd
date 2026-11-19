class_name PolicyNetwork
extends Control
## Panel de gobierno en red (estilo Democracy 4): medidas en el anillo exterior, agrupadas por área; indicadores y servicios
## en el anillo medio; grupos sociales en el interior y el apoyo al Gobierno en el centro. Al pasar el ratón por un nodo se
## dibujan sus vínculos (verde = favorable, rojo = adverso). Clic = seleccionar. Con `focus_area` se amplía un área.

signal picked(kind: String, id: String)

const AREA_ORDER := ["tax", "indirect", "industry", "jobs", "family", "social", "health", "education", "science", "housing", "transport",
	"energy", "agriculture", "territory", "immigration", "justice", "security", "defense"]
## Variables centrales y servicios que actúan como nodos: id → [nombre, ámbito, sentido bueno]
const CORES := {
	"growth": ["Crecimiento", "tax", 1], "unemployment": ["Paro", "jobs", -1], "inflation": ["Inflación", "indirect", -1], "deficit": ["Déficit público", "tax", -1],
	"health": ["Sanidad", "health", 1], "education": ["Educación", "education", 1], "housing": ["Acceso a la vivienda", "housing", 1],
	"security": ["Seguridad", "security", 1], "environment": ["Medio ambiente", "energy", 1], "equality": ["Igualdad social", "social", 1],
	"infrastructure": ["Infraestructuras", "transport", 1], "innovation": ["Innovación", "science", 1],
}

var m: GameModel
var editable: Array = []          ## áreas sobre las que el jugador puede actuar
var focus_area := ""
var selected_key := ""
var marked: Dictionary = {}       ## claves con cambios pendientes (anillo azul)
var nodes: Dictionary = {}
var adj: Dictionary = {}
var wedges: Dictionary = {}       ## área → {a0, a1}
var _hover := ""
var _mouse := Vector2.ZERO

func _init() -> void:
	custom_minimum_size = Vector2(560, 560)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_exited.connect(func() -> void:
		_hover = ""
		queue_redraw())

func setup(model: GameModel, editable_areas: Array) -> void:
	m = model
	editable = editable_areas
	_build_graph()
	_layout()
	queue_redraw()

func set_focus(area_id: String) -> void:
	focus_area = area_id
	_layout()
	queue_redraw()

func select(key: String) -> void:
	selected_key = key
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and m != null:
		_layout()
		queue_redraw()

# ---------------------------------------------------------------- grafo
func _core_key(id: String) -> String:
	return "i:" + id if WorldSim.has(id) else "q:" + id

func _add_node(key: String, kind: String, id: String, area: String, label: String) -> void:
	nodes[key] = {"key": key, "kind": kind, "id": id, "area": area, "label": label, "pos": Vector2.ZERO, "r": 8.0, "shown": true}
	adj[key] = []

func _edge(a: String, b: String, w: float) -> void:
	if not nodes.has(a) or not nodes.has(b) or absf(w) < 0.0001:
		return
	(adj[a] as Array).append({"o": b, "w": w, "out": true})
	(adj[b] as Array).append({"o": a, "w": w, "out": false})

func _build_graph() -> void:
	nodes.clear()
	adj.clear()
	for it in Policies.measures():
		var md: Dictionary = it
		_add_node("p:" + str(md["id"]), "policy", str(md["id"]), str(md["area"]), str(md["name"]))
	for it2 in WorldSim.indicators():
		var d: Dictionary = it2
		_add_node("i:" + str(d["id"]), "ind", str(d["id"]), str(d["domain"]), str(d["name"]))
	for k in CORES.keys():
		_add_node("q:" + str(k), "core", str(k), str((CORES[k] as Array)[1]), str((CORES[k] as Array)[0]))
	for g in Policies.groups():
		_add_node("g:" + str((g as Dictionary)["id"]), "group", str((g as Dictionary)["id"]), "", str((g as Dictionary)["name"]))
	_add_node("c:gov", "center", "gov", "", "Apoyo al Gobierno")
	# medidas → variables y grupos
	for it3 in Policies.measures():
		var md2: Dictionary = it3
		var pk := "p:" + str(md2["id"])
		for fk in (md2.get("fx", {}) as Dictionary).keys():
			var sc := float(WorldSim.def(str(fk)).get("scale", 1.0)) if WorldSim.has(str(fk)) else (float(WorldSim.CORE_SCALE.get(str(fk), WorldSim.QUALITY_SCALE)))
			_edge(pk, _core_key(str(fk)), float(md2["fx"][fk]) / maxf(0.0001, sc))
		for hk in (md2.get("hits", {}) as Dictionary).keys():
			_edge(pk, "g:" + str(hk), float(md2["hits"][hk]) / 3.0)
	# indicadores entre sí y con las variables centrales
	for it4 in WorldSim.indicators():
		var d4: Dictionary = it4
		for lk in (d4.get("links", {}) as Dictionary).keys():
			var src := _core_key(str(lk)) if (WorldSim.has(str(lk)) or CORES.has(str(lk))) else ""
			if src != "":
				_edge(src, "i:" + str(d4["id"]), float(d4["links"][lk]) / maxf(0.0001, float(d4["scale"])))
	for ck in WorldSim.feeds().keys():
		for ik in (WorldSim.feeds()[ck] as Dictionary).keys():
			_edge("i:" + str(ik), "q:" + str(ck), float(WorldSim.feeds()[ck][ik]) / maxf(0.0001, float(WorldSim.CORE_SCALE.get(str(ck), 1.0))) * 0.6)
	# variables → grupos
	for g2 in Policies.groups():
		var gd: Dictionary = g2
		var gk := "g:" + str(gd["id"])
		for lk2 in (gd.get("likes", {}) as Dictionary).keys():
			var like := float(gd["likes"][lk2])
			if WorldSim.has(str(lk2)):
				_edge("i:" + str(lk2), gk, like / 2.0)
			elif CORES.has(str(lk2)):
				var sc2 := float(WorldSim.CORE_SCALE.get(str(lk2), WorldSim.QUALITY_SCALE))
				_edge("q:" + str(lk2), gk, like * sc2 / 3.0)
		_edge(gk, "c:gov", float(gd.get("share", 10)) / 12.0)

# ---------------------------------------------------------------- disposición
func _ellipse(c: Vector2, rx: float, ry: float, a: float) -> Vector2:
	return c + Vector2(cos(a) * rx, sin(a) * ry)

func _layout() -> void:
	if m == null or size.x < 50.0:
		return
	var c := size * 0.5
	var rx := size.x * 0.5 - 46.0
	var ry := size.y * 0.5 - 46.0
	# cuñas por área (proporcionales al número de medidas)
	var total := 0
	var counts: Dictionary = {}
	for a in AREA_ORDER:
		counts[a] = Policies.measures_of(str(a)).size()
		total += int(counts[a])
	var gap := deg_to_rad(1.6)
	var avail := TAU - gap * float(AREA_ORDER.size())
	var a_cur := -PI * 0.5
	wedges.clear()
	for a2 in AREA_ORDER:
		var span := avail * float(counts[a2]) / maxf(1.0, float(total))
		wedges[a2] = {"a0": a_cur, "a1": a_cur + span}
		a_cur += span + gap
	var big := focus_area != ""
	# medidas
	var by_area: Dictionary = {}
	for k in nodes.keys():
		var nd: Dictionary = nodes[k]
		if str(nd["kind"]) == "policy":
			if not by_area.has(nd["area"]):
				by_area[nd["area"]] = []
			(by_area[nd["area"]] as Array).append(nd)
	for a3 in by_area.keys():
		var list: Array = by_area[a3]
		var w: Dictionary = wedges.get(a3, {"a0": 0.0, "a1": 1.0})
		for i in range(list.size()):
			var nd2: Dictionary = list[i]
			if big:
				nd2["shown"] = str(a3) == focus_area
				if str(a3) == focus_area:
					var step := deg_to_rad(clampf(300.0 / float(maxi(1, list.size())), 14.0, 30.0))
					var mid := (float(w["a0"]) + float(w["a1"])) * 0.5
					var aa := mid + (float(i) - (float(list.size()) - 1.0) * 0.5) * step
					nd2["pos"] = _ellipse(c, rx - 18.0, ry - 18.0, aa)
					nd2["r"] = 25.0
			else:
				nd2["shown"] = true
				var t := (float(i) + 0.5) / float(list.size())
				var ang := lerpf(float(w["a0"]), float(w["a1"]), t)
				var off := 5.0 if i % 2 == 0 else -5.0
				var p := _ellipse(c, rx, ry, ang)
				p += (p - c).normalized() * off
				nd2["pos"] = p
				nd2["r"] = clampf(minf(rx, ry) * 0.021, 6.0, 9.5)
	# indicadores y variables centrales por ámbito
	var by_dom: Dictionary = {}
	for k2 in nodes.keys():
		var n3: Dictionary = nodes[k2]
		if str(n3["kind"]) in ["ind", "core"]:
			if not by_dom.has(n3["area"]):
				by_dom[n3["area"]] = []
			(by_dom[n3["area"]] as Array).append(n3)
	var irx := rx * (0.70 if not big else 0.64)
	var iry := ry * (0.70 if not big else 0.64)
	for d in by_dom.keys():
		var lst: Array = by_dom[d]
		lst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["kind"]) > str(b["kind"]))
		var w2: Dictionary = wedges.get(d, {"a0": 0.0, "a1": 1.0})
		var mid2 := (float(w2["a0"]) + float(w2["a1"])) * 0.5
		var span2 := (float(w2["a1"]) - float(w2["a0"])) * 0.86
		for j in range(lst.size()):
			var nd3: Dictionary = lst[j]
			var t2 := (float(j) + 0.5) / float(lst.size())
			var ang2 := mid2 - span2 * 0.5 + span2 * t2
			var off2 := 14.0 if j % 2 == 0 else -14.0
			var p2 := _ellipse(c, irx, iry, ang2)
			p2 += (p2 - c).normalized() * off2
			nd3["pos"] = p2
			nd3["r"] = clampf(minf(rx, ry) * 0.036, 11.0, 17.0)
			nd3["shown"] = true
	# grupos
	var gl: Array = []
	for k3 in nodes.keys():
		if str((nodes[k3] as Dictionary)["kind"]) == "group":
			gl.append(nodes[k3])
	for i2 in range(gl.size()):
		var ng: Dictionary = gl[i2]
		var ag := -PI * 0.5 + TAU * (float(i2) + 0.5) / float(gl.size())
		ng["pos"] = _ellipse(c, rx * 0.30, ry * 0.31, ag)
		ng["r"] = clampf(minf(rx, ry) * 0.045, 13.0, 21.0)
	var cn: Dictionary = nodes["c:gov"]
	cn["pos"] = c
	cn["r"] = clampf(minf(rx, ry) * 0.12, 30.0, 50.0)

# ---------------------------------------------------------------- estado visual
func _good_dir(nd: Dictionary) -> int:
	match str(nd["kind"]):
		"ind": return int(WorldSim.def(str(nd["id"])).get("good", 0))
		"core": return int((CORES[str(nd["id"])] as Array)[2])
		"group", "center": return 1
	return 0

func _status_col(nd: Dictionary) -> Color:
	var kind := str(nd["kind"])
	if kind == "group":
		var s := m.eco.satisfaction(str(nd["id"]))
		return UI.GOOD if s >= 55.0 else (UI.BAD if s < 40.0 else UI.WARN)
	if kind == "center":
		var a := m.gov.approval()
		return UI.GOOD if a >= 55.0 else (UI.BAD if a < 40.0 else UI.WARN)
	if kind == "policy":
		return Glyphs.area_color(str(nd["area"]))
	var z := m.world.any_z(str(nd["id"]))
	var g := _good_dir(nd)
	if g == 0:
		return UI.ACCENT
	var gv := z * float(g)
	if gv > 0.3:
		return UI.GOOD
	if gv < -1.0:
		return UI.BAD
	if gv < -0.3:
		return UI.WARN
	return Color("#8792A4")

func _is_editable(nd: Dictionary) -> bool:
	return str(nd["kind"]) != "policy" or editable.has(str(nd["area"]))

func value_text(nd: Dictionary) -> String:
	match str(nd["kind"]):
		"policy":
			var meas := Policies.measure(str(nd["id"]))
			return Policies.value_text(meas, m.eco.value(str(nd["id"])))
		"ind": return WorldSim.fmt(str(nd["id"]), m.world.value(str(nd["id"])))
		"core":
			var e := m.eco.st()
			match str(nd["id"]):
				"growth": return "%.1f %%" % float(e.get("growth", 0.0))
				"unemployment": return "%.1f %%" % float(e.get("unemployment", 0.0))
				"inflation": return "%.1f %%" % float(e.get("inflation", 0.0))
				"deficit": return "%.1f %% PIB" % (-m.eco.balance_pct())
			return "%.0f / 100" % m.eco.quality(str(nd["id"]))
		"group": return "satisfacción %.0f" % m.eco.satisfaction(str(nd["id"]))
		"center": return "%.0f / 100" % m.gov.approval()
	return ""

# ---------------------------------------------------------------- dibujo
func _edge_color(nd_to: Dictionary, w: float) -> Color:
	var g := _good_dir(nd_to)
	if g == 0:
		return UI.ACCENT
	return UI.GOOD if w * float(g) > 0.0 else UI.BAD

func _draw_edges(key: String, alpha: float) -> void:
	if not nodes.has(key):
		return
	var a: Dictionary = nodes[key]
	for e in adj.get(key, []):
		var ed: Dictionary = e
		var b: Dictionary = nodes[str(ed["o"])]
		if not bool(b["shown"]) or not bool(a["shown"]):
			continue
		var w := float(ed["w"])
		var out := bool(ed["out"])
		var to_nd: Dictionary = b if out else a
		var col := _edge_color(to_nd, w)
		var width := 1.0 + 4.0 * clampf(absf(w) / 0.45, 0.0, 1.0)
		var p0: Vector2 = a["pos"]
		var p1: Vector2 = b["pos"]
		draw_line(p0, p1, Color(col, alpha), width, true)
		# punta de flecha hacia el nodo destino
		var from_p := p0 if out else p1
		var to_p := p1 if out else p0
		var to_r := float((b if out else a)["r"])
		var dir := (to_p - from_p).normalized()
		var tip := to_p - dir * (to_r + 1.0)
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + perp * 4.5, tip - dir * 9.0 - perp * 4.5]), Color(col, minf(1.0, alpha + 0.15)))

func _draw() -> void:
	if m == null:
		return
	var c := size * 0.5
	var rx := size.x * 0.5 - 46.0
	var ry := size.y * 0.5 - 46.0
	var font := UI.regular_font()
	# bandas de sector
	for a in wedges.keys():
		if focus_area != "" and str(a) != focus_area:
			continue
		var w: Dictionary = wedges[a]
		var col := Glyphs.area_color(str(a))
		var pts := PackedVector2Array()
		var n := 28
		for i in range(n + 1):
			var ang := lerpf(float(w["a0"]), float(w["a1"]), float(i) / float(n))
			pts.append(_ellipse(c, rx, ry, ang))
		var band := 34.0 if focus_area == "" else 70.0
		draw_polyline(pts, Color(col, 0.14 if editable.has(str(a)) else 0.07), band, true)
		# icono del área, fuera de la banda
		if focus_area != "":
			continue
		var mid := (float(w["a0"]) + float(w["a1"])) * 0.5
		var ip := _ellipse(c, rx, ry, mid)
		ip += (ip - c).normalized() * (band * 0.5 + 15.0)
		draw_circle(ip, 12.0, col)
		Glyphs.draw(self, Glyphs.of_area(str(a)), ip, 12.0, Color.WHITE)
	# anillo suave de los indicadores
	var irx := rx * (0.70 if focus_area == "" else 0.64)
	var iry := ry * (0.70 if focus_area == "" else 0.64)
	draw_arc(c, 1.0, 0.0, 0.0, 2, Color(0, 0, 0, 0))
	var ring := PackedVector2Array()
	for i2 in range(97):
		ring.append(_ellipse(c, irx, iry, TAU * float(i2) / 96.0))
	draw_polyline(ring, Color(UI.BORDER, 0.55), 1.0, true)
	var gring := PackedVector2Array()
	for i3 in range(65):
		gring.append(_ellipse(c, rx * 0.30, ry * 0.31, TAU * float(i3) / 64.0))
	draw_polyline(gring, Color(UI.BORDER, 0.55), 1.0, true)
	# vínculos
	if selected_key != "" and selected_key != _hover:
		_draw_edges(selected_key, 0.55)
	if _hover != "":
		_draw_edges(_hover, 0.8)
	var linked: Dictionary = {}
	for k in [selected_key, _hover]:
		if k != "" and adj.has(k):
			linked[k] = true
			for e in adj[k]:
				linked[str((e as Dictionary)["o"])] = true
	var dim := _hover != "" or (selected_key != "" and false)
	# nodos: medidas → indicadores → grupos → centro
	for kind in ["policy", "core", "ind", "group", "center"]:
		for k2 in nodes.keys():
			var nd: Dictionary = nodes[k2]
			if str(nd["kind"]) != kind or not bool(nd["shown"]):
				continue
			var faded: bool = (dim and not linked.has(str(k2))) or (focus_area != "" and kind in ["ind", "core"] and str(nd["area"]) != focus_area and not linked.has(str(k2)))
			_draw_node(nd, faded, font)
	# etiquetas en el modo ampliado
	if focus_area != "":
		for k3 in nodes.keys():
			var nl: Dictionary = nodes[k3]
			if str(nl["kind"]) == "policy" and bool(nl["shown"]):
				var out := ((nl["pos"] as Vector2) - c).normalized()
				var lp: Vector2 = (nl["pos"] as Vector2) + out * 30.0
				var txt := str(nl["label"])
				draw_multiline_string(font, lp - Vector2(48, 0) + Vector2(0, 4), txt, HORIZONTAL_ALIGNMENT_CENTER, 96.0, 10, 2, Color(UI.TEXT, 0.9))
	# etiquetas de indicadores y grupos en cercanía del cursor / seleccionados
	for k4 in linked.keys():
		var nl2: Dictionary = nodes[k4]
		if not bool(nl2["shown"]):
			continue
		if str(nl2["kind"]) in ["ind", "core", "group", "policy"] and not (focus_area != "" and str(nl2["kind"]) == "policy"):
			_label_tag(nl2, font)
	# tooltip del nodo bajo el cursor
	if _hover != "" and nodes.has(_hover):
		_tooltip(nodes[_hover], font)

func _label_tag(nd: Dictionary, font: Font) -> void:
	var txt := str(nd["label"])
	var fs := 11
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = nd["pos"]
	var r := float(nd["r"])
	var bx := pos.x - sz.x * 0.5 - 4.0
	var by := pos.y + r + 3.0
	bx = clampf(bx, 2.0, size.x - sz.x - 10.0)
	by = clampf(by, 2.0, size.y - 20.0)
	draw_rect(Rect2(bx, by, sz.x + 8.0, 16.0), Color(1, 1, 1, 0.92), true)
	draw_rect(Rect2(bx, by, sz.x + 8.0, 16.0), Color(UI.BORDER, 0.9), false, 1.0)
	draw_string(font, Vector2(bx + 4.0, by + 12.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)

func _draw_node(nd: Dictionary, faded: bool, font: Font) -> void:
	var pos: Vector2 = nd["pos"]
	var r := float(nd["r"])
	var kind := str(nd["kind"])
	var key := str(nd["key"])
	var col := _status_col(nd)
	var a := 0.28 if faded else 1.0
	var is_sel := key == selected_key
	match kind:
		"policy":
			var meas := Policies.measure(str(nd["id"]))
			var cur := m.eco.value(str(nd["id"]))
			var changed := not is_equal_approx(cur, float(meas["base"]))
			var ed := _is_editable(nd)
			var fill := col if ed else col.lerp(Color("#C9D1DD"), 0.7)
			if r > 14.0:
				draw_circle(pos, r + 2.0, Color(1, 1, 1, a))
				draw_circle(pos, r, Color(fill, a))
				Glyphs.draw(self, Glyphs.of_area(str(nd["area"])), pos, r, Color(1, 1, 1, a))
			else:
				draw_circle(pos, r, Color(fill, a))
			if changed:
				draw_arc(pos, r + 2.0, 0.0, TAU, 20, Color(UI.GOLD, a), 2.5, true)
			if marked.has(key):
				draw_arc(pos, r + 5.0, 0.0, TAU, 20, Color(UI.ACCENT, a), 2.0, true)
			if not ed and r > 14.0:
				draw_arc(pos, r + 2.0, 0.0, TAU, 20, Color(UI.FAINT, a * 0.6), 1.5, true)
		"ind", "core":
			draw_circle(pos, r + 2.5, Color(1, 1, 1, a))
			draw_circle(pos, r, Color(col, a))
			var g := Glyphs.of_area(str(nd["area"]))
			Glyphs.draw(self, g, pos, r, Color(1, 1, 1, a))
			if kind == "core":
				draw_arc(pos, r + 2.5, 0.0, TAU, 24, Color(UI.TEXT, 0.35 * a), 1.5, true)
		"group":
			draw_circle(pos, r + 2.5, Color(1, 1, 1, a))
			draw_circle(pos, r, Color(col.lerp(Color.WHITE, 0.82), a))
			draw_arc(pos, r, 0.0, TAU, 28, Color(col, a), 3.0, true)
			var nm := str(nd["label"])
			Glyphs.initial(self, nm.substr(0, 1), pos, r, Color(col.darkened(0.2), a))
		"center":
			draw_circle(pos, r + 4.0, Color(1, 1, 1, 1))
			draw_circle(pos, r, Color(col.lerp(Color.WHITE, 0.85), a))
			draw_arc(pos, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(m.gov.approval() / 100.0, 0.0, 1.0), 48, col, 6.0, true)
			var t := "%.0f" % m.gov.approval()
			var sz := UI.bold_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.62))
			draw_string(UI.bold_font(), pos + Vector2(-sz.x * 0.5, sz.y * 0.28), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.62), UI.TEXT)
			var cap := "APOYO"
			var csz := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			draw_string(font, pos + Vector2(-csz.x * 0.5, r * 0.62), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.MUTED)
	if is_sel:
		draw_arc(pos, r + 6.0, 0.0, TAU, 32, UI.ACCENT, 3.0, true)

func _tooltip(nd: Dictionary, font: Font) -> void:
	var title := str(nd["label"])
	var sub := value_text(nd)
	if str(nd["kind"]) == "policy":
		var ed := _is_editable(nd)
		sub += "" if ed else "  ·  otro ministerio"
	var w1 := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var w := maxf(w1, w2) + 20.0
	var p := _mouse + Vector2(16, 14)
	if p.x + w > size.x - 4.0:
		p.x = _mouse.x - w - 12.0
	if p.y + 42.0 > size.y - 4.0:
		p.y = _mouse.y - 50.0
	draw_rect(Rect2(p, Vector2(w, 40)), Color("#1C2636", 0.95), true)
	draw_string(UI.bold_font(), p + Vector2(10, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(font, p + Vector2(10, 32), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9AA8BD"))

# ---------------------------------------------------------------- ratón
func _node_at(p: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	for k in nodes.keys():
		var nd: Dictionary = nodes[k]
		if not bool(nd["shown"]):
			continue
		var d := p.distance_to(nd["pos"] as Vector2)
		var rr := float(nd["r"]) + 3.0
		if d <= rr and d < best_d:
			best_d = d
			best = str(k)
	return best

func _area_icon_at(p: Vector2) -> String:
	var c := size * 0.5
	var rx := size.x * 0.5 - 46.0
	var ry := size.y * 0.5 - 46.0
	var band := 34.0 if focus_area == "" else 70.0
	for a in wedges.keys():
		var w: Dictionary = wedges[a]
		var mid := (float(w["a0"]) + float(w["a1"])) * 0.5
		var ip := _ellipse(c, rx, ry, mid)
		ip += (ip - c).normalized() * (band * 0.5 + 15.0)
		if p.distance_to(ip) <= 14.0:
			return str(a)
	return ""

func _gui_input(event: InputEvent) -> void:
	if m == null:
		return
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		var h := _node_at(_mouse)
		if h == "" and _area_icon_at(_mouse) != "":
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
		_hover = h
		queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (event as InputEventMouseButton).position
		var k := _node_at(p)
		if k != "":
			selected_key = k
			var nd: Dictionary = nodes[k]
			emit_signal("picked", str(nd["kind"]), str(nd["id"]))
			queue_redraw()
			return
		var a := _area_icon_at(p)
		if a != "":
			emit_signal("picked", "area", a)
