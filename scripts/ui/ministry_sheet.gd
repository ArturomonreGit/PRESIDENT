class_name MinistrySheet
extends RefCounted
## Ficha de una cartera: titular (atributos, personalidad, relación, historial), competencias, acciones del presidente
## y estructura (renombrar, dividir, fusionar, eliminar). Se abre como modal desde el Consejo de Ministros.

var shell
var m: GameModel
var idx := 0
var tab := "minister"
var split_sel: Array = []
var _pick_party: OptionButton
var _pick_other: OptionButton
var _pick_area: OptionButton
var _name_edit: LineEdit
var _desc_edit: LineEdit
var _split_name: LineEdit

static func open(shell_node, model: GameModel, index: int, start_tab: String = "minister") -> void:
	var s := MinistrySheet.new()
	s.shell = shell_node
	s.m = model
	s.idx = index
	s.tab = start_tab
	s.show()

func _president() -> bool:
	return m.phase == "legislature" and m.coal.gov_id() == m.pid()

func _can_edit() -> bool:
	return m.cab.can_edit()

func _cost_text(action: String) -> String:
	var c := float(CabinetSim.ACTION_COST.get(action, 0.0))
	return "" if c <= 0.0 else " (%d cap.)" % int(c)

func show() -> void:
	var e := m.cab.entry(idx)
	if e.is_empty():
		shell.close_modal()
		return
	var party := str(e.get("party", ""))
	var col: VBoxContainer = shell.modal(str(e["name"]), 1040.0)
	var head := UI.hbox(8)
	head.add_child(UI.party_tag(m, party))
	var st := m.cab.status(idx)
	head.add_child(UI.chip(str(st["text"]), UI.tone_color(str(st["tone"])), true))
	if m.cab.is_reserved(idx):
		var rc := UI.chip("Reservada a su partido por el acuerdo", UI.WARN)
		head.add_child(rc)
	var tag := m.mact.tag_of(idx)
	if tag != "":
		head.add_child(UI.chip(tag, UI.BAD if tag == "Rival" else UI.ACCENT))
	head.add_child(UI.chip(str(CabinetSim.AUTONOMY_NAMES.get(str(e.get("autonomy", "plena")), "")), UI.MUTED))
	head.add_child(UI.fill())
	head.add_child(UI.button("Cerrar", "ghost", Callable(shell, "close_modal")))
	col.add_child(head)
	var tabs := UI.hbox(6)
	var order: Array = [["minister", "Ministro"], ["cands", "Candidatos"], ["comps", "Competencias"]]
	if _president():
		order.append(["actions", "Acciones del presidente"])
	if _can_edit():
		order.append(["struct", "Estructura"])
	if not order.any(func(o) -> bool: return str(o[0]) == tab):
		tab = "minister"
	for o in order:
		tabs.add_child(UI.pill(str(o[1]), tab == str(o[0]), Callable(self, "_set_tab").bind(str(o[0])), false))
	col.add_child(tabs)
	col.add_child(UI.hsep())
	match tab:
		"cands":
			_tab_cands(col)
		"comps":
			_tab_comps(col)
		"actions":
			_tab_actions(col)
		"struct":
			_tab_struct(col)
		_:
			_tab_minister(col)

func _set_tab(t: String) -> void:
	tab = t
	show()

func _done(res: Dictionary, then_close: bool = false) -> void:
	if bool(res.get("ok", false)):
		var txt := str(res.get("text", ""))
		if txt != "":
			shell.toast(txt, "positive")
	else:
		shell.toast(str(res.get("error", "No se pudo hacer.")), "negative")
	m.save_now()
	shell.refresh()
	if then_close or idx >= m.cab.size():
		shell.close_modal()
	else:
		show()

