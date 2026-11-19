extends Screen
## Agenda semanal de campaña: programar, cancelar y jugar actos.

static var week := -1

func build() -> void:
	if week < 1 or m.day == 1:
		week = m.week_of_campaign()
	var max_week := int(ceil(float(Rules.CAMPAIGN_LENGTH_DAYS) / 7.0))
	week = clampi(week, 1, max_week)
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.button("‹ Semana anterior", "ghost", func() -> void:
		week -= 1
		rebuild()))
	top.add_child(UI.label("Semana %d de %d" % [week, max_week], UI.FS_LEAD, UI.TEXT, true))
	top.add_child(UI.button("Semana siguiente ›", "ghost", func() -> void:
		week += 1
		rebuild()))
	top.add_child(UI.fill())
	top.add_child(UI.label("Presupuesto: %s" % Rules.money(m.funds), UI.FS_BODY, UI.WARN, true))

	var c := UI.card(self, "Calendario", "Máximo %d actos al día · pulsa un hueco para programar" % Rules.MAX_EVENTS_PER_DAY, UI.ACCENT)
	var grid := UI.grid(8, 6, 6)
	c.add_child(grid)
	grid.add_child(UI.spacer(36))
	var first := (week - 1) * 7 + 1
	for i in range(7):
		var d := first + i
		var hl := UI.vbox(0)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if d <= Rules.CAMPAIGN_LENGTH_DAYS:
			var today := d == m.day
			hl.add_child(UI.label(m.date_for_campaign_day(d), UI.FS_SMALL, UI.ACCENT if today else UI.MUTED, true))
			hl.add_child(UI.label("Día %d%s" % [d, " · HOY" if today else (" · ELECCIONES" if d == Rules.CAMPAIGN_LENGTH_DAYS else "")], UI.FS_TINY, UI.WARN if d == Rules.CAMPAIGN_LENGTH_DAYS else UI.FAINT))
		grid.add_child(hl)
	for hour in Rules.AGENDA_HOURS:
		grid.add_child(UI.label("%02d:00" % int(hour), UI.FS_SMALL, UI.FAINT))
		for i in range(7):
			grid.add_child(_cell(first + i, int(hour)))

	var legend := UI.card(self, "Tipos de acto", "", UI.WARN)
	var lg := UI.grid(2, 20, 6)
	legend.add_child(lg)
	for t in Rules.EVENT_TYPES.keys():
		var info: Dictionary = Rules.EVENT_TYPES[t]
		var row := UI.hbox(8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sw := ColorRect.new()
		sw.color = Color(str(info["color"]))
		sw.custom_minimum_size = Vector2(4, 28)
		row.add_child(sw)
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("%s · %s" % [str(t), Rules.money(float(info["cost"]))], UI.FS_BODY, UI.TEXT, true))
		v.add_child(UI.wrap_label(str(info["desc"]), UI.FS_SMALL, UI.MUTED))
		row.add_child(v)
		lg.add_child(row)

func _cell(d: int, hour: int) -> Control:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 54)
	if d > Rules.CAMPAIGN_LENGTH_DAYS:
		wrap.add_theme_stylebox_override("panel", UI.box(Color(UI.BG, 0.5), Color(0, 0, 0, 0), 6, 0, 0, 0))
		return wrap
	var found: Dictionary = {}
	for e in m.campaign.events_on(d):
		if int((e as Dictionary)["hour"]) == hour:
			found = e
	var past := d < m.day
	if found.is_empty():
		var b := Button.new()
		b.text = "+" if not past else ""
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = past
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", UI.box(UI.PANEL, UI.BORDER, 6, 1, 4, 4))
		b.add_theme_stylebox_override("hover", UI.box(UI.PANEL3, UI.ACCENT, 6, 1, 4, 4))
		b.add_theme_stylebox_override("disabled", UI.box(Color(UI.BG, 0.6), Color(0, 0, 0, 0), 6, 0, 4, 4))
		b.add_theme_color_override("font_color", UI.FAINT)
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_schedule_dialog.bind(d, hour))
		return b
	var info: Dictionary = Rules.EVENT_TYPES.get(str(found["type"]), {"color": "#8FA3B8"})
	var col := Color(str(info["color"]))
	var done := str(found.get("status", "")) == "done"
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	btn.text = "%s\n%s" % [str(found["type"]), str(found["region"])]
	btn.add_theme_font_size_override("font_size", UI.FS_SMALL)
	btn.add_theme_stylebox_override("normal", UI.box(Color(col, 0.10 if done else 0.22), col, 6, 1, 6, 4))
	btn.add_theme_stylebox_override("hover", UI.box(Color(col, 0.35), col.lightened(0.2), 6, 1, 6, 4))
	btn.add_theme_color_override("font_color", UI.MUTED if done else UI.TEXT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_event_dialog.bind(found))
	return btn

