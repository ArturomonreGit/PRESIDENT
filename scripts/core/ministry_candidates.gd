class_name MinistryCandidates
extends RefCounted
## Cinco candidatos plausibles por cartera (especificación de negociación §8).
## La lista se genera una vez, es persistente (`m.s["cand_sets"]`) y se contextualiza con la cartera: especialidad,
## experiencia, trayectoria y personalidad. Nunca hay un candidato mejor que otro en todo. El jugador elige los de su
## partido; la IA socia elige los suyos de su propia lista según los rasgos de su partido.

var m: GameModel

const SIZE := 5
## Atributos «buenos» (más es mejor). La ambición no cuenta: es una ventaja y un riesgo a la vez.
const GOOD_ATTRS := ["gestion", "lealtad", "afinidad", "popularidad", "experiencia", "comunicacion", "integridad"]
const SHORT := {"gestion": "Gestión", "lealtad": "Lealtad", "afinidad": "Afinidad", "ambicion": "Ambición", "popularidad": "Popularidad", "experiencia": "Experiencia", "comunicacion": "Comunicación", "integridad": "Integridad"}
const ROLE_NAMES := {"specialist": "Especialista", "veteran": "Veterano", "loyal": "De partido", "media": "Figura pública", "independent": "Independiente", "other": "Alternativa"}

func _init(model: GameModel) -> void:
	m = model

func _sets() -> Dictionary:
	if not m.s.has("cand_sets"):
		m.s["cand_sets"] = {}
	return m.s["cand_sets"]

func _next_id() -> int:
	var n := int(m.s.get("cand_seq", 100000))
	m.s["cand_seq"] = n + 1
	return n

func _sig(entry: Dictionary) -> String:
	var comps: Array = (entry.get("comps", []) as Array).duplicate()
	comps.sort()
	return "%d|%s|%s" % [m.cycle, str(entry.get("party", "")), ",".join(comps)]

## ¿Se permiten candidatos independientes? Siempre en las carteras del presidente; en las de un socio solo si el acuerdo lo
## autoriza (aún no existe esa cláusula: pendiente de la entrega G).
func independents_allowed(index: int) -> bool:
	var e := m.cab.entry(index)
	return not e.is_empty() and str(e.get("party", "")) == m.pid()

# ---------------------------------------------------------------- consulta
## Los cinco candidatos de una cartera (el titular actual, si lo hay, es uno de ellos).
func shortlist(index: int) -> Array:
	var e := m.cab.entry(index)
	if e.is_empty():
		return []
	var key := str(e.get("id", e.get("name", "")))
	var sets := _sets()
	var rec: Dictionary = sets.get(key, {})
	var sig := _sig(e)
	var incumbent: Dictionary = e.get("minister", {})
	if rec.is_empty() or str(rec.get("sig", "")) != sig:
		rec = {"sig": sig, "list": _generate(index, e, incumbent)}
		sets[key] = rec
	# Quien ya ocupa otra cartera sale de la lista; se rellena el hueco.
	var list: Array = rec["list"]
	var taken := _taken_elsewhere(index)
	var left: Array = rec.get("left", [])
	var kept: Array = []
	for c in list:
		var cd: Dictionary = c
		if not taken.has(int(cd.get("pool_id", -1))) and not left.has(int(cd.get("pool_id", -1))):
			kept.append(cd)
	if kept.size() < SIZE or (not incumbent.is_empty() and not _has(kept, incumbent)):
		kept = _complete(index, e, kept, incumbent)
		rec["list"] = kept
	return kept

## Quien deja el cargo (cese, dimisión, destitución) no vuelve a salir en la lista de esa cartera.
func retire(index: int, pool_id: int) -> void:
	var e := m.cab.entry(index)
	if e.is_empty():
		return
	var rec: Dictionary = _sets().get(str(e.get("id", e.get("name", ""))), {})
	if rec.is_empty():
		return
	var left: Array = rec.get("left", [])
	if not left.has(pool_id):
		left.append(pool_id)
	rec["left"] = left

func _has(list: Array, ch: Dictionary) -> bool:
	for c in list:
		if int((c as Dictionary).get("pool_id", -1)) == int(ch.get("pool_id", -2)):
			return true
	return false

