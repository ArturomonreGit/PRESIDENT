class_name MinistryScreen
extends Screen
## Panel de tu cartera dentro del Gobierno. Como ministro gestionas tu ministerio; como presidente puedes actuar sobre todos
## (siempre con el visto bueno del ministro). Los decretos se aplican sin pasar por el Congreso y cuestan capital político.

static var sel_idx := -1
static var tab := "ministry"

func build() -> void:
	m.eco.ensure()
	m.exec.ensure()
	var kind := m.exec.post_kind()
	if kind == "none":
		header("Cartera ministerial", "Ahora mismo tu partido no tiene ninguna cartera en el Gobierno.")
		return
	var list := m.exec.managed()
	if list.is_empty():
		header("Cartera ministerial", "No hay ministerios con competencias que gestionar.")
		return
	if not list.has(sel_idx):
		sel_idx = int(list[0])
	if kind == "minister":
		sel_idx = m.exec.post_index()
	var title := "Presidencia del Gobierno" if kind == "president" else "Ministerio de %s" % m.exec.ministry_name(m.exec.post_index())
	header(title, "Decretas sin pasar por el Congreso dentro de tus competencias. Cada decreto cuesta capital político y exige el consenso %s." % ("del ministro de cada cartera" if kind == "president" else "del presidente"))
	_kpis()
	_selector(list, kind)
	if tab == "budget":
		_budget(kind)
	else:
		_ministry(sel_idx, kind)

# ================================================================ cabecera
func _kpis() -> void:
	var inc := m.exec.monthly_income()
	var dir := m.exec.directive()
	kpi_row([
		{"title": "Capital político", "value": "%.0f / %.0f" % [m.exec.capital(), Executive.MAX_CAPITAL], "sub": "+%.1f por trimestre" % (inc * float(Rules.TURN_MONTHS)), "color": UI.ACCENT},
		{"title": "Confianza de la directiva", "value": "%.0f / 100" % dir, "sub": "Cumple los objetivos para mantenerla", "color": UI.GOOD if dir >= 50.0 else (UI.WARN if dir >= 30.0 else UI.BAD)},
		{"title": "Apoyo al Gobierno", "value": "%.0f / 100" % m.gov.approval(), "sub": "Estabilidad %.0f" % m.gov.stability(), "color": UI.TEXT},
		{"title": "Saldo público", "value": "%s bn €" % UI.signed(m.eco.balance(), 1), "sub": "%.1f %% del PIB" % m.eco.balance_pct(), "color": UI.GOOD if m.eco.balance() >= 0.0 else UI.BAD},
	])

func _selector(list: Array, kind: String) -> void:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	if kind == "president":
		for i in list:
			var idx: int = int(i)
			var b := UI.button(m.exec.ministry_name(idx), "primary" if tab == "ministry" and sel_idx == idx else "ghost", func() -> void:
				sel_idx = idx
				tab = "ministry"
				rebuild())
			b.custom_minimum_size = Vector2(0, 28)
			b.tooltip_text = "%s · %s" % [m.party_short(m.exec.party_of(idx)), m.exec.competency_text(idx)]
			fl.add_child(b)
	else:
		var b0 := UI.button("Mi ministerio", "primary" if tab == "ministry" else "ghost", func() -> void:
			tab = "ministry"
			rebuild())
		b0.custom_minimum_size = Vector2(0, 28)
		fl.add_child(b0)
	var bb := UI.button("Presupuestos (PGE)", "primary" if tab == "budget" else "ghost", func() -> void:
		tab = "budget"
		rebuild())
	bb.custom_minimum_size = Vector2(0, 28)
	fl.add_child(bb)
	add_child(fl)

