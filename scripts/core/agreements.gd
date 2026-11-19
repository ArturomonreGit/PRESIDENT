class_name Agreements
extends RefCounted
## Acuerdos y memoria política (Alpha 0.2.1, entrega C de la especificación de negociación).
## Cada condición aceptada en una mesa se convierte en un compromiso persistente dentro de `m.a("commitments")` (no hay otro
## registro) con los campos de la especificación §6: partes, tipo, condición y categoría, obligatoriedad, responsable, plazo,
## estado, consecuencia e historial, más `agreement_id` (el acuerdo del que nacen) y una regla de verificación automática.
## Una exigencia aceptada no desaparece en silencio: se cumple, se renegocia con la otra parte o se incumple con consecuencias.

var m: GameModel

const STATE_NAMES := {"pending": "Pendiente", "in_progress": "En curso", "fulfilled": "Cumplido", "breached": "Incumplido", "renegotiated": "Renegociado", "cancelled": "Cancelado"}
const TERMINAL := ["fulfilled", "renegotiated", "cancelled"]
const BINDING_NAMES := {"red_line": "Línea roja", "binding": "Vinculante", "objective": "Objetivo", "soft": "No vinculante"}
const TYPE_NAMES := {"coalicion": "Coalición", "externo": "Apoyo externo", "puntual": "Acuerdo puntual", "abstencion": "Abstención", "otro": "Pacto"}
const MODE_TYPE := {"coalition": "coalicion", "external": "externo", "puntual": "puntual", "abstention": "abstencion"}
const KIND_CATEGORY := {"policy": "politicas", "cabinet": "carteras", "portfolio": "carteras", "structure": "estructura", "objective": "objetivos",
	"territory": "territorio", "budget": "presupuesto", "parliament": "parlamento", "institution": "instituciones", "calendar": "calendario"}
## Gravedad de un incumplimiento (puntos de confianza del socio) según la obligatoriedad.
const BREACH_SEVERITY := {"red_line": 12.0, "binding": 6.0, "objective": 3.0, "soft": 1.5}
## Tema → [indicador, sentido (1 sube, -1 baja), mejora por nivel de ambición, tolerancia]. Es lo que se mide para dar un objetivo por cumplido.
const OBJECTIVE_METRIC := {
	"housing": ["housing", 1, 1.5, 0.0], "health": ["health", 1, 1.5, 0.0], "education": ["education", 1, 1.5, 0.0],
	"jobs": ["unemployment", -1, 0.5, 0.0], "energy": ["environment", 1, 1.5, 0.0], "security": ["security", 1, 1.5, 0.0],
	"tax": ["tax_pressure", -1, 0.8, 0.8], "territory": ["infrastructure", 1, 1.5, 0.0]
}
## Condiciones territoriales: indicador que se vigila y mejora por nivel.
const TERRITORY_METRIC := {"invest": ["infrastructure", 1, 1.5], "competences": ["tension", -1, 2.0], "financing": ["tension", -1, 1.5]}
## Capital político que cuesta cumplir a mano lo que no se puede medir.
const MANUAL_COST := {"parliament": 2.0, "institution": 2.0, "budget": 2.0}
const MAX_HISTORY := 12

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- identificadores y migración
func new_agreement_id() -> int:
	var seq := int(m.s.get("agreement_seq", 0)) + 1
	m.s["agreement_seq"] = seq
	return seq

func _next_commit_id() -> int:
	var seq := int(m.s.get("commit_seq", 0))
	for c in m.a("commitments"):
		seq = maxi(seq, int((c as Dictionary).get("id", 0)))
	seq += 1
	m.s["commit_seq"] = seq
	return seq

func list() -> Array:
	return m.a("commitments")

## Completa los campos de la especificación en un compromiso (también en partidas antiguas); no pisa nada existente.
func normalize(com: Dictionary) -> void:
	if not com.has("id"):
		com["id"] = _next_commit_id()
	if not com.has("agreement_id"):
		com["agreement_id"] = 0
	if not com.has("category"):
		com["category"] = "politicas"
	if not com.has("binding"):
		com["binding"] = "binding"
	if not com.has("type"):
		com["type"] = "otro"
	if not com.has("kind"):
		com["kind"] = "policy"
	if not com.has("parties"):
		var gid := str(m.s.get("government_party_id", ""))
		var ps: Array = []
		if gid != "":
			ps.append(gid)
		if str(com.get("party", "")) != "" and not ps.has(str(com["party"])):
			ps.append(str(com["party"]))
		com["parties"] = ps
	if not com.has("responsible"):
		com["responsible"] = {"kind": "party", "id": str(m.s.get("government_party_id", "")), "name": m.party_short(str(m.s.get("government_party_id", "")))}
	if not com.has("consequence"):
		com["consequence"] = "Pierde confianza el socio; si se acumulan incumplimientos escala la crisis de la coalición."
	if not com.has("history"):
		com["history"] = [{"turn": m.turn(), "text": "Pactado en la mesa."}]
	if not com.has("state"):
		com["state"] = "fulfilled" if bool(com.get("fulfilled", false)) else ("breached" if m.gov_month > int(com.get("due", 8)) else "pending")
	if not com.has("progress"):
		com["progress"] = 1.0 if bool(com.get("fulfilled", false)) else 0.0

func ensure() -> void:
	for c in list():
		normalize(c as Dictionary)

func state_of(com: Dictionary) -> String:
	normalize(com)
	return str(com["state"])

func is_active(com: Dictionary) -> bool:
	return not (state_of(com) in TERMINAL)

func _log(com: Dictionary, text: String) -> void:
	var h: Array = com.get("history", [])
	h.push_front({"turn": m.turn(), "text": text})
	while h.size() > MAX_HISTORY:
		h.pop_back()
	com["history"] = h

func set_state(com: Dictionary, state: String, text: String = "") -> void:
	normalize(com)
	if str(com["state"]) == state:
		return
	com["state"] = state
	com["fulfilled"] = state == "fulfilled"
	if state == "fulfilled":
		com["progress"] = 1.0
	if text != "":
		_log(com, text)

