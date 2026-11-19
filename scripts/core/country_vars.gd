class_name CountryVars
extends RefCounted
## Fachada de datos de la pantalla País: un único catálogo jerárquico de variables (economía, mercados, sociedad, servicios,
## grupos sociales) que unifica las fuentes (EconomySim, MacroSim, WorldSim) y responde a lo mismo para todas:
## nombre, valor, serie histórica, variación, estado y, sobre todo, QUÉ LO HA MOVIDO (leyes, medidas, crisis, agentes).

var m: GameModel

const CORE := {
	"growth": {"name": "Crecimiento del PIB", "unit": "% anual", "dec": 1, "good": 1, "desc": "Variación real interanual de la producción del país. Es la suma de la demanda de los hogares, la inversión de las empresas, el gasto público y el sector exterior."},
	"unemployment": {"name": "Tasa de paro", "unit": "%", "dec": 1, "good": -1, "desc": "Parte de la población activa sin empleo. Sigue al ciclo económico con retraso y se enquista cuando las crisis duran (histéresis)."},
	"inflation": {"name": "Inflación (IPC)", "unit": "%", "dec": 1, "good": -1, "desc": "Subida interanual de los precios de consumo. Depende de las expectativas, la demanda, los costes laborales, la energía y el exterior."},
}
const FISCAL := {
	"deficit_pct": {"name": "Déficit público", "unit": "% PIB", "dec": 1, "good": -1, "desc": "Diferencia entre lo que gasta y lo que ingresa el Estado (incluidos los intereses). El déficit de cada año se suma a la deuda."},
	"debt_pct": {"name": "Deuda pública", "unit": "% PIB", "dec": 0, "good": -1, "desc": "Lo que debe el Estado en proporción a la riqueza anual del país. Cuanto mayor, más vulnerable ante una crisis y más cara se vuelve la financiación."},
	"revenue": {"name": "Ingresos públicos", "unit": "bn €", "dec": 0, "good": 0, "desc": "Recaudación total de impuestos y cotizaciones. Crece con la economía y con las subidas de impuestos."},
	"spending": {"name": "Gasto público", "unit": "bn €", "dec": 0, "good": 0, "desc": "Gasto total de las administraciones, con los intereses de la deuda."},
	"gdp": {"name": "PIB nominal", "unit": "bn €", "dec": 0, "good": 1, "desc": "Valor de todo lo que produce el país en un año a precios corrientes."},
}

## Árbol del panel lateral: secciones → grupos → variables.
const TREE := [
	{"id": "eco", "name": "Economía", "glyph": "€", "groups": [
		{"id": "act", "name": "Actividad", "vars": ["growth", "gap", "pot", "consumption", "c_g", "investment", "i_g", "g_g", "productivity", "prod_g"]},
		{"id": "emp", "name": "Empleo y rentas", "vars": ["unemployment", "youth_unemp", "wages", "wage_g", "rdi", "ulc_gap", "sav", "informal"]},
		{"id": "pre", "name": "Precios", "vars": ["inflation", "infl_e", "energy_price", "world_inf"]},
		{"id": "din", "name": "Dinero y bancos", "vars": ["rate", "spread", "eff_cost", "credit_g", "bank", "npl"]},
		{"id": "con", "name": "Confianza", "vars": ["conf_c", "conf_f"]},
		{"id": "viv", "name": "Vivienda", "vars": ["house_price", "hp_g", "bubble", "rent_burden", "housing_stock"]},
		{"id": "pub", "name": "Cuentas públicas", "vars": ["deficit_pct", "debt_pct", "revenue", "spending", "gdp"]},
		{"id": "ing", "name": "Ingresos por impuesto", "vars": []},
		{"id": "gas", "name": "Gasto por área", "vars": []},
		{"id": "est", "name": "Estructura productiva", "vars": []},
		{"id": "ext", "name": "Mundo y comercio", "vars": ["world_g", "oil", "risk", "exports", "x_g", "tourism", "tour_dem"]},
	]},
	{"id": "soc", "name": "Sociedad", "glyph": "☺", "groups": [
		{"id": "pov", "name": "Pobreza y desigualdad", "vars": ["poverty", "gini", "pensions_gap"]},
		{"id": "sal", "name": "Salud", "vars": ["life_exp", "waiting"]},
		{"id": "edu", "name": "Educación y ciencia", "vars": ["dropout", "skills", "digital", "r_d", "entrepreneurship"]},
		{"id": "seg", "name": "Seguridad y justicia", "vars": ["crime", "court_delay", "trust", "transparency"]},
		{"id": "dem", "name": "Población y familia", "vars": ["net_migration", "birth", "gender_gap"]},
		{"id": "ter", "name": "Territorio y política", "vars": ["polarization", "tension"]},
		{"id": "cli", "name": "Clima y energía", "vars": ["emissions", "renewables", "transit_share"]},
		{"id": "rur", "name": "Mundo rural", "vars": ["rural", "farm_income"]},
	]},
	{"id": "serv", "name": "Servicios y grupos", "glyph": "♥", "groups": [
		{"id": "q", "name": "Servicios públicos", "vars": ["q:health", "q:education", "q:housing", "q:security", "q:environment", "q:equality", "q:infrastructure", "q:innovation"]},
		{"id": "g", "name": "Satisfacción de los grupos", "vars": ["g:jovenes", "g:trabajadores", "g:clase_media", "g:autonomos", "g:empresarios", "g:funcionarios", "g:pensionistas", "g:parados", "g:rurales", "g:vulnerables"]},
	]},
]

