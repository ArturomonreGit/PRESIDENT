extends SceneTree
## IA de votantes: calibración, dinámica, reacciones, abstención, trasvase y guardado.
## Uso: godot --headless --path . --script res://tests/electorate.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _mk(pid: String, seed_v: int, save: Dictionary = {}) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == pid:
			party = (p as Dictionary).duplicate(true)
	var d: Dictionary = save if not save.is_empty() else {"schema_version": 3, "save_id": "etest", "player_party": party, "game_state": {}}
	var m := GameModel.new(d)
	m.autosave = false
	m.rng.seed = seed_v
	return m

func _anger(m: GameModel, id: String) -> float:
	var tot := 0.0
	var w := 0.0
	for r in m.voters.cohort_overview():
		var rd: Dictionary = r
		tot += float((rd["anger"] as Dictionary).get(id, 0.0)) * float(rd["w"])
		w += float(rd["w"])
	return tot / maxf(w, 0.001)

func _initialize() -> void:
	print("== Calibración inicial")
	var m := _mk("psoe", 3)
	check(m.voters.ready_state(), "motor de votantes listo")
	for id in ["pp", "psoe", "vox", "sumar"]:
		check(absf(m.poll_of(id) - float(Rules.BASE_POLL[id])) < 1.2, "%s ≈ encuesta base (%.1f vs %.1f)" % [id, m.poll_of(id), float(Rules.BASE_POLL[id])])
	var tot := 0.0
	for v in m.polls().values():
		tot += float(v)
	check(absf(tot - 100.0) < 0.01, "las encuestas suman 100 (%.3f)" % tot)
	check(m.voters.turnout() > 0.6 and m.voters.turnout() < 0.82, "participación verosímil (%.1f %%)" % (m.voters.turnout() * 100.0))

	print("== Impulsos y reacciones")
	var p0 := m.player_poll()
	m.voters.nudge("psoe", 2.0)
	m.voters.recompute(false)
	check(m.player_poll() > p0 + 0.8, "un impulso positivo sube la intención de voto (%.1f → %.1f)" % [p0, m.player_poll()])
	check(m.poll_of("pp") < 33.5, "los rivales ceden a cambio")
	var m2 := _mk("psoe", 4)
	var ang0 := _anger(m2, "psoe")
	var before := m2.player_poll()
	# Ley muy escorada a la derecha propuesta por el jugador (de izquierdas): enfada a su electorado, pero no se va todo.
	m2.voters.react({"party": "psoe", "partners": [], "dir": [0.12, 0.12, 0.0], "groups": {}, "issue": "tax", "mag": 1.6, "label": "Ley de prueba"})
	m2.voters.recompute(false)
	var after := m2.player_poll()
	check(_anger(m2, "psoe") > ang0 + 0.01, "crece el enfado de sus votantes (%.3f → %.3f)" % [ang0, _anger(m2, "psoe")])
	var some_calm := false
	for r in m2.voters.cohort_overview():
		if float((r["anger"] as Dictionary).get("psoe", 0.0)) < 0.05:
			some_calm = true
	check(some_calm, "no todos los grupos se enfadan")
	check(after < before - 0.3, "pierde intención de voto (%.1f → %.1f)" % [before, after])
	check(after > before * 0.5, "pero no se hunde: los votantes piensan por sí mismos (%.1f)" % after)

	print("== Abstención")
	var m3 := _mk("pp", 5)
	var t0 := m3.voters.turnout()
	m3.voters.st()["fatigue"] = -0.6
	m3.voters.recompute(false)
	check(m3.voters.turnout() < t0 - 0.015, "el hartazgo baja la participación (%.1f → %.1f)" % [t0 * 100.0, m3.voters.turnout() * 100.0])
	m3.voters.st()["fatigue"] = 0.0
	m3.voters.on_broken_promises("pp", 1.0)
	m3.voters.recompute(false)
	check(m3.voters.turnout() < t0, "las promesas rotas desmovilizan")

	print("== Dinámica en 36 meses")
	var lead_changes := 0
	var ranges: Array = []
	var small_ranges: Array = []
	for sd in range(8):
		var mm := _mk("psoe", 100 + sd)
		var first_leader := ""
		var changed := false
		var lo := 99.0
		var hi := -1.0
		var slo := 99.0
		var shi := -1.0
		for mo in range(36):
			mm.gov_month = mo + 1
			mm.voters.monthly()
			var lead := "pp" if mm.poll_of("pp") > mm.poll_of("psoe") else "psoe"
			if first_leader == "":
				first_leader = lead
			elif lead != first_leader:
				changed = true
			lo = minf(lo, mm.player_poll())
			hi = maxf(hi, mm.player_poll())
			slo = minf(slo, mm.poll_of("erc"))
			shi = maxf(shi, mm.poll_of("erc"))
		if changed:
			lead_changes += 1
		ranges.append(hi - lo)
		small_ranges.append((shi - slo) / maxf(mm.poll_of("erc"), 0.1))
		if sd == 0:
			check(mm.a("poll_history_multi").size() >= 100, "historial de encuestas denso (%d puntos)" % mm.a("poll_history_multi").size())
			check(mm.voters.flows(6).size() > 0, "hay trasvase de votos visible")
	var avg := 0.0
	for r in ranges: avg += float(r) / ranges.size()
	check(avg > 3.0 and avg < 14.0, "oscilación del partido grande razonable (%.1f pts en 3 años)" % avg)
	check(lead_changes >= 2, "el favorito puede perder el liderazgo (%d de 8 partidas)" % lead_changes)
	var savg := 0.0
	for r in small_ranges: savg += float(r) / small_ranges.size()
	check(savg > 0.4, "los partidos pequeños fluctúan relativamente más (%.0f %% de su voto)" % (savg * 100.0))

	print("== Campaña de 42 días")
	var mc := _mk("psoe", 9)
	var h0 := mc.a("poll_history_multi").size()
	for d in range(42):
		mc.voters.step_day()
	check(mc.player_poll() > 10.0 and mc.player_poll() < 50.0, "la campaña no se desmadra (%.1f)" % mc.player_poll())

	print("== Elecciones")
	var me := _mk("psoe", 11)
	var ed := me.voters.election_day()
	check(ed.has("shares") and ed.has("turnout"), "el día D devuelve reparto y participación")
	var s_sum := 0.0
	for v in (ed["shares"] as Dictionary).values():
		s_sum += float(v)
	check(absf(s_sum - 100.0) < 0.5 or absf(s_sum - 1.0) < 0.01, "el reparto suma 100 (%.2f)" % s_sum)
	me.voters.finish_election(ed["shares"], float(ed["turnout"]))
	check(me.voters.ready_state(), "el motor sigue válido tras las elecciones")

	print("== Guardado y carga")
	var mg := _mk("psoe", 21)
	for mo in range(5):
		mg.gov_month = mo + 1
		mg.voters.monthly()
	var js := JSON.stringify(mg.save)
	var parsed: Variant = JSON.parse_string(js)
	check(typeof(parsed) == TYPE_DICTIONARY, "el guardado se serializa")
	var ml := _mk("psoe", 22, parsed as Dictionary)
	check(ml.voters.ready_state(), "el motor se restaura al cargar")
	check(absf(ml.player_poll() - mg.player_poll()) < 0.01, "mismas encuestas tras cargar (%.2f vs %.2f)" % [ml.player_poll(), mg.player_poll()])
	ml.voters.monthly()
	check(ml.a("poll_history_multi").size() > mg.a("poll_history_multi").size() - 1, "se puede seguir jugando tras cargar")
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)