func _taken_elsewhere(index: int) -> Dictionary:
	var taken: Dictionary = {}
	var cab := m.gov.cabinet()
	for i in range(cab.size()):
		if i == index:
			continue
		var mn: Dictionary = (cab[i] as Dictionary).get("minister", {})
		if not mn.is_empty():
			taken[int(mn.get("pool_id", -1))] = true
	return taken

## Busca un candidato por su pool_id en cualquier lista guardada (para nombrarlo).
func find(pool_id: int) -> Dictionary:
	for k in _sets().keys():
		for c in ((_sets()[k] as Dictionary).get("list", []) as Array):
			if int((c as Dictionary).get("pool_id", -1)) == pool_id:
				return c
	return {}

# ---------------------------------------------------------------- generación
func _generate(index: int, e: Dictionary, incumbent: Dictionary) -> Array:
	return _complete(index, e, [], incumbent)

## Completa la lista hasta cinco con perfiles distintos y sin que ninguno domine a otro.
func _complete(index: int, e: Dictionary, current: Array, incumbent: Dictionary) -> Array:
	var party := str(e.get("party", ""))
	var ministry := str(e.get("name", ""))
	var out: Array = []
	if not incumbent.is_empty():
		m.ministers.ensure_profile(incumbent)
		out.append(incumbent)
	for c in current:
		if not _has(out, c as Dictionary):
			out.append(c)
	var own := party == m.pid()
	var source: Array = _own_source(index, e, out) if own else []
	var roles: Array = ["specialist", "veteran", "loyal", "media", "independent" if independents_allowed(index) else "other"]
	var guard := 0
	var rejected: Array = []
	var ri := 0
	if not incumbent.is_empty() and roles.has(str(incumbent.get("cand_role", ""))):
		ri = roles.find(str(incumbent.get("cand_role", ""))) + 1
	while out.size() < SIZE and guard < 40:
		guard += 1
		var role := str(roles[ri % roles.size()])
		ri += 1
		var cand: Dictionary = _pick(role, source, out + rejected, e) if own else {}
		if cand.is_empty():
			cand = _make(party, role, e, guard)
		if _dominance_conflict(cand, out):
			cand = _soften(cand, out)
			if _dominance_conflict(cand, out):
				rejected.append(cand)
				continue
		if not cand.has("cand_role"):
			cand["cand_role"] = role
		out.append(cand)
	return out

## Candidatos del partido del jugador: la cantera común sin los ya nombrados ni quemados.
func _own_source(index: int, e: Dictionary, chosen: Array) -> Array:
	var taken := _taken_elsewhere(index)
	var rec: Dictionary = _sets().get(str(e.get("id", e.get("name", ""))), {})
	var left: Array = rec.get("left", [])
	var src: Array = []
	for p in m.ministers.pool():
		var pd: Dictionary = p
		if taken.has(int(pd["pool_id"])) or _has(chosen, pd) or left.has(int(pd["pool_id"])):
			continue
		if m.cab.is_burned(int(pd["pool_id"])):
			continue
		src.append(pd)
	return src

func _pick(role: String, source: Array, chosen: Array, e: Dictionary) -> Dictionary:
	var ministry := str(e.get("name", ""))
	var best := {}
	var best_v := -1.0e9
	for p in source:
		var pd: Dictionary = p
		if _has(chosen, pd):
			continue
		var v := _role_score(pd, role, ministry, e)
		if v > best_v:
			best_v = v
			best = pd
	if best.is_empty() or role == "independent":
		return {}
	# Si nadie de la cantera conoce la cartera, el especialista se ficha de fuera.
	if role == "specialist" and not m.ministers.specialty_match(best, ministry, e) and _specialty_for(e) != "":
		return {}
	var out := best.duplicate(true)
	out["cand_role"] = role
	return out

func _role_score(c: Dictionary, role: String, ministry: String, e: Dictionary) -> float:
	match role:
		"specialist":
			return m.ministers.effective_skill(c, ministry, e) * 2.0 + (3.0 if m.ministers.specialty_match(c, ministry, e) else 0.0)
		"veteran":
			return _a(c, "experiencia") * 2.0 + _a(c, "gestion") * 0.5
		"loyal":
			return _a(c, "lealtad") + _a(c, "afinidad")
		"media":
			return _a(c, "popularidad") + _a(c, "comunicacion") + _a(c, "ambicion") * 0.5
		_:
			return m.ministers.effective_skill(c, ministry, e)

func _a(c: Dictionary, k: String) -> float:
	return float(m.ministers.attr(c, k))

