class_name NegUI
extends RefCounted
## Piezas visuales compartidas por las pantallas de negociación (mesa, pactos, compromisos): cabeceras de columna con dirección,
## etiquetas de origen («quién lo propone»), reacciones del interlocutor, casillas de estadística y el medidor de disposición.
## Referencias de diseño: la ventana de comercio de Civilization y Stellaris (dos columnas y veredicto), las probabilidades con
## desglose de Crusader Kings y las cláusulas con estado de ánimo del agente en Football Manager.

## Color y etiqueta corta de cada categoría de la mesa (espec. §5).
const CAT_COLOR := {
	"participacion": Color("#6D4AC4"), "estructura": Color("#1F6FB8"), "carteras": Color("#B0561C"), "politicas": Color("#12875A"),
	"objetivos": Color("#B7791F"), "territorio": Color("#2A8C9B"), "presupuesto": Color("#8A6A00"), "parlamento": Color("#4B5FA8"),
	"instituciones": Color("#7A4B7F"), "calendario": Color("#5A6679")
}
const CAT_TAG := {
	"participacion": "PARTICIPACIÓN", "estructura": "ESTRUCTURA", "carteras": "CARTERAS", "politicas": "POLÍTICAS", "objetivos": "OBJETIVOS",
	"territorio": "TERRITORIO", "presupuesto": "PRESUPUESTO", "parlamento": "PARLAMENTO", "instituciones": "INSTITUCIONES", "calendario": "CALENDARIO"
}

static func cat_color(cat: String) -> Color:
	return CAT_COLOR.get(cat, UI.MUTED)

## Reacción del interlocutor ante una condición: texto, color y símbolo. Se lee de un vistazo por el color del punto.
static func reaction(stance: String, by_ai: bool) -> Dictionary:
	match stance:
		"ok": return {"text": "Lo aceptan" if by_ai else "Les parece bien", "color": UI.GOOD, "dot": "●"}
		"welcome": return {"text": "Les interesa", "color": UI.GOOD, "dot": "●"}
		"costly": return {"text": "Les cuesta", "color": UI.WARN, "dot": "◐"}
		"refuse": return {"text": "Lo rechazan", "color": UI.BAD, "dot": "○"}
		"veto": return {"text": "Veto", "color": UI.BAD, "dot": "✕"}
	return {}

## Cabecera de columna: banda de color con una flecha que indica quién da y quién recibe.
static func side_header(parent: Node, title: String, sub: String, color: Color, arrow: String) -> void:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color(color, 0.12), Color(color, 0.55), 6, 1, 12, 6))
	var h := UI.hbox(10)
	pc.add_child(h)
	var ar := UI.label(arrow, UI.FS_H2, color, true)
	ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ar)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := UI.label(title, UI.FS_LEAD, color.darkened(0.15), true)
	tl.clip_text = true
	v.add_child(tl)
	var sl := UI.label(sub, UI.FS_SMALL, UI.MUTED)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)
	h.add_child(v)
	parent.add_child(pc)

## Etiqueta de origen: de quién es la idea («TU PROPUESTA», «SU EXIGENCIA»…).
static func origin_tag(text: String, color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(color, Color(0, 0, 0, 0), 3, 0, 7, 1))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.add_child(UI.label(text, UI.FS_TINY, Color.WHITE, true))
	return pc

## Casilla de estadística: título pequeño y valor grande dentro de un recuadro.
static func stat_tile(parent: Node, title: String, value: String, color: Color = UI.TEXT, sub: String = "", tip: String = "") -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.72), Color(UI.D4_LINE, 0.9), 6, 1, 12, 5))
	if tip != "":
		pc.tooltip_text = tip
	var v := UI.vbox(0)
	pc.add_child(v)
	v.add_child(UI.label(title, UI.FS_TINY, UI.FAINT, true))
	if value != "":
		v.add_child(UI.label(value, UI.FS_LEAD, color, true))
	if sub != "":
		v.add_child(UI.label(sub, UI.FS_TINY, UI.MUTED))
	parent.add_child(pc)
	return v

## Fila de puntos: n llenos de un total (paciencia, ronda).
static func pips(filled: int, total: int, color: Color) -> HBoxContainer:
	var h := UI.hbox(4)
	for i in range(total):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(14, 14)
		p.add_theme_stylebox_override("panel", UI.box(color if i < filled else Color(color, 0.12), Color(color, 0.6), 7, 1, 0, 0))
		h.add_child(p)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h

## Medidor de disposición: franja con tres zonas (rechazo, duda, firma), el umbral de aceptación y la posición actual.
class Gauge extends Control:
	var ratio := 0.5
	var uncertain := false
	var accent := UI.MUTED
	func _init() -> void:
		custom_minimum_size = Vector2(0, 30)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var bar_y := 9.0
		var bar_h := 12.0
		var zones := [[0.0, 0.1, UI.BAD], [0.1, 0.5, UI.WARN], [0.5, 1.0, UI.GOOD]]
		for z in zones:
			var x0 := w * float(z[0])
			var x1 := w * float(z[1])
			draw_rect(Rect2(x0, bar_y, x1 - x0 - 1.0, bar_h), Color(z[2] as Color, 0.28))
		# Tramo conseguido hasta ahora.
		var cur := w * clampf(ratio, 0.0, 1.0)
		var fill := UI.BAD if ratio < 0.1 else (UI.WARN if ratio < 0.5 else UI.GOOD)
		draw_rect(Rect2(0, bar_y, cur, bar_h), fill)
		if uncertain:
			var span := w * 0.16
			draw_rect(Rect2(maxf(0.0, cur - span), bar_y - 2.0, minf(w, cur + span) - maxf(0.0, cur - span), bar_h + 4.0), Color(UI.TEXT, 0.10))
		# Umbral de aceptación.
		var tx := w * 0.5
		draw_line(Vector2(tx, bar_y - 4.0), Vector2(tx, bar_y + bar_h + 4.0), UI.TEXT, 2.0)
		# Puntero de la posición actual.
		var pts := PackedVector2Array([Vector2(cur, bar_y - 1.0), Vector2(cur - 6.0, bar_y - 9.0), Vector2(cur + 6.0, bar_y - 9.0)])
		draw_colored_polygon(pts, UI.TEXT)

