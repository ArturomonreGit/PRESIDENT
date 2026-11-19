class_name PlenaryScreen
extends Screen
## Pleno del Congreso, pantalla de juego. Cada iniciativa del orden del día pasa por cuatro fases:
##   presentación → enmiendas → tu voto → votación de los grupos (animada) → resultado.
## Tú votas primero; después el hemiciclo se va encendiendo grupo a grupo con la explicación de voto de cada uno.
## Las enmiendas van en los dos sentidos: la IA enmienda tus leyes y tú enmiendas las suyas (ver `Amendments`).

# Estado de la sesión (estático: sobrevive a las reconstrucciones de la pantalla).
static var phase := ""                    ## intro | debate | vote | reveal | result
static var law_id := ""
static var cur_law: Dictionary = {}
static var result: Dictionary = {}
static var order: Array = []
static var pos := 0
static var revealed: Dictionary = {}      ## id partido → voto ya mostrado
static var feed: Array = []               ## [{id, vote, line}] en orden de aparición
static var running := false
static var fast := false                  ## sin pausas (pruebas / saltar animación)
static var show_forecast := true
static var player_choice := ""
static var am_area := ""                  ## ventana «Redactar enmienda»: área, medida y valor elegidos
static var am_mid := ""
static var am_val := NAN

const STEPS := [["intro", "Presentación"], ["debate", "Enmiendas"], ["vote", "Votación"], ["result", "Resultado"]]
const VOTE_WORDS := {"yes": "A favor", "no": "En contra", "abstain": "Abstención"}
const REVEAL_SECS := 0.85

var hall: ParliamentHall
var tally: TallyBar
var lbl_yes: Label
var lbl_no: Label
var lbl_abs: Label
var lbl_caption: Label
var banner_box: HBoxContainer
var left_box: VBoxContainer
var side_box: VBoxContainer
var action_box: HBoxContainer
var feed_box: VBoxContainer
var feed_scroll: ScrollContainer

func wants_full() -> bool:
	return true

static func _reset_ui_static() -> void:
	phase = ""
	law_id = ""
	cur_law = {}
	result = {}
	order = []
	pos = 0
	revealed = {}
	feed = []
	running = false
	fast = false
	show_forecast = true
	player_choice = ""
	am_area = ""
	am_mid = ""
	am_val = NAN

func _reset_ui() -> void:
	var keep_fast := fast
	_reset_ui_static()
	fast = keep_fast

func build() -> void:
	m.eco.ensure()
	if phase in ["reveal", "result"] and not _in_results(cur_law):
		_reset_ui()          # estado de otra partida o de otra sesión
	if phase in ["reveal", "result"] and not cur_law.is_empty():
		_session()
		return
	match m.congress.stage():
		"ready": _agenda()
		"running": _session()
		_: _done()

func _in_results(law: Dictionary) -> bool:
	if law.is_empty():
		return false
	for r in m.congress.results():
		var rl: Dictionary = (r as Dictionary).get("law", {})
		if str(rl.get("id", "")) == str(law.get("id", "x")):
			return true
	return false

func _parties_left_to_right() -> Array:
	var ids: Array = m.gov.parliamentary_ids().duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return float(m.party_by_id(a).get("ideology", {}).get("economic", 0.0)) < float(m.party_by_id(b).get("ideology", {}).get("economic", 0.0)))
	return ids

func _hall_entries() -> Array:
	var entries: Array = []
	for id in _parties_left_to_right():
		entries.append({"id": str(id), "color": m.party_color(str(id)), "seats": m.seats_of(str(id)), "name": m.party_short(str(id))})
	return entries

func _scroll(parent: Node) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

func _vote_chip(vote: String, filled: bool = true) -> Control:
	match vote:
		"yes": return UI.chip("A favor", UI.GOOD, filled)
		"no": return UI.chip("En contra", UI.BAD, filled)
		"abstain": return UI.chip("Abstención", UI.MUTED, filled)
	return UI.label("…", UI.FS_SMALL, UI.FAINT)

func _kind_short(law: Dictionary) -> String:
	var k := str(law.get("kind", ""))
	if k == "presupuestos":
		return "Presupuestos"
	if k == "pnl":
		return "PNL"
	if k == "interpelacion":
		return "Interpelación"
	return "Ley"

func _area_chip(law: Dictionary) -> Control:
	if str(law.get("kind", "")) == "presupuestos":
		return UI.chip("Presupuestos", UI.WARN)
	var area := Policies.area(str(law.get("area", "")))
	return UI.chip(str(area.get("name", "")), Color(str(area.get("color", "#2563EB"))))

func _law() -> Dictionary:
	return cur_law if phase in ["reveal", "result"] and not cur_law.is_empty() else m.congress.current()

func _is_vote_kind(law: Dictionary) -> bool:
	return str(law.get("kind", "")) != "interpelacion"

# ================================================================ orden del día (antes de abrir la sesión)
func _agenda() -> void:
	var laws := m.congress.laws()
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(560, 0)
	row.add_child(left)
	var c := UI.card(left, "Orden del día", "trimestre %d · %d iniciativa%s" % [m.turn(), laws.size(), "" if laws.size() == 1 else "s"], UI.ACCENT)
	UI.expand_card(c)
	var list := _scroll(c)
	for l in laws:
		list.add_child(_agenda_item(l as Dictionary))
	var btns := UI.hbox(10)
	btns.add_child(UI.button("Abrir la sesión", "primary", _open_session, 220))
	btns.add_child(UI.button("Votar todo según mi ideología", "ghost", _auto_all))
	left.add_child(btns)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var hc := UI.card(right, "Hemiciclo", "350 escaños · mayoría absoluta 176", UI.GOOD)
	UI.expand_card(hc)
	hall = ParliamentHall.new()
	hall.player_id = m.pid()
	hall.entries = _hall_entries()
	hall.set_center("Sesión plenaria", "trimestre %d" % m.turn())
	hc.add_child(hall)
	var legend := UI.hbox(10)
	for id in _parties_left_to_right():
		if m.seats_of(str(id)) >= 8:
			legend.add_child(UI.party_tag(m, str(id), UI.FS_SMALL, m.is_player(str(id))))
	hc.add_child(legend)

func _agenda_item(law: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color("#F6F9FE"), UI.D4_LINE, 4, 1, 12, 10))
	var h := UI.hbox(12)
	pc.add_child(h)
	h.add_child(UI.leader_portrait(m, str(law["proposer"]), 52))
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(str(law["title"]), UI.FS_LEAD, UI.TEXT, true))
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 6)
	meta.add_child(UI.party_tag(m, str(law["proposer"]), UI.FS_SMALL, true))
	meta.add_child(UI.chip(_kind_short(law), UI.ACCENT))
	meta.add_child(_area_chip(law))
	if m.is_player(str(law["proposer"])):
		meta.add_child(UI.chip("Tuya", UI.ACCENT, true))
	v.add_child(meta)
	v.add_child(UI.wrap_label(m.congress.describe(law), UI.FS_SMALL, UI.MUTED))
	h.add_child(v)
	if m.laws.has_votes(law):
		var fc := m.laws.forecast(law)
		var ok := m.laws.passes(law, int(fc["yes"]), int(fc["no"]))
		var col := UI.vbox(2)
		col.add_child(UI.chip("Saldría" if ok else "Sin apoyos", UI.GOOD if ok else UI.BAD))
		col.add_child(UI.label("%d–%d" % [int(fc["yes"]), int(fc["no"])], UI.FS_SMALL, UI.MUTED))
		h.add_child(col)
	return pc

