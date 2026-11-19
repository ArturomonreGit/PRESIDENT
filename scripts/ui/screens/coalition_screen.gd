class_name CoalitionScreen
extends Screen
## Mesa de coalición: socios y su confianza, propuestas pendientes (de ministros y de socios), compromisos, crisis con
## sus salidas, apoyos alternativos y elecciones anticipadas. Una sola fuente de verdad: m.coal.

static var tab := "socios"
var _want: OptionButton
var _give: OptionButton
var _offer_party := ""

func build() -> void:
	m.coal.ensure()
	m.exec.ensure()
	header("Mesa de coalición", _subtitle())
	_kpis()
	var tabs := UI.hbox(6)
	var open_n := m.coal.open_for_player().size()
	var crisis_n := m.coal.in_crisis().size()
	for t in [["socios", "Socios"], ["propuestas", "Propuestas (%d)" % open_n], ["compromisos", "Compromisos"], ["crisis", "Crisis (%d)" % crisis_n], ["historial", "Historial"]]:
		tabs.add_child(UI.pill(str(t[1]), tab == str(t[0]), Callable(self, "_set_tab").bind(str(t[0])), false))
	add_child(tabs)
	match tab:
		"propuestas":
			_tab_proposals()
		"compromisos":
			_tab_commitments()
		"crisis":
			_tab_crisis()
		"historial":
			_tab_history()
		_:
			_tab_partners()

func _subtitle() -> String:
	var gid := m.coal.gov_id()
	if gid == m.pid():
		return "Gobiernas con %d socio%s. Aquí decides las propuestas, cumples compromisos y evitas que una crisis acabe en ruptura." % [m.coal.party_ids().size(), "" if m.coal.party_ids().size() == 1 else "s"]
	if m.coal.party_ids().has(m.pid()):
		return "Eres socio del Gobierno de %s. Presenta peticiones, vigila los compromisos y decide si seguir." % m.party_short(gid)
	return "Gobierna %s. Sigue la situación de su mayoría desde fuera." % m.party_short(gid)

func _set_tab(t: String) -> void:
	tab = t
	rebuild()

func _kpis() -> void:
	var seats := m.coal.government_seats()
	var trust_avg := 0.0
	var ids := m.coal.party_ids()
	for id in ids:
		trust_avg += m.coal.trust(str(id))
	if not ids.is_empty():
		trust_avg /= float(ids.size())
	kpi_row([
		{"title": "Mayoría", "value": "%d / %d" % [seats, Rules.MAJORITY], "sub": "escaños del Gobierno y sus socios", "color": UI.GOOD if seats >= Rules.MAJORITY else UI.BAD},
		{"title": "Estabilidad", "value": "%.0f / 100" % m.gov.stability(), "sub": "cae con las crisis de coalición", "color": UI.GOOD if m.gov.stability() >= 40.0 else (UI.WARN if m.gov.stability() >= 20.0 else UI.BAD)},
		{"title": "Confianza media de los socios", "value": "%.0f / 100" % trust_avg if not ids.is_empty() else "—", "sub": "%d socio%s" % [ids.size(), "" if ids.size() == 1 else "s"], "color": UI.TEXT},
		{"title": "Capital político", "value": "%.0f / %.0f" % [m.exec.capital(), Executive.MAX_CAPITAL], "sub": "reuniones y mediaciones lo gastan", "color": UI.ACCENT, "tip": m.exec.capital_text()},
	])

func _act(res: Dictionary) -> void:
	if bool(res.get("ok", false)):
		var t := str(res.get("text", ""))
		if t != "":
			shell.toast(t, "positive")
	else:
		shell.toast(str(res.get("error", "No se pudo hacer.")), "negative")
	m.save_now()
	shell.refresh()

