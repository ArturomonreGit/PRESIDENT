class_name InboxScreen
extends Screen
## Bandeja: lo que requiere tu decisión (con las acciones a mano), el seguimiento de negociaciones y pactos, y las novedades
## (prensa, consejos y avisos) aparte, sin contar como pendientes. Pantalla de juego: sin desplazamiento.

static var sel_news := -1
static var dpage := 0
const DECISIONS_PER_PAGE := 3
const DIGEST_ROWS := 9

func wants_full() -> bool:
	return true

func build() -> void:
	m.expire_news()
	_strip()
	var row := UI.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := UI.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	row.add_child(left)
	var mid := UI.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 1.0
	row.add_child(mid)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.95
	row.add_child(right)
	_decisions(left)
	_tracker(mid)
	_digest(right)

# ---------------------------------------------------------------- franja superior
func _strip() -> void:
	var pend := m.pending_count()
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color(UI.WARN, 0.10) if pend > 0 else UI.PANEL, UI.WARN if pend > 0 else UI.D4_LINE, 4, 1, 14, 8))
	var h := UI.hbox(12)
	bar.add_child(h)
	if pend > 0:
		h.add_child(UI.chip("%d por decidir" % pend, UI.WARN, true))
		h.add_child(UI.label("Lo que no contestes caduca. Lo demás (prensa, consejos) está aparte y no cuenta.", UI.FS_BODY, UI.TEXT))
	else:
		h.add_child(UI.chip("Al día", UI.GOOD, true))
		h.add_child(UI.label("No tienes nada pendiente de decidir.", UI.FS_BODY, UI.MUTED))
	h.add_child(UI.fill())
	var pacts := m.diplomacy.active_pacts()
	h.add_child(UI.chip("%d %s vigente%s" % [pacts.size(), "pacto" if pacts.size() == 1 else "pactos", "" if pacts.size() == 1 else "s"], UI.GOOD if pacts.size() > 0 else UI.MUTED))
	var key := "%s_%d" % [m.phase, m.day if m.phase == "campaign" else m.gov_month]
	var used := str(m.s.get("statement_key", "")) == key
	var stmt := UI.pill("Ya has hablado hoy" if used else "Declaración pública", false, _statement, false, UI.PILL_SUB)
	stmt.disabled = used
	stmt.tooltip_text = "Emite un mensaje del candidato para ganar presencia mediática. Solo una por %s." % ("día" if m.phase == "campaign" else "mes")
	h.add_child(stmt)
	add_child(bar)

func _statement() -> void:
	var key := "%s_%d" % [m.phase, m.day if m.phase == "campaign" else m.gov_month]
	var ctx := "campaign" if m.phase == "campaign" else ("negotiation" if m.phase in ["results", "investiture", "cabinet_design"] else "government")
	var fb := m.ai.player_statement(ctx)
	m.s["statement_key"] = key
	m.save_now()
	shell.toast(fb, "good")
	shell.refresh()

# ---------------------------------------------------------------- decisiones
func _decisions(parent: Node) -> void:
	var list := m.pending_messages()
	var c := UI.card(parent, "Requieren tu decisión", "%d pendiente%s" % [list.size(), "" if list.size() == 1 else "s"], UI.WARN)
	UI.expand_card(c)
	var mt := m.diplomacy.current()
	if m.diplomacy.active():
		c.add_child(_open_table_row(mt))
	if list.is_empty():
		var ok := UI.vbox(4)
		ok.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ok.add_child(UI.spacer(30))
		var t := UI.label("Todo al día", UI.FS_H1, UI.GOOD, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ok.add_child(t)
		var s := UI.wrap_label("Cuando un partido te proponga algo o un medio te invite, lo verás aquí con las acciones a mano.", UI.FS_BODY, UI.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ok.add_child(s)
		c.add_child(ok)
		return
	var pages := maxi(1, int(ceil(float(list.size()) / float(DECISIONS_PER_PAGE))))
	dpage = clampi(dpage, 0, pages - 1)
	for i in range(dpage * DECISIONS_PER_PAGE, mini(list.size(), (dpage + 1) * DECISIONS_PER_PAGE)):
		c.add_child(_decision_card(list[i] as Dictionary))
	if pages > 1:
		var pg := UI.hbox(8)
		var prev := UI.mini_button("‹ Anteriores", func() -> void:
			dpage -= 1
			rebuild())
		prev.disabled = dpage <= 0
		var next := UI.mini_button("Siguientes ›", func() -> void:
			dpage += 1
			rebuild())
		next.disabled = dpage >= pages - 1
		pg.add_child(prev)
		var pl := UI.label("%d / %d" % [dpage + 1, pages], UI.FS_SMALL, UI.MUTED)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pg.add_child(pl)
		pg.add_child(next)
		c.add_child(pg)

func _open_table_row(mt: Dictionary) -> Control:
	var id := str(mt["with"])
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(UI.D4_BLUE, 0.10), UI.D4_BLUE, 4, 1, 10, 6))
	var h := UI.hbox(10)
	pc.add_child(h)
	h.add_child(UI.party_emblem(m, id, 34))
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label("Mesa abierta con %s" % m.party_name(id), UI.FS_BODY, UI.TEXT, true))
	v.add_child(UI.label("%s · ronda %d de %d · %d términos sobre la mesa" % [str(Diplomacy.TOPICS[str(mt["topic"])]["name"]), mini(int(mt["round"]) + 1, Diplomacy.MAX_ROUNDS), Diplomacy.MAX_ROUNDS, (mt["table"] as Array).size()], UI.FS_SMALL, UI.MUTED))
	h.add_child(v)
	var back := func() -> void:
		MeetingScreen.return_to = "inbox"
		shell.go("meeting")
	h.add_child(UI.pill("Volver a la mesa", false, back, false, UI.PILL_GO))
	return pc