# ---------------------------------------------------------------- pestaña Ministro
func _tab_minister(col: VBoxContainer) -> void:
	var e := m.cab.entry(idx)
	var mn := m.cab.minister(idx)
	if mn.is_empty():
		col.add_child(UI.wrap_label("La cartera no tiene titular. Se nombrará uno al empezar el trimestre.", UI.FS_BODY, UI.WARN))
		return
	m.ministers.ensure_profile(mn)
	var cols := UI.hbox(24)
	col.add_child(cols)
	var left := UI.vbox(6)
	left.custom_minimum_size = Vector2(470, 0)
	cols.add_child(left)
	left.add_child(UI.label(Leader.full_name(mn), UI.FS_H2, UI.TEXT, true))
	left.add_child(UI.label("%s · %s" % [m.ministers.personality_name(mn), str(mn.get("style", "técnico"))], UI.FS_BODY, UI.ACCENT, true))
	left.add_child(UI.wrap_label(m.ministers.personality_desc(mn), UI.FS_SMALL, UI.MUTED))
	for k in Ministers.ATTR_ORDER:
		var v := m.ministers.attr(mn, str(k))
		var row := UI.hbox(8)
		var nm := UI.label(str((Ministers.ATTRS[k] as Dictionary)["name"]), UI.FS_SMALL, UI.TEXT)
		nm.custom_minimum_size = Vector2(170, 0)
		nm.tooltip_text = str((Ministers.ATTRS[k] as Dictionary)["desc"])
		row.add_child(nm)
		var good := v >= 7 if str(k) != "ambicion" else true
		var mt := UI.meter(float(v), 10.0, UI.GOOD if v >= 7 and good else (UI.WARN if v >= 4 else UI.BAD), 7)
		mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mt)
		var vl := UI.label("%d" % v, UI.FS_SMALL, UI.TEXT, true)
		vl.custom_minimum_size = Vector2(22, 0)
		row.add_child(vl)
		left.add_child(row)
	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var act := m.cab.act_of(idx)
	right.add_child(_meter_line("Rendimiento", act, 100.0, UI.GOOD if act >= 62.0 else (UI.WARN if act >= 40.0 else UI.BAD)))
	right.add_child(_meter_line("Relación con el presidente", m.ministers.relation(mn), 100.0, UI.ACCENT))
	var sk := m.ministers.effective_skill(mn, str(e["name"]), e)
	right.add_child(_meter_line("Competencia en la cartera", sk, 11.0, UI.GOOD if sk >= 7.0 else (UI.WARN if sk >= 5.0 else UI.BAD)))
	right.add_child(UI.wrap_label(m.ministers.describe(mn, str(e["name"]), e), UI.FS_SMALL, UI.MUTED))
	if str(e.get("party", "")) == m.pid() and (m.phase == "cabinet_design" or _president()):
		right.add_child(UI.button("Comparar los 5 candidatos", "secondary", Callable(self, "_set_tab").bind("cands")))
	right.add_child(UI.label("Historial", UI.FS_SMALL, UI.MUTED, true))
	var hist: Array = mn.get("history", [])
	if hist.is_empty():
		right.add_child(UI.label("Sin episodios destacados.", UI.FS_SMALL, UI.FAINT))
	for h in hist.slice(0, 5):
		right.add_child(UI.wrap_label("T%d · %s" % [int((h as Dictionary).get("turn", 0)), str((h as Dictionary).get("text", ""))], UI.FS_SMALL, UI.TEXT))
	var pend := 0
	for p in m.coal.open_list():
		if str((p as Dictionary).get("ministry_id", "")) == str(e["id"]):
			pend += 1
	if pend > 0:
		right.add_child(UI.chip("%d propuesta%s pendiente%s en la mesa" % [pend, "" if pend == 1 else "s", "" if pend == 1 else "s"], UI.WARN, true))

func _meter_line(title: String, v: float, mx: float, color: Color) -> HBoxContainer:
	var row := UI.hbox(8)
	var l := UI.label(title, UI.FS_SMALL, UI.TEXT)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var mt := UI.meter(v, mx, color, 8)
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mt)
	var vl := UI.label("%.0f" % v, UI.FS_SMALL, UI.TEXT, true)
	vl.custom_minimum_size = Vector2(30, 0)
	row.add_child(vl)
	return row

