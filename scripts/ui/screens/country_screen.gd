class_name CountryScreen
extends Screen
## País: un único panel con el árbol de variables a la izquierda (Economía · Sociedad · Servicios y grupos) y a la derecha la
## ficha de lo elegido: valor, gráfica (clic = ventana interactiva), QUÉ lo ha movido (leyes, medidas, crisis) y variables relacionadas.
## «Resumen» muestra el estado del país, la previsión del motor trimestral, los avisos y las crisis en curso.

static var sel := "summary"          # summary | events | laws | id de variable
static var open_nodes: Dictionary = {"eco": true, "act": true}
static var query := ""

var cv: CountryVars
var _tree_box: VBoxContainer
var _right: VBoxContainer
var _search: LineEdit

func wants_full() -> bool:
	return true

func build() -> void:
	m.eco.ensure()
	m.world.ensure()
	m.macro.ensure()
	cv = CountryVars.new(m)
	if sel != "summary" and sel != "events" and sel != "laws" and not CountryVars.exists(sel):
		sel = "summary"
	if CountryVars.exists(sel):
		open_nodes[CountryVars.section_of(sel)] = true
		open_nodes[CountryVars.group_of(sel)] = true
	var row := UI.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	_build_left(row)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	_right = UI.vbox(10)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_right)
	_fill_right()

# ================================================================ panel izquierdo
func _build_left(parent: Node) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(340, 0)
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 8, 8))
	parent.add_child(pc)
	var col := UI.vbox(6)
	pc.add_child(col)
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar variable…"
	_search.clear_button_enabled = true
	_search.text = query
	_search.text_changed.connect(_on_search)
	col.add_child(_search)
	_quick(col, "summary", "Resumen del país", "")
	var ev := m.macro.active_shocks().size()
	_quick(col, "events", "Crisis y oportunidades", ("%d en curso" % ev) if ev > 0 else "")
	var nl := m.eco.passed_laws().size()
	_quick(col, "laws", "Efecto de mis leyes", ("%d" % nl) if nl > 0 else "")
	col.add_child(UI.hsep())
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	_tree_box = UI.vbox(1)
	_tree_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_tree_box)
	_fill_tree()

func _flat_row(parent: Node, selected: bool, cb: Callable, height: float, accent: Color = UI.ACCENT) -> HBoxContainer:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL.lerp(accent, 0.13) if selected else Color(0, 0, 0, 0), accent if selected else Color(0, 0, 0, 0), 4, 1, 6, 2))
	b.add_theme_stylebox_override("hover", UI.box(UI.PANEL2, Color(0, 0, 0, 0), 4, 0, 6, 2))
	b.add_theme_stylebox_override("pressed", UI.box(UI.PANEL.lerp(accent, 0.2), accent, 4, 1, 6, 2))
	b.pressed.connect(cb)
	parent.add_child(b)
	var inner := UI.hbox(6)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_right = -8
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	return inner