## Variables que influyen en otra (para navegar por las causas de una a otra).
const REL := {
	"growth": ["consumption", "investment", "g_g", "exports", "gap", "pot", "conf_c", "conf_f", "rate", "world_g"],
	"unemployment": ["growth", "gap", "skills", "net_migration", "bank", "wages"],
	"inflation": ["infl_e", "gap", "wage_g", "ulc_gap", "oil", "world_inf", "rate", "energy_price"],
	"gap": ["growth", "pot"], "pot": ["productivity", "investment", "skills", "net_migration", "unemployment"],
	"consumption": ["rdi", "sav", "conf_c", "rate", "house_price", "credit_g"], "c_g": ["rdi", "sav", "conf_c", "rate", "hp_g", "credit_g"],
	"investment": ["growth", "rate", "conf_f", "ulc_gap", "credit_g", "bank"], "i_g": ["growth", "rate", "conf_f", "ulc_gap", "credit_g", "bank"],
	"g_g": ["revenue", "spending", "deficit_pct"], "productivity": ["prod_g", "r_d", "digital", "skills"], "prod_g": ["growth", "r_d", "digital", "skills"],
	"wages": ["wage_g", "inflation", "productivity"], "wage_g": ["infl_e", "inflation", "prod_g", "unemployment"],
	"rdi": ["unemployment", "wage_g", "inflation", "revenue"], "ulc_gap": ["wage_g", "prod_g"], "sav": ["unemployment", "inflation", "rate", "conf_c"],
	"infl_e": ["inflation"], "energy_price": ["oil", "renewables"], "world_inf": ["oil"],
	"rate": ["inflation", "world_g", "gap"], "spread": ["debt_pct", "deficit_pct", "risk", "bank", "growth"], "eff_cost": ["rate", "spread", "debt_pct"],
	"credit_g": ["growth", "rate", "bank", "hp_g"], "bank": ["npl", "spread", "bubble", "unemployment"], "npl": ["unemployment", "hp_g", "rate"],
	"conf_c": ["rdi", "unemployment", "inflation", "bank"], "conf_f": ["growth", "rate", "ulc_gap", "bank"],
	"house_price": ["hp_g", "rate", "credit_g", "net_migration", "housing_stock"], "hp_g": ["rdi", "credit_g", "rate", "net_migration", "bubble"], "bubble": ["hp_g", "growth"],
	"deficit_pct": ["revenue", "spending", "growth", "eff_cost"], "debt_pct": ["deficit_pct", "growth", "inflation"], "revenue": ["gdp", "growth"], "spending": ["gdp", "eff_cost", "unemployment"],
	"world_g": ["risk", "oil"], "oil": ["world_g", "energy_price"], "risk": ["world_g", "debt_pct"], "exports": ["world_g", "ulc_gap", "tourism"], "x_g": ["world_g", "ulc_gap", "tourism"],
	"tourism": ["tour_dem", "inflation", "crime"], "tour_dem": ["world_g"],
}

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- catálogo
static func is_quality(id: String) -> bool:
	return id.begins_with("q:")

