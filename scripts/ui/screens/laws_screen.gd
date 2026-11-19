class_name LawsScreen
extends Screen
## Taller de iniciativas parlamentarias (estilo Democracy 4, a pantalla completa y por módulos y ventanas).
## · Inicio: el cupo del trimestre (3 huecos, también los de las promesas del programa) y tres módulos que abren su ventana:
##   Nueva iniciativa, Borradores y Programa electoral.
## · Editor de leyes y PNL: el navegador de medidas (áreas → medidas → ficha) a la izquierda y, a la derecha, la tramitación:
##   tono del texto, visto bueno de los partidos con sus condiciones, efectos y el botón de registrar.
## · Editor de interpelaciones: área, tono de la intervención y clima político.

static var editing_id := ""
static var tab_area := ""
static var irpf_open := false
static var open_party := ""
static var new_kind := "ley"
static var prog_page := 0
static var _mem_law := ""
const PROG_PAGE := 6

var _side: VBoxContainer
var _side_foot: HBoxContainer

func wants_full() -> bool:
	return true

func build() -> void:
	m.eco.ensure()
	if editing_id != "" and m.laws.draft_by_id(editing_id).is_empty():
		editing_id = ""
	if editing_id == "":
		_mem_law = ""
		_home()
		return
	var law := m.laws.draft_by_id(editing_id)
	if str(law.get("kind", "")) == "interpelacion":
		_editor_interp(law)
	else:
		_editor(law)

func _kind_name(law: Dictionary) -> String:
	match str(law.get("kind", "")):
		"pnl": return "PNL"
		"interpelacion": return "Interpelación"
	return "Ley"

func _kind_color(law: Dictionary) -> Color:
	match str(law.get("kind", "")):
		"pnl": return UI.WARN
		"interpelacion": return Color("#7C5CFC")
	return UI.ACCENT

# ================================================================ inicio
## Mesa de trabajo: el cupo del trimestre arriba y tres módulos grandes que abren su ventana.
func _home() -> void:
	_strip()
	var body := UI.vbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_slots_card(body)
	var tiles := UI.hbox(12)
	body.add_child(tiles)
	var nd := 0
	for l in m.laws.drafts():
		if str((l as Dictionary).get("promise", "")) == "":
			nd += 1
	_tile(tiles, "+", "Nueva iniciativa", "Redacta una proposición de ley, una PNL o una interpelación.", "Crear", UI.ACCENT, _open_new)
	_tile(tiles, "≡", "Borradores", "Lo que tienes a medias. Edítalo y regístralo cuando esté listo.", "%d" % nd, UI.WARN, _open_drafts)
	if m.manifesto.count() > 0:
		var late := m.manifesto.late_list().size()
		var pend := _program_pending()
		_tile(tiles, "★", "Programa electoral", "Tus promesas ya redactadas. Cuentan para el cupo trimestral como cualquier otra.", "%d pendientes%s" % [pend, " · %d con retraso" % late if late > 0 else ""], UI.BAD if late > 0 else UI.GOOD, _open_program)

func _strip() -> void:
	var role := m.role()
	var intro := "Gobierno: proyectos de ley" if role == "government" else ("Socio de Gobierno: proposiciones" if role == "partner" else "Oposición: proposiciones, PNL e interpelaciones")
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 14, 8))
	var h := UI.hbox(10)
	bar.add_child(h)
	h.add_child(UI.label("TALLER DE INICIATIVAS", UI.FS_SMALL, UI.MUTED, true))
	h.add_child(UI.label(intro, UI.FS_BODY, UI.TEXT))
	h.add_child(UI.fill())
	var cl := m.congress.control_left()
	h.add_child(UI.chip("%d de %d acciones de control" % [cl, Congress.CONTROL_PER_TURN], UI.GOOD if cl > 0 else UI.FAINT, false))
	if m.congress.pending():
		h.add_child(UI.button("Ir al Pleno →", "primary", _on_go_plenary))
	add_child(bar)

func _on_go_plenary() -> void:
	shell.go("plenary")

