class_name MediaStudio
extends Control
## Plató de medios a pantalla completa (como la noche electoral): debates, entrevistas de tele y radio, pódcast,
## ruedas de prensa y sesiones de control. Las preguntas van saliendo una a una y es un minijuego:
## cuenta atrás, medidor de audiencia, racha de aciertos, asesor comodín, réplicas del rival y reacciones en redes.
## La lógica de preguntas, respuestas y efectos vive en Encounters (y el banco de textos en MediaDB).

signal finished(result: Dictionary)

const BG_TOP := Color("#10203A")
const BG_BOT := Color("#04070D")

var m: GameModel
var ev: Dictionary = {}
var session: Dictionary = {}
var fmt := "tv"
var fdef: Dictionary = {}
var questions: Array = []
var n_main := 0
var q_index := 0
var main_done := 0
var cur_q: Dictionary = {}
var phase := "intro"
var t_left := 0.0
var t_total := 1.0
var audience := 50.0
var streak := 0
var best_streak := 0
var advisor_left := 1
var appr0 := 0.0

var stage: _Stage
var top_label: Label
var live_chip: PanelContainer
var counter_label: Label
var host_portrait: LeaderPortrait
var player_portrait: LeaderPortrait
var host_name_label: Label
var player_name_label: Label
var zone: Control
var q_panel: PanelContainer
var q_who: Label
var q_text: Label
var q_banner: Label
var timer_bar: _Timer
var answer_box: Control
var react_box: Control
var aud: _Aud
var streak_label: Label
var advisor_btn: Button
var feed: VBoxContainer
var overlay: Control
var _answer_buttons: Array = []
var _best_idx := -1
var _idle_t := 4.0
var _react_t := 0.0
var _typed := 1.0
var _clock_t := 0.0
var _live_t := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
var _confirm := false
var abandon_btn: Button

static func open(host: Control, model: GameModel, event: Dictionary) -> MediaStudio:
	var s := MediaStudio.new()
	s.m = model
	s.ev = event
	host.add_child(s)
	host.move_child(s, host.get_child_count() - 1)
	return s

# ---------------------------------------------------------------- construcción
func _ready() -> void:
	name = "MediaStudio"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	session = m.enc.build_session(ev)
	fmt = str(session["format"])
	fdef = MediaDB.FORMATS[fmt]
	questions = session["questions"]
	n_main = questions.size()
	appr0 = m.gov.approval() if m.phase == "legislature" else 0.0
	_build()
	_intro()
	call_deferred("_place_portraits")

func _outlet_name() -> String:
	return str((session["outlet"] as Dictionary)["name"])

func _host_character(host: Dictionary) -> Dictionary:
	var ch := Leader.generate("periodista", hash(str(host.get("name", "x"))))
	var g := "f" if bool(host.get("fem", false)) else "m"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(host.get("name", "x"))) + 7
	ch["gender"] = g
	ch["appearance"] = Leader.randomize_appearance(rng, g)
	return ch

func _build() -> void:
	stage = _Stage.new()
	stage.fmt = fmt
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.setup_data(m, session)
	add_child(stage)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 28
	root.offset_right = -28
	root.offset_top = 18
	root.offset_bottom = -22
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Barra superior
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	bar.custom_minimum_size = Vector2(0, 46)
	root.add_child(bar)
	live_chip = PanelContainer.new()
	live_chip.add_theme_stylebox_override("panel", UI.box(TV.RED, Color(0, 0, 0, 0), 4, 0, 12, 6))
	var lv := UI.label("● EN DIRECTO" if fmt != "podcast" else "● GRABANDO", UI.FS_BODY, Color.WHITE, true)
	live_chip.add_child(lv)
	live_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(live_chip)
	top_label = UI.label("%s  ·  %s" % [_outlet_name().to_upper(), str(fdef["label"]).to_upper()], UI.FS_LEAD, TV.WHITE, true)
	top_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(top_label)
	bar.add_child(UI.fill())
	counter_label = UI.label("", UI.FS_LEAD, TV.GOLD, true)
	counter_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(counter_label)
	var hint := UI.label("Esc · pausa", UI.FS_SMALL, TV.FAINT)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(hint)
	abandon_btn = UI.button("Abandonar", "danger", _ask_abandon, 130)
	abandon_btn.tooltip_text = "Te levantas y te marchas. Los medios lo llamarán plantón y tu imagen se resentirá."
	abandon_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(abandon_btn)

	# Zona central: plató + panel derecho
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 16)
	root.add_child(mid)
	zone = Control.new()
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.resized.connect(_place_portraits)
	mid.add_child(zone)
	_build_portraits()
	mid.add_child(_build_side())

	# Rótulo de la pregunta
	q_panel = PanelContainer.new()
	q_panel.add_theme_stylebox_override("panel", UI.box(Color(TV.PANEL, 0.96), TV.TEAL, 10, 2, 22, 12))
	q_panel.custom_minimum_size = Vector2(0, 118)
	root.add_child(q_panel)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 4)
	q_panel.add_child(qv)
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 10)
	qv.add_child(qh)
	q_who = UI.label("", UI.FS_SMALL, TV.TEAL, true)
	qh.add_child(q_who)
	q_banner = UI.label("", UI.FS_SMALL, TV.RED, true)
	qh.add_child(q_banner)
	q_text = Label.new()
	q_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_text.add_theme_font_size_override("font_size", 25)
	q_text.add_theme_color_override("font_color", TV.WHITE)
	q_text.add_theme_font_override("font", TV.bold())
	q_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qv.add_child(q_text)

	timer_bar = _Timer.new()
	timer_bar.custom_minimum_size = Vector2(0, 12)
	root.add_child(timer_bar)

	# Zona de respuestas / reacción (misma altura)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 176)
	root.add_child(holder)
	answer_box = HBoxContainer.new()
	answer_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	answer_box.add_theme_constant_override("separation", 12)
	holder.add_child(answer_box)
	react_box = PanelContainer.new()
	react_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	react_box.add_theme_stylebox_override("panel", UI.box(Color(TV.PANEL, 0.97), TV.LINE, 10, 1, 24, 16))
	react_box.visible = false
	holder.add_child(react_box)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func _build_portraits() -> void:
	var host: Dictionary = session["host"]
	var hc := m.leader_of(str(host["party"])) if host.has("party") else _host_character(host)
	var hcol := Color(str(m.party_by_id(str(host["party"])).get("color", "#888"))) if host.has("party") else TV.MUTED
	host_portrait = LeaderPortrait.new()
	host_portrait.custom_minimum_size = Vector2(230, 230)
	host_portrait.setup(hc, hcol, "neutral")
	zone.add_child(host_portrait)
	player_portrait = LeaderPortrait.new()
	player_portrait.custom_minimum_size = Vector2(230, 230)
	player_portrait.setup(m.character(), Color(str(m.party.get("color", "#2563EB"))), "neutral", "player")
	zone.add_child(player_portrait)
	host_name_label = UI.label(str(host["name"]), UI.FS_BODY, TV.WHITE, true)
	zone.add_child(host_name_label)
	player_name_label = UI.label("%s · %s" % [m.leader_name(m.pid()), str(m.party.get("short_name", ""))], UI.FS_BODY, TV.WHITE, true)
	zone.add_child(player_name_label)
	if fmt == "podcast" or fmt == "radio":
		pass

