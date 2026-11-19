class_name HistoryGen
extends RefCounted
## Historial previo a la partida: reconstruye los cinco años anteriores (economía, 36 indicadores, servicios públicos, satisfacción
## de los grupos, cuentas públicas, presupuestos y encuestas semanales) para que los gráficos tengan datos desde el primer día.
## Modos: «realistic» (trayectoria aproximada de España 2018-2023: covid, inflación de 2022, subida de tipos…), «random»
## (ciclo propio inventado con recesiones y crisis aleatorias) y «none» (sin historial). Todas las series terminan exactamente
## en el estado inicial de la partida, de modo que el presente es continuo con el pasado.

const MONTHS := 60
const WEEKS := 260
const MODES := ["realistic", "random", "none"]
const MODE_NAMES := {"realistic": "Realista (España 2018-2023)", "random": "Aleatorio", "none": "Sin historial"}
const MODE_DESC := {
	"realistic": "Cinco años de datos que siguen la historia reciente de España: pandemia, inflación de 2022, subida de tipos y el reparto de fuerzas de la legislatura anterior.",
	"random": "Un pasado inventado: ciclos, recesiones y crisis aleatorias que terminan en el mismo punto de partida. Distinto en cada partida.",
	"none": "Empiezas sin pasado: las gráficas se irán llenando mes a mes durante la legislatura.",
}

## Trayectorias aproximadas de España [año, mes, valor] (trimestrales o mensuales; se interpolan).
const REAL := {
	"growth": [[2018, 6, 2.7], [2018, 12, 2.2], [2019, 6, 2.1], [2019, 12, 1.7], [2020, 3, -4.0], [2020, 6, -17.0], [2020, 9, -8.6], [2020, 12, -9.0], [2021, 3, -4.3], [2021, 6, 17.0], [2021, 9, 4.0], [2021, 12, 5.5], [2022, 3, 6.7], [2022, 6, 7.0], [2022, 9, 4.8], [2022, 12, 3.0], [2023, 3, 3.9], [2023, 6, 2.2]],
	"unemployment": [[2018, 6, 15.3], [2018, 12, 14.4], [2019, 6, 14.0], [2019, 12, 13.8], [2020, 3, 14.4], [2020, 6, 15.3], [2020, 9, 16.3], [2020, 12, 16.1], [2021, 3, 16.0], [2021, 6, 14.6], [2021, 9, 14.6], [2021, 12, 13.3], [2022, 3, 13.7], [2022, 6, 12.5], [2022, 9, 12.7], [2022, 12, 12.9], [2023, 3, 13.3], [2023, 6, 11.6]],
	"inflation": [[2018, 6, 2.3], [2018, 12, 1.2], [2019, 6, 0.6], [2019, 12, 0.8], [2020, 3, 0.1], [2020, 6, -0.3], [2020, 9, -0.4], [2020, 12, -0.5], [2021, 3, 1.3], [2021, 6, 2.7], [2021, 9, 4.0], [2021, 12, 6.5], [2022, 3, 9.8], [2022, 7, 10.8], [2022, 9, 8.9], [2022, 12, 5.7], [2023, 3, 3.3], [2023, 6, 1.9]],
	"rate": [[2018, 6, 2.9], [2019, 6, 2.7], [2020, 6, 2.4], [2021, 12, 2.0], [2022, 6, 1.9], [2022, 12, 2.1], [2023, 6, 2.5]],
	"deficit": [[2018, 6, 2.6], [2019, 6, 3.0], [2019, 12, 3.1], [2020, 6, 7.0], [2020, 12, 10.1], [2021, 12, 6.7], [2022, 12, 4.7], [2023, 6, 3.8]],
	"debt": [[2018, 6, 98.5], [2019, 12, 98.2], [2020, 6, 114.0], [2020, 12, 120.0], [2021, 12, 118.3], [2022, 12, 111.6], [2023, 6, 108.0]],
}
## Encuestas de intención de voto [año, mes, %] (promedio de sondeos). Los partidos sin serie siguen un paseo aleatorio.
const REAL_POLLS := {
	"psoe": [[2018, 6, 26.0], [2018, 12, 24.5], [2019, 6, 28.5], [2019, 12, 27.0], [2020, 6, 28.0], [2020, 12, 27.0], [2021, 6, 26.0], [2021, 12, 26.0], [2022, 6, 24.5], [2022, 12, 26.5], [2023, 6, 27.0]],
	"pp": [[2018, 6, 20.0], [2018, 12, 21.0], [2019, 6, 20.5], [2019, 12, 21.0], [2020, 12, 20.0], [2021, 6, 21.0], [2021, 12, 20.0], [2022, 3, 22.0], [2022, 6, 29.0], [2022, 12, 33.0], [2023, 6, 32.5]],
	"vox": [[2018, 6, 1.5], [2018, 12, 7.0], [2019, 6, 13.0], [2019, 12, 15.0], [2020, 6, 15.5], [2021, 6, 17.0], [2021, 12, 18.0], [2022, 6, 14.0], [2022, 12, 12.0], [2023, 6, 13.3]],
	"sumar": [[2018, 6, 5.0], [2019, 6, 6.0], [2019, 12, 6.5], [2020, 12, 7.0], [2021, 12, 8.0], [2022, 6, 9.5], [2022, 12, 10.0], [2023, 6, 8.0]],
	"podemos": [[2018, 6, 17.0], [2019, 6, 14.0], [2019, 12, 12.5], [2020, 12, 10.0], [2021, 12, 8.0], [2022, 12, 5.5], [2023, 6, 3.5]],
	"erc": [[2018, 6, 3.5], [2019, 12, 3.8], [2021, 6, 3.5], [2022, 6, 2.7], [2023, 6, 2.8]],
	"junts": [[2018, 6, 1.6], [2019, 12, 1.6], [2021, 6, 1.7], [2023, 6, 1.5]],
	"pnv": [[2018, 6, 1.5], [2019, 12, 1.6], [2021, 6, 1.4], [2023, 6, 1.3]],
}
## Hitos con fecha (aparecen como marcas verticales en las gráficas).
const REAL_EVENTS := [
	[2018, 6, "Moción de censura"], [2019, 11, "Elecciones generales"], [2020, 1, "Gobierno de coalición"], [2020, 3, "Covid-19: estado de alarma"],
	[2021, 5, "Vacunación masiva"], [2022, 2, "Invasión de Ucrania"], [2022, 7, "Sube el BCE los tipos"], [2023, 5, "Elecciones autonómicas"],
]
## Perfiles temporales (0-1) de dos grandes perturbaciones del periodo realista.
const COVID_PROFILE := [[2020, 2, 0.0], [2020, 3, 0.5], [2020, 5, 1.0], [2020, 8, 0.8], [2020, 12, 0.7], [2021, 3, 0.6], [2021, 6, 0.3], [2021, 12, 0.1], [2022, 6, 0.0]]
const ENERGY_PROFILE := [[2021, 5, 0.0], [2021, 12, 0.6], [2022, 3, 1.0], [2022, 8, 1.0], [2022, 12, 0.6], [2023, 3, 0.2], [2023, 6, 0.0]]
## Desviaciones (en desviaciones típicas del indicador) en el pico de cada perturbación.
const COVID_SHOCK := {"tourism": -6.0, "consumption": -2.5, "exports": -2.0, "investment": -2.0, "youth_unemp": 1.8, "informal": 0.5, "poverty": 0.8, "gini": 0.6,
	"life_exp": -1.6, "waiting": 1.5, "crime": -1.2, "net_migration": -1.5, "birth": -0.5, "emissions": -1.0, "energy_price": -0.7, "transit_share": -2.0,
	"digital": 0.5, "polarization": 0.5, "entrepreneurship": -1.0, "trust": -0.4}
