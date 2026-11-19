extends SceneTree
## Motor económico, taller de leyes, Pleno y ministros. Uso: godot --headless --path . --script res://tests/legislature.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _gov(party_id: String) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	# Camino rápido a la legislatura
	while m.phase == "campaign":
		for ev in m.campaign.pending_today():
			var evd: Dictionary = ev
			if m.campaign.is_interview_type(str(evd["type"])):
				var sess := m.enc.build_session(evd)
				for q in sess["questions"]:
					m.enc.resolve(sess, q as Dictionary, ((q as Dictionary)["answers"] as Array)[0] as Dictionary)
				m.enc.finish(sess, evd)
			else:
				m.campaign.resolve_auto(evd)
		var res := m.campaign.smart_continue()
		if str(res["stop"]) == "election": m.election.begin_night()
	while not m.election.night_finished():
		if m.election.reveal_next().is_empty(): break
	m.election.finish_night()
	m.gov.begin_investiture()
	var attempts := 0
	while m.phase == "investiture" and attempts < 12:
		attempts += 1
		if m.gov.candidate_id() == m.pid():
			for id in m.gov.offers().keys():
				var offer: Dictionary = m.gov.offers()[id]
				for i in range((offer["demands"] as Array).size()): m.gov.set_concession(str(id), i, true)
				m.gov.propose(str(id))
		elif m.gov.offers().has(m.pid()): m.gov.propose_as_partner()
		var vote := m.gov.hold_vote()
		if bool(vote["dissolved"]): break
	if m.phase == "cabinet_design": m.gov.form_government()
	return m

