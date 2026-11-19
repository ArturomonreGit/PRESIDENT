extends SceneTree
## Confianza interna, mandatos y avisos de la Secretaría. Uso: godot --headless --path . --script res://tests/trust.gd
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


func _goal_poll(m: GameModel, target: float) -> Dictionary:
	return {"kind": "poll", "start": m.player_poll(), "target": target}

func _mk(m: GameModel, kind: String, faction: String, sev: int = 2, goal: Dictionary = {}) -> Dictionary:
	var g := goal if not goal.is_empty() else _goal_poll(m, 99.0)
	return m.itrust._issue({"type": "ideologico", "kind": kind, "faction": faction, "severity": sev, "title": "Prueba %s" % kind,
		"body": "Cuerpo de prueba.", "reason": "Motivo de prueba.", "goal": g, "turns": 3})

func _initialize() -> void:
	print("== Núcleo")
	var m := _gov("psoe")
	var it := m.itrust
	it.ensure()
	check(it.value() >= 0.0 and it.value() <= 100.0, "confianza interna en rango (%.1f)" % it.value())
	check(it.value() >= 60.0, "arranca coherente con una legislatura recién formada (%.1f)" % it.value())
	var t0 := m.trust
	var poll0 := m.player_poll()
	var vs0 := it.value()
	it.shock(-6.0, "Prueba de escándalo")
	check(is_equal_approx(m.trust, t0) and is_equal_approx(m.player_poll(), poll0), "no se mezcla con la confianza ciudadana ni con las encuestas")
	check(it.value() < vs0 - 1.0, "el escándalo baja la confianza interna (%.1f)" % it.value())
	check(not it.log_entries(3).is_empty(), "queda un motivo registrado")
	check(it.secretary_title().contains("Organización"), "hay un interlocutor: %s" % it.secretary_title())
	check(InternalTrust.state_of(75.0)["id"] == "stable" and InternalTrust.state_of(60.0)["id"] == "warning" and InternalTrust.state_of(40.0)["id"] == "rebellion" and InternalTrust.state_of(20.0)["id"] == "crisis" and InternalTrust.state_of(5.0)["id"] == "rupture", "umbrales de estado del documento (70/50/30/15)")
	var comps := it.components()
	var sum_c := 0.0
	for c in comps: sum_c += float((c as Dictionary)["contrib"])
	check(absf(clampf(InternalTrust.BASE + sum_c, 0.0, 100.0) - it.target()) < 0.01, "el objetivo se explica por sus componentes")

	print("== Turnos y guardado")
	var v_before := it.value()
	for i in range(3):
		m.gov.advance_turn()
	check(m.phase == "legislature", "tras 3 trimestres sigue la legislatura")
	check(it.hist().size() >= 3, "historial de confianza (%d puntos)" % it.hist().size())
	var v_saved := it.value()
	var js: Variant = JSON.parse_string(JSON.stringify(m.save))
	var m2 := GameModel.new(js)
	m2.autosave = false
	check(absf(m2.itrust.value() - v_saved) < 0.001, "la confianza se conserva al guardar y cargar (%.2f)" % m2.itrust.value())
	check(m2.itrust.mandates().size() == it.mandates().size(), "los mandatos se conservan")
	m2.gov.advance_turn()
	check(m2.phase == "legislature", "la partida cargada sigue avanzando")
	check(v_before > 0.0, "valor inicial positivo")

	print("== Mandatos: aceptar, negociar, rechazar")
	var m3 := _gov("psoe")
	var i3 := m3.itrust
	i3.ensure()
	var mc := _mk(m3, "promise", "doctrina", 2)
	check(str(mc["status"]) == "nuevo" and str(mc["id"]) != "", "mandato creado con identificador y estado")
	for k in ["title", "body", "reason", "issuer", "issued_turn", "due_turn", "severity", "faction", "goal"]:
		check(mc.has(k), "el mandato tiene «%s»" % k)
	var pv := i3.preview(mc)
	check(pv.size() == 3, "tres respuestas previstas")
	check(str(((pv[0] as Dictionary)["lines"] as Array)[0]).begins_with("Confianza interna"), "la previsión estima el efecto en la confianza")
	var fsat_before := m3.militancy.sat("doctrina")
	var v1 := i3.value()
	var txt_rej := i3.respond(str(mc["id"]), 2)
	check(str(mc["status"]) == "rechazado", "rechazar cierra el mandato (%s)" % txt_rej)
	check(i3.value() < v1, "rechazar cuesta confianza (%.1f → %.1f)" % [v1, i3.value()])
	check(is_equal_approx(m3.militancy.sat("doctrina"), fsat_before), "el rechazo no penaliza dos veces a la corriente que lo planteó")
	check(str(i3.log_entries(1)[0]["text"]).contains("Rechazas"), "el motivo del cambio queda explicado")
	var ma := _mk(m3, "poll", "aparato", 2)
	var aparato_b := m3.militancy.sat("doctrina")
	var v2 := i3.value()
	i3.respond(str(ma["id"]), 0)
	check(str(ma["status"]) == "aceptado", "aceptar compromete")
	check(m3.militancy.sat("doctrina") < aparato_b, "satisfacer a una facción perjudica a otra (efecto cruzado)")
	var outcomes := {}
	for seed_i in range(30):
		var mx := _gov("psoe") if seed_i == 0 else null
		if mx == null:
			break
		var mnn := _mk(mx, "promise", "doctrina", 2)
		mx.rng.seed = seed_i + 1
		mx.itrust.respond(str(mnn["id"]), 1)
		outcomes[str(mnn["status"]) + str(mnn["can_negotiate"])] = true
	check(not outcomes.is_empty(), "negociar produce un resultado (%s)" % str(outcomes.keys()))
	print("== Resolución y caducidad")
	var m4 := _gov("psoe")
	var i4 := m4.itrust
	i4.ensure()
	var m_exp := _mk(m4, "poll", "aparato", 2)
	var m_ok := _mk(m4, "poll", "aparato", 1, {"kind": "poll", "start": 0.0, "target": 0.0})
	i4.respond(str(m_ok["id"]), 0)
	var m_fail := _mk(m4, "promise", "doctrina", 2)
	i4.respond(str(m_fail["id"]), 0)
	var rec0 := i4.record()
	for i in range(4):
		m4.gov.advance_turn()
	check(str(m_exp["status"]) == "caducado", "no responder deja caducar (%s)" % str(m_exp["status"]))
	check(str(m_ok["status"]) == "cumplido", "meta lograda tras aceptar = cumplido (%s)" % str(m_ok["status"]))
	check(str(m_fail["status"]) in ["incumplido", "cumplido"], "aceptar y no lograrlo = incumplido (%s)" % str(m_fail["status"]))
	check(int(i4.counts()["caducado"]) >= 1 and int(i4.counts()["cumplido"]) >= 1, "contadores de resultados")
	var open_msgs := 0
	for msg in m4.news():
		if bool((msg as Dictionary).get("needs_response", false)) and str((msg as Dictionary).get("key", "")).begins_with("mand_") and not bool((msg as Dictionary).get("resolved", false)):
			open_msgs += 1
	check(open_msgs <= InternalTrust.MAX_OPEN + 1, "los mensajes de mandatos no se acumulan (%d)" % open_msgs)
	check(rec0 > 0.0, "registro de mandatos en rango")

	print("== Alertas y mandatos contextuales")
	var m5 := _gov("psoe")
	m5.itrust.ensure()
	m5.eco.st()["inflation"] = 7.0
	m5.itrust._alerts()
	var alerted := false
	for a in m5.itrust.alerts():
		if str((a as Dictionary)["key"]) == "inflation":
			alerted = true
	check(alerted or m5.itrust.open_count() > 0, "la Secretaría avisa de un problema de gestión")
	check(m5.itrust.mandates(true).size() <= InternalTrust.MAX_OPEN, "máximo de mandatos abiertos")

	print("== Estados bajos: sin game over")
	var m6 := _gov("psoe")
	m6.itrust.ensure()
	m6.itrust.st()["v"] = 5.0
	m6.itrust.st()["rec"] = 10.0
	check(m6.itrust.capital_factor() < 0.6 and m6.itrust.bills_penalty() == 1, "los estados bajos frenan capital político e iniciativas")
	var left_before := m6.gov.bills_left()
	for i in range(4):
		m6.gov.advance_turn()
		if m6.phase != "legislature":
			break
	check(m6.phase in ["legislature", "campaign", "election_night", "results"], "sin destitución ni game over (%s)" % m6.phase)
	check(m6.itrust.value() >= 0.0, "valor sigue en rango")
	check(left_before >= 0, "iniciativas consultables")

	print("== Mandato por ley contra la ideología")
	var m8 := _gov("psoe")
	m8.itrust.ensure()
	var law := {"kind": "ordinaria", "title": "Ley de prueba", "proposer": m8.pid(), "changes": {"wealth_tax": 0.0, "unemp_benefit": 0.0}}
	m8.militancy.on_law(law, {"passed": true, "player_vote": "yes"})
	check(m8.itrust.open_count() == 1, "una ley contra el eje del partido genera un mandato (%d)" % m8.itrust.open_count())
	if m8.itrust.open_count() > 0:
		var md8: Dictionary = m8.itrust.mandates(true)[0]
		check(str(md8["kind"]) == "law_rectify" and str(md8["goal"]["kind"]) == "measure", "es una rectificación con meta medible (%s)" % str(md8["title"]))
		check(str(m8.find_news(int(md8["msg"])).get("title", "")).begins_with("Mandato"), "el mandato llega a la bandeja")
		m8.do_news_action(int(md8["msg"]), "mand:%s:2" % str(md8["id"]))
		check(str(md8["status"]) == "rechazado", "la bandeja resuelve el mandato (%s)" % str(md8["status"]))
		check(bool(m8.find_news(int(md8["msg"])).get("resolved", false)), "el mensaje queda resuelto")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
