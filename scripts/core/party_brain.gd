class_name PartyBrain
extends RefCounted
## Cerebro de los partidos: ideología multidimensional, rasgos de carácter, líneas rojas, historial y
## valoración razonada de cualquier paquete de acuerdo. No usa servicios externos: todo son reglas,
## pesos y memoria persistente. Cada valoración devuelve los factores que la explican para poder mostrarlos.

var m: GameModel

## Cómo se posiciona un partido en cada tema: claves de su perfil ideológico que empujan a cada lado.
const ISSUE_LEAN := {
	"housing": {"pos": ["progresismo", "igualdad", "socialismo"], "neg": ["liberalismo_economico"]},
	"tax": {"pos": ["socialdemocracia", "igualdad"], "neg": ["liberalismo_economico"]},
	"health": {"pos": ["igualdad", "socialdemocracia"], "neg": ["liberalismo_economico"]},
	"education": {"pos": ["igualdad", "progresismo", "laicismo"], "neg": ["conservadurismo"]},
	"jobs": {"pos": ["socialismo", "socialdemocracia"], "neg": ["liberalismo_economico"]},
	"energy": {"pos": ["ecologismo", "progresismo"], "neg": ["conservadurismo"]},
	"security": {"pos": ["conservadurismo", "patriotismo"], "neg": ["progresismo"]},
	"territory": {"pos": ["nacionalismo", "federalismo"], "neg": ["centralismo"]},
}

## Qué tema le importa a cada partido (pesos sobre su perfil).
const ISSUE_WEIGHT := {
	"housing": {"progresismo": 0.4, "igualdad": 0.4, "socialismo": 0.3},
	"tax": {"liberalismo_economico": 1.0},
	"health": {"igualdad": 0.5, "socialdemocracia": 0.5, "feminismo": 0.2},
	"education": {"igualdad": 0.4, "progresismo": 0.3, "europeismo": 0.2},
	"jobs": {"socialismo": 0.4, "socialdemocracia": 0.4, "liberalismo_economico": 0.25},
	"energy": {"ecologismo": 1.0},
	"security": {"conservadurismo": 0.5, "patriotismo": 0.5},
	"territory": {"nacionalismo": 0.6, "federalismo": 0.4, "centralismo": 0.3},
}

## Área de competencia → tema político que la ocupa (para saber cuánto le interesa a un partido una cartera concreta).
const AREA_ISSUE := {
	"tax": "tax", "indirect": "tax", "jobs": "jobs", "industry": "jobs", "transport": "jobs", "agriculture": "jobs",
	"energy": "energy", "health": "health", "social": "health", "family": "health", "education": "education",
	"science": "education", "housing": "housing", "security": "security", "immigration": "security", "justice": "security",
	"defense": "security", "territory": "territory"
}
## Objetivos medibles que se pueden poner sobre la mesa (tres niveles de ambición por tema).
const OBJECTIVES := {
	"housing": ["Objetivo: ampliar la oferta de vivienda asequible", "Objetivo: un plan de vivienda pública de gran escala", "Objetivo: duplicar el parque público de vivienda"],
	"tax": ["Objetivo: no subir la presión fiscal en la legislatura", "Objetivo: rebajar la presión fiscal media", "Objetivo: una reforma fiscal profunda"],
	"health": ["Objetivo: reducir las listas de espera", "Objetivo: reforzar la plantilla y la atención primaria", "Objetivo: un gran plan de inversión sanitaria"],
	"education": ["Objetivo: reducir el abandono escolar", "Objetivo: bajar la ratio de alumnos por aula", "Objetivo: un pacto educativo con inversión sostenida"],
	"jobs": ["Objetivo: bajar el paro", "Objetivo: un plan de empleo de calidad y juventud", "Objetivo: pleno empleo estructural"],
	"energy": ["Objetivo: más renovables en el mix eléctrico", "Objetivo: un calendario de descarbonización", "Objetivo: neutralidad energética acelerada"],
	"security": ["Objetivo: reforzar las plantillas de seguridad", "Objetivo: bajar la criminalidad", "Objetivo: un plan integral de seguridad"],
	"territory": ["Objetivo: más inversión en el territorio", "Objetivo: reducir el déficit de infraestructuras", "Objetivo: un plan de cohesión territorial"]
}
const TERRITORY_WHAT := {
	"invest": "Un plan de inversiones para su territorio", "competences": "La transferencia de competencias",
	"financing": "Una mejora de la financiación"
}
const PARLIAMENT_WHAT := {
	"budget_vote": "Apoyo a los Presupuestos", "commission": "La presidencia de una comisión", "agenda": "Capacidad de fijar parte de la agenda",
	"ponencia": "Una ponencia en las leyes que le importan"
}
const INSTITUTION_WHAT := {"appointment": "Un nombramiento institucional", "reform": "Una reforma institucional pactada"}
const CALENDAR_WHAT := {"review": "Una revisión periódica del acuerdo", "deadline": "Un plazo para cumplir lo pactado", "resolution": "Un mecanismo de resolución de discrepancias"}

const PROFILE_KEYS := [
	"liberalismo_economico", "conservadurismo", "cristianodemocracia", "patriotismo", "europeismo", "feminismo",
	"igualdad", "ecologismo", "socialdemocracia", "socialismo", "republicanismo", "federalismo", "centralismo",
	"laicismo", "nacionalismo", "comunismo", "anarquismo", "animalismo", "progresismo", "monarquismo"
]

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- rasgos
func profile(id: String) -> Dictionary:
	return m.ai.profile_of(id)

func trait_of(id: String, key: String, fallback: float = 0.5) -> float:
	return float(profile(id).get(key, fallback))

## Completa los rasgos del cerebro que falten (también al migrar partidas antiguas).
func ensure_traits(id: String, prof: Dictionary) -> void:
	var party := m.party_by_id(id)
	var ip: Dictionary = party.get("ideology_profile", {})
	var axes: Dictionary = party.get("ideology", {})
	var regional := m.is_regional(id)
	var extremity := (absf(float(axes.get("economic", 0.0))) + absf(float(axes.get("social", 0.0))) + absf(float(axes.get("territorial", 0.0)))) / 3.0
	if not prof.has("territorial"):
		prof["territorial"] = 0.92 if regional else clampf(0.1 + float(ip.get("nacionalismo", 20.0)) / 200.0, 0.05, 0.5)
	if not prof.has("rigidity"):
		prof["rigidity"] = clampf(0.25 + extremity * 0.5 + m.rng.randf_range(-0.08, 0.12), 0.1, 0.95)
	if not prof.has("ambition"):
		var share := clampf(m.poll_of(id) / 30.0, 0.0, 1.0)
		var amb := 0.3 + share * 0.4 + m.rng.randf_range(-0.1, 0.15)
		if regional:
			amb -= 0.12
		prof["ambition"] = clampf(amb, 0.1, 0.95)
	if not prof.has("loyalty"):
		prof["loyalty"] = clampf(m.rng.randf_range(0.3, 0.9) - extremity * 0.1, 0.1, 0.95)
	if not prof.has("risk_averse"):
		prof["risk_averse"] = clampf(m.rng.randf_range(0.2, 0.8), 0.1, 0.9)
	# Perfil de negociación (spec negociación §4.1): ambición institucional, cohesión, presión electoral y fiabilidad.
	if not prof.has("inst_ambition"):
		var share2 := clampf(m.poll_of(id) / 30.0, 0.0, 1.0)
		prof["inst_ambition"] = clampf(0.2 + float(prof.get("ambition", 0.5)) * 0.35 + share2 * 0.2 + m.rng.randf_range(-0.1, 0.15) - (0.1 if regional else 0.0), 0.05, 0.95)
	if not prof.has("cohesion"):
		prof["cohesion"] = clampf(m.rng.randf_range(0.35, 0.92) - extremity * 0.08, 0.1, 0.95)
	if not prof.has("electoral_pressure"):
		var share3 := clampf(m.poll_of(id) / 30.0, 0.0, 1.0)
		prof["electoral_pressure"] = clampf(0.3 + (1.0 - share3) * 0.25 + m.rng.randf_range(-0.12, 0.2), 0.05, 0.95)
	if not prof.has("reliability"):
		prof["reliability"] = clampf(0.3 + float(prof.get("loyalty", 0.5)) * 0.4 + m.rng.randf_range(-0.1, 0.25), 0.1, 0.95)