func overdue(com: Dictionary) -> bool:
	return is_active(com) and str(com.get("verify", {}).get("t", "")) != "review" and m.gov_month > int(com.get("due", 8))

func months_left(com: Dictionary) -> int:
	return int(com.get("due", 8)) - m.gov_month

func state_name(com: Dictionary) -> String:
	return str(STATE_NAMES.get(state_of(com), "—"))

func category_name(com: Dictionary) -> String:
	return str(Rules.TABLE_CATEGORIES.get(str(com.get("category", "politicas")), {"name": "Políticas"})["name"])

# ---------------------------------------------------------------- condiciones del acuerdo (términos de la mesa)
## Los términos nuevos se guardan en la oferta del socio; el resto de la mesa ya tenía su sitio (voto, carteras, medidas).
func extract_extra(table: Array) -> Array:
	var out: Array = []
	for t in table:
		var d: Dictionary = t
		if str(d.get("k", "")) in ["structure", "portfolio", "objective", "territory", "budget", "parliament", "institution", "calendar"]:
			out.append(d.duplicate(true))
	return out

func type_of_offer(offer: Dictionary) -> String:
	if str(offer.get("role", "external")) == "cabinet":
		return "coalicion"
	return "abstencion" if str(offer.get("vote", "yes")) == "abstain" else "externo"

## ¿Da algo el presidente al socio (cartera, partidas, objetivos que beneficia al socio…)? Si no, es el socio quien lo asume.
func president_side(term: Dictionary, as_partner: bool) -> bool:
	var by_player := str(term.get("by", "player")) == "player"
	return by_player != as_partner

func _gov_id() -> String:
	return str(m.s.get("government_party_id", m.gov.candidate_id()))

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

## Especificación de un compromiso a partir de un término. Devuelve {} si el término no genera seguimiento por sí mismo.
func spec_for_term(term: Dictionary, key: String, as_partner: bool, deadline: int = 0) -> Dictionary:
	var k := str(term.get("k", ""))
	var pres := president_side(term, as_partner)
	var who := m.party_short(key)
	var text := _cap(m.brain.term_text(term))
	var spec := {"kind": k, "category": str(KIND_CATEGORY.get(k, "politicas")), "ref": term.duplicate(true), "owed_to": key if pres else _gov_id(),
		"binding": "binding", "months": 12, "verify": {"t": "manual"}, "text": text, "pres": pres}
	match k:
		"portfolio":
			var cid := str(term.get("comp", ""))
			spec["text"] = "Cartera de %s para %s" % [Competencies.name_of(cid), who]
			spec["binding"] = "red_line" if bool(Competencies.by_id(cid).get("essential", false)) else "binding"
			spec["months"] = 2
			spec["verify"] = {"t": "portfolio", "comp": cid, "party": key}
		"structure":
			var what := str(term.get("what", "coordination"))
			spec["months"] = 2
			match what:
				"vicepresidency":
					spec["text"] = "Una vicepresidencia del Gobierno para %s" % who
					spec["binding"] = "red_line"
					spec["verify"] = {"t": "vice", "party": key}
				"max_ministries":
					spec["text"] = "Un Gobierno de %d ministerios como máximo" % int(term.get("n", 14))
					spec["verify"] = {"t": "max", "n": int(term.get("n", 14))}
				"min_ministries":
					spec["text"] = "Un Gobierno de al menos %d ministerios" % int(term.get("n", 12))
					spec["verify"] = {"t": "min", "n": int(term.get("n", 12))}
				_:
					spec["text"] = "Órgano de coordinación del Gobierno con %s" % who
					spec["binding"] = "soft"
					spec["months"] = 48
					spec["verify"] = {"t": "meeting", "party": key}
		"objective":
			var issue := str(term.get("issue", "jobs"))
			var lv := int(term.get("level", 1))
			spec["binding"] = "objective"
			spec["months"] = 12 + 6 * lv
			spec["verify"] = _metric_verify(issue, lv)
		"territory":
			var tw := str(term.get("what", "invest"))
			var tn := int(term.get("n", 1))
			spec["binding"] = "binding"
			spec["months"] = 15 + 3 * tn
			var tm: Array = TERRITORY_METRIC.get(tw, TERRITORY_METRIC["invest"])
			spec["verify"] = {"t": "metric", "metric": str(tm[0]), "dir": int(tm[1]), "delta": float(tm[2]) * float(tn), "hold": false}
		"budget":
			var bissue := str(term.get("issue", "jobs"))
			var line := line_for_issue(bissue)
			spec["binding"] = "binding"
			spec["months"] = 3
			if line != "":
				spec["verify"] = {"t": "credit", "line": line, "n": int(term.get("n", 1))}
			else:
				spec["verify"] = {"t": "manual", "cost": float(MANUAL_COST["budget"])}
		"parliament":
			spec["binding"] = "soft"
			spec["verify"] = {"t": "manual", "cost": float(MANUAL_COST["parliament"])}
		"institution":
			spec["binding"] = "binding" if str(term.get("what", "")) == "reform" else "soft"
			spec["months"] = 18
			spec["verify"] = {"t": "manual", "cost": float(MANUAL_COST["institution"]) + (1.0 if str(term.get("what", "")) == "reform" else 0.0)}
		"calendar":
			var cw := str(term.get("what", "review"))
			if cw != "review":
				return {}
			spec["text"] = "Revisión del acuerdo con %s cada %d meses" % [who, int(term.get("n", 6))]
			spec["binding"] = "soft"
			spec["months"] = 48
			spec["verify"] = {"t": "review", "every": int(term.get("n", 6)), "next": m.gov_month + int(term.get("n", 6)), "count": 0}
		_:
			return {}
	if deadline > 0 and str(spec["verify"].get("t", "")) in ["metric", "credit", "manual"]:
		spec["months"] = deadline
	return spec

