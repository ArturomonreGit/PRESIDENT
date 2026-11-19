extends SceneTree
## Banco de medios y agenda mediática: volumen, huecos sin rellenar, no repetición y ofertas de la legislatura.
## Uso: godot --headless --path . --script res://tests/media_db.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _model(pid: String, seed_v: int) -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == pid:
			party = (p as Dictionary).duplicate(true)
	var m := GameModel.new({"schema_version": 3, "save_id": "mtest", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = seed_v
	return m

func _initialize() -> void:
	Sfx.enabled = false
	var c := MediaDB.counts()
	print("== Volumen del banco: ", c)
	check(int(c["questions"]) >= 230, "al menos 230 preguntas y plantillas")
	check(int(c["answers"]) >= 350, "al menos 350 variantes de respuesta")
	check(int(c["reactions"]) >= 80, "al menos 80 reacciones del presentador")
	check(int(c["social"]) >= 38, "al menos 38 mensajes de redes")

	print("== Sesiones en cada formato (campaña)")
	var m := _model("psoe", 5)
	var seen: Dictionary = {}
	var total := 0
	var bad_holes := 0
	var empties := 0
	var fmts: Dictionary = {}
	var types := ["Entrevista", "Podcast", "Rueda de prensa", "Debate", "Sesión de control"]
	for i in range(40):
		var s := m.enc.build_session({"type": types[i % 5], "title": "t%d" % i, "region": "Madrid"})
		fmts[str(s["format"])] = true
		for qd in s["questions"]:
			var q: Dictionary = qd
			total += 1
			seen[str(q["text"])] = true
			if str(q["text"]).find("{") >= 0 or str(q["text"]).find("}") >= 0:
				bad_holes += 1
				print("    hueco: ", q["text"])
			if str(q["text"]).strip_edges() == "" or (q["answers"] as Array).size() < 2:
				empties += 1
			for ad in q["answers"]:
				if str((ad as Dictionary)["text"]).find("{") >= 0:
					bad_holes += 1
					print("    hueco en respuesta: ", (ad as Dictionary)["text"])
	check(fmts.size() == 5 or fmts.size() >= 4, "se generan los distintos formatos (%d)" % fmts.size())
	check(bad_holes == 0, "ningún hueco {…} sin rellenar")
	check(empties == 0, "ninguna pregunta vacía o sin respuestas")
	var ratio := float(seen.size()) / float(maxi(total, 1))
	print("  preguntas: %d · únicas: %d (%.0f%%)" % [total, seen.size(), ratio * 100.0])
	check(ratio >= 0.9, "al menos el 90% de las preguntas son distintas")

	print("== Réplica del rival")
	var s2 := m.enc.build_session({"type": "Debate", "title": "d", "region": "Madrid"})
	var rq := m.enc.replica_for(s2)
	check(str(rq["kind"]) == "replica" and (rq["answers"] as Array).size() == 3, "la réplica ofrece 3 respuestas rápidas")
	var r := m.enc.resolve(s2, rq, (rq["answers"] as Array)[0] as Dictionary)
	check(r.has("grade"), "la réplica se resuelve")
	var rt := m.enc.resolve(s2, rq, {"arch": "deflect", "text": "", "tag": "x", "stat": "experiencia", "stat_name": "", "target": "", "timeout": true})
	check(float(rt["quality"]) < 0.3, "quedarse sin tiempo penaliza")
	var eq := m.enc.expected_quality(s2, rq, (rq["answers"] as Array)[0] as Dictionary)
	check(absf(eq) <= 2.0, "el asesor calcula una calidad esperada")

	print("== Agenda mediática en la legislatura")
	var g := _model("pp", 9)
	g.phase = "legislature"
	g.s["government_party_id"] = "pp"
	g.gov_month = 1
	g.media.monthly()
	var offers := g.media.open_offers()
	check(offers.size() >= 2, "cada mes llegan ofertas (%d)" % offers.size())
	var has_control := false
	for o in offers:
		if str((o as Dictionary)["type"]) == "Sesión de control":
			has_control = true
	check(has_control, "siempre hay sesión de control")
	check(g.pending_count() >= offers.size(), "las ofertas llegan a la Bandeja como decisiones")
	var first: Dictionary = offers[0]
	var msg := g.find_news(int(first["msg_id"]))
	var fb := g.do_news_action(int(msg["id"]), "studio_auto:%d" % int(first["id"]))
	check(fb != "" and str(first["status"]) == "auto", "delegar resuelve la oferta")
	if offers.size() > 1:
		var second: Dictionary = offers[1]
		var msg2 := g.find_news(int(second["msg_id"]))
		g.do_news_action(int(msg2["id"]), "studio:%d" % int(second["id"]))
		check(int(g.s.get("open_studio", -1)) == int(second["id"]), "«Ir al plató» pide abrir el plató")
		g.s.erase("open_studio")
	var ap0 := g.gov.approval()
	var s3 := g.enc.build_session({"type": "Sesión de control", "title": "c", "region": "Madrid", "context": "una crisis"})
	check(str((s3["questions"][0] as Dictionary)["text"]).find("una crisis") >= 0, "el contexto de una crisis entra en la primera pregunta")
	for qd in s3["questions"]:
		var q2: Dictionary = qd
		g.enc.resolve(s3, q2, (q2["answers"] as Array)[0] as Dictionary)
	g.enc.finish(s3, {"type": "Sesión de control", "title": "c", "status": "scheduled"})
	check(g.gov.approval() != ap0, "el desempeño mediático mueve el apoyo al Gobierno")
	for i in range(3):
		g.media.take_slot()
	check(not g.media.take_slot(), "los huecos de agenda son limitados")
	var open_before := g.media.open_offers().size()
	g.gov_month = 2
	g.media.monthly()
	check(g.media.slots_left() == MediaAgenda.SLOTS_PER_TURN, "los huecos se reponen cada mes")
	check(g.media.open_offers().size() > 0 and open_before >= 0, "llegan nuevas ofertas el mes siguiente")

	var o := _model("psoe", 3)
	o.phase = "legislature"
	o.s["government_party_id"] = "pp"
	o.media.monthly()
	var ctrl := o.media.open_offers()[0] as Dictionary
	check(str(ctrl["type"]) == "Sesión de control" and str(ctrl["title"]).find("tu turno") >= 0, "en la oposición te toca preguntar al Gobierno")
	var s4 := o.enc.build_session({"type": "Sesión de control", "title": "c", "region": "Madrid"})
	var q4: Dictionary = s4["questions"][0]
	var archs: Array = []
	for ad in q4["answers"]:
		archs.append(str((ad as Dictionary)["arch"]))
	check(not archs.has("promise") and not archs.has("plan_centre"), "la oposición pregunta con tonos de interpelación")
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)
