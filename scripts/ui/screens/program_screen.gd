class_name ProgramScreen
extends Screen
## Programa electoral: obligatorio al empezar cada campaña. Se redacta por áreas añadiendo medidas concretas con el valor
## que prometes; los votantes lo valoran y, si gobiernas, se mide su cumplimiento.


func wants_full() -> bool:
	return m.phase == "campaign"

func build() -> void:
	m.eco.ensure()
	var mf := m.manifesto
	if m.phase == "campaign":
		_build_editor(mf)
	else:
		_build_tracker(mf)

# ================================================================ redacción (campaña)
func _build_editor(mf: Manifesto) -> void:
	var locked := mf.locked()
	var hud := UI.hbox(10)
	hud.custom_minimum_size = Vector2(0, 46)
	add_child(hud)
	var fill := func() -> void:
		_fill_hud(hud, mf, locked)
	fill.call()
	var br := PolicyBrowser.create(shell, m, "program", [], fill, locked)
	add_child(br)

func _fill_hud(hud: HBoxContainer, mf: Manifesto, locked: bool) -> void:
	UI.clear_children(hud)
	var fb := mf.fiscal_bn()
	var res := mf.resonance()
	var off := mf.off_line().size()
	hud_stat(hud, "Promesas", "%d  (mín. %d)" % [mf.count(), Manifesto.MIN_PROMISES], UI.GOOD if mf.count() >= Manifesto.MIN_PROMISES else UI.WARN)
	hud_stat(hud, "Áreas tocadas", "%d / %d  (mín. %d)" % [mf.areas_used().size(), Policies.areas().size(), Manifesto.MIN_AREAS], UI.GOOD if mf.areas_used().size() >= Manifesto.MIN_AREAS else UI.WARN)
	hud_stat(hud, "Impacto fiscal", "%s bn €  ·  %s %% PIB" % [UI.signed(fb, 1), UI.signed(mf.fiscal_pct(), 2)], UI.GOOD if fb >= -5.0 else (UI.WARN if fb >= -20.0 else UI.BAD))
	hud_stat(hud, "Tirón electoral", UI.signed(res * 100.0, 0), UI.delta_color(res, 0.05), "De -100 a +100")
	hud_stat(hud, "Línea del partido", "Coherente" if off == 0 else "%d fuera de línea" % off, UI.GOOD if off == 0 else UI.WARN, "Promesas que chocan con tu ideología")
	hud.add_child(UI.fill())
	if locked:
		hud.add_child(UI.chip("Programa firmado · tus compromisos ya son públicos", UI.GOOD, true))
		return
	var tone_box := UI.hbox(4)
	tone_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tone_box.add_child(UI.label("TONO", UI.FS_TINY, Color("#3B6A99"), true))
	for key in Rules.CAMPAIGN_TONES.keys():
		var tone: Dictionary = Rules.CAMPAIGN_TONES[key]
		var k := str(key)
		var active := str(m.s.get("tone", "contrast")) == k
		var tb := UI.pill(str(tone["name"]), active, func() -> void:
			m.campaign.set_tone(k)
			m.save_now()
			_fill_hud(hud, mf, locked), false, UI.PILL_SUB)
		tb.tooltip_text = str(tone["desc"])
		tone_box.add_child(tb)
	hud.add_child(tone_box)
	var sug := UI.button("Borrador sugerido", "secondary", func() -> void:
		mf.suggest()
		m.save_now()
		rebuild())
	sug.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(sug)
	var clr := UI.button("Vaciar", "ghost", func() -> void:
		mf.clear()
		PolicyBrowser.program_pending.clear()
		rebuild())
	clr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(clr)
	var do_sign := func() -> void:
		var r := mf.sign()
		if bool(r.get("ok", false)):
			m.save_now()
			shell.toast("Programa presentado. ¡Arranca la campaña!", "good")
			shell.refresh()
		else:
			shell.toast(str(r.get("error", "")), "bad")
	var sign_b := UI.button("FIRMAR Y PRESENTAR", "good", do_sign, 190)
	sign_b.custom_minimum_size = Vector2(190, 40)
	sign_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sign_b.disabled = not mf.ready()
	sign_b.tooltip_text = "Programa listo para firmar." if mf.ready() else "Aún no puedes firmar: %s." % mf.missing_text()
	hud.add_child(sign_b)

