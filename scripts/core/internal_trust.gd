class_name InternalTrust
extends RefCounted
## Confianza interna del partido en el liderazgo del jugador (0-100), mandatos y avisos de la Secretaría de
## Organización. Es una variable DISTINTA del apoyo electoral (encuestas) y de la «Confianza» ciudadana (m.trust).
##
## No inventa un segundo sistema: se construye sobre lo que ya existe y lo explica.
##   · Militancia y corrientes → Militancy.support() (coherencia ideológica, líneas rojas, promesas, resultados).
##   · Gestión y dirección     → Executive.directive() (objetivos anuales de la directiva en el Gobierno).
##   · Mandatos                → registro propio de este módulo: lo que cumples, negocias, rechazas o dejas caducar.
##   · Escándalos              → golpes puntuales que se disipan solos.
## Cada acontecimiento cuenta UNA sola vez: los mandatos no tocan a la corriente que los plantea (su enfado ya está en el
## registro de mandatos); sólo mueven a las demás corrientes (efecto cruzado) y a socios, votantes y capital político.
##
## Fase 1-2 del documento de diseño: sin destitución ni congreso. Los estados bajos sólo tienen consecuencias de gestión.

const BASE := 72.0
const NORMAL_MIL := 60.0
const NORMAL_DIR := 60.0
const NORMAL_REC := 70.0
const GAIN_MIL := 0.80
const GAIN_DIR := 0.30
const GAIN_REC := 0.70
const RATE := 0.45                 # fracción del hueco hacia el objetivo que se cierra cada trimestre
const IMMEDIATE := 0.5             # parte del cambio de objetivo que se nota en el acto al responder un mandato
const MAX_OPEN := 2
const MANDATE_TURNS := 3

const STATES := [
	{"id": "stable", "name": "Estabilidad", "min": 70.0, "tone": "good", "desc": "Respaldo normal: la dirección te deja trabajar y sólo plantea retos ordinarios."},
	{"id": "warning", "name": "Advertencias", "min": 50.0, "tone": "warn", "desc": "Llamadas de atención y peticiones de rectificación. La presión es moderada."},
	{"id": "rebellion", "name": "Rebelión interna", "min": 30.0, "tone": "bad", "desc": "Críticas públicas y filtraciones. El aparato te frena: menos capital político y menos iniciativas."},
	{"id": "crisis", "name": "Crisis de liderazgo", "min": 15.0, "tone": "bad", "desc": "Comité extraordinario y rumores de rival. Todo se vuelve más caro dentro del partido."},
	{"id": "rupture", "name": "Ruptura", "min": 0.0, "tone": "bad", "desc": "La dirección está al borde de abrir una disputa formal del liderazgo (todavía sin consecuencias de destitución)."},
]
const STATUS_NAMES := {"nuevo": "Nuevo", "aceptado": "Aceptado", "negociado": "Negociado", "rechazado": "Rechazado", "cumplido": "Cumplido", "incumplido": "Incumplido", "caducado": "Caducado"}
const OPEN_STATUS := ["nuevo", "aceptado", "negociado"]

const NAMES_F := ["Marta", "Lucía", "Inés", "Carmen", "Pilar", "Elena", "Beatriz", "Nuria"]
const NAMES_M := ["Álvaro", "Javier", "Ramón", "Íñigo", "Tomás", "Rafael", "Sergio", "Ignacio"]
const SURNAMES := ["Quintero", "Salgado", "Montoya", "Arce", "Barrios", "Valdés", "Cordero", "Lasa", "Ferrer", "Olmedo"]

var m: GameModel

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	return m.d("itrust")

func ready_state() -> bool:
	return st().has("v")

# ================================================================ creación
func ensure() -> void:
	if ready_state():
		return
	m.militancy.ensure()
	var s := st()
	s["rec"] = NORMAL_REC
	s["shock"] = 0.0
	s["mandates"] = []
	s["seq"] = 0
	s["log"] = []
	s["hist"] = []
	s["cool"] = {}
	s["alerts"] = []
	s["laws_passed"] = 0
	s["last_law_turn"] = 0
	s["counts"] = {"cumplido": 0, "incumplido": 0, "rechazado": 0, "caducado": 0, "negociado": 0}
	var h := hash(m.pid() + "|" + str(m.save.get("save_id", "")))
	var female := (h % 2) == 0
	var pool: Array = NAMES_F if female else NAMES_M
	s["sec"] = {"name": "%s %s %s" % [pool[absi(h / 3) % pool.size()], SURNAMES[absi(h / 7) % SURNAMES.size()], SURNAMES[absi(h / 11) % SURNAMES.size()]], "female": female}
	s["v"] = clampf(_target(), 0.0, 100.0)
	s["prev"] = _contribs()
	s["state_id"] = state_of(float(s["v"]))["id"]
	_log(0.0, "El partido te respalda con una confianza interna de %.0f/100 al inicio." % float(s["v"]), "system")

# ================================================================ consulta
func value() -> float:
	ensure()
	return float(st()["v"])

func secretary() -> Dictionary:
	ensure()
	return st()["sec"]

func secretary_title() -> String:
	var sec: Dictionary = secretary()
	return "%s, %s de Organización" % [str(sec["name"]), "secretaria" if bool(sec["female"]) else "secretario"]

static func state_of(v: float) -> Dictionary:
	for s in STATES:
		if v >= float((s as Dictionary)["min"]):
			return s
	return STATES[STATES.size() - 1]

func state() -> Dictionary:
	return state_of(value())

func hist() -> Array:
	ensure()
	return st()["hist"]

