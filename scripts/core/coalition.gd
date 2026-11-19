class_name Coalition
extends RefCounted
## Mesa permanente de gobierno: acuerdo de coalición, propuestas y compromisos, confianza entre socios, escalera de
## crisis (desacuerdo → ruptura) y salidas. La confianza de un socio es su `partner_satisfaction` (una sola fuente de
## verdad); los compromisos son los mismos `commitments` que crea la investidura.

var m: GameModel

const PHASES := ["Sin conflicto", "Desacuerdo", "Tensión", "Bloqueo", "Crisis pública", "Ultimátum", "Ruptura"]
const PHASE_TONE := ["good", "neutral", "warn", "warn", "bad", "bad", "bad"]
const PHASE_HELP := [
	"Relación estable.",
	"Diferencias sobre una propuesta: negociación ordinaria.",
	"Se acumulan incumplimientos o choques: hay advertencias y reuniones.",
	"No se alcanzan acuerdos relevantes: hacen falta mediación o concesiones.",
	"El conflicto llega a los medios y a la opinión pública.",
	"El socio fija condiciones y plazo para seguir en el Gobierno.",
	"El socio abandona el Gobierno o retira su apoyo.",
]
const MODALITY_NAMES := {"coalicion": "Gobierno de coalición", "externo": "Apoyo externo", "puntual": "Acuerdo puntual"}
const SCOPES := {
	"leyes": "Leyes y reformas",
	"presupuestos": "Presupuestos e impuestos",
	"social": "Vivienda, sanidad, educación y políticas sociales",
	"territorial": "Política territorial, financiación e inversiones",
	"infra": "Infraestructuras y agricultura",
	"nombramientos": "Nombramientos y remodelaciones",
	"crisis": "Crisis, escándalos y comunicación",
	"cumplimiento": "Cumplimiento del acuerdo",
}
const SCOPE_ORDER := ["leyes", "presupuestos", "social", "territorial", "infra", "nombramientos", "crisis", "cumplimiento"]

const ASK_GROUPS := {
	"economy": [{"kind": "budget", "line": "industria"}, {"kind": "bill", "issue": "jobs"}, {"kind": "comp", "comp": "empleo"}],
	"housing": [{"kind": "bill", "issue": "housing"}, {"kind": "budget", "line": "vivienda"}, {"kind": "comp", "comp": "vivienda"}],
	"territory": [{"kind": "budget", "line": "territorial"}, {"kind": "bill", "issue": "territory"}, {"kind": "budget", "line": "transportes"}, {"kind": "budget", "line": "agricultura"}],
	"public": [{"kind": "budget", "line": "sanidad"}, {"kind": "budget", "line": "educacion"}, {"kind": "bill", "issue": "health"}],
	"energy": [{"kind": "budget", "line": "transicion"}, {"kind": "bill", "issue": "energy"}, {"kind": "comp", "comp": "energia"}],
	"security": [{"kind": "budget", "line": "interior"}, {"kind": "bill", "issue": "security"}, {"kind": "comp", "comp": "interior"}],
}
const LINE_SCOPE := {"sanidad": "social", "educacion": "social", "prestaciones": "social", "vivienda": "social", "territorial": "territorial",
	"transportes": "infra", "agricultura": "infra"}
const CREDIT_STEP := 0.05
const MAX_OPEN_PER_PARTY := 2
const PROPOSAL_TTL := 3  ## trimestres que una propuesta espera respuesta

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	return m.d("coal")

func proposals() -> Array:
	return m.a("table_proposals")

func gov_id() -> String:
	return str(m.s.get("government_party_id", ""))

func active() -> bool:
	return m.phase == "legislature" and not st().is_empty()

func ensure() -> void:
	var s := st()
	for k in ["parties", "red_lines", "tension", "crises", "meet", "notes", "factors", "ruptured", "breach", "cool"]:
		if not s.has(k) or typeof(s[k]) != TYPE_DICTIONARY:
			s[k] = {}
	if not s.has("log") or typeof(s["log"]) != TYPE_ARRAY:
		s["log"] = []
	if not s.has("seq"):
		s["seq"] = 0
	if not s.has("rules"):
		s["rules"] = _default_rules()
	if not s.has("formed_turn"):
		s["formed_turn"] = m.turn()
	# Partidas anteriores a este sistema: el acuerdo se reconstruye con los socios que ya había.
	if m.phase == "legislature" and (s["parties"] as Dictionary).is_empty() and not m.gov.partners().is_empty():
		_register_partners()

func _default_rules() -> Dictionary:
	return {
		"coordination": "Las competencias compartidas se coordinan entre los ministros afectados; los choques se llevan a la mesa de coalición.",
		"resolution": "Los desacuerdos se resuelven en la mesa: propuesta, contraoferta o aplazamiento. Si no hay acuerdo, decide el presidente pagando confianza.",
		"review": "El acuerdo se revisa cada cuatro trimestres y tras cualquier crisis pública.",
	}

# ---------------------------------------------------------------- constitución del acuerdo
func _register_partners() -> void:
	var s := st()
	var parties: Dictionary = s["parties"]
	for id in m.gov.partners():
		var pid := str(id)
		var offer: Dictionary = m.gov.offers().get(pid, {})
		var role := str(offer.get("role", "external"))
		var modality := "coalicion" if role == "cabinet" else ("puntual" if role == "puntual" else "externo")
		parties[pid] = {"modality": modality, "since": m.turn(), "expires": (m.turn() + 2) if modality == "puntual" else 0}
		var lines: Array = []
		for rl in m.brain.red_lines(pid):
			if str((rl as Dictionary).get("type", "")) == "issue":
				lines.append(str((rl as Dictionary)["text"]))
		(s["red_lines"] as Dictionary)[pid] = lines

## Se llama al formarse el Gobierno: registra socios, modalidad, reparto, líneas rojas y reglas.
func on_formed() -> void:
	var s := st()
	s.clear()
	ensure()
	s["formed_turn"] = m.turn()
	s["review_turn"] = m.turn() + 4
	proposals().clear()
	_register_partners()
	for id in (s["parties"] as Dictionary).keys():
		var mod := str(((s["parties"] as Dictionary)[id] as Dictionary)["modality"])
		_log("Acuerdo con %s: %s." % [m.party_short(str(id)), str(MODALITY_NAMES[mod]).to_lower()], str(id))

func party_ids() -> Array:
	ensure()
	return (st()["parties"] as Dictionary).keys()

func modality(id: String) -> String:
	return str(((st()["parties"] as Dictionary).get(id, {}) as Dictionary).get("modality", "externo"))

func modality_name(id: String) -> String:
	return str(MODALITY_NAMES.get(modality(id), "—"))

## Reparto actual: {partido: [ministerios]}.
func allocation() -> Dictionary:
	var out: Dictionary = {}
	for e in m.gov.cabinet():
		var ed: Dictionary = e
		var p := str(ed.get("party", ""))
		if not out.has(p):
			out[p] = []
		(out[p] as Array).append(str(ed.get("name", "")))
	return out

func red_lines(id: String) -> Array:
	return ((st().get("red_lines", {}) as Dictionary).get(id, []) as Array)

func rules() -> Dictionary:
	ensure()
	return st()["rules"]

# ---------------------------------------------------------------- confianza entre socios
func trust(id: String) -> float:
	return float(m.d("partner_satisfaction").get(id, 60.0))

func shift_trust(id: String, delta: float, reason: String) -> void:
	if id == "" or not m.d("partner_satisfaction").has(id):
		return
	var sat := m.d("partner_satisfaction")
	sat[id] = clampf(float(sat[id]) + delta, 0.0, 100.0)
	if absf(delta) >= 0.9:
		var f: Array = (st().get("factors", {}) as Dictionary).get(id, [])
		f.push_front({"turn": m.turn(), "delta": delta, "text": reason})
		while f.size() > 8:
			f.pop_back()
		(st()["factors"] as Dictionary)[id] = f

func factors(id: String) -> Array:
	return ((st().get("factors", {}) as Dictionary).get(id, []) as Array)

func note(id: String, text: String) -> void:
	(st()["notes"] as Dictionary)[id] = text

func ai_note(id: String) -> String:
	return str((st().get("notes", {}) as Dictionary).get(id, ""))

func _log(text: String, party_id: String = "") -> void:
	var lg: Array = st().get("log", [])
	lg.push_front({"turn": m.turn(), "text": text, "party": party_id})
	while lg.size() > 60:
		lg.pop_back()
	st()["log"] = lg

func log_entries(n: int = 10) -> Array:
	return (st().get("log", []) as Array).slice(0, n)

## Decisión unilateral del presidente contra un socio: erosiona la confianza y cuenta como incumplimiento del reparto.
func unilateral(id: String, text: String) -> void:
	if id == "" or id == gov_id():
		return
	shift_trust(id, -8.0, text)
	(st()["breach"] as Dictionary)[id] = m.turn()
	add_cause(id, text)
	_log("%s denuncia una decisión unilateral: %s." % [m.party_short(id), text], id)

# ---------------------------------------------------------------- crisis
func crisis(id: String) -> Dictionary:
	var all: Dictionary = st().get("crises", {})
	if not all.has(id):
		all[id] = {"phase": 0, "causes": [], "opened": 0, "deadline": 0, "demand": {}, "postponed": false}
		st()["crises"] = all
	return all[id]

func phase(id: String) -> int:
	return int(crisis(id).get("phase", 0))

func phase_name(id: String) -> String:
	return str(PHASES[clampi(phase(id), 0, PHASES.size() - 1)])

