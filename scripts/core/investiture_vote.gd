class_name InvestitureVote
extends RefCounted
## Votación de investidura diputado a diputado (spec negociación §10).
##
## El grupo parlamentario anuncia un sentido de voto (GovernmentSim.estimate_votes) y cada uno de sus diputados
## lo sigue o rompe la disciplina según un modelo reproducible: tensiones internas, distancia ideológica con el
## candidato, presión territorial, crisis de liderazgo y pactos incumplidos, modulados por la lealtad del partido.
## La semilla sale del estado de la negociación, de modo que la misma situación produce siempre los mismos votos
## (recargar la partida no permite repetir la tirada).
##
## El recuento oficial (hold_vote) y la animación del hemiciclo leen EXACTAMENTE la misma cadena de votos.
## Persistencia: m.s["ivote_last"] (última votación) y m.s["ivote_history"] (resumen de todas).

var m: GameModel

const MAX_DISSENT := 0.30
## Los partidos españoles votan casi siempre en bloque: la presión bruta se atenúa para que las disidencias sean la excepción.
const DISSENT_SCALE := 0.5
const MAX_HISTORY := 12
const VOTE_NAMES := {"y": "A favor", "n": "En contra", "a": "Abstención"}

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- consultas
func last() -> Dictionary:
	var v: Variant = m.s.get("ivote_last", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}

func history() -> Array:
	return m.a("ivote_history")

## ¿La última votación guardada es de este ciclo y de este candidato/ronda en curso o ya celebrada?
func last_of_cycle() -> Dictionary:
	var l := last()
	if l.is_empty() or int(l.get("cycle", -1)) != m.cycle:
		return {}
	return l

func stance_char(vote: String) -> String:
	match vote:
		"yes": return "y"
		"no": return "n"
		_: return "a"

## Orden de los grupos en el hemiciclo: de izquierda a derecha por eje económico.
func hall_order() -> Array:
	var ids: Array = m.gov.parliamentary_ids()
	ids.sort_custom(func(x: String, y: String) -> bool:
		var ix: Dictionary = m.party_by_id(x).get("ideology", {})
		var iy: Dictionary = m.party_by_id(y).get("ideology", {})
		var ex := float(ix.get("economic", 0.0))
		var ey := float(iy.get("economic", 0.0))
		if ex != ey:
			return ex < ey
		return x < y)
	return ids

func _axis(id: String, key: String) -> float:
	return float((m.party_by_id(id).get("ideology", {}) as Dictionary).get(key, 0.0))

# ---------------------------------------------------------------- modelo de disciplina
## Factores de presión que empujan a los diputados de `pid` a romper la disciplina: [{id, label, value}].
func factors(pid: String, cand: String, stance: String) -> Array:
	var out: Array = []
	var cohesion := m.brain.trait_of(pid, "cohesion", 0.6)
	out.append({"id": "conflict", "label": "Tensiones internas", "value": (1.0 - cohesion) * 0.09})
	var compat := m.brain.compat(pid, cand)
	if pid == cand:
		# La bancada del candidato sufre por los pactos que cierra con partidos lejanos.
		var worst := 0.0
		var who := ""
		for id in m.gov.partners():
			var d := maxf(0.0, 0.45 - m.brain.compat(pid, str(id))) * 0.22
			if d > worst:
				worst = d
				who = str(id)
		if worst > 0.0:
			out.append({"id": "ideology", "label": "Malestar por el pacto con %s" % m.party_short(who), "value": worst})
	elif stance == "y":
		out.append({"id": "ideology", "label": "Distancia ideológica con el candidato", "value": maxf(0.0, 0.5 - compat) * 0.30})
		var dt := absf(_axis(pid, "territorial") - _axis(cand, "territorial")) / 2.0
		out.append({"id": "territory", "label": "Presión territorial", "value": dt * 0.10 * (0.5 + m.brain.trait_of(pid, "territorial", 0.2))})
	elif stance == "n":
		out.append({"id": "ideology", "label": "Afinidad con el candidato", "value": maxf(0.0, compat - 0.55) * 0.28})
	var seat_pct := float(m.seats_of(pid)) / 3.5
	var drop := maxf(0.0, seat_pct - m.poll_of(pid))
	out.append({"id": "leadership", "label": "Crisis de liderazgo", "value": clampf(drop / 12.0, 0.0, 1.0) * 0.06})
	out.append({"id": "pact", "label": "Pactos incumplidos", "value": m.brain.grievance(pid, cand) * 0.30})
	return out

