extends SceneTree
## Capturas del Parlamento (Taller de iniciativas y Pleno interactivo) a 1920×1080.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 --script res://tests/parliament_shots.gd -- <partido> <salida>

var out_dir := "/tmp/parl"
var shell: Control
var errors := 0

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

func _to_legislature(m: GameModel) -> void:
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
		if str(res["stop"]) == "election":
			m.election.begin_night()
	while not m.election.night_finished():
		if m.election.reveal_next().is_empty():
			break
	m.election.finish_night()
	m.gov.begin_investiture()
	var attempts := 0
	while m.phase == "investiture" and attempts < 12:
		attempts += 1
		if m.gov.candidate_id() == m.pid():
			for id in m.gov.offers().keys():
				var offer: Dictionary = m.gov.offers()[id]
				for i in range((offer["demands"] as Array).size()):
					m.gov.set_concession(str(id), i, true)
				m.gov.propose(str(id))
		elif m.gov.offers().has(m.pid()):
			m.gov.propose_as_partner()
		var vote := m.gov.hold_vote()
		if bool(vote["dissolved"]):
			break
	if m.phase == "cabinet_design":
		m.gov.form_government()

func _law(m: GameModel, area: String, kind: String = "ley", steps: int = 2) -> Dictionary:
	var law := m.laws.new_draft(area, kind)
	var added := 0
	for it in Policies.measures_of(area):
		var meas: Dictionary = it
		if added >= 3:
			break
		var cur := m.eco.value(str(meas["id"]))
		var nv := Policies.snap(meas, cur + float(meas["step"]) * steps)
		if not is_equal_approx(nv, cur):
			m.laws.set_change(law, str(meas["id"]), nv)
			added += 1
	return law

