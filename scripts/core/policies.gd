class_name Policies
extends RefCounted
## Catálogo de medidas de política pública (modelo tipo Democracy 4). Datos en data/scenarios/spain/policies.json
## (generado con tools/gen_policies.py).

const PATH := "res://data/scenarios/spain/policies.json"
static var _index: Dictionary = {}

static func data() -> Dictionary:
	var d: Variant = DataStore.read_json(PATH)
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func measures() -> Array:
	return data().get("measures", [])

## Medida especial «IRPF por tramos»: su valor escalar es el tipo medio efectivo; la escala completa va aparte.
static func irpf_measure() -> Dictionary:
	return {"id": Irpf.SPECIAL_ID, "area": "tax", "special": "irpf", "name": "IRPF por tramos",
		"desc": "Escala del impuesto sobre la renta: añade o quita tramos y fija el tipo marginal de cada uno.",
		"base": Irpf.average_rate(Irpf.DEFAULT), "min": 0.0, "max": 60.0, "step": 0.1, "unit": "%", "labels": [],
		"fx": {}, "cost": {}, "rev": {}, "hits": {}, "sec": {},
		"lean": {"economic": -0.6, "social": 0.0, "territorial": 0.0}, "likes": {"igualdad": 0.3, "liberalismo_economico": -0.7}}

static func is_special(id: String) -> bool:
	return id == Irpf.SPECIAL_ID

static func measure(id: String) -> Dictionary:
	if id == Irpf.SPECIAL_ID:
		return irpf_measure()
	if _index.is_empty():
		for it in measures():
			_index[str((it as Dictionary)["id"])] = it
	return _index.get(id, {})

static func areas() -> Array:
	return data().get("areas", [])

static func area(id: String) -> Dictionary:
	for a in areas():
		if str((a as Dictionary)["id"]) == id:
			return a
	return {}

## Medidas de un área. `with_special` añade el IRPF por tramos (sólo para las pantallas que saben editarlo).
static func measures_of(area_id: String, with_special: bool = false) -> Array:
	var out: Array = []
	if with_special and area_id == "tax":
		out.append(irpf_measure())
	for it in measures():
		if str((it as Dictionary)["area"]) == area_id:
			out.append(it)
	return out

static func budget() -> Array:
	return data().get("budget", [])

static func taxes() -> Array:
	return data().get("taxes", [])

static func groups() -> Array:
	return data().get("groups", [])

static func quality() -> Array:
	return data().get("quality", [])

static func sectors() -> Array:
	return data().get("sectors", [])

static func demand() -> Array:
	return data().get("demand", [])

static func start() -> Dictionary:
	return data().get("start", {})

static func entry(list: Array, id: String) -> Dictionary:
	for it in list:
		if str((it as Dictionary)["id"]) == id:
			return it
	return {}

static func group_name(id: String) -> String:
	return str(entry(groups(), id).get("name", id))

static func quality_name(id: String) -> String:
	if id == "growth": return "Crecimiento"
	if id == "unemployment": return "Paro"
	if id == "inflation": return "Inflación"
	return str(entry(quality(), id).get("name", id))

## Texto legible de un valor de la medida («Tope general», «21 %», «1.134 €/mes»).
static func value_text(meas: Dictionary, v: float) -> String:
	if str(meas.get("special", "")) == "irpf":
		return "tipo medio %.1f %%" % v
	var labels: Array = meas.get("labels", [])
	if not labels.is_empty():
		return str(labels[clampi(int(round(v)), 0, labels.size() - 1)])
	var unit := str(meas.get("unit", ""))
	var step := float(meas.get("step", 1.0))
	var num := ("%d" % int(round(v))) if step >= 1.0 and is_equal_approx(step, floorf(step)) else ("%.2f" % v).rstrip("0").rstrip(".")
	if absf(v) >= 1000.0:
		num = Rules.money(v)
	return "%s %s" % [num, unit] if unit != "" else num

static func snap(meas: Dictionary, v: float) -> float:
	var lo := float(meas["min"])
	var hi := float(meas["max"])
	var step := float(meas["step"])
	var base := float(meas["base"])
	var n := roundf((v - base) / step)
	return clampf(base + n * step, lo, hi)

## Ambición del cambio: fracción del recorrido del mando que se mueve (0-1).
static func ambition(meas: Dictionary, from_v: float, to_v: float) -> float:
	var span := maxf(0.0001, float(meas["max"]) - float(meas["min"]))
	return clampf(absf(to_v - from_v) / span, 0.0, 1.0)
