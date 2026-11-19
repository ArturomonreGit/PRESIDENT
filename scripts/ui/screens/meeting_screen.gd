class_name MeetingScreen
extends Screen
## Mesa de negociación: una sola pantalla. Arriba el interlocutor y el estado de la mesa; a la izquierda lo que sabes de él y la
## conversación; en el centro la mesa (lo que pones tú y lo que ponen ellos, con la reacción de cada término); a la derecha el
## catálogo para añadir condiciones (votos, cartera, medidas, leyes, vetos a terceros). Sin desplazamiento.

static var return_to := "negotiation"
static var tab := "participacion"
static var side := "ask"
static var page := 0
static var panel := ""  ## "" = catálogo · "drafts" = borradores · "versions" = versiones y comparación
static var cmp_index := -1
static var replace_idx := -1  ## condición que se está sustituyendo (o a la que se ofrece una alternativa)
static var _key := ""

const PAGE_SIZE := 6
const KIND_TAG := {
	"vote_yes": "VOTO", "vote_abstain": "ABSTENCIÓN", "cabinet": "GOBIERNO", "policy": "MEDIDA", "bills": "LEYES", "joint_list": "LISTA",
	"stability": "ESTABILIDAD", "law_vote": "LEY", "law_abstain": "LEY", "law_amend": "ENMIENDA", "owe_vote": "FAVOR", "cordon": "VETO",
	"participation": "PARTICIPACIÓN", "structure": "ESTRUCTURA", "portfolio": "CARTERA", "objective": "OBJETIVO", "territory": "TERRITORIO",
	"budget": "PRESUPUESTO", "parliament": "PARLAMENTO", "institution": "INSTITUCIONES", "calendar": "CALENDARIO"
}
const DANGER := Color("#C0392B")

func wants_full() -> bool:
	return true

func build() -> void:
	var mt := m.diplomacy.current()
	if mt.is_empty():
		var c0 := UI.card(self, "Mesa de negociación")
		empty_note(c0, "No hay ninguna mesa abierta. Abre una desde Negociación o desde una propuesta de la Bandeja.")
		c0.add_child(UI.button("Ir a Negociación", "primary", func() -> void: shell.go("negotiation")))
		return
	var id := str(mt["with"])
	var is_open := str(mt["status"]) == "open"
	var key := "%s_%s_%d_%s" % [id, str(mt["topic"]), m.cycle, str(mt.get("period", ""))]
	if key != _key:
		_key = key
		tab = "participacion"
		side = "ask"
		page = 0
		panel = ""
		cmp_index = -1
		replace_idx = -1
	_header(mt, id, is_open)
	_banner(mt, id, is_open)
	var main := UI.hbox(10)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main)
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(440, 0)
	main.add_child(left)
	var center := UI.vbox(8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(center)
	var right := UI.vbox(8)
	right.custom_minimum_size = Vector2(430, 0)
	main.add_child(right)
	_know(left, mt, id)
	_conversation(left, mt, id)
	_table(center, mt, id, is_open)
	_room(center, mt, id)
	if is_open:
		_palette(right, mt, id)
	else:
		_result(right, mt, id)
	_footer(mt, id, is_open)

# ---------------------------------------------------------------- cabecera
func _header(mt: Dictionary, id: String, is_open: bool) -> void:
	var col := m.party_color(id)
	var hero := UI.hero(self, Color(col, 0.14), Color(col, 0.55))
	var row := UI.hbox(16)
	hero.add_child(row)
	var tone := m.diplomacy._tone_of(id, mt)
	row.add_child(UI.leader_portrait(m, id, 76, "happy" if tone == "warm" else ("angry" if tone == "cold" else "neutral")))
	var t := UI.vbox(1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.eyebrow("Mesa de negociación · %s" % str(Diplomacy.TOPICS[str(mt["topic"])]["name"])))
	t.add_child(UI.label("%s · %s" % [m.party_name(id), m.leader_name(id)], UI.FS_H2, UI.TEXT, true))
	var weight := ("%d escaños" % m.seats_of(id)) if m.phase != "campaign" else ("%.1f%% en las encuestas" % m.poll_of(id))
	t.add_child(UI.label("%s · %s" % [weight, m.diplomacy.stakes_text(mt)], UI.FS_BODY, UI.MUTED))
	row.add_child(t)
	var side_box := UI.hbox(22)
	side_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pat := int(mt["patience"])
	var dots := ""
	for i in range(4):
		dots += ("●" if i < pat else "○")
	var v1 := UI.vbox(0)
	v1.add_child(UI.label("PACIENCIA", UI.FS_TINY, UI.FAINT, true))
	v1.add_child(UI.label(dots, UI.FS_LEAD, UI.BAD if pat <= 1 else UI.TEXT, true))
	side_box.add_child(v1)
	var v2 := UI.vbox(0)
	v2.add_child(UI.label("RONDA", UI.FS_TINY, UI.FAINT, true))
	v2.add_child(UI.label("%d de %d" % [mini(int(mt["round"]) + (1 if is_open else 0), Diplomacy.MAX_ROUNDS), Diplomacy.MAX_ROUNDS], UI.FS_LEAD, UI.TEXT, true))
	side_box.add_child(v2)
	var v3 := UI.vbox(0)
	v3.add_child(UI.label("RELACIÓN", UI.FS_TINY, UI.FAINT, true))
	v3.add_child(UI.label("%d / 100" % int(m.ai.relation(id)), UI.FS_LEAD, UI.TEXT, true))
	side_box.add_child(v3)
	var v4 := UI.vbox(0)
	v4.add_child(UI.label("AMBIENTE", UI.FS_TINY, UI.FAINT, true))
	var rap := float(mt.get("rapport", 0.0))
	v4.add_child(UI.label("%+d" % int(rap), UI.FS_LEAD, UI.GOOD if rap > 2.0 else (UI.BAD if rap < -2.0 else UI.TEXT), true))
	side_box.add_child(v4)
	row.add_child(side_box)

# ---------------------------------------------------------------- avisos de la mesa
func _banner(mt: Dictionary, id: String, is_open: bool) -> void:
	if not is_open:
		return
	var alert: Dictionary = mt.get("alert", {})
	var choice: Dictionary = mt.get("choice", {})
	var final := bool(mt.get("final", false))
	if alert.is_empty() and choice.is_empty() and not final:
		return
	var tone := UI.BAD if final else UI.tone_color(str(alert.get("tone", "warn")))
	if tone == UI.MUTED:
		tone = UI.WARN
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color(tone, 0.10), Color(tone, 0.6), 6, 1, 14, 7))
	var h := UI.hbox(12)
	bar.add_child(h)
	if final:
		h.add_child(UI.chip("ÚLTIMA OFERTA", UI.BAD, true))
		h.add_child(UI.wrap_label("Han puesto sobre la mesa su última oferta: cualquier cosa que no sea aceptarla rompe las negociaciones.", UI.FS_BODY, UI.TEXT))
	elif not alert.is_empty():
		h.add_child(UI.chip(str(alert["title"]).to_upper(), tone, true))
		var l := UI.wrap_label(str(alert["text"]), UI.FS_BODY, UI.TEXT)
		l.max_lines_visible = 2
		h.add_child(l)
	if not choice.is_empty():
		if final or not alert.is_empty():
			h.add_child(UI.fill())
		else:
			h.add_child(UI.wrap_label(str(choice.get("text", "")), UI.FS_BODY, UI.TEXT))
		for o in choice.get("options", []):
			var od: Dictionary = o
			var oid := str(od["id"])
			var pick := func() -> void:
				var fb := m.diplomacy.resolve_choice(oid)
				m.save_now()
				if fb != "":
					shell.toast(fb, "neutral")
				shell.refresh()
			var b := UI.pill(str(od["label"]), false, pick, false, UI.PILL_WARN if oid == "match" else UI.PILL_SUB)
			h.add_child(b)
	add_child(bar)