func _decision_card(msg: Dictionary) -> Control:
	var tone := UI.tone_color(str(msg.get("tone", "neutral")))
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.D4_LINE, 4, 1, 10, 8))
	var h := UI.hbox(10)
	pc.add_child(h)
	var bar := ColorRect.new()
	bar.color = tone if tone != UI.MUTED else UI.D4_BLUE
	bar.custom_minimum_size = Vector2(5, 0)
	h.add_child(bar)
	var sid := str(msg.get("speaker_id", ""))
	if sid != "":
		h.add_child(UI.leader_portrait(m, sid, 48))
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := UI.hbox(8)
	top.add_child(UI.label(str(msg.get("category", "")), UI.FS_TINY, bar.color.darkened(0.15), true))
	top.add_child(UI.fill())
	if msg.has("expires_day"):
		var clock := m.day if m.phase == "campaign" else m.gov_month
		var left_days := int(msg["expires_day"]) - clock + 1
		var unit := ("día" if left_days == 1 else "días") if m.phase == "campaign" else ("mes" if left_days == 1 else "meses")
		top.add_child(UI.chip("Caduca en %d %s" % [maxi(left_days, 0), unit], UI.BAD if left_days <= 1 else UI.WARN, left_days <= 1))
	v.add_child(top)
	var title := UI.label(str(msg.get("title", "")), UI.FS_LEAD, UI.TEXT, true)
	title.clip_text = true
	v.add_child(title)
	var body := UI.wrap_label(str(msg.get("body", "")), UI.FS_SMALL, UI.MUTED)
	body.max_lines_visible = 3
	body.tooltip_text = str(msg.get("body", ""))
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(body)
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 4)
	v.add_child(acts)
	var mid := int(msg["id"])
	for a in msg.get("actions", []):
		var ad: Dictionary = a
		var aid := str(ad["id"])
		var style := str(ad.get("style", "secondary"))
		var base := UI.PILL
		if style in ["good", "primary"] and aid in ["diplo_accept", "media_accept", "reply_dialogue"]:
			base = UI.PILL_GO
		elif style == "warn":
			base = UI.PILL_WARN
		elif style == "danger":
			base = Color("#C0392B")
		elif style == "ghost":
			base = UI.PILL_SUB
		var run := func() -> void:
			_run(mid, aid)
		var b := UI.pill(str(ad["label"]), false, run, false, base)
		b.custom_minimum_size = Vector2(0, 30)
		acts.add_child(b)
	return pc

func _run(msg_id: int, action_id: String) -> void:
	var fb := m.do_news_action(msg_id, action_id)
	m.save_now()
	if fb != "":
		shell.toast(fb, "good")
	var req: Dictionary = m.s.get("open_meeting_request", {})
	if m.s.has("open_studio"):
		shell.consume_studio_request()
	elif not req.is_empty():
		m.s.erase("open_meeting_request")
		shell.open_meeting(str(req["party"]), str(req["topic"]), {"law": str(req.get("law", "")), "invited": bool(req.get("invited", false)), "agenda": true})
	else:
		shell.refresh()