func archetype(id: String) -> String:
	var p := profile(id)
	var terr := float(p.get("territorial", 0.2))
	var prag := float(p.get("pragmatism", 0.5))
	var rig := float(p.get("rigidity", 0.5))
	var amb := float(p.get("ambition", 0.5))
	if terr > 0.7:
		return "Regionalista: prioriza el autogobierno y las inversiones"
	if rig > 0.7 and prag < 0.45:
		return "Doctrinario: defiende sus principios aunque cueste"
	if amb > 0.65 and prag > 0.5:
		return "Ambicioso pragmático: busca poder y está dispuesto a ceder"
	if prag > 0.7 and rig < 0.6:
		return "Negociador: cierra acuerdos con casi cualquiera"
	if str(p.get("strategy", "")) == "opposition":
		return "Opositor: rentabiliza el desgaste del Gobierno"
	return "Equilibrado: pondera programa y poder"

# ---------------------------------------------------------------- poder negociador y estrategia preferida
## Partido al que se está investiendo o que gobierna (el "otro lado" de la mesa para quien no es candidato).
func _anchor_party(id: String) -> String:
	if m.phase == "investiture":
		var cand := m.gov.candidate_id()
		if cand != "":
			return cand
	var gp := str(m.s.get("government_party_id", ""))
	if gp != "" and m.phase in ["cabinet_design", "legislature"]:
		return gp
	return ""

## Escaños con los que contaría el bloque del anclaje sin `id`: el propio anclaje, sus socios actuales y los partidos
## que podría sumar (afines y sin vetos mutuos).
func seats_without(id: String) -> int:
	var anchor := _anchor_party(id)
	if anchor == "":
		return 0
	var have := m.seats_of(anchor) if anchor != id else 0
	var seen := {anchor: true, id: true}
	for pid in m.gov.partners():
		if not seen.has(str(pid)):
			have += m.seats_of(str(pid))
			seen[str(pid)] = true
	for p in m.all_parties():
		var oid := str((p as Dictionary).get("id", ""))
		if seen.has(oid) or m.seats_of(oid) <= 0:
			continue
		if compat(anchor, oid) >= 0.40 and blocked_by(oid, anchor) == "" and blocked_by(anchor, oid) == "":
			have += m.seats_of(oid)
			seen[oid] = true
	return have

## Cuánto depende de `id` la mayoría (0..1): 1 si sin él no se llega a 176.
func decisive_share(id: String) -> float:
	if m.seats_of(id) <= 0:
		return 0.0
	var anchor := _anchor_party(id)
	if anchor == "":
		return clampf(float(m.seats_of(id)) / 60.0, 0.05, 0.5)
	if anchor == id:
		return 0.7
	var without := seats_without(id)
	if without < Rules.MAJORITY:
		return 1.0
	return clampf(0.6 - float(without - Rules.MAJORITY) / 50.0, 0.05, 0.6)

## Fuerza de la mejor alternativa de Gobierno de `id` al margen del anclaje actual (0..1).
func alternatives_of(id: String) -> float:
	var anchor := _anchor_party(id)
	var best := 0.0
	for p in m.all_parties():
		var c2 := str((p as Dictionary).get("id", ""))
		if c2 == id or c2 == anchor or m.seats_of(c2) < Rules.CANDIDATE_MIN_SEATS:
			continue
		var bloc := m.seats_of(c2) + m.seats_of(id)
		for q in m.all_parties():
			var x := str((q as Dictionary).get("id", ""))
			if x == id or x == c2 or m.seats_of(x) <= 0:
				continue
			if compat(c2, x) >= 0.45 and blocked_by(x, c2) == "":
				bloc += m.seats_of(x)
		var reach := clampf(float(bloc) / float(Rules.MAJORITY), 0.0, 1.0)
		best = maxf(best, reach * (0.35 + 0.65 * compat(id, c2)))
	if str(profile(id).get("strategy", "negotiator")) == "opposition":
		best = minf(1.0, best + 0.15)
	return clampf(best, 0.0, 1.0)

## Poder negociador multidimensional (spec §4.3). No decide nada: devuelve el total 0..1 y el desglose por factor.
func negotiating_power(id: String, other_id: String = "") -> Dictionary:
	var p := profile(id)
	var anchor := other_id if other_id != "" else _anchor_party(id)
	if anchor == "" or anchor == id:
		anchor = m.pid() if id != m.pid() else id
	var urgency := 0.40 * float(p.get("ambition", 0.5)) + 0.25 * float(p.get("inst_ambition", 0.4)) + 0.35 * float(p.get("electoral_pressure", 0.5))
	var vals := {
		"seats": clampf(float(m.seats_of(id)) / 80.0, 0.0, 1.0),
		"decisive": decisive_share(id),
		"affinity": compat(id, anchor),
		"alternatives": alternatives_of(id),
		"interest": clampf(1.0 - urgency, 0.0, 1.0),
		"credibility": 0.5 * float(p.get("cohesion", 0.6)) + 0.5 * float(p.get("reliability", 0.6))
	}
	var total := 0.0
	var rows: Array = []
	for key in ["seats", "decisive", "affinity", "alternatives", "interest", "credibility"]:
		var w := float(Rules.NEGOTIATION_WEIGHTS[key])
		var v := float(vals[key])
		total += w * v
		rows.append({"key": key, "label": str(Rules.NEGOTIATION_FACTOR_NAMES[key]), "weight": w, "value": v, "part": w * v})
	return {"total": clampf(total, 0.0, 1.0), "factors": rows}

func power_label(v: float) -> String:
	if v >= 0.62: return "Muy alto"
	if v >= 0.48: return "Alto"
	if v >= 0.34: return "Medio"
	if v >= 0.22: return "Bajo"
	return "Marginal"

## Modalidad de participación que prefiere `id` (spec §4.2). Sale de sus rasgos, su poder y la afinidad con el otro lado:
## nunca del tamaño ni del tipo de partido. Devuelve {mode, scores, best_coop, reason, enters}.
func preferred_modality(id: String, other_id: String = "", power: float = -1.0) -> Dictionary:
	var p := profile(id)
	var anchor := other_id if other_id != "" else _anchor_party(id)
	if anchor == "" or anchor == id:
		anchor = m.pid() if id != m.pid() else id
	var comp := compat(id, anchor)
	var amb := float(p.get("ambition", 0.5))
	var inst := float(p.get("inst_ambition", 0.4))
	var terr := float(p.get("territorial", 0.2))
	var risk := float(p.get("risk_averse", 0.5))
	var elec := float(p.get("electoral_pressure", 0.5))
	var prag := float(p.get("pragmatism", 0.5))
	var rig := float(p.get("rigidity", 0.5))
	var loy := float(p.get("loyalty", 0.5))
	var pw := power if power >= 0.0 else float(negotiating_power(id, anchor)["total"])
	var scores := {
		"coalition": 0.40 * amb + 0.20 * inst + 0.30 * comp + 0.10 * pw - 0.30 * risk * (1.0 - comp) - 0.25 * terr - 0.20 * elec * (1.0 - comp),
		"external": 0.20 + 0.20 * risk + 0.15 * prag + 0.20 * comp + 0.10 * pw - 0.15 * amb,
		"puntual": 0.10 + 0.40 * terr + 0.20 * prag + 0.10 * (1.0 - amb),
		"abstention": (0.10 + 0.30 * (1.0 - comp) * prag + 0.15 * risk + 0.10 * (1.0 - loy)) if comp >= 0.12 else 0.0,
		"opposition": (0.18 if str(p.get("strategy", "negotiator")) == "opposition" else 0.0) + 0.30 * (1.0 - comp) + 0.15 * elec + 0.15 * rig - 0.10 * pw,
		"block": 0.0
	}
	if blocked_by(id, anchor) != "":
		scores["block"] = 1.5
	elif comp < 0.2:
		scores["block"] = maxf(0.0, 0.2 * rig * (1.0 - comp) - 0.03)
	var best := "coalition"
	var best_v := -9.0
	for k in Rules.MODALITY_ORDER:
		if float(scores[k]) > best_v + 0.0001:
			best_v = float(scores[k])
			best = str(k)
	var coop := -9.0
	for k2 in ["coalition", "external", "puntual", "abstention"]:
		coop = maxf(coop, float(scores[k2]))
	var reason := ""
	match best:
		"coalition": reason = "quiere poder y le compensa el desgaste de gobernar"
		"external": reason = "prefiere influir sin asumir el desgaste de gobernar"
		"puntual": reason = "prefiere pactar medidas y votos concretos, no gobernar"
		"abstention": reason = "solo facilitaría la elección, sin comprometerse más"
		"opposition": reason = "ve más rentable oponerse que pactar"
		"block": reason = "no quiere ni sentarse a esta mesa"
	return {"mode": best, "scores": scores, "best_coop": coop, "reason": reason, "enters": best == "coalition"}

