class_name CampaignSim
extends RefCounted
## Dinámica de campaña: evolución diaria de encuestas, agenda de actos, programa electoral,
## tono de campaña, entrevistas, ingresos semanales y recomendaciones del asesor.

var m: GameModel

const INITIAL_SALIENCE := {
	"housing": 0.18, "jobs": 0.17, "health": 0.15, "tax": 0.12,
	"education": 0.09, "energy": 0.08, "security": 0.11, "territory": 0.10
}

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- estado inicial
func ensure_state() -> void:
	if m.polls().is_empty():
		init_polls()
	if m.d("issue_salience").is_empty():
		m.s["issue_salience"] = INITIAL_SALIENCE.duplicate()
	if not m.s.has("poll_anchor"):
		m.s["poll_anchor"] = m.polls().duplicate()
	if m.a("poll_history_multi").is_empty():
		_seed_history()
	m.d("province_bonus")
	m.a("finance_log")
	if not m.s.has("tone"):
		m.s["tone"] = "contrast"
	m.voters.ensure()

func init_polls() -> void:
	var polls: Dictionary = {}
	var player := m.pid()
	if Rules.BASE_POLL.has(player):
		for id in Rules.BASE_POLL.keys():
			polls[str(id)] = float(Rules.BASE_POLL[id])
		for p in m.rivals:
			var rid := str((p as Dictionary).get("id", ""))
			if not polls.has(rid):
				polls[rid] = 0.5
	else:
		var custom := 2.5
		if m.is_regional(player):
			# Un partido que solo se presenta en una comunidad parte de ~7 % local, que a escala nacional es mucho menos.
			custom = maxf(0.08, 7.0 * float(m.territory_of(player)["electorate"]))
		var factor := (100.0 - custom) / 100.0
		for p in m.rivals:
			var rid2 := str((p as Dictionary).get("id", ""))
			polls[rid2] = float(Rules.BASE_POLL.get(rid2, 0.5)) * factor
		polls[Rules.OTHERS_ID] = float(Rules.BASE_POLL[Rules.OTHERS_ID]) * factor
		polls[player] = custom
	_normalize(polls)
	m.s["polls"] = polls
	m.s["poll_anchor"] = polls.duplicate()
	m.s["issue_salience"] = INITIAL_SALIENCE.duplicate()
	_seed_history()

func migrate_polls() -> void:
	var player := m.pid()
	var player_value := float(m.s.get("polling", 0.0))
	if player_value <= 0.0:
		player_value = 2.5 if bool(m.party.get("is_custom", false)) else float(Rules.BASE_POLL.get(player, 2.5))
	var rival_polls: Dictionary = m.s.get("rival_polls", {})
	var others := float(Rules.BASE_POLL[Rules.OTHERS_ID])
	var polls: Dictionary = {}
	var rest := maxf(1.0, 100.0 - player_value - others)
	var total := 0.0
	for v in rival_polls.values():
		total += float(v)
	for id in rival_polls.keys():
		polls[str(id)] = float(rival_polls[id]) / maxf(total, 0.1) * rest
	for p in m.rivals:
		var rid := str((p as Dictionary).get("id", ""))
		if not polls.has(rid):
			polls[rid] = 0.5
	polls[player] = player_value
	polls[Rules.OTHERS_ID] = others
	_normalize(polls)
	m.s["polls"] = polls
	m.s["poll_anchor"] = polls.duplicate()
	# La serie histórica antigua tiene otro formato: se vuelve a generar.
	m.s["poll_history_multi"] = []

func reseed_history() -> void:
	if m.a("poll_history_multi").size() >= 8:
		record_snapshot("Elecciones %d" % m.cycle)
	else:
		_seed_history()

func _seed_history() -> void:
	var history := m.a("poll_history_multi")
	history.clear()
	var base := m.polls()
	var cur: Dictionary = {}
	for id in base.keys():
		cur[str(id)] = float(base[id])
	var back: Array = []
	var drift_v: Dictionary = {}
	var now := m.clock_unix()
	for i in range(1, 27):
		# Se camina hacia atrás en el tiempo con inercia: sube y baja como unas encuestas de verdad.
		for id in cur.keys():
			var dv := float(drift_v.get(id, 0.0)) * 0.72 + m.rng.randfn(0.0, 0.11 * sqrt(maxf(float(cur[id]), 0.4)))
			drift_v[id] = dv
			cur[id] = maxf(0.05, float(cur[id]) + dv)
		_normalize(cur)
		var snap: Dictionary = {}
		for id in cur.keys():
			snap[str(id)] = snappedf(float(cur[id]), 0.01)
		back.push_front({"day": m.day - i * 7, "label": "Hace %d sem." % i, "polls": snap, "t": now - i * 7 * 86400})
	for e in back:
		history.append(e)
	record_snapshot()