func _quick(parent: Node, id: String, text: String, badge: String) -> void:
	var inner := _flat_row(parent, sel == id, Callable(self, "_select").bind(id), 34)
	var l := UI.label(text, UI.FS_BODY, UI.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(l)
	if badge != "":
		var c := UI.chip(badge, UI.WARN if id == "events" else UI.ACCENT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(c)
	UI.pass_clicks(inner)

func _on_search(t: String) -> void:
	query = t
	_fill_tree()

func _toggle(key: String) -> void:
	open_nodes[key] = not bool(open_nodes.get(key, false))
	_fill_tree()

func _fill_tree() -> void:
	UI.clear_children(_tree_box)
	var q := query.strip_edges().to_lower()
	if q != "":
		var found := 0
		for sec in CountryVars.tree():
			for g in (sec as Dictionary)["groups"]:
				for id in (g as Dictionary)["vars"]:
					if CountryVars.name_of(str(id)).to_lower().find(q) >= 0:
						_var_row(_tree_box, str(id), 6)
						found += 1
		if found == 0:
			_tree_box.add_child(UI.label("Nada coincide con «%s»." % query, UI.FS_SMALL, UI.FAINT))
		return
	for sec in CountryVars.tree():
		var sd: Dictionary = sec
		var skey := str(sd["id"])
		var is_open := bool(open_nodes.get(skey, false))
		var inner := _flat_row(_tree_box, false, Callable(self, "_toggle").bind(skey), 34, UI.HEAD)
		var gl := UI.label(str(sd["glyph"]), UI.FS_LEAD, UI.HEAD, true)
		gl.custom_minimum_size = Vector2(18, 0)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(gl)
		var tl := UI.label(str(sd["name"]).to_upper(), UI.FS_SMALL, UI.HEAD, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tl)
		var ar := UI.label("▾" if is_open else "▸", UI.FS_BODY, UI.FAINT, true)
		ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ar)
		if not is_open:
			continue
		for g2 in sd["groups"]:
			var gd: Dictionary = g2
			var gkey := str(gd["id"])
			var g_open := bool(open_nodes.get(gkey, false))
			var gin := _flat_row(_tree_box, false, Callable(self, "_toggle").bind(gkey), 28)
			var sp := UI.spacer(0, 10)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gin.add_child(sp)
			var gt := UI.label(("▾ " if g_open else "▸ ") + str(gd["name"]), UI.FS_BODY, UI.MUTED, true)
			gt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gin.add_child(gt)
			if not g_open:
				continue
			for id2 in gd["vars"]:
				_var_row(_tree_box, str(id2), 24)

func _var_row(parent: Node, id: String, indent: int) -> void:
	var inner := _flat_row(parent, sel == id, Callable(self, "_select").bind(id), 28)
	var sp := UI.spacer(0, float(indent))
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sp)
	var g := CountryVars.good_of(id)
	var dq := cv.change(id, 85)
	var dcol := UI.delta_color(dq * float(g), 0.0) if g != 0 else UI.FAINT
	var nl := UI.label(CountryVars.name_of(id), UI.FS_SMALL, UI.TEXT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(nl)
	var vl := UI.label(CountryVars.fmt_short(id, cv.value(id)), UI.FS_SMALL, UI.TEXT, true)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.custom_minimum_size = Vector2(52, 0)
	inner.add_child(vl)
	var arrow := "▲" if dq > CountryVars.eps(id) else ("▼" if dq < -CountryVars.eps(id) else "·")
	var al := UI.label(arrow, UI.FS_TINY, dcol, true)
	al.custom_minimum_size = Vector2(14, 0)
	inner.add_child(al)
	UI.pass_clicks(inner)

func _select(id: String) -> void:
	sel = id
	if CountryVars.exists(id):
		open_nodes[CountryVars.section_of(id)] = true
		open_nodes[CountryVars.group_of(id)] = true
	_fill_tree_keep()
	_fill_right()

## Repinta el árbol conservando la posición del scroll.
func _fill_tree_keep() -> void:
	var sc: ScrollContainer = _tree_box.get_parent() as ScrollContainer
	var pos := sc.scroll_vertical if sc != null else 0
	_fill_tree()
	if sc != null:
		sc.set_deferred("scroll_vertical", pos)

# ================================================================ panel derecho
func _fill_right() -> void:
	UI.clear_children(_right)
	match sel:
		"summary": _summary(_right)
		"events": _events(_right)
		"laws": _laws(_right)
		_: _detail(_right, sel)

func _crumbs(parent: Node, id: String) -> void:
	var sec := ""
	var grp := ""
	for s in CountryVars.tree():
		for g in (s as Dictionary)["groups"]:
			if (g as Dictionary)["vars"].has(id):
				sec = str((s as Dictionary)["name"])
				grp = str((g as Dictionary)["name"])
	if sec != "":
		parent.add_child(UI.label("%s  ›  %s" % [sec, grp], UI.FS_SMALL, UI.FAINT, true))

# ---------------------------------------------------------------- mini-gráfica reutilizable
func _chart_for(id: String, quarters: int, height: float, with_proj: bool, color: Color = UI.ACCENT) -> LineChart:
	var all := cv.entries(id)
	var n := mini(all.size(), quarters + 1)
	var ents := all.slice(all.size() - n)
	var vals := CountryVars.values_of(ents)
	var labels := CountryVars.labels_of(ents)
	var dec := int(CountryVars.info(id).get("dec", 1))
	var ch := LineChart.new()
	ch.custom_minimum_size = Vector2(0, height)
	ch.value_fmt = "%." + str(dec) + "f"
	ch.allow_negative = true
	ch.show_end_labels = false
	var series: Array = [{"id": id, "name": CountryVars.name_of(id), "color": color, "values": vals, "width": 2.4, "fmt": "%." + str(dec) + "f"}]
	if with_proj and not ents.is_empty():
		var pr := cv.projection(id, 6)
		if not pr.is_empty():
			var pv: Array = [vals[vals.size() - 1]]
			pv.append_array(pr)
			series.append({"id": id + "_p", "name": "Previsión", "color": UI.WARN, "values": pv, "offset": vals.size() - 1, "width": 2.0, "dashed": true, "fmt": "%." + str(dec) + "f"})
			var t_last := int((ents[ents.size() - 1] as Dictionary)["t"])
			for k in range(pr.size()):
				labels.append(Rules.quarter_label(t_last + (k + 1) * 91 * 86400) + " (prev.)")
	ch.x_labels = labels
	ch.markers = cv.markers(ents)
	ch.series = series
	ch.point_clicked.connect(Callable(self, "_open_chart").bind(id))
	ch.tooltip_text = "Clic en un punto: abre la gráfica en una ventana"
	return ch

func _open_chart(idx: int, id: String) -> void:
	ChartWindow.open(shell, m, id, 8, idx)

func _open_chart_btn(id: String) -> void:
	ChartWindow.open(shell, m, id, 8, -1)

func _jump(id: String) -> void:
	_select(id)

# ================================================================ resumen
func _tile(parent: Node, id: String) -> void:
	var g := CountryVars.good_of(id)
	var dq := cv.change(id, 85)
	var dec := int(CountryVars.info(id).get("dec", 1))
	var col := UI.delta_color(dq * float(g), 0.0) if g != 0 else UI.ACCENT
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL, UI.BORDER, 8, 1, 10, 6, true))
	b.add_theme_stylebox_override("hover", UI.box(UI.PANEL.lerp(UI.ACCENT, 0.06), UI.ACCENT, 8, 1, 10, 6))
	b.add_theme_stylebox_override("pressed", UI.box(UI.PANEL.lerp(UI.ACCENT, 0.12), UI.ACCENT, 8, 2, 10, 6))
	b.pressed.connect(Callable(self, "_jump").bind(id))
	parent.add_child(b)
	var v := UI.vbox(1)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -4
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var nl := UI.label(CountryVars.name_of(id), UI.FS_SMALL, UI.MUTED, true)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nl)
	var r := UI.hbox(6)
	r.add_child(UI.label(CountryVars.fmt_short(id, cv.value(id)), UI.FS_H2, UI.TEXT, true))
	if absf(dq) >= CountryVars.eps(id):
		r.add_child(UI.label(UI.signed(dq, dec), UI.FS_SMALL, col, true))
	v.add_child(r)
	var sp := Spark.new()
	sp.custom_minimum_size = Vector2(0, 18)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.values = CountryVars.values_of(cv.entries(id), 12)
	sp.color = col
	v.add_child(sp)
	UI.pass_clicks(v)