func add_cause(id: String, text: String) -> void:
	var c := crisis(id)
	var causes: Array = c["causes"]
	if not causes.has(text):
		causes.push_front(text)
	while causes.size() > 5:
		causes.pop_back()

## Motivos vivos del malestar de un socio, ordenados de más a menos graves (explicación mostrada al jugador).
func explain(id: String) -> Array:
	var out: Array = []
	var od := overdue_count(id)
	if od > 0:
		out.append("%d compromiso%s vencido%s sin cumplir." % [od, "" if od == 1 else "s", "" if od == 1 else "s"])
	if int((st()["breach"] as Dictionary).get(id, -9)) >= m.turn() - 2:
		out.append("El Gobierno actuó por su cuenta en una materia suya.")
	var c := crisis(id)
	for x in (c.get("causes", []) as Array):
		if not out.has(str(x)):
			out.append(str(x))
	if trust(id) < 50.0:
		out.append("La confianza es baja (%.0f/100)." % trust(id))
	var rej := _recent_disagreements(id)
	if rej > 0:
		out.append("%d propuesta%s suya%s rechazada%s." % [rej, "" if rej == 1 else "s", "" if rej == 1 else "s", "" if rej == 1 else "s"])
	return out

func in_crisis() -> Array:
	var out: Array = []
	for id in party_ids():
		if phase(str(id)) >= 3:
			out.append(str(id))
	return out

func overdue_count(id: String) -> int:
	var n := 0
	for c in m.a("commitments"):
		var com: Dictionary = c
		if str(com.get("party", "")) == id and not bool(com.get("fulfilled", false)) and m.gov_month > int(com.get("due", 8)):
			n += 1
	return n

func _recent_disagreements(id: String) -> int:
	var n := 0
	for p in proposals():
		var d: Dictionary = p
		if (str(d.get("author", "")) == id or str(d.get("minister_party", "")) == id) and str(d.get("state", "")) in ["rejected"] and m.turn() - int(d.get("resolved_turn", -9)) <= 2:
			n += 1
	return n

func _target_phase(id: String) -> int:
	var t := trust(id)
	var base := 0 if t >= 60.0 else (1 if t >= 50.0 else (2 if t >= 40.0 else (3 if t >= 30.0 else (4 if t >= 20.0 else 5))))
	var overdue := overdue_count(id)
	var disag := _recent_disagreements(id)
	if base == 1 and overdue == 0 and disag == 0:
		base = 0
	if overdue >= 2 or int((st()["breach"] as Dictionary).get(id, -9)) >= m.turn() - 1:
		base = mini(5, base + 1)
	if m.turn() - int((st()["meet"] as Dictionary).get(id, -9)) <= 1:
		base = maxi(0, base - 1)
	return base

## Un paso por trimestre como máximo: ningún desacuerdo aislado rompe una coalición.
func _update_phase(id: String) -> void:
	var c := crisis(id)
	var p := int(c["phase"])
	var target := _target_phase(id)
	var np := p
	if target > p:
		np = p + 1
	elif target < p and p < 6:
		np = p - 1
	if np == p:
		return
	c["phase"] = np
	if p == 0:
		c["opened"] = m.turn()
	if np == 0:
		c["causes"] = []
		c["demand"] = {}
	_on_phase_change(id, p, np)

func _on_phase_change(id: String, from_p: int, to_p: int) -> void:
	var short := m.party_short(id)
	_log("%s: de «%s» a «%s»." % [short, str(PHASES[from_p]).to_lower(), str(PHASES[to_p]).to_lower()], id)
	if to_p < from_p:
		if to_p == 0:
			m.publish("%s y el Gobierno recomponen la relación" % short, "Se disipa el conflicto en la coalición.", "NEGOCIACIONES", "positive")
		return
	match to_p:
		1:
			note(id, "Hay un desacuerdo abierto: conviene negociarlo antes de que se acumule.")
		2:
			m.publish("%s advierte al Gobierno" % short, "Se acumulan incumplimientos y choques. El socio pide una reunión de seguimiento. %s" % _cause_text(id), "NEGOCIACIONES", "warning")
		3:
			m.publish("Bloqueo con %s" % short, "No hay acuerdos relevantes con el socio. Haría falta mediación o concesiones. %s" % _cause_text(id), "NEGOCIACIONES", "warning")
			m.s["stability"] = clampf(m.gov.stability() - 3.0, 0.0, 100.0)
		4:
			m.publish("Crisis pública en el Gobierno: %s" % short, "El conflicto con el socio llega a los medios. %s" % _cause_text(id), "GOBIERNO", "negative")
			m.gov.shift_government_approval(-1.5)
			m.itrust.shock(-1.0, "La crisis con %s erosiona al Gobierno ante el partido." % short)
			m.media.on_event("Crisis con %s" % short)
		5:
			_make_ultimatum(id)

func _cause_text(id: String) -> String:
	var causes := explain(id)
	return "Motivo: %s" % str(causes[0]) if not causes.is_empty() else ""

func _make_ultimatum(id: String) -> void:
	var c := crisis(id)
	var demand: Dictionary = {}
	for spec in ask_catalog(id):
		demand = spec
		break
	if demand.is_empty():
		demand = {"kind": "gesture", "title": "Un gesto político claro", "body": "El socio exige una muestra de compromiso con el acuerdo.", "scope": "cumplimiento", "cost": {"capital": 4.0}}
	c["demand"] = demand
	c["deadline"] = m.turn() + 2
	c["postponed"] = false
	var msg := m.publish("Ultimátum de %s" % m.party_short(id), "Condición para seguir: %s. Plazo: hasta el trimestre %d." % [str(demand["title"]), int(c["deadline"])], "GOBIERNO", "negative",
		{"needs_response": gov_id() == m.pid(), "actions": [
			{"id": "crisis:%s:accept" % id, "label": "Aceptar la condición", "style": "primary"},
			{"id": "crisis:%s:negotiate" % id, "label": "Reunirnos y negociar", "style": "secondary"},
			{"id": "crisis:%s:refuse" % id, "label": "Rechazar el ultimátum", "style": "danger"}] if gov_id() == m.pid() else [],
			"key": "ultimatum_%s" % id})
	if msg.is_empty():
		return

## Salidas de la crisis con un socio: reunirse, mediar, ceder, aceptar o rechazar el ultimátum, aplazar.
func crisis_action(id: String, action: String) -> Dictionary:
	if gov_id() != m.pid():
		return {"ok": false, "error": "Solo el presidente gestiona las crisis de coalición."}
	var c := crisis(id)
	match action:
		"meet", "negotiate":
			return meet(id)
		"mediate":
			if phase(id) < 3:
				return {"ok": false, "error": "No hace falta mediación todavía."}
			if int((st()["meet"] as Dictionary).get(id + "_med", -9)) >= m.turn() - 1:
				return {"ok": false, "error": "Ya hubo una mediación reciente."}
			var err := _pay(3.0)
			if err != "":
				return {"ok": false, "error": err}
			(st()["meet"] as Dictionary)[id + "_med"] = m.turn()
			(st()["meet"] as Dictionary)[id] = m.turn()
			shift_trust(id, 8.0, "mediación en la crisis")
			m.ai.change_relation(id, 3.0)
			_log("Mediación con %s: sube la confianza." % m.party_short(id), id)
			return {"ok": true, "text": "La mediación rebaja la tensión con %s." % m.party_short(id)}
		"concede":
			return concede(id)
		"accept":
			if phase(id) != 5:
				return {"ok": false, "error": "No hay ultimátum vigente."}
			var d: Dictionary = c["demand"]
			var res := _apply_ask(id, d, false)
			if not bool(res.get("ok", false)):
				return res
			c["phase"] = 3
			c["demand"] = {}
			shift_trust(id, 14.0, "se cumple su condición")
			_log("Aceptas la condición de %s: la crisis se rebaja a bloqueo." % m.party_short(id), id)
			return {"ok": true, "text": "Aceptas la condición de %s: %s" % [m.party_short(id), str(res.get("text", ""))]}
		"postpone":
			if phase(id) != 5 or bool(c.get("postponed", false)):
				return {"ok": false, "error": "No se puede aplazar el ultimátum."}
			c["deadline"] = int(c["deadline"]) + 1
			c["postponed"] = true
			shift_trust(id, -4.0, "el Gobierno aplaza su ultimátum")
			return {"ok": true, "text": "Ganas un trimestre, pero %s se impacienta." % m.party_short(id)}
		"refuse":
			if phase(id) != 5:
				return {"ok": false, "error": "No hay ultimátum vigente."}
			shift_trust(id, -8.0, "rechazo de su ultimátum")
			return rupture(id, "El Gobierno rechaza el ultimátum.")
	return {"ok": false, "error": "Acción desconocida."}

func _pay(cost: float) -> String:
	m.exec.ensure()
	if m.exec.capital() < cost:
		return "Capital político insuficiente (%d necesario)." % int(ceilf(cost))
	m.exec.add_capital(-cost)
	return ""

func meet(id: String) -> Dictionary:
	if gov_id() != m.pid():
		return {"ok": false, "error": "Solo el presidente convoca a los socios."}
	if int((st()["meet"] as Dictionary).get(id, -9)) == m.turn():
		return {"ok": false, "error": "Ya os habéis reunido este trimestre."}
	var err := _pay(1.0)
	if err != "":
		return {"ok": false, "error": err}
	(st()["meet"] as Dictionary)[id] = m.turn()
	var gain := 7.0 if phase(id) >= 3 else 5.0
	shift_trust(id, gain, "reunión de seguimiento con el presidente")
	m.ai.change_relation(id, 2.0)
	_log("Reunión de seguimiento con %s." % m.party_short(id), id)
	return {"ok": true, "text": "Reunión con %s: la confianza mejora %+.0f." % [m.party_short(id), gain]}