static func is_group(id: String) -> bool:
	return id.begins_with("g:")

static func kind_of(id: String) -> String:
	if CORE.has(id):
		return "core"
	if FISCAL.has(id):
		return "fiscal"
	if MacroSim.has_var(id):
		return "macro"
	if is_quality(id):
		return "quality"
	if is_group(id):
		return "group"
	if id.begins_with("b:") and not Policies.entry(Policies.budget(), id.substr(2)).is_empty():
		return "budget"
	if id.begins_with("t:") and not Policies.entry(Policies.taxes(), id.substr(2)).is_empty():
		return "tax"
	if id.begins_with("s:") and not Policies.entry(Policies.sectors(), id.substr(2)).is_empty():
		return "sector"
	if WorldSim.has(id):
		return "world"
	return ""

static func exists(id: String) -> bool:
	return kind_of(id) != ""

## Variables que se generan a partir de los datos (impuestos, áreas de gasto, sectores).
static func _dyn_vars(gid: String) -> Array:
	var out: Array = []
	match gid:
		"ing":
			for t in Policies.taxes():
				out.append("t:" + str((t as Dictionary)["id"]))
		"gas":
			for b in Policies.budget():
				out.append("b:" + str((b as Dictionary)["id"]))
		"est":
			for sct in Policies.sectors():
				out.append("s:" + str((sct as Dictionary)["id"]))
	return out

## Árbol sin variables desconocidas (por si cambian los datos).
static func tree() -> Array:
	var out: Array = []
	for sec in TREE:
		var sd: Dictionary = sec
		var groups: Array = []
		for g in sd["groups"]:
			var gd: Dictionary = g
			var vars: Array = []
			var src: Array = gd["vars"] if not (gd["vars"] as Array).is_empty() else _dyn_vars(str(gd["id"]))
			for v in src:
				if exists(str(v)):
					vars.append(str(v))
			if not vars.is_empty():
				groups.append({"id": str(gd["id"]), "name": str(gd["name"]), "vars": vars})
		out.append({"id": str(sd["id"]), "name": str(sd["name"]), "glyph": str(sd["glyph"]), "groups": groups})
	return out

static func group_of(id: String) -> String:
	for sec in tree():
		for g in (sec as Dictionary)["groups"]:
			if (g as Dictionary)["vars"].has(id):
				return str((g as Dictionary)["id"])
	return ""

static func section_of(id: String) -> String:
	for sec in tree():
		for g in (sec as Dictionary)["groups"]:
			if (g as Dictionary)["vars"].has(id):
				return str((sec as Dictionary)["id"])
	return ""

