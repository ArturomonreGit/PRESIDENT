class_name PolicyBrowser
extends HBoxContainer
## Navegador de medidas a pantalla completa, calcado del de Democracy 4: columna de áreas (bloques verticales), columna con las
## medidas del área elegida y, a la derecha, la ficha grande de la medida con su deslizador, popularidad y efectos.
## Modos: "gov" (decretar o llevar a ley desde el Gobierno), "program" (prometer medidas en el programa electoral) y
## "law" (redactar una iniciativa legislativa del Taller: incluir o quitar medidas de un borrador).

static var memory: Dictionary = {}          ## modo → {"area": …, "mid": …}: se conserva la selección al reconstruir
static var program_pending: Dictionary = {} ## valor propuesto en el programa antes de añadirlo
static var law_pending: Dictionary = {}     ## valor propuesto en el Taller antes de incluirlo en la ley

var shell
var m: GameModel
var mode := "gov"
var editable: Array = []                    ## áreas sobre las que el jugador puede actuar (modo gov)
var area := ""
var mid := ""
var host_refresh: Callable = Callable()     ## la pantalla anfitriona reconstruye su cabecera tras un cambio
var read_only := false                      ## programa ya firmado
var law_id := ""                            ## borrador que se edita (modo "law")
var _detail: PanelContainer

class Badge extends Control:
	var kind := "dot"
	var col := UI.ACCENT
	func _init(k: String, c: Color, px: float = 34.0) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, col)
		Glyphs.draw(self, kind, size * 0.5, r, Color.WHITE)

## Triángulo blanco que señala la ficha desde la medida elegida.
class Notch extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(12, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(size.x, 0), Vector2(0, size.y * 0.5), Vector2(size.x, size.y)]), Color.WHITE)

static func create(shell_node, model: GameModel, the_mode: String, editable_areas: Array, refresh_cb: Callable = Callable(), is_read_only: bool = false) -> PolicyBrowser:
	var b := PolicyBrowser.new()
	b.shell = shell_node
	b.m = model
	b.mode = the_mode
	b.editable = editable_areas
	b.host_refresh = refresh_cb
	b.read_only = is_read_only
	return b

func _init() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

## Fija la medida elegida (y su área) recordándola para la próxima reconstrucción.
func select(measure_id: String) -> void:
	mid = measure_id
	area = str(Policies.measure(measure_id).get("area", area))
	memory[mode] = {"area": area, "mid": mid}

func _ready() -> void:
	build()

func build() -> void:
	UI.clear_children(self)
	var mem: Dictionary = memory.get(mode, {})
	if area == "":
		area = str(mem.get("area", ""))
		mid = str(mem.get("mid", ""))
	if area == "" or Policies.area(area).is_empty():
		area = _first_area()
		mid = ""
	var ml := _measures(area)
	if mid == "" or Policies.measure(mid).is_empty() or str(Policies.measure(mid).get("area", "")) != area:
		mid = str((ml[0] as Dictionary)["id"]) if not ml.is_empty() else ""
	memory[mode] = {"area": area, "mid": mid}
	add_child(_areas_column())
	add_child(_measures_column())
	_detail = PanelContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.clip_contents = true
	_detail.add_theme_stylebox_override("panel", UI.box(Color("#F9FBFE"), UI.D4_LINE, 0, 0, 30, 20))
	add_child(_detail)
	_fill_detail()

func _first_area() -> String:
	for a in Policies.areas():
		var aid := str((a as Dictionary)["id"])
		if mode != "gov" or editable.has(aid):
			return aid
	return str((Policies.areas()[0] as Dictionary)["id"])

func _measures(area_id: String) -> Array:
	return Policies.measures_of(area_id, mode != "gov")

func _full_refresh() -> void:
	build()
	if host_refresh.is_valid():
		host_refresh.call()

# ---------------------------------------------------------------- bloques estilo D4
func _block(parent: Node, text: String, selected: bool, base: Color, sel_col: Color, cb: Callable, h: float, icon: String = "", icon_col: Color = Color.WHITE, tail: String = "", fs: int = 13, notch: bool = false) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col := sel_col if selected else base
	b.add_theme_stylebox_override("normal", UI.box(col, col.darkened(0.12), 0, 1, 10, 2))
	b.add_theme_stylebox_override("hover", UI.box(col.lightened(0.12), col.lightened(0.2), 0, 1, 10, 2))
	b.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.12), col, 0, 1, 10, 2))
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.pressed.connect(cb)
	parent.add_child(b)
	var inner := UI.hbox(8)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_right = -4
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	if icon != "":
		var bd := Badge.new(icon, icon_col, minf(30.0, h - 8.0))
		bd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(bd)
	var nm := UI.label(text, fs, Color.WHITE, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(nm)
	if tail != "":
		var tl := UI.label(tail, UI.FS_TINY, Color(1, 1, 1, 0.92), true)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tl)
	if notch:
		var nt := Notch.new()
		nt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(nt)