## Concede lo que más desea el socio: la salida más eficaz y la más cara.
func concede(id: String) -> Dictionary:
	if gov_id() != m.pid():
		return {"ok": false, "error": "Solo el presidente puede conceder."}
	var cat := ask_catalog(id)
	if cat.is_empty():
		return {"ok": false, "error": "No queda nada concreto que conceder a %s." % m.party_short(id)}
	var res := _apply_ask(id, cat[0] as Dictionary, false)
	if bool(res.get("ok", false)):
		shift_trust(id, 4.0, "concesión extra del presidente")
		_log("Concesión a %s: %s." % [m.party_short(id), str((cat[0] as Dictionary)["title"])], id)
	return res

# ---------------------------------------------------------------- ruptura
func rupture(id: String, reason: String) -> Dictionary:
	var parties: Dictionary = st()["parties"]
	if not parties.has(id):
		return {"ok": false, "error": "Ese partido no es socio."}
	var mod := modality(id)
	var seats := m.seats_of(id)
	var short := m.party_short(id)
	var lost_names: Array = []
	if mod == "coalicion":
		for e in m.gov.cabinet():
			var ed: Dictionary = e
			if str(ed.get("party", "")) == id:
				lost_names.append(str(ed["name"]))
				ed["party"] = gov_id()
				ed.erase("minister")
				ed["autonomy"] = "plena"
	m.gov.partners().erase(id)
	var offer: Dictionary = m.gov.offers().get(id, {})
	if not offer.is_empty():
		offer["status"] = "rejected"
		offer["role"] = "external"
	parties.erase(id)
	(st()["ruptured"] as Dictionary)[id] = m.turn()
	(st()["crises"] as Dictionary).erase(id)
	m.d("partner_satisfaction").erase(id)
	m.ai.change_relation(id, -15.0)
	m.ai.remember({"party": id, "event": "coalition_broken", "detail": reason})
	var drop := clampf(float(seats) / 4.0, 8.0, 25.0)
	m.s["stability"] = clampf(m.gov.stability() - drop, 0.0, 100.0)
	m.gov.shift_government_approval(-2.0)
	m.itrust.shock(-2.0, "%s rompe el pacto de Gobierno." % short)
	m.ministers.ensure_cabinet()
	for pr in proposals():
		var pd: Dictionary = pr
		if str(pd.get("state", "")) == "open" and (str(pd.get("author", "")) == id or str(pd.get("minister_party", "")) == id):
			pd["state"] = "expired"
			pd["result"] = "El socio abandonó el Gobierno."
	var tail := "El Gobierno gobierna ahora con %d escaños propios y de sus socios (mayoría: %d)." % [government_seats(), Rules.MAJORITY]
	var text := "%s abandona %s. %s %s" % [short, "el Gobierno" if mod == "coalicion" else "su apoyo al Ejecutivo", reason, tail]
	if not lost_names.is_empty():
		text += " Sus carteras quedan en manos del presidente: %s." % ", ".join(lost_names)
	m.publish("Ruptura: %s deja el Gobierno" % short if mod == "coalicion" else "Ruptura: %s retira su apoyo" % short, text, "GOBIERNO", "negative")
	_log("RUPTURA con %s (%s). %s" % [short, MODALITY_NAMES[mod], reason], id)
	if m.exec.post_kind() == "minister":
		var pidx := int(m.exec.st().get("post", -1))
		if pidx < 0 or m.exec.party_of(pidx) != m.pid():
			m.exec.st()["post"] = -1
	return {"ok": true, "rupture": true, "text": text}

func government_seats() -> int:
	var total := m.seats_of(gov_id())
	for id in m.gov.partners():
		total += m.seats_of(str(id))
	return total

func has_majority() -> bool:
	return government_seats() >= Rules.MAJORITY

## El jugador (socio) abandona el Gobierno o retira su apoyo.
func player_leave() -> Dictionary:
	if m.role() != "partner" and not (st()["parties"] as Dictionary).has(m.pid()):
		return {"ok": false, "error": "No formas parte del Gobierno."}
	if gov_id() == m.pid():
		return {"ok": false, "error": "Eres el presidente."}
	var res := rupture(m.pid(), "Tu partido decide romper el acuerdo.")
	m.exec.st()["post"] = -1
	m.ai.change_relation(gov_id(), -12.0)
	return res

# ---------------------------------------------------------------- mayoría rota y elecciones
## Estabilidad agotada: no hay elecciones automáticas. El Gobierno sigue en minoría con presión sobre los socios.
func on_stability_zero() -> Dictionary:
	var s := st()
	s["zero_turns"] = int(s.get("zero_turns", 0)) + 1
	for id in party_ids():
		var c := crisis(str(id))
		if int(c["phase"]) < 3:
			c["phase"] = 3
			add_cause(str(id), "La mayoría del Gobierno está rota.")
			_on_phase_change(str(id), 2, 3)
	m.s["stability"] = 8.0
	m.gov.shift_government_approval(-2.0)
	var text := "El Gobierno ya no cuenta con una mayoría estable. Puede buscar nuevos apoyos, renegociar el pacto o convocar elecciones anticipadas, pero nada se convoca solo."
	m.publish("El Gobierno pierde su mayoría estable", text, "PARLAMENTO", "warning")
	_log("La mayoría de gobierno se rompe (estabilidad agotada).")
	# Si preside la IA y lleva mucho tiempo sin salida, decide ella convocar elecciones (decisión explicada, no automática).
	if gov_id() != m.pid() and int(s["zero_turns"]) >= 3 and not has_majority():
		note(gov_id(), "Sin mayoría durante tres trimestres y sin socios viables: el presidente convoca elecciones.")
		return {"elections": true, "reason": "El presidente, sin mayoría viable tras tres trimestres de bloqueo, convoca elecciones anticipadas."}
	return {}

func can_call_elections() -> Dictionary:
	if gov_id() != m.pid() or m.phase != "legislature":
		return {"ok": false, "error": "Solo el presidente puede convocar elecciones anticipadas."}
	if m.turn() < 3 and has_majority():
		return {"ok": false, "error": "Con mayoría estable no procede convocar elecciones en los primeros trimestres."}
	return {"ok": true}

func call_early_elections() -> Dictionary:
	var chk := can_call_elections()
	if not bool(chk.get("ok", false)):
		return chk
	m.itrust.shock(-2.0 if has_majority() else 0.0, "El presidente adelanta las elecciones.")
	m.gov.call_elections("El presidente convoca elecciones anticipadas%s." % ("" if has_majority() else " ante la pérdida de la mayoría"))
	return {"ok": true, "elections": true}

# ---------------------------------------------------------------- nuevos apoyos tras una ruptura
func candidates_for_support() -> Array:
	var out: Array = []
	for id in m.gov.parliamentary_ids():
		var pid := str(id)
		if pid == gov_id() or m.is_player(pid) or m.gov.partners().has(pid):
			continue
		out.append(pid)
	return out

func recently_broken(id: String) -> bool:
	return m.turn() - int((st().get("ruptured", {}) as Dictionary).get(id, -99)) <= 4

func _invite_score(id: String, mod: String) -> Dictionary:
	var gid := gov_id()
	var veto := m.brain.blocked_by(id, gid)
	var gate := m.brain.gate(id, gid, "cabinet" if mod == "coalicion" else "stability")
	if veto != "" or gate != "":
		return {"verdict": "veto", "score": 0.0, "why": veto if veto != "" else gate}
	var compat := m.brain.compat(id, gid)
	var prag := m.brain.trait_of(id, "pragmatism")
	var s := 0.45 * compat + 0.25 * prag + 0.20 * (m.ai.relation(id) / 100.0) + 0.10
	var why: Array = ["afinidad %d %%" % int(compat * 100.0), "pragmatismo %d %%" % int(prag * 100.0)]
	if recently_broken(id):
		s -= 0.30
		why.append("la ruptura reciente pesa")
	if mod == "coalicion" and m.seats_of(id) < 8:
		s -= 0.15
		why.append("pocos escaños para entrar en el Ejecutivo")
	if mod == "puntual":
		s += 0.10
	var verdict := "accept" if s >= 0.50 else ("counter" if s >= 0.36 else "reject")
	return {"verdict": verdict, "score": s, "why": ", ".join(why)}

## Negocia un nuevo apoyo (tras una ruptura o para reforzar la mayoría). Puede aceptar, contraofertar o rechazar.
func invite(id: String, mod: String, accept_counter: bool = false) -> Dictionary:
	if gov_id() != m.pid():
		return {"ok": false, "error": "Solo el presidente negocia nuevos apoyos."}
	if m.gov.partners().has(id):
		return {"ok": false, "error": "Ya es socio."}
	var r := _invite_score(id, mod)
	var short := m.party_short(id)
	var verdict := str(r["verdict"])
	var why := str(r["why"])
	var counter: Dictionary = {}
	if verdict == "counter" or (verdict == "accept" and false):
		for spec in ask_catalog(id):
			counter = spec
			break
		if accept_counter and counter.is_empty():
			verdict = "reject"
	if verdict == "counter" and accept_counter:
		var res := _apply_ask(id, counter, false)
		if not bool(res.get("ok", false)):
			return res
		verdict = "accept"
	note(id, "%s: %s." % ["Acepta" if verdict == "accept" else ("Pide una contrapartida" if verdict == "counter" else "Rechaza"), why])
	if verdict == "accept":
		_admit(id, mod)
		return {"ok": true, "verdict": "accept", "text": "%s entra como %s." % [short, str(MODALITY_NAMES[mod]).to_lower()], "why": why}
	if verdict == "counter":
		return {"ok": true, "verdict": "counter", "text": "%s aceptaría si concedes: %s." % [short, str(counter.get("title", "una contrapartida"))], "demand": counter, "why": why}
	m.ai.change_relation(id, -1.0)
	return {"ok": true, "verdict": verdict, "text": "%s rechaza el acuerdo: %s." % [short, why], "why": why}

