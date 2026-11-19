class_name LawMaker
extends RefCounted
## Taller de leyes: borradores personalizables, postura de cada partido ante una ley (voto, condiciones y exigencias)
## y generación de iniciativas de la IA. Cuantas más medidas incluye una ley, más condiciones pueden poner los partidos.

var m: GameModel

## Medidas cuya modificación exige mayoría absoluta (leyes orgánicas).
const ORGANIC := ["competencies", "language_policy", "penal_code", "immigration", "surveillance", "abortion", "euthanasia", "lgbt_rights",
	"referendum", "senate_reform", "provincial", "fiscal_pact", "military_service", "drug_policy", "regularization", "deportation", "asylum"]
const YES_AT := 0.12
const NO_AT := -0.12

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- borradores
func drafts() -> Array:
	return m.a("law_drafts")

func queue() -> Array:
	return m.a("law_queue")

func _next_id() -> String:
	var n := int(m.s.get("law_counter", 0)) + 1
	m.s["law_counter"] = n
	return "ley_%d" % n

## Tipos de iniciativa: proposición/proyecto de ley, proposición no de ley («pnl») e interpelación al Gobierno.
const KINDS := {
	"ley": {"name": "Proposición de ley", "short": "Ley", "desc": "Cambia medidas del país si el Congreso la aprueba. Consume una iniciativa legislativa del trimestre."},
	"pnl": {"name": "Proposición no de ley", "short": "PNL", "desc": "Declaración política no vinculante: insta al Gobierno y retrata a quien vota en contra. Consume una acción de control."},
	"interpelacion": {"name": "Interpelación al Gobierno", "short": "Control", "desc": "Debate de control sobre un área: sin votación, gana visibilidad si el Gobierno flaquea en ella. Consume una acción de control."},
}
const TONES := {
	"consenso": {"name": "Consenso", "desc": "Texto tendido a los demás: los grupos lo reciben mejor, pero sale poca bandera."},
	"estandar": {"name": "Estándar", "desc": "Sin matices: cada grupo juzga las medidas por lo que son."},
	"bandera": {"name": "Bandera", "desc": "Ley de combate: lejanos la rechazan más, los afines se motivan y ganas visibilidad si sale."},
}
const STYLES := {
	"duro": {"name": "Duro", "desc": "Ataque frontal: mucha visibilidad si el Gobierno flaquea, pero puede salirte el tiro por la culata."},
	"tecnico": {"name": "Técnico", "desc": "Datos y cifras: ganancia moderada y estable."},
	"propositivo": {"name": "Propositivo", "desc": "Ofreces salidas: menos ruido, más confianza y mejor relación con el Gobierno."},
}

func new_draft(area_id: String, kind: String = "ley") -> Dictionary:
	var area := Policies.area(area_id)
	var title := "Ley de %s" % str(area.get("name", ""))
	var k := "proposición"
	if kind == "pnl":
		title = "Proposición no de ley sobre %s" % str(area.get("name", "")).to_lower()
		k = "pnl"
	elif kind == "interpelacion":
		title = "Interpelación sobre %s" % str(area.get("name", "")).to_lower()
		k = "interpelacion"
	var law := {"id": _next_id(), "title": title, "area": area_id, "proposer": m.pid(), "kind": k,
		"changes": {}, "goodwill": {}, "status": "draft", "month": m.gov_month, "tone": "estandar"}
	if k == "interpelacion":
		law["style"] = "tecnico"
	drafts().append(law)
	return law

func is_control(law: Dictionary) -> bool:
	return str(law.get("kind", "")) in ["pnl", "interpelacion"]

func has_votes(law: Dictionary) -> bool:
	return str(law.get("kind", "")) != "interpelacion"

func draft_by_id(id: String) -> Dictionary:
	for d in drafts():
		if str((d as Dictionary)["id"]) == id:
			return d
	return {}

## Busca una ley por id entre borradores y registradas.
func find(id: String) -> Dictionary:
	for l in queue():
		if str((l as Dictionary)["id"]) == id:
			return l
	return draft_by_id(id)

func delete_draft(id: String) -> void:
	var list := drafts()
	for i in range(list.size()):
		if str((list[i] as Dictionary)["id"]) == id:
			list.remove_at(i)
			return