func _areas_column() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(252, 0)
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.D4_BLUE_L, Color(0, 0, 0, 0), 0, 0, 0, 0))
	var v := UI.vbox(2)
	pc.add_child(v)
	var areas: Array = Policies.areas()
	var vp_h := get_viewport_rect().size.y
	var h := clampf((vp_h - 215.0) / float(maxi(1, areas.size())) - 2.0, 28.0, 46.0)
	var mf: Manifesto = m.manifesto
	for a in areas:
		var ad: Dictionary = a
		var aid := str(ad["id"])
		var ed := mode != "gov" or editable.has(aid)
		var tail := ""
		if mode == "program":
			var n := mf.area_count(aid)
			tail = "%d ★" % n if n > 0 else ""
		elif mode == "law":
			var nl := 0
			var lw := _law()
			for it0 in Policies.measures_of(aid, true):
				if not lw.is_empty() and (lw["changes"] as Dictionary).has(str((it0 as Dictionary)["id"])):
					nl += 1
			tail = "%d ★" % nl if nl > 0 else ""
		else:
			var changed := 0
			for it in Policies.measures_of(aid):
				if not is_equal_approx(m.eco.value(str((it as Dictionary)["id"])), float((it as Dictionary)["base"])):
					changed += 1
			tail = "●%d" % changed if changed > 0 else ""
		var pick := func() -> void:
			area = aid
			mid = ""
			build()
		var base := UI.D4_BLUE_D if ed else Color("#6E8FAE")
		_block(v, str(ad["name"]).to_upper(), aid == area, base, UI.D4_RED, pick, h, Glyphs.of_area(aid), Glyphs.area_color(aid) if ed else Color("#8FA7BF"), tail, 12)
	return pc

func _measures_column() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(340, 0)
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color("#7DC0EE"), Color(0, 0, 0, 0), 0, 0, 0, 0))
	var v := UI.vbox(2)
	pc.add_child(v)
	var list := _measures(area)
	var vp_h := get_viewport_rect().size.y
	var h := clampf((vp_h - 215.0) / float(maxi(1, list.size())) - 2.0, 34.0, 52.0)
	var mf: Manifesto = m.manifesto
	var ed_area := mode != "gov" or editable.has(area)
	var lw2 := _law()
	for it in list:
		var meas: Dictionary = it
		var id := str(meas["id"])
		var cur := m.eco.value(id)
		var tail := ""
		var base := UI.D4_BLUE
		if not ed_area:
			base = Color("#7F9BB8")
		if mode == "program":
			if mf.has(id):
				base = UI.PILL_GO
				tail = Policies.value_text(meas, mf.target(id)) if str(meas.get("special", "")) != "irpf" else "escala"
		elif mode == "law":
			if not lw2.is_empty() and (lw2["changes"] as Dictionary).has(id):
				base = UI.PILL_GO
				tail = Policies.value_text(meas, float(lw2["changes"][id])) if str(meas.get("special", "")) != "irpf" else "escala"
			elif law_pending.has(id):
				base = UI.PILL_WARN
				tail = "▲ " + Policies.value_text(meas, float(law_pending[id])) if str(meas.get("special", "")) != "irpf" else ""
		else:
			if not is_equal_approx(cur, float(meas["base"])):
				tail = Policies.value_text(meas, cur)
				if ed_area:
					base = UI.PILL_GO
			if PanelScreen.pending.has(id) and not is_equal_approx(float(PanelScreen.pending[id]), cur):
				base = UI.PILL_WARN
				tail = "▲ " + Policies.value_text(meas, float(PanelScreen.pending[id]))
		var pick_m := func() -> void:
			select(id)
			build()
		_block(v, str(meas["name"]), id == mid, base, UI.D4_BLUE_D if base == UI.D4_BLUE else base.darkened(0.18), pick_m, h, Glyphs.of_area(area), Glyphs.area_color(area).darkened(0.1) if ed_area else Color("#8FA7BF"), _short(tail), 13, id == mid)
	return pc

