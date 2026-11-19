class_name Executive
extends RefCounted
## Acción de Gobierno desde dentro: la cartera del jugador (presidente o ministro), las competencias de cada ministerio,
## los decretos que se aprueban sin pasar por el Congreso (con el consenso del presidente o del ministro), el capital
## político, los objetivos que marca la directiva del partido y los Presupuestos Generales del Estado.

var m: GameModel

## Ministerios que, por orden de preferencia, se encargan de cada área de política. Si no hay ninguno en el Consejo,
## el área pasa al ministerio con menos carga.
const AREA_OWNERS := {
	"housing": ["Vivienda", "Transportes y Movilidad"],
	"tax": ["Hacienda", "Economía y Empresa"],
	"health": ["Sanidad", "Derechos Sociales", "Igualdad"],
	"education": ["Educación y Formación Profesional", "Ciencia y Universidades"],
	"jobs": ["Trabajo y Economía Social", "Economía y Empresa", "Industria y Comercio", "Hacienda"],
	"energy": ["Transición Ecológica", "Industria y Comercio", "Agricultura y Alimentación", "Transportes y Movilidad", "Hacienda"],
	"security": ["Interior", "Justicia"],
	"territory": ["Política Territorial", "Presidencia y Relaciones con las Cortes"],
	"social": ["Derechos Sociales", "Igualdad", "Trabajo y Economía Social"],
	"indirect": ["Hacienda", "Consumo", "Economía y Empresa"],
	"science": ["Ciencia y Universidades", "Transformación Digital", "Educación y Formación Profesional"],
	"industry": ["Industria y Comercio", "Turismo", "Economía y Empresa"],
	"transport": ["Transportes y Movilidad", "Transición Ecológica"],
	"agriculture": ["Agricultura y Alimentación", "Transición Ecológica"],
	"justice": ["Justicia", "Interior"],
	"immigration": ["Interior", "Derechos Sociales", "Asuntos Exteriores"],
	"defense": ["Defensa", "Asuntos Exteriores"],
	"family": ["Igualdad", "Derechos Sociales", "Trabajo y Economía Social"],
}

## Área de política a la que se asocia cada partida del presupuesto cuando su ministerio no está en el Consejo.
const LINE_AREA := {
	"pensiones": "social", "sanidad": "health", "educacion": "education", "prestaciones": "social", "territorial": "territory",
	"transportes": "transport", "interior": "security", "transicion": "energy", "ciencia": "science", "agricultura": "agriculture",
	"justicia": "justice", "industria": "industry", "vivienda": "housing", "defensa": "defense",
}

## Magnitud que vigila la directiva para cada área: [indicador, sentido (1 = subir, -1 = bajar), mejora exigida].
const AREA_METRIC := {
	"housing": ["housing", 1, 3.0], "health": ["health", 1, 3.0], "education": ["education", 1, 3.0], "security": ["security", 1, 2.5],
	"energy": ["environment", 1, 3.0], "social": ["equality", 1, 3.0], "jobs": ["unemployment", -1, 0.8], "tax": ["deficit", -1, 0.4],
	"indirect": ["consumption", 1, 2.0], "science": ["digital", 1, 3.0], "industry": ["exports", 1, 1.5], "transport": ["transit_share", 1, 1.5],
	"agriculture": ["farm_income", 1, 4.0], "justice": ["court_delay", -1, 1.5], "immigration": ["tension", -1, 4.0],
	"defense": ["security", 1, 1.5], "family": ["birth", 1, 0.04],
}

## Áreas en las que todo exige una ley (reserva de ley tributaria).
const LAW_ONLY_AREAS := ["tax", "indirect"]

const PGE_MONTHS := [4, 16, 28, 40]  ## meses de legislatura (1.º trimestre del turno 2, 6, 10 y 14)
const MAX_CAPITAL := 30.0
const FACTOR_MIN := 0.8
const FACTOR_MAX := 1.25
const FACTOR_STEP := 0.025

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	return m.d("exec")

func cabinet() -> Array:
	return m.gov.cabinet()

# ---------------------------------------------------------------- competencias
func key_of(entry: Dictionary) -> String:
	return str(entry.get("key", entry.get("name", "")))

func ministry_name(idx: int) -> String:
	var cab := cabinet()
	return str((cab[idx] as Dictionary)["name"]) if idx >= 0 and idx < cab.size() else ""

func party_of(idx: int) -> String:
	var cab := cabinet()
	return str((cab[idx] as Dictionary).get("party", "")) if idx >= 0 and idx < cab.size() else ""