## Probabilidad de que un diputado de `pid` rompa la orden de grupo.
func dissent_rate(pid: String, cand: String, stance: String) -> float:
	var raw := 0.0
	for f in factors(pid, cand, stance):
		raw += float((f as Dictionary)["value"])
	var whip := 1.15 - 0.6 * m.brain.trait_of(pid, "loyalty", 0.6)
	return clampf(raw * whip * DISSENT_SCALE, 0.0, MAX_DISSENT)

## Disciplina 0..100 (100 = sin disidencias esperables).
func discipline_of(pid: String, cand: String, stance: String) -> float:
	return (1.0 - dissent_rate(pid, cand, stance)) * 100.0

## Estimación previa para la pantalla: disidencias esperadas y rango razonable sobre el voto a favor.
func outlook(est: Dictionary = {}) -> Dictionary:
	if est.is_empty():
		est = m.gov.estimate_votes()
	var cand := m.gov.candidate_id()
	var detail: Dictionary = est["detail"]
	var exp_yes_loss := 0.0
	var exp_total := 0.0
	var var_sum := 0.0
	var var_yes := 0.0
	var groups: Array = []
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		var stance := stance_char(str(detail.get(pid, "abstain")))
		var rate := dissent_rate(pid, cand, stance)
		var n := m.seats_of(pid)
		var expected := rate * float(n)
		exp_total += expected
		if stance == "y":
			exp_yes_loss += expected
			var_yes += float(n) * rate * (1.0 - rate) * 1.4
		var_sum += float(n) * rate * (1.0 - rate) * 1.4
		groups.append({"id": pid, "stance": stance, "rate": rate, "expected": expected, "discipline": (1.0 - rate) * 100.0})
	var sd := sqrt(var_sum)
	return {"expected_rebels": exp_total, "expected_yes_loss": exp_yes_loss, "sd": sd, "groups": groups,
		"safe_margin": int(ceil(exp_yes_loss + sqrt(var_yes)))}

# ---------------------------------------------------------------- votación
func _sig(cand: String, rnd: int, est: Dictionary) -> String:
	var parts: Array = []
	var detail: Dictionary = est["detail"]
	for id in hall_order():
		parts.append("%s:%d:%s" % [str(id), m.seats_of(str(id)), str(detail.get(str(id), "abstain"))])
	return "%d|%s|%d|%d|%d|%s" % [m.cycle, cand, rnd, m.gov.attempts(), int(m.s.get("leader_seed", 0)), ",".join(parts)]

func _name_pools(pid: String) -> Array:
	match pid:
		"erc", "junts", "alianca":
			return [Leader.CAT_M, Leader.CAT_F, Leader.CAT_S]
		"pnv", "ehbildu":
			return [Leader.EUS_M, Leader.EUS_F, Leader.EUS_S]
		"bng":
			return [Leader.GAL_M, Leader.GAL_F, Leader.GAL_S]
	return [Leader.MALE, Leader.FEMALE, Leader.SURNAME]

func _province_for(pid: String, rng: RandomNumberGenerator) -> String:
	var terr := m.territory_of(pid)
	var pool: Array = []
	for c in m.constituencies:
		var cd: Dictionary = c
		if terr.is_empty() or (terr["communities"] as Array).has(str(cd.get("autonomous_community", ""))):
			pool.append(str(cd.get("name", "")))
	if pool.is_empty():
		return ""
	return str(pool[rng.randi_range(0, pool.size() - 1)])