static func gauge(ratio: float, uncertain: bool) -> Gauge:
	var g := Gauge.new()
	g.ratio = ratio
	g.uncertain = uncertain
	return g

# ---------------------------------------------------------------- compromisos de un acuerdo
const STATE_COLOR := {"pending": Color("#B7791F"), "in_progress": Color("#2B6CB0"), "fulfilled": Color("#1E8E5A"), "breached": Color("#C53030"), "renegotiated": Color("#6B46C1"), "cancelled": Color("#718096")}
const BINDING_COLOR := {"red_line": Color("#C53030"), "binding": Color("#B7791F"), "objective": Color("#2B6CB0"), "soft": Color("#718096")}

## Ficha de un compromiso con su estado, quién responde, plazo, progreso, consecuencia y acciones.
## `act` recibe el Dictionary de resultado de Agreements (ok/text/error). `compact` oculta progreso e historial.
static func commitment_row(m: GameModel, com: Dictionary, can_act: bool, act: Callable, compact: bool = false) -> Control:
	m.agr.normalize(com)
	var idx := m.agr.index_of(com)
	var st := m.agr.state_of(com)
	var col: Color = STATE_COLOR.get(st, UI.MUTED)
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL.lerp(col, 0.06), UI.D4_LINE, 4, 1, 8, 6))
	var h := UI.hbox(8)
	pc.add_child(h)
	var bar := ColorRect.new()
	bar.color = col
	bar.custom_minimum_size = Vector2(5, 0)
	h.add_child(bar)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 6)
	top.add_theme_constant_override("v_separation", 2)
	v.add_child(top)
	top.add_child(UI.chip(m.agr.state_name(com), col, true))
	var bd := str(com.get("binding", "binding"))
	var bc := UI.chip(str(Agreements.BINDING_NAMES.get(bd, "Vinculante")), BINDING_COLOR.get(bd, UI.MUTED))
	bc.tooltip_text = "Gravedad si se incumple: " + str(Agreements.BREACH_SEVERITY.get(bd, 4.0)) + " puntos de confianza."
	top.add_child(bc)
	top.add_child(UI.chip(m.agr.category_name(com), cat_color(str(com.get("category", "politicas")))))
	top.add_child(UI.party_tag(m, str(com.get("party", "")), UI.FS_SMALL))
	if m.agr.is_active(com):
		var left := m.agr.months_left(com)
		var dl := "Plazo: mes %d" % int(com.get("due", 8))
		if left >= 0:
			dl += " · " + ("vence este mes" if left == 0 else "quedan %d meses" % left)
		top.add_child(UI.label(dl, UI.FS_TINY, UI.BAD if left <= 1 else UI.FAINT))
	var txt := UI.wrap_label(str(com.get("text", "")), UI.FS_BODY, UI.TEXT, true)
	txt.tooltip_text = str(com.get("consequence", ""))
	txt.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(txt)
	if not compact:
		var resp: Dictionary = com.get("responsible", {})
		var meta := "Responsable: %s" % str(resp.get("name", "—"))
		var prog := m.agr.progress_text(com) if m.agr.is_active(com) or st == "breached" else ""
		if prog != "":
			meta += " · " + prog
		v.add_child(UI.wrap_label(meta, UI.FS_SMALL, UI.MUTED))
		if m.agr.is_active(com) or st == "breached":
			var cons := UI.wrap_label("Si se incumple: %s" % str(com.get("consequence", "")), UI.FS_TINY, UI.FAINT)
			v.add_child(cons)
		var hist: Array = com.get("history", [])
		if not hist.is_empty():
			var last: Dictionary = hist[hist.size() - 1]
			var hl := UI.label("Último movimiento · T%d: %s" % [int(last.get("turn", 0)), str(last.get("text", ""))], UI.FS_TINY, UI.FAINT)
			hl.clip_text = true
			hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var lines: Array = []
			for e in hist:
				lines.append("T%d · %s" % [int((e as Dictionary).get("turn", 0)), str((e as Dictionary).get("text", ""))])
			hl.tooltip_text = "\n".join(lines)
			hl.mouse_filter = Control.MOUSE_FILTER_PASS
			v.add_child(hl)
	if can_act and idx >= 0 and (m.agr.is_active(com) or st == "breached"):
		var tools := UI.hbox(4)
		v.add_child(tools)
		if m.agr.can_fulfil(com) == "":
			var cb := UI.mini_button("Cumplir (%d cap.)" % int(ceilf(m.agr.manual_cost(com))), func() -> void: act.call(m.agr.fulfil(idx)))
			cb.tooltip_text = "Lo cumples a mano gastando capital político."
			tools.add_child(cb)
		var rb := UI.mini_button("Renegociar", func() -> void: act.call(m.agr.renegotiate(idx)))
		rb.tooltip_text = "Pides al socio que te libere de lo pactado; puede negarse."
		tools.add_child(rb)
		var ab := UI.mini_button("Romper", func() -> void: act.call(m.agr.abandon(idx)))
		ab.tooltip_text = "Lo retiras sin acuerdo: se anota como incumplido y el socio lo recordará."
		tools.add_child(ab)
	return pc