# ---------------------------------------------------------------- lo que sabes de ellos
func _know(parent: Node, mt: Dictionary, id: String) -> void:
	var c := UI.card(parent, "Lo que sabes de %s" % m.party_short(id), "", m.party_color(id))
	var disp := m.brain.disposition(id, m.pid()) + float(mt.get("rapport", 0.0)) * 0.3
	var dl := m.brain.disposition_label(clampf(disp, 0.0, 100.0))
	var r1 := UI.hbox(8)
	r1.add_child(UI.chip(str(dl["text"]), UI.tone_color(str(dl["tone"])), true))
	var mb := UI.meter(clampf(disp, 0.0, 100.0), 100.0, UI.tone_color(str(dl["tone"])), 8)
	mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(mb)
	c.add_child(r1)
	var arch := UI.wrap_label(m.brain.archetype(id), UI.FS_SMALL, UI.MUTED)
	arch.max_lines_visible = 2
	c.add_child(arch)
	if str(mt["topic"]) == "law_deal":
		var law := m.laws.find(str(mt.get("law", "")))
		if not law.is_empty():
			var st: Dictionary = m.laws.stance(law, id)
			var fc: Dictionary = m.laws.forecast(law)
			var ll := UI.label("«%s» · %d a favor / %d en contra" % [str(law["title"]), int(fc["yes"]), int(fc["no"])], UI.FS_SMALL, UI.TEXT, true)
			ll.clip_text = true
			c.add_child(ll)
			var vote := str(st["vote"])
			c.add_child(UI.label("Postura de %s: %s" % [m.party_short(id), {"yes": "a favor", "no": "en contra", "abstain": "duda"}[vote]], UI.FS_SMALL, {"yes": UI.GOOD, "no": UI.BAD, "abstain": UI.WARN}[vote]))
	var pw: Dictionary = m.brain.negotiating_power(id)
	var pl := UI.label("Poder negociador: %s" % m.brain.power_label(float(pw["total"])), UI.FS_SMALL, UI.TEXT, true)
	var tip: Array = []
	for f in pw["factors"]:
		var fd: Dictionary = f
		tip.append("%s (%d %%): %d" % [str(fd["label"]), int(round(float(fd["weight"]) * 100.0)), int(round(float(fd["value"]) * 100.0))])
	pl.tooltip_text = "\n".join(tip)
	pl.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(pl)
	if bool(mt.get("sounded", false)):
		var pm: Dictionary = m.brain.preferred_modality(id)
		var ml0 := UI.label("Prefiere: %s" % str(Rules.MODALITIES[str(pm["mode"])]["short"]), UI.FS_SMALL, UI.TEXT, true)
		ml0.tooltip_text = "%s: %s." % [str(Rules.MODALITIES[str(pm["mode"])]["desc"]), str(pm["reason"])]
		ml0.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(ml0)
	if bool(mt.get("has_alternatives", false)):
		c.add_child(UI.label("Tiene alternativas de Gobierno: aguanta menos la mesa.", UI.FS_SMALL, UI.WARN))
	if bool(mt.get("sounded", false)):
		var issues: Array = []
		for i in m.brain.top_issues(id, 2):
			issues.append(Rules.issue_name(str(i)).to_lower())
		c.add_child(UI.label("Prioridades: %s" % " y ".join(issues), UI.FS_SMALL, UI.TEXT, true))
		var shown := 0
		for rl in m.brain.red_lines(id):
			if shown >= 3:
				break
			var l := UI.label("• " + str((rl as Dictionary)["text"]), UI.FS_SMALL, UI.BAD)
			l.clip_text = true
			c.add_child(l)
			shown += 1
		if m.diplomacy.context_for(mt).get("enforce_must", false):
			var table: Array = mt["table"]
			for t in m.brain.must_terms(id):
				var td: Dictionary = t
				var have := false
				for x in table:
					var xd: Dictionary = x
					if str(xd.get("k", "")) == "policy" and str(xd.get("by", "")) == "player" and str(xd.get("issue", "")) == str(td["issue"]):
						have = true
				var ml := UI.label("%s inegociable: %s" % ["✓" if have else "✗", str(td.get("text", "")).to_lower()], UI.FS_SMALL, UI.GOOD if have else UI.BAD, true)
				ml.clip_text = true
				c.add_child(ml)
	else:
		c.add_child(UI.wrap_label("Sondea su posición para conocer sus prioridades, líneas rojas y cómo valoran cada término.", UI.FS_SMALL, UI.FAINT))
	var pacts := m.diplomacy.active_pacts(id)
	if not pacts.is_empty():
		var pf := HFlowContainer.new()
		pf.add_theme_constant_override("h_separation", 6)
		for p in pacts.slice(0, 3):
			pf.add_child(UI.chip("Pacto: " + str(Diplomacy.TOPICS[str((p as Dictionary)["kind"])]["name"]), UI.GOOD))
		c.add_child(pf)