func _pick_reason(facs: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for f in facs:
		total += float((f as Dictionary)["value"])
	if total <= 0.0:
		return "conflict"
	var r := rng.randf() * total
	for f in facs:
		r -= float((f as Dictionary)["value"])
		if r <= 0.0:
			return str((f as Dictionary)["id"])
	return "conflict"

## Genera (y guarda) los votos de los 350 diputados para la votación que toca ahora.
func cast() -> Dictionary:
	var cand := m.gov.candidate_id()
	var rnd := m.gov.round_number()
	var est := m.gov.estimate_votes()
	var sig := _sig(cand, rnd, est)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sig)
	var detail: Dictionary = est["detail"]
	var votes := ""
	var orders := ""
	var groups: Array = []
	var rebels: Array = []
	var tally := {"yes": 0, "no": 0, "abstain": 0}
	for id in hall_order():
		var pid := str(id)
		var n := m.seats_of(pid)
		var stance := stance_char(str(detail.get(pid, "abstain")))
		var facs := factors(pid, cand, stance)
		var rate := dissent_rate(pid, cand, stance)
		# Clima del grupo: unos días la bancada está más revuelta que otros (provoca bloques de disidentes).
		var mood := rng.randf_range(0.45, 1.7)
		var eff := clampf(rate * mood, 0.0, 0.6)
		var compat := m.brain.compat(pid, cand)
		var pools := _name_pools(pid)
		var g_votes := {"y": 0, "n": 0, "a": 0}
		var g_reb := 0
		for k in range(n):
			var v := stance
			if rng.randf() < eff:
				match stance:
					"y":
						v = "a" if rng.randf() < 0.72 else "n"
					"n":
						v = "y" if (compat > 0.4 and rng.randf() < 0.3) else "a"
					_:
						v = "y" if compat >= 0.5 else "n"
				var gender_f := rng.randf() < 0.45
				var first_pool: Array = pools[1] if gender_f else pools[0]
				var surn_pool: Array = pools[2]
				rebels.append({"party": pid, "seat": votes.length(),
					"name": "%s %s" % [str(first_pool[rng.randi_range(0, first_pool.size() - 1)]), str(surn_pool[rng.randi_range(0, surn_pool.size() - 1)])],
					"province": _province_for(pid, rng), "reason": _pick_reason(facs, rng), "from": stance, "to": v})
				g_reb += 1
			votes += v
			orders += stance
			g_votes[v] = int(g_votes[v]) + 1
		groups.append({"id": pid, "seats": n, "stance": stance, "rate": rate, "discipline": (1.0 - rate) * 100.0,
			"yes": int(g_votes["y"]), "no": int(g_votes["n"]), "abstain": int(g_votes["a"]), "rebels": g_reb,
			"factors": _compact_factors(facs)})
		tally["yes"] += int(g_votes["y"])
		tally["no"] += int(g_votes["n"])
		tally["abstain"] += int(g_votes["a"])
	var session := {"sig": sig, "cycle": m.cycle, "cand": cand, "round": rnd, "attempt": m.gov.attempts(),
		"date": m.date_label(), "votes": votes, "orders": orders, "groups": groups, "rebels": _trim_rebels(rebels, votes, orders),
		"tally": tally, "announced": _announced(est), "held": false, "passed": false}
	return session

func _compact_factors(facs: Array) -> Array:
	var out: Array = []
	for f in facs:
		var fd: Dictionary = f
		if float(fd["value"]) >= 0.004:
			out.append({"id": str(fd["id"]), "label": str(fd["label"]), "value": snappedf(float(fd["value"]), 0.001)})
	return out

func _announced(est: Dictionary) -> Dictionary:
	return {"yes": int(est["yes"]), "no": int(est["no"]), "abstain": int(est["abstain"])}

