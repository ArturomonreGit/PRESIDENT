extends Screen
## Partido interno: confianza interna del liderazgo, mandatos y retos de la dirección, corrientes y líneas rojas.

func _tone_color(tone: String) -> Color:
	match tone:
		"good": return UI.GOOD
		"warn": return UI.WARN
	return UI.BAD

func build() -> void:
	var mil := m.militancy
	mil.ensure()
	var it := m.itrust
	it.ensure()
	var sup := mil.support()
	var stt := it.state()
	var scol := _tone_color(str(stt["tone"]))
	var open_n := it.open_count()
	var next_due := ""
	var best := 999
	for md in it.mandates(true):
		var due := int((md as Dictionary)["due_turn"])
		if due < best:
			best = due
			next_due = "T%d" % due
	kpi_row([
		{"title": "Confianza interna", "value": "%.0f / 100" % it.value(), "sub": str(stt["name"]), "color": scol},
		{"title": "Apoyo de la militancia", "value": "%.0f / 100" % sup, "sub": mil.support_label(), "color": UI.GOOD if sup >= 58.0 else (UI.WARN if sup >= 35.0 else UI.BAD)},
		{"title": "Mandatos abiertos", "value": "%d" % open_n, "sub": ("el próximo vence en %s" % next_due) if open_n > 0 else "la dirección no pide nada", "color": UI.WARN if open_n > 0 else UI.TEXT},
		{"title": "Afiliados", "value": Rules.money(float(mil.members())), "sub": "cuotas y trabajo de calle"},
	])
	var cl := columns(1.25, 1.0)
	var left_col: VBoxContainer = cl[0]
	var right: VBoxContainer = cl[1]
	_mandates_card(left_col)
	_trust_card(right, it, scol)
	_reasons_card(right, it)
	_factions_card(right, mil)

# ---------------------------------------------------------------- mandatos
func _mandates_card(parent: Node) -> void:
	var it := m.itrust
	var c := UI.card(parent, "Mandatos y retos de la dirección", "Cumplir, negociar o rechazar: nada es gratis", UI.WARN)
	var open_list := it.mandates(true)
	if open_list.is_empty():
		var sec := str(it.secretary()["name"])
		c.add_child(UI.wrap_label("No hay mandatos ni retos pendientes. %s: «Por ahora la dirección te deja trabajar. Si surge algo, lo verás aquí y en la bandeja.»" % sec, UI.FS_BODY, UI.MUTED))
	for md in open_list:
		_mandate_block(c, md as Dictionary)
	var closed: Array = []
	for md2 in it.mandates(false):
		if not InternalTrust.OPEN_STATUS.has(str((md2 as Dictionary)["status"])):
			closed.append(md2)
	if not closed.is_empty():
		c.add_child(UI.hsep())
		c.add_child(UI.label("Resueltos recientemente", UI.FS_SMALL, UI.FAINT, true))
		for md3 in closed.slice(0, 4):
			var d: Dictionary = md3
			var row := UI.hbox(8)
			var stt := str(d["status"])
			var col := UI.GOOD if stt == "cumplido" else (UI.WARN if stt in ["rechazado", "caducado"] else UI.BAD)
			row.add_child(UI.chip(str(InternalTrust.STATUS_NAMES.get(stt, stt)), col, stt in ["cumplido", "incumplido"]))
			row.add_child(UI.label(str(d["title"]), UI.FS_SMALL, UI.TEXT, true))
			var res := UI.wrap_label(str(d.get("result", "")), UI.FS_SMALL, UI.FAINT)
			res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			res.autowrap_mode = TextServer.AUTOWRAP_OFF
			res.clip_text = true
			row.add_child(res)
			c.add_child(row)

