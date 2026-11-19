class_name InvestitureBroadcast
extends Control
## Pantalla especial de la votación de investidura (spec negociación §10), a pantalla completa.
## Tres momentos: presentación (candidato, pacto, posturas de los grupos, disciplina esperable),
## votación (los 350 diputados votan uno a uno en el hemiciclo con marcador en directo) y resultado
## (umbral aplicado y consecuencias). El recuento sale de GovernmentSim.hold_vote(), que usa los votos
## individuales de InvestitureVote: lo que se anima es exactamente lo que se ha votado.

signal finished(result: Dictionary)
signal closed

const SPEEDS := [1.0, 2.0, 4.0]
const SEATS_PER_SEC := 26.0

var m: GameModel
var replay := false
var phase := "intro"
var session: Dictionary = {}
var result: Dictionary = {}
var speed_i := 0
var playing := true
var revealed := 0

var hemi: VoteHemicycle
var bar: Control
var score: Dictionary = {}
var status_label: Label
var feed: VBoxContainer
var feed_box: VBoxContainer
var groups_box: VBoxContainer
var banner_holder: VBoxContainer
var actions: HBoxContainer
var title_label: Label
var sub_label: Label

var _order: Array = []
var _starts: Dictionary = {}
var _rows: Dictionary = {}
var _cand := ""
var _round := 1
var _announced: Dictionary = {}
var _intro_votes := ""
var _date := ""
var _acc := 0.0
var _feed_i := 0
var _last_int := -1
var _gavel_done := false

static func open(host: Control, model: GameModel, replay_session: Dictionary = {}) -> InvestitureBroadcast:
	var b := InvestitureBroadcast.new()
	b.m = model
	if not replay_session.is_empty():
		b.replay = true
		b.session = replay_session
	host.add_child(b)
	return b

# ---------------------------------------------------------------- construcción
func _ready() -> void:
	name = "InvestitureBroadcast"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_order = m.ivote.hall_order()
	if replay:
		_cand = str(session["cand"])
		_round = int(session["round"])
		_date = str(session.get("date", ""))
	else:
		_cand = m.gov.candidate_id()
		_round = m.gov.round_number()
		_date = m.date_label()
	_build()
	if replay:
		_begin_voting()
	else:
		_enter_intro()

func _build() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("#14233D"))
	grad.set_color(1, Color("#04060C"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var bgr := TextureRect.new()
	bgr.texture = gt
	bgr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgr.stretch_mode = TextureRect.STRETCH_SCALE
	bgr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgr)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + k, 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var root := UI.vbox(12)
	margin.add_child(root)
	root.add_child(_top_bar())
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_left_panel())
	body.add_child(_center_panel())
	body.add_child(_right_panel())
	actions = UI.hbox(10)
	root.add_child(actions)

func _panel(width: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	pc.add_theme_stylebox_override("panel", UI.box(Color(TV.PANEL, 0.92), TV.LINE, 10, 1, 14, 12))
	return pc

func _top_bar() -> Control:
	var row := UI.hbox(14)
	var emb := UI.party_emblem(m, _cand, 46)
	row.add_child(emb)
	var t := UI.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label("INVESTIDURA · EN DIRECTO DESDE EL CONGRESO", UI.FS_TINY, TV.GOLD, true))
	title_label = UI.label("", 26, TV.WHITE, true)
	t.add_child(title_label)
	sub_label = UI.label("", UI.FS_BODY, TV.MUTED)
	t.add_child(sub_label)
	row.add_child(t)
	var close := NightButton.new("close", "", 44)
	close.pressed.connect(_on_close)
	row.add_child(close)
	return row

func _left_panel() -> Control:
	var pc := _panel(410)
	var col := UI.vbox(8)
	pc.add_child(col)
	col.add_child(UI.label("EL CANDIDATO Y SU PACTO", UI.FS_TINY, TV.MUTED, true))
	col.add_child(_candidate_block())
	col.add_child(UI.hsep(TV.LINE))
	col.add_child(UI.label("POSTURA DE LOS GRUPOS", UI.FS_TINY, TV.MUTED, true))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	groups_box = UI.vbox(6)
	groups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(groups_box)
	return pc