func _place_portraits() -> void:
	if host_portrait == null:
		return
	var w := zone.size.x
	var h := zone.size.y
	var ps := clampf(h * 0.62, 150.0, 260.0)
	host_portrait.custom_minimum_size = Vector2(ps, ps)
	host_portrait.size = Vector2(ps, ps)
	player_portrait.custom_minimum_size = Vector2(ps, ps)
	player_portrait.size = Vector2(ps, ps)
	var y := h * 0.5 - ps * 0.5 - 6.0
	if fmt == "press":
		host_portrait.position = Vector2(w * 0.20 - ps * 0.5, y - 16.0)
		player_portrait.position = Vector2(w * 0.68 - ps * 0.5, y)
	else:
		host_portrait.position = Vector2(w * 0.26 - ps * 0.5, y)
		player_portrait.position = Vector2(w * 0.74 - ps * 0.5, y)
	host_name_label.position = Vector2(host_portrait.position.x + ps * 0.5 - host_name_label.size.x * 0.5, host_portrait.position.y + ps + 4.0)
	player_name_label.position = Vector2(player_portrait.position.x + ps * 0.5 - player_name_label.size.x * 0.5, player_portrait.position.y + ps + 4.0)
	stage.zone_rect = Rect2(zone.global_position - global_position, zone.size)

