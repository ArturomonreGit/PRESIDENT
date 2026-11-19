class_name Ideology
extends RefCounted
## Catálogo de ideologías y composición del perfil de un partido. Cada ideología aporta peso a las 20 claves del
## perfil ideológico y un vector en los tres ejes (economía, valores, territorio). El jugador reparte una bolsa de
## puntos de fuerza entre ideologías; de ahí salen el perfil, los ejes, la coherencia interna y la afinidad con
## cada partido. Ejes: economic -1 izquierda … +1 derecha · social -1 progresista … +1 conservador ·
## territorial -1 centralista … +1 descentralizador.

const BUDGET := 14
const MAX_PICKS := 6
const MAX_STRENGTH := 5

## Elegir alguna de estas ideologías limita al partido nuevo a una sola comunidad autónoma al principio.
const TERRITORIAL_IDS := ["regionalismo", "independentismo"]

const CATALOG := [
	{"id": "liberalismo", "name": "Liberalismo", "group": "Economía", "axes": [0.70, 0.0, 0.0],
		"desc": "Mercado libre, impuestos bajos y poco Estado.", "profile": {"liberalismo_economico": 90, "europeismo": 25}},
	{"id": "libertarismo", "name": "Libertarismo", "group": "Economía", "axes": [1.0, -0.3, 0.0],
		"desc": "Libertad individual máxima y Estado mínimo.", "profile": {"liberalismo_economico": 100, "anarquismo": 12, "progresismo": 10}},
	{"id": "socialdemocracia", "name": "Socialdemocracia", "group": "Economía", "axes": [-0.45, -0.4, 0.0],
		"desc": "Estado del bienestar, servicios públicos y mercado regulado.", "profile": {"socialdemocracia": 90, "igualdad": 60, "europeismo": 40, "progresismo": 30, "feminismo": 20}},
	{"id": "socialismo", "name": "Socialismo", "group": "Economía", "axes": [-0.75, -0.5, 0.0],
		"desc": "Propiedad pública de lo esencial y redistribución fuerte.", "profile": {"socialismo": 88, "igualdad": 75, "socialdemocracia": 35, "laicismo": 20}},
	{"id": "comunismo", "name": "Comunismo", "group": "Economía", "axes": [-1.0, -0.5, -0.1],
		"desc": "Economía planificada y superación del capitalismo.", "profile": {"comunismo": 92, "socialismo": 55, "republicanismo": 45, "laicismo": 35, "igualdad": 60}},
	{"id": "anarquismo", "name": "Anarquismo", "group": "Economía", "axes": [-0.8, -0.9, 0.3],
		"desc": "Sociedad sin Estado, autogestión y libertad radical.", "profile": {"anarquismo": 92, "igualdad": 50, "laicismo": 40, "animalismo": 20, "progresismo": 40}},
	{"id": "centrismo", "name": "Centrismo moderado", "group": "Economía", "axes": [0.05, 0.0, 0.0],
		"desc": "Moderación, consensos amplios y gestión pragmática.", "profile": {"europeismo": 40, "socialdemocracia": 25, "liberalismo_economico": 25, "progresismo": 15}},
	{"id": "liberalismosocial", "name": "Liberalismo social", "group": "Economía", "axes": [0.2, -0.45, 0.0],
		"desc": "Libertades individuales, mercado y una red de protección mínima.", "profile": {"liberalismo_economico": 55, "progresismo": 55, "europeismo": 40, "laicismo": 25, "igualdad": 20}},
	{"id": "liberalconservador", "name": "Liberal-conservadurismo", "group": "Economía", "axes": [0.6, 0.5, 0.0],
		"desc": "Mercado libre con valores tradicionales e instituciones fuertes.", "profile": {"liberalismo_economico": 65, "conservadurismo": 60, "monarquismo": 25, "patriotismo": 25, "europeismo": 25}},
	{"id": "populismoizq", "name": "Populismo de izquierdas", "group": "Economía", "axes": [-0.7, -0.4, 0.1],
		"desc": "La gente frente a las élites: banca, privilegios y redistribución.", "profile": {"socialismo": 60, "igualdad": 65, "republicanismo": 30, "progresismo": 30}},
	{"id": "ecosocialismo", "name": "Ecosocialismo", "group": "Economía", "axes": [-0.7, -0.55, 0.1],
		"desc": "Planificación económica al servicio de la transición ecológica.", "profile": {"socialismo": 55, "ecologismo": 70, "igualdad": 55, "progresismo": 35}},
	{"id": "laborismo", "name": "Laborismo y sindicalismo", "group": "Economía", "axes": [-0.55, -0.15, 0.0],
		"desc": "Derechos laborales, negociación colectiva y salarios dignos.", "profile": {"socialdemocracia": 55, "igualdad": 60, "socialismo": 35}},
	{"id": "tecnocracia", "name": "Tecnocracia", "group": "Economía", "axes": [0.15, 0.0, 0.0],
		"desc": "Gobiernan los expertos: datos, eficiencia y poca ideología.", "profile": {"europeismo": 45, "liberalismo_economico": 35, "socialdemocracia": 20}},
	{"id": "conservadurismo", "name": "Conservadurismo", "group": "Valores", "axes": [0.3, 0.8, 0.0],
		"desc": "Tradición, orden, familia y cambios graduales.", "profile": {"conservadurismo": 88, "monarquismo": 35, "patriotismo": 30, "cristianodemocracia": 25}},
	{"id": "democraciacristiana", "name": "Democracia cristiana", "group": "Valores", "axes": [0.2, 0.55, 0.0],
		"desc": "Humanismo cristiano, familia y economía social de mercado.", "profile": {"cristianodemocracia": 90, "conservadurismo": 40, "europeismo": 35, "igualdad": 12}},
	{"id": "progresismo", "name": "Progresismo", "group": "Valores", "axes": [0.1, -0.7, 0.0],
		"desc": "Derechos civiles, diversidad y modernización.", "profile": {"progresismo": 85, "europeismo": 45, "laicismo": 30, "liberalismo_economico": 25, "feminismo": 25}},
	{"id": "feminismo", "name": "Feminismo", "group": "Valores", "axes": [-0.15, -0.8, 0.0],
		"desc": "Igualdad real entre mujeres y hombres.", "profile": {"feminismo": 92, "igualdad": 50, "progresismo": 40}},
	{"id": "ecologismo", "name": "Ecologismo", "group": "Valores", "axes": [-0.3, -0.5, 0.0],
		"desc": "Transición ecológica y límites ambientales.", "profile": {"ecologismo": 92, "progresismo": 30, "animalismo": 30, "europeismo": 25}},
	{"id": "animalismo", "name": "Animalismo", "group": "Valores", "axes": [-0.1, -0.6, 0.0],
		"desc": "Protección y derechos de los animales.", "profile": {"animalismo": 92, "ecologismo": 30, "progresismo": 25}},
	{"id": "laicismo", "name": "Laicismo", "group": "Valores", "axes": [-0.1, -0.6, 0.0],
		"desc": "Separación estricta entre Iglesia y Estado.", "profile": {"laicismo": 92, "progresismo": 30}},
	{"id": "pacifismo", "name": "Pacifismo", "group": "Valores", "axes": [-0.35, -0.5, 0.0],
		"desc": "Rechazo a la guerra, desarme y diplomacia por encima de todo.", "profile": {"progresismo": 35, "igualdad": 25, "ecologismo": 20, "anarquismo": 10}},
	{"id": "nacionalpopulismo", "name": "Nacional-populismo", "group": "Identidad", "axes": [0.3, 0.9, -1.0],
		"desc": "Soberanía nacional, mano dura y desconfianza hacia las élites.", "profile": {"patriotismo": 95, "centralismo": 90, "conservadurismo": 72, "monarquismo": 40}},
	{"id": "patriotismo", "name": "Patriotismo español", "group": "Identidad", "axes": [0.3, 0.55, -0.85],
		"desc": "Unidad de España y símbolos comunes.", "profile": {"patriotismo": 90, "centralismo": 70, "monarquismo": 40, "conservadurismo": 40, "europeismo": 25}},
	{"id": "centralismo", "name": "Centralismo", "group": "Identidad", "axes": [0.1, 0.2, -0.8],
		"desc": "Estado unitario con competencias fuertes en el centro.", "profile": {"centralismo": 92, "patriotismo": 30}},
	{"id": "federalismo", "name": "Federalismo", "group": "Identidad", "axes": [-0.1, -0.2, 0.5],
		"desc": "Reparto federal del poder entre territorios.", "profile": {"federalismo": 92, "europeismo": 35, "progresismo": 15}},
	{"id": "regionalismo", "name": "Regionalismo", "group": "Identidad", "axes": [0.0, 0.0, 0.9],
		"desc": "Defensa de un territorio y su autogobierno. Empiezas presentándote solo en una comunidad.", "profile": {"nacionalismo": 92, "federalismo": 20}},
	{"id": "independentismo", "name": "Independentismo", "group": "Identidad", "axes": [-0.1, -0.3, 1.0],
		"desc": "Derecho a decidir y Estado propio. Empiezas presentándote solo en una comunidad.", "profile": {"nacionalismo": 100, "republicanismo": 35, "federalismo": 8}},
	{"id": "republicanismo", "name": "Republicanismo", "group": "Identidad", "axes": [-0.2, -0.3, 0.2],
		"desc": "Jefatura del Estado electa y fin de la monarquía.", "profile": {"republicanismo": 92, "laicismo": 30, "federalismo": 20}},
	{"id": "monarquismo", "name": "Monarquismo", "group": "Identidad", "axes": [0.2, 0.3, -0.2],
		"desc": "Defensa de la Corona y la continuidad institucional.", "profile": {"monarquismo": 92, "conservadurismo": 25}},
	{"id": "euroescepticismo", "name": "Euroescepticismo", "group": "Identidad", "axes": [0.2, 0.3, -0.3],
		"desc": "Menos Bruselas y más soberanía nacional en las decisiones clave.", "profile": {"patriotismo": 50, "nacionalismo": 25, "conservadurismo": 20}},
	{"id": "ruralismo", "name": "Ruralismo", "group": "Identidad", "axes": [0.1, 0.25, 0.4],
		"desc": "Defensa del mundo rural, la agricultura y la España vaciada.", "profile": {"conservadurismo": 30, "federalismo": 25, "ecologismo": 15}},
	{"id": "europeismo", "name": "Europeísmo", "group": "Identidad", "axes": [0.0, -0.1, 0.1],
		"desc": "Más integración y soberanía compartida en la UE.", "profile": {"europeismo": 95}},
]