const ENERGY_SHOCK := {"energy_price": 2.2, "wages": -1.2, "poverty": 0.4, "renewables": 0.4, "consumption": -0.6, "trust": -0.3, "rent_burden": 0.5, "farm_income": -0.6}
const RANDOM_EVENT_NAMES := {
	"recession": ["Crisis financiera", "Recesión", "Crisis del crédito", "Parón industrial"],
	"energy": ["Shock energético", "Escalada de precios", "Crisis de suministros"],
	"boom": ["Boom del turismo", "Auge de la inversión", "Burbuja del crédito"],
	"political": ["Crisis política", "Elecciones generales", "Moción de censura"],
}

var m: GameModel
var mode := "realistic"
var rng := RandomNumberGenerator.new()
var _t: Array = []  # marca de tiempo (unix) de cada mes: 0 = hace MONTHS meses … MONTHS = el día de inicio
var _core: Dictionary = {}  # id -> Array de MONTHS+1 valores
var _wv: Array = []  # Array de Dictionary {indicador: valor} (MONTHS+1)
var _quality: Array = []
var _sat: Array = []
var _fiscal: Array = []
var _events: Array = []  # [{t, label}]
var _rand_events: Array = []  # sucesos del modo aleatorio: {kind, c, w, amp, label}

func _init(model: GameModel, mode_id: String = "realistic") -> void:
	m = model
	mode = mode_id if MODES.has(mode_id) else "realistic"
	rng.randomize()