func _build_side() -> Control:
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(390, 0)
	side.add_theme_stylebox_override("panel", UI.box(Color(TV.PANEL, 0.93), TV.LINE, 10, 1, 16, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	side.add_child(v)
	v.add_child(UI.label("AUDIENCIA EN DIRECTO", UI.FS_SMALL, TV.MUTED, true))
	aud = _Aud.new()
	aud.custom_minimum_size = Vector2(0, 46)
	v.add_child(aud)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	v.add_child(rrow)
	streak_label = UI.label("Racha ×1", UI.FS_LEAD, TV.GOLD, true)
	streak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(streak_label)
	advisor_btn = UI.button("Asesor · 1", "secondary", _ask_advisor, 130)
	advisor_btn.tooltip_text = "Una vez por sesión: tu asesor señala la mejor respuesta."
	rrow.add_child(advisor_btn)
	v.add_child(UI.hsep(TV.LINE))
	v.add_child(UI.label("REDES SOCIALES", UI.FS_SMALL, TV.MUTED, true))
	feed = VBoxContainer.new()
	feed.add_theme_constant_override("separation", 7)
	feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed.clip_contents = true
	v.add_child(feed)
	return side

# ---------------------------------------------------------------- flujo
func _intro() -> void:
	phase = "intro"
	q_panel.visible = true
	timer_bar.visible = false
	answer_box.visible = false
	var lines := MediaDB.intros(fmt)
	var rname := m.party_short(str(session.get("rival", ""))) if session.get("rival", "") != "" else "su rival"
	var line := MediaDB.fill(m.enc.pick_h("intro:" + fmt, lines), {"outlet": _outlet_name(), "leader": m.leader_name(m.pid()), "rivalname": rname})
	q_who.text = str((session["host"] as Dictionary)["name"]).to_upper()
	q_banner.text = ""
	_type_text(line)
	_update_counter()
	_react_t = 3.6
	Sfx.play("reveal")

func _update_counter() -> void:
	counter_label.text = "PREGUNTA %d / %d" % [mini(main_done + 1, n_main), n_main] if phase != "end" else "FIN"

func _type_text(t: String) -> void:
	q_text.text = t
	q_text.visible_ratio = 0.0
	_typed = 0.0

func _next_question() -> void:
	if q_index >= questions.size():
		_end()
		return
	cur_q = questions[q_index]
	phase = "question"
	react_box.visible = false
	answer_box.visible = true
	timer_bar.visible = true
	var is_rep := str(cur_q["kind"]) == "replica"
	var host: Dictionary = session["host"]
	var who := str(host["name"])
	if fmt == "press" and cur_q.has("asker"):
		var ak: Dictionary = cur_q["asker"]
		who = "%s · %s" % [str(ak["name"]), str(ak["outlet"])]
		stage.asker = q_index % 5
		host_portrait.setup(_host_character(ak), TV.MUTED, "neutral")
		host_name_label.text = str(ak["name"])
	q_who.text = who.to_upper()
	q_banner.text = "  ¡INTERRUPCIÓN!  RESPONDE RÁPIDO" if is_rep else ("  " + _mood_text(str(cur_q["mood"])))
	q_banner.add_theme_color_override("font_color", TV.RED if (is_rep or str(cur_q["mood"]) == "hostile") else (TV.UP if str(cur_q["mood"]) == "friendly" else TV.MUTED))
	host_portrait.set_mood("angry" if (str(cur_q["mood"]) == "hostile" or is_rep) else ("happy" if str(cur_q["mood"]) == "friendly" else "neutral"))
	player_portrait.set_mood("neutral")
	_type_text(str(cur_q["text"]))
	_update_counter()
	call_deferred("_place_portraits")
	t_total = 10.0 if is_rep else float(fdef["secs"])
	t_left = t_total
	_build_answers()
	_best_idx = -1
	for b in _answer_buttons:
		(b as Control).modulate.a = 0.0
	Sfx.play("notify", 0.7)

func _mood_text(mood: String) -> String:
	match mood:
		"hostile": return "· TONO HOSTIL"
		"friendly": return "· TONO AMABLE"
	return "· TONO NEUTRO"

func _build_answers() -> void:
	for c in answer_box.get_children():
		answer_box.remove_child(c)
		c.queue_free()
	_answer_buttons.clear()
	var answers: Array = cur_q["answers"]
	for i in range(answers.size()):
		var a: Dictionary = answers[i]
		var b := _answer_card(a, i)
		answer_box.add_child(b)
		_answer_buttons.append(b)

func _answer_card(a: Dictionary, idx: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", UI.box(Color(TV.PANEL_HI, 0.96), TV.LINE, 10, 1, 14, 10))
	b.add_theme_stylebox_override("hover", UI.box(TV.PANEL_HI.lightened(0.1), TV.TEAL, 10, 2, 14, 10))
	b.add_theme_stylebox_override("pressed", UI.box(TV.PANEL_HI.lightened(0.18), TV.GOLD, 10, 2, 14, 10))
	b.pressed.connect(_answer.bind(a, false))
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14
	inner.offset_right = -14
	inner.offset_top = 10
	inner.offset_bottom = -10
	inner.add_theme_constant_override("separation", 5)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := UI.label(str(idx + 1), UI.FS_LEAD, TV.GOLD, true)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(key)
	var tag := UI.label(str(a["tag"]).to_upper(), UI.FS_SMALL, TV.TEAL, true)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)
	var st := UI.label("· %s %d" % [str(a["stat_name"]), Leader.stat(m.character(), str(a["stat"]))], UI.FS_TINY, TV.FAINT)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(st)
	inner.add_child(head)
	var t := Label.new()
	t.text = str(a["text"])
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", TV.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(t)
	b.add_child(inner)
	return b

func _answer(a: Dictionary, timeout: bool) -> void:
	if phase != "question":
		return
	phase = "reaction"
	var ans := a.duplicate()
	if timeout:
		ans = {"arch": "deflect", "text": "(Te quedas en blanco ante la pregunta…)", "tag": "Sin respuesta", "stat": "experiencia", "stat_name": "—", "target": "", "timeout": true}
	var r := m.enc.resolve(session, cur_q, ans)
	var grade := str(r["grade"])
	var good := grade == "great" or grade == "good"
	if good:
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
	var delta := {"great": 14.0, "good": 6.0, "weak": -7.0, "bad": -15.0}[grade] as float
	if good and streak >= 2:
		delta += 2.0 * float(mini(streak - 1, 3))
	audience = clampf(audience + delta, 0.0, 100.0)
	aud.target = audience
	streak_label.text = "Racha ×%d%s" % [maxi(streak, 1), "  🔥" if streak >= 3 else ""] if streak > 0 else "Racha ×1"
	_flash = 1.0
	_flash_col = TV.UP if good else TV.DOWN
	stage.flash(_flash_col)
	Sfx.play("confirm" if good else "deny", 0.8)
	player_portrait.set_mood(str(r["mood"]))
	host_portrait.set_mood("happy" if grade == "great" else ("smug" if grade == "good" else ("angry" if grade == "bad" else "worried")))
	main_done += 0 if str(cur_q["kind"]) == "replica" else 1
	_show_reaction(r, ans, timeout)
	_post_social(grade)
	if not good:
		_post_social(grade)

func _show_reaction(r: Dictionary, ans: Dictionary, timeout: bool) -> void:
	answer_box.visible = false
	timer_bar.visible = false
	for c in react_box.get_children():
		react_box.remove_child(c)
		c.queue_free()
	react_box.visible = true
	var grade := str(r["grade"])
	var col := TV.UP if grade in ["great", "good"] else (TV.GOLD if grade == "weak" else TV.DOWN)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	react_box.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 4)
	h.add_child(left)
	var stamp := UI.label(str(r["grade_name"]).to_upper(), UI.FS_H2, col, true)
	left.add_child(stamp)
	var sub := UI.label("«%s»" % str(ans["tag"]) if not timeout else "Se acabó el tiempo", UI.FS_BODY, TV.MUTED)
	left.add_child(sub)
	if streak >= 2:
		left.add_child(UI.label("Racha de %d buenas respuestas" % streak, UI.FS_SMALL, TV.GOLD, true))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	h.add_child(mid)
	var host: Dictionary = session["host"]
	mid.add_child(UI.label("%s:" % str(host["name"]), UI.FS_SMALL, TV.MUTED, true))
	var rt := Label.new()
	rt.text = "«%s»" % str(r["react"])
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.add_theme_font_size_override("font_size", 22)
	rt.add_theme_color_override("font_color", TV.WHITE)
	mid.add_child(rt)
	if bool(r.get("incoherent", false)):
		var w := UI.label("Esa respuesta chocaba con las ideas de tu partido y alguien lo ha notado.", UI.FS_SMALL, TV.GOLD)
		mid.add_child(w)
	var chips := _chip_flow(r["chips"])
	mid.add_child(chips)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.custom_minimum_size = Vector2(200, 0)
	h.add_child(right)
	var last := (q_index + 1 >= questions.size()) and (main_done >= n_main or q_index + 1 >= questions.size())
	var nb := UI.button("Ver el balance  ▶" if last else "Siguiente  ▶", "primary", _advance, 190)
	right.add_child(nb)
	right.add_child(UI.label("Espacio para seguir", UI.FS_TINY, TV.FAINT))
	_react_t = 9.0

func _chip_flow(chips: Array) -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for c in chips:
		var cd: Dictionary = c
		var d := float(cd["delta"])
		var unit := " pts" if str(cd.get("unit", "")) == "pts" else ""
		var chip := PanelContainer.new()
		var col := TV.UP if d >= 0.0 else TV.DOWN
		chip.add_theme_stylebox_override("panel", UI.box(Color(col, 0.18), col, 12, 1, 10, 3))
		chip.add_child(UI.label("%s %s%s" % [str(cd["label"]), UI.signed(d, 2 if unit != "" else 1), unit], UI.FS_SMALL, col.lightened(0.35), true))
		fl.add_child(chip)
	return fl

func _advance() -> void:
	if phase == "intro":
		q_index = 0
		_next_question()
		return
	if phase != "reaction":
		return
	var was_replica := str(cur_q["kind"]) == "replica"
	# Réplica del rival tras una respuesta (debates y ruedas de prensa).
	if not was_replica and (fmt == "debate" or fmt == "press") and main_done < n_main and m.rng.randf() < (0.4 if fmt == "debate" else 0.25):
		questions.insert(q_index + 1, m.enc.replica_for(session))
	q_index += 1
	if main_done >= n_main or q_index >= questions.size():
		_end()
	else:
		_next_question()

func _post_social(grade: String) -> void:
	var tone := grade
	var pool := MediaDB.social(tone)
	if pool.is_empty():
		return
	var raw := m.enc.pick_h("social:" + tone, pool)
	var issue := Rules.issue_name(str(cur_q.get("issue", ""))).to_lower() if str(cur_q.get("issue", "")) != "" else "esto"
	var tag := str(m.party.get("short_name", "pais")).replace(" ", "")
	var handle := m.enc.pick_h("handle", MediaDB.handles())
	_add_post(MediaDB.fill(raw, {"a": handle, "issue": issue, "tag": tag}), tone)

func _add_post(text: String, tone: String) -> void:
	var col := TV.UP if tone in ["great", "good"] else (TV.DOWN if tone in ["bad", "weak"] else TV.MUTED)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(col, 0.10), Color(col, 0.35), 8, 1, 10, 6))
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", TV.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	p.modulate.a = 0.0
	feed.add_child(p)
	feed.move_child(p, 0)
	while feed.get_child_count() > 4:
		var old := feed.get_child(feed.get_child_count() - 1)
		feed.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.35)