## Reparte las áreas entre los ministerios: {area_id: índice}.
func area_owners() -> Dictionary:
	var cab := cabinet()
	var owners: Dictionary = {}
	var loads: Dictionary = {}
	for i in range(cab.size()):
		loads[i] = 0
	var order := ["tax", "indirect", "health", "education", "science", "housing", "security", "justice", "immigration", "jobs", "industry", "energy",
		"transport", "agriculture", "social", "family", "territory", "defense"]
	for aid in order:
		var found := -1
		# Las etiquetas de competencia de cada cartera mandan sobre su nombre.
		var comp_id := Competencies.comp_of_area(str(aid))
		if comp_id != "":
			for i in range(cab.size()):
				if ((cab[i] as Dictionary).get("comps", []) as Array).has(comp_id):
					found = i
					break
		if found < 0 and not _has_comps():
			for key in AREA_OWNERS.get(aid, []):
				for i in range(cab.size()):
					if key_of(cab[i] as Dictionary) == str(key):
						found = i
						break
				if found >= 0:
					break
		if found < 0 and not cab.is_empty():
			var best_i := -1
			var best_l := 999
			for i in range(cab.size()):
				var k := key_of(cab[i] as Dictionary)
				if i == 0 or k == "Asuntos Exteriores" or k == "Defensa" or k == "Cultura":
					continue
				if int(loads[i]) < best_l:
					best_l = int(loads[i])
					best_i = i
			found = best_i if best_i >= 0 else 0
		owners[aid] = found
		if found >= 0:
			loads[found] = int(loads.get(found, 0)) + 1
	return owners

func areas_of(idx: int) -> Array:
	var out: Array = []
	var owners := area_owners()
	for a in Policies.areas():
		var aid := str((a as Dictionary)["id"])
		if int(owners.get(aid, -1)) == idx:
			out.append(aid)
	return out

## Las carteras ya llevan etiquetas de competencia (partidas nuevas o migradas).
func _has_comps() -> bool:
	for e in cabinet():
		if (e as Dictionary).has("comps"):
			return true
	return false

func line_owner(line_id: String) -> int:
	var cab := cabinet()
	var line := Policies.entry(Policies.budget(), line_id)
	var key := str(line.get("ministry", ""))
	var comp_id := Competencies.comp_of_line(line_id)
	if comp_id != "":
		for i in range(cab.size()):
			if ((cab[i] as Dictionary).get("comps", []) as Array).has(comp_id):
				return i
	if not _has_comps():
		for i in range(cab.size()):
			if key_of(cab[i] as Dictionary) == key:
				return i
	var aid := str(LINE_AREA.get(line_id, ""))
	if aid != "":
		return int(area_owners().get(aid, 0))
	return 0

func lines_of(idx: int) -> Array:
	var out: Array = []
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		if line_owner(bid) == idx:
			out.append(bid)
	return out

func has_competencies(idx: int) -> bool:
	return not areas_of(idx).is_empty() or not lines_of(idx).is_empty()

func competency_text(idx: int) -> String:
	var bits: Array = []
	for aid in areas_of(idx):
		bits.append(str(Policies.area(str(aid)).get("name", aid)))
	var n := lines_of(idx).size()
	if n > 0:
		bits.append("%d partida%s del presupuesto" % [n, "" if n == 1 else "s"])
	return ", ".join(bits) if not bits.is_empty() else "Sin competencias de política pública (representa al Gobierno)"

# ---------------------------------------------------------------- cartera del jugador
func in_cabinet() -> bool:
	return m.gov.government_parties().has(m.pid())

func is_president() -> bool:
	return str(m.s.get("government_party_id", "")) == m.pid() and m.phase in ["legislature", "cabinet_design"]

## "president", "minister" o "none".
func post_kind() -> String:
	if m.phase != "legislature":
		return "none"
	if str(m.s.get("government_party_id", "")) == m.pid():
		return "president"
	var idx := int(st().get("post", -1))
	if idx >= 0 and idx < cabinet().size() and party_of(idx) == m.pid():
		return "minister"
	return "none"

func post_index() -> int:
	return int(st().get("post", -1)) if post_kind() == "minister" else -1

func has_post() -> bool:
	return post_kind() != "none"

func post_text() -> String:
	match post_kind():
		"president": return "Presidente del Gobierno"
		"minister": return "Ministro/a de %s" % ministry_name(post_index())
	return "Sin cartera"

## Elige la cartera personal del jugador entre las de su partido (solo socios de Gobierno).
func set_post(idx: int) -> void:
	if idx >= 0 and idx < cabinet().size() and party_of(idx) == m.pid():
		var changed := int(st().get("post", -1)) != idx
		st()["post"] = idx
		if changed and st().has("objectives"):
			_new_objectives()

func default_post() -> int:
	var best := -1
	var best_n := -1
	for i in range(cabinet().size()):
		if party_of(i) != m.pid():
			continue
		var n := areas_of(i).size() * 2 + lines_of(i).size()
		if n > best_n:
			best_n = n
			best = i
	return best

## Ministerios sobre los que el jugador puede actuar con decretos.
func managed() -> Array:
	var out: Array = []
	match post_kind():
		"president":
			for i in range(cabinet().size()):
				if has_competencies(i):
					out.append(i)
		"minister":
			out.append(post_index())
	return out

func can_manage(idx: int) -> bool:
	return managed().has(idx)

# ---------------------------------------------------------------- puesta en marcha
func on_government_formed() -> void:
	var e := st()
	for entry in cabinet():
		var ed: Dictionary = entry
		if not ed.has("key"):
			ed["key"] = str(ed.get("name", ""))
	if in_cabinet() and not is_president():
		if int(e.get("post", -1)) < 0 or party_of(int(e["post"])) != m.pid():
			e["post"] = default_post()
	e["capital"] = 12.0
	e["directive"] = 60.0
	e["decrees"] = []
	e["objectives"] = []
	e["month_ai"] = 0
	e["pge"] = {"factors": {}, "status": "prorrogado", "year": 0, "draft": {}, "requests": {}, "open": false, "history": []}
	_new_objectives()