func _short(t: String) -> String:
	return t if t.length() <= 18 else t.substr(0, 17) + "…"

# ---------------------------------------------------------------- ficha
func _fill_detail() -> void:
	UI.clear_children(_detail)
	var meas := Policies.measure(mid)
	if meas.is_empty():
		_detail.add_child(UI.label("Elige una medida de la lista.", UI.FS_LEAD, UI.FAINT))
		return
	if str(meas.get("special", "")) == "irpf":
		_detail_irpf(meas)
		return
	var owner := int(m.exec.area_owners().get(area, -1))
	var gov := mode == "gov"
	var ed := (editable.has(area) if gov else not read_only)
	var can_decree := gov and ed and m.exec.decreeable(meas) and m.exec.can_manage(owner)
	var cur := m.eco.value(mid)
	var prop := _proposal(meas, cur, can_decree)
	var changed := not is_equal_approx(cur, prop)
	var acol := Glyphs.area_color(area)
	var root := UI.vbox(14)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(root)
	# --- título
	var head := UI.hbox(14)
	root.add_child(head)
	head.add_child(Badge.new(Glyphs.of_area(area), acol, 60.0))
	var ht := UI.vbox(3)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_child(UI.label(str(meas["name"]), 34, Color("#0F2A47"), true))
	var chips := UI.hbox(6)
	chips.add_child(UI.chip(str(Policies.area(area).get("name", "")), acol))
	_status_chips(chips, meas, ed, can_decree)
	ht.add_child(chips)
	head.add_child(ht)
	var cols := UI.hbox(26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	# --- izquierda: texto, cifras, popularidad y deslizador
	var l := UI.vbox(14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = 1.25
	cols.add_child(l)
	l.add_child(UI.wrap_label(str(meas["desc"]), UI.FS_LEAD, UI.MUTED))
	l.add_child(_stats(meas, cur, prop, changed, ed, can_decree, owner))
	l.add_child(_pop_block(meas, cur, prop, changed))
	if ed:
		l.add_child(_slider_block(meas, cur, prop, can_decree))
	if ed:
		_actions(l, meas, owner, cur, prop, changed, can_decree)
	_history_card(l, meas)
	# --- derecha: efectos estimados
	var r := UI.vbox(10)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(r)
	_effects_box(r, meas, cur, prop, changed)
	if mode == "program":
		_program_summary(r)

func _status_chips(chips: HBoxContainer, meas: Dictionary, ed: bool, can_decree: bool) -> void:
	if mode == "program":
		if read_only:
			chips.add_child(UI.chip("Programa firmado", UI.GOOD))
		elif m.manifesto.has(str(meas["id"])):
			chips.add_child(UI.chip("En tu programa", UI.GOOD, true))
		return
	if mode == "law":
		var lw := _law()
		if not lw.is_empty() and (lw["changes"] as Dictionary).has(str(meas["id"])):
			chips.add_child(UI.chip("En la ley", UI.GOOD, true))
		if LawMaker.ORGANIC.has(str(meas["id"])):
			chips.add_child(UI.chip("Ley orgánica", UI.BAD))
		return
	if not ed:
		chips.add_child(UI.chip("Otro ministerio · solo lectura", UI.FAINT))
	elif can_decree:
		chips.add_child(UI.chip("Se puede decretar", UI.GOOD))
	else:
		chips.add_child(UI.chip("Exige una ley del Congreso", UI.WARN))
		if LawMaker.ORGANIC.has(str(meas["id"])):
			chips.add_child(UI.chip("Ley orgánica", UI.BAD))

## Valor que muestra el deslizador: lo pendiente (gobierno), lo prometido o pendiente de prometer (programa).
func _proposal(meas: Dictionary, cur: float, can_decree: bool) -> float:
	var id := str(meas["id"])
	if mode == "program":
		if program_pending.has(id):
			return Policies.snap(meas, float(program_pending[id]))
		return Policies.snap(meas, m.manifesto.target(id)) if m.manifesto.has(id) else cur
	if mode == "law":
		if law_pending.has(id):
			return Policies.snap(meas, float(law_pending[id]))
		var lw := _law()
		if not lw.is_empty() and (lw["changes"] as Dictionary).has(id):
			return Policies.snap(meas, float((lw["changes"] as Dictionary)[id]))
		return cur
	var p := Policies.snap(meas, float(PanelScreen.pending.get(id, cur)))
	if can_decree:
		p = m.exec.clamp_value(meas, p)
	return p

func _row_line(label: String, value: String, col: Color = UI.TEXT) -> Control:
	var v := UI.vbox(0)
	var row := UI.hbox(8)
	row.custom_minimum_size = Vector2(0, 32)
	var a := UI.label(label, UI.FS_BODY, Color("#3B6A99"), true)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	var b := UI.label(value, UI.FS_LEAD, col, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	v.add_child(row)
	v.add_child(UI.hsep(Color("#8FA9C4")))
	return v

func _stats(meas: Dictionary, cur: float, prop: float, changed: bool, ed: bool, can_decree: bool, owner: int) -> Control:
	var v := UI.vbox(0)
	v.add_child(_row_line("Valor actual", Policies.value_text(meas, cur) + ("   →   " + Policies.value_text(meas, prop) if changed else ""), UI.TEXT))
	v.add_child(_row_line("Valor de partida", Policies.value_text(meas, float(meas["base"])), UI.MUTED))
	if mode == "gov" and ed:
		if can_decree:
			var cost := m.exec.cost_of(meas, prop) if changed else m.exec.cost_of(meas, Policies.snap(meas, cur + float(meas["step"])))
			v.add_child(_row_line("Coste de introducción (capital político)", "%d / %d" % [int(cost), int(m.exec.capital())], UI.ACCENT))
			v.add_child(_row_line("Implantación", "efectos graduales · 6-18 meses", UI.MUTED))
		else:
			v.add_child(_row_line("Vía", "ley en el Congreso (mayoría %s)" % ("absoluta" if LawMaker.ORGANIC.has(str(meas["id"])) else "simple"), UI.WARN))
	if changed:
		var pv := m.eco.preview({str(meas["id"]): prop})
		v.add_child(_row_line("Saldo público en régimen", "%s bn €/año" % UI.signed(float(pv["balance"]), 1), UI.GOOD if float(pv["balance"]) >= 0.0 else UI.BAD))
	if mode == "program" and m.manifesto.has(str(meas["id"])):
		var al := m.manifesto.alignment(str(meas["id"]))
		v.add_child(_row_line("Encaje con tu ideología", "Encaja" if al > 0.25 else ("Choca" if al < -0.25 else "Neutra"), UI.GOOD if al > 0.25 else (UI.BAD if al < -0.25 else UI.MUTED)))
	return v

## Popularidad estimada (0-100): cómo ven los grupos, ponderados por su peso, el valor de la medida respecto a su punto de partida.
func _popularity(meas: Dictionary, value: float) -> float:
	var steps := (value - float(meas["base"])) / maxf(0.0001, float(meas["step"]))
	var hits: Dictionary = meas.get("hits", {})
	var tot := 0.0
	var wsum := 0.0
	for g in Policies.groups():
		var gd: Dictionary = g
		tot += float(gd["share"]) * float(hits.get(str(gd["id"]), 0.0))
		wsum += float(gd["share"])
	return clampf(50.0 + tot / maxf(1.0, wsum) * steps * 9.0, 3.0, 97.0)

func _pop_block(meas: Dictionary, cur: float, prop: float, changed: bool) -> Control:
	var v := UI.vbox(4)
	var shown := prop if changed else cur
	var pop := _popularity(meas, shown)
	var row := UI.hbox(6)
	var t := UI.label("(Estimada) Popularidad entre los votantes", UI.FS_BODY, Color("#3B6A99"), true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UI.label("%d %%" % int(round(pop)), UI.FS_LEAD, UI.GOOD if pop >= 50.0 else UI.BAD, true))
	v.add_child(row)
	var mb := UI.meter(pop, 100.0, UI.PILL_WARN if pop < 60.0 and pop >= 35.0 else (UI.GOOD if pop >= 60.0 else UI.BAD), 18)
	mb.track_color = Color("#33414F")
	mb.marker = 50.0
	v.add_child(mb)
	if changed and mode != "program" and m.exec.incoherence(meas, prop) > 0.3:
		v.add_child(UI.label("Choca con la línea de tu partido: tus votantes y militantes lo notarán.", UI.FS_SMALL, UI.BAD))
	return v

# ---------------------------------------------------------------- deslizador
func _slider_block(meas: Dictionary, cur: float, prop: float, can_decree: bool) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color("#EAF1F9"), UI.D4_LINE, 4, 1, 18, 12))
	var v := UI.vbox(2)
	pc.add_child(v)
	var lo := float(meas["min"])
	var hi := float(meas["max"])
	if can_decree:
		var span := m.exec.max_span(meas)
		lo = maxf(lo, cur - span)
		hi = minf(hi, cur + span)
	var top := UI.hbox(10)
	v.add_child(top)
	var tl := UI.label("AJUSTAR LA MEDIDA", UI.FS_TINY, Color("#3B6A99"), true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	if can_decree:
		top.add_child(UI.label("alcance por decreto: %s – %s" % [Policies.value_text(meas, lo), Policies.value_text(meas, hi)], UI.FS_TINY, UI.MUTED))
	var row := UI.hbox(16)
	v.add_child(row)
	var sl := PolicySlider.new()
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.setup(meas, cur, prop, lo, hi, UI.D4_BLUE_D)
	var id := str(meas["id"])
	sl.committed.connect(func(nv: float) -> void: _set_value(id, nv))
	row.add_child(sl)
	if mode != "program" and can_decree:
		row.add_child(_raise_lower(meas, cur, prop))
	return pc

## Coste de capital político de mover la medida un paso arriba o abajo (como el recuadro «Raise/Lower» de Democracy 4).
func _raise_lower(meas: Dictionary, cur: float, prop: float) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(170, 0)
	pc.add_theme_stylebox_override("panel", UI.box(Color.WHITE, UI.D4_LINE, 4, 1, 10, 8))
	var v := UI.vbox(3)
	pc.add_child(v)
	var step := float(meas["step"])
	var up := Policies.snap(meas, prop + step)
	var dn := Policies.snap(meas, prop - step)
	v.add_child(UI.label("CAPITAL POLÍTICO", UI.FS_TINY, Color("#3B6A99"), true))
	for pair in [["Subir un paso", up], ["Bajar un paso", dn]]:
		var tgt := float(pair[1])
		var ok := tgt >= float(meas["min"]) - 0.001 and tgt <= float(meas["max"]) + 0.001 and not is_equal_approx(tgt, prop)
		var r := UI.hbox(6)
		var a := UI.label(str(pair[0]), UI.FS_SMALL, UI.MUTED)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(a)
		r.add_child(UI.label("%d" % int(m.exec.cost_of(meas, tgt)) if ok else "—", UI.FS_BODY, UI.TEXT, true))
		v.add_child(r)
	var r2 := UI.hbox(6)
	var a2 := UI.label("Disponible", UI.FS_SMALL, UI.MUTED)
	a2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(a2)
	r2.add_child(UI.label("%d" % int(m.exec.capital()), UI.FS_BODY, UI.ACCENT, true))
	v.add_child(r2)
	return pc

func _set_value(id: String, v: float) -> void:
	if mode == "program":
		program_pending[id] = v
	elif mode == "law":
		law_pending[id] = v
	else:
		PanelScreen.pending[id] = v
		PanelScreen.forced.erase(id)
	build()

# ---------------------------------------------------------------- efectos
func _effect_chip(text: String, delta: float, good: int) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color("#E3E9F1"), Color("#C9D4E2"), 14, 1, 12, 4))
	var h := UI.hbox(6)
	pc.add_child(h)
	h.add_child(UI.label(text, UI.FS_BODY, Color("#1F3550"), true))
	var up := delta > 0.0
	var col := UI.ACCENT
	if good != 0:
		col = UI.GOOD if (delta * float(good)) > 0.0 else UI.BAD
	elif not up:
		col = Color("#D9822B")
	var arrow := "▲" if up else "▼"
	if absf(delta) >= 1.0:
		arrow += arrow
	h.add_child(UI.label(arrow, UI.FS_BODY, col, true))
	return pc

