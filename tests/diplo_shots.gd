extends SceneTree
## Capturas de la bandeja, la negociación, las reuniones y la investidura.
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/diplo_shots.gd -- <partido> <salida>

var out_dir := "/tmp/diplo"
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
	# Avanza varios días para llenar la bandeja
	for i in range(3):
		shell.on_continue()
		await _frames(1)
	shell.go("home")
	await _shot("00_resumen_pendientes")
	shell.go("inbox")
	await _shot("01_bandeja")
	shell.go("negotiation")
	await _shot("02_negociacion_campana")
	shell.open_meeting("sumar", "joint_list")
	await _shot("03_reunion_abierta")
	m.diplomacy.sound()
	m.diplomacy.add_term({"k": "cabinet", "by": "player", "n": 1})
	shell.refresh()
	await _shot("04_reunion_sondeada")
	m.diplomacy.submit()
	shell.refresh()
	await _shot("05_reunion_respuesta")
	for i in range(4):
		if m.diplomacy.active():
			m.diplomacy.submit()
	shell.refresh()
	await _shot("06_reunion_final")
	shell.go("negotiation")
	await _shot("07_pactos")
	# Elecciones y investidura
	m.day = Rules.CAMPAIGN_LENGTH_DAYS
	m.election.begin_night()
	m.election.skip_night()
	m.election.finish_night()
	m.gov.begin_investiture()
	m.gov.set_candidate(m.pid())
	shell.refresh_chrome()
	shell.go("investiture")
	await _shot("08_investidura")
	shell.open_meeting("erc", "investiture")
	m.diplomacy.sound()
	var menu := m.diplomacy.term_menu("erc", "investiture")
	for t in menu["give"]:
		if str((t as Dictionary)["k"]) == "policy":
			m.diplomacy.add_term(t)
			break
	m.diplomacy.submit()
	shell.refresh()
	await _shot("09_reunion_erc")
	shell.go("investiture")
	await _shot("10_investidura_tras_reunion")
	shell.go("negotiation")
	await _shot("11_negociacion_investidura")
	# Investidura con candidato de la IA (el jugador es minoría) y pacto por una ley
	m.gov.set_candidate(str(m.gov.parliamentary_ids()[0]) if not m.is_player(str(m.gov.parliamentary_ids()[0])) else str(m.gov.parliamentary_ids()[1]))
	shell.refresh_chrome()
	shell.go("investiture")
	await _shot("12_investidura_candidato_ia")
	shell.go("inbox")
	await _shot("13_oferta_candidato")
	m.phase = "legislature"
	var law := m.laws.new_draft("housing")
	var meas := Policies.measures_of("housing")[0] as Dictionary
	m.laws.set_change(law, str(meas["id"]), Policies.snap(meas, m.eco.value(str(meas["id"])) + float(meas["step"]) * 2.0))
	shell.go("negotiation")
	var tgt := "sumar" if m.seats_of("sumar") > 0 and not m.is_player("sumar") else "pp"
	shell.open_meeting(tgt, "law_deal")
	await _shot("14_elegir_ley")
	shell.close_modal()
	shell.open_meeting(tgt, "law_deal", {"law": str(law["id"])})
	m.diplomacy.sound()
	shell.refresh()
	await _shot("15_reunion_ley")
	m.diplomacy.submit()
	shell.refresh()
	await _shot("16_reunion_ley_respuesta")
	print("Capturas en ", out_dir)
	quit(0)
