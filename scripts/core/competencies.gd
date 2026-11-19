class_name Competencies
extends RefCounted
## Catálogo ampliable de competencias de gobierno. Cada competencia tiene un identificador estable, una categoría
## y puede enlazar con un área de política (Policies), una partida del presupuesto y el indicador que mejora un buen
## ministro. Las carteras llevan etiquetas de competencia: el nombre del ministerio ya no decide qué gestiona.

const CATEGORIES := {
	"economica": {"name": "Económica", "color": "#F5D04B"},
	"social": {"name": "Social", "color": "#34D3A0"},
	"territorial": {"name": "Territorial", "color": "#4DA3FF"},
	"institucional": {"name": "Institucional", "color": "#C792EA"},
}
const CATEGORY_ORDER := ["economica", "social", "territorial", "institucional"]

## id, nombre, categoría, área de política (cada área tiene una sola competencia), partida del presupuesto, indicador
## que mejora un buen titular y si es esencial (alerta si nadie la gestiona).
const CATALOG := [
	{"id": "hacienda", "name": "Hacienda y presupuestos", "cat": "economica", "area": "tax", "line": "", "focus": "growth", "essential": true},
	{"id": "consumo", "name": "Consumo e impuestos indirectos", "cat": "economica", "area": "indirect", "line": "", "focus": "", "essential": false},
	{"id": "empleo", "name": "Empleo y economía social", "cat": "economica", "area": "jobs", "line": "", "focus": "unemployment", "essential": true},
	{"id": "economia", "name": "Economía y empresa", "cat": "economica", "area": "", "line": "", "focus": "growth", "essential": false},
	{"id": "industria", "name": "Industria y comercio", "cat": "economica", "area": "industry", "line": "industria", "focus": "growth", "essential": false},
	{"id": "energia", "name": "Energía y transición ecológica", "cat": "economica", "area": "energy", "line": "transicion", "focus": "environment", "essential": false},
	{"id": "pensiones", "name": "Seguridad Social y pensiones", "cat": "economica", "area": "", "line": "pensiones", "focus": "", "essential": false},
	{"id": "turismo", "name": "Turismo", "cat": "economica", "area": "", "line": "", "focus": "", "essential": false},
	{"id": "sanidad", "name": "Sanidad", "cat": "social", "area": "health", "line": "sanidad", "focus": "health", "essential": true},
	{"id": "educacion", "name": "Educación y formación profesional", "cat": "social", "area": "education", "line": "educacion", "focus": "education", "essential": true},
	{"id": "vivienda", "name": "Vivienda", "cat": "social", "area": "housing", "line": "vivienda", "focus": "housing", "essential": false},
	{"id": "derechos_sociales", "name": "Derechos sociales", "cat": "social", "area": "social", "line": "prestaciones", "focus": "equality", "essential": false},
	{"id": "igualdad", "name": "Igualdad y familia", "cat": "social", "area": "family", "line": "", "focus": "equality", "essential": false},
	{"id": "cultura", "name": "Cultura", "cat": "social", "area": "", "line": "", "focus": "", "essential": false},
	{"id": "deporte", "name": "Deporte y juventud", "cat": "social", "area": "", "line": "", "focus": "", "essential": false},
	{"id": "transportes", "name": "Transportes e infraestructuras", "cat": "territorial", "area": "transport", "line": "transportes", "focus": "infrastructure", "essential": false},
	{"id": "agricultura", "name": "Agricultura y desarrollo rural", "cat": "territorial", "area": "agriculture", "line": "agricultura", "focus": "environment", "essential": false},
	{"id": "medio_ambiente", "name": "Medio ambiente y agua", "cat": "territorial", "area": "", "line": "", "focus": "environment", "essential": false},
	{"id": "territorial", "name": "Administración territorial", "cat": "territorial", "area": "territory", "line": "territorial", "focus": "", "essential": false},
	{"id": "interior", "name": "Interior y seguridad", "cat": "institucional", "area": "security", "line": "interior", "focus": "security", "essential": true},
	{"id": "inmigracion", "name": "Inmigración", "cat": "institucional", "area": "immigration", "line": "", "focus": "", "essential": false},
	{"id": "justicia", "name": "Justicia", "cat": "institucional", "area": "justice", "line": "justicia", "focus": "security", "essential": true},
	{"id": "defensa", "name": "Defensa", "cat": "institucional", "area": "defense", "line": "defensa", "focus": "", "essential": true},
	{"id": "exteriores", "name": "Asuntos exteriores", "cat": "institucional", "area": "", "line": "", "focus": "", "essential": true},
	{"id": "presidencia", "name": "Presidencia y coordinación", "cat": "institucional", "area": "", "line": "administracion", "focus": "", "essential": true},
	{"id": "funcion_publica", "name": "Función pública", "cat": "institucional", "area": "", "line": "", "focus": "", "essential": false},
	{"id": "ciencia", "name": "Ciencia, universidades e innovación", "cat": "institucional", "area": "science", "line": "ciencia", "focus": "innovation", "essential": false},
	{"id": "digital", "name": "Transformación digital", "cat": "institucional", "area": "", "line": "", "focus": "innovation", "essential": false},
]