func log_entries(n: int = 8) -> Array:
	ensure()
	var lg: Array = st()["log"]
	return lg.slice(0, n)

func record() -> float:
	ensure()
	return float(st()["rec"])

func counts() -> Dictionary:
	ensure()
	return st()["counts"]

## Componentes de la confianza: valor actual, nivel normal y puntos que aportan al objetivo.
func components() -> Array:
	ensure()
	var out: Array = []
	var dir_v := _dir_value()
	var shock := float(st()["shock"])
	out.append({"id": "mil", "name": "Militancia y corrientes", "value": m.militancy.support(), "normal": NORMAL_MIL, "gain": GAIN_MIL,
		"contrib": GAIN_MIL * (m.militancy.support() - NORMAL_MIL), "why": _why_mil(), "hint": "Coherencia ideológica, líneas rojas, promesas y resultados"})
	out.append({"id": "dir", "name": "Gestión y dirección", "value": dir_v, "normal": NORMAL_DIR, "gain": GAIN_DIR,
		"contrib": GAIN_DIR * (dir_v - NORMAL_DIR), "why": _why_dir(), "hint": "Objetivos anuales de la directiva"})
	out.append({"id": "rec", "name": "Cumplimiento de mandatos", "value": record(), "normal": NORMAL_REC, "gain": GAIN_REC,
		"contrib": GAIN_REC * (record() - NORMAL_REC), "why": _why_rec(), "hint": "Lo que cumples, negocias o rechazas"})
	out.append({"id": "shock", "name": "Escándalos y crisis internas", "value": shock, "normal": 0.0, "gain": 1.0,
		"contrib": shock, "why": "golpes recientes que se disipan con el tiempo" if absf(shock) > 0.3 else "sin escándalos activos", "hint": "Caídas bruscas que se olvidan poco a poco"})
	return out

func target() -> float:
	ensure()
	return _target()

func _dir_value() -> float:
	if m.role() in ["government", "partner"] and m.exec.in_cabinet():
		return m.exec.directive()
	return NORMAL_DIR

func _target() -> float:
	var t := BASE
	t += GAIN_MIL * (m.militancy.support() - NORMAL_MIL)
	t += GAIN_DIR * (_dir_value() - NORMAL_DIR)
	t += GAIN_REC * (float(st().get("rec", NORMAL_REC)) - NORMAL_REC)
	t += float(st().get("shock", 0.0))
	return clampf(t, 0.0, 100.0)

func _contribs() -> Dictionary:
	var out: Dictionary = {}
	for c in components():
		out[str((c as Dictionary)["id"])] = float((c as Dictionary)["contrib"])
	return out

func _why_mil() -> String:
	var worst := ""
	var wv := 101.0
	for f in m.militancy.factions():
		var fid := str((f as Dictionary)["id"])
		if bool(m.militancy.fac_state(fid).get("out", false)):
			return "«%s» ha retirado su apoyo" % str((f as Dictionary)["name"])
		if m.militancy.sat(fid) < wv:
			wv = m.militancy.sat(fid)
			worst = str((f as Dictionary)["name"])
	if wv < 45.0:
		return "«%s» está descontenta (%.0f/100)" % [worst, wv]
	if m.militancy.support() >= 65.0:
		return "la militancia está alineada contigo"
	return "las corrientes están dentro de lo normal"

func _why_dir() -> String:
	if m.role() in ["government", "partner"] and m.exec.in_cabinet():
		return "la directiva evalúa tu gestión (%.0f/100)" % m.exec.directive()
	return "en la oposición no hay objetivos de gestión"

func _why_rec() -> String:
	var c := counts()
	return "%d cumplidos, %d incumplidos, %d rechazados" % [int(c["cumplido"]), int(c["incumplido"]) + int(c["caducado"]), int(c["rechazado"])]

# ================================================================ registro de cambios
func _log(delta: float, text: String, kind: String) -> void:
	var lg: Array = st()["log"]
	lg.push_front({"turn": m.turn(), "t": m.clock_unix(), "delta": delta, "text": text, "kind": kind})
	while lg.size() > 24:
		lg.pop_back()

## Aplica un cambio inmediato sobre el valor y lo deja explicado.
func _nudge(delta: float, text: String, kind: String) -> void:
	var s := st()
	s["v"] = clampf(float(s["v"]) + delta, 0.0, 100.0)
	_log(delta, text, kind)

## Escándalo o golpe puntual (se disipa un 40 % cada trimestre).
func shock(delta: float, text: String) -> void:
	ensure()
	var s := st()
	s["shock"] = clampf(float(s["shock"]) + delta, -30.0, 10.0)
	_nudge(delta * IMMEDIATE, text, "event")