func _do_pick(pool_id: int) -> void:
	if m.phase == "cabinet_design":
		m.ministers.assign(idx, pool_id)
		_done({"ok": true, "text": "Nombramiento hecho."})
	else:
		_done(m.cab.replace_with(idx, pool_id))

# ---------------------------------------------------------------- pestaña Candidatos
func _tab_cands(col: VBoxContainer) -> void:
	var e := m.cab.entry(idx)
	var party := str(e.get("party", ""))
	var mine := party == m.pid()
	var can_pick := mine and (m.phase == "cabinet_design" or _president()) and not m.cab.is_reserved(idx)
	var cur: Dictionary = m.cab.minister(idx)
	var intro := ""
	if mine:
		intro = "Cinco candidatos plausibles para %s, con su encaje real en la cartera. Ninguno es mejor en todo: elige qué riesgo asumes." % str(e["name"])
		if can_pick and _president():
			intro += " Cambiar de titular cuesta %d de capital político." % int(CabinetSim.ACTION_COST.get("replace", 0.0))
	else:
		intro = "%s elige a su ministro de esta cartera entre estos cinco candidatos, según los rasgos de su partido." % m.party_name(party)
	col.add_child(UI.wrap_label(intro, UI.FS_SMALL, UI.MUTED))
	var row := UI.hbox(8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var list: Array = m.cands.shortlist(idx)
	var chosen_id := int(cur.get("pool_id", -9))
	for c in list:
		row.add_child(_cand_card(c as Dictionary, e, chosen_id, can_pick, mine))
	if list.is_empty():
		col.add_child(UI.wrap_label("No hay candidatos disponibles para esta cartera.", UI.FS_BODY, UI.WARN))

func _cand_card(c: Dictionary, e: Dictionary, chosen_id: int, can_pick: bool, mine: bool) -> Control:
	m.ministers.ensure_profile(c)
	var is_cur := int(c.get("pool_id", -1)) == chosen_id
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(150, 0)
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL if not is_cur else UI.PANEL.lerp(UI.GOOD, 0.08), UI.GOOD if is_cur else UI.D4_LINE, 6, 2 if is_cur else 1, 8, 8))
	var v := UI.vbox(3)
	pc.add_child(v)
	var top := UI.hbox(4)
	top.add_child(UI.chip(m.cands.role_name(c), UI.D4_BLUE))
	if bool(c.get("independent", false)):
		top.add_child(UI.chip("Indep.", UI.MUTED))
	v.add_child(top)
	var nm := UI.label(Leader.full_name(c), UI.FS_BODY, UI.TEXT, true)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.tooltip_text = Leader.full_name(c)
	v.add_child(nm)
	var sub := UI.label("%d años · %s" % [int(c.get("age", 50)), m.ministers.personality_name(c)], UI.FS_TINY, UI.ACCENT, true)
	sub.tooltip_text = m.ministers.personality_desc(c)
	v.add_child(sub)
	var fit := m.cands.fit(c, idx)
	var fl := HBoxContainer.new()
	fl.add_theme_constant_override("separation", 4)
	fl.add_child(UI.label("Encaje", UI.FS_TINY, UI.MUTED))
	var fm := UI.meter(fit, 11.0, UI.GOOD if fit >= 7.0 else (UI.WARN if fit >= 5.0 else UI.BAD), 7)
	fm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fl.add_child(fm)
	fl.add_child(UI.label("%.1f" % fit, UI.FS_SMALL, UI.TEXT, true))
	v.add_child(fl)
	var sp := UI.label("Especialidad: %s" % str(c.get("specialty", "—")), UI.FS_TINY, UI.GOOD if m.ministers.specialty_match(c, str(e["name"]), e) else UI.FAINT)
	sp.clip_text = true
	sp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sp)
	v.add_child(UI.hsep())
	for k in Ministers.ATTR_ORDER:
		var val := m.ministers.attr(c, str(k))
		var ar := HBoxContainer.new()
		ar.add_theme_constant_override("separation", 4)
		var al := UI.label(str(MinistryCandidates.SHORT[str(k)]), UI.FS_TINY, UI.MUTED)
		al.custom_minimum_size = Vector2(78, 0)
		al.clip_text = true
		ar.add_child(al)
		var good := val >= 7 or str(k) == "ambicion"
		var ab := UI.meter(float(val), 10.0, UI.GOOD if val >= 7 and good else (UI.WARN if val >= 4 else UI.BAD), 5)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ar.add_child(ab)
		var avl := UI.label("%d" % val, UI.FS_TINY, UI.TEXT, true)
		avl.custom_minimum_size = Vector2(14, 0)
		ar.add_child(avl)
		v.add_child(ar)
	v.add_child(UI.hsep())
	var nt: Dictionary = m.cands.notes(c, idx)
	for line in nt["strengths"]:
		v.add_child(_note_line("+ " + str(line), UI.GOOD))
	for line in nt["weaknesses"]:
		v.add_child(_note_line("− " + str(line), UI.WARN))
	for line in nt["risks"]:
		v.add_child(_note_line("⚠ " + str(line), UI.BAD))
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp2)
	if is_cur:
		v.add_child(UI.chip("Titular", UI.GOOD, true))
	elif can_pick:
		var pid := int(c.get("pool_id", -1))
		var b := UI.button("Nombrar", "secondary", Callable(self, "_do_pick").bind(pid))
		v.add_child(b)
	return pc

