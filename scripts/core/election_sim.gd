class_name ElectionSim
extends RefCounted
## Genera votos por circunscripción a partir de las encuestas, el territorio y la actividad de campaña,
## y reparte escaños con D'Hondt (ElectionEngine). El mismo cálculo, sin ruido, sirve de proyección.
##
## Noche electoral: el recuento avanza por CORTES (0..CUTS). Cada circunscripción empieza y termina
## en momentos distintos y sus primeros votos están sesgados (voto rural / urbano que llega antes),
## de modo que los escaños provisionales se mueven, hay "vuelcos" y el resultado final solo se
## conoce al 100 %. Todo se deriva de una semilla y se guarda en el estado de la partida.

const CUTS := 90
const MIN_SHOW := 0.03

var m: GameModel
var _snap_tick := -1
var _snap: Dictionary = {}

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- modelo de voto provincial
func _community_lean(community: String, id: String) -> float:
	var lean: Dictionary = Rules.COMMUNITY_LEAN.get(community, {})
	return float(lean.get(id, 1.0))

## Peso electoral bruto de cada candidatura en una circunscripción.
func province_weights(province: Dictionary, noise: float, rng: RandomNumberGenerator, nat_error: Dictionary) -> Dictionary:
	var community := str(province.get("autonomous_community", ""))
	var pname := str(province.get("name", ""))
	var weights: Dictionary = {}
	var bonus: Dictionary = m.d("province_bonus")
	var base_polls := _base_shares()
	for key in base_polls.keys():
		var id := str(key)
		var poll := float(base_polls[key])
		var w := 0.0
		if id == Rules.OTHERS_ID:
			w = poll
		elif m.is_regional(id):
			var terr: Dictionary = m.territory_of(id)
			if community in (terr["communities"] as Array):
				w = poll / float(terr["electorate"])
		else:
			w = poll * _community_lean(community, id)
		if id == m.pid():
			w *= 1.0 + clampf(float(bonus.get(pname, 0.0)), 0.0, 0.35)
		if noise > 0.0 and id != Rules.OTHERS_ID:
			w *= maxf(0.2, rng.randfn(1.0, noise))
			w *= float(nat_error.get(id, 1.0))
		weights[id] = maxf(0.0, w)
	return weights

func _distribute_votes(weights: Dictionary, total_votes: int) -> Dictionary:
	var sum := 0.0
	for w in weights.values():
		sum += float(w)
	var votes: Dictionary = {}
	var allocated := 0
	var largest := ""
	var largest_w := -1.0
	for id in weights.keys():
		var count := int(round(float(total_votes) * float(weights[id]) / maxf(sum, 0.0001)))
		votes[id] = count
		allocated += count
		if float(weights[id]) > largest_w:
			largest_w = float(weights[id])
			largest = str(id)
	if largest != "":
		votes[largest] = int(votes[largest]) + total_votes - allocated
	return votes

func _allocate(votes: Dictionary, seats: int) -> Dictionary:
	var candidacies: Dictionary = {}
	var valid := 0
	for id in votes.keys():
		valid += int(votes[id])
		if str(id) != Rules.OTHERS_ID:
			candidacies[str(id)] = int(votes[id])
	# Los votos a "otros" y en blanco cuentan como válidos pero no obtienen escaños.
	return ElectionEngine.dhondt(candidacies, seats, valid, 0.03)

## Cuotas de voto con las que se reparte: en la noche electoral, el resultado del día (con su último vuelco);
## el resto del tiempo, las encuestas.
func _base_shares() -> Dictionary:
	if m.phase in ["election_night", "results"]:
		var sh: Dictionary = m.d("election_shares")
		if not sh.is_empty():
			return sh
	return m.polls()

## Participación respecto a la media de las últimas elecciones (la abstención se nota en las urnas).
func turnout_factor() -> float:
	var t := 0.0
	if m.phase in ["election_night", "results"] and m.s.has("election_turnout"):
		t = float(m.s["election_turnout"])
	elif m.voters.ready_state():
		t = m.voters.turnout()
	if t <= 0.0:
		return 1.0
	return clampf(t / 0.70, 0.7, 1.25)

func _province_total_votes(province: Dictionary) -> int:
	return int(round(float(int(province.get("seats", 4)) * 18000 + 12000) * turnout_factor()))