# ================================================================ ganchos con el resto del juego
## Una ley sale adelante (llamado desde Militancy.on_law). `worst_val` es el mayor daño sufrido por una corriente.
func on_law(law: Dictionary, res: Dictionary, worst_axis: int, worst_val: float) -> void:
	ensure()
	if str(law.get("kind", "")) == "presupuestos" or not bool(res.get("passed", false)):
		return
	var proposer := str(law.get("proposer", ""))
	if proposer == m.pid():
		st()["laws_passed"] = int(st()["laws_passed"]) + 1
		st()["last_law_turn"] = m.turn()
	var resp := proposer == m.pid() or str(res.get("player_vote", "")) == "yes"
	if not resp or worst_axis < 0 or worst_val > -4.0 or m.phase != "legislature":
		return
	if _open_of("law_rectify") != null or not _can_issue("law_rectify", 2):
		return
	# La medida de la ley que más se aleja del eje agraviado.
	var ax := [float(m.party.get("ideology", {}).get("economic", 0.0)), float(m.party.get("ideology", {}).get("social", 0.0)), float(m.party.get("ideology", {}).get("territorial", 0.0))]
	var axis_keys := ["economic", "social", "territorial"]
	var expect := signf(float(ax[worst_axis])) if absf(float(ax[worst_axis])) >= 0.2 else 0.0
	var best_id := ""
	var best_score := 0.0
	var changes: Dictionary = law.get("changes", {})
	for mid in changes.keys():
		var meas := Policies.measure(str(mid))
		if meas.is_empty():
			continue
		var lean: Dictionary = meas.get("lean", {})
		var sgn := signf(float(changes[mid]) - float(meas.get("base", 0.0)))
		var score := float(lean.get(axis_keys[worst_axis], 0.0)) * sgn * expect
		if expect == 0.0:
			score = -absf(float(lean.get(axis_keys[worst_axis], 0.0)))
		if score < best_score:
			best_score = score
			best_id = str(mid)
	if best_id == "":
		return
	var meas2 := Policies.measure(best_id)
	var fac := ["doctrina", "valores", "territorios"][worst_axis] as String
	var cur := m.eco.value(best_id)
	var base := float(meas2.get("base", cur))
	var goal_t := base + 0.5 * (cur - base)
	var sev := 3 if worst_val <= -10.0 else (2 if worst_val <= -7.0 else 1)
	var fdef := m.militancy.faction_def(fac)
	_issue({
		"type": "ideologico", "kind": "law_rectify", "faction": fac, "severity": sev,
		"title": "Rectificar «%s»" % str(meas2.get("name", best_id)),
		"body": "%s considera que la ley «%s» se aleja del programa y de la identidad del partido. Exige corregir «%s» antes de %d trimestres." % [str(fdef.get("name", fac)), str(law.get("title", "la última ley")), str(meas2.get("name", best_id)).to_lower(), MANDATE_TURNS],
		"reason": "Has respaldado «%s» y la corriente «%s» lo vive como un giro contra su eje %s." % [str(law.get("title", "la ley")), str(fdef.get("name", fac)), Militancy.AXIS_NAMES[worst_axis]],
		"goal": {"kind": "measure", "id": best_id, "from": cur, "target": goal_t, "name": str(meas2.get("name", best_id))},
		"turns": MANDATE_TURNS})

## Elecciones: los mandatos abiertos pierden sentido. El resultado electoral ya mueve a la militancia (Militancy.on_election).
func on_election(seats: int) -> void:
	ensure()
	var closed := 0
	for md in _mandates():
		var d: Dictionary = md
		if OPEN_STATUS.has(str(d["status"])):
			d["status"] = "caducado"
			d["result"] = "Cerrado por las elecciones: sin penalización."
			_close_msg(d, "Cerrado por las elecciones.")
			closed += 1
	_log(0.0, "Elecciones con %d escaños: la militancia reevalúa tu liderazgo (se refleja en las corrientes).%s" % [seats, " Mandatos cerrados: %d." % closed if closed > 0 else ""], "event")

# ================================================================ mandatos: creación
func _mandates() -> Array:
	return st()["mandates"]

func mandates(open_only: bool = false) -> Array:
	ensure()
	var out: Array = []
	for md in _mandates():
		if not open_only or OPEN_STATUS.has(str((md as Dictionary)["status"])):
			out.append(md)
	return out

func mandate(id: String) -> Dictionary:
	for md in _mandates():
		if str((md as Dictionary)["id"]) == id:
			return md
	return {}

func open_count() -> int:
	return mandates(true).size()

func _open_of(kind: String) -> Variant:
	for md in mandates(true):
		if str((md as Dictionary)["kind"]) == kind:
			return md
	return null

func _can_issue(kind: String, cool_turns: int) -> bool:
	var cool: Dictionary = st()["cool"]
	return m.turn() >= int(cool.get(kind, -99)) + cool_turns and open_count() < MAX_OPEN

func _issue(spec: Dictionary) -> Dictionary:
	var s := st()
	s["seq"] = int(s["seq"]) + 1
	var id := "m%d" % int(s["seq"])
	var turns := int(spec.get("turns", MANDATE_TURNS))
	var due_turn := m.turn() + turns
	var md := {
		"id": id, "type": str(spec["type"]), "kind": str(spec["kind"]), "faction": str(spec["faction"]),
		"title": str(spec["title"]), "body": str(spec["body"]), "reason": str(spec.get("reason", "")),
		"issuer": str(secretary()["name"]), "severity": int(spec.get("severity", 1)),
		"issued_turn": m.turn(), "issued_t": m.clock_unix(), "due_turn": due_turn,
		"status": "nuevo", "goal": spec["goal"], "can_negotiate": true, "result": "", "msg": 0}
	_mandates().push_front(md)
	(s["cool"] as Dictionary)[str(spec["kind"])] = m.turn()
	var fdef := m.militancy.faction_def(str(md["faction"]))
	var msg := m.publish("%s: %s" % ["Mandato" if str(md["type"]) == "ideologico" else "Reto", str(md["title"])],
		"%s\n\nMotivo: %s\nPlazo: %s. Importancia: %s." % [str(md["body"]), str(md["reason"]), due_label(md), severity_name(int(md["severity"]))],
		"PARTIDO", "warning" if int(md["severity"]) >= 2 else "neutral",
		{"needs_response": true, "expires_in": turns * Rules.TURN_MONTHS, "key": "mand_" + id, "data": {"mandate": id, "faction": str(md["faction"])},
		"speaker_id": "", "actions": [
			{"id": "mand:%s:0" % id, "label": "Aceptar y comprometerme", "style": "good"},
			{"id": "mand:%s:1" % id, "label": "Negociar una alternativa", "style": "primary"},
			{"id": "mand:%s:2" % id, "label": "Rechazar y asumir el coste", "style": "ghost"}]})
	md["msg"] = int(msg.get("id", 0))
	_log(0.0, "%s plantea: %s (%s)." % [str(fdef.get("name", "La dirección")), str(md["title"]), severity_name(int(md["severity"])).to_lower()], "mandate")
	return md

