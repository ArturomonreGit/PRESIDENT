class_name TableDynamics
extends RefCounted
## Dinámica de la mesa de negociación: propuesta de apertura de la IA, dureza, eventos que cambian la mesa
## (ofertas rivales, filtraciones, nuevas exigencias, marcha atrás, encuestas, ultimátum) y reacción término a término.

var m: GameModel

## Exigencia extra que añade la IA a todo acuerdo (con ella nada se firma «por defecto»).
const HARDNESS := 0.07
## En la primera oferta la IA tantea: no cierra salvo que le ofrezcas bastante más de lo necesario.
const ANCHOR := 0.09
const MAX_TERMS := 8

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- propuesta de apertura de la IA
## Lo que el partido pone sobre la mesa al sentarse: qué aporta y qué exige a cambio. Cada término lleva
## `from_ai` y `opening`. Nunca devuelve una lista vacía: sentarse siempre implica una propuesta concreta.
func agenda_for(id: String, topic: String, mt: Dictionary = {}) -> Array:
	var out: Array = []
	var p := m.brain.profile(id)
	var amb := float(p.get("ambition", 0.5))
	var seats := m.seats_of(id)
	var must: Array = m.brain.must_terms(id)
	var tops := m.brain.top_issues(id, 3)
	match topic:
		"investiture", "pre_pact":
			out.append({"k": "vote_yes", "by": "ai"})
			for t in must:
				out.append((t as Dictionary).duplicate(true))
			# Su propuesta respeta su estrategia preferida: quien no quiere entrar no pide carteras, ofrece su fórmula.
			var pref: Dictionary = m.brain.preferred_modality(id)
			var mode := str(pref["mode"])
			if mode == "coalition" and amb > 0.45 and (seats >= 8 or m.phase == "campaign"):
				out.append({"k": "cabinet", "by": "player", "n": 2 if (amb > 0.72 and seats >= 25) else 1})
				if float(p.get("inst_ambition", 0.4)) >= 0.7 and seats >= 20:
					out.append({"k": "structure", "what": "vicepresidency", "by": "player"})
			elif mode in ["external", "puntual", "abstention"] and topic == "investiture":
				out.append({"k": "participation", "mode": mode, "by": "ai"})
			if float(p.get("territorial", 0.2)) >= 0.6:
				out.append({"k": "territory", "what": "invest", "n": 2, "by": "player"})
			var cd := cordon_demand(id)
			if not cd.is_empty():
				out.append(cd)
		"partner":
			out.append({"k": "vote_yes", "by": "player"})
			var mine := m.brain.top_issues(m.pid(), 1)
			if not mine.is_empty():
				out.append(m.brain.policy_term(m.pid(), "ai", str(mine[0])))
			if m.gov.player_leverage() >= 0.45:
				out.append({"k": "cabinet", "by": "ai", "n": 1})
		"bills":
			out.append({"k": "bills", "by": "ai", "n": 2})
			if not tops.is_empty():
				out.append(m.brain.policy_term(id, "player", str(tops[0])))
			out.append({"k": "bills", "by": "player", "n": 1})
		"stability":
			out.append({"k": "stability", "by": "ai"})
			for t2 in must:
				out.append((t2 as Dictionary).duplicate(true))
			if amb > 0.5 and m.gov.player_in_government():
				out.append({"k": "cabinet", "by": "player", "n": 1})
		"joint_list":
			out.append({"k": "joint_list", "by": "player"})
			if not must.is_empty():
				out.append((must[0] as Dictionary).duplicate(true))
			if amb > 0.5:
				out.append({"k": "cabinet", "by": "player", "n": 1})
		"law_deal":
			var lid := str(mt.get("law", ""))
			var law := m.laws.find(lid)
			if not law.is_empty():
				out.append({"k": "law_vote", "by": "ai", "law": lid})
				var st: Dictionary = m.laws.stance(law, id)
				for cond in (st["conditions"] as Array).slice(0, 2):
					var cdd: Dictionary = cond
					out.append({"k": "law_amend", "by": "player", "law": lid, "type": str(cdd["type"]), "measure": str(cdd["measure"]), "value": float(cdd["value"]), "text": str(cdd["text"])})
				if amb > 0.5:
					out.append({"k": "owe_vote", "by": "player"})
		_:
			out.append({"k": "bills", "by": "ai", "n": 1})
			if not tops.is_empty():
				out.append(m.brain.policy_term(id, "player", str(tops[0])))
	for t3 in out:
		(t3 as Dictionary)["from_ai"] = true
		(t3 as Dictionary)["opening"] = true
	return out