## Fija el valor propuesto para una medida. Si coincide con el actual, se retira del borrador.
func set_change(law: Dictionary, measure_id: String, value: float) -> void:
	var meas := Policies.measure(measure_id)
	if meas.is_empty():
		return
	var v := Policies.snap(meas, value)
	var changes: Dictionary = law["changes"]
	if is_equal_approx(v, m.eco.value(measure_id)):
		changes.erase(measure_id)
	else:
		changes[measure_id] = v

## Fija una nueva escala de IRPF en el borrador (se guarda la escala y, como valor escalar, su tipo medio).
func set_irpf(law: Dictionary, brackets: Array) -> void:
	var b := Irpf.sanitize(brackets)
	if Irpf.same(b, m.eco.irpf_brackets()):
		(law["changes"] as Dictionary).erase(Irpf.SPECIAL_ID)
		law.erase("irpf")
	else:
		(law["changes"] as Dictionary)[Irpf.SPECIAL_ID] = Irpf.average_rate(b)
		law["irpf"] = b

func proposed_irpf(law: Dictionary) -> Array:
	if (law["changes"] as Dictionary).has(Irpf.SPECIAL_ID) and typeof(law.get("irpf", null)) == TYPE_ARRAY:
		return law["irpf"]
	return m.eco.irpf_brackets()

func proposed_value(law: Dictionary, measure_id: String) -> float:
	var changes: Dictionary = law["changes"]
	return float(changes[measure_id]) if changes.has(measure_id) else m.eco.value(measure_id)

func is_organic(law: Dictionary) -> bool:
	if str(law.get("kind", "")) in ["pnl", "interpelacion"]:
		return false
	for k in (law["changes"] as Dictionary).keys():
		if ORGANIC.has(str(k)):
			return true
	return false

func required_text(law: Dictionary) -> String:
	if str(law.get("kind", "")) == "presupuestos":
		return "Presupuestos · mayoría simple (si caen, se prorrogan los anteriores)"
	if str(law.get("kind", "")) == "pnl":
		return "No vinculante · más síes que noes"
	if str(law.get("kind", "")) == "interpelacion":
		return "Debate de control · sin votación"
	return "Ley orgánica · mayoría absoluta (176)" if is_organic(law) else "Ley ordinaria · más síes que noes"

func is_registered(id: String) -> bool:
	for l in queue():
		if str((l as Dictionary)["id"]) == id:
			return true
	return false

## Registra el borrador en el Congreso: se debatirá en la próxima sesión del Pleno.
func register(id: String) -> String:
	var law := draft_by_id(id)
	if law.is_empty():
		return "El borrador ya no existe."
	var control := is_control(law)
	if str(law.get("kind", "")) != "interpelacion" and (law["changes"] as Dictionary).is_empty():
		return "La ley no cambia ninguna medida." if not control else "La proposición no declara ninguna medida."
	# Tope duro: 3 iniciativas parlamentarias por trimestre, también las del programa electoral.
	if m.gov.bills_left() <= 0:
		return "Ya has registrado %d iniciativas este trimestre. El cupo se renueva el trimestre que viene." % GovernmentSim.INITIATIVES_PER_TURN
	if control:
		if m.congress.control_left() <= 0:
			return "No quedan acciones de control este trimestre."
		m.congress.use_control()
	else:
		law["kind"] = "proyecto" if m.role() == "government" else "proposición"
	m.s["bills_left"] = m.gov.bills_left() - 1
	law["status"] = "registered"
	queue().append(law)
	delete_draft(id)
	m.manifesto.on_bill(law, "registered")
	m.publish("Se registra: %s" % str(law["title"]), "Tu grupo registra la iniciativa en el Congreso. Se debatirá en el próximo Pleno.", "PARLAMENTO", "neutral")
	m.save_now()
	return ""

## Devuelve una iniciativa registrada a borradores (antes del Pleno) y recupera la cuota gastada.
func unregister(id: String) -> bool:
	var list := queue()
	for i in range(list.size()):
		var law: Dictionary = list[i]
		if str(law["id"]) != id:
			continue
		list.remove_at(i)
		_restore_quota(law)
		law["status"] = "draft"
		law.erase("amend")
		law.erase("committed")
		drafts().append(law)
		if str(law.get("promise", "")) != "":
			m.manifesto.on_bill(law, "draft")
		return true
	return false