func ensure() -> void:
	var e := st()
	if not e.has("capital"):
		on_government_formed()

# ---------------------------------------------------------------- capital político
func capital() -> float:
	return float(st().get("capital", 0.0))

func directive() -> float:
	return float(st().get("directive", 60.0))

func add_capital(v: float) -> void:
	st()["capital"] = clampf(capital() + v, 0.0, MAX_CAPITAL)

## Capital político por mes (especificación §9): CP = base institucional + liderazgo + apoyo parlamentario + cohesión +
## eficiencia media del gabinete. **No depende del número de ministerios**: la eficiencia es una media ponderada y
## normalizada (0-1), de modo que un gabinete de 8 y uno de 12 con la misma calidad media reciben lo mismo.
const CP_BASE := 1.5
const CP_LEADERSHIP := 2.0
const CP_PARLIAMENT := 2.0
const CP_COHESION := 2.0
const CP_EFFICIENCY := 2.0
const CP_MIN := 2.5
const CP_MAX := 9.0

## Peso de una cartera en la media: la suma de sus competencias (las esenciales pesan más). Dividir una cartera en dos
## deja la suma de pesos igual, así que no cambia la media.
func ministry_weight(entry: Dictionary) -> float:
	var w := 0.0
	for c in (entry.get("comps", []) as Array):
		w += 1.5 if bool(Competencies.by_id(str(c)).get("essential", false)) else 1.0
	return maxf(w, 1.0)

## Eficiencia de un ministerio (0-1): mitad rendimiento actual, mitad competencia efectiva del titular.
func ministry_efficiency(idx: int) -> float:
	var mn := m.cab.minister(idx)
	if mn.is_empty():
		return 0.3
	var perf := clampf(m.cab.act_of(idx) / 100.0, 0.0, 1.0)
	var skill := clampf(m.ministers.skill_in(idx) / 11.0, 0.0, 1.0)
	return 0.5 * perf + 0.5 * skill

## E = Σ (peso × eficiencia) / Σ pesos.
func cabinet_efficiency() -> float:
	var sw := 0.0
	var sv := 0.0
	var cab := cabinet()
	for i in range(cab.size()):
		var w := ministry_weight(cab[i] as Dictionary)
		sw += w
		sv += w * ministry_efficiency(i)
	return sv / sw if sw > 0.0 else 0.3

func capital_breakdown() -> Dictionary:
	var lead := CP_LEADERSHIP * clampf(m.gov.approval() / 100.0, 0.0, 1.0)
	var seats := float(m.coal.government_seats())
	var parl := CP_PARLIAMENT * clampf((seats - 100.0) / (float(Rules.MAJORITY) - 100.0), 0.0, 1.0)
	var coh := CP_COHESION * (0.5 * clampf(m.gov.stability() / 100.0, 0.0, 1.0) + 0.5 * clampf(m.itrust.capital_factor() / 1.08, 0.0, 1.0))
	var e := cabinet_efficiency()
	var eff := CP_EFFICIENCY * e
	var raw := CP_BASE + lead + parl + coh + eff
	return {"base": CP_BASE, "leadership": lead, "parliament": parl, "cohesion": coh, "efficiency": eff, "efficiency_index": e,
		"raw": raw, "total": clampf(raw, CP_MIN, CP_MAX)}

func monthly_income() -> float:
	return float(capital_breakdown()["total"])

## Texto de desglose para mostrar en una ayuda emergente.
func capital_text() -> String:
	var b := capital_breakdown()
	return "Capital político por mes: %.1f\n· Base institucional %.1f\n· Liderazgo (apoyo al Gobierno) %.1f\n· Apoyo parlamentario %.1f\n· Cohesión y estabilidad %.1f\n· Eficiencia media del gabinete %.1f (índice %.0f %%)\nEl número de ministerios no suma capital: solo cuenta la calidad media." % [float(b["total"]), float(b["base"]), float(b["leadership"]), float(b["parliament"]), float(b["cohesion"]), float(b["efficiency"]), float(b["efficiency_index"]) * 100.0]

# ---------------------------------------------------------------- decretos
func decreeable(meas: Dictionary) -> bool:
	if LawMaker.ORGANIC.has(str(meas["id"])):
		return false
	return not LAW_ONLY_AREAS.has(str(meas["area"]))

## Recorrido máximo de un decreto: un tercio del rango de la medida, como mínimo un paso.
func max_span(meas: Dictionary) -> float:
	var span := float(meas["max"]) - float(meas["min"])
	return maxf(float(meas["step"]), roundf(span * 0.34 / float(meas["step"])) * float(meas["step"]))

func measures_for(idx: int) -> Array:
	var out: Array = []
	for aid in areas_of(idx):
		for it in Policies.measures_of(str(aid)):
			if decreeable(it as Dictionary):
				out.append(it)
	return out

func clamp_value(meas: Dictionary, v: float) -> float:
	var cur := m.eco.value(str(meas["id"]))
	var span := max_span(meas)
	return Policies.snap(meas, clampf(v, cur - span, cur + span))

