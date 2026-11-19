class_name AIDirector
extends RefCounted
## Perfiles persistentes de los partidos rivales, relaciones, memoria de negociaciones y declaraciones.
## Es un sistema de reglas y probabilidades; no usa ningún servicio externo.

var m: GameModel

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- perfiles
func profiles() -> Dictionary:
	return m.d("ai_profiles")

func relations() -> Dictionary:
	return m.d("political_relationships")

func memory() -> Array:
	return m.a("ai_memory")

func ensure_profiles() -> void:
	var profs := profiles()
	var rels := relations()
	for item in m.rivals:
		var rp: Dictionary = item
		var id := str(rp.get("id", ""))
		if not profs.has(id):
			var prios := issue_priorities(rp)
			profs[id] = {
				"pragmatism": m.rng.randf_range(0.25, 0.9),
				"aggressiveness": m.rng.randf_range(0.2, 0.85),
				"media_activity": m.rng.randf_range(0.25, 0.9),
				"priority": demand_group(str(prios[0])),
				"issues": prios,
				"strategy": "negotiator" if m.rng.randf() > 0.45 else "opposition",
				"last_action": "none"
			}
		else:
			var prof: Dictionary = profs[id]
			if not prof.has("issues"):
				prof["issues"] = issue_priorities(rp)
			# Migración: prioridades antiguas en texto libre → grupos de demandas.
			if not Rules.DEMANDS.has(str(prof.get("priority", ""))):
				prof["priority"] = demand_group(str((prof["issues"] as Array)[0]))
		m.brain.ensure_traits(id, profs[id])
		if not rels.has(id):
			rels[id] = m.rng.randf_range(35.0, 65.0)

## Tres temas principales de un partido a partir de su perfil ideológico.
func issue_priorities(rp: Dictionary) -> Array:
	var p: Dictionary = rp.get("ideology_profile", {})
	var score := {
		"housing": _v(p, "progresismo") * 0.4 + _v(p, "igualdad") * 0.4 + _v(p, "socialismo") * 0.3,
		"tax": _v(p, "liberalismo_economico") * 1.0,
		"health": _v(p, "igualdad") * 0.5 + _v(p, "socialdemocracia") * 0.5 + _v(p, "feminismo") * 0.2,
		"education": _v(p, "igualdad") * 0.4 + _v(p, "progresismo") * 0.3 + _v(p, "europeismo") * 0.2,
		"jobs": _v(p, "socialismo") * 0.4 + _v(p, "sindicalismo") * 0.6 + _v(p, "keynesianismo") * 0.5 + _v(p, "liberalismo_economico") * 0.25,
		"energy": _v(p, "ecologismo") * 1.0,
		"security": _v(p, "conservadurismo") * 0.5 + _v(p, "patriotismo") * 0.5,
		"territory": _v(p, "nacionalismo") * 0.6 + _v(p, "federalismo") * 0.4 + _v(p, "regionalismo") * 0.6
	}
	var ids: Array = score.keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return float(score[x]) > float(score[y]))
	return ids.slice(0, 3)

func _v(profile: Dictionary, key: String) -> float:
	return float(profile.get(key, 0.0))

func demand_group(issue_id: String) -> String:
	match issue_id:
		"housing": return "housing"
		"tax", "jobs": return "economy"
		"health", "education": return "public"
		"energy": return "energy"
		"security": return "security"
		"territory": return "territory"
	return "economy"

func profile_of(id: String) -> Dictionary:
	return profiles().get(id, {})

func relation(id: String) -> float:
	return float(relations().get(id, 50.0))

func change_relation(id: String, delta: float) -> void:
	relations()[id] = clampf(relation(id) + delta, 0.0, 100.0)

func remember(entry: Dictionary) -> void:
	entry["day"] = m.day
	entry["cycle"] = m.cycle
	var mem := memory()
	mem.append(entry)
	while mem.size() > 100:
		mem.pop_front()

# ---------------------------------------------------------------- afinidad ideológica
## Distancia normalizada 0..1 (0 = idénticos) en los tres ejes ideológicos.
func distance(pa: Dictionary, pb: Dictionary) -> float:
	var ia: Dictionary = pa.get("ideology", {})
	var ib: Dictionary = pb.get("ideology", {})
	var sum := 0.0
	for axis in ["economic", "social", "territorial"]:
		var delta := float(ia.get(axis, 0.0)) - float(ib.get(axis, 0.0))
		sum += delta * delta
	return clampf(sqrt(sum / 3.0) / 2.0, 0.0, 1.0)

## Afinidad 0..1 (1 = muy afines).
func affinity(id_a: String, id_b: String) -> float:
	return clampf(1.0 - distance(m.party_by_id(id_a), m.party_by_id(id_b)) * 1.8, 0.0, 1.0)