func _tile(parent: Node, glyph: String, title: String, desc: String, badge: String, col: Color, cb: Callable) -> void:
	var inner := UI.select_row(parent, false, cb, col, 210)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var g := UI.label(glyph, 44, col, true)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(g)
	var t := UI.label(title, UI.FS_H2, UI.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UI.wrap_label(desc, UI.FS_BODY, UI.MUTED)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var cr := HBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.add_child(UI.chip(badge, col, true))
	v.add_child(cr)
	inner.add_child(v)
	UI.pass_clicks(inner)

## Los tres huecos del trimestre: registradas, ya tramitadas o libres.
func _slots_card(parent: Node) -> void:
	var cap := GovernmentSim.INITIATIVES_PER_TURN
	var left := m.gov.bills_left()
	var c := UI.card(parent, "Cupo de este trimestre", "%d de %d iniciativas libres · máximo %d por trimestre, también las del programa" % [left, cap, cap], UI.GOOD if left > 0 else UI.BAD)
	var row := UI.hbox(10)
	c.add_child(row)
	var q := m.laws.queue()
	var used := cap - left
	for i in range(cap):
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var filled := i < q.size() or i < used
		pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL.lerp(UI.ACCENT, 0.06) if filled else UI.PANEL, UI.ACCENT if i < q.size() else UI.D4_LINE, 4, 1, 12, 10))
		row.add_child(pc)
		var v := UI.vbox(4)
		pc.add_child(v)
		v.add_child(UI.label("HUECO %d" % (i + 1), UI.FS_TINY, UI.MUTED, true))
		if i < q.size():
			_slot_law(v, q[i] as Dictionary)
		elif i < used:
			v.add_child(UI.label("Ya tramitada este trimestre", UI.FS_BODY, UI.MUTED, true))
			v.add_child(UI.label("el cupo se renueva el mes que viene", UI.FS_SMALL, UI.FAINT))
		else:
			v.add_child(UI.label("Libre", UI.FS_LEAD, UI.GOOD, true))
			v.add_child(UI.label("registra una iniciativa para ocuparlo", UI.FS_SMALL, UI.FAINT))

func _slot_law(v: VBoxContainer, law: Dictionary) -> void:
	var lid := str(law["id"])
	var tl := UI.label(str(law["title"]), UI.FS_BODY, UI.TEXT, true)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tl)
	var chips := UI.hbox(6)
	chips.add_child(UI.chip(_kind_name(law), _kind_color(law), true))
	if m.laws.has_votes(law):
		var fc := m.laws.forecast(law)
		var ok := m.laws.passes(law, int(fc["yes"]), int(fc["no"]))
		chips.add_child(UI.chip("%d–%d · %s" % [int(fc["yes"]), int(fc["no"]), "saldría" if ok else "sin apoyos"], UI.GOOD if ok else UI.BAD))
	else:
		chips.add_child(UI.chip("debate de control", UI.MUTED))
	chips.add_child(UI.fill())
	chips.add_child(UI.mini_button("Retirar", _on_unregister.bind(lid)))
	v.add_child(chips)

func _on_unregister(lid: String) -> void:
	if m.laws.unregister(lid):
		shell.toast("Iniciativa devuelta a borradores. Recuperas el hueco.", "neutral")
		shell.refresh_chrome()
	rebuild()

# ---------------------------------------------------------------- ventanas (módulos)
func _window(title: String, width: float, subtitle: String = "") -> VBoxContainer:
	return shell.modal(title, width, subtitle)

func _close_row(col: VBoxContainer, extra: Control = null) -> void:
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	if extra != null:
		row.add_child(extra)
	row.add_child(UI.button("Cerrar", "ghost", shell.close_modal))
	col.add_child(row)

func _scroll_list(col: VBoxContainer, height: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, height)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	var list := UI.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return list

# --- nueva iniciativa
func _open_new() -> void:
	var left := m.gov.bills_left()
	var col := _window("Nueva iniciativa", 720.0, "Elige el tipo y el área. Después la redactas y la registras.")
	var kinds := [["ley", "Proposición de ley", "Cambia medidas del país si el Congreso la aprueba."],
		["pnl", "Proposición no de ley", "Declaración no vinculante: retrata a quien vota en contra."],
		["interpelacion", "Interpelación", "Debate de control sin votación."]]
	var kr := UI.hbox(8)
	col.add_child(kr)
	for k in kinds:
		var kid: String = k[0]
		var kc := UI.ACCENT if kid == "ley" else (UI.WARN if kid == "pnl" else Color("#7C5CFC"))
		var inner := UI.select_row(kr, new_kind == kid, _on_pick_kind.bind(kid), kc, 88)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(UI.label(str(k[1]), UI.FS_BODY, UI.TEXT, true))
		v.add_child(UI.wrap_label(str(k[2]), UI.FS_SMALL, UI.MUTED))
		inner.add_child(v)
		UI.pass_clicks(inner)
	col.add_child(UI.label("ÁREA", UI.FS_TINY, UI.MUTED, true))
	var g := UI.grid(4, 6, 6)
	col.add_child(g)
	for a in Policies.areas():
		var ad: Dictionary = a
		var aid := str(ad["id"])
		var pb := UI.pill(str(ad["name"]), false, _on_create.bind(aid), false, Color(str(ad.get("color", "#7C5CFC"))))
		pb.tooltip_text = str(ad["desc"])
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(pb)
	if left <= 0:
		col.add_child(UI.wrap_label("Este mes ya has usado tus %d iniciativas: puedes dejar el borrador listo, pero no registrarlo hasta el mes que viene." % GovernmentSim.INITIATIVES_PER_TURN, UI.FS_SMALL, UI.WARN))
	_close_row(col)