func _effects_box(parent: Node, meas: Dictionary, cur: float, prop: float, changed: bool) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color.WHITE, UI.D4_BLUE_D, 3, 2, 18, 14))
	parent.add_child(pc)
	var v := UI.vbox(10)
	pc.add_child(v)
	v.add_child(UI.label("EFECTOS ESTIMADOS" + ("  ·  con tu cambio" if changed else "  ·  por cada paso"), UI.FS_SMALL, Color("#3B6A99"), true))
	var steps := (prop - cur) / maxf(0.0001, float(meas["step"])) if changed else 1.0
	# grupos sociales
	var hits: Dictionary = meas.get("hits", {})
	var grows: Array = []
	for g in Policies.groups():
		var gid := str((g as Dictionary)["id"])
		var h := float(hits.get(gid, 0.0)) * steps
		if absf(h) >= 0.05:
			grows.append({"name": Policies.group_name(gid), "d": h})
	grows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["d"])) > absf(float(b["d"])))
	v.add_child(UI.label("Votantes", UI.FS_BODY, UI.MUTED, true))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	v.add_child(fl)
	if grows.is_empty():
		fl.add_child(UI.label("Ningún grupo reacciona de forma directa.", UI.FS_SMALL, UI.FAINT))
	for gr in grows.slice(0, 8):
		fl.add_child(_effect_chip(str(gr["name"]), float(gr["d"]), 1))
	# indicadores
	var fx: Dictionary = meas.get("fx", {})
	var irows: Array = []
	for k in fx.keys():
		var kk := str(k)
		var good := 1
		var sc := 1.0
		if WorldSim.has(kk):
			good = int(WorldSim.def(kk).get("good", 0))
			sc = float(WorldSim.def(kk)["scale"])
		elif PolicyNetwork.CORES.has(kk):
			good = int((PolicyNetwork.CORES[kk] as Array)[2])
			sc = float(WorldSim.CORE_SCALE.get(kk, WorldSim.QUALITY_SCALE))
		var d := float(fx[k]) * steps
		irows.append({"name": WorldSim.name_of(kk), "d": d / maxf(0.0001, sc), "good": good})
	irows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["d"])) > absf(float(b["d"])))
	v.add_child(UI.hsep(Color("#C9D4E2")))
	v.add_child(UI.label("Indicadores del país", UI.FS_BODY, UI.MUTED, true))
	var fl2 := HFlowContainer.new()
	fl2.add_theme_constant_override("h_separation", 6)
	fl2.add_theme_constant_override("v_separation", 6)
	v.add_child(fl2)
	if irows.is_empty():
		fl2.add_child(UI.label("Solo cambia el presupuesto y el ánimo de los grupos.", UI.FS_SMALL, UI.FAINT))
	for ir in irows.slice(0, 12):
		fl2.add_child(_effect_chip(str(ir["name"]), float(ir["d"]), int(ir["good"])))

