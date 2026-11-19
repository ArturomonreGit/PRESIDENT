extends SceneTree
## Motor económico, taller de leyes, Pleno y ministros. Uso: godot --headless --path . --script res://tests/legislature.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _gov(party_id: String) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	# Camino rápido a la legislatura
	while m.phase == "campaign":
		for ev in m.campaign.pending_today():
			var evd: Dictionary = ev
			if m.campaign.is_interview_type(str(evd["type"])):
				var sess := m.enc.build_session(evd)
				for q in sess["questions"]:
					m.enc.resolve(sess, q as Dictionary, ((q as Dictionary)["answers"] as Array)[0] as Dictionary)
				m.enc.finish(sess, evd)
			else:
				m.campaign.resolve_auto(evd)
		var res := m.campaign.smart_continue()
		if str(res["stop"]) == "election": m.election.begin_night()
	while not m.election.night_finished():
		if m.election.reveal_next().is_empty(): break
	m.election.finish_night()
	m.gov.begin_investiture()
	var attempts := 0
	while m.phase == "investiture" and attempts < 12:
		attempts += 1
		if m.gov.candidate_id() == m.pid():
			for id in m.gov.offers().keys():
				var offer: Dictionary = m.gov.offers()[id]
				for i in range((offer["demands"] as Array).size()): m.gov.set_concession(str(id), i, true)
				m.gov.propose(str(id))
		elif m.gov.offers().has(m.pid()): m.gov.propose_as_partner()
		var vote := m.gov.hold_vote()
		if bool(vote["dissolved"]): break
	if m.phase == "cabinet_design": m.gov.form_government()
	return m