func _summary(col: VBoxContainer) -> void:
	var head := UI.hbox(10)
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("Estado del país", UI.FS_H2, UI.TEXT, true))
	hv.add_child(UI.label("Trimestre %d de %d · %s" % [m.turn(), Rules.LEGISLATURE_TURNS, Rules.quarter_label(m.clock_unix())], UI.FS_SMALL, UI.MUTED))
	head.add_child(hv)
	var alerts := m.macro.alerts()
	var bad := 0
	for a in alerts:
		if str((a as Dictionary)["level"]) == "bad":
			bad += 1
	if bad > 0:
		head.add_child(UI.chip("%d aviso%s grave%s" % [bad, "" if bad == 1 else "s", "" if bad == 1 else "s"], UI.BAD, true))
	col.add_child(head)
	var grid := UI.grid(4, 8, 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	for id in ["growth", "unemployment", "inflation", "rate", "spread", "debt_pct", "deficit_pct", "conf_c"]:
		_tile(grid, str(id))
	# Previsión
	var cp := UI.card(col, "Previsión sin sorpresas", "próximos 6 trimestres · clic en una gráfica para ampliarla", UI.WARN)
	var prow := UI.hbox(10)
	prow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.add_child(prow)
	for id2 in ["growth", "unemployment", "inflation"]:
		var pv := UI.vbox(2)
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.add_child(UI.label(CountryVars.name_of(str(id2)), UI.FS_SMALL, UI.MUTED, true))
		pv.add_child(_chart_for(str(id2), 8, 170, true))
		prow.add_child(pv)
	cp.add_child(UI.wrap_label("Es lo que haría la economía si no hubiera nuevas crisis ni nuevas leyes. Una crisis, un boom o tus decisiones lo cambiarán.", UI.FS_TINY, UI.FAINT))
	# Avisos y crisis
	var two := columns(1.0, 1.0, col)
	var ca := UI.card(two[0], "Avisos", "", UI.BAD)
	_alerts(ca, alerts)
	var cs := UI.card(two[1], "Crisis y oportunidades en curso", "", UI.WARN)
	_active_shocks(cs)
	# Qué ha movido
	var cm := UI.card(col, "Qué ha movido la economía este trimestre", "causas por ley, medida, crisis y agentes", UI.ACCENT)
	var mrow := UI.hbox(14)
	mrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.add_child(mrow)
	for id3 in ["growth", "unemployment", "inflation"]:
		var mv := UI.vbox(4)
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tb := UI.button(CountryVars.name_of(str(id3)) + "  ›", "ghost", Callable(self, "_jump").bind(str(id3)))
		tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mv.add_child(tb)
		var lst := cv.causes(str(id3))
		if lst.is_empty():
			mv.add_child(UI.label("Sin cambios relevantes.", UI.FS_SMALL, UI.FAINT))
		else:
			ChartWindow.cause_rows(mv, cv, str(id3), lst, 4, true)
		mrow.add_child(mv)

func _alerts(c: VBoxContainer, alerts: Array) -> void:
	var any := false
	for a in alerts:
		var ad: Dictionary = a
		if str(ad["id"]).begins_with("shock_"):
			continue
		any = true
		var lv := str(ad["level"])
		var colr := UI.BAD if lv == "bad" else (UI.GOOD if lv == "good" else UI.WARN)
		var r := UI.hbox(8)
		r.add_child(UI.chip("Grave" if lv == "bad" else ("Bien" if lv == "good" else "Ojo"), colr))
		var tl := UI.wrap_label(str(ad["text"]), UI.FS_SMALL, UI.TEXT)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(tl)
		var via := str(ad.get("via", ""))
		if via != "" and CountryVars.exists(via):
			r.add_child(UI.mini_button("Ver", Callable(self, "_jump").bind(via)))
		c.add_child(r)
	if not any:
		c.add_child(UI.wrap_label("Ningún aviso: la economía no muestra desequilibrios importantes.", UI.FS_SMALL, UI.FAINT))

func _active_shocks(c: VBoxContainer) -> void:
	var list := m.macro.active_shocks()
	if list.is_empty():
		c.add_child(UI.wrap_label("Ahora mismo no hay ninguna crisis ni boom en marcha. Pueden aparecer en cualquier trimestre, y con más probabilidad si acumulas desequilibrios (deuda, burbuja inmobiliaria, banca frágil).", UI.FS_SMALL, UI.FAINT))
		return
	for s in list:
		var sd: Dictionary = s
		var good := bool(sd["good"])
		var r := UI.hbox(8)
		r.add_child(UI.chip("Oportunidad" if good else "Crisis", UI.GOOD if good else UI.BAD, true))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(str(sd["name"]), UI.FS_BODY, UI.TEXT, true))
		tv.add_child(UI.wrap_label("%s Quedan %d trimestre%s." % [str(sd["body"]), int(sd["left"]), "" if int(sd["left"]) == 1 else "s"], UI.FS_SMALL, UI.MUTED))
		r.add_child(tv)
		c.add_child(r)