func _restore_quota(law: Dictionary) -> void:
	if is_control(law):
		m.congress.refund_control()
	m.s["bills_left"] = mini(GovernmentSim.INITIATIVES_PER_TURN, m.gov.bills_left() + 1)

# ---------------------------------------------------------------- posturas de los partidos
func _coalition() -> Array:
	var ids: Array = []
	var gid := str(m.s.get("government_party_id", ""))
	if gid != "":
		ids.append(gid)
	for e in m.gov.cabinet():
		var p := str((e as Dictionary).get("party", ""))
		if p != "" and not ids.has(p):
			ids.append(p)
	return ids

## Cuánto le gusta a un partido que una medida AUMENTE (-1 … 1).
func measure_pref(party_id: String, meas: Dictionary) -> float:
	var p := m.party_by_id(party_id)
	var ax: Dictionary = p.get("ideology", {})
	var lean: Dictionary = meas.get("lean", {})
	var pref := 0.0
	for a in ["economic", "social", "territorial"]:
		pref += float(ax.get(a, 0.0)) * float(lean.get(a, 0.0))
	var prof: Dictionary = p.get("ideology_profile", {})
	var likes: Dictionary = meas.get("likes", {})
	for k in likes.keys():
		pref += (float(prof.get(str(k), 30.0)) / 100.0 - 0.3) * float(likes[k]) * 1.6
	return clampf(pref * 1.5, -1.0, 1.0)

func _priority(party_id: String, area_id: String) -> float:
	var issue := str(Policies.area(area_id).get("issue", ""))
	var issues: Array = m.ai.profile_of(party_id).get("issues", [])
	return 1.4 if issues.has(issue) else 1.0