func _on_pick_kind(kid: String) -> void:
	new_kind = kid
	_open_new()

func _on_create(aid: String) -> void:
	var law := m.laws.new_draft(aid, new_kind)
	editing_id = str(law["id"])
	tab_area = aid
	_mem_law = ""
	shell.close_modal()
	rebuild()

# --- borradores
func _open_drafts() -> void:
	var col := _window("Borradores", 640.0, "Iniciativas a medias. Las del programa están en su propia ventana.")
	var list := _scroll_list(col, 330.0)
	var shown := 0
	for l in m.laws.drafts():
		var law: Dictionary = l
		if str(law.get("promise", "")) != "":
			continue
		shown += 1
		var lid := str(law["id"])
		var row := UI.hbox(8)
		row.add_child(UI.chip(_kind_name(law), _kind_color(law)))
		var vv := UI.vbox(0)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tl := UI.label(str(law["title"]), UI.FS_BODY, UI.TEXT, true)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vv.add_child(tl)
		var nch := (law["changes"] as Dictionary).size()
		var sub := "%s · %d medida%s" % [str(Policies.area(str(law["area"])).get("name", "")), nch, "" if nch == 1 else "s"]
		if str(law.get("kind", "")) == "interpelacion":
			sub = "%s · tono %s" % [str(Policies.area(str(law["area"])).get("name", "")), str(LawMaker.STYLES.get(str(law.get("style", "tecnico")), {}).get("name", "")).to_lower()]
		vv.add_child(UI.label(sub, UI.FS_SMALL, UI.MUTED))
		row.add_child(vv)
		row.add_child(UI.button("Editar", "primary", _on_edit.bind(lid)))
		row.add_child(UI.button("Descartar", "ghost", _on_discard.bind(lid)))
		list.add_child(row)
	if shown == 0:
		empty_note(list, "No tienes borradores. Crea una iniciativa desde «Nueva iniciativa».")
	_close_row(col)

func _on_edit(lid: String) -> void:
	var law := m.laws.draft_by_id(lid)
	if law.is_empty():
		return
	editing_id = lid
	tab_area = str(law["area"])
	_mem_law = ""
	shell.close_modal()
	rebuild()

func _on_discard(lid: String) -> void:
	m.laws.delete_draft(lid)
	rebuild()
	_open_drafts()

# --- programa electoral
func _program_pending() -> int:
	var n := 0
	for r in m.manifesto.report():
		if str((r as Dictionary)["bill_state"]) == "draft":
			n += 1
	return n

func _bill_chip(state: String) -> PanelContainer:
	match state:
		"passed": return UI.chip("Aprobada", UI.GOOD)
		"registered": return UI.chip("En el Congreso", UI.ACCENT)
		"rejected": return UI.chip("Rechazada", UI.BAD)
		"draft": return UI.chip("Pendiente", UI.WARN)
	return UI.chip("Sin redactar", UI.MUTED)

