extends SceneTree
## Negociación: peticiones concretas y exigencias inegociables. Uso: godot --headless --path . --script res://tests/negotiation.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _initialize() -> void:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe": party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	m.manifesto.suggest()
	m.manifesto.sign()
	m.day = Rules.CAMPAIGN_LENGTH_DAYS
	m.election.begin_night()
	m.election.skip_night()
	m.election.finish_night()
	m.gov.begin_investiture()
	m.gov.set_candidate(m.pid())
	print("== Exigencias concretas")
	var checked := 0
	for p in m.all_parties():
		var id := str((p as Dictionary)["id"])
		if m.is_player(id) or m.seats_of(id) <= 0: continue
		var must := m.brain.must_terms(id)
		check(must.size() >= 1, "%s tiene una exigencia inegociable" % id)
		if must.is_empty(): continue
		var t: Dictionary = must[0]
		check(str(t.get("measure", "")) != "" or str(t.get("text", "")) != "", "%s: «%s»" % [id, str(t.get("text", ""))])
		checked += 1
	check(checked >= 4, "varios partidos exigentes (%d)" % checked)
	print("== Sin su línea roja no firman")
	var target := ""
	for p in m.all_parties():
		var id2 := str((p as Dictionary)["id"])
		if m.is_player(id2) or m.seats_of(id2) < 5: continue
		if m.brain.blocked_by(id2, m.pid()) != "": continue
		if not bool(m.diplomacy.can_meet(id2)["ok"]): continue
		if str(m.brain.assess(id2, m.pid(), [{"k": "vote_yes", "by": "ai"}], m.diplomacy.context_for({"with": id2, "topic": "investiture"}))["verdict"]) == "veto": continue
		target = id2
		break
	check(target != "", "hay un interlocutor disponible (%s)" % target)
	if target != "":
		m.diplomacy.open(target, "investiture")
		var mt := m.diplomacy.current()
		var res := m.brain.assess(target, m.pid(), [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 4}], m.diplomacy.context_for(mt))
		check(not (res["must_missing"] as Array).is_empty(), "falta la exigencia inegociable aunque le ofrezcas 4 carteras")
		check(str(res["verdict"]) != "accept", "no acepta sin su línea roja (%s)" % str(res["verdict"]))
		var table: Array = [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 4}]
		for t2 in m.brain.must_terms(target): table.append(t2)
		var res2 := m.brain.assess(target, m.pid(), table, m.diplomacy.context_for(mt))
		check((res2["must_missing"] as Array).is_empty(), "con su exigencia en la mesa ya no falta nada")
		# El flujo real: presentar la oferta hace que pida su línea roja
		mt["table"] = [{"k": "vote_yes", "by": "ai"}]
		var sub := m.diplomacy.submit()
		check(str(sub["verdict"]) in ["counter", "veto"], "presentar la oferta sin la exigencia da contraoferta/veto (%s)" % str(sub["verdict"]))
		if str(sub["verdict"]) == "counter":
			var has_policy := false
			for tt in m.diplomacy.current()["table"]:
				if str((tt as Dictionary).get("k", "")) == "policy": has_policy = true
			check(has_policy, "la IA añade su exigencia a la mesa")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
