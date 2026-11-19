class_name Congress
extends RefCounted
## Pleno (trimestral) del Congreso: todas las iniciativas (del Gobierno, de los grupos y las tuyas) se votan una a una.
## El jugador vota a favor, en contra o se abstiene; la IA vota según la ideología de la ley y de cada partido.

var m: GameModel
var amend: Amendments

const MAX_LAWS := 6
const CONTROL_PER_TURN := 2  ## acciones de control (PNL e interpelaciones) por turno
const FOLLOW_REL := 58.0       ## relación mínima con el jugador para que un grupo dudoso siga su voto
const FOLLOW_BAND := 0.09      ## margen bajo el umbral en el que un grupo puede dejarse arrastrar

func _init(model: GameModel) -> void:
	m = model
	amend = Amendments.new(model)

# ---------------------------------------------------------------- acciones de control (PNL e interpelaciones)
func control_left() -> int:
	if int(m.s.get("control_month", -1)) != m.gov_month:
		m.s["control_month"] = m.gov_month
		m.s["control_left"] = CONTROL_PER_TURN
	return int(m.s.get("control_left", CONTROL_PER_TURN))

func use_control() -> void:
	m.s["control_left"] = maxi(0, control_left() - 1)

func refund_control() -> void:
	m.s["control_left"] = mini(CONTROL_PER_TURN, control_left() + 1)

# ---------------------------------------------------------------- descripción breve de una iniciativa
func describe(law: Dictionary) -> String:
	var area := Policies.area(str(law.get("area", "")))
	var aname := str(area.get("name", "")).to_lower()
	var kind := str(law.get("kind", ""))
	if kind == "interpelacion":
		return "Interpela al Gobierno sobre %s: exige explicaciones y compromisos concretos. No se vota; se mide el efecto del debate." % aname
	if kind == "presupuestos":
		return "Los Presupuestos Generales fijan el gasto y los ingresos del año. Si caen, se prorrogan los anteriores."
	var lines: Array = m.laws.change_lines(law)
	var n := lines.size()
	var head := ""
	if n > 0:
		var first: Dictionary = lines[0]
		head = " Destaca «%s»." % str(first["name"])
	var what := "Reforma %s" % aname
	if kind == "pnl":
		return "Declaración no vinculante que insta al Gobierno a actuar en %s: %d medida%s.%s" % [aname, n, "" if n == 1 else "s", head]
	return "%s con %d medida%s.%s" % [what, n, "" if n == 1 else "s", head]

func session() -> Dictionary:
	return m.d("pleno")

func stage() -> String:
	return str(session().get("stage", "done"))

func laws() -> Array:
	return session().get("laws", [])

func results() -> Array:
	return session().get("results", [])

func index() -> int:
	return int(session().get("idx", 0))

func pending() -> bool:
	return m.phase == "legislature" and stage() != "done"

func remaining() -> int:
	return maxi(0, laws().size() - index())

func current() -> Dictionary:
	var list := laws()
	var i := index()
	return list[i] if i >= 0 and i < list.size() else {}

# ---------------------------------------------------------------- apertura de la sesión
func open_session() -> void:
	var ses := session()
	ses.clear()
	var list: Array = []
	for l in m.laws.queue():
		list.append(l)
	m.laws.queue().clear()
	var gov_id := str(m.s.get("government_party_id", ""))
	var coalition: Array = m.laws._coalition()
	var ids := m.gov.parliamentary_ids()
	# Proyecto del Gobierno (solo si lo lidera la IA).
	if gov_id != "" and not m.is_player(gov_id) and m.rng.randf() < 0.85:
		var gl := m.laws.generate_ai_law(gov_id)
		if not gl.is_empty():
			list.append(gl)
	# Proposiciones de los grupos
	var tries: Array = []
	for id in ids:
		var pid := str(id)
		if m.is_player(pid) or pid == gov_id:
			continue
		var share := float(m.seats_of(pid)) / 350.0
		if m.rng.randf() < 0.12 + share * 1.3:
			tries.append(pid)
	for pid in tries:
		if list.size() >= MAX_LAWS:
			break
		var law := m.laws.generate_ai_law(str(pid))
		if not law.is_empty():
			list.append(law)
	ses["month"] = m.gov_month
	ses["laws"] = list
	ses["idx"] = 0
	ses["results"] = []
	ses["stage"] = "ready" if not list.is_empty() else "done"
	if not list.is_empty():
		m.publish("Orden del día del Pleno", "El Congreso debatirá %d iniciativa%s este trimestre." % [list.size(), "" if list.size() == 1 else "s"], "PARLAMENTO", "neutral")