func _note_line(text: String, color: Color) -> Label:
	var l := UI.wrap_label(text, UI.FS_TINY, color)
	l.max_lines_visible = 3
	return l

# ---------------------------------------------------------------- pestaña Competencias
func _tab_comps(col: VBoxContainer) -> void:
	var editable := _can_edit() and not m.cab.is_reserved(idx)
	col.add_child(UI.wrap_label(m.cab.impact_text(idx), UI.FS_SMALL, UI.MUTED))
	if _can_edit() and m.phase == "legislature":
		col.add_child(UI.wrap_label("Cada cambio estructural cuesta %d de capital político (tienes %.0f)." % [int(m.cab.structural_cost()), m.exec.capital()], UI.FS_SMALL, UI.WARN))
	for cat in Competencies.CATEGORY_ORDER:
		var row := UI.hbox(8)
		var cl := UI.label(Competencies.category_name(str(cat)), UI.FS_SMALL, Competencies.category_color(str(cat)), true)
		cl.custom_minimum_size = Vector2(100, 0)
		row.add_child(cl)
		var fl := HFlowContainer.new()
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 4)
		row.add_child(fl)
		for c in Competencies.of_category(str(cat)):
			var cid := str((c as Dictionary)["id"])
			var mine := m.cab.comps_of(idx).has(cid)
			var owner := m.cab.owner_of(cid)
			var b := UI.pill(Competencies.name_of(cid), mine, Callable(self, "_toggle").bind(cid), false)
			b.disabled = not editable
			if owner >= 0 and not mine:
				b.tooltip_text = "Hoy la gestiona «%s»" % str(m.cab.entry(owner)["name"])
				b.modulate = Color(1, 1, 1, 0.65)
			elif owner < 0:
				b.tooltip_text = "Nadie la gestiona"
			fl.add_child(b)
		col.add_child(row)
	# Compartidas
	var sh := m.cab.shared_of(idx)
	var srow := UI.hbox(8)
	var sl := UI.label("Compartidas", UI.FS_SMALL, UI.MUTED, true)
	sl.custom_minimum_size = Vector2(100, 0)
	srow.add_child(sl)
	var sfl := HFlowContainer.new()
	sfl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfl.add_theme_constant_override("h_separation", 6)
	for c in sh:
		var own := m.cab.owner_of(str(c))
		var lab := "%s (con %s)" % [Competencies.name_of(str(c)), str(m.cab.entry(own)["name"]) if own >= 0 else "—"]
		var sb := UI.pill(lab, true, Callable(self, "_toggle_shared").bind(str(c)), false)
		sb.disabled = not editable
		sfl.add_child(sb)
	if editable:
		var opt := OptionButton.new()
		opt.add_item("Compartir otra competencia…")
		opt.set_item_metadata(0, "")
		for c in Competencies.catalog():
			var cid2 := str((c as Dictionary)["id"])
			var o2 := m.cab.owner_of(cid2)
			if o2 >= 0 and o2 != idx and not sh.has(cid2):
				opt.add_item(Competencies.name_of(cid2))
				opt.set_item_metadata(opt.item_count - 1, cid2)
		opt.item_selected.connect(Callable(self, "_share_selected").bind(opt))
		sfl.add_child(opt)
	elif sh.is_empty():
		sfl.add_child(UI.label("Ninguna", UI.FS_SMALL, UI.FAINT))
	srow.add_child(sfl)
	col.add_child(srow)
	if not editable and m.cab.is_reserved(idx):
		col.add_child(UI.wrap_label("Las competencias de esta cartera son del socio por el acuerdo de coalición: solo se modifican negociándolo en la mesa.", UI.FS_SMALL, UI.WARN))