func _candidate_block() -> Control:
	var v := UI.vbox(4)
	var name_l := UI.label(m.party_name(_cand), UI.FS_LEAD, TV.WHITE, true)
	v.add_child(name_l)
	var seats_txt := "%d escaños%s · mayoría absoluta %d" % [m.seats_of(_cand), " (tu partido)" if m.is_player(_cand) else "", Rules.MAJORITY]
	v.add_child(UI.label(seats_txt, UI.FS_SMALL, TV.MUTED))
	var partners: Array = m.gov.partners()
	if replay or partners.is_empty():
		if not replay:
			v.add_child(UI.wrap_label("Sin pactos cerrados: el candidato depende de las abstenciones y de la segunda votación.", UI.FS_SMALL, TV.MUTED))
		return v
	for id in partners:
		var offer: Dictionary = m.gov.offers().get(str(id), {})
		var role := "Coalición de Gobierno" if str(offer.get("role", "external")) == "cabinet" else ("Abstención pactada" if str(offer.get("vote", "yes")) == "abstain" else "Apoyo externo")
		var n := 0
		for d in offer.get("demands", []):
			if bool((d as Dictionary).get("conceded", false)):
				n += 1
		var h := UI.hbox(8)
		var sw := ColorRect.new()
		sw.color = m.party_color(str(id))
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		h.add_child(UI.label(m.party_short(str(id)), UI.FS_SMALL, TV.WHITE, true))
		var rl := UI.label("%s%s" % [role, " · %d condiciones" % n if n > 0 else ""], UI.FS_SMALL, TV.MUTED)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.clip_text = true
		h.add_child(rl)
		v.add_child(h)
	return v

func _center_panel() -> Control:
	var col := UI.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hemi = VoteHemicycle.new()
	var entries: Array = []
	var idx := 0
	for id in _order:
		var seats := m.seats_of(str(id))
		entries.append({"id": str(id), "color": m.party_color(str(id)), "seats": seats})
		_starts[str(id)] = [idx, idx + seats]
		idx += seats
	hemi.set_party_entries(entries)
	col.add_child(hemi)
	col.add_child(_scoreboard())
	status_label = UI.label("", UI.FS_LEAD, TV.WHITE, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status_label)
	banner_holder = UI.vbox(0)
	col.add_child(banner_holder)
	return col

func _scoreboard() -> Control:
	var v := UI.vbox(6)
	var row := UI.hbox(10)
	for spec in [["yes", "A FAVOR", VoteHemicycle.C_YES], ["abstain", "ABSTENCIONES", VoteHemicycle.C_ABS], ["no", "EN CONTRA", VoteHemicycle.C_NO]]:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var colr: Color = spec[2]
		pc.add_theme_stylebox_override("panel", UI.box(Color(colr, 0.12), Color(colr, 0.6), 10, 1, 14, 8))
		var inner := UI.vbox(0)
		pc.add_child(inner)
		inner.add_child(UI.label(str(spec[1]), UI.FS_TINY, colr, true))
		var num := UI.label("0", 40, TV.WHITE, true)
		inner.add_child(num)
		score[str(spec[0])] = num
		row.add_child(pc)
	v.add_child(row)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(0, 34)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar)
	v.add_child(bar)
	return v

func _right_panel() -> Control:
	var pc := _panel(330)
	var col := UI.vbox(8)
	pc.add_child(col)
	var title := UI.label("DISCIPLINA DE VOTO", UI.FS_TINY, TV.MUTED, true)
	col.add_child(title)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	feed_box = UI.vbox(8)
	feed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(feed_box)
	return pc

# ---------------------------------------------------------------- momentos
func _stance_of(pid: String) -> String:
	return str(_announced_detail().get(pid, "abstain"))

var _detail_cache: Dictionary = {}
func _announced_detail() -> Dictionary:
	if _detail_cache.is_empty():
		if replay:
			_detail_cache = (session.get("tally", {}) as Dictionary).get("detail", {})
			if _detail_cache.is_empty():
				for g in session["groups"]:
					var gd: Dictionary = g
					_detail_cache[str(gd["id"])] = {"y": "yes", "n": "no", "a": "abstain"}[str(gd["stance"])]
		else:
			_detail_cache = m.gov.estimate_votes()["detail"]
	return _detail_cache