func begin() -> void:
	if stage() == "ready":
		session()["stage"] = "running"

# ---------------------------------------------------------------- votación
## Votos de todos los grupos para una ley. El jugador aporta `player_vote`.
func tally(law: Dictionary, player_vote: String) -> Dictionary:
	var yes := 0
	var no := 0
	var abst := 0
	var by_party: Dictionary = {}
	var followers: Array = []
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		var vote := player_vote
		if not m.is_player(pid):
			var st: Dictionary = m.laws.stance(law, pid)
			vote = str(st["vote"])
			# Voto de arrastre: un grupo dudoso y bien avenido contigo se deja llevar por lo que votas tú.
			if not (law.get("committed", {}) as Dictionary).has(pid) and m.ai.relation(pid) >= FOLLOW_REL and m.seats_of(m.pid()) > 0:
				var sc := float(st["score"])
				if player_vote == "yes" and vote == "abstain" and sc >= LawMaker.YES_AT - FOLLOW_BAND:
					vote = "yes"
					followers.append(pid)
				elif player_vote == "no" and vote == "abstain" and sc <= LawMaker.NO_AT + FOLLOW_BAND:
					vote = "no"
					followers.append(pid)
		by_party[pid] = vote
		var seats := m.seats_of(pid)
		match vote:
			"yes": yes += seats
			"no": no += seats
			_: abst += seats
	return {"yes": yes, "no": no, "abstain": abst, "by_party": by_party, "followers": followers}

func player_votes_this(law: Dictionary) -> bool:
	return m.seats_of(m.pid()) > 0 and str(law.get("proposer", "")) != m.pid()

