extends SceneTree
## Capturas de la pantalla de investidura. Uso: ... -- <partido> <salida>
var out_dir := "/tmp/inv_shots"
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

func _to_investiture(m: GameModel) -> void:
	m.autosave = false
	while m.phase == "campaign":
		for ev in m.campaign.pending_today():
			var evd: Dictionary = ev
			if m.campaign.is_interview_type(str(evd["type"])):
				var sess := m.enc.build_session(evd)
				for q in sess["questions"]:
					m.enc.resolve(sess, q as Dictionary, ((q as Dictionary)["answers"] as Array)[0] as Dictionary)
				m.enc.finish(sess, evd)
			else:
				m.campaign.resolve_auto(evd)
		var res := m.campaign.smart_continue()
		if str(res["stop"]) == "election": m.election.begin_night()
	while not m.election.night_finished():
		if m.election.reveal_next().is_empty(): break
	m.election.finish_night()
	m.gov.begin_investiture()

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
	_to_investiture(m)
	m.autosave = false
	# Si el jugador es el candidato, cierra todos los pactos posibles
	if m.is_player(m.gov.candidate_id()):
		for id in m.gov.offers().keys():
			var offer: Dictionary = m.gov.offers()[id]
			for i in range((offer["demands"] as Array).size()):
				m.gov.set_concession(str(id), i, true)
			m.gov.propose(str(id))
	shell.refresh_chrome()
	shell.go("investiture")
	await _frames(4)
	await _shot("01_pantalla_investidura")
	var b: InvestitureBroadcast = shell.open_investiture_vote()
	await _shot("02_intro")
	b._begin_voting()
	b._acc = 120.0
	await _frames(10)
	await _shot("03_votando_mitad")
	b._acc = 350.0
	await _frames(8)
	await _shot("04_resultado")
	print("resultado: ", b.result.get("passed"), " ", (b.session["tally"] as Dictionary))
	b._on_continue()
	await _frames(6)
	print("fase tras votar: ", m.phase)
	await _shot("05_tras_votar")
	var last := m.ivote.last()
	var rb: InvestitureBroadcast = shell.open_investiture_vote(last)
	rb._acc = 200.0
	await _frames(6)
	await _shot("06_repeticion")
	rb._on_close()
	await _frames(3)
	print("overlay cerrado: ", shell.get_node_or_null("InvestitureBroadcast") == null)
	quit()
