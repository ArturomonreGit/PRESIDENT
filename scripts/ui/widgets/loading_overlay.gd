class_name LoadingOverlay
extends Control
## Pantalla de carga a pantalla completa: red de burbujas animada, barra de progreso y el paso que se está preparando.

var _bar_frac := 0.0
var _title := "Preparando el país"
var _step := ""
var _t := 0.0
var _nodes: Array = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 7
	for i in range(46):
		_nodes.append({"p": Vector2(_rng.randf(), _rng.randf()), "r": _rng.randf_range(10.0, 34.0), "ph": _rng.randf() * TAU, "c": i % 6})

func set_progress(frac: float, text: String) -> void:
	_bar_frac = clampf(frac, 0.0, 1.0)
	_step = text
	queue_redraw()

func set_title(t: String) -> void:
	_title = t
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#EEF1F6"))
	var cols := [Color("#2563EB"), Color("#F2481B"), Color("#16A06B"), Color("#E6A117"), Color("#8B5CF6"), Color("#0EA5B7")]
	# Red de burbujas con relaciones suaves
	var pts: Array = []
	for nd in _nodes:
		var d: Dictionary = nd
		var base: Vector2 = d["p"]
		var ph: float = d["ph"]
		var pos := Vector2(base.x * size.x + sin(_t * 0.5 + ph) * 14.0, base.y * size.y + cos(_t * 0.43 + ph) * 12.0)
		pts.append(pos)
	for i in range(pts.size()):
		for j in range(i + 1, pts.size()):
			var dd: float = (pts[i] as Vector2).distance_to(pts[j])
			if dd < 230.0:
				draw_line(pts[i], pts[j], Color(0.55, 0.62, 0.74, 0.20 * (1.0 - dd / 230.0)), 1.5, true)
	for i in range(pts.size()):
		var d2: Dictionary = _nodes[i]
		var c: Color = cols[int(d2["c"])]
		var pulse := 1.0 + 0.08 * sin(_t * 1.6 + float(d2["ph"]))
		draw_circle(pts[i], float(d2["r"]) * pulse + 4.0, Color(c.r, c.g, c.b, 0.10))
		draw_circle(pts[i], float(d2["r"]) * pulse, Color(c.r, c.g, c.b, 0.85))
		draw_arc(pts[i], float(d2["r"]) * pulse + 2.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 2.0, true)
	# Tarjeta central
	var w := 620.0
	var h := 190.0
	var r := Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
	draw_rect(Rect2(r.position + Vector2(0, 5), r.size), Color(0.1, 0.16, 0.28, 0.10))
	draw_rect(r, Color.WHITE)
	draw_rect(r, UI.BORDER, false, 1.0)
	var fb := UI.bold_font()
	var fr := UI.regular_font()
	draw_string(fb, r.position + Vector2(30, 52), _title, HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, 28, UI.TEXT)
	draw_string(fr, r.position + Vector2(30, 82), _step, HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, 14, UI.MUTED)
	var bar := Rect2(r.position + Vector2(30, 112), Vector2(w - 60.0, 12))
	draw_rect(bar, UI.PANEL3)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _bar_frac, bar.size.y)), UI.ACCENT)
	var sheen := fmod(_t * 0.6, 1.0)
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * _bar_frac * sheen, 0), Vector2(18, bar.size.y)), Color(1, 1, 1, 0.35 * (1.0 - sheen)))
	draw_string(fr, r.position + Vector2(30, 158), "%d %%" % int(round(_bar_frac * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 13, UI.FAINT)
	draw_string(fr, r.position + Vector2(w - 330, 158), "Datos de los cinco años anteriores", HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 12, UI.FAINT)
