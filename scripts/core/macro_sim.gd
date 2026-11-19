class_name MacroSim
extends RefCounted
## Motor macroeconómico TRIMESTRAL. Cada turno de legislatura (un trimestre) recalcula toda la economía a partir de agentes
## que reaccionan entre sí y de las medidas aprobadas:
##  · Hogares: renta real, ahorro precautorio, confianza → consumo.
##  · Empresas: acelerador de la inversión, márgenes (costes laborales unitarios), salarios y precios.
##  · Bancos: crédito, morosidad, tensión financiera.
##  · BCE: regla de Taylor con inercia sobre la inflación y la brecha de la zona euro.
##  · Mercados: prima de riesgo según deuda, déficit, crecimiento y aversión global al riesgo.
##  · Sector exterior: crecimiento mundial, petróleo/energía, inflación global, turismo.
##  · Director de shocks: crisis y booms con probabilidad condicionada a las fragilidades de la economía (burbuja, deuda…).
## Cada variable principal (crecimiento, paro, inflación) es la SUMA de componentes con estado propio, de modo que se puede
## explicar exactamente cuánto de su cambio se debe a cada medida o ley, a cada shock y a cada agente (`why`/`push`).
## Las medidas aprobadas llegan con retardo (POL_LAG por turno) y el efecto de cada una se atribuye a su ley de origen.

const CORE := ["growth", "unemployment", "inflation"]
const OWNED := ["wages", "productivity", "consumption", "investment", "exports", "house_price", "energy_price"]
const K := {"growth": 0.6, "unemployment": 0.4, "inflation": 0.5}
const POL_LAG := 0.55
const SC := 0.57
const SI := 0.20
const SG := 0.19
const SX := 0.35
const SM := 0.32
const POT0 := 1.9
const U0 := 12.0
const HIST_MAX := 160
const HIST_KEYS := ["growth", "unemployment", "inflation", "gap", "pot", "rate", "spread", "eff_cost", "credit_g", "bank", "npl", "hp_g", "bubble",
	"conf_c", "conf_f", "sav", "c_g", "i_g", "x_g", "mm_g", "g_g", "wage_g", "prod_g", "infl_e", "world_g", "oil", "world_inf", "risk", "rdi", "ulc_gap", "tour_dem"]

## Nombre, unidad y decimales de cada variable propia del motor (las principales viven en `eco`, los indicadores en `world`).
const VARS := {
	"gap": {"name": "Brecha de producción", "unit": "% PIB potencial", "dec": 1, "good": 0, "desc": "Cuánto produce la economía por encima (+) o por debajo (−) de su capacidad. Negativa = recesión; muy positiva = sobrecalentamiento."},
	"pot": {"name": "Crecimiento potencial", "unit": "%", "dec": 1, "good": 1, "desc": "Ritmo al que puede crecer la economía sin generar inflación: depende de la productividad, la inversión, la mano de obra y las cualificaciones."},
	"rate": {"name": "Tipo de interés del BCE", "unit": "%", "dec": 2, "good": 0, "desc": "Tipo oficial que fija el BCE para toda la zona euro con una regla de Taylor: sube con la inflación europea y baja con la debilidad económica."},
	"spread": {"name": "Prima de riesgo", "unit": "pp", "dec": 2, "good": -1, "desc": "Sobrecoste que exigen los mercados por comprar deuda española frente a la referencia alemana. Sube con la deuda, el déficit y el miedo global."},
	"eff_cost": {"name": "Coste medio de la deuda", "unit": "%", "dec": 2, "good": -1, "desc": "Interés medio que paga el Estado por toda su deuda. Se renueva despacio, por eso los tipos tardan años en notarse del todo."},
	"credit_g": {"name": "Crecimiento del crédito", "unit": "%", "dec": 1, "good": 0, "desc": "Variación anual del crédito bancario a hogares y empresas. Sin crédito no hay inversión; con demasiado se inflan las burbujas."},
	"bank": {"name": "Tensión bancaria", "unit": "0-100", "dec": 0, "good": -1, "desc": "Presión sobre los bancos: morosidad, caída del precio de la vivienda y primas de riesgo altas. Por encima de 60 se seca el crédito."},
	"npl": {"name": "Morosidad bancaria", "unit": "%", "dec": 1, "good": -1, "desc": "Parte de los préstamos que no se devuelve. Crece con el paro, los tipos y la caída de la vivienda."},
	"hp_g": {"name": "Variación del precio de la vivienda", "unit": "% anual", "dec": 1, "good": 0, "desc": "Crecimiento interanual nominal del precio de la vivienda."},
	"bubble": {"name": "Sobrevaloración de la vivienda", "unit": "%", "dec": 1, "good": -1, "desc": "Cuánto se ha separado el precio de la vivienda de lo que justifican las rentas. Por encima de 15 % hay riesgo de pinchazo."},
	"conf_c": {"name": "Confianza de los consumidores", "unit": "0-100", "dec": 0, "good": 1, "desc": "Ánimo de los hogares: empleo, inflación, tipos y clima político. Mueve el consumo y el ahorro."},
	"conf_f": {"name": "Confianza empresarial", "unit": "0-100", "dec": 0, "good": 1, "desc": "Espíritu animal de las empresas: demanda esperada, costes financieros y estabilidad. Mueve la inversión."},
	"sav": {"name": "Tasa de ahorro de los hogares", "unit": "% renta", "dec": 1, "good": 0, "desc": "Parte de la renta que no se gasta. Sube cuando hay miedo al paro o a los precios y frena el consumo."},
	"c_g": {"name": "Consumo: variación", "unit": "% anual", "dec": 1, "good": 1, "desc": "Variación real interanual del gasto de las familias."},
	"i_g": {"name": "Inversión: variación", "unit": "% anual", "dec": 1, "good": 1, "desc": "Variación real interanual de la inversión de las empresas."},
	"x_g": {"name": "Exportaciones: variación", "unit": "% anual", "dec": 1, "good": 1, "desc": "Variación real interanual de las exportaciones de bienes y servicios."},
	"g_g": {"name": "Gasto público: variación", "unit": "% anual", "dec": 1, "good": 0, "desc": "Variación real interanual del consumo e inversión de las administraciones."},
	"wage_g": {"name": "Salarios nominales", "unit": "% anual", "dec": 1, "good": 0, "desc": "Subida media de los salarios pactados. Depende de las expectativas de inflación, la productividad y la tensión del mercado de trabajo."},
	"prod_g": {"name": "Crecimiento de la productividad", "unit": "% anual", "dec": 1, "good": 1, "desc": "Producción por trabajador: depende del ciclo, la digitalización, la I+D y las cualificaciones."},
	"infl_e": {"name": "Expectativas de inflación", "unit": "%", "dec": 1, "good": 0, "desc": "Inflación que esperan hogares y empresas. Si se desanclan de la meta del 2 %, la inflación se retroalimenta."},
	"world_g": {"name": "Crecimiento mundial", "unit": "%", "dec": 1, "good": 1, "desc": "Demanda exterior: tira de las exportaciones y del turismo."},
	"oil": {"name": "Precio del petróleo y el gas", "unit": "índice", "dec": 0, "good": -1, "desc": "Coste de las materias primas energéticas que importa el país (base 100)."},
	"world_inf": {"name": "Inflación mundial", "unit": "%", "dec": 1, "good": 0, "desc": "Inflación importada del resto del mundo."},
	"risk": {"name": "Aversión global al riesgo", "unit": "índice", "dec": 2, "good": -1, "desc": "Miedo de los inversores en el mundo; encarece la deuda de los países endeudados."},
	"rdi": {"name": "Renta real de los hogares", "unit": "% anual", "dec": 1, "good": 1, "desc": "Crecimiento de la renta disponible real: empleo, salarios menos inflación, impuestos y prestaciones."},
	"ulc_gap": {"name": "Presión de costes laborales", "unit": "pp", "dec": 1, "good": -1, "desc": "Salarios por encima de la productividad (más allá del 2 % que absorbe la meta de precios). Encarece los productos y resta competitividad."},
	"tour_dem": {"name": "Demanda turística exterior", "unit": "puntos", "dec": 1, "good": 1, "desc": "Impulso de la demanda extranjera de viajes a España."},
}

