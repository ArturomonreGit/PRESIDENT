class_name PolicySlider
extends Control
## Deslizador de medida al estilo Democracy 4: pista gruesa con el tramo alcanzable resaltado, marca fantasma del valor vigente,
## muescas por paso, burbuja con el valor sobre el tirador y etiquetas debajo. Admite medidas por niveles (con etiquetas).

signal changed(value: float)     ## mientras se arrastra
signal committed(value: float)   ## al soltar (o con el teclado)

var min_v := 0.0
var max_v := 1.0
var step := 0.1
var lo := 0.0                    ## límite inferior alcanzable
var hi := 1.0                    ## límite superior alcanzable
var value := 0.0
var current := 0.0               ## valor vigente (se dibuja como marca)
var base := NAN                  ## valor de partida (muesca dorada)
var labels: Array = []
var fmt: Callable = Callable()
var accent := UI.D4_BLUE
var enabled := true

var _drag := false
var _hover := false

const MX := 30.0
const TRACK_Y := 54.0
const TRACK_H := 14.0

func _init() -> void:
	custom_minimum_size = Vector2(240, 124)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())

func setup(meas: Dictionary, cur: float, val: float, lo_v: float, hi_v: float, color: Color, can_edit: bool = true) -> void:
	min_v = float(meas["min"])
	max_v = float(meas["max"])
	step = maxf(0.0001, float(meas["step"]))
	labels = meas.get("labels", [])
	lo = clampf(lo_v, min_v, max_v)
	hi = clampf(hi_v, min_v, max_v)
	current = cur
	value = clampf(val, min_v, max_v)
	base = float(meas.get("base", NAN))
	accent = color
	enabled = can_edit
	fmt = func(v: float) -> String: return Policies.value_text(meas, v)
	queue_redraw()

func _text(v: float) -> String:
	if fmt.is_valid():
		return str(fmt.call(v))
	return String.num(v, 2)

func _x_of(v: float) -> float:
	var span := maxf(0.0001, max_v - min_v)
	return MX + clampf((v - min_v) / span, 0.0, 1.0) * (size.x - 2.0 * MX)

func _value_at(x: float) -> float:
	var span := maxf(0.0001, max_v - min_v)
	var raw := min_v + clampf((x - MX) / maxf(1.0, size.x - 2.0 * MX), 0.0, 1.0) * span
	var snapped := min_v + snappedf(raw - min_v, step)
	return clampf(snapped, lo, hi)

func _set_from_x(x: float) -> void:
	var nv := _value_at(x)
	if not is_equal_approx(nv, value):
		value = nv
		changed.emit(value)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				grab_focus()
				_set_from_x(mb.position.x)
			elif _drag:
				_drag = false
				committed.emit(value)
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		_set_from_x((event as InputEventMouseMotion).position.x)
		accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var k := (event as InputEventKey).keycode
		if k == KEY_LEFT or k == KEY_RIGHT:
			var nv := clampf(value + (step if k == KEY_RIGHT else -step), lo, hi)
			if not is_equal_approx(nv, value):
				value = nv
				changed.emit(value)
				committed.emit(value)
				queue_redraw()
			accept_event()

func _fit(text: String, fs: int, max_w: float, f: Font) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		t = t.substr(0, t.length() - 1)
	return t + "…"