func _metric_verify(issue: String, level: int) -> Dictionary:
	var om: Array = OBJECTIVE_METRIC.get(issue, OBJECTIVE_METRIC["jobs"])
	var dirn := int(om[1])
	var delta := float(om[2]) * float(level) - float(om[3])
	return {"t": "metric", "metric": str(om[0]), "dir": dirn, "delta": delta, "hold": float(om[3]) > 0.0 and level == 1}

func line_for_issue(issue: String) -> String:
	for c in Competencies.catalog():
		var cd: Dictionary = c
		if str(cd.get("line", "")) != "" and str(PartyBrain.AREA_ISSUE.get(str(cd.get("area", "")), "")) == issue:
			return str(cd["line"])
	return ""

## Compromisos que nacen de la oferta de un socio: las condiciones nuevas más las carteras en número pactadas.
func specs_for_offer(key: String, offer: Dictionary) -> Array:
	var out: Array = []
	var as_partner := m.is_player(key)
	var deadline := 0
	for t in offer.get("terms_extra", []):
		var d: Dictionary = t
		if str(d.get("k", "")) == "calendar" and str(d.get("what", "")) == "deadline":
			deadline = int(d.get("n", 12))
	var claims := int(m.d("cabinet_claims").get(key, 0))
	if claims > 0 and str(offer.get("role", "external")) == "cabinet":
		out.append({"kind": "cabinet", "category": "carteras", "ref": {"k": "cabinet", "n": claims, "by": "ai" if as_partner else "player"}, "owed_to": key,
			"binding": "binding", "months": 2, "verify": {"t": "cabinet_n", "party": key, "n": claims}, "pres": true,
			"text": "%d %s para %s" % [claims, "cartera" if claims == 1 else "carteras", m.party_short(key)]})
	for t2 in offer.get("terms_extra", []):
		var spec := spec_for_term(t2 as Dictionary, key, as_partner, deadline)
		if not spec.is_empty():
			out.append(spec)
	return out

# ---------------------------------------------------------------- Consejo de Ministros: reclamaciones y límites
func _party_entries(party: String) -> Array:
	var out: Array = []
	for i in range(m.cab.size()):
		if str(m.cab.entry(i).get("party", "")) == party:
			out.append(i)
	return out

func _offers_to_honour() -> Dictionary:
	var out: Dictionary = {}
	var gps := m.gov.government_parties()
	for key in m.gov.offers().keys():
		var offer: Dictionary = m.gov.offers()[key]
		if str(offer.get("status", "")) == "accepted" and gps.has(str(key)) and str(key) != _gov_id():
			out[str(key)] = offer
	return out

## Límites de ministerios pactados (ninguna cifra supera 8–20, que son los límites del juego).
func cabinet_limits() -> Dictionary:
	var lo := Competencies.MIN_MINISTRIES
	var hi := Competencies.MAX_MINISTRIES
	var by_lo := ""
	var by_hi := ""
	for st_ref in _structural_refs():
		var r: Dictionary = st_ref
		if str(r["what"]) == "max_ministries" and int(r["n"]) < hi:
			hi = int(r["n"])
			by_hi = str(r["party"])
		elif str(r["what"]) == "min_ministries" and int(r["n"]) > lo:
			lo = int(r["n"])
			by_lo = str(r["party"])
	if lo > hi:
		lo = hi
	return {"min": clampi(lo, Competencies.MIN_MINISTRIES, Competencies.MAX_MINISTRIES), "max": clampi(hi, Competencies.MIN_MINISTRIES, Competencies.MAX_MINISTRIES), "min_by": by_lo, "max_by": by_hi}

## Referencias estructurales vivas: en legislatura salen de los compromisos; antes, de las ofertas aceptadas.
func _structural_refs() -> Array:
	var out: Array = []
	if m.phase == "legislature":
		for c in list():
			var com: Dictionary = c
			if not is_active(com) or str(com.get("kind", "")) != "structure":
				continue
			var ref: Dictionary = com.get("ref", {})
			out.append({"what": str(ref.get("what", "")), "n": int(ref.get("n", 0)), "party": str(com.get("party", "")), "agr": int(com.get("agreement_id", 0))})
		return out
	for key in _offers_to_honour().keys():
		for t in (_offers_to_honour()[key] as Dictionary).get("terms_extra", []):
			var d: Dictionary = t
			if str(d.get("k", "")) == "structure":
				out.append({"what": str(d.get("what", "")), "n": int(d.get("n", 0)), "party": str(key), "agr": int((_offers_to_honour()[key] as Dictionary).get("agreement_id", 0))})
	return out

## Texto de bloqueo si añadir o quitar un ministerio incumpliría un límite pactado; "" si se puede.
func size_block(adding: bool) -> String:
	var lim := cabinet_limits()
	if adding and m.cab.size() >= int(lim["max"]) and str(lim["max_by"]) != "":
		return "El acuerdo con %s limita el Gobierno a %d ministerios: hace falta renegociarlo." % [m.party_short(str(lim["max_by"])), int(lim["max"])]
	if not adding and m.cab.size() <= int(lim["min"]) and str(lim["min_by"]) != "":
		return "El acuerdo con %s exige al menos %d ministerios: hace falta renegociarlo." % [m.party_short(str(lim["min_by"])), int(lim["min"])]
	return ""

