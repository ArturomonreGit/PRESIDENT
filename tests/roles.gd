extends SceneTree
## Roles (presidente / ministro / oposición), ministros de la IA, 18 áreas y panel. Uso: godot --headless --path . --script res://tests/roles.gd
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
	print("== Datos")
	var per_area := {}
	for ms in Policies.measures():
		var aid := str((ms as Dictionary)["area"])
		per_area[aid] = int(per_area.get(aid, 0)) + 1
	check(Policies.areas().size() == 18, "18 áreas")
	var min_n := 99
	for k in per_area.keys(): min_n = mini(min_n, int(per_area[k]))
	check(min_n >= 7, "cada área tiene al menos 7 medidas (mín %d)" % min_n)
	check(Policies.measures().size() >= 160, "%d medidas" % Policies.measures().size())

	print("== Presidente")
	var m := _gov("psoe")
	check(m.phase == "legislature", "legislatura (%s)" % m.phase)
	var kind := m.exec.post_kind()
	check(kind in ["president", "minister", "none"], "rol válido (%s)" % kind)
	if kind != "president":
		print("  (psoe no gobierna en esta semilla; se fuerza)")
		m.s["government_party_id"] = m.pid()
	check(m.exec.post_kind() == "president", "post_kind = president")
	var dec := 0
	var edit_ok := 0
	for ms in Policies.measures():
		if m.exec.decreeable(ms as Dictionary): dec += 1
	check(dec > 60, "%d medidas decretables" % dec)
	for ms in Policies.measures():
		var meas: Dictionary = ms
		if str(meas["area"]) in Executive.LAW_ONLY_AREAS:
			check(not m.exec.decreeable(meas), "%s (impuestos) solo por ley" % str(meas["id"]))
			break

	print("== Ministros de la IA")
	var m2 := _gov("psoe")
	m2.s["government_party_id"] = "pp"
	check(m2.exec.post_kind() in ["none", "minister"], "sin ser presidente (%s)" % m2.exec.post_kind())
	var before: int = (m2.exec.st().get("decrees", []) as Array).size()
	for i in range(80):
		m2.exec._ai_ministers()
		m2.gov_month += 1
	var after: int = (m2.exec.st().get("decrees", []) as Array).size()
	check(after > before, "los ministros de la IA aprueban decretos (%d → %d)" % [before, after])

	print("== Oposición")
	var m3 := _gov("psoe")
	m3.s["government_party_id"] = "pp"
	if m3.exec.post_kind() == "minister":
		m3.exec.st()["post"] = -1
	check(m3.exec.post_kind() == "none", "en la oposición no hay cartera")
	check(not m3.exec.has_post(), "has_post = false")

	print("== Panel")
	for nm in ["PolicyNetwork", "PanelScreen", "CountryScreen"]:
		var ok := false
		for c in ProjectSettings.get_global_class_list():
			if str((c as Dictionary).get("class", "")) == nm: ok = true
		check(ok, "clase %s registrada" % nm)
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