func _open_program() -> void:
	var mf := m.manifesto
	var late := mf.late_list().size()
	var sub := "Cada promesa es una proposición ya redactada. Cuentan para el tope de %d iniciativas por trimestre." % GovernmentSim.INITIATIVES_PER_TURN
	if late > 0:
		sub += " %d con retraso: los votantes lo notan." % late
	var col := _window("Programa electoral", 700.0, sub)
	var pending := _program_pending()
	var left := m.gov.bills_left()
	var rep := mf.report()
	var pages := maxi(1, int(ceil(float(rep.size()) / float(PROG_PAGE))))
	prog_page = clampi(prog_page, 0, pages - 1)
	for k in range(prog_page * PROG_PAGE, mini(rep.size(), (prog_page + 1) * PROG_PAGE)):
		var rd: Dictionary = rep[k]
		var mid := str(rd["id"])
		var row := UI.hbox(8)
		var vv := UI.vbox(0)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UI.label(str(rd["name"]), UI.FS_BODY, UI.TEXT, true)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vv.add_child(nl)
		var meas := Policies.measure(mid)
		var txt := "%s → %s" % [Policies.value_text(meas, float(rd["from"])), Policies.value_text(meas, float(rd["to"]))]
		if bool(rd["late"]):
			txt += "  ·  CON RETRASO"
		var sl := UI.label(txt, UI.FS_SMALL, UI.BAD if bool(rd["late"]) else UI.MUTED)
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vv.add_child(sl)
		row.add_child(vv)
		row.add_child(_bill_chip(str(rd["bill_state"])))
		if str(rd["bill_state"]) == "draft":
			var bid := str((mf.promises()[mid] as Dictionary).get("bill", ""))
			row.add_child(UI.mini_button("Editar", _on_edit_promise.bind(bid)))
			var rb := UI.mini_button("Registrar", _on_register_promise.bind(bid))
			rb.disabled = left <= 0
			row.add_child(rb)
		col.add_child(row)
	if pages > 1:
		var pg := UI.hbox(8)
		var prev := UI.mini_button("◀", _on_prog_page.bind(-1))
		prev.disabled = prog_page <= 0
		var next := UI.mini_button("▶", _on_prog_page.bind(1))
		next.disabled = prog_page >= pages - 1
		pg.add_child(prev)
		var pl := UI.label("Página %d de %d" % [prog_page + 1, pages], UI.FS_SMALL, UI.MUTED)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pg.add_child(pl)
		pg.add_child(next)
		col.add_child(pg)
	col.add_child(UI.label("Te quedan %d de %d iniciativas este trimestre." % [left, GovernmentSim.INITIATIVES_PER_TURN], UI.FS_SMALL, UI.GOOD if left > 0 else UI.BAD, true))
	var allb := UI.button("Registrar pendientes (%d)" % mini(pending, left), "primary", _on_register_all)
	allb.disabled = pending == 0 or left <= 0
	var rec := UI.button("Recuperar las que falten", "ghost", _on_recover)
	var extra := UI.hbox(8)
	extra.add_child(rec)
	extra.add_child(allb)
	_close_row(col, extra)

func _on_prog_page(d: int) -> void:
	prog_page += d
	_open_program()

func _on_register_promise(bid: String) -> void:
	var err := m.laws.register(bid)
	if err != "":
		shell.toast(err, "bad")
	else:
		shell.toast("Proposición registrada para el próximo Pleno.", "good")
	shell.refresh_chrome()
	rebuild()
	_open_program()

func _on_register_all() -> void:
	var n := 0
	var skipped := 0
	for d in m.laws.drafts().duplicate():
		if str((d as Dictionary).get("promise", "")) == "":
			continue
		if m.laws.register(str((d as Dictionary)["id"])) == "":
			n += 1
		else:
			skipped += 1
	var msg := "%d proposiciones registradas para el próximo Pleno." % n
	if skipped > 0:
		msg += " Las otras %d esperan: el tope es de %d iniciativas por trimestre." % [skipped, GovernmentSim.INITIATIVES_PER_TURN]
	shell.toast(msg, "good" if n > 0 else "warn")
	shell.refresh_chrome()
	rebuild()
	_open_program()

func _on_recover() -> void:
	var n2 := m.manifesto.ensure_bills()
	shell.toast("%d proposiciones recuperadas." % n2 if n2 > 0 else "No falta ninguna.", "good" if n2 > 0 else "neutral")
	rebuild()
	_open_program()

func _on_edit_promise(bid: String) -> void:
	var dl := m.laws.draft_by_id(bid)
	if dl.is_empty():
		shell.toast("La proposición no existe; pulsa «Recuperar las que falten».", "bad")
		return
	editing_id = bid
	tab_area = str(dl["area"])
	_mem_law = ""
	shell.close_modal()
	rebuild()

# ================================================================ editor de leyes y PNL
func _editor_top(law: Dictionary) -> void:
	var area := Policies.area(str(law["area"]))
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 12, 6))
	var top := UI.hbox(10)
	bar.add_child(top)
	top.add_child(UI.button("← Taller", "ghost", _on_back))
	top.add_child(UI.chip(_kind_name(law), _kind_color(law), true))
	var title_edit := LineEdit.new()
	title_edit.text = str(law["title"])
	title_edit.max_length = 80
	title_edit.placeholder_text = "Título de la iniciativa"
	title_edit.custom_minimum_size = Vector2(360, 34)
	title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_edit.text_changed.connect(_on_title.bind(law))
	top.add_child(title_edit)
	top.add_child(UI.chip(str(area.get("name", "")), Color(str(area.get("color", "#2563EB")))))
	add_child(bar)