## Pares que tiran en direcciones opuestas. Elegirlos a la vez resta coherencia interna.
const CONFLICTS := [
	["liberalismo", "socialismo"], ["liberalismo", "comunismo"], ["liberalismo", "socialdemocracia"],
	["libertarismo", "socialdemocracia"], ["libertarismo", "socialismo"], ["libertarismo", "comunismo"],
	["conservadurismo", "progresismo"], ["conservadurismo", "feminismo"], ["conservadurismo", "laicismo"],
	["democraciacristiana", "laicismo"], ["democraciacristiana", "progresismo"],
	["monarquismo", "republicanismo"], ["monarquismo", "comunismo"], ["monarquismo", "anarquismo"],
	["centralismo", "independentismo"], ["centralismo", "regionalismo"], ["centralismo", "federalismo"],
	["patriotismo", "independentismo"], ["patriotismo", "regionalismo"], ["nacionalpopulismo", "federalismo"],
	["nacionalpopulismo", "progresismo"], ["nacionalpopulismo", "europeismo"], ["nacionalpopulismo", "regionalismo"],
	["nacionalpopulismo", "independentismo"], ["anarquismo", "conservadurismo"], ["anarquismo", "patriotismo"],
	["comunismo", "democraciacristiana"], ["centrismo", "comunismo"], ["centrismo", "nacionalpopulismo"],
	["centrismo", "independentismo"],
	["euroescepticismo", "europeismo"], ["euroescepticismo", "liberalismosocial"], ["populismoizq", "liberalismo"],
	["populismoizq", "liberalconservador"], ["liberalconservador", "socialismo"], ["liberalconservador", "comunismo"],
	["liberalismosocial", "conservadurismo"], ["liberalismosocial", "nacionalpopulismo"], ["tecnocracia", "populismoizq"],
	["tecnocracia", "nacionalpopulismo"], ["ecosocialismo", "liberalismo"], ["ecosocialismo", "libertarismo"],
	["laborismo", "libertarismo"], ["pacifismo", "nacionalpopulismo"], ["ruralismo", "ecosocialismo"],
]