## ¿La mesa propone que `id` entre en el Gobierno? (cartera, vicepresidencia o participación en coalición).
func table_enters_government(terms: Array) -> bool:
	for t in terms:
		var d: Dictionary = t
		var k := str(d.get("k", ""))
		var by_ai := str(d.get("by", "player")) == "ai"
		if k in ["cabinet", "portfolio"] and not by_ai:
			return true
		if k == "structure" and str(d.get("what", "")) == "vicepresidency" and not by_ai:
			return true
		if k == "participation" and str(d.get("mode", "")) == "coalition" and by_ai:
			return true
	return false

# ---------------------------------------------------------------- ideología
func lean(id: String, issue: String) -> float:
	var ip: Dictionary = m.party_by_id(id).get("ideology_profile", {})
	var spec: Dictionary = ISSUE_LEAN.get(issue, {})
	var pos := 0.0
	for k in spec.get("pos", []):
		pos += float(ip.get(str(k), 0.0))
	var neg := 0.0
	for k in spec.get("neg", []):
		neg += float(ip.get(str(k), 0.0))
	var np := maxf(1.0, float((spec.get("pos", []) as Array).size()))
	var nn := maxf(1.0, float((spec.get("neg", []) as Array).size()))
	return clampf((pos / np - neg / nn) / 100.0, -1.0, 1.0)

## Importancia 0..1 que un partido da a cada tema (el más importante vale 1).
func salience_map(id: String) -> Dictionary:
	var ip: Dictionary = m.party_by_id(id).get("ideology_profile", {})
	var raw: Dictionary = {}
	var top := 0.01
	for issue in ISSUE_WEIGHT.keys():
		var sc := 0.0
		for k in (ISSUE_WEIGHT[issue] as Dictionary).keys():
			sc += float(ip.get(str(k), 0.0)) * float((ISSUE_WEIGHT[issue] as Dictionary)[k])
		raw[issue] = sc
		top = maxf(top, sc)
	var out: Dictionary = {}
	for issue in raw.keys():
		out[issue] = clampf(float(raw[issue]) / top, 0.0, 1.0)
	return out

func salience(id: String, issue: String) -> float:
	return float(salience_map(id).get(issue, 0.3))

func top_issues(id: String, n: int = 3) -> Array:
	var sm := salience_map(id)
	var ids: Array = sm.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(sm[a]) > float(sm[b]))
	return ids.slice(0, n)

## Parecido entre perfiles (0..1).
func profile_similarity(a: String, b: String) -> float:
	return Ideology.profile_similarity(m.party_by_id(a).get("ideology_profile", {}), m.party_by_id(b).get("ideology_profile", {}))

## Compatibilidad 0..1: combina distancia en los tres ejes y perfil ideológico.
func compat(a: String, b: String) -> float:
	return clampf(0.5 * m.ai.affinity(a, b) + 0.5 * profile_similarity(a, b), 0.0, 1.0)

func compat_label(c: float) -> String:
	if c >= 0.72: return "Muy afines"
	if c >= 0.5: return "Compatibles"
	if c >= 0.32: return "Distantes"
	if c >= 0.16: return "Opuestos"
	return "Incompatibles"

# ---------------------------------------------------------------- historial
func goodwill(id: String, toward: String) -> float:
	var total := 0.0
	for entry in m.ai.memory():
		var e: Dictionary = entry
		if str(e.get("party", "")) != id:
			continue
		var age := float(m.cycle - int(e.get("cycle", m.cycle)))
		var decay := 1.0 / (1.0 + age * 0.8)
		match str(e.get("event", "")):
			"agreement_accepted": total += 0.06 * decay
			"pact_kept": total += 0.10 * decay
			"meeting_good": total += 0.04 * decay
	return clampf(total, 0.0, 0.25)

func grievance(id: String, toward: String) -> float:
	var total := 0.0
	for entry in m.ai.memory():
		var e: Dictionary = entry
		if str(e.get("party", "")) != id and str(e.get("target", "")) != id:
			continue
		var age := float(m.cycle - int(e.get("cycle", m.cycle)))
		var decay := 1.0 / (1.0 + age * 0.8)
		match str(e.get("event", "")):
			"agreement_rejected": total += 0.03 * decay
			"pact_broken": total += 0.18 * decay
			"meeting_walkout": total += 0.07 * decay
		if str(e.get("stage", "")) == "reply" and str(e.get("style", "")) == "firm" and str(e.get("target", "")) == id:
			total += 0.03 * decay
	return clampf(total, 0.0, 0.4)

# ---------------------------------------------------------------- líneas rojas
## Líneas rojas del partido: no pactar con quien es incompatible, y temas que no puede aceptar.
func red_lines(id: String) -> Array:
	var out: Array = []
	for p in m.all_parties():
		var oid := str((p as Dictionary).get("id", ""))
		if oid == id or (m.seats_of(oid) <= 0 and m.poll_of(oid) < 0.3):
			continue
		if compat(id, oid) < 0.14:
			out.append({"type": "party", "party": oid, "text": "No pactará con %s" % m.party_short(oid)})
	var ip: Dictionary = m.party_by_id(id).get("ideology_profile", {})
	if float(ip.get("centralismo", 0.0)) >= 75.0:
		out.append({"type": "issue", "issue": "territory", "text": "No aceptará cesiones que rompan la unidad del Estado"})
	if float(ip.get("nacionalismo", 0.0)) >= 80.0 and float(ip.get("centralismo", 0.0)) < 30.0:
		out.append({"type": "issue", "issue": "territory", "text": "Exige un avance claro en autogobierno"})
	if float(ip.get("liberalismo_economico", 0.0)) >= 75.0:
		out.append({"type": "issue", "issue": "tax", "text": "No acepta subidas de impuestos"})
	return out

## Distancia izquierda-derecha (0 = mismo punto) entre dos partidos.
func bloc_distance(a: String, b: String) -> float:
	return absf(Ideology.bloc_score(m.party_by_id(a).get("ideology", {})) - Ideology.bloc_score(m.party_by_id(b).get("ideology", {})))

## Puertas ideológicas: hay acuerdos que un partido fiel a su ideología no firma con ciertos rivales aunque se le
## ofrezca mucho. Devuelve el motivo o "" si el acuerdo es ideológicamente posible.
func gate(ai_id: String, other_id: String, kind: String) -> String:
	if ai_id == other_id:
		return ""
	var c := compat(ai_id, other_id)
	var sa := Ideology.bloc_score(m.party_by_id(ai_id).get("ideology", {}))
	var sb := Ideology.bloc_score(m.party_by_id(other_id).get("ideology", {}))
	var opposed := sa * sb < 0.0 and absf(sa) > 0.3 and absf(sb) > 0.3
	var other_short := m.party_short(other_id)
	match kind:
		"joint_list":
			if opposed or c < 0.55 or bloc_distance(ai_id, other_id) > 0.45:
				return "Sus proyectos son demasiado distintos para concurrir juntos"
		"cabinet", "stability":
			if opposed or c < 0.20:
				return "No compartirá Gobierno ni estabilidad con %s" % other_short
		"vote_yes":
			if opposed and c < 0.20:
				return "No votará a favor de %s" % other_short
	return ""

func topic_gate(ai_id: String, topic: String) -> String:
	match topic:
		"joint_list":
			return gate(ai_id, m.pid(), "joint_list")
		"partner":
			return gate(ai_id, m.pid(), "cabinet")
		"stability":
			return gate(ai_id, m.pid(), "stability")
	return blocked_by(ai_id, m.pid())

func blocked_by(id: String, other_id: String) -> String:
	for rl in red_lines(id):
		var d: Dictionary = rl
		if str(d.get("type", "")) == "party" and str(d.get("party", "")) == other_id and m.ai.relation(id) < 80.0:
			return str(d["text"])
	return ""

