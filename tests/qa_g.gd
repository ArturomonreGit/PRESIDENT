extends SceneTree
## Entrega G: cláusula de independientes, vicepresidencia en «Condiciones por mi voto», guardado/carga y partidas antiguas.
## Uso: godot --headless --path . --script res://tests/qa_g.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _game(party_id: String, seed_value: int) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	if seed_value != 0:
		m.rng.seed = seed_value
	m.autosave = false
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
	return m

func _finish_investiture(m: GameModel) -> void:
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

func _fresh(party_id: String) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var g := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	g.autosave = false
	g.manifesto.suggest()
	g.manifesto.sign()
	g.day = Rules.CAMPAIGN_LENGTH_DAYS
	g.election.begin_night()
	g.election.skip_night()
	g.election.finish_night()
	g.gov.begin_investiture()
	return g

func _rival(g: GameModel, min_seats: int = 5) -> String:
	for p in g.all_parties():
		var id := str((p as Dictionary)["id"])
		if g.is_player(id) or g.seats_of(id) < min_seats: continue
		return id
	return ""

## El jugador preside y gobierna en coalición con un socio.
func _player_president_with_partner(form: bool = true, extra: Array = []) -> GameModel:
	var g := _fresh("psoe")
	g.gov.set_candidate(g.pid())
	var id := _rival(g)
	g.diplomacy._sync_investiture(id, [{"k": "participation", "mode": "coalition", "by": "ai"}, {"k": "vote_yes", "by": "ai"}] + extra, false)
	g.s["government_party_id"] = g.pid()
	g.s["government_candidate_id"] = g.pid()
	g.phase = "cabinet_design"
	g.gov._start_cabinet_design()
	if form:
		g.gov.form_government()
	return g

## Una IA preside y el jugador entra en el Gobierno como socio (pide además una vicepresidencia).
func _ai_president_with_player() -> GameModel:
	var g := _fresh("psoe")
	var cand := _rival(g, 20)
	g.gov.set_candidate(cand)
	g.diplomacy._sync_investiture(g.pid(), [{"k": "participation", "mode": "coalition", "by": "ai"}, {"k": "vote_yes", "by": "player"}, {"k": "structure", "what": "vicepresidency", "by": "ai"}], true)
	g.s["government_party_id"] = cand
	g.s["government_candidate_id"] = cand
	g.phase = "cabinet_design"
	g.gov._start_cabinet_design()
	g.gov.form_government()
	return g

func _reload(m: GameModel) -> GameModel:
	m.save_now()
	var copy: Variant = JSON.parse_string(JSON.stringify(m.save))
	return GameModel.new(copy as Dictionary)

func _ids_unique(m: GameModel) -> bool:
	var seen := {}
	for c in m.agr.list():
		var id := int((c as Dictionary).get("id", -1))
		if seen.has(id): return false
		seen[id] = true
	return true

