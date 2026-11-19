extends SceneTree
## Historial previo (HistoryGen): longitud, continuidad con el inicio, rangos y encuestas. Uso: godot --headless --path . --script res://tests/history.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model(party_id: String = "psoe") -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	return m

func _finite(v: float) -> bool:
	return not is_nan(v) and not is_inf(v)

func _initialize() -> void:
	for mode in ["realistic", "random"]:
		print("== Modo ", mode)
		var m := _model()
		var t0 := Time.get_ticks_msec()
		var g := HistoryGen.new(m, mode)
		g.generate()
		print("  (%d ms)" % (Time.get_ticks_msec() - t0))
		var eh := m.eco.history()
		check(eh.size() == HistoryGen.MONTHS + 1, "economía: %d meses" % eh.size())
		var wh := m.world.history()
		check(wh.size() == HistoryGen.MONTHS + 1, "indicadores: %d meses" % wh.size())
		var last: Dictionary = eh[eh.size() - 1]
		check(absf(float(last["unemployment"]) - float(m.eco.st()["unemployment"])) < 0.01, "el paro termina en el valor inicial")
		var prev: Dictionary = eh[eh.size() - 2]
		check(absf(float(prev["unemployment"]) - float(last["unemployment"])) < 1.5, "continuidad del paro (%.2f → %.2f)" % [float(prev["unemployment"]), float(last["unemployment"])])
		check(absf(float(prev["inflation"]) - float(last["inflation"])) < 2.0, "continuidad de la inflación")
		var ok := true
		var lo_u := 99.0
		var hi_u := 0.0
		for h in eh:
			var hd: Dictionary = h
			for k in ["gdp", "growth", "unemployment", "inflation", "debt_pct", "deficit_pct", "revenue", "spending", "avg_sat"]:
				if not _finite(float(hd[k])): ok = false
			lo_u = minf(lo_u, float(hd["unemployment"]))
			hi_u = maxf(hi_u, float(hd["unemployment"]))
			if float(hd["gdp"]) <= 0.0 or float(hd["revenue"]) <= 0.0 or float(hd["spending"]) <= 0.0: ok = false
		check(ok, "valores económicos finitos y positivos")
		print("  paro entre %.1f y %.1f" % [lo_u, hi_u])
		var wok := true
		for e in wh:
			for it in WorldSim.indicators():
				var d: Dictionary = it
				var v := float(((e as Dictionary)["v"] as Dictionary).get(str(d["id"]), NAN))
				if not _finite(v) or v < float(d["min"]) - 0.001 or v > float(d["max"]) + 0.001: wok = false
		check(wok, "36 indicadores dentro de sus límites en todos los meses")
		var wl: Dictionary = (wh[wh.size() - 1] as Dictionary)["v"]
		var cont := true
		for it in WorldSim.indicators():
			var d2: Dictionary = it
			if absf(float(wl[str(d2["id"])]) - float(d2["start"])) > 0.001: cont = false
		check(cont, "los indicadores terminan en su valor inicial")
		var ph := m.a("poll_history_multi")
		check(ph.size() >= HistoryGen.WEEKS, "encuestas: %d semanas" % ph.size())
		var sums_ok := true
		for snap in ph:
			var tot := 0.0
			for k in ((snap as Dictionary)["polls"] as Dictionary).keys():
				tot += float(((snap as Dictionary)["polls"] as Dictionary)[k])
			if absf(tot - 100.0) > 1.5: sums_ok = false
		check(sums_ok, "cada encuesta suma ~100 %")
		check(m.a("hist_events").size() >= 2, "%d hitos" % m.a("hist_events").size())
		check(str(m.s.get("history_mode", "")) == mode, "modo guardado")
		var mk := HistoryGen.markers_for(m, eh)
		check(mk.size() >= 2, "marcas para la gráfica: %d" % mk.size())
		# El juego sigue funcionando: un mes de simulación añade una entrada más
		m.eco.tick()
		check(m.eco.history().size() == HistoryGen.MONTHS + 2, "un tick añade un mes")
	print("== Sin historial")
	var m3 := _model()
	HistoryGen.new(m3, "none").generate()
	check(m3.eco.history().size() <= 1, "no añade datos")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