func _open_session() -> void:
	m.congress.begin()
	_reset_ui()
	Sfx.play("gavel")
	shell.refresh_chrome()
	rebuild()

func _auto_all() -> void:
	m.congress.auto_finish()
	_reset_ui()
	shell.refresh_chrome()
	rebuild()

# ================================================================ sesión en curso
func _session() -> void:
	var law := _law()
	if law.is_empty():
		_done()
		return
	if phase not in ["reveal", "result"] and str(law["id"]) != law_id:
		_reset_ui()
		law_id = str(law["id"])
		phase = "intro"
	cur_law = law
	_strip(law)
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	left_box = UI.vbox(8)
	left_box.custom_minimum_size = Vector2(400, 0)
	left_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(left_box)
	var center := UI.vbox(8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1.5
	row.add_child(center)
	side_box = UI.vbox(8)
	side_box.custom_minimum_size = Vector2(430, 0)
	side_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(side_box)
	_hall_panel(center)
	var abar := PanelContainer.new()
	abar.add_theme_stylebox_override("panel", UI.box(Color("#EAF0FA"), UI.D4_LINE, 4, 1, 14, 10))
	action_box = UI.hbox(10)
	abar.add_child(action_box)
	center.add_child(abar)
	_restore_hall(law)
	_fill_all()
	if phase == "reveal" and not running:
		_run_reveal()

func _fill_all() -> void:
	var law := _law()
	if law.is_empty():
		return
	cur_law = law
	_fill_left(law)
	_fill_side(law)
	_fill_actions(law)
	_fill_forecast(law)

# ---------------------------------------------------------------- franja superior: orden del día y fases
func _strip(law: Dictionary) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.D4_LINE, 4, 1, 12, 6))
	var h := UI.hbox(8)
	bar.add_child(h)
	h.add_child(UI.label("TRIMESTRE %d · PLENO" % m.turn(), UI.FS_SMALL, UI.MUTED, true))
	var laws := m.congress.laws()
	var res := m.congress.results()
	var shown := m.congress.index() - (1 if phase in ["reveal", "result"] and not result.is_empty() else 0)
	for i in range(laws.size()):
		var l: Dictionary = laws[i]
		var chip: Control
		if i < res.size() and i < shown:
			var rd: Dictionary = res[i]
			var tone := UI.GOOD if bool(rd.get("passed", false)) else UI.BAD
			if bool(rd.get("withdrawn", false)):
				tone = UI.MUTED
			chip = UI.chip("%d · %s" % [i + 1, _short_title(l)], tone)
		elif str(l["id"]) == str(law["id"]):
			chip = UI.chip("%d · %s" % [i + 1, _short_title(l)], UI.ACCENT, true)
		else:
			chip = UI.chip("%d · %s" % [i + 1, _short_title(l)], UI.FAINT)
		h.add_child(chip)
	h.add_child(UI.fill())
	for i2 in range(STEPS.size()):
		var sid: String = STEPS[i2][0]
		var active := sid == phase or (sid == "vote" and phase == "reveal")
		var past := _step_index(phase) > i2
		var col := UI.ACCENT if active else (UI.GOOD if past else UI.FAINT)
		h.add_child(UI.chip("%d %s" % [i2 + 1, str(STEPS[i2][1])], col, active))
	add_child(bar)

func _short_title(law: Dictionary) -> String:
	var t := str(law["title"])
	return t if t.length() <= 26 else t.substr(0, 25) + "…"

func _step_index(p: String) -> int:
	if p == "reveal":
		return 2
	for i in range(STEPS.size()):
		if str(STEPS[i][0]) == p:
			return i
	return 0

# ---------------------------------------------------------------- hemiciclo y recuento
func _hall_panel(parent: Node) -> void:
	var c := UI.card(parent, "Hemiciclo", "350 escaños", UI.GOOD)
	UI.expand_card(c)
	banner_box = UI.hbox(10)
	banner_box.custom_minimum_size = Vector2(0, 58)
	c.add_child(banner_box)
	hall = ParliamentHall.new()
	hall.player_id = m.pid()
	hall.entries = _hall_entries()
	c.add_child(hall)
	var tiles := UI.hbox(18)
	lbl_yes = UI.label("0", 28, UI.GOOD, true)
	lbl_abs = UI.label("0", 28, UI.MUTED, true)
	lbl_no = UI.label("0", 28, UI.BAD, true)
	for pair in [["A FAVOR", lbl_yes, UI.GOOD], ["ABSTENCIÓN", lbl_abs, UI.MUTED], ["EN CONTRA", lbl_no, UI.BAD]]:
		var v := UI.vbox(0)
		v.add_child(UI.label(str(pair[0]), UI.FS_TINY, UI.FAINT, true))
		v.add_child(pair[1])
		tiles.add_child(v)
	tiles.add_child(UI.fill())
	lbl_caption = UI.label("", UI.FS_SMALL, UI.MUTED, true)
	tiles.add_child(lbl_caption)
	c.add_child(tiles)
	tally = TallyBar.new()
	c.add_child(tally)

func _restore_hall(law: Dictionary) -> void:
	var organic := m.laws.is_organic(law)
	tally.marker = float(Rules.MAJORITY if organic else 175)
	tally.marker_label = "176 · absoluta" if organic else "mitad"
	hall.reset()
	hall.player_id = m.pid()
	for pid in revealed.keys():
		hall.reveal(str(pid), str(revealed[pid]), true)
	if phase == "result" and not result.is_empty():
		_apply_result_stamp(true)
	_update_counts(false)

func _counts() -> Dictionary:
	var yes := 0
	var no := 0
	var abst := 0
	for pid in revealed.keys():
		var seats := m.seats_of(str(pid))
		match str(revealed[pid]):
			"yes": yes += seats
			"no": no += seats
			_: abst += seats
	return {"yes": yes, "no": no, "abst": abst}

func _update_counts(animate: bool) -> void:
	if tally == null or not is_instance_valid(tally):
		return
	if revealed.is_empty() and phase != "result":
		return
	var c := _counts()
	lbl_yes.text = str(c["yes"])
	lbl_no.text = str(c["no"])
	lbl_abs.text = str(c["abst"])
	lbl_caption.text = "Recuento"
	if animate and not fast:
		tally.animate_to(int(c["yes"]), int(c["no"]), int(c["abst"]))
	else:
		tally.yes = float(c["yes"])
		tally.no = float(c["no"])
		tally.abst = float(c["abst"])
	if phase == "reveal":
		hall.set_center("%d" % int(c["yes"]), "votos a favor")

