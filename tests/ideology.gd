extends SceneTree
## Comprueba el catálogo de ideologías, la composición por fuerza y la fidelidad ideológica de la IA.
## Uso: godot --headless --path . --script res://tests/ideology.gd

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _custom(picks: Array, name := "Mi Partido") -> Dictionary:
	var comp := Ideology.compose(picks)
	return {"id": "custom_player", "name": name, "short_name": "MP", "color": "#E0A93B", "is_custom": true,
		"ideology": comp["axes"], "ideology_profile": comp["profile"], "ideology_picks": comp["picks"], "coherence": comp["coherence"]}

func _model(party: Dictionary) -> GameModel:
	var m := GameModel.new({"schema_version": 3, "save_id": "itest", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = 777
	return m

func _initialize() -> void:
	print("== Catálogo y composición")
	check(Ideology.CATALOG.size() >= 20, "catálogo con al menos 20 ideologías (%d)" % Ideology.CATALOG.size())
	var ids: Dictionary = {}
	for it in Ideology.CATALOG:
		var d: Dictionary = it
		check(not ids.has(d["id"]), "id único %s" % d["id"]) if ids.has(d["id"]) else null
		ids[d["id"]] = true
		for k in (d["profile"] as Dictionary).keys():
			if not PartyBrain.PROFILE_KEYS.has(k):
				failures += 1
				print("  FAIL clave de perfil desconocida ", k, " en ", d["id"])
	check(not Ideology.compose([]).is_empty(), "compose([]) no falla")
	var weak := Ideology.compose([{"id": "socialismo", "strength": 1}])
	var strong := Ideology.compose([{"id": "socialismo", "strength": 5}])
	check(int(strong["profile"]["socialismo"]) > int(weak["profile"]["socialismo"]), "más fuerza = más peso en el perfil")
	check(float(strong["axes"]["economic"]) < float(weak["axes"]["economic"]), "más fuerza = posición más extrema")
	var clash := Ideology.compose([{"id": "liberalismo", "strength": 5}, {"id": "socialismo", "strength": 5}])
	var calm := Ideology.compose([{"id": "liberalismo", "strength": 5}, {"id": "conservadurismo", "strength": 5}])
	check(float(clash["coherence"]) < float(calm["coherence"]), "ideologías opuestas restan coherencia")
	check(Ideology.normalize([{"id": "x", "strength": 3}, {"id": "socialismo", "strength": 9}, {"id": "socialismo", "strength": 2}]).size() == 1, "normalize descarta desconocidas y duplicadas")
	check(str(strong["bloc"]).begins_with("Izquierda"), "socialismo fuerte = izquierda (%s)" % strong["bloc"])
	check(str(Ideology.compose([{"id": "nacionalpopulismo", "strength": 5}])["bloc"]).begins_with("Derecha"), "nacional-populismo = derecha")

	print("== Afinidad prevista")
	var left := Ideology.compose([{"id": "socialdemocracia", "strength": 5}, {"id": "ecologismo", "strength": 3}])
	var prev := Ideology.preview(left)
	var rank: Dictionary = {}
	for i in range(prev.size()):
		rank[(prev[i] as Dictionary)["id"]] = i
	check(int(rank["psoe"]) < int(rank["pp"]), "una izquierda socialdemócrata es más afín al PSOE que al PP")
	check(int(rank["sumar"]) < int(rank["vox"]), "…y a Sumar que a Vox")
	var right := Ideology.compose([{"id": "nacionalpopulismo", "strength": 5}, {"id": "conservadurismo", "strength": 3}])
	var rp := Ideology.preview(right)
	check(str((rp[0] as Dictionary)["id"]) in ["vox", "upn", "pp"], "una derecha nacional-populista es afín a Vox/UPN/PP (%s)" % str((rp[0] as Dictionary)["id"]))

	print("== Fidelidad ideológica de la IA (jugador de izquierdas)")
	var m := _model(_custom([{"id": "socialismo", "strength": 5}, {"id": "feminismo", "strength": 3}, {"id": "ecologismo", "strength": 2}]))
	check(m.brain.compat("custom_player", "sumar") > m.brain.compat("custom_player", "vox"), "el partido propio es más afín a Sumar que a Vox")
	check(m.brain.gate("vox", "custom_player", "joint_list") != "", "Vox no concurre en lista conjunta con una izquierda socialista")
	check(m.brain.gate("pp", "custom_player", "cabinet") != "", "el PP no formaría Gobierno con una izquierda socialista")
	check(m.brain.gate("sumar", "custom_player", "joint_list") == "", "Sumar sí puede ir en lista conjunta")
	check(not bool(m.diplomacy.open("vox", "joint_list")["ok"]), "no se abre una reunión de lista conjunta con Vox")
	var greedy_pkg: Array = [{"k": "joint_list", "by": "player"}, {"k": "cabinet", "by": "player", "n": 4}, {"k": "policy", "by": "player", "issue": "security", "text": "Mano dura"}]
	var v := m.brain.assess("vox", "custom_player", greedy_pkg, {"pivot": 1.0, "player_pivot": 1.0})
	check(str(v["verdict"]) == "veto", "ninguna oferta compra a Vox (veredicto %s)" % str(v["verdict"]))
	var v2 := m.brain.assess("sumar", "custom_player", [{"k": "joint_list", "by": "player"}, {"k": "cabinet", "by": "player", "n": 2}], {"pivot": 0.5, "player_pivot": 0.5})
	check(str(v2["verdict"]) != "veto", "Sumar no veta la lista conjunta (%s)" % str(v2["verdict"]))

	print("== Fidelidad ideológica de la IA (jugador de derecha radical)")
	var m2 := _model(_custom([{"id": "nacionalpopulismo", "strength": 5}, {"id": "conservadurismo", "strength": 4}]))
	check(m2.brain.gate("sumar", "custom_player", "joint_list") != "", "Sumar no va con una derecha radical")
	check(m2.brain.gate("psoe", "custom_player", "cabinet") != "", "el PSOE no gobernaría con una derecha radical")
	check(m2.brain.gate("erc", "custom_player", "stability") != "", "ERC no firma estabilidad con ella")
	check(m2.brain.gate("vox", "custom_player", "joint_list") == "", "Vox sí puede ir en lista conjunta")

	print("== Los partidos del escenario son coherentes entre sí")
	var base := _model(DataStore.parties()[0] as Dictionary)
	var bad_pairs := [["psoe", "vox"], ["sumar", "vox"], ["ehbildu", "vox"], ["erc", "pp"], ["bng", "vox"], ["pp", "ehbildu"]]
	for pair in bad_pairs:
		check(base.brain.gate(str(pair[0]), str(pair[1]), "joint_list") != "", "%s y %s no concurren juntos" % [pair[0], pair[1]])
		check(base.brain.gate(str(pair[0]), str(pair[1]), "cabinet") != "", "%s y %s no comparten Gobierno" % [pair[0], pair[1]])
	check(base.brain.gate("psoe", "sumar", "cabinet") == "", "PSOE y Sumar sí pueden gobernar juntos")
	check(base.brain.gate("pp", "vox", "cabinet") == "", "PP y Vox sí pueden gobernar juntos")
	check(base.brain.gate("junts", "pnv", "stability") == "", "Junts y PNV sí pueden pactar estabilidad")

	print("== Fallos: %d" % failures)
	quit(1 if failures > 0 else 0)