# ---------------------------------------------------------------- API
## Pasos con etiqueta para mostrar una pantalla de carga con progreso: [{label, fn}].
func steps() -> Array:
	return [
		{"label": "Reconstruyendo el calendario de los últimos cinco años", "fn": Callable(self, "_calendar")},
		{"label": "Calculando la evolución del PIB, el paro y los precios", "fn": Callable(self, "_core_series")},
		{"label": "Simulando los 36 indicadores del país", "fn": Callable(self, "_world")},
		{"label": "Midiendo servicios públicos y satisfacción de cada grupo", "fn": Callable(self, "_quality_sat")},
		{"label": "Cuadrando ingresos, gastos y presupuestos por ministerio", "fn": Callable(self, "_fiscal_series")},
		{"label": "Recomponiendo las encuestas semanales", "fn": Callable(self, "_polls")},
		{"label": "Archivando el historial", "fn": Callable(self, "_commit")},
	]

func generate() -> void:
	if mode == "none":
		m.s["history_mode"] = "none"
		return
	for st in steps():
		(st["fn"] as Callable).call()

func is_done(model: GameModel) -> bool:
	return str(model.s.get("history_mode", "")) != ""

# ---------------------------------------------------------------- utilidades
static func months_back_of(year: int, month: int, start_year: int, start_month: int) -> int:
	return (start_year * 12 + start_month) - (year * 12 + month)

## Interpola linealmente las marcas [año, mes, valor] sobre los índices 0..MONTHS (MONTHS = hoy).
func _from_anchors(anchors: Array) -> Array:
	var sd := Time.get_datetime_dict_from_unix_time(m.campaign_start_unix())
	var pts: Array = []
	for a in anchors:
		var ar: Array = a
		var idx := MONTHS - months_back_of(int(ar[0]), int(ar[1]), int(sd["year"]), int(sd["month"]))
		pts.append([idx, float(ar[2])])
	pts.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	var out: Array = []
	for i in range(MONTHS + 1):
		if i <= int(pts[0][0]):
			out.append(float(pts[0][1]))
			continue
		if i >= int(pts[pts.size() - 1][0]):
			out.append(float(pts[pts.size() - 1][1]))
			continue
		var v := float(pts[0][1])
		for j in range(pts.size() - 1):
			var a0: Array = pts[j]
			var a1: Array = pts[j + 1]
			if i >= int(a0[0]) and i <= int(a1[0]):
				var f := float(i - int(a0[0])) / maxf(1.0, float(int(a1[0]) - int(a0[0])))
				v = lerpf(float(a0[1]), float(a1[1]), f)
				break
		out.append(v)
	return out

func _ar(n: int, sigma: float, phi: float) -> Array:
	var out: Array = []
	var x := 0.0
	for i in range(n):
		x = x * phi + rng.randfn(0.0, sigma)
		out.append(x)
	return out

## Suma a la serie la diferencia entre su último valor y el real, repartida con suavidad en los últimos `span` meses.
func _blend_end(vals: Array, target_end: float, span: int) -> void:
	var diff := target_end - float(vals[vals.size() - 1])
	for i in range(vals.size()):
		var f := clampf(float(i - (vals.size() - 1 - span)) / float(span), 0.0, 1.0)
		var w := f * f * (3.0 - 2.0 * f)
		vals[i] = float(vals[i]) + diff * w

func _bump(i: int, c: int, w: float) -> float:
	var x := float(i - c) / maxf(1.0, w)
	return exp(-x * x)

func _event_t(idx: int) -> int:
	return int(_t[clampi(idx, 0, MONTHS)])

# ---------------------------------------------------------------- 1. calendario
func _calendar() -> void:
	_t.clear()
	_events.clear()
	var sd := Time.get_datetime_dict_from_unix_time(m.campaign_start_unix())
	for i in range(MONTHS + 1):
		var back := MONTHS - i
		var total := int(sd["year"]) * 12 + (int(sd["month"]) - 1) - back
		var yy := int(total / 12)
		var mm := total % 12 + 1
		_t.append(int(Time.get_unix_time_from_datetime_dict({"year": yy, "month": mm, "day": clampi(int(sd["day"]), 1, 28), "hour": 12, "minute": 0, "second": 0})))
	_t[MONTHS] = m.campaign_start_unix()