static func info(id: String) -> Dictionary:
	match kind_of(id):
		"core": return CORE[id]
		"fiscal": return FISCAL[id]
		"macro": return MacroSim.VARS[id]
		"world":
			var d := WorldSim.def(id)
			return {"name": str(d["name"]), "unit": str(d["unit"]), "dec": int(d.get("dec", 1)), "good": int(d.get("good", 0)), "desc": str(d.get("desc", ""))}
		"quality":
			var qid := id.substr(2)
			return {"name": Policies.quality_name(qid), "unit": "/100", "dec": 0, "good": 1, "desc": "Calidad del servicio público: depende de su presupuesto, de las medidas aprobadas y de la marcha de la economía."}
		"group":
			var gd := Policies.entry(Policies.groups(), id.substr(2))
			return {"name": str(gd.get("name", id)), "unit": "/100", "dec": 0, "good": 1, "desc": "Satisfacción de este grupo con el Gobierno: sus medidas favoritas, el paro, los precios, los servicios y los indicadores que más le importan."}
		"budget":
			var bd := Policies.entry(Policies.budget(), id.substr(2))
			return {"name": str(bd.get("name", id)), "unit": "bn €", "dec": 1, "good": 0, "desc": "Gasto anual del Estado en esta partida: lo que fijan las medidas y los Presupuestos aprobados, más el efecto del tamaño de la economía (y el paro, en prestaciones)."}
		"tax":
			var td := Policies.entry(Policies.taxes(), id.substr(2))
			return {"name": str(td.get("name", id)), "unit": "bn €", "dec": 1, "good": 0, "desc": "Recaudación anual de este impuesto: sube con la economía y con los tipos que apruebes."}
		"sector":
			var sdd := Policies.entry(Policies.sectors(), id.substr(2))
			return {"name": str(sdd.get("name", id)), "unit": "% PIB", "dec": 1, "good": 0, "desc": "Peso de este sector en la economía. Las medidas de industria, turismo, energía o vivienda lo desplazan despacio."}
	return {"name": id, "unit": "", "dec": 1, "good": 0, "desc": ""}

static func name_of(id: String) -> String:
	return str(info(id).get("name", id))

static func fmt(id: String, v: float) -> String:
	var d := info(id)
	var num := ("%." + str(int(d.get("dec", 1))) + "f") % v
	var unit := str(d.get("unit", ""))
	if unit == "" or unit in ["índice", "puntos", "0-100"]:
		return num
	if unit in ["%", "% anual", "/100"]:
		return num + (" %" if unit.begins_with("%") else "")
	return "%s %s" % [num, unit]

## Valor con una cifra más corta (para las casillas pequeñas).
static func fmt_short(id: String, v: float) -> String:
	var d := info(id)
	var num := ("%." + str(int(d.get("dec", 1))) + "f") % v
	var unit := str(d.get("unit", ""))
	if unit.begins_with("%"):
		return num + " %"
	return num

static func good_of(id: String) -> int:
	return int(info(id).get("good", 0))

static func related(id: String) -> Array:
	if REL.has(id):
		return REL[id]
	var base := id.substr(2) if id.length() > 2 and id[1] == ":" else id
	match kind_of(id):
		"quality": return ["b:" + base, "growth", "unemployment", "deficit_pct"]
		"budget": return ["q:" + base, "spending", "deficit_pct", "growth"]
		"tax": return ["revenue", "growth", "consumption", "unemployment"]
		"group": return ["unemployment", "inflation", "wages", "house_price"]
		"sector": return ["growth", "consumption", "exports", "investment"]
	return []

# ---------------------------------------------------------------- valores y series
func value(id: String) -> float:
	match kind_of(id):
		"core": return float(m.eco.st().get(id, 0.0))
		"fiscal":
			match id:
				"deficit_pct": return -m.eco.balance_pct()
				"debt_pct": return m.eco.debt_pct()
				"revenue": return m.eco.revenue_total()
				"spending": return m.eco.spending_total()
				"gdp": return m.eco.gdp()
		"macro": return m.macro.v(id)
		"world": return m.world.value(id)
		"quality": return m.eco.quality(id.substr(2))
		"group": return m.eco.satisfaction(id.substr(2))
		"budget": return m.eco.budget_spending(id.substr(2))
		"tax": return m.eco.tax_revenue(id.substr(2))
		"sector": return float((m.eco.st().get("sectors", {}) as Dictionary).get(id.substr(2), 0.0))
	return 0.0

func fmt_now(id: String) -> String:
	return fmt(id, value(id))

## Serie histórica trimestral: [{t, label, v}] (de la más antigua a la actual). El pasado generado (mensual) se adelgaza a un punto por trimestre.
func entries(id: String) -> Array:
	var raw := _entries_raw(id)
	var out: Array = []
	var last_t := -(1 << 60)
	for i in range(raw.size()):
		var e: Dictionary = raw[i]
		if int(e["t"]) - last_t >= 80 * 86400 or out.is_empty():
			out.append(e)
			last_t = int(e["t"])
		elif i == raw.size() - 1:
			out[out.size() - 1] = e
	return out

