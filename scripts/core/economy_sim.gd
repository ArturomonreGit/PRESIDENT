class_name EconomySim
extends RefCounted
## Motor económico y social (inspirado en Democracy 4). Las medidas aprobadas fijan «mandos» que alteran ingresos,
## gasto por ministerio, crecimiento, paro, inflación, servicios públicos y la satisfacción de los grupos sociales.
## Todo converge con inercia hacia los objetivos que dictan las políticas, de modo que las leyes tardan en notarse.

var m: GameModel

const GDP_ELASTICITY_REV := 1.0
const GDP_ELASTICITY_SPEND := 0.97
const BASE_DEFICIT_PCT := 3.6

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- estado
func st() -> Dictionary:
	return m.d("eco")

func ready_state() -> bool:
	return st().has("gdp")

func ensure() -> void:
	if ready_state():
		return
	var start := Policies.start()
	var e := st()
	e["gdp0"] = float(start["gdp"])
	e["gdp"] = float(start["gdp"])
	e["debt"] = float(start["debt"])
	e["growth"] = float(start["growth"])
	e["unemployment"] = float(start["unemployment"])
	e["inflation"] = float(start["inflation"])
	e["cycle"] = 0.0
	e["policy"] = {}
	e["lag"] = {"growth": 0.0, "unemployment": 0.0, "inflation": 0.0}
	var q: Dictionary = {}
	for it in Policies.quality():
		q[str((it as Dictionary)["id"])] = float((it as Dictionary)["base"])
	e["quality"] = q
	var sat: Dictionary = {}
	for g in Policies.groups():
		sat[str((g as Dictionary)["id"])] = float((g as Dictionary)["base"])
	e["sat"] = sat
	e["sector_shift"] = {}
	e["history"] = []
	e["laws"] = []
	e["months"] = 0
	_compute_fiscal()
	_compute_composition()
	_snapshot("Inicio")
	if m.macro != null:
		m.macro.ensure()

func gdp() -> float:
	return float(st().get("gdp", 1462.0))

## Escala vigente del IRPF.
func irpf_brackets() -> Array:
	var cur: Variant = st().get("irpf", null)
	if typeof(cur) == TYPE_ARRAY and not (cur as Array).is_empty():
		return cur
	return Irpf.default_scale()

func irpf_base_revenue() -> float:
	return float(Policies.entry(Policies.taxes(), "irpf").get("base", 135.0))

func value(measure_id: String) -> float:
	if measure_id == Irpf.SPECIAL_ID:
		return Irpf.average_rate(irpf_brackets())
	var pol: Dictionary = st().get("policy", {})
	if pol.has(measure_id):
		return float(pol[measure_id])
	return float(Policies.measure(measure_id).get("base", 0.0))

func set_value(measure_id: String, v: float) -> void:
	var meas := Policies.measure(measure_id)
	if meas.is_empty() or Policies.is_special(measure_id):
		return
	(st()["policy"] as Dictionary)[measure_id] = Policies.snap(meas, v)

# ---------------------------------------------------------------- efectos agregados de las políticas
## Suma de efectos de todas las medidas respecto a su valor base. `overrides` = {id: valor} para simular cambios.
func policy_effects(overrides: Dictionary = {}, irpf: Array = []) -> Dictionary:
	var out := {"fx": {}, "cost": {}, "rev": {}, "hits": {}, "sec": {}}
	# IRPF por tramos: efecto respecto a la escala de partida.
	var scale: Array = irpf if not irpf.is_empty() else irpf_brackets()
	var ie := Irpf.delta_effects(Irpf.default_scale(), scale, irpf_base_revenue())
	(out["rev"] as Dictionary)["irpf"] = float(ie["rev"])
	for k in (ie["hits"] as Dictionary).keys():
		(out["hits"] as Dictionary)[k] = float(ie["hits"][k])
	for k2 in (ie["fx"] as Dictionary).keys():
		(out["fx"] as Dictionary)[k2] = float(ie["fx"][k2])
	for it in Policies.measures():
		var meas: Dictionary = it
		var id := str(meas["id"])
		var v := float(overrides[id]) if overrides.has(id) else value(id)
		var steps := (v - float(meas["base"])) / float(meas["step"])
		if is_zero_approx(steps):
			continue
		for key in ["fx", "cost", "rev", "hits", "sec"]:
			var src: Dictionary = meas.get(key, {})
			var dst: Dictionary = out[key]
			for k in src.keys():
				dst[k] = float(dst.get(k, 0.0)) + float(src[k]) * steps
	return out

