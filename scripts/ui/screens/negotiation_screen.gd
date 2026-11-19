extends Screen
## Mesa de negociación: interlocutores, su predisposición, reuniones disponibles y pactos vigentes.

static var sel_id := ""

func build() -> void:
	_hero()
	_open_meeting_banner()
	var ids := _ordered_parties()
	if sel_id == "" or not ids.has(sel_id):
		sel_id = str(ids[0]) if not ids.is_empty() else ""
	var parts := split(430.0)
	var left: VBoxContainer = parts[0]
	var right: VBoxContainer = parts[1]
	left.add_theme_constant_override("separation", 5)
	left.add_child(UI.label("INTERLOCUTORES", UI.FS_SMALL, UI.MUTED, true))
	for id in ids:
		_list_row(left, str(id))
	if sel_id != "":
		right.add_child(_party_card(sel_id))
	_pacts_card(right)

func _list_row(parent: Node, id: String) -> void:
	var disp := m.brain.disposition(id, m.pid())
	var dl := m.brain.disposition_label(disp)
	var inner := UI.select_row(parent, id == sel_id, func() -> void:
		sel_id = id
		rebuild(), UI.tone_color(str(dl["tone"])), 50.0)
	inner.add_child(UI.leader_portrait(m, id, 36))
	var t := UI.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UI.label(m.party_name(id), UI.FS_BODY, UI.TEXT, true)
	nm.clip_text = true
	t.add_child(nm)
	var sub := "%d escaños" % m.seats_of(id) if m.phase != "campaign" else "%.1f%% en las encuestas" % m.poll_of(id)
	t.add_child(UI.label("%s · Relación %d" % [sub, int(m.ai.relation(id))], UI.FS_SMALL, UI.MUTED))
	inner.add_child(t)
	inner.add_child(UI.chip(str(dl["text"]), UI.tone_color(str(dl["tone"])), true))
	UI.pass_clicks(inner)

# ---------------------------------------------------------------- cabecera
func _hero() -> void:
	var hero := UI.hero(self, Color(UI.ACCENT, 0.10), Color(UI.ACCENT, 0.4))
	var row := UI.hbox(14)
	hero.add_child(row)
	var t := UI.vbox(2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label(_headline(), UI.FS_H2, UI.TEXT, true))
	t.add_child(UI.wrap_label(_explain(), UI.FS_BODY, UI.MUTED))
	row.add_child(t)
	var k := UI.vbox(0)
	var left := m.diplomacy.meetings_left()
	k.add_child(UI.label("MESAS QUE PUEDES ABRIR", UI.FS_TINY, UI.FAINT, true))
	k.add_child(UI.label("%d de %d por %s" % [left, Diplomacy.MAX_MEETINGS_PER_PERIOD, m.diplomacy.period_name()], UI.FS_LEAD, UI.GOOD if left > 0 else UI.BAD, true))
	row.add_child(k)

func _headline() -> String:
	match m.phase:
		"campaign": return "Alianzas y pactos antes de las elecciones"
		"investiture": return "Cierra los apoyos para la investidura"
		"cabinet_design", "legislature": return "Mantén tu mayoría y tus socios"
	return "Habla con los partidos"

func _explain() -> String:
	match m.phase:
		"campaign": return "Puedes pactar candidaturas conjuntas, atar apoyos para después de las elecciones o simplemente sondear a los partidos."
		"investiture": return "Siéntate a negociar con cada grupo: cada uno llega con su propuesta, con sus condiciones y con vetos. Las mesas que abres tú consumen un hueco de esta ronda; las que te proponen ellos, no."
		_: return "Pacta votar leyes juntos, asegura la estabilidad con tus socios y prepara futuras candidaturas."

func _open_meeting_banner() -> void:
	var mt := m.diplomacy.current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return
	var c := UI.card(self, "Mesa abierta", "", UI.WARN)
	var row := UI.hbox(10)
	row.add_child(UI.party_emblem(m, str(mt["with"]), 36))
	row.add_child(UI.label("Tienes una mesa abierta con %s." % m.party_name(str(mt["with"])), UI.FS_BODY, UI.TEXT, true))
	row.add_child(UI.fill())
	row.add_child(UI.button("Volver a la mesa", "primary", func() -> void:
		MeetingScreen.return_to = "negotiation"
		shell.go("meeting")))
	c.add_child(row)

# ---------------------------------------------------------------- interlocutores
func _ordered_parties() -> Array:
	var ids: Array = []
	for p in m.rivals:
		var id := str((p as Dictionary).get("id", ""))
		if m.phase == "campaign" or m.seats_of(id) > 0:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		if m.phase == "campaign":
			return m.poll_of(a) > m.poll_of(b)
		return m.seats_of(a) > m.seats_of(b))
	return ids

