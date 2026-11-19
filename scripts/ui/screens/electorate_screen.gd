extends Screen
## Electorado: participación, grupos de votantes, tendencias globales y trasvase de votos.

func build() -> void:
	var v := m.voters
	var pid := m.pid()
	var turnout := v.turnout() * 100.0
	var last_t := float(m.s.get("election_turnout", 0.0)) * 100.0
	var tr := m.campaign.trend(pid)
	var op := v.opinion_of(pid)
	var kpis := [
		{"title": "Participación prevista", "value": "%.1f%%" % turnout,
			"sub": ("%s vs. últimas elecciones" % UI.signed(turnout - last_t, 1)) if last_t > 0.0 else "si hubiera elecciones hoy",
			"sub_color": UI.delta_color(turnout - last_t) if last_t > 0.0 else UI.MUTED},
		{"title": "Abstención", "value": "%.1f%%" % (100.0 - turnout), "sub": "no acude a votar", "color": UI.WARN if turnout < 62.0 else UI.TEXT},
		{"title": "Tu intención de voto", "value": "%.1f%%" % m.player_poll(), "sub": "%s en %s" % [UI.signed(tr, 1), m.campaign.trend_label()], "sub_color": UI.delta_color(tr)},
		{"title": "Imagen de tu partido", "value": ("%+.2f" % op), "sub": "de −1 (rechazo) a +1 (simpatía)", "color": UI.delta_color(op, 0.02)},
	]
	kpi_row(kpis)
	var cl := columns(1.0, 1.0)
	var left: VBoxContainer = cl[0]
	var right: VBoxContainer = cl[1]

	# Tendencias globales
	var c1 := UI.card(left, "Tendencias de fondo", "Corrientes de opinión que mueven a distintos votantes", UI.WARN)
	var shown := 0
	for t in v.trend_summary():
		var td: Dictionary = t
		var lv := float(td["level"])
		if shown >= 6:
			break
		shown += 1
		var row := UI.hbox(10)
		var nm := UI.label(str(td["name"]), UI.FS_BODY, UI.TEXT if absf(lv) > 0.15 else UI.MUTED, absf(lv) > 0.3)
		nm.custom_minimum_size = Vector2(190, 0)
		row.add_child(nm)
		var mb := UI.meter(absf(lv) * 100.0, 100.0, UI.ACCENT, 8)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mb)
		var st := UI.label("al alza" if lv > 0.15 else ("a la baja" if lv < -0.15 else "estable"), UI.FS_SMALL, UI.MUTED)
		st.custom_minimum_size = Vector2(70, 0)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(st)
		c1.add_child(row)

	# Trasvase
	var c2 := UI.card(left, "Trasvase de votos", "Movimiento neto desde las últimas elecciones (puntos del censo)", UI.ACCENT)
	var fl := v.flows(6)
	if fl.is_empty():
		empty_note(c2, "Todavía no hay movimientos apreciables respecto a las últimas elecciones.")
	for f in fl:
		var fd: Dictionary = f
		var from_id := str(fd["from"])
		var to_id := str(fd["to"])
		var row2 := UI.hbox(8)
		row2.custom_minimum_size = Vector2(0, 24)
		row2.add_child(_side(from_id))
		var arrow := UI.label("→", UI.FS_BODY, UI.MUTED, true)
		row2.add_child(arrow)
		row2.add_child(_side(to_id))
		row2.add_child(UI.fill())
		var pts := float(fd["pts"])
		var mine_gain := to_id == pid
		var mine_loss := from_id == pid
		var col := UI.GOOD if mine_gain else (UI.BAD if mine_loss else UI.TEXT)
		var pl := UI.label("%.1f pts" % pts, UI.FS_BODY, col, true)
		pl.custom_minimum_size = Vector2(70, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row2.add_child(pl)
		c2.add_child(row2)
	c2.add_child(UI.wrap_label("Para recuperar a quien se fue: mira qué grupos están enfadados contigo y qué temas les importan.", UI.FS_SMALL, UI.FAINT))

	# Registro
	var c3 := UI.card(left, "Lo que se comenta", "Cambios recientes en la opinión", UI.FAINT)
	var lg := v.log_entries()
	if lg.is_empty():
		empty_note(c3, "Sin novedades.")
	for e in lg.slice(0, 5):
		var ed: Dictionary = e
		c3.add_child(UI.wrap_label("· " + str(ed.get("text", "")), UI.FS_SMALL, UI.MUTED))

	# Grupos de votantes
	var rows := v.cohort_overview()
	var c4 := UI.card(right, "Grupos de votantes", "Peso · participación · a quién votan · ánimo", UI.GOOD)
	var head := UI.hbox(8)
	head.add_child(UI.spacer(0, 210))
	for h in [["Peso", 44], ["Part.", 44], ["Voto principal", 150], ["Ánimo", 56]]:
		var l := UI.label(str(h[0]), UI.FS_TINY, UI.FAINT, true)
		l.custom_minimum_size = Vector2(float(h[1]), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if str(h[0]) != "Voto principal" else HORIZONTAL_ALIGNMENT_LEFT
		head.add_child(l)
	c4.add_child(head)
	for r in rows:
		var rd: Dictionary = r
		var row3 := UI.hbox(8)
		row3.custom_minimum_size = Vector2(0, 24)
		var nl := UI.label(str(rd["name"]), UI.FS_SMALL, UI.TEXT)
		nl.custom_minimum_size = Vector2(210, 0)
		nl.clip_text = true
		nl.tooltip_text = str(rd["desc"])
		row3.add_child(nl)
		row3.add_child(_num("%.0f%%" % float(rd["w"]), 44))
		row3.add_child(_num("%.0f%%" % float(rd["turnout"]), 44))
		var best := ""
		var bv := 0.0
		for id in (rd["votes"] as Dictionary).keys():
			if float((rd["votes"] as Dictionary)[id]) > bv:
				bv = float((rd["votes"] as Dictionary)[id])
				best = str(id)
		var bl := UI.label("%s %.0f%%" % [("Otros" if best == Rules.OTHERS_ID else m.party_short(best)), bv], UI.FS_SMALL, m.party_color(best) if best != Rules.OTHERS_ID else UI.MUTED, true)
		bl.custom_minimum_size = Vector2(150, 0)
		row3.add_child(bl)
		var mood := float(rd["mood"])
		var ml := UI.label(("%+.2f" % mood) if not m.voters.incumbents().is_empty() else "—", UI.FS_SMALL, UI.delta_color(mood, 0.05), true)
		ml.custom_minimum_size = Vector2(56, 0)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row3.add_child(ml)
		c4.add_child(row3)

	# Tu electorado
	var c5 := UI.card(right, "Tu electorado", "Quién te apoya y quién está enfadado contigo", UI.ACCENT)
	var mine: Array = rows.duplicate()
	mine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float((a["votes"] as Dictionary).get(pid, 0.0)) * float(a["w"]) > float((b["votes"] as Dictionary).get(pid, 0.0)) * float(b["w"]))
	var cc := cols([1.0, 1.0], c5)
	cc[0].add_child(UI.label("MÁS FIELES", UI.FS_TINY, UI.MUTED, true))
	for r in mine.slice(0, 3):
		var rd2: Dictionary = r
		cc[0].add_child(UI.label("%s · %.0f%%" % [str(rd2["name"]), float((rd2["votes"] as Dictionary).get(pid, 0.0))], UI.FS_SMALL, UI.TEXT))
	var angry: Array = rows.duplicate()
	angry.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float((a["anger"] as Dictionary).get(pid, 0.0)) > float((b["anger"] as Dictionary).get(pid, 0.0)))
	cc[1].add_child(UI.label("MÁS ENFADADOS CONTIGO", UI.FS_TINY, UI.MUTED, true))
	var any_angry := false
	for r in angry.slice(0, 3):
		var rd3: Dictionary = r
		var a := float((rd3["anger"] as Dictionary).get(pid, 0.0))
		if a < 0.05:
			continue
		any_angry = true
		cc[1].add_child(UI.label("%s · %.0f%%" % [str(rd3["name"]), clampf(a * 100.0, 0.0, 100.0)], UI.FS_SMALL, UI.BAD))
	if not any_angry:
		cc[1].add_child(UI.label("Nadie en particular", UI.FS_SMALL, UI.FAINT))

func _side(id: String) -> Control:
	if id == Electorate.ABST:
		return UI.label("Abstención", UI.FS_BODY, UI.MUTED, true)
	if id == Rules.OTHERS_ID:
		return UI.label("Otros", UI.FS_BODY, UI.MUTED, true)
	var t := UI.party_tag(m, id, UI.FS_BODY, m.is_player(id))
	return t

func _num(text: String, w: float) -> Label:
	var l := UI.label(text, UI.FS_SMALL, UI.MUTED)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