## Cierra la votación de la ley actual y aplica sus efectos si sale adelante.
func resolve_current(player_vote: String) -> Dictionary:
	var law := current()
	if law.is_empty():
		return {}
	if str(law.get("proposer", "")) == m.pid():
		player_vote = "yes"
	if str(law.get("kind", "")) == "interpelacion":
		return _resolve_interpelacion(law)
	var t := tally(law, player_vote)
	var passed := m.laws.passes(law, int(t["yes"]), int(t["no"]))
	var res := {"law": law, "yes": t["yes"], "no": t["no"], "abstain": t["abstain"], "by_party": t["by_party"], "passed": passed,
		"player_vote": player_vote, "organic": m.laws.is_organic(law), "followers": t.get("followers", [])}
	var reasons: Dictionary = {}
	for pid0 in (t["by_party"] as Dictionary).keys():
		reasons[str(pid0)] = amend.vote_line(law, str(pid0), str((t["by_party"] as Dictionary)[pid0]))
	res["reasons"] = reasons
	if str(law.get("kind", "")) == "pnl":
		return _finish_pnl(law, res, player_vote)
	var is_budget := str(law.get("kind", "")) == "presupuestos"
	if is_budget:
		law["lines_cache"] = m.exec.budget_lines_changed(law)
	if passed:
		if is_budget:
			res["preview"] = {"revenue": 0.0, "spending": m.exec.draft_delta_of(law), "balance": -m.exec.draft_delta_of(law), "by_area": {}, "fx": {}, "groups": {}}
			m.exec.apply_pge(law)
		else:
			res["preview"] = m.eco.preview(law["changes"], law.get("irpf", []))
			m.eco.apply_law(law)
		_after_passed(law, res)
	else:
		if is_budget:
			m.exec.reject_pge(law)
		_after_rejected(law, res)
	# Pactos por la ley: los socios que se comprometieron cumplen y el jugador salda sus favores.
	var pact_log: Array = []
	var committed: Dictionary = law.get("committed", {})
	for cid in committed.keys():
		var kept := str((t["by_party"] as Dictionary).get(str(cid), "")) == str(committed[cid])
		if kept:
			m.ai.change_relation(str(cid), 3.0)
			pact_log.append("%s cumple su palabra" % m.party_short(str(cid)))
			for pc in m.diplomacy.active_pacts(str(cid)):
				if str((pc as Dictionary)["kind"]) == "law_deal":
					(pc as Dictionary)["status"] = "kept"
	if str(law.get("proposer", "")) != m.pid() and m.seats_of(m.pid()) > 0:
		var fav := m.diplomacy.settle_favor(str(law.get("proposer", "")), player_vote)
		if fav != "":
			pact_log.append(fav)
	if not pact_log.is_empty():
		res["pact_log"] = pact_log
	# Coherencia del jugador con lo que recomendaba su ideología
	if player_votes_this(law):
		var rec := m.laws.recommended_vote(law)
		m.trust = m.trust + (0.25 if rec == player_vote else -0.4)
		res["recommended"] = rec
	results().append(res)
	session()["idx"] = index() + 1
	if index() >= laws().size():
		session()["stage"] = "done"
		m.publish("Se levanta la sesión plenaria", "El Pleno ha votado todas las iniciativas del orden del día.", "PARLAMENTO", "neutral")
	m.save_now()
	return res

## Una proposición no de ley no cambia medidas: da visibilidad y retrata a quien vota en contra.
func _finish_pnl(law: Dictionary, res: Dictionary, player_vote: String) -> Dictionary:
	var passed := bool(res["passed"])
	var proposer := str(law.get("proposer", ""))
	var mine := m.is_player(proposer)
	law["status"] = "passed" if passed else "rejected"
	var by_party: Dictionary = res["by_party"]
	var against: Array = []
	for pid in by_party.keys():
		if str(pid) != proposer and str(by_party[pid]) == "no":
			against.append(str(pid))
	if passed:
		m.publish("El Congreso aprueba: %s" % str(law["title"]), "Sale adelante con %d votos a favor, %d en contra y %d abstenciones. Es una declaración no vinculante." % [res["yes"], res["no"], res["abstain"]], "PARLAMENTO", "positive")
		if mine:
			m.trust = m.trust + 0.8
			m.visibility = m.visibility + 1.0
			for pid2 in by_party.keys():
				if not m.is_player(str(pid2)):
					m.ai.change_relation(str(pid2), 0.8 if str(by_party[pid2]) == "yes" else 0.0)
	else:
		m.publish("El Congreso rechaza: %s" % str(law["title"]), "No obtiene apoyos: %d a favor, %d en contra y %d abstenciones." % [res["yes"], res["no"], res["abstain"]], "PARLAMENTO", "warning")
		if mine:
			m.trust = m.trust - 0.3
	# Retrato: si el Gobierno vota en contra de algo popular, sufre.
	var gov_id := str(m.s.get("government_party_id", ""))
	if mine and gov_id != "" and not m.is_player(gov_id) and against.has(gov_id) and (res["law"] as Dictionary).has("changes"):
		var pv := m.eco.preview(law["changes"], law.get("irpf", []))
		var tot := 0.0
		for g in (pv.get("groups", {}) as Dictionary).values():
			tot += float(g)
		if tot > 0.0:
			m.s["gov_approval"] = clampf(m.gov.approval() - 0.8, 8.0, 92.0)
			m.visibility = m.visibility + 0.8
			res["wedge"] = "El Gobierno vota en contra de algo que los votantes quieren: su apoyo cae."
	if not against.is_empty() and mine:
		var names: Array = []
		for a in against:
			names.append(m.party_short(str(a)))
		res["against_names"] = names
	_close_result(law, res, player_vote)
	return res