## Predisposición 0..100 de un partido hacia otro, sin paquete concreto sobre la mesa.
func disposition(id: String, toward: String) -> float:
	var c := compat(id, toward)
	var rel := m.ai.relation(id) / 100.0 if toward == m.pid() else 0.5
	var v := 100.0 * (0.50 * c + 0.30 * rel + 0.20 * 0.5 + goodwill(id, toward) - grievance(id, toward))
	v += (trait_of(id, "pragmatism") - 0.5) * 14.0
	if blocked_by(id, toward) != "":
		v = minf(v, 12.0)
	return clampf(v, 0.0, 100.0)

func disposition_label(v: float) -> Dictionary:
	if v >= 70.0: return {"text": "Aliado", "tone": "good"}
	if v >= 52.0: return {"text": "Receptivo", "tone": "good"}
	if v >= 38.0: return {"text": "Reticente", "tone": "warn"}
	if v >= 22.0: return {"text": "Frío", "tone": "bad"}
	return {"text": "Hostil", "tone": "bad"}

# ---------------------------------------------------------------- objetivos
func goal(id: String) -> String:
	var p := profile(id)
	var seats := m.seats_of(id)
	var terr := float(p.get("territorial", 0.2))
	if terr > 0.7:
		return "Arrancar competencias e inversiones para su territorio"
	if str(p.get("strategy", "")) == "opposition" and float(p.get("ambition", 0.5)) < 0.6:
		return "Mantener perfil propio y rentabilizar el desgaste"
	if seats >= 20 and float(p.get("ambition", 0.5)) >= 0.5:
		return "Entrar en el Gobierno y conseguir carteras"
	return "Influir en las políticas sin asumir el desgaste"

# ---------------------------------------------------------------- valoración de términos
## Un término del acuerdo: {k: tipo, by: "player"|"ai", ...}. Devuelve su valor para la IA (positivo = gana).
## Cuánto encaja con la ideología de `party_id` el cambio concreto que recoge el término (-1 a 1).
func measure_pref_of_term(party_id: String, term: Dictionary) -> float:
	var meas := Policies.measure(str(term.get("measure", "")))
	if meas.is_empty():
		return 0.0
	var cur := m.eco.value(str(meas["id"]))
	var dirn := 1.0 if float(term.get("to", cur)) > cur else -1.0
	return m.laws.measure_pref(party_id, meas) * dirn

func term_value(ai_id: String, other_id: String, term: Dictionary, ctx: Dictionary) -> Dictionary:
	var kind := str(term.get("k", ""))
	var by_ai := str(term.get("by", "player")) == "ai"
	var comp := compat(ai_id, other_id)
	var p := profile(ai_id)
	var rig := float(p.get("rigidity", 0.5))
	var amb := float(p.get("ambition", 0.5))
	var terr := float(p.get("territorial", 0.2))
	var pivot := float(ctx.get("pivot", 0.5))
	var v := 0.0
	var label := ""
	match kind:
		"vote_yes":
			if by_ai:
				v = -(0.22 + 0.30 * (1.0 - comp) + 0.08 * rig)
				label = "Votar a favor"
			else:
				v = 0.18 + 0.5 * float(ctx.get("player_pivot", 0.4))
				label = "Tu voto a favor"
		"vote_abstain":
			if by_ai:
				v = -(0.10 + 0.16 * (1.0 - comp))
				label = "Abstenerse"
			else:
				v = 0.10 + 0.25 * float(ctx.get("player_pivot", 0.4))
				label = "Tu abstención"
		"cabinet":
			var n := float(int(term.get("n", 1)))
			if by_ai:
				v = -(0.13 * n * (0.6 + 0.8 * amb))
				label = "Ceder %d %s" % [int(n), "cartera" if int(n) == 1 else "carteras"]
			else:
				v = amb * (0.20 + 0.10 * minf(n, 4.0)) * (1.0 - 0.5 * terr)
				label = "%d %s para ellos" % [int(n), "cartera" if int(n) == 1 else "carteras"]
		"policy":
			var issue := str(term.get("issue", "jobs"))
			var sal := salience(ai_id, issue)
			if by_ai and str(term.get("measure", "")) != "":
				var pm: float = measure_pref_of_term(ai_id, term)
				v = 0.03 if pm >= 0.0 else -((0.06 + 0.5 * -pm) * (0.5 + rig * 0.8))
				label = "Asumir: %s" % str(term.get("text", Rules.issue_name(issue)))
			elif by_ai:
				var agree := 1.0 - absf(lean(ai_id, issue) - float(term.get("lean", lean(other_id, issue)))) / 2.0
				v = -((0.05 + 0.38 * (1.0 - agree)) * (0.5 + rig * 0.8))
				label = "Asumir: %s" % str(term.get("text", Rules.issue_name(issue)))
			else:
				v = 0.07 + 0.42 * sal
				label = "Su prioridad: %s" % str(term.get("text", Rules.issue_name(issue)))
		"bills":
			var n2 := float(int(term.get("n", 1)))
			if by_ai:
				v = -(n2 * (0.07 + 0.22 * (1.0 - comp)) * (0.6 + 0.6 * rig))
				label = "Votar %d %s contigo" % [int(n2), "ley" if int(n2) == 1 else "leyes"]
			else:
				v = n2 * 0.08
				label = "Votar %d %s con ellos" % [int(n2), "ley" if int(n2) == 1 else "leyes"]
		"joint_list":
			var ai_poll := m.poll_of(ai_id)
			var other_poll := m.poll_of(other_id)
			var gain := 0.32 if ai_poll < other_poll * 0.8 else (0.12 if ai_poll < other_poll * 1.25 else 0.02)
			var identity := (0.18 + 0.55 * terr) * (0.6 + (1.0 - comp)) + 0.2 * rig
			v = gain - identity
			label = "Candidatura conjunta"
		"stability":
			if by_ai:
				v = -(0.12 + 0.3 * (1.0 - comp))
				label = "Pacto de estabilidad"
			else:
				v = 0.12
				label = "Tu apoyo a la estabilidad"
		"law_vote", "law_abstain":
			var law := m.laws.find(str(term.get("law", "")))
			var sc := float(m.laws.stance(law, ai_id)["score"]) if not law.is_empty() else 0.0
			if kind == "law_vote":
				v = -(0.30 - 0.26 * clampf(sc, -1.0, 1.0)) * (0.55 + 0.6 * rig)
				label = "Votar a favor de la ley"
			else:
				v = -(0.14 - 0.10 * clampf(sc, -1.0, 1.0)) * (0.6 + 0.5 * rig)
				label = "Abstenerse en la ley"
		"law_amend":
			var pm2 := measure_pref_of_term(ai_id, term)
			v = 0.10 + 0.20 * clampf(absf(pm2), 0.0, 1.0) if str(term.get("type", "")) != "add" else 0.12 + 0.2 * clampf(pm2, 0.0, 1.0)
			label = "Cambio en la ley: %s" % str(term.get("text", ""))
		"owe_vote":
			v = 0.12 + 0.12 * amb
			label = "Devolver el favor: votar una ley suya"
		"cordon":
			var target := str(term.get("target", ""))
			if by_ai:
				v = -(0.1 + 0.5 * compat(ai_id, target))
				label = "No pactar con %s" % m.party_short(target)
			else:
				v = 0.08 + 0.34 * (1.0 - compat(ai_id, target))
				label = "No pactarás con %s" % m.party_short(target)
		"participation":
			var mode := str(term.get("mode", "external"))
			var md := _ctx_modality(ai_id, other_id, ctx)
			var sc: Dictionary = md["scores"]
			# Comprometerse a una modalidad cuesta poco si es la que ya prefiere y mucho si va contra su carácter.
			v = -0.08 + (float(sc.get(mode, 0.0)) - float(md["best_coop"])) * 0.8
			if mode == "opposition":
				v = 0.0
			label = "Participar como: %s" % str(Rules.MODALITIES.get(mode, {}).get("short", mode))
		"structure":
			var what := str(term.get("what", "coordination"))
			var inst := float(p.get("inst_ambition", 0.4))
			match what:
				"vicepresidency":
					if by_ai:
						v = -(0.12 + 0.26 * amb)
						label = "Ceder una vicepresidencia"
					else:
						v = (0.10 + 0.40 * inst) * (1.0 - 0.3 * terr)
						label = "Una vicepresidencia para ellos"
				"independents":
					if by_ai:
						v = -(0.05 + 0.15 * amb)
						label = "Admitir independientes en sus ministerios"
					else:
						v = 0.04 + 0.08 * amb
						label = "Independientes en los ministerios de ellos"
				"max_ministries", "min_ministries":
					var nn := float(int(term.get("n", 12)))
					v = amb * 0.10 * clampf((nn - 8.0) / 12.0, 0.0, 1.0) + 0.01
					label = "%s de %d ministerios" % ["Máximo" if what == "max_ministries" else "Mínimo", int(nn)]
				_:
					v = 0.04 + 0.14 * inst
					label = "Un órgano de coordinación del Gobierno"
		"portfolio":
			var cid := str(term.get("comp", ""))
			var cdef := Competencies.by_id(cid)
			var area := str(cdef.get("area", ""))
			var fit := salience(ai_id, str(AREA_ISSUE.get(area, ""))) if AREA_ISSUE.has(area) else 0.3
			var prestige := 0.08 if bool(cdef.get("essential", false)) else 0.0
			if by_ai:
				v = -(0.18 + prestige + 0.30 * fit) * (0.6 + 0.8 * amb)
				label = "Ceder la cartera de %s" % Competencies.name_of(cid)
			else:
				v = amb * (0.16 + 0.24 * fit + prestige) * (1.0 - 0.5 * terr)
				label = "La cartera de %s para ellos" % Competencies.name_of(cid)
		"objective":
			var oissue := str(term.get("issue", "jobs"))
			var lvl := float(int(term.get("level", 1)))
			if by_ai:
				v = -(0.06 + 0.10 * lvl) * (0.5 + rig * 0.8)
				label = "Asumir: %s" % str(term.get("text", ""))
			else:
				v = 0.05 + 0.30 * salience(ai_id, oissue) * (0.55 + 0.25 * lvl)
				label = str(term.get("text", "Un objetivo medible"))
		"territory":
			var tlvl := float(int(term.get("n", 1)))
			v = (0.04 + 0.34 * terr) * (0.6 + 0.25 * tlvl)
			label = str(TERRITORY_WHAT.get(str(term.get("what", "invest")), "Una cesión territorial"))
		"budget":
			var bissue := str(term.get("issue", "jobs"))
			var blvl := float(int(term.get("n", 1)))
			v = 0.05 + 0.30 * salience(ai_id, bissue) * (0.5 + 0.25 * blvl)
			label = "Dotación para %s" % Rules.issue_name(bissue).to_lower()
		"parliament":
			var pwhat := str(term.get("what", "agenda"))
			if by_ai:
				v = -(0.16 + 0.26 * (1.0 - comp)) * (0.6 + 0.6 * rig)
				label = str(PARLIAMENT_WHAT.get(pwhat, "Un compromiso parlamentario"))
			else:
				v = 0.06 + 0.22 * float(p.get("inst_ambition", 0.4)) if pwhat in ["commission", "agenda"] else 0.05 + 0.10 * amb
				label = str(PARLIAMENT_WHAT.get(pwhat, "Un compromiso parlamentario"))
		"institution":
			var iwhat := str(term.get("what", "appointment"))
			var ilvl := float(int(term.get("n", 1)))
			if iwhat == "appointment":
				v = (0.05 + 0.25 * float(p.get("inst_ambition", 0.4)) * amb) * (0.6 + 0.25 * ilvl)
			else:
				v = 0.04 + 0.12 * rig
			label = str(INSTITUTION_WHAT.get(iwhat, "Un acuerdo institucional"))
		"calendar":
			# Los plazos y revisiones son garantías para quien desconfía del otro: valen más cuanto peor es la relación.
			var distrust := 1.0 - clampf(m.ai.relation(ai_id) / 100.0, 0.0, 1.0) if other_id == m.pid() else 0.5
			v = 0.03 + 0.12 * distrust + 0.04 * (1.0 - float(p.get("reliability", 0.6)))
			label = str(CALENDAR_WHAT.get(str(term.get("what", "review")), "Una garantía de calendario"))
	# Quien sabe que es decisivo valora menos lo que recibe y más lo que da; el poder negociador lo acentúa.
	var power := _ctx_power(ai_id, other_id, ctx)
	if by_ai and v < 0.0:
		v *= (1.0 + 0.25 * pivot) * (1.0 + 0.30 * (power - 0.4))
	elif not by_ai and v > 0.0:
		v *= (1.0 - 0.2 * pivot) * (1.0 - 0.25 * (power - 0.4))
	return {"v": v, "label": label}

