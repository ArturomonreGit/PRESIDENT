extends Screen
## Investidura: aritmética parlamentaria, siguiente paso recomendado y reuniones con cada grupo.

func build() -> void:
	var cand := m.gov.candidate_id()
	var est := m.gov.estimate_votes()
	_stepper(est)
	_hero(cand, est)
	_next_step(cand, est)
	_candidate_picker()
	if m.is_player(cand):
		_candidate_view(cand, est)
	else:
		_partner_view(cand, est)
	_vote_button(est)

# ---------------------------------------------------------------- pasos
func _stepper(est: Dictionary) -> void:
	var row := UI.hbox(8)
	var yes := int(est["yes"])
	var ok := yes >= Rules.MAJORITY if m.gov.round_number() == 1 else yes > int(est["no"])
	var steps := [["1", "Candidato", true], ["2", "Apoyos", true], ["3", "Votación", ok]]
	var i := 0
	for s in steps:
		var done: bool = s[2]
		var chip := UI.chip("%s  %s" % [str(s[0]), str(s[1])], UI.GOOD if (done and i == 2) else (UI.ACCENT if i < 2 else UI.MUTED), i == 1)
		row.add_child(chip)
		if i < steps.size() - 1:
			row.add_child(UI.label("›", UI.FS_LEAD, UI.FAINT))
		i += 1
	row.add_child(UI.fill())
	row.add_child(UI.label("Intento %d de %d · %s votación" % [m.gov.attempts() + 1, Rules.MAX_INVESTITURE_ATTEMPTS, "primera" if m.gov.round_number() == 1 else "segunda"], UI.FS_SMALL, UI.MUTED))
	add_child(row)

func _segments(est: Dictionary) -> Array:
	var segs: Array = []
	var detail: Dictionary = est["detail"]
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		segs.append({"id": pid, "seats": m.seats_of(pid), "color": m.party_color(pid), "state": str(detail.get(pid, "abstain")), "name": m.party_short(pid)})
	return segs

func _hero(cand: String, est: Dictionary) -> void:
	var col := m.party_color(cand)
	var hero := UI.hero(self, Color(col, 0.16), Color(col, 0.55))
	var head := UI.hbox(14)
	head.add_child(UI.party_emblem(m, cand, 56))
	var t := UI.vbox(2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.eyebrow("Candidato a la Presidencia"))
	t.add_child(UI.label(m.party_name(cand), UI.FS_H1, UI.TEXT, true))
	t.add_child(UI.label("%d escaños propios · mayoría absoluta: %d" % [m.seats_of(cand), Rules.MAJORITY], UI.FS_BODY, UI.MUTED))
	head.add_child(t)
	var yes := int(est["yes"])
	var ok := yes >= Rules.MAJORITY if m.gov.round_number() == 1 else yes > int(est["no"])
	var out := m.ivote.outlook(est)
	var margin := yes - (Rules.MAJORITY if m.gov.round_number() == 1 else int(est["no"]) + 1)
	var tight := ok and margin < int(out["safe_margin"])
	head.add_child(UI.chip("Margen ajustado" if tight else ("Saldría adelante" if ok else "No saldría adelante"), UI.WARN if (tight or not ok) else UI.GOOD, true))
	hero.add_child(head)
	var bar := VoteBar.new()
	bar.set_data(_segments(est))
	hero.add_child(bar)
	if m.gov.round_number() == 2:
		hero.add_child(UI.label("Segunda votación: basta con más votos a favor que en contra.", UI.FS_BODY, UI.WARN))
	var risk := UI.label("Disciplina de voto: se esperan unas %.0f disidencias en la Cámara (%.0f entre los votos a favor). Margen sobre el umbral: %s%d." % [float(out["expected_rebels"]), float(out["expected_yes_loss"]), "+" if margin >= 0 else "", margin], UI.FS_SMALL, UI.WARN if (tight or not ok) else UI.MUTED)
	risk.tooltip_text = "Cada diputado puede romper la disciplina de su grupo por tensiones internas, distancia ideológica, presión territorial, crisis de liderazgo o pactos incumplidos."
	hero.add_child(risk)