## Los rebeldes se identifican por su escaño real: se recorren votos y órdenes y se casan con la lista generada.
func _trim_rebels(rebels: Array, votes: String, orders: String) -> Array:
	var out: Array = []
	var by_seat: Dictionary = {}
	for r in rebels:
		by_seat[int((r as Dictionary)["seat"])] = r
	for i in range(votes.length()):
		if votes[i] != orders[i]:
			var r: Dictionary = by_seat.get(i, {"party": "", "name": "Diputado", "province": "", "reason": "conflict", "from": orders[i], "to": votes[i]})
			var item := {"seat": i, "party": str(r.get("party", "")), "name": str(r.get("name", "")), "province": str(r.get("province", "")),
				"reason": str(r.get("reason", "conflict")), "from": str(orders[i]), "to": str(votes[i])}
			out.append(item)
	return out

## Cuenta votos[0..upto) → {yes,no,abstain}. Es la función que usa el marcador animado.
static func count(votes: String, upto: int = -1) -> Dictionary:
	var n := votes.length() if upto < 0 else mini(upto, votes.length())
	var t := {"yes": 0, "no": 0, "abstain": 0}
	for i in range(n):
		match votes[i]:
			"y": t["yes"] += 1
			"n": t["no"] += 1
			_: t["abstain"] += 1
	return t

## Aplica el resultado de la sesión guardada (se llama desde GovernmentSim.hold_vote).
func record(session: Dictionary, passed: bool) -> void:
	session["held"] = true
	session["passed"] = passed
	m.s["ivote_last"] = session
	var h := history()
	h.append({"cycle": m.cycle, "cand": str(session["cand"]), "round": int(session["round"]), "yes": int((session["tally"] as Dictionary)["yes"]),
		"no": int((session["tally"] as Dictionary)["no"]), "abstain": int((session["tally"] as Dictionary)["abstain"]),
		"rebels": (session["rebels"] as Array).size(), "passed": passed, "date": str(session.get("date", ""))})
	while h.size() > MAX_HISTORY:
		h.pop_front()

# ---------------------------------------------------------------- textos
func reason_text(id: String) -> String:
	match id:
		"ideology": return "discrepancia ideológica"
		"territory": return "presión territorial"
		"leadership": return "crisis de liderazgo"
		"pact": return "pactos incumplidos"
		_: return "tensiones internas"

## Grupo que aún no ha decidido su voto (se abstiene por defecto, pero su postura es dudosa).
func is_undecided(pid: String, cand: String, stance: String) -> bool:
	if pid == cand or stance != "a" or m.is_player(pid) or m.gov.partners().has(pid):
		return false
	var offer: Dictionary = m.gov.offers().get(pid, {})
	if str(offer.get("status", "")) == "accepted":
		return false
	var disp := m.brain.disposition(pid, cand)
	return disp >= 24.0 and disp < 45.0

## Declaración del grupo ante la investidura, coherente con la negociación.
func statement(pid: String, cand: String, stance: String) -> String:
	var offer: Dictionary = m.gov.offers().get(pid, {})
	var cname := m.party_short(cand)
	var blocked := m.brain.blocked_by(pid, cand)
	if pid == cand:
		return "Presentamos un programa de Gobierno y pedimos la confianza de la Cámara."
	if m.gov.partners().has(pid):
		var role := "entraremos en el Gobierno" if str(offer.get("role", "external")) == "cabinet" else "apoyaremos desde fuera"
		return "Hay acuerdo con %s: %s y votaremos a favor." % [cname, role]
	if m.is_player(pid):
		match str(m.s.get("player_vote", "")):
			"no": return "Votaremos en contra."
			"yes": return "Votaremos a favor."
			_: return "Nos abstendremos."
	if str(offer.get("status", "")) == "accepted" and stance == "a":
		return "Con lo pactado, nos abstendremos para no bloquear la investidura."
	if stance == "n":
		if blocked != "":
			return "Votaremos en contra: %s." % blocked
		return "No vemos garantías en el programa de %s. Votaremos en contra." % cname
	if stance == "y":
		return "Apoyaremos a %s." % cname
	if is_undecided(pid, cand, stance):
		return "Sin decisión tomada. Esperamos a ver el debate."
	return "No apoyaremos la investidura, pero tampoco la bloquearemos: abstención."