func _eff_get(eff: Dictionary, key: String, id: String) -> float:
	return float((eff[key] as Dictionary).get(id, 0.0))

# ---------------------------------------------------------------- fiscal
func _scale() -> float:
	return gdp() / float(st().get("gdp0", 1462.0))

## Calcula ingresos, gastos, intereses y déficit (bn €/año) con las políticas actuales.
func _compute_fiscal(eff: Dictionary = {}) -> Dictionary:
	if eff.is_empty():
		eff = policy_effects()
	var e := st()
	var sc := _scale()
	var cyc := 1.0 + (float(e.get("growth", 1.9)) - 1.9) * 0.012
	var revenue: Dictionary = {}
	var rev_total := 0.0
	for t in Policies.taxes():
		var td: Dictionary = t
		var tid := str(td["id"])
		var v := maxf(0.0, float(td["base"]) * pow(sc, GDP_ELASTICITY_REV) * cyc + _eff_get(eff, "rev", tid) * sc)
		revenue[tid] = v
		rev_total += v
	var spending: Dictionary = {}
	var sp_total := 0.0
	for b in Policies.budget():
		var bd: Dictionary = b
		var bid := str(bd["id"])
		var v2 := maxf(0.0, float(bd["base"]) * pow(sc, GDP_ELASTICITY_SPEND) + _eff_get(eff, "cost", bid) * sc)
		v2 *= budget_factor(bid)
		# El paro eleva el gasto en prestaciones.
		if bid == "prestaciones":
			v2 *= 1.0 + (float(e.get("unemployment", 12.0)) - 12.0) * 0.035
		spending[bid] = v2
		sp_total += v2
	var dpc := float(e.get("debt", 1570.0)) / maxf(1.0, gdp()) * 100.0
	var rate := 2.2 + maxf(0.0, dpc - 100.0) * 0.02 + maxf(0.0, float(e.get("inflation", 3.0)) - 2.0) * 0.1
	if m.macro != null and m.macro.ready_state():
		rate = m.macro.v("eff_cost")
	var interest := float(e.get("debt", 1570.0)) * rate / 100.0
	var res := {"revenue": revenue, "revenue_total": rev_total, "spending": spending, "spending_total": sp_total,
		"interest": interest, "rate": rate, "balance": rev_total - sp_total - interest}
	e["revenue"] = revenue
	e["spending"] = spending
	e["interest"] = interest
	e["rate"] = rate
	e["revenue_total"] = rev_total
	e["spending_total"] = sp_total + interest
	e["balance"] = rev_total - sp_total - interest
	return res

## Dotación aprobada en los Presupuestos para una partida (1,0 = sin cambios).
func budget_factor(line_id: String) -> float:
	if m.exec == null:
		return 1.0
	return m.exec.factor(line_id)

func revenue_total() -> float:
	return float(st().get("revenue_total", 0.0))

func spending_total() -> float:
	return float(st().get("spending_total", 0.0))

## Saldo público en bn € (positivo = superávit).
func balance() -> float:
	return float(st().get("balance", 0.0))

func balance_pct() -> float:
	return balance() / maxf(1.0, gdp()) * 100.0

func debt() -> float:
	return float(st().get("debt", 0.0))

func debt_pct() -> float:
	return debt() / maxf(1.0, gdp()) * 100.0

func quality(id: String) -> float:
	return float((st().get("quality", {}) as Dictionary).get(id, 50.0))

func satisfaction(group_id: String) -> float:
	return float((st().get("sat", {}) as Dictionary).get(group_id, 50.0))

func avg_satisfaction() -> float:
	var tot := 0.0
	var w := 0.0
	for g in Policies.groups():
		var gd: Dictionary = g
		tot += satisfaction(str(gd["id"])) * float(gd["share"])
		w += float(gd["share"])
	return tot / maxf(w, 1.0)