# ---------------------------------------------------------------- 2. series centrales
func _core_series() -> void:
	var e := m.eco.st()
	var now_g := float(e["growth"])
	var now_u := float(e["unemployment"])
	var now_i := float(e["inflation"])
	var now_r := float(e.get("rate", WorldSim.CORE_START["rate"]))
	var now_d := -m.eco.balance_pct()
	var now_debt := m.eco.debt_pct()
	if mode == "realistic":
		_core["growth"] = _from_anchors(REAL["growth"])
		_core["unemployment"] = _from_anchors(REAL["unemployment"])
		_core["inflation"] = _from_anchors(REAL["inflation"])
		_core["rate"] = _from_anchors(REAL["rate"])
		_core["deficit"] = _from_anchors(REAL["deficit"])
		_core["debt"] = _from_anchors(REAL["debt"])
		var sd := Time.get_datetime_dict_from_unix_time(m.campaign_start_unix())
		for ev in REAL_EVENTS:
			var evl: Array = ev
			var idx := MONTHS - months_back_of(int(evl[0]), int(evl[1]), int(sd["year"]), int(sd["month"]))
			if idx >= 0 and idx < MONTHS:
				_events.append({"t": _event_t(idx), "label": str(evl[2])})
		var n_g: Array = _ar(MONTHS + 1, 0.12, 0.6)
		var n_u: Array = _ar(MONTHS + 1, 0.10, 0.7)
		var n_i: Array = _ar(MONTHS + 1, 0.12, 0.6)
		for i in range(MONTHS + 1):
			(_core["growth"] as Array)[i] = float((_core["growth"] as Array)[i]) + float(n_g[i])
			(_core["unemployment"] as Array)[i] = float((_core["unemployment"] as Array)[i]) + float(n_u[i])
			(_core["inflation"] as Array)[i] = float((_core["inflation"] as Array)[i]) + float(n_i[i])
	else:
		_random_core(now_g, now_u, now_i, now_r, now_d, now_debt)
	_blend_end(_core["growth"], now_g, 14)
	_blend_end(_core["unemployment"], now_u, 14)
	_blend_end(_core["inflation"], now_i, 14)
	_blend_end(_core["rate"], now_r, 10)
	_blend_end(_core["deficit"], now_d, 10)
	_blend_end(_core["debt"], now_debt, 10)
	for i in range(MONTHS + 1):
		(_core["unemployment"] as Array)[i] = clampf(float((_core["unemployment"] as Array)[i]), 3.0, 35.0)
		(_core["rate"] as Array)[i] = clampf(float((_core["rate"] as Array)[i]), 0.1, 9.0)
		(_core["debt"] as Array)[i] = clampf(float((_core["debt"] as Array)[i]), 30.0, 220.0)
	# Nivel del PIB (bn €) encadenando el crecimiento interanual hacia atrás.
	var gdp: Array = []
	gdp.resize(MONTHS + 1)
	var g0 := m.eco.gdp()
	for j in range(13):
		gdp[MONTHS - j] = g0 / pow(1.0 + now_g / 100.0, float(j) / 12.0)
	for i in range(MONTHS - 13, -1, -1):
		var gy := clampf(float((_core["growth"] as Array)[i + 12]), -30.0, 30.0)
		gdp[i] = float(gdp[i + 12]) / (1.0 + gy / 100.0)
	_core["gdp"] = gdp

