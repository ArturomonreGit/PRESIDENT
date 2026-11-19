extends SceneTree
## Galería de caricaturas para revisar el dibujo. Uso: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/portrait_shots.gd -- /tmp/portraits.png

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/portraits.png"
	root.size = Vector2i(1280, 720)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cols := ["#E30613", "#1D70B7", "#63BE21", "#E0A93B", "#8E44AD", "#0FA3B1", "#FF6B6B", "#2F6BFF"]
	var moods := ["neutral", "happy", "angry", "worried", "smug"]
	for i in range(32):
		var ch := Leader.random_player(rng)
		var p := LeaderPortrait.new()
		p.custom_minimum_size = Vector2(138, 138)
		p.setup(ch, Color(cols[i % cols.size()]), moods[i % moods.size()])
		grid.add_child(p)
	for i in range(6):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	quit()