## Texto de bloqueo si la cartera está comprometida con un socio (cartera concreta o vicepresidencia); "" si no.
func pledge_text(idx: int) -> String:
	var e := m.cab.entry(idx)
	if e.is_empty():
		return ""
	var party := str(e.get("party", ""))
	var comps: Array = m.cab.comps_of(idx)
	if m.phase == "legislature":
		for c in list():
			var com: Dictionary = c
			if not is_active(com):
				continue
			var vf: Dictionary = com.get("verify", {})
			if str(vf.get("t", "")) == "portfolio" and str(vf.get("party", "")) == party and comps.has(str(vf.get("comp", ""))):
				return "Está pactada con %s (%s): no se puede retirar sin renegociar." % [m.party_short(party), str(com.get("text", ""))]
			if str(vf.get("t", "")) == "vice" and str(vf.get("party", "")) == party and str(e.get("rank", "")) == "vice":
				return "Lleva la vicepresidencia pactada con %s: no se puede retirar sin renegociar." % m.party_short(party)
		return ""
	var offers := _offers_to_honour()
	if offers.has(party):
		for t in (offers[party] as Dictionary).get("terms_extra", []):
			var d: Dictionary = t
			if str(d.get("k", "")) == "portfolio" and comps.has(str(d.get("comp", ""))):
				return "Se la prometiste a %s en la mesa: no puedes quitársela." % m.party_short(party)
			if str(d.get("k", "")) == "structure" and str(d.get("what", "")) == "vicepresidency" and str(e.get("rank", "")) == "vice":
				return "Lleva la vicepresidencia que le prometiste a %s." % m.party_short(party)
	return ""

## Materializa en el constructor lo pactado: límites de tamaño, carteras concretas y vicepresidencias. Se llama al abrir el diseño del Consejo.
func apply_to_cabinet() -> void:
	m.cab.ensure()
	var offers := _offers_to_honour()
	var lim := cabinet_limits()
	var size := clampi(int(m.s.get("cabinet_size", 12)), int(lim["min"]), int(lim["max"]))
	if size != int(m.s.get("cabinet_size", size)):
		m.s["cabinet_size"] = size
		m.gov._grow_cabinet(size)
		m.cab.ensure()
	for key in offers.keys():
		var offer: Dictionary = offers[key]
		for t in offer.get("terms_extra", []):
			var d: Dictionary = t
			if str(d.get("k", "")) == "portfolio":
				_give_portfolio(str(key), str(d.get("comp", "")), int(offer.get("agreement_id", 0)))
	for key2 in offers.keys():
		for t2 in (offers[key2] as Dictionary).get("terms_extra", []):
			var d2: Dictionary = t2
			if str(d2.get("k", "")) == "structure" and str(d2.get("what", "")) == "vicepresidency":
				_give_vice(str(key2))
	m.ministers.ensure_cabinet()

## La cartera que gestiona la competencia pasa al socio: entera si es estrecha; si no, se crea una cartera propia con esa competencia.
func _give_portfolio(party: String, comp: String, agr: int) -> void:
	var owner := m.cab.owner_of(comp)
	if owner >= 0 and str(m.cab.entry(owner).get("party", "")) == party:
		return
	var other := m.cab.entry(owner) if owner >= 0 else {}
	var narrow := owner > 0 and m.cab.comps_of(owner).size() <= 2
	if narrow and str(other.get("party", "")) == _gov_id():
		m.cab.assign_party(owner, party, true)
		m.cab.entry(owner)["claim"] = agr
		return
	if m.cab.size() < int(cabinet_limits()["max"]):
		if owner >= 0:
			m.cab.comps_of(owner).erase(comp)
		var id := m.cab._next_id()
		m.cab.list().append({"id": id, "name": Competencies.suggest_name([comp]), "key": "custom:" + id, "party": party, "desc": "", "comps": [comp], "shared": [], "autonomy": "plena", "claim": agr})
		return
	if owner > 0:
		m.cab.assign_party(owner, party, true)
		m.cab.entry(owner)["claim"] = agr

## La vicepresidencia es un rango de una cartera real del socio, no un cargo suelto: la que más peso tiene entre las suyas.
func _give_vice(party: String) -> void:
	var best := -1
	var best_score := -1.0
	for i in _party_entries(party):
		var e := m.cab.entry(int(i))
		if str(e.get("rank", "")) == "vice":
			return
		var score := float(m.cab.comps_of(int(i)).size())
		for c in m.cab.comps_of(int(i)):
			if bool(Competencies.by_id(str(c)).get("essential", false)):
				score += 2.0
		if score > best_score:
			best_score = score
			best = int(i)
	if best >= 0:
		var n := 1
		for e2 in m.cab.list():
			if str((e2 as Dictionary).get("rank", "")) == "vice":
				n += 1
		var ed := m.cab.entry(best)
		ed["rank"] = "vice"
		ed["vice_n"] = n

## Nombre con el rango: «Vicepresidencia 1.ª · Vivienda».
func ministry_label(idx: int) -> String:
	var e := m.cab.entry(idx)
	if str(e.get("rank", "")) == "vice":
		return "Vicepresidencia %d.ª · %s" % [int(e.get("vice_n", 1)), str(e.get("name", ""))]
	return str(e.get("name", ""))

## Antes de constituir el Gobierno: todo lo prometido en el constructor tiene que estar. Devuelve {ok, error}.
func validate_formation() -> Dictionary:
	for key in _offers_to_honour().keys():
		var offer: Dictionary = _offers_to_honour()[key]
		for sp in specs_for_offer(str(key), offer):
			var spec: Dictionary = sp
			if not (str(spec["verify"].get("t", "")) in ["portfolio", "vice", "cabinet_n", "max", "min"]):
				continue
			var v := _verify_spec(spec["verify"] as Dictionary)
			if not bool(v["done"]):
				return {"ok": false, "error": "Lo pactado con %s no está en el Consejo: %s. %s" % [m.party_short(str(key)), str(spec["text"]).to_lower(), str(v.get("note", ""))]}
	return {"ok": true}

# ---------------------------------------------------------------- creación de compromisos
func _responsible(spec: Dictionary, key: String) -> Dictionary:
	var kind := str(spec.get("kind", ""))
	if kind in ["objective", "budget"]:
		var area := _area_ministry(str((spec.get("ref", {}) as Dictionary).get("issue", "")))
		if not area.is_empty():
			return area
	var pid := _gov_id() if bool(spec.get("pres", true)) else key
	return {"kind": "party", "id": pid, "name": m.party_short(pid)}