# ---------------------------------------------------------------- composición del PIB
func _compute_composition() -> void:
	var e := st()
	var shift: Dictionary = e.get("sector_shift", {})
	var sectors: Dictionary = {}
	var rest := 100.0
	for s in Policies.sectors():
		var sd: Dictionary = s
		var sid := str(sd["id"])
		if sid == "servicios":
			continue
		var v := maxf(0.5, float(sd["base"]) + float(shift.get(sid, 0.0)))
		if sid == "publico":
			var noint := float(e.get("spending_total", 573.0)) - float(e.get("interest", 39.0))
			v = clampf(float(sd["base"]) * (noint / maxf(1.0, gdp())) / base_spend_ratio(), 5.0, 12.0)
		sectors[sid] = v
		rest -= v
	sectors["servicios"] = rest
	e["sectors"] = sectors
	var base_ratio := base_spend_ratio()
	var ratio := (float(e.get("spending_total", 573.0)) - float(e.get("interest", 39.0))) / maxf(1.0, gdp())
	var dem: Dictionary = {}
	var publico := clampf(19.0 * ratio / base_ratio, 14.0, 28.0)
	var inversion := clampf(20.5 + (float(e.get("growth", 1.9)) - 1.9) * 0.5 + (quality("innovation") - 45.0) * 0.03, 15.0, 26.0)
	var consumo := clampf(55.0 + (avg_satisfaction() - 47.0) * 0.04, 48.0, 62.0)
	dem["publico"] = publico
	dem["inversion"] = inversion
	dem["consumo"] = consumo
	dem["exterior"] = 100.0 - publico - inversion - consumo
	e["demand"] = dem

# ---------------------------------------------------------------- tick trimestral
## Fracción de convergencia de un ritmo mensual `r` acumulada durante un turno (trimestre).
static func q_rate(r: float) -> float:
	return 1.0 - pow(1.0 - r, float(Rules.TURN_MONTHS))

func tick() -> void:
	ensure()
	var e := st()
	var eff := policy_effects()
	var mb: Dictionary = m.ministers.bonuses() if m.ministers != null else {}
	# Sectores
	var shift: Dictionary = e["sector_shift"]
	for k in (eff["sec"] as Dictionary).keys():
		shift[k] = float(shift.get(k, 0.0)) + (float((eff["sec"] as Dictionary)[k]) * 1.0 - float(shift.get(k, 0.0))) * q_rate(0.08)
	# Calidad de servicios
	var qd: Dictionary = e["quality"]
	for it in Policies.quality():
		var qdef: Dictionary = it
		var qid := str(qdef["id"])
		var target2 := float(qdef["base"]) + _eff_get(eff, "fx", qid) + float(mb.get(qid, 0.0))
		var dom := str(qdef.get("domain", ""))
		if dom != "":
			target2 += (budget_factor(dom) - 1.0) * 35.0
		if qid == "equality":
			target2 -= (float(e["unemployment"]) - 12.0) * 0.6
		if qid == "environment":
			target2 -= (float(e["growth"]) - 1.9) * 0.8
		if qid == "housing":
			target2 += (float(e["growth"]) - 1.9) * 0.4
		qd[qid] = clampf(float(qd[qid]) + (target2 - float(qd[qid])) * q_rate(0.10), 0.0, 100.0)
	# Macroeconomía: el motor trimestral calcula crecimiento, paro, inflación, tipos, prima de riesgo e indicadores propios.
	var deficit_pct := -balance_pct()
	var r := m.macro.tick()
	e["growth"] = float(r["growth"])
	e["unemployment"] = float(r["unemployment"])
	e["inflation"] = float(r["inflation"])
	e["cycle"] = m.macro.v("gap")
	# PIB nominal y deuda
	e["gdp"] = gdp() * (1.0 + (float(e["growth"]) + float(e["inflation"])) / 400.0)
	var fiscal := _compute_fiscal(eff)
	e["debt"] = debt() - float(fiscal["balance"]) / 4.0
	_compute_composition()
	m.world.tick(eff, r.get("owned", {}))
	_update_groups(eff)
	e["months"] = int(e["months"]) + Rules.TURN_MONTHS
	var idx := clampf(50.0 + (float(e["growth"]) - 1.9) * 8.0 - (float(e["unemployment"]) - 12.0) * 2.2 - (float(e["inflation"]) - 3.0) * 3.0 - maxf(0.0, deficit_pct - 5.0) * 1.5, 5.0, 95.0)
	m.s["economy"] = idx
	_snapshot("T%d" % m.turn())