# ---------------------------------------------------------------- conversación
func _conversation(parent: Node, mt: Dictionary, id: String) -> void:
	var c := UI.card(parent, "Conversación", "", m.party_color(id))
	UI.expand_card(c)
	var log: Array = mt["log"]
	var start := maxi(0, log.size() - 4)
	if start > 0:
		c.add_child(UI.label("… %d intervenciones anteriores" % start, UI.FS_TINY, UI.FAINT))
	for i in range(start, log.size()):
		c.add_child(_bubble(log[i] as Dictionary, id))

func _bubble(e: Dictionary, id: String) -> Control:
	var who := str(e.get("who", "ai"))
	var tone := str(e.get("tone", "neutral"))
	if who == "sys":
		var l := UI.wrap_label(str(e["text"]), UI.FS_SMALL, UI.WARN)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	var row := UI.hbox(8)
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := m.party_color(id) if who == "ai" else UI.ACCENT
	if tone == "bad":
		border = UI.BAD
	elif tone == "good":
		border = UI.GOOD
	pc.add_theme_stylebox_override("panel", UI.box(Color(border, 0.09), Color(border, 0.45), 8, 1, 10, 6))
	var col := UI.vbox(1)
	pc.add_child(col)
	col.add_child(UI.label(m.party_short(id) if who == "ai" else "Tú", UI.FS_TINY, border, true))
	var txt := UI.wrap_label(str(e["text"]), UI.FS_SMALL, UI.TEXT)
	txt.max_lines_visible = 4
	txt.tooltip_text = str(e["text"])
	txt.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(txt)
	if who == "ai":
		row.add_child(UI.party_emblem(m, id, 26))
		row.add_child(pc)
		row.add_child(UI.spacer(0, 26))
	else:
		row.add_child(UI.spacer(0, 26))
		row.add_child(pc)
	return row

# ---------------------------------------------------------------- la mesa
func _table(parent: Node, mt: Dictionary, id: String, is_open: bool) -> void:
	var c := UI.card(parent, "La mesa", "Lo que se pone y cómo lo ve %s" % m.party_short(id), UI.D4_BLUE)
	UI.expand_card(c)
	var table: Array = mt["table"]
	var ctx := m.diplomacy.context_for(mt)
	var show_stance := int(mt["round"]) > 0 or bool(mt.get("sounded", false))
	var stn: Array = m.diplomacy.dyn.stances(id, table, ctx) if show_stance else []
	var statuses: Array = m.diplomacy.term_statuses(mt)
	var lanes := UI.hbox(12)
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(lanes)
	var mine := UI.vbox(6)
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var theirs := UI.vbox(6)
	theirs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes.add_child(mine)
	lanes.add_child(UI.vsep())
	lanes.add_child(theirs)
	mine.add_child(UI.label("TÚ PONES", UI.FS_SMALL, UI.D4_BLUE_D, true))
	theirs.add_child(UI.label("%s PONE" % m.party_short(id), UI.FS_SMALL, m.party_color(id).darkened(0.2), true))
	var n_mine := 0
	var n_theirs := 0
	for i in range(table.size()):
		var t: Dictionary = table[i]
		var by_ai := str(t.get("by", "player")) == "ai"
		var st: Dictionary = stn[i] if i < stn.size() else {}
		var row := _term_row(t, i, is_open, st, id, bool(mt.get("sounded", false)), statuses[i] if i < statuses.size() else {})
		if by_ai:
			theirs.add_child(row)
			n_theirs += 1
		else:
			mine.add_child(row)
			n_mine += 1
	if n_mine == 0:
		mine.add_child(UI.wrap_label("No te comprometes a nada. Ofrece algo para que quieran darte lo que pides.", UI.FS_SMALL, UI.FAINT))
	if n_theirs == 0:
		theirs.add_child(UI.wrap_label("No aportan nada todavía. Pide votos, carteras o medidas.", UI.FS_SMALL, UI.FAINT))
	var counts: Dictionary = m.diplomacy.status_counts(mt)
	if int(counts["must"]) + int(counts["negotiable"]) + int(counts["rejected"]) > 0:
		var sum := HFlowContainer.new()
		sum.add_theme_constant_override("h_separation", 6)
		sum.add_child(UI.label("Según lo que sabes:", UI.FS_SMALL, UI.MUTED))
		sum.add_child(UI.chip("%d imprescindibles" % int(counts["must"]), UI.BAD, int(counts["must"]) > 0))
		sum.add_child(UI.chip("%d negociables" % int(counts["negotiable"]), UI.GOOD))
		sum.add_child(UI.chip("%d rechazadas" % int(counts["rejected"]), UI.MUTED))
		c.add_child(sum)

