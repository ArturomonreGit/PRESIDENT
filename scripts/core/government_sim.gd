class_name GovernmentSim
extends RefCounted
## Formación de Gobierno: investidura con negociación, reparto de carteras y legislatura mensual.
## Fases: results → investiture → cabinet_design → legislature → (elecciones) campaign.

var m: GameModel

const ACCEPT_THRESHOLD := 0.62
const CONCESSION_VALUE := 0.12
const CABINET_VALUE := 0.14

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- consultas básicas
func offers() -> Dictionary:
	return m.d("negotiation_offers")

func partners() -> Array:
	return m.a("coalition_partners")

func candidate_id() -> String:
	return str(m.s.get("negotiation_candidate_id", ""))

func parliamentary_ids() -> Array:
	## Partidos con escaños, de mayor a menor.
	var ids: Array = []
	for p in m.all_parties():
		var id := str((p as Dictionary).get("id", ""))
		if m.seats_of(id) > 0:
			ids.append(id)
	ids.sort_custom(func(x: String, y: String) -> bool:
		if m.seats_of(x) != m.seats_of(y):
			return m.seats_of(x) > m.seats_of(y)
		return x < y)
	return ids

func candidates() -> Array:
	var ids := parliamentary_ids()
	var list: Array = []
	for id in ids:
		if m.seats_of(str(id)) >= Rules.CANDIDATE_MIN_SEATS:
			list.append(str(id))
	if list.is_empty():
		list = ids.slice(0, 2)
	return list

func coalition_seats() -> int:
	var total := m.seats_of(candidate_id())
	for id in partners():
		total += m.seats_of(str(id))
	return total

func attempts() -> int:
	return int(m.s.get("investiture_attempts", 0))

func round_number() -> int:
	return int(m.s.get("negotiation_round", 1))

# ---------------------------------------------------------------- inicio de la negociación
func begin_investiture() -> void:
	m.phase = "investiture"
	m.s["investiture_attempts"] = 0
	m.s["negotiation_round"] = 1
	m.s["player_vote"] = ""
	m.advance_clock_days(21)
	m.s["investiture_log"] = []
	m.s["negotiation_candidate_id"] = str(parliamentary_ids()[0])
	var cand := candidate_id()
	m.publish("El Rey inicia la ronda de consultas",
		"El Rey propone primero al candidato de la fuerza más votada: %s, con %d escaños. Si no logra la confianza del Congreso, lo intentará el segundo partido. Tras dos intentos fallidos, se disuelven las Cortes y hay elecciones. Se necesitan %d votos a favor en primera votación." % [m.party_short(cand), m.seats_of(cand), Rules.MAJORITY],
		"INVESTIDURA", "neutral")
	reset_negotiation()
	m.save_now()

func reset_negotiation() -> void:
	partners().clear()
	offers().clear()
	m.s["negotiation_round"] = 1
	ensure_offers(false)
	m.diplomacy.candidate_offer()

func set_candidate(id: String) -> bool:
	if not candidates().has(id):
		return false
	m.s["negotiation_candidate_id"] = id
	reset_negotiation()
	return true

func demand_pool(id: String) -> Array:
	var group: String
	if m.is_player(id):
		var prios := m.ai.issue_priorities(m.party)
		var pool: Array = []
		for issue in prios.slice(0, 2):
			for entry in Rules.DEMANDS[m.ai.demand_group(str(issue))]:
				pool.append(entry)
		return pool
	group = str(m.ai.profile_of(id).get("priority", "economy"))
	return (Rules.DEMANDS.get(group, Rules.DEMANDS["economy"]) as Array).duplicate()

func _make_offer(id: String) -> Dictionary:
	var pool := demand_pool(id)
	if not m.is_player(id):
		pool.shuffle()
		pool = pool.slice(0, mini(3, pool.size()))
	var demands: Array = []
	var i := 0
	for entry in pool:
		demands.append({"id": "%s_%d" % [id, i], "issue": str((entry as Dictionary)["issue"]), "text": str((entry as Dictionary)["text"]), "conceded": false})
		i += 1
	return {"party_name": m.party_short(id), "seats": m.seats_of(id), "status": "open", "demands": demands, "role": "external", "note": ""}

func ensure_offers(force: bool) -> void:
	var all := offers()
	if force:
		all.clear()
		partners().clear()
	var cand := candidate_id()
	if cand == "":
		return
	for id in parliamentary_ids():
		if str(id) == cand or all.has(str(id)):
			continue
		all[str(id)] = _make_offer(str(id))
	if m.is_player(cand):
		m.diplomacy.apply_pledges(cand)
	else:
		for id in all.keys():
			var offer: Dictionary = all[id]
			if str(offer.get("status", "open")) == "open" and not m.is_player(str(id)):
				_ai_resolve(str(id))

# ---------------------------------------------------------------- valoración de acuerdos
## Convierte la oferta guardada de un partido en los términos que valora el cerebro.
func offer_terms(id: String) -> Array:
	var offer: Dictionary = offers().get(id, {})
	var terms: Array = []
	var cand := candidate_id()
	if m.is_player(id):
		# El jugador es socio: da su voto y pide medidas y carteras al candidato.
		terms.append({"k": "vote_yes", "by": "player"})
		for d in offer.get("demands", []):
			var dem: Dictionary = d
			if bool(dem.get("conceded", false)):
				terms.append({"k": "policy", "by": "ai", "issue": str(dem["issue"]), "text": str(dem["text"]), "lean": m.brain.lean(m.pid(), str(dem["issue"]))})
		if str(offer.get("role", "external")) == "cabinet":
			terms.append({"k": "cabinet", "by": "ai", "n": 1})
		return terms
	terms.append({"k": "vote_abstain" if str(offer.get("vote", "yes")) == "abstain" else "vote_yes", "by": "ai"})
	for d in offer.get("demands", []):
		var dem2: Dictionary = d
		if bool(dem2.get("conceded", false)):
			terms.append({"k": "policy", "by": "player", "issue": str(dem2["issue"]), "text": str(dem2["text"])})
	if str(offer.get("role", "external")) == "cabinet":
		terms.append({"k": "cabinet", "by": "player", "n": int(m.d("cabinet_claims").get(id, 1))})
	return terms