func _next_step(cand: String, est: Dictionary) -> void:
	var yes := int(est["yes"])
	var no := int(est["no"])
	var first := m.gov.round_number() == 1
	var text := ""
	var col := UI.ACCENT
	if (first and yes >= Rules.MAJORITY) or (not first and yes > no):
		text = "Tienes los votos necesarios. Puedes celebrar la votación cuando quieras."
		col = UI.GOOD
	elif first:
		var need := Rules.MAJORITY - yes
		var picks: Array = []
		var reach := 0
		var detail: Dictionary = est["detail"]
		var pool: Array = []
		for id in m.gov.parliamentary_ids():
			var pid := str(id)
			if pid == cand or m.is_player(pid) or str(detail.get(pid, "")) == "yes":
				continue
			if m.brain.blocked_by(pid, cand) != "":
				continue
			pool.append(pid)
		pool.sort_custom(func(a: String, b: String) -> bool:
			return m.brain.disposition(a, cand) * float(m.seats_of(a)) > m.brain.disposition(b, cand) * float(m.seats_of(b)))
		for pid in pool:
			if reach >= need or picks.size() >= 3:
				break
			picks.append("%s (%d)" % [m.party_short(str(pid)), m.seats_of(str(pid))])
			reach += m.seats_of(str(pid))
		text = "Te faltan %d votos a favor. " % need
		if not picks.is_empty():
			text += "Empieza por: %s." % ", ".join(picks)
			if reach < need:
				text += " Aun así, no llegarías: busca abstenciones y juega a la segunda votación (más síes que noes)."
		else:
			text += "No quedan socios viables: la segunda votación (más síes que noes) es tu opción."
		col = UI.WARN
	else:
		text = "Para ganar en segunda votación necesitas más votos a favor (%d) que en contra (%d). Convierte noes en abstenciones." % [yes, no]
		col = UI.WARN
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color(col, 0.10), Color(col, 0.5), 10, 1, 16, 10))
	var h := UI.hbox(10)
	h.add_child(UI.chip("SIGUIENTE PASO", col, true))
	var l := UI.wrap_label(text, UI.FS_BODY, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	bar.add_child(h)
	add_child(bar)

## Ronda de consultas del Rey: primero el más votado, después el segundo; si ambos fracasan, elecciones.
func _candidate_picker() -> void:
	var ranked := m.gov.parliamentary_ids()
	var log: Array = m.a("investiture_log")
	var c := UI.card(self, "Propuesta del Rey", "Primero la fuerza más votada, después la segunda. Si ambas fracasan, se disuelven las Cortes", UI.ACCENT)
	var row := UI.hbox(10)
	for i in range(Rules.MAX_INVESTITURE_ATTEMPTS):
		if i >= ranked.size():
			break
		var pid := str(ranked[i])
		var state := "pending"
		if i < log.size():
			state = "failed"
		elif i == m.gov.attempts():
			state = "current"
		var col: Color = {"failed": UI.BAD, "current": UI.ACCENT, "pending": UI.FAINT}[state]
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", UI.box(Color(col, 0.10 if state == "current" else 0.04), Color(col, 0.6 if state == "current" else 0.3), 10, 2 if state == "current" else 1, 14, 10))
		var h := UI.hbox(10)
		pc.add_child(h)
		h.add_child(UI.party_emblem(m, pid, 38))
		var t := UI.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UI.label("%d.º intento" % (i + 1), UI.FS_TINY, col, true))
		t.add_child(UI.label(m.party_name(pid), UI.FS_BODY, UI.TEXT, true))
		t.add_child(UI.label("%d escaños%s" % [m.seats_of(pid), " · tú" if m.is_player(pid) else ""], UI.FS_SMALL, UI.MUTED))
		h.add_child(t)
		h.add_child(UI.chip({"failed": "Fracasó", "current": "En curso", "pending": "Si el primero falla"}[state], col, state == "current"))
		row.add_child(pc)
	var end := PanelContainer.new()
	end.add_theme_stylebox_override("panel", UI.box(Color(UI.WARN, 0.06), Color(UI.WARN, 0.35), 10, 1, 14, 10))
	var eh := UI.vbox(0)
	end.add_child(eh)
	eh.add_child(UI.label("Si fracasan los dos", UI.FS_TINY, UI.WARN, true))
	eh.add_child(UI.label("Nuevas elecciones", UI.FS_BODY, UI.TEXT, true))
	row.add_child(end)
	c.add_child(row)

