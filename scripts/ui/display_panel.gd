class_name DisplayPanel
extends RefCounted
## Controles de pantalla reutilizables (ajustes del menú y ventana «Pantalla» dentro de la partida).

static func build(parent: Control) -> void:
	var fs := CheckBox.new()
	fs.text = "Pantalla completa (F11)"
	fs.button_pressed = DisplayManager.fullscreen
	fs.focus_mode = Control.FOCUS_NONE
	parent.add_child(fs)
	var row := UI.hbox(10)
	var l := UI.label("Resolución de la ventana", UI.FS_BODY, UI.TEXT)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	var res_opt := OptionButton.new()
	var sel := 2
	for i in range(DisplayManager.RESOLUTIONS.size()):
		var r: Vector2i = DisplayManager.RESOLUTIONS[i]
		res_opt.add_item("%d × %d%s" % [r.x, r.y, "  (recomendada)" if r == Vector2i(1920, 1080) else ""])
		if r == DisplayManager.window_res:
			sel = i
	res_opt.select(sel)
	res_opt.disabled = DisplayManager.fullscreen
	res_opt.item_selected.connect(func(i: int) -> void:
		DisplayManager.set_resolution(DisplayManager.RESOLUTIONS[i]))
	row.add_child(res_opt)
	parent.add_child(row)
	var row2 := UI.hbox(10)
	var l2 := UI.label("Tamaño de la interfaz", UI.FS_BODY, UI.TEXT)
	l2.custom_minimum_size = Vector2(210, 0)
	row2.add_child(l2)
	var scale_opt := OptionButton.new()
	var sel2 := 1
	for i in range(DisplayManager.SCALES.size()):
		scale_opt.add_item("%d %%" % int(float(DisplayManager.SCALES[i]) * 100.0))
		if is_equal_approx(float(DisplayManager.SCALES[i]), DisplayManager.user_scale):
			sel2 = i
	scale_opt.select(sel2)
	scale_opt.item_selected.connect(func(i: int) -> void:
		DisplayManager.set_scale(float(DisplayManager.SCALES[i])))
	row2.add_child(scale_opt)
	parent.add_child(row2)
	fs.toggled.connect(func(on: bool) -> void:
		DisplayManager.set_fullscreen(on)
		res_opt.disabled = on)
	parent.add_child(UI.wrap_label("Con 1920 × 1080 (o pantalla completa en un monitor Full HD) el juego se dibuja sin reescalado forzado y el texto queda nítido. El tamaño de la interfaz agranda o reduce todo el contenido.", UI.FS_SMALL, UI.MUTED))


## Controles de sonido (ajustes del menú y menú de pausa).
static func build_sound(parent: Control) -> void:
	var snd := CheckBox.new()
	snd.text = "Sonido activado"
	snd.button_pressed = not Sfx.is_muted()
	snd.focus_mode = Control.FOCUS_NONE
	snd.toggled.connect(func(on: bool) -> void:
		Sfx.set_muted(not on))
	parent.add_child(snd)
	var vrow := UI.hbox(10)
	var vl := UI.label("Volumen", UI.FS_BODY, UI.TEXT)
	vl.custom_minimum_size = Vector2(210, 0)
	vrow.add_child(vl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = Sfx.volume
	sl.custom_minimum_size = Vector2(200, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v: float) -> void:
		Sfx.volume = v
		Sfx.save_settings())
	vrow.add_child(sl)
	parent.add_child(vrow)