## Poder negociador y modalidad preferida, calculados una sola vez por contexto.
func _ctx_power(ai_id: String, other_id: String, ctx: Dictionary) -> float:
	if not ctx.has("power"):
		ctx["power"] = float(negotiating_power(ai_id)["total"])
	return float(ctx["power"])

func _ctx_modality(ai_id: String, other_id: String, ctx: Dictionary) -> Dictionary:
	if not ctx.has("modality"):
		ctx["modality"] = preferred_modality(ai_id, "", _ctx_power(ai_id, other_id, ctx))
	return ctx["modality"]

## Motivo por el que el partido no aceptaría este término en ningún caso ("" si no hay veto).
func term_block(ai_id: String, other_id: String, td: Dictionary) -> String:
	var k := str(td.get("k", ""))
	if k in ["joint_list", "cabinet", "stability", "vote_yes"]:
		var g := gate(ai_id, other_id, k)
		if g != "":
			return g
	var enters := (k == "portfolio" and str(td.get("by", "player")) != "ai") or (k == "structure" and str(td.get("what", "")) == "vicepresidency") or (k == "participation" and str(td.get("mode", "")) == "coalition")
	if enters:
		var g2 := gate(ai_id, other_id, "cabinet")
		if g2 != "":
			return g2
	if k == "policy" and str(td.get("by", "")) == "ai":
		if str(td.get("measure", "")) != "" and measure_pref_of_term(ai_id, td) <= -0.55:
			return "Es una línea roja para %s" % m.party_short(ai_id)
		for rl in red_lines(ai_id):
			var r: Dictionary = rl
			if str(r.get("type", "")) == "issue" and str(r.get("issue", "")) == str(td.get("issue", "")) and not bool(td.get("respects_red_line", false)):
				if lean(other_id, str(td.get("issue", ""))) * lean(ai_id, str(td.get("issue", ""))) < 0.0:
					return str(r["text"])
	return ""