# ================================================================ ficha de una variable
func _detail(col: VBoxContainer, id: String) -> void:
	_crumbs(col, id)
	var g := CountryVars.good_of(id)
	var dq := cv.change(id, 85)
	var dy := cv.change(id, 360)
	var dec := int(CountryVars.info(id).get("dec", 1))
	var hero := UI.card(col, "", "", UI.ACCENT)
	var top := UI.hbox(14)
	hero.add_child(top)
	var tv := UI.vbox(0)
	tv.add_child(UI.label(CountryVars.name_of(id), UI.FS_H2, UI.TEXT, true))
	var vrow := UI.hbox(10)
	vrow.add_child(UI.label(CountryVars.fmt(id, cv.value(id)), 30, UI.TEXT, true))
	vrow.add_child(UI.chip("%s vs trimestre anterior" % UI.signed(dq, dec), UI.delta_color(dq * float(g), 0.0) if g != 0 else UI.ACCENT) if absf(dq) >= CountryVars.eps(id) else UI.chip("estable este trimestre", UI.FAINT))
	if absf(dy) >= CountryVars.eps(id):
		vrow.add_child(UI.chip("%s en un año" % UI.signed(dy, dec), UI.delta_color(dy * float(g), 0.0) if g != 0 else UI.ACCENT))
	tv.add_child(vrow)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	top.add_child(UI.button("Abrir gráfica en ventana  ⤢", "primary", Callable(self, "_open_chart_btn").bind(id)))
	var desc := str(CountryVars.info(id).get("desc", ""))
	if desc != "":
		hero.add_child(UI.wrap_label(desc, UI.FS_BODY, UI.MUTED))
	var cc := UI.card(col, "Evolución", "pasa el ratón · clic en un punto = ventana con las causas de ese trimestre", UI.ACCENT)
	cc.add_child(_chart_for(id, 8, 250, true))
	# Qué lo ha movido
	var two := columns(1.3, 1.0, col)
	var cw := UI.card(two[0], "¿Por qué ha cambiado este trimestre?", "", UI.GOOD)
	var list := cv.causes(id)
	if list.is_empty():
		cw.add_child(UI.wrap_label("Sin cambios relevantes: ninguna medida, crisis ni agente ha empujado esta variable de forma notable.", UI.FS_SMALL, UI.FAINT))
	else:
		ChartWindow.cause_rows(cw, cv, id, list, 7)
	var st := cv.standing(id)
	if not st.is_empty():
		cw.add_child(UI.hsep())
		cw.add_child(UI.label("Efectos que siguen actuando", UI.FS_SMALL, UI.MUTED, true))
		cw.add_child(UI.wrap_label("Medidas y crisis cuyo efecto sigue llegando: se acumula trimestre a trimestre.", UI.FS_TINY, UI.FAINT))
		ChartWindow.cause_rows(cw, cv, id, st, 6)
	var cr := UI.card(two[1], "Qué influye en esta variable", "", UI.PILL_SUB)
	var rel: Array = []
	for rid in CountryVars.related(id):
		if CountryVars.exists(str(rid)):
			rel.append(str(rid))
	if CountryVars.kind_of(id) == "world":
		for e in m.world.edges():
			var ed: Dictionary = e
			if str(ed["to"]) == id and CountryVars.exists(str(ed["from"])) and not rel.has(str(ed["from"])):
				rel.append(str(ed["from"]))
	if rel.is_empty():
		cr.add_child(UI.label("Variable de partida: no depende de otras.", UI.FS_SMALL, UI.FAINT))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for rid2 in rel.slice(0, 14):
		fl.add_child(UI.mini_button("%s · %s" % [CountryVars.name_of(str(rid2)), CountryVars.fmt_short(str(rid2), cv.value(str(rid2)))], Callable(self, "_jump").bind(str(rid2))))
	cr.add_child(fl)
	var mine := _my_laws_on(id)
	if not mine.is_empty():
		var cl := UI.card(col, "Tus leyes que lo mueven", "", UI.GOLD)
		for it in mine:
			var d: Dictionary = it
			var r := UI.hbox(8)
			r.add_child(UI.chip("Ley", UI.GOLD))
			var tl := UI.wrap_label("%s · %s" % [str(d["title"]), str(d["when"])], UI.FS_SMALL, UI.TEXT)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(tl)
			r.add_child(UI.label(str(d["what"]), UI.FS_SMALL, UI.MUTED, true))
			cl.add_child(r)