# ================================================================ seguimiento (legislatura y otras fases)
func _build_tracker(mf: Manifesto) -> void:
	header("Programa electoral", "Lo que prometiste en campaña frente a lo que has hecho. Los votantes lo tendrán en cuenta en las próximas elecciones.")
	if mf.count() == 0:
		var c0 := UI.card(self, "Sin programa registrado", "", UI.MUTED)
		empty_note(c0, "Esta partida no tiene promesas registradas. El próximo programa se redactará al empezar la siguiente campaña.")
		return
	var ratio := mf.kept_ratio()
	var governs := m.role() == "government"
	var dis := mf.disappointment()
	kpi_row([
		{"title": "Cumplimiento", "value": "%.0f%%" % (ratio * 100.0), "sub": "promedio de tus promesas", "color": UI.GOOD if ratio >= 0.6 else (UI.WARN if ratio >= 0.3 else UI.BAD)},
		{"title": "Decepción de los votantes", "value": "%.0f%%" % (dis * 100.0), "sub": "esperado a estas alturas: %.0f%%" % (mf.expected_progress() * 100.0), "color": UI.GOOD if dis < 0.1 else (UI.WARN if dis < 0.3 else UI.BAD)},
		{"title": "Promesas", "value": "%d" % mf.count(), "sub": "en %d áreas" % mf.areas_used().size(), "color": UI.TEXT},
		{"title": "Cumplidas", "value": "%d" % mf.report().filter(func(r): return float(r["progress"]) >= 0.99).size(), "sub": "completas", "color": UI.GOOD},
		{"title": "Tu papel", "value": "Gobierno" if governs else ("Socio" if m.role() == "partner" else "Oposición"),
			"sub": "Cumples con leyes y decretos" if governs else "Sólo puedes cumplir desde el Gobierno", "color": UI.TEXT},
	])
	if dis >= 0.1:
		var cw := UI.card(self, "Tus votantes se sienten defraudados" if dis >= 0.3 else "Tus votantes empiezan a impacientarse", "", UI.BAD if dis >= 0.3 else UI.WARN)
		cw.add_child(UI.wrap_label("Se esperaba que ya estuviera cumplido el %.0f %% del programa y no es así. Cada trimestre de retraso erosiona la confianza y el apoyo del partido en las encuestas; al llegar las elecciones se te pedirán cuentas." % (mf.expected_progress() * 100.0), UI.FS_BODY, UI.TEXT))
		cw.add_child(UI.button("Ir al Taller de leyes", "primary", func() -> void: shell.go("laws")))
	var c := UI.card(self, "Estado de tus promesas", "De menos a más cumplidas", UI.ACCENT)
	for it in mf.report():
		var d: Dictionary = it
		var meas := Policies.measure(str(d["id"]))
		var row := UI.hbox(10)
		var nm := UI.label(str(d["name"]), UI.FS_BODY, UI.TEXT, true)
		nm.custom_minimum_size = Vector2(230, 0)
		nm.clip_text = true
		row.add_child(nm)
		var pr := float(d["progress"])
		var bar := UI.meter(pr * 100.0, 100.0, UI.GOOD if pr >= 0.99 else (UI.WARN if pr > 0.0 else UI.BAD), 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var txt := UI.label("%s → %s  (hoy %s)" % [Policies.value_text(meas, float(d["from"])), Policies.value_text(meas, float(d["to"])), Policies.value_text(meas, float(d["now"]))], UI.FS_SMALL, UI.MUTED)
		txt.custom_minimum_size = Vector2(300, 0)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(txt)
		var bs := str(d["bill_state"])
		if bool(d["late"]) and pr < 0.99:
			row.add_child(UI.chip("Con retraso", UI.BAD))
		elif bs == "passed" or pr >= 0.99:
			row.add_child(UI.chip("Cumplida", UI.GOOD))
		elif bs == "registered":
			row.add_child(UI.chip("En el Congreso", UI.ACCENT))
		elif bs == "rejected":
			row.add_child(UI.chip("Rechazada", UI.WARN))
		else:
			row.add_child(UI.chip("Sin registrar", UI.MUTED))
		c.add_child(row)
	var prev: Dictionary = m.d("manifesto_prev")
	if not prev.is_empty():
		var c2 := UI.card(self, "Legislatura anterior", "", UI.FAINT)
		c2.add_child(UI.wrap_label("Cumpliste de media el %.0f%% de tus %d promesas." % [float(prev.get("ratio", 0.0)) * 100.0, int(prev.get("count", 0))], UI.FS_BODY, UI.MUTED))