## Antes de votar, el hemiciclo y la barra muestran la previsión con el texto actual.
func _fill_forecast(law: Dictionary) -> void:
	if hall == null or not is_instance_valid(hall):
		return
	if phase in ["reveal", "result"]:
		hall.set_forecast({})
		if phase == "result" and str(result.get("kind", "")) == "interpelacion":
			lbl_yes.text = "–"
			lbl_no.text = "–"
			lbl_abs.text = "–"
			lbl_caption.text = "Sin votación"
		return
	if not _is_vote_kind(law) or not m.laws.has_votes(law) or not show_forecast:
		hall.set_forecast({})
		lbl_yes.text = "–"
		lbl_no.text = "–"
		lbl_abs.text = "–"
		lbl_caption.text = ("Sin votación" if not _is_vote_kind(law) else ("Previsión oculta" if not show_forecast else ""))
		tally.animate_to(0, 0, 0, 0.2)
		hall.set_center("Pleno" if _is_vote_kind(law) else "Debate", "trimestre %d" % m.turn())
		return
	var fc := m.laws.forecast(law)
	hall.set_forecast(fc["by_party"])
	lbl_yes.text = str(fc["yes"])
	lbl_no.text = str(fc["no"])
	lbl_abs.text = str(fc["abstain"])
	lbl_caption.text = "Previsión · sin tu voto concreto"
	tally.animate_to(int(fc["yes"]), int(fc["no"]), int(fc["abstain"]), 0.4)
	var ok := m.laws.passes(law, int(fc["yes"]), int(fc["no"]))
	hall.set_center("Saldría" if ok else "No saldría", "%d – %d" % [int(fc["yes"]), int(fc["no"])])

func _banner_text(title: String, sub: String, who: String = "", vote: String = "") -> void:
	if banner_box == null or not is_instance_valid(banner_box):
		return
	UI.clear_children(banner_box)
	if who != "":
		banner_box.add_child(UI.leader_portrait(m, who, 48))
	var v := UI.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(8)
	top.add_child(UI.label(title, UI.FS_LEAD, UI.TEXT, true))
	if vote != "":
		top.add_child(_vote_chip(vote))
	v.add_child(top)
	if sub != "":
		v.add_child(UI.wrap_label(sub, UI.FS_BODY, UI.MUTED))
	banner_box.add_child(v)
	if not fast:
		banner_box.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	else:
		banner_box.modulate = Color.WHITE