## Especialidad que encaja con la cartera (por nombre o por competencias), o "" si ninguna.
func _specialty_for(e: Dictionary) -> String:
	var ministry := str(e.get("name", ""))
	var focus_keys: Array = (Policies.data().get("ministry_focus", {}) as Dictionary).keys()
	if focus_keys.has(ministry):
		return ministry
	for k in focus_keys:
		if m.ministers.specialty_match({"specialty": str(k)}, ministry, e):
			return str(k)
	return ""

## Persona nueva (independiente, de otro partido o refuerzo) con un perfil acorde al papel.
func _make(party: String, role: String, e: Dictionary, slot: int) -> Dictionary:
	var seed_v := hash("cand_%s_%d_%d_%s" % [str(e.get("id", e.get("name", ""))), m.cycle, slot, role]) % 1000000
	var ch := m.ministers.generate(party, seed_v)
	var ministry := str(e.get("name", ""))
	ch["pool_id"] = _next_id()
	ch["uid"] = "%s_%d" % [party, int(ch["pool_id"])]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var focus_keys: Array = (Policies.data().get("ministry_focus", {}) as Dictionary).keys()
	# Una parte de los candidatos nuevos conoce la cartera; el resto viene de otras áreas.
	var known := _specialty_for(e)
	ch["specialty"] = known if (role in ["specialist", "independent"] and known != "") else str(focus_keys[rng.randi_range(0, focus_keys.size() - 1)])
	var attrs: Dictionary = ch["attrs"]
	match role:
		"independent":
			ch["personality"] = "independiente"
			ch["independent"] = true
			attrs["integridad"] = clampi(int(attrs["integridad"]) + 2, 1, 10)
			attrs["lealtad"] = clampi(int(attrs["lealtad"]) - 2, 1, 10)
			attrs["afinidad"] = clampi(int(attrs["afinidad"]) - 1, 1, 10)
			attrs["gestion"] = clampi(int(attrs["gestion"]) + 1, 1, 10)
		"specialist":
			attrs["gestion"] = clampi(int(attrs["gestion"]) + 1, 1, 10)
		"veteran":
			attrs["experiencia"] = clampi(int(attrs["experiencia"]) + 2, 1, 10)
			attrs["popularidad"] = clampi(int(attrs["popularidad"]) - 1, 1, 10)
		"media":
			attrs["comunicacion"] = clampi(int(attrs["comunicacion"]) + 2, 1, 10)
			attrs["integridad"] = clampi(int(attrs["integridad"]) - 1, 1, 10)
	ch["skill"] = int(attrs["gestion"])
	ch["age"] = int(ch.get("age", 50)) + (6 if role == "veteran" else 0)
	ch["cand_role"] = role
	return ch

# ---------------------------------------------------------------- dominancia
## `a` domina a `b` si es igual o mejor en todos los atributos buenos y estrictamente mejor en alguno.
func dominates(a: Dictionary, b: Dictionary) -> bool:
	var strict := false
	for k in GOOD_ATTRS:
		var va := m.ministers.attr(a, str(k))
		var vb := m.ministers.attr(b, str(k))
		if va < vb:
			return false
		if va > vb:
			strict = true
	return strict

func _dominance_conflict(c: Dictionary, list: Array) -> bool:
	for o in list:
		if dominates(o as Dictionary, c) or dominates(c, o as Dictionary):
			return true
	return false

## Si un candidato nuevo (no de la cantera) domina o es dominado, se le da un punto débil o fuerte para romper el empate.
func _soften(c: Dictionary, list: Array) -> Dictionary:
	if not (c.get("independent", false) or int(c.get("pool_id", 0)) >= 100000):
		return c
	var attrs: Dictionary = c["attrs"]
	for o in list:
		var od: Dictionary = o
		if dominates(od, c):
			# Sube un atributo en el que el otro es mejor para que el perfil sea distinto, y baja otro.
			var best_k := ""
			var best_gap := -99
			for k in GOOD_ATTRS:
				var gap := m.ministers.attr(od, str(k)) - int(attrs[str(k)])
				if gap > best_gap and int(attrs[str(k)]) < 10:
					best_gap = gap
					best_k = str(k)
			if best_k != "":
				attrs[best_k] = clampi(m.ministers.attr(od, best_k) + 1, 1, 10)
		elif dominates(c, od):
			var worst := "integridad" if m.ministers.attr(c, "integridad") > 3 else "lealtad"
			attrs[worst] = clampi(m.ministers.attr(od, worst) - 1, 1, 10)
	return c