func _draw() -> void:
	var f := UI.regular_font()
	var fb := UI.bold_font()
	var w := size.x
	var tx0 := MX
	var tx1 := w - MX
	# --- pista
	var track := Rect2(tx0 - 6.0, TRACK_Y - TRACK_H * 0.5, tx1 - tx0 + 12.0, TRACK_H)
	draw_rect(track, Color("#CBD6E3"), true)
	draw_rect(Rect2(track.position, Vector2(track.size.x, 2.0)), Color(0, 0, 0, 0.10), true)
	# tramo alcanzable
	var rx0 := _x_of(lo)
	var rx1 := _x_of(hi)
	draw_rect(Rect2(rx0, TRACK_Y - TRACK_H * 0.5, maxf(2.0, rx1 - rx0), TRACK_H), Color("#9FC4E8") if enabled else Color("#D5DCE6"), true)
	# relleno entre el valor vigente y el propuesto
	var cx := _x_of(current)
	var vx := _x_of(value)
	if absf(vx - cx) > 0.5:
		var col := UI.D4_RED if value < current else UI.PILL_GO
		draw_rect(Rect2(minf(cx, vx), TRACK_Y - TRACK_H * 0.5, absf(vx - cx), TRACK_H), col, true)
	# muescas por paso
	var n := int(round((max_v - min_v) / step))
	if n > 0 and n <= 30:
		for i in range(n + 1):
			var x := _x_of(min_v + float(i) * step)
			var major := n <= 10 or i % 5 == 0
			draw_line(Vector2(x, TRACK_Y + TRACK_H * 0.5 + 2.0), Vector2(x, TRACK_Y + TRACK_H * 0.5 + (8.0 if major else 5.0)), Color("#7C93AD"), 1.0)
	# partida (muesca dorada)
	if not is_nan(base) and base >= min_v and base <= max_v:
		var bx := _x_of(base)
		draw_rect(Rect2(bx - 1.5, TRACK_Y - TRACK_H * 0.5 - 5.0, 3.0, TRACK_H + 10.0), UI.GOLD, true)
	# valor vigente: aro blanco
	draw_circle(Vector2(cx, TRACK_Y), 8.0, Color.WHITE)
	draw_arc(Vector2(cx, TRACK_Y), 8.0, 0.0, TAU, 20, Color("#33506E"), 2.0, true)
	# --- tirador
	var r := 18.0 if (_drag or _hover) and enabled else 16.0
	var hc := Vector2(vx, TRACK_Y)
	draw_circle(hc + Vector2(0, 2), r + 1.0, Color(0, 0, 0, 0.18))
	draw_circle(hc, r, Color.WHITE if enabled else Color("#E8ECF2"))
	draw_circle(hc, r - 3.0, accent if enabled else Color("#9AA8BD"))
	draw_circle(hc, r - 8.0, Color(1, 1, 1, 0.9))
	if has_focus():
		draw_arc(hc, r + 3.0, 0.0, TAU, 28, UI.GOLD, 2.0, true)
	# --- burbuja con el valor
	var txt := _fit(_text(value), 16, 240.0, fb)
	var ts := fb.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var bw := ts.x + 24.0
	var bx2 := clampf(vx - bw * 0.5, 0.0, maxf(0.0, w - bw))
	var by := 2.0
	draw_rect(Rect2(bx2, by, bw, 28.0), accent if enabled else Color("#9AA8BD"), true)
	draw_colored_polygon(PackedVector2Array([Vector2(vx - 7.0, by + 28.0), Vector2(vx + 7.0, by + 28.0), Vector2(vx, by + 36.0)]), accent if enabled else Color("#9AA8BD"))
	draw_string(fb, Vector2(bx2 + 12.0, by + 20.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	# --- etiquetas inferiores
	var ly := TRACK_Y + TRACK_H * 0.5 + 30.0
	if not labels.is_empty() and labels.size() <= 6:
		var cnt := labels.size()
		var cell := (tx1 - tx0) / float(maxi(1, cnt - 1)) if cnt > 1 else 120.0
		var widest := 0.0
		for i0 in range(cnt):
			widest = maxf(widest, f.get_string_size(str(labels[i0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		var stagger := widest > cell * 0.92
		var crowded := widest > cell * 1.7
		var sel_i := int(round(value))
		for i in range(cnt):
			if crowded and i != 0 and i != cnt - 1 and i != sel_i:
				continue
			var lx := _x_of(float(i))
			var fs := 12
			var lt := _fit(str(labels[i]), fs, minf(cell * (1.0 if crowded and (i == 0 or i == cnt - 1) else (1.9 if stagger else 0.95)), 190.0), f)
			var lsz := f.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var px := clampf(lx - lsz.x * 0.5, 0.0, maxf(0.0, w - lsz.x))
			var on := is_equal_approx(float(i), value)
			var yy := ly + (15.0 if (stagger and i % 2 == 1) or (crowded and i != 0 and i != cnt - 1) else 0.0)
			draw_string(fb if on else f, Vector2(px, yy), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT if on else UI.MUTED)
	else:
		draw_string(f, Vector2(tx0 - 6.0, ly), _fit(_text(min_v), 12, w * 0.4, f), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
		var mt := _fit(_text(max_v), 12, w * 0.4, f)
		var msz := f.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(f, Vector2(tx1 + 6.0 - msz.x, ly), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	var cap := "◆ hoy" if absf(cx - vx) > 28.0 else ""
	if cap != "" and (labels.is_empty() or labels.size() > 6):
		draw_string(f, Vector2(clampf(cx - 14.0, 0.0, w - 40.0), ly), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#33506E"))