func _term_row(t: Dictionary, idx: int, is_open: bool, st: Dictionary, id: String, sounded: bool, status: Dictionary = {}) -> Control:
	var by_ai := str(t.get("by", "player")) == "ai"
	var accent := m.party_color(id) if by_ai else UI.D4_BLUE
	if str(t.get("k", "")) == "joint_list":
		accent = UI.GOLD
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.D4_LINE, 4, 1, 8, 5))
	var h := UI.hbox(8)
	pc.add_child(h)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(5, 0)
	h.add_child(bar)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 5)
	top.add_theme_constant_override("v_separation", 2)
	v.add_child(top)
	top.add_child(UI.label(str(KIND_TAG.get(str(t.get("k", "")), "TÉRMINO")), UI.FS_TINY, accent.darkened(0.15), true))
	if bool(t.get("ultimatum", false)):
		top.add_child(UI.chip("ÚLTIMA OFERTA", UI.BAD, true))
	elif bool(t.get("new", false)):
		top.add_child(UI.chip("NUEVA EXIGENCIA", UI.WARN, true))
	elif bool(t.get("changed", false)):
		top.add_child(UI.chip("AJUSTADO", UI.WARN))
	elif bool(t.get("sweetener", false)):
		top.add_child(UI.chip("TU MEJORA", UI.GOOD))
	elif bool(t.get("opening", false)):
		top.add_child(UI.chip("SU PROPUESTA", m.party_color(id)))
	elif bool(t.get("from_ai", false)):
		top.add_child(UI.chip("SU CONTRAOFERTA", m.party_color(id)))
	if not st.is_empty():
		var stance := str(st["stance"])
		var chip_text := ""
		var chip_col := UI.MUTED
		match stance:
			"ok":
				chip_text = "Lo aceptan" if by_ai else "Bien"
				chip_col = UI.GOOD
			"welcome":
				chip_text = "Les interesa"
				chip_col = UI.GOOD
			"costly":
				chip_text = "Les cuesta"
				chip_col = UI.WARN
			"refuse":
				chip_text = "Lo rechazan"
				chip_col = UI.BAD
			"veto":
				chip_text = "Veto"
				chip_col = UI.BAD
		if chip_text != "" and (sounded or stance in ["veto", "refuse", "costly"]):
			var sc := UI.chip(chip_text, chip_col, stance in ["veto", "refuse"])
			sc.tooltip_text = str(st.get("note", ""))
			top.add_child(sc)
	var sk := str(status.get("status", "unknown"))
	if sk == "must":
		var mc := UI.chip("IMPRESCINDIBLE", UI.BAD, true)
		mc.tooltip_text = str(status.get("why", ""))
		top.add_child(mc)
	elif sk == "rejected" and str(st.get("stance", "")) not in ["veto", "refuse"]:
		var rc := UI.chip("RECHAZADA", UI.MUTED, true)
		rc.tooltip_text = str(status.get("why", ""))
		top.add_child(rc)
	elif sk == "negotiable" and st.is_empty():
		var nc := UI.chip("NEGOCIABLE", UI.GOOD)
		nc.tooltip_text = str(status.get("why", ""))
		top.add_child(nc)
	if bool(t.get("partial", false)):
		top.add_child(UI.chip("PARCIAL", UI.WARN))
	if str(t.get("alt_for", "")) != "":
		var ac := UI.chip("ALTERNATIVA", UI.D4_BLUE)
		ac.tooltip_text = "En lugar de: " + str(t["alt_for"])
		top.add_child(ac)
	elif str(t.get("replaced", "")) != "":
		var pc2 := UI.chip("SUSTITUYE", UI.D4_BLUE)
		pc2.tooltip_text = "Antes: " + str(t["replaced"])
		top.add_child(pc2)
	var txt := UI.wrap_label(_cap(m.brain.term_text(t)), UI.FS_BODY, UI.TEXT, true)
	txt.max_lines_visible = 2
	txt.tooltip_text = m.brain.term_text(t)
	txt.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(txt)
	if is_open:
		var tools := UI.hbox(3)
		tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var qty_field := "n" if t.has("n") and str(t.get("k", "")) in ["cabinet", "bills", "territory", "budget", "institution", "calendar", "structure"] else ("level" if t.has("level") else "")
		if qty_field != "":
			var lo := 1
			var hi := 3
			var step := 1
			if str(t.get("k", "")) == "structure":
				lo = 8
				hi = 20
				step = 2
			elif str(t.get("k", "")) == "calendar":
				lo = 3
				hi = 24
				step = 3
			elif str(t.get("k", "")) in ["cabinet", "bills"]:
				hi = 6
			var less := UI.mini_button("−", func() -> void:
				m.diplomacy.modify_term(idx, {qty_field: maxi(lo, int(t.get(qty_field, lo)) - step)})
				shell.refresh())
			less.custom_minimum_size = Vector2(24, 26)
			less.tooltip_text = "Reducir la cantidad o el nivel"
			tools.add_child(less)
			var more := UI.mini_button("+", func() -> void:
				m.diplomacy.modify_term(idx, {qty_field: mini(hi, int(t.get(qty_field, lo)) + step)})
				shell.refresh())
			more.custom_minimum_size = Vector2(24, 26)
			more.tooltip_text = "Aumentar la cantidad o el nivel"
			tools.add_child(more)
		if bool(t.get("from_ai", false)) and m.diplomacy.can_split(t):
			var half := UI.mini_button("½", func() -> void:
				m.diplomacy.accept_partially(idx)
				shell.refresh())
			half.custom_minimum_size = Vector2(26, 26)
			half.tooltip_text = "Aceptar solo una parte de esta exigencia"
			tools.add_child(half)
		var swap := UI.mini_button("⇄", func() -> void:
			replace_idx = -1 if replace_idx == idx else idx
			panel = ""
			rebuild())
		swap.custom_minimum_size = Vector2(26, 26)
		swap.tooltip_text = "Sustituir por otra condición" + (" u ofrecer una alternativa a su exigencia" if bool(t.get("from_ai", false)) else "")
		if replace_idx == idx:
			swap.add_theme_color_override("font_color", UI.D4_BLUE_D)
		tools.add_child(swap)
		var x := UI.mini_button("✕", func() -> void:
			m.diplomacy.remove_term(idx)
			replace_idx = -1
			shell.refresh())
		x.custom_minimum_size = Vector2(28, 26)
		x.tooltip_text = "Retirar de la mesa"
		tools.add_child(x)
		h.add_child(tools)
	return pc

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

