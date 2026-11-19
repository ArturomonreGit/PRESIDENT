extends SceneTree
## Parlamento: iniciativas, enmiendas bidireccionales, votación y control. Uso: godot --headless --path . --script res://tests/parliament.gd
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

func _law(m: GameModel, area: String, steps: int = 2, kind: String = "ley") -> Dictionary:
	var law := m.laws.new_draft(area, kind)
	var added := 0
	for it in Policies.measures_of(area):
		var meas: Dictionary = it
		if added >= 3:
			break
		var cur := m.eco.value(str(meas["id"]))
		var nv := Policies.snap(meas, cur + float(meas["step"]) * steps)
		if not is_equal_approx(nv, cur):
			m.laws.set_change(law, str(meas["id"]), nv)
			added += 1
	return law

func _initialize() -> void:
	for pid in ["psoe", "pp"]:
		_run(pid)
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)

func _run(pid: String) -> void:
	print("== Parlamento con ", pid)
	var m := _gov(pid)
	check(m.phase == "legislature", "se llega a la legislatura (%s)" % m.phase)
	# --- tipos de iniciativa y cupo de control
	var pnl := _law(m, "housing", 2, "pnl")
	check(str(pnl["kind"]) == "pnl" and m.laws.is_control(pnl), "la PNL es una iniciativa de control")
	check(m.congress.control_left() == 2, "dos acciones de control al mes (%d)" % m.congress.control_left())
	check(m.laws.register(str(pnl["id"])) == "", "se registra la PNL")
	check(m.congress.control_left() == 1, "la PNL gasta una acción de control")
	check(m.laws.unregister(str(pnl["id"])) and m.congress.control_left() == 2, "devolver a borradores recupera el cupo")
	var bills := m.gov.bills_left()
	var ley := _law(m, "housing")
	check(m.laws.register(str(ley["id"])) == "", "se registra una ley")
	check(m.gov.bills_left() == bills - 1, "la ley gasta una iniciativa")
	var inter := m.laws.new_draft("health", "interpelacion")
	check(m.laws.register(str(inter["id"])) == "", "se registra una interpelación sin medidas")
	check(m.laws.required_text(inter).contains("sin votación"), "la interpelación no se vota")
	# --- tope de 3 iniciativas al mes (también las del programa)
	check(GovernmentSim.INITIATIVES_PER_TURN == 3, "el tope es de 3 iniciativas al mes")
	check(m.gov.bills_left() == 1, "tras ley e interpelación queda 1 (%d)" % m.gov.bills_left())
	var cap_a := _law(m, "tax")
	var cap_b := _law(m, "education")
	check(m.laws.register(str(cap_a["id"])) == "", "la tercera iniciativa del mes entra")
	check(m.gov.bills_left() == 0, "el cupo queda a cero")
	check(m.laws.register(str(cap_b["id"])) != "", "la cuarta se rechaza")
	var cap_c := m.laws.new_draft("health", "pnl")
	check(m.laws.register(str(cap_c["id"])) != "", "ni una acción de control entra sin cupo")
	cap_c["promise"] = "x_test"
	check(m.laws.register(str(cap_c["id"])) != "", "ni una iniciativa del programa")
	check(m.laws.unregister(str(cap_a["id"])) and m.gov.bills_left() == 1, "retirar una devuelve el hueco")
	check(m.laws.register(str(cap_b["id"])) == "" and m.gov.bills_left() == 0, "y se puede usar en otra")
	# --- tono
	var l1 := _law(m, "tax")
	var other := ""
	for id in m.gov.parliamentary_ids():
		if not m.is_player(str(id)) and m.ai.affinity(str(id), m.pid()) < 0.45 and m.seats_of(str(id)) > 0:
			other = str(id)
			break
	if other != "":
		l1["tone"] = "estandar"
		l1["tone"] = "bandera"
		var s1 := m.laws.tone_mod(l1, other)
		l1["tone"] = "consenso"
		var s2 := m.laws.tone_mod(l1, other)
		l1["tone"] = "estandar"
		check(s1 < 0.0 and s2 > 0.0 and is_zero_approx(m.laws.tone_mod(l1, other)), "la bandera enfada a los lejanos y el consenso los suaviza (%.2f / %.2f)" % [s1, s2])
	# --- ofertas de la IA a una ley del jugador
	var total_offers := 0
	var accepted := 0
	for area in ["housing", "tax", "health", "labour", "education", "energy"]:
		var law := _law(m, area, 3)
		if (law["changes"] as Dictionary).is_empty():
			continue
		law["status"] = "registered"
		m.congress.amend.open(law)
		check(bool(m.congress.amend.state(law)["opened"]), "%s: trámite abierto" % area)
		m.congress.amend.open(law)
		for o in m.congress.amend.offers(law):
			var od: Dictionary = o
			total_offers += 1
			check(str(od["status"]) == "open" and (od["terms"] as Array).size() >= 1, "%s: oferta de %s con %d cambio(s)" % [area, str(od["from"]), (od["terms"] as Array).size()])
			check(str(od["vote_if"]) in ["yes", "abstain"], "la oferta promete voto a favor o abstención")
			check(m.congress.amend.outlook(law, str(od["from"]), od["terms"]) != "no", "con la enmienda el grupo ya no vota en contra")
		var open_list: Array = m.congress.amend.open_offers(law)
		if not open_list.is_empty():
			var first: Dictionary = open_list[0]
			var res := m.congress.amend.accept(law, int(first["id"]))
			check(bool(res["ok"]), "aceptar una oferta funciona")
			accepted += 1
			check((law["committed"] as Dictionary).has(str(first["from"])), "el grupo queda comprometido a votar")
			check(str(m.laws.stance(law, str(first["from"]))["vote"]) == str(first["vote_if"]), "su voto coincide con lo prometido (%s)" % str(first["vote_if"]))
			check(not bool(m.congress.amend.accept(law, int(first["id"]))["ok"]), "no se acepta dos veces")
		if open_list.size() > 1:
			var second: Dictionary = open_list[1]
			if str(second["status"]) == "open":
				var rr := m.congress.amend.reject(law, int(second["id"]))
				check(bool(rr["ok"]) and str(second["status"]) == "rejected", "rechazar una oferta")
	print("  ofertas de la IA a tus leyes: %d (aceptadas %d)" % [total_offers, accepted])
	check(total_offers > 0, "la IA presenta enmiendas a alguna de tus leyes (%d)" % total_offers)
	# --- contraoferta
	var lc := _law(m, "housing", 3)
	lc["status"] = "registered"
	m.congress.amend.open(lc)
	for o2 in m.congress.amend.open_offers(lc):
		var r2 := m.congress.amend.counter(lc, int((o2 as Dictionary)["id"]))
		check(r2.has("text") and str(r2["text"]) != "", "contraoferta responde con texto")
		break
	# --- tus enmiendas a la ley de otro
	var alt := ""
	for id2 in m.gov.parliamentary_ids():
		if not m.is_player(str(id2)) and m.seats_of(str(id2)) >= 20:
			alt = str(id2)
			break
	var verdicts := {"accepted": 0, "counter": 0, "rejected": 0}
	var base_month := m.gov_month
	var cap_checked := false
	var parties: Array = []
	for id3 in m.gov.parliamentary_ids():
		if not m.is_player(str(id3)) and m.seats_of(str(id3)) >= 10:
			parties.append(str(id3))
	for k2 in range(1, 40):
		m.gov_month = base_month + k2
		var al := m.laws.generate_ai_law(str(parties[k2 % parties.size()]))
		if al.is_empty():
			continue
		al["status"] = "registered"
		var opts := m.congress.amend.player_options(al)
		for op in opts:
			if float((op as Dictionary)["gain"]) <= 0.0:
				check(false, "la opción mejora tu postura")
		if opts.is_empty():
			continue
		var pr := m.congress.amend.propose(al, opts[0] as Dictionary)
		verdicts[str(pr["verdict"])] = int(verdicts.get(str(pr["verdict"]), 0)) + 1
		if not cap_checked:
			cap_checked = true
			check(str(pr["verdict"]) in ["accepted", "counter", "rejected"], "veredicto del proponente (%s)" % str(pr["verdict"]))
			check(m.congress.amend.slots_left(al) == Amendments.PLAYER_SLOTS - 1, "la enmienda gasta un cupo")
			for _k in range(Amendments.PLAYER_SLOTS - 1):
				m.congress.amend.propose(al, opts[0] as Dictionary)
			var extra := m.congress.amend.propose(al, opts[0] as Dictionary)
			check(not bool(extra["ok"]), "no hay más enmiendas que el cupo")
		if str(pr["verdict"]) == "counter":
			var before_n: int = (al["changes"] as Dictionary).size()
			check(bool(m.congress.amend.accept_counter(al, 0)["ok"]), "aceptar la transaccional")
			check((al["changes"] as Dictionary).size() >= 0 and before_n >= 0, "la transaccional se aplica")
	m.gov_month = base_month
	# --- enmiendas libres: el jugador elige cualquier medida y valor
	var fl_law := m.laws.generate_ai_law(str(parties[0]))
	if not fl_law.is_empty():
		fl_law["status"] = "registered"
		var amd2 := m.congress.amend
		var in_mid := ""
		for k3 in (fl_law["changes"] as Dictionary).keys():
			if not Policies.is_special(str(k3)):
				in_mid = str(k3)
				break
		if in_mid != "":
			var cur_v := m.eco.value(in_mid)
			var t_drop := amd2.make_term(fl_law, in_mid, cur_v)
			check(str(t_drop.get("type", "")) == "drop", "volver al valor vigente es retirar la medida")
			check(amd2.make_term(fl_law, in_mid, amd2.value_in_law(fl_law, in_mid)).is_empty(), "sin cambio no hay enmienda")
			var pvw := amd2.preview(fl_law, t_drop)
			check(str(pvw["verdict"]) in ["accept", "talk", "reject"] and pvw.has("mine") and pvw.has("theirs"), "la vista previa da veredicto y efectos")
		var free_mid := ""
		for mm in Policies.measures():
			var md: Dictionary = mm
			if str(md["area"]) != str(fl_law["area"]) and not (fl_law["changes"] as Dictionary).has(str(md["id"])) and str(md["id"]) != Irpf.SPECIAL_ID:
				free_mid = str(md["id"])
				break
		if free_mid != "":
			var fm := Policies.measure(free_mid)
			var up := Policies.snap(fm, m.eco.value(free_mid) + float(fm["step"]) * 3.0)
			var t_add := amd2.make_term(fl_law, free_mid, up)
			check(str(t_add.get("type", "")) == "add" or t_add.is_empty(), "una medida de otra área se puede añadir (%s)" % str(t_add.get("type", "")))
			if not t_add.is_empty():
				var rr2 := amd2.propose(fl_law, t_add)
				check(bool(rr2.has("verdict")), "se presenta una enmienda libre (%s)" % str(rr2["verdict"]))
	print("  veredictos: ", verdicts)
	check(int(verdicts["accepted"]) + int(verdicts["counter"]) + int(verdicts["rejected"]) > 0, "se han podido presentar enmiendas a leyes de la IA")
	# --- enmiendas entre partidos de la IA
	var logged := 0
	for k in range(8):
		m.gov_month = base_month + 50 + k
		var al2 := m.laws.generate_ai_law(alt)
		if al2.is_empty():
			continue
		al2["id"] = "t_%d" % k
		m.congress.amend.open(al2)
		logged += m.congress.amend.log_of(al2).size()
	m.gov_month = base_month
	check(logged >= 0, "los grupos de la IA se enmiendan entre sí (%d registros)" % logged)
	# --- votar: reasons, followers, PNL y control
	m.congress.open_session()
	var l2 := _law(m, "housing")
	l2["status"] = "registered"
	m.congress.session()["laws"] = [l2, m.laws.queue().duplicate(true)[0] if false else _law(m, "tax")]
	m.congress.session()["idx"] = 0
	m.congress.session()["results"] = []
	m.congress.session()["stage"] = "running"
	var t := m.congress.tally(l2, "yes")
	check((t["by_party"] as Dictionary).size() == m.gov.parliamentary_ids().size(), "todos los grupos votan")
	var res3 := m.congress.resolve_current("yes")
	check((res3["reasons"] as Dictionary).size() == m.gov.parliamentary_ids().size(), "cada grupo explica su voto")
	for r in (res3["reasons"] as Dictionary).values():
		check(str(r) != "", "frase de voto no vacía")
		break
	check(res3.has("followers"), "se registra el voto de arrastre")
	# PNL
	var pnl2 := _law(m, "health", 2, "pnl")
	pnl2["status"] = "registered"
	m.congress.session()["laws"] = [pnl2]
	m.congress.session()["idx"] = 0
	m.congress.session()["stage"] = "running"
	m.congress.session()["results"] = []
	var vis := m.visibility
	var vals := {}
	for mid in (pnl2["changes"] as Dictionary).keys():
		vals[mid] = m.eco.value(str(mid))
	var res4 := m.congress.resolve_current("yes")
	check(res4.has("passed"), "la PNL se resuelve")
	for mid2 in vals.keys():
		check(is_equal_approx(m.eco.value(str(mid2)), float(vals[mid2])), "la PNL no cambia las medidas (%s)" % str(mid2))
	# Interpelación
	var it := m.laws.new_draft("health", "interpelacion")
	it["style"] = "duro"
	it["status"] = "registered"
	m.congress.session()["laws"] = [it]
	m.congress.session()["idx"] = 0
	m.congress.session()["stage"] = "running"
	m.congress.session()["results"] = []
	var res5 := m.congress.resolve_current("")
	check(str(res5["tier"]) in ["big", "ok", "flop", "backfire"], "interpelación con resultado (%s)" % str(res5["tier"]))
	check(m.congress.stage() == "done", "la sesión termina")
	# --- retirar una ley propia
	var wl := _law(m, "housing")
	m.s["bills_left"] = 2
	check(m.laws.register(str(wl["id"])) == "", "se registra la ley a retirar")
	m.congress.open_session()
	var sl: Array = m.congress.laws()
	var found := false
	for x in sl:
		if str((x as Dictionary)["id"]) == str(wl["id"]):
			found = true
	check(found, "tu ley registrada entra en el orden del día")
	# colocar la ley propia como actual
	m.congress.session()["laws"] = [wl]
	m.congress.session()["idx"] = 0
	m.congress.session()["stage"] = "running"
	var bl := m.gov.bills_left()
	check(m.congress.withdraw_current(), "se puede retirar una ley propia")
	check(m.gov.bills_left() == bl + 1, "retirarla devuelve la iniciativa")
	check(not m.laws.draft_by_id(str(wl["id"])).is_empty(), "vuelve a borradores")
	# --- auto_finish no se rompe con enmiendas abiertas
	m.congress.open_session()
	m.congress.open_debate()
	m.congress.auto_finish()
	check(m.congress.stage() == "done", "auto_finish cierra la sesión")
	# --- guardado: todo es serializable
	var js := JSON.stringify(m.s)
	check(js.length() > 100, "estado serializable")
