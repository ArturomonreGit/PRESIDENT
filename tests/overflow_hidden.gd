extends SceneTree
## Mide desbordes de las pantallas fuera de la navegación: cartera, presupuestos, reunión y editor de leyes.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/overflow_hidden.gd -- psoe
var shell: Control
var rows: Array = []

func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame

func _m(tag: String) -> void:
	await _frames(5)
	var vs: VScrollBar = shell.scroll.get_v_scroll_bar()
	var hs: HScrollBar = shell.scroll.get_h_scroll_bar()
	var over := maxi(0, int(vs.max_value - vs.page))
	var minw := int(_wide_px())
	var vw := int(root.get_visible_rect().size.x)
	rows.append("%-34s main %5d horiz %d%s" % [tag, over, maxi(0, int(hs.max_value - hs.page)), ("  ANCHO MIN %d > %d" % [minw, vw]) if minw > vw else ""])
	if minw > vw:
		over = 1
	if over > 0 or OS.get_environment("SHOTS") != "":
		DirAccess.make_dir_recursive_absolute("/tmp/ovh")
		root.get_viewport().get_texture().get_image().save_png("/tmp/ovh/%s.png" % tag.replace("/", "_").replace(" ", "_"))

func _wide_px() -> float:
	var w := 0.0
	for n in [shell.scroll, shell.rail_box.get_parent()]:
		w = maxf(w, (n as Control).get_global_rect().end.x)
	return maxf(w, shell.scroll.get_global_rect().position.x + shell.content_holder.get_combined_minimum_size().x + (shell.rail_box.get_parent() as Control).size.x)

func _wide() -> bool:
	return _wide_px() > root.get_visible_rect().size.x + 1.0

func _initialize() -> void:
	_run()

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
	m.phase = "legislature"
	m.s["government_party_id"] = m.pid()
	m.exec.on_government_formed()
	shell.refresh()
	# Cartera como presidente
	var owners := m.exec.area_owners()
	for k in owners.keys():
		MinistryScreen.sel_idx = int(owners[k])
		MinistryScreen.tab = "ministry"
		PanelScreen.pending = {}
		shell.go("ministry")
		await _m("cartera presidente/%s" % str(k))
	MinistryScreen.sel_idx = int(owners["health"])
	PanelScreen.pending = {"health_budget": m.eco.value("health_budget") + 10.0, "waiting_lists": 1.0}
	shell.go("ministry")
	await _m("cartera con cambios pendientes")
	m.exec.open_pge()
	MinistryScreen.tab = "budget"
	shell.go("ministry")
	await _m("presupuestos")
	# Editor de leyes
	m.s["government_party_id"] = m.pid()
	for a in Policies.areas():
		var aid := str((a as Dictionary)["id"])
		var law := m.laws.new_draft(aid)
		var n := 0
		for it in Policies.measures_of(aid, true):
			var meas: Dictionary = it
			if str(meas.get("special", "")) == "irpf":
				continue
			if n < 8 and meas.has("labels"):
				m.laws.set_change(law, str(meas["id"]), minf(float((meas["labels"] as Array).size() - 1), m.eco.value(str(meas["id"])) + 1.0))
				n += 1
		LawsScreen.editing_id = str(law["id"])
		LawsScreen.tab_area = aid
		shell.go("laws")
		await _m("editor leyes/%s" % aid)
		if aid == "tax":
			PolicyBrowser.memory["law"] = {"area": "tax", "mid": Irpf.SPECIAL_ID}
			shell.go("laws")
			await _m("editor leyes/irpf abierto")
	LawsScreen.editing_id = ""
	shell.go("laws")
	await _m("taller inicio con borradores")
	# Reunión
	LawsScreen.editing_id = ""
	# Reuniones bilaterales
	var rr := DataStore.parties()
	var tried := 0
	m.phase = "campaign"
	m.s["government_party_id"] = ""
	shell.refresh()
	for p in DataStore.parties():
		var pid2 := str((p as Dictionary)["id"])
		if pid2 == m.pid() or tried >= 4:
			continue
		for topic in m.diplomacy.topics_for(pid2):
			var r := m.diplomacy.open(pid2, str(topic))
			if bool(r.get("ok", false)):
				tried += 1
				shell.go("meeting")
				await _m("reunion/%s/%s" % [pid2, str(topic)])
				m.diplomacy.s_clear() if m.diplomacy.has_method("s_clear") else m.s.erase("meeting")
				break
	if tried == 0:
		rows.append("reunion: no se pudo abrir ninguna")
	print("===== OCULTAS =====")
	for r in rows:
		print(r)
	quit()
