extends SceneTree
## Captura del plató con el diálogo de abandono. Uso: xvfb-run -a ... --script res://tests/abandon_shot.gd -- psoe /tmp/ab
var shell: Control
func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame
func _initialize() -> void:
	_run()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := "/tmp/ab" if args.size() < 2 else str(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(2)
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe":
			party = p
	root.get_node("SaveManager").current_save = {"schema_version": 3, "save_id": "shots", "player_party": party, "game_state": {}}
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	var m: GameModel = shell.m
	m.autosave = false
	var st: MediaStudio = shell.play_studio({"type": "Debate", "title": "Prueba", "region": "Madrid", "hour": 20}, Callable())
	await _frames(30)
	st._advance()
	await _frames(40)
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/pregunta.png")
	var t0 := m.trust
	st._ask_abandon()
	await _frames(12)
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/confirmar.png")
	print("ok")
	quit()