func _ask_advisor() -> void:
	if phase != "question" or advisor_left <= 0:
		return
	advisor_left -= 1
	advisor_btn.text = "Asesor · 0"
	advisor_btn.disabled = true
	var answers: Array = cur_q["answers"]
	var best := -1
	var best_v := -99.0
	for i in range(answers.size()):
		var v := m.enc.expected_quality(session, cur_q, answers[i] as Dictionary)
		if v > best_v:
			best_v = v
			best = i
	_best_idx = best
	if best >= 0 and best < _answer_buttons.size():
		var b: Button = _answer_buttons[best]
		b.add_theme_stylebox_override("normal", UI.box(Color(TV.PANEL_HI, 0.96), TV.GOLD, 10, 3, 14, 10))
		_add_post("Tu asesor te susurra: «La opción %d es la que mejor encaja con lo que se espera de ti.»" % (best + 1), "good")
	Sfx.play("reveal")

# ---------------------------------------------------------------- bucle
func _process(delta: float) -> void:
	_live_t += delta
	live_chip.modulate.a = 0.75 + 0.25 * sin(_live_t * 4.0)
	if _confirm:
		return
	_clock_t += delta
	if _typed < 1.0:
		_typed = minf(1.0, _typed + delta / maxf(0.5, minf(1.6, float(q_text.text.length()) * 0.012)))
		q_text.visible_ratio = _typed
	match phase:
		"intro":
			_react_t -= delta
			if _react_t <= 0.0 and _typed >= 1.0:
				_advance()
		"question":
			if _typed >= 1.0:
				for b in _answer_buttons:
					(b as Control).modulate.a = minf(1.0, (b as Control).modulate.a + delta * 4.0)
				t_left -= delta
				_idle_t -= delta
				if _idle_t <= 0.0:
					_idle_t = randf_range(6.0, 9.0)
					var raw := m.enc.pick_h("social:idle", MediaDB.social("idle"))
					var issue := Rules.issue_name(str(cur_q.get("issue", ""))).to_lower() if str(cur_q.get("issue", "")) != "" else "esto"
					_add_post(MediaDB.fill(raw, {"a": m.enc.pick_h("handle", MediaDB.handles()), "issue": issue}), "idle")
				if t_left <= 0.0:
					_answer({}, true)
			timer_bar.value = clampf(t_left / t_total, 0.0, 1.0)
			timer_bar.danger = t_left < 6.0
		"reaction":
			_react_t -= delta
			if _react_t <= 0.0:
				_advance()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.6)

func _input(event: InputEvent) -> void:
	if _confirm or not is_visible_in_tree() or not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	var k := ke.keycode
	if phase == "question" and k >= KEY_1 and k <= KEY_4:
		var idx := int(k) - int(KEY_1)
		var answers: Array = cur_q["answers"]
		if idx < answers.size() and _typed >= 1.0:
			_answer(answers[idx] as Dictionary, false)
			get_viewport().set_input_as_handled()
	elif (k == KEY_SPACE or k == KEY_ENTER) and phase in ["reaction", "intro"]:
		_advance()
		get_viewport().set_input_as_handled()
	elif k == KEY_A and phase == "question":
		_ask_advisor()

