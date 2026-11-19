extends SceneTree
## Capturas de las pantallas de encuestas, electorado y militancia tras jugar unos meses.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/voters_shots.gd -- psoe /tmp/voters
var out_dir := "/tmp/voters"
var shell: Control

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var party_id := "psoe" if args.size() < 1 else str(args[0])
	if args.size() > 1:
		out_dir = str(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(party_id)

func _run(party_id: String) -> void:
	await _frames(2)
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	var sm := root.get_node("SaveManager")
	sm.current_save = {"schema_version": 3, "save_id": "shots", "player_party": party, "game_state": {}}
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	var m: GameModel = shell.m
	m.autosave = false
	m.rng.seed = 42
	for d in range(30):
		m.voters.step_day()
		if d % 7 == 6:
			m.campaign.record_snapshot("Día %d" % d, m.clock_unix() + d * 86400)
	m.voters.react({"party": party_id, "partners": [], "dir": [0.12, 0.1, 0.0], "groups": {}, "issue": "tax", "mag": 1.4, "label": "Ley de prueba"})
	m.voters.recompute(true)
	m.militancy.ensure()
	m.militancy.on_pact("vox" if party_id != "vox" else "pp")
	shell.refresh()
	for id in ["polls", "electorate", "militancy"]:
		shell.go(id)
		await _shot("campana_" + id)
	# Legislatura simulada con 30 meses de historial
	m.s["phase"] = "legislature"
	for mo in range(30):
		m.gov_month = mo + 1
		m.voters.monthly()
		m.militancy.monthly()
	shell.refresh()
	for id in ["polls", "electorate", "militancy", "home"]:
		shell.go(id)
		await _shot("legislatura_" + id)
	print("Capturas en ", out_dir)
	quit()
