extends Node
## Gestor de pantalla: ventana, pantalla completa y escalado de la interfaz. Se carga como autoload (`DisplayManager`).
## La interfaz se diseña en 1920×1080 y se escala con el modo `canvas_items`; aquí se ajusta el tamaño de la ventana
## a la pantalla disponible y se limita el factor de escala para que la interfaz nunca quede más pequeña que 1280×720 virtuales.

const SETTINGS_PATH := "user://political_simulator_settings.cfg"
const BASE := Vector2i(1920, 1080)
const MIN_VIRTUAL := Vector2(1280.0, 720.0)
const SCALES := [0.85, 1.0, 1.15, 1.3]
## Tamaños de ventana disponibles (16:9). 1920×1080 es el tamaño recomendado.
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var fullscreen := false
var user_scale := 1.0
var window_res := Vector2i(1920, 1080)
var _headless := false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	load_settings()
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = BASE
	win.min_size = Vector2i(960, 540)
	if not win.size_changed.is_connected(_fit):
		win.size_changed.connect(_fit)
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		user_scale = float(cfg.get_value("display", "ui_scale", 1.0))
		window_res = Vector2i(int(cfg.get_value("display", "res_w", 1920)), int(cfg.get_value("display", "res_h", 1080)))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "ui_scale", user_scale)
	cfg.set_value("display", "res_w", window_res.x)
	cfg.set_value("display", "res_h", window_res.y)
	cfg.save(SETTINGS_PATH)

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	save_settings()
	apply()

func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)

func set_resolution(res: Vector2i) -> void:
	window_res = res
	fullscreen = false
	save_settings()
	apply()

func set_scale(v: float) -> void:
	user_scale = v
	save_settings()
	_fit()

## Aplica el modo de ventana. En ventana usa la resolución elegida (reducida, si hace falta, para que quepa en la pantalla).
func apply() -> void:
	if _headless:
		return
	var win := get_window()
	if fullscreen:
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		var screen := DisplayServer.window_get_current_screen()
		var usable := DisplayServer.screen_get_usable_rect(screen)
		var room := usable.size - Vector2i(12, 48)  # bordes y barra de título
		var target := window_res
		if target.x > room.x or target.y > room.y:
			var k := minf(float(room.x) / float(target.x), float(room.y) / float(target.y))
			target = Vector2i(int(float(target.x) * k), int(float(target.y) * k))
		win.size = target
		win.position = usable.position + (usable.size - target) / 2
	_fit.call_deferred()

func _fit() -> void:
	if _headless:
		return
	var win := get_window()
	var sz := Vector2(win.size)
	var stretch := maxf(0.01, minf(sz.x / float(BASE.x), sz.y / float(BASE.y)))
	var limit := minf(sz.x / MIN_VIRTUAL.x, sz.y / MIN_VIRTUAL.y) / stretch
	win.content_scale_factor = clampf(user_scale, 0.5, maxf(0.5, limit))

func _unhandled_key_input(event: InputEvent) -> void:
	if _headless or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo and (k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed)):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