# ---------------------------------------------------------------- proyección (sin ruido)
func project_full() -> Dictionary:
	var totals: Dictionary = {}
	var by_province: Dictionary = {}
	var shares: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	for id in m.polls().keys():
		if str(id) != Rules.OTHERS_ID:
			totals[str(id)] = 0
	for c in m.constituencies:
		var province: Dictionary = c
		var votes := _distribute_votes(province_weights(province, 0.0, rng, {}), _province_total_votes(province))
		var alloc := _allocate(votes, int(province.get("seats", 0)))
		by_province[str(province["id"])] = alloc
		for id in alloc.keys():
			totals[id] = int(totals.get(id, 0)) + int(alloc[id])
		var tv := float(_province_total_votes(province))
		var pshare: Dictionary = {}
		for id in votes.keys():
			pshare[id] = float(votes[id]) / tv * 100.0
		shares[str(province["name"])] = pshare
	return {"totals": totals, "by_province": by_province, "shares": shares}

func project_seats() -> Dictionary:
	return project_full()["totals"]

# ---------------------------------------------------------------- noche electoral: preparación
func begin_night() -> void:
	m.phase = "election_night"
	var day := m.voters.election_day()
	m.s["election_shares"] = day.get("shares", {})
	m.s["election_turnout"] = float(day.get("turnout", 0.7))
	m.s["election_seed"] = m.rng.randi()
	m.s["election_index"] = 0
	m.s["election_tick"] = 0
	m.s["election_announced"] = {}
	m.s["election_leaders"] = {}
	m.s["election_flags"] = {}
	m.s["election_cuts"] = []
	m.s["election_revealed"] = []
	m.s["election_scrut"] = 0.0
	_snap_tick = -1
	_generate()
	m.s["election_baseline"] = _compute_baseline()
	var totals := {}
	var vtotals := {}
	for id in m.polls().keys():
		if str(id) != Rules.OTHERS_ID:
			totals[str(id)] = 0
		vtotals[str(id)] = 0
	m.s["election_totals"] = totals
	m.s["election_vote_totals"] = vtotals
	m.s["election_started"] = true
	m.s["election_complete"] = false
	m.save_now()

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.s.get("election_seed", 1))
	var nat_error: Dictionary = {}
	for id in m.polls().keys():
		nat_error[str(id)] = maxf(0.7, rng.randfn(1.0, 0.04))
	var votes_by: Dictionary = {}
	var alloc_by: Dictionary = {}
	var order: Array = []
	for c in m.constituencies:
		var province: Dictionary = c
		var cid := str(province["id"])
		var votes := _distribute_votes(province_weights(province, 0.06, rng, nat_error), _province_total_votes(province))
		votes_by[cid] = votes
		alloc_by[cid] = _allocate(votes, int(province.get("seats", 0)))
		order.append(province)
	# Orden de referencia: pequeñas primero (se conserva por compatibilidad).
	order.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if int(x["seats"]) != int(y["seats"]):
			return int(x["seats"]) < int(y["seats"])
		return str(x["id"]) < str(y["id"]))
	var ids: Array = []
	for p in order:
		ids.append(str((p as Dictionary)["id"]))
	m.s["election_votes"] = votes_by
	m.s["election_alloc"] = alloc_by
	m.s["election_order"] = ids
	# Curva de recuento de cada circunscripción: terminan repartidas a lo largo de toda la noche
	# y las grandes tardan más; la última cierra exactamente en el último corte.
	var curve: Dictionary = {}
	var last_id := ""
	var last_end := -1.0
	for p in order:
		var pd: Dictionary = p
		var cid2 := str(pd["id"])
		var big := clampf(float(int(pd["seats"])) / 14.0, 0.0, 1.0)
		var dur := (0.24 + rng.randf() * 0.22 + 0.16 * big) * float(CUTS)
		var end_t := rng.randf_range(0.30, 0.90) * float(CUTS)
		dur = minf(dur, end_t)
		var bias: Dictionary = {}
		for id in m.polls().keys():
			if str(id) != Rules.OTHERS_ID:
				bias[str(id)] = clampf(rng.randfn(1.0, 0.09), 0.75, 1.30)
		curve[cid2] = {"s": end_t - dur, "d": dur, "a": rng.randf_range(0.05, 0.50), "b": bias}
		if end_t > last_end:
			last_end = end_t
			last_id = cid2
	if last_id != "":
		var lc: Dictionary = curve[last_id]
		lc["d"] = float(CUTS) - float(lc["s"])
	m.s["election_curve"] = curve

