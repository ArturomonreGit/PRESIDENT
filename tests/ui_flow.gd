extends SceneTree
## Juega la partida solo con el botón CONTINUAR y los diálogos, como lo haría una persona.
## Uso: godot --headless --path . --script res://tests/ui_flow.gd -- <partido>

var shell: Control
var steps := 0
const PREFER := ["Participar en persona", "Celebrar el acto", "Continuar", "Entendido", "Celebrar la votación", "Ir a la noche electoral", "Continuar igualmente"]

func _frames(n: int = 2) -> void:
	for i in range(n):
		await process_frame

func _press_modal() -> bool:
	var layer: Control = shell.modal_layer
	if layer.get_child_count() == 0:
		return false
	var buttons: Array = []
	_collect(layer, buttons)
	if buttons.is_empty():
		return false
	for pref in PREFER:
		for b in buttons:
			if (b as Button).text == pref and not (b as Button).disabled:
				(b as Button).pressed.emit()
				return true
	for b in buttons:
		if not (b as Button).disabled and (b as Button).text != "Cancelar" and (b as Button).text != "Seguir negociando":
			(b as Button).pressed.emit()
			return true
	return false

func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_collect(c, out)

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pid := "psoe" if args.is_empty() else str(args[0])
	await _frames(2)
	var party: Dictionary = {}
	if pid == "custom":
		party = {"id": "custom_player", "name": "Partido Test", "short_name": "PT", "color": "#E0A93B", "is_custom": true,
			"ideology": {"economic": 0.1, "social": -0.2, "territorial": 0.2}, "ideology_profile": {"ecologismo": 70, "europeismo": 60}}
	elif pid == "regional":
		party = {"id": "custom_player", "name": "Compromiso Territorial", "short_name": "CT", "color": "#E85D04", "is_custom": true,
			"ideology": {"economic": -0.1, "social": -0.2, "territorial": 0.8}, "ideology_profile": {"regionalismo": 80}, "territory": ["Cataluña"]}
	else:
		for p in DataStore.parties():
			if str((p as Dictionary)["id"]) == pid:
				party = p
	root.get_node("SaveManager").create_new_game(party)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	shell.m.autosave = false
	var m: GameModel = shell.m
	var seen := {}
	if pid == "regional":
		shell.go("map")
		await _frames(2)
		m.funds = 1000000.0
		m.campaign.expand_territory("Galicia")
		shell.go("map")
		await _frames(2)
		print("Mapa territorial ok: ", m.s["player_territory"])
	var legislature_months := 0
	while steps < 900:
		steps += 1
		seen[m.phase] = true
		if await _drain():
			continue
		if m.phase == "legislature":
			legislature_months += 1
			if legislature_months > 8:
				break
			if m.congress.pending():
				shell.on_continue()
				await _frames(2)
				if shell.current != "plenary":
					print("ERROR: el botón no abre el Pleno")
				m.congress.auto_finish()
				shell.refresh()
				await _frames(2)
		match m.phase:
			"election_night":
				shell.go("night")
				await _frames(1)
				shell.screen_node._skip()
				shell.screen_node._finish()
				await _frames(1)
				continue
			"investiture":
				if m.is_player(m.gov.candidate_id()):
					for id in m.gov.offers().keys():
						for k in range(((m.gov.offers()[id] as Dictionary)["demands"] as Array).size()):
							m.gov.set_concession(str(id), k, true)
						m.gov.propose(str(id))
				elif m.gov.offers().has(m.pid()):
					m.gov.propose_as_partner()
			"campaign":
				if m.day == 1 and m.campaign.events().is_empty():
					m.campaign.schedule(1, 11, "Entrevista", "Madrid", "")
					m.campaign.schedule(1, 16, "Mitin", "Sevilla", "")
					m.manifesto.suggest()
					m.manifesto.sign()
		shell.on_continue()
		await _frames(1)
	print("Fases vistas: ", ", ".join(seen.keys()), " · pasos: ", steps, " · fase final: ", m.phase, " (mes ", m.gov_month, ")")
	quit(0)

## Si hay un plató abierto, lo juega entero (siempre la primera respuesta) y sale con el botón del balance.
func _drive_studio() -> bool:
	var st: Node = shell.get_node_or_null("MediaStudio")
	if st == null:
		return false
	var guard := 0
	while is_instance_valid(st) and guard < 80:
		guard += 1
		match str(st.phase):
			"intro", "reaction":
				st._advance()
			"question":
				st._typed = 1.0
				st._answer((st.cur_q["answers"] as Array)[0] as Dictionary, false)
			"end":
				var buttons: Array = []
				_collect(st.overlay, buttons)
				for b in buttons:
					if (b as Button).text.begins_with("Salir del plató"):
						(b as Button).pressed.emit()
		await _frames(1)
	return true

func _drain() -> bool:
	var did := false
	var guard := 0
	if await _drive_studio():
		did = true
	while guard < 12 and _press_modal():
		did = true
		guard += 1
		await _frames(1)
	return did