## Veto que el partido te exige a un tercero: solo si lo detesta y a ti te costaría de verdad (es un socio posible).
func cordon_demand(id: String) -> Dictionary:
	var best := ""
	var best_c := 0.22
	for p in m.all_parties():
		var oid := str((p as Dictionary).get("id", ""))
		if oid == id or m.is_player(oid):
			continue
		if m.seats_of(oid) <= 0 and m.poll_of(oid) < 2.0:
			continue
		var c := m.brain.compat(id, oid)
		if c < best_c and m.brain.compat(m.pid(), oid) >= 0.25:
			best_c = c
			best = oid
	if best == "":
		return {}
	return {"k": "cordon", "by": "player", "target": best}

# ---------------------------------------------------------------- dureza
## Exigencia añadida a la que ya pide el carácter del partido (se suma a `need` en la valoración).
func hardness(mt: Dictionary) -> float:
	var h := HARDNESS
	if int(mt.get("round", 0)) <= 1:
		h += ANCHOR
	h += float(mt.get("rival_bonus", 0.0))
	h += 0.03 * float(mt.get("stall", 0))
	if bool(mt.get("leaked", false)):
		h += 0.02
	h += float(mt.get("mood", 0.0))
	return clampf(h, 0.0, 0.40)

## Firma del paquete para detectar que se insiste con lo mismo.
func signature(table: Array) -> String:
	var parts: Array = []
	for t in table:
		var d: Dictionary = t
		parts.append("%s|%s|%s|%s|%s|%s|%s|%s|%s" % [d.get("k", ""), d.get("by", ""), d.get("n", ""), d.get("issue", d.get("target", d.get("measure", ""))), d.get("to", d.get("value", "")), d.get("law", ""), d.get("mode", d.get("what", "")), d.get("comp", ""), d.get("level", "")])
	parts.sort()
	return ";".join(parts)

# ---------------------------------------------------------------- reacción por término
## Cómo ve el partido cada término de la mesa: stance = ok | costly | refuse | veto | welcome | neutral.
func stances(id: String, table: Array, ctx: Dictionary) -> Array:
	var out: Array = []
	for i in range(table.size()):
		var t: Dictionary = table[i]
		var by_ai := str(t.get("by", "player")) == "ai"
		var v := float(m.brain.term_value(id, m.pid(), t, ctx)["v"])
		var block := m.brain.term_block(id, m.pid(), t)
		var stance := "neutral"
		var note := ""
		if block != "":
			stance = "veto"
			note = block
		elif str(t.get("k", "")) == "joint_list":
			stance = "ok" if v >= -0.05 else ("costly" if v >= -0.2 else "refuse")
		elif by_ai:
			if v >= -0.06:
				stance = "ok"
			elif v >= -0.20:
				stance = "costly"
				note = "Les cuesta ceder en esto"
			else:
				stance = "refuse"
				note = "Es demasiado para ellos"
		else:
			stance = "welcome" if v >= 0.10 else "neutral"
			if stance == "welcome":
				note = "Les interesa"
		out.append({"idx": i, "stance": stance, "note": note, "v": v})
	return out