# ---------------------------------------------------------------- lectura de la sala
func _room(parent: Node, mt: Dictionary, id: String) -> void:
	var c := UI.card(parent, "Lectura de la sala", "", UI.WARN)
	var read := m.diplomacy.read_the_room(mt)
	var tone := str(read["tone"])
	var row := UI.hbox(10)
	row.add_child(UI.chip(str(read["label"]), UI.tone_color(tone), true))
	var mb := UI.meter(float(read["ratio"]) * 100.0, 100.0, UI.tone_color(tone), 10)
	mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mb)
	c.add_child(row)
	if not bool(mt.get("sounded", false)):
		c.add_child(UI.label("Solo una impresión: sondea su posición para ver el detalle de su valoración.", UI.FS_SMALL, UI.FAINT))
		return
	var exact: Dictionary = read["exact"]
	var grid := UI.grid(2, 22, 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(grid)
	var shown := 0
	for f in exact["factors"]:
		var fd: Dictionary = f
		if shown >= 6:
			break
		var v := float(fd["value"])
		var line := UI.hbox(8)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.label(str(fd["label"]), UI.FS_SMALL, UI.MUTED)
		nm.custom_minimum_size = Vector2(170, 0)
		nm.clip_text = true
		line.add_child(nm)
		var bar := UI.meter(clampf(absf(v), 0.0, 0.6) * 100.0 / 0.6, 100.0, UI.GOOD if v >= 0.0 else UI.BAD, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var val := UI.label("%+.2f" % v, UI.FS_SMALL, UI.GOOD if v >= 0.0 else UI.BAD, true)
		val.custom_minimum_size = Vector2(42, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(val)
		grid.add_child(line)
		shown += 1
	c.add_child(UI.label("Exigen un balance de %+.2f; ahora hay %+.2f." % [float(exact["need"]), float(exact["utility"])], UI.FS_SMALL, UI.TEXT, true))

# ---------------------------------------------------------------- catálogo para añadir a la mesa
func _tab_of(t: Dictionary) -> String:
	return m.diplomacy.category_of(t)

func _palette(parent: Node, mt: Dictionary, id: String) -> void:
	var c := UI.card(parent, "Añadir a la mesa", "", UI.D4_BLUE)
	UI.expand_card(c)
	var modes := HFlowContainer.new()
	modes.add_theme_constant_override("h_separation", 5)
	modes.add_theme_constant_override("v_separation", 4)
	var dn := m.diplomacy.drafts().size()
	var vn := m.diplomacy.versions().size()
	for md in [["", "Catálogo"], ["drafts", "Borradores · %d" % dn], ["versions", "Versiones · %d" % vn]]:
		var mk := str(md[0])
		var set_mode := func() -> void:
			panel = mk
			cmp_index = -1
			replace_idx = -1
			rebuild()
		modes.add_child(UI.pill(str(md[1]), panel == mk, set_mode, false, UI.PILL_SUB))
	c.add_child(modes)
	if panel == "drafts":
		_drafts_panel(c, mt)
		return
	if panel == "versions":
		_versions_panel(c, mt)
		return
	var table: Array = mt["table"]
	if replace_idx >= 0 and replace_idx < table.size():
		var old_t: Dictionary = table[replace_idx]
		var from_ai := bool(old_t.get("from_ai", false))
		var rb := PanelContainer.new()
		rb.add_theme_stylebox_override("panel", UI.box(Color(UI.D4_BLUE, 0.10), UI.D4_BLUE, 4, 1, 8, 4))
		rb.add_child(UI.wrap_label("%s «%s». Elige abajo la condición nueva." % ["Ofreces una alternativa a" if from_ai else "Sustituyes", _cap(m.brain.term_text(old_t))], UI.FS_SMALL, UI.TEXT, true))
		c.add_child(rb)
	var menu := m.diplomacy.term_menu(id, str(mt["topic"]))
	var sides := UI.hbox(6)
	for sd in [["ask", "Lo que pides"], ["give", "Lo que ofreces"]]:
		var key := str(sd[0])
		var set_side := func() -> void:
			side = key
			page = 0
			rebuild()
		var sp := UI.pill(str(sd[1]), side == key, set_side, false, UI.PILL_SUB)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sides.add_child(sp)
	c.add_child(sides)
	var items: Array = []
	for t in menu[side]:
		var td: Dictionary = t
		if not m.diplomacy._menu_has(table, td) and not _on_table(table, td):
			items.append(td)
	var counts := {}
	for it in items:
		counts[_tab_of(it as Dictionary)] = int(counts.get(_tab_of(it as Dictionary), 0)) + 1
	if not counts.has(tab):
		for cat0 in Rules.TABLE_CATEGORY_ORDER:
			if counts.has(str(cat0)):
				tab = str(cat0)
				break
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	for cat in Rules.TABLE_CATEGORY_ORDER:
		var tk := str(cat)
		if not counts.has(tk):
			continue
		var pick_tab := func() -> void:
			tab = tk
			page = 0
			rebuild()
		tabs.add_child(UI.pill("%s · %d" % [str(Rules.TABLE_CATEGORIES[cat]["name"]), int(counts[tk])], tab == tk, pick_tab, false, UI.PILL_SUB))
	c.add_child(tabs)
	var list: Array = []
	for it2 in items:
		if _tab_of(it2 as Dictionary) == tab:
			list.append(it2)
	var pages := maxi(1, int(ceil(float(list.size()) / float(PAGE_SIZE))))
	page = clampi(page, 0, pages - 1)
	if list.is_empty():
		c.add_child(UI.wrap_label("No quedan condiciones de este tipo por añadir.", UI.FS_SMALL, UI.FAINT))
	var ctx := m.diplomacy.context_for(mt)
	for k in range(page * PAGE_SIZE, mini(list.size(), (page + 1) * PAGE_SIZE)):
		c.add_child(_menu_item(list[k] as Dictionary, id, ctx, bool(mt.get("sounded", false))))
	if pages > 1:
		var pg := UI.hbox(6)
		var prev := UI.mini_button("‹", func() -> void:
			page -= 1
			rebuild())
		prev.disabled = page <= 0
		var next := UI.mini_button("›", func() -> void:
			page += 1
			rebuild())
		next.disabled = page >= pages - 1
		pg.add_child(prev)
		var pl := UI.label("%d / %d" % [page + 1, pages], UI.FS_SMALL, UI.MUTED)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pg.add_child(pl)
		pg.add_child(next)
		c.add_child(pg)
	c.add_child(UI.fill())
	var hint := "Pide lo que quieres que asuman; ofrece lo que ellos valoran. Los vetos («no pactar con…») son moneda de cambio, pero te atan." if side == "ask" else "Lo que ofreces te compromete: si lo incumples después, se rompe el pacto y se resiente la relación."
	c.add_child(UI.wrap_label(hint, UI.FS_SMALL, UI.FAINT))

# ---------------------------------------------------------------- borradores y versiones
func _drafts_panel(c: Control, mt: Dictionary) -> void:
	var drafts := m.diplomacy.drafts()
	var do_save := func() -> void:
		var fb := m.diplomacy.save_draft()
		shell.toast(fb, "neutral")
		m.save_now()
		rebuild()
	var save := UI.pill("Guardar la mesa actual como borrador", false, do_save, false, UI.PILL_GO)
	save.disabled = (mt["table"] as Array).is_empty() or drafts.size() >= Rules.MAX_DRAFTS
	c.add_child(save)
	if drafts.is_empty():
		c.add_child(UI.wrap_label("Aún no hay borradores. Guarda la mesa para probar otra combinación y volver a esta cuando quieras (máximo %d)." % Rules.MAX_DRAFTS, UI.FS_SMALL, UI.FAINT))
	for i in range(drafts.size()):
		var d: Dictionary = drafts[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.D4_LINE, 4, 1, 8, 4))
		var h := UI.hbox(6)
		row.add_child(h)
		var info := UI.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(str(d["name"]), UI.FS_BODY, UI.TEXT, true))
		var summ := UI.label("%d condiciones · ronda %d" % [(d["table"] as Array).size(), int(d.get("round", 0))], UI.FS_SMALL, UI.MUTED)
		summ.clip_text = true
		info.add_child(summ)
		h.add_child(info)
		var idx := i
		h.add_child(UI.mini_button("Usar", func() -> void:
			m.diplomacy.load_draft(idx)
			panel = ""
			shell.refresh()))
		h.add_child(UI.mini_button("✕", func() -> void:
			m.diplomacy.delete_draft(idx)
			rebuild()))
		c.add_child(row)
	c.add_child(UI.fill())

func _versions_panel(c: Control, mt: Dictionary) -> void:
	var vers := m.diplomacy.versions()
	if vers.is_empty():
		c.add_child(UI.wrap_label("Aún no hay versiones: cada oferta que presentas y cada contraoferta suya quedan guardadas aquí para compararlas.", UI.FS_SMALL, UI.FAINT))
		c.add_child(UI.fill())
		return
	var shown := 0
	for ii in range(vers.size() - 1, -1, -1):
		if shown >= 5:
			break
		shown += 1
		var v: Dictionary = vers[ii]
		var by_ai := str(v["who"]) == "ai"
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(Color("#E3EFFB") if cmp_index == ii else UI.PANEL2, UI.D4_BLUE if cmp_index == ii else UI.D4_LINE, 4, 1, 8, 4))
		var h := UI.hbox(6)
		row.add_child(h)
		h.add_child(UI.chip("SU TURNO" if by_ai else "TU TURNO", UI.WARN if by_ai else UI.D4_BLUE))
		var info := UI.label("v%d · %s · %d condiciones" % [int(v["n"]), str(v["label"]), (v["table"] as Array).size()], UI.FS_SMALL, UI.TEXT)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		h.add_child(info)
		var idx := ii
		h.add_child(UI.mini_button("Comparar", func() -> void:
			cmp_index = -1 if cmp_index == idx else idx
			rebuild()))
		h.add_child(UI.mini_button("Recuperar", func() -> void:
			m.diplomacy.restore_version(idx)
			panel = ""
			shell.refresh()))
		c.add_child(row)
	if cmp_index >= 0 and cmp_index < vers.size():
		var diff := m.diplomacy.compare_tables((vers[cmp_index] as Dictionary)["table"], mt["table"])
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.D4_LINE, 4, 1, 8, 6))
		var bv := UI.vbox(2)
		box.add_child(bv)
		bv.add_child(UI.label("De la v%d a la mesa actual" % int((vers[cmp_index] as Dictionary)["n"]), UI.FS_SMALL, UI.D4_BLUE_D, true))
		var any := false
		for t in diff["added"]:
			any = true
			var l1 := UI.label("+ " + _cap(m.brain.term_text(t as Dictionary)), UI.FS_SMALL, UI.GOOD)
			l1.clip_text = true
			bv.add_child(l1)
		for t2 in diff["removed"]:
			any = true
			var l2 := UI.label("− " + _cap(m.brain.term_text(t2 as Dictionary)), UI.FS_SMALL, UI.BAD)
			l2.clip_text = true
			bv.add_child(l2)
		for ch in diff["changed"]:
			any = true
			var l3 := UI.label("± %s → %s" % [m.brain.term_text((ch as Dictionary)["before"] as Dictionary), m.brain.term_text((ch as Dictionary)["after"] as Dictionary)], UI.FS_SMALL, UI.WARN)
			l3.clip_text = true
			bv.add_child(l3)
		if not any:
			bv.add_child(UI.label("Sin diferencias con la mesa actual.", UI.FS_SMALL, UI.MUTED))
		c.add_child(box)
	c.add_child(UI.fill())

