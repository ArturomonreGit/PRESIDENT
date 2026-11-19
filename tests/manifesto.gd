extends SceneTree
## Programa electoral obligatorio. Uso: godot --headless --path . --script res://tests/manifesto.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _init() -> void:
	for pid in ["psoe", "pp", "vox", "sumar"]:
		var party: Dictionary = {}
		for p in DataStore.parties():
			if str((p as Dictionary)["id"]) == pid: party = p
		if party.is_empty(): continue
		var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
		m.autosave = false
		print("== ", pid)
		var mf := m.manifesto
		check(m.phase == "campaign" and not mf.locked(), "empieza sin programa firmado")
		check(not mf.ready(), "un programa vacío no es válido")
		check(not bool(mf.sign()["ok"]), "no se puede firmar vacío")
		mf.suggest()
		check(mf.ready(), "el borrador sugerido es válido (%d promesas, %d áreas)" % [mf.count(), mf.areas_used().size()])
		check(Manifesto.MAX_PER_AREA == 7, "máximo 7 promesas por área")
		check(m.campaign.program().size() >= Manifesto.MIN_AREAS, "program() deriva de las promesas")
		var res := mf.resonance()
		check(res >= -1.0 and res <= 1.0, "resonancia en rango (%.2f)" % res)
		check(mf.off_line().size() <= 2, "el borrador sigue la línea del partido")
		# Límite por área
		mf.clear()
		var n_ok := 0
		for it in Policies.measures_of("tax"):
			if Policies.is_special(str((it as Dictionary)["id"])): continue
			var meas: Dictionary = it
			var cur := m.eco.value(str(meas["id"]))
			var nv := minf(float(meas["max"]), cur + float(meas["step"]))
			if is_equal_approx(nv, cur): nv = maxf(float(meas["min"]), cur - float(meas["step"]))
			if bool(mf.set_promise(str(meas["id"]), nv)["ok"]): n_ok += 1
		check(n_ok == mini(Manifesto.MAX_PER_AREA, Policies.measures_of("tax").size()), "se llena el área hasta el máximo (%d)" % n_ok)
		# Sin límite general: promesas en todas las áreas
		mf.clear()
		for a in Policies.areas():
			var aid := str((a as Dictionary)["id"])
			var added := 0
			for it2 in Policies.measures_of(aid):
				var me: Dictionary = it2
				var cu := m.eco.value(str(me["id"]))
				var nv2 := minf(float(me["max"]), cu + float(me["step"]))
				if is_equal_approx(nv2, cu): nv2 = maxf(float(me["min"]), cu - float(me["step"]))
				if added < Manifesto.MAX_PER_AREA and bool(mf.set_promise(str(me["id"]), nv2)["ok"]): added += 1
		check(mf.count() > 12, "no hay límite general de promesas (%d)" % mf.count())
		# IRPF por tramos
		mf.clear()
		var base := m.eco.irpf_brackets()
		check(base.size() == 6, "escala vigente de 6 tramos")
		var nb: Array = base.duplicate(true)
		nb.append({"from": 500.0, "rate": 52.0})
		(nb[0] as Dictionary)["rate"] = 17.0
		check(bool(mf.set_irpf_promise(nb)["ok"]) and mf.has(Irpf.SPECIAL_ID), "se promete una escala de IRPF con un tramo nuevo")
		check(mf.irpf_target().size() == 7, "la escala prometida tiene 7 tramos")
		check(not mf.group_effects(Irpf.SPECIAL_ID).is_empty(), "el IRPF tiene reacción por colectivos")
		check(mf.area_count("tax") == 1, "el IRPF cuenta en el área Impuestos")
		var fb1 := mf.fiscal_bn()
		var nb2: Array = base.duplicate(true)
		(nb2[1] as Dictionary)["rate"] = 40.0
		mf.set_irpf_promise(nb2)
		check(mf.fiscal_bn() > fb1, "subir tipos mejora el saldo frente a bajarlos (%.1f vs %.1f)" % [mf.fiscal_bn(), fb1])
		check(float(mf.progress(Irpf.SPECIAL_ID)) < 0.01, "IRPF sin cumplir: progreso 0")
		mf.set_irpf_promise(base)
		check(not mf.has(Irpf.SPECIAL_ID), "prometer la escala actual retira la promesa")
		mf.set_irpf_promise(nb2)
		# Devolver a la situación actual retira la promesa
		mf.suggest()
		var first := str(mf.promises().keys()[0])
		mf.set_promise(first, m.eco.value(first))
		check(not mf.has(first), "igualar el valor actual retira la promesa")
		mf.suggest()
		mf.set_irpf_promise(nb2)
		check(bool(mf.sign()["ok"]) and mf.locked(), "firmar cierra el programa")
		var any := str(mf.promises().keys()[0])
		check(not bool(mf.set_promise(any, m.eco.value(any) + 99.0)["ok"]), "firmado no se puede editar")
		# Cumplimiento
		check(mf.kept_ratio() < 0.01, "al principio no hay nada cumplido")
		# Proposiciones de ley
		m.phase = "legislature"
		m.gov_month = 1
		var nb_drafts := m.laws.drafts().size()
		var made := mf.create_bills()
		check(made == mf.count() and m.laws.drafts().size() == nb_drafts + mf.count(), "cada promesa genera una proposición de ley (%d)" % made)
		var irpf_bill: Dictionary = {}
		for d in m.laws.drafts():
			if str((d as Dictionary).get("promise", "")) == Irpf.SPECIAL_ID: irpf_bill = d
		check(not irpf_bill.is_empty() and Irpf.same(m.laws.proposed_irpf(irpf_bill), nb2), "la proposición de IRPF lleva los tramos del programa")
		var any_bill: Dictionary = {}
		for d2 in m.laws.drafts():
			var pid2 := str((d2 as Dictionary).get("promise", ""))
			if pid2 != "" and pid2 != Irpf.SPECIAL_ID: any_bill = d2
		check(not any_bill.is_empty() and is_equal_approx(float((any_bill["changes"] as Dictionary).values()[0]), mf.target(str(any_bill["promise"]))), "la proposición lleva el valor prometido")
		check(mf.ensure_bills() == 0, "no se duplican proposiciones")
		var left0 := m.gov.bills_left()
		m.s["bills_left"] = 0
		var err0 := m.laws.register(str(any_bill["id"]))
		check(err0 != "" and mf.bill_state(str(any_bill["promise"])) == "draft", "sin cupo mensual, ni las del programa se registran")
		m.s["bills_left"] = 3
		var err := m.laws.register(str(any_bill["id"]))
		check(err == "" and mf.bill_state(str(any_bill["promise"])) == "registered", "una proposición del programa se registra con cupo (%s)" % err)
		check(m.gov.bills_left() == 2, "y consume una de las 3 iniciativas mensuales")
		m.s["bills_left"] = left0
		mf.on_bill(any_bill, "rejected")
		check(mf.ensure_bills() == 1 and mf.bill_state(str(any_bill["promise"])) == "draft", "si el Congreso la rechaza, se redacta de nuevo")
		var changes: Dictionary = {}
		for id in mf.promises().keys():
			changes[str(id)] = mf.target(str(id))
		m.eco.apply_law({"title": "t", "proposer": m.pid(), "changes": changes, "irpf": mf.irpf_target(), "area": "tax"})
		check(mf.kept_ratio() > 0.99, "aprobar lo prometido cumple el programa (%.2f)" % mf.kept_ratio())
		check(Irpf.same(m.eco.irpf_brackets(), nb2), "la escala de IRPF aprobada queda vigente")
		# Decepción de los votantes por promesas sin cumplir
		var mf2 := m.manifesto
		m.trust = 50.0
		var tr0 := m.trust
		var p0 := m.player_poll()
		m.s["government_party_id"] = m.pid()
		m.gov_month = 30
		mf2.promises().clear()
		mf2.promises()["vat_general"] = {"from": m.eco.value("vat_general"), "to": m.eco.value("vat_general") + 5.0}
		check(mf2.disappointment() > 0.3, "30 meses sin cumplir: decepción alta (%.2f)" % mf2.disappointment())
		check(mf2.late_list().size() == 1, "la promesa se marca con retraso")
		for _i in range(6): mf2.monthly()
		check(m.trust < tr0 - 1.0, "la decepción baja la confianza (%.1f -> %.1f)" % [tr0, m.trust])
		check(m.player_poll() < p0, "y el partido cae en las encuestas (%.2f -> %.2f)" % [p0, m.player_poll()])
		check(m.s.get("manifesto_anger_news", false), "hay noticia de castigo")
		mf2.promises().clear()
		# Nuevo ciclo exige programa nuevo
		mf2.promises().clear()
		for id4 in changes.keys():
			if Policies.is_special(str(id4)): continue
			mf2.promises()[id4] = {"from": m.eco.value(str(id4)), "to": m.eco.value(str(id4))}
		var t0 := m.trust
		m.gov.start_new_cycle("test")
		check(m.phase == "campaign" and not mf.locked() and mf.count() == 0, "la nueva campaña exige un programa nuevo")
		check(m.d("manifesto_prev").has("ratio"), "se guarda el balance del programa anterior")
		print("  confianza ", t0, " -> ", m.trust)
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