func _update_groups(eff: Dictionary) -> void:
	var e := st()
	var sat: Dictionary = e["sat"]
	var deficit_pct := -balance_pct()
	for g in Policies.groups():
		var gd: Dictionary = g
		var gid := str(gd["id"])
		var target := float(gd["base"]) + _eff_get(eff, "hits", gid)
		var likes: Dictionary = gd.get("likes", {})
		for k in likes.keys():
			var dev := 0.0
			match str(k):
				"growth": dev = float(e["growth"]) - 1.9
				"unemployment": dev = float(e["unemployment"]) - 12.0
				"inflation": dev = float(e["inflation"]) - 3.0
				"deficit": dev = deficit_pct - BASE_DEFICIT_PCT
				_:
					if WorldSim.has(str(k)):
						dev = m.world.z(str(k))
					else:
						var qdef := Policies.entry(Policies.quality(), str(k))
						dev = quality(str(k)) - float(qdef.get("base", 50.0))
			target += float(likes[k]) * dev
		sat[gid] = clampf(float(sat[gid]) + (clampf(target, 0.0, 100.0) - float(sat[gid])) * q_rate(0.12), 0.0, 100.0)

func _snapshot(label: String) -> void:
	var e := st()
	var q: Dictionary = (e["quality"] as Dictionary).duplicate()
	var sat: Dictionary = (e["sat"] as Dictionary).duplicate()
	var hist: Array = e["history"]
	var bud: Dictionary = {}
	for b in Policies.budget():
		bud[str((b as Dictionary)["id"])] = budget_spending(str((b as Dictionary)["id"]))
	hist.append({"label": Rules.quarter_label(m.clock_unix()), "t": m.clock_unix(), "rate": float(e.get("rate", 2.5)), "budget": bud, "sectors": (e.get("sectors", {}) as Dictionary).duplicate(), "taxes": (e.get("revenue", {}) as Dictionary).duplicate(), "gdp": gdp(), "growth": float(e["growth"]), "unemployment": float(e["unemployment"]), "inflation": float(e["inflation"]),
		"debt_pct": debt_pct(), "deficit_pct": -balance_pct(), "revenue": revenue_total(), "spending": spending_total(), "quality": q, "sat": sat,
		"avg_sat": avg_satisfaction()})
	while hist.size() > 360:
		hist.pop_front()

func history() -> Array:
	return st().get("history", [])

# ---------------------------------------------------------------- leyes
## Efectos previstos de una ley (en régimen, no inmediatos): deltas respecto al estado actual.
func preview(changes: Dictionary, irpf: Array = []) -> Dictionary:
	ensure()
	var cur := policy_effects()
	var over: Dictionary = {}
	for k in changes.keys():
		over[str(k)] = float(changes[k])
	var nxt := policy_effects(over, irpf)
	var sc := _scale()
	var rev_delta := 0.0
	for t in Policies.taxes():
		var tid := str((t as Dictionary)["id"])
		rev_delta += (_eff_get(nxt, "rev", tid) - _eff_get(cur, "rev", tid)) * sc
	var cost_delta := 0.0
	var by_area: Dictionary = {}
	for b in Policies.budget():
		var bid := str((b as Dictionary)["id"])
		var d := (_eff_get(nxt, "cost", bid) - _eff_get(cur, "cost", bid)) * sc
		if absf(d) > 0.001:
			by_area[bid] = d
		cost_delta += d
	var fx: Dictionary = {}
	for k in ["growth", "unemployment", "inflation"] + Policies.quality().map(func(x): return str((x as Dictionary)["id"])):
		var d2 := _eff_get(nxt, "fx", str(k)) - _eff_get(cur, "fx", str(k))
		if absf(d2) > 0.001:
			fx[str(k)] = d2
	var groups: Dictionary = {}
	for g in Policies.groups():
		var gid := str((g as Dictionary)["id"])
		var d3 := _eff_get(nxt, "hits", gid) - _eff_get(cur, "hits", gid)
		if absf(d3) > 0.05:
			groups[gid] = d3
	return {"revenue": rev_delta, "spending": cost_delta, "balance": rev_delta - cost_delta, "by_area": by_area, "fx": fx, "groups": groups}