func _on_table(table: Array, term: Dictionary) -> bool:
	for t in table:
		var d: Dictionary = t
		if str(d.get("k", "")) == str(term.get("k", "")) and str(d.get("by", "")) == str(term.get("by", "")):
			if str(term.get("k", "")) in ["vote_yes", "vote_abstain", "joint_list", "stability", "owe_vote", "law_vote", "law_abstain"]:
				return true
	return false

func _menu_item(term: Dictionary, id: String, ctx: Dictionary, sounded: bool) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text = "   +  " + _cap(m.brain.term_text(term))
	b.tooltip_text = m.brain.term_text(term)
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL2, UI.D4_LINE, 4, 1, 10, 4))
	b.add_theme_stylebox_override("hover", UI.box(Color("#E3EFFB"), UI.D4_BLUE, 4, 1, 10, 4))
	b.add_theme_stylebox_override("pressed", UI.box(Color("#CFE4F8"), UI.D4_BLUE_D, 4, 1, 10, 4))
	b.add_theme_color_override("font_color", UI.TEXT)
	b.add_theme_font_size_override("font_size", UI.FS_BODY)
	if sounded:
		var v := float(m.brain.term_value(id, m.pid(), term, ctx)["v"])
		var by_ai := str(term.get("by", "player")) == "ai"
		var col := UI.MUTED
		if by_ai:
			col = UI.GOOD if v >= -0.06 else (UI.WARN if v >= -0.2 else UI.BAD)
		else:
			col = UI.GOOD if v >= 0.10 else UI.MUTED
		var dot := ColorRect.new()
		dot.color = col
		dot.custom_minimum_size = Vector2(8, 8)
		dot.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		dot.offset_left = 8
		dot.offset_right = 16
		dot.offset_top = -4
		dot.offset_bottom = 4
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	var add_it := func() -> void:
		var mt0 := m.diplomacy.current()
		var tbl: Array = mt0.get("table", [])
		if replace_idx >= 0 and replace_idx < tbl.size():
			var from_ai := bool((tbl[replace_idx] as Dictionary).get("from_ai", false))
			if from_ai:
				m.diplomacy.offer_alternative(replace_idx, term.duplicate(true))
			else:
				m.diplomacy.replace_term(replace_idx, term.duplicate(true))
			replace_idx = -1
		else:
			m.diplomacy.add_term(term.duplicate(true))
		shell.refresh()
	b.pressed.connect(add_it)
	return b

