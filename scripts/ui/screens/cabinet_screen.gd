extends Screen
## Consejo de Ministros: tablero de carteras con competencias, titular y estado; constructor (crear, fusionar, dividir,
## eliminar), alertas, reparto entre partidos y acceso a la ficha de cada ministro.

var _new_sel: Array = []
var _new_name: LineEdit
var _new_party: OptionButton

func build() -> void:
	m.ministers.ensure_cabinet()
	var gov_parties := m.gov.government_parties()
	var designing := m.phase == "cabinet_design"
	var gov_id := str(m.s.get("government_party_id", ""))
	var editable := m.cab.can_edit()
	var cabinet := m.gov.cabinet()
	header("Consejo de Ministros", _subtitle(designing, editable, gov_id))
	_alerts_strip()
	var cols := columns(3.4, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var c := UI.card(left, "Carteras", "%d de %d–%d ministerios" % [cabinet.size(), Competencies.MIN_MINISTRIES, Competencies.MAX_MINISTRIES], UI.ACCENT)
	var grid := UI.grid(4, 8, 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(grid)
	for i in range(cabinet.size()):
		grid.add_child(_cell(i, cabinet[i] as Dictionary, designing))
	_share_card(right, gov_parties, cabinet)
	if editable:
		_builder_card(right, cabinet.size())
	_role_card(right)
	_ministers_summary(right)
	if designing and gov_id != m.pid() and gov_parties.has(m.pid()):
		var d := UI.card(right, "Apoyo parlamentario", "", UI.ACCENT)
		d.add_child(UI.wrap_label("Si prefieres no entrar en el Gobierno y apoyarlo desde fuera, puedes renunciar a tus carteras.", UI.FS_SMALL, UI.MUTED))
		d.add_child(UI.button("Renunciar a las carteras", "warn", Callable(self, "_decline")))

func _subtitle(designing: bool, editable: bool, gov_id: String) -> String:
	if designing and editable:
		return "Diseña el Gobierno: cada ministerio gestiona las competencias que le asignes. Entre 8 y 20 carteras; los cambios son gratis hasta constituirlo."
	if designing:
		return "El reparto lo decide el nuevo Gobierno de %s. Puedes revisarlo, pero no modificarlo." % m.party_short(gov_id)
	if editable:
		return "Reorganizar el Gobierno en plena legislatura cuesta capital político y las carteras de los socios están reservadas por el acuerdo."
	return "El Gobierno está constituido. Cada ministro mejora lo que gestiona según su competencia."

func _decline() -> void:
	m.gov.player_declines_cabinet()
	m.save_now()
	shell.refresh()

func _alerts_strip() -> void:
	var al := m.cab.alerts()
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var worst_bad := al.any(func(a) -> bool: return str((a as Dictionary)["level"]) == "bad")
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.BAD if worst_bad else (UI.WARN if not al.is_empty() else UI.GOOD), 8, 1, 12, 6))
	var row := UI.hbox(10)
	pc.add_child(row)
	if al.is_empty():
		row.add_child(UI.label("Sin alertas: todas las competencias esenciales tienen responsable y el reparto es coherente.", UI.FS_SMALL, UI.GOOD, true))
	else:
		row.add_child(UI.label("%d alerta%s" % [al.size(), "" if al.size() == 1 else "s"], UI.FS_SMALL, UI.BAD if worst_bad else UI.WARN, true))
		var v := UI.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for a in al.slice(0, 2):
			v.add_child(UI.label(str((a as Dictionary)["text"]), UI.FS_SMALL, UI.TEXT))
		if al.size() > 2:
			v.add_child(UI.label("… y %d más" % (al.size() - 2), UI.FS_TINY, UI.FAINT))
		row.add_child(v)
	add_child(pc)