static func severity_name(sev: int) -> String:
	return ["", "Baja", "Media", "Alta"][clampi(sev, 1, 3)]

func due_label(md: Dictionary) -> String:
	var left := int(md["due_turn"]) - m.turn()
	if left <= 0:
		return "vence este trimestre"
	return "%d trimestre%s (T%d)" % [left, "" if left == 1 else "s", int(md["due_turn"])]

func _sev_w(md: Dictionary) -> float:
	return [0.0, 0.7, 1.0, 1.4][clampi(int(md["severity"]), 1, 3)]

# ================================================================ metas
## Estado de la meta de un mandato: {met, now, target, text}
func goal_status(md: Dictionary) -> Dictionary:
	var g: Dictionary = md["goal"]
	var met := false
	var now_txt := ""
	var tgt_txt := ""
	match str(g["kind"]):
		"measure":
			var id := str(g["id"])
			var cur := m.eco.value(id)
			var t := float(g["target"])
			var from := float(g["from"])
			met = cur <= t + 0.0001 if from > t else cur >= t - 0.0001
			now_txt = _meas_fmt(id, cur)
			tgt_txt = _meas_fmt(id, t)
		"promise":
			var id2 := str(g["id"])
			if not m.manifesto.has(id2):
				met = true
				now_txt = "ya no figura en el programa"
				tgt_txt = ""
			else:
				var e := m.manifesto.effort(id2)
				met = e >= float(g["target"]) - 0.0001
				now_txt = "%.0f %%" % (e * 100.0)
				tgt_txt = "%.0f %%" % (float(g["target"]) * 100.0)
		"poll":
			met = m.player_poll() >= float(g["target"])
			now_txt = "%.1f %%" % m.player_poll()
			tgt_txt = "%.1f %%" % float(g["target"])
		"laws":
			var n := int(st()["laws_passed"])
			met = n >= int(g["target"])
			now_txt = "%d aprobadas" % (n - int(g["from"]))
			tgt_txt = "%d" % (int(g["target"]) - int(g["from"]))
	return {"met": met, "now": now_txt, "target": tgt_txt, "text": goal_text(md)}

func _meas_fmt(id: String, v: float) -> String:
	var meas := Policies.measure(id)
	var unit := str(meas.get("unit", ""))
	return ("%.1f %s" % [v, unit]).strip_edges() if absf(v - roundf(v)) > 0.05 else ("%.0f %s" % [v, unit]).strip_edges()

func goal_text(md: Dictionary) -> String:
	var g: Dictionary = md["goal"]
	match str(g["kind"]):
		"measure":
			return "Llevar «%s» a %s (ahora %s)." % [str(g["name"]), _meas_fmt(str(g["id"]), float(g["target"])), _meas_fmt(str(g["id"]), m.eco.value(str(g["id"])))]
		"promise":
			return "Hacer avanzar la promesa «%s» hasta el %.0f %% de lo prometido." % [str(g["name"]), float(g["target"]) * 100.0]
		"poll":
			return "Recuperar el %.1f %% en las encuestas (ahora %.1f %%)." % [float(g["target"]), m.player_poll()]
		"laws":
			return "Sacar adelante %d ley%s propia%s." % [int(g["target"]) - int(g["from"]), "" if int(g["target"]) - int(g["from"]) == 1 else "es", "" if int(g["target"]) - int(g["from"]) == 1 else "s"]
	return ""

# ================================================================ respuestas del jugador
## Efectos previstos de cada respuesta. Devuelve una lista [{choice, label, lines:[texto], tone}] para mostrarlos en la interfaz.
func preview(md: Dictionary) -> Array:
	var out: Array = []
	var neg := _neg_chance(md)
	for c in [0, 1, 2]:
		var fx := _fx(md, c, true)
		var lines: Array = []
		var dnow := _estimate_now(md, fx)
		lines.append("Confianza interna: %s ahora" % _signed(dnow))
		for k in (fx["cross"] as Dictionary).keys():
			var d := float((fx["cross"] as Dictionary)[k])
			if absf(d) >= 0.5:
				lines.append("%s: %s" % [str(m.militancy.faction_def(str(k)).get("name", k)), "contenta" if d > 0.0 else "se resiente"])
		if absf(float(fx["partner"])) >= 0.5:
			lines.append("Socios de Gobierno: %s" % ("mejor relación" if float(fx["partner"]) > 0.0 else "se enfrían"))
		if absf(float(fx["poll"])) >= 0.03:
			lines.append("Electorado: %s" % ("lo valora" if float(fx["poll"]) > 0.0 else "lo castiga"))
		if c == 0:
			lines.append("Si lo cumples a tiempo: mucho más respaldo. Si no: caída fuerte.")
		elif c == 1:
			lines.append("Probabilidad de acuerdo: %.0f %%" % (neg * 100.0) if bool(md["can_negotiate"]) else "Ya no queda margen para negociar.")
		else:
			var j := _justification(md)
			lines.append("Justificación: %s" % str(j["text"]))
		out.append({"choice": c, "label": ["Aceptar y comprometerme", "Negociar una alternativa", "Rechazar y asumir el coste"][c], "lines": lines,
			"disabled": c == 1 and not bool(md["can_negotiate"])})
	return out