## Catálogo de shocks: efectos como DESVIACIONES de nivel a plena intensidad (decaen linealmente durante su duración).
## world_g: crecimiento mundial · oil: energía · winf: inflación mundial · risk: aversión al riesgo · conf: confianza (puntos)
## dem: demanda interna directa (pp de crecimiento) · supply: cuellos de botella/precios (pp de inflación) · hp: precio de la vivienda (pp)
## bank: tensión bancaria · tour: turismo (puntos) · credit: crédito (pp) · inv: inversión (pp) · gov: gasto (pp) · prod: productividad (pp) · unemp: paro (pp)
const SHOCKS := [
	{"id": "recesion_global", "name": "Recesión mundial", "good": false, "haz": 0.028, "dur": [3, 5],
		"fx": {"world_g": -3.6, "risk": 0.5, "conf": -6.0, "tour": -9.0, "dem": -0.5},
		"title": "El mundo entra en recesión", "body": "La economía global se frena de golpe. Caen los pedidos exteriores y el turismo, y los mercados se vuelven más prudentes."},
	{"id": "shock_energetico", "name": "Crisis energética", "good": false, "haz": 0.032, "dur": [3, 5],
		"fx": {"oil": 52.0, "supply": 1.1, "conf": -4.0, "world_g": -0.8, "winf": 1.4},
		"title": "Se disparan la energía y los carburantes", "body": "El gas y el petróleo se encarecen con fuerza. Suben los costes de producción y los precios, y los hogares recortan gasto."},
	{"id": "crisis_financiera", "name": "Crisis financiera", "good": false, "haz": 0.014, "dur": [4, 6],
		"fx": {"bank": 32.0, "credit": -7.0, "risk": 0.7, "conf": -9.0, "hp": -5.0, "dem": -3.0, "unemp": 0.9},
		"title": "Crisis financiera: se seca el crédito", "body": "La desconfianza golpea a los bancos. El crédito a familias y empresas se corta y la inversión se paraliza."},
	{"id": "crisis_deuda", "name": "Crisis de deuda soberana", "good": false, "haz": 0.01, "dur": [3, 5],
		"fx": {"risk": 1.0, "conf": -6.0, "bank": 14.0, "dem": -1.5},
		"title": "Los mercados dudan de la deuda española", "body": "La prima de riesgo se dispara. Financiarse sale mucho más caro y cualquier ajuste fiscal pasa a ser urgente."},
	{"id": "burbuja_vivienda", "name": "Pinchazo inmobiliario", "good": false, "haz": 0.005, "dur": [4, 6],
		"fx": {"hp": -9.0, "bank": 20.0, "dem": -2.0, "conf": -6.0, "credit": -3.0},
		"title": "Estalla la burbuja de la vivienda", "body": "Los precios de la vivienda caen en picado. Los hogares se sienten más pobres y los bancos acumulan impagos."},
	{"id": "pandemia", "name": "Parón sanitario", "good": false, "haz": 0.011, "dur": [2, 4],
		"fx": {"dem": -6.0, "tour": -38.0, "supply": 0.5, "conf": -11.0, "world_g": -2.0, "unemp": 1.2},
		"title": "Una emergencia sanitaria paraliza la actividad", "body": "Las restricciones frenan en seco el consumo, el turismo y buena parte del empleo."},
	{"id": "guerra_comercial", "name": "Guerra comercial", "good": false, "haz": 0.026, "dur": [3, 5],
		"fx": {"world_g": -1.3, "risk": 0.3, "oil": 6.0, "conf": -2.5},
		"title": "Escalada de aranceles entre las grandes potencias", "body": "El comercio mundial se resiente. Las exportaciones y la inversión pierden impulso."},
	{"id": "sequia", "name": "Sequía y ola de calor", "good": false, "haz": 0.04, "dur": [2, 3],
		"fx": {"dem": -0.4, "supply": 0.7, "tour": -4.0},
		"title": "Sequía severa y olas de calor", "body": "La cosecha se resiente, suben los alimentos y la hostelería nota la falta de agua y el calor extremo."},
	{"id": "alimentos", "name": "Inflación de alimentos", "good": false, "haz": 0.03, "dur": [2, 4],
		"fx": {"supply": 1.0, "conf": -2.0},
		"title": "Se disparan los precios de los alimentos", "body": "La cesta de la compra sube con fuerza y presiona a las familias con menos renta."},
	{"id": "boom_turistico", "name": "Boom turístico", "good": true, "haz": 0.04, "dur": [3, 4],
		"fx": {"tour": 24.0, "world_g": 0.4, "conf": 3.0},
		"title": "Récord de turistas extranjeros", "body": "La llegada de visitantes bate récords y tira de los servicios, el empleo y las exportaciones."},
	{"id": "recuperacion_global", "name": "Recuperación mundial", "good": true, "haz": 0.035, "dur": [4, 5],
		"fx": {"world_g": 1.9, "risk": -0.3, "conf": 4.0, "winf": 0.2},
		"title": "La economía mundial acelera", "body": "Repuntan el comercio y la demanda exterior. Las empresas exportadoras estrenan pedidos."},
	{"id": "boom_tecnologico", "name": "Boom tecnológico", "good": true, "haz": 0.025, "dur": [4, 6],
		"fx": {"inv": 2.6, "prod": 0.5, "conf": 3.0},
		"title": "Oleada de inversión tecnológica", "body": "Empresas y fondos apuestan por la digitalización: más inversión y mejoras de productividad."},
	{"id": "fondos_europeos", "name": "Fondos europeos", "good": true, "haz": 0.022, "dur": [5, 7],
		"fx": {"gov": 0.9, "inv": 1.6, "conf": 2.0},
		"title": "Llegan fondos europeos de recuperación", "body": "Bruselas libera una tanda de fondos para inversión pública y privada."},
]

var m: GameModel

func _init(model: GameModel) -> void:
	m = model

# ================================================================ estado
func st() -> Dictionary:
	return m.d("macro")

func ready_state() -> bool:
	return st().has("v")

static func has_var(id: String) -> bool:
	return VARS.has(id)

func v(id: String) -> float:
	ensure()
	return float((st()["v"] as Dictionary).get(id, 0.0))

static func var_name(id: String) -> String:
	return str((VARS.get(id, {}) as Dictionary).get("name", id))

static func fmt(id: String, value: float) -> String:
	var d: Dictionary = VARS.get(id, {})
	var num := ("%." + str(int(d.get("dec", 1))) + "f") % value
	var unit := str(d.get("unit", ""))
	if unit == "" or unit in ["índice", "puntos", "0-100"]:
		return num
	return "%s %s" % [num, unit]

