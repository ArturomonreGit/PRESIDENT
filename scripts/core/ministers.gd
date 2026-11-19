class_name Ministers
extends RefCounted
## Ministros del Consejo: personajes políticos con atributos, personalidad, relación con el presidente e historial.
## El jugador elige los de su partido entre una cantera propia; la IA nombra a los suyos. Un buen ministro mejora las
## áreas que gestiona según su capacidad, su experiencia y su especialidad.

var m: GameModel

const POOL_SIZE := 12

## Atributos de un ministro (1..10).
const ATTRS := {
	"gestion": {"name": "Capacidad de gestión", "desc": "Calidad de ejecución, coordinación y respuesta a problemas."},
	"lealtad": {"name": "Lealtad", "desc": "Disciplina política y disposición a respaldar al presidente."},
	"afinidad": {"name": "Afinidad ideológica", "desc": "Cercanía a la línea del partido o del Gobierno."},
	"ambicion": {"name": "Ambición", "desc": "Búsqueda de influencia, visibilidad y liderazgo."},
	"popularidad": {"name": "Popularidad", "desc": "Capital político y percepción pública individual."},
	"experiencia": {"name": "Experiencia", "desc": "Solvencia en la cartera y ante situaciones complejas."},
	"comunicacion": {"name": "Comunicación", "desc": "Capacidad para defender decisiones y gestionar medios."},
	"integridad": {"name": "Integridad", "desc": "Riesgo de corrupción, escándalos y credibilidad."},
}
const ATTR_ORDER := ["gestion", "lealtad", "afinidad", "ambicion", "popularidad", "experiencia", "comunicacion", "integridad"]

const PERSONALITIES := {
	"tecnocrata": {"name": "Tecnócrata", "desc": "Prioriza resultados y eficiencia; puede chocar con decisiones partidistas.",
		"bias": {"gestion": 2, "experiencia": 1, "lealtad": -1, "ambicion": -1}, "style": "técnico"},
	"ambicioso": {"name": "Ambicioso", "desc": "Busca influencia y exposición, y puede aspirar al liderazgo.",
		"bias": {"ambicion": 3, "popularidad": 1, "lealtad": -1}, "style": "político"},
	"leal": {"name": "Leal", "desc": "Respalda al presidente y evita conflictos públicos.",
		"bias": {"lealtad": 3, "ambicion": -2, "comunicacion": -1}, "style": "político"},
	"mediatico": {"name": "Mediático", "desc": "Busca protagonismo; puede mejorar la comunicación o generar polémicas.",
		"bias": {"comunicacion": 3, "popularidad": 2, "integridad": -1}, "style": "político"},
	"ideologico": {"name": "Ideológico", "desc": "Defiende principios y puede resistirse a concesiones.",
		"bias": {"afinidad": 3, "lealtad": -1, "comunicacion": 1}, "style": "político"},
	"conciliador": {"name": "Conciliador", "desc": "Facilita acuerdos y coordinación.",
		"bias": {"lealtad": 1, "comunicacion": 1, "ambicion": -1, "afinidad": -1}, "style": "técnico"},
	"inexperto": {"name": "Inexperto", "desc": "Puede cometer errores y necesitar supervisión.",
		"bias": {"experiencia": -3, "gestion": -1, "popularidad": -1}, "style": "técnico"},
	"independiente": {"name": "Independiente", "desc": "Aporta credibilidad técnica, pero tiene menor disciplina partidista.",
		"bias": {"integridad": 2, "lealtad": -2, "gestion": 1, "afinidad": -2}, "style": "técnico"},
}
const PERSONALITY_ORDER := ["tecnocrata", "ambicioso", "leal", "mediatico", "ideologico", "conciliador", "inexperto", "independiente"]

func _init(model: GameModel) -> void:
	m = model

func _focus(ministry: String) -> String:
	return str((Policies.data().get("ministry_focus", {}) as Dictionary).get(ministry, ""))