func _admit(id: String, mod: String) -> void:
	var offers := m.gov.offers()
	if not offers.has(id):
		offers[id] = m.gov._make_offer(id)
	var offer: Dictionary = offers[id]
	offer["status"] = "accepted"
	offer["role"] = "cabinet" if mod == "coalicion" else ("puntual" if mod == "puntual" else "external")
	if not m.gov.partners().has(id):
		m.gov.partners().append(id)
	m.d("partner_satisfaction")[id] = 55.0
	(st()["parties"] as Dictionary)[id] = {"modality": mod, "since": m.turn(), "expires": (m.turn() + 2) if mod == "puntual" else 0}
	var lines: Array = []
	for rl in m.brain.red_lines(id):
		if str((rl as Dictionary).get("type", "")) == "issue":
			lines.append(str((rl as Dictionary)["text"]))
	(st()["red_lines"] as Dictionary)[id] = lines
	(st()["crises"] as Dictionary).erase(id)
	m.ai.change_relation(id, 6.0)
	var given := ""
	if mod == "coalicion":
		given = _give_ministry(id)
	m.s["stability"] = clampf(m.gov.stability() + clampf(float(m.seats_of(id)) / 3.0, 5.0, 18.0), 0.0, 100.0)
	m.publish("%s se suma al Gobierno" % m.party_short(id) if mod == "coalicion" else "Nuevo apoyo: %s" % m.party_short(id),
		"%s pasa a ser %s. %s Mayoría: %d de %d escaños." % [m.party_short(id), str(MODALITY_NAMES[mod]).to_lower(), given, government_seats(), Rules.MAJORITY], "GOBIERNO", "positive")
	_log("Nuevo acuerdo con %s: %s." % [m.party_short(id), str(MODALITY_NAMES[mod]).to_lower()], id)

## Cede al nuevo socio la cartera menos esencial del presidente.
func _give_ministry(id: String) -> String:
	var best := -1
	var best_score := 999.0
	var cab := m.gov.cabinet()
	for i in range(cab.size()):
		var e: Dictionary = cab[i]
		if str(e.get("party", "")) != gov_id() or i == 0:
			continue
		var score := 0.0
		for c in (e.get("comps", []) as Array):
			score += 3.0 if Competencies.essentials().has(str(c)) else 1.0
		if int(m.exec.st().get("post", -9)) == i and m.pid() == gov_id():
			score += 5.0
		if score < best_score:
			best_score = score
			best = i
	if best < 0:
		return ""
	m.cab.assign_party(best, id, true)
	return "Recibe la cartera de %s." % str((cab[best] as Dictionary)["name"])

# ---------------------------------------------------------------- catálogo de peticiones
func scope_of_line(line_id: String) -> String:
	return str(LINE_SCOPE.get(line_id, "presupuestos"))

## Peticiones concretas y viables que tiene un partido para el Gobierno, de más a menos importantes para él.
func ask_catalog(id: String) -> Array:
	var group := str(m.ai.profile_of(id).get("priority", "economy"))
	if m.is_player(id):
		var pr := m.ai.issue_priorities(m.party)
		group = m.ai.demand_group(str(pr[0])) if not pr.is_empty() else "economy"
	var out: Array = []
	var specs: Array = (ASK_GROUPS.get(group, ASK_GROUPS["economy"]) as Array).duplicate()
	# Los partidos pequeños con intereses territoriales también piden agricultura e infraestructuras.
	if group != "territory" and m.seats_of(id) <= 20 and m.is_regional(id):
		specs.append({"kind": "budget", "line": "agricultura"})
		specs.append({"kind": "budget", "line": "territorial"})
	for spec in specs:
		var ask := _build_ask(id, spec as Dictionary)
		if not ask.is_empty():
			out.append(ask)
	return out

func _line_name(line_id: String) -> String:
	return str(Policies.entry(Policies.budget(), line_id).get("name", line_id))

func _build_ask(id: String, spec: Dictionary) -> Dictionary:
	var short := m.party_short(id)
	match str(spec["kind"]):
		"budget":
			var line := str(spec["line"])
			if Policies.entry(Policies.budget(), line).is_empty():
				return {}
			m.exec.ensure()
			if m.exec.credit_delta(line) + CREDIT_STEP > 0.15 + 0.0001:
				return {}
			var funds := m.eco.budget_spending(line) * CREDIT_STEP
			return {"kind": "budget", "line": line, "scope": scope_of_line(line), "title": "%s: +5 %% de crédito" % _line_name(line),
				"body": "%s pide reforzar la partida de %s en un 5 %% sobre lo presupuestado." % [short, _line_name(line).to_lower()],
				"cost": {"funds": funds, "capital": 0.0}, "impact": ["Gasto público +%.1f mM€ al año" % funds, "El déficit empeora levemente", "Mejora el servicio financiado"]}
		"bill":
			var issue := str(spec["issue"])
			for c in m.a("commitments"):
				var com: Dictionary = c
				if str(com.get("party", "")) == id and str(com.get("issue", "")) == issue and not bool(com.get("fulfilled", false)):
					return {}
			var bill_id := ""
			for b in Rules.BILLS:
				if str((b as Dictionary)["issue"]) == issue:
					bill_id = str((b as Dictionary)["id"])
			if bill_id != "" and m.a("passed_bills").has(bill_id):
				return {}
			return {"kind": "bill", "issue": issue, "scope": "leyes", "title": "Ley sobre %s" % Rules.issue_name(issue).to_lower(),
				"body": "%s exige que el Gobierno impulse y apruebe una ley sobre %s." % [short, Rules.issue_name(issue).to_lower()],
				"cost": {"funds": 0.0, "capital": 0.0}, "impact": ["Compromiso a 9 meses", "Se cumple cuando una ley de la materia sale adelante", "Si no se cumple, cae la confianza"]}
		"comp":
			var comp_id := str(spec["comp"])
			if modality(id) != "coalicion":
				return {}
			var owner := m.cab.owner_of(comp_id)
			if owner < 0 or str(m.cab.entry(owner).get("party", "")) == id or m.cab.is_reserved(owner):
				return {}
			return {"kind": "comp", "comp": comp_id, "scope": "nombramientos", "title": "Competencia: %s" % Competencies.name_of(comp_id),
				"body": "%s reclama gestionar %s, hoy en manos de «%s»." % [short, Competencies.name_of(comp_id).to_lower(), str(m.cab.entry(owner)["name"])],
				"cost": {"funds": 0.0, "capital": 0.0}, "impact": ["«%s» pierde la competencia" % str(m.cab.entry(owner)["name"]), "Pasa a una cartera de %s" % short]}
	return {}

# ---------------------------------------------------------------- aplicar una petición aceptada
func _new_commitment(id: String, ask: Dictionary, fulfilled: bool, reduced: bool) -> Dictionary:
	var seq := int(st().get("cseq", 0)) + 1
	st()["cseq"] = seq
	var com := {"id": seq, "party": id, "issue": str(ask.get("issue", ask.get("line", ask.get("comp", "mesa")))), "text": str(ask["title"]),
		"due": m.gov_month + (12 if reduced else 9), "fulfilled": fulfilled, "overdue_flagged": false, "source": "mesa", "scope": str(ask.get("scope", "leyes"))}
	m.a("commitments").append(com)
	return com

func _apply_ask(id: String, ask: Dictionary, reduced: bool) -> Dictionary:
	var mult := 0.5 if reduced else 1.0
	match str(ask.get("kind", "")):
		"budget":
			m.exec.ensure()
			var line := str(ask["line"])
			var p := m.exec.pge()
			if not p.has("adjust"):
				p["adjust"] = {}
			var adj: Dictionary = p["adjust"]
			var step := CREDIT_STEP * mult
			var nv := snappedf(clampf(float(adj.get(line, 0.0)) + step, -0.10, 0.15), 0.0005)
			if nv <= float(adj.get(line, 0.0)) + 0.00001:
				return {"ok": false, "error": "La partida ya no admite más crédito sin nuevos Presupuestos."}
			adj[line] = nv
			m.eco._compute_fiscal()
			m.eco._compute_composition()
			_new_commitment(id, ask, true, reduced)
			shift_trust(id, 8.0 * mult + 2.0, "se refuerza la partida que pedía")
			m.ai.change_relation(id, 3.0 * mult)
			return {"ok": true, "text": "%s sube un %.1f %% y %s lo valora." % [_line_name(line), step * 100.0, m.party_short(id)]}
		"bill":
			_new_commitment(id, ask, false, reduced)
			shift_trust(id, 4.0 * mult + 1.0, "compromiso de impulsar su ley")
			m.ai.change_relation(id, 2.0 * mult)
			return {"ok": true, "text": "Te comprometes con %s a sacar adelante: %s (plazo de %d meses)." % [m.party_short(id), str(ask["title"]).to_lower(), 12 if reduced else 9]}
		"comp":
			var comp_id := str(ask["comp"])
			var owner := m.cab.owner_of(comp_id)
			if owner < 0:
				return {"ok": false, "error": "Esa competencia ya no la gestiona ninguna cartera."}
			var target := -1
			var best_n := 999
			for i in range(m.cab.size()):
				var e: Dictionary = m.cab.entry(i)
				if str(e.get("party", "")) == id and (e.get("comps", []) as Array).size() < best_n:
					best_n = (e.get("comps", []) as Array).size()
					target = i
			if target < 0:
				return {"ok": false, "error": "%s no tiene ninguna cartera que pueda asumirla." % m.party_short(id)}
			if reduced:
				var sh: Array = m.cab.shared_of(target)
				if not sh.has(comp_id):
					sh.append(comp_id)
			else:
				m.cab.comps_of(owner).erase(comp_id)
				m.cab.comps_of(target).append(comp_id)
			_new_commitment(id, ask, true, reduced)
			shift_trust(id, 8.0 * mult + 2.0, "obtiene la competencia que pedía")
			m.ai.change_relation(id, 3.0 * mult)
			return {"ok": true, "text": "%s %s la competencia de %s en «%s»." % [m.party_short(id), "comparte" if reduced else "asume", Competencies.name_of(comp_id).to_lower(), str(m.cab.entry(target)["name"])]}
		"gesture":
			var err := _pay(4.0)
			if err != "":
				return {"ok": false, "error": err}
			return {"ok": true, "text": "Haces un gesto político claro hacia %s." % m.party_short(id)}
	return {"ok": false, "error": "Petición no válida."}

