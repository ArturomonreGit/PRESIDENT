class_name Militancy
extends RefCounted
## IA de la militancia. El partido del jugador tiene cuatro corrientes internas con opiniones propias; cada una
## puntúa lo que haces (leyes que apruebas o votas, pactos, promesas, resultados) según SUS intereses, no los tuyos.
## La militancia fija líneas rojas por escrito: si las cruzas te lanzan un ultimátum; si no la contentas deja de
## apoyarte (se van afiliados, caen los ingresos y la confianza, y parte del electorado afín te castiga).
##
##  · doctrina    → eje económico: quiere que legisles en la dirección de las ideas del partido.
##  · valores     → eje social: derechos y modelo de sociedad.
##  · territorios → eje territorial: cómo se reparte el poder entre territorios.
##  · aparato     → poder y resultados: encuestas, estabilidad y cargos. Premia ganar y castiga perder.

const FACTIONS := [
	{"id": "doctrina", "name": "Guardianes de la doctrina", "desc": "Quieren leyes fieles a la ideología económica del partido.", "axis": 0, "power": 0.25},
	{"id": "valores", "name": "Activistas de valores", "desc": "Defienden derechos y modelo de sociedad; no perdonan los bandazos.", "axis": 1, "power": 0.20},
	{"id": "territorios", "name": "Barones y territorios", "desc": "Vigilan el reparto del poder entre territorios y las siglas locales.", "axis": 2, "power": 0.20},
	{"id": "aparato", "name": "El aparato", "desc": "Quieren ganar: encuestas, estabilidad y cargos. Toleran casi todo si se gana.", "axis": -1, "power": 0.35},
]
const AXIS_NAMES := ["económica", "de valores", "territorial"]

var m: GameModel

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	return m.d("militancy")

func ready_state() -> bool:
	return st().has("fac")

func factions() -> Array:
	return FACTIONS

func faction_def(id: String) -> Dictionary:
	for f in FACTIONS:
		if str((f as Dictionary)["id"]) == id:
			return f
	return {}

# ---------------------------------------------------------------- creación
func ensure() -> void:
	if ready_state():
		return
	var s := st()
	var fac: Dictionary = {}
	for f in FACTIONS:
		var fd: Dictionary = f
		fac[str(fd["id"])] = {"sat": 62.0 + m.rng.randf_range(-4.0, 4.0), "low": 0, "out": false, "ult": 0}
	s["fac"] = fac
	s["rules"] = _make_rules()
	s["poll_ref"] = maxf(m.player_poll(), 0.5)
	s["cool"] = 0
	s["log"] = []

func _axes() -> Array:
	var ax: Dictionary = m.party.get("ideology", {})
	return [float(ax.get("economic", 0.0)), float(ax.get("social", 0.0)), float(ax.get("territorial", 0.0))]

func _make_rules() -> Array:
	var rules: Array = []
	# Línea roja 1: pactar con quien más lejos está ideológicamente.
	var worst := ""
	var wc := 9.0
	for p in m.rivals:
		var id := str((p as Dictionary).get("id", ""))
		if m.poll_of(id) < 1.0:
			continue
		var c := m.brain.compat(m.pid(), id)
		if c < wc:
			wc = c
			worst = id
	if worst != "":
		rules.append({"id": "pact_" + worst, "type": "pact_with", "party": worst, "faction": "doctrina",
			"text": "No pactar con %s" % m.party_name(worst), "state": "ok"})
	# Línea roja 2 y 3: no legislar contra el propio rumbo en los ejes en los que el partido tiene posición.
	var ax := _axes()
	var order := [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return absf(float(ax[a])) > absf(float(ax[b])))
	var fac_by_axis := ["doctrina", "valores", "territorios"]
	var made := 0
	for i in order:
		if absf(float(ax[i])) < 0.2 or made >= 2:
			continue
		var sgn := 1 if float(ax[i]) > 0.0 else -1
		var txt := ""
		match i:
			0: txt = "No aprobar medidas económicas de signo %s" % ("izquierdista" if sgn > 0 else "liberal")
			1: txt = "No aprobar medidas que recorten derechos y libertades" if sgn < 0 else "No aprobar medidas que erosionen los valores tradicionales"
			2: txt = "No aprobar más autogobierno a costa del conjunto" if sgn < 0 else "No aprobar medidas que recentralicen competencias"
		rules.append({"id": "axis_%d" % i, "type": "law_axis", "axis": i, "sign": sgn, "faction": fac_by_axis[i], "text": txt, "state": "ok"})
		made += 1
	rules.append({"id": "promises", "type": "promises", "faction": "valores", "text": "Cumplir el programa: sin traiciones evidentes", "state": "ok"})
	rules.append({"id": "polls", "type": "polls", "faction": "aparato", "text": "No hundirse en las encuestas (por debajo del 70 % del punto de partida)", "state": "ok"})
	return rules