func _entries_raw(id: String) -> Array:
	var out: Array = []
	match kind_of(id):
		"core":
			for h in m.eco.history():
				var hd: Dictionary = h
				out.append({"t": int(hd.get("t", 0)), "label": str(hd.get("label", "")), "v": float(hd.get(id, 0.0))})
		"fiscal":
			var key := id
			for h2 in m.eco.history():
				var hd2: Dictionary = h2
				var vv := float(hd2.get(key, 0.0))
				if id == "spending":
					vv = float(hd2.get("spending", 0.0))
				out.append({"t": int(hd2.get("t", 0)), "label": str(hd2.get("label", "")), "v": vv})
		"macro":
			for h3 in m.macro.history():
				var hd3: Dictionary = h3
				out.append({"t": int(hd3.get("t", 0)), "label": str(hd3.get("label", "")), "v": float((hd3["v"] as Dictionary).get(id, 0.0))})
		"world":
			for h4 in m.world.history():
				var hd4: Dictionary = h4
				out.append({"t": int(hd4.get("t", 0)), "label": str(hd4.get("label", "")), "v": float((hd4["v"] as Dictionary).get(id, m.world.start_of(id)))})
		"quality":
			var qid := id.substr(2)
			for h5 in m.eco.history():
				var hd5: Dictionary = h5
				out.append({"t": int(hd5.get("t", 0)), "label": str(hd5.get("label", "")), "v": float((hd5.get("quality", {}) as Dictionary).get(qid, 50.0))})
		"group":
			var gid := id.substr(2)
			for h6 in m.eco.history():
				var hd6: Dictionary = h6
				out.append({"t": int(hd6.get("t", 0)), "label": str(hd6.get("label", "")), "v": float((hd6.get("sat", {}) as Dictionary).get(gid, 50.0))})
		"budget", "tax", "sector":
			var src_key := {"budget": "budget", "tax": "taxes", "sector": "sectors"}[kind_of(id)] as String
			var key2 := id.substr(2)
			var first_v := value(id)
			for h7 in m.eco.history():
				var hd7: Dictionary = h7
				var dct: Dictionary = hd7.get(src_key, {})
				if not dct.has(key2):
					continue
				out.append({"t": int(hd7.get("t", 0)), "label": str(hd7.get("label", "")), "v": float(dct[key2])})
			first_v += 0.0
	return out

static func values_of(ents: Array, last_n: int = 0) -> Array:
	var out: Array = []
	var from := maxi(0, ents.size() - last_n) if last_n > 0 else 0
	for i in range(from, ents.size()):
		out.append(float((ents[i] as Dictionary)["v"]))
	return out

static func labels_of(ents: Array, last_n: int = 0) -> Array:
	var out: Array = []
	var from := maxi(0, ents.size() - last_n) if last_n > 0 else 0
	for i in range(from, ents.size()):
		out.append(str((ents[i] as Dictionary)["label"]))
	return out

## Variación respecto a hace `days` días (por defecto un trimestre).
func change(id: String, days: int = 85) -> float:
	var ents := entries(id)
	if ents.size() < 2:
		return 0.0
	var last: Dictionary = ents[ents.size() - 1]
	var tt := int(last["t"]) - days * 86400
	var past: Dictionary = ents[0]
	for i in range(ents.size() - 1, -1, -1):
		if int((ents[i] as Dictionary)["t"]) <= tt:
			past = ents[i]
			break
	return float(last["v"]) - float(past["v"])

## Umbral por debajo del cual una variación no se muestra.
static func eps(id: String) -> float:
	return 0.5 * pow(10.0, -float(int(info(id).get("dec", 1))))

