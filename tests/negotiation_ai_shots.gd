extends SceneTree
## Capturas de la mesa con las categorías nuevas, borradores, versiones y estados.
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/negotiation_ai_shots.gd -- <partido> <salida>
var out_dir := "/tmp/nego_ai"
var shell: Control

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	await _frames(5)
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
	NightScreen.auto_open = false
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	root.get_node("SaveManager").create_new_game(party)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	var waited := 0
	while str(shell.m.s.get("history_mode", "")) == "" and waited < 900:
		await _frames(1)
		waited += 1
	await _frames(20)
	var m: GameModel = shell.m
	m.autosave = false
	m.manifesto.suggest()
	m.manifesto.sign()
	m.rng.seed = 7
	m.day = Rules.CAMPAIGN_LENGTH_DAYS
	m.election.begin_night()
	m.election.skip_night()
	m.election.finish_night()
	m.gov.begin_investiture()
	m.gov.set_candidate(m.pid())
	shell.refresh_chrome()
	var target := ""
	var best_c := -1.0
	for p2 in m.all_parties():
		var id := str((p2 as Dictionary)["id"])
		if m.is_player(id) or m.seats_of(id) < 8: continue
		if m.brain.blocked_by(id, m.pid()) != "": continue
		if not bool(m.diplomacy.can_meet(id)["ok"]): continue
		if m.brain.compat(id, m.pid()) > best_c:
			best_c = m.brain.compat(id, m.pid())
			target = id
	print("interlocutor: ", target)
	shell.open_meeting(target, "investiture", {"agenda": true})
	await _shot("01_apertura")
	m.diplomacy.sound()
	m.diplomacy.add_term({"k": "portfolio", "comp": "vivienda", "by": "player"})
	m.diplomacy.add_term(m.brain.objective_term("housing", 2))
	m.diplomacy.add_term({"k": "structure", "what": "vicepresidency", "by": "player"})
	m.diplomacy.add_term({"k": "participation", "mode": "external", "by": "ai"})
	m.diplomacy.add_term({"k": "calendar", "what": "review", "n": 6, "by": "player"})
	m.diplomacy.save_draft("Plan con vicepresidencia")
	shell.refresh()
	await _shot("02_tabla_categorias")
	# Peticiones costosas para forzar una contraoferta y que quede historial de versiones.
	m.diplomacy.add_term({"k": "parliament", "what": "budget_vote", "by": "ai"})
	m.diplomacy.add_term({"k": "bills", "by": "ai", "n": 3})
	m.diplomacy.add_term({"k": "cabinet", "by": "ai", "n": 2})
	m.diplomacy.submit()
	shell.refresh()
	await _shot("03_respuesta_y_estados")
	var MS := load("res://scripts/ui/screens/meeting_screen.gd")
	MS.tab = "territorio"
	shell.refresh()
	await _shot("04_categoria_territorio")
	MS.panel = "drafts"
	shell.refresh()
	await _shot("05_borradores")
	MS.panel = "versions"
	MS.cmp_index = 0
	shell.refresh()
	await _shot("06_versiones_comparar")
	MS.panel = ""
	MS.replace_idx = 0
	shell.refresh()
	await _shot("07_sustituir")
	MS.replace_idx = -1
	m.diplomacy.request_counter()
	shell.refresh()
	await _shot("08_contraoferta_pedida")
	quit()