func rules() -> Array:
	ensure()
	return st()["rules"]

func fac_state(id: String) -> Dictionary:
	ensure()
	return (st()["fac"] as Dictionary).get(id, {})

func sat(id: String) -> float:
	return float(fac_state(id).get("sat", 60.0))

func _bump(id: String, delta: float) -> void:
	var f := fac_state(id)
	if f.is_empty():
		return
	f["sat"] = clampf(float(f["sat"]) + delta, 0.0, 100.0)

## Apoyo global de la militancia (0-100): media ponderada; una corriente en rebeldía pesa el doble en negativo.
func support() -> float:
	ensure()
	var total := 0.0
	for f in FACTIONS:
		var fd: Dictionary = f
		var s_f := sat(str(fd["id"]))
		var pw := float(fd["power"])
		if bool(fac_state(str(fd["id"])).get("out", false)):
			s_f = minf(s_f, 25.0)
		total += pw * s_f
	return total

func support_label() -> String:
	var v := support()
	if v >= 75.0:
		return "Entusiasmada"
	if v >= 58.0:
		return "Alineada"
	if v >= 42.0:
		return "Inquieta"
	if v >= 28.0:
		return "Rebelde"
	return "En ruptura"

func members() -> int:
	return int(m.s.get("members", 1200))

func _scale_members(factor: float) -> void:
	m.s["members"] = maxi(100, int(round(float(members()) * factor)))

func _log(text: String) -> void:
	var lg: Array = st().get("log", [])
	lg.push_front({"t": m.clock_unix(), "text": text})
	while lg.size() > 30:
		lg.pop_back()
	st()["log"] = lg

# ---------------------------------------------------------------- reacciones
func _law_dir(law: Dictionary) -> Array:
	var dir: Array = [0.0, 0.0, 0.0]
	var changes: Dictionary = law.get("changes", {})
	for mid in changes.keys():
		var meas := Policies.measure(str(mid))
		if meas.is_empty():
			continue
		var lean: Dictionary = meas.get("lean", {})
		var sgn := signf(float(changes[mid]) - float(meas.get("base", 0.0)))
		dir[0] = float(dir[0]) + float(lean.get("economic", 0.0)) * sgn
		dir[1] = float(dir[1]) + float(lean.get("social", 0.0)) * sgn
		dir[2] = float(dir[2]) + float(lean.get("territorial", 0.0)) * sgn
	return dir

## Una ley sale adelante: cada corriente la juzga por su eje; la responsabilidad depende de tu voto.
func on_law(law: Dictionary, res: Dictionary) -> void:
	ensure()
	if str(law.get("kind", "")) == "presupuestos" or not bool(res.get("passed", false)):
		return
	var proposer := str(law.get("proposer", ""))
	var vote := str(res.get("player_vote", ""))
	var resp := 0.0
	if proposer == m.pid() or vote == "yes":
		resp = 1.0
	elif vote == "abstain":
		resp = 0.4
	else:
		resp = -0.5
	var dir := _law_dir(law)
	var ax := _axes()
	var sum_mag := 0.0
	for i in range(3):
		sum_mag += absf(float(dir[i]))
	var fac_by_axis := ["doctrina", "valores", "territorios"]
	var worst_axis := -1
	var worst_val := 0.0
	for i in range(3):
		var expect := signf(float(ax[i])) if absf(float(ax[i])) >= 0.2 else 0.0
		var d := float(dir[i])
		var align := d * expect if expect != 0.0 else -absf(d) * 0.4
		var delta := clampf(align * 5.0 * resp, -14.0, 9.0)
		if resp < 0.0:
			# Votar en contra de algo que va contra el partido gusta; de algo que va a favor, no.
			delta = clampf(-align * 5.0 * 0.5, -6.0, 4.0)
		if absf(delta) >= 0.4:
			_bump(fac_by_axis[i], delta)
		if delta < worst_val:
			worst_val = delta
			worst_axis = i
	# El aparato sólo mira si el Gobierno funciona: aprobar leyes propias da sensación de poder.
	if proposer == m.pid():
		_bump("aparato", 2.0)
	# Líneas rojas cruzadas (sólo si la ley cuenta con tu voto a favor).
	if resp > 0.0:
		for r in rules():
			var rd: Dictionary = r
			if str(rd["type"]) == "law_axis":
				var i2 := int(rd["axis"])
				var moved := float(dir[i2]) * float(rd["sign"])
				if moved <= -0.5 and str(rd["state"]) == "ok":
					_cross(rd, "La ley «%s» va contra su línea roja" % str(law.get("title", "")))
	m.itrust.on_law(law, res, worst_axis, worst_val)