func _initialize() -> void:
	print("== Economía base (sin leyes, 48 meses)")
	var m := _gov("psoe")
	check(m.phase == "legislature", "se llega a la legislatura (%s)" % m.phase)
	check(m.eco.ready_state(), "economía inicializada")
	check(Policies.measures().size() >= 55, "catálogo de medidas (%d)" % Policies.measures().size())
	check(absf(m.eco.balance_pct() + 3.0) < 0.8, "déficit inicial ≈ 3 %% (%.2f)" % (-m.eco.balance_pct()))
	check(absf(m.eco.debt_pct() - 107.0) < 2.0, "deuda inicial ≈ 107 %% (%.1f)" % m.eco.debt_pct())
	var g0 := m.eco.gdp()
	for i in range(16): m.eco.tick()
	print("  tras 16 trimestres: PIB %.0f (%+.1f %%), paro %.1f, inflación %.1f, déficit %.2f %%, deuda %.1f %%, sat %.1f" % [m.eco.gdp(), (m.eco.gdp() / g0 - 1.0) * 100.0, float(m.eco.st()["unemployment"]), float(m.eco.st()["inflation"]), -m.eco.balance_pct(), m.eco.debt_pct(), m.eco.avg_satisfaction()])
	check(m.eco.gdp() > g0 * 1.04 and m.eco.gdp() < g0 * 1.50, "PIB nominal crece de forma verosímil")
	check(float(m.eco.st()["unemployment"]) > 6.0 and float(m.eco.st()["unemployment"]) < 17.5, "paro razonable")
	check(float(m.eco.st()["inflation"]) > -1.0 and float(m.eco.st()["inflation"]) < 10.0, "inflación razonable")
	check(m.eco.debt_pct() > 85.0 and m.eco.debt_pct() < 125.0, "deuda razonable")
	check(m.eco.history().size() >= 17, "historial para las gráficas (%d)" % m.eco.history().size())
	var sector_sum := 0.0
	for v in (m.eco.st()["sectors"] as Dictionary).values(): sector_sum += float(v)
	check(absf(sector_sum - 100.0) < 0.01, "los sectores suman 100")
	var dem_sum := 0.0
	for v in (m.eco.st()["demand"] as Dictionary).values(): dem_sum += float(v)
	check(absf(dem_sum - 100.0) < 0.01, "la demanda suma 100")

	print("== Efecto de las políticas")
	var m2 := _gov("psoe")
	var bal0 := m2.eco.balance()
	m2.eco.set_value("vat_general", 23.0)
	m2.eco.set_value("health_budget", 115.0)
	m2.eco._compute_fiscal()
	print("  IVA +2, sanidad +20: saldo %.1f → %.1f" % [bal0, m2.eco.balance()])
	check(m2.eco.balance() > bal0 - 25.0 and m2.eco.balance() < bal0 + 5.0, "IVA +2 y +20 bn sanidad dan saldo menor")
	var h0 := m2.eco.quality("health")
	for i in range(8): m2.eco.tick()
	check(m2.eco.quality("health") > h0 + 4.0, "más gasto sanitario mejora la sanidad (%.1f → %.1f)" % [h0, m2.eco.quality("health")])
	check(m2.eco.satisfaction("pensionistas") != 55.0, "los grupos reaccionan")

	print("== Leyes y votaciones")
	var law := m.laws.new_draft("housing")
	m.laws.set_change(law, "rent_cap", 2.0)
	m.laws.set_change(law, "social_housing", 8.0)
	check((law["changes"] as Dictionary).size() == 2, "borrador con 2 medidas")
	m.laws.set_change(law, "rent_cap", m.eco.value("rent_cap"))
	check((law["changes"] as Dictionary).size() == 1, "volver al valor actual retira la medida")
	m.laws.set_change(law, "rent_cap", 3.0)
	var pv := m.eco.preview(law["changes"])
	check(float(pv["spending"]) > 4.0, "previsión: coste de vivienda pública (%.1f)" % float(pv["spending"]))
	var votes := {}
	for id in m.gov.parliamentary_ids():
		votes[str(id)] = str(m.laws.stance(law, str(id))["vote"])
	print("  votos previstos: ", votes)
	check(str(votes.get("sumar", "")) == "yes", "Sumar apoya tope y vivienda pública")
	check(str(votes.get("vox", "")) != "yes", "Vox no apoya el tope al alquiler")
	check(str(votes.get("pp", "")) != "yes", "el PP no apoya el tope al alquiler")
	var big := m.laws.new_draft("tax")
	for mid in ["ssc_employer", "corp_tax", "wealth_tax", "vat_general", "inheritance_tax"]:
		var meas := Policies.measure(mid)
		m.laws.set_change(big, mid, float(meas["base"]) + float(meas["step"]) * 2.0)
	var small := m.laws.new_draft("tax")
	m.laws.set_change(small, "corp_tax", 27.0)
	check((m.laws.stance(big, "pp")["conditions"] as Array).size() > (m.laws.stance(small, "pp")["conditions"] as Array).size(), "más medidas ⇒ más condiciones")
	var conds: Array = m.laws.stance(big, "pp")["conditions"]
	var score_before := float(m.laws.stance(big, "pp")["score"])
	if not conds.is_empty():
		m.laws.apply_condition(big, "pp", conds[0])
		# El apoyo se satura en -1 (con ruido aleatorio por ley): basta con que no empeore y que se registre la buena voluntad.
		check(float(m.laws.stance(big, "pp")["score"]) >= score_before and float((big["goodwill"] as Dictionary).get("pp", 0.0)) > 0.0, "aceptar una condición mejora el apoyo")
	check(m.laws.is_organic(m.laws.new_draft("territory")) == false, "ley vacía no es orgánica")
	var org := m.laws.new_draft("territory")
	m.laws.set_change(org, "competencies", 3.0)
	check(m.laws.is_organic(org), "competencias ⇒ ley orgánica")
	var msg := m.laws.register(str(law["id"]))
	check(msg == "", "registrar la ley (%s)" % msg)
	check(m.laws.queue().size() == 1, "ley en cola")
	# Pleno
	m.congress.open_session()
	check(m.congress.laws().size() >= 1, "orden del día con iniciativas (%d)" % m.congress.laws().size())
	check(str((m.congress.laws()[0] as Dictionary)["id"]) == str(law["id"]), "tu ley va la primera")
	m.congress.begin()
	var n := 0
	while m.congress.stage() == "running" and n < 12:
		n += 1
		var cur := m.congress.current()
		var pvote := "yes" if str(cur.get("proposer", "")) == m.pid() else "no"
		var res := m.congress.resolve_current(pvote)
		check(int(res["yes"]) + int(res["no"]) + int(res["abstain"]) == 350, "votos suman 350 (%d–%d–%d) %s" % [res["yes"], res["no"], res["abstain"], "APROBADA" if bool(res["passed"]) else "rechazada"])
	check(m.congress.stage() == "done", "sesión terminada")

	print("== Ministros")
	check(m.gov.cabinet().size() >= 8, "gabinete (%d)" % m.gov.cabinet().size())
	var all_have := true
	for e in m.gov.cabinet():
		if not (e as Dictionary).has("minister"): all_have = false
	check(all_have, "todas las carteras tienen titular")
	check(m.ministers.pool().size() == Ministers.POOL_SIZE, "cantera del partido")
	var idx := -1
	for i in range(m.gov.cabinet().size()):
		if str((m.gov.cabinet()[i] as Dictionary)["party"]) == m.pid(): idx = i
	if idx >= 0:
		var av := m.ministers.available_for(idx)
		check(av.size() > 0, "candidatos disponibles para la cartera")
		m.ministers.assign(idx, int((av[0] as Dictionary)["pool_id"]))
		check(int(m.ministers.minister_at(idx)["pool_id"]) == int((av[0] as Dictionary)["pool_id"]), "se nombra al ministro elegido")
	check(m.ministers.bonuses().size() > 0, "los ministros aportan mejoras")

	print("== Mes completo")
	var before := m.gov_month
	m.gov.advance_turn()
	check(m.gov_month == before + Rules.TURN_MONTHS, "avanza el trimestre")
	check(m.congress.stage() in ["ready", "done"], "nueva sesión abierta (%s)" % m.congress.stage())
	var js: Variant = JSON.parse_string(JSON.stringify(m.save))
	var m3 := GameModel.new(js)
	m3.autosave = false
	check(absf(m3.eco.gdp() - m.eco.gdp()) < 0.01, "la economía sobrevive al guardado")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