## En el programa electoral: reacción de los colectivos al conjunto de promesas.
func _program_summary(parent: Node) -> void:
	var c := UI.card(parent, "Tu programa en conjunto", "reacción de cada colectivo", UI.GOOD)
	var sum := m.manifesto.group_summary()
	if sum.is_empty():
		c.add_child(UI.wrap_label("Añade promesas para ver cómo reaccionan los colectivos.", UI.FS_SMALL, UI.FAINT))
		return
	var rows: Array = []
	for it in sum.slice(0, 8):
		var d: Dictionary = it
		rows.append({"label": Policies.group_name(str(d["id"])), "value": float(d["v"]), "color": UI.GOOD if float(d["v"]) >= 0.0 else UI.BAD})
	var bars := DriverBars.new()
	bars.custom_minimum_size.x = 240.0
	bars.label_w = 120.0
	bars.value_fmt = "%+.1f"
	bars.rows = rows
	c.add_child(bars)

# ---------------------------------------------------------------- acciones
func _actions(c: VBoxContainer, meas: Dictionary, owner: int, cur: float, prop: float, changed: bool, can_decree: bool) -> void:
	var id := str(meas["id"])
	if mode == "program":
		_program_actions(c, meas, cur, prop, changed)
		return
	if mode == "law":
		_law_actions(c, meas, cur, prop)
		return
	if not changed:
		c.add_child(UI.wrap_label("Mueve el deslizador para proponer un cambio." if can_decree else "Mueve el deslizador y llévalo al Taller de leyes.", UI.FS_SMALL, UI.FAINT))
		return
	if not can_decree:
		var row0 := UI.hbox(8)
		var b0 := UI.button("Llevar al Taller de leyes", "primary", func() -> void: _to_law(meas, prop), 220)
		b0.custom_minimum_size = Vector2(220, 42)
		row0.add_child(b0)
		row0.add_child(UI.button("Restablecer", "ghost", func() -> void:
			PanelScreen.pending.erase(id)
			build()))
		c.add_child(row0)
		c.add_child(UI.wrap_label("Registrar una ley consume una iniciativa mensual y se vota en el Pleno.", UI.FS_TINY, UI.FAINT))
		return
	var cost := m.exec.cost_of(meas, prop)
	var cons := m.exec.consent(owner, id, prop)
	var status := str(cons["status"])
	var foot := UI.hbox(8)
	var col := UI.GOOD if status == "yes" else (UI.WARN if status == "reluctant" else UI.BAD)
	foot.add_child(UI.chip("%s: %s" % [m.party_short(str(cons["who"])) if str(cons["who"]) != "" else "Consenso", str(cons["label"])], col))
	c.add_child(foot)
	var extra := 3.0 if status == "reluctant" else (8.0 if status == "no" else 0.0)
	var must_force := status == "no"
	var is_forced := bool(PanelScreen.forced.get(id, false))
	var row := UI.hbox(8)
	if must_force and not is_forced:
		row.add_child(UI.button("Forzar (+%d)" % int(extra), "warn", func() -> void:
			PanelScreen.forced[id] = true
			build()))
	var do_issue := func() -> void:
		var r := m.exec.issue(owner, id, prop, is_forced)
		if bool(r["ok"]):
			shell.toast("Decreto aprobado: %s" % str(meas["name"]), "good")
			PanelScreen.pending.erase(id)
			PanelScreen.forced.erase(id)
			shell.refresh()
		else:
			shell.toast(str(r["error"]), "bad")
			_full_refresh()
	var go := UI.button("IMPLEMENTAR  (%d)" % int(cost + extra), "primary", do_issue, 200)
	go.custom_minimum_size = Vector2(200, 42)
	go.disabled = (must_force and not is_forced) or m.exec.capital() < cost + extra
	row.add_child(go)
	row.add_child(UI.button("Como ley", "secondary", func() -> void: _to_law(meas, prop)))
	row.add_child(UI.button("Restablecer", "ghost", func() -> void:
		PanelScreen.pending.erase(id)
		PanelScreen.forced.erase(id)
		build()))
	c.add_child(row)
	if m.exec.capital() < cost + extra:
		c.add_child(UI.label("No tienes capital político suficiente.", UI.FS_SMALL, UI.BAD))

