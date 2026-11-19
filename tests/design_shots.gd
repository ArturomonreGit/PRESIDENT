extends SceneTree
## Capturas del rediseño (indicadores, panel de gobierno…). Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/design_shots.gd -- psoe /tmp/design [pantallas…]
var out_dir := "/tmp/design"
var shell: Control

func _dump(n: Node, depth: int, limit: float) -> void:
	if n is Control and (n as Control).get_combined_minimum_size().x >= limit and depth < 9:
		print("      ".repeat(0), "  ".repeat(depth), n.get_class(), " ", n.name, " min.x=", (n as Control).get_combined_minimum_size().x)
		for c in n.get_children():
			_dump(c, depth + 1, limit)

func _dump_h(n: Node, depth: int) -> void:
	if n is Control and depth < 7:
		var c := n as Control
		print("  ".repeat(depth), n.get_class(), " ", n.name, " size=", c.size, " min=", c.get_combined_minimum_size())
		for ch in n.get_children():
			_dump_h(ch, depth + 1)

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
	var screens: Array = ["country"] if args.size() < 3 else Array(args.slice(2))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(party_id, screens)

func _fast_gov(m: GameModel) -> void:
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

func _run(party_id: String, screens: Array) -> void:
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
	var waited := 0
	while str(m.s.get("history_mode", "")) == "" and waited < 600:
		await _frames(1)
		waited += 1
	await create_timer(0.8).timeout
	m.rng.seed = 42
	if OS.get_environment("PHASE") == "campaign":
		for id0 in screens:
			var p0 := str(id0).split(":")
			if p0[0] == "program" and p0.size() > 2:
				PolicyBrowser.memory["program"] = {"area": str(p0[1]), "mid": str(p0[2])}
				if p0.size() > 3:
					PolicyBrowser.program_pending[str(p0[2])] = float(p0[3])
			shell.go(str(p0[0]))
			await _frames(2)
			await _shot(str(id0).replace(":", "_"))
			if OS.get_environment("DUMP") != "":
				print("SHELL ", shell.size, " scroll ", shell.scroll.size, " scrollmin ", shell.scroll.get_combined_minimum_size(), " margin ", shell.margin_box.size, " rail ", shell.rail_panel.size, " vp ", root.size)
				_dump_h(shell.content_holder.get_child(0).get_child(1), 0)
		print("Capturas en ", out_dir)
		quit()
		return
	var role := OS.get_environment("ROLE") if OS.get_environment("ROLE") != "" else "president"
	_fast_gov(m)
	print("fase ", m.phase, " rol ", m.role(), " cartera ", m.exec.post_text())
	if role == "president":
		m.s["government_party_id"] = m.pid()
		m.exec.on_government_formed()
	elif role == "minister":
		var other := "pp" if m.pid() != "pp" else "psoe"
		m.s["government_party_id"] = other
		for i in range(m.gov.cabinet().size()):
			if i == 3:
				(m.gov.cabinet()[i] as Dictionary)["party"] = m.pid()
			elif str((m.gov.cabinet()[i] as Dictionary)["party"]) == m.pid():
				(m.gov.cabinet()[i] as Dictionary)["party"] = other
		m.exec.on_government_formed()
		m.exec.set_post(3)
	elif role == "opposition":
		var other2 := "pp" if m.pid() != "pp" else "psoe"
		m.s["government_party_id"] = other2
		for i2 in range(m.gov.cabinet().size()):
			if str((m.gov.cabinet()[i2] as Dictionary)["party"]) == m.pid():
				(m.gov.cabinet()[i2] as Dictionary)["party"] = other2
		m.exec.on_government_formed()
	print("rol final ", m.role(), " cartera ", m.exec.post_text())
	m.eco.set_value("vat_general", 23.0)
	m.eco.set_value("min_wage", 1250.0)
	m.eco.set_value("rent_cap", 2.0)
	m.eco.set_value("coal_phaseout", 2.0)
	for mo in range(6):
		m.gov_month += Rules.TURN_MONTHS
		m.eco.tick()
	shell.refresh()
	if screens.has("auditfull"):
		var worst := Vector2.ZERO
		var worst_id := ""
		var n := 0
		for a in Policies.areas():
			var aid := str((a as Dictionary)["id"])
			for it in Policies.measures_of(aid):
				var mid := str((it as Dictionary)["id"])
				PolicyBrowser.memory["gov"] = {"area": aid, "mid": mid}
				PanelScreen.pending[mid] = float((it as Dictionary)["max"])
				shell.go("policies")
				await _frames(2)
				n += 1
				var avail: Vector2 = shell.full_holder.size - Vector2(16, 16)
				var mn: Vector2 = shell.screen_node.get_combined_minimum_size()
				var o := Vector2(maxf(0.0, mn.x - avail.x), maxf(0.0, mn.y - avail.y))
				if o.x + o.y > worst.x + worst.y:
					worst = o
					worst_id = mid
				PanelScreen.pending.erase(mid)
		print("AUDITFULL role=", role, " ", n, " medidas · peor exceso x ", worst.x, " y ", worst.y, " ", worst_id, " (área ", shell.full_holder.size, ")")
		quit()
		return
	if screens.has("militancy"):
		m.itrust.ensure()
		var meas_w := Policies.measure("wealth_tax")
		m.itrust._issue({"type": "ideologico", "kind": "law_rectify", "faction": "doctrina", "severity": 2, "title": "Rectificar «%s»" % str(meas_w.get("name", "")),
			"body": "Guardianes de la doctrina considera que la última ley se aleja del programa. Exige corregir el impuesto sobre el patrimonio antes de 3 trimestres.",
			"reason": "Has respaldado «Ley de reforma fiscal» y la corriente lo vive como un giro contra su eje económica.",
			"goal": {"kind": "measure", "id": "wealth_tax", "from": m.eco.value("wealth_tax"), "target": m.eco.value("wealth_tax") + 1.0, "name": str(meas_w.get("name", ""))}, "turns": 3})
		m.itrust._issue({"type": "reto", "kind": "poll", "faction": "aparato", "severity": 1, "title": "Recuperar apoyo en las encuestas",
			"body": "El aparato ve caer el apoyo del partido. Pide un plan para volver al 24.0 % en 3 trimestres.", "reason": "Las encuestas han bajado del 26.0 % de referencia al 22.5 %.",
			"goal": {"kind": "poll", "start": m.player_poll(), "target": 24.0}, "turns": 3})
		m.itrust.shock(-4.0, "Filtración sobre una discusión interna")
		m.itrust._log(-2.1, "Trimestre: Militancia y corrientes −2.1 («El aparato» está descontenta (41/100)).", "quarter")
	for id in screens:
		var parts := str(id).split(":")
		if parts[0] == "policies" and parts.size() > 2:
			PolicyBrowser.memory["gov"] = {"area": str(parts[1]), "mid": str(parts[2])}
			if parts.size() > 3:
				PanelScreen.pending[str(parts[2])] = float(parts[3])
		if parts[0] == "panel" and parts.size() > 1:
			PanelScreen.focus = str(parts[1]) if str(parts[1]) != "all" else ""
			PanelScreen.sel_kind = ""
		if parts[0] == "panel" and parts.size() > 3:
			PanelScreen.sel_kind = str(parts[2])
			PanelScreen.sel_id = str(parts[3])
		if parts[0] == "country" and parts.size() > 1:
			CountryScreen.sel = ":".join(parts.slice(1))
		if parts[0] == "ministry" and parts.size() > 1:
			MinistryScreen.sel_idx = int(parts[1])
			MinistryScreen.tab = "ministry"
		if parts[0] == "win":
			var wp: Array = Array(parts.slice(1))
			var wpick := -1
			if wp.size() > 1 and str(wp[wp.size() - 1]).is_valid_int():
				wpick = int(wp.pop_back())
			var wid := ":".join(PackedStringArray(wp))
			CountryScreen.sel = wid
			shell.go("country")
			await _frames(2)
			ChartWindow.open(shell, m, wid, 12, wpick)
			await _frames(2)
			await _shot(str(id).replace(":", "_"))
			shell.close_modal()
			continue
		if parts[0] == "dialog":
			shell.go("panel")
			await _frames()
			var ed: Array = []
			for a in Policies.areas():
				ed.append(str((a as Dictionary)["id"]))
			if parts.size() > 2:
				PanelScreen.pending[str(parts[1])] = float(parts[2])
			PolicyDialog.open(shell, m, str(parts[1]), ed if role == "president" else (shell.screen_node as PanelScreen).editable)
			await _frames()
			await _shot(str(id).replace(":", "_"))
			shell.close_modal()
			continue
		shell.go(str(parts[0]))
		await _shot(str(id).replace(":", "_"))
		if OS.get_environment("DUMP") != "":
			_dump(shell.content_holder, 0, float(OS.get_environment("DUMP")))
		print("   ", id, " content min=", shell.content_holder.get_combined_minimum_size(), " win=", root.size)
	print("Capturas en ", out_dir)
	quit()