# ================================================================ ministerio
func _ministry(idx: int, kind: String) -> void:
	var cols := columns(1.6, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var party_id := m.exec.party_of(idx)
	var head := UI.card(left, m.exec.ministry_name(idx), "Competencias: %s" % m.exec.competency_text(idx), m.party_color(party_id))
	var mn: Dictionary = m.ministers.minister_at(idx)
	var row := UI.hbox(10)
	row.add_child(UI.party_tag(m, party_id, UI.FS_BODY, true))
	row.add_child(UI.label(m.ministers.describe(mn, m.exec.ministry_name(idx)), UI.FS_SMALL, UI.MUTED))
	head.add_child(row)
	if kind == "president":
		head.add_child(UI.wrap_label("Para decretar en este ministerio necesitas el visto bueno de %s. Si se opone puedes forzarlo pagando más capital político y dañando la relación." % m.party_short(party_id) if party_id != m.pid() else "Este ministerio es de tu partido: tendrás pleno consenso.", UI.FS_SMALL, UI.FAINT))
	else:
		var pres := str(m.s.get("government_party_id", ""))
		head.add_child(UI.wrap_label("Tus decretos necesitan el visto bueno de la Presidencia (%s)." % m.party_short(pres), UI.FS_SMALL, UI.FAINT))
	var grid := GridContainer.new()
	grid.columns = 1 if m.exec.areas_of(idx).size() <= 1 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(grid)
	var area_ids: Array = m.exec.areas_of(idx)
	for aid in area_ids:
		_area_tile(grid, idx, str(aid))
	if area_ids.is_empty():
		var c2 := UI.card(left, "Sin medidas de política", "", UI.WARN)
		c2.add_child(UI.wrap_label("Las competencias de esta cartera se gestionan con presupuesto. Revisa la pestaña de Presupuestos.", UI.FS_SMALL, UI.MUTED))
	_indicators(right, idx)
	_objectives(right)
	_lines_card(right, idx)
	_decrees(left, idx, kind)

## Áreas que el jugador puede tocar desde la cartera: las de todos los ministerios que gestiona.
func _editable_areas() -> Array:
	var out: Array = []
	for i in m.exec.managed():
		for aid in m.exec.areas_of(int(i)):
			if not out.has(str(aid)):
				out.append(str(aid))
	return out

## Baldosa de un área de política (estilo Democracy 4): icono, resumen y medidas destacadas. Un clic abre la ficha completa.
func _area_tile(parent: Node, idx: int, aid: String) -> void:
	var area := Policies.area(aid)
	var col := Glyphs.area_color(aid)
	var all: Array = Policies.measures_of(aid)
	var dec := 0
	var changed: Array = []
	for it in all:
		var meas: Dictionary = it
		if m.exec.decreeable(meas):
			dec += 1
		if not is_equal_approx(m.eco.value(str(meas["id"])), float(meas["base"])):
			changed.append(meas)
	var open_id := str((changed[0] as Dictionary)["id"]) if not changed.is_empty() else (str((all[0] as Dictionary)["id"]) if not all.is_empty() else "")
	var open_dialog := func() -> void:
		if open_id != "":
			PolicyDialog.open(shell, m, open_id, _editable_areas(), func() -> void:
				if is_instance_valid(self) and is_inside_tree():
					rebuild())
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	var inner := UI.select_row(holder, false, open_dialog, col, 132.0)
	var badge := PolicyDialog.Badge.new(Glyphs.of_area(aid), col, 52.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(badge)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(v)
	var top := UI.hbox(6)
	var nm := UI.label(str(area.get("name", aid)), UI.FS_LEAD, UI.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(nm)
	if not changed.is_empty():
		top.add_child(UI.chip("%d cambiad%s" % [changed.size(), "a" if changed.size() == 1 else "as"], UI.WARN))
	v.add_child(top)
	var stats := "%d medidas · %d decretables" % [all.size(), dec]
	if dec == 0:
		stats = "%d medidas · todo por ley" % all.size()
	v.add_child(UI.label(stats, UI.FS_SMALL, UI.MUTED))
	var shown: Array = changed.duplicate()
	for it2 in all:
		if shown.size() >= 3:
			break
		if not shown.has(it2):
			shown.append(it2)
	for it3 in shown.slice(0, 3):
		var meas3: Dictionary = it3
		var r := UI.hbox(6)
		var n3 := UI.label(str(meas3["name"]), UI.FS_SMALL, UI.TEXT)
		n3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_child(n3)
		var cv := m.eco.value(str(meas3["id"]))
		var ch := not is_equal_approx(cv, float(meas3["base"]))
		var vl := UI.label(Policies.value_text(meas3, cv), UI.FS_SMALL, UI.WARN if ch else UI.MUTED, ch)
		vl.custom_minimum_size = Vector2(96, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_child(vl)
		v.add_child(r)
	inner.add_child(UI.label("›", UI.FS_H1, col, true))
	UI.pass_clicks(inner)

# ================================================================ paneles laterales
func _history_values(metric: String) -> Array:
	var vals: Array = []
	for h in m.eco.history():
		var hd: Dictionary = h
		match metric:
			"unemployment": vals.append(float(hd.get("unemployment", 0.0)))
			"deficit": vals.append(float(hd.get("deficit_pct", 0.0)))
			_:
				if not WorldSim.has(metric):
					vals.append(float((hd.get("quality", {}) as Dictionary).get(metric, 0.0)))
	if WorldSim.has(metric):
		return m.world.series(metric)
	return vals

func _history_labels() -> Array:
	var out: Array = []
	for h in m.eco.history():
		out.append(str((h as Dictionary).get("label", "")))
	return out

func _indicators(parent: Node, idx: int) -> void:
	var c := UI.card(parent, "Indicadores de tu ministerio", "Evolución desde el inicio de la legislatura", UI.GOOD)
	var shown := 0
	for aid in m.exec.areas_of(idx):
		var spec: Array = Executive.AREA_METRIC.get(str(aid), [])
		if spec.is_empty():
			continue
		var metric := str(spec[0])
		var now := 0.0
		var delta := 0.0
		var fmt := "%.0f"
		match metric:
			"deficit":
				now = -m.eco.balance_pct()
				fmt = "%.1f"
			"unemployment":
				now = float(m.eco.st().get("unemployment", 12.0))
				fmt = "%.1f"
			_:
				if WorldSim.has(metric):
					now = m.world.value(metric)
					delta = m.world.delta(metric, 12)
					fmt = "%." + str(int(WorldSim.def(metric).get("dec", 1))) + "f"
				else:
					now = m.eco.quality(metric)
					delta = m.eco.quality_delta(metric, 12)
		var good := (delta > 0.0) if int(spec[1]) > 0 else (delta < 0.0)
		var r := UI.hbox(8)
		r.add_child(UI.label(m.exec.metric_label(metric), UI.FS_BODY, UI.TEXT))
		r.add_child(UI.fill())
		r.add_child(UI.label(fmt % now, UI.FS_LEAD, UI.TEXT, true))
		if metric not in ["unemployment", "deficit"]:
			r.add_child(UI.label(UI.signed(delta, 1), UI.FS_SMALL, UI.GOOD if good else (UI.BAD if absf(delta) > 0.05 else UI.MUTED), true))
		c.add_child(r)
		var vals := _history_values(metric)
		if vals.size() >= 2:
			var chart := LineChart.new()
			chart.custom_minimum_size = Vector2(260, 96)
			chart.show_end_labels = false
			chart.value_fmt = "%.1f"
			chart.allow_negative = true
			chart.series = [{"id": metric, "name": "", "color": UI.ACCENT, "values": vals, "width": 2.5}]
			chart.x_labels = _history_labels()
			c.add_child(chart)
		shown += 1
	# Calidad de los servicios que financian las partidas del ministerio.
	for lid in m.exec.lines_of(idx):
		for q in Policies.quality():
			var qd: Dictionary = q
			if str(qd.get("domain", "")) != str(lid):
				continue
			var qid := str(qd["id"])
			var already := false
			for aid2 in m.exec.areas_of(idx):
				if str((Executive.AREA_METRIC.get(str(aid2), [""]) as Array)[0]) == qid:
					already = true
			if already:
				continue
			var qdelta := m.eco.quality_delta(qid, 12)
			var rq := UI.hbox(8)
			rq.add_child(UI.label(str(qd["name"]), UI.FS_BODY, UI.TEXT))
			rq.add_child(UI.fill())
			rq.add_child(UI.label("%.0f" % m.eco.quality(qid), UI.FS_LEAD, UI.TEXT, true))
			rq.add_child(UI.label(UI.signed(qdelta, 1), UI.FS_SMALL, UI.delta_color(qdelta), true))
			c.add_child(rq)
			var qv := _history_values(qid)
			if qv.size() >= 2:
				var qchart := LineChart.new()
				qchart.custom_minimum_size = Vector2(260, 96)
				qchart.show_end_labels = false
				qchart.value_fmt = "%.1f"
				qchart.series = [{"id": qid, "name": "", "color": UI.ACCENT, "values": qv, "width": 2.5}]
				qchart.x_labels = _history_labels()
				c.add_child(qchart)
			shown += 1
	if shown == 0:
		empty_note(c, "Esta cartera no controla indicadores de la economía: tu palanca es el gasto de sus partidas.")
	# Opinión de los grupos más afectados por tus medidas.
	var weights: Dictionary = {}
	for it in m.exec.measures_for(idx):
		for g in ((it as Dictionary).get("hits", {}) as Dictionary).keys():
			weights[g] = float(weights.get(g, 0.0)) + absf(float(it["hits"][g]))
	var gk: Array = weights.keys()
	gk.sort_custom(func(a, b) -> bool: return float(weights[a]) > float(weights[b]))
	if not gk.is_empty():
		c.add_child(UI.hsep())
		c.add_child(UI.label("OPINIÓN DE LOS GRUPOS CLAVE", UI.FS_TINY, UI.MUTED, true))
		for g2 in gk.slice(0, 4):
			var sat := m.eco.satisfaction(str(g2))
			var d := m.eco.sat_delta(str(g2), 6)
			var rr := UI.hbox(8)
			rr.add_child(UI.label(Policies.group_name(str(g2)), UI.FS_SMALL, UI.TEXT))
			var mt := UI.meter(sat, 100.0, UI.GOOD if sat >= 55.0 else (UI.WARN if sat >= 40.0 else UI.BAD), 6)
			mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mt.custom_minimum_size = Vector2(80, 6)
			rr.add_child(mt)
			rr.add_child(UI.label("%.0f" % sat, UI.FS_SMALL, UI.TEXT, true))
			rr.add_child(UI.label(UI.signed(d, 1), UI.FS_TINY, UI.delta_color(d)))
			c.add_child(rr)

func _objectives(parent: Node) -> void:
	var c := UI.card(parent, "Mínimos de la directiva", "Si no los cumples pierdes su confianza", UI.WARN)
	var list := m.exec.objectives()
	if list.is_empty():
		empty_note(c, "La directiva no te ha fijado objetivos concretos.")
	for o in list:
		var od: Dictionary = o
		var metric := str(od["metric"])
		var now := _metric_now(metric)
		var start := float(od["start"])
		var target := float(od["target"])
		var prog := clampf((now - start) / (target - start), 0.0, 1.0) if not is_equal_approx(target, start) else 1.0
		var status := str(od["status"])
		var r := UI.hbox(8)
		var t := UI.wrap_label("%s: %.1f → %.1f" % [m.exec.metric_label(metric), start, target], UI.FS_SMALL, UI.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		match status:
			"met": r.add_child(UI.chip("Cumplido", UI.GOOD, true))
			"failed": r.add_child(UI.chip("Incumplido", UI.BAD, true))
			_: r.add_child(UI.chip("Mes %d" % int(od["due"]), UI.MUTED))
		c.add_child(r)
		var mt := UI.meter(prog * 100.0, 100.0, UI.GOOD if prog >= 0.99 else UI.ACCENT, 6)
		c.add_child(mt)
		c.add_child(UI.label("Ahora %.1f" % now, UI.FS_TINY, UI.FAINT))

func _metric_now(metric: String) -> float:
	match metric:
		"deficit": return -m.eco.balance_pct()
		"unemployment": return float(m.eco.st().get("unemployment", 12.0))
		"approval": return m.gov.approval()
	if WorldSim.has(metric):
		return m.world.value(metric)
	return m.eco.quality(metric)

func _lines_card(parent: Node, idx: int) -> void:
	var lines := m.exec.lines_of(idx)
	if lines.is_empty():
		return
	var c := UI.card(parent, "Presupuesto de tu ministerio", "Estado de los PGE: %s · puedes mover el crédito ±2,5 %% por decreto" % m.exec.pge_status(), UI.ACCENT)
	var total := 0.0
	for lid in lines:
		var lid_s := str(lid)
		var bd := Policies.entry(Policies.budget(), lid_s)
		var amt := m.eco.budget_spending(lid_s)
		total += amt
		var r := UI.hbox(8)
		var nm := UI.label(str(bd.get("name", lid)), UI.FS_SMALL, UI.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		if m.exec.can_manage(idx):
			r.add_child(UI.button("−", "secondary", func() -> void: _adjust(idx, lid_s, -1.0), 30))
		r.add_child(UI.label("%.1f bn €" % amt, UI.FS_SMALL, UI.TEXT, true))
		r.add_child(UI.label("%.1f %%" % (m.exec.factor(lid_s) * 100.0), UI.FS_TINY, UI.delta_color(m.exec.factor(lid_s) - 1.0)))
		if m.exec.can_manage(idx):
			r.add_child(UI.button("+", "secondary", func() -> void: _adjust(idx, lid_s, 1.0), 30))
		c.add_child(r)
	c.add_child(UI.label("Total: %.1f bn € (%.1f %% del gasto público)" % [total, total / maxf(1.0, m.eco.spending_total()) * 100.0], UI.FS_TINY, UI.MUTED))

func _adjust(idx: int, line_id: String, dirn: float) -> void:
	var key := "line_" + line_id
	var r := m.exec.adjust_line(idx, line_id, dirn, bool(PanelScreen.forced.get(key, false)))
	if bool(r["ok"]):
		shell.toast("Crédito modificado. Coste: %d de capital político." % int(r["cost"]), "good")
		PanelScreen.forced.erase(key)
		shell.refresh()
	else:
		if bool(r.get("needs_force", false)):
			PanelScreen.forced[key] = true
			shell.toast("%s Pulsa de nuevo para forzarlo (+8 de capital)." % str(r["error"]), "warn")
		else:
			shell.toast(str(r["error"]), "bad")
	rebuild()

func _decrees(parent: Node, idx: int, kind: String) -> void:
	var c := UI.card(parent, "Decretos recientes", "", UI.ACCENT)
	var shown := 0
	for d in m.exec.st().get("decrees", []):
		var dd: Dictionary = d
		if kind == "minister" and str(dd.get("ministry", "")) != m.exec.ministry_name(idx):
			continue
		if kind == "president" and str(dd.get("ministry", "")) != m.exec.ministry_name(idx):
			continue
		var row := UI.hbox(8)
		row.add_child(UI.chip("Tuyo" if bool(dd.get("player", false)) else m.party_short(str(dd.get("party", ""))), UI.ACCENT if bool(dd.get("player", false)) else UI.MUTED))
		row.add_child(UI.wrap_label("M%d · %s: %s → %s" % [int(dd.get("month", 0)), str(dd.get("measure", "")), str(dd.get("from", "")), str(dd.get("to", ""))], UI.FS_SMALL, UI.TEXT))
		c.add_child(row)
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		empty_note(c, "Aún no se ha decretado nada en este ministerio.")

# ================================================================ presupuestos
func _budget(kind: String) -> void:
	var cols := columns(1.5, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var p := m.exec.pge()
	var open := m.exec.pge_open()
	var status := m.exec.pge_status()
	var st := UI.card(left, "Presupuestos Generales del Estado", "", UI.WARN)
	var row := UI.hbox(8)
	row.add_child(UI.chip("Aprobados" if status == "aprobado" else "Prorrogados", UI.GOOD if status == "aprobado" else UI.WARN, true))
	row.add_child(UI.label("Ejercicio %d" % int(p.get("year", 0)), UI.FS_SMALL, UI.MUTED))
	st.add_child(row)
	var nxt := 0
	for mo in Executive.PGE_MONTHS:
		if int(mo) > m.gov_month:
			nxt = int(mo)
			break
	if open:
		st.add_child(UI.wrap_label("El plazo está abierto: ajusta las partidas, comprueba los apoyos y presenta el proyecto al Congreso antes de que acabe el mes.", UI.FS_BODY, UI.TEXT))
	elif nxt > 0:
		st.add_child(UI.wrap_label("Los próximos Presupuestos se elaboran en el mes %d de legislatura. Mientras tanto rigen los actuales (prorrogados si el Congreso los tumbó)." % nxt, UI.FS_SMALL, UI.MUTED))
	else:
		st.add_child(UI.wrap_label("No quedan más Presupuestos en esta legislatura.", UI.FS_SMALL, UI.MUTED))
	var lines_card := UI.card(left, "Partidas por ministerio", "Dotación respecto a los Presupuestos vigentes", UI.ACCENT)
	var mine: Array = m.exec.lines_of(m.exec.post_index()) if kind == "minister" else []
	for b in Policies.budget():
		var bd: Dictionary = b
		var bid := str(bd["id"])
		var owner := m.exec.line_owner(bid)
		var r := UI.hbox(8)
		r.custom_minimum_size = Vector2(0, 30)
		var nm := UI.label(str(bd["name"]), UI.FS_BODY, UI.TEXT, bid in mine)
		nm.custom_minimum_size = Vector2(190, 0)
		r.add_child(nm)
		var own := UI.label(m.exec.ministry_name(owner), UI.FS_TINY, UI.FAINT)
		own.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(own)
		r.add_child(UI.label("%.1f bn €" % (m.exec.line_amount(bid, open)), UI.FS_SMALL, UI.TEXT, true))
		if open and kind == "president":
			var cur := m.exec.draft_factor(bid)
			r.add_child(UI.button("−", "secondary", func() -> void:
				m.exec.set_draft_factor(bid, cur - Executive.FACTOR_STEP)
				rebuild(), 34))
			r.add_child(UI.label("%.1f %%" % (cur * 100.0), UI.FS_SMALL, UI.delta_color(cur - m.exec.factor(bid)), true))
			r.add_child(UI.button("+", "secondary", func() -> void:
				m.exec.set_draft_factor(bid, cur + Executive.FACTOR_STEP)
				rebuild(), 34))
		else:
			r.add_child(UI.label("%.1f %%" % (m.exec.factor(bid) * 100.0), UI.FS_SMALL, UI.MUTED))
			if kind == "minister" and bid in mine:
				var req := m.exec.request_of(bid)
				if req > 0.0:
					r.add_child(UI.chip("Pides %.1f %%" % (req * 100.0), UI.ACCENT))
				else:
					r.add_child(UI.button("Pedir +5 %", "secondary", func() -> void:
						m.exec.request_funds(bid, m.exec.factor(bid) + 0.05)
						shell.toast("Has pedido más dotación a la Presidencia para los próximos Presupuestos.", "good")
						rebuild()))
		lines_card.add_child(r)
	if kind == "president":
		_budget_draft_panel(right, open)
	else:
		var c := UI.card(right, "Cómo funcionan", "", UI.GOOD)
		c.add_child(UI.wrap_label("La Presidencia redacta los Presupuestos y los vota el Congreso. Como ministro puedes pedir más dotación para tus partidas: se concederá según la relación y el margen fiscal. Si los Presupuestos caen, se prorrogan los anteriores.", UI.FS_SMALL, UI.MUTED))
		var req_card := UI.card(right, "Calidad de los servicios", "Más dotación mejora la calidad con el tiempo", UI.ACCENT)
		for q in Policies.quality():
			var qd: Dictionary = q
			var dom := str(qd.get("domain", ""))
			if dom == "" or not (dom in mine):
				continue
			req_card.add_child(UI.label("%s: %.0f / 100" % [str(qd["name"]), m.eco.quality(str(qd["id"]))], UI.FS_SMALL, UI.TEXT))

func _budget_draft_panel(parent: Node, open: bool) -> void:
	var c := UI.card(parent, "Impacto del borrador" if open else "Resumen fiscal", "", UI.WARN)
	var delta := m.exec.draft_delta() if open else 0.0
	c.add_child(UI.label("Gasto total %.1f bn €" % (m.eco.spending_total() + delta), UI.FS_LEAD, UI.TEXT, true))
	c.add_child(UI.label("Variación frente a lo vigente: %s bn €" % UI.signed(delta, 1), UI.FS_SMALL, UI.delta_color(-delta)))
	var after := -(m.eco.balance() - delta) / maxf(1.0, m.eco.gdp()) * 100.0
	c.add_child(UI.label("Déficit resultante %.2f %% del PIB (ahora %.2f %%)" % [after, -m.eco.balance_pct()], UI.FS_SMALL, UI.TEXT))
	if not open:
		return
	var law := {"id": "pge_preview", "title": "Presupuestos", "area": "", "proposer": m.pid(), "kind": "presupuestos", "changes": {}, "goodwill": {}, "budget": (m.exec.pge()["draft"] as Dictionary).duplicate()}
	var fc := m.laws.forecast(law)
	var ok := int(fc["yes"]) > int(fc["no"])
	var s := UI.card(parent, "Apoyos previstos", "Con las posturas actuales", UI.GOOD if ok else UI.WARN)
	var line := UI.hbox(14)
	line.add_child(UI.label("%d a favor" % int(fc["yes"]), UI.FS_LEAD, UI.GOOD, true))
	line.add_child(UI.label("%d en contra" % int(fc["no"]), UI.FS_LEAD, UI.BAD, true))
	line.add_child(UI.label("%d abst." % int(fc["abstain"]), UI.FS_BODY, UI.MUTED))
	s.add_child(line)
	var mb := UI.meter(float(fc["yes"]), 350.0, UI.GOOD if ok else UI.WARN, 8)
	mb.marker = 175.0
	s.add_child(mb)
	s.add_child(UI.label("Los Presupuestos %s." % ("saldrían adelante" if ok else "NO saldrían adelante: se prorrogarían los actuales"), UI.FS_BODY, UI.GOOD if ok else UI.BAD, true))
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		if m.is_player(pid):
			continue
		var vote := str((fc["by_party"] as Dictionary).get(pid, "abstain"))
		var r := UI.hbox(8)
		var tag := UI.party_tag(m, pid, UI.FS_SMALL, false)
		tag.custom_minimum_size = Vector2(96, 0)
		r.add_child(tag)
		r.add_child(UI.label("%d" % m.seats_of(pid), UI.FS_SMALL, UI.FAINT))
		r.add_child(UI.fill())
		match vote:
			"yes": r.add_child(UI.chip("A favor", UI.GOOD, true))
			"no": r.add_child(UI.chip("En contra", UI.BAD, true))
			_: r.add_child(UI.chip("Abstención", UI.MUTED, true))
		s.add_child(r)
	var send := UI.button("Presentar al Congreso", "primary", func() -> void:
		m.exec.submit_pge(false)
		shell.toast("Presupuestos registrados: se votarán en el próximo Pleno.", "good")
		shell.refresh()
		rebuild())
	s.add_child(send)