## Pactar con quien la militancia detesta rompe una línea roja y contenta al aparato si da poder.
func on_pact(partner: String) -> void:
	ensure()
	var c := m.brain.compat(m.pid(), partner)
	if c < 0.3:
		_bump("doctrina", -(0.3 - c) * 30.0)
		_bump("valores", -(0.3 - c) * 20.0)
	elif c > 0.6:
		_bump("doctrina", 3.0)
	_bump("aparato", 2.0)
	for r in rules():
		var rd: Dictionary = r
		if str(rd["type"]) == "pact_with" and str(rd["party"]) == partner and str(rd["state"]) == "ok":
			_cross(rd, "Has pactado con %s" % m.party_short(partner))

func on_government_formed() -> void:
	ensure()
	var gp := m.gov.government_parties()
	if gp.has(m.pid()):
		_bump("aparato", 12.0)
		for other in gp:
			if str(other) != m.pid():
				on_pact(str(other))
	else:
		_bump("aparato", -6.0)

func on_election(seats: int) -> void:
	ensure()
	var obj := m.d("objective")
	var target := int(obj.get("target_seats", 1))
	var met := seats >= target
	for f in FACTIONS:
		var fd: Dictionary = f
		var id := str(fd["id"])
		if id == "aparato":
			_bump(id, 14.0 if met else -16.0)
		else:
			_bump(id, 5.0 if met else -6.0)
	var s := st()
	s["poll_ref"] = maxf(m.player_poll(), 0.5)
	m.itrust.on_election(seats)
	for r in s["rules"]:
		if str((r as Dictionary)["type"]) in ["polls", "promises"]:
			(r as Dictionary)["state"] = "ok"

# ---------------------------------------------------------------- líneas rojas y ultimátums
func _cross(rule: Dictionary, why: String) -> void:
	rule["state"] = "broken"
	var fid := str(rule["faction"])
	_bump(fid, -22.0)
	m.trust = m.trust - 1.5
	var fd := faction_def(fid)
	_log("%s: %s." % [str(rule["text"]), why])
	var f := fac_state(fid)
	var msg := m.publish("%s: has cruzado una línea roja" % str(fd.get("name", fid)),
		"%s. La corriente exige explicaciones: «%s». Si no responde con hechos, empezará a retirarte su apoyo." % [why, str(rule["text"])],
		"PARTIDO", "negative",
		{"needs_response": true, "expires_in": 2, "key": "mil_" + str(rule["id"]),
		"data": {"rule": str(rule["id"]), "faction": fid},
		"actions": [
			{"id": "mil:%s:0" % str(rule["id"]), "label": "Dar garantías y rectificar", "style": "good"},
			{"id": "mil:%s:1" % str(rule["id"]), "label": "Reunir a la corriente (25.000 €)", "style": "primary"},
			{"id": "mil:%s:2" % str(rule["id"]), "label": "Mantener tu posición", "style": "ghost"}]})
	f["ult"] = int(msg.get("id", 0))

func rule_by_id(id: String) -> Dictionary:
	for r in rules():
		if str((r as Dictionary)["id"]) == id:
			return r
	return {}

## Respuesta del jugador a un ultimátum. Devuelve el texto de confirmación.
func resolve(rule_id: String, choice: int) -> String:
	var rd := rule_by_id(rule_id)
	if rd.is_empty():
		return ""
	var fid := str(rd["faction"])
	var fd := faction_def(fid)
	var txt := ""
	match choice:
		0:
			_bump(fid, 20.0)
			m.trust = m.trust + 0.5
			if str(rd["type"]) == "pact_with":
				m.ai.change_relation(str(rd["party"]), -6.0)
				txt = "Te distancias públicamente de %s. %s recupera la confianza, pero el pacto se enfría." % [m.party_short(str(rd["party"])), str(fd["name"])]
			else:
				txt = "Das garantías a %s: la corriente baja el tono." % str(fd["name"]).to_lower()
			rd["state"] = "ok"
		1:
			if m.funds < 25000.0:
				_bump(fid, 4.0)
				txt = "No tienes fondos para la reunión: la corriente lo toma como un desplante."
				rd["state"] = "ignored"
			else:
				m.add_finance("Reunión con la corriente «%s»" % str(fd["name"]), -25000.0)
				_bump(fid, 11.0)
				txt = "La reunión sirve para templar ánimos en %s." % str(fd["name"]).to_lower()
				rd["state"] = "ok"
		_:
			_bump(fid, -8.0)
			_scale_members(0.985)
			rd["state"] = "ignored"
			txt = "Mantienes tu posición: %s lo vive como una afrenta." % str(fd["name"]).to_lower()
	_log("%s: %s" % [str(rd["text"]), txt])
	return txt

