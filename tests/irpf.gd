extends SceneTree
## IRPF por tramos. Uso: godot --headless --path . --script res://tests/irpf.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _init() -> void:
	var d := Irpf.default_scale()
	check(d.size() == 6 and absf(Irpf.tax(d, 12.45) - 12.45 * 0.19) < 0.001, "cuota del primer tramo")
	check(Irpf.rate_at(d, 400.0) > Irpf.rate_at(d, 20.0), "el tipo efectivo es progresivo")
	var s := Irpf.sanitize([{"from": 30.0, "rate": 70.0}, {"from": 5.0, "rate": 10.0}, {"from": 5.0, "rate": 12.0}])
	check(s.size() == 2 and float((s[0] as Dictionary)["from"]) == 0.0 and float((s[1] as Dictionary)["rate"]) == Irpf.MAX_RATE, "sanitize ordena, fuerza el 0 y limita el tipo")
	var many: Array = []
	for i in range(20): many.append({"from": float(i * 10), "rate": 20.0})
	check(Irpf.sanitize(many).size() == Irpf.MAX_BRACKETS, "máximo de tramos")
	var up := d.duplicate(true)
	for b in up: (b as Dictionary)["rate"] = float((b as Dictionary)["rate"]) + 3.0
	var e := Irpf.delta_effects(d, up, 135.0)
	check(float(e["rev"]) > 0.0 and float((e["hits"] as Dictionary)["trabajadores"]) < 0.0 and float((e["fx"] as Dictionary)["growth"]) < 0.0, "subir tipos recauda, enfada y frena el crecimiento")
	var e0 := Irpf.delta_effects(d, d, 135.0)
	check(absf(float(e0["rev"])) < 0.0001, "misma escala: efecto nulo")
	check(Irpf.distance(d, d) == 0.0 and Irpf.distance(d, up) > 0.0, "distancia entre escalas")
	# Integración con la economía y las leyes
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == "psoe": party = p
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	m.eco.ensure()
	var law := m.laws.new_draft("tax")
	m.laws.set_irpf(law, up)
	check((law["changes"] as Dictionary).has(Irpf.SPECIAL_ID), "la ley recoge el cambio de IRPF")
	var pv := m.eco.preview(law["changes"], m.laws.proposed_irpf(law))
	check(float(pv["revenue"]) > 0.0, "la previsión de la ley incluye la recaudación (%.1f)" % float(pv["revenue"]))
	m.eco.apply_law(law)
	check(Irpf.same(m.eco.irpf_brackets(), Irpf.sanitize(up)), "aprobada, la escala nueva queda vigente")
	check(absf(m.eco.value(Irpf.SPECIAL_ID) - Irpf.average_rate(up)) < 0.001, "el valor escalar es el tipo medio vigente")
	m.laws.set_irpf(law, Irpf.sanitize(up))
	check(not (law["changes"] as Dictionary).has(Irpf.SPECIAL_ID), "proponer la escala vigente no cambia nada")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