# ---------------------------------------------------------------- generación
## Genera un ministro de un partido: personaje + atributos + personalidad + especialidad.
func generate(party_id: String, seed_value: int) -> Dictionary:
	var ch := Leader.generate(party_id, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("min_%s_%d" % [party_id, seed_value])
	var focus_keys: Array = (Policies.data().get("ministry_focus", {}) as Dictionary).keys()
	ch["specialty"] = str(focus_keys[rng.randi_range(0, focus_keys.size() - 1)])
	ch["style"] = "político" if rng.randf() < 0.45 else "técnico"
	ch["pool_id"] = seed_value
	ch["party"] = party_id
	var skill := clampi(int(round(rng.randfn(6.0, 1.6))), 3, 9)
	_build_profile(ch, rng, skill)
	return ch

func _build_profile(ch: Dictionary, rng: RandomNumberGenerator, skill: int) -> void:
	# La personalidad sale del estilo (técnico/político) con algo de variación.
	var pool: Array = []
	for pid in PERSONALITY_ORDER:
		var st := str((PERSONALITIES[pid] as Dictionary)["style"])
		var w := 3 if st == str(ch.get("style", "técnico")) else 1
		for _i in range(w):
			pool.append(pid)
	var pers := str(pool[rng.randi_range(0, pool.size() - 1)])
	var bias: Dictionary = (PERSONALITIES[pers] as Dictionary)["bias"]
	var attrs: Dictionary = {}
	for k in ATTR_ORDER:
		var base := rng.randi_range(3, 7)
		if k == "gestion":
			base = skill
		attrs[k] = clampi(base + int(bias.get(k, 0)), 1, 10)
	ch["attrs"] = attrs
	ch["personality"] = pers
	ch["skill"] = int(attrs["gestion"])
	ch["rel"] = clampf(50.0 + (float(attrs["lealtad"]) - 5.0) * 4.0 + (float(attrs["afinidad"]) - 5.0) * 3.0, 15.0, 90.0)
	ch["act"] = 55.0
	ch["history"] = []
	ch["uid"] = "%s_%d" % [str(ch.get("party", "")), int(ch.get("pool_id", 0))]

## Atributos para ministros de partidas antiguas: se derivan de forma estable de su semilla.
func ensure_profile(ch: Dictionary) -> void:
	if ch.is_empty() or (ch.has("attrs") and ch.has("personality")):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mp_%s_%s_%d" % [str(ch.get("name", "")), str(ch.get("surname", "")), int(ch.get("pool_id", 0))])
	if not ch.has("style"):
		ch["style"] = "político" if rng.randf() < 0.45 else "técnico"
	_build_profile(ch, rng, int(ch.get("skill", 6)))

func attr(ch: Dictionary, key: String) -> int:
	ensure_profile(ch)
	return int((ch.get("attrs", {}) as Dictionary).get(key, 5))

func personality_name(ch: Dictionary) -> String:
	ensure_profile(ch)
	return str((PERSONALITIES.get(str(ch.get("personality", "")), {"name": "—"}) as Dictionary)["name"])

func personality_desc(ch: Dictionary) -> String:
	ensure_profile(ch)
	return str((PERSONALITIES.get(str(ch.get("personality", "")), {"desc": ""}) as Dictionary)["desc"])

func relation(ch: Dictionary) -> float:
	ensure_profile(ch)
	return float(ch.get("rel", 50.0))

func shift_relation(ch: Dictionary, delta: float) -> void:
	ensure_profile(ch)
	ch["rel"] = clampf(float(ch.get("rel", 50.0)) + delta, 0.0, 100.0)

func shift_attr(ch: Dictionary, key: String, delta: int) -> void:
	ensure_profile(ch)
	var a: Dictionary = ch["attrs"]
	a[key] = clampi(int(a.get(key, 5)) + delta, 1, 10)

func log_history(ch: Dictionary, text: String) -> void:
	ensure_profile(ch)
	var h: Array = ch["history"]
	h.push_front({"turn": m.turn(), "text": text})
	while h.size() > 12:
		h.pop_back()

# ---------------------------------------------------------------- competencia
## Un ministro es especialista de una cartera si su especialidad coincide con ella o comparte competencias con ella.
func specialty_match(minister: Dictionary, ministry: String, entry: Dictionary = {}) -> bool:
	var spec := str(minister.get("specialty", ""))
	if spec == "":
		return false
	if spec == ministry:
		return true
	if entry.has("comps"):
		for c in Competencies.defaults_for(spec):
			if (entry["comps"] as Array).has(c):
				return true
	return false

func effective_skill(minister: Dictionary, ministry: String, entry: Dictionary = {}) -> float:
	if minister.is_empty():
		return 4.0
	ensure_profile(minister)
	var sk := float(attr(minister, "gestion"))
	if specialty_match(minister, ministry, entry):
		sk += 2.0
	sk += (float(attr(minister, "experiencia")) - 5.0) * 0.25
	match str(minister.get("personality", "")):
		"tecnocrata": sk += 0.5
		"inexperto": sk -= 0.5
	return clampf(sk, 1.0, 11.0)

func skill_in(index: int) -> float:
	var cab := m.gov.cabinet()
	if index < 0 or index >= cab.size():
		return 4.0
	var e: Dictionary = cab[index]
	return effective_skill(e.get("minister", {}), str(e.get("name", "")), e)

## Cantera del partido del jugador (estable por ciclo).
func pool() -> Array:
	var list := m.a("minister_pool")
	if list.is_empty() or int(m.s.get("minister_pool_cycle", 0)) != m.cycle:
		list.clear()
		for i in range(POOL_SIZE):
			list.append(generate(m.pid(), m.cycle * 1000 + i + int(m.s.get("leader_seed", 7)) % 97 * 10))
		m.s["minister_pool_cycle"] = m.cycle
	for p in list:
		ensure_profile(p as Dictionary)
	return list

func _pool_taken() -> Dictionary:
	var taken: Dictionary = {}
	for e in m.gov.cabinet():
		var ed: Dictionary = e
		if str(ed.get("party", "")) == m.pid() and ed.has("minister"):
			taken[int((ed["minister"] as Dictionary).get("pool_id", -1))] = str(ed["name"])
	return taken

## Candidatos de una cartera de tu partido: los cinco de su lista (ver MinistryCandidates), de mejor a peor encaje.
func available_for(index: int) -> Array:
	var cab := m.gov.cabinet()
	if index < 0 or index >= cab.size():
		return []
	var entry: Dictionary = cab[index]
	var ministry := str(entry["name"])
	var out: Array = m.cands.shortlist(index).duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return effective_skill(a, ministry, entry) > effective_skill(b, ministry, entry))
	return out