# ---------------------------------------------------------------- valoración global
## Valora un paquete desde el punto de vista de `ai_id`. ctx: pivot, player_pivot, rapport (0..100), pressure.
func assess(ai_id: String, other_id: String, terms: Array, ctx: Dictionary = {}) -> Dictionary:
	var p := profile(ai_id)
	var factors: Array = []
	var total := 0.0
	var terms_detail: Array = []
	var worst_idx := -1
	var worst_v := 0.0
	var blocked := blocked_by(ai_id, other_id)
	var i := 0
	var term_sum := 0.0
	for t in terms:
		var td: Dictionary = t
		if blocked == "" and str(td.get("k", "")) in ["joint_list", "cabinet", "stability", "vote_yes"]:
			blocked = gate(ai_id, other_id, str(td.get("k", "")))
		if blocked == "" and str(td.get("k", "")) in ["portfolio", "structure", "participation"]:
			blocked = term_block(ai_id, other_id, td)
		var tv := term_value(ai_id, other_id, td, ctx)
		term_sum += float(tv["v"])
		terms_detail.append({"label": str(tv["label"]), "v": float(tv["v"]), "by": str(td.get("by", "player")), "k": str(td.get("k", ""))})
		if float(tv["v"]) < worst_v:
			worst_v = float(tv["v"])
			worst_idx = i
		# Líneas rojas concretas: hay medidas que la IA no firmaría jamás.
		if str(td.get("k", "")) == "policy" and str(td.get("by", "")) == "ai" and str(td.get("measure", "")) != "":
			if measure_pref_of_term(ai_id, td) <= -0.55:
				blocked = "Es una línea roja para %s: «%s»" % [m.party_short(ai_id), str(td.get("text", ""))]
		# Líneas rojas temáticas: no se puede pedir a la IA lo que vulnera su línea roja.
		if str(td.get("k", "")) == "policy" and str(td.get("by", "")) == "ai":
			for rl in red_lines(ai_id):
				var r: Dictionary = rl
				if str(r.get("type", "")) == "issue" and str(r.get("issue", "")) == str(td.get("issue", "")) and not bool(td.get("respects_red_line", false)):
					if lean(other_id, str(td.get("issue", ""))) * lean(ai_id, str(td.get("issue", ""))) < 0.0:
						blocked = str(r["text"])
		i += 1
	factors.append({"key": "terms", "label": "Balance del paquete", "value": term_sum})
	total += term_sum
	var comp := compat(ai_id, other_id)
	var f_aff := (comp - 0.5) * 0.55
	factors.append({"key": "affinity", "label": "Afinidad ideológica", "value": f_aff})
	total += f_aff
	var rel := m.ai.relation(ai_id) if other_id == m.pid() or ai_id == m.pid() else 50.0
	if ai_id == m.pid():
		rel = m.ai.relation(other_id)
	var f_trust := (rel - 50.0) / 100.0 * 0.5
	if other_id == m.pid() or ai_id == m.pid():
		# Cómo te ven: honradez percibida y la honestidad del propio líder pesan en la confianza de los demás.
		f_trust += (float(m.enc.image().get("honesty", 50.0)) - 50.0) / 100.0 * 0.2 + Leader.edge(m.character(), "honestidad") * 0.04
	factors.append({"key": "trust", "label": "Confianza personal", "value": f_trust})
	total += f_trust
	var f_hist := goodwill(ai_id, other_id) - grievance(ai_id, other_id)
	factors.append({"key": "history", "label": "Historial entre ambos", "value": f_hist})
	total += f_hist
	var involves_power := false
	for t in terms:
		if str((t as Dictionary).get("k", "")) in ["cabinet", "joint_list", "stability"]:
			involves_power = true
	var f_risk := 0.0
	if involves_power:
		f_risk = -(1.0 - comp) * 0.2 * (0.6 + float(p.get("risk_averse", 0.5)))
	factors.append({"key": "risk", "label": "Riesgo electoral de asociarse", "value": f_risk})
	total += f_risk
	var rapport := float(ctx.get("rapport", 0.0))
	var f_rap := rapport / 100.0 * 0.22
	if absf(f_rap) > 0.0:
		factors.append({"key": "rapport", "label": "Ambiente de la reunión", "value": f_rap})
	total += f_rap
	var f_press := float(ctx.get("pressure", 0.0))
	if absf(f_press) > 0.0:
		factors.append({"key": "pressure", "label": "Presión ejercida", "value": f_press})
	total += f_press
	# Estrategia preferida: si lo que más le conviene es entrar, apoyar desde fuera, pactar puntualmente, abstenerse
	# u oponerse, cada paquete se mide contra eso (spec negociación §4.2).
	var power := _ctx_power(ai_id, other_id, ctx)
	var modality := _ctx_modality(ai_id, other_id, ctx)
	var mode := str(modality["mode"])
	var f_style := -0.07 if str(p.get("strategy", "negotiator")) == "opposition" else 0.0
	if mode == "opposition":
		f_style = -(0.07 + 0.2 * clampf(float((modality["scores"] as Dictionary)["opposition"]) - float(modality["best_coop"]), 0.0, 0.4))
	if f_style != 0.0:
		factors.append({"key": "strategy", "label": "Prefiere la oposición" if mode == "opposition" else "Estrategia de oposición", "value": f_style})
	total += f_style
	var entry_refused := false
	if table_enters_government(terms) and mode != "coalition":
		var sc: Dictionary = modality["scores"]
		var gap_mod := float(modality["best_coop"]) - float(sc["coalition"])
		var f_entry := -clampf(0.08 + 0.55 * gap_mod, 0.08, 0.45)
		factors.append({"key": "entry", "label": "No le conviene entrar en el Gobierno", "value": f_entry})
		total += f_entry
		entry_refused = gap_mod > 0.10
	var need := 0.04 + 0.12 * float(p.get("rigidity", 0.5)) - 0.08 * float(p.get("pragmatism", 0.5)) + float(ctx.get("pivot", 0.5)) * 0.10 + float(ctx.get("hard", 0.0)) + (power - 0.4) * Rules.POWER_NEED_SLOPE
	var verdict := "reject"
	if blocked != "":
		verdict = "veto"
	elif total >= need:
		verdict = "accept"
	elif total >= need - 0.24:
		verdict = "counter"
	# Exigencias inegociables: quien da apoyo no firma sin ellas, por mucho que le ofrezcas.
	var must_missing: Array = []
	if bool(ctx.get("enforce_must", false)) and verdict != "veto":
		must_missing = missing_must(ai_id, terms)
		if not must_missing.is_empty():
			verdict = "reject"
	return {
		"utility": total, "need": need, "verdict": verdict, "factors": factors, "terms": terms_detail,
		"blocked": blocked, "worst": worst_idx, "gap": need - total, "compat": comp, "must_missing": must_missing,
		"power": power, "modality": mode, "modality_reason": str(modality["reason"]), "entry_refused": entry_refused
	}