func _enter_intro() -> void:
	phase = "intro"
	var est := m.gov.estimate_votes()
	_announced = {"yes": int(est["yes"]), "no": int(est["no"]), "abstain": int(est["abstain"])}
	_detail_cache = est["detail"]
	var s := ""
	for id in _order:
		s += m.ivote.stance_char(str(_detail_cache.get(str(id), "abstain"))).repeat(m.seats_of(str(id)))
	_intro_votes = s
	hemi.orders = s
	hemi.revealed = 0
	title_label.text = "%s vota la investidura de %s" % ["Primera votación:" if _round == 1 else "Segunda votación:", m.party_short(_cand)]
	sub_label.text = "%s · %s" % [_date, "Hace falta mayoría absoluta: %d votos a favor" % Rules.MAJORITY if _round == 1 else "Basta mayoría simple: más votos a favor que en contra"]
	_fill_groups(false)
	_fill_intro_feed(est)
	_refresh_score(_announced)
	hemi.set_center("%d" % int(_announced["yes"]), "apoyos anunciados")
	status_label.text = "Los grupos anuncian el sentido de su voto"
	status_label.add_theme_color_override("font_color", TV.WHITE)
	_build_actions()
	bar.queue_redraw()

func _fill_groups(voting: bool) -> void:
	for c in groups_box.get_children():
		c.queue_free()
	_rows.clear()
	for id in _order:
		var pid := str(id)
		var stance_name := _stance_of(pid)
		var ch := m.ivote.stance_char(stance_name)
		var box := UI.vbox(1)
		var h := UI.hbox(8)
		var sw := ColorRect.new()
		sw.color = m.party_color(pid)
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var nm := UI.label(m.party_short(pid), UI.FS_BODY, TV.WHITE, true)
		nm.custom_minimum_size = Vector2(86, 0)
		h.add_child(nm)
		var sl := UI.label(str(m.seats_of(pid)), UI.FS_SMALL, TV.MUTED)
		sl.custom_minimum_size = Vector2(28, 0)
		h.add_child(sl)
		var st := UI.label("", UI.FS_SMALL, TV.MUTED, true)
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(st)
		box.add_child(h)
		var stmt := UI.wrap_label(m.ivote.statement(pid, _cand, ch), UI.FS_TINY, TV.MUTED)
		box.add_child(stmt)
		groups_box.add_child(box)
		_rows[pid] = st
		_set_group_status(pid, 0)
	_update_groups()

func _set_group_status(pid: String, count_revealed: int) -> void:
	var st: Label = _rows[pid]
	var ch := m.ivote.stance_char(_stance_of(pid))
	if phase == "intro":
		var und := m.ivote.is_undecided(pid, _cand, ch)
		st.text = "Sin decidir" if und else VoteHemicycle_name(ch)
		st.add_theme_color_override("font_color", TV.MUTED if und else VoteHemicycle.vote_color(ch))
		return
	var range_a: Array = _starts[pid]
	var a := int(range_a[0])
	var b := mini(int(range_a[1]), count_revealed)
	if b <= a:
		st.text = "Espera su turno"
		st.add_theme_color_override("font_color", TV.FAINT)
		return
	var votes := str(session["votes"]).substr(a, b - a)
	var t := InvestitureVote.count(votes)
	var parts: Array = []
	if int(t["yes"]) > 0: parts.append("%d sí" % int(t["yes"]))
	if int(t["no"]) > 0: parts.append("%d no" % int(t["no"]))
	if int(t["abstain"]) > 0: parts.append("%d abst." % int(t["abstain"]))
	st.text = " · ".join(parts)
	st.add_theme_color_override("font_color", VoteHemicycle.vote_color(ch))

func VoteHemicycle_name(ch: String) -> String:
	return str(InvestitureVote.VOTE_NAMES.get(ch, "Abstención"))

func _update_groups() -> void:
	for id in _order:
		_set_group_status(str(id), revealed)