func _area_ministry(issue: String) -> Dictionary:
	if issue == "":
		return {}
	var comp := ""
	for c in Competencies.catalog():
		var cd: Dictionary = c
		if str(PartyBrain.AREA_ISSUE.get(str(cd.get("area", "")), "")) == issue and str(cd.get("area", "")) != "":
			comp = str(cd["id"])
			break
	if comp == "":
		return {}
	var idx := m.cab.owner_of(comp)
	if idx < 0:
		return {}
	return {"kind": "ministry", "id": str(m.cab.entry(idx).get("id", "")), "name": str(m.cab.entry(idx).get("name", "")), "party": str(m.cab.entry(idx).get("party", ""))}

func make_commitment(spec: Dictionary, key: String, agr: int, type: String) -> Dictionary:
	var vf: Dictionary = (spec["verify"] as Dictionary).duplicate(true)
	if str(vf.get("t", "")) == "metric":
		vf["base"] = _read_metric(str(vf["metric"]))
		vf["target"] = float(vf["base"]) + float(vf["dir"]) * float(vf["delta"])
	var gid := _gov_id()
	var parties: Array = [gid]
	if key != gid:
		parties.append(key)
	var com := {
		"id": _next_commit_id(), "agreement_id": agr, "party": key, "parties": parties, "type": type, "kind": str(spec["kind"]), "category": str(spec["category"]),
		"issue": "agr:%s" % str(spec["kind"]), "text": str(spec["text"]), "binding": str(spec["binding"]), "responsible": _responsible(spec, key),
		"due": m.gov_month + int(spec["months"]), "state": "pending", "fulfilled": false, "overdue_flagged": false, "progress": 0.0,
		"source": "acuerdo", "scope": str(spec["category"]), "verify": vf, "ref": spec.get("ref", {}), "pres": bool(spec.get("pres", true)),
		"consequence": _consequence(str(spec["binding"]), bool(spec.get("pres", true)), key),
		"history": [{"turn": m.turn(), "text": "Pactado en la mesa."}]
	}
	list().append(com)
	return com

func _consequence(binding: String, pres: bool, key: String) -> String:
	var who := m.party_short(key)
	if not pres:
		return "Si %s no lo cumple, se resiente la relación y se debilita su apoyo." % who
	match binding:
		"red_line": return "Línea roja de %s: incumplirla le hace perder mucha confianza y puede llevarle a una crisis de coalición." % who
		"binding": return "Compromiso vinculante: si vence sin cumplirse, %s pierde confianza y exige explicaciones." % who
		"objective": return "Objetivo pactado: no cumplirlo erosiona la confianza de %s, aunque menos que romper un compromiso." % who
	return "Concesión no vinculante: no cumplirla cuesta poca confianza, pero queda en la memoria de %s." % who

## Al constituirse el Gobierno: convierte en compromisos lo aceptado en la investidura (políticas, carteras, estructura, objetivos…).
func on_government_formed() -> void:
	ensure()
	var gid := _gov_id()
	for c in list():
		var com: Dictionary = c
		if str(com.get("source", "")) != "acuerdo" and int(com.get("agreement_id", 0)) == 0:
			var offer: Dictionary = m.gov.offers().get(str(com.get("party", "")), {})
			com["agreement_id"] = int(offer.get("agreement_id", 0))
			com["type"] = type_of_offer(offer)
			com["responsible"] = {"kind": "party", "id": gid, "name": m.party_short(gid)}
	for key in m.gov.offers().keys():
		var offer2: Dictionary = m.gov.offers()[key]
		if str(offer2.get("status", "")) != "accepted":
			continue
		var type := str(offer2.get("type", type_of_offer(offer2)))
		var agr := int(offer2.get("agreement_id", 0))
		for sp in specs_for_offer(str(key), offer2):
			_start_commitment(sp as Dictionary, str(key), agr, type, false)

func _start_commitment(spec: Dictionary, key: String, agr: int, type: String, announce: bool) -> void:
	var com := make_commitment(spec, key, agr, type)
	var vf: Dictionary = com["verify"]
	if str(vf.get("t", "")) == "credit":
		_apply_credit(com)
	var v := _verify(com)
	if bool(v["done"]) and str(vf.get("t", "")) in ["portfolio", "vice", "cabinet_n", "max", "min", "credit"]:
		set_state(com, "fulfilled", "Materializado: %s." % str(v.get("note", "ya figura en el Consejo")))
	else:
		com["progress"] = float(v.get("progress", 0.0))
		set_state(com, "in_progress" if float(v.get("progress", 0.0)) > 0.0 or str(vf.get("t", "")) in ["review", "meeting"] else "pending")
	if announce:
		m.publish("Compromiso con %s" % m.party_short(key), "%s. Plazo: %d meses." % [str(com["text"]), maxi(0, int(com["due"]) - m.gov_month)], "NEGOCIACIONES", "neutral", {"key": "commit_%d" % int(com["id"])})

## Pactos de la legislatura (estabilidad, leyes…): lo que traen de nuevo también se vigila.
func register_pact(party: String, topic: String, table: Array, pact_id: int) -> void:
	if not (topic in ["stability", "bills", "relationship"]) or m.phase != "legislature":
		return
	var extra := extract_extra(table)
	if extra.is_empty():
		return
	var deadline := 0
	for t in extra:
		if str((t as Dictionary).get("k", "")) == "calendar" and str((t as Dictionary).get("what", "")) == "deadline":
			deadline = int((t as Dictionary).get("n", 12))
	var type := "externo" if topic == "stability" else ("puntual" if topic == "bills" else "otro")
	var in_gov := m.gov.government_parties().has(party)
	for t2 in extra:
		var td: Dictionary = t2
		var spec := spec_for_term(td, party, false, deadline)
		if spec.is_empty():
			continue
		# Una cartera o vicepresidencia solo se puede dar a quien ya está en el Consejo; si no, queda como intención no vinculante.
		if str(spec["kind"]) in ["portfolio"] or (str(spec["kind"]) == "structure" and str(td.get("what", "")) == "vicepresidency"):
			if not in_gov:
				spec["binding"] = "soft"
				spec["verify"] = {"t": "manual", "cost": 2.0}
				spec["text"] = "%s (si entra en el Gobierno)" % str(spec["text"])
		_start_commitment(spec, party, pact_id, type, true)