# ---------------------------------------------------------------- propuestas
func find(pid: int) -> Dictionary:
	for p in proposals():
		if int((p as Dictionary).get("id", -1)) == pid:
			return p
	return {}

func open_list() -> Array:
	var out: Array = []
	for p in proposals():
		if str((p as Dictionary).get("state", "")) in ["open", "countered"]:
			out.append(p)
	return out

func open_for_player() -> Array:
	var out: Array = []
	for p in open_list():
		if str((p as Dictionary).get("decider", "")) == m.pid():
			out.append(p)
	return out

func history(n: int = 12) -> Array:
	var out: Array = []
	var all := proposals()
	for i in range(all.size() - 1, -1, -1):
		if not str((all[i] as Dictionary).get("state", "open")) in ["open", "countered"]:
			out.append(all[i])
			if out.size() >= n:
				break
	return out

func options_for(p: Dictionary) -> Array:
	match str(p.get("kind", "")):
		"reform":
			return [{"id": "accept", "label": "Autorizar", "style": "primary"}, {"id": "modify", "label": "Moderar", "style": "secondary"},
				{"id": "postpone", "label": "Aplazar", "style": "ghost"}, {"id": "reject", "label": "Rechazar", "style": "danger"}]
		"resources":
			return [{"id": "accept", "label": "Conceder", "style": "primary"}, {"id": "postpone", "label": "Aplazar", "style": "ghost"}, {"id": "reject", "label": "Denegar", "style": "danger"}]
		"party_ask":
			return [{"id": "accept", "label": "Aceptar", "style": "primary"}, {"id": "counter", "label": "Contraoferta", "style": "secondary"},
				{"id": "postpone", "label": "Aplazar", "style": "ghost"}, {"id": "reject", "label": "Rechazar", "style": "danger"}]
		"statement":
			return [{"id": "back", "label": "Respaldar", "style": "primary"}, {"id": "negotiate", "label": "Negociar en la mesa", "style": "secondary"}, {"id": "disown", "label": "Desautorizar", "style": "danger"}]
		"clash":
			return [{"id": "favor_a", "label": "Dar la razón a %s" % str(p.get("name_a", "A")), "style": "secondary"},
				{"id": "favor_b", "label": "Dar la razón a %s" % str(p.get("name_b", "B")), "style": "secondary"}, {"id": "coordinate", "label": "Ordenar coordinarse", "style": "primary"}]
		"scandal":
			return [{"id": "back", "label": "Respaldar", "style": "secondary"}, {"id": "investigate", "label": "Abrir una investigación", "style": "primary"}, {"id": "resign", "label": "Exigir la dimisión", "style": "danger"}]
		"error":
			return [{"id": "back", "label": "Respaldar", "style": "secondary"}, {"id": "plan", "label": "Exigir un plan correctivo", "style": "primary"}, {"id": "rebuke", "label": "Reprender", "style": "danger"}]
		"offer":
			if str(p.get("state", "")) == "countered":
				return [{"id": "accept", "label": "Aceptar su condición", "style": "primary"}, {"id": "reject", "label": "Retirar la propuesta", "style": "ghost"}]
	return []

## Crea una propuesta en la mesa. Si la decide la IA se resuelve de inmediato; si la decide el jugador queda abierta.
func submit(p: Dictionary) -> Dictionary:
	ensure()
	var seq := int(st().get("seq", 0)) + 1
	st()["seq"] = seq
	p["id"] = seq
	p["state"] = "open"
	p["created_turn"] = m.turn()
	p["due_turn"] = m.turn() + PROPOSAL_TTL
	if not p.has("scope"):
		p["scope"] = "leyes"
	if not p.has("decider"):
		p["decider"] = gov_id()
	proposals().append(p)
	while proposals().size() > 80:
		proposals().pop_front()
	if str(p["decider"]) == m.pid():
		var actions: Array = []
		for o in options_for(p):
			actions.append({"id": "tbl:%d:%s" % [seq, str((o as Dictionary)["id"])], "label": str((o as Dictionary)["label"]), "style": str((o as Dictionary)["style"])})
		m.publish(str(p["title"]), "%s %s" % [str(p.get("body", "")), _impact_line(p)], "GOBIERNO", "warning",
			{"needs_response": true, "actions": actions, "expires_in": PROPOSAL_TTL * Rules.TURN_MONTHS, "key": "tbl_%d" % seq})
	else:
		_ai_decide(p)
	return p

func _impact_line(p: Dictionary) -> String:
	var bits: Array = []
	var cost: Dictionary = p.get("cost", {})
	if float(cost.get("capital", 0.0)) > 0.0:
		bits.append("Capital político: %d." % int(cost["capital"]))
	if float(cost.get("funds", 0.0)) > 0.0:
		bits.append("Coste: %.1f mM€/año." % float(cost["funds"]))
	if str(p.get("risk", "")) != "":
		bits.append("Riesgo: %s." % str(p["risk"]))
	return " ".join(bits)

func _close(p: Dictionary, state: String, result: String) -> void:
	p["state"] = state
	p["result"] = result
	p["resolved_turn"] = m.turn()
	_log("%s — %s: %s" % [str(p.get("title", "")), state, result], str(p.get("author", "")))

## Respuesta del jugador (o de la bandeja) a una propuesta abierta.
func respond(pid: int, opt: String) -> Dictionary:
	var p := find(pid)
	if p.is_empty() or not str(p.get("state", "")) in ["open", "countered"]:
		return {"ok": false, "error": "La propuesta ya está resuelta."}
	if str(p.get("decider", "")) != m.pid():
		return {"ok": false, "error": "No te corresponde decidir esta propuesta."}
	var res := _resolve(p, opt)
	if bool(res.get("ok", false)):
		# La notificación de la bandeja deja de esperar respuesta.
		for n in m.news():
			var nd: Dictionary = n
			if str(nd.get("key", "")) == "tbl_%d" % pid and bool(nd.get("needs_response", false)):
				nd["resolved"] = true
				nd["needs_response"] = false
				nd["resolution"] = str(res.get("text", ""))
	return res

func _resolve(p: Dictionary, opt: String) -> Dictionary:
	var kind := str(p.get("kind", ""))
	var party := str(p.get("minister_party", p.get("author", "")))
	var mid := str(p.get("ministry_id", ""))
	var idx := m.cab.idx_of(mid) if mid != "" else -1
	var res: Dictionary = {"ok": false, "error": "Opción no válida."}
	match kind:
		"reform":
			res = _resolve_reform(p, opt, idx)
		"resources":
			res = _resolve_resources(p, opt, idx)
		"party_ask":
			res = _resolve_party_ask(p, opt)
		"statement":
			res = _resolve_statement(p, opt, idx)
		"clash":
			res = _resolve_clash(p, opt)
		"scandal":
			res = _resolve_scandal(p, opt, idx)
		"error":
			res = _resolve_error(p, opt, idx)
		"offer":
			res = _resolve_offer(p, opt)
	if bool(res.get("ok", false)) and str(p.get("state", "")) == "open" and not res.has("keep_open"):
		_close(p, "accepted" if opt in ["accept", "back", "investigate", "plan", "coordinate", "favor_a", "favor_b", "negotiate"] else ("postponed" if opt == "postpone" else "rejected"), str(res.get("text", "")))
	return res