# ---------------------------------------------------------------- contraoferta
## Qué pediría la IA para cerrar el trato. Devuelve {add: [términos], remove: [índices], text}.
func counter(ai_id: String, other_id: String, terms: Array, ctx: Dictionary, check: Dictionary) -> Dictionary:
	var gap := float(check["gap"])
	var add: Array = []
	var remove: Array = []
	var cur: Array = terms.duplicate(true)
	var must: Array = check.get("must_missing", [])
	if not must.is_empty():
		var names: Array = []
		for mt in must:
			add.append(mt)
			names.append("«%s»" % str((mt as Dictionary)["text"]))
		return {"add": add, "remove": remove, "kind": "ask",
			"text": "Es nuestra línea roja: sin %s no firmamos nada. Lo demás se puede hablar." % " y ".join(names)}
	# No quiere entrar en el Gobierno: retira lo que lo implica y propone su modalidad preferida.
	if bool(check.get("entry_refused", false)) and table_enters_government(cur):
		var pref := str(check.get("modality", "external"))
		var drop: Array = []
		for ci in range(cur.size()):
			var ct: Dictionary = cur[ci]
			var ck := str(ct.get("k", ""))
			if (ck in ["cabinet", "portfolio"] and str(ct.get("by", "player")) != "ai") or (ck == "structure" and str(ct.get("what", "")) == "vicepresidency") or (ck == "participation" and str(ct.get("mode", "")) == "coalition"):
				drop.append(ci)
		drop.reverse()  # se retiran de atrás adelante para no desplazar los índices
		var mode_term: Dictionary = {"k": "participation", "mode": pref if pref in ["external", "puntual", "abstention", "opposition"] else "external", "by": "ai"}
		if str(mode_term["mode"]) == "opposition":
			return {"add": [], "remove": drop, "kind": "drop",
				"text": "No vamos a entrar en el Gobierno ni a comprometernos: preferimos mantenernos en la oposición."}
		return {"add": [mode_term], "remove": drop, "kind": "modality",
			"text": "No queremos entrar en el Gobierno: %s. Lo que sí podemos ofrecer es %s." % [str(check.get("modality_reason", "preferimos otra fórmula")), term_text(mode_term)]}
	# Si lo más costoso es algo que ella da, primero lo recorta: menos carteras o leyes, o abstención en vez de voto.
	var worst := int(check.get("worst", -1))
	if worst >= 0:
		var wt: Dictionary = cur[worst]
		if str(wt.get("by", "")) == "ai":
			var wk := str(wt.get("k", ""))
			if wk in ["cabinet", "bills"] and int(wt.get("n", 1)) > 1:
				var nn := int(wt.get("n", 1)) - 1
				var noun := ("cartera" if nn == 1 else "carteras") if wk == "cabinet" else ("ley" if nn == 1 else "leyes")
				return {"add": add, "remove": remove, "mods": [{"idx": worst, "set": {"n": nn}}], "kind": "mod",
					"text": "Eso es demasiado: puedo ofrecer %d %s, no más." % [nn, noun]}
			if wk == "vote_yes" and gap > 0.10 and str(check.get("verdict", "")) == "counter":
				return {"add": add, "remove": remove, "mods": [{"idx": worst, "replace": {"k": "vote_abstain", "by": "ai"}}], "kind": "mod",
					"text": "Votar a favor es mucho pedir por ahora. Puedo abstenerme, y ya sería un gesto importante."}
	# Si hay una petición muy costosa y quitarla basta, la IA pide retirarla.
	if worst >= 0 and not str((cur[worst] as Dictionary).get("k", "")) in ["vote_yes", "vote_abstain", "joint_list", "law_vote", "law_abstain"]:
		var tv := term_value(ai_id, other_id, cur[worst] as Dictionary, ctx)
		if float(tv["v"]) < -0.28 and gap <= absf(float(tv["v"])) + 0.01:
			remove.append(worst)
			return {"add": add, "remove": remove, "text": "No puedo aceptar «%s». Retírelo y hablamos." % str(tv["label"]), "kind": "drop"}
	# Si no, pide más de lo que valora: su prioridad temática, carteras, o apoyo.
	var options: Array = []
	# Voto a una ley concreta: lo que pide es cambiar la ley (suavizar, retirar o añadir medidas).
	for tt in cur:
		var td0: Dictionary = tt
		if str(td0.get("k", "")) == "law_vote" and str(td0.get("by", "")) == "ai":
			var law := m.laws.find(str(td0.get("law", "")))
			if law.is_empty():
				continue
			var st: Dictionary = m.laws.stance(law, ai_id)
			for cond in st["conditions"]:
				var cd: Dictionary = cond
				var term := {"k": "law_amend", "by": "player", "law": str(law["id"]), "type": str(cd["type"]), "measure": str(cd["measure"]), "value": float(cd["value"]), "text": str(cd["text"])}
				if not _has_amend(cur, str(cd["measure"])):
					options.append({"term": term, "gain": 0.16})
	if not _has_term(cur, "owe_vote", "player", "") and not options.is_empty():
		options.append({"term": {"k": "owe_vote", "by": "player"}, "gain": 0.12 + 0.12 * float(profile(ai_id).get("ambition", 0.5))})
	for issue in top_issues(ai_id, 2):
		if not _has_term(cur, "policy", "player", str(issue)):
			var sal := salience(ai_id, str(issue))
			options.append({"term": policy_term(ai_id, "player", str(issue)), "gain": 0.07 + 0.42 * sal})
	var cdem := m.diplomacy.dyn.cordon_demand(ai_id)
	if not cdem.is_empty() and not m.diplomacy.dyn._has_cordon(cur, str(cdem["target"])):
		options.append({"term": cdem, "gain": 0.12 + 0.3 * (1.0 - compat(ai_id, str(cdem["target"])))})
	var amb := float(profile(ai_id).get("ambition", 0.5))
	var enters_ok := str(check.get("modality", "coalition")) == "coalition"
	if amb > 0.4 and enters_ok and not _has_term(cur, "cabinet", "player", ""):
		options.append({"term": {"k": "cabinet", "by": "player", "n": 1}, "gain": amb * 0.30})
	# Peticiones propias de su carácter: territorio, vicepresidencia, objetivos medibles y garantías.
	var pf := profile(ai_id)
	if float(pf.get("territorial", 0.2)) >= 0.45 and not _has_term(cur, "territory", "player", ""):
		options.append({"term": {"k": "territory", "what": "invest", "n": 2, "by": "player"}, "gain": 0.10 + 0.40 * float(pf.get("territorial", 0.2))})
	if float(pf.get("inst_ambition", 0.4)) >= 0.6 and enters_ok and not _has_struct(cur, "vicepresidency"):
		options.append({"term": {"k": "structure", "what": "vicepresidency", "by": "player"}, "gain": 0.10 + 0.40 * float(pf.get("inst_ambition", 0.4))})
	var ti := top_issues(ai_id, 1)
	if not ti.is_empty() and not _has_term(cur, "objective", "player", str(ti[0])):
		options.append({"term": objective_term(str(ti[0]), 2), "gain": 0.05 + 0.30 * salience(ai_id, str(ti[0])) * 1.05})
	if not options.is_empty():
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["gain"]) > float(b["gain"]))
		var acc := 0.0
		for o in options:
			add.append((o as Dictionary)["term"])
			acc += float((o as Dictionary)["gain"])
			if acc >= gap or add.size() >= 2:
				break
	var text := ""
	if add.is_empty():
		text = "No veo qué más podría aportar para acercarnos."
	else:
		var parts: Array = []
		for a in add:
			parts.append(term_text(a as Dictionary))
		text = "Para firmarlo necesitaríamos además: %s." % "; ".join(parts)
	return {"add": add, "remove": remove, "text": text, "kind": "ask"}

func _has_struct(terms: Array, what: String) -> bool:
	for t in terms:
		var d: Dictionary = t
		if str(d.get("k", "")) == "structure" and str(d.get("what", "")) == what:
			return true
	return false

## Término de objetivo medible para un tema y un nivel de ambición (1 a 3).
func objective_term(issue: String, level: int) -> Dictionary:
	var texts: Array = OBJECTIVES.get(issue, OBJECTIVES["jobs"])
	var lv := clampi(level, 1, 3)
	return {"k": "objective", "by": "player", "issue": issue, "level": lv, "text": str(texts[lv - 1])}

func _has_amend(terms: Array, measure_id: String) -> bool:
	for t in terms:
		var d: Dictionary = t
		if str(d.get("k", "")) == "law_amend" and str(d.get("measure", "")) == measure_id:
			return true
	return false

func _has_term(terms: Array, kind: String, by: String, issue: String) -> bool:
	for t in terms:
		var d: Dictionary = t
		if str(d.get("k", "")) == kind and str(d.get("by", "")) == by and (issue == "" or str(d.get("issue", "")) == issue):
			return true
	return false

## Medida concreta que `party_id` defendería en un tema: {measure, to, text} o {} si no hay catálogo para ese tema.
func policy_demand(party_id: String, issue: String) -> Dictionary:
	m.eco.ensure()
	var best: Dictionary = {}
	var best_score := 0.05
	for a in Policies.areas():
		if str((a as Dictionary).get("issue", "")) != issue:
			continue
		for it in Policies.measures_of(str((a as Dictionary)["id"])):
			var meas: Dictionary = it
			var cur := m.eco.value(str(meas["id"]))
			for dirn in [-1.0, 1.0]:
				var nv := Policies.snap(meas, cur + dirn * float(meas["step"]))
				if is_equal_approx(nv, cur):
					continue
				var pref: float = m.laws.measure_pref(party_id, meas) * dirn
				if pref > best_score:
					best_score = pref
					best = {"measure": str(meas["id"]), "to": nv,
						"text": "%s: %s" % [str(meas["name"]), Policies.value_text(meas, nv)]}
	return best

## Término de negociación sobre un tema, con medida concreta cuando la hay. `by` = quien la asume ("player" o "ai").
func policy_term(party_id: String, by: String, issue: String) -> Dictionary:
	var term := {"k": "policy", "by": by, "issue": issue, "text": _policy_text(party_id, issue)}
	var d := policy_demand(party_id, issue)
	if not d.is_empty():
		term["text"] = str(d["text"])
		term["measure"] = str(d["measure"])
		term["to"] = float(d["to"])
	if by == "ai":
		term["lean"] = lean(m.pid(), issue)
	return term

## Exigencia inegociable de un partido: sin ella no apoya nada. Todos tienen una; sólo los más rígidos suman una segunda.
func must_terms(ai_id: String) -> Array:
	var out: Array = []
	var tops := top_issues(ai_id, 2)
	if tops.is_empty():
		return out
	out.append(policy_term(ai_id, "player", str(tops[0])))
	if tops.size() > 1 and float(profile(ai_id).get("rigidity", 0.5)) >= 0.7:
		out.append(policy_term(ai_id, "player", str(tops[1])))
	return out

## Exigencias inegociables que aún no figuran en la mesa.
func missing_must(ai_id: String, terms: Array) -> Array:
	var out: Array = []
	for mt in must_terms(ai_id):
		if not _has_term(terms, "policy", "player", str((mt as Dictionary)["issue"])):
			out.append(mt)
	return out