## Competencias por defecto de cada cartera del catálogo clásico (Rules.MINISTRY_CATALOG).
const DEFAULTS := {
	"Presidencia y Relaciones con las Cortes": ["presidencia", "funcion_publica"],
	"Hacienda": ["hacienda", "consumo"],
	"Asuntos Exteriores": ["exteriores"],
	"Defensa": ["defensa"],
	"Interior": ["interior", "inmigracion"],
	"Justicia": ["justicia"],
	"Transportes y Movilidad": ["transportes"],
	"Vivienda": ["vivienda"],
	"Sanidad": ["sanidad"],
	"Educación y Formación Profesional": ["educacion"],
	"Trabajo y Economía Social": ["empleo", "pensiones"],
	"Economía y Empresa": ["economia"],
	"Industria y Comercio": ["industria"],
	"Agricultura y Alimentación": ["agricultura"],
	"Transición Ecológica": ["energia", "medio_ambiente"],
	"Cultura": ["cultura", "deporte"],
	"Ciencia y Universidades": ["ciencia"],
	"Igualdad": ["igualdad"],
	"Política Territorial": ["territorial"],
	"Derechos Sociales": ["derechos_sociales"],
	"Turismo": ["turismo"],
	"Deportes": ["deporte"],
	"Transformación Digital": ["digital"],
	"Consumo": ["consumo"],
}

const MIN_MINISTRIES := 8
const MAX_MINISTRIES := 20
const BROAD_LIMIT := 5

static func catalog() -> Array:
	return CATALOG

static func by_id(id: String) -> Dictionary:
	for c in CATALOG:
		if str((c as Dictionary)["id"]) == id:
			return c
	return {}

static func exists(id: String) -> bool:
	return not by_id(id).is_empty()

static func name_of(id: String) -> String:
	return str(by_id(id).get("name", id))

static func category_name(cat: String) -> String:
	return str((CATEGORIES.get(cat, {"name": cat}) as Dictionary)["name"])

static func category_color(cat: String) -> Color:
	return Color(str((CATEGORIES.get(cat, {"color": "#8FA3B8"}) as Dictionary)["color"]))

static func of_category(cat: String) -> Array:
	var out: Array = []
	for c in CATALOG:
		if str((c as Dictionary)["cat"]) == cat:
			out.append(c)
	return out

static func essentials() -> Array:
	var out: Array = []
	for c in CATALOG:
		if bool((c as Dictionary).get("essential", false)):
			out.append(str((c as Dictionary)["id"]))
	return out

static func defaults_for(key: String) -> Array:
	return (DEFAULTS.get(key, []) as Array).duplicate()

## Competencia que gobierna un área de política, o "" si ninguna.
static func comp_of_area(area_id: String) -> String:
	for c in CATALOG:
		if str((c as Dictionary).get("area", "")) == area_id:
			return str((c as Dictionary)["id"])
	return ""

static func comp_of_line(line_id: String) -> String:
	for c in CATALOG:
		if str((c as Dictionary).get("line", "")) == line_id:
			return str((c as Dictionary)["id"])
	return ""

## Nombre sugerido para una cartera a partir de sus competencias.
static func suggest_name(comps: Array) -> String:
	if comps.is_empty():
		return "Nuevo ministerio"
	var names: Array = []
	for id in comps.slice(0, 2):
		var n := name_of(str(id))
		names.append(n)
	return "Ministerio de " + " y ".join(names)