func ensure() -> void:
	if ready_state():
		return
	m.eco.ensure()
	m.world.ensure()
	var e := m.eco.st()
	var wv: Dictionary = m.world.st()["v"]
	var pot := POT0
	var infl := float(e.get("inflation", 3.0))
	var rate := float(e.get("rate", 2.5))
	var infl_e := 0.7 * infl + 0.3 * 2.0
	var v0 := {
		"gap": 0.0, "pot": pot, "du": 0.0, "rdi": pot, "rr0": rate - infl_e,
		"infl_e": infl_e, "wage_g": 3.05, "prod_g": 1.0, "prod_tr": 1.0, "ulc_gap": 0.0,
		"rate": rate, "spread": 0.5, "eff_cost": float(e.get("rate", 2.5)),
		"ez_inf": 3.0, "ez_gap": 0.0,
		"credit_g": 3.0, "bank": 25.0, "npl": 3.5, "hp_g": 3.0, "hp_idx": float(wv.get("house_price", 100.0)), "hp_fund": float(wv.get("house_price", 100.0)), "bubble": 0.0,
		"conf_c": 50.0, "conf_f": 50.0, "sav": 7.4, "sav_prev": 7.4,
		"c_g": pot, "i_g": pot, "x_g": pot, "mm_g": pot, "g_g": pot,
		"world_g": 2.2, "ar_wg": 0.0, "ar_oil": 0.0, "ar_winf": 0.0, "ar_risk": 0.0, "ar_tour": 0.0, "oil": 100.0, "world_inf": 2.5, "risk": 0.0, "tour_dem": 0.0,
		"oil_hist": [100.0, 100.0, 100.0, 100.0], "tour_prev": float(wv.get("tourism", 100.0)),
		"tax_prev": float(m.eco.revenue_total()) / maxf(1.0, m.eco.gdp()) * 100.0,
		"sp_prev": (float(m.eco.spending_total()) - float(e.get("interest", 0.0))) / maxf(1.0, m.eco.gdp()) * 100.0,
		"ar_dem": 0.0, "rw0": 0.05, "stab0": float(m.s.get("stability", 50.0)),
		"growth": float(e.get("growth", 1.9)), "unemployment": float(e.get("unemployment", 12.0)), "inflation": infl,
		"growth_prev": float(e.get("growth", 1.9)), "neg_run": 0,
	}
	var S := st()
	S["v"] = v0.duplicate(true)
	S["parts"] = {}
	S["why"] = {}
	S["shocks"] = []
	S["events"] = []
	S["pol"] = {}
	S["origin"] = {}
	S["hist"] = []
	S["proj"] = []
	S["fc"] = {}
	S["turn"] = 0
	S["quiet"] = 2
	# La política actual no genera transitorio: el retardo parte de los valores vigentes.
	var steps := _steps_now()
	for mid in steps.keys():
		(S["pol"] as Dictionary)[mid] = float(steps[mid])
	# Arranque en régimen: una pasada sin ruido fija el estado estacionario de los componentes y el resto va a «dinámica previa».
	var X := _context()
	S["booting"] = true
	_step(S, X, false, false)
	S.erase("booting")
	S["v"] = v0.duplicate(true)
	S["why"] = {}
	for mid2 in steps.keys():
		(S["pol"] as Dictionary)[mid2] = float(steps[mid2])
	_record_hist(S)
	S["proj"] = project(6)

# ================================================================ contexto exterior al motor
static var _pol_cache: Array = []

## Medidas con efecto sobre alguna variable del motor.
static func policy_measures() -> Array:
	if _pol_cache.is_empty():
		var keys := CORE + OWNED
		for it in Policies.measures():
			var meas: Dictionary = it
			var fxd: Dictionary = meas.get("fx", {})
			var any := false
			for k in keys:
				if fxd.has(k):
					any = true
					break
			if any:
				_pol_cache.append(meas)
	return _pol_cache

func _steps_now() -> Dictionary:
	var out: Dictionary = {}
	for it in policy_measures():
		var meas: Dictionary = it
		var mid := str(meas["id"])
		var steps := (m.eco.value(mid) - float(meas["base"])) / float(meas["step"])
		if absf(steps) > 0.0001:
			out[mid] = steps
	return out

func _context() -> Dictionary:
	var gdp := maxf(1.0, m.eco.gdp())
	var zs: Dictionary = {}
	for id in ["skills", "dropout", "trust", "digital", "r_d", "renewables", "housing_stock"]:
		zs[id] = m.world.z(id)
	var mb: Dictionary = m.ministers.bonuses() if m.ministers != null else {}
	return {
		"steps": _steps_now(),
		"tax": m.eco.revenue_total() / gdp * 100.0, "sp": (m.eco.spending_total() - float(m.eco.st().get("interest", 0.0))) / gdp * 100.0,
		"deficit": -m.eco.balance_pct(), "debt": m.eco.debt_pct(),
		"z": zs, "mig": m.world.value("net_migration"), "tourism": m.world.value("tourism"),
		"mb": mb, "stab": float(m.s.get("stability", 50.0)),
	}

# ================================================================ componentes con estado
static func _c(key: String, label: String, kind: String, ref: String, target: float, via: String = "") -> Dictionary:
	return {"key": key, "label": label, "kind": kind, "ref": ref, "t": target, "via": via}

## Actualiza los componentes de una variable: x += k·(objetivo − x). Devuelve la suma y guarda los cambios en `why`.
func _upd(S: Dictionary, id: String, comps: Array, k: float, start_value: float) -> float:
	var parts: Dictionary = S["parts"]
	var boot := parts.is_empty() or not parts.has(id)
	if boot:
		parts[id] = {}
	var store: Dictionary = parts[id]
	var seen: Dictionary = {}
	var changes: Array = []
	var total := 0.0
	var tsum := 0.0
	for c in comps:
		var cd: Dictionary = c
		var key := str(cd["key"])
		seen[key] = true
		if not store.has(key):
			store[key] = {"x": float(cd["t"]) if boot else 0.0, "label": str(cd["label"]), "kind": str(cd["kind"]), "ref": str(cd["ref"]), "via": str(cd["via"])}
		var ent: Dictionary = store[key]
		ent["label"] = str(cd["label"])
		ent["via"] = str(cd["via"])
		var x0 := float(ent["x"])
		var x1 := x0 + k * (float(cd["t"]) - x0) if not boot else float(cd["t"])
		ent["x"] = x1
		tsum += float(cd["t"])
		if absf(x1 - x0) > 0.0004 and not boot:
			changes.append({"key": key, "label": str(cd["label"]), "kind": str(cd["kind"]), "ref": str(cd["ref"]), "via": str(cd["via"]), "value": x1 - x0})
	for key2 in store.keys():
		if seen.has(str(key2)):
			continue
		var e2: Dictionary = store[key2]
		var x2 := float(e2["x"])
		var nx := x2 + k * (0.0 - x2)
		e2["x"] = nx
		if absf(nx - x2) > 0.0004 and not boot:
			changes.append({"key": str(key2), "label": str(e2["label"]), "kind": str(e2["kind"]), "ref": str(e2["ref"]), "via": str(e2["via"]), "value": nx - x2})
		if absf(nx) < 0.0005 and str(e2["kind"]) != "structural":
			store.erase(key2)
	for key3 in store.keys():
		total += float((store[key3] as Dictionary)["x"])
	if boot:
		var resid := start_value - total
		store["prev"] = {"x": resid, "label": "Dinámica previa", "kind": "structural", "ref": "", "via": ""}
		total = start_value
	changes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	(S["why"] as Dictionary)[id] = changes
	return total

func why(id: String) -> Array:
	ensure()
	return (st()["why"] as Dictionary).get(id, [])