## Leyes aprobadas que tocaron alguna medida con efecto sobre esta variable: [{title, when, what}].
func _my_laws_on(id: String) -> Array:
	var out: Array = []
	var laws := m.eco.passed_laws()
	for i in range(laws.size() - 1, -1, -1):
		var l: Dictionary = laws[i]
		for mid in (l.get("changes", {}) as Dictionary).keys():
			var meas := Policies.measure(str(mid))
			if meas.is_empty():
				continue
			var fx: Dictionary = meas.get("fx", {})
			var hits_g: Dictionary = meas.get("hits", {})
			var key := id.substr(2) if CountryVars.is_group(id) or CountryVars.is_quality(id) else id
			var touches := fx.has(key) or (CountryVars.is_group(id) and hits_g.has(key))
			if not touches and CountryVars.kind_of(id) == "macro":
				continue
			if touches:
				out.append({"title": str(l.get("title", "")), "when": "T%d" % Rules.turn_of(int(l.get("month", 1))), "what": "%s → %s" % [str(meas["name"]), Policies.value_text(meas, float((l["changes"] as Dictionary)[mid]))]})
	return out.slice(0, 6)

# ================================================================ crisis y oportunidades
func _events(col: VBoxContainer) -> void:
	col.add_child(UI.label("Crisis y oportunidades", UI.FS_H2, UI.TEXT, true))
	col.add_child(UI.wrap_label("La economía no está quieta: cada trimestre el motor puede lanzar una crisis (financiera, energética, de deuda, pandemia…) o un boom (turismo, tecnología, fondos europeos). La probabilidad crece con tus desequilibrios: burbuja inmobiliaria, deuda alta, bancos frágiles.", UI.FS_BODY, UI.MUTED))
	var c1 := UI.card(col, "En curso", "", UI.WARN)
	_active_shocks(c1)
	var c2 := UI.card(col, "Historial", "", UI.ACCENT)
	var ev := m.macro.events()
	if ev.is_empty():
		c2.add_child(UI.label("Todavía no ha pasado nada extraordinario.", UI.FS_SMALL, UI.FAINT))
	for i in range(ev.size() - 1, -1, -1):
		var e: Dictionary = ev[i]
		var good := bool(e["good"])
		var r := UI.hbox(8)
		r.add_child(UI.chip(Rules.quarter_label(int(e["t"])), UI.MUTED))
		r.add_child(UI.chip("Oportunidad" if good else "Crisis", UI.GOOD if good else UI.BAD))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(str(e["name"]), UI.FS_BODY, UI.TEXT, true))
		tv.add_child(UI.wrap_label(str(e["text"]), UI.FS_SMALL, UI.MUTED))
		r.add_child(tv)
		c2.add_child(r)

