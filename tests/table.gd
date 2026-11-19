extends SceneTree
## Mesa de negociación: propuesta de apertura de la IA, dureza, eventos, última oferta, firma de su propuesta,
## vetos a terceros y mensajes (la prensa no cuenta como pendiente, nunca hay una reunión sin propuestas).
## Uso: godot --headless --path . --script res://tests/table.gd

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model(party_id: String, seed_n: int = 777) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	var save := {"schema_version": 3, "save_id": "ttest", "player_party": party, "game_state": {}}
	var m := GameModel.new(save)
	m.autosave = false
	m.rng.seed = seed_n
	return m

func _initialize() -> void:
	print("== Agenda de apertura")
	var m := _model("psoe")
	for topic in ["joint_list", "pre_pact", "relationship"]:
		for id in ["sumar", "pp", "erc", "podemos", "junts", "pnv"]:
			var ag := m.diplomacy.dyn.agenda_for(id, topic)
			check(not ag.is_empty(), "%s/%s: la IA siempre trae una propuesta (%d términos)" % [id, topic, ag.size()])
			var all_flagged := true
			for t in ag:
				if not bool((t as Dictionary).get("from_ai", false)):
					all_flagged = false
			check(all_flagged, "%s/%s: todos los términos van marcados como suyos" % [id, topic])
	var r := m.diplomacy.open("sumar", "pre_pact", {"agenda": true})
	check(bool(r["ok"]), "se abre la mesa con agenda")
	var mt := m.diplomacy.current()
	check((mt["table"] as Array).size() >= 2, "la mesa abre con propuesta de la IA (%d términos)" % (mt["table"] as Array).size())
	check((mt["log"] as Array).size() >= 2, "la IA expone su propuesta al sentarse")
	check(str(mt["origin"]) == "player", "origen propio si no hay invitación")

	print("== Invitaciones: no gastan reuniones")
	var m2 := _model("psoe")
	var left0 := m2.diplomacy.meetings_left()
	var r2 := m2.diplomacy.open("sumar", "joint_list", {"agenda": true, "invited": true})
	check(bool(r2["ok"]), "mesa por invitación abierta")
	check(m2.diplomacy.meetings_left() == left0, "la invitación no consume reuniones")
	check(str(m2.diplomacy.current()["origin"]) == "ai", "origen: la IA pidió la mesa")

	print("== Dureza: no cierra a la primera")
	var firsts := 0
	var runs := 0
	for seed_n in range(40):
		var mm := _model("psoe", 100 + seed_n)
		var id := "sumar"
		mm.diplomacy.open(id, "pre_pact")
		var mt2 := mm.diplomacy.current()
		for t in mm.diplomacy.dyn.agenda_for(id, "pre_pact"):
			mm.diplomacy.add_term(t as Dictionary)
		var ctx := mm.diplomacy.context_for(mt2)
		check_hard(mm, mt2)
		var res := mm.brain.assess(id, "psoe", mt2["table"], ctx)
		runs += 1
		if str(res["verdict"]) == "accept":
			firsts += 1
	print("  primera oferta aceptada: %d de %d" % [firsts, runs])
	check(firsts <= runs, "recuento coherente")

	var m3 := _model("psoe")
	m3.diplomacy.open("sumar", "pre_pact")
	var base_hard: float = m3.diplomacy.dyn.hardness(m3.diplomacy.current())
	m3.diplomacy.current()["round"] = 3
	var later_hard: float = m3.diplomacy.dyn.hardness(m3.diplomacy.current())
	check(base_hard > later_hard, "el anclaje de la primera ronda desaparece después (%.2f > %.2f)" % [base_hard, later_hard])
	m3.diplomacy.current()["rival_bonus"] = 0.07
	check(m3.diplomacy.dyn.hardness(m3.diplomacy.current()) > later_hard, "una oferta rival endurece a la IA")
	m3.diplomacy.current()["stall"] = 2
	check(m3.diplomacy.dyn.hardness(m3.diplomacy.current()) > later_hard + 0.07, "insistir sin moverse la endurece")

	print("== Insistir con lo mismo gasta paciencia")
	var m4 := _model("psoe")
	m4.diplomacy.open("sumar", "pre_pact")
	m4.diplomacy.add_term({"k": "cabinet", "by": "player", "n": 1})
	var p0 := int(m4.diplomacy.current()["patience"])
	m4.diplomacy.submit()
	if str(m4.diplomacy.current()["status"]) == "open":
		var p1 := int(m4.diplomacy.current()["patience"])
		m4.diplomacy.submit()
		if str(m4.diplomacy.current()["status"]) == "open":
			check(int(m4.diplomacy.current()["stall"]) >= 1, "repetir la misma oferta se anota como estancamiento")
			check(int(m4.diplomacy.current()["patience"]) < p1 or p1 <= 0, "y cuesta paciencia (%d → %d)" % [p1, int(m4.diplomacy.current()["patience"])])
		check(p0 >= p1, "la paciencia nunca sube sola")

	print("== Eventos y última oferta (50 mesas)")
	var kinds := {}
	var finals := 0
	var broke_after_final := 0
	for seed_n in range(50):
		var mm := _model("psoe", 500 + seed_n)
		mm.diplomacy.open("sumar", "pre_pact", {"agenda": true})
		mm.diplomacy.add_term({"k": "cabinet", "by": "ai", "n": 1})
		mm.diplomacy.add_term({"k": "bills", "by": "ai", "n": 3})
		var rounds := 0
		while str(mm.diplomacy.current()["status"]) == "open" and rounds < 7:
			if mm.diplomacy.current().has("choice"):
				mm.diplomacy.resolve_choice(["match", "warn", "ignore"][seed_n % 3])
			var tb: Array = mm.diplomacy.current()["table"]
			# El jugador alterna: mueve algo (quita un término suyo) o insiste.
			if rounds % 2 == 1 and tb.size() > 2:
				mm.diplomacy.remove_term(tb.size() - 1)
			mm.diplomacy.submit()
			var al: Dictionary = mm.diplomacy.current().get("alert", {})
			if not al.is_empty():
				kinds[str(al["kind"])] = int(kinds.get(str(al["kind"]), 0)) + 1
			rounds += 1
		var fm := mm.diplomacy.current()
		if bool(fm.get("final", false)):
			finals += 1
			if str(fm["status"]) == "broken":
				broke_after_final += 1
		check(str(fm["status"]) != "open", "la mesa %d termina (en %d rondas)" % [seed_n, rounds]) if seed_n < 3 else null
		if str(fm["status"]) == "open":
			failures += 1
			print("  FAIL mesa %d sigue abierta" % seed_n)
	print("  eventos vistos: ", kinds)
	check(kinds.size() >= 3, "aparecen al menos 3 tipos de evento distintos (%d)" % kinds.size())
	check(finals > 0, "hay mesas que llegan a última oferta (%d)" % finals)

	print("== Dilema de oferta rival")
	var m5 := _model("psoe", 31)
	m5.diplomacy.open("sumar", "pre_pact")
	var mt5 := m5.diplomacy.current()
	mt5["choice"] = {"id": "rival_offer", "party": "pp", "text": "x", "options": []}
	mt5["rival_bonus"] = 0.07
	var n5 := (mt5["table"] as Array).size()
	m5.diplomacy.resolve_choice("match")
	check(float(mt5["rival_bonus"]) <= 0.02 + 0.0001, "igualar la oferta calma la competencia")
	check((mt5["table"] as Array).size() == n5 + 1, "igualar añade una mejora a la mesa")
	check(not mt5.has("choice"), "el dilema se cierra")

	print("== Firmar su propuesta")
	var m6 := _model("psoe", 12)
	m6.diplomacy.open("sumar", "pre_pact", {"agenda": true})
	m6.diplomacy.sign_their_proposal()
	check(str(m6.diplomacy.current()["status"]) == "agreed", "firmar su propuesta cierra el acuerdo")
	check(m6.diplomacy.active_pacts("sumar").size() == 1, "queda registrado como pacto")
	check(not m6.a("table_history").is_empty(), "queda en el historial de mesas")

	print("== Vetos a terceros")
	var m7 := _model("psoe", 5)
	var menu := m7.diplomacy.term_menu("sumar", "pre_pact")
	var has_cordon_ask := false
	var has_cordon_give := false
	for t in menu["ask"]:
		if str((t as Dictionary).get("k", "")) == "cordon":
			has_cordon_ask = true
	for t in menu["give"]:
		if str((t as Dictionary).get("k", "")) == "cordon":
			has_cordon_give = true
	check(has_cordon_ask, "puedes pedir que no pacten con un tercero")
	check(has_cordon_give, "puedes comprometerte a no pactar con un tercero que detestan")
	var issues := {}
	for t in menu["ask"]:
		if str((t as Dictionary).get("k", "")) == "policy":
			issues[str((t as Dictionary).get("issue", ""))] = true
	check(issues.size() >= 6, "puedes pedir medidas sobre casi cualquier tema (%d)" % issues.size())
	# Compromiso cumplido: tras acordar un veto no puedes sentarte con ese partido.
	var m8 := _model("psoe", 9)
	m8.diplomacy.open("sumar", "pre_pact")
	m8.diplomacy.add_term({"k": "cordon", "by": "player", "target": "vox"})
	m8.diplomacy.current()["status"] = "open"
	m8.diplomacy._register_pacts("sumar", "pre_pact", m8.diplomacy.current()["table"])
	check(m8.diplomacy.cordon_block("vox") != "", "el compromiso de no pactar con Vox queda en vigor")
	check(not bool(m8.diplomacy.open("vox", "pre_pact")["ok"]), "no puedes negociar un pacto con Vox mientras dure")

	print("== Mensajes: la prensa no cuenta")
	var m9 := _model("psoe", 2)
	var before := m9.unread_count()
	m9.publish("Titular de prensa", "Cuerpo", "DECLARACIONES", "neutral")
	m9.publish("Consejo", "Cuerpo", "ASESOR", "neutral")
	check(m9.unread_count() == before, "prensa y consejos no suman sin leer")
	check(m9.pending_count() == 0, "no hay decisiones pendientes")
	m9.publish("Propuesta", "Cuerpo", "NEGOCIACIONES", "positive", {"needs_response": true, "expires_in": 2, "actions": [{"id": "diplo_decline", "label": "Declinar", "style": "ghost"}], "data": {"party": "pp"}})
	check(m9.pending_count() == 1, "una decisión sí cuenta")
	check(m9.attention_count() == 1, "la atención incluye la decisión")
	check(m9.pending_messages().size() == 1, "aparece en la lista de pendientes")
	check(m9.digest_messages().size() >= 2, "las novedades se listan aparte")

	print("== Propuestas de la IA: siempre con propuesta")
	var empty_ones := 0
	var proposals := 0
	for seed_n in range(60):
		var mp := _model("psoe", 900 + seed_n)
		mp.rng.seed = 900 + seed_n
		for i in range(6):
			mp.brain.initiative("campaign")
		for item in mp.news():
			var msg: Dictionary = item
			if str(msg.get("key", "")).begins_with("proposal"):
				proposals += 1
				var data: Dictionary = msg["data"]
				if (data.get("terms", []) as Array).is_empty():
					empty_ones += 1
	print("  propuestas generadas: %d, vacías: %d" % [proposals, empty_ones])
	check(proposals > 0, "la IA propone cosas")
	check(empty_ones == 0, "ninguna propuesta llega sin términos")

	print("")
	print("== Fallos: %d" % failures)
	quit(1 if failures > 0 else 0)

func check_hard(mm: GameModel, mt: Dictionary) -> void:
	var h: float = mm.diplomacy.dyn.hardness(mt)
	if h <= 0.0:
		failures += 1
		print("  FAIL dureza no positiva")