func _cell(i: int, entry: Dictionary, designing: bool) -> Control:
	var party_id := str(entry["party"])
	var mn := m.cab.minister(i)
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reserved := m.cab.is_reserved(i)
	cell.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.WARN if reserved else UI.BORDER, 8, 1, 8, 6))
	var cv := UI.vbox(3)
	cell.add_child(cv)
	var row := UI.hbox(6)
	var bar := ColorRect.new()
	bar.color = m.party_color(party_id)
	bar.custom_minimum_size = Vector2(4, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var nm := UI.label(m.agr.ministry_label(i), UI.FS_SMALL, UI.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip(nm)
	nm.tooltip_text = m.agr.ministry_label(i)
	row.add_child(nm)
	row.add_child(UI.chip(m.party_short(party_id), m.party_color(party_id)))
	cv.add_child(row)
	var who := Leader.full_name(mn) if not mn.is_empty() else "Vacante"
	var wl := UI.label(who, UI.FS_TINY, UI.MUTED)
	_clip(wl)
	cv.add_child(wl)
	var comps := UI.label(m.cab.comp_names(i, 2), UI.FS_TINY, UI.FAINT)
	_clip(comps)
	comps.tooltip_text = m.exec.competency_text(i)
	cv.add_child(comps)
	var bottom := UI.hbox(6)
	var st := m.cab.status(i)
	var act := float(st["value"])
	var mt := UI.meter(act, 100.0, UI.tone_color(str(st["tone"])), 6)
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mt.tooltip_text = "%s (%.0f/100)" % [str(st["text"]), act]
	bottom.add_child(mt)
	var tag := m.mact.tag_of(i)
	if tag != "":
		bottom.add_child(UI.label("★", UI.FS_SMALL, UI.BAD if tag == "Rival" else UI.ACCENT, true))
		bottom.tooltip_text = tag
	if designing and party_id == m.pid() and m.exec.in_cabinet() and not m.exec.is_president():
		if int(m.exec.st().get("post", -1)) == i:
			bottom.add_child(UI.chip("Tu cartera", UI.GOOD, true))
		else:
			bottom.add_child(UI.mini_button("Mía", Callable(self, "_take_post").bind(i)))
	bottom.add_child(UI.mini_button("Ficha", Callable(self, "_open_sheet").bind(i)))
	cv.add_child(bottom)
	return cell

func _clip(l: Label) -> void:
	l.clip_text = true
	l.set("text_overflow_behavior", 3)
	l.custom_minimum_size = Vector2(10, 0)

func _take_post(i: int) -> void:
	m.exec.set_post(i)
	m.save_now()
	shell.refresh()

func _open_sheet(i: int) -> void:
	MinistrySheet.open(shell, m, i)

func _share_card(parent: Node, gov_parties: Array, cabinet: Array) -> void:
	var s := UI.card(parent, "Reparto", "", UI.GOOD)
	var counts := {}
	for e in cabinet:
		var pid := str((e as Dictionary)["party"])
		counts[pid] = int(counts.get(pid, 0)) + 1
	for id in gov_parties:
		var row2 := UI.hbox(8)
		var tag := UI.party_tag(m, str(id))
		tag.custom_minimum_size = Vector2(110, 0)
		row2.add_child(tag)
		row2.add_child(UI.meter(float(counts.get(str(id), 0)), 20.0, m.party_color(str(id)), 8))
		row2.add_child(UI.label("%d" % int(counts.get(str(id), 0)), UI.FS_BODY, UI.TEXT, true))
		s.add_child(row2)
		row2.tooltip_text = "%d escaños" % m.seats_of(str(id))
	var check := m.gov.validate_cabinet()
	if not bool(check["ok"]):
		s.add_child(UI.wrap_label(str(check["error"]), UI.FS_SMALL, UI.BAD))
	else:
		s.add_child(UI.label("El reparto es válido.", UI.FS_SMALL, UI.GOOD))

func _builder_card(parent: Node, n: int) -> void:
	var sz := UI.card(parent, "Constructor", "%d / %d" % [n, Competencies.MAX_MINISTRIES], UI.WARN)
	var cost := m.cab.structural_cost()
	sz.add_child(UI.wrap_label("Crea, fusiona, divide o elimina ministerios desde la ficha de cada cartera (pestaña Estructura). %s" % ("Cada cambio cuesta %d de capital político." % int(cost) if cost > 0.0 else "Ahora los cambios son gratuitos."), UI.FS_SMALL, UI.MUTED))
	var b := UI.button("Crear ministerio", "primary", Callable(self, "_open_create"))
	b.disabled = n >= Competencies.MAX_MINISTRIES
	sz.add_child(b)

# ---------------------------------------------------------------- crear ministerio
func _open_create() -> void:
	_new_sel = []
	_render_create()

func _render_create() -> void:
	var col: VBoxContainer = shell.modal("Crear ministerio", 860.0, "Elige las competencias que gestionará. Si ya las lleva otra cartera, podrás traspasarlas.")
	var r1 := UI.hbox(8)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Nombre (si lo dejas vacío se sugiere uno)"
	_new_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(_new_name)
	_new_party = OptionButton.new()
	var gp := m.gov.government_parties()
	if m.phase == "legislature":
		gp = [m.coal.gov_id()]
	for k in range(gp.size()):
		_new_party.add_item(m.party_short(str(gp[k])))
		_new_party.set_item_metadata(k, str(gp[k]))
	r1.add_child(_new_party)
	col.add_child(r1)
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
			var b := UI.pill(Competencies.name_of(cid), _new_sel.has(cid), Callable(self, "_new_toggle").bind(cid), false)
			var o := m.cab.owner_of(cid)
			if o >= 0:
				b.tooltip_text = "Hoy la gestiona «%s»" % str(m.cab.entry(o)["name"])
			fl.add_child(b)
		col.add_child(row)
	var act := UI.hbox(8)
	act.alignment = BoxContainer.ALIGNMENT_END
	act.add_child(UI.button("Cancelar", "ghost", Callable(shell, "close_modal")))
	act.add_child(UI.button("Crear", "primary", Callable(self, "_do_create").bind(false)))
	col.add_child(act)

func _new_toggle(cid: String) -> void:
	var keep := _new_name.text if _new_name != null else ""
	if _new_sel.has(cid):
		_new_sel.erase(cid)
	else:
		_new_sel.append(cid)
	_render_create()
	_new_name.text = keep

func _do_create(take: bool) -> void:
	var pid := str(_new_party.get_item_metadata(_new_party.selected)) if _new_party != null and _new_party.selected >= 0 else ""
	var r := m.cab.create(_new_name.text if _new_name != null else "", _new_sel, pid, take)
	if not bool(r.get("ok", false)) and r.has("conflicts"):
		var txts: Array = []
		for cf in r["conflicts"]:
			txts.append("«%s» (hoy en «%s»)" % [Competencies.name_of(str((cf as Dictionary)["comp"])), str((cf as Dictionary)["owner_name"])])
		shell.confirm("Traspasar competencias", "Se quitarán a su cartera actual: %s." % ", ".join(txts), "Traspasar y crear", Callable(self, "_do_create").bind(true))
		return
	if bool(r.get("ok", false)):
		shell.close_modal()
		m.save_now()
		shell.toast("Ministerio creado.", "positive")
		shell.refresh()
	else:
		shell.toast(str(r.get("error", "No se pudo crear.")), "negative")

func _role_card(parent: Node) -> void:
	if not m.exec.in_cabinet():
		return
	var c := UI.card(parent, "Tu papel en el Gobierno", "", UI.ACCENT)
	if m.exec.is_president():
		c.add_child(UI.wrap_label("Presidente del Gobierno: decretas en todos los ministerios con el visto bueno de cada titular, decides en la mesa de coalición y respondes de las crisis.", UI.FS_SMALL, UI.TEXT))
	else:
		var idx := int(m.exec.st().get("post", -1))
		if idx < 0 or m.exec.party_of(idx) != m.pid():
			idx = m.exec.default_post()
			if idx >= 0:
				m.exec.set_post(idx)
		if idx >= 0:
			c.add_child(UI.label("Ministro/a de %s" % m.exec.ministry_name(idx), UI.FS_LEAD, UI.GOOD, true))
			c.add_child(UI.wrap_label("Tienes un panel propio con las competencias de tu cartera. El resto de ministerios los lleva la IA.", UI.FS_SMALL, UI.MUTED))
		else:
			c.add_child(UI.wrap_label("Tu partido aún no tiene ninguna cartera.", UI.FS_SMALL, UI.WARN))

func _ministers_summary(parent: Node) -> void:
	var b := m.ministers.bonuses()
	var c := UI.card(parent, "Efecto de los ministros", "", UI.GOOD)
	if b.is_empty():
		c.add_child(UI.wrap_label("Se notará en cuanto el Gobierno esté constituido.", UI.FS_SMALL, UI.MUTED))
		return
	var keys: Array = b.keys()
	keys.sort_custom(func(x, y) -> bool: return absf(float(b[x])) > absf(float(b[y])))
	var shown := 0
	for k in keys:
		var v := float(b[k])
		if absf(v) < 0.005:
			continue
		shown += 1
		if shown > 5:
			break
		var good := v < 0.0 if str(k) == "unemployment" else v > 0.0
		var row := UI.hbox(8)
		row.add_child(UI.label(Policies.quality_name(str(k)), UI.FS_SMALL, UI.TEXT))
		row.add_child(UI.fill())
		row.add_child(UI.label(UI.signed(v, 2), UI.FS_SMALL, UI.GOOD if good else UI.BAD, true))
		c.add_child(row)