func _fill_intro_feed(est: Dictionary) -> void:
	for c in feed_box.get_children():
		c.queue_free()
	var out := m.ivote.outlook(est)
	var yes := int(est["yes"])
	var need := Rules.MAJORITY if _round == 1 else int(est["no"]) + 1
	var margin := yes - need
	var loss := float(out["expected_yes_loss"])
	var verdict := ""
	var col := TV.GOLD
	if margin >= int(out["safe_margin"]) + 2:
		verdict = "Margen holgado: aun con disidencias, la investidura saldría adelante."
		col = VoteHemicycle.C_YES
	elif margin >= 0:
		verdict = "Margen ajustado: unas pocas disidencias pueden hacerla fracasar."
		col = TV.GOLD
	else:
		verdict = "Faltan %d votos para el umbral%s. Solo prosperaría si hay deserciones favorables." % [-margin, "" if _round == 1 else " (hay más noes que síes)"]
		col = VoteHemicycle.C_NO
	feed_box.add_child(UI.wrap_label(verdict, UI.FS_BODY, col, true))
	feed_box.add_child(UI.wrap_label("Se esperan unas %.0f disidencias en toda la Cámara (%.0f entre los votos a favor)." % [float(out["expected_rebels"]), loss], UI.FS_SMALL, TV.MUTED))
	var groups: Array = (out["groups"] as Array).duplicate()
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["expected"]) > float(b["expected"]))
	feed_box.add_child(UI.label("GRUPOS MÁS INDISCIPLINADOS", UI.FS_TINY, TV.MUTED, true))
	var shown := 0
	for g in groups:
		var gd: Dictionary = g
		if shown >= 5 or float(gd["expected"]) < 0.3:
			break
		shown += 1
		var h := UI.hbox(8)
		var sw := ColorRect.new()
		sw.color = m.party_color(str(gd["id"]))
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var nm := UI.label(m.party_short(str(gd["id"])), UI.FS_SMALL, TV.WHITE, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.label("disciplina %.0f %%" % float(gd["discipline"]), UI.FS_SMALL, TV.MUTED))
		feed_box.add_child(h)
		var facs: Array = m.ivote.factors(str(gd["id"]), _cand, str(gd["stance"]))
		facs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
		if not facs.is_empty() and float((facs[0] as Dictionary)["value"]) > 0.01:
			feed_box.add_child(UI.wrap_label("Pesa más: " + str((facs[0] as Dictionary)["label"]).to_lower(), UI.FS_TINY, TV.FAINT))

func _begin_voting() -> void:
	if not replay:
		result = m.gov.hold_vote()
		session = result["session"]
	phase = "voting"
	revealed = 0
	_feed_i = 0
	_acc = 0.0
	_last_int = -1
	_detail_cache = {}
	_announced_detail()
	hemi.votes = str(session["votes"])
	hemi.orders = str(session["orders"])
	hemi.revealed = 0
	title_label.text = "%s · %s" % ["Primera votación" if _round == 1 else "Segunda votación", m.party_short(_cand)]
	sub_label.text = "%s · pase de lista de los 350 diputados" % _date
	for c in feed_box.get_children():
		c.queue_free()
	feed_box.add_child(UI.wrap_label("Aquí aparecerán los diputados que rompan la disciplina de su grupo.", UI.FS_SMALL, TV.MUTED))
	_fill_groups(true)
	_build_actions()
	_refresh_all()

func _process(delta: float) -> void:
	if phase != "voting" or not playing:
		return
	_acc += delta * SEATS_PER_SEC * float(SPEEDS[speed_i])
	var target := mini(350, int(_acc))
	if target != revealed:
		revealed = target
		_refresh_all()
	if revealed >= 350:
		_finish_voting()

func _refresh_all() -> void:
	hemi.revealed = revealed
	var t := InvestitureVote.count(str(session["votes"]), revealed)
	_refresh_score(t)
	hemi.set_center("%d" % int(t["yes"]), "a favor")
	_update_groups()
	_update_feed()
	_update_status()
	bar.queue_redraw()

func _refresh_score(t: Dictionary) -> void:
	for k in ["yes", "no", "abstain"]:
		(score[k] as Label).text = str(int(t[k]))
	bar.queue_redraw()

func _update_status() -> void:
	var cur := ""
	for id in _order:
		var a: Array = _starts[str(id)]
		if revealed > int(a[0]) and revealed <= int(a[1]):
			cur = str(id)
			break
	if revealed >= 350:
		status_label.text = "Votación cerrada"
	elif cur != "":
		status_label.text = "Votan los diputados de %s…" % m.party_short(cur)
	else:
		status_label.text = "Comienza el pase de lista"

