extends SceneTree
## Comprueba el cerebro de los partidos, las reuniones, los pactos y la bandeja.
## Uso: godot --headless --path . --script res://tests/diplomacy.gd

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model(party_id: String) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	var save := {"schema_version": 3, "save_id": "dtest", "player_party": party, "game_state": {}}
	var m := GameModel.new(save)
	m.autosave = false
	m.rng.seed = 12345
	return m

func _initialize() -> void:
	var m := _model("psoe")
	print("== Cerebro de partidos")
	var c_ps := m.brain.compat("psoe", "sumar")
	var c_pv := m.brain.compat("psoe", "vox")
	print("  afinidad PSOE-SUMAR %.2f · PSOE-VOX %.2f · PP-VOX %.2f · PP-EHBILDU %.2f" % [c_ps, c_pv, m.brain.compat("pp", "vox"), m.brain.compat("pp", "ehbildu")])
	check(c_ps > c_pv, "PSOE es más afín a Sumar que a Vox")
	check(m.brain.compat("pp", "vox") > m.brain.compat("pp", "ehbildu"), "PP más afín a Vox que a EH Bildu")
	for id in ["pp", "vox", "sumar", "erc", "junts", "ehbildu", "pnv", "bng", "cc", "upn"]:
		var d := m.brain.disposition(id, "psoe")
		check(d >= 0.0 and d <= 100.0, "predisposición de %s hacia el PSOE entre 0 y 100 (%.0f)" % [id, d])
		check(not m.brain.archetype(id).is_empty(), "%s tiene arquetipo" % id)
		check(not (m.ai.profile_of(id).is_empty()), "%s tiene perfil con rasgos" % id)
		check(m.ai.profile_of(id).has("rigidity") and m.ai.profile_of(id).has("ambition"), "%s: rasgos del cerebro presentes" % id)
	var sal := m.brain.salience_map("psoe")
	check(sal.size() == 8, "mapa de prioridades con 8 temas")
	# Valoración de paquetes
	var good: Array = [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 2}, {"k": "policy", "by": "player", "issue": str(m.brain.top_issues("sumar", 2)[0]), "text": "Medida"}, {"k": "policy", "by": "player", "issue": str(m.brain.top_issues("sumar", 2)[1]), "text": "Otra medida"}]
	var greedy: Array = [{"k": "vote_yes", "by": "ai"}, {"k": "joint_list", "by": "ai"}, {"k": "stability", "by": "ai"}, {"k": "bills", "by": "ai", "n": 3}]
	var ctx := {"pivot": 0.5, "player_pivot": 0.4}
	var a_good := m.brain.assess("sumar", "psoe", good, ctx)
	var a_greedy := m.brain.assess("sumar", "psoe", greedy, ctx)
	check(float(a_good["utility"]) > float(a_greedy["utility"]), "un paquete generoso vale más que uno exigente")
	check(str(a_good["verdict"]) == "accept", "Sumar acepta un paquete generoso con el PSOE (%s)" % str(a_good["verdict"]))
	var a_veto := m.brain.assess("vox", "sumar", good, ctx)
	check(str(a_veto["verdict"]) == "veto", "Vox veta a Sumar (%s)" % str(a_veto["verdict"]))
	var cnt := m.brain.counter("sumar", "psoe", greedy, ctx, a_greedy)
	check(cnt.has("text") and not str(cnt["text"]).is_empty(), "la IA genera contraoferta con texto")

	print("== Reunión en campaña")
	var open := m.diplomacy.open("sumar", "joint_list")
	check(bool(open["ok"]), "se abre una reunión con Sumar")
	check(m.diplomacy.active(), "la reunión está activa")
	check(not bool(m.diplomacy.can_meet("sumar")["ok"]), "no se puede repetir la reunión el mismo día")
	check(m.diplomacy.meetings_left() == 2, "quedan 2 reuniones")
	check(not bool(m.diplomacy.open("sumar", "joint_list")["ok"]), "rechaza reabrir con el mismo partido")
	check(not bool(m.diplomacy.open("pp", "investiture")["ok"]), "tema no disponible en campaña")
	var read0 := m.diplomacy.read_the_room()
	check(read0.has("ratio") and float(read0["ratio"]) >= 0.0 and float(read0["ratio"]) <= 1.0, "lectura de la sala válida")
	m.diplomacy.sound()
	check(bool(m.diplomacy.current()["sounded"]), "sondeo realizado")
	check(bool(m.d("known_red_lines").get("sumar", false)), "las líneas rojas pasan a ser conocidas")
	m.diplomacy.add_term({"k": "cabinet", "by": "player", "n": 1})
	var n_terms := (m.diplomacy.current()["table"] as Array).size()
	m.diplomacy.add_term({"k": "cabinet", "by": "player", "n": 2})
	check((m.diplomacy.current()["table"] as Array).size() == n_terms, "los términos de cantidad se sustituyen, no se duplican")
	m.diplomacy.remove_term(n_terms - 1)
	check((m.diplomacy.current()["table"] as Array).size() == n_terms - 1, "se puede quitar un término")
	var guard := 0
	while m.diplomacy.active() and guard < 8:
		guard += 1
		var res := m.diplomacy.submit()
		var v: String = res["verdict"]
		print("   ronda %d → %s" % [guard, v])
	check(not m.diplomacy.active(), "la reunión acaba (agreed/broken) en menos de 8 envíos")
	var status := str(m.diplomacy.current()["status"])
	check(status in ["agreed", "broken", "closed"], "estado final válido (%s)" % status)
	if status == "agreed":
		check(m.diplomacy.active_pacts("sumar").size() == 1, "el acuerdo se registra como pacto")
		var before := m.poll_of("sumar")
		for i in range(10):
			m.diplomacy.joint_list_tick()
		check(m.poll_of("sumar") > before, "la candidatura conjunta mejora las encuestas de Sumar")
	var logn := (m.diplomacy.current()["log"] as Array).size()
	check(logn >= 3, "la conversación tiene %d intervenciones" % logn)

	print("== Investidura con reuniones")
	var m2 := _model("psoe")
	m2.diplomacy.open("sumar", "pre_pact")
	m2.diplomacy.add_term({"k": "cabinet", "by": "player", "n": 1})
	for i in range(4):
		if m2.diplomacy.active():
			m2.diplomacy.submit()
	m2.day = Rules.CAMPAIGN_LENGTH_DAYS
	m2.election.begin_night()
	m2.election.skip_night()
	m2.election.finish_night()
	m2.gov.begin_investiture()
	check(m2.phase == "investiture", "fase de investidura")
	check(m2.gov.set_candidate(m2.pid()), "el jugador puede ser candidato")
	var est0 := m2.gov.estimate_votes()
	print("   votos previstos sin pactos: %d sí · %d no · %d abstención" % [est0["yes"], est0["no"], est0["abstain"]])
	var opened := 0
	for id in m2.gov.parliamentary_ids():
		if m2.is_player(str(id)):
			continue
		var r := m2.diplomacy.open(str(id), "investiture")
		if not bool(r["ok"]):
			continue
		opened += 1
		for k in range(5):
			if not m2.diplomacy.active():
				break
			m2.diplomacy.sound()
			m2.diplomacy.submit()
		if m2.diplomacy.active():
			m2.diplomacy.leave()
	check(opened == 3, "máximo 3 reuniones por ronda (%d)" % opened)
	var est1 := m2.gov.estimate_votes()
	print("   votos previstos tras reunirse: %d sí · %d no · %d abstención" % [est1["yes"], est1["no"], est1["abstain"]])
	check(int(est1["yes"]) >= int(est0["yes"]), "las reuniones no restan apoyos")
	var vote := m2.gov.hold_vote()
	check(vote.has("passed"), "se celebra la votación")

	print("== Bandeja")
	var m3 := _model("vox")
	m3.publish("Consejo", "uno", "ASESOR", "neutral", {"key": "advisor"})
	m3.publish("Consejo", "dos", "ASESOR", "neutral", {"key": "advisor"})
	var advisors := 0
	for it in m3.news():
		if str((it as Dictionary).get("key", "")) == "advisor":
			advisors += 1
	check(advisors == 1, "los mensajes con la misma clave se sustituyen (%d)" % advisors)
	var seq := int(m3.s["news_seq"])
	m3.publish("Invitación", "x", "INVITACIÓN", "neutral", {"needs_response": true, "expires_in": 2, "key": "inv"})
	check(m3.urgent_since(seq), "se detecta un mensaje urgente nuevo")
	check(not m3.urgent_since(int(m3.s["news_seq"])), "no hay urgentes posteriores al último")
	check(m3.pending_count() == 1, "una decisión pendiente")
	m3.day = m3.day + 5
	m3.expire_news()
	check(m3.pending_count() == 0, "la invitación caduca")
	# CONTINUAR no debe detenerse cada día por un mensaje viejo sin responder
	var m4 := _model("vox")
	m4.publish("Invitación vieja", "x", "INVITACIÓN", "neutral", {"needs_response": true})
	var res4 := m4.campaign.smart_continue(5)
	check(int(res4["days"]) >= 2, "smart_continue avanza más de un día con un mensaje viejo pendiente (%d)" % int(res4["days"]))

	print("== Iniciativa de los partidos")
	var m5 := _model("psoe")
	m5.rng.seed = 99
	var proposals := 0
	for i in range(300):
		m5.brain.initiative("campaign")
		for it in m5.news():
			var d: Dictionary = it
			if str(d.get("key", "")).begins_with("proposal") and bool(d.get("needs_response", false)) and not bool(d.get("resolved", false)):
				proposals += 1
				var acts: Array = d["actions"]
				check(acts.size() >= 2, "la propuesta de %s trae acciones" % str(d["speaker_id"]))
				if (d["data"] as Dictionary).get("topic", "") == "joint_list":
					var fb := m5.do_news_action(int(d["id"]), "diplo_accept")
					check(fb.begins_with("Pacto cerrado"), "aceptar una propuesta cierra el pacto")
					check(m5.diplomacy.active_pacts(str(d["speaker_id"])).size() == 1, "el pacto queda registrado")
				else:
					var fb2 := m5.do_news_action(int(d["id"]), "diplo_meet")
					check(fb2.begins_with("Te sientas a negociar"), "aceptar reunión: " + fb2)
					check(not (m5.s.get("open_meeting_request", {}) as Dictionary).is_empty(), "se pide abrir la reunión")
					m5.s.erase("open_meeting_request")
				break
		if proposals >= 3:
			break
	check(proposals >= 1, "los partidos toman la iniciativa (%d propuestas)" % proposals)

	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
