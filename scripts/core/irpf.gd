class_name Irpf
extends RefCounted
## IRPF por tramos. Una escala es una lista de {from: miles de € desde los que se aplica, rate: tipo marginal en %}.
## Se calcula con una distribución simplificada de contribuyentes; todos los efectos se miden respecto a la escala de partida.

const MAX_BRACKETS := 10
const MAX_RATE := 60.0
const SPECIAL_ID := "irpf_scale"

## Escala de partida (estatal + autonómica, aproximada a la vigente).
const DEFAULT := [
	{"from": 0.0, "rate": 19.0}, {"from": 12.45, "rate": 24.0}, {"from": 20.2, "rate": 30.0},
	{"from": 35.2, "rate": 37.0}, {"from": 60.0, "rate": 45.0}, {"from": 300.0, "rate": 47.0},
]

## Contribuyentes tipo: [renta anual en miles de €, peso].
const DIST := [[4.0, 0.10], [9.0, 0.13], [14.0, 0.14], [19.0, 0.13], [25.0, 0.14], [32.0, 0.11], [40.0, 0.08],
	[52.0, 0.06], [75.0, 0.045], [110.0, 0.018], [180.0, 0.007], [400.0, 0.002]]

## Renta típica de cada colectivo (miles de €).
const GROUP_INCOME := {"jovenes": 16.0, "trabajadores": 26.0, "clase_media": 40.0, "autonomos": 32.0, "empresarios": 160.0,
	"funcionarios": 34.0, "pensionistas": 19.0, "parados": 5.0, "rurales": 21.0, "vulnerables": 8.0}

static func default_scale() -> Array:
	return DEFAULT.duplicate(true)

## Ordena, fuerza que el primer tramo empiece en 0, limita tipos y elimina tramos duplicados.
static func sanitize(brackets: Array) -> Array:
	var tmp: Array = []
	for b in brackets:
		var d: Dictionary = b
		tmp.append({"from": clampf(float(d.get("from", 0.0)), 0.0, 1000.0), "rate": clampf(float(d.get("rate", 0.0)), 0.0, MAX_RATE)})
	if tmp.is_empty():
		return default_scale()
	tmp.sort_custom(func(a, b) -> bool: return float(a["from"]) < float(b["from"]))
	var out: Array = []
	for d2 in tmp:
		if not out.is_empty() and is_equal_approx(float((out[out.size() - 1] as Dictionary)["from"]), float(d2["from"])):
			out[out.size() - 1] = d2
		else:
			out.append(d2)
	(out[0] as Dictionary)["from"] = 0.0
	while out.size() > MAX_BRACKETS:
		out.pop_back()
	return out

static func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if absf(float((a[i] as Dictionary)["from"]) - float((b[i] as Dictionary)["from"])) > 0.001 or absf(float((a[i] as Dictionary)["rate"]) - float((b[i] as Dictionary)["rate"])) > 0.001:
			return false
	return true

## Cuota (miles de €) para una renta (miles de €).
static func tax(brackets: Array, income: float) -> float:
	var total := 0.0
	for i in range(brackets.size()):
		var lo := float((brackets[i] as Dictionary)["from"])
		var hi := float((brackets[i + 1] as Dictionary)["from"]) if i + 1 < brackets.size() else INF
		if income <= lo:
			break
		total += (minf(income, hi) - lo) * float((brackets[i] as Dictionary)["rate"]) / 100.0
	return total

static func rate_at(brackets: Array, income: float) -> float:
	return tax(brackets, income) / maxf(0.1, income) * 100.0

static func _total(brackets: Array) -> float:
	var t := 0.0
	for p in DIST:
		t += float(p[1]) * tax(brackets, float(p[0]))
	return t

static func average_rate(brackets: Array) -> float:
	var base := 0.0
	for p in DIST:
		base += float(p[1]) * float(p[0])
	return _total(brackets) / maxf(0.001, base) * 100.0

## Distancia entre dos escalas (cuota media ponderada, miles de €): 0 si son iguales.
static func distance(a: Array, b: Array) -> float:
	var d := 0.0
	for p in DIST:
		d += float(p[1]) * absf(tax(a, float(p[0])) - tax(b, float(p[0])))
	return d

static func top_rate(brackets: Array) -> float:
	return float((brackets[brackets.size() - 1] as Dictionary)["rate"])

## Efectos de pasar de la escala `from_b` a `to_b`: {rev: bn € a escala de partida, hits: {grupo: puntos}, fx: {indicador: delta}}.
static func delta_effects(from_b: Array, to_b: Array, irpf_base_rev: float) -> Dictionary:
	var t0 := _total(from_b)
	var t1 := _total(to_b)
	var ratio := t1 / maxf(0.001, t0)
	var rev := (ratio - 1.0) * irpf_base_rev * (0.9 if ratio > 1.0 else 1.0)
	var hits: Dictionary = {}
	for g in GROUP_INCOME.keys():
		var inc := float(GROUP_INCOME[g])
		hits[g] = -(rate_at(to_b, inc) - rate_at(from_b, inc)) * 0.55
	var d_avg := average_rate(to_b) - average_rate(from_b)
	var prog := (rate_at(to_b, 160.0) - rate_at(to_b, 16.0)) - (rate_at(from_b, 160.0) - rate_at(from_b, 16.0))
	var fx := {
		"growth": -0.045 * d_avg - 0.01 * (maxf(0.0, top_rate(to_b) - 50.0) - maxf(0.0, top_rate(from_b) - 50.0)),
		"unemployment": 0.01 * d_avg,
		"equality": 0.05 * prog,
	}
	return {"rev": rev, "hits": hits, "fx": fx}

## Texto corto de una escala.
static func describe(brackets: Array) -> String:
	var parts: Array = []
	for b in brackets:
		parts.append("%s%% desde %s k€" % [("%.1f" % float((b as Dictionary)["rate"])).rstrip("0").rstrip("."), ("%.2f" % float((b as Dictionary)["from"])).rstrip("0").rstrip(".")])
	return " · ".join(parts)