func _on_title(t: String, law: Dictionary) -> void:
	law["title"] = t

func _on_back() -> void:
	editing_id = ""
	open_party = ""
	rebuild()

func _editor(law: Dictionary) -> void:
	_editor_top(law)
	var row := UI.hbox(0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	if _mem_law != editing_id:
		_mem_law = editing_id
		var start_area := tab_area if tab_area != "" else str(law["area"])
		var first_mid := ""
		for it in Policies.measures_of(start_area, true):
			if (law["changes"] as Dictionary).has(str((it as Dictionary)["id"])):
				first_mid = str((it as Dictionary)["id"])
				break
		if PolicyBrowser.memory.get("law", {}).get("area", "") != start_area or first_mid != "":
			PolicyBrowser.memory["law"] = {"area": start_area, "mid": first_mid}
	var br := PolicyBrowser.create(shell, m, "law", [], _fill_side)
	br.law_id = editing_id
	row.add_child(br)
	var side_wrap := PanelContainer.new()
	side_wrap.custom_minimum_size = Vector2(430, 0)
	side_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_wrap.add_theme_stylebox_override("panel", UI.box(Color("#E9EFF8"), UI.D4_LINE, 0, 1, 10, 10))
	row.add_child(side_wrap)
	var col := UI.vbox(8)
	side_wrap.add_child(col)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	_side = UI.vbox(8)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_side)
	_side_foot = UI.hbox(8)
	col.add_child(_side_foot)
	_fill_side()

func _fill_side() -> void:
	if _side == null or not is_instance_valid(_side):
		return
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	UI.clear_children(_side)
	UI.clear_children(_side_foot)
	_tone_card(_side, law)
	_summary_card(_side, law)
	_consultation(_side, law)
	if str(law.get("kind", "")) != "pnl":
		_effects(_side, law)
	_foot(law)

# ---------------------------------------------------------------- tono del texto
func _tone_card(parent: Node, law: Dictionary) -> void:
	var c := UI.card(parent, "Tono del texto", "cómo se presenta la iniciativa", UI.ACCENT)
	var row := UI.hbox(6)
	var cur := str(law.get("tone", "estandar"))
	for key in LawMaker.TONES.keys():
		var k := str(key)
		var tb := UI.pill(str(LawMaker.TONES[k]["name"]), cur == k, _on_tone.bind(k), false, UI.PILL_SUB)
		row.add_child(tb)
	c.add_child(row)
	c.add_child(UI.wrap_label(str(LawMaker.TONES.get(cur, {}).get("desc", "")), UI.FS_SMALL, UI.MUTED))

func _on_tone(k: String) -> void:
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	law["tone"] = k
	_fill_side()

