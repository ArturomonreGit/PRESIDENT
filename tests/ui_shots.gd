extends SceneTree
## Recorre la interfaz real, avanza la partida y guarda capturas de cada pantalla.
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/ui_shots.gd -- <partido> <carpeta_salida>

var out_dir := "/tmp/shots"
var shell: Control
var errors := 0

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	await _frames(3)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])

func _open_main() -> void:
	if shell != null:
		shell.queue_free()
		await _frames(2)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)

func _all_screens(prefix: String) -> void:
	for id in shell.nav_ids():
		shell.go(str(id))
		await _shot("%s_%s" % [prefix, id])

func _phase3(m: GameModel) -> void:
	# Rol ministerial: presidente con todos los ministerios y ministro con una sola cartera
	m.s["government_party_id"] = m.pid()
	m.exec.on_government_formed()
	var owners := m.exec.area_owners()
	MinistryScreen.sel_idx = int(owners["health"])
	MinistryScreen.tab = "ministry"
	PanelScreen.pending = {"health_budget": m.eco.value("health_budget") + 10.0, "waiting_lists": 1.0}
	shell.refresh()
	shell.go("ministry")
	await _shot("80_cartera_presidente")
	m.exec.open_pge()
	MinistryScreen.tab = "budget"
	shell.go("ministry")
	await _shot("81_presupuestos_borrador")
	var other := "pp" if m.pid() != "pp" else "psoe"
	m.s["government_party_id"] = other
	var mine := 3
	for i in range(m.gov.cabinet().size()):
		(m.gov.cabinet()[i] as Dictionary)["party"] = m.pid() if i == mine else other
	m.exec.on_government_formed()
	m.exec.set_post(mine)
	MinistryScreen.tab = "ministry"
	PanelScreen.pending = {}
	shell.refresh()
	shell.go("ministry")
	await _shot("82_cartera_ministro")
	shell.go("cabinet")
	await _shot("83_consejo_competencias")

func _phase2(m: GameModel) -> void:
	# Taller de leyes
	var law := m.laws.new_draft("housing")
	m.laws.set_change(law, "rent_cap", 2.0)
	m.laws.set_change(law, "social_housing", 8.0)
	LawsScreen.editing_id = str(law["id"])
	LawsScreen.tab_area = ""
	shell.go("laws")
	await _shot("70_taller_editor")
	m.laws.register(str(law["id"]))
	LawsScreen.editing_id = ""
	shell.refresh()
	shell.go("laws")
	await _shot("72_taller_inicio")
	# Pleno
	shell.go("plenary")
	await _shot("73_pleno_orden")
	m.congress.begin()
	PlenaryScreen._reset_ui_static()
	shell.go("plenary")
	await _shot("74_pleno_ley")
	PlenaryScreen.fast = true
	if shell.screen_node.has_method("_on_open_debate"):
		shell.screen_node._on_open_debate()
	shell.screen_node._on_to_vote()
	await _shot("75_pleno_votar")
	shell.screen_node._on_vote("yes")
	await _frames(30)
	await _shot("76_pleno_resultado")
	m.congress.auto_finish()
	shell.go("plenary")
	await _shot("77_pleno_resumen")
	shell.go("country")
	await _shot("78_pais")
	shell.go("cabinet")
	await _shot("80_consejo")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var party_id := "psoe" if args.size() < 1 else str(args[0])
	if args.size() > 1:
		out_dir = str(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(party_id)

func _run(party_id: String) -> void:
	await _frames(2)
	var sm := root.get_node("SaveManager")
	# Menú de inicio
	var st: Control = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	root.add_child(st)
	await _frames(3)
	await _shot("00_inicio")
	st.show_new()
	await _shot("01_nueva")
	st.show_settings()
	await _shot("03_ajustes")
	st.queue_free()
	await _frames(2)
	# Partida
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id:
			party = p
	sm.create_new_game(party)
	await _open_main()
	var m: GameModel = shell.m
	m.autosave = false
	await _all_screens("10_campana")
	# Programa y agenda
	shell.go("program")
	await _shot("10_programa_vacio")
	m.manifesto.suggest()
	shell.go("program")
	await _shot("10_programa_borrador")
	m.manifesto.sign()
	m.campaign.schedule(1, 11, "Mitin", "Madrid", "")
	m.campaign.schedule(1, 16, "Entrevista", "Barcelona", "")
	m.campaign.schedule(2, 11, "Debate", "Sevilla", "")
	m.campaign.schedule(3, 9, "Recaudación de fondos", "Valencia", "")
	shell.go("agenda")
	await _shot("11_agenda")
	shell.go("home")
	await _shot("12_home_con_actos")
	# Jugar el primer acto (modal)
	shell.on_continue()
	await _shot("13_modal_acto")
	shell.close_modal()
	# Entrevista en persona
	var ev: Dictionary = m.campaign.events_on(1)[1]
	shell._run_interview(ev, Callable())
	await _shot("14_modal_entrevista")
	shell.close_modal()
	# Avanzar jugando todo por delegación
	var guard := 0
	while m.phase == "campaign" and guard < 200:
		guard += 1
		for e in m.campaign.pending_today():
			m.campaign.resolve_auto(e)
		var res := m.campaign.smart_continue()
		if str(res["stop"]) == "election":
			break
	shell.refresh()
	shell.go("polls")
	await _shot("15_encuestas_final")
	shell.go("map")
	await _shot("16_mapa_final")
	shell.go("inbox")
	await _shot("17_bandeja")
	# Noche electoral
	NightScreen.auto_open = false
	m.election.begin_night()
	shell.go("night")
	await _shot("20_noche_inicio")
	var nscr = shell.screen_node
	for i in range(30):
		nscr._step()
	await _shot("21_noche_mitad")
	nscr._skip()
	await _shot("22_noche_fin")
	nscr._finish()
	await _all_screens("30_resultados")
	# Investidura
	shell.on_continue()
	await _shot("40_investidura")
	await _all_screens("41_investidura")
	shell.go("investiture")
	shell.confirm_vote()
	await _shot("42_modal_voto")
	shell.close_modal()
	# Si el jugador es candidato, concede todo y propone
	var attempts := 0
	while m.phase == "investiture" and attempts < 10:
		attempts += 1
		if m.is_player(m.gov.candidate_id()):
			for id in m.gov.offers().keys():
				var offer: Dictionary = m.gov.offers()[id]
				for i in range((offer["demands"] as Array).size()):
					m.gov.set_concession(str(id), i, true)
				m.gov.propose(str(id))
		elif m.gov.offers().has(m.pid()):
			m.gov.propose_as_partner()
		shell.refresh()
		if attempts == 1:
			shell.go("investiture")
			await _shot("43_investidura_negociada")
		var vote := m.gov.hold_vote()
		if bool(vote["dissolved"]):
			break
	shell.refresh()
	print("Fase tras investidura: ", m.phase)
	if m.phase == "cabinet_design":
		shell.go("cabinet")
		await _shot("50_gabinete")
		shell.on_continue()
		await _frames(2)
		shell.close_modal()
		await _all_screens("60_legislatura")
		await _phase2(m)
		await _phase3(m)
		for i in range(6):
			m.gov.advance_turn()
		shell.refresh()
		shell.go("government")
		await _shot("61_gobierno_mes6")
		shell.go("inbox")
		await _shot("62_bandeja_gob")
	print("Capturas en ", out_dir)
	quit(0)