func _update_feed() -> void:
	var rebels: Array = session["rebels"]
	while _feed_i < rebels.size() and int((rebels[_feed_i] as Dictionary)["seat"]) < revealed:
		if _feed_i == 0:
			for c in feed_box.get_children():
				c.queue_free()
		_add_rebel_row(rebels[_feed_i] as Dictionary)
		_feed_i += 1

func _add_rebel_row(r: Dictionary) -> void:
	var pc := PanelContainer.new()
	var to := str(r["to"])
	var colr := VoteHemicycle.vote_color(to)
	pc.add_theme_stylebox_override("panel", UI.box(Color(colr, 0.09), Color(colr, 0.5), 8, 1, 10, 7))
	var v := UI.vbox(1)
	pc.add_child(v)
	var h := UI.hbox(6)
	var sw := ColorRect.new()
	sw.color = m.party_color(str(r["party"]))
	sw.custom_minimum_size = Vector2(8, 8)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var nl := UI.label(str(r["name"]), UI.FS_SMALL, TV.WHITE, true)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	h.add_child(nl)
	v.add_child(h)
	var verb: String = {"y": "vota a favor", "n": "vota en contra", "a": "se abstiene"}[to]
	var where := m.party_short(str(r["party"])) + ((" · " + str(r["province"])) if str(r["province"]) != "" else "")
	v.add_child(UI.wrap_label("%s: %s rompiendo la disciplina de su grupo (%s)." % [where, verb, m.ivote.reason_text(str(r["reason"]))], UI.FS_TINY, TV.MUTED))
	feed_box.add_child(pc)

func _finish_voting() -> void:
	phase = "result"
	revealed = 350
	_refresh_all()
	var passed := bool(session["passed"]) if not replay else bool(session.get("passed", false))
	var rebels: Array = session["rebels"]
	if rebels.is_empty() and _feed_i == 0:
		for c in feed_box.get_children():
			c.queue_free()
		feed_box.add_child(UI.wrap_label("Todos los grupos han votado en bloque: ninguna disidencia.", UI.FS_SMALL, TV.MUTED))
	_show_banner(passed)
	_build_actions()
	if not _gavel_done:
		_gavel_done = true
		Sfx.play("gavel")
		get_tree().create_timer(0.35).timeout.connect(func() -> void: Sfx.play("fanfare" if passed else "deny"))

func _show_banner(passed: bool) -> void:
	for c in banner_holder.get_children():
		c.queue_free()
	var t: Dictionary = session["tally"]
	var colr := VoteHemicycle.C_YES if passed else VoteHemicycle.C_NO
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(colr, 0.14), Color(colr, 0.8), 12, 2, 18, 12))
	var v := UI.vbox(4)
	pc.add_child(v)
	var dissolved := bool(result.get("dissolved", false))
	var head := "INVESTIDURA APROBADA" if passed else ("DISOLUCIÓN DE LAS CORTES" if dissolved else "INVESTIDURA FALLIDA")
	v.add_child(UI.label(head, 26, TV.WHITE, true))
	var rule := "Mayoría absoluta (%d): %d a favor." % [Rules.MAJORITY, int(t["yes"])] if _round == 1 else "Mayoría simple: %d a favor frente a %d en contra." % [int(t["yes"]), int(t["no"])]
	v.add_child(UI.label("%d a favor · %d en contra · %d abstenciones. %s" % [int(t["yes"]), int(t["no"]), int(t["abstain"]), rule], UI.FS_BODY, TV.WHITE))
	var rebels: Array = session["rebels"]
	if not rebels.is_empty():
		var changed := 0
		for r in rebels:
			if str((r as Dictionary)["from"]) == "y" or str((r as Dictionary)["to"]) == "y":
				changed += 1
		v.add_child(UI.wrap_label("%d diputados rompieron la disciplina de su grupo; %d de ellos movieron el voto a favor." % [rebels.size(), changed], UI.FS_SMALL, TV.MUTED))
	v.add_child(UI.wrap_label(_consequences(passed, dissolved), UI.FS_BODY, TV.WHITE))
	banner_holder.add_child(pc)

