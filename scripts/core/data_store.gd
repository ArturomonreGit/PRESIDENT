class_name DataStore
extends RefCounted
## Carga de datos del escenario desde JSON con caché en memoria.

const PARTIES_PATH := "res://data/scenarios/spain/parties.json"
const CONSTITUENCIES_PATH := "res://data/scenarios/spain/constituencies_2023.json"
const MAP_PATH := "res://data/maps/spain_provinces_real.json"

static var _cache: Dictionary = {}

static func read_json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("JSON no válido en " + path)
		return {}
	_cache[path] = parsed
	return parsed

static func parties() -> Array:
	var data: Variant = read_json(PARTIES_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return (data as Dictionary).get("parties", []).duplicate(true)

static func constituencies() -> Array:
	var data: Variant = read_json(CONSTITUENCIES_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return (data as Dictionary).get("constituencies", []).duplicate(true)

static func map_provinces() -> Array:
	var data: Variant = read_json(MAP_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return (data as Dictionary).get("provinces", [])

static func map_insets() -> Array:
	var data: Variant = read_json(MAP_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return (data as Dictionary).get("insets", [])

static func map_view_size() -> Vector2:
	var data: Variant = read_json(MAP_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		var v: Array = (data as Dictionary).get("view_size", [920, 620])
		return Vector2(float(v[0]), float(v[1]))
	return Vector2(920, 620)