func _toggle(cid: String) -> void:
	var r := m.cab.toggle_comp(idx, cid, false)
	if not bool(r.get("ok", false)) and r.has("conflicts"):
		var c0: Dictionary = (r["conflicts"] as Array)[0]
		shell.confirm("Traspasar competencia", "«%s» la gestiona hoy «%s». ¿Traspasarla a «%s»?%s" % [Competencies.name_of(cid), str(c0["owner_name"]), str(m.cab.entry(idx)["name"]), (" Costará %d de capital político." % int(m.cab.structural_cost())) if m.cab.structural_cost() > 0.0 else ""],
			"Traspasar", Callable(self, "_toggle_take").bind(cid))
		return
	_done(r)

func _toggle_take(cid: String) -> void:
	_done(m.cab.toggle_comp(idx, cid, true))

func _toggle_shared(cid: String) -> void:
	_done(m.cab.toggle_shared(idx, cid))

func _share_selected(i: int, opt: OptionButton) -> void:
	var cid := str(opt.get_item_metadata(i))
	if cid != "":
		_done(m.cab.toggle_shared(idx, cid))

# ---------------------------------------------------------------- pestaña Acciones
func _tab_actions(col: VBoxContainer) -> void:
	var e := m.cab.entry(idx)
	var mn := m.cab.minister(idx)
	col.add_child(UI.wrap_label("Capital político: %.0f. Las acciones sobre ministros de un socio afectan también a la confianza de su partido." % m.exec.capital(), UI.FS_SMALL, UI.MUTED))
	if mn.is_empty():
		col.add_child(UI.wrap_label("No hay titular sobre el que actuar.", UI.FS_BODY, UI.WARN))
		return
	var grid := UI.grid(3, 8, 8)
	col.add_child(grid)
	var acts: Array = [
		["Convocar y pedir explicaciones%s" % _cost_text("convene"), "convene", "primary"],
		["Respaldar en público", "back", "good"],
		["Desautorizar", "disown", "danger"],
		["Reprender", "rebuke", "warn"],
		["Limitar autonomía", "limit", "secondary"],
		["Restaurar autonomía", "restore", "secondary"],
		["Exigir plan correctivo%s" % _cost_text("plan"), "plan", "secondary"],
		["Pedir la dimisión%s" % _cost_text("ask_resign"), "ask_resign", "warn"],
		["Destituir%s" % _cost_text("fire"), "fire", "danger"],
	]
	for a in acts:
		var b := UI.button(str(a[0]), str(a[2]), Callable(self, "_act").bind(str(a[1])))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var row := UI.hbox(8)
	var areas := m.exec.areas_of(idx)
	if not areas.is_empty():
		_pick_area = OptionButton.new()
		for a2 in areas:
			_pick_area.add_item(str(Policies.area(str(a2)).get("name", a2)))
			_pick_area.set_item_metadata(_pick_area.item_count - 1, str(a2))
		row.add_child(UI.label("Instruir prioridad:", UI.FS_SMALL, UI.MUTED, true))
		row.add_child(_pick_area)
		row.add_child(UI.button("Fijar%s" % _cost_text("instruct"), "secondary", Callable(self, "_do_instruct")))
	col.add_child(row)
	var row2 := UI.hbox(8)
	_pick_other = OptionButton.new()
	var others: Array = []
	for i in range(m.cab.size()):
		if i != idx and str(m.cab.entry(i).get("party", "")) == str(e.get("party", "")) and not m.cab.minister(i).is_empty():
			_pick_other.add_item(str(m.cab.entry(i)["name"]))
			_pick_other.set_item_metadata(_pick_other.item_count - 1, i)
			others.append(i)
	if not others.is_empty():
		row2.add_child(UI.label("Remodelación:", UI.FS_SMALL, UI.MUTED, true))
		row2.add_child(_pick_other)
		row2.add_child(UI.button("Intercambiar ministros%s" % _cost_text("swap"), "secondary", Callable(self, "_do_swap")))
	col.add_child(row2)
	if e.has("plan"):
		col.add_child(UI.wrap_label("Plan correctivo en marcha: plazo hasta el trimestre %d." % int((e["plan"] as Dictionary).get("due", 0)), UI.FS_SMALL, UI.WARN))