func _consequences(passed: bool, dissolved: bool) -> String:
	if replay:
		return "Repetición de la votación celebrada el %s." % _date
	if passed:
		var n := m.gov.government_parties().size() - 1
		return "%s es investido presidente. Toca diseñar el Consejo de Ministros%s; los pactos cerrados pasan a ser compromisos de tu acuerdo." % [m.party_short(_cand), " con %d socios de Gobierno" % n if n > 0 else ""]
	if dissolved:
		return "Se agotan los intentos de investidura: el Rey disuelve las Cortes y se convocan nuevas elecciones."
	if _round == 1:
		return "Se abre la segunda votación el %s: bastará con más votos a favor que en contra. Hay dos días para renegociar apoyos." % m.date_label()
	return "Fracasa el intento %d de %d. El Rey propone ahora a %s (%d escaños). Si también fracasa, hay elecciones." % [m.gov.attempts(), Rules.MAX_INVESTITURE_ATTEMPTS, m.party_name(m.gov.candidate_id()), m.seats_of(m.gov.candidate_id())]

# ---------------------------------------------------------------- barra y botones
func _draw_bar() -> void:
	var w := bar.size.x
	var h := bar.size.y
	var y := 8.0
	var bh := 16.0
	TV.rrect(bar, Rect2(0, y, w, bh), Color(TV.PANEL_HI, 0.9), 8.0)
	var t: Dictionary
	if phase == "intro":
		t = _announced
	else:
		t = InvestitureVote.count(str(session.get("votes", "")), revealed)
	var x := 0.0
	for pair in [["yes", VoteHemicycle.C_YES], ["abstain", VoteHemicycle.C_ABS], ["no", VoteHemicycle.C_NO]]:
		var seg := float(int(t.get(str(pair[0]), 0))) / 350.0 * w
		if seg > 0.0:
			bar.draw_rect(Rect2(x, y, seg, bh), pair[1])
		x += seg
	if _round == 1:
		var mx := float(Rules.MAJORITY) / 350.0 * w
		bar.draw_line(Vector2(mx, y - 6), Vector2(mx, y + bh + 6), TV.WHITE, 2.0)
		TV.text_tl(bar, "mayoría absoluta · %d" % Rules.MAJORITY, Vector2(mx + 6, y + bh + 2), 11, TV.MUTED, true)
	else:
		TV.text_tl(bar, "gana quien tenga más votos a favor que en contra", Vector2(0, y + bh + 2), 11, TV.MUTED, true)

func _build_actions() -> void:
	for c in actions.get_children():
		c.queue_free()
	if phase == "intro":
		var back := NightButton.new("text", "Volver a negociar", 210)
		back.pressed.connect(_on_close)
		actions.add_child(back)
		actions.add_child(UI.fill())
		actions.add_child(UI.label("La votación es definitiva: no se puede deshacer.", UI.FS_SMALL, TV.MUTED))
		var go := NightButton.new("text", "Comenzar la votación", 260)
		go.active = true
		go.accent = VoteHemicycle.C_YES
		go.pressed.connect(_begin_voting)
		actions.add_child(go)
	elif phase == "voting":
		var pp := NightButton.new("pause" if playing else "play", "", 48)
		pp.pressed.connect(func() -> void:
			playing = not playing
			_build_actions())
		actions.add_child(pp)
		for i in range(SPEEDS.size()):
			var sb := NightButton.new("text", "x%d" % int(SPEEDS[i]), 52)
			sb.active = i == speed_i
			var idx := i
			sb.pressed.connect(func() -> void:
				speed_i = idx
				_build_actions())
			actions.add_child(sb)
		actions.add_child(UI.fill())
		var sk := NightButton.new("text", "Saltar al resultado", 220)
		sk.pressed.connect(func() -> void:
			_acc = 350.0
			revealed = 350
			_refresh_all()
			_finish_voting())
		actions.add_child(sk)
	else:
		actions.add_child(UI.fill())
		var done := NightButton.new("text", "Cerrar" if replay else "Continuar", 240)
		done.active = true
		done.pressed.connect(_on_continue)
		actions.add_child(done)

func _on_close() -> void:
	if phase == "intro" or replay:
		closed.emit()
		queue_free()
	else:
		if phase == "voting":
			revealed = 350
			_finish_voting()
		_on_continue()

func _on_continue() -> void:
	if replay:
		closed.emit()
	else:
		finished.emit(result)
	queue_free()