# ================================================================ columna izquierda: la iniciativa
func _fill_left(law: Dictionary) -> void:
	UI.clear_children(left_box)
	var c := UI.card(left_box, "Iniciativa", "", UI.ACCENT)
	UI.expand_card(c)
	var top := UI.hbox(12)
	top.add_child(UI.leader_portrait(m, str(law["proposer"]), 64))
	var who := UI.vbox(2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.eyebrow("PRESENTA"))
	who.add_child(UI.label(m.party_name(str(law["proposer"])), UI.FS_LEAD, UI.TEXT, true))
	var seats := UI.hbox(6)
	seats.add_child(UI.chip("%d escaños" % m.seats_of(str(law["proposer"])), UI.MUTED))
	if m.is_player(str(law["proposer"])):
		seats.add_child(UI.chip("Tuya", UI.ACCENT, true))
	who.add_child(seats)
	top.add_child(who)
	c.add_child(top)
	c.add_child(UI.hsep())
	c.add_child(UI.wrap_label(str(law["title"]), UI.FS_H2, UI.TEXT, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.add_child(UI.chip(_kind_short(law), UI.ACCENT))
	chips.add_child(_area_chip(law))
	if _is_vote_kind(law):
		chips.add_child(UI.chip(m.laws.required_text(law), UI.WARN if m.laws.is_organic(law) else UI.MUTED))
	var tone := str(law.get("tone", "estandar"))
	if str(law.get("kind", "")) in ["proposición", "proyecto", "pnl"] and tone != "estandar":
		chips.add_child(UI.chip(str(LawMaker.TONES.get(tone, {}).get("name", tone)), UI.WARN if tone == "bandera" else UI.GOOD))
	c.add_child(chips)
	c.add_child(UI.wrap_label(m.congress.describe(law), UI.FS_BODY, UI.MUTED))
	var body := _scroll(c)
	if str(law.get("kind", "")) == "interpelacion":
		var style := str(law.get("style", "tecnico"))
		body.add_child(UI.label("TONO DE LA INTERVENCIÓN", UI.FS_TINY, UI.MUTED, true))
		body.add_child(UI.label(str(LawMaker.STYLES.get(style, {}).get("name", style)), UI.FS_BODY, UI.TEXT, true))
		body.add_child(UI.wrap_label(str(LawMaker.STYLES.get(style, {}).get("desc", "")), UI.FS_SMALL, UI.MUTED))
		return
	var lines: Array = m.laws.change_lines(law) if result.is_empty() or str(law.get("kind", "")) == "presupuestos" else _applied_lines(law)
	body.add_child(UI.label("QUÉ CAMBIA" if str(law.get("kind", "")) != "pnl" else "QUÉ PIDE AL GOBIERNO", UI.FS_TINY, UI.MUTED, true))
	for i in range(mini(lines.size(), 8)):
		var d: Dictionary = lines[i]
		var txt := "%s: %s → %s" % [str(d["name"]), str(d["from"]), str(d["to"])] if str(d.get("from", "")) != "" else "%s: %s" % [str(d["name"]), str(d["to"])]
		body.add_child(UI.wrap_label("• " + txt, UI.FS_BODY, UI.TEXT))
	if lines.size() > 8:
		body.add_child(UI.label("… y %d medidas más" % (lines.size() - 8), UI.FS_SMALL, UI.FAINT))
	if str(law.get("kind", "")) in ["pnl", "presupuestos"]:
		return
	var pv: Dictionary = m.eco.preview(law["changes"], law.get("irpf", [])) if result.is_empty() else (result.get("preview", {}) as Dictionary)
	if pv.is_empty():
		return
	body.add_child(UI.hsep())
	body.add_child(UI.label("EFECTO PREVISTO", UI.FS_TINY, UI.MUTED, true))
	var bal := float(pv.get("balance", 0.0))
	body.add_child(UI.label("Saldo público %s bn €/año" % UI.signed(bal, 1), UI.FS_BODY, UI.GOOD if bal >= 0.0 else UI.BAD, true))
	var fx: Dictionary = pv.get("fx", {})
	var keys: Array = fx.keys()
	keys.sort_custom(func(a, b) -> bool: return absf(float(fx[a])) > absf(float(fx[b])))
	for k in keys.slice(0, 4):
		var val := float(fx[k])
		var good := val > 0.0 if not (str(k) in ["unemployment", "inflation"]) else val < 0.0
		body.add_child(UI.label(("▲ " if good else "▼ ") + "%s %s" % [Policies.quality_name(str(k)), UI.signed(val, 1)], UI.FS_SMALL, UI.GOOD if good else UI.BAD))

## Tras aprobarse, la economía ya tiene los valores nuevos: se listan solo las medidas con el valor aprobado.
func _applied_lines(law: Dictionary) -> Array:
	var out: Array = []
	for mid in (law["changes"] as Dictionary).keys():
		var meas := Policies.measure(str(mid))
		if str(mid) == Irpf.SPECIAL_ID:
			out.append({"name": "IRPF por tramos", "from": "", "to": "nueva escala"})
			continue
		out.append({"name": str(meas["name"]), "from": "", "to": Policies.value_text(meas, float(law["changes"][mid]))})
	return out

# ================================================================ columna derecha según la fase
func _fill_side(law: Dictionary) -> void:
	UI.clear_children(side_box)
	match phase:
		"intro": _side_intro(law)
		"debate": _side_debate(law)
		"vote": _side_forecast(law)
		"reveal": _side_feed()
		"result": _side_result(law)
	_banner_for_phase(law)

func _banner_for_phase(law: Dictionary) -> void:
	var prop := str(law["proposer"])
	match phase:
		"intro":
			_banner_text("%s presenta la iniciativa" % m.party_short(prop), _speech(law), prop)
		"debate":
			_banner_text("Trámite de enmiendas", "Los grupos negocian el texto antes de votar.", "")
		"vote":
			if m.congress.player_votes_this(law):
				_banner_text("Tu grupo vota primero", "Después irán votando el resto de grupos, de izquierda a derecha.", m.pid())
			else:
				_banner_text("Votación de tu propia iniciativa", "Tu grupo la defiende; vota a favor.", m.pid())
		"reveal":
			if feed.is_empty():
				_banner_text("Se abre la votación", "Primero vota tu grupo; después, el resto de la Cámara.", m.pid())
		"result":
			if str(result.get("kind", "")) == "interpelacion":
				_banner_text("Fin del debate", "", "")
			else:
				_banner_text("APROBADA" if bool(result.get("passed", false)) else "RECHAZADA", "%d a favor · %d en contra · %d abstenciones" % [int(result.get("yes", 0)), int(result.get("no", 0)), int(result.get("abstain", 0))], "")

func _speech(law: Dictionary) -> String:
	var tone := str(law.get("tone", "estandar"))
	var kind := str(law.get("kind", ""))
	var area := str(Policies.area(str(law.get("area", ""))).get("name", "")).to_lower()
	if kind == "presupuestos":
		return "Presentamos las cuentas del año. Pedimos responsabilidad al Pleno."
	if kind == "interpelacion":
		return "Interpelamos al Gobierno sobre %s: queremos respuestas, no excusas." % area
	if m.is_player(str(law["proposer"])):
		match tone:
			"consenso": return "Tendéis la mano a los demás grupos: texto abierto al acuerdo."
			"bandera": return "Ley de bandera: tu grupo la defiende sin complejos."
		return "Tu grupo presenta su iniciativa sobre %s." % area
	match tone:
		"consenso": return "«Tendemos la mano a todos los grupos: esta ley sobre %s es de todos.»" % area
		"bandera": return "«Esta es nuestra bandera en %s. Que cada uno se retrate.»" % area
	return "«Presentamos esta iniciativa sobre %s y pedimos el voto de la Cámara.»" % area

# ---------------------------------------------------------------- presentación
func _side_intro(law: Dictionary) -> void:
	_side_forecast(law)

func _side_forecast(law: Dictionary) -> void:
	var fc: Dictionary = {}
	var has := _is_vote_kind(law) and m.laws.has_votes(law)
	if has:
		fc = m.laws.forecast(law)
	var c := UI.card(side_box, "Así llegan los grupos" if has else "Debate de control", "previsión" if has else "", UI.ACCENT)
	UI.expand_card(c)
	if not has:
		c.add_child(UI.wrap_label("Una interpelación no se vota: se mide por el impacto del debate. Cuanto más flaquee el Gobierno en esta área, más rédito sacarás; el tono que elegiste en el Taller decide el riesgo.", UI.FS_BODY, UI.MUTED))
		return
	var list := _scroll(c)
	var committed: Dictionary = law.get("committed", {})
	for id in _parties_left_to_right():
		var pid := str(id)
		var r := UI.hbox(8)
		r.custom_minimum_size = Vector2(0, 30)
		r.add_child(UI.party_tag(m, pid, UI.FS_BODY, m.is_player(pid)))
		r.add_child(UI.label("%d" % m.seats_of(pid), UI.FS_SMALL, UI.FAINT))
		r.add_child(UI.fill())
		if committed.has(pid):
			var pact := UI.chip("Comprometido", UI.ACCENT)
			pact.tooltip_text = "Se comprometió a votar así en el trámite de enmiendas."
			r.add_child(pact)
		var vote := str((fc["by_party"] as Dictionary).get(pid, "abstain"))
		r.add_child(_vote_chip(vote, false))
		list.add_child(r)
	var ok := m.laws.passes(law, int(fc["yes"]), int(fc["no"]))
	c.add_child(UI.hsep())
	var sum := UI.hbox(8)
	sum.add_child(UI.chip("Saldría" if ok else "No saldría", UI.GOOD if ok else UI.BAD, true))
	sum.add_child(UI.label("%d a favor · %d en contra · %d abst." % [int(fc["yes"]), int(fc["no"]), int(fc["abstain"])], UI.FS_SMALL, UI.MUTED))
	c.add_child(sum)

# ---------------------------------------------------------------- enmiendas
func _side_debate(law: Dictionary) -> void:
	var amd := m.congress.amend
	if not amd.supports(law):
		_side_forecast(law)
		return
	if m.is_player(str(law["proposer"])):
		_side_offers(law)
	else:
		_side_propose(law)

func _side_offers(law: Dictionary) -> void:
	var amd := m.congress.amend
	var open := amd.open_offers(law)
	var c := UI.card(side_box, "Enmiendas de los grupos", "%d sobre la mesa" % open.size(), UI.ACCENT)
	UI.expand_card(c)
	var list := _scroll(c)
	if open.is_empty():
		list.add_child(UI.wrap_label("Ningún grupo pide cambios ahora mismo. Si crees que la ley no suma, puedes retirarla y reelaborarla en el Taller.", UI.FS_BODY, UI.MUTED))
	for o in open:
		list.add_child(_offer_card(law, o as Dictionary))
	var closed: Array = []
	for o2 in amd.offers(law):
		if str((o2 as Dictionary)["status"]) != "open":
			closed.append(o2)
	if not closed.is_empty():
		list.add_child(UI.label("YA RESUELTAS", UI.FS_TINY, UI.MUTED, true))
		for o3 in closed:
			var od: Dictionary = o3
			var r := UI.hbox(6)
			r.add_child(UI.party_tag(m, str(od["from"]), UI.FS_SMALL, true))
			var st := str(od["status"])
			r.add_child(UI.chip({"accepted": "Aceptada", "rejected": "Rechazada", "obsolete": "Superada"}.get(st, st), UI.GOOD if st == "accepted" else UI.FAINT))
			list.add_child(r)
	_log_block(list, law)

func _offer_card(law: Dictionary, o: Dictionary) -> Control:
	var pid := str(o["from"])
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color("#F6F9FE"), m.party_color(pid), 4, 1, 12, 10))
	var v := UI.vbox(6)
	pc.add_child(v)
	var top := UI.hbox(10)
	top.add_child(UI.leader_portrait(m, pid, 44))
	var who := UI.vbox(1)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.label(m.party_name(pid), UI.FS_BODY, UI.TEXT, true))
	who.add_child(UI.label("%d escaños" % m.seats_of(pid), UI.FS_SMALL, UI.MUTED))
	top.add_child(who)
	var vi := str(o.get("vote_if", "yes"))
	top.add_child(_vote_chip(vi if vi != "no" else "abstain", true))
	v.add_child(top)
	v.add_child(UI.wrap_label(str(o["line"]), UI.FS_SMALL, UI.MUTED))
	for t in o["terms"]:
		var td: Dictionary = t
		v.add_child(UI.wrap_label("• " + str(td["text"]), UI.FS_BODY, UI.TEXT, true))
	var btns := UI.hbox(6)
	var oid := int(o["id"])
	btns.add_child(UI.button("Aceptar", "good", _on_accept.bind(oid)))
	var counter_txt := "Solo la primera" if (o["terms"] as Array).size() > 1 else "Solo abstención"
	var cb := UI.button(counter_txt, "secondary", _on_counter.bind(oid))
	cb.tooltip_text = "Aceptas solo una parte: puede que el grupo se avenga a abstenerse."
	btns.add_child(cb)
	btns.add_child(UI.button("Rechazar", "ghost", _on_reject.bind(oid)))
	v.add_child(btns)
	return pc

