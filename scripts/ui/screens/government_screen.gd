extends Screen
## Gobierno y Cortes: iniciativas legislativas, oposición, Consejo de Ministros y compromisos.

func build() -> void:
	var role := m.role()
	var cols := columns(1.35, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	_pending_event(left)
	_bills(left)
	if role == "opposition":
		_opposition(left)
	_balance(left)
	_cabinet(right)
	_commitments(right)

func _pending_event(parent: Node) -> void:
	var msg := m.gov.pending_event_message()
	if msg.is_empty():
		return
	var c := UI.card(parent, "Decisión pendiente", "", UI.WARN)
	c.add_child(UI.label(str(msg["title"]), UI.FS_LEAD, UI.TEXT, true))
	c.add_child(UI.wrap_label(str(msg["body"]), UI.FS_BODY, UI.MUTED))
	var col := UI.vbox(6)
	for a in msg.get("actions", []):
		var ad: Dictionary = a
		var aid := str(ad["id"])
		var run_action := func() -> void:
			var fb := m.do_news_action(int(msg["id"]), aid)
			m.save_now()
			shell.toast(fb, "good")
			shell.refresh()
		var kind := str(ad.get("style", "secondary"))
		var b := UI.pill(str(ad["label"]), false, run_action, false, UI.PILL_GO if kind in ["good", "primary"] else (UI.PILL_WARN if kind == "warn" else (Color("#C0392B") if kind == "danger" else UI.PILL)))
		b.custom_minimum_size = Vector2(0, 34)
		col.add_child(b)
	c.add_child(col)

func _bills(parent: Node) -> void:
	var opposition := m.role() == "opposition"
	var c := UI.card(parent, "Agenda legislativa", "Iniciativas por registrar: %d" % m.gov.bills_left(), UI.GOOD if not opposition else UI.ACCENT)
	if opposition:
		c.add_child(UI.wrap_label("Desde la oposición puedes registrar tus propias leyes en el Taller y votar las de los demás en el Pleno. Cada mes se votan todas las iniciativas, una a una.", UI.FS_BODY, UI.MUTED))
	else:
		c.add_child(UI.wrap_label("Diseña leyes a medida en el Taller: cuantas más medidas incluyas, más condiciones plantearán los partidos. Cada mes el Pleno vota todas las iniciativas, una a una.", UI.FS_BODY, UI.MUTED))
	var queued := m.laws.queue()
	if queued.is_empty():
		c.add_child(UI.label("Ninguna ley tuya en cola este trimestre.", UI.FS_SMALL, UI.FAINT))
	for q in queued:
		var law: Dictionary = q
		var row := UI.hbox(8)
		row.add_child(UI.chip("En cola", UI.ACCENT))
		row.add_child(UI.label(str(law["title"]), UI.FS_BODY, UI.TEXT, true))
		c.add_child(row)
	var row2 := UI.hbox(10)
	row2.add_child(UI.button("Abrir el Taller de leyes", "primary", func() -> void: shell.go("laws"), 230))
	var pl := UI.button("Ir al Pleno (%d)" % m.congress.remaining() if m.congress.pending() else "Pleno sin asuntos", "secondary", func() -> void: shell.go("plenary"), 200)
	pl.disabled = not m.congress.pending()
	row2.add_child(pl)
	c.add_child(row2)

func _opposition(parent: Node) -> void:
	var c := UI.card(parent, "Acción parlamentaria", "Iniciativas por registrar: %d" % m.gov.bills_left(), UI.ACCENT)
	c.add_child(UI.wrap_label("Además de legislar, puedes fiscalizar al Gobierno o tejer alianzas con otros grupos.", UI.FS_BODY, UI.MUTED))
	var disabled := m.gov.bills_left() <= 0
	var r1 := UI.hbox(10)
	var b1 := UI.button("Pregunta parlamentaria", "secondary", func() -> void:
		_run_opposition("question"))
	b1.disabled = disabled
	r1.add_child(b1)
	c.add_child(r1)
	var opt := OptionButton.new()
	var targets: Array = []
	for id in m.gov.parliamentary_ids():
		if not m.is_player(str(id)):
			targets.append(str(id))
			opt.add_item("%s (%d)" % [m.party_short(str(id)), m.seats_of(str(id))])
	var r2 := UI.hbox(10)
	r2.add_child(opt)
	var b3 := UI.button("Reunión de coordinación", "secondary", func() -> void:
		if targets.is_empty():
			return
		_run_opposition("pact", str(targets[opt.selected])))
	b3.disabled = disabled
	r2.add_child(b3)
	c.add_child(r2)

func _run_opposition(kind: String, target: String = "") -> void:
	var res := m.gov.opposition_action(kind, target)
	if bool(res.get("ok", false)):
		shell.toast(str(res["text"]), "good")
	else:
		shell.toast(str(res.get("error", "")), "bad")
	shell.refresh()

func _cabinet(parent: Node) -> void:
	var c := UI.card(parent, "Consejo de Ministros", "%s preside" % m.party_short(str(m.s.get("government_party_id", ""))), UI.WARN)
	var grid := UI.grid(2, 14, 4)
	c.add_child(grid)
	for e in m.gov.cabinet():
		var ed: Dictionary = e
		var row := UI.hbox(6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.tooltip_text = m.party_short(str(ed["party"]))
		var bar := ColorRect.new()
		bar.color = m.party_color(str(ed["party"]))
		bar.custom_minimum_size = Vector2(4, 24)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var t := UI.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := UI.label(str(ed["name"]), UI.FS_SMALL, UI.TEXT, true)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.add_child(l)
		var mn: Dictionary = ed.get("minister", {})
		if not mn.is_empty():
			var ml := UI.label("%s · %s" % [Leader.full_name(mn), m.party_short(str(ed["party"]))], UI.FS_TINY, UI.MUTED)
			ml.clip_text = true
			ml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			t.add_child(ml)
		row.add_child(t)
		grid.add_child(row)
	if m.gov.cabinet().is_empty():
		empty_note(c, "El Gobierno no tiene carteras definidas.")

func _commitments(parent: Node) -> void:
	var c := UI.card(parent, "Socios y compromisos", "", UI.GOOD)
	var sat := m.d("partner_satisfaction")
	var pg := UI.grid(2, 18, 6)
	c.add_child(pg)
	for id in m.gov.partners():
		var row := UI.hbox(8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tag := UI.party_tag(m, str(id))
		tag.custom_minimum_size = Vector2(100, 0)
		row.add_child(tag)
		var v := float(sat.get(str(id), 60.0))
		var mb := UI.meter(v, 100.0, UI.GOOD if v >= 50 else UI.BAD, 8)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mb)
		row.add_child(UI.label("%.0f" % v, UI.FS_SMALL, UI.TEXT, true))
		pg.add_child(row)
	if m.gov.partners().is_empty():
		empty_note(c, "Sin socios formales.")
	# Primero los pendientes; como mucho 5 líneas para que la pantalla no necesite desplazarse.
	var coms: Array = []
	for cm in m.a("commitments"):
		if not bool((cm as Dictionary).get("fulfilled", false)):
			coms.append(cm)
	for cm in m.a("commitments"):
		if bool((cm as Dictionary).get("fulfilled", false)):
			coms.append(cm)
	for i in range(mini(5, coms.size())):
		var com: Dictionary = coms[i]
		var row2 := UI.hbox(8)
		row2.add_child(UI.chip("Cumplido" if bool(com.get("fulfilled", false)) else "Pendiente", UI.GOOD if bool(com.get("fulfilled", false)) else UI.WARN))
		var cl := UI.wrap_label("%s: %s" % [m.party_short(str(com["party"])), str(com["text"])], UI.FS_SMALL, UI.TEXT)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(cl)
		c.add_child(row2)
	if coms.size() > 5:
		c.add_child(UI.label("y %d compromisos más" % (coms.size() - 5), UI.FS_SMALL, UI.FAINT))

func _balance(parent: Node) -> void:
	var c := UI.card(parent, "Balance legislativo", "", UI.ACCENT)
	var laws := m.eco.passed_laws()
	if laws.is_empty():
		empty_note(c, "Aún no se ha aprobado ninguna ley en esta legislatura.")
	var shown := 0
	for i in range(laws.size() - 1, -1, -1):
		if shown >= 6:
			break
		var l: Dictionary = laws[i]
		var row := UI.hbox(8)
		row.add_child(UI.chip("Aprobada", UI.GOOD))
		row.add_child(UI.label(str(l.get("title", "")), UI.FS_BODY, UI.TEXT))
		c.add_child(row)
		shown += 1
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(300, 200)
	setup_poll_chart(chart, 4, 12)
	c.add_child(UI.label("INTENCIÓN DE VOTO EN LA LEGISLATURA", UI.FS_TINY, UI.MUTED, true))
	c.add_child(chart)
