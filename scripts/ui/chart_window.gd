class_name ChartWindow
extends VBoxContainer
## Ventana de una gráfica del país: periodo, previsión punteada, marcas de leyes y crisis, comparación con otra variable
## y, al hacer clic en un trimestre, qué lo movió (medidas con su ley de origen, crisis, agentes).

var shell
var m: GameModel
var cv: CountryVars
var id := ""
var range_n := 8           ## trimestres mostrados (0 = todo el historial)
var compare := ""
var show_proj := true
var show_marks := true
var sel := -1              ## punto elegido (índice en la serie mostrada, incluida la previsión)
var _chart: LineChart
var _detail: VBoxContainer
var _ents: Array = []       ## serie mostrada [{t, label, v}]
var _proj: Array = []

const RANGES := [["2 años", 8], ["3 años", 12], ["5 años", 20], ["Todo", 0]]

static func open(shell_node, model: GameModel, var_id: String, range_quarters: int = 8, pick: int = -1) -> void:
	var col: VBoxContainer = shell_node.modal(CountryVars.name_of(var_id), 1180.0)
	var w := ChartWindow.new()
	w.shell = shell_node
	w.m = model
	w.cv = CountryVars.new(model)
	w.id = var_id
	w.range_n = range_quarters
	w.sel = pick
	w.add_theme_constant_override("separation", 10)
	col.add_child(w)
	w.build()

func build() -> void:
	UI.clear_children(self)
	_header()
	_controls()
	_chart = LineChart.new()
	_chart.custom_minimum_size = Vector2(1100, 330)
	_chart.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_chart.show_end_labels = true
	_chart.allow_negative = true
	_chart.point_clicked.connect(_on_pick)
	add_child(_chart)
	_detail = UI.vbox(8)
	add_child(_detail)
	_fill_chart()
	_fill_detail()

# ---------------------------------------------------------------- cabecera y controles
func _header() -> void:
	var row := UI.hbox(12)
	var v := cv.value(id)
	row.add_child(UI.label(CountryVars.fmt(id, v), UI.FS_H2, UI.TEXT, true))
	var g := CountryVars.good_of(id)
	var dq := cv.change(id, 85)
	var dy := cv.change(id, 360)
	var dec := int(CountryVars.info(id).get("dec", 1))
	if absf(dq) >= CountryVars.eps(id):
		row.add_child(UI.chip("%s vs trimestre anterior" % UI.signed(dq, dec), UI.delta_color(dq * float(g), 0.0) if g != 0 else UI.ACCENT))
	if absf(dy) >= CountryVars.eps(id):
		row.add_child(UI.chip("%s en un año" % UI.signed(dy, dec), UI.delta_color(dy * float(g), 0.0) if g != 0 else UI.ACCENT))
	row.add_child(UI.fill())
	row.add_child(UI.button("Cerrar", "primary", Callable(self, "_close")))
	add_child(row)
	var d := str(CountryVars.info(id).get("desc", ""))
	if d != "":
		add_child(UI.wrap_label(d, UI.FS_SMALL, UI.MUTED))

func _close() -> void:
	shell.close_modal()

func _controls() -> void:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	fl.add_child(UI.label("Periodo", UI.FS_SMALL, UI.MUTED, true))
	for r in RANGES:
		var rd: Array = r
		fl.add_child(UI.pill(str(rd[0]), range_n == int(rd[1]), Callable(self, "_set_range").bind(int(rd[1])), false))
	fl.add_child(UI.spacer(0, 10))
	fl.add_child(UI.pill("Previsión", show_proj, Callable(self, "_toggle_proj"), false, UI.PILL_SUB))
	fl.add_child(UI.pill("Leyes y crisis", show_marks, Callable(self, "_toggle_marks"), false, UI.PILL_SUB))
	var rel: Array = []
	for rid in CountryVars.related(id):
		if CountryVars.exists(str(rid)) and str(rid) != id:
			rel.append(str(rid))
	if not rel.is_empty():
		fl.add_child(UI.spacer(0, 10))
		fl.add_child(UI.label("Comparar con", UI.FS_SMALL, UI.MUTED, true))
		for rid2 in rel.slice(0, 6):
			fl.add_child(UI.pill(CountryVars.name_of(str(rid2)), compare == str(rid2), Callable(self, "_set_compare").bind(str(rid2)), false, UI.PILL_SUB))
	add_child(fl)