static func is_territorial(picks: Array) -> bool:
	for p in picks:
		if TERRITORIAL_IDS.has(str((p as Dictionary).get("id", ""))):
			return true
	return false

static func by_id(id: String) -> Dictionary:
	for it in CATALOG:
		if str((it as Dictionary)["id"]) == id:
			return it
	return {}

static func name_of(id: String) -> String:
	return str(by_id(id).get("name", id))

static func groups() -> Array:
	var out: Array = []
	for it in CATALOG:
		var g := str((it as Dictionary)["group"])
		if not out.has(g):
			out.append(g)
	return out

## picks: [{id, strength}] con strength 1..5.
static func points_used(picks: Array) -> int:
	var t := 0
	for p in picks:
		t += int((p as Dictionary).get("strength", 0))
	return t

static func normalize(picks: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for p in picks:
		var d: Dictionary = p
		var id := str(d.get("id", ""))
		if id == "" or seen.has(id) or by_id(id).is_empty():
			continue
		seen[id] = true
		out.append({"id": id, "strength": clampi(int(d.get("strength", 1)), 1, MAX_STRENGTH)})
		if out.size() >= MAX_PICKS:
			break
	return out

static func conflicts(picks: Array) -> Array:
	var strength: Dictionary = {}
	for p in picks:
		strength[str((p as Dictionary)["id"])] = int((p as Dictionary)["strength"])
	var out: Array = []
	for pair in CONFLICTS:
		var a := str(pair[0])
		var b := str(pair[1])
		if strength.has(a) and strength.has(b):
			var sev := float(mini(int(strength[a]), int(strength[b]))) / float(MAX_STRENGTH)
			out.append({"a": a, "b": b, "severity": sev, "text": "%s ↔ %s" % [name_of(a), name_of(b)]})
	return out

## Perfil de fondo que cualquier partido tiene según su posición en los ejes (los partidos reales tienen un perfil
## completo; sin esto un partido propio, con pocas ideologías, parecería "vacío" y poco afín a todos).
static func baseline(axes: Dictionary) -> Dictionary:
	var e := float(axes.get("economic", 0.0))
	var so := float(axes.get("social", 0.0))
	var t := float(axes.get("territorial", 0.0))
	var b := {
		"liberalismo_economico": 45.0 + 45.0 * e, "conservadurismo": 40.0 + 45.0 * so, "cristianodemocracia": 25.0 + 25.0 * so,
		"patriotismo": 40.0 + 25.0 * so - 25.0 * t, "europeismo": 55.0 - 10.0 * absf(so), "feminismo": 45.0 - 35.0 * so,
		"igualdad": 50.0 - 40.0 * e - 10.0 * so, "ecologismo": 40.0 - 15.0 * so - 10.0 * e, "socialdemocracia": 40.0 - 30.0 * e,
		"socialismo": 25.0 - 35.0 * e, "republicanismo": 25.0 - 15.0 * so + 10.0 * t, "federalismo": 25.0 + 25.0 * t,
		"centralismo": 35.0 - 35.0 * t, "laicismo": 35.0 - 25.0 * so, "nacionalismo": 20.0 + 30.0 * t,
		"comunismo": 5.0 - 12.0 * e, "anarquismo": 5.0, "animalismo": 20.0 - 8.0 * so, "progresismo": 45.0 - 40.0 * so,
		"monarquismo": 40.0 + 30.0 * so,
	}
	for k in b.keys():
		b[k] = clampf(float(b[k]), 0.0, 100.0)
	return b

## Devuelve {profile, axes, coherence, conflicts, bloc, tags}.
static func compose(raw_picks: Array) -> Dictionary:
	var picks := normalize(raw_picks)
	var profile: Dictionary = {}
	for k in PartyBrain.PROFILE_KEYS:
		profile[k] = 0.0
	var total := 0.0
	var ax := [0.0, 0.0, 0.0]
	for p in picks:
		var it := by_id(str((p as Dictionary)["id"]))
		var s := float(int((p as Dictionary)["strength"])) / float(MAX_STRENGTH)
		total += s
		for k in (it["profile"] as Dictionary).keys():
			profile[k] = minf(100.0, float(profile.get(k, 0.0)) + s * float((it["profile"] as Dictionary)[k]))
		for i in range(3):
			ax[i] += s * float((it["axes"] as Array)[i])
	var axes := {"economic": 0.0, "social": 0.0, "territorial": 0.0}
	if total > 0.0:
		var factor := clampf(0.35 + 0.65 * total, 0.0, 1.0)
		axes["economic"] = clampf(ax[0] / total * factor, -1.0, 1.0)
		axes["social"] = clampf(ax[1] / total * factor, -1.0, 1.0)
		axes["territorial"] = clampf(ax[2] / total * factor, -1.0, 1.0)
	var cf := conflicts(picks)
	var pen := 0.0
	for c in cf:
		pen += float((c as Dictionary)["severity"]) * 0.38
	var coherence := clampf(1.0 - pen, 0.15, 1.0)
	var out_profile: Dictionary = {}
	var base := baseline(axes) if total > 0.0 else {}
	for k in profile.keys():
		out_profile[k] = int(round(maxf(float(profile[k]), float(base.get(k, 0.0)))))
	return {"picks": picks, "profile": out_profile, "axes": axes, "coherence": coherence, "conflicts": cf,
		"bloc": bloc_name(axes, out_profile), "score": bloc_score(axes)}

# ---------------------------------------------------------------- posición y bloques
## Posición izquierda-derecha 0 centro; negativo izquierda.
static func bloc_score(axes: Dictionary) -> float:
	return 0.55 * float(axes.get("economic", 0.0)) + 0.45 * float(axes.get("social", 0.0))

static func bloc_name(axes: Dictionary, profile: Dictionary) -> String:
	var sc := bloc_score(axes)
	var terr := float(axes.get("territorial", 0.0))
	var base := "Centro"
	if sc < -0.62: base = "Izquierda radical"
	elif sc < -0.32: base = "Izquierda"
	elif sc < -0.1: base = "Centroizquierda"
	elif sc <= 0.1: base = "Centro"
	elif sc <= 0.3: base = "Centroderecha"
	elif sc <= 0.55: base = "Derecha"
	else: base = "Derecha radical"
	if terr >= 0.55:
		return "%s · nacionalista periférica" % base
	if terr <= -0.6:
		return "%s · centralista" % base
	return base

## Etiqueta corta con tres rasgos para tarjetas.
static func tagline(axes: Dictionary, profile: Dictionary) -> String:
	var parts: Array = [bloc_name(axes, profile)]
	var soc := float(axes.get("social", 0.0))
	if soc <= -0.55: parts.append("progresista")
	elif soc >= 0.55: parts.append("conservador")
	return " · ".join(parts)

# ---------------------------------------------------------------- afinidad
static func axes_distance(a: Dictionary, b: Dictionary) -> float:
	var sum := 0.0
	for axis in ["economic", "social", "territorial"]:
		var d := float(a.get(axis, 0.0)) - float(b.get(axis, 0.0))
		sum += d * d
	return clampf(sqrt(sum / 3.0) / 2.0, 0.0, 1.0)

static func affinity(axes_a: Dictionary, axes_b: Dictionary) -> float:
	return clampf(1.0 - axes_distance(axes_a, axes_b) * 1.8, 0.0, 1.0)

static func profile_similarity(pa: Dictionary, pb: Dictionary) -> float:
	var diff := 0.0
	for k in PartyBrain.PROFILE_KEYS:
		diff += absf(float(pa.get(k, 0.0)) - float(pb.get(k, 0.0)))
	return clampf(1.0 - diff / (100.0 * float(PartyBrain.PROFILE_KEYS.size())) * 2.2, 0.0, 1.0)

## Misma fórmula que PartyBrain.compat, pero sobre datos de partido sueltos.
static func compat(party_a: Dictionary, party_b: Dictionary) -> float:
	var a := affinity(party_a.get("ideology", {}), party_b.get("ideology", {}))
	var s := profile_similarity(party_a.get("ideology_profile", {}), party_b.get("ideology_profile", {}))
	return clampf(0.5 * a + 0.5 * s, 0.0, 1.0)

## Afinidad prevista de una composición con todos los partidos del escenario. Ordenada de mayor a menor.
static func preview(composition: Dictionary) -> Array:
	var me := {"ideology": composition["axes"], "ideology_profile": composition["profile"]}
	var out: Array = []
	for p in DataStore.parties():
		var d: Dictionary = p
		var c := compat(me, d)
		out.append({"id": str(d["id"]), "name": str(d.get("short_name", d["id"])), "color": str(d.get("color", "#888888")), "compat": c,
			"bloc": bloc_name(d.get("ideology", {}), d.get("ideology_profile", {}))})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["compat"]) > float(y["compat"]))
	return out

## Estima las picks de un partido existente (para mostrar su ideología como la del jugador).
static func infer_picks(party: Dictionary, max_n: int = 4) -> Array:
	if party.has("ideology_picks"):
		return party["ideology_picks"]
	var prof: Dictionary = party.get("ideology_profile", {})
	var scored: Array = []
	for it in CATALOG:
		var d: Dictionary = it
		var sc := 0.0
		var cnt := 0.0
		for k in (d["profile"] as Dictionary).keys():
			var w := float((d["profile"] as Dictionary)[k])
			sc += w * float(prof.get(k, 0.0)) / 100.0
			cnt += w
		scored.append({"id": str(d["id"]), "score": sc / maxf(cnt, 1.0)})
	scored.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["score"]) > float(y["score"]))
	var out: Array = []
	for i in range(mini(max_n, scored.size())):
		var s := float((scored[i] as Dictionary)["score"])
		if s < 0.3:
			break
		out.append({"id": str((scored[i] as Dictionary)["id"]), "strength": clampi(int(round(s * 5.0)), 1, MAX_STRENGTH)})
	return out