# ---------------------------------------------------------------- el jugador es candidato
func _candidate_view(cand: String, est: Dictionary) -> void:
	var c := UI.card(self, "Grupos parlamentarios", "%d reuniones disponibles en esta ronda" % m.diplomacy.meetings_left(), UI.GOOD)
	var detail: Dictionary = est["detail"]
	var head := UI.hbox(10)
	for pair in [["Grupo", 150], ["Escaños", 60], ["Voto previsto", 110], ["Disposición", 110]]:
		var l := UI.label(str(pair[0]).to_upper(), UI.FS_TINY, UI.FAINT, true)
		l.custom_minimum_size = Vector2(float(pair[1]), 0)
		head.add_child(l)
	c.add_child(head)
	c.add_child(UI.hsep())
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		if m.is_player(pid):
			continue
		c.add_child(_group_row(pid, cand, str(detail.get(pid, "abstain"))))

func _group_row(pid: String, cand: String, vote: String) -> Control:
	var offer: Dictionary = m.gov.offers().get(pid, {})
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := UI.hbox(10)
	var tag := UI.party_tag(m, pid)
	tag.custom_minimum_size = Vector2(150, 0)
	row.add_child(tag)
	var seats := UI.label(str(m.seats_of(pid)), UI.FS_BODY, UI.MUTED)
	seats.custom_minimum_size = Vector2(60, 0)
	row.add_child(seats)
	var vtxt: String = {"yes": "A favor", "no": "En contra", "abstain": "Abstención"}[vote]
	var vcol: Color = {"yes": UI.GOOD, "no": UI.BAD, "abstain": UI.MUTED}[vote]
	var vc := UI.chip(vtxt, vcol, vote == "yes")
	var vwrap := HBoxContainer.new()
	vwrap.custom_minimum_size = Vector2(110, 0)
	vwrap.add_child(vc)
	row.add_child(vwrap)
	var disp := m.brain.disposition(pid, cand)
	var dl := m.brain.disposition_label(disp)
	var dwrap := HBoxContainer.new()
	dwrap.custom_minimum_size = Vector2(110, 0)
	dwrap.add_child(UI.chip(str(dl["text"]), UI.tone_color(str(dl["tone"]))))
	row.add_child(dwrap)
	var note := ""
	if str(offer.get("status", "")) == "accepted":
		var role := "entra en el Gobierno" if str(offer.get("role", "")) == "cabinet" else "apoyo externo"
		note = "Acuerdo: %s" % ("abstención" if str(offer.get("vote", "yes")) == "abstain" else role)
	elif m.brain.blocked_by(pid, cand) != "":
		note = "Veto: " + m.brain.blocked_by(pid, cand)
	var nl := UI.label(note, UI.FS_SMALL, UI.GOOD if note.begins_with("Acuerdo") else UI.BAD)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	row.add_child(nl)
	var chk := m.diplomacy.can_meet(pid)
	var meet_cb := func() -> void: shell.open_meeting(pid, "investiture")
	var b := UI.pill("REUNIRSE", false, meet_cb, false, UI.PILL if bool(chk["ok"]) else Color("#8E9BB0"))
	b.custom_minimum_size = Vector2(110, 28)
	b.disabled = not bool(chk["ok"])
	b.tooltip_text = str(chk["reason"])
	row.add_child(b)
	box.add_child(row)
	return box

