extends SceneTree
## Motor de encuentros: variedad, no repetición, efectos reales y recuerdo de lo dicho.
## Uso: godot --headless --path . --script res://tests/encounters.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model(pid: String, seed_v: int, character := {}) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == pid:
			party = (p as Dictionary).duplicate(true)
	if not character.is_empty():
		party["character"] = character
	var m := GameModel.new({"schema_version": 3, "save_id": "etest", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = seed_v
	return m

func _initialize() -> void:
	var m := _model("psoe", 11)
	print("== Variedad y no repetición")
	var texts: Dictionary = {}
	var answers: Dictionary = {}
	var kinds: Dictionary = {}
	var total := 0
	var types := ["Entrevista", "Debate", "Rueda de prensa", "Podcast"]
	for i in range(18):
		var ev := {"type": types[i % 4], "title": "Acto %d" % i, "region": "Madrid"}
		var s := m.enc.build_session(ev)
		for qd in s["questions"]:
			var q: Dictionary = qd
			total += 1
			texts[str(q["text"])] = true
			kinds[str(q["kind"])] = true
			var arch_seen: Dictionary = {}
			for ad in q["answers"]:
				answers[str((ad as Dictionary)["text"])] = true
				arch_seen[str((ad as Dictionary)["arch"])] = true
			check_quiet(arch_seen.size() == (q["answers"] as Array).size(), "")
			check_quiet((q["answers"] as Array).size() >= 3, "")
	print("  preguntas: %d · únicas: %d · respuestas únicas: %d · tipos: %d" % [total, texts.size(), answers.size(), kinds.size()])
	check(texts.size() >= int(total * 0.9), "al menos el 90%% de las preguntas son distintas (%d/%d)" % [texts.size(), total])
	check(answers.size() >= 120, "respuestas muy variadas (%d)" % answers.size())
	check(kinds.size() >= 7, "se usan al menos 7 tipos de pregunta (%d)" % kinds.size())
	print("== Efectos reales")
	var m2 := _model("pp", 21)
	var ev2 := {"type": "Entrevista", "title": "Prueba", "region": "Madrid"}
	var s2 := m2.enc.build_session(ev2)
	var q0: Dictionary = s2["questions"][0]
	var img0: Dictionary = m2.enc.image().duplicate(true)
	var poll0 := m2.player_poll()
	var tr0 := m2.trust
	var changed := false
	for qd in s2["questions"]:
		var q: Dictionary = qd
		var r := m2.enc.resolve(s2, q, (q["answers"] as Array)[0] as Dictionary)
		check_quiet(r.has("react") and r.has("grade"), "")
		changed = changed or not (r["chips"] as Array).is_empty()
	check(changed, "las respuestas producen cambios visibles")
	var img1: Dictionary = m2.enc.image()
	var moved := false
	for k in img1.keys():
		if absf(float(img1[k]) - float(img0[k])) > 0.01:
			moved = true
	check(moved, "la imagen ante los votantes cambia")
	var res := m2.enc.finish(s2, ev2)
	check(str(ev2["status"]) == "done" and str(res["summary"]) != "", "el acto se cierra con titular")
	check(m2.news().size() > 0, "el titular llega a la bandeja")
	check(m2.enc.hemeroteca().size() > 0, "queda en la hemeroteca")
	print("== Atributos del personaje importan")
	var good := Leader.default_character()
	good["stats"] = {"carisma": 8, "oratoria": 8, "honestidad": 8, "experiencia": 8, "mano_izquierda": 8, "firmeza": 8}
	var bad := Leader.default_character()
	bad["stats"] = {"carisma": 3, "oratoria": 3, "honestidad": 3, "experiencia": 3, "mano_izquierda": 3, "firmeza": 3}
	var avg_good := _avg_quality(good)
	var avg_bad := _avg_quality(bad)
	print("  calidad media: bueno %.3f · malo %.3f" % [avg_good, avg_bad])
	check(avg_good > avg_bad + 0.15, "un líder con mejores atributos responde mejor")
	print("== Ideología y coherencia")
	var right := _model("pp", 5)
	var left_plan := {"arch": "plan_left", "text": "x", "tag": "", "stat": "oratoria", "stat_name": "", "target": ""}
	var right_plan := {"arch": "plan_right", "text": "x", "tag": "", "stat": "oratoria", "stat_name": "", "target": ""}
	var ql := 0.0
	var qr := 0.0
	for i in range(40):
		var sx := right.enc.build_session({"type": "Entrevista", "title": "t%d" % i})
		var qq := {"kind": "policy", "topic": "tax", "issue": "tax", "mood": "neutral", "rival": "psoe"}
		ql += float(right.enc.resolve(sx, qq, left_plan)["quality"])
		qr += float(right.enc.resolve(sx, qq, right_plan)["quality"])
	check(qr > ql + 5.0, "un partido de derechas rinde mejor con un plan de derechas (%.1f vs %.1f)" % [qr, ql])
	print("== Relaciones y memoria")
	var m3 := _model("psoe", 31)
	var rel0 := m3.ai.relation("pp")
	var s3 := m3.enc.build_session({"type": "Debate", "title": "d"})
	var qa := {"kind": "rival", "topic": "tax", "issue": "tax", "mood": "hostile", "rival": "pp"}
	var atk := {"arch": "attack", "text": "x", "tag": "", "stat": "firmeza", "stat_name": "", "target": "pp"}
	m3.enc.resolve(s3, qa, atk)
	check(m3.ai.relation("pp") < rel0, "atacar a un partido deteriora la relación")
	check(not m3.enc.said_about("pp").is_empty(), "queda constancia de lo dicho sobre ese partido")
	var cnd := {"kind": "pact", "topic": "", "issue": "", "mood": "neutral", "rival": "sumar"}
	var hand := {"arch": "concede", "text": "x", "tag": "", "stat": "mano_izquierda", "stat_name": "", "target": "sumar"}
	var rs0 := m3.ai.relation("sumar")
	m3.enc.resolve(s3, cnd, hand)
	check(m3.ai.relation("sumar") > rs0, "tender la mano a un partido mejora la relación")
	# Contradicción
	var m4 := _model("psoe", 41)
	var s4 := m4.enc.build_session({"type": "Entrevista", "title": "e"})
	var qt := {"kind": "policy", "topic": "tax", "issue": "tax", "mood": "neutral", "rival": "pp"}
	m4.enc.resolve(s4, qt, {"arch": "plan_left", "text": "Quien más tiene más aporta", "tag": "", "stat": "oratoria", "stat_name": "", "target": ""})
	m4.enc.resolve(s4, qt, {"arch": "plan_right", "text": "Bajar impuestos a todos", "tag": "", "stat": "oratoria", "stat_name": "", "target": ""})
	var found := false
	for i in range(12):
		var sx2 := m4.enc.build_session({"type": "Entrevista", "title": "f%d" % i})
		for q in sx2["questions"]:
			if str((q as Dictionary)["kind"]) == "flipflop":
				found = true
	check(found, "la contradicción acaba saliendo en una pregunta de hemeroteca")
	print("== Bandeja e incidentes")
	var m5 := _model("psoe", 51)
	var msg := m5.enc.press_question()
	check(bool(msg["needs_response"]) and (msg["actions"] as Array).size() >= 3, "pregunta de prensa con opciones en la bandeja")
	var fb := m5.do_news_action(int(msg["id"]), "press:0")
	check(fb != "" and bool(m5.find_news(int(msg["id"]))["resolved"]), "se puede contestar desde la bandeja (%s)" % fb.substr(0, 40))
	var got := false
	for i in range(40):
		if m5.enc.maybe_incident("sumar", true):
			got = true
			break
	check(got, "los incidentes tras reuniones ocurren")
	var inc: Dictionary = m5.news()[0]
	var fb2 := m5.do_news_action(int(inc["id"]), "incident:0")
	check(fb2 != "", "un incidente se puede resolver (%s)" % fb2.substr(0, 40))
	print("== Abandonar el plató")
	var ma := _model("psoe", 77)
	var sa := ma.enc.build_session({"type": "Debate", "title": "Plantón", "region": "Madrid"})
	var trust_a0 := ma.trust
	var img_a0 := ma.enc.image_avg()
	var resa := ma.enc.abandon(sa, {"type": "Debate", "title": "Plantón"}, 3)
	check(bool(resa.get("abandoned", false)), "abandonar devuelve resultado marcado")
	check(ma.trust < trust_a0 - 5.0, "abandonar cuesta confianza (%.1f → %.1f)" % [trust_a0, ma.trust])
	check(ma.enc.image_avg() < img_a0, "abandonar daña la imagen")
	check(str((resa["headline"] as Dictionary).get("tone", "")) == "warning", "los medios lo cuentan como un plantón")
	var mb := _model("psoe", 77)
	var sb := mb.enc.build_session({"type": "Debate", "title": "Plantón", "region": "Madrid"})
	var resb := mb.enc.abandon(sb, {"type": "Debate", "title": "Plantón"}, 0)
	check(mb.trust < trust_a0, "abandonar al final también tiene coste")
	check(ma.trust < mb.trust, "cuanto más queda por responder, mayor el castigo")
	for fmt_id in MediaDB.FORMATS.keys():
		check(float(MediaDB.FORMATS[fmt_id]["secs"]) >= 20.0, "formato %s con tiempo suficiente para leer" % fmt_id)
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)

func check_quiet(cond: bool, _l: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL (silencioso)")

func _avg_quality(ch: Dictionary) -> float:
	var t := 0.0
	var n := 0
	for seed_v in range(8):
		var m := _model("psoe", 100 + seed_v, ch.duplicate(true))
		var s := m.enc.build_session({"type": "Entrevista", "title": "q"})
		for qd in s["questions"]:
			var q: Dictionary = qd
			for ad in q["answers"]:
				if str((ad as Dictionary)["arch"]) in ["data", "honest", "empathy", "attack", "plan_centre"]:
					t += float(m.enc.resolve(s, q, ad as Dictionary)["quality"])
					n += 1
	return t / maxf(float(n), 1.0)