func _act(which: String) -> void:
	match which:
		"convene": _done(m.cab.convene(idx))
		"back": _done(m.cab.back(idx))
		"disown": _done(m.cab.disown(idx))
		"rebuke": _done(m.cab.rebuke(idx))
		"limit": _done(m.cab.limit_autonomy(idx))
		"restore": _done(m.cab.restore_autonomy(idx))
		"plan": _done(m.cab.demand_plan(idx))
		"ask_resign": _done(m.cab.ask_resignation(idx))
		"fire":
			shell.confirm("Destituir al ministro", "Cesas a %s. La cartera se resiente y puede ganar un crítico dentro del partido. Costará %d de capital político." % [Leader.full_name(m.cab.minister(idx)), int(CabinetSim.ACTION_COST["fire"])], "Destituir", Callable(self, "_do_fire"), "danger")

func _do_fire() -> void:
	_done(m.cab.fire(idx))

func _do_instruct() -> void:
	if _pick_area != null and _pick_area.selected >= 0:
		_done(m.cab.instruct(idx, str(_pick_area.get_item_metadata(_pick_area.selected))))

func _do_swap() -> void:
	if _pick_other != null and _pick_other.selected >= 0:
		_done(m.cab.swap(idx, int(_pick_other.get_item_metadata(_pick_other.selected))))

