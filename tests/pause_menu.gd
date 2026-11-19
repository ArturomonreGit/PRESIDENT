extends SceneTree
## Menú de pausa (Esc): se abre, pausa el árbol, navega por Ajustes y se cierra; los botones fijos ya no están en la barra.
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e

func _initialize() -> void:
	_run()

func _run() -> void:
	Sfx.enabled = false
	await _frames(2)
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe":
			party = p
	root.get_node("SaveManager").current_save = {"schema_version": 3, "save_id": "pause", "player_party": party, "game_state": {}}
	var shell: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	shell.m.autosave = false
	check(shell.util_box.get_child_count() == 0, "la barra superior ya no tiene Sonido/Pantalla/Guardar/Menú")
	shell._input(_esc())
	await _frames(2)
	var pm := shell.get_node_or_null("PauseMenu")
	check(pm != null, "Esc abre el menú de pausa")
	check(paused, "el juego queda en pausa")
	pm._show_settings()
	await _frames(2)
	check(pm._mode == "settings", "se llega a Ajustes")
	pm._input(_esc())
	check(pm._mode == "main", "Esc dentro de Ajustes vuelve al menú de pausa")
	pm._confirm("¿Salir?", "x", "Salir", func() -> void: pass)
	check(pm._mode == "confirm", "salir y volver al menú piden confirmación")
	pm._show_main()
	pm._input(_esc())
	await _frames(3)
	check(shell.get_node_or_null("PauseMenu") == null, "Esc cierra el menú de pausa")
	check(not paused, "el juego se reanuda")
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)
