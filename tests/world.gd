extends SceneTree
## Red de indicadores (WorldSim): estabilidad, direcciones causales, guardado y datos. Uso: godot --headless --path . --script res://tests/world.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model() -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe": party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = 7
	return m

func _run(m: GameModel, quarters: int, quiet: bool = false) -> void:
	m.eco.ensure()
	if quiet:
		m.macro.st()["quiet"] = 999
	for i in range(quarters):
		m.eco.tick()
		m.gov_month += Rules.TURN_MONTHS

func _initialize() -> void:
	print("== Datos")
	var inds := WorldSim.indicators()
	check(inds.size() >= 30, "%d indicadores" % inds.size())
	check(Policies.measures().size() >= 150, "%d medidas" % Policies.measures().size())
	check(Policies.areas().size() >= 18, "%d áreas" % Policies.areas().size())
	var m0 := _model()
	m0.world.ensure()
	var ok_start := true
	for it in inds:
		if absf(m0.world.value(str((it as Dictionary)["id"])) - float((it as Dictionary)["start"])) > 0.0001: ok_start = false
	check(ok_start, "los indicadores arrancan en su valor inicial")
	check(m0.world.edges().size() > 80, "grafo con %d vínculos" % m0.world.edges().size())

	print("== Estabilidad sin cambiar nada (20 trimestres)")
	var m := _model()
	_run(m, 20)
	var worst := 0.0
	var worst_id := ""
	var in_range := true
	for it in inds:
		var d: Dictionary = it
		var id := str(d["id"])
		var zz := absf(m.world.z(id))
		if zz > worst:
			worst = zz
			worst_id = id
		var v := m.world.value(id)
		if v < float(d["min"]) - 0.001 or v > float(d["max"]) + 0.001: in_range = false
	print("   mayor desviación: %s = %.2f z" % [worst_id, worst])
	check(in_range, "todos los indicadores dentro de rango")
	check(worst < 2.5, "ningún indicador se descontrola sin medidas (%.2f z)" % worst)
	var e := m.eco.st()
	check(float(e["growth"]) > -1.0 and float(e["growth"]) < 4.5, "crecimiento razonable %.2f" % float(e["growth"]))
	check(float(e["unemployment"]) > 8.0 and float(e["unemployment"]) < 15.5, "paro razonable %.2f" % float(e["unemployment"]))
	check(float(e["inflation"]) > 0.0 and float(e["inflation"]) < 6.5, "inflación razonable %.2f" % float(e["inflation"]))
	check(m.world.history().size() >= 18, "historial de %d trimestres" % m.world.history().size())

	print("== Direcciones causales (8 trimestres frente a la línea base, sin shocks)")
	var base := _model()
	_run(base, 8, true)
	var cases := [
		["IVA general +4 puntos", {"vat_general": 25}, "consumption", -1],
		["Impuesto a los carburantes +40", {"fuel_tax": 140}, "emissions", -1],
		["Tope general al alquiler", {"rent_cap": 3}, "rent_burden", -1],
		["Salario mínimo +200 €", {"min_wage": 1334}, "wages", 1],
		["Inversión en I+D", {"rd_budget": 12}, "r_d", 1],
		["Cierre del carbón", {"coal_phaseout": 3}, "emissions", -1],
		["Presupuesto de sanidad +20", {"health_budget": 115}, "waiting", -1],
		["Lucha anticorrupción", {"anticorruption": 2}, "transparency", 1],
		["Abono gratuito", {"free_transit": 2}, "transit_share", 1],
		["Cheque bebé + permisos", {"birth_bonus": 2, "maternity_leave": 2}, "birth", 1],
		["Control de fronteras y expulsiones", {"border_control": 2, "deportation": 2}, "net_migration", -1],
		["Renta básica", {"basic_income": 2}, "poverty", -1],
		["Aranceles agrícolas", {"farm_tariffs": 2}, "farm_income", 1],
		["Fracking", {"fracking": 2}, "energy_price", -1],
	]
	for c in cases:
		var mm := _model()
		for k in (c[1] as Dictionary).keys():
			mm.eco.set_value(str(k), float(c[1][k]))
		_run(mm, 8, true)
		var dv := mm.world.value(str(c[2])) - base.world.value(str(c[2]))
		check(dv * float(c[3]) > 0.0, "%s → %s %+.2f" % [c[0], c[2], dv])

	print("== Repercusión global (IVA)")
	var mv := _model()
	mv.eco.set_value("vat_general", 25.0)
	_run(mv, 8, true)
	check(mv.eco.balance() > base.eco.balance() - 5.0, "el IVA mejora la recaudación (%+.1f bn)" % (mv.eco.balance() - base.eco.balance()))
	check(float(mv.eco.st()["inflation"]) > float(base.eco.st()["inflation"]) - 0.05, "sube la inflación o se mantiene")
	check(mv.world.value("consumption") < base.world.value("consumption"), "cae el consumo")
	check(mv.eco.satisfaction("vulnerables") < base.eco.satisfaction("vulnerables"), "los vulnerables lo notan")
	check(not m.world.group_term("jovenes", "rent_burden") > 100.0, "términos de grupo calculables")

	print("== Explicaciones")
	var drv := mv.world.target_parts("consumption")
	check(not drv.is_empty(), "el consumo tiene componentes (%d)" % drv.size())
	var pd := mv.world.policy_drivers("consumption")
	check(not pd.is_empty() and str((pd[0] as Dictionary)["measure"]) != "", "medidas que mueven el consumo: %d" % pd.size())
	check(not mv.world.measure_links("vat_general").is_empty(), "enlaces de una medida")
	check(mv.world.series("wages", 8).size() == 8, "serie de 8 trimestres")

	print("== Guardado")
	var v1 := mv.world.value("consumption")
	check(is_equal_approx(v1, float((mv.s["world"]["v"] as Dictionary)["consumption"])) if mv.s.has("world") else true, "estado en el guardado")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
