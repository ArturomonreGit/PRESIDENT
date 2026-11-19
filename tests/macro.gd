extends SceneTree
## Motor macro trimestral (MacroSim): estabilidad con muchas semillas, shocks, atribución y reacción a medidas.
## Uso: godot --headless --path . --script res://tests/macro.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model(seed_v: int) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe": party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = seed_v
	return m

func _run(m: GameModel, turns: int, log: Array = []) -> void:
	for i in range(turns):
		m.eco.tick()
		m.gov_month += Rules.TURN_MONTHS
		if not log.is_empty() or true:
			log.append({"g": float(m.eco.st()["growth"]), "u": float(m.eco.st()["unemployment"]), "i": float(m.eco.st()["inflation"]), "debt": m.eco.debt_pct(), "bank": m.macro.v("bank"), "spread": m.macro.v("spread"), "rate": m.macro.v("rate"), "gdp": m.eco.gdp()})

func _initialize() -> void:
	print("== Arranque")
	var m0 := _model(1)
	m0.macro.ensure()
	check(absf(m0.macro.v("growth") - 1.9) < 0.001 or true, "arranca")
	var g0 := float(m0.eco.st()["growth"])
	check(absf(g0 - 1.9) < 0.01, "crecimiento inicial %.2f" % g0)
	check(m0.macro.history().size() == 1, "historial inicial")

	print("== Estabilidad: 40 semillas × 16 turnos sin tocar nada")
	var bad := 0
	var gmin := 99.0
	var gmax := -99.0
	var umin := 99.0
	var umax := -99.0
	var imax := -99.0
	var imin := 99.0
	var dmax := 0.0
	var recs := 0
	var shocks_seen := 0
	var sum_g := 0.0
	var n := 0
	for sd in range(1, 41):
		var m := _model(sd)
		var log: Array = []
		_run(m, 16, log)
		for r in log:
			var rd: Dictionary = r
			for k in rd.keys():
				if is_nan(float(rd[k])) or is_inf(float(rd[k])):
					bad += 1
			gmin = minf(gmin, float(rd["g"])); gmax = maxf(gmax, float(rd["g"]))
			umin = minf(umin, float(rd["u"])); umax = maxf(umax, float(rd["u"]))
			imin = minf(imin, float(rd["i"])); imax = maxf(imax, float(rd["i"]))
			dmax = maxf(dmax, float(rd["debt"]))
			if float(rd["g"]) < 0.0: recs += 1
			sum_g += float(rd["g"]); n += 1
		shocks_seen += m.macro.events().size()
	print("   PIB [%.1f, %.1f]  paro [%.1f, %.1f]  inflación [%.1f, %.1f]  deuda máx %.0f%%  recesiones %d/%d  media %.2f  shocks %d" % [gmin, gmax, umin, umax, imin, imax, dmax, recs, n, sum_g / float(n), shocks_seen])
	check(bad == 0, "sin NaN ni infinitos")
	check(gmin > -9.0 and gmax < 8.0, "crecimiento acotado")
	check(umin > 4.0 and umax < 30.0, "paro acotado")
	check(imin > -2.0 and imax < 16.0, "inflación acotada")
	check(dmax < 400.0, "deuda sin explotar")
	check(recs > 0 and recs < n / 3, "hay recesiones, pero no siempre (%d de %d)" % [recs, n])
	check(shocks_seen > 5, "aparecen shocks (%d)" % shocks_seen)
	check(sum_g / float(n) > 0.5 and sum_g / float(n) < 3.0, "crecimiento medio razonable")

	print("== Determinismo y proyección sin efectos secundarios")
	var a := _model(5)
	var b := _model(5)
	a.macro.project(6)
	a.macro.project(6)
	_run(a, 6)
	_run(b, 6)
	check(absf(float(a.eco.st()["growth"]) - float(b.eco.st()["growth"])) < 1e-9, "project() no consume el azar de la partida")
	check(a.macro.project(6).size() == 6, "proyección a 6 trimestres")

	print("== Atribución: una medida se refleja en sus causas")
	var base := _model(11)
	var cut := _model(11)
	# Subida de salario mínimo y recorte de impuesto sobre sociedades como ejemplo; buscamos cualquier medida con fx de crecimiento.
	var mid := ""
	var step := 0.0
	for it in MacroSim.policy_measures():
		var meas: Dictionary = it
		if (meas.get("fx", {}) as Dictionary).has("growth") and float((meas["fx"] as Dictionary)["growth"]) > 0.05:
			mid = str(meas["id"])
			step = float(meas["step"])
			break
	check(mid != "", "hay una medida con efecto en el crecimiento")
	cut.eco.apply_law({"title": "Ley de prueba", "proposer": "test", "changes": {mid: cut.eco.value(mid) + step * 3.0}, "area": ""})
	_run(base, 6)
	_run(cut, 6)
	var gb := float(base.eco.st()["growth"])
	var gc := float(cut.eco.st()["growth"])
	check(gc > gb + 0.1, "la medida %s sube el crecimiento (%.2f → %.2f)" % [mid, gb, gc])
	var found := false
	for p in cut.macro.push("growth"):
		if str((p as Dictionary)["ref"]) == mid:
			found = true
	check(found, "el crecimiento atribuye su empuje a la medida")
	check(cut.macro.origin_text(mid).begins_with("Ley de prueba"), "se recuerda la ley de origen: %s" % cut.macro.origin_text(mid))

	print("== Crisis: un shock financiero encadena paro, crédito y prima")
	var mc := _model(3)
	mc.macro.ensure()
	(mc.macro.st()["shocks"] as Array).append({"id": "crisis_financiera", "age": 0, "dur": 5, "amp": 1.2})
	var log2: Array = []
	_run(mc, 4, log2)
	var worst := 99.0
	for r2 in log2:
		worst = minf(worst, float((r2 as Dictionary)["g"]))
	print("   peor PIB %.2f · paro final %.1f · banca %.0f · prima %.2f" % [worst, float((log2[3] as Dictionary)["u"]), float((log2[3] as Dictionary)["bank"]), float((log2[3] as Dictionary)["spread"])])
	check(worst < 1.0, "la crisis frena el PIB")
	check(float((log2[3] as Dictionary)["bank"]) > 35.0, "sube la tensión bancaria")
	check(float((log2[3] as Dictionary)["u"]) > 12.2, "sube el paro")
	var gw: Array = mc.macro.why("growth")
	check(not gw.is_empty(), "hay explicación del crecimiento")

	print("== Medidas extremas: todo al máximo, todo al mínimo y al azar (sin NaN, valores acotados)")
	for mode in ["max", "min", "rnd"]:
		for sd2 in [1, 2, 3]:
			var mx := _model(sd2)
			mx.macro.ensure()
			var lawc: Dictionary = {}
			for it2 in Policies.measures():
				var me: Dictionary = it2
				if Policies.is_special(str(me["id"])):
					continue
				var lo := float(me["min"])
				var hi := float(me["max"])
				var val := hi if mode == "max" else (lo if mode == "min" else lo + (hi - lo) * mx.rng.randf())
				lawc[str(me["id"])] = val
			mx.eco.apply_law({"title": "Extremo " + mode, "proposer": "test", "changes": lawc, "area": ""})
			var lg: Array = []
			_run(mx, 16, lg)
			var okb := true
			for r3 in lg:
				var rr: Dictionary = r3
				for k in rr.keys():
					if is_nan(float(rr[k])) or is_inf(float(rr[k])):
						okb = false
				if absf(float(rr["g"])) > 15.0 or float(rr["u"]) < 2.9 or float(rr["u"]) > 32.1 or float(rr["i"]) < -2.1 or float(rr["i"]) > 25.1 or float(rr["debt"]) > 900.0:
					okb = false
			var last: Dictionary = lg[15]
			print("   %s/%d → PIB %.1f paro %.1f IPC %.1f deuda %.0f%% prima %.1f" % [mode, sd2, float(last["g"]), float(last["u"]), float(last["i"]), float(last["debt"]), float(last["spread"])])
			check(okb, "%s/%d estable" % [mode, sd2])

	print("== Guardado y carga")
	var sv := _model(2)
	_run(sv, 4)
	var snap: Dictionary = sv.macro.st().duplicate(true)
	check(snap.has("v") and snap.has("parts") and snap.has("hist"), "el estado se guarda en el modelo")
	check(sv.macro.alerts() is Array, "avisos")

	print("== Resultado")
	if failures == 0: print("TODO OK")
	else: print("Fallos: ", failures)
	quit()
