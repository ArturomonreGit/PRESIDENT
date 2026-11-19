extends SceneTree
## Abre el plató de medios en cada formato, juega una sesión completa y guarda capturas.
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/media_shots.gd -- <partido> <carpeta>

var out_dir := "/tmp/media"
var shell: Control
var fails := 0

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

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FALLO: ", msg)

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
	for t: String in ["Entrevista", "Podcast", "Rueda de prensa", "Debate", "Sesión de control"]:
		var tag: String = t.to_lower().replace(" ", "_").replace("ó", "o")
		var st: MediaStudio = shell.play_studio({"type": t, "title": "Prueba", "region": "Madrid", "hour": 20}, Callable())
		await _frames(30)
		await _shot("%s_0_intro" % tag)
		st._advance()
		var n := 0
		var guard := 0
		while st.phase != "end" and guard < 30:
			guard += 1
			await _frames(6)
			st._typed = 1.0
			st.q_text.visible_ratio = 1.0
			await _frames(30)
			if st.phase == "question":
				if n == 0:
					await _shot("%s_1_pregunta" % tag)
					st._ask_advisor()
					await _frames(4)
					await _shot("%s_2_asesor" % tag)
				var answers: Array = st.cur_q["answers"]
				_check(answers.size() >= 2, "pocas respuestas en %s" % t)
				_check(str(st.cur_q["text"]).find("{") < 0, "hueco sin rellenar: %s" % str(st.cur_q["text"]))
				_check(str(st.cur_q["text"]).strip_edges() != "", "pregunta vacía")
				st._answer(answers[n % answers.size()] as Dictionary, false)
				await _frames(10)
				if n == 0:
					await _shot("%s_3_reaccion" % tag)
				n += 1
			if st.phase == "reaction":
				st._advance()
		_check(st.phase == "end", "no terminó %s" % t)
		await _frames(10)
		await _shot("%s_4_balance" % tag)
		st.queue_free()
		await _frames(3)
	print("Capturas en ", out_dir, " fallos=", fails)
	quit(1 if fails > 0 else 0)