func cost_of(meas: Dictionary, nv: float) -> float:
	var cur := m.eco.value(str(meas["id"]))
	var amb := Policies.ambition(meas, cur, nv)
	if amb <= 0.0:
		return 0.0
	var dirn := 1.0 if nv > cur else -1.0
	var own := m.laws.measure_pref(m.pid(), meas) * dirn
	return roundf(2.0 + amb * 12.0 + maxf(0.0, -own) * 4.0)

## Cuánto choca el decreto con la línea ideológica del partido del jugador (0 = nada, 1 = frontal).
func incoherence(meas: Dictionary, nv: float) -> float:
	var cur := m.eco.value(str(meas["id"]))
	if is_equal_approx(cur, nv):
		return 0.0
	var dirn := 1.0 if nv > cur else -1.0
	var own := m.laws.measure_pref(m.pid(), meas) * dirn
	return clampf(-own, 0.0, 1.0)

## Parte que debe dar su visto bueno: el ministro (si decide el presidente) o el presidente (si decide un ministro).
func consent_party(idx: int) -> String:
	if post_kind() == "president":
		return party_of(idx)
	return str(m.s.get("government_party_id", ""))

func consent(idx: int, measure_id: String, nv: float) -> Dictionary:
	var meas := Policies.measure(measure_id)
	var who := consent_party(idx)
	if who == "" or who == m.pid():
		return {"status": "yes", "score": 1.0, "who": who, "label": "Total sintonía"}
	var cur := m.eco.value(measure_id)
	var dirn := 1.0 if nv > cur else -1.0
	var lm := m.laws
	var score := lm.measure_pref(who, meas) * dirn + (m.ai.relation(who) - 50.0) / 100.0 * 0.4 \
		+ (float(m.d("partner_satisfaction").get(who, 60.0)) - 60.0) / 100.0 * 0.3
	if score >= -0.05:
		return {"status": "yes", "score": score, "who": who, "label": "Favorable"}
	if score >= -0.35:
		return {"status": "reluctant", "score": score, "who": who, "label": "Reticente"}
	return {"status": "no", "score": score, "who": who, "label": "Se opone"}

## Comprueba y ejecuta un decreto del jugador. `force` lo impone aun con la oposición del otro socio.
func issue(idx: int, measure_id: String, nv: float, force: bool = false) -> Dictionary:
	ensure()
	var meas := Policies.measure(measure_id)
	if meas.is_empty() or not can_manage(idx):
		return {"ok": false, "error": "No tienes competencias sobre esta medida."}
	if not areas_of(idx).has(str(meas["area"])) or not decreeable(meas):
		return {"ok": false, "error": "Esta medida exige una ley aprobada en el Congreso."}
	nv = clamp_value(meas, nv)
	var cur := m.eco.value(measure_id)
	if is_equal_approx(cur, nv):
		return {"ok": false, "error": "El decreto no cambia nada."}
	var c := cost_of(meas, nv)
	var cons := consent(idx, measure_id, nv)
	var extra := 0.0
	if str(cons["status"]) == "reluctant":
		extra = 3.0
	elif str(cons["status"]) == "no":
		if not force:
			return {"ok": false, "error": "%s se opone. Puedes forzarlo pagando capital político." % m.party_short(str(cons["who"])), "needs_force": true}
		extra = 8.0
	if capital() < c + extra:
		return {"ok": false, "error": "Capital político insuficiente (%d necesario)." % int(c + extra)}
	add_capital(-(c + extra))
	var who := str(cons["who"])
	if who != "" and who != m.pid():
		if str(cons["status"]) == "no":
			m.ai.change_relation(who, -4.0)
			# Decretar contra la voluntad del titular de un socio es una decisión unilateral: erosiona la confianza de su partido.
			m.coal.unilateral(who, "Decreto «%s» forzado contra su criterio" % str(meas["name"]))
		elif str(cons["status"]) == "reluctant":
			m.ai.change_relation(who, -1.0)
	_apply(idx, meas, nv, m.pid(), true)
	var inc := incoherence(meas, nv)
	if inc > 0.3:
		_voter_backlash(meas, inc)
	elif inc <= 0.0 and m.laws.measure_pref(m.pid(), meas) * (1.0 if nv > cur else -1.0) > 0.3:
		m.trust = m.trust + 0.4
	m.save_now()
	return {"ok": true, "cost": c + extra, "consent": cons}

func _apply(idx: int, meas: Dictionary, nv: float, by_party: String, by_player: bool) -> void:
	var mid := str(meas["id"])
	var before := m.eco.value(mid)
	m.eco.apply_law({"title": "Decreto: %s" % str(meas["name"]), "proposer": by_party, "changes": {mid: nv}, "area": str(meas["area"])})
	var log: Array = st().get("decrees", [])
	log.push_front({"month": m.gov_month, "ministry": ministry_name(idx), "party": by_party, "measure": str(meas["name"]),
		"from": Policies.value_text(meas, before), "to": Policies.value_text(meas, nv), "player": by_player})
	while log.size() > 40:
		log.pop_back()
	st()["decrees"] = log
	m.publish("%s: %s" % ["Decreto del Gobierno" if by_player else "Orden ministerial", str(meas["name"])],
		"%s (%s) la fija en «%s» (antes «%s»)." % [ministry_name(idx), m.party_short(by_party), Policies.value_text(meas, nv), Policies.value_text(meas, before)],
		"GOBIERNO", "neutral")

