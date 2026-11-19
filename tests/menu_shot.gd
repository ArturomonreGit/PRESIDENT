extends SceneTree
func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame
func _initialize() -> void:
	_run()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/menu")
	await _frames(2)
	var st: Control = (load("res://scenes/startup.tscn") as PackedScene).instantiate()
	root.add_child(st)
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("/tmp/menu/home.png")
	st.show_load(); await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("/tmp/menu/load.png")
	st.show_settings(); await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("/tmp/menu/settings.png")
	quit()