## Partido que "defiende" cada circunscripción: ganador de las últimas elecciones o, si no las hay,
## el que proyectaban las encuestas. Sirve para detectar los vuelcos.
func _compute_baseline() -> Dictionary:
	var prev: Dictionary = m.d("prev_election_winners")
	if not prev.is_empty():
		return prev.duplicate()
	var out: Dictionary = {}
	var by_province: Dictionary = project_full()["by_province"]
	for cid in by_province.keys():
		out[str(cid)] = _best_of(by_province[cid], {})
	return out

func _baseline() -> Dictionary:
	return m.d("election_baseline")

## Garantiza que una partida guardada a medias (formato antiguo) tiene curva de recuento.
func ensure_night() -> void:
	if m.phase != "election_night":
		return
	if m.d("election_curve").is_empty() or m.a("election_order").is_empty():
		if not m.s.has("election_seed"):
			m.s["election_seed"] = m.rng.randi()
		if m.d("election_shares").is_empty():
			var day2 := m.voters.election_day()
			m.s["election_shares"] = day2.get("shares", {})
			m.s["election_turnout"] = float(day2.get("turnout", 0.7))
		_generate()
		m.s["election_tick"] = 0
		m.s["election_announced"] = {}
		m.s["election_leaders"] = {}
		m.s["election_flags"] = {}
		m.s["election_cuts"] = []
		m.s["election_revealed"] = []
		m.s["election_baseline"] = _compute_baseline()
		var totals := {}
		var vtotals := {}
		for id in m.polls().keys():
			if str(id) != Rules.OTHERS_ID:
				totals[str(id)] = 0
			vtotals[str(id)] = 0
		m.s["election_totals"] = totals
		m.s["election_vote_totals"] = vtotals
		_snap_tick = -1

# ---------------------------------------------------------------- noche electoral: estado
func night_tick() -> int:
	return int(m.s.get("election_tick", 0))

func night_progress() -> float:
	if m.a("election_order").is_empty():
		return 0.0
	if night_finished():
		return 100.0
	return float(m.s.get("election_scrut", 0.0))

func night_finished() -> bool:
	return not m.a("election_order").is_empty() and night_tick() >= CUTS

func constituency_by_id(cid: String) -> Dictionary:
	for c in m.constituencies:
		if str((c as Dictionary).get("id", "")) == cid:
			return c
	return {}

func province_frac(cid: String, tick: int) -> float:
	if tick >= CUTS:
		return 1.0
	var c: Dictionary = (m.d("election_curve")).get(cid, {})
	if c.is_empty():
		return 0.0
	var lin := clampf((float(tick) - float(c["s"])) / maxf(1.0, float(c["d"])), 0.0, 1.0)
	return lin * lin * (3.0 - 2.0 * lin)

## Resultado parcial de una circunscripción en un corte dado.
func province_partial(cid: String, tick: int) -> Dictionary:
	var f := province_frac(cid, tick)
	var final_votes: Dictionary = (m.d("election_votes")).get(cid, {})
	var province := constituency_by_id(cid)
	var seats := int(province.get("seats", 0))
	if f < MIN_SHOW or final_votes.is_empty():
		return {"frac": f if f >= MIN_SHOW else 0.0, "votes": {}, "alloc": {}, "counted": 0, "leader": "", "started": false}
	var votes: Dictionary = {}
	var alloc: Dictionary = {}
	var counted := 0
	if f >= 1.0:
		for id in final_votes.keys():
			votes[str(id)] = int(final_votes[id])
		alloc = ((m.d("election_alloc")).get(cid, {}) as Dictionary).duplicate()
	else:
		var bias: Dictionary = ((m.d("election_curve")).get(cid, {}) as Dictionary).get("b", {})
		for id in final_votes.keys():
			var bf := lerpf(float(bias.get(str(id), 1.0)), 1.0, f)
			votes[str(id)] = int(round(float(final_votes[id]) * f * bf))
		alloc = _allocate(votes, seats)
	for v in votes.values():
		counted += int(v)
	return {"frac": f, "votes": votes, "alloc": alloc, "counted": counted, "leader": _best_of(alloc, votes), "started": true}