func _policy_text(ai_id: String, issue: String) -> String:
	var group := m.ai.demand_group(issue)
	var pool: Array = Rules.DEMANDS.get(group, Rules.DEMANDS["economy"])
	for e in pool:
		if str((e as Dictionary)["issue"]) == issue:
			return str((e as Dictionary)["text"])
	return Rules.issue_name(issue)

func term_text(t: Dictionary) -> String:
	match str(t.get("k", "")):
		"vote_yes": return "voto a favor" if str(t.get("by", "player")) == "ai" else "tu voto a favor"
		"vote_abstain": return "abstención" if str(t.get("by", "player")) == "ai" else "tu abstención"
		"cabinet": return "%d %s en el Gobierno" % [int(t.get("n", 1)), "cartera" if int(t.get("n", 1)) == 1 else "carteras"]
		"policy": return str(t.get("text", "una medida"))
		"bills": return "votar %d %s juntos" % [int(t.get("n", 1)), "ley" if int(t.get("n", 1)) == 1 else "leyes"]
		"joint_list": return "presentarse en candidatura conjunta"
		"stability": return "un pacto de estabilidad"
		"law_vote":
			var lw := m.laws.find(str(t.get("law", "")))
			return "voto a favor de «%s»" % str(lw.get("title", "tu ley"))
		"law_abstain":
			var lw2 := m.laws.find(str(t.get("law", "")))
			return "abstención en «%s»" % str(lw2.get("title", "tu ley"))
		"law_amend": return str(t.get("text", "un cambio en la ley"))
		"owe_vote": return "devolver el favor: votar a favor de una ley suya"
		"cordon": return "no pactar con %s" % m.party_short(str(t.get("target", "")))
		"participation":
			var md := str(t.get("mode", "external"))
			return "participar como %s" % str(Rules.MODALITIES.get(md, {}).get("name", md)).to_lower()
		"structure":
			match str(t.get("what", "coordination")):
				"vicepresidency": return "una vicepresidencia del Gobierno" if str(t.get("by", "player")) != "ai" else "una vicepresidencia para ti"
				"independents": return "que el presidente pueda nombrar independientes en sus ministerios" if str(t.get("by", "player")) == "ai" else "admitir independientes en tus ministerios"
				"max_ministries": return "un Gobierno de %d ministerios como máximo" % int(t.get("n", 14))
				"min_ministries": return "un Gobierno de al menos %d ministerios" % int(t.get("n", 12))
			return "un órgano de coordinación del Gobierno"
		"portfolio":
			var nm := Competencies.name_of(str(t.get("comp", "")))
			return ("la cartera de %s" % nm) if str(t.get("by", "player")) != "ai" else ("ceder la cartera de %s" % nm)
		"objective": return str(t.get("text", "un objetivo medible"))
		"territory": return "%s%s" % [str(TERRITORY_WHAT.get(str(t.get("what", "invest")), "Una cesión territorial")), " (nivel %d)" % int(t.get("n", 1)) if int(t.get("n", 1)) > 1 else ""]
		"budget": return "una dotación presupuestaria %s para %s" % [["básica", "reforzada", "prioritaria"][clampi(int(t.get("n", 1)) - 1, 0, 2)], Rules.issue_name(str(t.get("issue", "jobs"))).to_lower()]
		"parliament": return str(PARLIAMENT_WHAT.get(str(t.get("what", "agenda")), "un compromiso parlamentario")).to_lower()
		"institution": return str(INSTITUTION_WHAT.get(str(t.get("what", "appointment")), "un acuerdo institucional")).to_lower()
		"calendar":
			var mo := int(t.get("n", 6))
			var base := str(CALENDAR_WHAT.get(str(t.get("what", "review")), "una garantía de calendario")).to_lower()
			return "%s (%d meses)" % [base, mo] if str(t.get("what", "")) != "resolution" else base
	return "una condición"

# ---------------------------------------------------------------- iniciativa propia
## Los partidos también toman la iniciativa: proponen pactos o piden reuniones al jugador.
func initiative(stage: String) -> void:
	if m.rng.randf() > (0.11 if stage == "campaign" else 0.30):
		return
	for item in m.news():
		var msg: Dictionary = item
		if str(msg.get("key", "")).begins_with("proposal") and bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)):
			return
	var pool: Array = []
	var weights: Array = []
	for p in m.rivals:
		var id := str((p as Dictionary).get("id", ""))
		if stage != "campaign" and m.seats_of(id) <= 0:
			continue
		if blocked_by(id, m.pid()) != "":
			continue
		var disp := disposition(id, m.pid())
		if disp >= 48.0:
			pool.append(id)
			weights.append(disp * (0.5 + trait_of(id, "ambition")))
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
	var short := m.party_short(chosen)
	var topic := ""
	var title := ""
	var body := ""
	var law_id := ""
	var terms: Array = []
	if stage == "campaign":
		if compat(chosen, m.pid()) >= 0.55 and m.poll_of(chosen) < m.player_poll() * 0.8 and gate(chosen, m.pid(), "joint_list") == "":
			topic = "joint_list"
			title = "%s propone ir en candidatura conjunta" % short
			body = "%s cree que sumar fuerzas beneficia a ambos y os plantea presentaros juntos a las elecciones." % short
		elif gate(chosen, m.pid(), "vote_yes") == "":
			topic = "pre_pact"
			title = "%s propone atar un pacto para después de las elecciones" % short
			body = "%s quiere dejar acordado su apoyo mutuo antes de saber el resultado." % short
		else:
			return
	else:
		var deal := _law_proposal(chosen)
		if not deal.is_empty():
			topic = "law_deal"
			law_id = str(deal["law"])
			title = "%s te propone cambios para votar tu ley" % short
			body = "Apoyarían «%s» si aceptas: %s." % [str(deal["title"]), str(deal["summary"])]
		elif (m.gov.player_in_government() or m.role() == "partner") and m.gov.stability() < 60.0 and gate(chosen, m.pid(), "stability") == "":
			topic = "stability"
			title = "%s plantea un pacto de estabilidad" % short
			body = "%s quiere garantías sobre el rumbo del Gobierno antes de comprometer su apoyo durante la legislatura." % short
		else:
			topic = "bills"
			title = "%s plantea votar leyes en común" % short
			body = "%s propone un intercambio de apoyos en iniciativas concretas." % short
	terms = m.diplomacy.dyn.agenda_for(chosen, topic, {"law": law_id})
	if terms.is_empty():
		return
	body += " Sobre la mesa: %s." % m.diplomacy._summary_text(terms, false)
	var actions: Array = [
		{"id": "diplo_accept", "label": "Aceptar la propuesta tal cual", "style": "good"},
		{"id": "diplo_meet", "label": "Sentarse a negociar", "style": "primary"},
		{"id": "diplo_decline", "label": "Declinar", "style": "ghost"},
	]
	m.publish(title, body, "NEGOCIACIONES", "positive", {
		"needs_response": true, "expires_in": 4 if stage == "campaign" else 1, "key": "proposal_" + chosen, "speaker_id": chosen,
		"actions": actions, "data": {"party": chosen, "topic": topic, "terms": terms, "law": law_id}
	})

## Un partido que no apoyaría tu ley tal cual propone enmiendas para votarla. {} si no hay ley que negociar.
func _law_proposal(party_id: String) -> Dictionary:
	if m.phase != "legislature":
		return {}
	var laws: Array = []
	for l in m.diplomacy.deal_laws():
		if m.laws.is_registered(str((l as Dictionary)["id"])) and not (l as Dictionary).get("committed", {}).has(party_id):
			laws.append(l)
	if laws.is_empty():
		return {}
	var law: Dictionary = laws[m.rng.randi() % laws.size()]
	var st: Dictionary = m.laws.stance(law, party_id)
	if str(st["vote"]) == "yes" or (st["conditions"] as Array).is_empty():
		return {}
	var terms: Array = [{"k": "law_vote", "by": "ai", "law": str(law["id"])}]
	var texts: Array = []
	for cond in (st["conditions"] as Array).slice(0, 2):
		var cd: Dictionary = cond
		terms.append({"k": "law_amend", "by": "player", "law": str(law["id"]), "type": str(cd["type"]), "measure": str(cd["measure"]), "value": float(cd["value"]), "text": str(cd["text"])})
		texts.append(str(cd["text"]).to_lower())
	return {"law": str(law["id"]), "title": str(law["title"]), "terms": terms, "summary": " y ".join(texts)}