func _voter_backlash(meas: Dictionary, inc: float) -> void:
	m.trust = m.trust - 1.8 * inc
	m.campaign.adjust_poll(m.pid(), -0.14 * inc)
	var groups: Dictionary = meas.get("hits", {})
	var angry := ""
	var worst := 0.0
	for g in groups.keys():
		var v := float(groups[g])
		if v < worst:
			worst = v
			angry = str(g)
	var who := Policies.group_name(angry) if angry != "" else "Tus votantes"
	m.publish("Tus votantes te reprochan «%s»" % str(meas["name"]),
		"%s reprochan a %s que haya impulsado una medida contraria a su línea. Caen la confianza y la intención de voto." % [who, m.party_short(m.pid())],
		"GOBIERNO", "warning")

# ---------------------------------------------------------------- mes de gobierno
func monthly() -> void:
	ensure()
	add_capital(monthly_income() * float(Rules.TURN_MONTHS))
	_ai_ministers()
	_check_objectives()
	_pge_monthly()

## Los ministros que no controla el jugador adoptan algún decreto acorde con su partido.
func _ai_ministers() -> void:
	var cab := cabinet()
	if cab.is_empty():
		return
	# Con el jugador al frente del Gobierno, las reformas de los ministros llegan como propuestas a la mesa.
	if m.phase == "legislature" and str(m.s.get("government_party_id", "")) == m.pid():
		return
	var done := 0
	var order: Array = range(cab.size())
	order.shuffle()
	for ii in order:
		var idx: int = int(ii)
		if done >= 2:
			return
		if not has_competencies(idx) or (party_of(idx) == m.pid() and has_post()):
			continue
		if m.rng.randf() > 0.45:
			continue
		var pick := _ai_pick(idx)
		if pick.is_empty():
			continue
		var meas: Dictionary = pick["meas"]
		var nv := float(pick["nv"])
		# El presidente (si es el jugador) tiene que haber dado su consentimiento: se ignora si el decreto choca con su línea.
		if post_kind() == "president" and incoherence(meas, nv) > 0.5:
			continue
		_apply(idx, meas, nv, party_of(idx), false)
		done += 1

## Elige el decreto que prefiere un ministerio gobernado por la IA: ideología del partido más necesidades del país.
func _ai_pick(idx: int) -> Dictionary:
	var party_id := party_of(idx)
	var recent := {}
	for l in st().get("decrees", []):
		if m.gov_month - int((l as Dictionary).get("month", -99)) < 10:
			recent[str((l as Dictionary).get("measure", ""))] = true
	var best: Dictionary = {}
	var best_score := 0.0
	for it in measures_for(idx):
		var meas: Dictionary = it
		if recent.has(str(meas["name"])):
			continue
		var cur := m.eco.value(str(meas["id"]))
		var pref := m.laws.measure_pref(party_id, meas)
		for dirn in [1.0, -1.0]:
			var nv := Policies.snap(meas, cur + float(dirn) * float(meas["step"]))
			if is_equal_approx(nv, cur):
				continue
			# Las medidas que ya se desvían mucho de su valor inicial en el sentido deseado se frenan.
			var away := absf(nv - float(meas["base"])) / maxf(0.0001, float(meas["max"]) - float(meas["min"]))
			var score := pref * float(dirn) + _need_bonus(meas, float(dirn)) - away * 0.35 + m.rng.randf_range(-0.12, 0.12)
			if score > best_score and pref * float(dirn) > -0.1:
				best_score = score
				best = {"meas": meas, "nv": nv}
	return best if best_score >= 0.30 else {}

## Cuánto ayuda un paso de la medida a corregir lo que va mal en el país (0 si no hay nada que corregir).
func _need_bonus(meas: Dictionary, dirn: float) -> float:
	var bonus := 0.0
	var fx: Dictionary = meas.get("fx", {})
	for k in fx.keys():
		var kk := str(k)
		var good := 0
		var sc := 1.0
		if WorldSim.has(kk):
			good = int(WorldSim.def(kk).get("good", 0))
			sc = float(WorldSim.def(kk)["scale"])
		elif PolicyNetwork.CORES.has(kk):
			good = int((PolicyNetwork.CORES[kk] as Array)[2])
			sc = float(WorldSim.CORE_SCALE.get(kk, WorldSim.QUALITY_SCALE))
		if good == 0:
			continue
		var need := clampf(-m.world.any_z(kk) * float(good), 0.0, 1.5)
		var benefit := float(fx[k]) / maxf(0.0001, sc) * dirn * float(good)
		bonus += benefit * need
	return clampf(bonus, -0.4, 0.5)

# ---------------------------------------------------------------- objetivos de la directiva
func objectives() -> Array:
	return st().get("objectives", [])

func _metric_now(metric: String) -> float:
	match metric:
		"deficit": return -m.eco.balance_pct()
		"unemployment": return float(m.eco.st().get("unemployment", 12.0))
		"approval": return m.gov.approval()
	if WorldSim.has(metric):
		return m.world.value(metric)
	return m.eco.quality(metric)

func metric_label(metric: String) -> String:
	match metric:
		"deficit": return "Déficit público (% PIB)"
		"approval": return "Apoyo al Gobierno"
		"unemployment": return "Paro (%)"
	if WorldSim.has(metric):
		return WorldSim.name_of(metric)
	return Policies.quality_name(metric)

