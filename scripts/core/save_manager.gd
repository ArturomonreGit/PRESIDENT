extends Node
## Autoload. Gestiona las partidas guardadas en user://saves.
## La escritura es atómica (archivo temporal + renombrado) y conserva una copia .bak.

const SAVE_DIR := "user://saves"
const SAVE_EXTENSION := ".json"
const SCHEMA_VERSION := 3

var current_save: Dictionary = {}
var current_path := ""
var last_error := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func create_new_game(party: Dictionary, scenario_id: String = "spain_2023") -> Dictionary:
	var now := Time.get_datetime_dict_from_system(true)
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
	var game_id := "save_%s_%s" % [stamp, str(randi() % 10000).pad_zeros(4)]
	var clean_party := party.duplicate(true)
	var data := {
		"schema_version": SCHEMA_VERSION,
		"save_id": game_id,
		"save_name": str(clean_party.get("short_name", "Nueva formación")),
		"created_at": Time.get_datetime_string_from_system(true),
		"updated_at": Time.get_datetime_string_from_system(true),
		"scenario_id": scenario_id,
		"scenario_name": "España · 2023",
		"current_date": "2023-06-11",
		"player_party": clean_party,
		"game_state": {}
	}
	var path := SAVE_DIR.path_join(game_id + SAVE_EXTENSION)
	var ok := _write_json(path, data)
	if ok:
		current_save = data
		current_path = path
	return {"ok": ok, "data": data, "path": path}

func load_game(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "El archivo de partida no existe."}
	var parsed: Variant = _read_json_file(path)
	if typeof(parsed) != TYPE_DICTIONARY and FileAccess.file_exists(path + ".bak"):
		parsed = _read_json_file(path + ".bak")
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "El archivo de guardado está dañado o no es válido."}
	var data: Dictionary = parsed
	if int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return {"ok": false, "error": "Esta partida pertenece a una versión más reciente del juego."}
	if not data.has("game_state") or typeof(data["game_state"]) != TYPE_DICTIONARY:
		data["game_state"] = {}
	current_save = data
	current_path = path
	return {"ok": true, "data": current_save}

func _read_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func save_current() -> bool:
	if current_save.is_empty() or current_path.is_empty():
		return false
	current_save["updated_at"] = Time.get_datetime_string_from_system(true)
	current_save["schema_version"] = SCHEMA_VERSION
	return _write_json(current_path, current_save)

func update_player_party(party: Dictionary) -> void:
	if current_save.is_empty():
		return
	current_save["player_party"] = party.duplicate(true)
	current_save["save_name"] = str(party.get("short_name", "Partida"))
	save_current()

func list_saves() -> Array:
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(SAVE_EXTENSION):
			var path := SAVE_DIR.path_join(filename)
			var parsed: Variant = _read_json_file(path)
			if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("save_id"):
				var item: Dictionary = parsed
				item["_path"] = path
				result.append(item)
		filename = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("updated_at", "")) > str(b.get("updated_at", "")))
	return result

func delete_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

func _write_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		last_error = "No se pudo escribir el guardado: " + path
		push_error(last_error)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path))
	if err != OK:
		last_error = "No se pudo finalizar el guardado (código %d)." % err
		push_error(last_error)
		return false
	return true
