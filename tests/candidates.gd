extends SceneTree
## Cinco candidatos por cartera. Uso: godot --headless --path . --script res://tests/candidates.gd
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

func _initialize() -> void:
	var m := _any_gov()
	check(m != null, "partida con Gobierno formado")
	if m == null:
		print("== Fallos: ", failures)
		quit()
		return
	m.ministers.ensure_cabinet()
	var cab := m.gov.cabinet()
	print("== Listas de cinco candidatos")
	var all5 := true
	var uniq := true
	var no_dom := true
	var has_incumbent := true
	var roles_ok := true
	var own_n := 0
	var other_n := 0
	for i in range(cab.size()):
		var list := m.cands.shortlist(i)
		if list.size() != MinistryCandidates.SIZE:
			all5 = false
		var ids := {}
		var roles := {}
		for c in list:
			var cd: Dictionary = c
			if ids.has(int(cd["pool_id"])):
				uniq = false
			ids[int(cd["pool_id"])] = true
			roles[str(cd.get("cand_role", ""))] = true
		if roles.size() < 3:
			roles_ok = false
		for a in list:
			for b in list:
				if a != b and m.cands.dominates(a as Dictionary, b as Dictionary):
					no_dom = false
		var mn: Dictionary = (cab[i] as Dictionary).get("minister", {})
		var found := false
		for c2 in list:
			if int((c2 as Dictionary)["pool_id"]) == int(mn.get("pool_id", -9)):
				found = true
		if not found:
			has_incumbent = false
		if str((cab[i] as Dictionary)["party"]) == m.pid():
			own_n += 1
		else:
			other_n += 1
	check(all5, "cada cartera tiene cinco candidatos (%d carteras)" % cab.size())
	check(uniq, "sin candidatos repetidos en una lista")
	check(no_dom, "ningún candidato domina a otro en todos los atributos")
	check(has_incumbent, "el titular actual es uno de los cinco")
	check(roles_ok, "al menos tres perfiles distintos por lista")
	check(own_n > 0, "el jugador tiene carteras propias (%d) y socios %d" % [own_n, other_n])

	print("== Persistencia")
	var snapshot: Array = []
	for i in range(cab.size()):
		var row: Array = []
		for c3 in m.cands.shortlist(i):
			row.append(int((c3 as Dictionary)["pool_id"]))
		snapshot.append(row)
	var again: Array = []
	for i in range(cab.size()):
		var row2: Array = []
		for c4 in m.cands.shortlist(i):
			row2.append(int((c4 as Dictionary)["pool_id"]))
		again.append(row2)
	check(snapshot == again, "la lista no cambia al volver a consultarla")
	var parsed: Variant = JSON.parse_string(JSON.stringify(m.s["cand_sets"]))
	check(parsed is Dictionary and (parsed as Dictionary).size() >= cab.size(), "las listas sobreviven a guardar y cargar (%d)" % (parsed as Dictionary).size())

	print("== Contexto y lectura")
	var own_idx := -1
	var other_idx := -1
	for i in range(cab.size()):
		if str((cab[i] as Dictionary)["party"]) == m.pid() and own_idx < 0:
			own_idx = i
		elif str((cab[i] as Dictionary)["party"]) != m.pid() and other_idx < 0:
			other_idx = i
	if own_idx >= 0:
		var spec_idx := own_idx
		for i in range(cab.size()):
			if str((cab[i] as Dictionary)["party"]) == m.pid() and m.cands._specialty_for(cab[i] as Dictionary) != "":
				spec_idx = i
				break
		var l0 := m.cands.shortlist(own_idx)
		var spec_n := 0
		for c5 in m.cands.shortlist(spec_idx):
			if m.ministers.specialty_match(c5 as Dictionary, str((cab[spec_idx] as Dictionary)["name"]), cab[spec_idx] as Dictionary):
				spec_n += 1
		check(m.cands._specialty_for(cab[spec_idx] as Dictionary) == "" or spec_n >= 1, "al menos un candidato conoce la cartera (%d)" % spec_n)
		var nt: Dictionary = m.cands.notes(l0[0] as Dictionary, own_idx)
		check(nt.has("strengths") and nt.has("weaknesses") and nt.has("risks"), "fortalezas, debilidades y riesgos")
		var anyrisk := false
		for c6 in l0:
			var n2: Dictionary = m.cands.notes(c6 as Dictionary, own_idx)
			if (n2["risks"] as Array).size() + (n2["weaknesses"] as Array).size() > 0:
				anyrisk = true
		check(anyrisk, "los candidatos tienen puntos débiles visibles")
		check(m.ministers.available_for(own_idx).size() == 5, "available_for devuelve cinco")
	if other_idx >= 0:
		var chosen: Dictionary = (cab[other_idx] as Dictionary)["minister"]
		var ids2 := {}
		for c7 in m.cands.shortlist(other_idx):
			ids2[int((c7 as Dictionary)["pool_id"])] = true
		check(ids2.has(int(chosen["pool_id"])), "el socio eligió a su ministro entre sus cinco")
		check(not m.cands.appoint(other_idx, int(chosen["pool_id"])), "el jugador no nombra ministros de un socio")
		check(int(m.cands.ai_choose(other_idx).get("pool_id", -1)) == int(chosen["pool_id"]), "la IA decide con los rasgos de su partido")

	print("== Nombramiento")
	if own_idx >= 0:
		var l1 := m.cands.shortlist(own_idx)
		var target: Dictionary = {}
		for c8 in l1:
			if int((c8 as Dictionary)["pool_id"]) != int(((cab[own_idx] as Dictionary).get("minister", {}) as Dictionary).get("pool_id", -9)):
				target = c8
				break
		var ok := m.cands.appoint(own_idx, int(target["pool_id"]))
		check(ok and int(((cab[own_idx] as Dictionary)["minister"] as Dictionary)["pool_id"]) == int(target["pool_id"]), "nombrar a un candidato de la lista")
		# Quien ya es ministro de otra cartera propia desaparece de las demás listas y se rellena el hueco.
		var other_own := -1
		for i in range(cab.size()):
			if i != own_idx and str((cab[i] as Dictionary)["party"]) == m.pid():
				other_own = i
				break
		if other_own >= 0:
			var l2 := m.cands.shortlist(other_own)
			var dup := false
			for c9 in l2:
				if int((c9 as Dictionary)["pool_id"]) == int(target["pool_id"]):
					dup = true
			check(not dup and l2.size() == 5, "un ministro ya nombrado no aparece en otra lista y sigue habiendo cinco")
		# Candidatos independientes en las carteras propias
		var indep := 0
		for i in range(cab.size()):
			if str((cab[i] as Dictionary)["party"]) == m.pid():
				for c10 in m.cands.shortlist(i):
					if bool((c10 as Dictionary).get("independent", false)):
						indep += 1
		check(indep >= 0 and m.cands.independents_allowed(own_idx), "independientes permitidos en carteras propias (%d en listas)" % indep)
		check(other_idx < 0 or not m.cands.independents_allowed(other_idx), "no en carteras de socios sin cláusula")

	print("== Cambio de estructura")
	if own_idx >= 0:
		var before := m.cands.shortlist(own_idx).size()
		var comps: Array = (cab[own_idx] as Dictionary).get("comps", [])
		var sig_before := str((m.s["cand_sets"] as Dictionary).get(str((cab[own_idx] as Dictionary)["id"]), {}).get("sig", ""))
		var extra := ""
		for cid in Competencies.CATALOG:
			var cidd := str((cid as Dictionary)["id"])
			if not comps.has(cidd) and m.cab.owner_of(cidd) < 0:
				extra = cidd
				break
		if extra != "":
			comps.append(extra)
			var l3 := m.cands.shortlist(own_idx)
			var sig_after := str((m.s["cand_sets"] as Dictionary).get(str((cab[own_idx] as Dictionary)["id"]), {}).get("sig", ""))
			check(l3.size() == 5 and sig_after != sig_before, "al cambiar las competencias se recalcula la lista (%d→%d)" % [before, l3.size()])
		else:
			check(true, "sin competencias libres para probar el recálculo")
	print("== Fallos: ", failures)
	quit()