# ---------------------------------------------------------------- verificación
func _read_metric(metric: String) -> float:
	if metric == "tax_pressure":
		return m.eco.revenue_total() / maxf(1.0, m.eco.gdp()) * 100.0
	return m.exec._metric_now(metric)

func metric_label(metric: String) -> String:
	if metric == "tax_pressure":
		return "Presión fiscal (% PIB)"
	return m.exec.metric_label(metric)

func _verify(com: Dictionary) -> Dictionary:
	var vf: Dictionary = com.get("verify", {})
	if str(vf.get("t", "")) == "metric":
		return _verify_metric(com, vf)
	return _verify_spec(vf, com)

func _verify_metric(com: Dictionary, vf: Dictionary) -> Dictionary:
	var base := float(vf.get("base", 0.0))
	var target := float(vf.get("target", base))
	var cur := _read_metric(str(vf["metric"]))
	var dirn := float(vf.get("dir", 1))
	var span := absf(target - base)
	var gained := (cur - base) * dirn
	var prog := clampf(gained / span, 0.0, 1.0) if span > 0.0001 else 1.0
	var reached := (cur - target) * dirn >= -0.0001
	if bool(vf.get("hold", false)):
		# «No subir»: se juzga al vencer el plazo, no antes.
		var ok := (cur - base) * dirn >= -0.2
		return {"done": ok and m.gov_month >= int(com.get("due", 99)), "progress": 0.5 if ok else 0.0, "note": "%s: %.1f (al pactar, %.1f)." % [metric_label(str(vf["metric"])), cur, base]}
	return {"done": reached, "progress": prog, "note": "%s: %.1f; meta %.1f (al pactar, %.1f)." % [metric_label(str(vf["metric"])), cur, target, base]}

## Verificación de las reglas estructurales (también sirve antes de constituir el Gobierno, cuando aún no existe el compromiso).
func _last_meet(key: String) -> int:
	m.coal.ensure()
	return int((m.coal.st().get("meet", {}) as Dictionary).get(key, -9))

func _verify_spec(vf: Dictionary, com: Dictionary = {}) -> Dictionary:
	match str(vf.get("t", "")):
		"portfolio":
			var idx := m.cab.owner_of(str(vf["comp"]))
			if idx < 0:
				return {"done": false, "progress": 0.0, "note": "Ningún ministerio gestiona esa competencia."}
			var holder := str(m.cab.entry(idx).get("party", ""))
			return {"done": holder == str(vf["party"]), "progress": 1.0 if holder == str(vf["party"]) else 0.0, "note": "La gestiona «%s» (%s)." % [str(m.cab.entry(idx).get("name", "")), m.party_short(holder)]}
		"vice":
			for i in _party_entries(str(vf["party"])):
				if str(m.cab.entry(int(i)).get("rank", "")) == "vice":
					return {"done": true, "progress": 1.0, "note": "Vicepresidencia en «%s»." % str(m.cab.entry(int(i)).get("name", ""))}
			return {"done": false, "progress": 0.0, "note": "Ninguna cartera suya tiene rango de vicepresidencia."}
		"cabinet_n":
			var have := _party_entries(str(vf["party"])).size()
			return {"done": have >= int(vf["n"]), "progress": clampf(float(have) / float(maxi(1, int(vf["n"]))), 0.0, 1.0), "note": "Tiene %d de %d carteras." % [have, int(vf["n"])]}
		"max":
			var ok := m.cab.size() <= int(vf["n"])
			return {"done": ok, "progress": 1.0 if ok else 0.0, "note": "Hay %d ministerios (máximo pactado %d)." % [m.cab.size(), int(vf["n"])]}
		"min":
			var ok2 := m.cab.size() >= int(vf["n"])
			return {"done": ok2, "progress": 1.0 if ok2 else 0.0, "note": "Hay %d ministerios (mínimo pactado %d)." % [m.cab.size(), int(vf["n"])]}
		"credit":
			var cur := m.exec.credit_delta(str(vf["line"]))
			var want := float(vf.get("to", 0.0))
			return {"done": cur >= want - 0.0001, "progress": 1.0 if cur >= want - 0.0001 else 0.0, "note": "Crédito de la partida: %+.0f %%." % (cur * 100.0)}
		"meeting":
			var last := _last_meet(str(vf["party"]))
			return {"done": false, "progress": 1.0 if m.turn() - last <= 2 else 0.0, "note": "Última reunión: %s." % ("hace %d trimestres" % (m.turn() - last) if last >= 0 else "ninguna")}
	return {"done": false, "progress": float(com.get("progress", 0.0)), "note": ""}

func _apply_credit(com: Dictionary) -> void:
	var vf: Dictionary = com["verify"]
	var line := str(vf["line"])
	m.exec.ensure()
	var p := m.exec.pge()
	if not p.has("adjust"):
		p["adjust"] = {}
	var adj: Dictionary = p["adjust"]
	var nv := snappedf(clampf(float(adj.get(line, 0.0)) + Coalition.CREDIT_STEP * float(vf.get("n", 1)), -0.10, 0.15), 0.0005)
	adj[line] = nv
	vf["to"] = nv
	m.eco._compute_fiscal()
	m.eco._compute_composition()