# ---------------------------------------------------------------- abandonar
func _remaining_main() -> int:
	return maxi(0, n_main - main_done)

func _ask_abandon() -> void:
	if _confirm or phase == "end":
		return
	_confirm = true
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	panel.add_theme_stylebox_override("panel", UI.box(TV.PANEL, TV.RED, 14, 2, 30, 24, true))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UI.label("¿ABANDONAR EL %s?" % str(fdef["label"]).to_upper(), UI.FS_H2, TV.RED, true))
	var left := _remaining_main()
	var pen := 2.5 + 1.2 * float(left)
	var body := "Te levantas y te marchas con %d pregunta%s sin responder. Los medios lo llamarán plantón: perderás unos %.0f puntos de confianza, y tu honradez, liderazgo y competencia se resentirán. Siempre es mejor que un desastre, pero nunca es gratis." % [left, "" if left == 1 else "s", pen]
	v.add_child(UI.wrap_label(body, UI.FS_BODY, TV.WHITE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	row.add_child(UI.button("Seguir en el plató", "secondary", _cancel_abandon, 190))
	row.add_child(UI.button("Abandonar y asumir el golpe", "danger", func() -> void: _end(true), 250))

func _cancel_abandon() -> void:
	_confirm = false
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---------------------------------------------------------------- final
func _end(abandoned: bool = false) -> void:
	_confirm = false
	for c in overlay.get_children():
		c.queue_free()
	if abandon_btn != null:
		abandon_btn.visible = false
	phase = "end"
	answer_box.visible = false
	react_box.visible = false
	timer_bar.visible = false
	q_panel.modulate.a = 0.0
	_update_counter()
	session["i"] = questions.size()
	var res := m.enc.abandon(session, ev, _remaining_main()) if abandoned else m.enc.finish(session, ev)
	# Premios de la sesión: racha, ovación o bronca del público.
	var notes: Array = []
	if abandoned:
		notes.append("Plantón: la confianza cae %.1f puntos y la imagen se resiente." % float(res.get("trust_penalty", 0.0)))
	elif best_streak >= 2:
		var b := float(mini(best_streak, 4))
		m.visibility = m.visibility + 0.6 * b
		m.trust = m.trust + 0.4 * b
		notes.append("Racha de %d buenas respuestas: +%.1f visibilidad, +%.1f confianza." % [best_streak, 0.6 * b, 0.4 * b])
	if abandoned:
		pass
	elif audience >= 70.0:
		m.campaign.adjust_poll(m.pid(), 0.04)
		m.momentum = m.momentum + 0.4
		notes.append("Ovación del público: el plató termina en pie.")
	elif audience <= 30.0:
		m.campaign.adjust_poll(m.pid(), -0.04)
		m.momentum = m.momentum - 0.4
		notes.append("Mala salida: el público te despide con frialdad.")
	res["audience"] = audience
	res["best_streak"] = best_streak
	res["notes"] = notes
	res["poll_delta"] = m.player_poll() - float(session["poll0"])
	if m.phase == "legislature":
		res["approval_delta"] = m.gov.approval() - appr0
	Sfx.play("fanfare", 0.8)
	_show_balance(res)

func _show_balance(res: Dictionary) -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	panel.add_theme_stylebox_override("panel", UI.box(TV.PANEL, TV.TEAL, 14, 2, 34, 26, true))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UI.label("BALANCE DEL %s" % str(fdef["label"]).to_upper(), UI.FS_H2, TV.TEAL, true))
	var hl: Dictionary = res.get("headline", {})
	var tone := str(hl.get("tone", "neutral"))
	var tcol := TV.UP if tone == "positive" else (TV.DOWN if tone == "warning" else TV.MUTED)
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", UI.box(TV.PANEL_HI, tcol, 10, 2, 20, 14))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	hv.add_child(UI.label("AL DÍA SIGUIENTE · %s" % str(hl.get("outlet", _outlet_name())).to_upper(), UI.FS_SMALL, TV.MUTED, true))
	var ht := Label.new()
	ht.text = "«%s»" % str(hl.get("text", res.get("summary", "")))
	ht.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ht.add_theme_font_size_override("font_size", 26)
	ht.add_theme_color_override("font_color", TV.WHITE)
	ht.add_theme_font_override("font", TV.bold())
	hv.add_child(ht)
	hp.add_child(hv)
	v.add_child(hp)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 40)
	v.add_child(stats)
	var pd := float(res.get("poll_delta", 0.0))
	stats.add_child(_stat("INTENCIÓN DE VOTO", "%.2f%% (%s)" % [m.player_poll(), UI.signed(pd, 2)], TV.UP if pd >= 0.0 else TV.DOWN))
	stats.add_child(_stat("AUDIENCIA FINAL", "%.0f / 100" % audience, TV.UP if audience >= 55.0 else (TV.DOWN if audience <= 40.0 else TV.WHITE)))
	stats.add_child(_stat("MEJOR RACHA", "×%d" % best_streak, TV.GOLD))
	if res.has("approval_delta"):
		var ad := float(res["approval_delta"])
		stats.add_child(_stat("APOYO AL GOBIERNO", "%.0f (%s)" % [m.gov.approval(), UI.signed(ad, 1)], TV.UP if ad >= 0.0 else TV.DOWN))
	else:
		stats.add_child(_stat("CONFIANZA · VISIBILIDAD", "%.0f · %.0f" % [m.trust, m.visibility], TV.WHITE))
	var tally: Dictionary = res.get("tally", {})
	var chips: Array = []
	for k in tally.keys():
		if absf(float(tally[k])) >= 0.4:
			chips.append({"label": str(Encounters.IMAGE_DIMS.get(k, k)), "delta": float(tally[k])})
	if not chips.is_empty():
		v.add_child(UI.label("CÓMO TE VEN AHORA", UI.FS_SMALL, TV.MUTED, true))
		v.add_child(_chip_flow(chips))
	var seg: Dictionary = res.get("seg_tally", {})
	var bk := ""
	var wk := ""
	var bv := 0.0
	var wv := 0.0
	for k2 in seg.keys():
		var sv := float(seg[k2])
		if sv > bv:
			bv = sv
			bk = str(k2)
		if sv < wv:
			wv = sv
			wk = str(k2)
	if bk != "" and bv >= 0.8:
		v.add_child(UI.label("Conecta mejor con: %s" % str(Encounters.SEGMENTS[bk]["name"]), UI.FS_BODY, TV.UP, true))
	if wk != "" and wv <= -0.8:
		v.add_child(UI.label("Pierde fuelle entre: %s" % str(Encounters.SEGMENTS[wk]["name"]), UI.FS_BODY, TV.DOWN, true))
	for n in res.get("notes", []):
		v.add_child(UI.label(str(n), UI.FS_BODY, TV.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var outro := m.enc.pick_h("outro:" + fmt, MediaDB.outros(fmt))
	if outro != "":
		var ol := UI.label(outro, UI.FS_SMALL, TV.FAINT)
		ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ol)
	row.add_child(UI.button("Salir del plató  ▶", "primary", func() -> void:
		finished.emit(res)
		queue_free(), 220))
	v.add_child(row)

func _stat(title: String, value: String, col: Color) -> VBoxContainer:
	var s := VBoxContainer.new()
	s.add_theme_constant_override("separation", 0)
	s.add_child(UI.label(title, UI.FS_TINY, TV.MUTED, true))
	s.add_child(UI.label(value, UI.FS_H2, col, true))
	return s

# ---------------------------------------------------------------- piezas de dibujo
class _Timer extends Control:
	var value := 1.0:
		set(v):
			value = v
			queue_redraw()
	var danger := false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TV.LINE)
		var col := TV.RED if danger else TV.TEAL
		draw_rect(Rect2(0, 0, size.x * clampf(value, 0.0, 1.0), size.y), col)
		draw_rect(Rect2(size.x * clampf(value, 0.0, 1.0) - 3.0, 0, 3.0, size.y), Color.WHITE)