func assess_offer(id: String) -> Dictionary:
	var cand := candidate_id()
	if m.is_player(id):
		return m.brain.assess(cand, m.pid(), offer_terms(id), m.diplomacy.context_for({"with": cand}))
	return m.brain.assess(id, cand, offer_terms(id), m.diplomacy.context_for({"with": id}))

func vetoed(id: String, cand: String) -> bool:
	return m.brain.blocked_by(id, cand) != ""

func offer_score(id: String) -> float:
	var res := assess_offer(id)
	return float(res["utility"]) - float(res["need"]) + 0.62

## Etiqueta de disposición de un partido ante el acuerdo actual.
func willingness_label(id: String) -> Dictionary:
	var res := assess_offer(id)
	match str(res["verdict"]):
		"veto": return {"text": "Veto político", "tone": "bad"}
		"accept": return {"text": "Dispuesto a firmar", "tone": "good"}
		"counter": return {"text": "Dudoso", "tone": "warn"}
	return {"text": "En contra", "tone": "bad"}

func _ai_resolve(id: String) -> void:
	var offer: Dictionary = offers()[id]
	var prof := m.ai.profile_of(id)
	var demands: Array = offer["demands"]
	var n := int(round(float(prof.get("pragmatism", 0.5)) * float(demands.size())))
	for i in range(demands.size()):
		(demands[i] as Dictionary)["conceded"] = i < n
	# La fórmula de participación sale del carácter del partido, no de su tamaño (spec negociación §4.2).
	var pref := m.brain.preferred_modality(id, candidate_id())
	var mode := str(pref["mode"])
	offer["modality"] = mode
	offer["role"] = "cabinet" if mode == "coalition" and m.seats_of(id) >= 3 else "external"
	offer["vote"] = "abstain" if mode == "abstention" else "yes"
	var label := willingness_label(id)
	if mode == "block":
		label = {"text": "Bloqueo", "tone": "bad"}
	if str(label["tone"]) == "good":
		offer["status"] = "accepted"
		if not partners().has(id):
			partners().append(id)
	else:
		offer["status"] = "rejected"
		partners().erase(id)

func set_concession(id: String, index: int, value: bool) -> void:
	var offer: Dictionary = offers().get(id, {})
	if offer.is_empty():
		return
	var demands: Array = offer["demands"]
	if index >= 0 and index < demands.size():
		(demands[index] as Dictionary)["conceded"] = value
	_reopen(id)

func set_role(id: String, role: String) -> void:
	var offer: Dictionary = offers().get(id, {})
	if offer.is_empty():
		return
	offer["role"] = role
	_reopen(id)

func _reopen(id: String) -> void:
	var offer: Dictionary = offers()[id]
	if str(offer.get("status", "open")) != "open":
		offer["status"] = "open"
		partners().erase(id)

## El jugador (candidato) propone el acuerdo a un partido.
func propose(id: String) -> String:
	var offer: Dictionary = offers().get(id, {})
	if offer.is_empty():
		return ""
	var label := willingness_label(id)
	var short := m.party_short(id)
	if str(label["tone"]) == "good":
		offer["status"] = "accepted"
		if not partners().has(id):
			partners().append(id)
		m.ai.change_relation(id, 8.0)
		m.ai.remember({"party": id, "event": "agreement_accepted", "detail": _conceded_text(offer)})
		m.publish("Acuerdo preliminar con %s" % short,
			"%s apoyará la investidura a cambio de: %s. %s" % [short, _conceded_text(offer), "Entrará en el Consejo de Ministros." if str(offer["role"]) == "cabinet" else "Mantendrá un apoyo parlamentario externo."],
			"NEGOCIACIONES", "positive")
		return "%s acepta el acuerdo." % short
	offer["status"] = "rejected"
	partners().erase(id)
	m.ai.change_relation(id, -3.0)
	m.ai.remember({"party": id, "event": "agreement_rejected", "detail": _conceded_text(offer)})
	var reason := "No hay encaje político suficiente." if vetoed(id, candidate_id()) else "Las condiciones ofrecidas no le bastan."
	offer["note"] = reason
	m.publish("%s rechaza el acuerdo" % short, reason + " El apoyo no está garantizado.", "NEGOCIACIONES", "warning")
	return "%s rechaza: %s" % [short, reason]

func _conceded_text(offer: Dictionary) -> String:
	var parts: Array = []
	for d in offer.get("demands", []):
		if bool((d as Dictionary).get("conceded", false)):
			parts.append(str(d["text"]))
	return "; ".join(parts) if not parts.is_empty() else "apoyo sin condiciones"

func withdraw(id: String) -> void:
	_reopen(id)