func _program_actions(c: VBoxContainer, meas: Dictionary, cur: float, prop: float, changed: bool) -> void:
	var id := str(meas["id"])
	var mf: Manifesto = m.manifesto
	var promised := mf.has(id)
	var row := UI.hbox(8)
	if changed:
		var do_add := func() -> void:
			var res := mf.set_promise(id, prop)
			if not bool(res.get("ok", false)):
				shell.toast(str(res.get("error", "")), "warn")
			else:
				program_pending.erase(id)
				m.save_now()
			_full_refresh()
		var b := UI.button("AÑADIR AL PROGRAMA" if not promised else "ACTUALIZAR PROMESA", "primary", do_add, 230)
		b.custom_minimum_size = Vector2(230, 42)
		row.add_child(b)
	if promised:
		row.add_child(UI.button("Retirar promesa", "ghost", func() -> void:
			mf.set_promise(id, cur)
			program_pending.erase(id)
			m.save_now()
			_full_refresh()))
	elif changed:
		row.add_child(UI.button("Descartar", "ghost", func() -> void:
			program_pending.erase(id)
			build()))
	if not changed and not promised:
		c.add_child(UI.wrap_label("Mueve el deslizador al valor que prometes y pulsa «Añadir al programa».", UI.FS_SMALL, UI.FAINT))
	c.add_child(row)