func _noise(law: Dictionary, party_id: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_%d" % [str(law["id"]), party_id, m.cycle])
	return rng.randf_range(-0.05, 0.05)

## Puntuación «de contenido» de un partido ante las medidas de una ley (sin pactos, favores ni lealtades).
func raw_score(law: Dictionary, party_id: String) -> float:
	return float(_content(law, party_id)["score"])

## Ajuste por el tono de la iniciativa y por ser no vinculante.
func tone_mod(law: Dictionary, party_id: String) -> float:
	var proposer := str(law.get("proposer", ""))
	if party_id == proposer:
		return 0.0
	var mod := 0.0
	var aff := m.ai.affinity(party_id, proposer)
	match str(law.get("tone", "estandar")):
		"consenso": mod += 0.07
		"bandera": mod += -0.11 if aff < 0.5 else 0.04
	if str(law.get("kind", "")) == "pnl":
		mod += 0.08
	return mod

func _content(law: Dictionary, party_id: String) -> Dictionary:
	var items: Array = []
	var pos := 0.0
	var neg := 0.0
	var wsum := 0.0
	var changes: Dictionary = law["changes"]
	for mid in changes.keys():
		var meas := Policies.measure(str(mid))
		var cur := m.eco.value(str(mid))
		var nv := float(changes[mid])
		var amb := Policies.ambition(meas, cur, nv)
		if amb <= 0.0:
			continue
		var dirn := 1.0 if nv > cur else -1.0
		var s := clampf(measure_pref(party_id, meas) * dirn, -1.0, 1.0) * (0.45 + 0.55 * minf(1.0, amb * 2.2))
		var w := (0.6 + amb * 1.4) * _priority(party_id, str(meas["area"]))
		items.append({"measure": str(mid), "s": s, "w": w})
		pos += w * maxf(s, 0.0)
		neg += w * maxf(-s, 0.0)
		wsum += w
	var score := (pos - 1.25 * neg) / (0.8 + wsum * 0.6) if wsum > 0.0 else 0.0
	return {"items": items, "score": score}

## Postura de un partido: puntuación (-1…1), voto, medidas que apoya/rechaza y condiciones.
func stance(law: Dictionary, party_id: String) -> Dictionary:
	if str(law.get("kind", "")) == "presupuestos":
		return m.exec.budget_stance(law, party_id)
	var core := _content(law, party_id)
	var items: Array = core["items"]
	var score := float(core["score"])
	var proposer := str(law.get("proposer", ""))
	var coalition := _coalition()
	var gov_bill := coalition.has(proposer)
	if party_id == proposer:
		score = maxf(score, 0.6)
	else:
		if coalition.has(party_id) and gov_bill:
			score += 0.3
		elif not coalition.has(party_id) and gov_bill:
			score -= 0.1
		if m.is_player(proposer):
			score += (m.ai.relation(party_id) - 50.0) / 100.0 * 0.3
		else:
			score += (m.ai.affinity(party_id, proposer) - 0.5) * 0.35
	score += float((law.get("goodwill", {}) as Dictionary).get(party_id, 0.0)) + _noise(law, party_id) + tone_mod(law, party_id)
	var vote := "yes" if score >= YES_AT else ("no" if score <= NO_AT else "abstain")
	# Pacto por la ley: si el partido se comprometió en una reunión, vota lo acordado.
	var committed: Dictionary = law.get("committed", {})
	var pact_note := ""
	if committed.has(party_id):
		vote = str(committed[party_id])
		pact_note = "Votará %s por vuestro pacto." % ("a favor" if vote == "yes" else "abstención")
		score = maxf(score, 0.2) if vote == "yes" else maxf(score, 0.0)
	return {"party": party_id, "score": clampf(score, -1.0, 1.0), "vote": vote, "items": items, "conditions": conditions(law, party_id, items), "pact": pact_note}

## Condiciones: rechazos puntuales que el partido pide suavizar y exigencias de incluir algo propio.
func conditions(law: Dictionary, party_id: String, items: Array) -> Array:
	var out: Array = []
	var n := items.size()
	var cap := 1 + int(n / 2)
	var bad: Array = []
	for it in items:
		if float((it as Dictionary)["s"]) < -0.3:
			bad.append(it)
	bad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) * float(a["w"]) < float(b["s"]) * float(b["w"]))
	for it in bad.slice(0, cap):
		var mid := str((it as Dictionary)["measure"])
		var meas := Policies.measure(mid)
		var cur := m.eco.value(mid)
		var nv := proposed_value(law, mid)
		var half := Policies.snap(meas, cur + (nv - cur) * 0.5)
		var drop := is_equal_approx(half, cur)
		out.append({"type": "drop" if drop else "soften", "measure": mid, "value": cur if drop else half,
			"text": "Retira «%s»" % str(meas["name"]) if drop else "Suaviza «%s»: %s" % [str(meas["name"]), Policies.value_text(meas, half)]})
	# Exigencias: a partir de 3 medidas piden meter algo suyo del mismo área.
	if n >= 3:
		var want := 1 + int(n / 5)
		var area_meas := Policies.measures_of(str(law["area"]))
		var cands: Array = []
		for mm in area_meas:
			var md: Dictionary = mm
			var mid2 := str(md["id"])
			if (law["changes"] as Dictionary).has(mid2):
				continue
			var pref := measure_pref(party_id, md)
			if absf(pref) >= 0.5:
				cands.append({"meas": md, "pref": pref})
		cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["pref"])) > absf(float(b["pref"])))
		for c in cands.slice(0, want):
			var cd: Dictionary = c
			var md2: Dictionary = cd["meas"]
			var dirn := 1.0 if float(cd["pref"]) > 0.0 else -1.0
			var cur2 := m.eco.value(str(md2["id"]))
			var target := Policies.snap(md2, cur2 + dirn * float(md2["step"]) * maxf(1.0, roundf((float(md2["max"]) - float(md2["min"])) / float(md2["step"]) * 0.2)))
			if is_equal_approx(target, cur2):
				continue
			out.append({"type": "add", "measure": str(md2["id"]), "value": target,
				"text": "Exige incluir «%s»: %s" % [str(md2["name"]), Policies.value_text(md2, target)]})
	return out

func apply_condition(law: Dictionary, party_id: String, cond: Dictionary) -> void:
	var mid := str(cond["measure"])
	set_change(law, mid, float(cond["value"]))
	var gw: Dictionary = law["goodwill"]
	gw[party_id] = float(gw.get(party_id, 0.0)) + 0.22

## Recuento previsto de la ley con las posturas actuales (el jugador vota lo recomendado).
func forecast(law: Dictionary) -> Dictionary:
	var yes := 0
	var no := 0
	var abst := 0
	var by_party: Dictionary = {}
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		var seats := m.seats_of(pid)
		var vote: String
		if m.is_player(pid):
			vote = recommended_vote(law)
		else:
			vote = str(stance(law, pid)["vote"])
		by_party[pid] = vote
		match vote:
			"yes": yes += seats
			"no": no += seats
			_: abst += seats
	return {"yes": yes, "no": no, "abstain": abst, "by_party": by_party}