# ---- el jugador como socio: pide condiciones a un candidato de la IA
func player_leverage() -> float:
	var cand := candidate_id()
	var needed := Rules.MAJORITY - m.seats_of(cand)
	for id in partners():
		if not m.is_player(str(id)):
			needed -= m.seats_of(str(id))
	needed = maxi(1, needed)
	var pivotal := clampf(float(m.seats_of(m.pid())) / float(needed), 0.0, 1.0)
	var prag := float(m.ai.profile_of(cand).get("pragmatism", 0.5))
	return 0.15 + pivotal * 0.6 + m.ai.relation(cand) / 100.0 * 0.2 + prag * 0.2

func player_ask_cost() -> float:
	var offer: Dictionary = offers().get(m.pid(), {})
	var cost := 0.0
	for d in offer.get("demands", []):
		if bool((d as Dictionary).get("conceded", false)):
			cost += 0.2
	if str(offer.get("role", "external")) == "cabinet":
		cost += 0.35
	return cost

func propose_as_partner() -> String:
	var id := m.pid()
	var offer: Dictionary = offers().get(id, {})
	if offer.is_empty():
		return ""
	var cand := candidate_id()
	var cname := m.party_short(cand)
	var res := assess_offer(id)
	if str(res["verdict"]) == "veto":
		offer["status"] = "rejected"
		offer["note"] = "%s descarta cualquier acuerdo con tu partido." % cname
		return str(offer["note"])
	if str(res["verdict"]) == "accept":
		offer["status"] = "accepted"
		if not partners().has(id):
			partners().append(id)
		m.ai.change_relation(cand, 5.0)
		m.s["player_vote"] = "yes"
		var asks := _conceded_text(offer)
		m.publish("%s acepta las condiciones de tu partido" % cname,
			"Tu apoyo a la investidura queda comprometido a cambio de: %s. %s" % [asks, "Entrarás en el Consejo de Ministros." if str(offer["role"]) == "cabinet" else "Mantendrás un apoyo externo."],
			"NEGOCIACIONES", "positive")
		return "Acuerdo cerrado con %s." % cname
	offer["status"] = "rejected"
	offer["note"] = "%s considera excesivas tus peticiones. Reduce las exigencias o renuncia a entrar en el Gobierno." % cname
	partners().erase(id)
	m.publish("%s rechaza las condiciones de tu partido" % cname, str(offer["note"]), "NEGOCIACIONES", "warning")
	return str(offer["note"])

func set_player_vote(vote: String) -> void:
	m.s["player_vote"] = vote

# ---------------------------------------------------------------- votación de investidura
func estimate_votes() -> Dictionary:
	var cand := candidate_id()
	var yes := m.seats_of(cand)
	var no := 0
	var abstain := 0
	var detail: Dictionary = {}
	detail[cand] = "yes"
	for id in parliamentary_ids():
		var pid := str(id)
		if pid == cand:
			continue
		var seats := m.seats_of(pid)
		var vote := "abstain"
		var offer_pid: Dictionary = offers().get(pid, {})
		if partners().has(pid):
			vote = "yes"
		elif m.is_player(pid):
			vote = str(m.s.get("player_vote", ""))
			if vote == "" or vote == "yes":
				vote = "abstain"
		elif str(offer_pid.get("status", "")) == "accepted" and str(offer_pid.get("vote", "yes")) == "abstain":
			vote = "abstain"
		else:
			var cand_is_player := m.is_player(cand)
			var disp: float = m.brain.disposition(pid, cand) if cand_is_player else m.brain.compat(pid, cand) * 100.0
			if m.brain.compat(pid, cand) < 0.3 or m.brain.blocked_by(pid, cand) != "" or (cand_is_player and disp < 24.0):
				vote = "no"
		detail[pid] = vote
		match vote:
			"yes": yes += seats
			"no": no += seats
			_: abstain += seats
	return {"yes": yes, "no": no, "abstain": abstain, "detail": detail}

func hold_vote() -> Dictionary:
	var tally := estimate_votes()
	var rnd := round_number()
	var passed := int(tally["yes"]) >= Rules.MAJORITY if rnd == 1 else int(tally["yes"]) > int(tally["no"])
	var cand := candidate_id()
	var result := {"passed": passed, "tally": tally, "round": rnd, "dissolved": false}
	m.publish("Investidura de %s: %s (%s votación)" % [m.party_short(cand), "aprobada" if passed else "fallida", "primera" if rnd == 1 else "segunda"],
		"%d votos a favor, %d en contra y %d abstenciones. %s" % [tally["yes"], tally["no"], tally["abstain"], "El candidato obtiene la confianza del Congreso." if passed else "No se alcanza la mayoría necesaria."],
		"PARLAMENTO", "positive" if passed else "warning")
	if passed:
		m.s["government_party_id"] = cand
		m.s["government_candidate_id"] = cand
		m.phase = "cabinet_design"
		m.advance_clock_days(3)
		_start_cabinet_design()
	elif rnd == 1:
		m.s["negotiation_round"] = 2
		m.advance_clock_days(2)
	else:
		m.a("investiture_log").append({"party": cand, "round": rnd})
		m.s["investiture_attempts"] = attempts() + 1
		m.advance_clock_days(30)
		if attempts() >= Rules.MAX_INVESTITURE_ATTEMPTS:
			result["dissolved"] = true
			m.publish("Disolución de las Cortes", "Ni %s ni el segundo candidato han logrado la confianza del Congreso. El Rey disuelve las Cortes y se convocan nuevas elecciones." % m.party_short(cand), "PARLAMENTO", "warning")
			start_new_cycle("investiture")
		else:
			var ranked := parliamentary_ids()
			m.s["negotiation_candidate_id"] = str(ranked[mini(attempts(), ranked.size() - 1)])
			m.publish("El Rey propone al segundo candidato", "Tras el fracaso de %s, el Rey encarga la investidura a %s (intento %d de %d). Si también fracasa, se convocan elecciones." % [m.party_short(cand), m.party_short(candidate_id()), attempts() + 1, Rules.MAX_INVESTITURE_ATTEMPTS], "INVESTIDURA", "neutral")
			reset_negotiation()
	m.save_now()
	return result