func _resolve_reform(p: Dictionary, opt: String, idx: int) -> Dictionary:
	var mn := m.cab.minister(idx) if idx >= 0 else {}
	var party := str(p.get("minister_party", ""))
	var partner := party != "" and party != gov_id()
	var meas := Policies.measure(str(p["measure"]))
	if idx < 0 or meas.is_empty():
		_close(p, "expired", "La cartera ya no existe.")
		return {"ok": true, "text": "La propuesta decae: la cartera ya no existe.", "keep_open": true}
	var nv := float(p["nv"])
	match opt:
		"accept", "modify":
			if opt == "modify":
				var cur := m.eco.value(str(meas["id"]))
				nv = Policies.snap(meas, cur + (nv - cur) * 0.5)
				if is_equal_approx(nv, cur):
					return {"ok": false, "error": "No se puede moderar más: queda igual que ahora."}
			var cost := m.exec.cost_of(meas, nv)
			var err := _pay(cost)
			if err != "":
				return {"ok": false, "error": err}
			m.exec._apply(idx, meas, nv, party if party != "" else gov_id(), false)
			var inc := m.exec.incoherence(meas, nv)
			if inc > 0.3 and gov_id() == m.pid():
				m.exec._voter_backlash(meas, inc)
			if not mn.is_empty():
				mn["act"] = clampf(float(mn.get("act", 55.0)) + (6.0 if opt == "accept" else 3.0), 0.0, 100.0)
				m.ministers.shift_relation(mn, 4.0 if opt == "accept" else 1.0)
				m.ministers.log_history(mn, "El Gobierno %s su reforma: %s." % ["autoriza" if opt == "accept" else "modera", str(meas["name"])])
			if partner:
				shift_trust(party, 4.0 if opt == "accept" else 1.0, "el Gobierno atiende la reforma de su ministro")
			return {"ok": true, "text": "%s: %s queda en «%s»." % ["Autorizas" if opt == "accept" else "Moderas", str(meas["name"]), Policies.value_text(meas, nv)]}
		"postpone":
			p["due_turn"] = int(p["due_turn"]) + 1
			p["postponed"] = int(p.get("postponed", 0)) + 1
			if not mn.is_empty():
				m.ministers.shift_relation(mn, -1.5)
			if partner:
				shift_trust(party, -1.5, "el Gobierno aplaza la reforma de su ministro")
			if int(p["postponed"]) >= 2:
				return {"ok": true, "text": "Aplazas la reforma de nuevo: el ministro pierde la paciencia."}
			return {"ok": true, "text": "Aplazas la decisión un trimestre.", "keep_open": true}
		"reject":
			if not mn.is_empty():
				m.ministers.shift_relation(mn, -5.0)
				m.ministers.log_history(mn, "El Gobierno rechaza su reforma: %s." % str(meas["name"]))
				if m.ministers.attr(mn, "ambicion") >= 7:
					m.ministers.shift_relation(mn, -2.0)
			if partner:
				shift_trust(party, -5.0, "el Gobierno rechaza la reforma de su ministro")
				add_cause(party, "El Gobierno vetó una reforma de su ministro de %s." % str(m.cab.entry(idx).get("name", "")))
			return {"ok": true, "text": "Rechazas la reforma: el ministro lo nota%s." % (" y su partido también" if partner else "")}
	return {"ok": false, "error": "Opción no válida."}

func _resolve_resources(p: Dictionary, opt: String, idx: int) -> Dictionary:
	var mn := m.cab.minister(idx) if idx >= 0 else {}
	var party := str(p.get("minister_party", ""))
	var partner := party != "" and party != gov_id()
	var line := str(p.get("line", ""))
	match opt:
		"accept":
			m.exec.ensure()
			var pge := m.exec.pge()
			if not pge.has("adjust"):
				pge["adjust"] = {}
			var adj: Dictionary = pge["adjust"]
			var nv := snappedf(clampf(float(adj.get(line, 0.0)) + Executive.FACTOR_STEP, -0.10, 0.15), 0.0005)
			if nv <= float(adj.get(line, 0.0)) + 0.00001:
				return {"ok": false, "error": "La partida ya no admite más crédito sin nuevos Presupuestos."}
			adj[line] = nv
			m.eco._compute_fiscal()
			m.eco._compute_composition()
			if not mn.is_empty():
				mn["act"] = clampf(float(mn.get("act", 55.0)) + 4.0, 0.0, 100.0)
				m.ministers.shift_relation(mn, 3.0)
			if partner:
				shift_trust(party, 3.0, "se atiende la petición de recursos de su ministerio")
			return {"ok": true, "text": "Concedes más crédito a %s (+%.1f %%)." % [_line_name(line), Executive.FACTOR_STEP * 100.0]}
		"postpone":
			p["due_turn"] = int(p["due_turn"]) + 1
			return {"ok": true, "text": "Aplazas la petición un trimestre.", "keep_open": true}
		"reject":
			if not mn.is_empty():
				m.ministers.shift_relation(mn, -3.0)
			if partner:
				shift_trust(party, -3.0, "se deniega la petición de recursos de su ministerio")
			return {"ok": true, "text": "Deniegas los recursos."}
	return {"ok": false, "error": "Opción no válida."}

func _resolve_party_ask(p: Dictionary, opt: String) -> Dictionary:
	var id := str(p.get("author", ""))
	var ask: Dictionary = p.get("ask", {})
	match opt:
		"accept":
			return _apply_ask(id, ask, false)
		"counter":
			var res := _apply_ask(id, ask, true)
			if bool(res.get("ok", false)):
				res["text"] = "Contraoferta aceptada por %s: %s" % [m.party_short(id), str(res["text"])]
			return res
		"postpone":
			p["due_turn"] = int(p["due_turn"]) + 1
			shift_trust(id, -1.5, "el Gobierno aplaza su petición")
			return {"ok": true, "text": "Aplazas la petición de %s." % m.party_short(id), "keep_open": true}
		"reject":
			shift_trust(id, -6.0, "el Gobierno rechaza su petición")
			add_cause(id, "El Gobierno rechazó su petición: %s." % str(p.get("title", "")))
			m.ai.change_relation(id, -2.0)
			return {"ok": true, "text": "Rechazas la petición de %s." % m.party_short(id)}
	return {"ok": false, "error": "Opción no válida."}

func _offended(p: Dictionary) -> String:
	return str(p.get("offended", ""))

func _resolve_statement(p: Dictionary, opt: String, idx: int) -> Dictionary:
	var mn := m.cab.minister(idx) if idx >= 0 else {}
	var party := str(p.get("minister_party", ""))
	var off := _offended(p)
	match opt:
		"back":
			if not mn.is_empty():
				m.ministers.shift_relation(mn, 5.0)
				m.ministers.log_history(mn, "El presidente respalda su polémica declaración.")
			m.gov.shift_government_approval(-0.3)
			if party != "" and party != gov_id():
				shift_trust(party, 3.0, "el presidente respalda a su ministro")
			if off != "":
				shift_trust(off, -5.0, "el presidente respalda unas declaraciones que le ofenden")
				add_cause(off, "Declaraciones polémicas respaldadas por el presidente.")
			return {"ok": true, "text": "Respaldas la declaración: el ministro, agradecido; el socio ofendido, no tanto."}
		"disown":
			if not mn.is_empty():
				m.ministers.shift_relation(mn, -10.0)
				m.ministers.shift_attr(mn, "lealtad", -1)
				m.ministers.log_history(mn, "El presidente le desautoriza por sus declaraciones.")
			m.gov.shift_government_approval(0.2)
			if party != "" and party != gov_id():
				shift_trust(party, -7.0, "el presidente desautoriza a su ministro")
				add_cause(party, "El presidente desautorizó públicamente a su ministro.")
			if off != "":
				shift_trust(off, 3.0, "el presidente desautoriza unas declaraciones que le ofendían")
			return {"ok": true, "text": "Desautorizas al ministro: se calma el conflicto, pero hay heridas."}
		"negotiate":
			var err := _pay(1.0)
			if err != "":
				return {"ok": false, "error": err}
			if party != "" and party != gov_id():
				shift_trust(party, 1.0, "mediación por las declaraciones de su ministro")
			if off != "":
				shift_trust(off, 3.0, "el presidente media por unas declaraciones que le ofendían")
			if not mn.is_empty():
				m.ministers.shift_relation(mn, -1.0)
			return {"ok": true, "text": "Negocias en la mesa: ambos socios aceptan rebajar el tono."}
	return {"ok": false, "error": "Opción no válida."}

func _resolve_clash(p: Dictionary, opt: String) -> Dictionary:
	var pa := str(p.get("party_a", ""))
	var pb := str(p.get("party_b", ""))
	match opt:
		"favor_a":
			shift_trust(pa, 4.0, "gana el choque de competencias") if pa != gov_id() else null
			shift_trust(pb, -5.0, "pierde el choque de competencias") if pb != gov_id() else null
			return {"ok": true, "text": "Das la razón a «%s» en el choque de competencias." % str(p.get("name_a", ""))}
		"favor_b":
			shift_trust(pb, 4.0, "gana el choque de competencias") if pb != gov_id() else null
			shift_trust(pa, -5.0, "pierde el choque de competencias") if pa != gov_id() else null
			return {"ok": true, "text": "Das la razón a «%s» en el choque de competencias." % str(p.get("name_b", ""))}
		"coordinate":
			var err := _pay(1.0)
			if err != "":
				return {"ok": false, "error": err}
			if pa != gov_id():
				shift_trust(pa, 1.0, "coordinación entre ministerios")
			if pb != gov_id():
				shift_trust(pb, 1.0, "coordinación entre ministerios")
			return {"ok": true, "text": "Ordenas a ambos ministerios coordinarse: ni ganadores ni perdedores."}
	return {"ok": false, "error": "Opción no válida."}