func _law() -> Dictionary:
	return m.laws.draft_by_id(law_id) if law_id != "" else {}

## Taller de leyes: incluir la medida (con el valor del deslizador) en el borrador, actualizarla o quitarla.
func _law_actions(c: VBoxContainer, meas: Dictionary, cur: float, prop: float) -> void:
	var id := str(meas["id"])
	var law := _law()
	if law.is_empty():
		return
	var included := (law["changes"] as Dictionary).has(id)
	var inc_val := float((law["changes"] as Dictionary).get(id, cur))
	var differs := not is_equal_approx(prop, inc_val) if included else not is_equal_approx(prop, cur)
	var row := UI.hbox(8)
	if differs:
		var do_add := func() -> void:
			m.laws.set_change(law, id, prop)
			law_pending.erase(id)
			_full_refresh()
		var b := UI.button("ACTUALIZAR EN LA LEY" if included else "INCLUIR EN LA LEY", "primary", do_add, 250)
		b.custom_minimum_size = Vector2(250, 42)
		row.add_child(b)
		row.add_child(UI.button("Descartar cambio", "ghost", func() -> void:
			law_pending.erase(id)
			build()))
	if included:
		row.add_child(UI.button("Quitar de la ley", "secondary", func() -> void:
			m.laws.set_change(law, id, cur)
			law_pending.erase(id)
			_full_refresh()))
	c.add_child(row)
	if not differs and not included:
		c.add_child(UI.wrap_label("Mueve el deslizador al valor que quieres aprobar y pulsa «Incluir en la ley». Cuantas más medidas, más condiciones pedirán los grupos.", UI.FS_SMALL, UI.FAINT))