# ---------------------------------------------------------------- Consejo de Ministros
func cabinet() -> Array:
	return m.a("cabinet")

func government_parties() -> Array:
	var ids: Array = [str(m.s.get("government_party_id", candidate_id()))]
	for id in partners():
		var offer: Dictionary = offers().get(str(id), {})
		if str(offer.get("role", "external")) == "cabinet" and not ids.has(str(id)):
			ids.append(str(id))
	return ids

func _start_cabinet_design() -> void:
	var cabinet_partners := government_parties().size() - 1
	m.s["cabinet_size"] = clampi(10 + cabinet_partners * 2, 8, 18)
	var claimed := 0
	for id in government_parties():
		claimed += int(m.d("cabinet_claims").get(str(id), 0))
	m.s["cabinet_size"] = clampi(maxi(int(m.s["cabinet_size"]), claimed + 4), 8, 18)
	cabinet().clear()
	_grow_cabinet(int(m.s["cabinet_size"]))
	_apply_claims()

## Reparte primero las carteras que los socios pactaron en la mesa.
func _apply_claims() -> void:
	var list := cabinet()
	var claims := m.d("cabinet_claims")
	var gov_id := str(m.s.get("government_party_id", candidate_id()))
	for id in claims.keys():
		var want := int(claims[id])
		if not government_parties().has(str(id)):
			continue
		var have := 0
		for e in list:
			if str((e as Dictionary)["party"]) == str(id):
				have += 1
		# Las carteras de menos peso (final del catálogo) se ceden al socio.
		var i := list.size() - 1
		while have < want and i >= 1:
			if str((list[i] as Dictionary)["party"]) == gov_id:
				(list[i] as Dictionary)["party"] = str(id)
				have += 1
			i -= 1

func _grow_cabinet(target: int) -> void:
	var list := cabinet()
	var gov_ids := government_parties()
	while list.size() > target:
		list.pop_back()
	while list.size() < target and list.size() < Rules.MINISTRY_CATALOG.size():
		var counts: Dictionary = {}
		for g in gov_ids:
			counts[str(g)] = 0
		for entry in list:
			var party_id := str((entry as Dictionary)["party"])
			counts[party_id] = int(counts.get(party_id, 0)) + 1
		var recipient: String = str(gov_ids[0])
		if list.size() > 0:
			var best := -1.0
			for g in gov_ids:
				var q := float(m.seats_of(str(g))) / float(int(counts.get(str(g), 0)) + 1)
				if q > best:
					best = q
					recipient = str(g)
		list.append({"name": str(Rules.MINISTRY_CATALOG[list.size()]), "key": str(Rules.MINISTRY_CATALOG[list.size()]), "party": recipient})

func set_cabinet_size(n: int) -> void:
	m.s["cabinet_size"] = clampi(n, 8, 18)
	_grow_cabinet(int(m.s["cabinet_size"]))

func rename_ministry(index: int, new_name: String) -> void:
	var list := cabinet()
	if index >= 0 and index < list.size() and not new_name.strip_edges().is_empty():
		(list[index] as Dictionary)["name"] = new_name.strip_edges()

func assign_ministry(index: int, party_id: String) -> void:
	var list := cabinet()
	if index >= 0 and index < list.size() and government_parties().has(party_id):
		if str((list[index] as Dictionary).get("party", "")) != party_id:
			(list[index] as Dictionary).erase("minister")
		(list[index] as Dictionary)["party"] = party_id

func validate_cabinet() -> Dictionary:
	var counts: Dictionary = {}
	for entry in cabinet():
		var party_id := str((entry as Dictionary)["party"])
		counts[party_id] = int(counts.get(party_id, 0)) + 1
	for g in government_parties():
		if int(counts.get(str(g), 0)) == 0:
			return {"ok": false, "error": "%s debe tener al menos una cartera." % m.party_short(str(g))}
	return {"ok": true}

## El jugador (socio) rechaza las carteras ofrecidas y pasa a apoyo externo.
func player_declines_cabinet() -> void:
	var offer: Dictionary = offers().get(m.pid(), {})
	if not offer.is_empty():
		offer["role"] = "external"
	_start_cabinet_design()
	m.publish("Tu partido renuncia a entrar en el Gobierno", "La formación prefiere mantener autonomía parlamentaria y apoyar desde fuera.", "NEGOCIACIONES", "neutral")

func form_government() -> Dictionary:
	var check := validate_cabinet()
	if not bool(check["ok"]):
		return check
	m.phase = "legislature"
	m.gov_month = 1
	m.advance_clock_days(5)
	var counts: Dictionary = {}
	for entry in cabinet():
		var pid := str((entry as Dictionary)["party"])
		counts[pid] = int(counts.get(pid, 0)) + 1
	var parts: Array = []
	for pid in counts.keys():
		parts.append("%s: %d" % [m.party_short(str(pid)), int(counts[pid])])
	ensure_legislature_state(true)
	var gp := government_parties()
	for other in gp:
		if str(other) != str(gp[0]):
			m.voters.on_pact(str(gp[0]), str(other))
	m.militancy.on_government_formed()
	create_commitments()
	m.manifesto.create_bills()
	m.cab.ensure()
	m.ministers.ensure_cabinet()
	m.exec.on_government_formed()
	m.coal.on_formed()
	m.congress.open_session()
	m.publish("El nuevo Gobierno queda constituido", "Consejo de Ministros de %d carteras. Reparto: %s. Comienza la legislatura." % [cabinet().size(), ", ".join(parts)], "GOBIERNO", "positive")
	m.save_now()
	return {"ok": true}

