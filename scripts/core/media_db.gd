class_name MediaDB
extends RefCounted
## Base de datos de medios: preguntas, respuestas, reacciones y mensajes de redes en data/media/*.json.
## Las entradas admiten etiquetas al principio: [d,t,r,p,c] formatos (debate, tele, radio, podcast, rueda de prensa)
## y [g,o] papel (g = Gobierno o socio, o = oposición). Sin etiqueta valen para todo.
## Los huecos {issue}, {rival}, {leader}... se rellenan al generar la pregunta (ver fill()).

const FORMATS := {
	"tv": {"label": "Entrevista en televisión", "scene": "tv", "secs": 26.0, "n": 4, "tag": "t"},
	"radio": {"label": "Entrevista en radio", "scene": "radio", "secs": 22.0, "n": 4, "tag": "r"},
	"podcast": {"label": "Pódcast", "scene": "podcast", "secs": 32.0, "n": 4, "tag": "p"},
	"press": {"label": "Rueda de prensa", "scene": "press", "secs": 24.0, "n": 5, "tag": "c"},
	"debate": {"label": "Debate", "scene": "debate", "secs": 20.0, "n": 5, "tag": "d"},
	"control": {"label": "Sesión de control", "scene": "pleno", "secs": 22.0, "n": 4, "tag": "c"},
}
const FORMAT_TAGS := ["d", "t", "r", "p", "c"]

static var _q: Dictionary = {}
static var _a: Dictionary = {}
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_q = _read("res://data/media/questions.json")
	_a = _read("res://data/media/answers.json")

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

## "tv", "radio", "podcast", "press", "debate" o "control" según el tipo de acto y el medio.
static func format_of(type_name: String, outlet_kind: String) -> String:
	match type_name:
		"Debate": return "debate"
		"Rueda de prensa": return "press"
		"Podcast": return "podcast"
		"Sesión de control": return "control"
	match outlet_kind:
		"radio": return "radio"
		"digital": return "podcast"
	return "tv"

## Separa las etiquetas del texto: {"t": texto, "f": [formatos], "r": [papeles], "s": [subtipos]}.
## Las etiquetas que no son formato ni papel son subtipos (p. ej. "libro", "apoyo"): una pregunta con subtipo solo recibe
## respuestas de ese subtipo, y una pregunta sin subtipo solo respuestas sin subtipo.
static func parse(raw: String) -> Dictionary:
	var out := {"t": raw, "f": [], "r": [], "s": []}
	if raw.begins_with("["):
		var end := raw.find("]")
		if end > 0:
			out["t"] = raw.substr(end + 1)
			for tg in raw.substr(1, end - 1).split(","):
				var tag := str(tg).strip_edges()
				if tag in FORMAT_TAGS:
					(out["f"] as Array).append(tag)
				elif tag in ["g", "o"]:
					(out["r"] as Array).append(tag)
				elif tag != "":
					(out["s"] as Array).append(tag)
	return out

static func _matches(entry: Dictionary, fmt: String, role_tag: String) -> bool:
	var tag := str((FORMATS.get(fmt, {}) as Dictionary).get("tag", ""))
	if not (entry["f"] as Array).is_empty() and not (entry["f"] as Array).has(tag):
		return false
	if not (entry["r"] as Array).is_empty() and not (entry["r"] as Array).has(role_tag):
		return false
	return true

static func _texts(list: Array, fmt: String, role_tag: String) -> Array:
	var out: Array = []
	for raw in list:
		var e := parse(str(raw))
		if _matches(e, fmt, role_tag):
			out.append(str(e["t"]))
	return out

## Preguntas de un tipo (y tema, si hay banco por tema) válidas para el formato y el papel.
static func questions(kind: String, issue: String, fmt: String, role_tag: String) -> Array:
	_ensure()
	var bank: Variant = (_q.get("q", {}) as Dictionary).get(kind, [])
	var out: Array = []
	if typeof(bank) == TYPE_DICTIONARY:
		out = _texts((bank as Dictionary).get(issue, []), fmt, role_tag)
	elif typeof(bank) == TYPE_ARRAY:
		out = _texts(bank as Array, fmt, role_tag)
	if kind in ["policy", "crisis"] and not issue.is_empty():
		var by_issue: Variant = (_q.get("q", {}) as Dictionary).get("issue", {})
		if kind == "policy" and typeof(by_issue) == TYPE_DICTIONARY:
			out.append_array(_texts((by_issue as Dictionary).get(issue, []), fmt, role_tag))
	return out

