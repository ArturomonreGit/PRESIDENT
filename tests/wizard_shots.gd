extends SceneTree
## Capturas y desborde de cada paso del asistente de nueva partida.
var out_dir := "/tmp/wiz"
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
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(2)
	var st: Control = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	root.add_child(st)
	await _frames(3)
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/00_inicio.png")
	st.show_new()
	await _frames(3)
	var wiz: NewGameWizard = st.view.get_child(0)
	for mode in ["existing", "custom"]:
		wiz.mode = mode
		wiz.party_id = "psoe"
		for step in wiz._steps():
			wiz.step = str(step)
			wiz.render()
			await _frames(4)
			var sc := _first_scroll(wiz)
			var vs := sc.get_v_scroll_bar()
			var nav_bottom: float = wiz._nav_problem.get_parent().get_global_rect().end.y if wiz._nav_problem != null else -1.0
			print("%-9s %-10s desborde %4d  pie en y=%d / %d" % [mode, step, int(maxf(0.0, vs.max_value - vs.page)), int(nav_bottom), int(root.get_visible_rect().size.y)])
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, mode, step])
	st.show_load()
	await _frames(3)
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/load.png")
	st.show_settings()
	await _frames(3)
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/settings.png")
	quit()
