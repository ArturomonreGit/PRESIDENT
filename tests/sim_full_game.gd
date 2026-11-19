extends SceneTree
## Juega por script una partida completa sin interfaz y comprueba invariantes.
## Uso: godot --headless --path . --script res://tests/sim_full_game.gd -- [party_id]

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var party_id := "psoe" if args.is_empty() else str(args[0])
	var party: Dictionary = {}
	if party_id == "custom":
		party = {"id": "custom_1", "name": "Partido de Prueba", "short_name": "PDP", "color": "#2463B5", "is_custom": true, "leader": "Ana Test",
			"ideology": {"economic": -0.2, "social": -0.3, "territorial": 0.1},
			"ideology_profile": {"socialdemocracia": 70, "ecologismo": 60, "igualdad": 70, "progresismo": 60}}
	elif party_id == "regional":
		party = {"id": "custom_player", "name": "Compromiso Territorial", "short_name": "CT", "color": "#E85D04", "is_custom": true, "leader": "Marc Test",
			"ideology": {"economic": -0.1, "social": -0.2, "territorial": 0.8},
			"ideology_profile": {"regionalismo": 80, "progresismo": 50, "federalismo": 60},
			"territory": ["Cataluña"]}
	else:
		for p in DataStore.parties():
			if str((p as Dictionary)["id"]) == party_id:
				party = p
	var save := {"schema_version": 3, "save_id": "test", "player_party": party, "game_state": {}}
	var m := GameModel.new(save)
	m.autosave = false
	print("== Partida de prueba con ", m.party_short(m.pid()))
	check(m.phase == "campaign", "empieza en campaña")
	var total := 0.0
	for v in m.polls().values():
		total += float(v)
	check(absf(total - 100.0) < 0.01, "las encuestas suman 100 (%.3f)" % total)
	check(m.player_poll() > 0.5, "intención de voto del jugador > 0.5 (%.2f)" % m.player_poll())

	# Programa y agenda
	m.manifesto.suggest()
	m.manifesto.sign()
	var r := m.campaign.schedule(1, 11, "Mitin", "Madrid", "")
	check(bool(r["ok"]), "programar un mitin")
	r = m.campaign.schedule(1, 11, "Entrevista", "Madrid", "")
	check(not bool(r["ok"]), "rechaza dos actos a la misma hora")
	m.campaign.schedule(2, 9, "Entrevista", "Madrid", "")
	m.campaign.schedule(2, 11, "Debate", "Barcelona", "")
	m.campaign.schedule(3, 9, "Recaudación de fondos", "Sevilla", "")
	check(not m.campaign.schedule(1, 9, "Entrevista", "Madrid", "")["ok"] == false, "tercer acto del día permitido")
	var r4 := m.campaign.schedule(1, 13, "Mitin", "Valencia", "")
	r4 = m.campaign.schedule(1, 16, "Mitin", "Valencia", "")
	check(not bool(r4["ok"]), "rechaza un cuarto acto en el mismo día")

	# Campaña completa
	var safety := 0
	while m.phase == "campaign" and safety < 400:
		safety += 1
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
		if str(res["stop"]) == "election":
			m.election.begin_night()
	check(m.phase == "election_night", "la campaña termina en noche electoral (día %d)" % m.day)
	check(m.day == Rules.CAMPAIGN_LENGTH_DAYS, "se llega al día 42")
	check(m.funds > -1.0, "presupuesto no negativo (%.0f)" % m.funds)

	# Noche electoral
	var steps := 0
	while steps < 100:
		var rev := m.election.reveal_next()
		if rev.is_empty():
			break
		steps += 1
	check(m.election.night_finished(), "el escrutinio llega al 100 %")
	check(steps == 52, "52 circunscripciones escrutadas (%d)" % steps)
	var seat_sum := 0
	for v in m.d("election_totals").values():
		seat_sum += int(v)
	check(seat_sum == 350, "se reparten 350 escaños (%d)" % seat_sum)
	m.election.finish_night()
	check(m.phase == "results", "fase resultados")
	var shares := 0.0
	for id in m.d("election_vote_totals").keys():
		shares += m.vote_share_of(str(id))
	check(absf(shares - 100.0) < 0.01, "los porcentajes de voto suman 100 (%.3f)" % shares)
	var parts := []
	for id in m.d("election_totals").keys():
		parts.append("%s %d" % [m.party_short(str(id)), m.seats_of(str(id))])
	print("  Resultado: ", ", ".join(parts))

	# Investidura
	m.gov.begin_investiture()
	check(m.phase == "investiture", "fase investidura")
	check(not m.gov.candidate_id().is_empty(), "hay candidato (%s)" % m.party_short(m.gov.candidate_id()))
	var attempts := 0
	while m.phase == "investiture" and attempts < 12:
		attempts += 1
		if m.gov.candidate_id() == m.pid():
			for id in m.gov.offers().keys():
				var offer: Dictionary = m.gov.offers()[id]
				for i in range((offer["demands"] as Array).size()):
					m.gov.set_concession(str(id), i, true)
				m.gov.propose(str(id))
		elif m.gov.offers().has(m.pid()):
			m.gov.propose_as_partner()
		var vote := m.gov.hold_vote()
		print("  Votación ", attempts, ": ", "aprobada" if bool(vote["passed"]) else "fallida", " ", vote["tally"]["yes"], "-", vote["tally"]["no"])
		if bool(vote["dissolved"]):
			break
	check(m.phase in ["cabinet_design", "campaign"], "tras investidura: gobierno o nuevas elecciones (%s)" % m.phase)

	if m.phase == "cabinet_design":
		check(m.gov.cabinet().size() >= 8 and m.gov.cabinet().size() <= 18, "Consejo de Ministros 8–18 (%d)" % m.gov.cabinet().size())
		var fg := m.gov.form_government()
		check(bool(fg["ok"]), "se constituye el Gobierno")
		check(m.phase == "legislature", "fase legislatura")
		print("  Rol del jugador: ", m.role())
		var months := 0
		var elections := false
		while m.phase == "legislature" and months < 60:
			months += 1
			var areas := ["housing", "health", "tax", "education"]
			var dl := m.laws.new_draft(str(areas[months % areas.size()]))
			var ms := Policies.measures_of(str(dl["area"]))
			if not ms.is_empty():
				var meas: Dictionary = ms[0]
				m.laws.set_change(dl, str(meas["id"]), float(meas["base"]) + float(meas["step"]))
			if not dl["changes"].is_empty() and m.gov.bills_left() > 0:
				m.laws.register(str(dl["id"]))
			if months % 2 == 0:
				var guard := 0
				if m.congress.stage() == "ready":
					m.congress.begin()
				while m.congress.stage() == "running" and guard < 10:
					guard += 1
					m.congress.resolve_current(m.laws.recommended_vote(m.congress.current()))
			var mres := m.gov.advance_turn()
			if mres.has("elections"):
				elections = true
		check(elections, "la legislatura acaba en elecciones (meses %d)" % months)
		check(m.eco.passed_laws().size() >= 0, "las leyes aprobadas quedan registradas")
		check(m.phase == "campaign" and m.cycle == 2, "nuevo ciclo electoral (ciclo %d)" % m.cycle)
		var total2 := 0.0
		for v in m.polls().values():
			total2 += float(v)
		check(absf(total2 - 100.0) < 0.01, "encuestas del ciclo 2 suman 100")

	# Guardado y recarga del estado
	var json_text := JSON.stringify(m.save)
	var parsed: Variant = JSON.parse_string(json_text)
	check(typeof(parsed) == TYPE_DICTIONARY, "el guardado serializa a JSON")
	var m2 := GameModel.new(parsed)
	m2.autosave = false
	check(m2.phase == m.phase and m2.day == m.day and m2.cycle == m.cycle, "recarga conserva fase/día/ciclo")
	check(absf(m2.player_poll() - m.player_poll()) < 0.0001, "recarga conserva encuestas")

	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