class _Aud extends Control:
	var target := 50.0
	var shown := 50.0
	func _process(delta: float) -> void:
		shown = lerpf(shown, target, clampf(delta * 4.0, 0.0, 1.0))
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := 16.0
		var y := size.y * 0.5 - 6.0
		var n := 40
		for i in range(n):
			var t := float(i) / float(n - 1)
			var col := TV.DOWN.lerp(TV.GOLD, clampf(t * 2.0, 0.0, 1.0)) if t < 0.5 else TV.GOLD.lerp(TV.UP, clampf((t - 0.5) * 2.0, 0.0, 1.0))
			var on := t * 100.0 <= shown
			draw_rect(Rect2(float(i) * w / float(n), y, w / float(n) - 2.0, h), col if on else Color(col, 0.16))
		var nx := clampf(shown / 100.0, 0.0, 1.0) * w
		TV.tri_down(self, Vector2(nx, y - 5.0), 6.0, TV.WHITE)
		TV.text_tl(self, "%d" % int(round(shown)), Vector2(0, y + h + 4.0), 13, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, w)
		TV.text_tl(self, "BRONCA", Vector2(0, y + h + 4.0), 10, TV.FAINT)
		TV.text_tl(self, "OVACIÓN", Vector2(0, y + h + 4.0), 10, TV.FAINT, true, HORIZONTAL_ALIGNMENT_RIGHT, w)