func _resolve_scandal(p: Dictionary, opt: String, idx: int) -> Dictionary:
	if idx < 0:
		return {"ok": true, "text": "La cartera ya no existe."}
	var mn := m.cab.minister(idx)
	var party := str(p.get("minister_party", ""))
	match opt:
		"back":
			m.ministers.shift_relation(mn, 4.0)
			m.gov.shift_government_approval(-1.5)
			m.itrust.shock(-1.0, "El presidente respalda a un ministro bajo sospecha.")
			if party != "" and party != gov_id():
				shift_trust(party, 3.0, "el presidente respalda a su ministro en un escándalo")
			return {"ok": true, "text": "Respaldas al ministro: el coste en imagen es alto."}
		"investigate":
			m.gov.shift_government_approval(-0.8)
			var p_guilty := clampf((6.0 - float(m.ministers.attr(mn, "integridad"))) / 8.0, 0.1, 0.85)
			if m.rng.randf() < p_guilty:
				var r := m.cab.fire(idx) if not m.cab.is_reserved(idx) else m.cab._request_partner(idx, "la dimisión tras la investigación")
				return {"ok": true, "text": "La investigación halla irregularidades. %s" % str(r.get("text", ""))}
			m.gov.shift_government_approval(0.4)
			m.ministers.shift_relation(mn, 3.0)
			m.ministers.log_history(mn, "Una investigación independiente le exculpa.")
			return {"ok": true, "text": "La investigación exculpa al ministro y el Gobierno recupera algo de crédito."}
		"resign":
			var r2 := m.cab.ask_resignation(idx)
			return {"ok": bool(r2.get("ok", false)), "text": str(r2.get("text", r2.get("error", "")))}
	return {"ok": false, "error": "Opción no válida."}

func _resolve_error(p: Dictionary, opt: String, idx: int) -> Dictionary:
	if idx < 0:
		return {"ok": true, "text": "La cartera ya no existe."}
	var mn := m.cab.minister(idx)
	match opt:
		"back":
			m.ministers.shift_relation(mn, 3.0)
			m.gov.shift_government_approval(-0.3)
			return {"ok": true, "text": "Respaldas al ministro pese al error."}
		"plan":
			var r := m.cab.demand_plan(idx)
			return {"ok": bool(r.get("ok", false)), "text": str(r.get("text", r.get("error", ""))), "error": str(r.get("error", ""))}
		"rebuke":
			var r2 := m.cab.rebuke(idx)
			return {"ok": bool(r2.get("ok", false)), "text": str(r2.get("text", r2.get("error", ""))), "error": str(r2.get("error", ""))}
	return {"ok": false, "error": "Opción no válida."}

func _resolve_offer(p: Dictionary, opt: String) -> Dictionary:
	var id := str(p.get("target", ""))
	if opt == "reject":
		return {"ok": true, "text": "Retiras la propuesta."}
	if opt == "accept" and str(p.get("state", "")) == "countered":
		var give: Dictionary = p.get("give", {})
		var res := _apply_ask(id, give, false)
		if not bool(res.get("ok", false)):
			return res
		_apply_want(id, str(p.get("want", "stability")))
		return {"ok": true, "text": "Cierras el trato con %s: %s" % [m.party_short(id), str(res["text"])]}
	return {"ok": false, "error": "Opción no válida."}

# ---------------------------------------------------------------- decisión automática (la IA preside)
func _ai_decide(p: Dictionary) -> void:
	var kind := str(p.get("kind", ""))
	var idx := m.cab.idx_of(str(p.get("ministry_id", "")))
	var ok := true
	match kind:
		"reform":
			var meas := Policies.measure(str(p.get("measure", "")))
			var dirn := 1.0 if float(p.get("nv", 0.0)) > m.eco.value(str(meas.get("id", ""))) else -1.0
			ok = not meas.is_empty() and m.laws.measure_pref(gov_id(), meas) * dirn > -0.15
			if ok and idx >= 0:
				m.exec._apply(idx, meas, float(p["nv"]), str(p.get("minister_party", gov_id())), false)
			_close(p, "accepted" if ok else "rejected", "El Gobierno %s la reforma." % ("autoriza" if ok else "rechaza"))
		"resources":
			_close(p, "accepted", "El Gobierno concede más crédito.") if m.rng.randf() < 0.6 else _close(p, "rejected", "El Gobierno deniega los recursos.")
		_:
			_close(p, "accepted", "El Gobierno actúa según su criterio.")

# ---------------------------------------------------------------- propuestas del jugador a un socio
const WANT_NAMES := {"stability": "Estabilidad parlamentaria", "votes": "Apoyo en las próximas votaciones"}

func offer_preview(id: String, want: String, give_index: int) -> Dictionary:
	var cat := ask_catalog(id)
	var give: Dictionary = cat[give_index] if give_index >= 0 and give_index < cat.size() else {}
	var gid := gov_id()
	var s := 0.20 + (trust(id) - 50.0) / 100.0 * 0.6 + m.ai.affinity(id, gid) * 0.30 + m.brain.trait_of(id, "pragmatism") * 0.15
	var why: Array = ["confianza %d" % int(trust(id)), "afinidad %d %%" % int(m.ai.affinity(id, gid) * 100.0)]
	s -= 0.15 if want == "stability" else 0.25
	s -= 0.05 * float(phase(id))
	if not give.is_empty():
		s += 0.35
		why.append("la contrapartida le interesa")
	var verdict := "accept" if s >= 0.5 else ("counter" if s >= 0.3 and give.is_empty() else "reject")
	if s >= 0.3 and not give.is_empty() and s < 0.5:
		verdict = "reject"
	return {"verdict": verdict, "score": s, "why": ", ".join(why), "give": give}

func _apply_want(id: String, want: String) -> void:
	match want:
		"stability":
			m.s["stability"] = clampf(m.gov.stability() + 6.0, 0.0, 100.0)
		"votes":
			m.diplomacy._register_pacts(id, "bills", [{"k": "bills", "by": "ai", "n": 2}])

## El presidente propone a un socio un intercambio: pide estabilidad o votos y, si quiere, ofrece una de sus peticiones.
func player_offer(id: String, want: String, give_index: int) -> Dictionary:
	if gov_id() != m.pid():
		return {"ok": false, "error": "Solo el presidente propone intercambios a los socios."}
	if not party_ids().has(id):
		return {"ok": false, "error": "Ese partido no es socio."}
	var open_n := 0
	for p in open_list():
		if str((p as Dictionary).get("target", "")) == id:
			open_n += 1
	if open_n > 0:
		return {"ok": false, "error": "Ya tienes una propuesta abierta con %s." % m.party_short(id)}
	var pv := offer_preview(id, want, give_index)
	var prop := {"kind": "offer", "origin": "player", "author": m.pid(), "target": id, "decider": id, "want": want,
		"title": "Propuesta a %s: %s" % [m.party_short(id), str(WANT_NAMES[want]).to_lower()], "scope": "leyes",
		"body": "Pides %s%s." % [str(WANT_NAMES[want]).to_lower(), (" a cambio de: %s" % str((pv["give"] as Dictionary)["title"])) if not (pv["give"] as Dictionary).is_empty() else ""],
		"cost": {"capital": 0.0, "funds": float(((pv["give"] as Dictionary).get("cost", {}) as Dictionary).get("funds", 0.0))}}
	var seq := int(st().get("seq", 0)) + 1
	st()["seq"] = seq
	prop["id"] = seq
	prop["created_turn"] = m.turn()
	prop["due_turn"] = m.turn() + PROPOSAL_TTL
	prop["reason"] = str(pv["why"])
	proposals().append(prop)
	var verdict := str(pv["verdict"])
	note(id, "%s: %s." % ["Acepta" if verdict == "accept" else ("Pide una contrapartida" if verdict == "counter" else "Rechaza"), str(pv["why"])])
	if verdict == "accept":
		var res: Dictionary = {"ok": true, "text": ""}
		if not (pv["give"] as Dictionary).is_empty():
			res = _apply_ask(id, pv["give"] as Dictionary, false)
			if not bool(res.get("ok", false)):
				_close(prop, "rejected", str(res.get("error", "")))
				return res
		_apply_want(id, want)
		shift_trust(id, 2.0, "pacto en la mesa")
		_close(prop, "accepted", "%s acepta (%s)." % [m.party_short(id), str(pv["why"])])
		return {"ok": true, "verdict": "accept", "text": "%s acepta: %s." % [m.party_short(id), str(WANT_NAMES[want]).to_lower()], "why": str(pv["why"])}
	if verdict == "counter":
		var cat := ask_catalog(id)
		if cat.is_empty():
			_close(prop, "rejected", "%s rechaza (%s)." % [m.party_short(id), str(pv["why"])])
			return {"ok": true, "verdict": "reject", "text": "%s rechaza la propuesta." % m.party_short(id), "why": str(pv["why"])}
		prop["give"] = cat[0]
		prop["state"] = "countered"
		prop["decider"] = m.pid()
		prop["body"] = "%s acepta darte %s si concedes: %s." % [m.party_short(id), str(WANT_NAMES[want]).to_lower(), str((cat[0] as Dictionary)["title"])]
		return {"ok": true, "verdict": "counter", "text": str(prop["body"]), "why": str(pv["why"])}
	shift_trust(id, -1.0, "rechaza una propuesta del presidente")
	_close(prop, "rejected", "%s rechaza (%s)." % [m.party_short(id), str(pv["why"])])
	return {"ok": true, "verdict": "reject", "text": "%s rechaza la propuesta: %s." % [m.party_short(id), str(pv["why"])], "why": str(pv["why"])}