## Color-estado: 1 bien, 0 neutro, −1 mal, 2 sin juicio de valor.
func status(id: String) -> int:
	var g := good_of(id)
	if g == 0:
		return 2
	var ents := entries(id)
	if ents.is_empty():
		return 0
	var first: float = float((ents[maxi(0, ents.size() - 9)] as Dictionary)["v"])
	var d := (value(id) - first) * float(g)
	var span := maxf(0.0001, _span(id))
	if d > 0.25 * span:
		return 1
	if d < -0.25 * span:
		return -1
	return 0

## Escala típica de movimiento de la variable.
static func _span(id: String) -> float:
	match kind_of(id):
		"core":
			return {"growth": 1.5, "unemployment": 1.0, "inflation": 1.0}[id]
		"fiscal": return {"deficit_pct": 1.0, "debt_pct": 5.0, "revenue": 30.0, "spending": 30.0, "gdp": 40.0}[id]
		"macro": return maxf(0.3, 5.0 * pow(10.0, -float(int(info(id).get("dec", 1)))) * 4.0)
		"world": return float(WorldSim.def(id).get("scale", 1.0)) * 0.5
		"quality", "group": return 4.0
		"budget", "tax": return 3.0
		"sector": return 0.5
	return 1.0

# ---------------------------------------------------------------- explicación: qué lo ha movido
## Unidad de las contribuciones que muestra `causes`.
func cause_unit(id: String) -> String:
	match kind_of(id):
		"core": return "pp"
		"world":
			var u := str(WorldSim.def(id).get("unit", ""))
			return "pts" if u == "índice" else u
		"macro": return str(MacroSim.VARS[id].get("unit", ""))
		"budget", "tax": return "bn €"
	return ""

## Quiénes han movido la variable ESTE TRIMESTRE: [{label, value, kind, ref, text}] (kind: policy|shock|agent|structural|law|link|budget).
func causes(id: String) -> Array:
	var out: Array = []
	match kind_of(id):
		"core":
			out = _clean(m.macro.why(id))
		"world":
			if MacroSim.OWNED.has(id):
				out = _clean(m.macro.why(id))
			else:
				out = _world_pressure(id)
		"fiscal":
			out = _fiscal_causes(id)
		"group":
			for it in m.eco.group_drivers(id.substr(2)):
				var gd: Dictionary = it
				out.append({"label": str(gd["label"]), "value": float(gd["value"]), "kind": "policy" if str(gd["label"]).find(":") >= 0 else "agent", "ref": "", "text": ""})
		"quality":
			out = _quality_causes(id.substr(2))
		"budget", "tax":
			out = _line_causes(id)
	var acc: Dictionary = {}
	if CORE.has(id) or MacroSim.OWNED.has(id):
		for p in m.macro.push(id):
			var pd: Dictionary = p
			acc[str(pd["kind"]) + "|" + str(pd["ref"]) + "|" + str(pd["label"])] = float(pd["value"])
	var unit := cause_unit(id)
	for c in out:
		var cd: Dictionary = c
		var parts: Array = []
		if str(cd.get("kind", "")) == "policy" and str(cd.get("ref", "")) != "":
			var ot := m.macro.origin_text(str(cd["ref"]))
			if ot != "" and str(cd.get("text", "")) == "":
				parts.append(ot)
		var ak := str(cd.get("kind", "")) + "|" + str(cd.get("ref", "")) + "|" + str(cd.get("label", ""))
		if acc.has(ak) and (str(cd.get("kind", "")) in ["policy", "shock"]):
			var av := float(acc[ak])
			parts.append("efecto acumulado %s %s" % [(("%+." + str(2 if absf(av) < 1.0 else 1) + "f") % av).replace("-", "−"), unit])
			if str(cd.get("kind", "")) == "shock" and av * float(cd["value"]) < 0.0:
				parts.append("va remitiendo")
		if not parts.is_empty():
			cd["text"] = " · ".join(parts)
	return out

func _clean(list: Array) -> Array:
	var out: Array = []
	for c in list:
		var cd: Dictionary = c
		if str(cd["kind"]) == "structural" and absf(float(cd["value"])) < 0.02:
			continue
		out.append({"label": str(cd["label"]), "value": float(cd["value"]), "kind": str(cd["kind"]), "ref": str(cd.get("ref", "")), "via": str(cd.get("via", "")), "text": ""})
	return out