func _wait_reveal() -> void:
	var guard := 0
	while PlenaryScreen.phase == "reveal" and guard < 400:
		await _frames(2)
		guard += 1

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
	m.rng.seed = 11
	_to_legislature(m)
	shell.refresh_chrome()
	print("Fase: ", m.phase)
	# Una ley, una PNL y una interpelación del jugador en cola + leyes de la IA
	var areas := ["housing", "health", "education"]
	var area_ids: Array = []
	for a in Policies.areas():
		area_ids.append(str((a as Dictionary)["id"]))
	var ley := _law(m, str(area_ids[0]))
	print("registro ley: '", m.laws.register(str(ley["id"])), "'")
	var pnl := _law(m, str(area_ids[1]), "pnl")
	print("registro pnl: '", m.laws.register(str(pnl["id"])), "'")
	var inter := m.laws.new_draft(str(area_ids[2]), "interpelacion")
	print("registro interpelación: '", m.laws.register(str(inter["id"])), "'")
	m.gov_month += 1
	m.congress.open_session()
	# Asegura que haya leyes de la IA
	var guard := 0
	while m.congress.laws().size() < 4 and guard < 8:
		guard += 1
		var opp := ""
		for id in m.gov.parliamentary_ids():
			if not m.is_player(str(id)) and m.seats_of(str(id)) > 20 and opp == "":
				opp = str(id)
		var al := m.laws.generate_ai_law(opp)
		if not al.is_empty():
			m.congress.laws().append(al)
	m.congress.session()["stage"] = "ready"
	print("orden del día: ", m.congress.laws().size())
	# ---- Taller (antes de abrir sesión: se prueba con borradores nuevos)
	LawsScreen.editing_id = ""
	shell.go("laws")
	await _shot("20_taller_inicio")
	shell.screen_node._open_new()
	await _shot("21_taller_ventana_nueva")
	shell.close_modal()
	shell.screen_node._open_drafts()
	await _shot("21b_taller_ventana_borradores")
	shell.close_modal()
	shell.screen_node._open_program()
	await _shot("21c_taller_ventana_programa")
	shell.close_modal()
	var dl := m.laws.new_draft(str(area_ids[3]))
	m.laws.set_change(dl, str(Policies.measures_of(str(area_ids[3]))[0]["id"]), Policies.snap(Policies.measures_of(str(area_ids[3]))[0], m.eco.value(str(Policies.measures_of(str(area_ids[3]))[0]["id"])) + float(Policies.measures_of(str(area_ids[3]))[0]["step"]) * 2.0))
	LawsScreen.editing_id = str(dl["id"])
	LawsScreen.tab_area = str(area_ids[3])
	shell.go("laws")
	await _shot("22_taller_editor_ley")
	shell.refresh()
	var idr := m.laws.new_draft(str(area_ids[2]), "interpelacion")
	LawsScreen.editing_id = str(idr["id"])
	shell.go("laws")
	await _shot("23_taller_editor_interpelacion")
	LawsScreen.editing_id = str(ley["id"]) if false else ""
	m.laws.delete_draft(str(dl["id"]))
	m.laws.delete_draft(str(idr["id"]))
	shell.go("laws")
	await _shot("24_taller_inicio_registradas")
	PlenaryScreen._reset_ui_static()
	shell.go("plenary")
	await _shot("01_pleno_orden")
	m.congress.begin()
	PlenaryScreen._reset_ui_static()
	PlenaryScreen.fast = false
	shell.go("plenary")
	await _shot("02_pleno_presentacion")
	var scr: PlenaryScreen = shell.screen_node
	scr._on_open_debate()
	await _shot("03_pleno_enmiendas")
	scr = shell.screen_node
	scr._on_to_vote()
	await _shot("04_pleno_votar")
	scr = shell.screen_node
	PlenaryScreen.fast = false
	scr._on_vote("yes")
	await create_timer(2.4).timeout
	await _shot("05_pleno_votando")
	PlenaryScreen.fast = true
	await _wait_reveal()
	await _frames(40)
	await _shot("06_pleno_resultado")
	# Siguiente iniciativa (ley de la IA): enmiendas del jugador
	PlenaryScreen.fast = true
	shell.screen_node._on_next()
	await _frames(3)
	shell.screen_node._on_open_debate()
	await _shot("07_pleno_enmiendas_ia")
	var hops := 0
	while m.is_player(str(m.congress.current()["proposer"])) and hops < 6:
		hops += 1
		shell.screen_node._on_to_vote()
		shell.screen_node._on_vote("abstain")
		await _wait_reveal()
		await _frames(10)
		shell.screen_node._on_next()
		await _frames(3)
		shell.screen_node._on_open_debate()
		await _frames(3)
	if not m.is_player(str(m.congress.current()["proposer"])):
		await _shot("07b_pleno_enmiendas_ley_ia")
		shell.screen_node._on_open_amend()
		await _shot("08a_pleno_redactar_enmienda")
		var opts := m.congress.amend.player_options(m.congress.current())
		if not opts.is_empty():
			var t0: Dictionary = opts[0]
			shell.screen_node._on_am_pick(str(t0["measure"]))
			shell.screen_node._on_am_value(float(t0["value"]))
			await _shot("08b_pleno_redactar_valor")
			shell.screen_node._on_am_present()
			await _shot("08c_pleno_enmienda_resultado")
		else:
			shell.screen_node._on_am_close()
	shell.screen_node._on_to_vote()
	shell.screen_node._on_vote("no")
	await _wait_reveal()
	await _frames(20)
	await _shot("09_pleno_resultado_ia")
	# Resto: avanzar hasta que aparezca una interpelación o termine
	var rounds := 0
	while m.congress.stage() == "running" and rounds < 8:
		rounds += 1
		shell.screen_node._on_next()
		await _frames(3)
		var law := m.congress.current()
		if law.is_empty():
			break
		if str(law.get("kind", "")) == "interpelacion":
			await _shot("10_pleno_interpelacion")
			shell.screen_node._on_interpelar()
			await create_timer(0.9).timeout
			await _shot("11_pleno_interpelacion_resultado")
			continue
		if m.congress.amend.supports(law):
			shell.screen_node._on_open_debate()
		else:
			shell.screen_node._on_to_vote()
		shell.screen_node._on_to_vote()
		shell.screen_node._on_vote("abstain")
		await _wait_reveal()
		await _frames(10)
	shell.screen_node._on_next()
	await _frames(3)
	await _shot("12_pleno_resumen")
	print("errores: ", errors)
	quit(0)