func _signed(v: float) -> String:
	return "%+.1f" % v

## Probabilidad de que la corriente acepte una alternativa.
func _neg_chance(md: Dictionary) -> float:
	var edge := Leader.edge(m.character(), "mano_izquierda")
	var fsat := m.militancy.sat(str(md["faction"])) / 100.0
	var cap := clampf(m.exec.capital() / Executive.MAX_CAPITAL, 0.0, 1.0) if m.role() in ["government", "partner"] else 0.4
	return clampf(0.28 + 0.28 * fsat + 0.20 * edge + 0.12 * cap - 0.12 * float(int(md["severity"]) - 1), 0.1, 0.9)

## Cómo se puede justificar un rechazo ante el partido. Devuelve {text, mult}
func _justification(md: Dictionary) -> Dictionary:
	var ref := float(m.militancy.st().get("poll_ref", maxf(m.player_poll(), 0.5)))
	if m.player_poll() >= ref * 1.02:
		return {"text": "las urnas y las encuestas te avalan (coste ×0.7)", "mult": 0.7}
	if m.player_poll() < ref * 0.92:
		return {"text": "con las encuestas a la baja nadie te da la razón (coste ×1.25)", "mult": 1.25}
	return {"text": "defiendes el interés general, pero sin respaldo extra (coste normal)", "mult": 1.0}

## Tabla de efectos de una respuesta: variación del registro de mandatos, efecto cruzado en corrientes,
## relación con socios, voto y confianza ciudadana.
func _fx(md: Dictionary, choice: int, preview_only: bool = false) -> Dictionary:
	var s := _sev_w(md)
	var rec := 0.0
	var cross: Dictionary = {}
	var partner := 0.0
	var poll := 0.0
	var pub := 0.0
	var accept_cross: Dictionary = {}
	var reject_cross: Dictionary = {}
	var kind := str(md["kind"])
	match kind:
		"law_rectify":
			accept_cross = {"aparato": -3.0, "territorios": -1.5}
			reject_cross = {"aparato": 2.5}
		"promise":
			accept_cross = {"aparato": -2.0}
			reject_cross = {"aparato": 1.0}
		"poll":
			accept_cross = {"doctrina": -3.0, "valores": -2.0}
			reject_cross = {"doctrina": 2.5}
		"laws":
			accept_cross = {"territorios": -2.0}
			reject_cross = {"territorios": 1.5}
	match choice:
		0:
			rec = 3.0 * s
			for k in accept_cross.keys():
				cross[k] = float(accept_cross[k]) * s
			if kind == "law_rectify":
				partner = -4.0 * s
				pub = -0.4 * s
			if kind == "promise":
				pub = 0.3 * s
		1:
			rec = 2.0 * s
			for k2 in accept_cross.keys():
				cross[k2] = float(accept_cross[k2]) * s * 0.4
			if kind == "law_rectify":
				partner = -1.5 * s
		_:
			var j := _justification(md)
			var mult := float(j["mult"])
			rec = -8.0 * s * mult
			for k3 in reject_cross.keys():
				cross[k3] = float(reject_cross[k3]) * s
			if kind == "law_rectify":
				partner = 1.5 * s
				poll = 0.10 * s
			if kind == "promise":
				pub = -0.3 * s
				poll = -0.08 * s
	return {"rec": rec, "cross": cross, "partner": partner, "poll": poll, "pub": pub}

## Efecto inmediato estimado sobre la confianza (mitad del cambio de objetivo).
func _estimate_now(_md: Dictionary, fx: Dictionary) -> float:
	var dt := GAIN_REC * float(fx["rec"])
	for k in (fx["cross"] as Dictionary).keys():
		dt += GAIN_MIL * float(m.militancy.faction_def(str(k)).get("power", 0.2)) * float((fx["cross"] as Dictionary)[k])
	return IMMEDIATE * dt

func _apply_fx(fx: Dictionary) -> void:
	var s := st()
	s["rec"] = clampf(float(s["rec"]) + float(fx["rec"]), 0.0, 100.0)
	for k in (fx["cross"] as Dictionary).keys():
		m.militancy._bump(str(k), float((fx["cross"] as Dictionary)[k]))
	if absf(float(fx["partner"])) > 0.0:
		for pid in m.gov.government_parties():
			if str(pid) != m.pid():
				m.ai.change_relation(str(pid), float(fx["partner"]))
	if absf(float(fx["poll"])) > 0.0:
		m.campaign.adjust_poll(m.pid(), float(fx["poll"]))
	if absf(float(fx["pub"])) > 0.0:
		m.trust = clampf(m.trust + float(fx["pub"]), 5.0, 95.0)

func _close_msg(md: Dictionary, text: String) -> void:
	var item := m.find_news(int(md.get("msg", 0)))
	if not item.is_empty() and not bool(item.get("resolved", false)):
		item["resolved"] = true
		item["needs_response"] = false
		item["read"] = true
		item["resolution"] = text
		item["kind"] = "press"

