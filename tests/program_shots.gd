extends SceneTree
## Capturas del programa (editor con IRPF por tramos, seguimiento) y del Taller con las proposiciones del programa.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/program_shots.gd -- <partido> <carpeta>
var shell: Control
var out_dir := "/tmp/pshots"

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = str(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run("psoe" if args.size() < 1 else str(args[0]))

func _run(party_id: String) -> void:
	await _frames(2)
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	root.get_node("SaveManager").create_new_game(party)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	var m: GameModel = shell.m
	m.autosave = false
	var mf := m.manifesto
	mf.suggest()
	var nb: Array = m.eco.irpf_brackets().duplicate(true)
	(nb[1] as Dictionary)["rate"] = 22.0
	nb.append({"from": 500.0, "rate": 50.0})
	mf.set_irpf_promise(nb)
	PolicyBrowser.memory["program"] = {"area": "tax", "mid": ""}
	shell.go("program")
	await _shot("20_programa_irpf")
	mf.sign()
	m.phase = "legislature"
	m.gov_month = 1
	m.s["government_party_id"] = m.pid()
	m.gov.ensure_legislature_state(true)
	mf.create_bills()
	shell.refresh()
	LawsScreen.editing_id = ""
	shell.go("laws")
	await _shot("21_taller_proposiciones")
	for d in m.laws.drafts():
		if str((d as Dictionary).get("promise", "")) == Irpf.SPECIAL_ID:
			LawsScreen.editing_id = str(d["id"])
			LawsScreen.tab_area = "tax"
	shell.go("laws")
	await _shot("22_taller_irpf")
	LawsScreen.editing_id = ""
	m.gov_month = 22
	shell.go("program")
	await _shot("23_seguimiento_retraso")
	quit()
