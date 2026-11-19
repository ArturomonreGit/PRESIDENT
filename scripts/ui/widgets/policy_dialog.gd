class_name PolicyDialog
extends Control
## Ventana emergente con el navegador de medidas (para abrir una medida concreta desde otras pantallas, p. ej. las baldosas de la cartera).

var shell
var m: GameModel
var on_close: Callable = Callable()

class Badge extends PolicyBrowser.Badge:
	pass

static func open(shell_node, model: GameModel, measure_id: String, editable_areas: Array, close_cb: Callable = Callable()) -> PolicyDialog:
	var d := PolicyDialog.new()
	d.shell = shell_node
	d.m = model
	d.on_close = close_cb
	shell_node.close_modal()
	shell_node.modal_layer.add_child(d)
	d.build(measure_id, editable_areas)
	return d

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if on_close.is_valid():
		on_close.call()
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()

func build(measure_id: String, editable_areas: Array) -> void:
	var back := ColorRect.new()
	back.color = Color(0.06, 0.12, 0.2, 0.68)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close())
	add_child(back)
	var panel := PanelContainer.new()
	var vp := get_viewport_rect().size
	var w := minf(1500.0, vp.x - 40.0)
	var h := minf(900.0, vp.y - 40.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_BLUE_D, 4, 2, 0, 0, true))
	panel.clip_contents = true
	add_child(panel)
	var col := UI.vbox(0)
	panel.add_child(col)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.NAVY, Color(0, 0, 0, 0), 0, 0, 16, 8))
	col.add_child(bar)
	var row := UI.hbox(12)
	bar.add_child(row)
	var t := UI.label("MEDIDAS DE GOBIERNO", UI.FS_BODY, Color.WHITE, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UI.label("Capital político %d" % int(m.exec.capital()), UI.FS_BODY, Color("#9FD0FF"), true))
	row.add_child(UI.button("✕  Cerrar", "secondary", close, 100))
	var br := PolicyBrowser.create(shell, m, "gov_dialog", editable_areas)
	br.select(measure_id)
	col.add_child(br)