## Preguntas con su subtipo: [{"t": texto, "s": subtipo o ""}].
static func questions_tagged(kind: String, issue: String, fmt: String, role_tag: String) -> Array:
	_ensure()
	var raws: Array = []
	var bank: Variant = (_q.get("q", {}) as Dictionary).get(kind, [])
	if typeof(bank) == TYPE_DICTIONARY:
		raws.append_array((bank as Dictionary).get(issue, []))
	elif typeof(bank) == TYPE_ARRAY:
		raws.append_array(bank as Array)
	if kind == "policy" and not issue.is_empty():
		var by_issue: Variant = (_q.get("q", {}) as Dictionary).get("issue", {})
		if typeof(by_issue) == TYPE_DICTIONARY:
			raws.append_array((by_issue as Dictionary).get(issue, []))
	var out: Array = []
	for raw in raws:
		var e := parse(str(raw))
		if _matches(e, fmt, role_tag):
			var subs: Array = e["s"]
			out.append({"t": str(e["t"]), "s": "" if subs.is_empty() else str(subs[0])})
	return out

## ¿Hay un banco de respuestas propio para este tipo de pregunta?
static func has_kind_bank(kind: String) -> bool:
	_ensure()
	return (_a.get("by_kind", {}) as Dictionary).has(kind)

## Respuestas de un tipo de pregunta y estilo, ya filtradas por formato, papel y subtipo de la pregunta.
static func kind_answers(kind: String, arch: String, sub: String, fmt: String, role_tag: String) -> Array:
	_ensure()
	var out: Array = []
	var bank: Array = (((_a.get("by_kind", {}) as Dictionary).get(kind, {}) as Dictionary).get(arch, []) as Array)
	for raw in bank:
		var e := parse(str(raw))
		if not _matches(e, fmt, role_tag):
			continue
		var subs: Array = e["s"]
		if (subs.is_empty() and sub == "") or subs.has(sub):
			out.append(str(e["t"]))
	return out

static func answers(arch: String, fmt: String) -> Array:
	_ensure()
	return _texts((_a.get("answers", {}) as Dictionary).get(arch, []), fmt, "")

static func replica_answers(arch: String) -> Array:
	_ensure()
	return (_a.get("replica", {}) as Dictionary).get(arch, [])

static func react(grade: String, mood: String) -> Array:
	_ensure()
	return ((_a.get("react", {}) as Dictionary).get(grade, {}) as Dictionary).get(mood, [])

static func social(tone: String) -> Array:
	_ensure()
	return (_a.get("social", {}) as Dictionary).get(tone, [])

static func handles() -> Array:
	_ensure()
	return _a.get("handles", ["@usuario"])

static func intros(fmt: String) -> Array:
	_ensure()
	return (_a.get("intros", {}) as Dictionary).get(fmt, [])

static func outros(fmt: String) -> Array:
	_ensure()
	return (_a.get("outros", {}) as Dictionary).get(fmt, [])

static func rival_lines() -> Array:
	_ensure()
	return _q.get("rivallines", [])

static func scandals() -> Array:
	_ensure()
	return _q.get("scandals", [])

## [{"txt", "issue"}]
static func crises() -> Array:
	_ensure()
	var out: Array = []
	for c in _q.get("crises", []):
		out.append({"txt": str((c as Array)[0]), "issue": str((c as Array)[1])})
	return out

static func control_facts(issue: String) -> Array:
	_ensure()
	return (_q.get("control", {}) as Dictionary).get(issue, [])

## Recuento total de entradas (para pruebas y para el cuaderno de diseño).
static func counts() -> Dictionary:
	_ensure()
	var nq := 0
	for k in (_q.get("q", {}) as Dictionary).keys():
		var v: Variant = (_q["q"] as Dictionary)[k]
		if typeof(v) == TYPE_DICTIONARY:
			for kk in (v as Dictionary).keys():
				nq += ((v as Dictionary)[kk] as Array).size()
		else:
			nq += (v as Array).size()
	var na := 0
	for k2 in (_a.get("answers", {}) as Dictionary).keys():
		na += ((_a["answers"] as Dictionary)[k2] as Array).size()
	for k3 in (_a.get("replica", {}) as Dictionary).keys():
		na += ((_a["replica"] as Dictionary)[k3] as Array).size()
	var nr := 0
	for g in (_a.get("react", {}) as Dictionary).values():
		for l in (g as Dictionary).values():
			nr += (l as Array).size()
	for kk in (_a.get("by_kind", {}) as Dictionary).keys():
		for l4 in ((_a["by_kind"] as Dictionary)[kk] as Dictionary).values():
			na += (l4 as Array).size()
	var ns := 0
	for l2 in (_a.get("social", {}) as Dictionary).values():
		ns += (l2 as Array).size()
	return {"questions": nq + (_q.get("scandals", []) as Array).size() + (_q.get("crises", []) as Array).size() + (_q.get("rivallines", []) as Array).size(), "answers": na, "reactions": nr, "social": ns}

static func fill(text: String, vars: Dictionary) -> String:
	var out := text
	for k in vars.keys():
		out = out.replace("{%s}" % str(k), str(vars[k]))
	return out