## Decorado del plató según el formato. Todo se dibuja por código y se anima suavemente.
class _Stage extends Control:
	var fmt := "tv"
	var asker := 0
	var zone_rect := Rect2()
	var _t := 0.0
	var _flash_a := 0.0
	var _flash_c := Color.WHITE
	var _m: GameModel
	var _session: Dictionary = {}
	var _journalists: Array = []
	var _seats: Array = []

	func setup_data(model: GameModel, sess: Dictionary) -> void:
		_m = model
		_session = sess
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(sess.get("id", "x")))
		for i in range(5):
			_journalists.append({"col": Color.from_hsv(rng.randf(), 0.35, 0.55), "tag": ["RTV", "DIARIO", "RADIO", "AGENCIA", "DIGITAL", "CADENA", "CANAL"][rng.randi_range(0, 6)]})
		if fmt == "pleno":
			pass

	func flash(col: Color) -> void:
		_flash_a = 1.0
		_flash_c = col

	func _process(delta: float) -> void:
		_t += delta
		_flash_a = maxf(0.0, _flash_a - delta * 1.8)
		queue_redraw()

	func _grad(rect: Rect2, top: Color, bot: Color) -> void:
		draw_polygon(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y)]), PackedColorArray([top, top, bot, bot]))

	func _draw() -> void:
		var w := size.x
		var h := size.y
		_grad(Rect2(0, 0, w, h), Color("#0B1224"), Color("#03050A"))
		var z := zone_rect if zone_rect.size.x > 100.0 else Rect2(0, 0, w, h)
		draw_set_transform(z.position, 0.0, Vector2.ONE)
		var zw := z.size.x
		var zh := z.size.y
		match fmt:
			"radio": _draw_radio(zw, zh)
			"podcast": _draw_podcast(zw, zh)
			"press": _draw_press(zw, zh)
			"debate": _draw_debate(zw, zh)
			"control": _draw_pleno(zw, zh)
			_: _draw_tv(zw, zh)
		draw_rect(Rect2(0, 0, zw, zh), Color(TV.LINE), false, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _flash_a > 0.01:
			draw_rect(Rect2(0, 0, w, 6), Color(_flash_c, _flash_a * 0.9))
			draw_rect(Rect2(0, h - 6, w, 6), Color(_flash_c, _flash_a * 0.9))
			draw_rect(Rect2(0, 0, 6, h), Color(_flash_c, _flash_a * 0.9))
			draw_rect(Rect2(w - 6, 0, 6, h), Color(_flash_c, _flash_a * 0.9))

	func _spot(cx: float, top_y: float, bottom_y: float, half_w: float, col: Color) -> void:
		draw_polygon(PackedVector2Array([Vector2(cx - 14, top_y), Vector2(cx + 14, top_y), Vector2(cx + half_w, bottom_y), Vector2(cx - half_w, bottom_y)]),
			PackedColorArray([Color(col, 0.22), Color(col, 0.22), Color(col, 0.0), Color(col, 0.0)]))

	func _desk(y: float, w: float, col: Color) -> void:
		TV.rrect(self, Rect2(w * 0.08, y, w * 0.84, 78.0), col.darkened(0.25), 10.0)
		TV.rrect(self, Rect2(w * 0.08, y, w * 0.84, 12.0), col.lightened(0.15), 6.0)

	func _draw_tv(w: float, h: float) -> void:
		_grad(Rect2(0, 0, w, h), Color("#12305A"), Color("#050A14"))
		# Ciudad al fondo y paneles led
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var x := 0.0
		while x < w:
			var bw := rng.randf_range(38.0, 90.0)
			var bh := rng.randf_range(h * 0.16, h * 0.42)
			draw_rect(Rect2(x, h * 0.62 - bh, bw, bh), Color("#0A1830"))
			for k in range(int(bh / 22.0)):
				if rng.randf() < 0.35:
					draw_rect(Rect2(x + 6.0 + float(k % 3) * 14.0, h * 0.62 - bh + 8.0 + float(k) * 20.0, 6.0, 8.0), Color(TV.GOLD, 0.35))
			x += bw + 4.0
		for i in range(6):
			var pulse := 0.5 + 0.5 * sin(_t * 1.5 + float(i))
			draw_rect(Rect2(w * 0.08 + float(i) * w * 0.15, 20.0, w * 0.12, 6.0), Color(TV.TEAL, 0.25 + 0.35 * pulse))
		_spot(w * 0.26, 0.0, h * 0.8, 150.0, Color("#CFE6FF"))
		_spot(w * 0.74, 0.0, h * 0.8, 150.0, Color("#CFE6FF"))
		_desk(h * 0.74, w, Color("#1C3A66"))
		TV.text_tl(self, "PLATÓ", Vector2(w * 0.5 - 40.0, h * 0.74 + 24.0), 22, Color(TV.WHITE, 0.4), true, HORIZONTAL_ALIGNMENT_CENTER, 80.0)

	func _draw_radio(w: float, h: float) -> void:
		_grad(Rect2(0, 0, w, h), Color("#0C2A2E"), Color("#03090B"))
		for r in range(6):
			for c in range(14):
				var a := 0.10 + 0.06 * float((r + c) % 2)
				draw_rect(Rect2(20.0 + float(c) * (w - 40.0) / 14.0, 80.0 + float(r) * 58.0, (w - 40.0) / 14.0 - 6.0, 52.0), Color("#1D4B52", a * 3.0))
		# Cartel AL AIRE
		var on := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 3.0))
		TV.rrect(self, Rect2(w * 0.5 - 110.0, 24.0, 220.0, 54.0), Color(TV.RED, on), 8.0)
		TV.text_tl(self, "AL AIRE", Vector2(w * 0.5 - 110.0, 34.0), 30, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		# Vúmetro
		for i in range(18):
			var lvl := 0.3 + 0.7 * absf(sin(_t * 2.3 + float(i) * 0.7))
			draw_rect(Rect2(40.0 + float(i) * 14.0, h - 58.0 - 50.0 * lvl, 9.0, 50.0 * lvl), TV.TEAL if lvl < 0.85 else TV.GOLD)
		_desk(h * 0.74, w, Color("#1B4850"))
		for sx in [0.38, 0.62]:
			draw_line(Vector2(w * sx, h * 0.74), Vector2(w * sx + 16.0, h * 0.55), Color("#3A4A55"), 6.0)
			draw_circle(Vector2(w * sx + 18.0, h * 0.53), 18.0, Color("#222B33"))
			draw_circle(Vector2(w * sx + 18.0, h * 0.53), 12.0, Color("#505C66"))

	func _draw_podcast(w: float, h: float) -> void:
		_grad(Rect2(0, 0, w, h), Color("#2A1640"), Color("#0A0510"))
		for s in range(3):
			var yy := 70.0 + float(s) * 120.0
			draw_rect(Rect2(40.0, yy + 44.0, w * 0.22, 5.0), Color("#5B3A2A"))
			for b in range(11):
				var bh := 30.0 + float((b * 7 + s * 5) % 14)
				draw_rect(Rect2(46.0 + float(b) * 17.0, yy + 44.0 - bh, 13.0, bh), Color.from_hsv(float((b * 37 + s * 13) % 100) / 100.0, 0.45, 0.55))
		# Neón
		var glow := 0.65 + 0.35 * sin(_t * 2.0)
		var title := str((_session.get("outlet", {}) as Dictionary).get("name", "PÓDCAST"))
		TV.text_tl(self, title, Vector2(0, 22), 38, Color(Color("#FF7AD9"), glow), true, HORIZONTAL_ALIGNMENT_CENTER, w)
		TV.text_tl(self, "● REC  %02d:%02d" % [int(_t / 60.0) % 60, int(_t) % 60], Vector2(w - 190.0, 22), 18, TV.RED)
		# Ondas de sonido
		for i in range(60):
			var amp := 6.0 + 26.0 * absf(sin(_t * 3.0 + float(i) * 0.4)) * (0.4 + 0.6 * absf(sin(float(i) * 0.15)))
			draw_rect(Rect2(w * 0.12 + float(i) * (w * 0.76) / 60.0, h * 0.84 - amp * 0.5, 4.0, amp), Color("#FF7AD9", 0.55))
		_desk(h * 0.74, w, Color("#4A2B66"))
		for sx in [0.36, 0.64]:
			draw_line(Vector2(w * sx, h * 0.74), Vector2(w * sx, h * 0.52), Color("#B9A3D6"), 4.0)
			draw_circle(Vector2(w * sx, h * 0.50), 16.0, Color("#D8C8EE"))

	func _draw_press(w: float, h: float) -> void:
		_grad(Rect2(0, 0, w, h), Color("#1A2740"), Color("#070B14"))
		for r in range(4):
			for c in range(7):
				TV.text_tl(self, ["MONCLOA", "GOBIERNO", "ESPAÑA", "PRENSA"][(r + c) % 4], Vector2(30.0 + float(c) * w / 7.0, 40.0 + float(r) * 60.0), 22, Color(TV.WHITE, 0.05))
		# Atril
		TV.rrect(self, Rect2(w * 0.68 - 70.0, h * 0.5, 140.0, h * 0.34), Color("#2D3F62"), 8.0)
		for k in range(3):
			draw_line(Vector2(w * 0.68 - 36.0 + float(k) * 36.0, h * 0.5), Vector2(w * 0.68 - 36.0 + float(k) * 36.0, h * 0.42), Color("#9CAAC0"), 3.0)
			draw_circle(Vector2(w * 0.68 - 36.0 + float(k) * 36.0, h * 0.41), 7.0, Color("#E1E8F3"))
		# Periodistas en primera fila; el que pregunta levanta la mano
		for i in range(5):
			var jx := w * (0.1 + 0.19 * float(i))
			var jy := h * 0.9
			var jc: Color = (_journalists[i] as Dictionary)["col"]
			var active := i == asker
			draw_circle(Vector2(jx, jy - 34.0 - (10.0 if active else 0.0)), 22.0, jc.lightened(0.15 if active else 0.0))
			TV.rrect(self, Rect2(jx - 34.0, jy - 8.0 - (10.0 if active else 0.0), 68.0, 60.0), jc.darkened(0.2), 18.0)
			TV.text_tl(self, str((_journalists[i] as Dictionary)["tag"]), Vector2(jx - 34.0, jy + 8.0 - (10.0 if active else 0.0)), 11, Color(TV.WHITE, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER, 68.0)
			if active:
				draw_line(Vector2(jx + 20.0, jy - 40.0), Vector2(jx + 34.0, jy - 78.0), jc.lightened(0.2), 7.0)
				draw_circle(Vector2(jx + 36.0, jy - 82.0), 8.0, jc.lightened(0.3))
				var fl := 0.5 + 0.5 * sin(_t * 12.0)
				draw_rect(Rect2(jx - 16.0, jy - 112.0, 32.0, 6.0), Color(TV.GOLD, 0.4 + 0.5 * fl))

	func _draw_debate(w: float, h: float) -> void:
		_grad(Rect2(0, 0, w, h), Color("#241A3E"), Color("#05040C"))
		draw_rect(Rect2(w * 0.5 - 1.0, 0, 2.0, h), Color(TV.WHITE, 0.08))
		var rival := str(_session.get("rival", ""))
		var cl := Color(_m.party_color(_m.pid()))
		var cr := Color(_m.party_color(rival)) if rival != "" else TV.MUTED
		_spot(w * 0.26, 0.0, h * 0.85, 190.0, cr.lightened(0.5))
		_spot(w * 0.74, 0.0, h * 0.85, 190.0, cl.lightened(0.5))
		TV.rrect(self, Rect2(w * 0.26 - 130.0, h * 0.72, 260.0, h * 0.2), cr.darkened(0.45), 10.0, cr, 3)
		TV.rrect(self, Rect2(w * 0.74 - 130.0, h * 0.72, 260.0, h * 0.2), cl.darkened(0.45), 10.0, cl, 3)
		TV.text_tl(self, _m.party_short(rival) if rival != "" else "", Vector2(w * 0.26 - 130.0, h * 0.72 + 16.0), 24, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 260.0)
		TV.text_tl(self, str(_m.party.get("short_name", "")), Vector2(w * 0.74 - 130.0, h * 0.72 + 16.0), 24, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 260.0)
		TV.text_tl(self, "CARA A CARA", Vector2(0, 10), 30, Color(TV.GOLD, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER, w)

	func _draw_pleno(w: float, h: float) -> void:
		_grad(Rect2(0, 0, w, h), Color("#2B1E1A"), Color("#0A0605"))
		TV.text_tl(self, "CONGRESO DE LOS DIPUTADOS", Vector2(0, 14), 26, Color(TV.GOLD, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER, w)
		# Hemiciclo de fondo: puntos de colores por escaño
		if _seats.is_empty():
			var ids: Array = []
			for p in _m.rivals:
				ids.append(str((p as Dictionary)["id"]))
			ids.append(_m.pid())
			for id in ids:
				var n := int(round(float(_m.seats_of(str(id))) / 350.0 * 150.0))
				for k in range(n):
					_seats.append(_m.party_color(str(id)))
		var rows := 6
		var kx := minf(1.5, w * 0.47 / (h * 0.795))
		var idx := 0
		for r in range(rows):
			var rad := h * (0.42 + 0.075 * float(r))
			var count := 16 + r * 5
			for k in range(count):
				var a := PI + PI * (float(k) + 0.5) / float(count)
				var pos := Vector2(w * 0.5 + cos(a) * rad * kx, h * 0.9 + sin(a) * rad)
				var col: Color = _seats[idx % maxi(_seats.size(), 1)] if not _seats.is_empty() else Color("#555555")
				draw_circle(pos, 7.0, Color(col, 0.75))
				idx += 1
		TV.rrect(self, Rect2(w * 0.5 - 150.0, h * 0.08, 300.0, 38.0), Color("#3A2A22"), 8.0, TV.GOLD, 2)
		TV.text_tl(self, "PRESIDENCIA", Vector2(w * 0.5 - 150.0, h * 0.08 + 8.0), 18, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
