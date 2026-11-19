extends SceneTree
## Abre la retransmisión de la noche electoral y guarda capturas de cada escena.
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/night_shots.gd -- <partido> <carpeta>

var out_dir := "/tmp/night"
var shell: Control
var bc: NightBroadcast

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	await _frames(4)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])

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
	m.election.begin_night()
	NightScreen.auto_open = false
	shell.go("night")
	await _shot("00_landing")
	bc = NightBroadcast.open(shell, m)
	await _frames(40)
	await _shot("01_intro")
	bc._on_play()          # sondeo
	await _frames(70)
	await _shot("02_sondeo")
	bc._on_play()          # empieza el recuento
	bc.auto = false
	for i in range(14):
		bc._do_cut()
	await _frames(30)
	bc._show_scene("results")
	await _frames(70)
	await _shot("03_resultados_t14")
	bc._show_scene("map")
	await _frames(60)
	await _shot("04_mapa_t14")
	for i in range(20):
		bc._do_cut()
	bc._show_scene("hemi")
	await _frames(70)
	await _shot("05_hemiciclo_t34")
	bc._show_scene("contested")
	await _frames(40)
	await _shot("06_enjuego_t34")
	bc._show_scene("evolution")
	await _frames(40)
	await _shot("07_evolucion_t34")
	bc._show_scene("choose")
	await _frames(40)
	await _shot("08_tueliges_t34")
	var sc = bc.scene
	if sc.picks.size() > 0:
		sc.detail = str((sc.picks[0] as Dictionary)["name"])
		sc._rows = bc.province_rows(sc.detail)
		await _frames(10)
		await _shot("09_tueliges_detalle")
	bc._show_scene("choose")
	await _frames(20)
	var sc2 = bc.scene
	sc2.detail = "Andalucía"
	sc2._rows = bc.province_rows("Andalucía")
	await _frames(10)
	await _shot("09b_tueliges_andalucia")
	bc._show_scene("map")
	await _frames(60)
	await _shot("10_mapa_votos")
	bc._queue_pill("VUELCO", "psoe", "pnv", "Bizkaia", "le quita")
	await _frames(60)
	await _shot("11_vuelco")
	for i in range(60):
		bc._do_cut()
	await _frames(20)
	bc._show_scene("hemi")
	await _frames(70)
	await _shot("12_hemiciclo_final")
	await _frames(100)
	await _shot("13_final")
	print("Capturas en ", out_dir, " tick=", m.election.night_tick(), " fase=", bc.phase)
	quit(0)