# ---------------------------------------------------------------- negociaciones y pactos
func _tracker(parent: Node) -> void:
	var c := UI.card(parent, "Negociaciones y pactos", "", UI.D4_BLUE)
	UI.expand_card(c)
	c.add_child(UI.label("MESAS RECIENTES", UI.FS_TINY, UI.MUTED, true))
	var hist := m.a("table_history")
	if hist.is_empty():
		c.add_child(UI.wrap_label("Aún no has cerrado ninguna mesa. Las propuestas de los partidos llegarán a «Requieren tu decisión».", UI.FS_SMALL, UI.FAINT))
	var n := 0
	for hh in hist:
		if n >= 4:
			break
		var d: Dictionary = hh
		var row := UI.hbox(8)
		row.add_child(UI.party_tag(m, str(d["party"]), UI.FS_BODY, true))
		var tname := str(Diplomacy.TOPICS.get(str(d["topic"]), {"name": "Mesa"})["name"])
		var tl := UI.label(tname, UI.FS_SMALL, UI.MUTED)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
		row.add_child(tl)
		var st := str(d["status"])
		row.add_child(UI.chip({"agreed": "Acuerdo", "broken": "Sin acuerdo", "closed": "Cerrada"}.get(st, "Cerrada"), UI.GOOD if st == "agreed" else (UI.BAD if st == "broken" else UI.MUTED), st == "agreed"))
		c.add_child(row)
		n += 1
	c.add_child(UI.hsep())
	c.add_child(UI.label("PACTOS", UI.FS_TINY, UI.MUTED, true))
	var pacts: Array = []
	for p in m.diplomacy.pacts():
		pacts.append(p)
	pacts.reverse()
	if pacts.is_empty():
		c.add_child(UI.wrap_label("Todavía no hay pactos. Cierra uno en una mesa para ver aquí su seguimiento.", UI.FS_SMALL, UI.FAINT))
	var shown := 0
	for p2 in pacts:
		if shown >= 5:
			break
		c.add_child(_pact_row(p2 as Dictionary))
		shown += 1
	if pacts.size() > shown:
		c.add_child(UI.label("y %d más en Negociación" % (pacts.size() - shown), UI.FS_SMALL, UI.FAINT))
	c.add_child(UI.fill())
	c.add_child(UI.pill("Abrir Negociación (interlocutores y mesas)", false, _go_negotiation, false, UI.PILL))

func _go_negotiation() -> void:
	shell.go("negotiation")

func _pact_row(d: Dictionary) -> Control:
	var status := str(d.get("status", "active"))
	var v := UI.vbox(1)
	var top := UI.hbox(8)
	top.add_child(UI.party_tag(m, str(d["party"]), UI.FS_BODY, true))
	var kn := UI.label(str(Diplomacy.TOPICS.get(str(d["kind"]), {"name": "Pacto"})["name"]), UI.FS_SMALL, UI.MUTED)
	kn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kn.clip_text = true
	top.add_child(kn)
	match status:
		"active":
			var extra := ""
			if int(d.get("remaining_bills", 0)) > 0:
				extra = " · %d leyes por votar" % int(d["remaining_bills"])
			top.add_child(UI.chip("Vigente%s" % extra, UI.GOOD, true))
		"kept": top.add_child(UI.chip("Cumplido", UI.GOOD))
		"broken": top.add_child(UI.chip("Roto", UI.BAD))
		_: top.add_child(UI.chip("Caducado", UI.MUTED))
	v.add_child(top)
	var l := UI.label(str(d.get("label", "")), UI.FS_SMALL, UI.FAINT)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = str(d.get("label", ""))
	v.add_child(l)
	return v

# ---------------------------------------------------------------- novedades
func _digest(parent: Node) -> void:
	var items := m.digest_messages(DIGEST_ROWS)
	var c := UI.card(parent, "Novedades", "Prensa, consejos y avisos · no cuentan como pendientes", UI.D4_BLUE_D)
	UI.expand_card(c)
	if items.is_empty():
		c.add_child(UI.wrap_label("Sin novedades por ahora.", UI.FS_SMALL, UI.FAINT))
		return
	if sel_news >= 0 and m.find_news(sel_news).is_empty():
		sel_news = -1
	for it in items:
		var msg: Dictionary = it
		c.add_child(_digest_row(msg))
	var sel := m.find_news(sel_news)
	if not sel.is_empty():
		c.add_child(UI.hsep())
		c.add_child(UI.label(str(sel.get("title", "")), UI.FS_BODY, UI.TEXT, true))
		var body := UI.wrap_label(str(sel.get("body", "")), UI.FS_SMALL, UI.MUTED)
		body.max_lines_visible = 4
		c.add_child(body)
		var sid := str(sel.get("speaker_id", ""))
		if sid != "" and not m.is_player(sid):
			var go_meet := func() -> void:
				shell.open_meeting(sid, "relationship", {})
			c.add_child(UI.pill("Hablar con %s" % m.party_short(sid), false, go_meet, false, UI.PILL_SUB))
		if str(sel.get("resolution", "")) != "":
			c.add_child(UI.label("Resuelto: %s" % str(sel["resolution"]), UI.FS_SMALL, UI.MUTED))
	c.add_child(UI.fill())

func _digest_row(msg: Dictionary) -> Control:
	var id := int(msg["id"])
	var active := id == sel_news
	var tone := UI.tone_color(str(msg.get("tone", "neutral")))
	var toggle := func() -> void:
		sel_news = -1 if active else id
		rebuild()
	var holder := VBoxContainer.new()
	var inner := UI.select_row(holder, active, toggle, tone, 34.0)
	var row := inner.get_parent()
	holder.remove_child(row)
	holder.free()
	var cat := UI.label(str(msg.get("category", "")), UI.FS_TINY, tone, true)
	cat.custom_minimum_size = Vector2(128, 0)
	cat.clip_text = true
	inner.add_child(cat)
	var t := UI.label(str(msg.get("title", "")), UI.FS_SMALL, UI.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(t)
	inner.add_child(UI.label(str(msg.get("date", "")), UI.FS_TINY, UI.FAINT))
	UI.pass_clicks(inner)
	return row
