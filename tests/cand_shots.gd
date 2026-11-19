extends SceneTree
## Capturas del selector de cinco candidatos. Uso: ... -- <partido> <salida>
var out_dir := "/tmp/cand_shots"
func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame
func _shot(name: String) -> void:
	await _frames(6)
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
	var T = load("res://tests/candidates.gd").new()
	T._fast_gov_into(m)
	print("fase: ", m.phase, " gobierna: ", m.coal.gov_id(), " yo: ", m.pid())
	m.ministers.ensure_cabinet()
	shell.refresh_chrome()
	var idx := 0
	var cab := m.gov.cabinet()
	for i in range(cab.size()):
		if str((cab[i] as Dictionary)["party"]) == m.pid():
			idx = i
			break
	shell.go("cabinet")
	await _frames(4)
	await _shot("01_consejo")
	MinistrySheet.open(shell, m, idx, "cands")
	await _shot("02_candidatos_propia")
	var other := -1
	for i in range(cab.size()):
		if str((cab[i] as Dictionary)["party"]) != m.pid():
			other = i
			break
	if other >= 0:
		shell.close_modal()
		MinistrySheet.open(shell, m, other, "cands")
		await _shot("03_candidatos_socio")
	quit()