func _new_objectives() -> void:
	var list: Array = []
	var due := (int(m.gov_month / 12) + 1) * 12
	due = maxi(due, 12)
	match post_kind():
		"president":
			list.append({"scope": "president", "metric": "approval", "dir": 1, "target": maxf(45.0, m.gov.approval() + 1.5), "start": m.gov.approval(), "due": due, "status": "pending"})
			list.append({"scope": "president", "metric": "deficit", "dir": -1, "target": maxf(3.0, -m.eco.balance_pct() - 0.2), "start": -m.eco.balance_pct(), "due": due, "status": "pending"})
		"minister":
			for aid in areas_of(post_index()):
				var spec: Array = AREA_METRIC.get(str(aid), [])
				if spec.is_empty():
					continue
				var cur := _metric_now(str(spec[0]))
				var dirn := int(spec[1])
				list.append({"scope": "min", "metric": str(spec[0]), "dir": dirn, "target": cur + float(dirn) * float(spec[2]), "start": cur, "due": due, "status": "pending"})
	st()["objectives"] = list

func _check_objectives() -> void:
	var list := objectives()
	var any_due := false
	for o in list:
		var od: Dictionary = o
		if str(od["status"]) == "pending" and m.gov_month >= int(od["due"]):
			any_due = true
			var v := _metric_now(str(od["metric"]))
			var ok := v >= float(od["target"]) if int(od["dir"]) > 0 else v <= float(od["target"])
			od["status"] = "met" if ok else "failed"
			od["final"] = v
			st()["directive"] = clampf(directive() + (12.0 if ok else -18.0), 0.0, 100.0)
			if ok:
				add_capital(4.0)
	if not any_due:
		return
	var ok_n := 0
	for o in list:
		if str((o as Dictionary)["status"]) == "met":
			ok_n += 1
	m.publish("La directiva evalúa tu gestión", "Has cumplido %d de %d objetivos. Confianza de la directiva: %.0f/100." % [ok_n, list.size(), directive()],
		"GOBIERNO", "positive" if ok_n * 2 >= list.size() else "warning")
	if directive() < 20.0:
		_directive_crisis()
	_new_objectives()

func _directive_crisis() -> void:
	if post_kind() == "minister":
		var mname := ministry_name(post_index())
		st()["post"] = -1
		m.publish("Te cesan como ministro/a de %s" % mname, "La directiva te retira la confianza tras no cumplir los mínimos exigidos. Dejas la cartera.", "GOBIERNO", "negative")
	else:
		m.trust = m.trust - 6.0
		m.publish("Crisis de liderazgo en tu partido", "La directiva cuestiona tu gestión al frente del Gobierno. Cae la confianza de la militancia.", "GOBIERNO", "negative")
	st()["directive"] = 45.0

# ---------------------------------------------------------------- Presupuestos Generales
func pge() -> Dictionary:
	return st().get("pge", {})

func pge_status() -> String:
	return str(pge().get("status", "prorrogado"))

func base_factor(line_id: String) -> float:
	return float((pge().get("factors", {}) as Dictionary).get(line_id, 1.0))

## Dotación vigente de una partida: lo aprobado en los Presupuestos más las modificaciones de crédito decretadas en el año.
func factor(line_id: String) -> float:
	return base_factor(line_id) + float((pge().get("adjust", {}) as Dictionary).get(line_id, 0.0))

func credit_delta(line_id: String) -> float:
	return float((pge().get("adjust", {}) as Dictionary).get(line_id, 0.0))

## Parte que debe consentir una modificación de crédito (misma regla que los decretos).
func line_consent(idx: int, line_id: String, dirn: float) -> Dictionary:
	var who := consent_party(idx)
	if who == "" or who == m.pid():
		return {"status": "yes", "score": 1.0, "who": who, "label": "Total sintonía"}
	var ax: Dictionary = m.party_by_id(who).get("ideology", {})
	var pref := float(ax.get("economic", 0.0)) * _line_lean(line_id) * dirn
	var score := pref + (m.ai.relation(who) - 50.0) / 100.0 * 0.4 + (float(m.d("partner_satisfaction").get(who, 60.0)) - 60.0) / 100.0 * 0.3
	if score >= -0.05:
		return {"status": "yes", "score": score, "who": who, "label": "Favorable"}
	if score >= -0.3:
		return {"status": "reluctant", "score": score, "who": who, "label": "Reticente"}
	return {"status": "no", "score": score, "who": who, "label": "Se opone"}