func _normalize(polls: Dictionary) -> void:
	var total := 0.0
	for k in polls.keys():
		polls[k] = maxf(0.05, float(polls[k]))
		total += float(polls[k])
	if total <= 0.0:
		return
	for k in polls.keys():
		polls[k] = float(polls[k]) / total * 100.0

func record_snapshot(label: String = "", t: int = -1) -> void:
	var history := m.a("poll_history_multi")
	var snap: Dictionary = {}
	for id in m.polls().keys():
		snap[str(id)] = snappedf(float(m.polls()[id]), 0.01)
	var lbl := label if label != "" else "Día %d" % m.day
	var tt := t if t >= 0 else m.clock_unix()
	var entry := {"day": m.day, "label": lbl, "polls": snap, "t": tt}
	if not history.is_empty() and (str((history[history.size() - 1] as Dictionary).get("label", "")) == lbl or int((history[history.size() - 1] as Dictionary).get("t", -1)) == tt):
		history[history.size() - 1] = entry
	else:
		history.append(entry)
	while history.size() > Electorate.HISTORY_CAP:
		history.pop_front()

## Etiquetas de fecha («jul 23») para el eje del gráfico de encuestas.
func history_labels() -> Array:
	var out: Array = []
	for snap in m.a("poll_history_multi"):
		var t := int((snap as Dictionary).get("t", -1))
		out.append(Rules.month_label(t) if t >= 0 else str((snap as Dictionary).get("label", "")))
	return out

## Mueve la intención de voto de un partido y reparte la variación entre los demás.
func adjust_poll(id: String, delta: float) -> void:
	if m.is_player(id) and m.is_regional(id) and not Rules.REGIONALIST_TERRITORY.has(id):
		# Los efectos de campaña están calibrados para un partido estatal: se reducen según el censo cubierto.
		delta *= clampf(float(m.territory_of(id)["electorate"]) / 0.16, 0.05, 1.0)
	if m.voters.ready_state():
		m.voters.nudge(id, delta)
		return
	var polls := m.polls()
	if not polls.has(id):
		return
	var cur := float(polls[id])
	var target := maxf(0.05, cur + delta)
	var actual := target - cur
	var others_total := 0.0
	for k in polls.keys():
		if str(k) != id:
			others_total += float(polls[k])
	if others_total <= 0.0:
		return
	polls[id] = target
	for k in polls.keys():
		if str(k) != id:
			polls[k] = maxf(0.05, float(polls[k]) - actual * float(polls[k]) / others_total)
	_normalize(polls)

# ---------------------------------------------------------------- consultas de encuestas
## Instantánea de encuestas hace `back` días de calendario.
func _snapshot_back(back: int, from_index: int = -1) -> Dictionary:
	var history := m.a("poll_history_multi")
	if history.is_empty():
		return {}
	var last := history.size() - 1 if from_index < 0 else from_index
	var t_last := int((history[last] as Dictionary).get("t", -1))
	if t_last >= 0:
		var limit_t := t_last - back * 86400
		var pick := 0
		for i in range(last + 1):
			if int((history[i] as Dictionary).get("t", 0)) <= limit_t:
				pick = i
		return (history[pick] as Dictionary).get("polls", {})
	return (history[maxi(0, last - back)] as Dictionary).get("polls", {})

## Días que abarca la «tendencia»: una semana en campaña, un mes fuera de ella.
func trend_days() -> int:
	return 7 if m.phase == "campaign" else 30

func trend_label() -> String:
	return "7 d" if m.phase == "campaign" else "30 d"

func trend(id: String, back: int = -1) -> float:
	if back < 0:
		back = trend_days()
	var history := m.a("poll_history_multi")
	if history.size() < 2:
		return 0.0
	var current := float(((history[history.size() - 1] as Dictionary)["polls"] as Dictionary).get(id, 0.0))
	var past: Dictionary = _snapshot_back(back)
	return current - float(past.get(id, current))

