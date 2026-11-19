class_name WorldSim
extends RefCounted
## Red de indicadores del país (salarios, vivienda, pobreza, emisiones, confianza…). Cada indicador converge con inercia
## hacia un objetivo que depende de: las medidas aplicadas (efectos «fx»), otros indicadores y variables centrales
## (vínculos causales con peso por desviación típica) y la dotación presupuestaria. Los indicadores devuelven su efecto a
## crecimiento, paro e inflación y a la satisfacción de los grupos, de modo que cualquier medida repercute en todo el país.
## Datos: data/scenarios/spain/world.json (generado con tools/gen_policies.py).

const PATH := "res://data/scenarios/spain/world.json"
const CORE_SCALE := {"growth": 1.0, "unemployment": 2.0, "inflation": 1.5, "rate": 1.0, "deficit": 2.0}
const CORE_START := {"growth": 1.9, "unemployment": 12.0, "inflation": 3.0, "rate": 2.5, "deficit": 3.6}
const QUALITY_SCALE := 10.0

var m: GameModel
static var _idx: Dictionary = {}

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- datos estáticos
static func data() -> Dictionary:
	var d: Variant = DataStore.read_json(PATH)
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func indicators() -> Array:
	return data().get("indicators", [])

static func def(id: String) -> Dictionary:
	if _idx.is_empty():
		for it in indicators():
			_idx[str((it as Dictionary)["id"])] = it
	return _idx.get(id, {})

static func has(id: String) -> bool:
	return not def(id).is_empty()

static func feeds() -> Dictionary:
	return data().get("feeds", {})

static func ids_of(domain: String) -> Array:
	var out: Array = []
	for it in indicators():
		if str((it as Dictionary)["domain"]) == domain:
			out.append(str((it as Dictionary)["id"]))
	return out

## Nombre legible de cualquier variable de la red (indicador, variable central o calidad de servicio).
static func name_of(id: String) -> String:
	if has(id):
		return str(def(id)["name"])
	match id:
		"rate": return "Tipo de interés"
		"deficit": return "Déficit público"
	return Policies.quality_name(id)

static func fmt(id: String, v: float) -> String:
	var d := def(id)
	if d.is_empty():
		return "%.1f" % v
	var num := ("%." + str(int(d.get("dec", 1))) + "f") % v
	var unit := str(d.get("unit", ""))
	if unit == "" or unit in ["índice", "puntos", "0-100"]:
		return num
	return "%s %s" % [num, unit]

# ---------------------------------------------------------------- estado
func st() -> Dictionary:
	return m.d("world")

func ensure() -> void:
	var e := st()
	if e.has("v"):
		return
	var v: Dictionary = {}
	for it in indicators():
		v[str((it as Dictionary)["id"])] = float((it as Dictionary)["start"])
	e["v"] = v
	e["hist"] = []
	_snapshot("Inicio")

func value(id: String) -> float:
	ensure()
	return float((st()["v"] as Dictionary).get(id, float(def(id).get("start", 0.0))))

func start_of(id: String) -> float:
	return float(def(id).get("start", 0.0))

## Desviación tipificada respecto al valor de partida.
func z(id: String) -> float:
	var d := def(id)
	if d.is_empty():
		return core_z(id)
	return (value(id) - float(d["start"])) / maxf(0.0001, float(d["scale"]))

## Desviación tipificada de una variable central o de una calidad de servicio.
func core_z(id: String) -> float:
	var e := m.eco.st()
	match id:
		"growth": return (float(e.get("growth", 1.9)) - 1.9) / float(CORE_SCALE["growth"])
		"unemployment": return (float(e.get("unemployment", 12.0)) - 12.0) / float(CORE_SCALE["unemployment"])
		"inflation": return (float(e.get("inflation", 3.0)) - 3.0) / float(CORE_SCALE["inflation"])
		"rate": return (float(e.get("rate", 2.5)) - 2.5) / float(CORE_SCALE["rate"])
		"deficit": return (-m.eco.balance_pct() - 3.6) / float(CORE_SCALE["deficit"])
	var q := Policies.entry(Policies.quality(), id)
	if q.is_empty():
		return 0.0
	return (m.eco.quality(id) - float(q.get("base", 50.0))) / QUALITY_SCALE

func any_z(id: String) -> float:
	return z(id) if has(id) else core_z(id)

## Positivo = mejor que al inicio (según el sentido «bueno» del indicador).
func goodness(id: String) -> float:
	return z(id) * float(def(id).get("good", 0))

# ---------------------------------------------------------------- objetivos
## Desglose del objetivo de un indicador: [{kind, id, label, value}], en las unidades del indicador.
func target_parts(id: String, eff: Dictionary = {}) -> Array:
	if eff.is_empty():
		eff = m.eco.policy_effects()
	var d := def(id)
	var out: Array = []
	var fx := float(((eff["fx"] as Dictionary)).get(id, 0.0))
	if absf(fx) > 0.00001:
		out.append({"kind": "policy", "id": id, "label": "Medidas aplicadas", "value": fx})
	var links: Dictionary = d.get("links", {})
	for k in links.keys():
		var c := float(links[k]) * any_z(str(k))
		if absf(c) > 0.00001:
			out.append({"kind": "link", "id": str(k), "label": name_of(str(k)), "value": c})
	var bf: Dictionary = d.get("bf", {})
	for k2 in bf.keys():
		var c2 := float(bf[k2]) * (m.eco.budget_factor(str(k2)) - 1.0)
		if absf(c2) > 0.00001:
			out.append({"kind": "budget", "id": str(k2), "label": "Presupuesto de " + str(Policies.entry(Policies.budget(), str(k2)).get("name", k2)), "value": c2})
	return out