# ---------------------------------------------------------------- el jugador no es candidato
func _partner_view(cand: String, est: Dictionary) -> void:
	var offer: Dictionary = m.gov.offers().get(m.pid(), {})
	var cols := columns(1.2, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var c := UI.card(left, "Tu posición ante %s" % m.party_short(cand), "", UI.GOOD)
	var accepted := str(offer.get("status", "")) == "accepted"
	var lev := m.gov.player_leverage()
	var r1 := UI.hbox(8)
	r1.add_child(UI.label("Tu fuerza negociadora", UI.FS_SMALL, UI.MUTED))
	r1.add_child(UI.meter(lev * 100.0, 100.0, UI.GOOD, 8))
	r1.add_child(UI.label("%.0f" % (lev * 100.0), UI.FS_SMALL, UI.TEXT, true))
	c.add_child(r1)
	c.add_child(UI.wrap_label("Cuantos más escaños necesite el candidato, más fuerza tienes en la mesa. Reúnete con él para pactar tu voto a cambio de medidas y carteras.", UI.FS_BODY, UI.MUTED))
	if accepted:
		var role := "entrarás en el Gobierno" if str(offer.get("role", "")) == "cabinet" else "apoyo externo"
		c.add_child(UI.chip("Acuerdo cerrado · %s" % role, UI.GOOD, true))
	var chk := m.diplomacy.can_meet(cand)
	var meet := UI.button("Negociar con %s" % m.party_short(cand), "primary" if bool(chk["ok"]) else "ghost", func() -> void:
		shell.open_meeting(cand, "partner"))
	meet.disabled = not bool(chk["ok"])
	meet.tooltip_text = str(chk["reason"])
	c.add_child(meet)
	if not bool(chk["ok"]):
		c.add_child(UI.label(str(chk["reason"]), UI.FS_SMALL, UI.FAINT))
	var v := UI.card(left, "Sentido de tu voto", "Si no hay acuerdo", UI.WARN)
	var cur := str(m.s.get("player_vote", ""))
	if m.gov.partners().has(m.pid()):
		v.add_child(UI.label("Tu voto está comprometido a favor por el acuerdo.", UI.FS_BODY, UI.GOOD))
	else:
		var row := UI.hbox(6)
		for opt in [["no", "En contra"], ["abstain", "Abstención"]]:
			var key: String = opt[0]
			row.add_child(UI.button(str(opt[1]), "primary" if (cur == key or (cur == "" and key == "abstain")) else "ghost", func() -> void:
				m.gov.set_player_vote(key)
				shell.refresh()))
		v.add_child(row)
		v.add_child(UI.wrap_label("Tu abstención puede facilitar la investidura en segunda votación; votar en contra la dificulta.", UI.FS_SMALL, UI.MUTED))
	var o := UI.card(right, "Apoyos al candidato", "", UI.ACCENT)
	var detail: Dictionary = est["detail"]
	for id in m.gov.parliamentary_ids():
		var vote := str(detail.get(str(id), "abstain"))
		var row2 := UI.hbox(8)
		var tag := UI.party_tag(m, str(id))
		tag.custom_minimum_size = Vector2(110, 0)
		row2.add_child(tag)
		row2.add_child(UI.label("%d" % m.seats_of(str(id)), UI.FS_BODY, UI.MUTED))
		row2.add_child(UI.fill())
		row2.add_child(UI.chip({"yes": "A favor", "no": "En contra", "abstain": "Abstención"}[vote], {"yes": UI.GOOD, "no": UI.BAD, "abstain": UI.MUTED}[vote]))
		o.add_child(row2)

func _vote_button(est: Dictionary) -> void:
	var yes := int(est["yes"])
	var ok := yes >= Rules.MAJORITY if m.gov.round_number() == 1 else yes > int(est["no"])
	var row := UI.hbox(10)
	var last := m.ivote.last_of_cycle()
	if not last.is_empty():
		# Resumen de la última votación del ciclo, con opción de repetirla (misma fila: no añade altura).
		var lt: Dictionary = last["tally"]
		var passed := bool(last.get("passed", false))
		row.add_child(UI.chip("Última votación: " + ("aprobada" if passed else "fallida"), UI.GOOD if passed else UI.BAD, true))
		var lbl := UI.label("%d a favor · %d en contra · %d abstenciones · %d disidentes" % [int(lt["yes"]), int(lt["no"]), int(lt["abstain"]), (last["rebels"] as Array).size()], UI.FS_SMALL, UI.MUTED)
		lbl.clip_text = true
		row.add_child(lbl)
		row.add_child(UI.mini_button("Ver de nuevo", func() -> void: shell.open_investiture_vote(last)))
	row.add_child(UI.fill())
	row.add_child(UI.label("Cuando estés listo:", UI.FS_BODY, UI.MUTED))
	row.add_child(UI.button("Celebrar la votación", "good" if ok else "warn", func() -> void: shell.confirm_vote(), 220))
	add_child(row)