# ---------------------------------------------------------------- trimestre
## Se ejecuta cada trimestre tras actualizar satisfacción de socios (GovernmentSim._update_partners).
func quarterly() -> void:
	if m.phase != "legislature":
		return
	ensure()
	var s := st()
	# Acuerdos puntuales que caducan.
	for id in party_ids():
		var info: Dictionary = (s["parties"] as Dictionary)[id]
		if str(info.get("modality", "")) == "puntual" and int(info.get("expires", 0)) > 0 and m.turn() >= int(info["expires"]):
			_expire_puntual(str(id))
	# Factores de confianza ligados a resultados y a la gestión de sus ministros.
	var app := m.gov.approval()
	for id in party_ids():
		var pid := str(id)
		if m.is_player(pid):
			continue
		if app >= 55.0:
			shift_trust(pid, 1.0, "buenos resultados del Gobierno")
		elif app < 40.0:
			shift_trust(pid, -2.0, "el Gobierno pierde apoyo social")
		var acts: Array = []
		for e in m.gov.cabinet():
			var ed: Dictionary = e
			if str(ed.get("party", "")) == pid and ed.has("minister"):
				acts.append(float((ed["minister"] as Dictionary).get("act", 55.0)))
		if not acts.is_empty():
			var avg := 0.0
			for a in acts:
				avg += float(a)
			avg /= float(acts.size())
			if avg >= 62.0:
				shift_trust(pid, 1.5, "sus ministros rinden bien")
			elif avg < 35.0:
				shift_trust(pid, -1.5, "sus ministros rinden mal")
	# Propuestas sin respuesta: caducan y cuestan.
	for p in proposals():
		var pd: Dictionary = p
		if str(pd.get("state", "")) in ["open", "countered"] and m.turn() > int(pd.get("due_turn", 0)):
			var who := str(pd.get("author", ""))
			_close(pd, "expired", "Sin respuesta a tiempo.")
			if str(pd.get("kind", "")) == "party_ask" and who != "":
				shift_trust(who, -4.0, "su petición queda sin respuesta")
				add_cause(who, "Su petición «%s» no recibió respuesta." % str(pd.get("title", "")))
			elif str(pd.get("minister_party", "")) not in ["", gov_id()]:
				shift_trust(str(pd["minister_party"]), -2.0, "su propuesta ministerial queda sin respuesta")
	# Revisión periódica del acuerdo.
	if int(s.get("review_turn", 0)) > 0 and m.turn() >= int(s["review_turn"]):
		s["review_turn"] = m.turn() + 4
		_log("Revisión del acuerdo de coalición: %d socios, confianza media %.0f." % [party_ids().size(), _avg_trust()])
	# Escalera de crisis.
	for id in party_ids():
		var pid2 := str(id)
		if m.is_player(pid2) or modality(pid2) == "puntual":
			continue
		var c := crisis(pid2)
		if int(c["phase"]) == 5:
			# Ultimátum vigente: si el plazo vence sin cumplirse, el socio rompe.
			if m.turn() >= int(c.get("deadline", 0)) and trust(pid2) < 40.0:
				rupture(pid2, "Vence el plazo de su ultimátum sin que se cumpla su condición.")
				continue
		_update_phase(pid2)
	# Peticiones nuevas de los socios.
	_gen_asks()

func _avg_trust() -> float:
	var ids := party_ids()
	if ids.is_empty():
		return 0.0
	var t := 0.0
	for id in ids:
		t += trust(str(id))
	return t / float(ids.size())

func _expire_puntual(id: String) -> void:
	(st()["parties"] as Dictionary).erase(id)
	m.gov.partners().erase(id)
	m.d("partner_satisfaction").erase(id)
	(st()["crises"] as Dictionary).erase(id)
	var offer: Dictionary = m.gov.offers().get(id, {})
	if not offer.is_empty():
		offer["status"] = "rejected"
	m.publish("Termina el acuerdo puntual con %s" % m.party_short(id), "El apoyo limitado de %s a la investidura y al paquete pactado ha concluido. Habrá que renegociar sus votos para cada iniciativa." % m.party_short(id), "GOBIERNO", "warning")
	_log("Caduca el acuerdo puntual con %s." % m.party_short(id), id)

func _gen_asks() -> void:
	var cool: Dictionary = st()["cool"]
	var ids: Array = party_ids().duplicate()
	ids.shuffle()
	var made := 0
	for id in ids:
		if made >= 2 or open_list().size() >= 10:
			break
		var pid := str(id)
		if m.is_player(pid) or modality(pid) == "puntual" or phase(pid) >= 5:
			continue
		var open_n := 0
		for p in open_list():
			var pd: Dictionary = p
			if str(pd.get("author", "")) == pid and str(pd.get("kind", "")) == "party_ask":
				open_n += 1
		if open_n >= MAX_OPEN_PER_PARTY:
			continue
		if m.turn() - int(cool.get(pid, -9)) < 2:
			continue
		# Piden más cuanto menos confían: quien está a gusto no necesita exigir.
		var urge := clampf((78.0 - trust(pid)) / 80.0, 0.06, 0.7)
		if m.rng.randf() > urge:
			continue
		var cat := ask_catalog(pid)
		if cat.is_empty():
			continue
		cool[pid] = m.turn()
		made += 1
		var ask: Dictionary = cat[0]
		submit({"kind": "party_ask", "origin": "party", "author": pid, "decider": gov_id(), "scope": str(ask["scope"]), "title": "%s pide: %s" % [m.party_short(pid), str(ask["title"])],
			"body": str(ask["body"]), "ask": ask, "cost": ask["cost"], "impact": ask["impact"], "risk": "si lo rechazas cae la confianza y el socio puede endurecerse"})

# ---------------------------------------------------------------- compromisos y peticiones del jugador socio
## Prorroga un compromiso pendiente tres meses (una vez) a cambio de un poco de capital político y de confianza.
func extend_commitment(index: int) -> Dictionary:
	var list := m.a("commitments")
	if index < 0 or index >= list.size():
		return {"ok": false, "error": "Compromiso inexistente."}
	var com: Dictionary = list[index]
	if bool(com.get("fulfilled", false)):
		return {"ok": false, "error": "Ya está cumplido."}
	if bool(com.get("extended", false)):
		return {"ok": false, "error": "Ya se prorrogó una vez."}
	if gov_id() != m.pid():
		return {"ok": false, "error": "Solo el presidente renegocia plazos."}
	var err := _pay(1.0)
	if err != "":
		return {"ok": false, "error": err}
	var who := str(com.get("party", ""))
	com["due"] = int(com.get("due", 8)) + 3
	com["extended"] = true
	com["overdue_flagged"] = false
	shift_trust(who, -1.0, "se prorroga un compromiso pendiente")
	_log("Prórroga de un compromiso con %s: %s." % [m.party_short(who), str(com.get("text", ""))], who)
	return {"ok": true, "text": "Compromiso con %s prorrogado tres meses." % m.party_short(who)}

## Como socio (jugador), pides algo concreto al presidente (IA). Responde según confianza, afinidad y coste, y lo explica.
func partner_ask(index: int) -> Dictionary:
	var me := m.pid()
	if gov_id() == me or not party_ids().has(me):
		return {"ok": false, "error": "Solo un socio del Gobierno puede presentar peticiones."}
	var cat := ask_catalog(me)
	if index < 0 or index >= cat.size():
		return {"ok": false, "error": "Petición no válida."}
	var cool: Dictionary = st()["cool"]
	if m.turn() - int(cool.get(me, -9)) < 1:
		return {"ok": false, "error": "Ya has presentado una petición este trimestre."}
	cool[me] = m.turn()
	var ask: Dictionary = cat[index]
	var gid := gov_id()
	var funds := float((ask.get("cost", {}) as Dictionary).get("funds", 0.0))
	var s := 0.30 + (trust(me) - 50.0) / 100.0 * 0.5 + m.ai.affinity(gid, me) * 0.25 + m.brain.trait_of(gid, "pragmatism") * 0.15 - 0.04 * float(phase(me))
	var why: Array = ["confianza %d" % int(trust(me)), "afinidad %d %%" % int(m.ai.affinity(gid, me) * 100.0)]
	if funds > 2.0:
		s -= 0.10
		why.append("el coste fiscal le preocupa")
	var seq := int(st().get("seq", 0)) + 1
	st()["seq"] = seq
	var prop := {"id": seq, "kind": "party_ask", "origin": "player", "author": me, "decider": gid, "scope": str(ask["scope"]), "title": "Tu petición: %s" % str(ask["title"]),
		"body": str(ask["body"]), "ask": ask, "cost": ask["cost"], "created_turn": m.turn(), "due_turn": m.turn() + 1}
	proposals().append(prop)
	if s >= 0.5:
		var res := _apply_ask(me, ask, false)
		_close(prop, "accepted" if bool(res.get("ok", false)) else "rejected", "El presidente acepta (%s)." % ", ".join(why))
		note(me, "El presidente acepta: %s." % ", ".join(why))
		return {"ok": bool(res.get("ok", false)), "verdict": "accept", "text": "El Gobierno acepta: %s" % str(res.get("text", "")), "error": str(res.get("error", "")), "why": ", ".join(why)}
	if s >= 0.35:
		var res2 := _apply_ask(me, ask, true)
		_close(prop, "accepted" if bool(res2.get("ok", false)) else "rejected", "El presidente acepta una versión reducida (%s)." % ", ".join(why))
		return {"ok": bool(res2.get("ok", false)), "verdict": "counter", "text": "El presidente ofrece una versión reducida: %s" % str(res2.get("text", "")), "error": str(res2.get("error", "")), "why": ", ".join(why)}
	shift_trust(me, -2.0, "el presidente rechaza su petición")
	_close(prop, "rejected", "El presidente rechaza (%s)." % ", ".join(why))
	return {"ok": true, "verdict": "reject", "text": "El presidente rechaza tu petición: %s." % ", ".join(why), "why": ", ".join(why)}
