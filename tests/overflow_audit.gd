extends SceneTree
## Mide cuánto se desborda cada pantalla (px de scroll vertical) en la ventana actual.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/overflow_audit.gd -- psoe
var shell: Control
var seen := {}
var rows: Array = []

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

## Desborde de una pantalla «de juego» (sin scroll): cuánto sobrepasa su min size el área disponible.
func _full_over() -> Vector2:
	var n: Control = shell.screen_node
	var avail: Vector2 = shell.full_holder.size - Vector2(16, 16)
	var mn := n.get_combined_minimum_size()
	return Vector2(maxf(0.0, mn.x - avail.x), maxf(0.0, mn.y - avail.y))

func _measure_full(tag: String, id: String, mode: String) -> void:
	var worst := Vector2.ZERO
	var worst_id := ""
	var areas_n := 0
	for a in Policies.areas():
		var aid := str((a as Dictionary)["id"])
		for it in Policies.measures_of(aid, mode == "program"):
			var mid := str((it as Dictionary)["id"])
			PolicyBrowser.memory[mode] = {"area": aid, "mid": mid}
			shell.go(id)
			await _frames(2)
			areas_n += 1
			var o := _full_over()
			if o.x + o.y > worst.x + worst.y:
				worst = o
				worst_id = mid
				if o.y > 0.0 or o.x > 0.0:
					DirAccess.make_dir_recursive_absolute("/tmp/ov")
					root.get_viewport().get_texture().get_image().save_png("/tmp/ov/%s_%s.png" % [id, mid])
	rows.append("%-14s %-12s FULL %d medidas · peor exceso x %d y %d (%s)" % [tag, id, areas_n, int(worst.x), int(worst.y), worst_id])

func _measure(tag: String) -> void:
	for id in shell.nav_ids():
		shell.go(str(id))
		await _frames(4)
		if shell.screen_node.fullscreen and str(id) == "inbox":
			var o2 := _full_over()
			rows.append("%-14s %-12s FULL exceso x %d y %d" % [tag, str(id), int(o2.x), int(o2.y)])
			if o2.x + o2.y > 0.0:
				DirAccess.make_dir_recursive_absolute("/tmp/ov")
				root.get_viewport().get_texture().get_image().save_png("/tmp/ov/inbox_%s.png" % tag)
			continue
		if shell.screen_node.fullscreen:
			await _measure_full(tag, str(id), "program" if str(id) == "program" else "gov")
			continue
		var vs: VScrollBar = shell.scroll.get_v_scroll_bar()
		var over := int(vs.max_value - vs.page)
		var rs: VScrollBar = (shell.rail_box.get_parent() as ScrollContainer).get_v_scroll_bar()
		var rover := int(rs.max_value - rs.page)
		if over > 0 and not FileAccess.file_exists("/tmp/ov/%s.png" % str(id)):
			DirAccess.make_dir_recursive_absolute("/tmp/ov")
			root.get_viewport().get_texture().get_image().save_png("/tmp/ov/%s.png" % str(id))
		var hh: HScrollBar = shell.scroll.get_h_scroll_bar()
		if _wide():
			rows.append("%-14s %-12s ANCHO MIN %d > %d" % [tag, str(id), int(_wide_px()), int(root.get_visible_rect().size.x)])
		rows.append("%-14s %-12s horiz %d main %5d  rail %5d  (vista %dx%d, área %d)" % [tag, str(id), maxi(0, int(hh.max_value - hh.page)), maxi(0, over), maxi(0, rover), int(root.get_visible_rect().size.x), int(root.get_visible_rect().size.y), int(vs.page)])

## Mesa de negociación con una mesa larga (todas las condiciones posibles, alerta y última oferta).
func _measure_mesa(tag: String, party: String, topic: String, extra: Dictionary = {}) -> void:
	var m: GameModel = shell.m
	shell.open_meeting(party, topic, extra)
	await _frames(4)
	if not m.diplomacy.active():
		rows.append("%-14s mesa %s/%s: no se pudo abrir" % [tag, party, topic])
		return
	m.diplomacy.sound()
	var menu := m.diplomacy.term_menu(party, topic)
	var n := 0
	for side in ["give", "ask"]:
		for t in (menu.get(side, []) as Array):
			if n >= 8:
				break
			m.diplomacy.add_term(t)
			n += 1
	shell.refresh()
	await _frames(4)
	var o := _full_over()
	rows.append("%-14s mesa %s/%s (%d términos) FULL exceso x %d y %d" % [tag, party, topic, m.diplomacy.current().get("table", []).size(), int(o.x), int(o.y)])
	for i in range(3):
		if m.diplomacy.active():
			m.diplomacy.submit()
	shell.refresh()
	await _frames(4)
	o = _full_over()
	rows.append("%-14s mesa tras rondas FULL exceso x %d y %d" % [tag, int(o.x), int(o.y)])
	if o.x + o.y > 0.0:
		DirAccess.make_dir_recursive_absolute("/tmp/ov")
		root.get_viewport().get_texture().get_image().save_png("/tmp/ov/mesa_%s.png" % tag)
	if m.diplomacy.active():
		m.diplomacy.leave()

func m_phase_is_campaign() -> bool:
	return str(shell.m.phase) == "campaign"