## Empuje actual de cada componente (en las unidades de la variable) respecto a su estado base.
func push(id: String) -> Array:
	ensure()
	var out: Array = []
	var store: Dictionary = (st()["parts"] as Dictionary).get(id, {})
	for key in store.keys():
		var e: Dictionary = store[key]
		if str(e["kind"]) == "structural":
			continue
		if absf(float(e["x"])) < 0.01:
			continue
		out.append({"key": str(key), "label": str(e["label"]), "kind": str(e["kind"]), "ref": str(e["ref"]), "via": str(e.get("via", "")), "value": float(e["x"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out

# ================================================================ origen de las medidas
## Anota qué ley o decreto cambió cada medida (para explicar de dónde viene cada efecto).
func note_law(title: String, changes: Dictionary) -> void:
	ensure()
	var og: Dictionary = st()["origin"]
	for k in changes.keys():
		og[str(k)] = {"title": title, "turn": m.turn()}

func origin_text(mid: String) -> String:
	var og: Dictionary = (st().get("origin", {}) as Dictionary).get(mid, {})
	if og.is_empty():
		return ""
	return "%s · T%d" % [str(og["title"]), int(og["turn"])]

func _measure_label(mid: String) -> String:
	var meas := Policies.measure(mid)
	var base := str(meas.get("name", mid))
	var o := origin_text(mid)
	return "%s (%s)" % [base, o] if o != "" else base

# ================================================================ turno
## Un trimestre de economía. Se llama desde EconomySim.tick().
func tick() -> Dictionary:
	ensure()
	var S := st()
	var X := _context()
	var out := _step(S, X, true, true)
	S["turn"] = int(S["turn"]) + 1
	_publish_events(out)
	_record_hist(S)
	S["proj"] = project(6)
	return out

func _record_hist(S: Dictionary) -> void:
	var vv: Dictionary = S["v"]
	var snap: Dictionary = {}
	for k in HIST_KEYS:
		snap[k] = float(vv.get(k, 0.0))
	var h: Array = S["hist"]
	var wsnap: Dictionary = {}
	for cid in CORE + OWNED:
		var wl: Array = (S["why"] as Dictionary).get(cid, [])
		var keep: Array = []
		for i in range(mini(6, wl.size())):
			var wd: Dictionary = wl[i]
			keep.append({"label": str(wd["label"]), "kind": str(wd["kind"]), "ref": str(wd.get("ref", "")), "value": float(wd["value"])})
		wsnap[cid] = keep
	h.append({"t": m.clock_unix(), "label": Rules.quarter_label(m.clock_unix()), "v": snap, "why": wsnap})
	while h.size() > HIST_MAX:
		h.pop_front()

func history() -> Array:
	ensure()
	return st()["hist"]

# ---------------------------------------------------------------- shocks
func active_shocks() -> Array:
	ensure()
	var out: Array = []
	for s in st()["shocks"]:
		var sd: Dictionary = s
		var d := shock_def(str(sd["id"]))
		out.append({"id": str(sd["id"]), "name": str(d.get("name", "")), "good": bool(d.get("good", false)), "age": int(sd["age"]), "dur": int(sd["dur"]),
			"intensity": _intensity(sd), "left": maxi(0, int(sd["dur"]) - int(sd["age"])), "body": str(d.get("body", ""))})
	return out

static func shock_def(id: String) -> Dictionary:
	for d in SHOCKS:
		if str((d as Dictionary)["id"]) == id:
			return d
	return {}

static func _intensity(sd: Dictionary) -> float:
	return maxf(0.0, float(sd.get("amp", 1.0)) * (1.0 - float(sd["age"]) / maxf(1.0, float(sd["dur"]))))

func events() -> Array:
	ensure()
	return st()["events"]

func _shock_fx(S: Dictionary) -> Dictionary:
	var fx: Dictionary = {}
	var per: Array = []
	for s in S["shocks"]:
		var sd: Dictionary = s
		var d := shock_def(str(sd["id"]))
		var it := _intensity(sd)
		var one: Dictionary = {}
		for k in (d["fx"] as Dictionary).keys():
			var val := float(d["fx"][k]) * it
			fx[k] = float(fx.get(k, 0.0)) + val
			one[k] = val
		per.append({"id": str(sd["id"]), "name": str(d["name"]), "fx": one, "good": bool(d["good"])})
	fx["_list"] = per
	return fx

func _haz_mult(id: String, S: Dictionary, X: Dictionary) -> float:
	var vv: Dictionary = S["v"]
	var z: Dictionary = X["z"]
	match id:
		"crisis_financiera":
			return 1.0 + maxf(0.0, float(vv["bubble"]) - 8.0) / 8.0 + maxf(0.0, float(X["debt"]) - 110.0) / 30.0 + maxf(0.0, float(vv["bank"]) - 25.0) / 35.0
		"crisis_deuda":
			return 0.4 + maxf(0.0, float(X["debt"]) - 105.0) / 12.0 + maxf(0.0, float(X["deficit"]) - 4.0) / 2.0 + float(vv["spread"]) * 0.4
		"burbuja_vivienda":
			return 0.3 + maxf(0.0, float(vv["bubble"]) - 10.0) / 5.0 + maxf(0.0, float(vv["rate"]) - 3.5) * 0.4
		"recesion_global":
			return 1.0 + maxf(0.0, float(vv["world_g"]) - 3.0) * 0.3
		"recuperacion_global":
			return 0.3 + (2.0 if float(vv["world_g"]) < 1.0 else 0.0)
		"shock_energetico":
			return clampf(1.0 - 0.15 * float(z.get("renewables", 0.0)), 0.5, 1.6)
		"boom_tecnologico":
			return clampf(0.7 + 0.5 * float(z.get("digital", 0.0)) + 0.3 * float(z.get("r_d", 0.0)), 0.3, 2.0)
		"fondos_europeos":
			return clampf(0.8 + 0.3 * float(z.get("trust", 0.0)), 0.3, 1.8)
		"boom_turistico":
			return 1.0 if float(vv["tour_dem"]) < 6.0 else 0.5
		"sequia":
			return clampf(1.0 + 0.1 * (float(m.world.value("emissions")) - 288.0) / 12.0, 0.7, 2.0)
	return 1.0

func _spawn(S: Dictionary, X: Dictionary, noise: bool) -> Array:
	var out: Array = []
	if not noise:
		return out
	if int(S.get("quiet", 0)) > 0:
		S["quiet"] = int(S["quiet"]) - 1
		return out
	var active: Array = S["shocks"]
	var bad_active := 0
	for s in active:
		if not bool(shock_def(str((s as Dictionary)["id"])).get("good", false)):
			bad_active += 1
	for it in SHOCKS:
		var d: Dictionary = it
		var id := str(d["id"])
		# se consumen siempre las mismas tiradas por shock para que dos partidas con la
		# misma semilla sigan sincronizadas aunque una política altere las probabilidades
		var roll := m.rng.randf()
		var dr: Array = d["dur"]
		var dur := m.rng.randi_range(int(dr[0]), int(dr[1]))
		var amp := m.rng.randf_range(0.8, 1.25)
		var dup := false
		for s2 in active:
			if str((s2 as Dictionary)["id"]) == id:
				dup = true
		if dup:
			continue
		if not bool(d["good"]) and bad_active >= 2:
			continue
		var haz := float(d["haz"]) * 1.4 * _haz_mult(id, S, X)
		if roll < haz:
			var sd := {"id": id, "age": 0, "dur": dur, "amp": amp}
			active.append(sd)
			out.append(sd)
			if not bool(d["good"]):
				bad_active += 1
	return out

func _publish_events(out: Dictionary) -> void:
	var S := st()
	for sd in out.get("spawned", []):
		var d := shock_def(str((sd as Dictionary)["id"]))
		(S["events"] as Array).append({"turn": int(S["turn"]), "t": m.clock_unix(), "id": str(d["id"]), "name": str(d["name"]), "good": bool(d["good"]), "text": str(d["body"])})
		m.publish(str(d["title"]), "%s Duración estimada: %d trimestres." % [str(d["body"]), int((sd as Dictionary)["dur"])], "ECONOMÍA", "positive" if bool(d["good"]) else "warning")
	while (S["events"] as Array).size() > 40:
		(S["events"] as Array).pop_front()

# ================================================================ el paso trimestral
func _rn(sd: float, on: bool) -> float:
	return m.rng.randfn(0.0, sd) if on else 0.0

func _step(S: Dictionary, X: Dictionary, noise: bool, spawn: bool) -> Dictionary:
	var vv: Dictionary = S["v"]
	var z: Dictionary = X["z"]
	var mb: Dictionary = X["mb"]
	var rng := m.rng
	var res: Dictionary = {"spawned": []}
	var nz := 1.0 if noise else 0.0
	# ---- 1. shocks
	if spawn:
		res["spawned"] = _spawn(S, X, noise)
	var fx := _shock_fx(S)
	# ---- 2. medidas con retardo
	var pol: Dictionary = S["pol"]
	var steps_now: Dictionary = X["steps"]
	var dpol: Dictionary = {}          # variable propia -> cambio de nivel (puntos de índice) este turno
	var dpol_parts: Dictionary = {}    # variable propia -> [{label, ref, value}]
	var core_pol: Dictionary = {"growth": [], "unemployment": [], "inflation": []}
	var ids: Dictionary = {}
	for k in steps_now.keys():
		ids[str(k)] = true
	for k2 in pol.keys():
		ids[str(k2)] = true
	for mid in ids.keys():
		var meas := Policies.measure(str(mid))
		if meas.is_empty():
			continue
		var cur_steps := float(steps_now.get(mid, 0.0))
		var old := float(pol.get(mid, 0.0))
		var nw := old + POL_LAG * (cur_steps - old)
		if absf(nw) < 0.0005 and absf(cur_steps) < 0.0005:
			pol.erase(mid)
			nw = 0.0
		else:
			pol[mid] = nw
		var fxd: Dictionary = meas.get("fx", {})
		for var_id in fxd.keys():
			var vid := str(var_id)
			var val := float(fxd[var_id])
			if CORE.has(vid):
				(core_pol[vid] as Array).append(_c("m:" + str(mid), _measure_label(str(mid)), "policy", str(mid), val * nw))
			elif OWNED.has(vid):
				var dv := val * (nw - old)
				if absf(dv) > 0.00001:
					dpol[vid] = float(dpol.get(vid, 0.0)) + dv
					if not dpol_parts.has(vid):
						dpol_parts[vid] = []
					(dpol_parts[vid] as Array).append({"label": _measure_label(str(mid)), "kind": "policy", "ref": str(mid), "via": "", "value": dv})
	# ---- 3. entorno exterior (base aleatoria persistente + shocks)
	vv["ar_wg"] = 0.55 * float(vv["ar_wg"]) + _rn(0.42, noise)
	vv["ar_dem"] = 0.5 * float(vv["ar_dem"]) + _rn(0.42, noise)
	var wg_b := 2.2 + float(vv["ar_wg"])
	var world_g := wg_b + float(fx.get("world_g", 0.0))
	vv["ar_oil"] = 0.7 * float(vv["ar_oil"]) + _rn(4.5, noise)
	var oil_b := clampf(100.0 + float(vv["ar_oil"]), 40.0, 320.0)
	var oil := clampf(oil_b + float(fx.get("oil", 0.0)), 40.0, 320.0)
	vv["ar_winf"] = 0.6 * float(vv["ar_winf"]) + _rn(0.25, noise)
	var world_inf := clampf(2.5 + 0.02 * (oil - 100.0) + float(vv["ar_winf"]) + float(fx.get("winf", 0.0)), -0.5, 12.0)
	vv["ar_risk"] = 0.6 * float(vv["ar_risk"]) + _rn(0.12, noise)
	var risk := clampf(float(vv["ar_risk"]) + float(fx.get("risk", 0.0)), -0.5, 2.5)
	vv["ar_tour"] = 0.65 * float(vv["ar_tour"]) + _rn(2.2, noise)
	var tour_b := float(vv["ar_tour"])
	var tour_dem := tour_b + float(fx.get("tour", 0.0))
	vv["world_g"] = world_g
	vv["oil"] = oil
	vv["world_inf"] = world_inf
	vv["risk"] = risk
	vv["tour_dem"] = tour_dem
	# ---- 4. variables previas
	var pot := float(vv["pot"])
	var gap0 := float(vv["gap"])
	var u0 := float(vv["unemployment"])
	var infl0 := float(vv["inflation"])
	var infl_e := float(vv["infl_e"])
	var rate := float(vv["rate"])
	var rr := rate - infl_e
	var rr0 := float(vv["rr0"])
	var bank0 := float(vv["bank"])
	var credit0 := float(vv["credit_g"])
	var g0 := float(vv["growth"])
	# ---- 5. hogares: renta, confianza y ahorro
	var d_tax := float(X["tax"]) - float(vv["tax_prev"])
	var d_sp := float(X["sp"]) - float(vv["sp_prev"])
	var rdi_prev := float(vv["rdi"])
	var wage_prev := float(vv["wage_g"])
	var rdi := pot - 2.0 * float(vv["du"]) + (wage_prev - infl0 - float(vv["rw0"])) - 1.2 * d_tax + 0.25 * (float(vv["g_g"]) - pot)
	rdi = clampf(rdi, -12.0, 12.0)
	var conf_c_t := 50.0 + 2.5 * (rdi_prev - pot) - 2.0 * (u0 - U0) - 1.2 * (infl0 - 3.0) + 4.0 * float(z.get("trust", 0.0)) + float(fx.get("conf", 0.0)) - 0.15 * (bank0 - 25.0) + 0.04 * (float(X["stab"]) - float(vv["stab0"]))
	var conf_c := clampf(float(vv["conf_c"]) + 0.5 * (conf_c_t - float(vv["conf_c"])), 5.0, 95.0)
	var conf_f_t := 50.0 + 3.0 * (g0 - pot) - 3.0 * (rr - rr0) - 0.5 * float(vv["ulc_gap"]) + 3.0 * float(z.get("digital", 0.0)) + float(fx.get("conf", 0.0)) - 0.12 * (bank0 - 25.0) + 0.06 * (float(X["stab"]) - float(vv["stab0"]))
	var conf_f := clampf(float(vv["conf_f"]) + 0.5 * (conf_f_t - float(vv["conf_f"])), 5.0, 95.0)
	var sav_t := 7.4 + 0.35 * (u0 - U0) + 0.5 * maxf(0.0, infl0 - 3.0) + 0.6 * (rr - rr0) - 0.04 * (conf_c - 50.0)
	var sav_prev := float(vv["sav"])
	var sav := clampf(sav_prev + 0.4 * (sav_t - sav_prev), 2.0, 20.0)
	vv["sav_prev"] = sav_prev
	vv["sav"] = sav
	vv["conf_c"] = conf_c
	vv["conf_f"] = conf_f
	# ---- 6. demanda: consumo, inversión, exterior, gasto público (sin shocks → «0»; con shocks → nivel observado)
	var ulc0 := float(vv["ulc_gap"])
	var wealth := 0.05 * (float(vv["hp_g"]) - infl0)
	var dem_s := float(fx.get("dem", 0.0))
	var c_terms: Array = [
		_c("c1", "Renta real de los hogares", "agent", "", 0.75 * (rdi - pot), "rdi"),
		_c("c2", "Ahorro precautorio", "agent", "", -1.3 * (sav - sav_prev), "sav"),
		_c("c3", "Tipos de interés reales", "agent", "", -0.25 * (rr - rr0), "rate"),
		_c("c4", "Confianza de los consumidores", "agent", "", 0.04 * (conf_c - 50.0), "conf_c"),
		_c("c5", "Efecto riqueza (vivienda)", "agent", "", wealth, "hp_g"),
		_c("c6", "Crédito a los hogares", "agent", "", 0.05 * (credit0 - 3.0), "credit_g"),
	]
	var c_g0 := pot
	for t in c_terms:
		c_g0 += float((t as Dictionary)["t"])
	c_g0 = clampf(c_g0, -16.0, 12.0)
	var i_terms: Array = [
		_c("i1", "Acelerador (crecimiento reciente)", "agent", "", 1.8 * (g0 - pot), "growth"),
		_c("i2", "Tipos de interés reales", "agent", "", -0.9 * (rr - rr0), "rate"),
		_c("i3", "Confianza empresarial", "agent", "", 0.06 * (conf_f - 50.0), "conf_f"),
		_c("i4", "Márgenes (costes laborales)", "agent", "", -0.25 * ulc0, "ulc_gap"),
		_c("i5", "Crédito a las empresas", "agent", "", 0.05 * (credit0 - 3.0) - 0.03 * (bank0 - 25.0), "credit_g"),
	]
	var i_g0 := pot
	for t2 in i_terms:
		i_g0 += float((t2 as Dictionary)["t"])
	i_g0 = clampf(i_g0, -30.0, 20.0)
	var tour_now := m.world.value("tourism")
	var tour_chg := (tour_now - float(vv["tour_prev"])) / 100.0 * 400.0
	var x_terms: Array = [
		_c("x1", "Demanda mundial", "agent", "", 0.8 * (wg_b - 2.2), "world_g"),
		_c("x2", "Turismo", "agent", "", 0.012 * tour_chg + 0.02 * tour_b, "tourism"),
		_c("x3", "Competitividad (costes laborales)", "agent", "", -0.5 * ulc0, "ulc_gap"),
		_c("x4", "Factura energética", "agent", "", -0.02 * (oil_b - 100.0), "energy_price"),
	]
	var x_g0 := pot
	for t3 in x_terms:
		x_g0 += float((t3 as Dictionary)["t"])
	x_g0 = clampf(x_g0, -25.0, 18.0)
	var mm_g0 := clampf(pot + 1.1 * (SC * (c_g0 - pot) + SI * (i_g0 - pot)) / (SC + SI) + 0.012 * (oil_b - 100.0), -25.0, 18.0)
	var g_g0 := clampf(pot + 2.5 * d_sp, -8.0, 10.0)
	# Efecto de los shocks en cada demanda (para el nivel observado).
	var c_g := clampf(c_g0 + 0.55 * dem_s, -16.0, 12.0)
	var i_g := clampf(i_g0 + float(fx.get("inv", 0.0)) + 0.3 * dem_s, -30.0, 20.0)
	var x_g := clampf(x_g0 + 0.8 * float(fx.get("world_g", 0.0)) + 0.02 * float(fx.get("tour", 0.0)) - 0.02 * float(fx.get("oil", 0.0)), -25.0, 18.0)
	var g_g := clampf(g_g0 + float(fx.get("gov", 0.0)), -8.0, 10.0)
	var mm_g := clampf(pot + 1.1 * (SC * (c_g - pot) + SI * (i_g - pot)) / (SC + SI) + 0.012 * (oil - 100.0), -25.0, 18.0)
	# ---- 7. crecimiento (suma de componentes: cada una con su causa)
	var comps_g: Array = [
		_c("pot", "Crecimiento potencial", "structural", "", pot, "pot"),
		_c("c", "Consumo de los hogares", "agent", "", SC * (c_g0 - pot), "consumption"),
		_c("i", "Inversión empresarial", "agent", "", SI * (i_g0 - pot), "investment"),
		_c("g", "Gasto público", "agent", "", SG * (g_g0 - pot), "g_g"),
		_c("x", "Sector exterior", "agent", "", SX * (x_g0 - pot) - SM * (mm_g0 - pot), "exports"),
		_c("cyc", "Corrección del ciclo", "agent", "", -0.15 * gap0, "gap"),
		_c("ani", "Ánimo de los mercados y expectativas", "agent", "", float(vv["ar_dem"]), "conf_f"),
		_c("net", "Confianza, empleo informal y emprendimiento", "agent", "", _feed_free("growth"), ""),
		_c("min", "Gestión de los ministros", "agent", "", float(mb.get("growth", 0.0)), ""),
	]
	for sh in fx["_list"]:
		var shd: Dictionary = sh
		var sfx: Dictionary = shd["fx"]
		var sg := float(sfx.get("dem", 0.0)) + SI * float(sfx.get("inv", 0.0)) + SG * float(sfx.get("gov", 0.0)) \
			+ SX * (0.8 * float(sfx.get("world_g", 0.0)) + 0.02 * float(sfx.get("tour", 0.0)) - 0.02 * float(sfx.get("oil", 0.0)))
		if absf(sg) > 0.0001:
			comps_g.append(_c("s:" + str(shd["id"]), str(shd["name"]), "shock", str(shd["id"]), sg))
	for pc in core_pol["growth"]:
		comps_g.append(pc)
	var growth := clampf(_upd(S, "growth", comps_g, float(K["growth"]), float(vv["growth"])), -14.0, 9.0)
	vv["growth_prev"] = g0
	vv["growth"] = growth
	var gap := clampf(0.92 * gap0 + (growth - pot) / 4.0, -14.0, 10.0)
	vv["gap"] = gap
	vv["c_g"] = c_g
	vv["i_g"] = i_g
	vv["x_g"] = x_g
	vv["mm_g"] = mm_g
	vv["g_g"] = g_g
	# ---- 8. paro
	var mig := float(X["mig"])
	var comps_u: Array = [
		_c("base", "Tasa estructural", "structural", "", U0),
		_c("cyc", "Ciclo económico (brecha de producción)", "agent", "", -0.55 * gap, "gap"),
		_c("hys", "Histéresis (paro de larga duración)", "agent", "", 0.2 * (u0 - U0), ""),
		_c("skl", "Cualificación de los trabajadores", "agent", "", -0.15 * float(z.get("skills", 0.0)), "skills"),
		_c("mig", "Inmigración y fuerza laboral", "agent", "", 0.0015 * (mig - 640.0), "net_migration"),
		_c("bnk", "Tensión bancaria (crédito)", "agent", "", 0.02 * (bank0 - 25.0), "bank"),
		_c("min", "Gestión de los ministros", "agent", "", float(mb.get("unemployment", 0.0)), ""),
	]
	if absf(float(fx.get("unemp", 0.0))) > 0.0001:
		for sh2 in fx["_list"]:
			var sh2d: Dictionary = sh2
			var du2 := float((sh2d["fx"] as Dictionary).get("unemp", 0.0))
			if absf(du2) > 0.0001:
				comps_u.append(_c("s:" + str(sh2d["id"]), str(sh2d["name"]), "shock", str(sh2d["id"]), du2))
	for pc2 in core_pol["unemployment"]:
		comps_u.append(pc2)
	var u_new := clampf(_upd(S, "unemployment", comps_u, float(K["unemployment"]), u0), 3.0, 32.0)
	vv["du"] = u_new - u0
	vv["unemployment"] = u_new
	# ---- 9. salarios, productividad y costes
	var prod_g := 1.0 + 0.3 * (growth - pot) + 0.04 * float(z.get("r_d", 0.0)) + 0.04 * float(z.get("digital", 0.0)) + 0.03 * float(z.get("skills", 0.0)) + float(fx.get("prod", 0.0)) + 4.0 * float(dpol.get("productivity", 0.0))
	prod_g = clampf(prod_g, -3.0, 4.5)
	var wage_g := 0.55 * infl_e + 0.30 * infl0 + 0.5 * prod_g - 0.30 * (u0 - U0) + 0.10 + 2.0 * float(dpol.get("wages", 0.0))
	wage_g = clampf(wage_g, -3.0, 14.0)
	var ulc_gap := (wage_g - prod_g) - 2.0
	vv["prod_g"] = prod_g
	vv["prod_tr"] = 0.8 * float(vv["prod_tr"]) + 0.2 * prod_g
	vv["wage_g"] = wage_g
	vv["ulc_gap"] = ulc_gap
	vv["rdi"] = rdi
	# ---- 10. inflación
	var oil_hist: Array = vv["oil_hist"]
	var energy_yoy := (oil / maxf(10.0, float(oil_hist[0])) - 1.0) * 100.0
	var comps_i: Array = [
		_c("base", "Inflación subyacente estructural", "structural", "", 0.45),
		_c("exp", "Expectativas de inflación", "agent", "", 0.65 * infl_e, "infl_e"),
		_c("idx", "Indexación a la inflación pasada", "agent", "", 0.20 * infl0, ""),
		_c("dem", "Demanda (brecha de producción)", "agent", "", 0.28 * gap, "gap"),
		_c("ulc", "Costes laborales unitarios", "agent", "", 0.30 * ulc_gap, "ulc_gap"),
		_c("en", "Precio de la energía", "agent", "", 0.05 * energy_yoy, "energy_price"),
		_c("imp", "Inflación importada del exterior", "agent", "", 0.20 * (world_inf - 2.5), "world_inf"),
		_c("mon", "Política monetaria del BCE", "agent", "", -0.15 * (rr - rr0), "rate"),
		_c("net", "Turismo y otros indicadores", "agent", "", _feed_free("inflation"), ""),
		_c("min", "Gestión de los ministros", "agent", "", float(mb.get("inflation", 0.0)), ""),
	]
	if absf(float(fx.get("supply", 0.0))) > 0.0001:
		for sh3 in fx["_list"]:
			var sh3d: Dictionary = sh3
			var sp3 := float((sh3d["fx"] as Dictionary).get("supply", 0.0))
			if absf(sp3) > 0.0001:
				comps_i.append(_c("s:" + str(sh3d["id"]), str(sh3d["name"]), "shock", str(sh3d["id"]), sp3))
	for pc3 in core_pol["inflation"]:
		comps_i.append(pc3)
	var infl := clampf(_upd(S, "inflation", comps_i, float(K["inflation"]), infl0), -2.0, 25.0)
	vv["inflation"] = infl
	var cred := clampf(1.0 - 0.12 * maxf(0.0, infl0 - 3.5), 0.2, 1.0)
	vv["infl_e"] = clampf(infl_e + 0.35 * (infl0 - infl_e) + 0.15 * cred * (2.0 - infl_e), -1.0, 20.0)
	oil_hist.append(oil)
	oil_hist.pop_front()
	# ---- 11. BCE y mercados
	vv["ez_inf"] = 0.7 * float(vv["ez_inf"]) + 0.1 * infl + 0.2 * world_inf
	vv["ez_gap"] = 0.6 * float(vv["ez_gap"]) + 0.32 * (world_g - 2.2) + 0.1 * gap
	var r_target := 1.0 + 1.5 * (float(vv["ez_inf"]) - 2.0) + 0.5 * float(vv["ez_gap"])
	var move := clampf(0.5 * (r_target - rate), -0.75, 0.75)
	rate = clampf(rate + snappedf(move, 0.25), 0.0, 9.0)
	vv["rate"] = rate
	var debt := float(X["debt"])
	var sp_t := 0.5 + 0.03 * (debt - 107.0) + 0.004 * maxf(0.0, debt - 110.0) * maxf(0.0, debt - 110.0) + 0.14 * (float(X["deficit"]) - 3.6) + 0.35 * risk + 0.025 * (bank0 - 25.0) - 0.08 * (growth - pot)
	vv["spread"] = clampf(float(vv["spread"]) + 0.6 * (sp_t - float(vv["spread"])), 0.1, 10.0)
	vv["eff_cost"] = clampf(float(vv["eff_cost"]) + 0.10 * (rate + float(vv["spread"]) - float(vv["eff_cost"])), 0.2, 14.0)
	# ---- 12. bancos y vivienda
	var rr_new := rate - float(vv["infl_e"])
	var credit_t := 3.0 + 0.8 * (growth - pot) - 0.9 * (rr_new - rr0) - 0.12 * (bank0 - 25.0) + 0.04 * (float(vv["hp_g"]) - 3.0) + float(fx.get("credit", 0.0))
	vv["credit_g"] = clampf(credit0 + 0.5 * (credit_t - credit0), -15.0, 20.0)
	var npl_t := 3.5 + 0.4 * (u_new - U0) + 0.05 * maxf(0.0, -float(vv["hp_g"])) * 4.0 + 0.25 * maxf(0.0, rate - 2.5)
	vv["npl"] = clampf(float(vv["npl"]) + 0.3 * (npl_t - float(vv["npl"])), 1.0, 25.0)
	var bank_t := 25.0 + 6.0 * (float(vv["npl"]) - 3.5) + 8.0 * maxf(0.0, float(vv["spread"]) - 1.0) + 0.5 * maxf(0.0, float(vv["bubble"]) - 10.0) + float(fx.get("bank", 0.0))
	vv["bank"] = clampf(bank0 + 0.5 * (bank_t - bank0), 0.0, 100.0)
	var hp_terms: Array = [
		_c("h1", "Renta nominal de los hogares", "agent", "", 0.45 * (growth + infl), "rdi"),
		_c("h2", "Crédito hipotecario", "agent", "", 0.25 * float(vv["credit_g"]), "credit_g"),
		_c("h3", "Tipos de interés", "agent", "", -1.2 * (rate - 2.5), "rate"),
		_c("h4", "Inmigración y demanda", "agent", "", 0.002 * (mig - 640.0), "net_migration"),
		_c("h5", "Oferta de vivienda protegida", "agent", "", -0.5 * float(z.get("housing_stock", 0.0)), "housing_stock"),
		_c("h6", "Corrección de la burbuja", "agent", "", -0.12 * float(vv["bubble"]), "bubble"),
		_c("h7", "Inercia del mercado", "agent", "", 0.4 * float(vv["hp_g"]) - 1.15, "hp_g"),
	]
	var hp_g := 0.0
	for t4 in hp_terms:
		hp_g += float((t4 as Dictionary)["t"])
	hp_g += float(fx.get("hp", 0.0))
	hp_g = clampf(hp_g, -25.0, 25.0)
	vv["hp_g"] = hp_g
	vv["hp_idx"] = float(vv["hp_idx"]) * (1.0 + hp_g / 400.0)
	vv["hp_fund"] = float(vv["hp_fund"]) * (1.0 + 0.95 * (growth + infl) / 400.0)
	vv["bubble"] = (float(vv["hp_idx"]) / maxf(1.0, float(vv["hp_fund"])) - 1.0) * 100.0
	# ---- 13. potencial
	var inv_z := (float(m.world.value("investment")) - 100.0) / 8.0
	var pot_t := POT0 + 0.5 * (float(vv["prod_tr"]) - 1.0) + 0.12 * inv_z + 0.0008 * (mig - 640.0) + 0.1 * float(z.get("skills", 0.0)) - 0.05 * maxf(0.0, u_new - U0) + 0.012 * (m.eco.quality("innovation") - 45.0) + 0.008 * (m.eco.quality("infrastructure") - 66.0)
	vv["pot"] = clampf(pot + 0.2 * (pot_t - pot), 0.2, 3.5)
	# ---- 14. indicadores propios (niveles)
	var owned: Dictionary = {}
	var wv: Dictionary = m.world.st()["v"]
	var whys: Dictionary = S["why"]
	var wi := float(wv.get("wages", 100.0))
	var d_w := wi * (wage_g - infl) / 400.0
	owned["wages"] = {"v": wi + d_w + float(dpol.get("wages", 0.0)),
		"parts": [{"label": "Subida salarial pactada", "kind": "agent", "ref": "", "via": "wage_g", "value": wi * wage_g / 400.0}, {"label": "Inflación (pierde poder adquisitivo)", "kind": "agent", "ref": "", "via": "inflation", "value": -wi * infl / 400.0}]}
	var pi := float(wv.get("productivity", 100.0))
	owned["productivity"] = {"v": pi * (1.0 + prod_g / 400.0) + float(dpol.get("productivity", 0.0)),
		"parts": [{"label": "Ciclo, digitalización, I+D y cualificación", "kind": "agent", "ref": "", "via": "prod_g", "value": pi * prod_g / 400.0}]}
	var ci := float(wv.get("consumption", 100.0))
	owned["consumption"] = {"v": ci * (1.0 + c_g / 400.0) + float(dpol.get("consumption", 0.0)), "parts": _scale_parts(c_terms, ci / 400.0, pot, fx, "consumption")}
	var ii := float(wv.get("investment", 100.0))
	owned["investment"] = {"v": ii * (1.0 + i_g / 400.0) + float(dpol.get("investment", 0.0)), "parts": _scale_parts(i_terms, ii / 400.0, pot, fx, "investment")}
	var ei := float(wv.get("exports", 35.0))
	owned["exports"] = {"v": ei * (1.0 + (x_g - growth) / 400.0) + float(dpol.get("exports", 0.0)), "parts": _scale_parts(x_terms, ei / 400.0, pot - growth, fx, "exports")}
	var hi := float(wv.get("house_price", 100.0))
	owned["house_price"] = {"v": float(vv["hp_idx"]) + float(dpol.get("house_price", 0.0)), "parts": _scale_parts(hp_terms, float(vv["hp_idx"]) / 400.0, 0.0, fx, "house_price")}
	vv["hp_idx"] = float(owned["house_price"]["v"])
	var ren := float(z.get("renewables", 0.0))
	vv["plev_en"] = float(vv.get("plev_en", 0.0)) + float(dpol.get("energy_price", 0.0))
	var en := clampf(oil * (1.0 - 0.06 * ren) + float(vv["plev_en"]), 40.0, 320.0)
	owned["energy_price"] = {"v": en, "parts": [{"label": "Mercados internacionales de energía", "kind": "agent", "ref": "", "via": "oil", "value": en - float(wv.get("energy_price", 100.0))}]}
	for var_id2 in owned.keys():
		var od: Dictionary = owned[var_id2]
		var plist: Array = (od["parts"] as Array).duplicate()
		for pp in dpol_parts.get(var_id2, []):
			plist.append(pp)
		plist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
		whys[var_id2] = plist
	res["owned"] = owned
	vv["tax_prev"] = float(X["tax"])
	vv["sp_prev"] = float(X["sp"])
	vv["tour_prev"] = tour_now
	# envejecimiento de los shocks
	var keep: Array = []
	for s in S["shocks"]:
		var sd: Dictionary = s
		sd["age"] = int(sd["age"]) + 1
		if int(sd["age"]) < int(sd["dur"]):
			keep.append(sd)
	S["shocks"] = keep
	res["growth"] = growth
	res["unemployment"] = u_new
	res["inflation"] = infl
	res["rate"] = rate
	return res

## Descompone la variación de un indicador propio en los términos de su ecuación (cada término por la escala del nivel).
func _scale_parts(terms: Array, sc: float, base: float, fx: Dictionary, own: String) -> Array:
	var out: Array = []
	if absf(base) > 0.0001:
		out.append({"label": "Tendencia de crecimiento potencial", "kind": "structural", "ref": "", "via": "pot", "value": base * sc})
	for t in terms:
		var td: Dictionary = t
		out.append({"label": str(td["label"]), "kind": "agent", "ref": "", "via": str(td["via"]), "value": float(td["t"]) * sc})
	for sh in fx["_list"]:
		var shd: Dictionary = sh
		var sfx: Dictionary = shd["fx"]
		var val := 0.0
		match own:
			"consumption": val = 0.55 * float(sfx.get("dem", 0.0))
			"investment": val = float(sfx.get("inv", 0.0)) + 0.3 * float(sfx.get("dem", 0.0))
			"house_price": val = float(sfx.get("hp", 0.0))
			"exports": val = 0.8 * float(sfx.get("world_g", 0.0)) + 0.02 * float(sfx.get("tour", 0.0)) - 0.02 * float(sfx.get("oil", 0.0))
		if absf(val) > 0.0001:
			out.append({"label": str(shd["name"]), "kind": "shock", "ref": str(shd["id"]), "via": "", "value": val * sc})
	return out

## Término libre de la red de indicadores que alimentan a una variable central (sin los que ya modela el motor).
func _feed_free(core_id: String) -> float:
	return m.world.feed(core_id, OWNED + ["skills"] if core_id == "unemployment" else OWNED)

# ================================================================ proyección y previsión
## Trayectoria sin nuevos shocks para los próximos `n` trimestres: [{growth, unemployment, inflation, rate, spread, ...}].
func project(n: int) -> Array:
	ensure()
	var S := st().duplicate(true)
	var X := _context()
	var out: Array = []
	for i in range(n):
		_step(S, X, false, false)
		var vv: Dictionary = S["v"]
		var snap: Dictionary = {}
		for k in HIST_KEYS:
			snap[k] = float(vv.get(k, 0.0))
		out.append(snap)
	return out

## Previsión del consenso de analistas para el próximo trimestre (con su sesgo) y sorpresa del último.
func forecast_next() -> Dictionary:
	ensure()
	var p := project(1)
	if p.is_empty():
		return {}
	var f: Dictionary = p[0]
	return {"growth": float(f["growth"]), "unemployment": float(f["unemployment"]), "inflation": float(f["inflation"])}

# ================================================================ avisos
## Riesgos y oportunidades de la economía: [{id, level (bad|warn|good), text, via}].
func alerts() -> Array:
	ensure()
	var vv: Dictionary = st()["v"]
	var out: Array = []
	var debt := m.eco.debt_pct()
	var deficit := -m.eco.balance_pct()
	if float(vv["growth"]) < 0.0:
		out.append({"id": "recesion", "level": "bad", "text": "La economía se contrae (%.1f %%): hay recesión." % float(vv["growth"]), "via": "growth"})
	elif float(vv["gap"]) > 2.5:
		out.append({"id": "calentamiento", "level": "warn", "text": "Sobrecalentamiento: se produce por encima de la capacidad y sube la inflación.", "via": "gap"})
	if float(vv["unemployment"]) > 15.0:
		out.append({"id": "paro", "level": "bad", "text": "Paro muy alto (%.1f %%): las familias recortan gasto y la protesta crece." % float(vv["unemployment"]), "via": "unemployment"})
	if float(vv["inflation"]) > 5.0:
		out.append({"id": "inflacion", "level": "bad", "text": "Inflación alta (%.1f %%): se come el poder adquisitivo y el BCE aprieta." % float(vv["inflation"]), "via": "inflation"})
	elif float(vv["infl_e"]) > 3.6:
		out.append({"id": "expectativas", "level": "warn", "text": "Las expectativas de inflación se desanclan (%.1f %%): cuesta más bajar los precios." % float(vv["infl_e"]), "via": "infl_e"})
	if float(vv["bubble"]) > 15.0:
		out.append({"id": "burbuja", "level": "warn", "text": "La vivienda está %.0f %% sobrevalorada: riesgo de pinchazo con los tipos al alza." % float(vv["bubble"]), "via": "bubble"})
	if float(vv["spread"]) > 2.0:
		out.append({"id": "prima", "level": "bad" if float(vv["spread"]) > 3.5 else "warn", "text": "La prima de riesgo sube a %.1f pp: financiarse se encarece." % float(vv["spread"]), "via": "spread"})
	if float(vv["bank"]) > 50.0:
		out.append({"id": "bancos", "level": "bad" if float(vv["bank"]) > 65.0 else "warn", "text": "Tensión en los bancos (%.0f/100): el crédito se estrecha." % float(vv["bank"]), "via": "bank"})
	if deficit > 5.0:
		out.append({"id": "deficit", "level": "warn", "text": "Déficit de %.1f %% del PIB: la deuda sigue creciendo." % deficit, "via": "deficit"})
	if debt > 120.0:
		out.append({"id": "deuda", "level": "warn", "text": "Deuda del %.0f %% del PIB: poco margen ante una crisis." % debt, "via": "debt"})
	if float(vv["growth"]) > 3.0 and float(vv["du"]) <= 0.0 and float(vv["inflation"]) < 3.5:
		out.append({"id": "bonanza", "level": "good", "text": "Fase de bonanza: crece la economía, baja el paro y los precios están controlados.", "via": "growth"})
	for s in active_shocks():
		var sd: Dictionary = s
		out.append({"id": "shock_" + str(sd["id"]), "level": "good" if bool(sd["good"]) else "warn", "text": "%s (quedan %d trimestres)." % [str(sd["name"]), int(sd["left"])], "via": ""})
	return out

# ================================================================ informe trimestral
## Noticia con el resumen del trimestre: cifras, causas principales y avisos.
func quarter_report() -> void:
	ensure()
	var vv: Dictionary = st()["v"]
	var parts: Array = []
	for id in ["growth", "unemployment", "inflation"]:
		var w: Array = why(id)
		var top := ""
		if not w.is_empty():
			var t: Dictionary = w[0]
			top = "%s %s" % [str(t["label"]), "empuja al alza" if float(t["value"]) > 0.0 else "empuja a la baja"]
		var label := {"growth": "PIB", "unemployment": "Paro", "inflation": "Inflación"}[id] as String
		parts.append("%s %.1f %%%s" % [label, float(vv[id]), (" (%s)" % top) if top != "" else ""])
	var al: Array = alerts()
	var extra := ""
	for a in al:
		var ad: Dictionary = a
		if str(ad["level"]) in ["bad", "warn"] and not str(ad["id"]).begins_with("shock_"):
			extra = " Aviso: %s" % str(ad["text"])
			break
	m.publish("Informe económico del trimestre", "; ".join(parts) + "." + extra + " Tipos del BCE: %.2f %%." % float(vv["rate"]), "ECONOMÍA", "neutral")