func assign(index: int, pool_id: int) -> void:
	var cab := m.gov.cabinet()
	if index < 0 or index >= cab.size():
		return
	var entry: Dictionary = cab[index]
	if str(entry.get("party", "")) != m.pid():
		return
	if m.cands.appoint(index, pool_id):
		return
	for p in pool():
		if int((p as Dictionary)["pool_id"]) == pool_id:
			entry["minister"] = (p as Dictionary).duplicate(true)
			log_history(entry["minister"], "Nombrado/a para %s." % str(entry["name"]))
			return

## Rellena los ministros que faltan: la IA elige a los suyos y al jugador se le propone el mejor de su cantera.
func ensure_cabinet() -> void:
	m.cab.ensure()
	var cab := m.gov.cabinet()
	var used: Dictionary = {}
	for e in cab:
		var ed: Dictionary = e
		if str(ed.get("party", "")) == m.pid() and ed.has("minister"):
			used[int((ed["minister"] as Dictionary).get("pool_id", -1))] = true
	for i in range(cab.size()):
		var ed2: Dictionary = cab[i]
		var party_id := str(ed2.get("party", ""))
		if party_id == m.pid():
			if ed2.has("minister") and int((ed2["minister"] as Dictionary).get("pool_id", -1)) >= 0:
				ensure_profile(ed2["minister"] as Dictionary)
				continue
			# El jugador parte del candidato de mejor encaje de su lista; puede cambiarlo en la pestaña Candidatos.
			var best := {}
			var best_v := -1.0
			for c in m.cands.shortlist(i):
				var cd: Dictionary = c
				var v := effective_skill(cd, str(ed2["name"]), ed2)
				if v > best_v:
					best_v = v
					best = cd
			if not best.is_empty():
				used[int(best["pool_id"])] = true
				ed2["minister"] = best.duplicate(true)
				log_history(ed2["minister"], "Nombrado/a para %s." % str(ed2["name"]))
		elif not ed2.has("minister") or (ed2["minister"] as Dictionary).is_empty():
			# El socio elige a su ministro entre sus cinco candidatos según los rasgos de su partido.
			var mn := m.cands.ai_choose(i)
			if mn.is_empty():
				var seed_v := hash("%s_%s_%d_%d" % [party_id, str(ed2.get("id", ed2["name"])), m.cycle, m.gov_month]) % 100000
				mn = generate(party_id, seed_v)
			ed2["minister"] = mn.duplicate(true)
			log_history(ed2["minister"], "Nombrado/a para %s." % str(ed2["name"]))
		else:
			ensure_profile(ed2["minister"] as Dictionary)

func minister_at(index: int) -> Dictionary:
	var cab := m.gov.cabinet()
	if index < 0 or index >= cab.size():
		return {}
	return (cab[index] as Dictionary).get("minister", {})

## Indicadores que mejora o empeora la cartera según sus competencias.
func foci_of(entry: Dictionary) -> Array:
	var out: Array = []
	if entry.has("comps"):
		for c in entry["comps"]:
			var f := str(Competencies.by_id(str(c)).get("focus", ""))
			if f != "" and not out.has(f):
				out.append(f)
	else:
		var f2 := _focus(str(entry.get("name", "")))
		if f2 != "":
			out.append(f2)
	return out

## Mejoras totales por ministros: {indicador: puntos}. El paro mejora con valores negativos.
func bonuses() -> Dictionary:
	var out: Dictionary = {}
	if m.phase != "legislature":
		return out
	for e in m.gov.cabinet():
		var ed: Dictionary = e
		var foci := foci_of(ed)
		if foci.is_empty():
			continue
		var delta := effective_skill(ed.get("minister", {}), str(ed.get("name", "")), ed) - 5.0
		# Una cartera muy ancha dispersa el esfuerzo de su titular; el rendimiento reciente modula el efecto.
		var spread := 1.0 if foci.size() <= 2 else 0.75
		var act_mod := clampf(0.85 + float((ed.get("minister", {}) as Dictionary).get("act", 55.0)) / 200.0, 0.85, 1.3)
		for focus in foci:
			var v := delta * 0.9 * spread
			if focus == "growth":
				v = delta * 0.05 * spread
			elif focus == "unemployment":
				v = -delta * 0.08 * spread
			v *= act_mod if delta > 0.0 else 1.0
			out[focus] = float(out.get(focus, 0.0)) + v
	return out

func describe(minister: Dictionary, ministry: String, entry: Dictionary = {}) -> String:
	if minister.is_empty():
		return "Sin titular"
	return "%s · %s · competencia %d%s" % [Leader.full_name(minister), personality_name(minister), int(effective_skill(minister, ministry, entry)), " (especialista)" if specialty_match(minister, ministry, entry) else ""]
