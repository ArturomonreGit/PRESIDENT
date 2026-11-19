extends Screen
## Resumen: panel principal dependiente de la fase.

func build() -> void:
	_pending_strip()
	match m.phase:
		"campaign": _campaign()
		"results": _results_home()
		"investiture": _investiture_home()
		"cabinet_design": _cabinet_home()
		"legislature": _legislature()
		_: _campaign()

## Franja de asuntos pendientes: lo que caduca y la mesa abierta, con acceso directo. Solo aparece si hay algo que decidir.
func _pending_strip() -> void:
	if m.attention_count() <= 0:
		return
	var c := UI.card(self, "Asuntos pendientes", "Lo que caduca si no respondes", UI.WARN)
	var clock := m.day if m.phase == "campaign" else m.gov_month
	if m.diplomacy.active():
		var cur := m.diplomacy.current()
		var row := UI.hbox(10)
		row.add_child(UI.chip("Mesa abierta", UI.D4_BLUE, true))
		var t := UI.label("Negociación con %s · %s" % [m.party_name(str(cur.get("with", ""))), str((Diplomacy.TOPICS.get(str(cur.get("topic", "")), {"name": "Mesa"}) as Dictionary)["name"])], UI.FS_BODY, UI.TEXT, true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		row.add_child(t)
		var wid := str(cur.get("with", ""))
		var wtopic := str(cur.get("topic", ""))
		var back := func() -> void:
			shell.open_meeting(wid, wtopic)
		row.add_child(UI.pill("Volver a la mesa", false, back, false, UI.PILL_GO))
		c.add_child(row)
	var n := 0
	var max_rows := 2
	for pm in m.pending_messages():
		if n >= max_rows:
			break
		n += 1
		var d: Dictionary = pm
		var row2 := UI.hbox(10)
		var left_days := int(d.get("expires_day", clock + 99)) - clock + 1
		row2.add_child(UI.chip(("Caduca en %d %s" % [maxi(left_days, 0), ("día" if left_days == 1 else "días") if m.phase == "campaign" else ("mes" if left_days == 1 else "meses")]) if d.has("expires_day") else "Pendiente", UI.BAD if left_days <= 1 else UI.WARN, left_days <= 1))
		var t2 := UI.label("%s · %s" % [str(d.get("category", "")), str(d.get("title", ""))], UI.FS_BODY, UI.TEXT)
		t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2.clip_text = true
		row2.add_child(t2)
		c.add_child(row2)
	var more := m.pending_count() - n
	var foot := UI.hbox(10)
	if more > 0:
		foot.add_child(UI.label("y %d más en la Bandeja" % more, UI.FS_SMALL, UI.MUTED))
	foot.add_child(UI.fill())
	var go_inbox := func() -> void:
		shell.go("inbox")
	foot.add_child(UI.pill("Abrir la Bandeja", false, go_inbox, false, UI.PILL_WARN))
	c.add_child(foot)

# ---------------------------------------------------------------- campaña
func _campaign() -> void:
	var proj := m.election.project_seats()
	var seats := int(proj.get(m.pid(), 0))
	var target := int(m.d("objective").get("target_seats", 1))
	var trend := m.campaign.trend(m.pid())
	kpi_row([
		{"title": "Intención de voto", "value": "%.1f%%" % m.player_poll(), "sub": "%s en %s" % [UI.signed(trend, 1), m.campaign.trend_label()], "sub_color": UI.delta_color(trend)},
		{"title": "Escaños proyectados", "value": str(seats), "sub": "Objetivo %d" % target, "sub_color": UI.GOOD if seats >= target else UI.WARN},
		{"title": "Confianza", "value": "%.0f" % m.trust, "sub": "de 100"},
		{"title": "Visibilidad", "value": "%.0f" % m.visibility, "sub": "de 100"},
		{"title": "Impulso", "value": UI.signed(m.momentum, 1), "color": UI.delta_color(m.momentum, 0.2), "sub": "momentum"},
		{"title": "Tiempo", "value": "%d días" % (Rules.CAMPAIGN_LENGTH_DAYS - m.day), "sub": "hasta las elecciones"},
	])
	var cl := cols([1.3, 1.0])
	var left: VBoxContainer = cl[0]
	var right: VBoxContainer = cl[1]

	var c1 := UI.card(left, "Evolución de la intención de voto", "Últimas semanas", UI.ACCENT)
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(300, 230)
	setup_poll_chart(chart, 4, 12)
	c1.add_child(chart)

	var c2 := UI.card(left, "Temas de la campaña", "Lo que preocupa a la ciudadanía", UI.WARN)
	var sal: Dictionary = m.campaign.salience()
	var ids: Array = sal.keys()
	ids.sort_custom(func(x, y) -> bool: return float(sal[x]) > float(sal[y]))
	for id in ids:
		var row := UI.hbox(10)
		var in_prog := m.campaign.program().has(str(id))
		var name := UI.label(Rules.issue_name(str(id)), UI.FS_BODY, UI.TEXT if in_prog else UI.MUTED, in_prog)
		name.custom_minimum_size = Vector2(150, 0)
		row.add_child(name)
		var bar := UI.meter(float(sal[id]) * 100.0, 30.0, UI.GOOD if in_prog else UI.FAINT, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var pct := UI.label("%.0f%%" % (float(sal[id]) * 100.0), UI.FS_SMALL, UI.MUTED)
		pct.custom_minimum_size = Vector2(36, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		if in_prog:
			row.add_child(UI.chip("En tu programa", UI.GOOD))
		c2.add_child(row)
	c2.add_child(UI.label("Cobertura del programa: %.0f%% de la agenda pública" % (m.campaign.program_coverage() * 100.0), UI.FS_SMALL, UI.MUTED))

	var c3 := UI.card(right, "Hoy · %s" % m.date_for_campaign_day(m.day), "", UI.GOOD)
	var today := m.campaign.events_on(m.day)
	if today.is_empty():
		empty_note(c3, "No tienes actos hoy. Pulsa CONTINUAR para avanzar hasta el próximo evento o abre la agenda para programar actos.")
		c3.add_child(UI.button("Abrir agenda", "secondary", shell.go.bind("agenda")))
	for e in today:
		_event_line(c3, e as Dictionary)
	_image_card(right)
	_country_card(right)

func _event_line(parent: Node, ev: Dictionary) -> void:
	var col := Color(str((Rules.EVENT_TYPES.get(str(ev["type"]), {"color": "#8FA3B8"}) as Dictionary)["color"]))
	var row := UI.hbox(10)
	var bar := ColorRect.new()
	bar.color = col
	bar.custom_minimum_size = Vector2(4, 36)
	row.add_child(bar)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(str(ev["title"]), UI.FS_BODY, UI.TEXT, true))
	v.add_child(UI.label("%02d:00 · %s · %s" % [int(ev["hour"]), str(ev["type"]), str(ev["region"])], UI.FS_SMALL, UI.MUTED))
	row.add_child(v)
	if str(ev.get("status", "")) == "done":
		row.add_child(UI.chip("Hecho", UI.GOOD))
	parent.add_child(row)

func _message_line(parent: Node, msg: Dictionary) -> void:
	var row := UI.hbox(8)
	var dot := ColorRect.new()
	dot.color = UI.tone_color(str(msg.get("tone", "neutral"))) if not bool(msg.get("read", true)) else UI.BORDER
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var t := UI.label(str(msg.get("title", "")), UI.FS_BODY, UI.TEXT if not bool(msg.get("read", true)) else UI.MUTED, not bool(msg.get("read", true)))
	t.clip_text = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	parent.add_child(row)

# ---------------------------------------------------------------- resultados / investidura / gobierno
func _results_home() -> void:
	var leader := m.election.leading_party()
	var hero := UI.hero(self, Color(m.party_color(leader), 0.20), Color(m.party_color(leader), 0.6))
	hero.add_child(UI.eyebrow("Escrutinio completo", m.party_color(leader).lightened(0.3)))
	hero.add_child(UI.label("%s gana las elecciones con %d escaños" % [m.party_short(leader), m.seats_of(leader)], UI.FS_H1, UI.TEXT, true))
	var obj := m.d("objective")
	var met := bool(obj.get("met", false))
	hero.add_child(UI.label("Tu partido: %d escaños (%.1f%% de los votos). Objetivo de la dirección: %d → %s." % [m.seats_of(m.pid()), m.vote_share_of(m.pid()), int(obj.get("target_seats", 0)), "cumplido" if met else "no cumplido"], UI.FS_LEAD, UI.GOOD if met else UI.WARN))
	hero.add_child(UI.wrap_label("Pulsa INICIAR CONSULTAS para que el Rey abra la ronda de investidura. Ninguna fuerza tiene asegurada la mayoría de %d diputados: tocará negociar." % Rules.MAJORITY, UI.FS_BODY, UI.MUTED))
	_hemicycle_card(self)

func _hemicycle_card(parent: Node, highlight: Array = []) -> void:
	var c := UI.card(parent, "Congreso de los Diputados", "350 escaños · mayoría %d" % Rules.MAJORITY, UI.ACCENT)
	var h := ResultsScreen.make_hemicycle(m, highlight)
	h.custom_minimum_size = Vector2(300, 300)
	c.add_child(h)

func _investiture_home() -> void:
	var cand := m.gov.candidate_id()
	var hero := UI.hero(self, Color(m.party_color(cand), 0.18), Color(m.party_color(cand), 0.55))
	hero.add_child(UI.eyebrow("Ronda de investidura"))
	hero.add_child(UI.label("Candidato: %s" % m.party_name(cand), UI.FS_H1, UI.TEXT, true))
	var role_text := "Eres el candidato: negocia con los grupos y reúne %d votos." % Rules.MAJORITY if m.is_player(cand) else "Tu partido puede decidir su voto y pactar condiciones de apoyo con el candidato."
	hero.add_child(UI.wrap_label(role_text, UI.FS_LEAD, UI.TEXT))
	hero.add_child(UI.button("Ir a la mesa de negociación", "primary", shell.go.bind("investiture"), 260))
	_hemicycle_card(self, [cand] + m.gov.partners())

func _cabinet_home() -> void:
	var hero := UI.hero(self, Color(UI.GOOD, 0.14), Color(UI.GOOD, 0.5))
	hero.add_child(UI.eyebrow("Investidura superada", UI.GOOD))
	hero.add_child(UI.label("Diseña el Consejo de Ministros", UI.FS_H1, UI.TEXT, true))
	hero.add_child(UI.wrap_label("Reparte las carteras entre los partidos del Ejecutivo. Cada formación de Gobierno debe tener al menos un ministerio.", UI.FS_LEAD, UI.MUTED))
	hero.add_child(UI.button("Abrir Consejo de Ministros", "primary", shell.go.bind("cabinet"), 260))
	_hemicycle_card(self, m.gov.government_parties() + m.gov.partners())

## Agenda mediática del trimestre: ofertas de los medios que puedes aceptar, delegar o declinar.
func _media_card(parent: Node) -> void:
	var offers := m.media.open_offers()
	if offers.is_empty():
		return
	var c := UI.card(parent, "Agenda mediática", "%d huecos libres este trimestre" % m.media.slots_left(), UI.WARN)
	for item in offers:
		var o: Dictionary = item
		var oid := int(o["id"])
		var row := UI.hbox(8)
		var kind := str(o["kind"])
		row.add_child(UI.chip(str((MediaAgenda.KINDS[kind] as Dictionary)["label"]), UI.BAD if kind == "urgent" else (UI.WARN if kind == "prime" else UI.MUTED), kind != "routine"))
		var t := UI.label(str(o["title"]), UI.FS_SMALL, UI.TEXT)
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		var go_b := UI.button("Plató", "primary", func() -> void: shell.start_media_offer(oid))
		go_b.custom_minimum_size = Vector2(70, 30)
		row.add_child(go_b)
		var de_b := UI.button("Delegar", "ghost", func() -> void: shell.delegate_media_offer(oid))
		de_b.custom_minimum_size = Vector2(80, 30)
		row.add_child(de_b)
		c.add_child(row)

func _legislature() -> void:
	var gov_id := str(m.s.get("government_party_id", ""))
	kpi_row([
		{"title": "Apoyo al Gobierno", "value": "%.0f" % m.gov.approval(), "sub": "de 100"},
		{"title": "Estabilidad", "value": "%.0f" % m.gov.stability(), "sub": "mayoría parlamentaria", "color": UI.GOOD if m.gov.stability() > 40 else UI.BAD},
		{"title": "Economía", "value": "%.0f" % m.gov.economy(), "sub": "índice"},
		{"title": "Presidencia", "value": m.party_short(gov_id), "sub": "Trimestre %d de %d" % [m.turn(), Rules.LEGISLATURE_TURNS]},
		{"title": "Tu papel", "value": {"government": "Gobierno", "partner": "Socio", "opposition": "Oposición", "none": "—"}[m.role()], "sub": "%d iniciativas" % m.gov.bills_left()},
		{"title": "Confianza interna", "value": "%.0f" % m.itrust.value(), "sub": "%s%s" % [str(m.itrust.state()["name"]), " · %d mandato%s" % [m.itrust.open_count(), "" if m.itrust.open_count() == 1 else "s"] if m.itrust.open_count() > 0 else ""], "color": UI.GOOD if str(m.itrust.state()["tone"]) == "good" else (UI.WARN if str(m.itrust.state()["tone"]) == "warn" else UI.BAD)},
	])
	_country_strip()
	var cl := cols([1.5, 1.0])
	var left: VBoxContainer = cl[0]
	var right: VBoxContainer = cl[1]
	var c1 := UI.card(left, "Intención de voto durante la legislatura", "", UI.ACCENT)
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(300, 270)
	setup_poll_chart(chart, 4, 12)
	c1.add_child(chart)
	_media_card(left)
	if not m.gov.partners().is_empty():
		var c3 := UI.card(left, "Socios de la mayoría", "", UI.WARN)
		var sat := m.d("partner_satisfaction")
		var pg := UI.grid(2, 24, 6)
		c3.add_child(pg)
		for id in m.gov.partners():
			var row := UI.hbox(10)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var tag := UI.party_tag(m, str(id))
			tag.custom_minimum_size = Vector2(110, 0)
			row.add_child(tag)
			var v := float(sat.get(str(id), 60.0))
			var bar := UI.meter(v, 100.0, UI.GOOD if v >= 50 else UI.BAD, 8)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			row.add_child(UI.label("%.0f" % v, UI.FS_BODY, UI.TEXT, true))
			pg.add_child(row)
	_image_card(right)
	m.agr.ensure()
	var pending: Array = []
	var in_gov: bool = m.coal.gov_id() == m.pid() or m.coal.party_ids().has(m.pid())
	for cm in m.a("commitments"):
		if in_gov and not (m.agr.state_of(cm as Dictionary) in Agreements.TERMINAL):
			pending.append(cm)
	if not pending.is_empty():
		var c4 := UI.card(right, "Compromisos del acuerdo", "%d vigentes" % pending.size(), UI.GOOD)
		for cm2 in pending.slice(0, 2):
			var com: Dictionary = cm2
			var row2 := UI.hbox(8)
			row2.add_child(UI.chip(m.agr.state_name(com), NegUI.STATE_COLOR.get(m.agr.state_of(com), UI.WARN)))
			var ctxt := UI.label("%s: %s" % [m.party_short(str(com["party"])), str(com["text"])], UI.FS_SMALL, UI.TEXT)
			ctxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctxt.clip_text = true
			ctxt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			ctxt.tooltip_text = str(com["text"])
			row2.add_child(ctxt)
			c4.add_child(row2)
		if pending.size() > 2:
			c4.add_child(UI.label("y %d más en Mesa de coalición" % (pending.size() - 2), UI.FS_TINY, UI.FAINT))

## Franja «Estado del país»: los grandes indicadores con su tendencia de los últimos 5 años.
func _country_strip() -> void:
	m.eco.ensure()
	var hist: Array = m.eco.history()
	if hist.size() < 3:
		return
	var defs := [
		{"k": "growth", "name": "Crecimiento del PIB", "fmt": "%.1f %%", "good": 1},
		{"k": "unemployment", "name": "Paro", "fmt": "%.1f %%", "good": -1},
		{"k": "inflation", "name": "Inflación", "fmt": "%.1f %%", "good": -1},
		{"k": "deficit_pct", "name": "Déficit público", "fmt": "%.1f %% PIB", "good": -1},
		{"k": "debt_pct", "name": "Deuda pública", "fmt": "%.0f %% PIB", "good": -1},
		{"k": "avg_sat", "name": "Satisfacción con servicios", "fmt": "%.0f", "good": 1},
	]
	var row := UI.hbox(10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)
	var span := mini(60, hist.size())
	for d in defs:
		var dd: Dictionary = d
		var vals: Array = []
		for i in range(hist.size() - span, hist.size()):
			vals.append(float((hist[i] as Dictionary).get(str(dd["k"]), 0.0)))
		var now := float(vals[vals.size() - 1])
		var back := float(vals[maxi(0, vals.size() - 13)])
		var delta := now - back
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.BORDER, 10, 1, 14, 10))
		row.add_child(pc)
		var v := UI.vbox(2)
		pc.add_child(v)
		v.add_child(UI.label(str(dd["name"]).to_upper(), UI.FS_TINY, UI.MUTED, true))
		var r := UI.hbox(6)
		r.add_child(UI.label(str(dd["fmt"]) % now, UI.FS_H2, UI.TEXT, true))
		var good := float(dd["good"])
		var col := UI.delta_color(delta * good, 0.05)
		r.add_child(UI.label("%s en 12 m" % UI.signed(delta, 1), UI.FS_TINY, col, true))
		v.add_child(r)
		var sp := Spark.new()
		sp.custom_minimum_size = Vector2(0, 34)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.values = vals
		sp.color = col if absf(delta) > 0.05 else UI.ACCENT
		v.add_child(sp)

