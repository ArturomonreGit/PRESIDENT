extends SceneTree
## Peor caso del asistente: ideología con 6 ideologías (una territorial) y resumen de partido propio territorial.
func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame
func _first_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer: return n
	for c in n.get_children():
		var r := _first_scroll(c)
		if r != null: return r
	return null
func _initialize() -> void:
	_run()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/wiz")
	await _frames(2)
	var st: Control = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	root.add_child(st)
	await _frames(3)
	st.show_new()
	await _frames(3)
	var wiz: NewGameWizard = st.view.get_child(0)
	wiz.mode = "custom"
	wiz.custom["name"] = "Alianza Verde Social"
	wiz.custom["short"] = "AVS"
	wiz.custom["motto"] = "Más futuro, menos ruido"
	wiz.custom["territory"] = "Cataluña"
	for id in ["ecologismo", "regionalismo", "socialdemocracia", "feminismo", "europeismo", "laicismo"]:
		wiz._add_pick(id)
	wiz.hero["name"] = "Marta"
	wiz.hero["surname"] = "Ribas Colom"
	for step in ["identity", "ideology", "summary"]:
		wiz.step = step
		wiz.render()
		await _frames(4)
		var vs := _first_scroll(wiz).get_v_scroll_bar()
		print("%-9s desborde %d" % [step, int(maxf(0.0, vs.max_value - vs.page))])
		root.get_viewport().get_texture().get_image().save_png("/tmp/wiz/worst_%s.png" % step)
	quit()