# ---------------------------------------------------------------- resumen
func _summary_card(parent: Node, law: Dictionary) -> void:
	var changes: Dictionary = law["changes"]
	var c := UI.card(parent, "Qué incluye", "%d medida%s" % [changes.size(), "" if changes.size() == 1 else "s"], _kind_color(law))
	c.add_child(UI.label(m.laws.required_text(law), UI.FS_SMALL, UI.WARN if m.laws.is_organic(law) else UI.MUTED, true))
	if changes.is_empty():
		empty_note(c, "Aún no has incluido ninguna medida. Elígelas a la izquierda y pulsa «Incluir en la ley».")
	var lines := m.laws.change_lines(law)
	var keys: Array = changes.keys()
	for i in range(lines.size()):
		var d: Dictionary = lines[i]
		var r := UI.hbox(6)
		var t := UI.wrap_label("%s: %s → %s" % [str(d["name"]), str(d["from"]), str(d["to"])], UI.FS_SMALL, UI.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		if i < keys.size():
			r.add_child(UI.mini_button("✕", _on_remove.bind(str(keys[i]))))
		c.add_child(r)

func _on_remove(mid: String) -> void:
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	if mid == Irpf.SPECIAL_ID:
		m.laws.set_irpf(law, m.eco.irpf_brackets())
	else:
		m.laws.set_change(law, mid, m.eco.value(mid))
	rebuild()

# ---------------------------------------------------------------- efectos
func _effects(parent: Node, law: Dictionary) -> void:
	var changes: Dictionary = law["changes"]
	if changes.is_empty():
		return
	var pv := m.eco.preview(changes, m.laws.proposed_irpf(law))
	var c := UI.card(parent, "Efectos previstos", "con la ley en régimen", UI.WARN)
	var bal := float(pv["balance"])
	c.add_child(UI.label("Saldo público: %s bn €/año" % UI.signed(bal, 1), UI.FS_LEAD, UI.GOOD if bal >= 0.0 else UI.BAD, true))
	c.add_child(UI.label("Ingresos %s · Gasto %s bn €" % [UI.signed(float(pv["revenue"]), 1), UI.signed(float(pv["spending"]), 1)], UI.FS_SMALL, UI.MUTED))
	var after := -(m.eco.balance() + bal) / maxf(1.0, m.eco.gdp()) * 100.0
	c.add_child(UI.label("Déficit resultante: %.2f %% del PIB (ahora %.2f %%)" % [after, -m.eco.balance_pct()], UI.FS_SMALL, UI.TEXT))
	var fx: Dictionary = pv["fx"]
	var lines: Array = []
	for k in fx.keys():
		var val := float(fx[k])
		var good := val > 0.0
		if str(k) in ["unemployment", "inflation"]:
			good = val < 0.0
		var unit := " pp" if str(k) in ["growth", "unemployment", "inflation"] else " pts"
		lines.append({"txt": "%s %s%s" % [Policies.quality_name(str(k)), UI.signed(val, 1), unit], "good": good, "v": absf(val)})
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["v"]) > float(b["v"]))
	for it in lines.slice(0, 5):
		c.add_child(UI.label(("▲ " if bool((it as Dictionary)["good"]) else "▼ ") + str((it as Dictionary)["txt"]), UI.FS_SMALL, UI.GOOD if bool((it as Dictionary)["good"]) else UI.BAD))
	var gl: Array = []
	for g in (pv["groups"] as Dictionary).keys():
		gl.append({"id": str(g), "v": float(pv["groups"][g])})
	gl.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["v"]) > float(b["v"]))
	if not gl.is_empty():
		c.add_child(UI.hsep())
		c.add_child(UI.label("REACCIÓN DE LOS COLECTIVOS", UI.FS_TINY, UI.MUTED, true))
		for it2 in gl.slice(0, 2):
			c.add_child(UI.label("▲ %s %s" % [Policies.group_name(str((it2 as Dictionary)["id"])), UI.signed(float((it2 as Dictionary)["v"]), 1)], UI.FS_SMALL, UI.GOOD))
		var worst := gl.slice(maxi(0, gl.size() - 2), gl.size())
		worst.reverse()
		for it3 in worst:
			if float((it3 as Dictionary)["v"]) < 0.0:
				c.add_child(UI.label("▼ %s %s" % [Policies.group_name(str((it3 as Dictionary)["id"])), UI.signed(float((it3 as Dictionary)["v"]), 1)], UI.FS_SMALL, UI.BAD))

# ---------------------------------------------------------------- visto bueno de los partidos
func _vote_chip(vote: String) -> PanelContainer:
	match vote:
		"yes": return UI.chip("A favor", UI.GOOD, true)
		"no": return UI.chip("En contra", UI.BAD, true)
	return UI.chip("Abstención", UI.MUTED, true)