## Interpelación: sin votación; se mide si el golpe de efecto cuaja según el tema, el estado del Gobierno y el tono.
func _resolve_interpelacion(law: Dictionary) -> Dictionary:
	var issue := str(Policies.area(str(law["area"])).get("issue", ""))
	var sal := float(m.campaign.salience().get(issue, 0.12))
	var style := str(law.get("style", "tecnico"))
	var base := 0.46 + (50.0 - m.gov.approval()) / 120.0 + (sal - 0.12) * 1.2
	var spread := 0.1
	match style:
		"duro":
			base += 0.05
			spread = 0.32
		"propositivo":
			base -= 0.04
			spread = 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("interp_%s_%d_%d" % [str(law["id"]), m.cycle, m.gov_month])
	var roll := base + rng.randf_range(-spread, spread)
	var tier := "flop"
	if roll >= 0.68:
		tier = "big"
	elif roll >= 0.5:
		tier = "ok"
	elif roll <= 0.3 and style == "duro":
		tier = "backfire"
	var gov_id := str(m.s.get("government_party_id", ""))
	var lines: Array = []
	match tier:
		"big":
			m.visibility = m.visibility + (2.6 if style == "duro" else 1.8)
			m.trust = m.trust + 0.6
			lines.append("Golpe de efecto: la intervención abre los telediarios.")
		"ok":
			m.visibility = m.visibility + 1.2
			m.trust = m.trust + 0.4
			lines.append("El debate cuaja: el Gobierno tiene que dar explicaciones.")
		"backfire":
			m.visibility = m.visibility - 0.5
			m.trust = m.trust - 1.2
			lines.append("El tiro sale por la culata: el Gobierno te replica con datos.")
		_:
			m.trust = m.trust - 0.4
			lines.append("La intervención pasa sin pena ni gloria.")
	if tier in ["big", "ok"] and gov_id != "" and not m.is_player(gov_id):
		var hit := 1.4 if tier == "big" else 0.8
		m.s["gov_approval"] = clampf(m.gov.approval() - hit, 8.0, 92.0)
		lines.append("El apoyo al Gobierno cae %.1f puntos." % hit)
	if style == "propositivo" and tier != "backfire" and gov_id != "" and not m.is_player(gov_id):
		m.trust = m.trust + 0.4
		m.ai.change_relation(gov_id, 2.0)
		lines.append("Tu tono constructivo mejora la relación con el Gobierno.")
	law["status"] = "passed" if tier in ["big", "ok"] else "rejected"
	m.publish("Interpelación: %s" % str(law["title"]), " ".join(lines), "PARLAMENTO", "positive" if tier in ["big", "ok"] else "warning")
	var res := {"law": law, "kind": "interpelacion", "yes": 0, "no": 0, "abstain": 0, "by_party": {}, "passed": tier in ["big", "ok"],
		"player_vote": "", "organic": false, "tier": tier, "score": clampf(roll, 0.0, 1.0), "lines": lines, "style": style}
	_close_result(law, res, "")
	return res

func _close_result(_law: Dictionary, res: Dictionary, _player_vote: String) -> void:
	results().append(res)
	session()["idx"] = index() + 1
	if index() >= laws().size():
		session()["stage"] = "done"
		m.publish("Se levanta la sesión plenaria", "El Pleno ha votado todas las iniciativas del orden del día.", "PARLAMENTO", "neutral")
	m.save_now()