# ---------------------------------------------------------------- eventos de la mesa
## Después de cada oferta que no cierra el trato puede ocurrir algo que cambia la mesa. A lo sumo uno por ronda.
func roll_event(mt: Dictionary) -> void:
	if str(mt.get("status", "")) != "open":
		return
	var round_n := int(mt.get("round", 0))
	if round_n < 1:
		return
	var id := str(mt["with"])
	var fired: Array = mt.get("events", [])
	var chance := 0.34 + 0.09 * float(round_n)
	if m.rng.randf() > chance:
		return
	var pool: Array = []
	var weights: Array = []
	if not fired.has("rival_offer") and not _rival_candidates(id).is_empty():
		pool.append("rival_offer")
		weights.append(3.0)
	if not fired.has("leak") and m.phase != "results":
		pool.append("leak")
		weights.append(1.4)
	if int(mt.get("demands_added", 0)) < 2 and (mt["table"] as Array).size() < MAX_TERMS and round_n >= 2:
		pool.append("new_demand")
		weights.append(2.4)
	if not fired.has("backdown") and float(mt.get("rapport", 0.0)) >= 8.0 and not _droppable(mt).is_empty():
		pool.append("backdown")
		weights.append(2.0)
	if not fired.has("poll_shift"):
		pool.append("poll_shift")
		weights.append(1.2)
	if not fired.has("bases") and not _ai_gives(mt).is_empty() and (mt["table"] as Array).size() >= 3:
		pool.append("bases")
		weights.append(1.3)
	if pool.is_empty():
		return
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := m.rng.randf() * total
	var chosen := str(pool[0])
	for i in range(pool.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			chosen = str(pool[i])
			break
	fired.append(chosen)
	mt["events"] = fired
	match chosen:
		"rival_offer": _ev_rival(mt, id)
		"leak": _ev_leak(mt, id)
		"new_demand": _ev_new_demand(mt, id)
		"backdown": _ev_backdown(mt, id)
		"poll_shift": _ev_poll(mt, id)
		"bases": _ev_bases(mt, id)

func _alert(mt: Dictionary, kind: String, title: String, text: String, tone: String) -> void:
	mt["alert"] = {"kind": kind, "title": title, "text": text, "tone": tone, "round": int(mt.get("round", 0))}
	(mt["log"] as Array).append({"who": "ai", "text": text, "tone": tone})

func _rival_candidates(id: String) -> Array:
	var out: Array = []
	for p in m.rivals:
		var oid := str((p as Dictionary).get("id", ""))
		if oid == id or m.is_player(oid):
			continue
		if m.phase != "campaign" and m.seats_of(oid) <= 0:
			continue
		if m.brain.compat(id, oid) >= 0.3:
			out.append(oid)
	return out

func _ai_gives(mt: Dictionary) -> Array:
	var out: Array = []
	var table: Array = mt["table"]
	for i in range(table.size()):
		var t: Dictionary = table[i]
		if str(t.get("by", "")) == "ai" and str(t.get("k", "")) in ["cabinet", "policy", "bills", "cordon"]:
			out.append(i)
	return out

## Exigencias suyas que podría soltar: las que no son su línea roja.
func _droppable(mt: Dictionary) -> Array:
	var out: Array = []
	var id := str(mt["with"])
	var musts: Array = m.brain.must_terms(id).map(func(t): return str((t as Dictionary)["issue"]))
	var table: Array = mt["table"]
	for i in range(table.size()):
		var t: Dictionary = table[i]
		if bool(t.get("from_ai", false)) and str(t.get("by", "")) == "player" and not str(t.get("k", "")) in ["law_amend"]:
			if str(t.get("k", "")) == "policy" and musts.has(str(t.get("issue", ""))):
				continue
			out.append(i)
	return out

func _ev_rival(mt: Dictionary, id: String) -> void:
	var cands := _rival_candidates(id)
	var rid := str(cands[m.rng.randi() % cands.size()])
	mt["rival_bonus"] = minf(0.14, float(mt.get("rival_bonus", 0.0)) + 0.07)
	var short := m.party_short(rid)
	var text := str(m.enc.pick([
		"Le seré franco: %s nos ha hecho llegar una propuesta más generosa. Tendrá que mejorar la suya.",
		"No es un secreto que %s también nos ha llamado. Su oferta, de momento, es mejor que la suya.",
		"Mientras hablamos, %s insiste en que cerremos con ellos. Me toca valorar alternativas."], "tevent_rival")).replace("%s", short)
	mt["choice"] = {"id": "rival_offer", "party": rid, "text": "%s compite por su apoyo." % short, "options": [
		{"id": "match", "label": "Igualar: mejorar tu oferta"},
		{"id": "warn", "label": "Advertir de lo que perderían"},
		{"id": "ignore", "label": "Mantener tu oferta"},
	]}
	_alert(mt, "rival_offer", "Oferta rival de %s" % short, text, "warn")

func _ev_leak(mt: Dictionary, id: String) -> void:
	mt["leaked"] = true
	mt["rapport"] = float(mt.get("rapport", 0.0)) - 8.0
	var short := m.party_short(id)
	m.publish("Se filtra la negociación con %s" % short, "Un medio publica detalles de lo que se habla en la mesa. Cada parte acusa a la otra.", "DIPLOMACIA", "warning")
	m.trust = m.trust - 0.4
	_alert(mt, "leak", "Filtración", str(m.enc.pick([
		"Esto ha salido en la prensa y no ha sido de nuestra parte. Así es difícil negociar con tranquilidad.",
		"Alguien ha filtrado lo que hablamos. Si va a ser así, endureceremos nuestra posición.",
		"Lo hablado aquí está en los periódicos. Me obliga a ser más exigente de cara a los míos."], "tevent_leak")), "bad")

func _ev_new_demand(mt: Dictionary, id: String) -> void:
	var table: Array = mt["table"]
	var term := {}
	var cd := cordon_demand(id)
	var tops := m.brain.top_issues(id, 3)
	var cands: Array = []
	for issue in tops:
		var has_issue := false
		for t in table:
			if str((t as Dictionary).get("k", "")) == "policy" and str((t as Dictionary).get("by", "")) == "player" and str((t as Dictionary).get("issue", "")) == str(issue):
				has_issue = true
		if not has_issue:
			cands.append(m.brain.policy_term(id, "player", str(issue)))
	if not cd.is_empty() and not _has_cordon(table, str(cd["target"])):
		cands.append(cd)
	var cab_idx := -1
	for i in range(table.size()):
		var tt: Dictionary = table[i]
		if str(tt.get("k", "")) == "cabinet" and str(tt.get("by", "")) == "player" and int(tt.get("n", 1)) < 3:
			cab_idx = i
	if cands.is_empty() and cab_idx < 0:
		return
	var text := ""
	if cab_idx >= 0 and (cands.is_empty() or m.rng.randf() < 0.35):
		var cur: Dictionary = table[cab_idx]
		cur["n"] = int(cur.get("n", 1)) + 1
		cur["from_ai"] = true
		cur["changed"] = true
		text = "Mi ejecutiva no aprueba menos de %d carteras para nosotros. Es lo que me piden." % int(cur["n"])
	else:
		term = cands[m.rng.randi() % cands.size()]
		term["from_ai"] = true
		term["new"] = true
		table.append(term)
		text = "Mi dirección exige además: %s. Sin eso no me van a dejar firmar." % m.brain.term_text(term).to_lower()
	mt["demands_added"] = int(mt.get("demands_added", 0)) + 1
	_alert(mt, "new_demand", "Nueva exigencia", text, "warn")

func _has_cordon(table: Array, target: String) -> bool:
	for t in table:
		var d: Dictionary = t
		if str(d.get("k", "")) == "cordon" and str(d.get("target", "")) == target:
			return true
	return false

func _ev_backdown(mt: Dictionary, id: String) -> void:
	var idxs := _droppable(mt)
	if idxs.is_empty():
		return
	var idx := int(idxs[m.rng.randi() % idxs.size()])
	var table: Array = mt["table"]
	var gone: Dictionary = table[idx]
	table.remove_at(idx)
	mt["rapport"] = float(mt.get("rapport", 0.0)) + 3.0
	_alert(mt, "backdown", "Cesión de %s" % m.party_short(id), "He hablado con los míos y podemos renunciar a %s. Es un gesto: espero otro por su parte." % m.brain.term_text(gone).to_lower(), "good")

func _ev_poll(mt: Dictionary, id: String) -> void:
	var tr := m.campaign.trend(id)
	var short := m.party_short(id)
	if tr >= 0.2:
		mt["mood"] = float(mt.get("mood", 0.0)) + 0.04
		_alert(mt, "poll_shift", "Sondeo favorable a %s" % short, "Las últimas encuestas nos dan aire. No tengo tanta prisa por cerrar algo que nos obligue a ceder.", "warn")
	elif tr <= -0.2:
		mt["mood"] = float(mt.get("mood", 0.0)) - 0.03
		_alert(mt, "poll_shift", "Sondeo adverso a %s" % short, "Las encuestas no nos acompañan. Quizá convenga ser menos rígidos si hay un buen acuerdo.", "good")
	else:
		mt["mood"] = float(mt.get("mood", 0.0)) + 0.01
		_alert(mt, "poll_shift", "Sin cambios en los sondeos", "Los sondeos no se mueven, así que no hay nada que me empuje a ceder hoy.", "neutral")

func _ev_bases(mt: Dictionary, id: String) -> void:
	var idxs := _ai_gives(mt)
	if idxs.is_empty():
		return
	var idx := int(idxs[m.rng.randi() % idxs.size()])
	var table: Array = mt["table"]
	var gone: Dictionary = table[idx]
	table.remove_at(idx)
	mt["rapport"] = float(mt.get("rapport", 0.0)) - 3.0
	_alert(mt, "bases", "Sus bases se rebelan", "Mis bases no aceptan %s. Ya no puedo ofrecerlo; habrá que buscar otra fórmula." % m.brain.term_text(gone).to_lower(), "bad")

# ---------------------------------------------------------------- decisiones ante un evento
## Respuesta del jugador al dilema abierto en la mesa. Devuelve el texto de confirmación.
func resolve_choice(mt: Dictionary, option_id: String) -> String:
	var ch: Dictionary = mt.get("choice", {})
	if ch.is_empty():
		return ""
	var id := str(mt["with"])
	var log: Array = mt["log"]
	var out := ""
	match str(ch.get("id", "")):
		"rival_offer":
			var rid := str(ch.get("party", ""))
			match option_id:
				"match":
					mt["rival_bonus"] = 0.02
					var table: Array = mt["table"]
					var sweet := {}
					for issue in m.brain.top_issues(id, 3):
						var has_issue := false
						for t in table:
							if str((t as Dictionary).get("k", "")) == "policy" and str((t as Dictionary).get("by", "")) == "player" and str((t as Dictionary).get("issue", "")) == str(issue):
								has_issue = true
						if not has_issue:
							sweet = m.brain.policy_term(id, "player", str(issue))
							break
					if sweet.is_empty():
						sweet = {"k": "bills", "by": "player", "n": 1}
					if table.size() < MAX_TERMS:
						sweet["sweetener"] = true
						table.append(sweet)
					log.append({"who": "player", "text": "Entonces mejoro mi propuesta: no quiero que %s se lo lleve por una cuestión de detalle." % m.party_short(rid), "tone": "neutral"})
					log.append({"who": "ai", "text": "Eso ya suena distinto. Veamos si alcanza.", "tone": "good"})
					out = "Mejoras tu oferta para competir con %s." % m.party_short(rid)
				"warn":
					var pp := clampf(0.30 + 0.35 * float(m.diplomacy.context_for(mt).get("player_pivot", 0.4)) + 0.2 * (1.0 - m.brain.compat(id, rid)) + 0.15 * Leader.edge(m.character(), "firmeza"), 0.1, 0.85)
					log.append({"who": "player", "text": "Piensen bien con quién se sientan: %s no les va a dar lo que yo sí puedo darles." % m.party_short(rid), "tone": "warn"})
					if m.rng.randf() < pp:
						mt["rival_bonus"] = 0.02
						mt["rapport"] = float(mt.get("rapport", 0.0)) - 3.0
						log.append({"who": "ai", "text": "No me gustan los avisos, pero tiene parte de razón. Seguimos con usted.", "tone": "warn"})
						out = "Tu advertencia surte efecto: la oferta rival pierde fuerza."
					else:
						mt["rapport"] = float(mt.get("rapport", 0.0)) - 10.0
						mt["patience"] = int(mt["patience"]) - 1
						log.append({"who": "ai", "text": "No voy a aceptar que me digan con quién puedo hablar. Esto sienta mal.", "tone": "bad"})
						out = "La advertencia sale mal: se enfría el ambiente."
				_:
					log.append({"who": "player", "text": "Mi oferta es la que está sobre la mesa.", "tone": "neutral"})
					out = "Mantienes tu oferta."
	mt.erase("choice")
	return out

# ---------------------------------------------------------------- historial de mesas
func record(mt: Dictionary) -> void:
	var hist := m.a("table_history")
	hist.push_front({
		"party": str(mt.get("with", "")), "topic": str(mt.get("topic", "")), "status": str(mt.get("status", "")),
		"text": str(mt.get("result", "")), "cycle": m.cycle, "clock": m.day if m.phase == "campaign" else m.gov_month, "phase": m.phase
	})
	while hist.size() > 20:
		hist.pop_back()