# ---------------------------------------------------------------- legislatura
func ensure_legislature_state(reset: bool = false) -> void:
	var gov_id := str(m.s.get("government_party_id", candidate_id()))
	m.s["government_party_id"] = gov_id
	if reset or not m.s.has("gov_approval"):
		var bonus := (m.trust - 50.0) / 5.0 if gov_id == m.pid() else 0.0
		m.s["gov_approval"] = clampf(50.0 + bonus, 20.0, 80.0)
	if reset or not m.s.has("stability"):
		m.s["stability"] = clampf(40.0 + float(coalition_seats() - 160) * 0.8, 20.0, 90.0)
	if reset or not m.s.has("economy"):
		m.s["economy"] = 50.0
	if reset or not m.s.has("bills_left"):
		m.s["bills_left"] = INITIATIVES_PER_TURN
	var sat := m.d("partner_satisfaction")
	if reset:
		sat.clear()
	for id in partners():
		if not sat.has(str(id)):
			sat[str(id)] = 60.0
	m.a("passed_bills")
	m.a("commitments")

## Un compromiso con medida concreta se da por cumplido cuando la medida alcanza el valor pactado.
func _measure_done(com: Dictionary) -> bool:
	var cur := m.eco.value(str(com["measure"]))
	var from_v := float(com.get("from", cur))
	var to_v := float(com.get("to", cur))
	return cur >= to_v - 0.0001 if to_v >= from_v else cur <= to_v + 0.0001

func create_commitments() -> void:
	var list := m.a("commitments")
	list.clear()
	for id in partners():
		var offer: Dictionary = offers().get(str(id), {})
		for d in offer.get("demands", []):
			var dem: Dictionary = d
			if bool(dem.get("conceded", false)):
				var com := {"party": str(id), "issue": str(dem["issue"]), "text": str(dem["text"]), "due": 8, "fulfilled": false, "overdue_flagged": false}
				var mid := str(dem.get("measure", ""))
				if mid != "" and not Policies.measure(mid).is_empty():
					com["measure"] = mid
					com["to"] = float(dem.get("to", 0.0))
					com["from"] = m.eco.value(mid)
					# Ceder en algo contrario a tu propia línea cuesta credibilidad ante tus votantes.
					if not m.is_player(str(id)) and m.is_player(candidate_id()):
						var pm: float = m.brain.measure_pref_of_term(m.pid(), {"measure": mid, "to": com["to"]})
						if pm < -0.25:
							m.trust = clampf(m.trust - 2.5, 5.0, 95.0)
							m.publish("Tus bases critican una cesión", "Aceptar «%s» choca con la línea de tu partido y desconcierta a tu electorado." % str(dem["text"]), "NEGOCIACIONES", "warning")
				list.append(com)

func approval() -> float:
	return float(m.s.get("gov_approval", 50.0))

func stability() -> float:
	return float(m.s.get("stability", 50.0))

func economy() -> float:
	return float(m.s.get("economy", 50.0))

## Máximo de iniciativas parlamentarias registrables por turno (trimestre), incluidas las del programa electoral.
const INITIATIVES_PER_TURN := 3

func bills_left() -> int:
	return int(m.s.get("bills_left", 0))

func average_satisfaction() -> float:
	var sat := m.d("partner_satisfaction")
	if sat.is_empty():
		return 60.0
	var total := 0.0
	for v in sat.values():
		total += float(v)
	return total / float(sat.size())

## Desgaste o respaldo al Gobierno por factores externos (p. ej. oposición brillante en un medio).
func shift_government_approval(delta: float) -> void:
	m.s["gov_approval"] = clampf(approval() + delta, 5.0, 95.0)
	m.voters.on_approval(delta)

func player_in_government() -> bool:
	return m.role() in ["government", "partner"]

func pending_event_message() -> Dictionary:
	for msg in m.news():
		var mm: Dictionary = msg
		if str(mm.get("category", "")) == "GOBIERNO" and bool(mm.get("needs_response", false)) and not bool(mm.get("resolved", false)):
			return mm
	return {}

func apply_event_choice(event_id: String, index: int) -> String:
	for ev in Rules.LEGISLATURE_EVENTS:
		var e: Dictionary = ev
		if str(e["id"]) != event_id:
			continue
		var choices: Array = e["choices"]
		if index < 0 or index >= choices.size():
			return ""
		var c: Dictionary = choices[index]
		m.s["gov_approval"] = clampf(approval() + float(c.get("approval", 0.0)), 5.0, 95.0)
		m.voters.on_approval(float(c.get("approval", 0.0)))
		m.s["stability"] = clampf(stability() + float(c.get("stability", 0.0)), 0.0, 100.0)
		if player_in_government():
			m.trust = m.trust + float(c.get("trust", 0.0))
			if c.has("funds"):
				m.add_finance("Gestión de crisis: %s" % str(e["title"]), float(c["funds"]))
		return "%s → apoyo del Gobierno %+.1f, estabilidad %+.1f" % [str(c["label"]), float(c.get("approval", 0.0)), float(c.get("stability", 0.0))]
	return ""