func _initialize() -> void:
	print("== G1: cláusula de independientes en carteras del socio")
	var m := _player_president_with_partner()
	check(m.phase == "legislature" and m.coal.gov_id() == m.pid() and m.gov.government_parties().size() >= 2, "partida con jugador presidente y socio de Gobierno")
	if m.phase != "legislature":
		print("== Fallos: ", failures)
		quit(1)
		return
	var partner := ""
	for id in m.gov.government_parties():
		if str(id) != m.pid(): partner = str(id)
	var idx := -1
	for i in range(m.cab.size()):
		if str(m.cab.entry(i).get("party", "")) == partner and idx < 0: idx = i
	check(idx >= 0, "el socio %s lleva alguna cartera" % partner)
	check(not m.cands.independents_allowed(idx), "sin cláusula: no se permiten independientes en la cartera del socio")
	var has_indep := false
	for c in m.cands.shortlist(idx):
		if bool((c as Dictionary).get("independent", false)): has_indep = true
	check(not has_indep, "sin cláusula: ningún candidato independiente en la lista del socio")
	# Menú de la mesa: el jugador presidente puede pedir la cláusula; en «Condiciones por mi voto» puede pedir vicepresidencia
	var give: Array = []
	var ask: Array = []
	m.diplomacy._category_menu(partner, "stability", give, ask)
	var offered := false
	for t in ask:
		if str((t as Dictionary).get("k", "")) == "structure" and str((t as Dictionary).get("what", "")) == "independents": offered = true
	check(offered, "el menú de estabilidad ofrece pedir independientes (el jugador preside)")
	var give2: Array = []
	var ask2: Array = []
	m.diplomacy._category_menu(partner, "partner", give2, ask2)
	var vice_ask := false
	for t in ask2:
		if str((t as Dictionary).get("k", "")) == "structure" and str((t as Dictionary).get("what", "")) == "vicepresidency" and str((t as Dictionary).get("by", "")) == "ai": vice_ask = true
	check(vice_ask, "«Condiciones por mi voto» permite pedir una vicepresidencia")
	# El cerebro valora ceder una vicepresidencia como un coste, y recibir una como beneficio
	var v_ai: Dictionary = m.brain.term_value(partner, m.pid(), {"k": "structure", "what": "vicepresidency", "by": "ai"}, {})
	var v_pl: Dictionary = m.brain.term_value(partner, m.pid(), {"k": "structure", "what": "vicepresidency", "by": "player"}, {})
	check(float(v_ai["v"]) < 0.0 and float(v_pl["v"]) > 0.0, "ceder vicepresidencia cuesta; recibirla suma")
	var v_ind: Dictionary = m.brain.term_value(partner, m.pid(), {"k": "structure", "what": "independents", "by": "ai"}, {})
	check(float(v_ind["v"]) < 0.0, "admitir independientes tiene un coste para el socio")
	# Se firma el pacto
	var before := m.agr.list().size()
	m.agr.register_pact(partner, "stability", [{"k": "structure", "what": "independents", "by": "ai"}], 990001)
	check(m.agr.list().size() == before + 1, "la cláusula crea un compromiso visible")
	check(m.agr.independents_permitted(partner), "el pacto concede el permiso")
	check(m.cands.independents_allowed(idx), "ahora se permiten independientes en esa cartera")
	var indep_id := -1
	var normal_id := -1
	for c in m.cands.shortlist(idx):
		var cd: Dictionary = c
		if bool(cd.get("independent", false)): indep_id = int(cd["pool_id"])
		elif int(cd.get("pool_id", -1)) != int(m.cab.minister(idx).get("pool_id", -2)): normal_id = int(cd["pool_id"])
	check(indep_id >= 0, "la lista del socio incluye un candidato independiente")
	# En legislatura la cuota del socio es suya: el presidente no sustituye a sus ministros ni siquiera con la cláusula.
	m.exec.add_capital(30.0)
	var r_res := m.cab.replace_with(idx, indep_id)
	check(not bool(r_res.get("ok", false)), "en legislatura la cartera del socio sigue reservada")
	var m2 := _reload(m)
	check(m2.agr.independents_permitted(partner) and m2.agr.list().size() == m.agr.list().size(), "la cláusula sobrevive al guardado/carga sin duplicarse")
	# Diseño del gabinete: con la cláusula el presidente propone un independiente en la cartera del socio
	var d := _player_president_with_partner(false, [{"k": "structure", "what": "independents", "by": "ai"}])
	check(d.phase == "cabinet_design", "escenario de diseño del gabinete")
	var dp := ""
	for id in d.gov.government_parties():
		if str(id) != d.pid(): dp = str(id)
	var di := -1
	for i in range(d.cab.size()):
		if str(d.cab.entry(i).get("party", "")) == dp and di < 0: di = i
	check(di >= 0, "el socio tiene cartera en el diseño")
	var ind2 := -1
	for c in d.cands.shortlist(di):
		if bool((c as Dictionary).get("independent", false)): ind2 = int((c as Dictionary)["pool_id"])
	check(ind2 >= 0, "con la cláusula, la lista del socio incluye un independiente")
	check(d.cands.appoint(di, ind2), "el presidente puede proponer al independiente")
	d.gov.form_government()
	check(bool(d.cab.minister(di).get("independent", false)), "el independiente es titular tras formar Gobierno")
	var d2 := _reload(d)
	check(bool(d2.cab.minister(di).get("independent", false)), "el independiente nombrado sobrevive al guardado/carga")
	check(d2.agr.independents_permitted(dp) and d2.agr.list().size() == d.agr.list().size(), "el permiso no se duplica al recargar")
	# Si el pacto se cancela, el permiso desaparece
	for c in m.agr.list():
		var cd2: Dictionary = c
		if str((cd2.get("ref", {}) as Dictionary).get("what", "")) == "independents":
			m.agr.set_state(cd2, "cancelled", "prueba")
	check(not m.agr.independents_permitted(partner), "cancelado el pacto, ya no hay permiso")

	print("== G2: guardado/carga y partidas antiguas")
	var sig1 := JSON.stringify(m.agr.list())
	var m3 := _reload(m)
	check(JSON.stringify(m3.agr.list()) == sig1 or m3.agr.list().size() == m.agr.list().size(), "compromisos intactos tras recargar")
	check(_ids_unique(m3), "ids de compromisos únicos tras recargar")
	m3.save_now()
	var m4 := _reload(m3)
	check(m4.agr.list().size() == m.agr.list().size() and _ids_unique(m4), "cargar y guardar dos veces no duplica acuerdos")
	# Partida antigua: sin ninguna de las claves nuevas
	var old: Dictionary = (JSON.parse_string(JSON.stringify(m.save)) as Dictionary)
	var gs: Dictionary = old["game_state"]
	for k in ["ivote_last", "ivote_history", "cand_sets", "cand_seq"]:
		gs.erase(k)
	var m5 := GameModel.new(old)
	check(m5.ivote.last().is_empty() and m5.ivote.history().is_empty(), "sin claves de votación: valores por defecto")
	var okl := true
	for i in range(m5.cab.size()):
		if m5.cands.shortlist(i).size() != MinistryCandidates.SIZE: okl = false
	check(okl, "partida antigua: se regeneran las listas de cinco candidatos")
	check(m5.agr.list().size() == m.agr.list().size(), "partida antigua: los acuerdos no cambian")
	m5.gov.advance_turn()
	check(m5.phase in ["legislature", "campaign", "election_night"], "partida antigua: la legislatura sigue avanzando")

	print("== G3: guardar durante la negociación y tras la investidura")
	var n := _game("psoe", 5)
	var cand := n.gov.candidate_id()
	var offers_before := JSON.stringify(JSON.parse_string(JSON.stringify(n.gov.offers())))
	var n2 := _reload(n)
	check(n2.phase == "investiture" and n2.gov.candidate_id() == cand, "se recarga en plena investidura con el mismo candidato")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(n2.gov.offers()))) == offers_before, "las ofertas de investidura no cambian al recargar")
	var est1 := n.gov.estimate_votes()
	var est2 := n2.gov.estimate_votes()
	check(int(est1["yes"]) == int(est2["yes"]) and int(est1["no"]) == int(est2["no"]), "el recuento previsto es el mismo tras recargar")
	var vote_a := n.ivote.cast()
	var vote_b := n2.ivote.cast()
	check(str(vote_a["votes"]) == str(vote_b["votes"]), "recargar no cambia los 350 votos")
	_finish_investiture(n)
	var cnt := n.agr.list().size()
	var n3 := _reload(n)
	check(n3.agr.list().size() == cnt and _ids_unique(n3), "tras la investidura, recargar no pierde ni duplica acuerdos (%d)" % cnt)
	check(n3.phase == n.phase, "la fase se conserva")

	print("== G4: IA presidente y jugador socio")
	var ai_game := _ai_president_with_player()
	check(ai_game.phase == "legislature" and ai_game.coal.gov_id() != ai_game.pid() and ai_game.gov.government_parties().has(ai_game.pid()), "IA presidente (%s) y el jugador en el Gobierno como socio" % ai_game.coal.gov_id())
	var vice_com := false
	var mine := 0
	for c in ai_game.agr.list():
		var cd: Dictionary = c
		if str(cd.get("party", "")) == ai_game.pid(): mine += 1
		if str((cd.get("verify", {}) as Dictionary).get("t", "")) == "vice" and str((cd.get("verify", {}) as Dictionary).get("party", "")) == ai_game.pid(): vice_com = true
	check(vice_com, "la vicepresidencia pedida por el jugador queda como compromiso suyo")
	var has_vice := false
	for i in range(ai_game.cab.size()):
		var e: Dictionary = ai_game.cab.entry(i)
		if str(e.get("rank", "")) == "vice" and str(e.get("party", "")) == ai_game.pid(): has_vice = true
	check(has_vice, "el Consejo da una vicepresidencia real al jugador")
	check(_ids_unique(ai_game), "compromisos con ids únicos (%d, %d del jugador)" % [ai_game.agr.list().size(), mine])
	for t in range(6):
		ai_game.gov.advance_turn()
		if ai_game.phase != "legislature": break
	check(_ids_unique(ai_game), "seis trimestres como socio sin errores ni duplicados (fase %s)" % ai_game.phase)
	var back := _reload(ai_game)
	check(back.agr.list().size() == ai_game.agr.list().size() and back.phase == ai_game.phase, "guardar/cargar como socio conserva los compromisos")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
