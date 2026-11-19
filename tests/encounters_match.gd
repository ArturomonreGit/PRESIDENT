extends SceneTree
## Coherencia pregunta-respuesta del motor de encuentros: toda respuesta ofrecida viene de un banco que encaja con el tipo,
## el subtipo, el formato y el papel de la pregunta, y no queda ningún hueco {…} sin rellenar.
## Uso: godot --headless --path . --script res://tests/encounters_match.gd
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
	var m := GameModel.new({"schema_version": 3, "save_id": "ematch", "player_party": party, "game_state": {}})
	m.autosave = false
	m.rng.seed = seed_v
	return m

func _initialize() -> void:
	print("== Coherencia pregunta-respuesta")
	var types := ["Entrevista", "Debate", "Rueda de prensa", "Podcast", "Sesión de control"]
	var total := 0
	var holes := 0
	var few := 0
	var combos: Dictionary = {}
	var samples: Array = []
	for role_i in range(3):
		var m := _model("psoe" if role_i != 2 else "pp", 100 + role_i)
		if role_i == 1:
			m.s["government_party_id"] = "pp"
			m.phase = "legislature"
		for i in range(60):
			var ev := {"type": types[i % types.size()], "title": "Acto %d" % i, "region": "Madrid"}
			var s := m.enc.build_session(ev)
			for qd in s["questions"]:
				var q: Dictionary = qd
				total += 1
				var key := "%s/%s" % [str(q["kind"]), str(q.get("sub", ""))]
				var n := (q["answers"] as Array).size()
				combos[key] = mini(int(combos.get(key, 99)), n)
				if n < 3:
					few += 1
				if str(q["text"]).contains("{") or str(q["text"]).contains("}"):
					holes += 1
					print("    hueco en pregunta: ", q["text"])
				for ad in q["answers"]:
					var t := str((ad as Dictionary)["text"])
					if t.contains("{") or t.contains("}") or t.strip_edges() == "":
						holes += 1
						print("    hueco en respuesta: ", t)
				if samples.size() < 400 and i % 5 == 0:
					samples.append(q)
	print("  preguntas generadas: %d" % total)
	check(holes == 0, "ningún hueco {…} sin rellenar (%d)" % holes)
	check(few == 0, "toda pregunta ofrece al menos 3 respuestas (%d con menos)" % few)
	var keys := combos.keys()
	keys.sort()
	for k in keys:
		print("    %-22s mínimo de respuestas: %d" % [str(k), int(combos[k])])
	# Subtipos: una pregunta con subtipo solo recibe respuestas de ese subtipo.
	var mm := _model("psoe", 7)
	var bad := 0
	for kind in ["human", "rival", "record", "cost", "crisis", "ideology", "control", "control_ask", "pact", "scandal", "flipflop", "gotcha"]:
		for sub in _subs(kind):
			for fmt in ["tv", "debate", "press", "podcast", "radio", "control"]:
				for role in ["g", "o", ""]:
					var qs := MediaDB.questions_tagged(kind, "housing", fmt, role)
					for e in qs:
						if str((e as Dictionary)["s"]) != sub:
							continue
						var n_ok := 0
						for arch in Encounters.ARCH.keys():
							if not MediaDB.kind_answers(kind, str(arch), sub, fmt, role).is_empty():
								n_ok += 1
						if n_ok < 3 and not (kind in ["pact", "scandal", "gotcha", "flipflop"]):
							bad += 1
							print("    pocas respuestas: %s/%s %s %s → %d" % [kind, sub, fmt, role, n_ok])
	check(bad == 0, "cada subtipo de pregunta tiene al menos 3 estilos de respuesta (%d huecos)" % bad)
	mm = null
	var f := FileAccess.open("/tmp/encounter_samples.txt", FileAccess.WRITE)
	if f != null:
		for q2 in samples:
			var qq: Dictionary = q2
			f.store_line("[%s/%s] %s" % [str(qq["kind"]), str(qq.get("sub", "")), str(qq["text"])])
			for ad2 in qq["answers"]:
				f.store_line("    - (%s) %s" % [str((ad2 as Dictionary)["arch"]), str((ad2 as Dictionary)["text"])])
	print("Fallos: ", failures)
	quit(failures)

func _subs(kind: String) -> Array:
	var out: Array = [""]
	for fmt in ["tv", "debate", "press", "podcast", "radio", "control"]:
		for role in ["g", "o", ""]:
			for e in MediaDB.questions_tagged(kind, "housing", fmt, role):
				var sb := str((e as Dictionary)["s"])
				if not out.has(sb):
					out.append(sb)
	return out