# ---------------------------------------------------------------- declaraciones
func tick(stage: String) -> void:
	if m.rivals.is_empty():
		return
	m.brain.initiative(stage)
	if stage == "campaign" and int(m.s.get("ai_last_statement_day", -99)) == m.day:
		return
	if m.rng.randf() > (0.5 if stage == "government" else 0.36):
		return
	# El partido más activo en medios toma la palabra.
	var speaker: Dictionary = m.rivals[0]
	var best := -1.0
	for candidate in m.rivals:
		var cprof := profile_of(str((candidate as Dictionary).get("id", "")))
		var weight := m.rng.randf() * float(cprof.get("media_activity", 0.5))
		if weight > best:
			best = weight
			speaker = candidate
	var id := str(speaker.get("id", ""))
	var short := str(speaker.get("short_name", id))
	var prof := profile_of(id)
	var aggressiveness := float(prof.get("aggressiveness", 0.5))
	var topic_id := _hot_topic(prof)
	var topic := Rules.issue_name(topic_id).to_lower()
	var player_name := str(m.party.get("short_name", "tu partido"))
	var last := _last_interaction(id)
	var kinds := ["attack_player", "open_door", "own_proposal", "attack_rival", "red_lines"]
	var kind: String = kinds[m.rng.randi_range(0, kinds.size() - 1)]
	if last == "agreement_rejected" and m.rng.randf() < 0.65:
		kind = "attack_player"
	elif last == "agreement_accepted" and m.rng.randf() < 0.55:
		kind = "open_door"
	elif aggressiveness > 0.7 and m.rng.randf() < 0.5:
		kind = "attack_player"
	if stage == "government" and m.role() == "opposition" and m.rng.randf() < 0.5:
		kind = "attack_rival"
	var templates: Array = Rules.AI_STATEMENTS[kind]
	var template: Array = templates[m.rng.randi_range(0, templates.size() - 1)]
	var headline_tpl := str(template[0])
	var body_tpl := str(template[1])
	var headline := ""
	var body := ""
	var tone := "neutral"
	var actions: Array = []
	match kind:
		"attack_player":
			headline = headline_tpl % [short, player_name]
			body = body_tpl % [short, player_name, topic]
			tone = "warning"
			change_relation(id, -3.0)
			actions = _reply_actions()
		"open_door":
			headline = headline_tpl % [short, player_name]
			body = body_tpl % [short, player_name, topic]
			tone = "positive"
			change_relation(id, 4.0)
			actions = _reply_actions()
		"own_proposal":
			headline = headline_tpl % short
			body = body_tpl % topic.capitalize() if body_tpl.count("%s") == 1 else body_tpl % [short, topic]
		"attack_rival":
			var other: Dictionary = m.rivals[m.rng.randi_range(0, m.rivals.size() - 1)]
			headline = headline_tpl % short
			body = body_tpl % [short, str(other.get("short_name", "sus rivales"))]
		_:
			headline = headline_tpl % short
			body = body_tpl % [short, topic]
			tone = "warning"
	prof["last_action"] = headline
	profiles()[id] = prof
	m.s["ai_last_statement_day"] = m.day
	remember({"party": id, "stage": stage, "headline": headline, "body": body, "topic": topic_id})
	m.publish(headline, body, "DECLARACIONES", tone, {"speaker_id": id, "actions": actions})

func _reply_actions() -> Array:
	return [
		{"id": "reply_firm", "label": "Responder con firmeza", "style": "primary"},
		{"id": "reply_dialogue", "label": "Tender puentes", "style": "good"}
	]

## Entre los temas del partido, elige el más presente en la agenda pública.
func _hot_topic(prof: Dictionary) -> String:
	var best := "jobs"
	var best_weight := -1.0
	var sal: Dictionary = m.d("issue_salience")
	for issue in prof.get("issues", ["jobs"]):
		var w := float(sal.get(str(issue), 0.1)) * m.rng.randf_range(0.8, 1.2)
		if w > best_weight:
			best_weight = w
			best = str(issue)
	return best

func _last_interaction(id: String) -> String:
	var last := ""
	for entry in memory():
		var e: Dictionary = entry
		if str(e.get("party", "")) == id and str(e.get("event", "")) in ["agreement_accepted", "agreement_rejected"]:
			last = str(e.get("event", ""))
	return last

func reply(speaker_id: String, style: String) -> String:
	var short := m.party_short(speaker_id)
	if style == "dialogue":
		change_relation(speaker_id, 7.0)
		m.trust = m.trust + 0.4
		m.publish("Respuesta conciliadora a %s" % short, "Tu formación invita a mantener el diálogo y buscar coincidencias programáticas.", "DECLARACIONES", "positive")
		remember({"party": m.pid(), "stage": "reply", "target": speaker_id, "style": style})
		return "Has tendido la mano a %s (+relación, +confianza)." % short
	change_relation(speaker_id, -6.0)
	m.visibility = m.visibility + 0.6
	m.publish("Respuesta firme a %s" % short, "Tu formación rechaza las críticas y exige al grupo que concrete sus propias propuestas.", "DECLARACIONES", "warning")
	remember({"party": m.pid(), "stage": "reply", "target": speaker_id, "style": style})
	return "Has respondido con firmeza a %s (+visibilidad, −relación)." % short

## Declaración propia del jugador. context: campaign | negotiation | government
func player_statement(context: String) -> String:
	var body := "No vamos a renunciar a nuestras prioridades. Invitamos a los demás partidos a debatir propuestas concretas."
	var feedback := "Declaración emitida: +visibilidad, +impulso."
	if context == "negotiation":
		body = "Estamos dispuestos a negociar un acuerdo de investidura, pero exigimos compromisos claros, verificables y públicos."
		m.trust = m.trust + 0.7
		feedback = "Declaración emitida: +confianza."
	elif context == "government":
		body = "El Gobierno debe rendir cuentas por sus decisiones. Defenderemos el acuerdo de legislatura y exigiremos que se cumpla."
		m.visibility = m.visibility + 0.5
		feedback = "Declaración emitida: +visibilidad."
	else:
		m.visibility = m.visibility + 0.8
		m.momentum = m.momentum + 0.15
	m.publish("Tu partido responde a la actualidad política", body, "DECLARACIÓN DEL CANDIDATO", "neutral")
	remember({"party": m.pid(), "stage": context, "headline": "Declaración", "body": body})
	return feedback