## Modificación de crédito en una partida del ministerio: ±2,5 % sobre lo presupuestado (entre −10 % y +15 %).
func adjust_line(idx: int, line_id: String, dirn: float, force: bool = false) -> Dictionary:
	ensure()
	if not can_manage(idx) or not lines_of(idx).has(line_id):
		return {"ok": false, "error": "Esa partida no es de tu ministerio."}
	var p := pge()
	if not p.has("adjust"):
		p["adjust"] = {}
	var adj: Dictionary = p["adjust"]
	var nv := snappedf(float(adj.get(line_id, 0.0)) + dirn * FACTOR_STEP, 0.0005)
	if nv < -0.10 - 0.0001 or nv > 0.15 + 0.0001:
		return {"ok": false, "error": "No puedes modificar más el crédito sin unos nuevos Presupuestos."}
	var cons := line_consent(idx, line_id, dirn)
	var extra := 0.0
	if str(cons["status"]) == "reluctant":
		extra = 3.0
	elif str(cons["status"]) == "no":
		if not force:
			return {"ok": false, "error": "%s se opone. Puedes forzarlo pagando capital político." % m.party_short(str(cons["who"])), "needs_force": true}
		extra = 8.0
	var c := 3.0 + extra
	if capital() < c:
		return {"ok": false, "error": "Capital político insuficiente (%d necesario)." % int(c)}
	add_capital(-c)
	adj[line_id] = nv
	var who := str(cons["who"])
	if who != "" and who != m.pid() and str(cons["status"]) == "no":
		m.ai.change_relation(who, -3.0)
	m.eco._compute_fiscal()
	m.eco._compute_composition()
	var bd := Policies.entry(Policies.budget(), line_id)
	var log: Array = st().get("decrees", [])
	log.push_front({"month": m.gov_month, "ministry": ministry_name(idx), "party": m.pid(), "measure": "Crédito: %s" % str(bd.get("name", line_id)),
		"from": "%.1f %%" % ((factor(line_id) - dirn * FACTOR_STEP) * 100.0), "to": "%.1f %%" % (factor(line_id) * 100.0), "player": true})
	st()["decrees"] = log
	m.save_now()
	return {"ok": true, "cost": c, "consent": cons}

func draft_factor(line_id: String) -> float:
	var d: Dictionary = pge().get("draft", {})
	return float(d.get(line_id, factor(line_id)))

func set_draft_factor(line_id: String, v: float) -> void:
	var p := pge()
	if not p.has("draft"):
		p["draft"] = {}
	(p["draft"] as Dictionary)[line_id] = snappedf(clampf(v, FACTOR_MIN, FACTOR_MAX), 0.005)

func pge_open() -> bool:
	return bool(pge().get("open", false))

func is_pge_month(month: int) -> bool:
	return PGE_MONTHS.has(month)

## Importe previsto (bn €) de una partida con los factores del borrador.
func line_amount(line_id: String, use_draft: bool) -> float:
	var cur := m.eco.budget_spending(line_id)
	var cf := maxf(0.01, factor(line_id))
	var f := draft_factor(line_id) if use_draft else cf
	return cur / cf * f

func draft_delta() -> float:
	var tot := 0.0
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		tot += line_amount(bid, true) - line_amount(bid, false)
	return tot

func _pge_monthly() -> void:
	var p := pge()
	if p.is_empty():
		return
	# Un borrador que el jugador no presentó a tiempo se registra tal cual.
	if bool(p.get("open", false)) and m.gov_month > int(p.get("opened_month", 0)):
		submit_pge(true)
	if is_pge_month(m.gov_month):
		open_pge()

func open_pge() -> void:
	var p := pge()
	p["year"] = int(p.get("year", 0)) + 1
	p["opened_month"] = m.gov_month
	var draft: Dictionary = {}
	var gov_id := str(m.s.get("government_party_id", ""))
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		draft[bid] = factor(bid)
	p["draft"] = draft
	if post_kind() == "president":
		p["open"] = true
		m.publish("Toca preparar los Presupuestos", "Tienes este trimestre para ajustar las partidas con tus ministros y presentarlas al Congreso. Si no lo haces, se registrará el borrador actual.", "GOBIERNO", "warning")
		return
	p["open"] = false
	# Presupuestos de la IA: reflejan la ideología del Gobierno y las peticiones de tu ministerio.
	_ai_draft(gov_id)
	_enqueue_pge(gov_id, "Presupuestos Generales del Estado, año %d" % int(p["year"]))

func _ai_draft(gov_id: String) -> void:
	var p := pge()
	var draft: Dictionary = p["draft"]
	var ax: Dictionary = m.party_by_id(gov_id).get("ideology", {})
	var econ := float(ax.get("economic", 0.0))
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		var lean := _line_lean(bid)
		var f := 1.0 + 0.03 + lean * econ * 0.06 + m.rng.randfn(0.0, 0.01)
		var req := float((p.get("requests", {}) as Dictionary).get(bid, 0.0))
		if req > 0.0:
			f = maxf(f, minf(req, 1.0 + (m.ai.relation(gov_id) - 30.0) / 800.0 + 0.03))
		draft[bid] = snappedf(clampf(f, FACTOR_MIN, FACTOR_MAX), 0.005)
	p["requests"] = {}

## Cuánto «social» o «de orden» es una partida: -1 gasto de izquierdas … 1 gasto de derechas.
func _line_lean(line_id: String) -> float:
	match line_id:
		"pensiones", "sanidad", "educacion", "prestaciones", "vivienda", "transicion", "ciencia": return -0.8
		"defensa", "interior", "justicia": return 0.7
	return 0.0

func submit_pge(auto: bool = false) -> void:
	var p := pge()
	if not bool(p.get("open", false)):
		return
	p["open"] = false
	var title := "Presupuestos Generales del Estado, año %d" % int(p.get("year", 1))
	_enqueue_pge(str(m.s.get("government_party_id", "")), title)
	if auto:
		m.publish("Presupuestos registrados", "Se envía al Congreso el borrador sin cambios porque no lo presentaste a tiempo.", "GOBIERNO", "neutral")