func _random_event() -> void:
	var recent: Array = m.a("recent_events")
	var pool: Array = []
	for ev in Rules.LEGISLATURE_EVENTS:
		if not recent.has(str((ev as Dictionary)["id"])):
			pool.append(ev)
	if pool.is_empty():
		recent.clear()
		pool = Rules.LEGISLATURE_EVENTS.duplicate()
	var e: Dictionary = pool[m.rng.randi_range(0, pool.size() - 1)]
	recent.append(str(e["id"]))
	while recent.size() > 4:
		recent.pop_front()
	var choices: Array = e["choices"]
	if player_in_government():
		var actions: Array = []
		for i in range(choices.size()):
			actions.append({"id": "legchoice:%s:%d" % [str(e["id"]), i], "label": str((choices[i] as Dictionary)["label"]), "style": "primary" if i == 0 else "secondary"})
		m.publish(str(e["title"]), str(e["body"]), "GOBIERNO", "warning", {"needs_response": true, "actions": actions, "event_id": str(e["id"])})
		m.media.on_event(str(e["title"]))
	else:
		var idx := m.rng.randi_range(0, choices.size() - 1)
		var text := apply_event_choice(str(e["id"]), idx)
		m.publish(str(e["title"]), "%s El Gobierno opta por: %s." % [str(e["body"]), str((choices[idx] as Dictionary)["label"]).to_lower()], "GOBIERNO", "neutral")
		if text == "":
			return

func _resolve_pending_event_by_default() -> void:
	var msg := pending_event_message()
	if msg.is_empty():
		return
	var event_id := str(msg.get("event_id", ""))
	for ev in Rules.LEGISLATURE_EVENTS:
		if str((ev as Dictionary)["id"]) == event_id:
			var last := ((ev as Dictionary)["choices"] as Array).size() - 1
			apply_event_choice(event_id, last)
	msg["resolved"] = true
	msg["needs_response"] = false
	msg["resolution"] = "Sin respuesta: se aplicó la opción más pasiva."

## Avanza un turno de legislatura = un trimestre (Rules.TURN_MONTHS meses): la economía se recalcula entera y la
## política, las encuestas y las relaciones acumulan tres meses de cambios.
func advance_turn() -> Dictionary:
	if m.phase != "legislature":
		return {"ok": false}
	_resolve_pending_event_by_default()
	# Si el Pleno quedó a medias, el resto de iniciativas se vota según la recomendación de tu ideología.
	m.congress.auto_finish()
	var tm := float(Rules.TURN_MONTHS)
	m.gov_month = m.gov_month + Rules.TURN_MONTHS
	m.advance_clock_days(Rules.TURN_MONTHS * 30 + 1)
	m.s["bills_left"] = maxi(1, INITIATIVES_PER_TURN - m.itrust.bills_penalty())
	m.cab.ensure()
	m.ministers.ensure_cabinet()
	m.eco.tick()
	m.macro.quarter_report()
	m.exec.monthly()
	m.manifesto.monthly()
	var econ := economy()
	var app := approval()
	app += ((m.eco.avg_satisfaction() - 47.0) * 0.05 + (econ - 50.0) * 0.015 + (50.0 - app) * 0.03) * tm + m.rng.randfn(0.0, 1.2)
	m.s["gov_approval"] = clampf(app, 8.0, 92.0)
	_update_partners()
	m.mact.quarterly()
	m.coal.quarterly()
	_update_polls()
	m.militancy.monthly()
	m.itrust.quarterly()
	m.diplomacy.monthly()
	m.enc.daily()
	m.expire_news()
	m.media.monthly()
	m.ai.tick("government")
	if m.rng.randf() < 0.65:
		_random_event()
	else:
		m.publish("Balance trimestral del Ejecutivo", "Trimestre %d de %d. Apoyo al Gobierno: %.0f/100. Estabilidad de la mayoría: %.0f/100." % [m.turn(), Rules.LEGISLATURE_TURNS, approval(), stability()], "GOBIERNO", "neutral")
	m.campaign.record_snapshot("T%d" % m.turn())
	var result := {"ok": true}
	if stability() <= 0.0:
		# Ya no hay elecciones automáticas: la pérdida de mayoría abre una crisis que el presidente debe resolver.
		var zero := m.coal.on_stability_zero()
		if zero.has("elections"):
			call_elections(str(zero.get("reason", "El Gobierno pierde su mayoría y se convocan elecciones anticipadas.")))
			result["elections"] = true
	elif m.gov_month > Rules.LEGISLATURE_MONTHS:
		call_elections("Se agota la legislatura y se convocan elecciones generales.")
		result["elections"] = true
	if not result.has("elections"):
		m.congress.open_session()
	m.save_now()
	return result