# ================================================================ efecto de mis leyes
func _laws(col: VBoxContainer) -> void:
	col.add_child(UI.label("Efecto de mis leyes", UI.FS_H2, UI.TEXT, true))
	col.add_child(UI.wrap_label("Cada ley aprobada cambia medidas del país. Sus efectos llegan con retardo (varios trimestres) y se ven en las variables que mueven: pulsa una para abrir su ficha.", UI.FS_BODY, UI.MUTED))
	var laws := m.eco.passed_laws()
	if laws.is_empty():
		var c0 := UI.card(col, "Aún no has aprobado ninguna ley", "", UI.GOLD)
		c0.add_child(UI.wrap_label("Cuando el Congreso apruebe una ley tuya o del Gobierno, aparecerá aquí con las variables que mueve.", UI.FS_SMALL, UI.FAINT))
		return
	for i in range(laws.size() - 1, -1, -1):
		var l: Dictionary = laws[i]
		var c := UI.card(col, str(l.get("title", "Ley")), "T%d · %s" % [Rules.turn_of(int(l.get("month", 1))), str(l.get("proposer", ""))], UI.GOLD)
		for mid in (l.get("changes", {}) as Dictionary).keys():
			var meas := Policies.measure(str(mid))
			if meas.is_empty():
				continue
			var r := UI.vbox(3)
			var line := UI.hbox(8)
			line.add_child(UI.label(str(meas["name"]), UI.FS_BODY, UI.TEXT, true))
			line.add_child(UI.label("→ %s" % Policies.value_text(meas, float((l["changes"] as Dictionary)[mid])), UI.FS_SMALL, UI.MUTED))
			r.add_child(line)
			var fl := HFlowContainer.new()
			fl.add_theme_constant_override("h_separation", 6)
			fl.add_theme_constant_override("v_separation", 4)
			var links := m.world.measure_links(str(mid))
			links.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["w"])) > absf(float(b["w"])))
			var n := 0
			for lk in links:
				var ld: Dictionary = lk
				if str(ld["kind"]) == "group" or n >= 5:
					continue
				var vid := str(ld["id"])
				if not CountryVars.exists(vid) and CountryVars.exists("q:" + vid):
					vid = "q:" + vid
				var label := CountryVars.name_of(vid) if CountryVars.exists(vid) else WorldSim.name_of(vid)
				var sign_t := "▲" if float(ld["w"]) > 0.0 else "▼"
				if CountryVars.exists(vid):
					fl.add_child(UI.mini_button("%s %s" % [sign_t, label], Callable(self, "_jump").bind(vid)))
				else:
					fl.add_child(UI.chip("%s %s" % [sign_t, label], UI.FAINT))
				n += 1
			r.add_child(fl)
			c.add_child(r)