func _after_amend(res: Dictionary) -> void:
	var txt := str(res.get("text", ""))
	if txt != "":
		shell.toast(txt, "positive" if bool(res.get("ok", false)) else "warning")
	_fill_all()

func _on_accept(oid: int) -> void:
	_after_amend(m.congress.amend.accept(_law(), oid))

func _on_counter(oid: int) -> void:
	_after_amend(m.congress.amend.counter(_law(), oid))

func _on_reject(oid: int) -> void:
	_after_amend(m.congress.amend.reject(_law(), oid))

func _side_propose(law: Dictionary) -> void:
	var amd := m.congress.amend
	var left := amd.slots_left(law)
	var c := UI.card(side_box, "Tus enmiendas", "%d de %d disponibles" % [left, Amendments.PLAYER_SLOTS], UI.ACCENT)
	UI.expand_card(c)
	var list := _scroll(c)
	list.add_child(UI.wrap_label("Tú decides qué cambiar: cualquier medida, de cualquier área, con el valor que quieras. %s la aceptará según cuánto necesite tus votos." % m.party_short(str(law["proposer"])), UI.FS_BODY, UI.MUTED))
	var wb := UI.button("✎  Redactar una enmienda", "primary", _on_open_amend)
	wb.custom_minimum_size = Vector2(0, 44)
	wb.disabled = left <= 0
	list.add_child(wb)
	if left <= 0:
		list.add_child(UI.label("Has agotado tus enmiendas para esta ley.", UI.FS_SMALL, UI.WARN))
	var cs := amd.counters(law)
	for i in range(cs.size()):
		list.add_child(_counter_card(cs[i] as Dictionary, i))
	# medidas de la ley: tocar cualquiera abre la ventana con ella elegida
	list.add_child(UI.hsep())
	list.add_child(UI.label("MEDIDAS DE LA LEY", UI.FS_TINY, UI.MUTED, true))
	var shown := 0
	for k in (law["changes"] as Dictionary).keys():
		var mid := str(k)
		if Policies.is_special(mid):
			continue
		var meas := Policies.measure(mid)
		if meas.is_empty():
			continue
		shown += 1
		var r := UI.hbox(6)
		var t := UI.wrap_label("%s: %s → %s" % [str(meas["name"]), Policies.value_text(meas, m.eco.value(mid)), Policies.value_text(meas, float((law["changes"] as Dictionary)[mid]))], UI.FS_SMALL, UI.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		var eb := UI.mini_button("Enmendar", _on_amend_measure.bind(mid))
		eb.disabled = left <= 0
		r.add_child(eb)
		list.add_child(r)
	if shown == 0:
		list.add_child(UI.label("La ley no toca medidas concretas.", UI.FS_SMALL, UI.FAINT))
	# ideas rápidas: las que más te favorecen
	var opts := amd.player_options(law)
	if not opts.is_empty():
		list.add_child(UI.hsep())
		list.add_child(UI.label("IDEAS RÁPIDAS", UI.FS_TINY, UI.MUTED, true))
		for i2 in range(mini(3, opts.size())):
			var t2: Dictionary = opts[i2]
			var row := UI.hbox(6)
			var txt := UI.wrap_label(str(t2["text"]), UI.FS_SMALL, UI.TEXT)
			txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(txt)
			var rb := UI.mini_button("Revisar", _on_idea.bind(str(t2["measure"]), float(t2["value"])))
			rb.disabled = left <= 0
			row.add_child(rb)
			list.add_child(row)
	_log_block(list, law)

# ---------------------------------------------------------------- ventana «Redactar enmienda»
func _on_open_amend() -> void:
	_open_amend()

func _on_amend_measure(mid: String) -> void:
	_open_amend(mid, NAN)

func _on_idea(mid: String, val: float) -> void:
	_open_amend(mid, val)

func _on_am_area(aid: String) -> void:
	am_area = aid
	am_mid = ""
	am_val = NAN
	var ms := Policies.measures_of(aid)
	if not ms.is_empty():
		am_mid = str((ms[0] as Dictionary)["id"])
	_open_amend()

func _on_am_pick(mid: String) -> void:
	am_mid = mid
	am_val = NAN
	_open_amend()

func _on_am_value(v: float) -> void:
	am_val = v
	_open_amend()

func _on_am_remove() -> void:
	am_val = m.eco.value(am_mid)
	_open_amend()

func _on_am_close() -> void:
	shell.close_modal()

func _on_am_present() -> void:
	var law := _law()
	var term := m.congress.amend.make_term(law, am_mid, am_val)
	if term.is_empty():
		return
	var res := m.congress.amend.propose(law, term)
	var verdict := str(res.get("verdict", ""))
	if verdict == "accepted":
		Sfx.play("confirm")
	elif verdict == "rejected":
		Sfx.play("deny")
	shell.close_modal()
	am_val = NAN
	_after_amend(res)

func _gain_chip(mine: float) -> PanelContainer:
	if mine >= 0.14:
		return UI.chip("Mejora grande para ti", UI.GOOD, true)
	if mine >= 0.06:
		return UI.chip("Mejora notable para ti", UI.GOOD)
	if mine >= 0.015:
		return UI.chip("Mejora leve para ti", UI.GOOD)
	if mine <= -0.015:
		return UI.chip("Empeora tu postura", UI.BAD)
	return UI.chip("Apenas te afecta", UI.MUTED)

func _open_amend(mid: String = "", val: float = NAN) -> void:
	var law := _law()
	if law.is_empty():
		return
	var amd := m.congress.amend
	if mid != "":
		am_mid = mid
		am_val = val
	if am_mid == "" or Policies.measure(am_mid).is_empty():
		am_mid = ""
		am_val = NAN
		for k in (law["changes"] as Dictionary).keys():
			if not Policies.is_special(str(k)):
				am_mid = str(k)
				break
		if am_mid == "":
			var ms := Policies.measures_of(str(law["area"]))
			if not ms.is_empty():
				am_mid = str((ms[0] as Dictionary)["id"])
	var meas := Policies.measure(am_mid)
	if meas.is_empty():
		return
	am_area = str(meas.get("area", law["area"]))
	if is_nan(am_val):
		am_val = amd.value_in_law(law, am_mid)
	var col: VBoxContainer = shell.modal("Redactar una enmienda", 960.0, "A «%s» de %s. Elige la medida, fija el valor que quieres y mira cómo la recibirá el proponente." % [str(law["title"]), m.party_short(str(law["proposer"]))])
	var body := UI.hbox(14)
	col.add_child(body)
	# columna izquierda: áreas y medidas
	var lc := UI.vbox(8)
	lc.custom_minimum_size = Vector2(330, 0)
	body.add_child(lc)
	lc.add_child(UI.label("ÁREA", UI.FS_TINY, UI.MUTED, true))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 5)
	fl.add_theme_constant_override("v_separation", 5)
	for a in Policies.areas():
		var ad: Dictionary = a
		var aid := str(ad["id"])
		fl.add_child(UI.pill(str(ad["name"]), aid == am_area, _on_am_area.bind(aid), false, Color(str(ad.get("color", "#7C5CFC")))))
	lc.add_child(fl)
	lc.add_child(UI.label("MEDIDA", UI.FS_TINY, UI.MUTED, true))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 300)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lc.add_child(sc)
	var ml := UI.vbox(4)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(ml)
	for it in Policies.measures_of(am_area):
		var md: Dictionary = it
		var id2 := str(md["id"])
		var inl := (law["changes"] as Dictionary).has(id2)
		var inner := UI.select_row(ml, id2 == am_mid, _on_am_pick.bind(id2), UI.ACCENT, 40)
		var nm := UI.label(str(md["name"]), UI.FS_SMALL, UI.TEXT, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		inner.add_child(nm)
		if inl:
			inner.add_child(UI.chip("en la ley", UI.ACCENT))
		UI.pass_clicks(inner)
	# columna derecha: ficha y vista previa
	var rc := UI.vbox(8)
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rc)
	rc.add_child(UI.label(str(meas["name"]), UI.FS_H2, UI.TEXT, true))
	rc.add_child(UI.wrap_label(str(meas.get("desc", "")), UI.FS_SMALL, UI.MUTED))
	var cur := m.eco.value(am_mid)
	var here := amd.value_in_law(law, am_mid)
	var sl := PolicySlider.new()
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.setup(meas, cur, am_val, float(meas["min"]), float(meas["max"]), UI.D4_BLUE_D)
	sl.committed.connect(_on_am_value)
	rc.add_child(sl)
	var st := UI.hbox(14)
	st.add_child(UI.label("Hoy: %s" % Policies.value_text(meas, cur), UI.FS_SMALL, UI.MUTED))
	st.add_child(UI.label("En la ley: %s" % ("sin cambios" if is_equal_approx(here, cur) else Policies.value_text(meas, here)), UI.FS_SMALL, UI.MUTED))
	st.add_child(UI.label("Tu enmienda: %s" % Policies.value_text(meas, am_val), UI.FS_SMALL, UI.ACCENT, true))
	rc.add_child(st)
	var term := amd.make_term(law, am_mid, am_val)
	var pv := amd.preview(law, term)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(Color("#F6F9FE"), UI.D4_LINE, 4, 1, 12, 10))
	rc.add_child(box)
	var bv := UI.vbox(6)
	box.add_child(bv)
	if term.is_empty():
		bv.add_child(UI.wrap_label("Mueve el deslizador a un valor distinto del que ya tiene la ley para proponer un cambio.", UI.FS_BODY, UI.FAINT))
	else:
		bv.add_child(UI.wrap_label(str(term["text"]), UI.FS_BODY, UI.TEXT, true))
		var chips := UI.hbox(6)
		chips.add_child(_gain_chip(float(pv["mine"])))
		var theirs := float(pv["theirs"])
		var pshort := m.party_short(str(law["proposer"]))
		chips.add_child(UI.chip("A %s le sienta %s" % [pshort, "bien" if theirs >= 0.015 else ("regular" if theirs >= -float(pv["tol"]) else "mal")], UI.GOOD if theirs >= 0.015 else (UI.WARN if theirs >= -float(pv["tol"]) else UI.BAD)))
		bv.add_child(chips)
		var vtxt := "Es probable que la acepte."
		var vcol := UI.GOOD
		if str(pv["verdict"]) == "talk":
			vtxt = "No la aceptará tal cual, pero puede ofrecerte una transaccional."
			vcol = UI.WARN
		elif str(pv["verdict"]) == "reject":
			vtxt = "La rechazará: le desvirtúa demasiado la ley."
			vcol = UI.BAD
		bv.add_child(UI.wrap_label(vtxt, UI.FS_BODY, vcol, true))
	var acts := UI.hbox(8)
	acts.alignment = BoxContainer.ALIGNMENT_END
	if (law["changes"] as Dictionary).has(am_mid) and not is_equal_approx(am_val, cur):
		acts.add_child(UI.button("Retirar la medida", "ghost", _on_am_remove))
	acts.add_child(UI.button("Cerrar", "ghost", _on_am_close))
	var pb := UI.button("Presentar enmienda (%d disp.)" % amd.slots_left(law), "primary", _on_am_present)
	pb.disabled = term.is_empty() or amd.slots_left(law) <= 0
	acts.add_child(pb)
	col.add_child(acts)