# ---------------------------------------------------------------- seguimiento mensual
func tick() -> void:
	if m.phase != "legislature":
		return
	ensure()
	for c in list():
		var com: Dictionary = c
		if str(com.get("source", "")) != "acuerdo" and not com.has("verify"):
			_tick_legacy(com)
			continue
		if not is_active(com) and str(com["state"]) != "breached":
			continue
		var vf: Dictionary = com.get("verify", {})
		var t := str(vf.get("t", ""))
		if t == "review":
			_tick_review(com)
			continue
		if t == "meeting":
			_tick_meeting(com)
			continue
		var v := _verify(com)
		com["progress"] = float(v.get("progress", 0.0))
		if bool(v["done"]):
			_fulfil(com, "Cumplido. %s" % str(v.get("note", "")))
			continue
		if t == "manual" and m.gov_month >= int(com["due"]):
			_resolve_manual(com)
			continue
		if m.gov_month > int(com["due"]) and str(com["state"]) != "breached":
			_breach(com, "Vence el plazo sin cumplirse. %s" % str(v.get("note", "")))
		elif str(com["state"]) == "pending" and float(com["progress"]) > 0.0:
			set_state(com, "in_progress")

## Compromisos antiguos o de la mesa de coalición: solo se ordena su estado a partir de lo que ya hacía el juego.
func _tick_legacy(com: Dictionary) -> void:
	if bool(com.get("fulfilled", false)):
		set_state(com, "fulfilled", "Cumplido.")
	elif m.gov_month > int(com.get("due", 8)):
		set_state(com, "breached", "Vence el plazo sin cumplirse.")
	elif str(com.get("measure", "")) != "":
		if m.gov._measure_done(com):
			set_state(com, "fulfilled", "Cumplido.")
		else:
			set_state(com, "in_progress")

func _fulfil(com: Dictionary, text: String) -> void:
	var late := str(com["state"]) == "breached"
	set_state(com, "fulfilled", text + (" (con retraso)" if late else ""))
	var key := str(com.get("party", ""))
	var gain := 2.0 if late else 4.0
	if bool(com.get("pres", true)):
		m.coal.shift_trust(key, gain, "se cumple: %s" % str(com.get("text", "")))
		m.ai.change_relation(key, gain * 0.6)
	m.publish("Se cumple un compromiso con %s" % m.party_short(key), "%s." % str(com.get("text", "")), "GOBIERNO", "positive", {"key": "commit_ok_%d" % int(com["id"]), "read": true})

func _breach(com: Dictionary, text: String) -> void:
	set_state(com, "breached", text)
	com["overdue_flagged"] = true
	var key := str(com.get("party", ""))
	var sev := float(BREACH_SEVERITY.get(str(com.get("binding", "binding")), 4.0))
	var resolution := _has_resolution(key)
	if resolution:
		sev *= 0.5
	if bool(com.get("pres", true)):
		m.coal.shift_trust(key, -sev, "incumplimiento: %s" % str(com.get("text", "")))
		m.coal.add_cause(key, "Incumplido: %s" % str(com.get("text", "")))
		if str(com.get("binding", "")) in ["red_line", "binding"]:
			(m.coal.st()["breach"] as Dictionary)[key] = m.turn()
		m.ai.change_relation(key, -sev * 0.5)
		m.coal._log("%s denuncia un incumplimiento: %s%s." % [m.party_short(key), str(com.get("text", "")), " (se activa el mecanismo de resolución)" if resolution else ""], key)
		m.publish("%s denuncia un incumplimiento" % m.party_short(key), "%s. %s" % [str(com.get("text", "")), str(com.get("consequence", ""))], "NEGOCIACIONES", "warning", {"key": "commit_bad_%d" % int(com["id"])})
	else:
		m.ai.change_relation(key, -3.0)
		m.publish("%s no cumple lo pactado" % m.party_short(key), "%s." % str(com.get("text", "")), "NEGOCIACIONES", "warning", {"key": "commit_bad_%d" % int(com["id"])})

func _has_resolution(key: String) -> bool:
	for c in list():
		var com: Dictionary = c
		if str(com.get("party", "")) == key and is_active(com) and str((com.get("ref", {}) as Dictionary).get("what", "")) == "resolution":
			return true
	return false

func _tick_review(com: Dictionary) -> void:
	var vf: Dictionary = com["verify"]
	if str(com["state"]) == "pending":
		set_state(com, "in_progress")
	if m.gov_month < int(vf.get("next", 99)):
		return
	vf["next"] = m.gov_month + int(vf.get("every", 6))
	vf["count"] = int(vf.get("count", 0)) + 1
	var key := str(com.get("party", ""))
	var ok := m.coal.trust(key) >= 45.0
	m.coal.shift_trust(key, 1.0 if ok else -1.0, "revisión periódica del acuerdo")
	m.coal._log("Revisión del acuerdo con %s: %s." % [m.party_short(key), "sin sobresaltos" if ok else "reproches por lo pendiente"], key)
	_log(com, "Revisión %d: %s." % [int(vf["count"]), "sin sobresaltos" if ok else "reproches por lo pendiente"])
	com["progress"] = clampf(float(m.gov_month) / 48.0, 0.0, 1.0)

func _tick_meeting(com: Dictionary) -> void:
	var key := str(com.get("party", ""))
	var last := _last_meet(key)
	if str(com["state"]) == "pending":
		set_state(com, "in_progress")
	if _gov_id() != m.pid():
		return
	var lapsed := m.turn() - last > 3
	if lapsed and int(com.get("lapse_turn", -9)) < m.turn() - 3:
		com["lapse_turn"] = m.turn()
		set_state(com, "breached", "No se reúne el órgano de coordinación desde hace más de tres trimestres.")
		m.coal.shift_trust(key, -1.5, "el órgano de coordinación no se reúne")
	elif not lapsed and str(com["state"]) == "breached":
		set_state(com, "in_progress", "Se retoma la coordinación.")
	com["progress"] = 0.0 if lapsed else 1.0

## Lo que no se puede medir lo decide quien gobierna: el jugador lo cumple pagando capital político; la IA, según su fiabilidad.
func _resolve_manual(com: Dictionary) -> void:
	if bool(com.get("pres", true)) and _gov_id() == m.pid():
		if str(com["state"]) != "breached":
			_breach(com, "Vence el plazo sin cumplirse (puedes cumplirlo todavía desde Compromisos).")
		return
	var key := str(com.get("party", ""))
	var resp := str((com.get("responsible", {}) as Dictionary).get("id", _gov_id()))
	var rel := float(m.brain.trait_of(resp, "reliability")) if resp != "" and not m.is_player(resp) else 0.6
	var roll := m.rng.randf()
	if roll < clampf(0.35 + 0.45 * rel + 0.2 * (m.coal.trust(key) / 100.0), 0.1, 0.95):
		_fulfil(com, "%s cumple lo pactado." % m.party_short(resp))
	else:
		_breach(com, "%s no cumple lo pactado." % m.party_short(resp))