func _set_range(n: int) -> void:
	range_n = n
	sel = -1
	build()

func _toggle_proj() -> void:
	show_proj = not show_proj
	build()

func _toggle_marks() -> void:
	show_marks = not show_marks
	build()

func _set_compare(cid: String) -> void:
	compare = "" if compare == cid else cid
	build()

func _on_pick(i: int) -> void:
	sel = i
	_fill_detail()

# ---------------------------------------------------------------- gráfica
## Valores de `other` alineados por fecha con las entradas mostradas: {offset, values}.
func _align(other: Array) -> Dictionary:
	var vals: Array = []
	var first := -1
	for i in range(_ents.size()):
		var t := int((_ents[i] as Dictionary)["t"])
		var best := -1
		var gap := 1 << 60
		for j in range(other.size()):
			var dt := absi(int((other[j] as Dictionary)["t"]) - t)
			if dt < gap:
				gap = dt
				best = j
		if best >= 0 and gap <= 50 * 86400:
			if first < 0:
				first = i
			vals.append(float((other[best] as Dictionary)["v"]))
	return {"offset": maxi(0, first), "values": vals}

func _fill_chart() -> void:
	var all := cv.entries(id)
	var n := all.size() if range_n <= 0 else mini(all.size(), range_n + 1)
	_ents = all.slice(all.size() - n)
	var labels := CountryVars.labels_of(_ents)
	var main_vals := CountryVars.values_of(_ents)
	var dec := int(CountryVars.info(id).get("dec", 1))
	var series: Array = []
	_proj = []
	var unit := str(CountryVars.info(id).get("unit", ""))
	var main_name := CountryVars.name_of(id)
	_chart.value_fmt = "%." + str(dec) + "f"
	_chart.ref_line = NAN
	if compare == "":
		series.append({"id": id, "name": "%s" % main_name, "color": UI.ACCENT, "values": main_vals, "width": 2.6, "fmt": "%." + str(dec) + "f " + ("" if unit in ["índice", "puntos", "0-100"] else unit)})
		if show_proj and not _ents.is_empty():
			_proj = cv.projection(id, 6)
			if not _proj.is_empty():
				var pv: Array = [main_vals[main_vals.size() - 1]]
				pv.append_array(_proj)
				series.append({"id": id + "_p", "name": "Previsión", "color": UI.WARN, "values": pv, "offset": main_vals.size() - 1, "width": 2.2, "dashed": true, "fmt": "%." + str(dec) + "f"})
				var t_last := int((_ents[_ents.size() - 1] as Dictionary)["t"])
				for k in range(_proj.size()):
					labels.append(Rules.quarter_label(t_last + (k + 1) * 91 * 86400) + " (prev.)")
	else:
		var other := cv.entries(compare)
		var al := _align(other)
		var off := int(al["offset"])
		var ovals: Array = al["values"]
		var base_main := float(main_vals[off]) if off < main_vals.size() else 1.0
		var base_o := float(ovals[0]) if not ovals.is_empty() else 1.0
		var nm: Array = []
		for i in range(off, main_vals.size()):
			nm.append(_norm(float(main_vals[i]), base_main))
		var no: Array = []
		for v in ovals:
			no.append(_norm(float(v), base_o))
		series.append({"id": id, "name": main_name, "color": UI.ACCENT, "values": nm, "offset": off, "width": 2.6, "fmt": "%.0f"})
		series.append({"id": compare, "name": CountryVars.name_of(compare), "color": UI.D4_RED, "values": no, "offset": off, "width": 2.6, "fmt": "%.0f"})
		_chart.value_fmt = "%.0f"
	_chart.x_labels = labels
	_chart.focus_id = ""
	_chart.markers = cv.markers(_ents) if show_marks else []
	_chart.series = series
	if sel < 0 or sel >= labels.size():
		sel = _ents.size() - 1
	_chart.selected = sel