## Respuesta del jugador. choice: 0 aceptar, 1 negociar, 2 rechazar. Devuelve el texto de confirmación.
func respond(mandate_id: String, choice: int) -> String:
	ensure()
	var md := mandate(mandate_id)
	if md.is_empty() or str(md["status"]) != "nuevo":
		return ""
	if choice == 1 and not bool(md["can_negotiate"]):
		return "Ya no queda margen para negociar este asunto."
	var before := _target()
	var fdef := m.militancy.faction_def(str(md["faction"]))
	var fname := str(fdef.get("name", "La dirección"))
	var txt := ""
	var reopen := false
	var label := ""
	match choice:
		0:
			md["status"] = "aceptado"
			md["accepted_turn"] = m.turn()
			txt = "Te comprometes con %s: «%s». Tienes hasta %s." % [fname, str(md["title"]), due_label(md)]
			label = "Aceptas"
			_apply_fx(_fx(md, 0))
		1:
			label = "Negocias"
			if m.rng.randf() < _neg_chance(md):
				md["status"] = "negociado"
				md["negotiated"] = true
				md["due_turn"] = int(md["due_turn"]) + 1
				_relax(md)
				txt = "%s acepta una alternativa más suave. %s Plazo ampliado a %s." % [fname, goal_text(md), due_label(md)]
				var counts_n: Dictionary = st()["counts"]
				counts_n["negociado"] = int(counts_n["negociado"]) + 1
				_apply_fx(_fx(md, 1))
			else:
				md["can_negotiate"] = false
				md["severity"] = mini(3, int(md["severity"]) + 1)
				_apply_fx({"rec": -2.0 * _sev_w(md), "cross": {}, "partner": 0.0, "poll": 0.0, "pub": 0.0})
				txt = "%s rechaza la alternativa y se enroca: el asunto gana importancia (%s) y ya no admite negociación." % [fname, severity_name(int(md["severity"])).to_lower()]
				reopen = true
		_:
			var j := _justification(md)
			md["status"] = "rechazado"
			md["result"] = "Rechazaste el mandato. Justificación: %s." % str(j["text"])
			var counts_r: Dictionary = st()["counts"]
			counts_r["rechazado"] = int(counts_r["rechazado"]) + 1
			var jt := str(j["text"])
			txt = "Rechazas «%s»: %s%s." % [str(md["title"]), jt.substr(0, 1).to_upper(), jt.substr(1)]
			label = "Rechazas"
			_apply_fx(_fx(md, 2))
	var d := IMMEDIATE * (_target() - before)
	_nudge(d, "%s «%s»." % [label if label != "" else "Respondes", str(md["title"])] if not reopen else "Negociación fallida en «%s»." % str(md["title"]), "mandate")
	_close_msg(md, "%s Confianza interna %s." % [txt, _signed(d)])
	if reopen:
		_reopen_msg(md)
	return "%s Confianza interna: %s." % [txt, _signed(d)]

func _reopen_msg(md: Dictionary) -> void:
	var id := str(md["id"])
	var msg := m.publish("Sin acuerdo: %s" % str(md["title"]),
		"La corriente se enroca. Tienes hasta %s para aceptar o rechazar." % due_label(md), "PARTIDO", "warning",
		{"needs_response": true, "expires_in": maxi(1, int(md["due_turn"]) - m.turn()) * Rules.TURN_MONTHS, "key": "mand_" + id, "data": {"mandate": id},
		"actions": [
			{"id": "mand:%s:0" % id, "label": "Aceptar y comprometerme", "style": "good"},
			{"id": "mand:%s:2" % id, "label": "Rechazar y asumir el coste", "style": "ghost"}]})
	md["msg"] = int(msg.get("id", 0))

## Una negociación aceptada rebaja la meta a la mitad del recorrido.
func _relax(md: Dictionary) -> void:
	var g: Dictionary = md["goal"]
	match str(g["kind"]):
		"measure":
			g["target"] = float(g["from"]) + (float(g["target"]) - float(g["from"])) * 0.5
		"promise":
			var e := m.manifesto.effort(str(g["id"]))
			g["target"] = e + (float(g["target"]) - e) * 0.5
		"poll":
			g["target"] = float(g["start"]) + (float(g["target"]) - float(g["start"])) * 0.5

# ================================================================ cada trimestre
func quarterly() -> void:
	ensure()
	var s := st()
	var prev: Dictionary = s["prev"]
	# 1. Registro de mandatos y escándalos tienden a su nivel normal.
	s["rec"] = float(s["rec"]) + (NORMAL_REC - float(s["rec"])) * 0.12
	s["shock"] = float(s["shock"]) * 0.6
	if absf(float(s["shock"])) < 0.2:
		s["shock"] = 0.0
	# 2. Mandatos abiertos: cumplidos, incumplidos o caducados.
	_review_mandates()
	# 3. La confianza se acerca al objetivo y se explica por qué.
	var old_v := float(s["v"])
	var tgt := _target()
	var new_v := clampf(old_v + (tgt - old_v) * RATE, 0.0, 100.0)
	s["v"] = new_v
	var now := _contribs()
	var drivers: Array = []
	for c in components():
		var cd: Dictionary = c
		var dc := float(now[str(cd["id"])]) - float(prev.get(str(cd["id"]), 0.0))
		if absf(dc) >= 0.5:
			drivers.append({"d": dc, "t": "%s %s (%s)" % [str(cd["name"]), _signed(dc), str(cd["why"])]})
	drivers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["d"])) > absf(float(b["d"])))
	if absf(new_v - old_v) >= 0.3 or not drivers.is_empty():
		var txt := "Trimestre: %s." % _signed(new_v - old_v)
		if not drivers.is_empty():
			var parts: Array = []
			for dv in drivers.slice(0, 2):
				parts.append(str((dv as Dictionary)["t"]))
			txt = "Trimestre: " + "; ".join(parts) + "."
		elif absf(tgt - old_v) > 1.0:
			txt = "Trimestre: la confianza converge hacia %.0f (%s)." % [tgt, "militancia y mandatos" if tgt > old_v else "presión acumulada"]
		_log(new_v - old_v, txt, "quarter")
	s["prev"] = now
	# 4. Cambio de estado: aviso de la Secretaría.
	var sid := str(state_of(new_v)["id"])
	if sid != str(s["state_id"]):
		_state_change(str(s["state_id"]), sid)
		s["state_id"] = sid
	# 5. Consecuencias de gestión en los estados bajos y nuevos retos/alertas.
	if sid in ["rebellion", "crisis", "rupture"]:
		_unrest(sid)
	_generate()
	var h: Array = s["hist"]
	h.append({"turn": m.turn(), "v": new_v, "t": m.clock_unix()})
	while h.size() > 40:
		h.pop_front()