func _counter_card(t: Dictionary, idx: int) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color(UI.WARN, 0.10), UI.WARN, 4, 1, 10, 8))
	var v := UI.vbox(5)
	pc.add_child(v)
	v.add_child(UI.label("TRANSACCIONAL PROPUESTA", UI.FS_TINY, UI.WARN, true))
	v.add_child(UI.wrap_label(str(t["text"]), UI.FS_BODY, UI.TEXT, true))
	var h := UI.hbox(6)
	h.add_child(UI.button("Aceptar", "good", _on_accept_counter.bind(idx)))
	h.add_child(UI.button("Descartar", "ghost", _on_dismiss_counter.bind(idx)))
	v.add_child(h)
	return pc

func _on_accept_counter(idx: int) -> void:
	_after_amend(m.congress.amend.accept_counter(_law(), idx))

func _on_dismiss_counter(idx: int) -> void:
	m.congress.amend.dismiss_counter(_law(), idx)
	_fill_all()

func _log_block(parent: Node, law: Dictionary) -> void:
	var log := m.congress.amend.log_of(law)
	if log.is_empty():
		return
	parent.add_child(UI.hsep())
	parent.add_child(UI.label("PASILLOS Y ACUERDOS", UI.FS_TINY, UI.MUTED, true))
	for i in range(maxi(0, log.size() - 7), log.size()):
		var e: Dictionary = log[i]
		var ok := bool(e.get("ok", false))
		parent.add_child(UI.wrap_label(("✔ " if ok else "✖ ") + str(e.get("text", "")), UI.FS_SMALL, UI.GOOD if ok else UI.MUTED))

# ---------------------------------------------------------------- votación: la crónica de cada grupo
func _side_feed() -> void:
	var c := UI.card(side_box, "Explicación de voto", "", UI.ACCENT)
	UI.expand_card(c)
	feed_scroll = ScrollContainer.new()
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(feed_scroll)
	feed_box = UI.vbox(6)
	feed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_scroll.add_child(feed_box)
	for e in feed:
		_add_feed_card(e as Dictionary, false)