func _random_core(now_g: float, now_u: float, now_i: float, now_r: float, now_d: float, now_debt: float) -> void:
	_rand_events.clear()
	var n_ev := rng.randi_range(2, 4)
	var kinds := ["recession", "energy", "boom", "political"]
	var used: Array = []
	for k in range(n_ev):
		var kind := str(kinds[rng.randi() % kinds.size()]) if k > 0 else ("recession" if rng.randf() < 0.7 else "energy")
		var c := rng.randi_range(8, MONTHS - 10)
		var near := true
		# Reintenta la colocación: antes un hito cercano a otro se descartaba y podían quedar < 2.
		for _try in range(30):
			near = false
			for uc in used:
				if absi(int(uc) - c) < 9:
					near = true
			if not near:
				break
			c = rng.randi_range(8, MONTHS - 10)
		if near:
			continue
		used.append(c)
		var names: Array = RANDOM_EVENT_NAMES[kind]
		_rand_events.append({"kind": kind, "c": c, "w": rng.randf_range(3.5, 7.0), "amp": rng.randf_range(0.6, 1.4), "label": str(names[rng.randi() % names.size()])})
		_events.append({"t": _event_t(c), "label": str((_rand_events[_rand_events.size() - 1] as Dictionary)["label"])})
	var g: Array = []
	var u: Array = []
	var inf: Array = []
	var r: Array = []
	var d: Array = []
	var ng: Array = _ar(MONTHS + 1, 0.30, 0.75)
	var nu: Array = _ar(MONTHS + 1, 0.12, 0.85)
	var ni: Array = _ar(MONTHS + 1, 0.22, 0.8)
	var nr: Array = _ar(MONTHS + 1, 0.05, 0.9)
	var nd: Array = _ar(MONTHS + 1, 0.12, 0.85)
	for i in range(MONTHS + 1):
		var dg := 0.0
		var du := 0.0
		var di := 0.0
		var dr := 0.0
		var dd := 0.0
		for ev in _rand_events:
			var evd: Dictionary = ev
			var c2 := int(evd["c"])
			var w2 := float(evd["w"])
			var amp := float(evd["amp"])
			match str(evd["kind"]):
				"recession":
					dg -= 5.5 * amp * _bump(i, c2, w2)
					du += 3.0 * amp * _bump(i, c2 + 5, w2 * 1.6)
					di -= 0.8 * amp * _bump(i, c2 + 3, w2)
					dd += 3.0 * amp * _bump(i, c2 + 2, w2 * 1.3)
					dr -= 0.5 * amp * _bump(i, c2 + 2, w2)
				"energy":
					di += 4.0 * amp * _bump(i, c2, w2)
					dg -= 1.6 * amp * _bump(i, c2 + 2, w2)
					dr += 1.0 * amp * _bump(i, c2 + 4, w2 * 1.4)
					du += 0.8 * amp * _bump(i, c2 + 5, w2 * 1.5)
				"boom":
					dg += 2.0 * amp * _bump(i, c2, w2 * 1.3)
					du -= 1.4 * amp * _bump(i, c2 + 3, w2 * 1.5)
					di += 0.7 * amp * _bump(i, c2 + 3, w2)
					dd -= 1.0 * amp * _bump(i, c2 + 2, w2 * 1.3)
				"political":
					dg -= 0.4 * amp * _bump(i, c2, w2)
		g.append(now_g + dg + float(ng[i]))
		u.append(now_u + du + float(nu[i]))
		inf.append(now_i + di + float(ni[i]))
		r.append(now_r + dr + float(nr[i]))
		d.append(now_d + dd + float(nd[i]))
	_core["growth"] = g
	_core["unemployment"] = u
	_core["inflation"] = inf
	_core["rate"] = r
	_core["deficit"] = d
	# Deuda: se reconstruye hacia atrás desde hoy con los déficits y el crecimiento nominal.
	var debt: Array = []
	debt.resize(MONTHS + 1)
	debt[MONTHS] = now_debt
	for i in range(MONTHS, 0, -1):
		var nominal := (float(g[i]) + float(inf[i])) / 1200.0
		debt[i - 1] = clampf((float(debt[i]) - float(d[i]) / 12.0) / maxf(0.5, 1.0 - nominal), 25.0, 220.0)
	_core["debt"] = debt

# ---------------------------------------------------------------- 3. indicadores del país
func _core_z(id: String, i: int) -> float:
	var arr: Variant = _core.get(id, null)
	if arr == null:
		return 0.0
	var v := float((arr as Array)[i])
	var z := 0.0
	match id:
		"growth": z = (v - float(WorldSim.CORE_START["growth"])) / float(WorldSim.CORE_SCALE["growth"])
		"unemployment": z = (v - float(WorldSim.CORE_START["unemployment"])) / float(WorldSim.CORE_SCALE["unemployment"])
		"inflation": z = (v - float(WorldSim.CORE_START["inflation"])) / float(WorldSim.CORE_SCALE["inflation"])
		"rate": z = (v - float(WorldSim.CORE_START["rate"])) / float(WorldSim.CORE_SCALE["rate"])
		"deficit": z = (v - float(WorldSim.CORE_START["deficit"])) / float(WorldSim.CORE_SCALE["deficit"])
	return clampf(z, -3.0, 3.0)