func _review_mandates() -> void:
	for md in _mandates():
		var d: Dictionary = md
		var stt := str(d["status"])
		if not OPEN_STATUS.has(stt):
			continue
		var gs := goal_status(d)
		var s_w := _sev_w(d)
		var counts_d: Dictionary = st()["counts"]
		if bool(gs["met"]):
			var bonus := 8.0 if stt == "aceptado" else (5.0 if stt == "negociado" else 6.0)
			var before := _target()
			st()["rec"] = clampf(float(st()["rec"]) + bonus * s_w, 0.0, 100.0)
			d["status"] = "cumplido"
			d["result"] = "Meta lograda a tiempo."
			counts_d["cumplido"] = int(counts_d["cumplido"]) + 1
			var dn := IMMEDIATE * (_target() - before)
			_nudge(dn, "Mandato cumplido: %s." % str(d["title"]), "mandate")
			_close_msg(d, "Cumplido.")
			m.publish("Mandato cumplido: %s" % str(d["title"]), "El partido reconoce que has cumplido. Confianza interna %s." % _signed(dn), "PARTIDO", "positive")
		elif m.turn() >= int(d["due_turn"]):
			var before2 := _target()
			if stt == "nuevo":
				st()["rec"] = clampf(float(st()["rec"]) - 9.0 * s_w, 0.0, 100.0)
				d["status"] = "caducado"
				d["result"] = "Lo dejaste caducar sin responder."
				counts_d["caducado"] = int(counts_d["caducado"]) + 1
			else:
				st()["rec"] = clampf(float(st()["rec"]) - (14.0 if stt == "aceptado" else 8.0) * s_w, 0.0, 100.0)
				m.trust = clampf(m.trust - 0.5 * s_w, 5.0, 95.0)
				d["status"] = "incumplido"
				d["result"] = "Te comprometiste y no lo cumpliste."
				counts_d["incumplido"] = int(counts_d["incumplido"]) + 1
			var dn2 := IMMEDIATE * (_target() - before2)
			_nudge(dn2, "Mandato %s: %s." % [str(d["status"]), str(d["title"])], "mandate")
			_close_msg(d, str(d["result"]))
			m.publish("Mandato %s: %s" % [str(d["status"]), str(d["title"])], "%s Confianza interna %s." % [str(d["result"]), _signed(dn2)], "PARTIDO", "negative")

func _state_change(from_id: String, to_id: String) -> void:
	var sec := str(secretary()["name"])
	var st_to := {}
	for sx in STATES:
		if str((sx as Dictionary)["id"]) == to_id:
			st_to = sx
	var order := ["stable", "warning", "rebellion", "crisis", "rupture"]
	var worse := order.find(to_id) > order.find(from_id)
	var body := ""
	match to_id:
		"stable":
			body = "%s: «El partido vuelve a ordenar filas detrás de ti. Aprovecha para ganar autoridad.»" % sec
		"warning":
			body = "%s: «Hay malestar en la dirección. Necesitamos gestos: cumple lo prometido y cuida a las corrientes antes de que esto vaya a más.»" % sec
		"rebellion":
			body = "%s: «La dirección se ha roto. Hay críticas en público y filtraciones. Desde ahora te costará más sacar adelante cosas dentro del partido.»" % sec
		"crisis":
			body = "%s: «Se habla de un comité extraordinario y de un posible rival. Tienes que mover ficha ya.»" % sec
		_:
			body = "%s: «Los barones piden abrir una disputa formal por el liderazgo. Todavía puedes frenarlo si recuperas el respaldo.»" % sec
	m.publish("%s: %s" % ["Confianza interna" if worse else "Respiro interno", str(st_to.get("name", ""))], body, "PARTIDO", "negative" if worse else "positive")
	_log(0.0, "Estado interno: %s." % str(st_to.get("name", "")), "event")

## Consecuencias de la rebelión interna (sin destitución): filtraciones.
func _unrest(sid: String) -> void:
	if m.rng.randf() < (0.35 if sid == "rebellion" else 0.55):
		m.visibility = m.visibility + 2.0
		m.trust = clampf(m.trust - 0.6, 5.0, 95.0)
		m.publish("Filtración desde dentro del partido", "Fuentes de la dirección de %s critican tu liderazgo. La imagen de un partido dividido pesa entre los votantes." % str(m.party.get("short_name", "tu partido")), "PARTIDO", "negative")

## Consecuencias de gestión del estado actual.
func capital_factor() -> float:
	if not ready_state():
		return 1.0
	match str(state_of(float(st()["v"]))["id"]):
		"stable": return 1.08
		"warning": return 1.0
		"rebellion": return 0.75
		"crisis": return 0.55
	return 0.4

func bills_penalty() -> int:
	if not ready_state():
		return 0
	return 1 if str(state_of(float(st()["v"]))["id"]) in ["rebellion", "crisis", "rupture"] else 0