func _best_of(alloc: Dictionary, votes: Dictionary) -> String:
	var best := ""
	var best_seats := -1
	var best_votes := -1
	var keys: Array = alloc.keys()
	keys.sort()
	for id in keys:
		var s := int(alloc[id])
		var v := int(votes.get(id, 0))
		if s > best_seats or (s == best_seats and v > best_votes):
			best_seats = s
			best_votes = v
			best = str(id)
	return best

## Foto completa del recuento en un corte: escaños, votos, % escrutado y estado de cada provincia.
func snapshot(tick: int = -1) -> Dictionary:
	if tick < 0:
		tick = night_tick()
	if tick == _snap_tick and not _snap.is_empty():
		return _snap
	var totals: Dictionary = {}
	var vtotals: Dictionary = {}
	for id in m.polls().keys():
		if str(id) != Rules.OTHERS_ID:
			totals[str(id)] = 0
		vtotals[str(id)] = 0
	var provinces: Dictionary = {}
	var counted_all := 0
	var total_all := 0
	var started := 0
	var done := 0
	for c in m.constituencies:
		var cd: Dictionary = c
		var cid := str(cd["id"])
		var ps := province_partial(cid, tick)
		provinces[cid] = ps
		total_all += _province_total_votes(cd)
		if bool(ps["started"]):
			started += 1
			counted_all += int(ps["counted"])
			for id in (ps["alloc"] as Dictionary).keys():
				totals[id] = int(totals.get(id, 0)) + int((ps["alloc"] as Dictionary)[id])
			for id in (ps["votes"] as Dictionary).keys():
				vtotals[id] = int(vtotals.get(id, 0)) + int((ps["votes"] as Dictionary)[id])
		if float(ps["frac"]) >= 1.0:
			done += 1
	_snap = {
		"tick": tick, "totals": totals, "votes": vtotals, "provinces": provinces,
		"scrutinized": 100.0 if tick >= CUTS else float(counted_all) / float(maxi(total_all, 1)) * 100.0,
		"started": started, "done": done,
	}
	_snap_tick = tick
	return _snap

# ---------------------------------------------------------------- noche electoral: avance
## Avanza `steps` cortes y devuelve los sucesos (ganadores, vuelcos, mayorías) ocurridos.
func advance_night(steps: int = 1) -> Array:
	if m.phase != "election_night":
		return []
	ensure_night()
	var events: Array = []
	for _i in range(steps):
		if night_tick() >= CUTS:
			break
		events.append_array(_apply_tick(night_tick() + 1))
	return events

## Salta directamente al 100 % del escrutinio.
func skip_night() -> Array:
	if m.phase != "election_night":
		return []
	ensure_night()
	if night_tick() >= CUTS:
		return []
	return _apply_tick(CUTS)