## Presión actual sobre un indicador de la red: medidas (con su ley de origen), variables relacionadas y presupuesto.
func _world_pressure(id: String) -> Array:
	var out: Array = []
	for pd in m.world.policy_drivers(id):
		var d: Dictionary = pd
		if absf(float(d["value"])) < 0.0001:
			continue
		out.append({"label": str(d["label"]), "value": float(d["value"]), "kind": "policy", "ref": str(d["measure"]), "via": "", "text": ""})
	for tp in m.world.target_parts(id):
		var t: Dictionary = tp
		if str(t["kind"]) == "policy":
			continue
		out.append({"label": str(t["label"]), "value": float(t["value"]), "kind": "link" if str(t["kind"]) == "link" else "budget", "ref": "", "via": str(t["id"]), "text": ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out

func _fiscal_causes(id: String) -> Array:
	var out: Array = []
	var hist := m.eco.history()
	if hist.size() < 2:
		return out
	var cur: Dictionary = hist[hist.size() - 1]
	var prev: Dictionary = hist[maxi(0, hist.size() - 2)]
	if id == "deficit_pct" or id == "spending" or id == "debt_pct":
		var cb: Dictionary = cur.get("budget", {})
		var pb: Dictionary = prev.get("budget", {})
		for k in cb.keys():
			var d := float(cb[k]) - float(pb.get(k, cb[k]))
			if absf(d) >= 0.4:
				out.append({"label": "Gasto en %s" % str(Policies.entry(Policies.budget(), str(k)).get("name", k)), "value": d if id != "debt_pct" else d / maxf(1.0, m.eco.gdp()) * 100.0, "kind": "budget", "ref": "", "via": "", "text": ""})
	if id == "deficit_pct" or id == "revenue" or id == "debt_pct":
		var dr := float(cur.get("revenue", 0.0)) - float(prev.get("revenue", 0.0))
		if absf(dr) >= 0.4:
			out.append({"label": "Recaudación de impuestos", "value": -dr / maxf(1.0, m.eco.gdp()) * 100.0 if id != "revenue" else dr, "kind": "agent", "ref": "", "via": "", "text": ""})
	var di := float(m.eco.st().get("interest", 0.0))
	if id == "deficit_pct" or id == "spending":
		out.append({"label": "Intereses de la deuda (%.2f %% de coste medio)" % float(m.macro.v("eff_cost")), "value": di / maxf(1.0, m.eco.gdp()) * 100.0 if id == "deficit_pct" else di, "kind": "agent", "ref": "", "via": "eff_cost", "text": "Nivel actual"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out

## Medidas que mueven una partida de gasto o un impuesto (por su efecto sobre el coste o la recaudación).
func _line_causes(id: String) -> Array:
	var out: Array = []
	var key := "cost" if id.begins_with("b:") else "rev"
	var lid := id.substr(2)
	var sc := m.eco.gdp() / float(m.eco.st().get("gdp0", 1462.0))
	for it in Policies.measures():
		var meas: Dictionary = it
		var fxd: Dictionary = meas.get(key, {})
		if not fxd.has(lid):
			continue
		var steps := (m.eco.value(str(meas["id"])) - float(meas["base"])) / float(meas["step"])
		if absf(steps) < 0.001:
			continue
		out.append({"label": str(meas["name"]), "value": float(fxd[lid]) * steps * sc * (1.0 if key == "cost" else 1.0), "kind": "policy", "ref": str(meas["id"]), "via": "", "text": ""})
	if id.begins_with("b:"):
		var f := m.eco.budget_factor(lid)
		if absf(f - 1.0) > 0.001:
			out.append({"label": "Presupuestos aprobados (dotación ×%.2f)" % f, "value": m.eco.budget_spending(lid) * (1.0 - 1.0 / maxf(0.01, f)), "kind": "budget", "ref": "", "via": "", "text": ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out

func _quality_causes(qid: String) -> Array:
	var out: Array = []
	for it in m.world.policy_drivers(qid):
		var d: Dictionary = it
		if absf(float(d["value"])) < 0.0001:
			continue
		out.append({"label": str(d["label"]), "value": float(d["value"]), "kind": "policy", "ref": str(d["measure"]), "via": "", "text": ""})
	var qd := Policies.entry(Policies.quality(), qid)
	var dom := str(qd.get("domain", ""))
	if dom != "":
		var bf := (m.eco.budget_factor(dom) - 1.0) * 35.0
		if absf(bf) > 0.05:
			out.append({"label": "Presupuesto de %s" % str(Policies.entry(Policies.budget(), dom).get("name", dom)), "value": bf, "kind": "budget", "ref": "", "via": "", "text": ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out

## Efectos que siguen actuando (medidas todavía llegando, crisis activas): [{label, value, kind, ref, text}].
func standing(id: String) -> Array:
	var out: Array = []
	if CORE.has(id) or MacroSim.OWNED.has(id):
		for c in m.macro.push(id):
			var cd: Dictionary = c
			out.append({"label": str(cd["label"]), "value": float(cd["value"]), "kind": str(cd["kind"]), "ref": str(cd["ref"]), "via": str(cd.get("via", "")), "text": m.macro.origin_text(str(cd["ref"])) if str(cd["kind"]) == "policy" else ""})
	return out

## Qué movió una variable en un trimestre pasado (si el motor lo guardó): [{label, value, kind, ref}].
func causes_at(id: String, t: int) -> Array:
	if not (CORE.has(id) or MacroSim.OWNED.has(id)):
		return []
	var best: Dictionary = {}
	var gap := 1 << 60
	for h in m.macro.history():
		var hd: Dictionary = h
		var dt := absi(int(hd["t"]) - t)
		if dt < gap:
			gap = dt
			best = hd
	if best.is_empty() or gap > 50 * 86400:
		return []
	return (best.get("why", {}) as Dictionary).get(id, [])

# ---------------------------------------------------------------- hitos para las gráficas
## Leyes aprobadas y crisis como marcas verticales alineadas con la serie: [{i, text}].
func markers(ents: Array, with_laws: bool = true, with_events: bool = true) -> Array:
	var out: Array = []
	if ents.is_empty():
		return out
	var first_t := int((ents[0] as Dictionary)["t"])
	var items: Array = []
	if with_laws:
		for l in m.eco.passed_laws():
			var ld: Dictionary = l
			var t := int(ld.get("t", 0))
			if t >= first_t:
				items.append({"t": t, "text": "Ley: " + str(ld.get("title", ""))})
	if with_events:
		for e in m.macro.events():
			var ed: Dictionary = e
			items.append({"t": int(ed.get("t", 0)), "text": ("▲ " if bool(ed.get("good", false)) else "▼ ") + str(ed.get("name", ""))})
	for it in items:
		var d: Dictionary = it
		if int(d["t"]) < first_t:
			continue
		var idx := ents.size() - 1
		for i in range(ents.size()):
			if int((ents[i] as Dictionary)["t"]) >= int(d["t"]):
				idx = i
				break
		out.append({"i": idx, "text": str(d["text"])})
	return out

# ---------------------------------------------------------------- previsión
## Trayectoria previsible (sin nuevos shocks) para las variables del motor y las centrales: lista de `n` valores.
func projection(id: String, n: int = 6) -> Array:
	var keymap := {"growth": "growth", "unemployment": "unemployment", "inflation": "inflation"}
	var key := str(keymap.get(id, id))
	if not (CORE.has(id) or (MacroSim.has_var(id) and MacroSim.HIST_KEYS.has(id))):
		return []
	var out: Array = []
	var src: Array = m.macro.st().get("proj", []) if n <= 6 else m.macro.project(n)
	for i in range(mini(n, src.size())):
		out.append(float((src[i] as Dictionary).get(key, 0.0)))
	return out