func _consultation(parent: Node, law: Dictionary) -> void:
	var changes: Dictionary = law["changes"]
	var c := UI.card(parent, "Visto bueno de los partidos", "consulta previa", UI.GOOD)
	if changes.is_empty():
		empty_note(c, "Incluye medidas para saber cómo reaccionarían los partidos.")
		return
	var fc := m.laws.forecast(law)
	var ok := m.laws.passes(law, int(fc["yes"]), int(fc["no"]))
	var line := UI.hbox(14)
	line.add_child(UI.label("%d a favor" % int(fc["yes"]), UI.FS_LEAD, UI.GOOD, true))
	line.add_child(UI.label("%d en contra" % int(fc["no"]), UI.FS_LEAD, UI.BAD, true))
	line.add_child(UI.label("%d abst." % int(fc["abstain"]), UI.FS_BODY, UI.MUTED))
	c.add_child(line)
	var mb := UI.meter(float(fc["yes"]), 350.0, UI.GOOD if ok else UI.WARN, 8)
	mb.marker = float(Rules.MAJORITY if m.laws.is_organic(law) else 175)
	c.add_child(mb)
	c.add_child(UI.label("Con las posturas actuales %s." % ("saldría adelante" if ok else "NO saldría adelante"), UI.FS_BODY, UI.GOOD if ok else UI.BAD, true))
	if not ok:
		c.add_child(UI.label("Faltan votos: acepta condiciones o suaviza el texto. Antes del voto podrás negociar enmiendas.", UI.FS_SMALL, UI.MUTED))
	c.add_child(UI.hsep())
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		if m.is_player(pid):
			continue
		var st := m.laws.stance(law, pid)
		var vote := str(st["vote"])
		var row := UI.hbox(8)
		var tag := UI.party_tag(m, pid, UI.FS_SMALL, false)
		tag.custom_minimum_size = Vector2(96, 0)
		row.add_child(tag)
		row.add_child(UI.label("%d" % m.seats_of(pid), UI.FS_SMALL, UI.FAINT))
		var sc := float(st["score"])
		var mt := UI.meter((sc + 1.0) * 50.0, 100.0, UI.GOOD if sc >= 0.12 else (UI.BAD if sc <= -0.12 else UI.MUTED), 6)
		mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mt.marker = 50.0
		row.add_child(mt)
		row.add_child(_vote_chip(vote))
		c.add_child(row)
		var conds: Array = st["conditions"]
		if vote != "yes":
			for cd in conds.slice(0, 2):
				var cdict: Dictionary = cd
				var crow := UI.hbox(8)
				var txt := UI.wrap_label("• %s" % str(cdict["text"]), UI.FS_TINY, UI.MUTED)
				txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				crow.add_child(txt)
				crow.add_child(UI.mini_button("Aceptar", _on_condition.bind(pid, cdict)))
				c.add_child(crow)

func _on_condition(pid: String, cond: Dictionary) -> void:
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	m.laws.apply_condition(law, pid, cond)
	rebuild()

# ---------------------------------------------------------------- pie: registrar
func _foot(law: Dictionary) -> void:
	var changes: Dictionary = law["changes"]
	var kind := str(law.get("kind", ""))
	var control := kind in ["pnl", "interpelacion"]
	var from_program := str(law.get("promise", "")) != ""
	var left := m.gov.bills_left()
	var ctl := m.congress.control_left()
	var blocked := left <= 0 or (control and ctl <= 0)
	var reg := UI.button("Registrar en el Congreso", "primary", _on_register, 230)
	reg.custom_minimum_size = Vector2(230, 42)
	reg.disabled = (changes.is_empty() and kind != "interpelacion") or blocked
	_side_foot.add_child(reg)
	if not from_program:
		_side_foot.add_child(UI.button("Descartar", "ghost", _on_discard_open))
	var note := UI.label("Te quedan %d de %d iniciativas este trimestre." % [left, GovernmentSim.INITIATIVES_PER_TURN], UI.FS_SMALL, UI.MUTED)
	if left <= 0:
		note.text = "Ya has usado las %d iniciativas de este trimestre." % GovernmentSim.INITIATIVES_PER_TURN
		note.add_theme_color_override("font_color", UI.WARN)
	elif control and ctl <= 0:
		note.text = "No quedan acciones de control este trimestre."
		note.add_theme_color_override("font_color", UI.WARN)
	_side_foot.add_child(note)

func _on_register() -> void:
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	var err := m.laws.register(str(law["id"]))
	if err != "":
		shell.toast(err, "bad")
		return
	shell.toast("Iniciativa registrada. Se debatirá en el próximo Pleno.", "good")
	editing_id = ""
	shell.refresh_chrome()
	rebuild()

func _on_discard_open() -> void:
	m.laws.delete_draft(editing_id)
	editing_id = ""
	rebuild()