func _world() -> void:
	m.world.ensure()
	var inds := WorldSim.indicators()
	var x: Dictionary = {}
	for it in inds:
		var d: Dictionary = it
		x[str(d["id"])] = float(d["start"]) + rng.randfn(0.0, 0.35) * float(d["scale"])
	var noise: Dictionary = {}
	for it in inds:
		noise[str((it as Dictionary)["id"])] = 0.0
	_wv.clear()
	var covid: Array = _from_anchors(COVID_PROFILE) if mode == "realistic" else []
	var energy: Array = _from_anchors(ENERGY_PROFILE) if mode == "realistic" else []
	for i in range(MONTHS + 1):
		var nxt: Dictionary = {}
		for it in inds:
			var d: Dictionary = it
			var id := str(d["id"])
			var tgt := float(d["start"])
			var links: Dictionary = d.get("links", {})
			for k in links.keys():
				var ks := str(k)
				var zz := 0.0
				if _core.has(ks) or ks in ["growth", "unemployment", "inflation", "rate", "deficit"]:
					zz = _core_z(ks, i)
				elif x.has(ks):
					var dd: Dictionary = WorldSim.def(ks)
					zz = clampf((float(x[ks]) - float(dd["start"])) / maxf(0.0001, float(dd["scale"])), -3.0, 3.0)
				tgt += float(links[k]) * zz
			var sc := float(d["scale"])
			noise[id] = float(noise[id]) * 0.7 + rng.randfn(0.0, 0.035 * sc)
			var cur := float(x[id])
			nxt[id] = clampf(cur + (tgt - cur) * float(d["rate"]) * 1.4 + float(noise[id]) * 0.4, float(d["min"]), float(d["max"]))
		for k2 in nxt.keys():
			x[k2] = nxt[k2]
		var snap: Dictionary = {}
		for it in inds:
			var d2: Dictionary = it
			var id2 := str(d2["id"])
			var v := float(x[id2])
			if mode == "realistic":
				var sc2 := float(d2["scale"])
				v += float(covid[i]) * float(COVID_SHOCK.get(id2, 0.0)) * sc2 + float(energy[i]) * float(ENERGY_SHOCK.get(id2, 0.0)) * sc2
			snap[id2] = v
		_wv.append(snap)
	# El último valor ha de coincidir con el inicio real: se corrige con suavidad.
	for it in inds:
		var d3: Dictionary = it
		var id3 := str(d3["id"])
		var vals: Array = []
		for i in range(MONTHS + 1):
			vals.append(float((_wv[i] as Dictionary)[id3]))
		_blend_end(vals, float(d3["start"]), 30)
		for i in range(MONTHS + 1):
			(_wv[i] as Dictionary)[id3] = clampf(float(vals[i]), float(d3["min"]), float(d3["max"]))

# ---------------------------------------------------------------- 4. servicios y grupos
func _quality_sat() -> void:
	_quality.clear()
	_sat.clear()
	var qnow: Dictionary = m.eco.st()["quality"]
	var snow: Dictionary = m.eco.st()["sat"]
	var qnoise: Dictionary = {}
	for q in Policies.quality():
		qnoise[str((q as Dictionary)["id"])] = _ar(MONTHS + 1, 0.5, 0.9)
	var snoise: Dictionary = {}
	for g in Policies.groups():
		snoise[str((g as Dictionary)["id"])] = _ar(MONTHS + 1, 1.0, 0.85)
	var covid: Array = _from_anchors(COVID_PROFILE) if mode == "realistic" else []
	var qvals: Dictionary = {}
	for q in Policies.quality():
		var id := str((q as Dictionary)["id"])
		var vals: Array = []
		for i in range(MONTHS + 1):
			var v := float(qnow.get(id, 50.0)) + float((qnoise[id] as Array)[i]) * 2.0
			if mode == "realistic":
				var cs := float(covid[i])
				if id == "health":
					v -= 7.0 * cs
				elif id == "education":
					v -= 3.5 * cs
				elif id == "equality":
					v -= 2.0 * cs
			vals.append(v)
		_blend_end(vals, float(qnow.get(id, 50.0)), 36)
		qvals[id] = vals
	for i in range(MONTHS + 1):
		var qs: Dictionary = {}
		for k in qvals.keys():
			qs[k] = clampf(float((qvals[k] as Array)[i]), 5.0, 95.0)
		_quality.append(qs)
	var svals: Dictionary = {}
	for g in Policies.groups():
		var gd: Dictionary = g
		var id2 := str(gd["id"])
		var wu := 2.0 if id2 in ["parados", "jovenes", "vulnerables"] else 1.0
		var wi := 1.6 if id2 in ["pensionistas", "clase_media", "trabajadores"] else 1.0
		var wg := 1.5 if id2 in ["empresarios", "autonomos"] else 0.7
		var vals2: Array = []
		for i in range(MONTHS + 1):
			var du := float((_core["unemployment"] as Array)[i]) - float((_core["unemployment"] as Array)[MONTHS])
			var di := float((_core["inflation"] as Array)[i]) - float((_core["inflation"] as Array)[MONTHS])
			var dg := clampf(float((_core["growth"] as Array)[i]) - float((_core["growth"] as Array)[MONTHS]), -8.0, 8.0)
			vals2.append(float(snow.get(id2, 50.0)) - du * 1.1 * wu - di * 0.9 * wi + dg * 0.45 * wg + float((snoise[id2] as Array)[i]))
		_blend_end(vals2, float(snow.get(id2, 50.0)), 18)
		svals[id2] = vals2
	for i in range(MONTHS + 1):
		var ss: Dictionary = {}
		for k in svals.keys():
			ss[k] = clampf(float((svals[k] as Array)[i]), 3.0, 97.0)
		_sat.append(ss)