func _party_card(id: String) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.BORDER, 10, 1, 14, 12))
	var col := UI.vbox(8)
	pc.add_child(col)
	var head := UI.hbox(10)
	head.add_child(UI.leader_portrait(m, id, 52))
	var t := UI.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(m.party_name(id), UI.FS_BODY, UI.TEXT, true)
	nm.clip_text = true
	t.add_child(nm)
	t.add_child(UI.label("Líder: %s" % m.leader_name(id), UI.FS_SMALL, UI.FAINT))
	var sub := "%d escaños" % m.seats_of(id) if m.phase != "campaign" else "%.1f%% en las encuestas" % m.poll_of(id)
	t.add_child(UI.label("%s · Relación %d" % [sub, int(m.ai.relation(id))], UI.FS_SMALL, UI.MUTED))
	head.add_child(t)
	var disp := m.brain.disposition(id, m.pid())
	var dl := m.brain.disposition_label(disp)
	head.add_child(UI.chip(str(dl["text"]), UI.tone_color(str(dl["tone"])), true))
	col.add_child(head)
	col.add_child(UI.meter(disp, 100.0, UI.tone_color(str(dl["tone"])), 6))
	var pd: Dictionary = m.party_by_id(id)
	col.add_child(UI.label(Ideology.bloc_name(pd.get("ideology", {}), pd.get("ideology_profile", {})), UI.FS_SMALL, UI.TEXT, true))
	col.add_child(UI.label(m.brain.archetype(id), UI.FS_SMALL, UI.MUTED))
	col.add_child(UI.wrap_label("Objetivo: " + m.brain.goal(id), UI.FS_SMALL, UI.FAINT))
	var blocked := m.brain.blocked_by(id, m.pid())
	if blocked != "":
		col.add_child(UI.chip("Veto: " + blocked, UI.BAD))
	elif bool(m.d("known_red_lines").get(id, false)):
		var rls := m.brain.red_lines(id)
		if not rls.is_empty():
			col.add_child(UI.label("Línea roja: " + str((rls[0] as Dictionary)["text"]), UI.FS_SMALL, UI.BAD))
	var pacts := m.diplomacy.active_pacts(id)
	if not pacts.is_empty():
		var pf := HFlowContainer.new()
		pf.add_theme_constant_override("h_separation", 6)
		for p in pacts:
			pf.add_child(UI.chip(str(Diplomacy.TOPICS[str((p as Dictionary)["kind"])]["name"]), UI.GOOD))
		col.add_child(pf)
	var chk := m.diplomacy.can_meet(id)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var first := true
	for topic in m.diplomacy.topics_for(id):
		var tp := str(topic)
		var b := UI.button(str(Diplomacy.TOPICS[tp]["name"]), "primary" if first and bool(chk["ok"]) else "ghost", func() -> void:
			shell.open_meeting(id, tp))
		b.custom_minimum_size = Vector2(0, 30)
		var ideo := m.brain.topic_gate(id, tp) if tp in ["joint_list", "partner", "stability"] else ""
		b.disabled = not bool(chk["ok"]) or ideo != ""
		b.tooltip_text = ideo if ideo != "" else (str(Diplomacy.TOPICS[tp]["desc"]) if bool(chk["ok"]) else str(chk["reason"]))
		flow.add_child(b)
		first = false
	col.add_child(flow)
	if not bool(chk["ok"]):
		col.add_child(UI.label(str(chk["reason"]), UI.FS_SMALL, UI.FAINT))
	return pc

# ---------------------------------------------------------------- pactos
func _pacts_card(parent: Node) -> void:
	var pacts: Array = []
	for p in m.diplomacy.pacts():
		pacts.append(p)
	var c := UI.card(parent, "Pactos y compromisos", "", UI.GOOD)
	if pacts.is_empty():
		empty_note(c, "Todavía no has cerrado ningún pacto.")
		return
	pacts.reverse()
	for p in pacts.slice(0, 6):
		var d: Dictionary = p
		var status := str(d.get("status", "active"))
		var row := UI.hbox(10)
		row.add_child(UI.party_tag(m, str(d["party"])))
		row.add_child(UI.chip(str(Diplomacy.TOPICS.get(str(d["kind"]), {"name": "Pacto"})["name"]), UI.ACCENT))
		var l := UI.wrap_label(str(d.get("label", "")), UI.FS_SMALL, UI.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		match status:
			"active":
				row.add_child(UI.chip("Vigente", UI.GOOD, true))
				var pid := int(d["id"])
				row.add_child(UI.button("Romper", "ghost", func() -> void:
					shell.confirm("Romper el pacto", "Romper un pacto daña seriamente la relación y tu confianza.", "Romper el pacto", func() -> void:
						var fb := m.diplomacy.break_pact(pid)
						m.save_now()
						shell.toast(fb, "warn")
						shell.refresh(), "warn")))
			"kept": row.add_child(UI.chip("Cumplido", UI.GOOD))
			"broken": row.add_child(UI.chip("Roto", UI.BAD))
			_: row.add_child(UI.chip("Caducado", UI.MUTED))
		c.add_child(row)
