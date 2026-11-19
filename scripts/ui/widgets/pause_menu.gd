class_name PauseMenu
extends Control
## Menú de pausa (Esc): continuar, guardar, ajustes, menú principal y salir del juego.
## Se monta encima de todo el Shell (también de la retransmisión de la noche electoral)
## y pausa el árbol mientras está abierto.

var shell: Control = null
var box: VBoxContainer = null
var _mode := "main"

static func open(host: Control) -> PauseMenu:
	var existing := host.get_node_or_null("PauseMenu")
	if existing != null:
		return existing as PauseMenu
	var p := PauseMenu.new()
	p.name = "PauseMenu"
	p.shell = host
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(p)
	host.move_child(p, host.get_child_count() - 1)
	return p

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.10, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var psb := UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 32, 24, true)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)
	box = UI.vbox(10)
	panel.add_child(box)
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = true
	_show_main()

func _exit_tree() -> void:
	var t := get_tree()
	if t != null:
		t.paused = false

func close() -> void:
	if is_inside_tree():
		get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _mode == "main":
				close()
			else:
				_show_main()

func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _title(text: String, sub: String = "") -> void:
	box.add_child(UI.eyebrow("POLITICAL SIMULATOR", UI.D4_BLUE_D))
	box.add_child(UI.label(text, 38, UI.NAVY, true))
	var rule := ColorRect.new()
	rule.color = UI.D4_RED
	rule.custom_minimum_size = Vector2(72, 5)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(rule)
	if sub != "":
		box.add_child(UI.label(sub, UI.FS_BODY, UI.MUTED))
	box.add_child(UI.spacer(6))

func _show_main() -> void:
	_mode = "main"
	_clear()
	var sub := ""
	if shell != null and "m" in shell and shell.m != null:
		sub = "%s  ·  %s" % [shell.m.date_label(), str(shell.m.party.get("short_name", ""))]
	_title("PAUSA", sub)
	var do_save := func() -> void:
		if shell != null and shell.has_method("save_game"):
			shell.save_game()
		_flash("Partida guardada.")
	var ask_menu := func() -> void:
		_confirm("¿Volver al menú principal?", "La partida se guardará antes de salir.", "Ir al menú", _to_menu)
	var ask_quit := func() -> void:
		_confirm("¿Salir del juego?", "La partida se guardará antes de cerrar.", "Salir", _quit)
	box.add_child(UI.menu_block("Continuar", "Volver a la partida", "main", close, 456.0))
	box.add_child(UI.menu_block("Guardar partida", "", "blue", do_save, 456.0))
	box.add_child(UI.menu_block("Ajustes", "Sonido y pantalla", "quiet", _show_settings, 456.0))
	box.add_child(UI.menu_block("Menú principal", "Guarda y sale al menú", "blue", ask_menu, 456.0))
	box.add_child(UI.menu_block("Salir del juego", "", "danger", ask_quit, 456.0))
	box.add_child(UI.label("Esc para volver a la partida", UI.FS_SMALL, UI.MUTED))

func _flash(text: String) -> void:
	var l := UI.label(text, UI.FS_BODY, UI.GOOD, true)
	l.name = "Flash"
	var old := box.get_node_or_null("Flash")
	if old != null:
		old.queue_free()
	box.add_child(l)

func _show_settings() -> void:
	_mode = "settings"
	_clear()
	_title("AJUSTES")
	DisplayPanel.build_sound(box)
	box.add_child(UI.hsep())
	DisplayPanel.build(box)
	box.add_child(UI.spacer(4))
	box.add_child(UI.pill("‹  VOLVER", false, _show_main, true, UI.PILL_SUB))

func _confirm(title: String, text: String, ok_label: String, on_ok: Callable) -> void:
	_mode = "confirm"
	_clear()
	_title(title)
	var w := UI.wrap_label(text, UI.FS_BODY, UI.MUTED)
	box.add_child(w)
	var row := UI.hbox(10)
	row.add_child(UI.pill("CANCELAR", false, _show_main, true, Color("#8E9BB0")))
	row.add_child(UI.pill(ok_label.to_upper(), false, on_ok, true, UI.PILL_GO))
	box.add_child(row)

func _to_menu() -> void:
	var t := get_tree()
	if shell != null and shell.has_method("back_to_menu"):
		t.paused = false
		shell.back_to_menu()
	else:
		t.paused = false
		t.change_scene_to_file("res://scenes/startup.tscn")

func _quit() -> void:
	if shell != null and "m" in shell and shell.m != null:
		shell.m.save_now()
	get_tree().paused = false
	get_tree().quit()