## Índice base 100 (o diferencia si la base es casi cero).
static func _norm(v: float, base: float) -> float:
	if absf(base) < 0.05:
		return 100.0 + (v - base) * 10.0
	return v / base * 100.0

# ---------------------------------------------------------------- detalle
func _fill_detail() -> void:
	UI.clear_children(_detail)
	if _chart != null:
		_chart.selected = sel
	var row := UI.hbox(14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_child(row)
	_stats(row)
	_why(row)

func _stats(parent: Node) -> void:
	var c := UI.card(parent, "En el periodo", "", UI.ACCENT)
	c.get_parent().get_parent().get_parent().custom_minimum_size = Vector2(300, 0)
	if _ents.is_empty():
		c.add_child(UI.label("Sin datos todavía.", UI.FS_SMALL, UI.FAINT))
		return
	var lo := 1e12
	var hi := -1e12
	var sum := 0.0
	for e in _ents:
		var v := float((e as Dictionary)["v"])
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	var first := float((_ents[0] as Dictionary)["v"])
	var last := float((_ents[_ents.size() - 1] as Dictionary)["v"])
	var g := CountryVars.good_of(id)
	var dec := int(CountryVars.info(id).get("dec", 1))
	for kv in [["Máximo", CountryVars.fmt_short(id, hi), UI.TEXT], ["Mínimo", CountryVars.fmt_short(id, lo), UI.TEXT], ["Media", CountryVars.fmt_short(id, sum / float(_ents.size())), UI.TEXT],
			["Variación", UI.signed(last - first, dec), UI.delta_color((last - first) * float(g), 0.0) if g != 0 else UI.TEXT]]:
		var r := UI.hbox(6)
		r.add_child(UI.label(str(kv[0]), UI.FS_SMALL, UI.MUTED))
		r.add_child(UI.fill())
		r.add_child(UI.label(str(kv[1]), UI.FS_BODY, kv[2], true))
		c.add_child(r)

func _why(parent: Node) -> void:
	var proj_idx := sel - _ents.size()
	var c := UI.card(parent, "", "", UI.GOOD)
	var wrap := c.get_parent().get_parent().get_parent()
	if wrap is Control:
		(wrap as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_l := UI.label("", UI.FS_LEAD, UI.TEXT, true)
	c.add_child(title_l)
	if sel >= _ents.size() and not _proj.is_empty():
		title_l.text = "Previsión: %s" % _chart.x_labels[sel]
		var pv := float(_proj[clampi(proj_idx, 0, _proj.size() - 1)])
		c.add_child(UI.wrap_label("Si no ocurre ninguna sorpresa y no cambias nada, el modelo espera %s. Las crisis, los booms y tus nuevas leyes lo cambiarán." % CountryVars.fmt(id, pv), UI.FS_BODY, UI.MUTED))
		return
	if _ents.is_empty() or sel < 0 or sel >= _ents.size():
		return
	var e: Dictionary = _ents[sel]
	title_l.text = "Qué movió «%s» en %s" % [CountryVars.name_of(id), str(e["label"])]
	var is_last := sel == _ents.size() - 1
	var list: Array = cv.causes(id) if is_last else cv.causes_at(id, int(e["t"]))
	if list.is_empty() and not is_last:
		if CountryVars.kind_of(id) == "core" or CountryVars.kind_of(id) == "world" and MacroSim.OWNED.has(id):
			c.add_child(UI.wrap_label("Este trimestre es anterior al inicio de la partida: no hay desglose guardado.", UI.FS_SMALL, UI.FAINT))
		else:
			_related_then(c, e)
		return
	if list.is_empty():
		c.add_child(UI.wrap_label("Sin cambios relevantes: nada ha empujado esta variable de forma notable.", UI.FS_SMALL, UI.FAINT))
		_standing(c)
		return
	ChartWindow.cause_rows(c, cv, id, list, 6)
	if is_last:
		_standing(c)

func _standing(c: VBoxContainer) -> void:
	var st := cv.standing(id)
	if st.is_empty():
		return
	c.add_child(UI.hsep())
	c.add_child(UI.label("Efectos que siguen actuando", UI.FS_SMALL, UI.MUTED, true))
	ChartWindow.cause_rows(c, cv, id, st, 4)

## Para variables sin desglose guardado: valores de las relacionadas en ese trimestre.
func _related_then(c: VBoxContainer, e: Dictionary) -> void:
	c.add_child(UI.wrap_label("Variables relacionadas en ese trimestre:", UI.FS_SMALL, UI.MUTED))
	for rid in CountryVars.related(id).slice(0, 6):
		if not CountryVars.exists(str(rid)):
			continue
		var ents := cv.entries(str(rid))
		var best: Dictionary = {}
		var gap := 1 << 60
		for x in ents:
			var dt := absi(int((x as Dictionary)["t"]) - int(e["t"]))
			if dt < gap:
				gap = dt
				best = x
		if best.is_empty() or gap > 50 * 86400:
			continue
		var r := UI.hbox(6)
		r.add_child(UI.label(CountryVars.name_of(str(rid)), UI.FS_SMALL, UI.TEXT))
		r.add_child(UI.fill())
		r.add_child(UI.label(CountryVars.fmt(str(rid), float(best["v"])), UI.FS_SMALL, UI.MUTED, true))
		c.add_child(r)

# ---------------------------------------------------------------- filas de causas (compartidas con la pantalla)
static func kind_chip(cause: Dictionary) -> Control:
	var kind := str(cause.get("kind", ""))
	match kind:
		"policy": return UI.chip("Medida", UI.ACCENT)
		"shock":
			var sd := MacroSim.shock_def(str(cause.get("ref", "")))
			return UI.chip("Oportunidad" if bool(sd.get("good", false)) else "Crisis", UI.GOOD if bool(sd.get("good", false)) else UI.BAD)
		"structural": return UI.chip("Estructura", UI.FAINT)
		"link": return UI.chip("Relacionado", UI.PILL_SUB)
		"budget": return UI.chip("Presupuesto", UI.GOLD)
	return UI.chip("Economía", UI.D4_BLUE_D)

## Lista de causas: etiqueta de tipo, texto (con la ley de origen) y barra con el valor.
static func cause_rows(parent: Node, cv: CountryVars, var_id: String, list: Array, max_rows: int, compact: bool = false) -> void:
	var mx := 0.0001
	for c in list:
		mx = maxf(mx, absf(float((c as Dictionary)["value"])))
	var g := CountryVars.good_of(var_id)
	var unit := cv.cause_unit(var_id)
	var dec := 2 if mx < 1.0 else 1
	var shown := 0
	for c2 in list:
		if shown >= max_rows:
			break
		shown += 1
		var cd: Dictionary = c2
		var v := float(cd["value"])
		var col := UI.delta_color(v * float(g), 0.0) if g != 0 else (UI.ACCENT if v >= 0.0 else UI.D4_RED)
		var r := UI.hbox(8)
		r.custom_minimum_size = Vector2(0, 30)
		var chip := kind_chip(cd)
		chip.custom_minimum_size = Vector2(70 if compact else 86, 0)
		r.add_child(chip)
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nl := UI.label(str(cd["label"]), UI.FS_SMALL, UI.TEXT, true)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.tooltip_text = str(cd["label"])
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		tv.add_child(nl)
		var sub := str(cd.get("text", ""))
		if sub != "":
			var sl := UI.label(sub, UI.FS_TINY, UI.FAINT)
			sl.clip_text = true
			sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tv.add_child(sl)
		r.add_child(tv)
		if not compact:
			var bar := ColorRect.new()
			bar.color = col
			bar.custom_minimum_size = Vector2(maxf(2.0, 90.0 * absf(v) / mx), 8)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(bar)
		var vl := UI.label(("%s %s" % [UI.signed(v, dec), unit]).strip_edges(), UI.FS_SMALL, col, true)
		vl.custom_minimum_size = Vector2(70 if compact else 78, 0)
		vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(vl)
		parent.add_child(r)