## Imagen pública: cómo te ven los votantes (cinco dimensiones), por segmentos y la última prensa.
func _image_card(parent: Node) -> void:
	var c := UI.card(parent, "Imagen pública", "Cómo te ven los votantes", UI.WARN)
	var port_row := UI.hbox(12)
	port_row.add_child(UI.leader_portrait(m, m.pid(), 64, "smug" if m.enc.image_avg() >= 52.0 else ("worried" if m.enc.image_avg() < 46.0 else "neutral")))
	var pv := UI.vbox(0)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pv.add_child(UI.label(m.leader_name(m.pid()), UI.FS_LEAD, UI.TEXT, true))
	pv.add_child(UI.label(Leader.tagline(m.character()), UI.FS_SMALL, UI.MUTED))
	port_row.add_child(pv)
	c.add_child(port_row)
	for k in Encounters.IMAGE_DIMS.keys():
		var v := float(m.enc.image().get(k, 50.0))
		var row := UI.hbox(8)
		var l := UI.label(str(Encounters.IMAGE_DIMS[k]), UI.FS_SMALL, UI.MUTED)
		l.custom_minimum_size = Vector2(80, 0)
		row.add_child(l)
		var bar := UI.meter(v, 100.0, UI.GOOD if v >= 55.0 else (UI.BAD if v < 45.0 else UI.ACCENT), 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(UI.label("%.0f" % v, UI.FS_SMALL, UI.TEXT, true))
		c.add_child(row)
	c.add_child(UI.hsep())
	c.add_child(UI.label("OPINIÓN POR SEGMENTOS", UI.FS_TINY, UI.MUTED, true))
	for sid in Encounters.SEGMENTS.keys():
		var sv := float(m.enc.seg().get(sid, 50.0))
		var row2 := UI.hbox(8)
		var l2 := UI.label(str(Encounters.SEGMENTS[sid]["name"]), UI.FS_SMALL, UI.MUTED)
		l2.custom_minimum_size = Vector2(170, 0)
		l2.clip_text = true
		row2.add_child(l2)
		var bar2 := UI.meter(sv, 100.0, UI.GOOD if sv >= 55.0 else (UI.BAD if sv < 45.0 else UI.ACCENT), 6)
		bar2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row2.add_child(bar2)
		c.add_child(row2)
	var hem := m.enc.hemeroteca()
	if not hem.is_empty():
		c.add_child(UI.hsep())
		c.add_child(UI.label("HEMEROTECA", UI.FS_TINY, UI.MUTED, true))
		for i in range(mini(3, hem.size())):
			var h: Dictionary = hem[i]
			var col := UI.GOOD if str(h.get("tone", "")) == "positive" else (UI.BAD if str(h.get("tone", "")) == "warning" else UI.MUTED)
			c.add_child(UI.wrap_label("%s — «%s»" % [str(h.get("outlet", "")), str(h.get("headline", ""))], UI.FS_SMALL, col))

## Cuentas y datos básicos del país (punto de partida basado en España).
func _country_card(parent: Node) -> void:
	m.eco.ensure()
	var e := m.eco.st()
	var c := UI.card(parent, "El país hoy", "Punto de partida de esta legislatura", UI.TEXT)
	var gdp := m.eco.gdp()
	var items := [
		["PIB", "%s bn €" % ("%.0f" % gdp), UI.TEXT],
		["Crecimiento", "%.1f %%" % float(e.get("growth", 0.0)), UI.delta_color(float(e.get("growth", 0.0)) - 1.5)],
		["Paro", "%.1f %%" % float(e.get("unemployment", 0.0)), UI.BAD if float(e.get("unemployment", 0.0)) > 11.0 else UI.TEXT],
		["Inflación", "%.1f %%" % float(e.get("inflation", 0.0)), UI.TEXT],
		["Ingresos públicos", "%.0f bn € · %.1f %% PIB" % [m.eco.revenue_total(), m.eco.revenue_total() / gdp * 100.0], UI.TEXT],
		["Gasto público", "%.0f bn € · %.1f %% PIB" % [m.eco.spending_total(), m.eco.spending_total() / gdp * 100.0], UI.TEXT],
		["Déficit", "%.1f %% del PIB" % -m.eco.balance_pct(), UI.WARN if m.eco.balance_pct() < -3.0 else UI.GOOD],
		["Deuda", "%.0f %% del PIB" % m.eco.debt_pct(), UI.BAD if m.eco.debt_pct() > 100.0 else UI.TEXT],
	]
	for it in items:
		var row := UI.hbox(8)
		var l := UI.label(str(it[0]), UI.FS_SMALL, UI.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label(str(it[1]), UI.FS_SMALL, it[2], true))
		c.add_child(row)