func target(id: String, eff: Dictionary = {}) -> float:
	var d := def(id)
	var t := float(d["start"])
	for p in target_parts(id, eff):
		t += float((p as Dictionary)["value"])
	return clampf(t, float(d["min"]), float(d["max"]))

## Contribución de cada medida al objetivo del indicador: [{measure, value}] (solo medidas que se desvían de su base).
func policy_drivers(id: String) -> Array:
	var out: Array = []
	for it in Policies.measures():
		var meas: Dictionary = it
		var fxd: Dictionary = meas.get("fx", {})
		if not fxd.has(id):
			continue
		var v := m.eco.value(str(meas["id"]))
		var steps := (v - float(meas["base"])) / float(meas["step"])
		out.append({"measure": str(meas["id"]), "label": str(meas["name"]), "value": float(fxd[id]) * steps, "per_step": float(fxd[id])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out

# ---------------------------------------------------------------- tick
## Un trimestre. `owned` = {id: {v, parts}} con los indicadores que calcula el motor macro (salarios, consumo, vivienda…).
func tick(eff: Dictionary, owned: Dictionary = {}) -> void:
	ensure()
	var v: Dictionary = st()["v"]
	var nxt: Dictionary = {}
	for it in indicators():
		var d: Dictionary = it
		var id := str(d["id"])
		var cur := float(v.get(id, d["start"]))
		if owned.has(id):
			nxt[id] = clampf(float((owned[id] as Dictionary)["v"]), float(d["min"]), float(d["max"]))
			continue
		var tgt := target(id, eff)
		var q := 1.0 - pow(1.0 - float(d["rate"]), float(Rules.TURN_MONTHS))
		nxt[id] = clampf(cur + (tgt - cur) * q, float(d["min"]), float(d["max"]))
	for k in nxt.keys():
		v[k] = nxt[k]
	_snapshot("T%d" % m.turn())

func _snapshot(label: String) -> void:
	var e := st()
	var hist: Array = e["hist"]
	hist.append({"label": Rules.quarter_label(m.clock_unix()), "t": m.clock_unix(), "v": (e["v"] as Dictionary).duplicate()})
	while hist.size() > 360:
		hist.pop_front()

func history() -> Array:
	ensure()
	return st()["hist"]

func series(id: String, months: int = 0) -> Array:
	var out: Array = []
	var h := history()
	var from := maxi(0, h.size() - months) if months > 0 else 0
	for i in range(from, h.size()):
		out.append(float(((h[i] as Dictionary)["v"] as Dictionary).get(id, start_of(id))))
	return out

func labels(months: int = 0) -> Array:
	var out: Array = []
	var h := history()
	var from := maxi(0, h.size() - months) if months > 0 else 0
	for i in range(from, h.size()):
		out.append(str((h[i] as Dictionary).get("label", "")))
	return out

func delta(id: String, months_back: int = 12) -> float:
	var h := history()
	if h.size() < 2:
		return 0.0
	var past: Dictionary = h[maxi(0, h.size() - 1 - months_back)]
	return value(id) - float((past["v"] as Dictionary).get(id, value(id)))

# ---------------------------------------------------------------- efecto sobre los mandos centrales
## Suma de (peso × desviación) de los indicadores que alimentan a «growth», «unemployment» o «inflation».
func feed(core_id: String, skip: Array = []) -> float:
	ensure()
	var f: Dictionary = feeds().get(core_id, {})
	var tot := 0.0
	for k in f.keys():
		if skip.has(str(k)):
			continue
		tot += float(f[k]) * z(str(k))
	return tot

## Puntos de satisfacción que aporta un indicador a un grupo.
func group_term(group_id: String, ind_id: String) -> float:
	var likes: Dictionary = Policies.entry(Policies.groups(), group_id).get("likes", {})
	return float(likes.get(ind_id, 0.0)) * z(ind_id)

# ---------------------------------------------------------------- grafo (para el panel de burbujas)
## Vínculos causales entre variables: [{from, to, w}] (w en unidades del destino por desviación del origen).
func edges() -> Array:
	var out: Array = []
	for it in indicators():
		var d: Dictionary = it
		var links: Dictionary = d.get("links", {})
		for k in links.keys():
			out.append({"from": str(k), "to": str(d["id"]), "w": float(links[k]) / maxf(0.0001, float(d["scale"]))})
	return out

## Variables que mueve una medida: [{id, w, kind}] con w por paso de la medida (indicadores y variables centrales «fx», grupos «hits»).
func measure_links(measure_id: String) -> Array:
	var meas := Policies.measure(measure_id)
	var out: Array = []
	var fx: Dictionary = meas.get("fx", {})
	for k in fx.keys():
		var sc := float(def(str(k)).get("scale", 1.0)) if has(str(k)) else (QUALITY_SCALE if not CORE_SCALE.has(str(k)) else float(CORE_SCALE[str(k)]))
		out.append({"id": str(k), "w": float(fx[k]) / maxf(0.0001, sc), "kind": "ind" if has(str(k)) else "core"})
	var hits: Dictionary = meas.get("hits", {})
	for k2 in hits.keys():
		out.append({"id": str(k2), "w": float(hits[k2]) / 3.0, "kind": "group"})
	return out
