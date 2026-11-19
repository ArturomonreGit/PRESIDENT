extends Screen
## Fichas de los partidos: lista a la izquierda y ficha completa del seleccionado a la derecha (sin scroll).

static var sel_id := ""

func build() -> void:
	var ids: Array = [m.pid()]
	for r in m.ranked_polls():
		var rid := str((r as Dictionary)["id"])
		if not ids.has(rid):
			ids.append(rid)
	if sel_id == "" or not ids.has(sel_id):
		sel_id = str(ids[1]) if ids.size() > 1 else str(ids[0])
	var parts := split(430.0)
	var left: VBoxContainer = parts[0]
	var right: VBoxContainer = parts[1]
	left.add_theme_constant_override("separation", 5)
	left.add_child(UI.label("PARTIDOS", UI.FS_SMALL, UI.MUTED, true))
	for id in ids:
		_list_row(left, str(id))
	right.add_child(_detail(sel_id))

func _list_row(parent: Node, id: String) -> void:
	var inner := UI.select_row(parent, id == sel_id, func() -> void:
		sel_id = id
		rebuild(), m.party_color(id), 50.0)
	inner.add_child(UI.party_emblem(m, id, 32))
	var t := UI.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UI.label(m.party_name(id), UI.FS_BODY, UI.TEXT, true)
	nm.clip_text = true
	t.add_child(nm)
	var sub := "%.1f%%" % m.poll_of(id)
	if not m.d("election_totals").is_empty():
		sub += " · %d escaños" % m.seats_of(id)
	t.add_child(UI.label(sub, UI.FS_SMALL, UI.MUTED))
	inner.add_child(t)
	if m.is_player(id):
		inner.add_child(UI.chip("Tu partido", UI.ACCENT, true))
	else:
		var rel := m.ai.relation(id)
		var mb := UI.meter(rel, 100.0, UI.GOOD if rel >= 55 else (UI.WARN if rel >= 35 else UI.BAD), 6)
		mb.custom_minimum_size = Vector2(70, 6)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(mb)
	UI.pass_clicks(inner)

func _detail(id: String) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, m.party_color(id), 10, 1, 20, 16, true))
	var col := UI.vbox(10)
	pc.add_child(col)
	var head := UI.hbox(14)
	head.add_child(UI.party_emblem(m, id, 64))
	var t := UI.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_child(UI.label(m.party_name(id), UI.FS_H2, UI.TEXT, true))
	t.add_child(UI.label("%.1f%% en las encuestas%s" % [m.poll_of(id), "" if m.d("election_totals").is_empty() else " · %d escaños" % m.seats_of(id)], UI.FS_BODY, UI.MUTED))
	head.add_child(t)
	if not m.is_player(id):
		head.add_child(UI.leader_portrait(m, id, 64))
	col.add_child(head)
	var pd := m.party_by_id(id)
	col.add_child(UI.label(Ideology.bloc_name(pd.get("ideology", {}), pd.get("ideology_profile", {})), UI.FS_LEAD, UI.TEXT, true))
	var ideo: Dictionary = pd.get("ideology", {})
	for axis in [["economic", "Izquierda", "Derecha"], ["social", "Progresista", "Conservador"], ["territorial", "Centralista", "Descentralizador"]]:
		var v := float(ideo.get(str(axis[0]), 0.0))
		var row := UI.hbox(8)
		var l1 := UI.label(str(axis[1]), UI.FS_SMALL, UI.FAINT)
		l1.custom_minimum_size = Vector2(100, 0)
		row.add_child(l1)
		var mb := UI.meter((v + 1.0) * 50.0, 100.0, m.party_color(id), 8)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mb.marker = 50.0
		row.add_child(mb)
		var l2 := UI.label(str(axis[2]), UI.FS_SMALL, UI.FAINT)
		l2.custom_minimum_size = Vector2(120, 0)
		row.add_child(l2)
		col.add_child(row)
	col.add_child(UI.hsep())
	if m.is_player(id):
		col.add_child(UI.wrap_label(str(pd.get("description", "")), UI.FS_BODY, UI.MUTED))
		return pc
	var prof := m.ai.profile_of(id)
	var rel := m.ai.relation(id)
	var rr := UI.hbox(10)
	rr.add_child(UI.label("Relación con tu partido", UI.FS_BODY, UI.MUTED))
	rr.add_child(UI.meter(rel, 100.0, UI.GOOD if rel >= 55 else (UI.WARN if rel >= 35 else UI.BAD), 8))
	rr.add_child(UI.label("%.0f" % rel, UI.FS_BODY, UI.TEXT, true))
	col.add_child(rr)
	var aff := m.ai.affinity(id, m.pid())
	var chips := UI.hbox(6)
	chips.add_child(UI.chip("Afinidad %.0f%%" % (aff * 100.0), UI.GOOD if aff >= 0.55 else (UI.WARN if aff >= 0.3 else UI.BAD)))
	chips.add_child(UI.chip("Pragmático" if float(prof.get("pragmatism", 0.5)) >= 0.6 else "Intransigente" if float(prof.get("pragmatism", 0.5)) < 0.4 else "Moderado", UI.ACCENT))
	chips.add_child(UI.chip("Negociador" if str(prof.get("strategy", "")) == "negotiator" else "Opositor", UI.MUTED))
	col.add_child(chips)
	var issues: Array = []
	for i in prof.get("issues", []):
		issues.append(Rules.issue_name(str(i)))
	col.add_child(UI.wrap_label("Prioridades: %s" % ", ".join(issues), UI.FS_BODY, UI.MUTED))
	col.add_child(UI.wrap_label(str(pd.get("description", "")), UI.FS_BODY, UI.FAINT))
	col.add_child(UI.button("Abrir la mesa de negociación", "secondary", func() -> void: shell.go("negotiation")))
	return pc