# ---------------------------------------------------------------- acciones del jugador
func index_of(com: Dictionary) -> int:
	return list().find(com)

func can_fulfil(com: Dictionary) -> String:
	if not is_active(com) and str(com.get("state", "")) != "breached":
		return "Ya no está vigente."
	if str((com.get("verify", {}) as Dictionary).get("t", "")) != "manual":
		return "Se comprueba sola: se da por cumplido cuando se cumple de verdad."
	if _gov_id() != m.pid() or not bool(com.get("pres", true)):
		return "Solo lo puede cumplir quien gobierna."
	if m.phase != "legislature":
		return "Solo durante la legislatura."
	return ""

func manual_cost(com: Dictionary) -> float:
	return float((com.get("verify", {}) as Dictionary).get("cost", 2.0))

## Cumples a mano un compromiso no medible (presidencia de comisión, nombramiento, reforma…): cuesta capital político.
func fulfil(index: int) -> Dictionary:
	var l := list()
	if index < 0 or index >= l.size():
		return {"ok": false, "error": "Compromiso inexistente."}
	var com: Dictionary = l[index]
	var why := can_fulfil(com)
	if why != "":
		return {"ok": false, "error": why}
	m.exec.ensure()
	var cost := manual_cost(com)
	if m.exec.capital() < cost:
		return {"ok": false, "error": "Capital político insuficiente (%d necesario)." % int(ceilf(cost))}
	m.exec.add_capital(-cost)
	_fulfil(com, "Cumplido por el Gobierno (coste %d de capital político)." % int(ceilf(cost)))
	return {"ok": true, "text": "Compromiso cumplido: %s." % str(com.get("text", ""))}

## Pides al socio que te libere de lo pactado. Acepta o no según confianza y afinidad; si acepta, queda «Renegociado».
func renegotiate(index: int) -> Dictionary:
	var l := list()
	if index < 0 or index >= l.size():
		return {"ok": false, "error": "Compromiso inexistente."}
	var com: Dictionary = l[index]
	if not is_active(com) and str(com.get("state", "")) != "breached":
		return {"ok": false, "error": "Ya no está vigente."}
	if _gov_id() != m.pid():
		return {"ok": false, "error": "Solo quien gobierna puede pedir renegociar."}
	var key := str(com.get("party", ""))
	var score := 0.15 + (m.coal.trust(key) - 50.0) / 100.0 * 0.6 + m.ai.affinity(m.pid(), key) * 0.25 + m.brain.trait_of(key, "pragmatism") * 0.20 - 0.08 * float(float(BREACH_SEVERITY.get(str(com.get("binding", "binding")), 4.0)) / 6.0)
	if score >= 0.45:
		set_state(com, "renegotiated", "%s acepta renegociarlo." % m.party_short(key))
		m.coal.shift_trust(key, -1.0, "renegocia un compromiso")
		m.coal._log("Se renegocia con %s: %s." % [m.party_short(key), str(com.get("text", ""))], key)
		return {"ok": true, "text": "%s acepta renegociar: «%s» queda sin efecto." % [m.party_short(key), str(com.get("text", ""))]}
	m.coal.shift_trust(key, -1.5, "se niega a renegociar y le molesta que se pida")
	_log(com, "%s se niega a renegociarlo." % m.party_short(key))
	return {"ok": false, "error": "%s se niega a liberarte de lo pactado." % m.party_short(key)}

## Lo retiras tú, sin acuerdo: se anota como incumplido y se activan las consecuencias pactadas.
func abandon(index: int) -> Dictionary:
	var l := list()
	if index < 0 or index >= l.size():
		return {"ok": false, "error": "Compromiso inexistente."}
	var com: Dictionary = l[index]
	if _gov_id() != m.pid():
		return {"ok": false, "error": "Solo quien gobierna puede romper un compromiso."}
	if not is_active(com) and str(com.get("state", "")) != "breached":
		return {"ok": false, "error": "Ya no está vigente."}
	com["binding"] = com.get("binding", "binding")
	_breach(com, "Lo retira unilateralmente el Gobierno.")
	com["state"] = "cancelled"
	com["fulfilled"] = false
	return {"ok": true, "text": "Compromiso roto: %s lo recordará." % m.party_short(str(com.get("party", "")))}

# ---------------------------------------------------------------- consulta para las pantallas
func counts() -> Dictionary:
	ensure()
	var out := {"pending": 0, "in_progress": 0, "fulfilled": 0, "breached": 0, "renegotiated": 0, "cancelled": 0}
	for c in list():
		var s := state_of(c as Dictionary)
		out[s] = int(out.get(s, 0)) + 1
	return out

func progress_text(com: Dictionary) -> String:
	var vf: Dictionary = com.get("verify", {})
	match str(vf.get("t", "")):
		"metric":
			var cur := _read_metric(str(vf["metric"]))
			return "%s: %.1f → meta %.1f" % [metric_label(str(vf["metric"])), cur, float(vf.get("target", cur))]
		"manual":
			return "Se cumple a mano (cuesta %d de capital político)" % int(ceilf(manual_cost(com)))
		"review":
			return "%d revisiones hechas" % int(vf.get("count", 0))
		"meeting":
			var last := _last_meet(str(vf.get("party", "")))
			return "Última reunión: %s" % ("hace %d trimestres" % (m.turn() - last) if last >= 0 else "ninguna")
	return str(_verify(com).get("note", ""))

## Última nota de verificación, lista para mostrarla.
func verify_note(com: Dictionary) -> String:
	return str(_verify(com).get("note", ""))