func _update_partners() -> void:
	var sat := m.d("partner_satisfaction")
	for id in partners():
		var pid := str(id)
		var v := float(sat.get(pid, 60.0)) - 1.0 * float(Rules.TURN_MONTHS) + m.rng.randfn(0.0, 2.5)
		sat[pid] = clampf(v, 0.0, 100.0)
	for c in m.a("commitments"):
		var com: Dictionary = c
		if bool(com.get("fulfilled", false)):
			continue
		if str(com.get("measure", "")) != "" and _measure_done(com):
			com["fulfilled"] = true
			var pidm := str(com["party"])
			sat[pidm] = clampf(float(sat.get(pidm, 60.0)) + 14.0, 0.0, 100.0)
			m.ai.change_relation(pidm, 5.0)
			m.publish("Cumples un compromiso con %s" % m.party_short(pidm), "Se materializa: %s." % str(com["text"]), "GOBIERNO", "positive")
			continue
		if m.gov_month > int(com.get("due", 8)):
			var pid2 := str(com["party"])
			sat[pid2] = clampf(float(sat.get(pid2, 60.0)) - 3.0, 0.0, 100.0)
			if not bool(com.get("overdue_flagged", false)):
				com["overdue_flagged"] = true
				m.publish("%s reclama el cumplimiento del pacto" % m.party_short(pid2), "El grupo recuerda que sigue pendiente: %s." % str(com["text"]), "NEGOCIACIONES", "warning")
		elif str(com.get("measure", "")) == "" and not player_in_government() and m.is_player(str(com["party"])) and m.rng.randf() < 0.12:
			com["fulfilled"] = true
			m.ai.change_relation(candidate_id(), 4.0)
			m.publish("El Gobierno cumple un compromiso con tu partido", "Se materializa: %s." % str(com["text"]), "GOBIERNO", "positive")
	m.s["stability"] = clampf(stability() + ((average_satisfaction() - 50.0) / 20.0 - 0.3) * float(Rules.TURN_MONTHS) + m.rng.randfn(0.0, 1.7), 0.0, 100.0)

func _update_polls() -> void:
	if m.voters.ready_state():
		m.voters.monthly()
		return
	var gov_ids := government_parties()
	var shift := (approval() - 50.0) * 0.012
	for id in gov_ids:
		var share := float(m.seats_of(str(id))) / float(maxi(1, m.seats_of(str(gov_ids[0])) + 1))
		m.campaign.adjust_poll(str(id), shift * clampf(share, 0.3, 1.0) + m.rng.randfn(0.0, 0.05))
	# Parte del desgaste o mérito del Gobierno se traslada a la oposición con ruido propio.
	for p in m.rivals:
		var rid := str((p as Dictionary).get("id", ""))
		if not gov_ids.has(rid):
			m.campaign.adjust_poll(rid, m.rng.randfn(0.0, 0.04))
	if not gov_ids.has(m.pid()):
		m.campaign.adjust_poll(m.pid(), m.rng.randfn(0.0, 0.04))

# ---- iniciativas del jugador en la legislatura
func bill_votes(bill: Dictionary) -> Dictionary:
	var gov_id := str(m.s.get("government_party_id", ""))
	var support: Array = [gov_id]
	for id in partners():
		support.append(str(id))
	var yes := 0
	var no := 0
	for id in parliamentary_ids():
		var pid := str(id)
		var seats := m.seats_of(pid)
		var vote_yes := support.has(pid)
		if not vote_yes:
			var issues: Array = m.ai.profile_of(pid).get("issues", [])
			if m.is_player(pid):
				vote_yes = false
			elif m.diplomacy.bill_ally(pid):
				vote_yes = true
			elif issues.has(str(bill["issue"])) and m.ai.relation(pid) >= 40.0:
				vote_yes = true
			elif m.ai.affinity(pid, gov_id) >= 0.55:
				vote_yes = true
		if vote_yes:
			yes += seats
		else:
			no += seats
	return {"yes": yes, "no": no}

func propose_bill(bill_id: String) -> Dictionary:
	if not player_in_government():
		return {"ok": false, "error": "Solo el Gobierno y sus socios pueden impulsar iniciativas."}
	if bills_left() <= 0:
		return {"ok": false, "error": "No quedan iniciativas legislativas este trimestre."}
	var bill: Dictionary = {}
	for b in Rules.BILLS:
		if str((b as Dictionary)["id"]) == bill_id:
			bill = b
	if bill.is_empty() or m.a("passed_bills").has(bill_id):
		return {"ok": false, "error": "Esa iniciativa ya está aprobada."}
	var votes := bill_votes(bill)
	var passed := int(votes["yes"]) > int(votes["no"])
	m.s["bills_left"] = bills_left() - 1
	for id in parliamentary_ids():
		if m.diplomacy.bill_ally(str(id)):
			m.diplomacy.consume_bill(str(id))
	var issue := str(bill["issue"])
	var weight := 0.5 + float(m.campaign.salience().get(issue, 0.1)) * 4.0
	var delta := float(bill["impact"]) * weight * 0.8
	if passed:
		m.a("passed_bills").append(bill_id)
		m.s["gov_approval"] = clampf(approval() + delta, 5.0, 95.0)
		m.trust = m.trust + 1.0
		for c in m.a("commitments"):
			var com: Dictionary = c
			if str(com["issue"]) == issue and not bool(com.get("fulfilled", false)) and str(com.get("measure", "")) == "":
				com["fulfilled"] = true
				var pid := str(com["party"])
				m.d("partner_satisfaction")[pid] = clampf(float(m.d("partner_satisfaction").get(pid, 60.0)) + 14.0, 0.0, 100.0)
				m.ai.change_relation(pid, 5.0)
		m.publish("El Congreso aprueba: %s" % str(bill["name"]), "La iniciativa sale adelante con %d votos a favor y %d en contra." % [votes["yes"], votes["no"]], "PARLAMENTO", "positive")
	else:
		m.s["gov_approval"] = clampf(approval() - delta * 0.5, 5.0, 95.0)
		m.trust = m.trust - 1.0
		m.publish("El Congreso rechaza: %s" % str(bill["name"]), "La iniciativa decae con %d votos a favor y %d en contra." % [votes["yes"], votes["no"]], "PARLAMENTO", "warning")
	m.save_now()
	return {"ok": true, "passed": passed, "yes": votes["yes"], "no": votes["no"], "delta": delta}

