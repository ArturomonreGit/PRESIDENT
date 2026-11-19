extends SceneTree
## Recorre el asistente de nueva partida (partido existente y partido propio) y comprueba la partida resultante.
## Uso: godot --headless --path . --script res://tests/wizard.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var root_ctl := Control.new()
	root_ctl.size = Vector2(1280, 800)
	root.add_child(root_ctl)
	var w := NewGameWizard.new()
	root_ctl.add_child(w)
	await process_frame
	print("== Partido existente")
	check(w.step == "party", "empieza en selección de partido")
	w._party_card(w._party("psoe"))
	w.party_id = "pp"
	w.render()
	await process_frame
	w.step = "character"; w.render(); await process_frame
	check(w._problem() != "", "exige nombre al personaje")
	check(w._nav_next != null and w._nav_next.disabled, "Siguiente desactivado sin nombre")
	# Escribir en los campos (señal real) debe reactivar el botón sin recargar el paso.
	var edits: Array = []
	var stack: Array = [w]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is LineEdit: edits.append(n)
		for ch in n.get_children(): stack.append(ch)
	check(edits.size() >= 2, "hay campos de nombre y apellidos (%d)" % edits.size())
	for e in edits:
		var le: LineEdit = e
		if le.placeholder_text == "Nombre":
			le.text = "Ana"; le.text_changed.emit("Ana")
		elif le.placeholder_text == "Apellidos":
			le.text = "Prueba Gil"; le.text_changed.emit("Prueba Gil")
	check(str(w.hero["name"]) == "Ana" and str(w.hero["surname"]) == "Prueba Gil", "los campos actualizan al personaje")
	check(w._problem() == "", "tras escribir nombre y apellidos ya no hay problema: '%s'" % w._problem())
	check(not w._nav_next.disabled, "Siguiente se activa al escribir, sin recargar el paso")
	check(w._nav_problem == null or not w._nav_problem.visible, "el aviso desaparece al escribir")
	w.hero["name"] = "Ana"; w.hero["surname"] = "Prueba Gil"
	var pts := Leader.STAT_POINTS - Leader.points_spent(w.hero["stats"])
	print("  puntos libres: ", pts)
	var guard := 0
	while Leader.points_spent(w.hero["stats"]) < Leader.STAT_POINTS and guard < 100:
		for k in (w.hero["stats"] as Dictionary).keys():
			if Leader.points_spent(w.hero["stats"]) < Leader.STAT_POINTS and int(w.hero["stats"][k]) < Leader.STAT_MAX:
				w.hero["stats"][k] = int(w.hero["stats"][k]) + 1
		guard += 1
	check(w._problem() == "", "personaje válido sin problemas (%s)" % w._problem())
	w._rebuild_body(); await process_frame
	check(not w._nav_next.disabled, "Siguiente se activa al completar el personaje")
	w.render(); await process_frame
	w.step = "summary"; w.render(); await process_frame
	var p := w.build_party()
	check(str(p["id"]) == "pp", "partido PP")
	check(p.has("character") and str(p["leader"]) == "Ana Prueba Gil", "personaje incluido")
	check((p["ideology_picks"] as Array).size() > 0, "ideología inferida")
	print("== Partido propio")
	w.mode = "custom"; w.step = "party"; w.render(); await process_frame
	w.step = "identity"; w.render(); await process_frame
	check(w._problem() == "", "identidad por defecto válida")
	w.custom["name"] = "Alianza Verde Social"; w.custom["short"] = "avs"
	w.step = "ideology"; w.render(); await process_frame
	check(w._problem() != "", "exige al menos una ideología")
	w._add_pick("ecologismo"); w._add_pick("socialdemocracia"); w._add_pick("feminismo")
	check(w._picks().size() == 3, "3 ideologías añadidas")
	w._set_strength("ecologismo", 5)
	check(w._pick_strength("ecologismo") == 5, "fuerza 5")
	for id in ["progresismo", "europeismo", "laicismo", "republicanismo", "animalismo"]:
		w._add_pick(id)
	check(Ideology.points_used(w._picks()) <= Ideology.BUDGET, "presupuesto respetado (%d)" % Ideology.points_used(w._picks()))
	check(w._picks().size() <= Ideology.MAX_PICKS, "máximo de ideologías")
	w._remove_pick("animalismo")
	await process_frame
	w.step = "character"; w.render(); await process_frame
	w.step = "summary"; w.render(); await process_frame
	var cp := w.build_party()
	check(str(cp["id"]) == "custom_player" and str(cp["short_name"]) == "AVS", "partido propio con siglas en mayúsculas")
	check(float(cp["coherence"]) > 0.0, "coherencia calculada")
	var pr := Ideology.preview(Ideology.compose(cp["ideology_picks"]))
	var comp_sumar := 0.0
	var comp_vox := 0.0
	for it in pr:
		if str(it["id"]) == "sumar": comp_sumar = float(it["compat"])
		if str(it["id"]) == "vox": comp_vox = float(it["compat"])
	check(comp_sumar > comp_vox + 0.2, "verdes-socialdemócratas más afines a Sumar (%.2f) que a Vox (%.2f)" % [comp_sumar, comp_vox])
	print("== Partido territorial")
	check(not Ideology.is_territorial(cp["ideology_picks"]) and not cp.has("territory"), "partido estatal sin territorio")
	w.mode = "custom"; w.step = "ideology"
	for pk in w._picks().duplicate():
		w._remove_pick(str((pk as Dictionary)["id"]))
	w._add_pick("regionalismo"); w._add_pick("progresismo")
	w.render(); await process_frame
	check(w._problem().contains("comunidad"), "exige comunidad: %s" % w._problem())
	check(w._nav_next.disabled, "Siguiente bloqueado sin comunidad")
	var comms := w._community_names()
	check(comms.size() >= 15, "catálogo de comunidades (%d)" % comms.size())
	w.custom["territory"] = "Cataluña" if comms.has("Cataluña") else str(comms[0])
	w._rebuild_body(); await process_frame
	check(w._problem() == "", "con comunidad ya se puede continuar")
	check(not w._nav_next.disabled, "Siguiente activo con comunidad")
	var tp := w.build_party()
	check((tp.get("territory", []) as Array).size() == 1, "party lleva un único territorio")
	w._remove_pick("regionalismo")
	check(not w.build_party().has("territory"), "sin ideología territorial no hay territorio")
	w._add_pick("independentismo")
	check(w._problem().contains("comunidad") or str(w.custom["territory"]) != "", "independentismo también es territorial")
	print("== Partida")
	var res: Dictionary = root.get_node("SaveManager").create_new_game(cp)
	check(bool(res.get("ok", false)) or res.has("save_id") or res.has("data"), "create_new_game acepta el partido")
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)
