extends SceneTree
## Comprueba que un guardado del formato anterior (v0.8/v0.9) se abre y sigue siendo jugable.

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _party(id: String) -> Dictionary:
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == id:
			return p
	return {}

func _initialize() -> void:
	# 1) Campaña a mitad
	var old_campaign := {
		"schema_version": 2, "save_id": "old1", "player_party": _party("psoe"),
		"game_state": {
			"campaign_day": 20, "money": 400000, "trust": 61, "visibility": 44, "momentum": 1.5,
			"polling": 28.5, "rival_polls": {"pp": 33.0, "vox": 11.0, "sumar": 12.0, "erc": 1.8, "junts": 1.5, "ehbildu": 1.2, "pnv": 1.1, "bng": 0.7, "cc": 0.4, "upn": 0.3},
			"program": {"housing": true, "health": true},
			"campaign_events": [{"id": "e1", "day": 21, "hour": 11, "type": "Mitin", "region": "Madrid", "title": "Mitin", "status": "scheduled"}],
			"campaign_news": [{"title": "Antigua", "body": "Mensaje de la versión anterior", "category": "AGENDA", "tone": "neutral", "day": 3}],
		}
	}
	var m := GameModel.new(old_campaign)
	m.autosave = false
	print("== Migración: campaña a mitad")
	check(m.phase == "campaign", "fase campaña")
	check(m.day == 20, "día 20 conservado")
	var total := 0.0
	for v in m.polls().values():
		total += float(v)
	check(absf(total - 100.0) < 0.01, "encuestas normalizadas (%.2f)" % total)
	check(m.player_poll() > 20.0, "intención del jugador conservada aprox. (%.1f)" % m.player_poll())
	check(m.news().size() >= 1 and int((m.news()[0] as Dictionary).get("id", 0)) > 0, "mensajes antiguos migrados con id")
	var safety := 0
	while m.phase == "campaign" and safety < 100:
		safety += 1
		for ev in m.campaign.pending_today():
			m.campaign.resolve_auto(ev)
		if str(m.campaign.smart_continue()["stop"]) == "election":
			break
	check(m.day == Rules.CAMPAIGN_LENGTH_DAYS, "campaña migrada llega a las elecciones")
	m.election.begin_night()
	while not m.election.night_finished():
		m.election.reveal_next()
	m.election.finish_night()
	check(m.phase == "results", "noche electoral tras migrar")

	# 2) Resultados con formato antiguo
	var old_results := {
		"schema_version": 2, "save_id": "old2", "player_party": _party("pp"),
		"game_state": {
			"campaign_day": 42, "election_complete": true, "political_phase": "results", "money": 900000, "trust": 55, "visibility": 50,
			"polling": 33.0, "rival_polls": {"psoe": 29.0, "vox": 12.0, "sumar": 12.0, "erc": 1.8, "junts": 1.5, "ehbildu": 1.2, "pnv": 1.1, "bng": 0.7, "cc": 0.4, "upn": 0.3},
			"election_totals": {"pp": 137, "psoe": 121, "vox": 33, "sumar": 31, "erc": 7, "junts": 7, "ehbildu": 6, "pnv": 5, "bng": 1, "cc": 1, "upn": 1},
			"election_vote_totals": {"pp": 8000000, "psoe": 7700000, "vox": 3000000, "sumar": 3000000, "erc": 460000, "junts": 390000, "ehbildu": 330000, "pnv": 275000, "bng": 150000, "cc": 115000, "upn": 52000},
		}
	}
	var m2 := GameModel.new(old_results)
	m2.autosave = false
	print("== Migración: resultados")
	check(m2.phase == "results", "fase resultados")
	check(m2.seats_of("pp") == 137, "escaños conservados")
	m2.gov.begin_investiture()
	check(m2.phase == "investiture", "se puede abrir la investidura")
	var ok := false
	for i in range(8):
		if m2.phase != "investiture":
			break
		if m2.gov.candidate_id() == m2.pid():
			for id in m2.gov.offers().keys():
				for k in range(((m2.gov.offers()[id] as Dictionary)["demands"] as Array).size()):
					m2.gov.set_concession(str(id), k, true)
				m2.gov.propose(str(id))
		m2.gov.hold_vote()
	ok = m2.phase in ["cabinet_design", "campaign"]
	check(ok, "la investidura migrada resuelve (%s)" % m2.phase)
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
