extends SceneTree
## Capturas de las fichas de compromisos (Coalición y Gobierno). Uso: ... -- <partido> <salida>
var out_dir := "/tmp/commit_shots"
func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame
func _shot(name: String) -> void:
	await _frames(5)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = str(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run("psoe" if args.size() < 1 else str(args[0]))
func _run(party_id: String) -> void:
	await _frames(2)
	NightScreen.auto_open = false
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	root.get_node("SaveManager").create_new_game(party)
	var shell: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	var waited := 0
	while str(shell.m.s.get("history_mode", "")) == "" and waited < 900:
		await _frames(1)
		waited += 1
	await _frames(20)
	var m: GameModel = shell.m
	m.autosave = false
	m.phase = "legislature"
	m.s["government_party_id"] = m.pid()
	var com := {"party": "sumar", "text": "Plan de vivienda pública de gran escala", "due": 6, "source": "acuerdo", "fulfilled": false, "measure": "", "issue": "housing"}
	m.a("commitments").append(com)
	m.agr.normalize(com)
	com["binding"] = "red_line"
	com["verify"] = {"t": "manual", "cost": 2.0}
	m.a("commitments").append({"party": "sumar", "text": "Una vicepresidencia del Gobierno", "due": 3, "source": "acuerdo", "fulfilled": true})
	m.agr.normalize(m.a("commitments")[1])
	m.agr.set_state(m.a("commitments")[1], "fulfilled", "Entregada")
	load("res://scripts/ui/screens/coalition_screen.gd").set("tab", "compromisos")
	shell.go("coalition")
	await _frames(5)
	var scr = shell.get("current")
	print("ok")
	await _shot("01_coalicion")
	quit()