func _initialize() -> void:
	print("== Competencias del Consejo de Ministros")
	var m := _gov("psoe")
	check(m.phase == "legislature", "se llega a la legislatura (%s)" % m.phase)
	var cab := m.gov.cabinet()
	check(cab.size() >= 8, "Consejo con %d carteras" % cab.size())
	var owners := m.exec.area_owners()
	check(owners.size() == Policies.areas().size(), "las %d áreas tienen titular" % Policies.areas().size())
	var ok_owner := true
	for k in owners.keys():
		if int(owners[k]) < 0 or int(owners[k]) >= cab.size():
			ok_owner = false
	check(ok_owner, "todos los titulares existen")
	var line_ok := true
	for b in Policies.budget():
		var o := m.exec.line_owner(str((b as Dictionary)["id"]))
		if o < 0 or o >= cab.size():
			line_ok = false
	check(line_ok, "todas las partidas tienen ministerio")
	print("  rol: ", m.role(), " cartera: ", m.exec.post_text())

	print("== Presidente: decretos")
	m.s["government_party_id"] = m.pid()
	m.exec.on_government_formed()
	check(m.exec.post_kind() == "president", "el jugador es presidente")
	check(m.exec.managed().size() >= 3, "puede gestionar varios ministerios (%d)" % m.exec.managed().size())
	var hidx: int = int(owners["health"])
	var meas := Policies.measure("health_budget")
	var cur := m.eco.value("health_budget")
	var cap0 := m.exec.capital()
	var cost := m.exec.cost_of(meas, cur + float(meas["step"]) * 2.0)
	var cons := m.exec.consent(hidx, "health_budget", cur + float(meas["step"]) * 2.0)
	print("  consenso: ", cons["label"], " coste ", cost, " capital ", cap0)
	var r := m.exec.issue(hidx, "health_budget", cur + float(meas["step"]) * 2.0, true)
	check(bool(r["ok"]), "decreto de sanidad aprobado: %s" % str(r.get("error", "")))
	check(m.eco.value("health_budget") > cur, "el decreto cambia la medida (%.0f → %.0f)" % [cur, m.eco.value("health_budget")])
	check(m.exec.capital() < cap0, "el decreto cuesta capital político (%.1f → %.1f)" % [cap0, m.exec.capital()])
	check((m.exec.st()["decrees"] as Array).size() == 1, "el decreto queda registrado")
	var rt := m.exec.issue(int(owners["tax"]), "vat_general", 23.0, true)
	check(not bool(rt["ok"]), "no se puede decretar una medida fiscal")
	var rb := m.exec.issue(hidx, "health_budget", float(meas["max"]), true)
	check(m.eco.value("health_budget") <= cur + m.exec.max_span(meas) + 0.01, "un decreto no excede su recorrido máximo")
	m.exec.st()["capital"] = 0.0
	var rn := m.exec.issue(hidx, "health_budget", m.eco.value("health_budget") + float(meas["step"]), true)
	check(not bool(rn["ok"]), "sin capital no hay decreto")
	check(m.exec.consent(hidx, "health_budget", cur).has("status"), "consentimiento calculado")

	print("== Ministro: solo su cartera")
	var m3 := _gov("psoe")
	var other := "pp" if m3.pid() != "pp" else "psoe"
	m3.s["government_party_id"] = other
	var mine := -1
	for i in range(m3.gov.cabinet().size()):
		if i == 3:
			(m3.gov.cabinet()[i] as Dictionary)["party"] = m3.pid()
			mine = i
		elif str((m3.gov.cabinet()[i] as Dictionary)["party"]) == m3.pid():
			(m3.gov.cabinet()[i] as Dictionary)["party"] = other
	m3.exec.on_government_formed()
	m3.exec.set_post(mine)
	check(m3.exec.post_kind() == "minister", "el jugador es ministro (%s)" % m3.exec.post_text())
	check(m3.exec.managed() == [mine], "solo gestiona su ministerio")
	check(m3.exec.can_manage(mine) and not m3.exec.can_manage(1), "no puede actuar sobre otros")
	check(not m3.exec.objectives().is_empty() or m3.exec.areas_of(mine).is_empty(), "la directiva fija objetivos")

	var own_lines := m3.exec.lines_of(mine)
	check(not own_lines.is_empty(), "el ministerio tiene partidas propias (%s)" % m3.exec.ministry_name(mine))
	if not own_lines.is_empty():
		var l0 := str(own_lines[0])
		var f0 := m3.exec.factor(l0)
		var sp0 := m3.eco.budget_spending(l0)
		m3.exec.st()["capital"] = 20.0
		var ra := m3.exec.adjust_line(mine, l0, 1.0, true)
		check(bool(ra["ok"]), "modificación de crédito aprobada: %s" % str(ra.get("error", "")))
		check(m3.exec.factor(l0) > f0 and m3.eco.budget_spending(l0) > sp0, "el crédito sube la partida (%.1f → %.1f)" % [sp0, m3.eco.budget_spending(l0)])
		check(not bool(m3.exec.adjust_line(1, l0, 1.0, true)["ok"]), "no puede tocar partidas de otro ministerio")

	print("== Presupuestos")
	var m4 := _gov("psoe")
	m4.s["government_party_id"] = m4.pid()
	m4.exec.on_government_formed()
	var guard := 0
	while m4.gov_month < 3 and guard < 5:
		guard += 1
		m4.gov.advance_turn()
	check(m4.exec.pge_open(), "se abre el plazo de Presupuestos en el mes 3")
	m4.exec.set_draft_factor("sanidad", 1.10)
	m4.exec.set_draft_factor("defensa", 1.05)
	check(m4.exec.draft_delta() > 0.0, "el borrador aumenta el gasto (%.1f bn)" % m4.exec.draft_delta())
	var law := {"id": "x", "title": "PGE", "area": "", "proposer": m4.pid(), "kind": "presupuestos", "changes": {}, "goodwill": {}, "budget": (m4.exec.pge()["draft"] as Dictionary).duplicate()}
	var fc := m4.laws.forecast(law)
	check(int(fc["yes"]) + int(fc["no"]) + int(fc["abstain"]) == 350, "el recuento de apoyos suma 350")
	var spend0 := m4.eco.budget_spending("sanidad")
	m4.exec.submit_pge(false)
	check(m4.laws.queue().size() == 1 and str((m4.laws.queue()[0] as Dictionary)["kind"]) == "presupuestos", "los Presupuestos quedan registrados")
	m4.gov.advance_turn()
	var found := false
	for l in m4.congress.laws():
		if str((l as Dictionary).get("kind", "")) == "presupuestos":
			found = true
	check(found, "el Pleno incluye los Presupuestos")
	m4.congress.auto_finish()
	var res_pge: String = m4.exec.pge_status()
	print("  estado PGE tras la votación: ", res_pge)
	if res_pge == "aprobado":
		check(m4.exec.factor("sanidad") > 1.05, "se aplica la dotación aprobada (%.3f)" % m4.exec.factor("sanidad"))
		check(m4.eco.budget_spending("sanidad") > spend0, "el gasto sanitario sube (%.1f → %.1f)" % [spend0, m4.eco.budget_spending("sanidad")])
	else:
		check(m4.exec.factor("sanidad") == 1.0, "prórroga: factores sin cambios")

	print("== Legislatura completa con ministros IA y directiva")
	var m5 := _gov("psoe")
	m5.s["government_party_id"] = m5.pid()
	m5.exec.on_government_formed()
	var months := 0
	var cap_ok := true
	while m5.phase == "legislature" and months < 20:
		months += 1
		if m5.exec.pge_open() and months % 2 == 1:
			m5.exec.submit_pge(false)
		m5.gov.advance_turn()
		if m5.exec.capital() < 0.0 or m5.exec.capital() > Executive.MAX_CAPITAL + 0.01:
			cap_ok = false
	check(cap_ok, "el capital político se mantiene en rango")
	var ai_decrees := 0
	for d in m5.exec.st()["decrees"]:
		if not bool((d as Dictionary).get("player", false)):
			ai_decrees += 1
	print("  meses jugados: ", months, " decretos IA recientes: ", ai_decrees, " confianza directiva: ", m5.exec.directive(), " PGE: ", (m5.exec.pge()["history"] as Array).size())
	check(months >= 8, "la legislatura avanza (%d meses)" % months)
	var evaluated := false
	for o in m5.exec.objectives():
		if str((o as Dictionary)["status"]) != "pending":
			evaluated = true
	check(evaluated or months < 8 or m5.exec.directive() != 60.0, "la directiva evalúa los objetivos")
	check((m5.exec.pge()["history"] as Array).size() >= 1, "se han votado Presupuestos")
	print("== Fallos: ", failures)
	quit()