# ---------------------------------------------------------------- socios
func _tab_partners() -> void:
	var cols := columns(2.6, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var ids := m.coal.party_ids()
	var president := m.coal.gov_id() == m.pid()
	if ids.is_empty():
		var c0 := UI.card(left, "Sin socios", "", UI.WARN)
		c0.add_child(UI.wrap_label("El Gobierno no tiene socios: gobierna en solitario con %d escaños. Puedes buscar apoyos en la pestaña Crisis." % m.coal.government_seats(), UI.FS_BODY, UI.MUTED))
	var pgrid := UI.grid(2, 10, 10)
	pgrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(pgrid)
	for id in ids:
		_partner_card(pgrid, str(id), president)
	# Acuerdo
	var a := UI.card(right, "Acuerdo de coalición", "", UI.ACCENT)
	var alloc := m.coal.allocation()
	for pid in alloc.keys():
		var names: Array = alloc[pid]
		a.add_child(UI.wrap_label("%s: %s" % [m.party_short(str(pid)), ", ".join(names)], UI.FS_TINY, UI.MUTED))
	a.add_child(UI.hsep())
	var rules := m.coal.rules()
	for k in rules.keys():
		a.add_child(UI.wrap_label(str(rules[k]), UI.FS_TINY, UI.FAINT))
	var rv := int(m.coal.st().get("review_turn", 0))
	if rv > 0:
		a.add_child(UI.label("Próxima revisión: trimestre %d" % rv, UI.FS_TINY, UI.MUTED))
	if not president and ids.has(m.pid()):
		_partner_asks(right)
		right.add_child(UI.button("Abandonar el Gobierno", "danger", Callable(self, "_ask_leave")))

func _partner_card(parent: Node, id: String, president: bool) -> void:
	var ph := m.coal.phase(id)
	var tone := UI.tone_color(str(Coalition.PHASE_TONE[ph]))
	var c := UI.card(parent, m.party_name(id), "%s · %d escaño%s" % [m.coal.modality_name(id), m.seats_of(id), "" if m.seats_of(id) == 1 else "s"], m.party_color(id))
	var row := UI.hbox(10)
	row.add_child(UI.label("Confianza", UI.FS_SMALL, UI.MUTED, true))
	var t := m.coal.trust(id)
	var mt := UI.meter(t, 100.0, UI.GOOD if t >= 60.0 else (UI.WARN if t >= 40.0 else UI.BAD), 9)
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mt)
	row.add_child(UI.label("%.0f" % t, UI.FS_BODY, UI.TEXT, true))
	row.add_child(UI.chip(m.coal.phase_name(id), tone, ph >= 2))
	c.add_child(row)
	var info := UI.hbox(8)
	var rl := m.coal.red_lines(id)
	info.add_child(UI.label("Líneas rojas:", UI.FS_TINY, UI.MUTED, true))
	if rl.is_empty():
		info.add_child(UI.label("ninguna declarada", UI.FS_TINY, UI.FAINT))
	for r in rl.slice(0, 2):
		info.add_child(UI.chip(str(r), UI.BAD))
	c.add_child(info)
	var f := m.coal.factors(id)
	if not f.is_empty():
		var fl: Array = []
		for x in f.slice(0, 2):
			fl.append("%s %s" % [UI.signed(float((x as Dictionary)["delta"]), 0), str((x as Dictionary)["text"])])
		c.add_child(UI.wrap_label("Últimos motivos: %s" % " · ".join(fl), UI.FS_TINY, UI.MUTED))
	var note := m.coal.ai_note(id)
	if note != "" and ph < 1:
		c.add_child(UI.wrap_label("Última respuesta: %s" % note, UI.FS_TINY, UI.FAINT))
	if president:
		var b := UI.hbox(6)
		b.add_child(UI.button("Reunirse (1 cap.)", "primary", Callable(self, "_do_crisis").bind(id, "meet")))
		b.add_child(UI.button("Proponer intercambio", "secondary", Callable(self, "_open_offer").bind(id)))
		b.add_child(UI.button("Negociar a fondo", "ghost", Callable(shell, "go").bind("negotiation")))
		c.add_child(b)

func _do_crisis(id: String, action: String) -> void:
	_act(m.coal.crisis_action(id, action))

func _ask_leave() -> void:
	shell.confirm("Abandonar el Gobierno", "Tu partido deja el acuerdo: perdéis las carteras, sube la tensión y el Gobierno puede quedar sin mayoría. ¿Continuar?", "Abandonar", Callable(self, "_do_leave"), "danger")

func _do_leave() -> void:
	_act(m.coal.player_leave())

func _partner_asks(parent: Node) -> void:
	var c := UI.card(parent, "Tus peticiones al Gobierno", "una por trimestre", UI.GOOD)
	var cat := m.coal.ask_catalog(m.pid())
	if cat.is_empty():
		c.add_child(UI.label("No tienes peticiones viables ahora.", UI.FS_SMALL, UI.FAINT))
	for i in range(mini(cat.size(), 4)):
		var ask: Dictionary = cat[i]
		var row := UI.hbox(8)
		var l := UI.wrap_label(str(ask["title"]), UI.FS_SMALL, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.mini_button("Pedir", Callable(self, "_partner_ask").bind(i)))
		c.add_child(row)