func _to_law(meas: Dictionary, prop: float) -> void:
	var law := m.laws.new_draft(str(meas["area"]))
	m.laws.set_change(law, str(meas["id"]), prop)
	memory["law"] = {"area": str(meas["area"]), "mid": str(meas["id"])}
	LawsScreen.editing_id = str(law["id"])
	LawsScreen.tab_area = str(meas["area"])
	PanelScreen.pending.erase(str(meas["id"]))
	shell.go("laws")

## Evolución de los últimos años del indicador que más mueve la medida.
func _history_card(parent: Node, meas: Dictionary) -> void:
	var fx: Dictionary = meas.get("fx", {})
	var best := ""
	var best_v := 0.0
	for k in fx.keys():
		var kk := str(k)
		if not WorldSim.has(kk):
			continue
		var v := absf(float(fx[k])) / maxf(0.0001, float(WorldSim.def(kk)["scale"]))
		if v > best_v:
			best_v = v
			best = kk
	if best == "":
		return
	var vals: Array = m.world.series(best)
	if vals.size() < 3:
		return
	var c := UI.card(parent, "Evolución · %s" % WorldSim.name_of(best), "últimos %d meses" % vals.size(), UI.ACCENT)
	UI.expand_card(c)
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(300, 120)
	chart.series = [{"id": best, "name": WorldSim.name_of(best), "color": UI.D4_BLUE_D, "values": vals, "width": 3.0}]
	chart.value_fmt = "%.1f"
	chart.allow_negative = true
	chart.fill_first = true
	chart.show_end_labels = false
	c.add_child(chart)

# ---------------------------------------------------------------- IRPF (escala por tramos)
func _detail_irpf_law() -> void:
	var law := _law()
	if law.is_empty():
		return
	var cur := m.eco.irpf_brackets()
	var shown := m.laws.proposed_irpf(law)
	var included := (law["changes"] as Dictionary).has(Irpf.SPECIAL_ID)
	var root := UI.vbox(10)
	_detail.add_child(root)
	var head := UI.hbox(14)
	root.add_child(head)
	head.add_child(Badge.new(Glyphs.of_area(area), Glyphs.area_color(area), 60.0))
	var ht := UI.vbox(3)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_child(UI.label("IRPF por tramos", 30, Color("#0F2A47"), true))
	ht.add_child(UI.label("Define la escala que propone la ley: añade o quita tramos y fija desde qué renta y con qué porcentaje se aplica cada uno.", UI.FS_BODY, UI.MUTED))
	head.add_child(ht)
	if included:
		head.add_child(UI.chip("En la ley", UI.GOOD, true))
		head.add_child(UI.button("Quitar de la ley", "ghost", func() -> void:
			m.laws.set_irpf(law, cur)
			_full_refresh()))
	IrpfEditor.build(root, m, shown, cur, func(nb: Array) -> void:
		m.laws.set_irpf(law, nb)
		_full_refresh(), true)

func _detail_irpf(meas: Dictionary) -> void:
	if mode == "law":
		_detail_irpf_law()
		return
	var mf: Manifesto = m.manifesto
	var promised := mf.has(Irpf.SPECIAL_ID)
	var cur := m.eco.irpf_brackets()
	var shown: Array = mf.irpf_target() if promised else cur
	var root := UI.vbox(10)
	_detail.add_child(root)
	var head := UI.hbox(14)
	root.add_child(head)
	head.add_child(Badge.new(Glyphs.of_area(area), Glyphs.area_color(area), 60.0))
	var ht := UI.vbox(3)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_child(UI.label("IRPF por tramos", 30, Color("#0F2A47"), true))
	ht.add_child(UI.label("Define la escala que prometes: añade o quita tramos y fija desde qué renta y con qué porcentaje se aplica cada uno.", UI.FS_BODY, UI.MUTED))
	head.add_child(ht)
	if promised and not read_only:
		head.add_child(UI.button("Retirar promesa", "ghost", func() -> void:
			mf.set_irpf_promise(cur)
			_full_refresh()))
	IrpfEditor.build(root, m, shown, cur, func(nb: Array) -> void:
		var res := mf.set_irpf_promise(nb)
		if not bool(res.get("ok", false)):
			shell.toast(str(res.get("error", "")), "warn")
		else:
			m.save_now()
		_full_refresh(), not read_only)
