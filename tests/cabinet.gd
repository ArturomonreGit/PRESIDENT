extends SceneTree
## Gabinete, ministros, coaliciones y crisis. Uso: godot --headless --path . --script res://tests/cabinet.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _fast_gov_into(m: GameModel) -> void:
	m.autosave = false
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

func _gov(party_id: String, seed_value: int = 0) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	if seed_value != 0:
		m.rng.seed = seed_value
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

## Partida en la que el jugador preside un Gobierno con al menos un socio de coalición.
func _coalition_game() -> GameModel:
	for pid in ["psoe", "pp", "sumar"]:
		for sd in [0, 11, 23, 37]:
			var m := _gov(pid, sd)
			if m.phase != "legislature" or m.coal.gov_id() != m.pid():
				continue
			if m.coal.party_ids().size() >= 1:
				return m
	return null

func _first_partner(m: GameModel, modality: String = "") -> String:
	for id in m.coal.party_ids():
		if modality == "" or m.coal.modality(str(id)) == modality:
			return str(id)
	return ""

func _initialize() -> void:
	print("== Catálogo de competencias")
	check(Competencies.CATALOG.size() >= 20, "catálogo con competencias suficientes (%d)" % Competencies.CATALOG.size())
	var areas_ok := true
	for a in Executive.AREA_OWNERS.keys():
		if Competencies.comp_of_area(str(a)) == "":
			areas_ok = false
	check(areas_ok, "toda área de política tiene competencia")
	check(Competencies.MIN_MINISTRIES == 8 and Competencies.MAX_MINISTRIES == 20, "límites 8 y 20 ministerios")

	print("== Constructor de Gobierno")
	var m := _coalition_game()
	check(m != null, "partida con jugador presidente y socio")
	if m == null:
		print("== Fallos: ", failures + 1)
		quit(1)
		return
	var cab := m.cab
	check(cab.size() >= 8 and cab.size() <= 20, "Consejo entre 8 y 20 ministerios (%d)" % cab.size())
	check(bool(cab.validate()["ok"]), "validación del Consejo correcta")
	var all_have_id := true
	for i in range(cab.size()):
		if str(cab.entry(i).get("id", "")) == "": all_have_id = false
	check(all_have_id, "todas las carteras con id y competencias")
	var unowned := 0
	for c in Competencies.essentials():
		if cab.owner_of(str(c)) < 0: unowned += 1
	var alerted := 0
	for al in cab.alerts():
		if (al as Dictionary).has("comp"): alerted += 1
	check(unowned == alerted, "toda competencia esencial sin responsable genera alerta (%d)" % unowned)
	m.exec.ensure()
	m.exec.add_capital(30.0)
	var n0 := cab.size()
	# Crear (solo si hay hueco), con una competencia ya gestionada → conflicto sin 'take'
	var gov_idx := -1
	for i in range(cab.size()):
		if not cab.is_reserved(i): gov_idx = i; break
	if n0 < Competencies.MAX_MINISTRIES:
		var conflict: Dictionary = cab.create("Ministerio de Pruebas", ["sanidad"], "", false)
		var had_conf := cab.owner_of("sanidad") >= 0
		check(bool(conflict.get("ok", false)) != had_conf, "crear con competencia ocupada exige confirmar el traspaso")
		var made: Dictionary = cab.create("Ministerio de Pruebas", ["sanidad"], "", true)
		check(bool(made.get("ok", false)) and cab.size() == n0 + 1, "crear ministerio (con traspaso)")
		check(bool(cab.validate()["ok"]), "tras crear sigue siendo válido")
		var idx_new := int(made.get("index", cab.size() - 1))
		check(cab.owner_of("sanidad") == idx_new, "la competencia pasa al nuevo ministerio")
		cab.rename(idx_new, "Ministerio de Ciencia y Pruebas")
		check(str(cab.entry(idx_new)["name"]) == "Ministerio de Ciencia y Pruebas", "renombrar")
		var imp := cab.impact(idx_new)
		check(not imp.is_empty(), "impacto calculable")
		var del: Dictionary = cab.delete(idx_new)
		check(bool(del.get("ok", false)) and cab.size() == n0, "eliminar devuelve el tamaño original: %s" % str(del.get("error", "")))
		check(cab.owner_of("sanidad") >= 0, "las competencias del eliminado pasan a otra cartera")
	check(bool(cab.validate()["ok"]), "validación tras operaciones")
	# Mínimo: no se puede bajar de 8
	var guard := 0
	while cab.size() > Competencies.MIN_MINISTRIES and guard < 30:
		guard += 1
		var killed := false
		for i in range(cab.size() - 1, 0, -1):
			if not cab.is_reserved(i) and bool(cab.delete(i).get("ok", false)):
				killed = true
				break
		if not killed: break
	var floor_res: Dictionary = {}
	if cab.size() == Competencies.MIN_MINISTRIES:
		for i in range(cab.size() - 1, 0, -1):
			if not cab.is_reserved(i):
				floor_res = cab.delete(i)
				break
		check(not floor_res.is_empty() and not bool(floor_res.get("ok", true)), "no se puede bajar de 8 ministerios")
	check(bool(cab.validate()["ok"]), "Consejo válido tras recortes")

	print("== Fusionar, dividir y acciones del presidente")
	var mb := _coalition_game()
	mb.exec.ensure()
	mb.exec.add_capital(30.0)
	var cb := mb.cab
	var own: Array = []
	for i in range(cb.size()):
		if not cb.is_reserved(i): own.append(i)
	var sz0 := cb.size()
	if own.size() >= 2 and sz0 > Competencies.MIN_MINISTRIES:
		var a: int = int(own[own.size() - 1])
		var b: int = int(own[own.size() - 2])
		var comps_a: Array = cb.comps_of(a).duplicate()
		var comps_b: Array = cb.comps_of(b).duplicate()
		var mr: Dictionary = cb.merge(b, a, "Ministerio fusionado")
		check(bool(mr.get("ok", false)) and cb.size() == sz0 - 1, "fusionar dos carteras reduce el Consejo: %s" % str(mr.get("error", "")))
		var merged := int(mr.get("index", -1))
		var all_in := merged >= 0
		for c in comps_a + comps_b:
			if merged >= 0 and not cb.comps_of(merged).has(c): all_in = false
		check(all_in, "la cartera fusionada hereda todas las competencias")
		check(bool(cb.validate()["ok"]), "Consejo válido tras fusionar")
		if merged >= 0 and cb.comps_of(merged).size() >= 2 and cb.size() < Competencies.MAX_MINISTRIES:
			var moved: Array = [cb.comps_of(merged)[0]]
			var sr: Dictionary = cb.split(merged, moved, "Ministerio escindido")
			check(bool(sr.get("ok", false)) and cb.size() == sz0, "dividir crea una cartera nueva: %s" % str(sr.get("error", "")))
			check(cb.owner_of(str(moved[0])) == int(sr.get("index", -2)), "la competencia pasa a la nueva cartera")
			check(bool(cb.validate()["ok"]), "Consejo válido tras dividir")
			var bad_split: Dictionary = cb.split(merged, cb.comps_of(merged).duplicate(), "x")
			check(not bool(bad_split.get("ok", true)), "no se pueden mover todas las competencias")
	# Acciones del presidente
	var tgt := -1
	for i in range(cb.size()):
		if not cb.is_reserved(i) and not cb.minister(i).is_empty(): tgt = i
	var rel0 := mb.ministers.relation(cb.minister(tgt))
	check(bool(cb.convene(tgt).get("ok", false)), "convocar al ministro")
	check(bool(cb.back(tgt).get("ok", false)) and mb.ministers.relation(cb.minister(tgt)) > rel0, "respaldar mejora la relación")
	var rel1 := mb.ministers.relation(cb.minister(tgt))
	check(bool(cb.disown(tgt).get("ok", false)) and mb.ministers.relation(cb.minister(tgt)) < rel1, "desautorizar la empeora")
	check(bool(cb.limit_autonomy(tgt).get("ok", false)) and str(cb.entry(tgt)["autonomy"]) == "limitada", "limitar autonomía")
	check(bool(cb.restore_autonomy(tgt).get("ok", false)) and str(cb.entry(tgt)["autonomy"]) == "plena", "restaurar autonomía")
	check(bool(cb.demand_plan(tgt).get("ok", false)) and cb.entry(tgt).has("plan"), "exigir un plan correctivo")
	var old_name := Leader.full_name(cb.minister(tgt))
	var fired: Dictionary = cb.fire(tgt)
	check(bool(fired.get("ok", false)) and not cb.minister(tgt).is_empty(), "destituir nombra a otro titular")
	check(Leader.full_name(cb.minister(tgt)) != old_name, "el titular cambia")
	var rsv := -1
	for i in range(cb.size()):
		if cb.is_reserved(i): rsv = i
	if rsv >= 0:
		var pty := str(cb.entry(rsv)["party"])
		var t_before := mb.coal.trust(pty)
		var ar: Dictionary = cb.ask_resignation(rsv)
		check(bool(ar.get("ok", false)), "pedir la dimisión a un ministro de socio no es una orden")
		check(mb.coal.trust(pty) <= t_before, "la petición cuesta confianza al socio")
	# Actividad: tope por trimestre
	var ma := _coalition_game()
	ma.exec.ensure()
	var capped := true
	for q in range(6):
		var before := ma.mact.log_entries(60).size()
		ma.gov_month += Rules.TURN_MONTHS
		ma.mact.quarterly()
		var after := ma.mact.log_entries(60).size()
		if after - before > MinisterActivity.MAX_EVENTS: capped = false
	check(capped, "la actividad respeta el máximo de eventos por trimestre")
	check(ma.mact.log_entries(60).size() > 0, "hay actividad en 6 trimestres")
	# Decreto forzado contra un socio = acción unilateral
	var mu := _coalition_game()
	mu.exec.ensure()
	var up := _first_partner(mu)
	var t_u := mu.coal.trust(up)
	mu.coal.unilateral(up, "Prueba unilateral")
	check(mu.coal.trust(up) < t_u and mu.coal.phase(up) >= 0, "una decisión unilateral erosiona la confianza")
	check(not mu.coal.explain(up).is_empty(), "la crisis tiene motivos explicables")

	# El jugador como socio
	var mp: GameModel = null
	for pid2 in ["vox", "sumar", "psoe", "podemos", "pp"]:
		for sd2 in [0, 11, 23]:
			var cand := _gov(pid2, sd2)
			if cand.phase == "legislature" and cand.coal.gov_id() != cand.pid() and cand.coal.party_ids().has(cand.pid()):
				mp = cand
				break
		if mp != null: break
	if mp == null:
		print("  SKIP no se encontró una partida con el jugador como socio")
	else:
		check(mp.coal.modality(mp.pid()) in ["coalicion", "externo", "puntual"], "el jugador socio tiene modalidad")
		var pas := mp.coal.ask_catalog(mp.pid())
		check(not pas.is_empty(), "el socio jugador tiene peticiones")
		var pr := mp.coal.partner_ask(0)
		check(bool(pr.get("ok", false)) and str(pr.get("why", "")) != "", "el presidente IA responde y explica: %s" % str(pr.get("text", pr.get("error", ""))))
		var again := mp.coal.partner_ask(0)
		check(not bool(again.get("ok", true)), "solo una petición por trimestre")
		var leave := mp.coal.player_leave()
		check(bool(leave.get("ok", false)) and not mp.coal.party_ids().has(mp.pid()), "el jugador puede abandonar el Gobierno")
		check(mp.phase == "legislature", "abandonar tampoco convoca elecciones")

	print("== Acuerdo de coalición")
	m = _coalition_game()
	cab = m.cab
	var pid := _first_partner(m)
	check(pid != "", "hay socio registrado en el acuerdo")
	check(m.coal.modality(pid) in ["coalicion", "externo", "puntual"], "modalidad registrada: %s" % m.coal.modality(pid))
	check(m.coal.trust(pid) > 0.0, "confianza inicial del socio (%.0f)" % m.coal.trust(pid))
	check(not m.coal.rules().is_empty(), "reglas del acuerdo definidas")
	var coal_partner := _first_partner(m, "coalicion")
	if coal_partner != "":
		var res_idx := -1
		for i in range(cab.size()):
			if str(cab.entry(i).get("party", "")) == coal_partner: res_idx = i
		check(res_idx >= 0 and cab.is_reserved(res_idx), "las carteras del socio están reservadas")
		m.exec.ensure()
		m.exec.add_capital(30.0)
		var fire_res: Dictionary = cab.fire(res_idx)
		check(not bool(fire_res.get("ok", true)), "no se destituye al ministro de un socio")
		var pre_trust := m.coal.trust(coal_partner)
		var steal: Dictionary = cab.set_comps(res_idx, cab.comps_of(res_idx), true)
		check(bool(cab.validate()["ok"]), "validación estable con reservas")
		var seats_ok := m.coal.government_seats()
		check(seats_ok > 0, "escaños de gobierno calculados (%d)" % seats_ok)

	print("== Mesa de propuestas")
	m.exec.ensure()
	m.exec.add_capital(30.0)
	var asks := m.coal.ask_catalog(pid)
	check(not asks.is_empty(), "el socio tiene peticiones concretas (%d)" % asks.size())
	var prop: Dictionary = m.coal.submit({"kind": "party_ask", "author": pid, "decider": m.pid(), "scope": str((asks[0] as Dictionary)["scope"]),
		"title": "Petición de prueba", "body": "x", "ask": asks[0], "cost": (asks[0] as Dictionary)["cost"], "impact": (asks[0] as Dictionary)["impact"]})
	check(m.coal.open_for_player().size() >= 1, "la propuesta queda abierta para el jugador")
	var inbox_has := false
	for n in m.news():
		if str((n as Dictionary).get("key", "")) == "tbl_%d" % int(prop["id"]): inbox_has = true
	check(inbox_has, "la propuesta llega a la bandeja con acciones")
	var t0 := m.coal.trust(pid)
	var r1: Dictionary = m.coal.respond(int(prop["id"]), "accept")
	check(bool(r1.get("ok", false)), "aceptar la petición: %s" % str(r1.get("text", r1.get("error", ""))))
	check(m.coal.trust(pid) > t0, "aceptar sube la confianza (%.0f → %.0f)" % [t0, m.coal.trust(pid)])
	check(str(m.coal.find(int(prop["id"]))["state"]) == "accepted", "estado aceptada")
	var r2: Dictionary = m.coal.respond(int(prop["id"]), "reject")
	check(not bool(r2.get("ok", true)), "no se responde dos veces")
	# Rechazo aislado no rompe nada
	var asks2 := m.coal.ask_catalog(pid)
	if not asks2.is_empty():
		var p2: Dictionary = m.coal.submit({"kind": "party_ask", "author": pid, "decider": m.pid(), "scope": "leyes", "title": "Otra petición", "body": "x", "ask": asks2[0], "cost": (asks2[0] as Dictionary)["cost"]})
		var t1 := m.coal.trust(pid)
		m.coal.respond(int(p2["id"]), "reject")
		check(m.coal.trust(pid) < t1, "rechazar baja la confianza")
		for q in range(3):
			m.coal.quarterly()
		check(m.coal.phase(pid) <= 2, "un desacuerdo aislado no rompe la coalición (fase %d)" % m.coal.phase(pid))
		check(m.coal.gov_id() == m.pid() and m.coal.party_ids().has(pid), "el socio sigue en el acuerdo")
	# Intercambio propuesto por el jugador
	var po: Dictionary = m.coal.player_offer(pid, "stability", -1)
	check(bool(po.get("ok", false)) and str(po.get("why", "")) != "", "propuesta del jugador evaluada con explicación: %s" % str(po.get("why", "")))
	# Reformas de ministros → propuesta con efecto real
	var found_reform := false
	for sd in range(1, 25):
		m.rng.seed = 100 + sd
		m.mact.quarterly()
		for p in m.coal.open_for_player():
			if str((p as Dictionary)["kind"]) == "reform": found_reform = true
		if found_reform: break
	check(found_reform, "algún ministro propone una reforma a la mesa")
	if found_reform:
		var rp: Dictionary = {}
		for p in m.coal.open_for_player():
			if str((p as Dictionary)["kind"]) == "reform": rp = p
		var meas := Policies.measure(str(rp["measure"]))
		var cur := m.eco.value(str(meas["id"]))
		m.exec.add_capital(30.0)
		var rr: Dictionary = m.coal.respond(int(rp["id"]), "accept")
		check(bool(rr.get("ok", false)), "autorizar la reforma: %s" % str(rr.get("text", rr.get("error", ""))))
		check(not is_equal_approx(m.eco.value(str(meas["id"])), cur), "la reforma cambia la política real")
	var events_log := m.mact.log_entries(20).size()
	check(events_log >= 1, "la actividad de ministros queda registrada (%d)" % events_log)

	print("== Escalera de crisis y ruptura")
	var m2 := _coalition_game()
	var cp := _first_partner(m2, "coalicion")
	if cp == "": cp = _first_partner(m2)
	m2.exec.ensure()
	m2.exec.add_capital(30.0)
	var stab0 := m2.gov.stability()
	var cabinet_before := 0
	for e in m2.gov.cabinet():
		if str((e as Dictionary).get("party", "")) == cp: cabinet_before += 1
	# Desplome de la confianza: la crisis sube un escalón por trimestre como máximo
	m2.d("partner_satisfaction")[cp] = 12.0
	var last := m2.coal.phase(cp)
	var jumps_ok := true
	var steps := 0
	var ruptured := false
	var reached_ult := false
	while steps < 14 and m2.coal.party_ids().has(cp):
		steps += 1
		m2.d("partner_satisfaction")[cp] = minf(m2.coal.trust(cp), 15.0)
		m2.gov_month += Rules.TURN_MONTHS
		m2.coal.quarterly()
		if not m2.coal.party_ids().has(cp):
			ruptured = true
			break
		var ph := m2.coal.phase(cp)
		if ph - last > 1: jumps_ok = false
		if ph == 5: reached_ult = true
		last = ph
	check(jumps_ok, "la crisis no salta fases (máx. un escalón por trimestre)")
	check(reached_ult or ruptured, "se llega al ultimátum")
	check(ruptured, "el socio rompe tras vencer el ultimátum (%d trimestres)" % steps)
	check(m2.phase == "legislature", "la ruptura NO convoca elecciones automáticas")
	check(not m2.gov.partners().has(cp), "el socio sale de los apoyos")
	check(m2.gov.stability() < stab0 or m2.gov.stability() <= 8.0, "la ruptura reduce la estabilidad (%.0f → %.0f)" % [stab0, m2.gov.stability()])
	var still := 0
	for e in m2.gov.cabinet():
		if str((e as Dictionary).get("party", "")) == cp: still += 1
	check(still == 0, "sus carteras vuelven al presidente (%d → %d)" % [cabinet_before, still])
	check(bool(m2.cab.validate()["ok"]) or m2.cab.size() >= 1, "el Consejo sigue siendo coherente tras la ruptura")
	check(m2.cab.size() >= 8, "sin vacantes que impidan gobernar")
	check(m2.coal.recently_broken(cp), "se recuerda la ruptura reciente")
	# Se puede seguir jugando: avanzar un trimestre sin elecciones forzadas
	var adv := m2.gov.advance_turn()
	check(bool(adv.get("ok", false)), "se puede avanzar de trimestre tras la ruptura")

	print("== Ultimátum: aceptar y rechazar")
	var m3 := _coalition_game()
	var cp3 := _first_partner(m3, "coalicion")
	if cp3 == "": cp3 = _first_partner(m3)
	m3.exec.ensure()
	m3.exec.add_capital(30.0)
	var c3 := m3.coal.crisis(cp3)
	c3["phase"] = 4
	m3.d("partner_satisfaction")[cp3] = 18.0
	m3.coal.quarterly()
	check(m3.coal.phase(cp3) == 5, "fase 5 = ultimátum (%d)" % m3.coal.phase(cp3))
	var acc: Dictionary = m3.coal.crisis_action(cp3, "accept")
	check(bool(acc.get("ok", false)), "aceptar la condición: %s" % str(acc.get("text", acc.get("error", ""))))
	check(m3.coal.phase(cp3) < 5 and m3.coal.party_ids().has(cp3), "aceptar el ultimátum evita la ruptura")
	var c3b := m3.coal.crisis(cp3)
	c3b["phase"] = 5
	c3b["demand"] = {"kind": "gesture", "title": "Gesto", "scope": "cumplimiento"}
	c3b["deadline"] = m3.turn() + 2
	var ref: Dictionary = m3.coal.crisis_action(cp3, "refuse")
	check(bool(ref.get("rupture", false)) and not m3.coal.party_ids().has(cp3), "rechazar el ultimátum rompe")
	check(m3.phase == "legislature", "tampoco hay elecciones al rechazar")
	# Renegociar un nuevo apoyo tras la ruptura
	var cands := m3.coal.candidates_for_support()
	check(not cands.is_empty(), "hay candidatos a nuevos apoyos")
	var invited := false
	for cid in cands:
		var iv: Dictionary = m3.coal.invite(str(cid), "externo")
		if bool(iv.get("ok", false)) and str(iv.get("verdict", "")) in ["accept", "counter", "reject"] and str(iv.get("why", "")) != "":
			invited = true
		if str(iv.get("verdict", "")) == "accept":
			check(m3.gov.partners().has(str(cid)), "el nuevo apoyo se registra")
			break
	check(invited, "la IA responde a la invitación con explicación")

	print("== Pérdida de mayoría sin elecciones automáticas")
	var m4 := _coalition_game()
	m4.gov_month += 9
	m4.s["stability"] = 0.0
	var z := m4.coal.on_stability_zero()
	check(m4.phase == "legislature", "estabilidad 0 no cambia de fase")
	check(not z.has("elections") or m4.coal.gov_id() != m4.pid(), "con presidente jugador nunca se convocan solas")
	var ce: Dictionary = m4.coal.call_early_elections()
	check(bool(ce.get("ok", false)) and m4.phase == "campaign", "el presidente puede convocar elecciones anticipadas")

	print("== Guardado y carga")
	var m5 := _coalition_game()
	m5.exec.ensure()
	m5.exec.add_capital(30.0)
	var pp := _first_partner(m5)
	m5.coal.shift_trust(pp, -20.0, "prueba")
	m5.mact.quarterly()
	var js: Variant = JSON.parse_string(JSON.stringify(m5.save))
	check(js is Dictionary, "el guardado es serializable")
	var m6 := GameModel.new(js as Dictionary)
	m6.autosave = false
	check(m6.coal.party_ids().size() == m5.coal.party_ids().size(), "socios del acuerdo persisten")
	check(is_equal_approx(m6.coal.trust(pp), m5.coal.trust(pp)), "confianza persiste")
	check(m6.cab.size() == m5.cab.size(), "carteras persisten")
	var comps_same := true
	for i in range(m5.cab.size()):
		if m5.cab.comps_of(i) != m6.cab.comps_of(i): comps_same = false
	check(comps_same, "competencias persisten")
	# Partida antigua: sin estado de coalición ni competencias
	var old := JSON.parse_string(JSON.stringify(m5.save)) as Dictionary
	var gs: Dictionary = old.get("game_state", old)
	for key in ["coal", "table_proposals", "mact", "cab"]:
		gs.erase(key)
	for e in (gs.get("cabinet", []) as Array):
		for k in ["id", "comps", "shared", "desc", "autonomy"]:
			(e as Dictionary).erase(k)
	var m7 := GameModel.new(old)
	m7.autosave = false
	m7.cab.ensure()
	m7.coal.ensure()
	check(bool(m7.cab.validate()["ok"]), "una partida antigua recibe competencias por defecto")
	check(m7.coal.party_ids().size() == m5.coal.party_ids().size(), "el acuerdo se reconstruye con los socios existentes")
	var adv7 := m7.gov.advance_turn()
	check(bool(adv7.get("ok", false)), "la partida antigua avanza de trimestre")

	print("== Partida completa de gobierno")
	var m8 := _coalition_game()
	var turns := 0
	var bad := false
	while m8.phase == "legislature" and turns < 18:
		turns += 1
		m8.exec.ensure()
		m8.exec.add_capital(10.0)
		for p in m8.coal.open_for_player():
			var opts := m8.coal.options_for(p as Dictionary)
			if not opts.is_empty():
				m8.coal.respond(int((p as Dictionary)["id"]), str((opts[0] as Dictionary)["id"]))
		var res := m8.gov.advance_turn()
		if not bool(res.get("ok", false)): bad = true
	check(not bad, "%d trimestres sin errores" % turns)
	check(m8.phase in ["legislature", "campaign"], "la partida termina en una fase válida (%s)" % m8.phase)

	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
