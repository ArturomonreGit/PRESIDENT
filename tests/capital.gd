extends SceneTree
## Capital político normalizado. Uso: godot --headless --path . --script res://tests/capital.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func _gov(party_id: String, seed_value: int = 0) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	if seed_value != 0:
		m.rng.seed = seed_value
	_fast_gov_into(m)
	return m

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

func _any_gov() -> GameModel:
	for pid in ["psoe", "pp", "sumar"]:
		for sd in [0, 11, 23, 37]:
			var m := _gov(pid, sd)
			if m.phase == "legislature" and m.gov.cabinet().size() >= 8 and m.coal.gov_id() == m.pid():
				return m
	return null

func _synthetic(m: GameModel, n: int, template: Dictionary) -> void:
	## Gabinete de n ministerios que reparte todas las competencias del catálogo; todos los titulares son iguales.
	var cab := m.gov.cabinet()
	cab.clear()
	var ids: Array = []
	for c in Competencies.CATALOG:
		ids.append(str((c as Dictionary)["id"]))
	for i in range(n):
		var comps: Array = []
		var k := i
		while k < ids.size():
			comps.append(ids[k])
			k += n
		var mn := template.duplicate(true)
		mn["pool_id"] = 5000 + i
		cab.append({"id": "t_%d" % i, "name": "Cartera %d" % i, "party": m.pid(), "comps": comps, "minister": mn, "autonomy": "plena"})

func _initialize() -> void:
	var m := _any_gov()
	check(m != null, "partida con Gobierno formado")
	if m == null:
		print("== Fallos: ", failures)
		quit()
		return
	m.exec.ensure()
	print("== Desglose")
	var b := m.exec.capital_breakdown()
	var sum := float(b["base"]) + float(b["leadership"]) + float(b["parliament"]) + float(b["cohesion"]) + float(b["efficiency"])
	check(absf(sum - float(b["raw"])) < 1e-6, "el total es la suma de sus cinco partes (%.2f)" % sum)
	check(float(b["total"]) >= Executive.CP_MIN and float(b["total"]) <= Executive.CP_MAX, "el ingreso está acotado (%.2f)" % float(b["total"]))
	check(float(b["efficiency_index"]) >= 0.0 and float(b["efficiency_index"]) <= 1.0, "la eficiencia media está normalizada (%.2f)" % float(b["efficiency_index"]))
	check(m.exec.capital_text().find("no suma capital") >= 0, "el texto explica que el número de ministerios no suma")

	print("== 8, 10, 12 y 20 ministerios con la misma calidad")
	var template: Dictionary = m.cab.minister(0).duplicate(true)
	template["specialty"] = ""
	template["personality"] = "conciliador"
	template["act"] = 60.0
	template["attrs"] = {"gestion": 7, "lealtad": 6, "afinidad": 5, "ambicion": 5, "popularidad": 5, "experiencia": 6, "comunicacion": 5, "integridad": 6}
	var incomes: Array = []
	for n in [8, 10, 12, 20]:
		_synthetic(m, n, template)
		incomes.append(m.exec.monthly_income())
		print("  n=%d  ingreso=%.4f  E=%.4f" % [n, m.exec.monthly_income(), m.exec.cabinet_efficiency()])
	var same := true
	for v in incomes:
		if absf(float(v) - float(incomes[0])) > 1e-9:
			same = false
	check(same, "con iguales condiciones, 8, 10, 12 y 20 carteras dan el mismo capital")

	print("== La calidad sí cuenta")
	_synthetic(m, 12, template)
	var base_income := m.exec.monthly_income()
	var better: Dictionary = template.duplicate(true)
	better["act"] = 90.0
	(better["attrs"] as Dictionary)["gestion"] = 10
	(better["attrs"] as Dictionary)["experiencia"] = 9
	_synthetic(m, 12, better)
	var good_income := m.exec.monthly_income()
	var worse: Dictionary = template.duplicate(true)
	worse["act"] = 20.0
	(worse["attrs"] as Dictionary)["gestion"] = 3
	_synthetic(m, 12, worse)
	var bad_income := m.exec.monthly_income()
	check(good_income > base_income and base_income > bad_income, "mejores ministros dan más capital (%.2f > %.2f > %.2f)" % [good_income, base_income, bad_income])
	_synthetic(m, 12, better)
	var vacant_cab := m.gov.cabinet()
	for i in range(6):
		(vacant_cab[i] as Dictionary).erase("minister")
	check(m.exec.monthly_income() < good_income, "las carteras vacantes restan eficiencia")

	print("== Otros factores")
	_synthetic(m, 12, template)
	var i0 := m.exec.monthly_income()
	m.s["gov_approval"] = 90.0
	check(m.exec.monthly_income() > i0, "más apoyo al Gobierno sube el liderazgo")
	m.s["gov_approval"] = 50.0
	var i1 := m.exec.monthly_income()
	m.s["stability"] = 5.0
	check(m.exec.monthly_income() < i1 or i1 <= Executive.CP_MIN, "menos estabilidad baja la cohesión")
	m.s["stability"] = 0.0
	m.s["gov_approval"] = 0.0
	_synthetic(m, 8, worse)
	check(m.exec.monthly_income() >= Executive.CP_MIN - 1e-9, "suelo del ingreso")
	m.s["stability"] = 100.0
	m.s["gov_approval"] = 100.0
	_synthetic(m, 8, better)
	check(m.exec.monthly_income() <= Executive.CP_MAX + 1e-9, "techo del ingreso")
	m.exec.st()["capital"] = Executive.MAX_CAPITAL - 1.0
	m.exec.monthly()
	check(m.exec.capital() <= Executive.MAX_CAPITAL + 1e-9, "el capital acumulado nunca pasa del máximo")
	print("== Fallos: ", failures)
	quit()
