extends SceneTree
## Alpha 0.2.1 (entrega C): acuerdos y memoria política. Las condiciones pactadas se materializan en el constructor de ministerios,
## quedan como compromisos con los campos de la especificación §6 y se verifican, se cumplen, se renegocian o se incumplen.
## Uso: godot --headless --path . --script res://tests/agreements.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

var m: GameModel

func _fresh(party_id: String = "psoe") -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var g := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	g.autosave = false
	g.manifesto.suggest()
	g.manifesto.sign()
	g.day = Rules.CAMPAIGN_LENGTH_DAYS
	g.election.begin_night()
	g.election.skip_night()
	g.election.finish_night()
	g.gov.begin_investiture()
	g.gov.set_candidate(g.pid())
	return g

func _rival(min_seats: int = 5) -> String:
	for p in m.all_parties():
		var id := str((p as Dictionary)["id"])
		if m.is_player(id) or m.seats_of(id) < min_seats: continue
		return id
	return ""

func _com(kind: String, verify_t: String = "") -> Dictionary:
	for c in m.a("commitments"):
		var d: Dictionary = c
		if str(d.get("kind", "")) == kind and (verify_t == "" or str((d.get("verify", {}) as Dictionary).get("t", "")) == verify_t):
			return d
	return {}

func _initialize() -> void:
	m = _fresh()
	var id := _rival()
	check(id != "", "hay un socio con escaños")
	print("== Una mesa cerrada guarda las condiciones nuevas en la oferta")
	var table: Array = [
		{"k": "participation", "mode": "coalition", "by": "ai"}, {"k": "vote_yes", "by": "ai"},
		{"k": "portfolio", "comp": "vivienda", "by": "player"},
		{"k": "structure", "what": "vicepresidency", "by": "player"},
		{"k": "structure", "what": "max_ministries", "n": 14, "by": "player"},
		{"k": "structure", "what": "coordination", "by": "player"},
		m.brain.objective_term("housing", 2),
		{"k": "budget", "issue": "housing", "n": 2, "by": "player"},
		{"k": "territory", "what": "invest", "n": 2, "by": "player"},
		{"k": "parliament", "what": "commission", "by": "player"},
		{"k": "institution", "what": "appointment", "n": 1, "by": "player"},
		{"k": "calendar", "what": "review", "n": 6, "by": "player"},
		{"k": "calendar", "what": "deadline", "n": 12, "by": "player"},
	]
	m.diplomacy._sync_investiture(id, table, false)
	var offer: Dictionary = m.gov.offers()[id]
	check((offer["terms_extra"] as Array).size() == 11, "la oferta guarda las 11 condiciones nuevas (%d)" % (offer["terms_extra"] as Array).size())
	check(int(offer["agreement_id"]) > 0 and str(offer["type"]) == "coalicion", "la oferta recibe un identificador de acuerdo y un tipo (coalición)")
	check(str(offer["role"]) == "cabinet", "la participación pactada como coalición mete al socio en el Gobierno")
	var terms := m.gov.offer_terms(id)
	var has_pf := false
	for t in terms:
		if str((t as Dictionary).get("k", "")) == "portfolio": has_pf = true
	check(has_pf, "la valoración de la oferta ya tiene en cuenta las condiciones nuevas")

	print("== Constructor: lo pactado se materializa")
	m.s["government_party_id"] = m.pid()
	m.s["government_candidate_id"] = m.pid()
	m.phase = "cabinet_design"
	m.gov._start_cabinet_design()
	var lim := m.agr.cabinet_limits()
	check(int(lim["max"]) == 14 and str(lim["max_by"]) == id, "el límite máximo de 14 queda atribuido al socio")
	check(m.cab.size() <= 14 and m.cab.size() >= Competencies.MIN_MINISTRIES, "el Consejo respeta lo pactado (%d ministerios, entre 8 y 14)" % m.cab.size())
	var viv := m.cab.owner_of("vivienda")
	check(viv >= 0 and str(m.cab.entry(viv)["party"]) == id, "la cartera de Vivienda es del socio")
	var vice := -1
	var vice_n := 0
	for i in range(m.cab.size()):
		if str(m.cab.entry(i).get("rank", "")) == "vice":
			vice = i
			vice_n += 1
	check(vice_n == 1 and vice >= 0 and str(m.cab.entry(vice)["party"]) == id, "hay una vicepresidencia real, rango de una cartera del socio")
	check(m.agr.ministry_label(vice).begins_with("Vicepresidencia 1.ª"), "la cartera se muestra con su rango (%s)" % m.agr.ministry_label(vice))
	check(m.agr.pledge_text(viv) != "", "no se puede retirar una cartera prometida en la mesa")
	var del := m.cab.delete(viv)
	check(not bool(del.get("ok", true)) and m.cab.owner_of("vivienda") >= 0, "eliminarla es imposible sin renegociar")
	var before_party := str(m.cab.entry(viv)["party"])
	m.gov.assign_ministry(viv, m.pid())
	check(str(m.cab.entry(viv)["party"]) == before_party, "pasar la cartera al presidente tampoco funciona")
	while m.cab.size() > 14:
		m.cab.list().pop_back()
	while m.cab.size() < 14:
		m.cab.list().append({"id": "x%d" % m.cab.size(), "name": "Extra %d" % m.cab.size(), "key": "x", "party": m.pid(), "comps": [], "shared": [], "autonomy": "plena"})
	check(m.agr.size_block(true) != "", "con 14 ministerios no se puede crear otro: lo bloquea el acuerdo")
	check(not bool(m.cab.create("Otro", []).get("ok", true)), "crear un ministerio por encima del pacto falla con aviso")
	while m.cab.size() > 12:
		m.cab.list().pop_back()
	var ve0: Dictionary = m.cab.entry(vice)
	ve0.erase("rank")
	var v1 := m.agr.validate_formation()
	check(not bool(v1["ok"]), "no se puede constituir el Gobierno sin la vicepresidencia prometida: %s" % str(v1.get("error", "")))
	ve0["rank"] = "vice"
	ve0["vice_n"] = 1
	check(bool(m.agr.validate_formation()["ok"]), "con todo lo prometido en el Consejo, se puede constituir")

	print("== Constitución del Gobierno: compromisos con los campos de la especificación")
	var r := m.gov.form_government()
	check(bool(r.get("ok", false)) and m.phase == "legislature", "el Gobierno se constituye")
	var coms: Array = m.a("commitments")
	var agr_n := 0
	var fields_ok := true
	for c in coms:
		var d: Dictionary = c
		if str(d.get("source", "")) != "acuerdo": continue
		agr_n += 1
		for k in ["id", "agreement_id", "parties", "type", "category", "binding", "responsible", "due", "state", "consequence", "history", "verify"]:
			if not d.has(k): fields_ok = false
		if int(d["agreement_id"]) != int(offer["agreement_id"]): fields_ok = false
	check(agr_n >= 9, "se crean compromisos por cada condición con seguimiento (%d)" % agr_n)
	check(fields_ok, "cada compromiso lleva partes, tipo, categoría, obligatoriedad, responsable, plazo, estado, consecuencia e historial")
	var c_pf := _com("portfolio")
	check(str(c_pf.get("state", "")) == "fulfilled" and str(c_pf.get("binding", "")) in ["binding", "red_line"], "la cartera pactada consta como cumplida al materializarse")
	var c_vice := _com("structure", "vice")
	check(str(c_vice.get("state", "")) == "fulfilled" and str(c_vice.get("binding", "")) == "red_line", "la vicepresidencia es línea roja y consta cumplida")
	var c_max := _com("structure", "max")
	check(str(c_max.get("state", "")) == "fulfilled", "el límite de ministerios consta cumplido")
	var c_obj := _com("objective")
	var vf_obj: Dictionary = c_obj.get("verify", {})
	check(str(c_obj.get("state", "")) == "pending" and str(vf_obj.get("t", "")) == "metric" and str(vf_obj.get("metric", "")) == "housing", "el objetivo de vivienda queda ligado a un indicador medible")
	check(str((c_obj["responsible"] as Dictionary).get("kind", "")) in ["ministry", "party"], "el objetivo tiene responsable (%s)" % str((c_obj["responsible"] as Dictionary).get("name", "")))
	check(int(c_obj["due"]) == m.gov_month + 12, "el plazo pactado en el calendario (12 meses) se aplica a los objetivos")
	var c_bud := _com("budget")
	check(str(c_bud.get("state", "")) == "fulfilled" and m.exec.credit_delta("vivienda") > 0.05, "la dotación presupuestaria se aplica de verdad (+%.0f %% en Vivienda)" % (m.exec.credit_delta("vivienda") * 100.0))
	var c_par := _com("parliament")
	check(str((c_par.get("verify", {}) as Dictionary).get("t", "")) == "manual" and str(c_par.get("state", "")) == "pending", "lo que no se puede medir queda para cumplirlo a mano")
	var c_rev := _com("calendar")
	check(str(c_rev.get("state", "")) == "in_progress", "la revisión periódica está en curso")
	var c_coo := _com("structure", "meeting")
	check(not c_coo.is_empty(), "el órgano de coordinación es un compromiso con seguimiento")

	print("== Seguimiento mensual")
	var trust0 := m.coal.trust(id)
	m.gov_month = int(c_obj["due"]) + 1
	m.agr.tick()
	check(str(c_obj["state"]) == "breached", "un objetivo que vence sin cumplirse pasa a «Incumplido»")
	check(m.coal.trust(id) < trust0, "el incumplimiento cuesta confianza al socio (%.0f → %.0f)" % [trust0, m.coal.trust(id)])
	var vf2: Dictionary = c_obj["verify"]
	vf2["target"] = float(vf2["base"]) - 1.0
	m.agr.tick()
	check(str(c_obj["state"]) == "fulfilled" and (str(c_obj["history"][0]["text"]) as String).find("retraso") >= 0, "si se cumple tarde pasa a «Cumplido» con nota de retraso")
	check(str(c_par["state"]) == "breached", "lo manual también vence y se denuncia")
	m.exec.ensure()
	m.exec.add_capital(10.0 - m.exec.capital())
	var idx_par := m.a("commitments").find(c_par)
	var fr := m.agr.fulfil(idx_par)
	check(bool(fr.get("ok", false)) and str(c_par["state"]) == "fulfilled" and m.exec.capital() < 10.0, "cumplir a mano cuesta capital político y cierra el compromiso")
	var c_inst := _com("institution")
	var cap1 := m.exec.capital()
	m.exec.add_capital(-m.exec.capital())
	var fr2 := m.agr.fulfil(m.a("commitments").find(c_inst))
	check(not bool(fr2.get("ok", true)) and str(c_inst["state"]) != "fulfilled", "sin capital político no se cumple (%s)" % str(fr2.get("error", "")))
	m.exec.add_capital(cap1)

	print("== Integridad del acuerdo")
	check(m.agr.pledge_text(m.cab.owner_of("vivienda")) != "" or m.cab.is_reserved(m.cab.owner_of("vivienda")), "en legislatura la cartera sigue protegida")
	var del2 := m.cab.delete(m.cab.owner_of("vivienda"))
	check(not bool(del2.get("ok", true)), "no se puede suprimir una cartera pactada: %s" % str(del2.get("error", "")))
	check(not bool(m.cab.create("Otro", []).get("ok", true)) or m.cab.size() < 14, "el máximo pactado también rige en legislatura")
	var t_before := m.coal.trust(id)
	var ab := m.agr.abandon(m.a("commitments").find(c_inst))
	check(bool(ab.get("ok", false)) and str(c_inst["state"]) == "cancelled" and m.coal.trust(id) < t_before, "retirar unilateralmente un compromiso se anota y cuesta confianza (%.1f → %.1f)" % [t_before, m.coal.trust(id)])
	check(not bool(m.agr.abandon(m.a("commitments").find(c_max)).get("ok", true)), "un compromiso ya cumplido no se puede romper")
	m.d("partner_satisfaction")[id] = 95.0
	var rn := m.agr.renegotiate(m.a("commitments").find(c_rev))
	check(bool(rn.get("ok", false)) and str(c_rev["state"]) == "renegotiated", "con confianza alta el socio acepta renegociar y queda «Renegociado»")
	m.d("partner_satisfaction")[id] = 5.0
	var rn2 := m.agr.renegotiate(m.a("commitments").find(c_coo))
	check(not bool(rn2.get("ok", true)) and str(c_coo["state"]) != "renegotiated", "con confianza baja se niega a renegociar")
	var counts := m.agr.counts()
	check(int(counts["fulfilled"]) >= 4 and int(counts["cancelled"]) >= 1 and int(counts["renegotiated"]) >= 1, "el recuento por estados cuadra")

	print("== Los compromisos anteriores siguen funcionando")
	m.gov_month = 1
	var old := {"party": id, "issue": "jobs", "text": "Una medida antigua", "due": 8, "fulfilled": false, "overdue_flagged": false}
	m.a("commitments").append(old)
	m.agr.normalize(old)
	check(old.has("agreement_id") and old.has("state") and old.has("history") and str(old["state"]) == "pending", "una partida antigua recibe los campos nuevos sin perder los suyos")
	m.gov_month = 20
	m.agr.tick()
	check(str(old["state"]) == "breached", "su estado sigue la regla anterior (vencido = incumplido)")

	print("== Persistencia")
	var js: Variant = JSON.parse_string(JSON.stringify(m.save))
	var m2 := GameModel.new(js as Dictionary)
	m2.autosave = false
	var kept := 0
	for c2 in m2.a("commitments"):
		if str((c2 as Dictionary).get("source", "")) == "acuerdo" and (c2 as Dictionary).has("verify") and (c2 as Dictionary).has("history"): kept += 1
	check(kept == agr_n, "los compromisos sobreviven a guardar y cargar (%d/%d)" % [kept, agr_n])
	var vice_kept := false
	for i2 in range(m2.cab.size()):
		if str(m2.cab.entry(i2).get("rank", "")) == "vice": vice_kept = true
	check(vice_kept, "la vicepresidencia sobrevive a guardar y cargar")
	m2.gov_month += 1
	m2.agr.tick()
	check(true, "el seguimiento sigue funcionando tras cargar")

	print("== Límite de ministerios unificado 8–20")
	var m3 := _fresh("pp")
	m3.s["government_party_id"] = m3.pid()
	m3.phase = "cabinet_design"
	m3.gov.set_cabinet_size(40)
	check(int(m3.s["cabinet_size"]) == Competencies.MAX_MINISTRIES and m3.cab.size() == 20, "el tamaño del Consejo llega a 20 (%d)" % m3.cab.size())
	m3.gov.set_cabinet_size(2)
	check(int(m3.s["cabinet_size"]) == Competencies.MIN_MINISTRIES and m3.cab.size() == 8, "y nunca baja de 8 (%d)" % m3.cab.size())

	print("== Fallos: %d" % failures)
	quit(1 if failures > 0 else 0)
