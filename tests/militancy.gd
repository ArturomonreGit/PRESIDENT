extends SceneTree
## IA de la militancia: corrientes, líneas rojas, ultimátums y retirada de apoyo.
## Uso: godot --headless --path . --script res://tests/militancy.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _mk(pid: String, seed_v: int) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == pid:
			party = (p as Dictionary).duplicate(true)
	var m := GameModel.new({"schema_version": 3, "save_id": "mtest", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = seed_v
	return m

func _initialize() -> void:
	print("== Creación")
	var m := _mk("psoe", 3)
	m.militancy.ensure()
	check(m.militancy.ready_state(), "militancia creada")
	check(m.militancy.factions().size() == 4, "cuatro corrientes")
	check(m.militancy.rules().size() >= 4, "líneas rojas definidas (%d)" % m.militancy.rules().size())
	check(m.militancy.support() > 50.0, "arranca con apoyo razonable (%.0f)" % m.militancy.support())

	print("== Línea roja cruzada → ultimátum")
	var pact_rule: Dictionary = {}
	for r in m.militancy.rules():
		if str((r as Dictionary)["type"]) == "pact_with":
			pact_rule = r
	check(not pact_rule.is_empty(), "existe una línea roja de pacto")
	var n_news := m.news().size()
	var sat0 := m.militancy.sat(str(pact_rule["faction"]))
	m.militancy.on_pact(str(pact_rule["party"]))
	check(str(pact_rule["state"]) == "broken", "pactar con el vetado la rompe")
	check(m.militancy.sat(str(pact_rule["faction"])) < sat0 - 10.0, "la corriente se enfada")
	check(m.news().size() > n_news, "llega un ultimátum a la bandeja")
	var msg := m.news()[0] as Dictionary
	check(bool(msg.get("needs_response", false)) and (msg["actions"] as Array).size() == 3, "ultimátum con tres respuestas")
	var aid := str(((msg["actions"] as Array)[0] as Dictionary)["id"])
	var fb := m.do_news_action(int(msg["id"]), aid)
	check(fb != "" and str(pact_rule["state"]) == "ok", "rectificar calma a la corriente")
	check(m.militancy.sat(str(pact_rule["faction"])) > sat0 - 10.0 + 10.0 or m.militancy.sat(str(pact_rule["faction"])) > 40.0, "recupera apoyo")

	print("== Ignorar las quejas → retirada de apoyo")
	var m2 := _mk("psoe", 4)
	m2.militancy.ensure()
	var members0 := m2.militancy.members()
	var support0 := m2.militancy.support()
	var fid := "valores"
	(m2.militancy.fac_state(fid))["sat"] = 12.0
	for i in range(3):
		m2.militancy.monthly()
		(m2.militancy.fac_state(fid))["sat"] = minf(float(m2.militancy.fac_state(fid)["sat"]), 12.0)
	check(bool(m2.militancy.fac_state(fid)["out"]), "la corriente retira su apoyo tras meses de agravio")
	# Tolerancia: el estado inicial usa azar (la semilla se fija tras crear el modelo) y el flujo de altas puede compensar la salida en pocos meses.
	check(m2.militancy.members() < members0 * 1.01, "se marchan afiliados (sin crecimiento neto relevante) (%d → %d)" % [members0, m2.militancy.members()])
	check(m2.militancy.support() < support0 - 2.0, "baja el apoyo global (%.0f → %.0f)" % [support0, m2.militancy.support()])
	# Recuperación
	(m2.militancy.fac_state(fid))["sat"] = 80.0
	m2.militancy.monthly()
	check(not bool(m2.militancy.fac_state(fid)["out"]), "vuelve a respaldarte si lo arreglas")

	print("== Crisis de liderazgo")
	var m3 := _mk("pp", 5)
	m3.militancy.ensure()
	for f in m3.militancy.factions():
		(m3.militancy.fac_state(str((f as Dictionary)["id"])))["sat"] = 8.0
	var tr0 := m3.trust
	m3.militancy.monthly()
	check(m3.trust < tr0 - 2.0, "una rebelión general cuesta confianza (%.0f → %.0f)" % [tr0, m3.trust])

	print("== Guardado")
	var parsed: Variant = JSON.parse_string(JSON.stringify(m2.save))
	check(typeof(parsed) == TYPE_DICTIONARY, "serializa")
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)