# ---------------------------------------------------------------- pestaña Estructura
func _tab_struct(col: VBoxContainer) -> void:
	var e := m.cab.entry(idx)
	var reserved := m.cab.is_reserved(idx)
	if reserved:
		col.add_child(UI.wrap_label("Esta cartera es de un socio: su estructura se negocia en la mesa de coalición.", UI.FS_BODY, UI.WARN))
		return
	if m.phase == "legislature":
		col.add_child(UI.wrap_label("Cada cambio estructural cuesta %d de capital político (tienes %.0f). Mientras el Gobierno se forma, los cambios son gratis." % [int(m.cab.structural_cost()), m.exec.capital()], UI.FS_SMALL, UI.WARN))
	var r1 := UI.hbox(8)
	_name_edit = LineEdit.new()
	_name_edit.text = str(e["name"])
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(UI.label("Nombre", UI.FS_SMALL, UI.MUTED, true))
	r1.add_child(_name_edit)
	_desc_edit = LineEdit.new()
	_desc_edit.text = str(e.get("desc", ""))
	_desc_edit.placeholder_text = "Descripción"
	_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(_desc_edit)
	r1.add_child(UI.button("Guardar", "primary", Callable(self, "_do_rename")))
	col.add_child(r1)
	if m.phase == "cabinet_design":
		var r2 := UI.hbox(8)
		r2.add_child(UI.label("Partido responsable", UI.FS_SMALL, UI.MUTED, true))
		_pick_party = OptionButton.new()
		var gp := m.gov.government_parties()
		var sel := 0
		for k in range(gp.size()):
			_pick_party.add_item(m.party_short(str(gp[k])))
			_pick_party.set_item_metadata(k, str(gp[k]))
			if str(gp[k]) == str(e.get("party", "")):
				sel = k
		_pick_party.select(sel)
		r2.add_child(_pick_party)
		r2.add_child(UI.button("Asignar", "secondary", Callable(self, "_do_party")))
		col.add_child(r2)
	col.add_child(UI.hsep())
	# Fusionar
	var r3 := UI.hbox(8)
	_pick_other = OptionButton.new()
	for i in range(m.cab.size()):
		if i != idx and str(m.cab.entry(i).get("party", "")) == str(e.get("party", "")) and not m.cab.is_reserved(i):
			_pick_other.add_item(str(m.cab.entry(i)["name"]))
			_pick_other.set_item_metadata(_pick_other.item_count - 1, i)
	r3.add_child(UI.label("Fusionar con", UI.FS_SMALL, UI.MUTED, true))
	r3.add_child(_pick_other)
	var mb := UI.button("Fusionar", "secondary", Callable(self, "_do_merge"))
	mb.disabled = _pick_other.item_count == 0 or m.cab.size() <= Competencies.MIN_MINISTRIES
	r3.add_child(mb)
	r3.add_child(UI.fill())
	var db := UI.button("Eliminar ministerio", "danger", Callable(self, "_ask_delete"))
	db.disabled = m.cab.size() <= Competencies.MIN_MINISTRIES
	r3.add_child(db)
	col.add_child(r3)
	if m.cab.size() <= Competencies.MIN_MINISTRIES:
		col.add_child(UI.label("El Gobierno necesita al menos %d ministerios." % Competencies.MIN_MINISTRIES, UI.FS_SMALL, UI.FAINT))
	# Dividir
	col.add_child(UI.hsep())
	col.add_child(UI.label("Dividir: elige las competencias que pasan a una cartera nueva", UI.FS_SMALL, UI.MUTED, true))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 4)
	for c in m.cab.comps_of(idx):
		fl.add_child(UI.pill(Competencies.name_of(str(c)), split_sel.has(str(c)), Callable(self, "_split_toggle").bind(str(c)), false))
	col.add_child(fl)
	var r4 := UI.hbox(8)
	_split_name = LineEdit.new()
	_split_name.placeholder_text = "Nombre de la nueva cartera (opcional)"
	_split_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r4.add_child(_split_name)
	var sbtn := UI.button("Dividir", "secondary", Callable(self, "_do_split"))
	sbtn.disabled = m.cab.size() >= Competencies.MAX_MINISTRIES
	r4.add_child(sbtn)
	col.add_child(r4)

func _do_rename() -> void:
	m.cab.rename(idx, _name_edit.text)
	m.cab.set_desc(idx, _desc_edit.text)
	_done({"ok": true, "text": "Cartera actualizada."})

func _do_party() -> void:
	if _pick_party == null:
		return
	_done(m.cab.assign_party(idx, str(_pick_party.get_item_metadata(_pick_party.selected))))

func _ask_delete() -> void:
	shell.confirm("Eliminar ministerio", "Efectos: %s" % m.cab.impact_text(idx), "Eliminar", Callable(self, "_do_delete"), "danger")

func _do_delete() -> void:
	_done(m.cab.delete(idx), true)

func _do_merge() -> void:
	if _pick_other == null or _pick_other.selected < 0:
		return
	var other := int(_pick_other.get_item_metadata(_pick_other.selected))
	var r := m.cab.merge(idx, other, "")
	if bool(r.get("ok", false)):
		idx = int(r.get("index", 0))
	_done(r)

func _split_toggle(cid: String) -> void:
	if split_sel.has(cid):
		split_sel.erase(cid)
	else:
		split_sel.append(cid)
	show()

func _do_split() -> void:
	var r := m.cab.split(idx, split_sel, _split_name.text if _split_name != null else "")
	if bool(r.get("ok", false)):
		split_sel.clear()
	_done(r)