func opposition_action(kind: String, target: String = "") -> Dictionary:
	if m.role() != "opposition":
		return {"ok": false, "error": "Solo la oposición puede usar estas herramientas."}
	if bills_left() <= 0:
		return {"ok": false, "error": "No quedan iniciativas parlamentarias este trimestre."}
	m.s["bills_left"] = bills_left() - 1
	var text := ""
	match kind:
		"question":
			m.visibility = m.visibility + 1.2
			m.s["gov_approval"] = clampf(approval() - 0.8, 5.0, 95.0)
			m.publish("Tu grupo interpela al Gobierno", "La pregunta parlamentaria obtiene eco en los medios y aumenta la presión sobre el Ejecutivo.", "PARLAMENTO", "neutral")
			text = "Pregunta parlamentaria: +visibilidad, −apoyo al Gobierno."
		"proposal":
			var yes := m.seats_of(m.pid())
			var no := 0
			for id in parliamentary_ids():
				var pid := str(id)
				if pid == m.pid():
					continue
				if m.ai.affinity(pid, m.pid()) >= 0.55 and m.ai.relation(pid) >= 45.0:
					yes += m.seats_of(pid)
				else:
					no += m.seats_of(pid)
			var passed := yes > no
			if passed:
				m.campaign.adjust_poll(m.pid(), 0.2)
				m.visibility = m.visibility + 1.5
			else:
				m.visibility = m.visibility + 0.5
			m.publish("Tu grupo registra una proposición de ley", "La iniciativa %s con %d votos a favor y %d en contra." % ["sale adelante" if passed else "no prospera", yes, no], "PARLAMENTO", "positive" if passed else "neutral")
			text = "Proposición %s (%d–%d)." % ["aprobada" if passed else "rechazada", yes, no]
		"pact":
			if target == "":
				m.s["bills_left"] = bills_left() + 1
				return {"ok": false, "error": "Elige un grupo."}
			m.ai.change_relation(target, 8.0)
			m.publish("Reunión con %s" % m.party_short(target), "Tu grupo y %s acuerdan coordinar posiciones en la Cámara." % m.party_short(target), "PARLAMENTO", "positive")
			text = "Relación con %s mejorada." % m.party_short(target)
	m.save_now()
	return {"ok": true, "text": text}

# ---------------------------------------------------------------- nuevas elecciones
func call_elections(reason: String) -> void:
	m.publish("Se convocan elecciones generales", reason, "PARLAMENTO", "warning")
	start_new_cycle("legislature")

func start_new_cycle(_origin: String) -> void:
	m.manifesto.close_term()
	m.voters.on_new_cycle()
	var polls := m.polls()
	# Las nuevas encuestas mezclan el último resultado con la opinión actual (el motor de votantes ya lo ha hecho).
	var vt := m.d("election_vote_totals")
	var total := 0.0
	for v in vt.values():
		total += float(v)
	if total > 0.0 and not m.voters.ready_state():
		for id in polls.keys():
			var result_share := float(vt.get(str(id), 0)) / total * 100.0
			polls[id] = 0.5 * result_share + 0.5 * float(polls[id])
	if m.s.has("government_party_id") and m.phase == "legislature" and not m.voters.ready_state():
		var shift := (approval() - 50.0) * 0.1
		for id in government_parties():
			polls[str(id)] = maxf(0.05, float(polls.get(str(id), 1.0)) + shift)
	var sum := 0.0
	for k in polls.keys():
		polls[k] = maxf(0.05, float(polls[k]))
		sum += float(polls[k])
	for k in polls.keys():
		polls[k] = float(polls[k]) / sum * 100.0
	m.s["poll_anchor"] = polls.duplicate()
	for key in ["election_votes", "election_alloc", "election_order", "election_totals", "election_vote_totals",
			"negotiation_offers", "commitments", "passed_bills", "partner_satisfaction", "cabinet", "coalition_partners",
			"recent_events", "province_bonus", "campaign_events",
			"election_tick", "election_curve", "election_announced", "election_leaders", "election_flags", "election_cuts",
			"coal", "table_proposals", "mact", "cab", "election_revealed", "election_scrut", "election_baseline", "election_shares", "election_turnout", "meeting", "meet_log", "cabinet_claims", "pleno", "law_queue", "law_drafts"]:
		m.s.erase(key)
	for key in ["government_party_id", "government_candidate_id", "gov_approval", "stability", "economy", "bills_left",
			"negotiation_candidate_id", "player_vote", "election_index", "election_seed", "investiture_attempts", "negotiation_round"]:
		m.s.erase(key)
	m.s["election_complete"] = false
	m.s["election_started"] = false
	m.s["cycle"] = m.cycle + 1
	m.phase = "campaign"
	m.s["campaign_start_unix"] = m.clock_unix() + 7 * 86400
	m.day = 1
	m.set_clock_to_campaign_day()
	m.gov_month = 1
	m.momentum = 0.0
	m.visibility = 25.0
	m.s["adviser_last_day"] = -10
	m.campaign.ensure_state()
	m.campaign.reseed_history()
	m.s["objective"] = {"target_seats": maxi(1, int(m.election.project_seats().get(m.pid(), 1))), "evaluated": false}
	m.publish("Arranca una nueva campaña electoral",
		"Se abre la campaña de las elecciones número %d. El resultado anterior y la gestión de la legislatura marcan el punto de partida." % m.cycle,
		"ELECCIONES", "neutral")
	m.save_now()