func _apply_tick(new_t: int) -> Array:
	var events: Array = []
	var snap := snapshot(new_t)
	var announced: Dictionary = m.d("election_announced")
	var leaders: Dictionary = m.d("election_leaders")
	var base: Dictionary = _baseline()
	var curve: Dictionary = m.d("election_curve")
	for c in m.constituencies:
		var cd: Dictionary = c
		var cid := str(cd["id"])
		var ps: Dictionary = (snap["provinces"] as Dictionary)[cid]
		if not bool(ps["started"]):
			continue
		var f := float(ps["frac"])
		var leader := str(ps["leader"])
		var a := float((curve.get(cid, {}) as Dictionary).get("a", 0.2))
		var info := {"cid": cid, "name": str(cd["name"]), "party": leader, "frac": f * 100.0, "seats": int(cd["seats"]), "alloc": ps["alloc"]}
		if not announced.has(cid):
			if f >= a or new_t >= CUTS:
				announced[cid] = true
				leaders[cid] = leader
				var holder := str(base.get(cid, ""))
				if holder != "" and holder != leader:
					info["type"] = "flip"
					info["from"] = holder
				else:
					info["type"] = "win"
				events.append(info)
		elif str(leaders.get(cid, "")) != leader:
			var prev := str(leaders[cid])
			leaders[cid] = leader
			if f >= 0.15:
				info["from"] = prev
				info["type"] = "regain" if str(base.get(cid, "")) == leader else "flip"
				events.append(info)
	m.s["election_tick"] = new_t
	m.s["election_scrut"] = float(snap["scrutinized"])
	m.s["election_totals"] = (snap["totals"] as Dictionary).duplicate()
	m.s["election_vote_totals"] = (snap["votes"] as Dictionary).duplicate()
	m.s["election_index"] = int(snap["done"])
	# Hitos nacionales: mayoría absoluta.
	var flags: Dictionary = m.d("election_flags")
	for id in (snap["totals"] as Dictionary).keys():
		var n := int((snap["totals"] as Dictionary)[id])
		if n >= Rules.MAJORITY and not flags.has("maj_" + str(id)):
			flags["maj_" + str(id)] = true
			events.append({"type": "majority", "party": str(id), "seats": n})
	# Evolución del voto por corte.
	var shares: Dictionary = {}
	var vsum := 0.0
	for v in (snap["votes"] as Dictionary).values():
		vsum += float(v)
	for id in (snap["votes"] as Dictionary).keys():
		shares[id] = float((snap["votes"] as Dictionary)[id]) / maxf(vsum, 1.0) * 100.0
	if vsum > 0.0:
		m.a("election_cuts").append({"t": new_t, "p": float(snap["scrutinized"]), "sh": shares, "seats": (snap["totals"] as Dictionary).duplicate()})
	return events

## Compatibilidad: revela la siguiente circunscripción completada (avanza cortes hasta que haya una).
func reveal_next() -> Dictionary:
	if m.phase != "election_night":
		return {}
	ensure_night()
	var revealed: Array = m.a("election_revealed")
	while true:
		var snap := snapshot()
		for c in m.constituencies:
			var cd: Dictionary = c
			var cid := str(cd["id"])
			if revealed.has(cid):
				continue
			if float(((snap["provinces"] as Dictionary)[cid] as Dictionary)["frac"]) >= 1.0:
				revealed.append(cid)
				var alloc := result_alloc(cid)
				return {"id": cid, "name": str(cd["name"]), "seats": int(cd["seats"]), "alloc": alloc, "winner": result_winner(cid)}
		if night_tick() >= CUTS:
			return {}
		advance_night(1)
	return {}

# ---------------------------------------------------------------- datos para la retransmisión
## Escaños más disputados: a qué partido le faltan menos votos para arrebatar el último escaño de la provincia.
func contested(limit: int = 6, min_frac: float = 0.35) -> Array:
	var snap := snapshot()
	var out: Array = []
	for c in m.constituencies:
		var cd: Dictionary = c
		var cid := str(cd["id"])
		var ps: Dictionary = (snap["provinces"] as Dictionary)[cid]
		if not bool(ps["started"]) or float(ps["frac"]) < min_frac:
			continue
		var votes: Dictionary = ps["votes"]
		var alloc: Dictionary = ps["alloc"]
		var valid := 0
		for v in votes.values():
			valid += int(v)
		var last_q := INF
		var holder := ""
		for id in alloc.keys():
			var a := int(alloc[id])
			if a > 0:
				var q := float(int(votes.get(id, 0))) / float(a)
				if q < last_q:
					last_q = q
					holder = str(id)
		if holder == "":
			continue
		var best_need := INF
		var challenger := ""
		for id in alloc.keys():
			if str(id) == holder or str(id) == Rules.OTHERS_ID:
				continue
			var v := int(votes.get(id, 0))
			if valid <= 0 or float(v) / float(valid) < 0.03:
				continue
			var need := last_q * float(int(alloc[id]) + 1) - float(v)
			if need < best_need:
				best_need = need
				challenger = str(id)
		if challenger == "":
			continue
		out.append({"cid": cid, "name": str(cd["name"]), "holder": holder, "challenger": challenger, "need": int(ceil(best_need / maxf(float(ps["frac"]), 0.05))), "seats": int(cd["seats"])})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["need"]) < int(y["need"]))
	return out.slice(0, limit)