## Forma reciente (de más antiguo a más reciente): 1 sube, 0 estable, -1 baja.
func form(id: String, n: int = 5) -> Array:
	var history := m.a("poll_history_multi")
	var result: Array = []
	if history.size() < 2:
		return result
	var step := trend_days()
	var t_last := int((history[history.size() - 1] as Dictionary).get("t", -1))
	for i in range(n):
		var hi_idx := -1
		if t_last >= 0:
			var target_t := t_last - i * step * 86400
			for k in range(history.size()):
				if int((history[k] as Dictionary).get("t", 0)) <= target_t:
					hi_idx = k
		else:
			hi_idx = history.size() - 1 - i * step
		if hi_idx < 1:
			break
		var a_val := float(((history[hi_idx] as Dictionary)["polls"] as Dictionary).get(id, 0.0))
		var past: Dictionary = _snapshot_back(step, hi_idx)
		var diff := a_val - float(past.get(id, a_val))
		result.push_front(1 if diff > 0.15 else (-1 if diff < -0.15 else 0))
	return result

# ---------------------------------------------------------------- programa y temas
func salience() -> Dictionary:
	return m.d("issue_salience")

## Temas cubiertos por el programa (derivado de las promesas del Manifesto).
func program() -> Dictionary:
	return m.manifesto.issues_covered()

func program_coverage() -> float:
	var total := 0.0
	for issue in program().keys():
		total += float(salience().get(str(issue), 0.0))
	return minf(total, 0.7)

func rival_coverage(id: String) -> float:
	var prof := m.ai.profile_of(id)
	var total := 0.0
	for issue in prof.get("issues", []):
		total += float(salience().get(str(issue), 0.0))
	# Los rivales cubren tres temas; se escala para compararlos con un programa de hasta seis.
	return total * 1.6

func set_tone(tone: String) -> void:
	if Rules.CAMPAIGN_TONES.has(tone):
		m.s["tone"] = tone

func top_issues(n: int = 3) -> Array:
	var ids: Array = salience().keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return float(salience()[x]) > float(salience()[y]))
	return ids.slice(0, n)

func _shift_salience() -> void:
	var sal := salience()
	var ids: Array = sal.keys()
	var up := str(ids[m.rng.randi_range(0, ids.size() - 1)])
	var down := str(ids[m.rng.randi_range(0, ids.size() - 1)])
	if up == down:
		return
	var amount := minf(0.045, float(sal[down]) - 0.04)
	if amount <= 0.0:
		return
	sal[up] = float(sal[up]) + amount
	sal[down] = float(sal[down]) - amount
	m.publish("La agenda pública gira hacia %s" % Rules.issue_name(up).to_lower(),
		"Los medios dedican cada vez más espacio a %s, mientras pierde protagonismo %s. Los partidos con propuestas sobre ese tema ganan visibilidad." % [Rules.issue_name(up).to_lower(), Rules.issue_name(down).to_lower()],
		"AGENDA PÚBLICA", "neutral", {"key": "agenda_shift"})

# ---------------------------------------------------------------- agenda de actos
func events() -> Array:
	return m.a("campaign_events")

func events_on(day: int) -> Array:
	var list: Array = []
	for item in events():
		var ev: Dictionary = item
		if int(ev.get("day", -1)) == day and str(ev.get("status", "scheduled")) != "cancelled":
			list.append(ev)
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("hour", 9)) < int(y.get("hour", 9)))
	return list

func pending_today() -> Array:
	var list: Array = []
	for ev in events_on(m.day):
		if str((ev as Dictionary).get("status", "scheduled")) == "scheduled":
			list.append(ev)
	return list

func upcoming(limit: int = 4) -> Array:
	var list: Array = []
	for item in events():
		var ev: Dictionary = item
		if str(ev.get("status", "scheduled")) == "scheduled" and int(ev.get("day", 0)) >= m.day:
			list.append(ev)
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if int(x["day"]) != int(y["day"]):
			return int(x["day"]) < int(y["day"])
		return int(x.get("hour", 9)) < int(y.get("hour", 9)))
	return list.slice(0, limit)

func find_event(event_id: String) -> Dictionary:
	for item in events():
		if str((item as Dictionary).get("id", "")) == event_id:
			return item
	return {}