# ---------------------------------------------------------------- lectura de cada candidato
## Encaje en la cartera (0..11) con la misma fórmula que usa el juego para la competencia real.
func fit(c: Dictionary, index: int) -> float:
	var e := m.cab.entry(index)
	return m.ministers.effective_skill(c, str(e.get("name", "")), e)

func notes(c: Dictionary, index: int) -> Dictionary:
	var e := m.cab.entry(index)
	var ministry := str(e.get("name", ""))
	m.ministers.ensure_profile(c)
	var strengths: Array = []
	var weaknesses: Array = []
	var risks: Array = []
	if m.ministers.specialty_match(c, ministry, e):
		strengths.append("Especialista en la cartera")
	else:
		weaknesses.append("Su especialidad es otra: %s" % str(c.get("specialty", "—")))
	var labels := {"gestion": "gestor", "lealtad": "lealtad", "afinidad": "afinidad con la línea", "popularidad": "popularidad", "experiencia": "experiencia", "comunicacion": "comunicación", "integridad": "integridad"}
	for k in GOOD_ATTRS:
		var v := m.ministers.attr(c, str(k))
		if v >= 8:
			strengths.append("Destaca en %s (%d)" % [str(labels[str(k)]), v])
		elif v <= 3:
			weaknesses.append("Floja %s (%d)" % [str(labels[str(k)]), v])
	if m.ministers.attr(c, "ambicion") >= 8:
		risks.append("Ambición alta: puede rivalizar con el presidente")
	if m.ministers.attr(c, "integridad") <= 4:
		risks.append("Riesgo de escándalos")
	if m.ministers.attr(c, "lealtad") <= 4:
		risks.append("Poca disciplina: puede contradecir al Gobierno")
	match str(c.get("personality", "")):
		"mediatico": risks.append("Puede generar polémicas")
		"ideologico": risks.append("Se resistirá a las concesiones")
		"inexperto": risks.append("Necesitará supervisión")
		"independiente": risks.append("No responde ante ningún partido")
	return {"strengths": strengths.slice(0, 2), "weaknesses": weaknesses.slice(0, 2), "risks": risks.slice(0, 2)}

func role_name(c: Dictionary) -> String:
	return str(ROLE_NAMES.get(str(c.get("cand_role", "other")), "Alternativa"))

# ---------------------------------------------------------------- elección de la IA
## El socio elige de su propia lista según los rasgos de su partido: los pragmáticos buscan competencia; los leales y
## rígidos, fidelidad y afinidad; los ambiciosos, visibilidad.
func ai_choose(index: int) -> Dictionary:
	var e := m.cab.entry(index)
	var party := str(e.get("party", ""))
	var list := shortlist(index)
	if list.is_empty():
		return {}
	var prag := m.brain.trait_of(party, "pragmatism")
	var rig := m.brain.trait_of(party, "rigidity")
	var loy := m.brain.trait_of(party, "loyalty")
	var amb := m.brain.trait_of(party, "ambition")
	var best := {}
	var best_v := -1.0e9
	for c in list:
		var cd: Dictionary = c
		var v := fit(cd, index) * (0.6 + prag)
		v += (float(m.ministers.attr(cd, "lealtad")) + float(m.ministers.attr(cd, "afinidad"))) * 0.25 * (loy + rig)
		v += (float(m.ministers.attr(cd, "popularidad")) + float(m.ministers.attr(cd, "comunicacion"))) * 0.2 * amb
		v += float(m.ministers.attr(cd, "integridad")) * 0.15
		if v > best_v:
			best_v = v
			best = cd
	return best

## Nombra a un candidato de la lista de esa cartera (solo carteras del jugador). Devuelve false si no es posible.
func appoint(index: int, pool_id: int) -> bool:
	var e := m.cab.entry(index)
	if e.is_empty() or str(e.get("party", "")) != m.pid():
		return false
	for c in shortlist(index):
		if int((c as Dictionary).get("pool_id", -1)) == pool_id:
			e["minister"] = (c as Dictionary).duplicate(true)
			m.ministers.log_history(e["minister"], "Nombrado/a para %s." % str(e.get("name", "")))
			return true
	return false
