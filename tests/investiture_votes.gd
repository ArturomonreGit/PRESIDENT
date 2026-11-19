extends SceneTree
## Votación de investidura por diputados (spec §10). Uso: godot --headless --path . --script res://tests/investiture_votes.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _to_investiture(party_id: String, seed_value: int) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	if seed_value != 0:
		m.rng.seed = seed_value
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
	return m

func _init() -> void:
	print("== Investidura por diputados ==")
	for pid in ["psoe", "pp", "vox"]:
		var m := _to_investiture(pid, 17)
		print("-- jugador ", pid, " · candidato ", m.gov.candidate_id())
		_one(m)
	# Partida con el jugador de candidato y todos los pactos cerrados
	var m2 := _to_investiture("psoe", 5)
	var tries := 0
	while m2.phase == "investiture" and tries < 6:
		tries += 1
		if m2.gov.candidate_id() == m2.pid():
			for id in m2.gov.offers().keys():
				var offer: Dictionary = m2.gov.offers()[id]
				for i in range((offer["demands"] as Array).size()): m2.gov.set_concession(str(id), i, true)
				m2.gov.propose(str(id))
		_one(m2)
		var v := m2.gov.hold_vote()
		if bool(v["dissolved"]): break
	print("== %s ==" % ("OK" if failures == 0 else "%d FALLOS" % failures))
	quit(1 if failures > 0 else 0)

func _one(m: GameModel) -> void:
	var a := m.ivote.cast()
	var b := m.ivote.cast()
	var votes := str(a["votes"])
	check(votes.length() == 350 and str(a["orders"]).length() == 350, "350 votos y 350 órdenes")
	var t := InvestitureVote.count(votes)
	check(int(t["yes"]) + int(t["no"]) + int(t["abstain"]) == 350, "yes+no+abstain = 350")
	var tal: Dictionary = a["tally"]
	check(int(tal["yes"]) == int(t["yes"]) and int(tal["no"]) == int(t["no"]) and int(tal["abstain"]) == int(t["abstain"]), "tally == recuento de la cadena")
	check(votes == str(b["votes"]) and str(a["sig"]) == str(b["sig"]), "reproducible: misma situación, mismos votos")
	var mism := 0
	for i in range(350):
		if votes[i] != str(a["orders"])[i]: mism += 1
	check(mism == (a["rebels"] as Array).size(), "rebeldes == escaños que rompen la orden (%d)" % mism)
	var gsum := 0
	var reb_groups := 0
	for g in a["groups"]:
		var gd: Dictionary = g
		gsum += int(gd["seats"])
		reb_groups += int(gd["rebels"])
		check(int(gd["yes"]) + int(gd["no"]) + int(gd["abstain"]) == int(gd["seats"]), "grupo %s suma sus escaños" % str(gd["id"]))
	check(gsum == 350 and reb_groups == mism, "grupos suman 350 y rebeldes por grupo cuadran")
	var ok_rebels := true
	for r in a["rebels"]:
		var rd: Dictionary = r
		if str(rd["name"]) == "" or str(rd["party"]) == "" or str(rd["from"]) == str(rd["to"]): ok_rebels = false
	check(ok_rebels, "cada rebelde tiene nombre, partido y desviación real")
	var out := m.ivote.outlook()
	check(float(out["expected_rebels"]) >= 0.0 and int(out["safe_margin"]) >= 0, "previsión de disidencias válida")
	for pidg in m.gov.parliamentary_ids():
		var d := m.ivote.discipline_of(str(pidg), m.gov.candidate_id(), "y")
		if d < 60.0 or d > 100.0:
			check(false, "disciplina fuera de rango en %s: %.1f" % [str(pidg), d])
	# Votación oficial = misma cadena
	var rnd := m.gov.round_number()
	var cand := m.gov.candidate_id()
	var res := m.gov.hold_vote()
	var last := m.ivote.last()
	check(str(last["votes"]) == votes, "hold_vote usa la misma cadena de votos")
	var rt: Dictionary = res["tally"]
	var lt := InvestitureVote.count(str(last["votes"]))
	check(int(rt["yes"]) == int(lt["yes"]) and int(rt["no"]) == int(lt["no"]) and int(rt["abstain"]) == int(lt["abstain"]), "resultado oficial == recuento visual")
	var want := int(rt["yes"]) >= Rules.MAJORITY if rnd == 1 else int(rt["yes"]) > int(rt["no"])
	check(bool(res["passed"]) == want, "umbral aplicado (%s votación)" % ("primera" if rnd == 1 else "segunda"))
	check(bool(last["held"]) and str(last["cand"]) == cand and int(last["round"]) == rnd, "sesión guardada con candidato y ronda")
	check(m.ivote.history().size() >= 1, "historial de votaciones")
	# Guardado y carga
	m.save_now()
	var copy: Variant = JSON.parse_string(JSON.stringify(m.save))
	var m2 := GameModel.new(copy as Dictionary)
	var l2 := m2.ivote.last()
	check(str(l2.get("votes", "")) == votes and bool(l2.get("held", false)), "los votos sobreviven al guardado/carga")
	check((l2.get("rebels", []) as Array).size() == mism, "los rebeldes sobreviven al guardado/carga")