func _partner_ask(i: int) -> void:
	var r := m.coal.partner_ask(i)
	m.save_now()
	if bool(r.get("ok", false)):
		shell.info("Respuesta del presidente", "%s\n\nMotivos: %s." % [str(r.get("text", "")), str(r.get("why", ""))])
	else:
		shell.toast(str(r.get("error", "")), "negative")
	shell.refresh()

# ---------------------------------------------------------------- intercambio propuesto al socio
func _open_offer(id: String) -> void:
	_offer_party = id
	var col: VBoxContainer = shell.modal("Propuesta a %s" % m.party_short(id), 620.0, "Pide algo al socio y, si quieres, ofrece a cambio una de sus peticiones. Su respuesta se explica.")
	col.add_child(UI.label("Qué le pides", UI.FS_SMALL, UI.MUTED, true))
	_want = OptionButton.new()
	for k in Coalition.WANT_NAMES.keys():
		_want.add_item(str(Coalition.WANT_NAMES[k]))
		_want.set_item_metadata(_want.item_count - 1, str(k))
	col.add_child(_want)
	col.add_child(UI.label("Qué le ofreces", UI.FS_SMALL, UI.MUTED, true))
	_give = OptionButton.new()
	_give.add_item("Nada a cambio")
	_give.set_item_metadata(0, -1)
	var cat := m.coal.ask_catalog(id)
	for i in range(cat.size()):
		_give.add_item(str((cat[i] as Dictionary)["title"]))
		_give.set_item_metadata(_give.item_count - 1, i)
	col.add_child(_give)
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("Cancelar", "ghost", Callable(shell, "close_modal")))
	row.add_child(UI.button("Proponer", "primary", Callable(self, "_send_offer")))
	col.add_child(row)

func _send_offer() -> void:
	var want := str(_want.get_item_metadata(_want.selected))
	var give := int(_give.get_item_metadata(_give.selected))
	var r := m.coal.player_offer(_offer_party, want, give)
	shell.close_modal()
	m.save_now()
	if bool(r.get("ok", false)):
		shell.info("Respuesta de %s" % m.party_short(_offer_party), "%s\n\nMotivos: %s." % [str(r.get("text", "")), str(r.get("why", ""))])
	else:
		shell.toast(str(r.get("error", "")), "negative")
	shell.refresh()