func _mandate_block(parent: Node, md: Dictionary) -> void:
	var it := m.itrust
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.BORDER, 6, 1, 12, 10))
	parent.add_child(box)
	var v := UI.vbox(5)
	box.add_child(v)
	var fdef := m.militancy.faction_def(str(md["faction"]))
	var top := UI.hbox(8)
	top.add_child(UI.chip("Mandato ideológico" if str(md["type"]) == "ideologico" else "Reto político", UI.ACCENT, true))
	var sev := int(md["severity"])
	top.add_child(UI.chip("Importancia " + InternalTrust.severity_name(sev).to_lower(), UI.BAD if sev >= 3 else (UI.WARN if sev == 2 else UI.MUTED), sev >= 3))
	top.add_child(UI.label(str(fdef.get("name", "La dirección")), UI.FS_SMALL, UI.FAINT))
	top.add_child(UI.fill())
	var left := int(md["due_turn"]) - m.turn()
	top.add_child(UI.label("Plazo: %s" % it.due_label(md), UI.FS_SMALL, UI.BAD if left <= 1 else UI.WARN, true))
	v.add_child(top)
	v.add_child(UI.label(str(md["title"]), UI.FS_LEAD, UI.TEXT, true))
	v.add_child(UI.wrap_label(str(md["body"]), UI.FS_SMALL, UI.MUTED))
	v.add_child(UI.wrap_label("Motivo: " + str(md["reason"]), UI.FS_SMALL, UI.FAINT))
	var gs := it.goal_status(md)
	var gl := UI.hbox(8)
	gl.add_child(UI.label("Meta:", UI.FS_SMALL, UI.TEXT, true))
	var gt := UI.wrap_label(str(gs["text"]), UI.FS_SMALL, UI.GOOD if bool(gs["met"]) else UI.TEXT)
	gt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.add_child(gt)
	v.add_child(gl)
	if str(md["status"]) != "nuevo":
		var st_row := UI.hbox(8)
		st_row.add_child(UI.chip(str(InternalTrust.STATUS_NAMES.get(str(md["status"]), "")), UI.GOOD, true))
		st_row.add_child(UI.label("Pendiente de cumplir: la dirección comprobará la meta al vencer el plazo.", UI.FS_SMALL, UI.MUTED))
		v.add_child(st_row)
		return
	var opts := UI.hbox(10)
	v.add_child(opts)
	var kinds := ["good", "primary", "secondary"]
	var names := ["Aceptar", "Negociar", "Rechazar"]
	var pv := it.preview(md)
	for i in range(3):
		var col := UI.vbox(3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := UI.button(names[i], kinds[i], Callable(self, "_answer").bind(str(md["id"]), i))
		b.disabled = bool((pv[i] as Dictionary)["disabled"])
		col.add_child(b)
		for ln in ((pv[i] as Dictionary)["lines"] as Array).slice(0, 5):
			col.add_child(UI.wrap_label("· " + str(ln), UI.FS_TINY, UI.MUTED))
		opts.add_child(col)

func _answer(mandate_id: String, choice: int) -> void:
	var fb := m.itrust.respond(mandate_id, choice)
	m.save_now()
	if fb != "":
		shell.toast(fb, "good" if choice == 0 else ("warn" if choice == 2 else "neutral"))
	shell.refresh()

# ---------------------------------------------------------------- confianza
func _trust_card(parent: Node, it: InternalTrust, scol: Color) -> void:
	var stt := it.state()
	var c := UI.card(parent, "Confianza interna en tu liderazgo", it.secretary_title(), scol)
	var top := UI.hbox(12)
	top.add_child(UI.label("%.0f" % it.value(), 32, scol, true))
	top.add_child(UI.chip(str(stt["name"]), scol, true))
	top.add_child(UI.fill())
	var hv: Array = []
	for h in it.hist():
		hv.append(float((h as Dictionary)["v"]))
	if hv.size() >= 2:
		var sp := Spark.new()
		sp.values = hv
		sp.color = scol
		sp.custom_minimum_size = Vector2(140, 34)
		top.add_child(sp)
	c.add_child(top)
	c.add_child(UI.meter(it.value(), 100.0, scol, 8))
	c.add_child(UI.wrap_label(str(stt["desc"]), UI.FS_SMALL, UI.MUTED))
	c.add_child(UI.label("Separada del voto: encuestas %.1f %% · confianza ciudadana %.0f" % [m.player_poll(), m.trust], UI.FS_TINY, UI.FAINT))
	for comp in it.components():
		var cd: Dictionary = comp
		if str(cd["id"]) == "shock" and absf(float(cd["value"])) < 0.3:
			continue
		var row := UI.hbox(8)
		var vb := UI.vbox(0)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(UI.label(str(cd["name"]), UI.FS_SMALL, UI.TEXT, true))
		var why := UI.label(str(cd["why"]), UI.FS_TINY, UI.FAINT)
		why.clip_text = true
		vb.add_child(why)
		row.add_child(vb)
		var ctb := float(cd["contrib"])
		var l := UI.label("%+.1f" % ctb, UI.FS_BODY, UI.GOOD if ctb > 0.4 else (UI.BAD if ctb < -0.4 else UI.MUTED), true)
		l.custom_minimum_size = Vector2(46, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
		c.add_child(row)

func _reasons_card(parent: Node, it: InternalTrust) -> void:
	var c := UI.card(parent, "Por qué ha cambiado", "Motivos recientes", UI.FAINT)
	var entries := it.log_entries(4)
	if entries.is_empty():
		empty_note(c, "Todavía no ha cambiado nada.")
	for e in entries:
		var ed: Dictionary = e
		var row := UI.hbox(8)
		var dl := float(ed.get("delta", 0.0))
		var l := UI.label("%+.1f" % dl if absf(dl) >= 0.05 else "·", UI.FS_SMALL, UI.GOOD if dl > 0.05 else (UI.BAD if dl < -0.05 else UI.FAINT), true)
		l.custom_minimum_size = Vector2(38, 0)
		row.add_child(l)
		var t := UI.wrap_label("T%d · %s" % [int(ed.get("turn", 0)), str(ed.get("text", ""))], UI.FS_SMALL, UI.MUTED)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		c.add_child(row)
	var al := it.alerts()
	if not al.is_empty():
		var a0: Dictionary = al[0]
		c.add_child(UI.hsep())
		c.add_child(UI.wrap_label("Secretaría · %s %s" % [str(a0["title"]), str(a0["sug"])], UI.FS_SMALL, UI.WARN))

# ---------------------------------------------------------------- corrientes y líneas rojas
func _factions_card(parent: Node, mil: Militancy) -> void:
	var c := UI.card(parent, "Corrientes y líneas rojas", "Cada una te juzga por lo que le importa", UI.ACCENT)
	for f in mil.factions():
		var fd: Dictionary = f
		var id := str(fd["id"])
		var s_f := mil.sat(id)
		var out := bool(mil.fac_state(id).get("out", false))
		var row := UI.hbox(8)
		var nm := UI.label(str(fd["name"]), UI.FS_SMALL, UI.TEXT, true)
		nm.custom_minimum_size = Vector2(170, 0)
		row.add_child(nm)
		row.add_child(UI.meter(s_f, 100.0, UI.GOOD if s_f >= 58.0 else (UI.WARN if s_f >= 35.0 else UI.BAD), 7))
		if out:
			row.add_child(UI.chip("Retira apoyo", UI.BAD, true))
		else:
			var l := UI.label("%.0f" % s_f, UI.FS_SMALL, UI.GOOD if s_f >= 58.0 else (UI.WARN if s_f >= 35.0 else UI.BAD), true)
			l.custom_minimum_size = Vector2(28, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
		c.add_child(row)
	for r in mil.rules():
		var rd: Dictionary = r
		var state := str(rd["state"])
		var rrow := UI.hbox(8)
		rrow.add_child(UI.chip("Respetada" if state == "ok" else ("Cruzada" if state == "broken" else "Ignorada"), UI.GOOD if state == "ok" else (UI.BAD if state == "broken" else UI.WARN), state != "ok"))
		var rt := UI.label(str(rd["text"]), UI.FS_SMALL, UI.TEXT)
		rt.clip_text = true
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(rt)
		c.add_child(rrow)
