extends SceneTree
## Capturas y desbordes de Gabinete y Mesa de coalición. Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/cabinet_shots.gd -- psoe /tmp/cab
var out_dir := "/tmp/cab"
var shell: Control
var helper = load("res://tests/cabinet.gd").new()

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _over() -> int:
	var vs: VScrollBar = shell.scroll.get_v_scroll_bar()
	return int(vs.max_value - vs.page)

func _shot(name: String) -> void:
	await _frames(4)
	var o := _over()
	print("  %-22s desborde %d px" % [name, o])
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
	var waited := 0
	while str(m.s.get("history_mode", "")) == "" and waited < 600:
		await _frames(1)
		waited += 1
	await create_timer(0.8).timeout
	m.rng.seed = 42
	var shot_design := OS.get_environment("DESIGN") != ""
	helper._fast_gov_into(m)
	print("fase ", m.phase, " presidente ", m.coal.gov_id(), " socios ", m.coal.party_ids())
	if shot_design and m.phase != "legislature":
		pass
	shell.go("cabinet")
	await _shot("cabinet")
	if m.phase != "legislature":
		print("Capturas en ", out_dir)
		quit()
		return
	m.exec.ensure()
	m.exec.add_capital(30.0)
	for q in range(3):
		m.gov_month += Rules.TURN_MONTHS
		m.mact.quarterly()
		m.coal.quarterly()
	shell.refresh()
	shell.go("cabinet")
	await _shot("cabinet_t3")
	for t in ["minister", "comps", "actions", "struct"]:
		MinistrySheet.open(shell, m, 1, t)
		await _shot("sheet_" + t)
		shell.close_modal()
	shell.go("coalition")
	for t in ["socios", "propuestas", "compromisos", "crisis", "historial"]:
		CoalitionScreen.tab = t
		shell.go("coalition")
		await _shot("mesa_" + t)
	var pid := ""
	for id in m.coal.party_ids():
		pid = str(id)
		break
	if pid != "":
		m.d("partner_satisfaction")[pid] = 18.0
		m.coal.crisis(pid)["phase"] = 4
		m.gov_month += Rules.TURN_MONTHS
		m.coal.quarterly()
		CoalitionScreen.tab = "crisis"
		shell.go("coalition")
		await _shot("mesa_crisis_ultimatum")
	print("Capturas en ", out_dir)
	quit()
