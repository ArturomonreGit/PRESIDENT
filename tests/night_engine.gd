extends SceneTree
## Comprueba el motor de la noche electoral por cortes (sin interfaz).
## Uso: godot --headless --path . --script res://tests/night_engine.gd

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _initialize() -> void:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe":
			party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	m.election.begin_night()
	var el := m.election
	check(el.night_tick() == 0 and not el.night_finished(), "empieza en el corte 0")
	var last_p := -1.0
	var flips := 0
	var wins := 0
	var majorities := 0
	var changes := 0
	var prev_totals := {}
	var announced_at := {}
	for t in range(1, ElectionSim.CUTS + 1):
		var ev := el.advance_night(1)
		var p := el.night_progress()
		if p + 0.0001 < last_p:
			check(false, "el % escrutado no decrece (%f -> %f)" % [last_p, p])
		last_p = p
		for e in ev:
			match str((e as Dictionary)["type"]):
				"flip": flips += 1
				"win": wins += 1
				"majority": majorities += 1
				"regain": changes += 1
		var tot: Dictionary = m.d("election_totals")
		if t in [1, 5, 10, 20, 30, 45, 60, 75, 89, 90]:
			var parts := []
			for id in tot.keys():
				if int(tot[id]) > 0:
					parts.append("%s %d" % [m.party_short(str(id)), int(tot[id])])
			print("  t=%02d  %5.1f%%  %s" % [t, p, ", ".join(parts)])
	check(el.night_finished(), "termina en el corte %d" % ElectionSim.CUTS)
	check(absf(el.night_progress() - 100.0) < 0.001, "100 % escrutado al final")
	var seat_sum := 0
	for v in m.d("election_totals").values():
		seat_sum += int(v)
	check(seat_sum == 350, "350 escaños al final (%d)" % seat_sum)
	# El resultado final coincide con el reparto definitivo.
	var final_sum := {}
	for cid in m.d("election_alloc").keys():
		for id in (m.d("election_alloc")[cid] as Dictionary).keys():
			final_sum[id] = int(final_sum.get(id, 0)) + int((m.d("election_alloc")[cid] as Dictionary)[id])
	var same := true
	for id in final_sum.keys():
		if int(final_sum[id]) != int(m.d("election_totals").get(id, 0)):
			same = false
	check(same, "los escaños finales coinciden con el reparto definitivo")
	check(m.d("election_announced").size() == 52, "52 circunscripciones anunciadas (%d anuncios de ganador, %d vuelcos)" % [wins, flips])
	print("  vuelcos=%d  recuperaciones=%d  mayorías=%d  cortes guardados=%d" % [flips, changes, majorities, m.a("election_cuts").size()])
	var ex := el.exit_poll()
	var parts2 := []
	for id in ex.keys():
		parts2.append("%s %d-%d" % [m.party_short(str(id)), int(ex[id]["lo"]), int(ex[id]["hi"])])
	print("  sondeo: ", ", ".join(parts2))
	# Escaños en juego a mitad de recuento
	var m2 := GameModel.new({"schema_version": 3, "save_id": "t2", "player_party": party, "game_state": {}})
	m2.autosave = false
	m2.election.begin_night()
	m2.election.advance_night(60)
	var c := m2.election.contested(5)
	check(c.size() > 0, "hay escaños en juego a mitad de recuento (%d)" % c.size())
	for item in c:
		print("   en juego: %s %s <- %s faltan %d" % [item["name"], m2.party_short(str(item["holder"])), m2.party_short(str(item["challenger"])), int(item["need"])])
	# Saltar al final y cerrar
	m2.election.skip_night()
	check(m2.election.night_finished(), "skip_night llega al final")
	m2.election.finish_night()
	check(m2.phase == "results", "finish_night pasa a resultados")
	check(not m2.d("prev_election_winners").is_empty(), "se guardan los ganadores para el próximo ciclo")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