# ---------------------------------------------------------------- resultado
func _result(parent: Node, mt: Dictionary, id: String) -> void:
	var st := str(mt["status"])
	var col := UI.GOOD if st == "agreed" else (UI.BAD if st == "broken" else UI.MUTED)
	var c := UI.card(parent, "Resultado de la mesa", "", col)
	UI.expand_card(c)
	if not bool(mt.get("sfx", false)):
		mt["sfx"] = true
		Sfx.play("fanfare" if st == "agreed" else "deny", 0.8)
	c.add_child(UI.chip({"agreed": "ACUERDO", "broken": "SIN ACUERDO", "closed": "MESA CERRADA"}.get(st, "CERRADA"), col, true))
	c.add_child(UI.wrap_label(str(mt.get("result", "")), UI.FS_LEAD, UI.TEXT, true))
	if st == "agreed":
		c.add_child(UI.wrap_label("El acuerdo figura ya en Negociación. Cumplirlo mejora la relación; incumplirlo la dañará y te costará confianza.", UI.FS_SMALL, UI.MUTED))
	else:
		c.add_child(UI.wrap_label("Puedes volver a intentarlo otro %s con una propuesta distinta; lo ocurrido hoy queda en su memoria." % m.diplomacy.period_name(), UI.FS_SMALL, UI.MUTED))
	c.add_child(UI.fill())