## Retira una iniciativa propia antes de votarla: vuelve a borradores y recupera su cupo.
func withdraw_current() -> bool:
	var law := current()
	if law.is_empty() or not m.is_player(str(law.get("proposer", ""))):
		return false
	m.laws._restore_quota(law)
	law["status"] = "draft"
	law.erase("amend")
	law.erase("committed")
	if str(law.get("kind", "")) in ["proyecto", "proposición"]:
		law["kind"] = "proposición"
	m.laws.drafts().append(law)
	m.publish("Retiras: %s" % str(law["title"]), "Retiras la iniciativa antes de la votación. Vuelve a tus borradores para reelaborarla.", "PARLAMENTO", "neutral")
	var res := {"law": law, "yes": 0, "no": 0, "abstain": 0, "by_party": {}, "passed": false, "withdrawn": true, "player_vote": "", "organic": false}
	_close_result(law, res, "")
	return true

## Abre el trámite de enmiendas de la iniciativa actual.
func open_debate() -> void:
	var law := current()
	if not law.is_empty():
		amend.open(law)
		m.save_now()

## Previsión con el texto actual (tú votas lo que te recomienda tu ideología).
func forecast_now() -> Dictionary:
	var law := current()
	return m.laws.forecast(law) if not law.is_empty() and m.laws.has_votes(law) else {}

func _after_passed(law: Dictionary, res: Dictionary) -> void:
	law["status"] = "passed"
	m.manifesto.on_bill(law, "passed")
	m.voters.on_law(law, res)
	m.militancy.on_law(law, res)
	var proposer := str(law.get("proposer", ""))
	var area := Policies.area(str(law.get("area", "")))
	var issue := str(area.get("issue", ""))
	m.publish("El Congreso aprueba: %s" % str(law["title"]),
		"Sale adelante con %d votos a favor, %d en contra y %d abstenciones. Presentada por %s." % [res["yes"], res["no"], res["abstain"], m.party_short(proposer)], "PARLAMENTO", "positive")
	if m.is_player(proposer):
		m.trust = m.trust + 1.5
		m.visibility = m.visibility + 1.2
		match str(law.get("tone", "estandar")):
			"bandera":
				m.visibility = m.visibility + 1.5
			"consenso":
				m.trust = m.trust + 0.5
	# Los pactos de investidura se dan por cumplidos si la ley toca su materia.
	for c in m.a("commitments"):
		var com: Dictionary = c
		if str(com.get("issue", "")) == issue and not bool(com.get("fulfilled", false)) and str(com.get("measure", "")) == "" and m.laws._coalition().has(proposer):
			com["fulfilled"] = true
			var pid := str(com["party"])
			m.d("partner_satisfaction")[pid] = clampf(float(m.d("partner_satisfaction").get(pid, 60.0)) + 14.0, 0.0, 100.0)
			m.ai.change_relation(pid, 5.0)
	# Quien vota que sí a una iniciativa del jugador mejora su relación con él.
	if m.is_player(proposer):
		for pid2 in (res["by_party"] as Dictionary).keys():
			if not m.is_player(str(pid2)):
				m.ai.change_relation(str(pid2), 1.0 if str(res["by_party"][pid2]) == "yes" else (-0.5 if str(res["by_party"][pid2]) == "no" else 0.0))

func _after_rejected(law: Dictionary, res: Dictionary) -> void:
	law["status"] = "rejected"
	m.manifesto.on_bill(law, "rejected")
	var proposer := str(law.get("proposer", ""))
	m.publish("El Congreso rechaza: %s" % str(law["title"]),
		"No obtiene apoyos suficientes: %d a favor, %d en contra y %d abstenciones." % [res["yes"], res["no"], res["abstain"]], "PARLAMENTO", "warning")
	if m.is_player(proposer):
		m.trust = m.trust - 0.8

## Resuelve lo que quede de la sesión votando por el jugador según la recomendación de su ideología.
func auto_finish() -> void:
	if stage() == "ready":
		begin()
	var guard := 0
	while stage() == "running" and guard < 20:
		guard += 1
		var law := current()
		if law.is_empty():
			break
		resolve_current(m.laws.recommended_vote(law))
	if stage() != "done":
		session()["stage"] = "done"

func last_results() -> Array:
	return results()