func _schedule_dialog(d: int, hour: int) -> void:
	var col: VBoxContainer = shell.modal("Programar acto", 560.0, "%s · %02d:00" % [m.date_for_campaign_day(d), hour])
	var type_opt := OptionButton.new()
	var types: Array = Rules.EVENT_TYPES.keys()
	for t in types:
		type_opt.add_item("%s  (%s)" % [str(t), Rules.money(float(Rules.EVENT_TYPES[t]["cost"]))])
	var venue_opt := OptionButton.new()
	var venues: Array = Rules.VENUES.keys()
	for v in venues:
		venue_opt.add_item(str(v))
	var title_edit := LineEdit.new()
	title_edit.placeholder_text = "Título del acto (opcional)"
	var desc := UI.wrap_label(str(Rules.EVENT_TYPES[types[0]]["desc"]), UI.FS_SMALL, UI.MUTED)
	type_opt.item_selected.connect(func(i: int) -> void:
		desc.text = str(Rules.EVENT_TYPES[types[i]]["desc"]))
	col.add_child(UI.label("Tipo de acto", UI.FS_SMALL, UI.MUTED, true))
	col.add_child(type_opt)
	col.add_child(desc)
	col.add_child(UI.label("Ciudad", UI.FS_SMALL, UI.MUTED, true))
	col.add_child(venue_opt)
	col.add_child(title_edit)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Cancelar", "ghost", shell.close_modal))
	row.add_child(UI.button("Programar", "primary", func() -> void:
		var res := m.campaign.schedule(d, hour, str(types[type_opt.selected]), str(venues[venue_opt.selected]), title_edit.text)
		if bool(res.get("ok", false)):
			shell.close_modal()
			m.save_now()
			shell.refresh()
			shell.toast("Acto programado.", "good")
		else:
			shell.toast(str(res.get("error", "No se puede programar.")), "bad")))
	col.add_child(row)

func _event_dialog(ev: Dictionary) -> void:
	var d := int(ev["day"])
	var status := str(ev.get("status", "scheduled"))
	var col: VBoxContainer = shell.modal(str(ev["title"]), 520.0, "%s · %02d:00 · %s" % [m.date_for_campaign_day(d), int(ev["hour"]), str(ev["region"])])
	col.add_child(UI.wrap_label(str((Rules.EVENT_TYPES.get(str(ev["type"]), {}) as Dictionary).get("desc", "")), UI.FS_BODY, UI.MUTED))
	col.add_child(UI.label("Coste: %s" % Rules.money(float(ev.get("cost", 0.0))), UI.FS_BODY, UI.WARN))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Cerrar", "ghost", shell.close_modal))
	if status == "scheduled":
		row.add_child(UI.button("Cancelar acto", "danger", func() -> void:
			var fb := m.campaign.cancel(str(ev["id"]))
			shell.close_modal()
			m.save_now()
			shell.refresh()
			shell.toast(fb, "warn")))
		if d == m.day:
			row.add_child(UI.button("Jugar ahora", "primary", func() -> void:
				shell.close_modal()
				shell.play_event(ev, shell.play_pending)))
	else:
		col.add_child(UI.label("Acto celebrado.", UI.FS_BODY, UI.GOOD))
	col.add_child(row)