func event_cost(type_name: String) -> float:
	return float((Rules.EVENT_TYPES.get(type_name, {}) as Dictionary).get("cost", 0.0))

func schedule(day: int, hour: int, type_name: String, venue: String, title: String, free: bool = false) -> Dictionary:
	if m.phase != "campaign":
		return {"ok": false, "error": "La campaña ha terminado."}
	if day < m.day or day > Rules.CAMPAIGN_LENGTH_DAYS:
		return {"ok": false, "error": "Ese día no está disponible."}
	var count := 0
	for existing in events_on(day):
		count += 1
		if int((existing as Dictionary).get("hour", -1)) == hour:
			return {"ok": false, "error": "Ya tienes un acto programado a esa hora."}
	if count >= Rules.MAX_EVENTS_PER_DAY:
		return {"ok": false, "error": "No puedes programar más de tres actos en un mismo día."}
	var cost := 0.0 if free else event_cost(type_name)
	if m.funds < cost:
		return {"ok": false, "error": "No tienes presupuesto suficiente para este acto."}
	var final_title := title.strip_edges()
	if final_title.is_empty():
		final_title = "%s · %s" % [type_name, venue]
	var seq := int(m.s.get("event_seq", 0))
	var ev := {
		"id": "event_%d_%d_%d" % [day, hour, seq],
		"day": day, "hour": hour, "type": type_name, "region": venue,
		"title": final_title, "cost": cost, "status": "scheduled"
	}
	m.s["event_seq"] = seq + 1
	events().append(ev)
	if cost > 0.0:
		m.add_finance("Acto: %s en %s" % [type_name, venue], -cost)
	m.publish("Nuevo acto en la agenda", "%s queda programado en %s para el día %d a las %02d:00." % [type_name, venue, day, hour], "AGENDA", "neutral")
	return {"ok": true, "event": ev}

func cancel(event_id: String) -> String:
	var ev := find_event(event_id)
	if ev.is_empty() or str(ev.get("status", "")) != "scheduled":
		return ""
	ev["status"] = "cancelled"
	if int(ev.get("day", 0)) > m.day:
		var refund := float(ev.get("cost", 0.0)) * 0.6
		if refund > 0.0:
			m.add_finance("Reembolso parcial: %s" % str(ev.get("title", "acto")), refund)
		return "Acto cancelado. Recuperas el 60 % del coste."
	m.trust = m.trust - 0.5
	return "Acto cancelado el mismo día: se pierde el coste y baja ligeramente la confianza."

func accept_media_invitation(data: Dictionary) -> String:
	var type_name := str(data.get("type", "Entrevista"))
	var venue := str(data.get("venue", "Madrid"))
	var title := str(data.get("title", "Invitación de un medio"))
	for d_value in range(m.day + 1, mini(m.day + 5, Rules.CAMPAIGN_LENGTH_DAYS) + 1):
		for hour in Rules.AGENDA_HOURS:
			var res := schedule(d_value, int(hour), type_name, venue, title, true)
			if bool(res.get("ok", false)):
				return "%s aceptada: queda en la agenda el día %d a las %02d:00." % [type_name, d_value, int(hour)]
	return "No hay huecos libres en la agenda de los próximos días."

# ---------------------------------------------------------------- resolución de actos
func _bonus(province: String, amount: float) -> void:
	var bonus := m.d("province_bonus")
	bonus[province] = minf(0.35, float(bonus.get(province, 0.0)) + amount)

func community_of(province_name: String) -> String:
	for c in m.constituencies:
		if str((c as Dictionary).get("name", "")) == province_name:
			return str((c as Dictionary).get("autonomous_community", ""))
	return ""

func venue_province(venue: String) -> String:
	return str(Rules.VENUES.get(venue, venue))

func is_interview_type(type_name: String) -> bool:
	return bool((Rules.EVENT_TYPES.get(type_name, {}) as Dictionary).get("interview", false))

func _media_mult(type_name: String) -> float:
	return 1.4 if type_name == "Debate" else (0.8 if type_name == "Rueda de prensa" else (0.9 if type_name == "Podcast" else 1.0))

