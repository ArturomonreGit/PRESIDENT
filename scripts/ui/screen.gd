class_name Screen
extends VBoxContainer
## Base de las pantallas. `shell` es el Shell (se deja sin tipo para evitar dependencias circulares).

var shell
var m: GameModel
var title := ""
var subtitle := ""
## Pantalla «de juego»: ocupa todo el área útil (sin panel lateral ni desplazamiento) y reparte el alto entre sus columnas.
var fullscreen := false

func setup(shell_node, model: GameModel) -> void:
	shell = shell_node
	m = model
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

func build() -> void:
	pass

## Las pantallas «de juego» devuelven true: ocupan todo el área útil, sin panel lateral ni desplazamiento.
func wants_full() -> bool:
	return false

func rebuild() -> void:
	UI.clear_children(self)
	build()

# ---------------------------------------------------------------- ayudas comunes
func header(text: String, sub: String = "") -> void:
	var v := UI.vbox(2)
	v.add_child(UI.label(text, UI.FS_H2, UI.TEXT, true))
	if sub != "":
		v.add_child(UI.wrap_label(sub, UI.FS_BODY, UI.MUTED))
	add_child(v)

func columns(left_weight: float = 1.0, right_weight: float = 1.0, parent: Node = null) -> Array:
	var row := UI.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else self).add_child(row)
	var l := UI.vbox(10)
	var r := UI.vbox(10)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = left_weight
	r.size_flags_stretch_ratio = right_weight
	row.add_child(l)
	row.add_child(r)
	return [l, r]

## Lista a la izquierda (ancho fijo) y detalle a la derecha: ninguna de las dos hace crecer la página.
func split(left_w: float = 380.0, parent: Node = null) -> Array:
	var row := UI.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(parent if parent != null else self).add_child(row)
	var l := UI.vbox(6)
	l.custom_minimum_size = Vector2(left_w, 0)
	var r := UI.vbox(10)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(r)
	return [l, r]

## Reparte el ancho en N columnas iguales (o con pesos) y las devuelve.
func cols(weights: Array, parent: Node = null) -> Array:
	var row := UI.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else self).add_child(row)
	var out: Array = []
	for w in weights:
		var v := UI.vbox(10)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_stretch_ratio = float(w)
		row.add_child(v)
		out.append(v)
	return out

## Casilla compacta de la barra de estado de una pantalla de juego: título pequeño y valor grande.
func hud_stat(parent: Node, title: String, value: String, color: Color = UI.TEXT, tip: String = "") -> void:
	var pc := PanelContainer.new()
	var sb := UI.box(UI.PANEL, color if color != UI.TEXT else UI.D4_BLUE, 3, 0, 12, 4)
	sb.border_width_left = 5
	pc.add_theme_stylebox_override("panel", sb)
	pc.tooltip_text = tip
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := UI.vbox(0)
	pc.add_child(v)
	v.add_child(UI.label(title.to_upper(), 10, UI.MUTED, true))
	v.add_child(UI.label(value, UI.FS_LEAD, color, true))
	parent.add_child(pc)

func kpi_row(items: Array) -> void:
	var row := UI.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)
	for it in items:
		var d: Dictionary = it
		var tile := UI.kpi(row, str(d["title"]), str(d["value"]), str(d.get("sub", "")), d.get("color", UI.TEXT), d.get("sub_color", UI.MUTED))
		if d.has("tip"):
			(tile.get_parent() as Control).tooltip_text = str(d["tip"])

## Fila de tabla de partido: etiqueta, valores a la derecha.
func party_row(parent: Node, id: String, cells: Array, bold: bool = false) -> HBoxContainer:
	var row := UI.hbox(10)
	row.custom_minimum_size = Vector2(0, 26)
	var tag := UI.party_tag(m, id, UI.FS_BODY, bold or m.is_player(id))
	tag.custom_minimum_size = Vector2(110, 0)
	row.add_child(tag)
	for c in cells:
		var cd: Dictionary = c
		var l := UI.label(str(cd["text"]), UI.FS_BODY, cd.get("color", UI.TEXT), bool(cd.get("bold", false)))
		l.custom_minimum_size = Vector2(float(cd.get("w", 60)), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	parent.add_child(row)
	return row

func empty_note(parent: Node, text: String) -> void:
	parent.add_child(UI.wrap_label(text, UI.FS_BODY, UI.FAINT))

## Índice del primer punto del historial dentro de los últimos `months` meses (0 = todo).
func _history_start(months: int) -> int:
	var history := m.a("poll_history_multi")
	if months <= 0 or history.size() < 2:
		return 0
	var t_now := int((history[history.size() - 1] as Dictionary).get("t", 0))
	var first := history.size() - 1
	while first > 0 and int((history[first - 1] as Dictionary).get("t", 0)) >= t_now - months * 30 * 86400:
		first -= 1
	return first

func poll_chart_series(limit: int = 4, months: int = 0) -> Array:
	var history := m.a("poll_history_multi").slice(_history_start(months))
	var ids: Array = []
	for r in m.ranked_polls_with_player(limit):
		ids.append(str((r as Dictionary)["id"]))
	if not ids.has(m.pid()):
		ids.append(m.pid())
	var series: Array = []
	for id in ids:
		var vals: Array = []
		for snap in history:
			vals.append(float(((snap as Dictionary)["polls"] as Dictionary).get(str(id), 0.0)))
		series.append({"id": str(id), "name": m.party_short(str(id)), "color": m.party_color(str(id)), "values": vals, "width": 3.0 if m.is_player(str(id)) else 2.0})
	return series

## Configura un gráfico de encuestas con fechas en el eje y la línea «ahora».
func setup_poll_chart(chart: LineChart, limit: int = 4, months: int = 12) -> void:
	chart.series = poll_chart_series(limit, months)
	chart.x_labels = m.campaign.history_labels().slice(_history_start(months))
	chart.show_now = true
