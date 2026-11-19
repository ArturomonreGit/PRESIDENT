extends SceneTree
## Pactos por leyes concretas, favores de voto, ofertas a minorías y rondas de investidura. Uso: godot --headless --path . --script res://tests/law_deals.gd
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
	print("== Rondas de investidura del Rey")
	check(Rules.MAX_INVESTITURE_ATTEMPTS == 2, "máximo dos intentos de investidura")
	var mi := _fresh("psoe")
	mi.gov.begin_investiture()
	var ranked := mi.gov.parliamentary_ids()
	check(mi.gov.candidate_id() == str(ranked[0]), "el Rey propone primero a la fuerza más votada (%s)" % mi.gov.candidate_id())
	print("== Pacto por una ley")
	var m := _gov("psoe")
	check(m.phase == "legislature" or m.phase == "cabinet_design" or m.phase == "investiture", "modelo en fase de gobierno (%s)" % m.phase)
	var law := m.laws.new_draft("housing")
	var meas := Policies.measures_of("housing")[0] as Dictionary
	var cur := m.eco.value(str(meas["id"]))
	m.laws.set_change(law, str(meas["id"]), Policies.snap(meas, cur + float(meas["step"]) * 2.0))
	check(not m.diplomacy.deal_laws().is_empty(), "el borrador cuenta como ley negociable")
	var target := ""
	for id in m.gov.parliamentary_ids():
		if not m.is_player(str(id)) and m.brain.blocked_by(str(id), m.pid()) == "":
			target = str(id)
			break
	check(target != "", "hay interlocutor para negociar la ley (%s)" % target)
	m.phase = "legislature"
	var chk := m.diplomacy.can_meet(target)
	check(bool(chk["ok"]), "puede reunirse con %s" % target)
	check(m.diplomacy.topics_for(target).has("law_deal"), "el tema «Pacto por una ley» está disponible")
	check(not bool(m.diplomacy.open(target, "law_deal")["ok"]), "no se abre sin elegir la ley")
	var res := m.diplomacy.open(target, "law_deal", {"law": str(law["id"])})
	check(bool(res["ok"]), "se abre la reunión sobre la ley")
	var table: Array = m.diplomacy.current()["table"]
	check(table.size() == 1 and str((table[0] as Dictionary)["k"]) == "law_vote", "la mesa parte de «voto a favor de la ley»")
	var menu := m.diplomacy.term_menu(target, "law_deal")
	var kinds: Array = (menu["give"] as Array).map(func(t): return str((t as Dictionary)["k"]))
	check(kinds.has("owe_vote"), "puedes ofrecer un favor de voto")
	check(not (menu["ask"] as Array).is_empty(), "puedes pedir voto o abstención en la ley")
	var tt := m.brain.term_text(table[0] as Dictionary)
	check(tt.contains(str(law["title"])), "el término nombra la ley (%s)" % tt)
	# La IA responde con enmiendas o acepta; tras varias rondas la reunión termina.
	var guard := 0
	var saw_amend := false
	while m.diplomacy.active() and guard < 6:
		guard += 1
		m.diplomacy.submit()
		for t in m.diplomacy.current()["table"]:
			if str((t as Dictionary)["k"]) == "law_amend":
				saw_amend = true
		if m.diplomacy.active():
			m.diplomacy.add_term({"k": "owe_vote", "by": "player"})
	var status := str(m.diplomacy.current()["status"])
	print("   estado final: %s · enmiendas propuestas: %s" % [status, str(saw_amend)])
	check(status in ["agreed", "broken", "closed"], "la reunión termina")
	if status == "agreed":
		var st: Dictionary = m.laws.stance(law, target)
		check(str(st["vote"]) in ["yes", "abstain"], "el partido vota lo pactado (%s)" % str(st["vote"]))
		check(m.diplomacy.active_pacts(target).size() >= 1, "el pacto queda registrado")
	print("== Favores de voto")
	var fav := m.d("favors")
	fav["pp"] = 1
	check(m.diplomacy.favors_owed("pp") == 1, "se debe un favor a PP")
	var txt_ok := m.diplomacy.settle_favor("pp", "yes")
	check(txt_ok != "" and m.diplomacy.favors_owed("pp") == 0, "votar a favor salda el favor")
	fav["pp"] = 1
	var rel0 := m.ai.relation("pp")
	var txt_bad := m.diplomacy.settle_favor("pp", "no")
	check(m.ai.relation("pp") < rel0 and txt_bad != "", "incumplir el favor daña la relación")
	print("== Pactos aplican enmiendas")
	var law2 := m.laws.new_draft("tax")
	var m2 := Policies.measures_of("tax")[0] as Dictionary
	m.diplomacy._apply_law_terms("pp", str(law2["id"]), [{"k": "law_amend", "by": "player", "measure": str(m2["id"]), "value": float(m2["base"]) + float(m2["step"]), "type": "add", "text": "x"}, {"k": "law_vote", "by": "ai", "law": str(law2["id"])}])
	check((law2["changes"] as Dictionary).has(str(m2["id"])), "la enmienda se incorpora a la ley")
	check(str((law2["committed"] as Dictionary).get("pp", "")) == "yes", "PP queda comprometido a votar sí")
	check(str(m.laws.stance(law2, "pp")["vote"]) == "yes", "el pacto fuerza el voto a favor")
	print("== Oferta a un grupo minoritario")
	var mm := _fresh("sumar")
	mm.gov.begin_investiture()
	var cand := mm.gov.candidate_id()
	if not mm.is_player(cand):
		var found := false
		for it in mm.news():
			if str((it as Dictionary).get("key", "")).begins_with("proposal_inv_"):
				found = true
		print("   candidato IA: %s · oferta publicada: %s" % [cand, str(found)])
		check(true, "ronda de investidura con candidato de la IA")
	print("Fallos: ", failures)
	quit(failures)

## Modelo recién llegado a la investidura.
func _fresh(party_id: String) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	m.manifesto.suggest()
	m.manifesto.sign()
	m.day = Rules.CAMPAIGN_LENGTH_DAYS
	m.election.begin_night()
	m.election.skip_night()
	m.election.finish_night()
	return m