func resolve_auto(ev: Dictionary) -> Dictionary:
	var type_name := str(ev.get("type", ""))
	var venue := str(ev.get("region", ""))
	var province := venue_province(venue)
	var result := {"type": type_name, "venue": venue, "title": str(ev.get("title", ""))}
	if is_interview_type(type_name):
		var auto := m.enc.auto_play(ev)
		result["factor"] = float(auto["factor"])
		result["summary"] = "Intervención delegada en tu portavoz. %s" % str(auto["summary"])
		result["headline"] = auto["headline"]
		_bonus(province, 0.004 * _media_mult(type_name))
		ev["status"] = "done"
		return result
	else:
		var factor2 := m.rng.randf_range(0.25, 1.0)
		match type_name:
			"Mitin":
				m.visibility = m.visibility + 2.0 + factor2
				m.trust = m.trust + 1.0 + factor2 * 0.8
				adjust_poll(m.pid(), 0.07 + factor2 * 0.05)
				_bonus(province, 0.03 + 0.03 * factor2)
				m.voters.on_event_region(community_of(province), 0.8 + factor2)
			"Visita territorial":
				adjust_poll(m.pid(), 0.04 + factor2 * 0.04)
				m.voters.on_event_region(community_of(province), 1.0 + factor2)
				m.momentum = m.momentum + 0.3
				m.visibility = m.visibility + 1.0
				_bonus(province, 0.05 + 0.04 * factor2)
			"Reunión de equipo":
				m.trust = m.trust + 0.3
				m.momentum = m.momentum + 0.25
			"Recaudación de fondos":
				var raised := m.rng.randf_range(9000.0, 26000.0) * (0.6 + m.trust / 100.0)
				m.add_finance("Recaudación en %s" % venue, raised)
				result["raised"] = raised
			"Descanso":
				m.trust = m.trust + 0.8
				m.momentum = m.momentum + 0.2
			_:
				m.visibility = m.visibility + 1.0
		result["factor"] = factor2
		result["summary"] = "%s en %s completado con un balance %s." % [type_name, venue, "positivo" if factor2 >= 0.55 else "moderado"]
		m.publish("%s en %s" % [type_name, venue], str(result["summary"]) + " La intención estimada se sitúa en %.1f%%." % m.player_poll(), "CAMPAÑA", "positive" if factor2 >= 0.55 else "neutral")
	ev["status"] = "done"
	m.a("campaign_log").append(str(result["summary"]))
	record_snapshot()
	return result

func _apply_media_effects(factor: float, mult: float, delegate_scale: float) -> void:
	var vis_scale := 0.8 if delegate_scale < 1.0 else 1.0
	m.trust = m.trust + factor * 4.0 * delegate_scale * mult * 0.7
	m.visibility = m.visibility + (2.5 + factor * 2.0) * mult * vis_scale
	adjust_poll(m.pid(), factor * 0.22 * mult * vis_scale)
	m.momentum = m.momentum + factor * 0.8 * mult * delegate_scale

func _tone_word(factor: float) -> String:
	return "positivo" if factor >= 0.25 else ("negativo" if factor < -0.2 else "mixto")

func cancel_pending_today() -> void:
	for ev in pending_today():
		(ev as Dictionary)["status"] = "cancelled"

func delegate_all_today() -> int:
	var n := 0
	for ev in pending_today():
		resolve_auto(ev)
		n += 1
	return n

# ---------------------------------------------------------------- avance del tiempo
## Termina el día actual y empieza el siguiente. Devuelve {ok, reason}.
func end_day() -> Dictionary:
	if m.phase != "campaign":
		return {"ok": false, "reason": "phase"}
	if not pending_today().is_empty():
		return {"ok": false, "reason": "events"}
	if m.day >= Rules.CAMPAIGN_LENGTH_DAYS:
		return {"ok": false, "reason": "election"}
	_daily_update()
	m.day = m.day + 1
	m.set_clock_to_campaign_day()
	record_snapshot()
	if m.day % 7 == 1:
		_weekly_update()
	m.expire_news()
	m.diplomacy.joint_list_tick()
	m.ai.tick("campaign")
	m.enc.daily()
	_maybe_media_invitation()
	_adviser_check()
	return {"ok": true}