func _add_feed_card(e: Dictionary, animate: bool) -> void:
	if feed_box == null or not is_instance_valid(feed_box):
		return
	var pid := str(e["id"])
	var vote := str(e["vote"])
	var col := UI.GOOD if vote == "yes" else (UI.BAD if vote == "no" else UI.MUTED)
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color(col, 0.07), Color(col, 0.6), 4, 1, 10, 8))
	var h := UI.hbox(10)
	pc.add_child(h)
	h.add_child(UI.leader_portrait(m, pid, 42, "happy" if vote == "yes" else ("angry" if vote == "no" else "neutral")))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(6)
	top.add_child(UI.party_tag(m, pid, UI.FS_BODY, true))
	top.add_child(UI.label("%d" % m.seats_of(pid), UI.FS_SMALL, UI.FAINT))
	top.add_child(UI.fill())
	if (result.get("followers", []) as Array).has(pid):
		var f := UI.chip("Te sigue", UI.ACCENT)
		f.tooltip_text = "Se abstenía, pero su buena relación contigo le hace seguir tu voto."
		top.add_child(f)
	top.add_child(_vote_chip(vote))
	v.add_child(top)
	if str(e.get("line", "")) != "":
		v.add_child(UI.wrap_label(str(e["line"]), UI.FS_SMALL, UI.MUTED))
	h.add_child(v)
	feed_box.add_child(pc)
	if animate and not fast:
		pc.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(pc, "modulate:a", 1.0, 0.3)
	if feed_scroll != null and is_instance_valid(feed_scroll):
		_scroll_down.call_deferred()

func _scroll_down() -> void:
	if feed_scroll != null and is_instance_valid(feed_scroll):
		feed_scroll.scroll_vertical = 100000

# ---------------------------------------------------------------- resultado
func _side_result(law: Dictionary) -> void:
	if str(result.get("kind", "")) == "interpelacion":
		_side_interpelacion()
		return
	var passed := bool(result.get("passed", false))
	var c := UI.card(side_box, "Resultado", "%d a favor · %d en contra" % [int(result.get("yes", 0)), int(result.get("no", 0))], UI.GOOD if passed else UI.BAD)
	UI.expand_card(c)
	var list := _scroll(c)
	var head := UI.hbox(8)
	head.add_child(UI.chip("Aprobada" if passed else "Rechazada", UI.GOOD if passed else UI.BAD, true))
	head.add_child(UI.chip(m.laws.required_text(law), UI.MUTED))
	list.add_child(head)
	var pv_word := {"yes": "a favor", "no": "en contra", "abstain": "abstención"}
	if str(result.get("player_vote", "")) != "" and not m.is_player(str(law["proposer"])):
		var rec := str(result.get("recommended", ""))
		var tail := ""
		if rec != "" and rec != str(result["player_vote"]):
			tail = " (tu ideología recomendaba %s)" % str(pv_word.get(rec, rec))
		list.add_child(UI.wrap_label("Tu grupo votó %s%s." % [str(pv_word.get(str(result["player_vote"]), "")), tail], UI.FS_BODY, UI.TEXT))
	var fol: Array = result.get("followers", [])
	if not fol.is_empty():
		var names: Array = []
		for f in fol:
			names.append(m.party_short(str(f)))
		list.add_child(UI.wrap_label("Te siguieron en tu voto por su buena relación: %s." % ", ".join(names), UI.FS_BODY, UI.ACCENT))
	for pl in result.get("pact_log", []):
		list.add_child(UI.wrap_label("Pacto: " + str(pl), UI.FS_SMALL, UI.ACCENT, true))
	if str(law.get("kind", "")) == "pnl":
		list.add_child(UI.wrap_label("Una PNL no cambia medidas: da visibilidad y retrata a quien vota en contra.", UI.FS_BODY, UI.MUTED))
	elif passed:
		list.add_child(UI.wrap_label("La ley entra en vigor: sus efectos se irán notando mes a mes en la economía y la sociedad.", UI.FS_BODY, UI.MUTED))
	else:
		list.add_child(UI.wrap_label("La iniciativa decae. Si era tuya, puedes reelaborarla en el Taller el mes que viene.", UI.FS_BODY, UI.MUTED))

func _side_interpelacion() -> void:
	var tier := str(result.get("tier", "flop"))
	var title := {"big": "Golpe de efecto", "ok": "El debate cuaja", "flop": "Sin pena ni gloria", "backfire": "Tiro por la culata"}
	var good := tier in ["big", "ok"]
	var c := UI.card(side_box, "Resultado del debate", "", UI.GOOD if good else UI.BAD)
	UI.expand_card(c)
	var list := _scroll(c)
	list.add_child(UI.label(str(title.get(tier, "")), UI.FS_H2, UI.GOOD if good else (UI.BAD if tier == "backfire" else UI.MUTED), true))
	list.add_child(UI.meter(float(result.get("score", 0.0)), 1.0, UI.GOOD if good else UI.WARN, 10))
	for ln in result.get("lines", []):
		list.add_child(UI.wrap_label("• " + str(ln), UI.FS_BODY, UI.TEXT))

# ================================================================ barra de acciones
func _fill_actions(law: Dictionary) -> void:
	UI.clear_children(action_box)
	var own := m.is_player(str(law["proposer"]))
	match phase:
		"intro":
			if str(law.get("kind", "")) == "interpelacion":
				action_box.add_child(UI.wrap_label("Sube a la tribuna y defiende tu interpelación.", UI.FS_BODY, UI.MUTED))
				action_box.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				action_box.add_child(UI.button("Intervenir en el Pleno", "primary", _on_interpelar, 240))
			elif m.congress.amend.supports(law):
				var l := UI.wrap_label("Antes de votar se abre el trámite de enmiendas: los grupos pueden pedir cambios a cambio de su apoyo.", UI.FS_BODY, UI.MUTED)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				action_box.add_child(l)
				if own:
					action_box.add_child(UI.button("Retirar", "ghost", _on_withdraw))
				action_box.add_child(UI.button("Abrir el trámite de enmiendas", "primary", _on_open_debate, 280))
			else:
				var l2 := UI.wrap_label("Esta iniciativa no admite enmiendas. Pasamos directamente a la votación.", UI.FS_BODY, UI.MUTED)
				l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				action_box.add_child(l2)
				action_box.add_child(UI.button("Pasar a la votación", "primary", _on_to_vote, 240))
		"debate":
			var l3 := UI.wrap_label("Cuando no queden cambios que negociar, cierra el trámite y vota.", UI.FS_BODY, UI.MUTED)
			l3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_box.add_child(l3)
			if own:
				action_box.add_child(UI.button("Retirar", "ghost", _on_withdraw))
			action_box.add_child(UI.button("Cerrar enmiendas y votar", "primary", _on_to_vote, 260))
		"vote":
			_vote_actions(law)
		"reveal":
			var l4 := UI.label("Votando…", UI.FS_LEAD, UI.TEXT, true)
			l4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_box.add_child(l4)
			action_box.add_child(UI.button("Saltar animación", "ghost", _on_skip))
		"result":
			var more := m.congress.stage() != "done"
			var l5 := UI.label("Resultado registrado.", UI.FS_BODY, UI.MUTED, true)
			l5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_box.add_child(l5)
			action_box.add_child(UI.button("Siguiente iniciativa →" if more else "Levantar la sesión", "primary", _on_next, 260))