# ---------------------------------------------------------------- 5. cuentas públicas
func _fiscal_series() -> void:
	_fiscal.clear()
	var gdp_now := m.eco.gdp()
	var rev_now := m.eco.revenue_total()
	var sp_now := m.eco.spending_total()
	var secs_now: Dictionary = m.eco.st().get("sectors", {})
	var covid: Array = _from_anchors(COVID_PROFILE) if mode == "realistic" else []
	var rnoise: Array = _ar(MONTHS + 1, 0.004, 0.8)
	for i in range(MONTHS + 1):
		var gdp_i := float((_core["gdp"] as Array)[i])
		var rev := rev_now * gdp_i / gdp_now * (1.0 + float(rnoise[i]))
		var spend := rev + float((_core["deficit"] as Array)[i]) / 100.0 * gdp_i
		var scale := spend / maxf(1.0, sp_now)
		var budget: Dictionary = {}
		for b in Policies.budget():
			var bd: Dictionary = b
			var bid := str(bd["id"])
			var extra := 1.0
			if mode == "realistic" and i < MONTHS:
				var cs := float(covid[i])
				if bid == "sanidad":
					extra += 0.22 * cs
				elif bid == "prestaciones":
					extra += 0.45 * cs
				elif bid == "pensiones":
					extra -= 0.015 * (1.0 - float(i) / MONTHS)
			budget[bid] = float(bd["base"]) * scale * extra
		var sectors: Dictionary = {}
		var tot := 0.0
		for sc in Policies.sectors():
			var sd: Dictionary = sc
			var sid := str(sd["id"])
			var v := float(secs_now.get(sid, sd["base"]))
			if mode == "realistic":
				var cs2 := float(covid[i])
				if sid == "servicios":
					v -= 3.0 * cs2
				elif sid == "construccion":
					v -= 0.4 * cs2
				else:
					v += 0.6 * cs2
			sectors[sid] = v
			tot += v
		for k in sectors.keys():
			sectors[k] = float(sectors[k]) / tot * 100.0
		_fiscal.append({"revenue": rev, "spending": spend, "budget": budget, "sectors": sectors})

# ---------------------------------------------------------------- 6. encuestas
func _polls() -> void:
	var cur: Dictionary = {}
	var base := m.polls()
	for id in base.keys():
		cur[str(id)] = float(base[id])
	var ids: Array = cur.keys()
	var series: Dictionary = {}
	var weeks_t: Array = []
	var now := m.clock_unix()
	var sd := Time.get_datetime_dict_from_unix_time(m.campaign_start_unix())
	for w in range(WEEKS + 1):
		weeks_t.append(now - (WEEKS - w) * 7 * 86400)
	for id in ids:
		var ids_s := str(id)
		var vals: Array = []
		if mode == "realistic" and REAL_POLLS.has(ids_s) and ids_s != Rules.OTHERS_ID:
			var pts: Array = []
			for a in (REAL_POLLS[ids_s] as Array):
				var ar: Array = a
				pts.append([ar[0], ar[1], ar[2]])
			var monthly: Array = _from_anchors(pts)
			for w2 in range(WEEKS + 1):
				var mi := clampf(float(MONTHS) - float(WEEKS - w2) / 4.345, 0.0, float(MONTHS))
				var i0 := int(floor(mi))
				var i1 := mini(MONTHS, i0 + 1)
				vals.append(lerpf(float(monthly[i0]), float(monthly[i1]), mi - float(i0)))
		else:
			# Paseo aleatorio con reversión: la serie termina en el valor actual.
			var level := float(cur[ids_s])
			var raw: Array = []
			var x := 0.0
			for w3 in range(WEEKS + 1):
				x = x * 0.97 + rng.randfn(0.0, 0.10 * sqrt(maxf(level, 0.4)))
				raw.append(level + x)
			vals = raw
		var noise: Array = _ar(WEEKS + 1, 0.12 * sqrt(maxf(float(cur[ids_s]), 0.5)) * 0.6, 0.5)
		for w4 in range(WEEKS + 1):
			vals[w4] = float(vals[w4]) + float(noise[w4])
		_blend_end(vals, float(cur[ids_s]), 26)
		series[ids_s] = vals
	var hist: Array = []
	for w5 in range(WEEKS):
		var snap: Dictionary = {}
		var tot := 0.0
		for id3 in ids:
			var idk := str(id3)
			if idk == Rules.OTHERS_ID:
				continue
			var v := maxf(0.05, float((series[idk] as Array)[w5]))
			snap[idk] = v
			tot += v
		# «Otros» absorbe lo que no suman los partidos con serie.
		var others := 100.0 - tot
		if others < 1.0:
			var f := 99.0 / maxf(1.0, tot)
			for k in snap.keys():
				snap[k] = float(snap[k]) * f
			others = 1.0
		snap[Rules.OTHERS_ID] = others
		for k2 in snap.keys():
			snap[k2] = snappedf(float(snap[k2]), 0.01)
		var tt := int(weeks_t[w5])
		hist.append({"day": m.day - (WEEKS - w5) * 7, "label": Rules.month_label(tt), "polls": snap, "t": tt, "pre": true})
	m.s["_hist_polls"] = hist