func _enqueue_pge(gov_id: String, title: String) -> void:
	var p := pge()
	var law := {"id": m.laws._next_id(), "title": title, "area": "", "proposer": gov_id, "kind": "presupuestos",
		"changes": {}, "goodwill": {}, "status": "registered", "month": m.gov_month, "budget": (p["draft"] as Dictionary).duplicate()}
	m.laws.queue().append(law)

## Efecto de aprobar la ley de presupuestos.
func apply_pge(law: Dictionary) -> void:
	var p := pge()
	var old_total := m.eco.spending_total()
	p["factors"] = (law["budget"] as Dictionary).duplicate()
	p["adjust"] = {}
	p["status"] = "aprobado"
	m.eco._compute_fiscal()
	m.eco._compute_composition()
	(p["history"] as Array).append({"year": int(p.get("year", 0)), "status": "aprobado", "month": m.gov_month, "delta": m.eco.spending_total() - old_total})
	m.s["stability"] = clampf(m.gov.stability() + 3.0, 0.0, 100.0)

func reject_pge(_law: Dictionary) -> void:
	var p := pge()
	p["status"] = "prorrogado"
	(p["history"] as Array).append({"year": int(p.get("year", 0)), "status": "prorrogado", "month": m.gov_month, "delta": 0.0})
	m.s["stability"] = clampf(m.gov.stability() - 5.0, 0.0, 100.0)
	m.s["gov_approval"] = clampf(m.gov.approval() - 2.0, 8.0, 92.0)
	m.publish("Presupuestos prorrogados", "El Congreso rechaza los Presupuestos: siguen vigentes los anteriores y el Gobierno pierde autoridad.", "GOBIERNO", "warning")

## Un ministro (jugador) pide más dotación para sus partidas en los próximos Presupuestos.
func request_funds(line_id: String, f: float) -> void:
	var p := pge()
	if not p.has("requests"):
		p["requests"] = {}
	(p["requests"] as Dictionary)[line_id] = snappedf(clampf(f, 1.0, FACTOR_MAX), 0.005)

func request_of(line_id: String) -> float:
	return float((pge().get("requests", {}) as Dictionary).get(line_id, 0.0))

func budget_lines_changed(law: Dictionary) -> Array:
	var out: Array = []
	var cur: Dictionary = pge().get("factors", {})
	var bud: Dictionary = law.get("budget", {})
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		var f0 := float(cur.get(bid, 1.0))
		var f1 := float(bud.get(bid, f0))
		if absf(f1 - f0) > 0.001:
			out.append({"name": "Dotación: %s" % str((b as Dictionary)["name"]), "from": "%.1f %%" % (f0 * 100.0), "to": "%.1f %%" % (f1 * 100.0)})
	return out

func budget_stance(law: Dictionary, party_id: String) -> Dictionary:
	var bud: Dictionary = law.get("budget", {})
	var cur: Dictionary = pge().get("factors", {})
	var ax: Dictionary = m.party_by_id(party_id).get("ideology", {})
	var econ := float(ax.get("economic", 0.0))
	var terr := float(ax.get("territorial", 0.0))
	var s := 0.0
	var total := 0.0
	var base_total := 0.0
	for b in Policies.budget():
		var bd: Dictionary = b
		var bid := str(bd["id"])
		var f0 := float(cur.get(bid, 1.0))
		var f1 := float(bud.get(bid, f0))
		var w := float(bd["base"])
		s += (f1 - f0) * 10.0 * econ * _line_lean(bid) * clampf(w / 40.0, 0.3, 2.0)
		if bid == "territorial":
			s += (f1 - f0) * 12.0 * maxf(0.0, terr)
		total += w * f1
		base_total += w * f0
	# Todos los grupos toleran poco una subida global del gasto, salvo los que más lo piden.
	s -= (total / maxf(1.0, base_total) - 1.0) * 3.0 * clampf(econ + 0.3, 0.0, 1.0)
	var proposer := str(law.get("proposer", ""))
	var coalition := m.laws._coalition()
	var score := s
	if coalition.has(party_id):
		score += 0.45
	elif party_id == proposer:
		score += 0.6
	else:
		score -= 0.25
		score += (m.ai.relation(party_id) - 50.0) / 100.0 * 0.4 if m.is_player(proposer) else (m.ai.affinity(party_id, proposer) - 0.5) * 0.4
	score += float((law.get("goodwill", {}) as Dictionary).get(party_id, 0.0))
	var vote := "yes" if score >= LawMaker.YES_AT else ("no" if score <= LawMaker.NO_AT else "abstain")
	return {"party": party_id, "score": clampf(score, -1.0, 1.0), "vote": vote, "items": [], "conditions": []}

## Variación total de gasto (bn €) que supone una ley de presupuestos respecto a lo vigente.
func draft_delta_of(law: Dictionary) -> float:
	var bud: Dictionary = law.get("budget", {})
	var tot := 0.0
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		var f0 := factor(bid)
		var cur := m.eco.budget_spending(bid)
		tot += cur / maxf(0.01, f0) * (float(bud.get(bid, f0)) - f0)
	return tot