# ---------------------------------------------------------------- acciones
func _do_submit() -> void:
	m.diplomacy.submit()
	m.save_now()
	shell.refresh()

func _do_sign() -> void:
	m.diplomacy.sign_their_proposal()
	m.save_now()
	shell.refresh()

func _do_counter() -> void:
	var r := m.diplomacy.request_counter()
	if not bool(r.get("ok", false)) and str(r.get("text", "")) != "":
		shell.toast(str(r["text"]), "warn")
	m.save_now()
	shell.refresh()

func _do_sound() -> void:
	var fb := m.diplomacy.sound()
	shell.toast(fb, "neutral")
	shell.refresh()

func _do_appeal() -> void:
	var fb := m.diplomacy.appeal()
	shell.toast(fb, "neutral")
	shell.refresh()

func _do_press() -> void:
	var fb := m.diplomacy.pressure()
	shell.toast(fb, "warn")
	shell.refresh()

func _do_leave() -> void:
	m.diplomacy.leave()
	m.save_now()
	shell.refresh()

func _go_back() -> void:
	shell.go(return_to)

func _go_pacts() -> void:
	shell.go("negotiation")

func _go_inbox() -> void:
	shell.go("inbox")

func _footer(mt: Dictionary, id: String, is_open: bool) -> void:
	var bar := UI.hbox(10)
	bar.custom_minimum_size = Vector2(0, 42)
	add_child(bar)
	if not is_open:
		bar.add_child(UI.pill("Volver", false, _go_back, true, UI.PILL_GO))
		bar.add_child(UI.pill("Pactos y negociación", false, _go_pacts, true))
		bar.add_child(UI.pill("Bandeja", false, _go_inbox, true, UI.PILL_SUB))
		return
	var table: Array = mt["table"]
	var submit := UI.pill("Presentar mi oferta", false, _do_submit, true, UI.PILL)
	submit.disabled = table.is_empty()
	submit.tooltip_text = "Presentas el contenido de la mesa. Responden según su carácter, vuestra historia y lo que hay sobre ella."
	bar.add_child(submit)
	var sign := UI.pill("Firmar su propuesta", false, _do_sign, true, UI.PILL_GO)
	var theirs := m.diplomacy.their_proposal(mt)
	sign.disabled = theirs.is_empty()
	sign.tooltip_text = "Aceptas exactamente lo que ellos proponen: " + m.diplomacy._summary_text(theirs, false)
	bar.add_child(sign)
	var ask := UI.pill("Pedir contraoferta", false, _do_counter, false, UI.PILL_SUB)
	ask.disabled = table.is_empty() or int(mt.get("counter_requests", 0)) >= 3
	ask.tooltip_text = "Les preguntas qué necesitarían para cerrar, sin presentar la oferta. Cuesta paciencia (máximo tres veces)."
	bar.add_child(ask)
	var sound := UI.pill("Sondear", false, _do_sound, false, UI.PILL_SUB)
	sound.disabled = bool(mt["sounded"])
	sound.tooltip_text = "Revela sus prioridades, líneas rojas y la valoración detallada. Mejora un poco el ambiente."
	bar.add_child(sound)
	var appeal := UI.pill("Apelar a lo que os une", false, _do_appeal, false, UI.PILL_SUB)
	appeal.disabled = bool(mt["appealed"])
	appeal.tooltip_text = "Funciona mejor cuanto más afines sois."
	bar.add_child(appeal)
	var press := UI.pill("Presionar", false, _do_press, false, UI.PILL_WARN)
	press.disabled = bool(mt["pushed"])
	press.tooltip_text = "Puede arrancar concesiones, pero daña el ambiente y la relación si sale mal."
	bar.add_child(press)
	bar.add_child(UI.fill())
	bar.add_child(UI.pill("Pausar y volver", false, _go_back, false, UI.PILL_SUB))
	bar.add_child(UI.pill("Levantarse de la mesa", false, _do_leave, false, DANGER))