# ---------------------------------------------------------------- mes a mes
func monthly() -> void:
	ensure()
	var s := st()
	var in_gov := m.role() in ["government", "partner"]
	var trend := m.campaign.trend(m.pid(), 30)
	var stab := float(m.s.get("stability", 50.0))
	for f in FACTIONS:
		var fd: Dictionary = f
		var id := str(fd["id"])
		var fs := fac_state(id)
		var target := 60.0
		if id == "aparato":
			target = 58.0 + trend * 7.0
			if in_gov:
				target += 6.0 + (stab - 50.0) / 12.0
		elif m.manifesto.count() > 0:
			target = 60.0 - m.manifesto.disappointment() * 24.0
		fs["sat"] = clampf(float(fs["sat"]) + (target - float(fs["sat"])) * (1.0 - pow(0.89, float(Rules.TURN_MONTHS))) + m.rng.randfn(0.0, 1.5), 0.0, 100.0)
	# Líneas rojas «de estado».
	for r in rules():
		var rd: Dictionary = r
		match str(rd["type"]):
			"polls":
				var floor_v := float(s.get("poll_ref", 5.0)) * 0.7
				if m.player_poll() < floor_v and str(rd["state"]) == "ok":
					_cross(rd, "Las encuestas caen hasta el %.1f %%" % m.player_poll())
				elif m.player_poll() >= floor_v * 1.1 and str(rd["state"]) != "ok":
					rd["state"] = "ok"
			"promises":
				if m.manifesto.count() > 0 and m.gov_month > 6 and m.manifesto.disappointment() > 0.35 and str(rd["state"]) == "ok":
					_cross(rd, "El programa se incumple de forma evidente")
				elif m.manifesto.disappointment() < 0.2 and str(rd["state"]) == "broken":
					rd["state"] = "ok"
	# Consecuencias de la rebeldía.
	var any_out := false
	for f in FACTIONS:
		var fd2: Dictionary = f
		var fid := str(fd2["id"])
		var fs2 := fac_state(fid)
		if float(fs2["sat"]) < 25.0:
			fs2["low"] = int(fs2["low"]) + 1
		elif float(fs2["sat"]) > 42.0:
			if bool(fs2["out"]):
				m.publish("%s vuelve a respaldarte" % str(fd2["name"]), "Tras los últimos gestos, la corriente retira su plante y vuelve a trabajar con la dirección.", "PARTIDO", "positive")
				_log("%s vuelve a apoyarte." % str(fd2["name"]))
			fs2["low"] = 0
			fs2["out"] = false
		if int(fs2["low"]) >= 2 and not bool(fs2["out"]):
			fs2["out"] = true
			m.publish("%s retira su apoyo" % str(fd2["name"]),
				"La corriente deja de trabajar por tu candidatura: bajan los afiliados activos, las donaciones y la presencia en la calle. Los votantes afines lo notan.",
				"PARTIDO", "negative")
			_log("%s retira su apoyo." % str(fd2["name"]))
			m.voters.on_broken_promises(m.pid(), 0.5)
		if bool(fs2["out"]):
			any_out = true
			_scale_members(0.97)
			m.trust = m.trust - 1.0
			m.campaign.adjust_poll(m.pid(), -0.18)
	# Crisis de liderazgo: la militancia en su conjunto se rebela.
	s["cool"] = maxi(0, int(s.get("cool", 0)) - 1)
	if support() < 28.0 and int(s["cool"]) == 0:
		s["cool"] = 2
		m.trust = m.trust - 8.0
		m.visibility = m.visibility + 6.0
		_scale_members(0.9)
		m.campaign.adjust_poll(m.pid(), -0.6)
		m.publish("Crisis de liderazgo en %s" % str(m.party.get("short_name", "tu partido")),
			"La militancia pide cuentas a la dirección en público. Los medios hablan de un partido dividido y cuestionan tu autoridad.", "PARTIDO", "negative")
		_log("Crisis de liderazgo: la militancia se rebela.")
	# La militancia crece o se marcha con el ánimo general.
	var sup := support()
	_scale_members(1.0 + (sup - 55.0) / 100.0 * 0.02 + trend * 0.002)
	if sup >= 75.0 and not any_out:
		m.trust = m.trust + 0.3
	for r2 in rules():
		if str((r2 as Dictionary)["state"]) == "ignored":
			(r2 as Dictionary)["state"] = "ok" if m.rng.randf() < 0.3 else "ignored"

## Influencia en la campaña: una militancia volcada multiplica el trabajo de calle.
func campaign_boost() -> float:
	ensure()
	return clampf((support() - 55.0) / 100.0 * 0.05, -0.04, 0.03)