# ---------------------------------------------------------------- 7. volcado al estado
func _commit() -> void:
	var eh: Array = []
	for i in range(MONTHS):
		var fs: Dictionary = _fiscal[i]
		var q: Dictionary = _quality[i]
		var sat: Dictionary = _sat[i]
		var tot := 0.0
		var wt := 0.0
		for g in Policies.groups():
			tot += float(sat.get(str((g as Dictionary)["id"]), 50.0)) * float((g as Dictionary)["share"])
			wt += float((g as Dictionary)["share"])
		eh.append({"label": Rules.month_label(int(_t[i])), "t": int(_t[i]), "pre": true,
			"gdp": float((_core["gdp"] as Array)[i]), "growth": float((_core["growth"] as Array)[i]), "unemployment": float((_core["unemployment"] as Array)[i]),
			"inflation": float((_core["inflation"] as Array)[i]), "rate": float((_core["rate"] as Array)[i]), "debt_pct": float((_core["debt"] as Array)[i]),
			"deficit_pct": float((_core["deficit"] as Array)[i]), "revenue": float(fs["revenue"]), "spending": float(fs["spending"]),
			"budget": fs["budget"], "sectors": fs["sectors"], "quality": q, "sat": sat, "avg_sat": tot / maxf(1.0, wt)})
	var cur_eco: Array = m.eco.st()["history"]
	for e in cur_eco:
		(e as Dictionary)["t"] = m.campaign_start_unix()
		(e as Dictionary)["label"] = Rules.month_label(m.campaign_start_unix())
		if not (e as Dictionary).has("rate"):
			(e as Dictionary)["rate"] = float(m.eco.st().get("rate", 2.5))
	m.eco.st()["history"] = eh + cur_eco
	var wh: Array = []
	for i in range(MONTHS):
		wh.append({"label": Rules.month_label(int(_t[i])), "t": int(_t[i]), "pre": true, "v": _wv[i]})
	m.world.ensure()
	var cur_w: Array = m.world.st()["hist"]
	for e2 in cur_w:
		(e2 as Dictionary)["t"] = m.campaign_start_unix()
		(e2 as Dictionary)["label"] = Rules.month_label(m.campaign_start_unix())
	m.world.st()["hist"] = wh + cur_w
	# Encuestas: sustituye la semilla corta por cinco años semanales.
	var ph: Array = m.a("poll_history_multi")
	var recent: Array = []
	for snap in ph:
		if int((snap as Dictionary).get("t", 0)) >= m.campaign_start_unix() - 86400:
			recent.append(snap)
	var pre: Array = m.s.get("_hist_polls", [])
	m.s.erase("_hist_polls")
	m.s["poll_history_multi"] = pre + recent
	m.s["hist_events"] = _events
	m.s["history_mode"] = mode

# ---------------------------------------------------------------- consulta (pantallas)
## Hitos dentro de una ventana de tiempos [t_min, t_max]: [{t, label}].
static func events_between(model: GameModel, t_min: int, t_max: int) -> Array:
	var out: Array = []
	for e in model.a("hist_events"):
		var t := int((e as Dictionary).get("t", 0))
		if t >= t_min and t <= t_max:
			out.append(e)
	return out

## Para una lista de entradas de historial (con «t»), devuelve [{i, text}] con el índice más cercano de cada hito.
static func markers_for(model: GameModel, entries: Array) -> Array:
	var out: Array = []
	if entries.size() < 2:
		return out
	var t0 := int((entries[0] as Dictionary).get("t", 0))
	var t1 := int((entries[entries.size() - 1] as Dictionary).get("t", 0))
	for e in model.a("hist_events"):
		var t := int((e as Dictionary).get("t", 0))
		if t < t0 or t > t1:
			continue
		var best := 0
		var bd := 1 << 60
		for i in range(entries.size()):
			var dt := absi(int((entries[i] as Dictionary).get("t", 0)) - t)
			if dt < bd:
				bd = dt
				best = i
		out.append({"i": best, "text": str((e as Dictionary).get("label", ""))})
	return out