# ================================================================ editor de interpelaciones
func _editor_interp(law: Dictionary) -> void:
	_editor_top(law)
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := UI.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.85
	row.add_child(right)
	# área
	var ca := UI.card(left, "Área del debate", "dónde interpelas al Gobierno", Color("#7C5CFC"))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for a in Policies.areas():
		var ad: Dictionary = a
		var aid := str(ad["id"])
		var b := UI.pill(("● " if str(law["area"]) == aid else "") + str(ad["name"]), str(law["area"]) == aid, _on_interp_area.bind(aid), false, Color(str(ad.get("color", "#7C5CFC"))))
		fl.add_child(b)
	ca.add_child(fl)
	# tono
	var ct := UI.card(left, "Tono de la intervención", "decide el riesgo y la recompensa", Color("#7C5CFC"))
	var cur := str(law.get("style", "tecnico"))
	for key in LawMaker.STYLES.keys():
		var k := str(key)
		var inner := UI.select_row(ct, cur == k, _on_style.bind(k), Color("#7C5CFC"), 74)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(UI.label(str(LawMaker.STYLES[k]["name"]), UI.FS_LEAD, UI.TEXT, true))
		v.add_child(UI.wrap_label(str(LawMaker.STYLES[k]["desc"]), UI.FS_SMALL, UI.MUTED))
		inner.add_child(v)
		var risk := UI.chip("riesgo alto" if k == "duro" else ("riesgo bajo" if k == "propositivo" else "riesgo medio"), UI.BAD if k == "duro" else (UI.GOOD if k == "propositivo" else UI.WARN))
		risk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(risk)
		UI.pass_clicks(inner)
	var co := UI.card(left, "Posibles resultados", "según el clima y tu tono", UI.ACCENT)
	UI.expand_card(co)
	for tr in [["Golpe de efecto", "Abres los telediarios: sube tu visibilidad y baja el apoyo al Gobierno.", UI.GOOD], ["El debate cuaja", "El Gobierno tiene que dar explicaciones: ganancia moderada.", UI.GOOD], ["Sin pena ni gloria", "Pasa desapercibida y pierdes algo de confianza.", UI.MUTED], ["Tiro por la culata", "Solo con tono duro: el Gobierno te replica con datos y pierdes confianza.", UI.BAD]]:
		var rr := UI.hbox(8)
		rr.add_child(UI.chip(str(tr[0]), tr[2] as Color))
		var tl := UI.wrap_label(str(tr[1]), UI.FS_SMALL, UI.MUTED)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(tl)
		co.add_child(rr)
	# clima
	var cc := UI.card(right, "Clima político", "qué tal pinta el debate", UI.ACCENT)
	var area := Policies.area(str(law["area"]))
	var issue := str(area.get("issue", ""))
	var sal := float(m.campaign.salience().get(issue, 0.12))
	var appr := m.gov.approval()
	var base := 0.46 + (50.0 - appr) / 120.0 + (sal - 0.12) * 1.2
	var mood := "favorable" if base >= 0.56 else ("difícil" if base < 0.44 else "equilibrado")
	cc.add_child(UI.label("Ambiente: %s" % mood, UI.FS_H2, UI.GOOD if mood == "favorable" else (UI.BAD if mood == "difícil" else UI.WARN), true))
	cc.add_child(UI.meter(clampf(base, 0.0, 1.0), 1.0, UI.GOOD if mood == "favorable" else (UI.BAD if mood == "difícil" else UI.WARN), 12))
	cc.add_child(UI.label("Apoyo al Gobierno: %.0f %%" % appr, UI.FS_BODY, UI.TEXT))
	cc.add_child(UI.label("Interés de la gente por «%s»: %s" % [str(area.get("name", "")).to_lower(), "alto" if sal >= 0.16 else ("medio" if sal >= 0.1 else "bajo")], UI.FS_BODY, UI.TEXT))
	cc.add_child(UI.wrap_label("Cuanto más flaquea el Gobierno y más preocupa el tema, más rédito sacas. El tono «duro» multiplica lo bueno y lo malo.", UI.FS_SMALL, UI.MUTED))
	var cr := UI.card(right, "Registrar", "", UI.GOOD)
	UI.expand_card(cr)
	var left_n := mini(m.congress.control_left(), m.gov.bills_left())
	cr.add_child(UI.wrap_label("Se debatirá en el próximo Pleno. No se vota: se mide el impacto de tu intervención.", UI.FS_BODY, UI.MUTED))
	var reg := UI.button("Registrar la interpelación", "primary", _on_register, 260)
	reg.custom_minimum_size = Vector2(260, 42)
	reg.disabled = left_n <= 0
	cr.add_child(reg)
	cr.add_child(UI.button("Descartar", "ghost", _on_discard_open))
	if left_n <= 0:
		cr.add_child(UI.label("No te quedan huecos o acciones de control este trimestre.", UI.FS_SMALL, UI.WARN))

func _on_interp_area(aid: String) -> void:
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	var old_default := "Interpelación sobre %s" % str(Policies.area(str(law["area"])).get("name", "")).to_lower()
	law["area"] = aid
	if str(law["title"]) == old_default:
		law["title"] = "Interpelación sobre %s" % str(Policies.area(aid).get("name", "")).to_lower()
	tab_area = aid
	rebuild()

func _on_style(k: String) -> void:
	var law := m.laws.draft_by_id(editing_id)
	if law.is_empty():
		return
	law["style"] = k
	rebuild()