func _wide_px() -> float:
	var w := 0.0
	for n in [shell.scroll, shell.rail_box.get_parent()]:
		w = maxf(w, (n as Control).get_global_rect().end.x)
	return maxf(w, shell.scroll.get_global_rect().position.x + shell.content_holder.get_combined_minimum_size().x + (shell.rail_box.get_parent() as Control).size.x)

func _wide() -> bool:
	return _wide_px() > root.get_visible_rect().size.x + 1.0

func _initialize() -> void:
	_run()

func _modal_check(tag: String) -> void:
	await _frames(3)
	var layer: Control = shell.modal_layer
	if layer.get_child_count() == 0:
		return
	var r := Rect2()
	var stack: Array = [layer]
	var best := 0.0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is PanelContainer:
				var cc := c as Control
				best = maxf(best, cc.size.y)
	rows.append("%-14s MODAL panel alto máx %d / vista %d" % [tag, int(best), int(root.get_visible_rect().size.y)])

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pid := "psoe" if args.is_empty() else str(args[0])
	await _frames(2)
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == pid:
			party = p
	root.get_node("SaveManager").create_new_game(party)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(shell)
	await _frames(3)
	var m: GameModel = shell.m
	m.autosave = false
	await _measure("campaña-sinfirmar")
	m.manifesto.suggest()
	m.manifesto.sign()
	m.campaign.schedule(1, 11, "Entrevista", "Madrid", "")
	m.campaign.schedule(1, 16, "Mitin", "Sevilla", "")
	shell.refresh()
	await _measure("campaña")
	await _measure_mesa("campaña", "sumar", "joint_list")
	var guard := 0
	while m.phase == "campaign" and guard < 200:
		guard += 1
		for e in m.campaign.pending_today():
			m.campaign.resolve_auto(e)
		if str(m.campaign.smart_continue()["stop"]) == "election":
			break
	m.election.begin_night()
	shell.refresh()
	await _measure("noche")
	var steps := 0
	var legis := 0
	const PREFER := ["Participar en persona", "Celebrar el acto", "Continuar", "Entendido", "Celebrar la votación", "Ir a la noche electoral", "Continuar igualmente"]
	while steps < 400:
		steps += 1
		if not seen.has(m.phase) and m.phase != "campaign":
			seen[m.phase] = true
			await _measure(m.phase)
		# modales
		var pressed := false
		var g2 := 0
		while g2 < 10:
			g2 += 1
			var buttons: Array = []
			var st: Array = [shell.modal_layer]
			while not st.is_empty():
				var n: Node = st.pop_back()
				for c in n.get_children():
					st.append(c)
					if c is Button:
						buttons.append(c)
			if buttons.is_empty():
				break
			await _modal_check("modal-" + m.phase)
			var chosen: Button = null
			for pref in PREFER:
				for b in buttons:
					if (b as Button).text == pref and not (b as Button).disabled:
						chosen = b
						break
				if chosen != null:
					break
			if chosen == null:
				for b2 in buttons:
					if not (b2 as Button).disabled and (b2 as Button).text != "Cancelar":
						chosen = b2
						break
			if chosen == null:
				break
			chosen.pressed.emit()
			pressed = true
			await _frames(2)
		if pressed:
			continue
		if m.phase == "legislature":
			legis += 1
			if legis == 2:
				await _measure("legislatura")
			if m.congress.pending():
				if legis < 6:
					shell.go("plenary")
					await _frames(3)
					await _measure_one("pleno-pendiente", "plenary")
				m.congress.auto_finish()
				shell.refresh()
			if legis > 6:
				break
		match m.phase:
			"election_night":
				shell.go("night")
				await _frames(1)
				shell.screen_node._skip()
				shell.screen_node._finish()
				continue
			"investiture":
				if not seen.has("mesa-inv"):
					seen["mesa-inv"] = true
					# Con el jugador de candidato se negocia «investiture» con cualquiera; con un candidato de la IA, «partner» con él.
					var inv_party := m.gov.candidate_id()
					var inv_topic := "partner"
					if m.is_player(m.gov.candidate_id()):
						inv_topic = "investiture"
						for pp in m.all_parties():
							var pid2 := str((pp as Dictionary).get("id", ""))
							if not m.is_player(pid2) and m.seats_of(pid2) >= 3 and bool(m.diplomacy.can_meet(pid2)["ok"]) and m.brain.blocked_by(pid2, m.pid()) == "":
								inv_party = pid2
								break
					await _measure_mesa("investidura", inv_party, inv_topic)
				if m.is_player(m.gov.candidate_id()):
					for id in m.gov.offers().keys():
						for k in range(((m.gov.offers()[id] as Dictionary)["demands"] as Array).size()):
							m.gov.set_concession(str(id), k, true)
						m.gov.propose(str(id))
				elif m.gov.offers().has(m.pid()):
					m.gov.propose_as_partner()
		shell.on_continue()
		await _frames(2)
	print("===== AUDITORÍA DE DESBORDE =====")
	for r in rows:
		print(r)
	quit()

func _measure_one(tag: String, id: String) -> void:
	shell.go(id)
	await _frames(4)
	var vs: VScrollBar = shell.scroll.get_v_scroll_bar()
	rows.append("%-14s %-12s main %5d  (área %d)" % [tag, id, maxi(0, int(vs.max_value - vs.page)), int(vs.page)])