# ---------------------------------------------------------------- propuestas
func _tab_proposals() -> void:
	var cols := columns(1.6, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var mine := m.coal.open_for_player()
	var c := UI.card(left, "Para decidir", "%d pendiente%s" % [mine.size(), "" if mine.size() == 1 else "s"], UI.WARN if not mine.is_empty() else UI.GOOD)
	if mine.is_empty():
		c.add_child(UI.wrap_label("No hay propuestas pendientes. Los ministros y los socios las presentan cada trimestre; también puedes proponer un intercambio a un socio.", UI.FS_BODY, UI.MUTED))
	var shown := 0
	for p in mine:
		shown += 1
		if shown > 4:
			c.add_child(UI.label("… y %d más en la Bandeja" % (mine.size() - 4), UI.FS_TINY, UI.FAINT))
			break
		_proposal_card(c, p as Dictionary)
	var h := UI.card(right, "Resueltas recientemente", "", UI.ACCENT)
	var hist := m.coal.history(8)
	if hist.is_empty():
		h.add_child(UI.label("Todavía no hay historial.", UI.FS_SMALL, UI.FAINT))
	for p2 in hist:
		var pd: Dictionary = p2
		var row := UI.hbox(6)
		row.add_child(UI.chip(_state_name(str(pd.get("state", ""))), UI.GOOD if str(pd.get("state", "")) == "accepted" else (UI.WARN if str(pd.get("state", "")) in ["postponed", "expired"] else UI.BAD)))
		var l := UI.wrap_label(str(pd.get("title", "")), UI.FS_SMALL, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		h.add_child(row)
		if str(pd.get("result", "")) != "":
			h.add_child(UI.wrap_label(str(pd["result"]), UI.FS_TINY, UI.FAINT))

func _state_name(s: String) -> String:
	return {"accepted": "Aceptada", "rejected": "Rechazada", "postponed": "Aplazada", "expired": "Caducada", "open": "Abierta", "countered": "Contraoferta"}.get(s, s)

func _proposal_card(parent: Node, p: Dictionary) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.BORDER, 8, 1, 12, 8))
	var v := UI.vbox(4)
	box.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.chip(str(Coalition.SCOPES.get(str(p.get("scope", "leyes")), "Mesa")), UI.ACCENT))
	var author := str(p.get("author", ""))
	if author != "" and author != m.pid():
		head.add_child(UI.chip(m.party_short(author), m.party_color(author)))
	var tl := UI.label(str(p.get("title", "")), UI.FS_BODY, UI.TEXT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(UI.label("Responder antes del trimestre %d" % int(p.get("due_turn", 0)), UI.FS_TINY, UI.FAINT))
	v.add_child(head)
	v.add_child(UI.wrap_label(str(p.get("body", "")), UI.FS_SMALL, UI.MUTED))
	var bits: Array = []
	var cost: Dictionary = p.get("cost", {})
	if float(cost.get("capital", 0.0)) > 0.0:
		bits.append("Capital político: %d" % int(cost["capital"]))
	if float(cost.get("funds", 0.0)) > 0.0:
		bits.append("Coste: %.1f mM€/año" % float(cost["funds"]))
	if str(p.get("risk", "")) != "":
		bits.append("Riesgo: %s" % str(p["risk"]))
	if not bits.is_empty():
		v.add_child(UI.label(" · ".join(bits), UI.FS_TINY, UI.WARN))
	var row := UI.hbox(6)
	for o in m.coal.options_for(p):
		var od: Dictionary = o
		row.add_child(UI.button(str(od["label"]), str(od["style"]), Callable(self, "_respond").bind(int(p["id"]), str(od["id"]))))
	v.add_child(row)
	parent.add_child(box)

func _respond(pid: int, opt: String) -> void:
	_act(m.coal.respond(pid, opt))

# ---------------------------------------------------------------- compromisos
func _tab_commitments() -> void:
	m.agr.ensure()
	var list := m.a("commitments")
	var cnt := m.agr.counts()
	var active := int(cnt["pending"]) + int(cnt["in_progress"])
	var c := UI.card(self, "Compromisos del acuerdo", "%d vigentes · %d cumplidos · %d incumplidos" % [active, int(cnt["fulfilled"]), int(cnt["breached"])], UI.ACCENT)
	if list.is_empty():
		c.add_child(UI.wrap_label("No hay compromisos: nadie te ha exigido nada concreto todavía.", UI.FS_BODY, UI.MUTED))
		return
	var box := UI.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(box)
	var president := m.coal.gov_id() == m.pid()
	# Primero los vigentes y los incumplidos; después lo ya cerrado.
	var order: Array = []
	for pass_n in range(2):
		for i in range(list.size() - 1, -1, -1):
			var com: Dictionary = list[i]
			var closed := m.agr.state_of(com) in Agreements.TERMINAL
			if (pass_n == 0) != closed:
				order.append(com)
	for com2 in order:
		var cd: Dictionary = com2
		var row := NegUI.commitment_row(m, cd, president, Callable(self, "_act"))
		box.add_child(row)
		if president and m.agr.is_active(cd) and not bool(cd.get("extended", false)) and m.agr.state_of(cd) != "breached":
			var ext := UI.mini_button("Prorrogar (1 cap.)", Callable(self, "_extend").bind(list.find(cd)))
			ext.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			(row.get_child(0).get_child(1) as VBoxContainer).add_child(ext)
	c.add_child(UI.wrap_label("Pasa el ratón por el texto para ver la consecuencia de incumplir. Lo medible se comprueba solo cada mes; lo demás lo cumples a mano con capital político. Incumplir resta confianza según la gravedad y, si se acumula, escala la crisis.", UI.FS_TINY, UI.FAINT))

func _pending_n(list: Array) -> int:
	var n := 0
	for c in list:
		if not bool((c as Dictionary).get("fulfilled", false)):
			n += 1
	return n

func _extend(i: int) -> void:
	_act(m.coal.extend_commitment(i))

# ---------------------------------------------------------------- crisis y apoyos
func _tab_crisis() -> void:
	var cols := columns(1.5, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var president := m.coal.gov_id() == m.pid()
	var any := false
	for id in m.coal.party_ids():
		var pid := str(id)
		var ph := m.coal.phase(pid)
		if ph == 0 and m.coal.trust(pid) >= 50.0:
			continue
		any = true
		_crisis_card(left, pid, president)
	if not any:
		var c0 := UI.card(left, "Sin crisis abiertas", "", UI.GOOD)
		c0.add_child(UI.wrap_label("Ningún socio está en conflicto. Mantén la confianza cumpliendo compromisos y respondiendo a tiempo a sus propuestas.", UI.FS_BODY, UI.MUTED))
	var ladder := UI.card(left, "Escalera de crisis", "", UI.ACCENT)
	var lrow := HFlowContainer.new()
	lrow.add_theme_constant_override("h_separation", 6)
	for i in range(Coalition.PHASES.size()):
		lrow.add_child(UI.chip("%d · %s" % [i, str(Coalition.PHASES[i])], UI.tone_color(str(Coalition.PHASE_TONE[i]))))
	ladder.add_child(lrow)
	ladder.add_child(UI.wrap_label("Un desacuerdo aislado nunca rompe una coalición: la crisis sube un escalón por trimestre como máximo y solo un ultimátum vencido o rechazado provoca la ruptura. La ruptura no convoca elecciones.", UI.FS_TINY, UI.FAINT))
	_support_card(right, president)

func _crisis_card(parent: Node, id: String, president: bool) -> void:
	var ph := m.coal.phase(id)
	var c := UI.card(parent, "%s · %s" % [m.party_short(id), m.coal.phase_name(id)], str(Coalition.PHASE_HELP[ph]), UI.tone_color(str(Coalition.PHASE_TONE[ph])))
	var causes: Array = m.coal.explain(id)
	for cs in causes.slice(0, 3):
		c.add_child(UI.wrap_label("• %s" % str(cs), UI.FS_SMALL, UI.TEXT))
	if causes.is_empty():
		c.add_child(UI.wrap_label("Sin motivos graves: se vigila la confianza (%.0f/100)." % m.coal.trust(id), UI.FS_SMALL, UI.MUTED))
	if ph == 5:
		var d: Dictionary = m.coal.crisis(id).get("demand", {})
		c.add_child(UI.label("Ultimátum: %s" % str(d.get("title", "")), UI.FS_BODY, UI.BAD, true))
		c.add_child(UI.label("Plazo: trimestre %d (ahora el %d)" % [int(m.coal.crisis(id).get("deadline", 0)), m.turn()], UI.FS_SMALL, UI.WARN))
	if not president:
		return
	var row := UI.hbox(6)
	if ph == 5:
		row.add_child(UI.button("Aceptar su condición", "primary", Callable(self, "_do_crisis").bind(id, "accept")))
		row.add_child(UI.button("Aplazar", "ghost", Callable(self, "_do_crisis").bind(id, "postpone")))
		row.add_child(UI.button("Rechazar", "danger", Callable(self, "_ask_refuse").bind(id)))
	else:
		row.add_child(UI.button("Reunirse (1 cap.)", "primary", Callable(self, "_do_crisis").bind(id, "meet")))
		if ph >= 3:
			row.add_child(UI.button("Mediación (3 cap.)", "secondary", Callable(self, "_do_crisis").bind(id, "mediate")))
		row.add_child(UI.button("Conceder", "warn", Callable(self, "_do_crisis").bind(id, "concede")))
	c.add_child(row)

func _ask_refuse(id: String) -> void:
	shell.confirm("Rechazar el ultimátum", "%s abandonará el Gobierno. Perderás su apoyo y bajará la estabilidad, pero no se convocan elecciones. ¿Rechazar?" % m.party_short(id), "Rechazar y asumir la ruptura", Callable(self, "_do_crisis").bind(id, "refuse"), "danger")

func _support_card(parent: Node, president: bool) -> void:
	var c := UI.card(parent, "Mayoría y apoyos", "", UI.ACCENT)
	var seats := m.coal.government_seats()
	c.add_child(UI.label("%d de %d escaños" % [seats, Rules.MAJORITY], UI.FS_LEAD, UI.GOOD if seats >= Rules.MAJORITY else UI.BAD, true))
	if not president:
		c.add_child(UI.wrap_label("Solo el presidente negocia nuevos apoyos.", UI.FS_SMALL, UI.MUTED))
		return
	var cands := m.coal.candidates_for_support()
	var shown := 0
	for id in cands:
		var pid := str(id)
		if m.seats_of(pid) < 5:
			continue
		shown += 1
		if shown > 4:
			break
		var row := UI.hbox(6)
		var tag := UI.party_tag(m, pid, UI.FS_SMALL)
		tag.custom_minimum_size = Vector2(100, 0)
		row.add_child(tag)
		row.add_child(UI.label("%d" % m.seats_of(pid), UI.FS_SMALL, UI.MUTED, true))
		row.add_child(UI.fill())
		row.add_child(UI.mini_button("Coalición", Callable(self, "_invite").bind(pid, "coalicion")))
		row.add_child(UI.mini_button("Externo", Callable(self, "_invite").bind(pid, "externo")))
		row.add_child(UI.mini_button("Puntual", Callable(self, "_invite").bind(pid, "puntual")))
		c.add_child(row)
		if m.coal.recently_broken(pid):
			c.add_child(UI.label("Rompió con el Gobierno hace poco", UI.FS_TINY, UI.WARN))
	c.add_child(UI.hsep())
	c.add_child(UI.button("Convocar elecciones anticipadas", "danger", Callable(self, "_ask_elections")))
	c.add_child(UI.wrap_label("Sin mayoría el Gobierno sigue en minoría: nada se convoca solo. Tú decides entre buscar apoyos, renegociar o ir a las urnas.", UI.FS_TINY, UI.FAINT))

func _invite(id: String, mod: String) -> void:
	var r := m.coal.invite(id, mod)
	m.save_now()
	if not bool(r.get("ok", false)):
		shell.toast(str(r.get("error", "")), "negative")
		return
	var verdict := str(r.get("verdict", ""))
	if verdict == "counter":
		shell.confirm("%s pide una contrapartida" % m.party_short(id), "%s\nMotivos: %s." % [str(r["text"]), str(r.get("why", ""))], "Aceptar su condición", Callable(self, "_invite_accept").bind(id, mod))
	else:
		shell.info("Respuesta de %s" % m.party_short(id), "%s\n\nMotivos: %s." % [str(r.get("text", "")), str(r.get("why", ""))])
	shell.refresh()

func _invite_accept(id: String, mod: String) -> void:
	var r := m.coal.invite(id, mod, true)
	m.save_now()
	if bool(r.get("ok", false)):
		shell.toast(str(r.get("text", "")), "positive")
	else:
		shell.toast(str(r.get("error", "")), "negative")
	shell.refresh()

func _ask_elections() -> void:
	shell.confirm("Elecciones anticipadas", "Disuelves las Cortes y arranca una nueva campaña. Perderás el cargo si no repites mayoría. ¿Convocar?", "Convocar elecciones", Callable(self, "_do_elections"), "danger")

func _do_elections() -> void:
	var r := m.coal.call_early_elections()
	m.save_now()
	if bool(r.get("elections", false)):
		shell.go("home")
		shell.info("Elecciones generales", "Se convocan nuevas elecciones. Arranca una nueva campaña electoral.", "warn")
	else:
		shell.toast(str(r.get("error", "")), "negative")

# ---------------------------------------------------------------- historial
func _tab_history() -> void:
	var cols := columns(1.0, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var c := UI.card(left, "Historial de la coalición", "", UI.ACCENT)
	var lg := m.coal.log_entries(12)
	if lg.is_empty():
		c.add_child(UI.label("Sin episodios todavía.", UI.FS_SMALL, UI.FAINT))
	for e in lg:
		c.add_child(UI.wrap_label("T%d · %s" % [int((e as Dictionary).get("turn", 0)), str((e as Dictionary).get("text", ""))], UI.FS_SMALL, UI.TEXT))
	var c2 := UI.card(right, "Actividad de los ministros", "", UI.GOOD)
	var ml := m.mact.log_entries(8)
	if ml.is_empty():
		c2.add_child(UI.label("Sin actividad registrada.", UI.FS_SMALL, UI.FAINT))
	for e2 in ml:
		var d: Dictionary = e2
		c2.add_child(UI.wrap_label("T%d · %s · %s: %s" % [int(d.get("turn", 0)), str(MinisterActivity.KIND_NAMES.get(str(d.get("kind", "")), "")), str(d.get("ministry", "")), str(d.get("text", ""))], UI.FS_SMALL, UI.TEXT))
	var c3 := UI.card(right, "Cambios en el Consejo", "", UI.WARN)
	for e3 in m.cab.log_entries(6):
		c3.add_child(UI.wrap_label("T%d · %s" % [int((e3 as Dictionary).get("turn", 0)), str((e3 as Dictionary).get("text", ""))], UI.FS_SMALL, UI.TEXT))