## Sondeo a pie de urna (horquillas de escaños): final real con un margen de error.
func exit_poll() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.s.get("election_seed", 1)) ^ 0x5CA1AB1E
	var final: Dictionary = {}
	for cid in (m.d("election_alloc")).keys():
		for id in ((m.d("election_alloc"))[cid] as Dictionary).keys():
			final[id] = int(final.get(id, 0)) + int(((m.d("election_alloc"))[cid] as Dictionary)[id])
	var out: Dictionary = {}
	for id in final.keys():
		var n := int(final[id])
		if n <= 0:
			continue
		var center := maxi(0, n + int(round(rng.randfn(0.0, 0.035 * float(n) + 0.6))))
		var half := maxi(1, int(round(0.055 * float(n) + 0.5)))
		out[str(id)] = {"lo": maxi(0, center - half), "hi": center + half}
	return out

## Ganadores de cada circunscripción en el resultado final.
func final_winners() -> Dictionary:
	var out: Dictionary = {}
	for cid in (m.d("election_alloc")).keys():
		out[str(cid)] = result_winner(str(cid))
	return out

# ---------------------------------------------------------------- cierre
func finish_night() -> void:
	var player := m.pid()
	if m.d("election_totals").is_empty() or not night_finished():
		skip_night()
	var seats := m.seats_of(player)
	var share := m.vote_share_of(player)
	var history := m.a("election_history")
	history.append({"cycle": m.cycle, "seats": seats, "share": share, "date": Rules.date_string(m.election_unix())})
	m.s["seats"] = seats
	m.s["election_complete"] = true
	m.s["election_started"] = false
	m.s["prev_election_winners"] = final_winners()
	var vt_all := m.d("election_vote_totals")
	var vt_sum := 0.0
	for v in vt_all.values():
		vt_sum += float(v)
	var res_shares: Dictionary = {}
	for id in vt_all.keys():
		res_shares[str(id)] = float(vt_all[id]) / maxf(vt_sum, 1.0) * 100.0
	m.voters.finish_election(res_shares, float(m.s.get("election_turnout", 0.7)))
	m.militancy.on_election(seats)
	m.phase = "results"
	m.s["clock_unix"] = m.election_unix() + 86400
	# Subvención pública por escaños y votos (cifras del escenario, no oficiales).
	var player_votes := int(m.d("election_vote_totals").get(player, 0))
	var subsidy := float(seats) * 21167.0 + float(player_votes) * 0.81
	m.add_finance("Subvención pública por resultados", subsidy)
	_evaluate_objective(seats)
	var leader := leading_party()
	m.publish("Escrutinio completo: %s encabeza el resultado" % m.party_short(leader),
		"%s consigue %d escaños. %s obtiene %d diputados y el %.1f%% de los votos." % [m.party_short(leader), m.seats_of(leader), str(m.party.get("short_name", "Tu partido")), seats, share],
		"ELECCIONES", "positive" if seats >= int(m.d("objective").get("target_seats", 1)) else "warning")
	m.save_now()

func leading_party() -> String:
	var best := ""
	var best_seats := -1
	for id in m.d("election_totals").keys():
		var n := int(m.d("election_totals")[id])
		if n > best_seats:
			best_seats = n
			best = str(id)
	return best

func _evaluate_objective(seats: int) -> void:
	var obj := m.d("objective")
	var target := int(obj.get("target_seats", 1))
	obj["evaluated"] = true
	obj["result_seats"] = seats
	obj["met"] = seats >= target
	var members := int(m.s.get("members", 1200))
	if seats >= target:
		m.s["members"] = int(members * 1.08)
		m.publish("La dirección valora el resultado", "El objetivo de %d escaños se ha cumplido. La militancia respalda el rumbo de la campaña." % target, "PARTIDO", "positive")
	else:
		m.s["members"] = int(members * 0.95)
		m.publish("Críticas internas tras el resultado", "El partido no alcanza el objetivo de %d escaños. Algunas voces piden una reflexión sobre la estrategia." % target, "PARTIDO", "warning")

func result_alloc(cid: String) -> Dictionary:
	return (m.d("election_alloc")).get(cid, {})

func result_winner(cid: String) -> String:
	return _best_of(result_alloc(cid), (m.d("election_votes")).get(cid, {}))