func passes(law: Dictionary, yes: int, no: int) -> bool:
	if is_organic(law):
		return yes >= Rules.MAJORITY
	return yes > no

func recommended_vote(law: Dictionary) -> String:
	if str(law.get("proposer", "")) == m.pid():
		return "yes"
	return str(stance(law, m.pid())["vote"])

# ---------------------------------------------------------------- iniciativas de la IA
func generate_ai_law(party_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ai_law_%s_%d_%d" % [party_id, m.cycle, m.gov_month])
	var issues: Array = m.ai.profile_of(party_id).get("issues", [])
	var area_list: Array = Policies.areas()
	var weights: Array = []
	for a in area_list:
		var ad: Dictionary = a
		var w := 1.0 + (2.5 if issues.has(str(ad["issue"])) else 0.0)
		weights.append(w)
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := rng.randf() * total
	var area: Dictionary = area_list[0]
	var acc := 0.0
	for i in range(area_list.size()):
		acc += float(weights[i])
		if r <= acc:
			area = area_list[i]
			break
	var cands: Array = []
	for mm in Policies.measures_of(str(area["id"])):
		var md: Dictionary = mm
		var pref := measure_pref(party_id, md)
		if absf(pref) >= 0.3:
			cands.append({"meas": md, "pref": pref})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["pref"])) > absf(float(b["pref"])))
	var changes: Dictionary = {}
	var count := rng.randi_range(1, 3)
	for c in cands:
		if changes.size() >= count:
			break
		var cd: Dictionary = c
		var md2: Dictionary = cd["meas"]
		var cur := m.eco.value(str(md2["id"]))
		var dirn := 1.0 if float(cd["pref"]) > 0.0 else -1.0
		var steps := maxf(1.0, roundf((float(md2["max"]) - float(md2["min"])) / float(md2["step"]) * rng.randf_range(0.12, 0.3)))
		var nv := Policies.snap(md2, cur + dirn * steps * float(md2["step"]))
		if not is_equal_approx(nv, cur):
			changes[str(md2["id"])] = nv
	if changes.is_empty():
		return {}
	var coalition := _coalition()
	var is_gov := coalition.has(party_id)
	var short := m.party_short(party_id)
	var as_pnl := not is_gov and rng.randf() < 0.16
	var title := "Proyecto de Ley de %s" % str(area["name"]) if is_gov else "Proposición de Ley de %s (%s)" % [str(area["name"]), short]
	var kind := "proyecto" if is_gov else "proposición"
	if as_pnl:
		title = "Proposición no de Ley sobre %s (%s)" % [str(area["name"]).to_lower(), short]
		kind = "pnl"
	var tone := "estandar"
	var tr := rng.randf()
	if tr < 0.2:
		tone = "consenso"
	elif tr > 0.82:
		tone = "bandera"
	return {"id": _next_id(), "title": title, "area": str(area["id"]), "proposer": party_id, "kind": kind,
		"changes": changes, "goodwill": {}, "status": "registered", "month": m.gov_month, "tone": tone}

# ---------------------------------------------------------------- descripción
func change_lines(law: Dictionary) -> Array:
	var out: Array = []
	if str(law.get("kind", "")) == "presupuestos":
		return law.get("lines_cache", m.exec.budget_lines_changed(law))
	for mid in (law["changes"] as Dictionary).keys():
		var meas := Policies.measure(str(mid))
		if str(mid) == Irpf.SPECIAL_ID:
			var nb := proposed_irpf(law)
			out.append({"name": "IRPF por tramos", "from": "tipo medio %.1f %%" % m.eco.value(str(mid)), "to": "tipo medio %.1f %% · %d tramos, máx. %s %%" % [Irpf.average_rate(nb), nb.size(), ("%.1f" % Irpf.top_rate(nb)).rstrip("0").rstrip(".")]})
			continue
		out.append({"name": str(meas["name"]), "from": Policies.value_text(meas, m.eco.value(str(mid))), "to": Policies.value_text(meas, float(law["changes"][mid]))})
	return out