func apply_law(law: Dictionary) -> void:
	ensure()
	var changes: Dictionary = law.get("changes", {})
	for k in changes.keys():
		set_value(str(k), float(changes[k]))
	if changes.has(Irpf.SPECIAL_ID) and typeof(law.get("irpf", null)) == TYPE_ARRAY:
		st()["irpf"] = Irpf.sanitize(law["irpf"])
	var log: Array = st()["laws"]
	log.append({"title": str(law.get("title", "")), "proposer": str(law.get("proposer", "")), "month": m.gov_month, "t": m.clock_unix(), "cycle": m.cycle,
		"changes": changes.duplicate(), "area": str(law.get("area", ""))})
	if m.macro != null:
		m.macro.note_law(str(law.get("title", "")), changes)
	_compute_fiscal()
	_compute_composition()

func passed_laws() -> Array:
	return st().get("laws", [])

# ---------------------------------------------------------------- explicaciones para la interfaz
## Qué mueve la satisfacción de un grupo: [{label, value}] ordenado de más positivo a más negativo.
func group_drivers(group_id: String) -> Array:
	var out: Array = []
	for it in Policies.measures():
		var meas: Dictionary = it
		var hits: Dictionary = meas.get("hits", {})
		if not hits.has(group_id):
			continue
		var steps := (value(str(meas["id"])) - float(meas["base"])) / float(meas["step"])
		if absf(steps) < 0.01:
			continue
		out.append({"label": "%s: %s" % [str(meas["name"]), Policies.value_text(meas, value(str(meas["id"])))], "value": float(hits[group_id]) * steps})
	var gd := Policies.entry(Policies.groups(), group_id)
	var e := st()
	var deficit_pct := -balance_pct()
	var likes: Dictionary = gd.get("likes", {})
	for k in likes.keys():
		var dev := 0.0
		var label := ""
		match str(k):
			"growth": dev = float(e["growth"]) - 1.9; label = "Crecimiento %.1f %%" % float(e["growth"])
			"unemployment": dev = float(e["unemployment"]) - 12.0; label = "Paro %.1f %%" % float(e["unemployment"])
			"inflation": dev = float(e["inflation"]) - 3.0; label = "Inflación %.1f %%" % float(e["inflation"])
			"deficit": dev = deficit_pct - BASE_DEFICIT_PCT; label = "Déficit %.1f %% del PIB" % deficit_pct
			_:
				if WorldSim.has(str(k)):
					dev = m.world.z(str(k))
					label = "%s: %s" % [WorldSim.name_of(str(k)), WorldSim.fmt(str(k), m.world.value(str(k)))]
				else:
					var qd := Policies.entry(Policies.quality(), str(k))
					dev = quality(str(k)) - float(qd.get("base", 50.0))
					label = "%s %.0f/100" % [str(qd.get("name", k)), quality(str(k))]
		var v := float(likes[k]) * dev
		if absf(v) >= 0.4:
			out.append({"label": label, "value": v})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	return out

func quality_delta(id: String, months_back: int = 12) -> float:
	var hist := history()
	if hist.size() < 2:
		return 0.0
	var past: Dictionary = hist[maxi(0, hist.size() - 1 - months_back)]
	return quality(id) - float((past["quality"] as Dictionary).get(id, quality(id)))

func sat_delta(id: String, months_back: int = 6) -> float:
	var hist := history()
	if hist.size() < 2:
		return 0.0
	var past: Dictionary = hist[maxi(0, hist.size() - 1 - months_back)]
	return satisfaction(id) - float((past["sat"] as Dictionary).get(id, satisfaction(id)))

func budget_spending(id: String) -> float:
	return float((st().get("spending", {}) as Dictionary).get(id, 0.0))

func tax_revenue(id: String) -> float:
	return float((st().get("revenue", {}) as Dictionary).get(id, 0.0))


## Gasto no financiero de partida / PIB de partida (referencia de calibración).
static func base_spend_ratio() -> float:
	var total := 0.0
	for b in Policies.budget():
		total += float((b as Dictionary)["base"])
	return total / maxf(1.0, float(Policies.start().get("gdp", 1462.0)))