# ================================================================ generación contextual de mandatos y alertas
func _generate() -> void:
	if m.phase != "legislature":
		return
	var gov := m.role() in ["government", "partner"]
	# Retos y mandatos según el momento.
	if _open_of("promise") == null and _can_issue("promise", 4) and m.manifesto.count() > 0 and m.gov_month > 6 and m.manifesto.disappointment() >= 0.18:
		var late: Array = m.manifesto.late_list()
		if not late.is_empty():
			_issue_promise(str(late[0]))
			return
	var ref := float(m.militancy.st().get("poll_ref", m.player_poll()))
	if _open_of("poll") == null and _can_issue("poll", 4) and m.player_poll() < ref * 0.90 and ref >= 2.0:
		var tgt := minf(ref * 0.97, m.player_poll() + maxf(1.0, ref * 0.05))
		_issue({"type": "reto", "kind": "poll", "faction": "aparato", "severity": 2 if m.player_poll() < ref * 0.8 else 1,
			"title": "Recuperar apoyo en las encuestas",
			"body": "El aparato ve caer el apoyo del partido. Pide un plan para volver a %.1f %% en %d trimestres." % [tgt, MANDATE_TURNS],
			"reason": "Las encuestas han bajado del %.1f %% de referencia al %.1f %%." % [ref, m.player_poll()],
			"goal": {"kind": "poll", "start": m.player_poll(), "target": tgt}, "turns": MANDATE_TURNS})
		return
	if gov and _open_of("laws") == null and _can_issue("laws", 5) and m.turn() >= int(st()["last_law_turn"]) + 3 and m.turn() >= 4:
		var n0 := int(st()["laws_passed"])
		_issue({"type": "reto", "kind": "laws", "faction": "aparato", "severity": 1,
			"title": "Sacar adelante una ley propia",
			"body": "Hace tiempo que el Gobierno no aprueba una ley impulsada por el partido. El aparato quiere ver que se gobierna.",
			"reason": "Llevas %d trimestres sin aprobar una iniciativa propia." % (m.turn() - int(st()["last_law_turn"])),
			"goal": {"kind": "laws", "from": n0, "target": n0 + 1}, "turns": 2})
		return
	_alerts()

func _issue_promise(mid: String) -> void:
	var meas := Policies.measure(mid)
	var e := m.manifesto.effort(mid)
	var tgt := minf(1.0, e + 0.3) if e < 0.7 else 1.0
	var sev := 2 if m.manifesto.shortfall(mid) > 0.4 else 1
	_issue({"type": "ideologico", "kind": "promise", "faction": "doctrina", "severity": sev,
		"title": "Cumplir «%s»" % str(meas.get("name", mid)),
		"body": "La militancia recuerda que «%s» figura en el programa y sigue atascada. Exige un avance claro en %d trimestres." % [str(meas.get("name", mid)), MANDATE_TURNS],
		"reason": "Llevas un %.0f %% de lo prometido en el conjunto del programa y esta promesa va con retraso." % (m.manifesto.kept_ratio() * 100.0),
		"goal": {"kind": "promise", "id": mid, "name": str(meas.get("name", mid)), "target": tgt}, "turns": MANDATE_TURNS})

## Alertas de gestión: avisos de la Secretaría. No son órdenes ni cuestan confianza por sí mismas.
func _alerts() -> void:
	var s := st()
	var al: Array = s["alerts"]
	var checks: Array = [
		{"key": "inflation", "on": float(m.eco.st().get("inflation", 2.0)) > 4.8, "title": "Alerta: inflación al %.1f %%" % float(m.eco.st().get("inflation", 2.0)),
		"body": "Los precios se disparan y la militancia lo comenta en las agrupaciones.", "sug": ["energy_cap", "vat_basic"]},
		{"key": "unemployment", "on": float(m.eco.st().get("unemployment", 12.0)) > 14.0, "title": "Alerta: el paro sube al %.1f %%" % float(m.eco.st().get("unemployment", 12.0)),
		"body": "El desempleo golpea a los barrios que sostienen al partido.", "sug": ["active_jobs", "unemp_benefit"]},
		{"key": "deficit", "on": -m.eco.balance_pct() > 4.5, "title": "Alerta: déficit del %.1f %% del PIB" % (-m.eco.balance_pct()),
		"body": "El déficit se descontrola y Bruselas empieza a mirar.", "sug": ["vat_general", "corp_tax"]},
		{"key": "housing", "on": m.world.value("rent_burden") > 42.0, "title": "Alerta: el alquiler se come el %.0f %% de la renta" % m.world.value("rent_burden"),
		"body": "La vivienda se ha convertido en el principal malestar de las juventudes del partido.", "sug": ["rent_cap", "social_housing"]},
	]
	for c in checks:
		var cd: Dictionary = c
		if not bool(cd["on"]):
			continue
		var last := -99
		for a in al:
			if str((a as Dictionary)["key"]) == str(cd["key"]):
				last = int((a as Dictionary)["turn"])
				break
		if m.turn() < last + 4:
			continue
		var names: Array = []
		for sid in cd["sug"]:
			var nm := str(Policies.measure(str(sid)).get("name", ""))
			if nm != "":
				names.append("«%s»" % nm)
		var sug_txt := "La Secretaría sugiere revisar %s, pero la decisión es tuya." % " o ".join(names) if not names.is_empty() else ""
		m.publish(str(cd["title"]), "%s %s" % [str(cd["body"]), sug_txt], "ASESOR", "warning")
		al.push_front({"key": str(cd["key"]), "turn": m.turn(), "title": str(cd["title"]), "sug": sug_txt})
		while al.size() > 8:
			al.pop_back()
		return

func alerts() -> Array:
	ensure()
	return st()["alerts"]