## Avanza hasta el siguiente evento relevante. Devuelve {stop: event|message|election|limit, days: int}.
func smart_continue(max_days: int = 14) -> Dictionary:
	var days := 0
	var seq0 := int(m.s.get("news_seq", 0))
	while days < max_days:
		if not pending_today().is_empty():
			return {"stop": "event", "days": days}
		if m.day >= Rules.CAMPAIGN_LENGTH_DAYS:
			return {"stop": "election", "days": days}
		var res := end_day()
		if not bool(res.get("ok", false)):
			return {"stop": str(res.get("reason", "event")), "days": days}
		days += 1
		if not pending_today().is_empty():
			return {"stop": "event", "days": days}
		if m.urgent_since(seq0):
			return {"stop": "message", "days": days}
	return {"stop": "limit", "days": days}

func _daily_update() -> void:
	var player := m.pid()
	var tone := str(m.s.get("tone", "contrast"))
	var deltas: Dictionary = {}
	for key in m.polls().keys():
		var id := str(key)
		if id == Rules.OTHERS_ID:
			continue
		var delta := 0.0
		if id == player:
			delta += (program_coverage() - 0.45) * 0.12 + m.manifesto.resonance() * 0.035
			delta += m.momentum * 0.02 + (m.trust - 50.0) / 100.0 * 0.03 + (m.visibility - 25.0) / 100.0 * 0.02
			if tone == "attack":
				delta += 0.01
			elif tone == "positive":
				delta += 0.004
		else:
			delta += (rival_coverage(id) - 0.45) * 0.06
		# Los efectos de campaña están calibrados para un partido estatal: los regionales casi no se mueven a escala nacional.
		if m.is_regional(id):
			delta *= 0.3
			if id == player:
				delta *= clampf(float(m.territory_of(id)["electorate"]) / 0.16, 0.05, 1.0)
		deltas[id] = delta
	match tone:
		"positive":
			m.trust = m.trust + 0.12
		"contrast":
			m.visibility = m.visibility + 0.18
		"attack":
			m.visibility = m.visibility + 0.32
			m.trust = m.trust - 0.14
			var target := _top_rival()
			if target != "":
				deltas[target] = float(deltas.get(target, 0.0)) - 0.05
	if m.voters.ready_state():
		m.voters.nudge_many(deltas)
		m.voters.step_day()
	else:
		var polls := m.polls()
		for id in deltas.keys():
			polls[id] = maxf(0.05, float(polls[id]) + float(deltas[id]) + m.rng.randfn(0.0, 0.065))
		_normalize(polls)
	m.momentum = m.momentum * 0.9
	m.visibility = maxf(5.0, m.visibility - 0.35)
	m.trust = m.trust + (50.0 - m.trust) * 0.01
	# Los efectos territoriales de los actos se desvanecen poco a poco.
	var bonus := m.d("province_bonus")
	for k in bonus.keys():
		bonus[k] = float(bonus[k]) * 0.985

func _top_rival() -> String:
	for row in m.ranked_polls():
		if str((row as Dictionary)["id"]) != m.pid():
			return str((row as Dictionary)["id"])
	return ""

func _weekly_update() -> void:
	var income := m.weekly_income_forecast()
	m.add_finance("Cuotas y donaciones de la semana", income)
	m.add_finance("Gastos de estructura y personal", -m.weekly_expense_forecast())
	_shift_salience()
	m.publish("Balance semanal de campaña",
		"Tras la semana %d, la intención estimada del partido es del %.1f%%. Ingresos de la semana: %s €." % [m.week_of_campaign() - 1, m.player_poll(), Rules.money(income)],
		"SONDEO INTERNO", "neutral", {"key": "weekly_balance"})

func _maybe_media_invitation() -> void:
	for item in m.news():
		var msg: Dictionary = item
		if str(msg.get("category", "")) == "INVITACIÓN" and not bool(msg.get("resolved", false)):
			return
	if m.day >= Rules.CAMPAIGN_LENGTH_DAYS - 1:
		return
	if m.rng.randf() > 0.05 + m.visibility / 600.0:
		return
	var outlets := ["Cadena Nacional", "Radio Ciudadana", "El Observador", "Televisión Autonómica", "Podcast Político"]
	var types := ["Entrevista", "Entrevista", "Podcast", "Rueda de prensa", "Debate"]
	var type_name: String = types[m.rng.randi_range(0, types.size() - 1)]
	var outlet: String = outlets[m.rng.randi_range(0, outlets.size() - 1)]
	var venues: Array = Rules.VENUES.keys()
	var venue: String = venues[m.rng.randi_range(0, venues.size() - 1)]
	m.publish("Invitación de %s" % outlet,
		"%s te ofrece una intervención (%s) en los próximos días. Aceptarla no tiene coste, pero ocupará un hueco de tu agenda." % [outlet, type_name.to_lower()],
		"INVITACIÓN", "neutral",
		{"needs_response": true, "expires_in": 3, "key": "invite_" + outlet, "data": {"type": type_name, "venue": venue, "title": "%s · %s" % [type_name, outlet]},
		 "actions": [{"id": "media_accept", "label": "Aceptar invitación", "style": "good"}, {"id": "media_decline", "label": "Declinar", "style": "ghost"}]})

