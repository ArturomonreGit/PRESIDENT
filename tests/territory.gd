extends SceneTree
## Partido propio territorial (regionalismo / independentismo): solo se presenta en una comunidad y puede ampliar.
## Uso: godot --headless --path . --script res://tests/territory.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _initialize() -> void:
	var party := {"id": "custom_player", "name": "Compromiso Territorial", "short_name": "CT", "color": "#E85D04", "is_custom": true, "leader": "Marc Test",
		"ideology": {"economic": -0.1, "social": -0.2, "territorial": 0.8},
		"ideology_profile": {"regionalismo": 80, "progresismo": 50}, "territory": ["Cataluña"]}
	var m := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	m.autosave = false
	check(m.is_regional(m.pid()), "el partido es territorial")
	var share := m.community_share(["Cataluña"])
	check(share > 0.10 and share < 0.25, "Cataluña pesa %.1f %% del censo" % (share * 100.0))
	check(m.communities().size() >= 15, "comunidades en el mapa (%d)" % m.communities().size())
	var p0 := m.player_poll()
	check(p0 > 0.3 and p0 < 2.0, "encuesta nacional inicial acorde al territorio (%.2f)" % p0)
	var proj := m.election.project_full()
	var by_prov: Dictionary = proj["by_province"]
	var outside := 0
	var inside := 0
	for c in m.constituencies:
		var cd: Dictionary = c
		var seats := int((by_prov.get(str(cd["id"]), {}) as Dictionary).get(m.pid(), 0))
		if str(cd.get("autonomous_community", "")) == "Cataluña": inside += seats
		else: outside += seats
	check(outside == 0, "ningún escaño fuera de su comunidad (%d)" % outside)
	check(inside > 0, "obtiene escaños en su comunidad (%d)" % inside)
	var share_cat := 0.0
	for c in m.constituencies:
		var cd2: Dictionary = c
		if str(cd2.get("autonomous_community", "")) == "Cataluña":
			share_cat = maxf(share_cat, float(((proj["shares"] as Dictionary).get(str(cd2["name"]), {}) as Dictionary).get(m.pid(), 0.0)))
	print("  voto máximo local: %.1f %%" % share_cat)
	check(share_cat > 3.0 and share_cat < 15.0, "voto local de partida razonable")
	# Ampliación
	check(m.campaign.can_expand() == "", "puede ampliar")
	var cost := m.campaign.expansion_cost("Galicia")
	check(cost > 80000 and cost < 600000, "coste de ampliar (%d)" % cost)
	m.funds = 0.0
	check(m.campaign.expand_territory("Galicia") != "", "sin fondos no amplía")
	m.funds = 2000000.0
	check(m.campaign.expand_territory("Galicia") == "", "amplía a Galicia con fondos")
	check((m.s["player_territory"] as Array).size() == 2, "territorio con 2 comunidades")
	check(m.funds < 2000000.0, "se descuenta el coste")
	check(m.campaign.expand_territory("Galicia") != "", "no repite comunidad")
	var tot := 0.0
	for v in m.polls().values(): tot += float(v)
	check(absf(tot - 100.0) < 0.01, "encuestas suman 100 (%.3f)" % tot)
	# Cobertura total → partido estatal
	for cn in m.communities():
		if not (m.s["player_territory"] as Array).has(cn):
			m.s["player_territory"].append(cn)
	check(not m.is_regional(m.pid()), "con todas las comunidades pasa a ser estatal")
	# Guardado
	var parsed: Variant = JSON.parse_string(JSON.stringify(m.save))
	var m2 := GameModel.new(parsed)
	m2.autosave = false
	check((m2.s.get("player_territory", []) as Array).size() == m.communities().size(), "el territorio sobrevive al guardado")
	print("== Fallos: ", failures)
	quit(1 if failures > 0 else 0)
