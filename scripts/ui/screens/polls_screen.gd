extends Screen
## Encuestas, tendencias y proyección de escaños.

static var focus := ""
static var window := 0  ## meses visibles (0 = todo el historial)

func build() -> void:
	var proj := m.election.project_seats()
	var cols := columns(1.5, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var c := UI.card(left, "Evolución", "Pulsa un partido para resaltarlo", UI.ACCENT)
	var chips := UI.hbox(6)
	for r in m.ranked_polls_with_player(8):
		var id := str((r as Dictionary)["id"])
		var b := UI.button(m.party_short(id), "primary" if focus == id else "ghost", func() -> void:
			focus = "" if focus == id else id
			rebuild())
		b.custom_minimum_size = Vector2(0, 28)
		chips.add_child(b)
	chips.add_child(UI.spacer(0, 16))
	for wd in [[6, "6 m"], [12, "1 año"], [0, "Todo"]]:
		var wb := UI.button(str(wd[1]), "primary" if window == int(wd[0]) else "ghost", func() -> void:
			window = int(wd[0])
			rebuild())
		wb.custom_minimum_size = Vector2(0, 28)
		chips.add_child(wb)
	c.add_child(chips)
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(400, 470)
	chart.focus_id = focus
	var ids: Array = []
	for r in m.ranked_polls_with_player(7):
		ids.append(str((r as Dictionary)["id"]))
	if not ids.has(m.pid()):
		ids.append(m.pid())
	var history := m.a("poll_history_multi")
	var all_labels := m.campaign.history_labels()
	var first := 0
	if window > 0 and history.size() > 1:
		var t_now := int((history[history.size() - 1] as Dictionary).get("t", 0))
		first = history.size() - 1
		while first > 0 and int((history[first - 1] as Dictionary).get("t", 0)) >= t_now - window * 30 * 86400:
			first -= 1
	history = history.slice(first)
	all_labels = all_labels.slice(first)
	var series: Array = []
	for id in ids:
		var vals: Array = []
		for snap in history:
			vals.append(float(((snap as Dictionary)["polls"] as Dictionary).get(str(id), 0.0)))
		series.append({"id": str(id), "name": m.party_short(str(id)), "color": m.party_color(str(id)), "values": vals, "width": 3.0 if m.is_player(str(id)) else 2.0})
	chart.series = series
	chart.x_labels = all_labels
	chart.show_now = true
	c.add_child(chart)

	var t := UI.card(right, "Clasificación", "%% · tendencia %s · forma · escaños proyectados" % m.campaign.trend_label(), UI.GOOD)
	var head := UI.hbox(10)
	head.add_child(UI.spacer(0, 110))
	for h in [["Voto", 52], [m.campaign.trend_label(), 44], ["Forma", 60], ["Esc.", 40]]:
		var l := UI.label(str(h[0]), UI.FS_TINY, UI.FAINT, true)
		l.custom_minimum_size = Vector2(float(h[1]), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(l)
	t.add_child(head)
	var listed := 0
	var hidden := 0
	for r in m.ranked_polls():
		var id := str((r as Dictionary)["id"])
		if listed >= 11 and not m.is_player(id):
			hidden += 1
			continue
		listed += 1
		var tr := m.campaign.trend(id)
		var row := party_row(t, id, [
			{"text": "%.1f" % float((r as Dictionary)["share"]), "w": 52, "bold": true},
			{"text": UI.signed(tr, 1), "w": 44, "color": UI.delta_color(tr)},
		])
		var dots := UI.hbox(3)
		dots.custom_minimum_size = Vector2(60, 0)
		dots.alignment = BoxContainer.ALIGNMENT_END
		for v in m.campaign.form(id, 5):
			var sq := ColorRect.new()
			sq.custom_minimum_size = Vector2(8, 8)
			sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sq.color = UI.GOOD if int(v) > 0 else (UI.BAD if int(v) < 0 else UI.FAINT)
			dots.add_child(sq)
		row.add_child(dots)
		var es := UI.label(str(int(proj.get(id, 0))), UI.FS_BODY, UI.TEXT, true)
		es.custom_minimum_size = Vector2(40, 0)
		es.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(es)
	var rest_txt := "Otros: %.1f%%" % m.poll_of(Rules.OTHERS_ID)
	if hidden > 0:
		rest_txt += " · %d formaciones menores sin listar" % hidden
	t.add_child(UI.label(rest_txt, UI.FS_SMALL, UI.FAINT))

	var s := UI.card(right, "Proyección de escaños", "Mayoría absoluta: %d" % Rules.MAJORITY, UI.WARN)
	var ids2: Array = proj.keys()
	ids2.sort_custom(func(x, y) -> bool: return int(proj[x]) > int(proj[y]))
	var shown_seats := 0
	for id in ids2:
		if int(proj[id]) <= 0:
			continue
		if shown_seats >= 10 and not m.is_player(str(id)):
			continue
		shown_seats += 1
		var row2 := UI.hbox(8)
		var tag := UI.party_tag(m, str(id))
		tag.custom_minimum_size = Vector2(110, 0)
		row2.add_child(tag)
		var mb := UI.meter(float(proj[id]), 200.0, m.party_color(str(id)), 8)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mb.marker = float(Rules.MAJORITY)
		row2.add_child(mb)
		var n := UI.label(str(int(proj[id])), UI.FS_BODY, UI.TEXT, true)
		n.custom_minimum_size = Vector2(32, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row2.add_child(n)
		s.add_child(row2)
	s.add_child(UI.wrap_label("Proyección con el sistema D'Hondt y umbral del 3 %. Es una estimación: el resultado real incluye ruido por circunscripción.", UI.FS_SMALL, UI.FAINT))