func _adviser_check() -> void:
	var last := int(m.s.get("adviser_last_day", -10))
	if m.day - last < 3:
		return
	var advice := ""
	var tone := "neutral"
	if m.player_poll() < float(m.s.get("adviser_previous_poll", m.player_poll())) - 0.4:
		advice = "La intención de voto está retrocediendo. Recomiendo revisar el mensaje y reforzar la presencia en territorios competitivos."
		tone = "warning"
	elif m.funds < 45000.0:
		advice = "El presupuesto empieza a ser limitado. Conviene reservar recursos para los últimos actos o programar una recaudación de fondos."
		tone = "warning"
	elif program().size() < 4:
		advice = "Tu programa tiene pocos compromisos. Cubrir los temas que más preocupan a la ciudadanía mejora tu evolución diaria en las encuestas."
	elif upcoming(10).is_empty():
		advice = "No quedan actos en la agenda. Planifica nuevos compromisos para mantener la presencia pública."
	elif m.day % 7 == 0:
		advice = "Balance semanal: concentra la próxima semana en las provincias donde puedas crecer y revisa a los rivales directos."
	if not advice.is_empty():
		m.publish("Consejo de tu asesor de campaña", advice, "ASESOR", tone, {"key": "advisor"})
	m.s["adviser_last_day"] = m.day
	m.s["adviser_previous_poll"] = m.player_poll()

# ---------------------------------------------------------------- implantación territorial
## Coste de presentar candidatura en otra comunidad.
func expansion_cost(community: String) -> int:
	return int(round((80000.0 + 1500000.0 * m.community_share([community])) / 1000.0) * 1000.0)

func can_expand() -> String:
	if not m.is_regional(m.pid()) or Rules.REGIONALIST_TERRITORY.has(m.pid()):
		return "Tu partido ya se presenta en toda España."
	if m.phase == "election_night":
		return "No puedes ampliar durante la noche electoral."
	return ""

func expand_territory(community: String) -> String:
	var why := can_expand()
	if why != "":
		return why
	var terr: Array = m.s.get("player_territory", [])
	if terr.has(community):
		return "Ya te presentas en %s." % community
	var cost := expansion_cost(community)
	if m.funds < float(cost):
		return "No tienes fondos: la expansión cuesta %s." % Rules.money(float(cost))
	m.add_finance("Candidatura en %s" % community, -float(cost))
	terr.append(community)
	m.s["player_territory"] = terr
	m.voters.on_territory_changed()
	# Arranque local modesto en la nueva comunidad, sacado de los demás.
	var share := m.community_share([community])
	adjust_poll_raw(m.pid(), 2.5 * share)
	m.publish("Candidatura en %s" % community, "Tu formación presentará listas también en %s. El arranque es modesto: hay que hacerse conocer." % community, "REDACCIÓN", "positive")
	m.save_now()
	return ""

## Suma puntos de encuesta sin reescalar (para ajustes ya calculados en términos nacionales).
func adjust_poll_raw(id: String, delta: float) -> void:
	if m.voters.ready_state():
		m.voters.nudge(id, delta)
		return
	var polls := m.polls()
	if not polls.has(id):
		return
	var cur := float(polls[id])
	var target := maxf(0.05, cur + delta)
	var actual := target - cur
	var others_total := 0.0
	for k in polls.keys():
		if str(k) != id:
			others_total += float(polls[k])
	if others_total <= 0.0:
		return
	polls[id] = target
	for k in polls.keys():
		if str(k) != id:
			polls[k] = float(polls[k]) * (others_total - actual) / others_total