func _vote_actions(law: Dictionary) -> void:
	if not m.congress.player_votes_this(law):
		var l := UI.wrap_label("Es tu iniciativa: tu grupo votará a favor.", UI.FS_BODY, UI.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_box.add_child(l)
		action_box.add_child(UI.button("Abrir la votación", "primary", _on_vote.bind("yes"), 240))
		return
	var rec := m.laws.recommended_vote(law)
	var hint := UI.vbox(0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_child(UI.label("Tu voto, %s" % m.party_short(m.pid()), UI.FS_LEAD, UI.TEXT, true))
	hint.add_child(UI.label("Tu ideología te inclina a votar: %s." % str(VOTE_WORDS.get(rec, "")).to_lower(), UI.FS_SMALL, UI.MUTED))
	action_box.add_child(hint)
	var tg := UI.mini_button("Previsión: %s" % ("sí" if show_forecast else "no"), _on_toggle_forecast)
	action_box.add_child(tg)
	var by := UI.button("A favor", "good", _on_vote.bind("yes"), 130)
	var bn := UI.button("En contra", "danger", _on_vote.bind("no"), 130)
	var ba := UI.button("Abstención", "secondary", _on_vote.bind("abstain"), 130)
	for b in [by, bn, ba]:
		(b as Button).custom_minimum_size = Vector2(130, 44)
	action_box.add_child(by)
	action_box.add_child(bn)
	action_box.add_child(ba)

func _on_toggle_forecast() -> void:
	show_forecast = not show_forecast
	_fill_all()

func _on_open_debate() -> void:
	m.congress.open_debate()
	phase = "debate"
	Sfx.play("click")
	_after_phase()

func _on_to_vote() -> void:
	phase = "vote"
	_after_phase()

func _after_phase() -> void:
	shell.refresh_chrome()
	# la franja de fases está fuera de las columnas: se reconstruye la pantalla completa (el hemiciclo se restaura)
	rebuild()
	if phase == "vote" and m.congress.player_votes_this(_law()):
		hall.pulse_id = m.pid()

func _on_withdraw() -> void:
	shell.confirm("Retirar la iniciativa", "Vuelve a tus borradores y recuperas el cupo del trimestre. Podrás reelaborarla en el Taller.", "Retirar", _do_withdraw, "danger")

func _do_withdraw() -> void:
	m.congress.withdraw_current()
	shell.toast("Iniciativa retirada: vuelve a tus borradores.", "neutral")
	_reset_ui()
	shell.refresh_chrome()
	rebuild()

func _on_skip() -> void:
	fast = true

func _on_next() -> void:
	_reset_ui()
	shell.refresh_chrome()
	rebuild()

func _on_interpelar() -> void:
	var law := _law()
	result = m.congress.resolve_current("")
	cur_law = law
	phase = "result"
	revealed = {}
	var tier := str(result.get("tier", "flop"))
	var good := tier in ["big", "ok"]
	shell.refresh_chrome()
	rebuild()
	hall.celebrate({"big": "GOLPE DE EFECTO", "ok": "BIEN DEBATIDO", "flop": "SIN PENA NI GLORIA", "backfire": "TIRO POR LA CULATA"}.get(tier, ""), good)
	Sfx.play("gavel" if good else "deny")

# ---------------------------------------------------------------- tu voto y la votación de los grupos
func _on_vote(v: String) -> void:
	var law := _law()
	player_choice = v
	result = m.congress.resolve_current(v)
	cur_law = law
	phase = "reveal"
	revealed = {}
	feed = []
	order = _parties_left_to_right()
	order.erase(m.pid())
	if m.seats_of(m.pid()) > 0:
		order.push_front(m.pid())
	pos = 0
	shell.refresh_chrome()
	rebuild()

func _run_reveal() -> void:
	if running:
		return
	running = true
	_fill_actions(cur_law)
	hall.pulse_id = ""
	if not fast:
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree():
			running = false
			return
	while pos < order.size():
		var pid := str(order[pos])
		_reveal_one(pid, str((result["by_party"] as Dictionary).get(pid, "abstain")))
		pos += 1
		if not fast:
			await get_tree().create_timer(REVEAL_SECS).timeout
			if not is_inside_tree():
				running = false
				return
	running = false
	if not fast:
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
	phase = "result"
	_apply_result_stamp(false)
	Sfx.play("gavel")
	shell.refresh_chrome()
	_fill_all()

func _reveal_one(pid: String, vote: String) -> void:
	revealed[pid] = vote
	var line := str((result.get("reasons", {}) as Dictionary).get(pid, ""))
	var e := {"id": pid, "vote": vote, "line": line}
	feed.append(e)
	hall.reveal(pid, vote, fast)
	_update_counts(true)
	_banner_text(m.party_name(pid), line, pid, vote)
	_add_feed_card(e, true)
	match vote:
		"yes": Sfx.play("confirm", 0.5)
		"no": Sfx.play("deny", 0.5)
		_: Sfx.play("click", 0.5)

func _apply_result_stamp(silent: bool) -> void:
	var passed := bool(result.get("passed", false))
	var text := "APROBADA" if passed else "RECHAZADA"
	if silent:
		hall.stamp = text
		hall.stamp_col = ParliamentHall.C_YES if passed else ParliamentHall.C_NO
		hall.stamp_p = 1.0
	else:
		hall.celebrate(text, passed)
	_update_counts(false)

# ================================================================ sesión levantada
func _done() -> void:
	var res := m.congress.results()
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(560, 0)
	row.add_child(left)
	var c := UI.card(left, "Resumen de la sesión", "trimestre %d" % m.turn(), UI.ACCENT)
	UI.expand_card(c)
	var list := _scroll(c)
	if res.is_empty():
		empty_note(list, "Este mes no se ha votado ninguna iniciativa.")
	for r in res:
		list.add_child(_done_row(r as Dictionary))
	left.add_child(UI.wrap_label("Pulsa SIGUIENTE MES para avanzar: lo aprobado empezará a notarse en la economía.", UI.FS_BODY, UI.MUTED))
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var hc := UI.card(right, "Hemiciclo", "sesión levantada", UI.GOOD)
	UI.expand_card(hc)
	hall = ParliamentHall.new()
	hall.player_id = m.pid()
	hall.entries = _hall_entries()
	var passed := 0
	for r2 in res:
		if bool((r2 as Dictionary).get("passed", false)) and not bool((r2 as Dictionary).get("withdrawn", false)):
			passed += 1
	hall.set_center("Sesión levantada", "%d iniciativa%s aprobada%s" % [passed, "" if passed == 1 else "s", "" if passed == 1 else "s"])
	hc.add_child(hall)

func _done_row(rd: Dictionary) -> Control:
	var law: Dictionary = rd["law"]
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UI.box(Color("#F6F9FE"), UI.D4_LINE, 4, 1, 12, 8))
	var h := UI.hbox(10)
	pc.add_child(h)
	var withdrawn := bool(rd.get("withdrawn", false))
	var passed := bool(rd.get("passed", false))
	var label := "Retirada" if withdrawn else ("Aprobada" if passed else "Rechazada")
	if str(rd.get("kind", "")) == "interpelacion":
		label = {"big": "Golpe de efecto", "ok": "Bien debatida", "flop": "Sin impacto", "backfire": "Culata"}.get(str(rd.get("tier", "")), "Debatida")
	h.add_child(UI.chip(label, UI.MUTED if withdrawn else (UI.GOOD if passed else UI.BAD), true))
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(str(law["title"]), UI.FS_BODY, UI.TEXT, true))
	var sub := "%s · %s" % [m.party_short(str(law["proposer"])), _kind_short(law)]
	if not withdrawn and str(rd.get("kind", "")) != "interpelacion":
		sub += " · %d a favor, %d en contra, %d abst." % [int(rd["yes"]), int(rd["no"]), int(rd["abstain"])]
	v.add_child(UI.label(sub, UI.FS_SMALL, UI.MUTED))
	h.add_child(v)
	return pc
