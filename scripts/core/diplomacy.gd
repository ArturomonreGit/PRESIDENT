class_name Diplomacy
extends RefCounted
## Reuniones bilaterales con los partidos y pactos resultantes (investidura, coalición, candidaturas
## conjuntas, votar leyes juntos, estabilidad y cordones). La IA responde con el cerebro del partido.

var m: GameModel
var dyn: TableDynamics

const MAX_ROUNDS := 5
const MAX_MEETINGS_PER_PERIOD := 3

const TOPICS := {
	"investiture": {"name": "Apoyo a mi investidura", "desc": "Pides su voto para investirte presidente."},
	"partner": {"name": "Condiciones por mi voto", "desc": "Ofreces tu voto al candidato a cambio de carteras y medidas."},
	"joint_list": {"name": "Candidatura conjunta", "desc": "Presentaros juntos a las próximas elecciones."},
	"pre_pact": {"name": "Pacto postelectoral", "desc": "Atar ahora el apoyo mutuo para después de las elecciones."},
	"bills": {"name": "Votar leyes juntos", "desc": "Cerrar apoyo mutuo en iniciativas concretas."},
	"stability": {"name": "Pacto de estabilidad", "desc": "Asegurar la mayoría durante la legislatura."},
	"law_deal": {"name": "Pacto por una ley", "desc": "Pide su voto a una ley concreta tuya y negocia los cambios que exigen a cambio."},
	"relationship": {"name": "Conversación política", "desc": "Mejorar la relación y sondear intenciones."},
}

func _init(model: GameModel) -> void:
	m = model
	dyn = TableDynamics.new(model)

# ---------------------------------------------------------------- estado
func current() -> Dictionary:
	return m.d("meeting")

func active() -> bool:
	return not current().is_empty() and str(current().get("status", "")) == "open"

func pacts() -> Array:
	return m.a("pacts")

func active_pacts(party_id: String = "") -> Array:
	var out: Array = []
	for p in pacts():
		var d: Dictionary = p
		if str(d.get("status", "")) == "active" and (party_id == "" or str(d.get("party", "")) == party_id):
			out.append(d)
	return out

func period_key() -> String:
	match m.phase:
		"campaign": return "c%d_%d" % [m.cycle, m.day]
		"investiture": return "i%d_%d_%d" % [m.cycle, m.gov.round_number(), m.gov.attempts()]
		"legislature", "cabinet_design": return "g%d_%d" % [m.cycle, m.gov_month]
	return "x%d_%s" % [m.cycle, m.phase]

func _meet_log() -> Dictionary:
	var log := m.d("meet_log")
	if str(log.get("key", "")) != period_key():
		log.clear()
		log["key"] = period_key()
		log["with"] = []
	return log

func meetings_left() -> int:
	return MAX_MEETINGS_PER_PERIOD - (_meet_log()["with"] as Array).size()

func period_name() -> String:
	return "día" if m.phase == "campaign" else ("ronda" if m.phase == "investiture" else "mes")

func can_meet(id: String, invited: bool = false) -> Dictionary:
	if m.is_player(id) or m.seats_of(id) <= 0 and m.phase != "campaign":
		return {"ok": false, "reason": "Este grupo no tiene representación."}
	if invited:
		return {"ok": true, "reason": ""}
	if (_meet_log()["with"] as Array).has(id):
		return {"ok": false, "reason": "Ya habéis abierto una mesa esta %s." % period_name() if period_name() != "día" else "Ya habéis abierto una mesa hoy."}
	if meetings_left() <= 0:
		return {"ok": false, "reason": "Has agotado las reuniones de este periodo."}
	return {"ok": true, "reason": ""}

## Compromiso vigente de no pactar con `id` (por un pacto anterior). "" si no hay ninguno.
func cordon_block(id: String) -> String:
	for p in active_pacts():
		var d: Dictionary = p
		for t in d.get("terms", []):
			var td: Dictionary = t
			if str(td.get("k", "")) == "cordon" and str(td.get("by", "")) == "player" and str(td.get("target", "")) == id:
				return "Te comprometiste con %s a no pactar con %s mientras dure vuestro acuerdo." % [m.party_short(str(d["party"])), m.party_short(id)]
	return ""

## Leyes del jugador sobre las que se puede pedir apoyo: borradores y registradas pendientes de Pleno.
func deal_laws() -> Array:
	var out: Array = []
	for l in m.laws.queue():
		var d: Dictionary = l
		if str(d.get("proposer", "")) == m.pid() and (d["changes"] as Dictionary).size() > 0:
			out.append(d)
	for dr in m.laws.drafts():
		var dd: Dictionary = dr
		if (dd["changes"] as Dictionary).size() > 0:
			out.append(dd)
	return out

## Temas disponibles con un partido según la fase.
func topics_for(id: String) -> Array:
	var out: Array = []
	match m.phase:
		"campaign":
			out = ["joint_list", "pre_pact", "relationship"]
		"investiture":
			var cand := m.gov.candidate_id()
			if m.is_player(cand):
				out = ["investiture", "relationship"]
			elif id == cand:
				out = ["partner", "relationship"]
			else:
				out = ["relationship"]
		"cabinet_design", "legislature":
			out = ["bills", "stability", "joint_list", "relationship"]
			if not deal_laws().is_empty() and m.seats_of(id) > 0:
				out.push_front("law_deal")
		"results":
			out = ["relationship"]
	return out

# ---------------------------------------------------------------- términos que se pueden poner sobre la mesa
## Plantillas disponibles para añadir a la mesa. Devuelve {give: [], ask: []}.
func term_menu(id: String, topic: String) -> Dictionary:
	var give: Array = []
	var ask: Array = []
	var cand_is_player := m.phase == "investiture" and m.is_player(m.gov.candidate_id())
	if topic == "investiture" or topic == "pre_pact":
		ask.append({"k": "vote_yes", "by": "ai"})
		ask.append({"k": "vote_abstain", "by": "ai"})
		ask.append({"k": "stability", "by": "ai"})
		give.append({"k": "cabinet", "by": "player", "n": 1})
		give.append({"k": "cabinet", "by": "player", "n": 2})
		for issue in m.brain.top_issues(id, 3):
			give.append(m.brain.policy_term(id, "player", str(issue)))
		give.append({"k": "bills", "by": "player", "n": 2})
	elif topic == "partner":
		give.append({"k": "vote_yes", "by": "player"})
		give.append({"k": "vote_abstain", "by": "player"})
		ask.append({"k": "cabinet", "by": "ai", "n": 1})
		ask.append({"k": "cabinet", "by": "ai", "n": 2})
		for issue in m.brain.top_issues(m.pid(), 3):
			ask.append(m.brain.policy_term(m.pid(), "ai", str(issue)))
	elif topic == "joint_list":
		give.append({"k": "joint_list", "by": "player"})
		for issue in m.brain.top_issues(id, 2):
			give.append(m.brain.policy_term(id, "player", str(issue)))
		give.append({"k": "cabinet", "by": "player", "n": 1})
	elif topic == "bills":
		ask.append({"k": "bills", "by": "ai", "n": 1})
		ask.append({"k": "bills", "by": "ai", "n": 3})
		give.append({"k": "bills", "by": "player", "n": 1})
		for issue in m.brain.top_issues(id, 2):
			give.append(m.brain.policy_term(id, "player", str(issue)))
	elif topic == "law_deal":
		var lid := str(current().get("law", ""))
		var law := m.laws.find(lid)
		if not law.is_empty():
			ask.append({"k": "law_vote", "by": "ai", "law": lid})
			ask.append({"k": "law_abstain", "by": "ai", "law": lid})
			var st: Dictionary = m.laws.stance(law, id)
			for cond in st["conditions"]:
				var cd: Dictionary = cond
				give.append({"k": "law_amend", "by": "player", "law": lid, "type": str(cd["type"]), "measure": str(cd["measure"]), "value": float(cd["value"]), "text": str(cd["text"])})
			give.append({"k": "owe_vote", "by": "player"})
			give.append({"k": "bills", "by": "player", "n": 1})
			for issue in m.brain.top_issues(id, 2):
				give.append(m.brain.policy_term(id, "player", str(issue)))
			if m.gov.player_in_government():
				give.append({"k": "cabinet", "by": "player", "n": 1})
	elif topic == "stability":
		ask.append({"k": "stability", "by": "ai"})
		give.append({"k": "cabinet", "by": "player", "n": 1})
		for issue in m.brain.top_issues(id, 2):
			give.append(m.brain.policy_term(id, "player", str(issue)))
	if topic in ["investiture", "pre_pact", "stability"] or cand_is_player:
		for p in m.all_parties():
			var oid := str((p as Dictionary).get("id", ""))
			if oid != id and not m.is_player(oid) and m.seats_of(oid) > 0 and m.brain.compat(m.pid(), oid) < 0.3 and m.brain.compat(id, oid) < 0.3:
				ask.append({"k": "cordon", "by": "ai", "target": oid})
				break
	_extend_menu(id, topic, give, ask)
	return {"give": give, "ask": ask}

## Más material para la mesa: medidas sobre cualquier tema, vetos a terceros y cantidades mayores.
func _extend_menu(id: String, topic: String, give: Array, ask: Array) -> void:
	var talks := topic in ["investiture", "pre_pact", "partner", "stability", "bills", "joint_list", "relationship"]
	if talks:
		for issue in m.brain.ISSUE_LEAN.keys():
			var theirs := m.brain.policy_term(id, "player", str(issue))
			if not _menu_has(give, theirs):
				give.append(theirs)
			var mine := m.brain.policy_term(m.pid(), "ai", str(issue))
			if not _menu_has(ask, mine):
				ask.append(mine)
		for kk in ["cabinet", "bills"]:
			for n in [1, 2, 3]:
				var g := {"k": kk, "by": "player", "n": n}
				var a := {"k": kk, "by": "ai", "n": n}
				if topic in ["investiture", "pre_pact", "stability", "joint_list"] and kk == "cabinet" and not _menu_has(give, g):
					give.append(g)
				if topic in ["partner"] and kk == "cabinet" and not _menu_has(ask, a):
					ask.append(a)
				if kk == "bills" and topic in ["bills", "stability", "relationship"]:
					if not _menu_has(give, g):
						give.append(g)
					if not _menu_has(ask, a):
						ask.append(a)
	# Vetos a terceros: pedir que no pacten con alguien o comprometerte tú a no hacerlo.
	var third: Array = []
	for p in m.all_parties():
		var oid := str((p as Dictionary).get("id", ""))
		if oid == id or m.is_player(oid):
			continue
		if m.seats_of(oid) <= 0 and m.poll_of(oid) < 2.0:
			continue
		third.append(oid)
	third.sort_custom(func(x: String, y: String) -> bool: return m.brain.compat(id, x) < m.brain.compat(id, y))
	var shown := 0
	for oid2 in third:
		if shown >= 3:
			break
		var ca := {"k": "cordon", "by": "ai", "target": str(oid2)}
		var cg := {"k": "cordon", "by": "player", "target": str(oid2)}
		if not _menu_has(ask, ca):
			ask.append(ca)
		if m.brain.compat(id, str(oid2)) < 0.45 and not _menu_has(give, cg):
			give.append(cg)
		shown += 1
	_category_menu(id, topic, give, ask)

## Categoría de la mesa (spec §5) a la que pertenece un término.
func category_of(term: Dictionary) -> String:
	var k := str(term.get("k", ""))
	for cat in Rules.TABLE_CATEGORY_ORDER:
		if k in (Rules.TABLE_CATEGORIES[cat]["kinds"] as Array):
			return str(cat)
	return "participacion"

## Material de las categorías nuevas: participación, estructura, carteras concretas, objetivos, territorio, presupuesto,
## parlamento, instituciones y calendario. Cada término es evaluado de verdad por el cerebro del partido.
func _category_menu(id: String, topic: String, give: Array, ask: Array) -> void:
	var gov_topics := topic in ["investiture", "pre_pact", "stability", "joint_list"]
	var talks := topic in ["investiture", "pre_pact", "partner", "stability", "bills", "joint_list", "relationship"]
	if not talks:
		return
	# Participación: la modalidad con la que se compromete el partido.
	if topic in ["investiture", "pre_pact", "stability"]:
		for mode in ["coalition", "external", "puntual", "abstention"]:
			_menu_add(ask, {"k": "participation", "mode": mode, "by": "ai"})
	if topic in ["investiture", "pre_pact", "stability", "bills", "relationship"]:
		_menu_add(ask, {"k": "parliament", "what": "budget_vote", "by": "ai"})
	# Estructura del Gobierno.
	if gov_topics:
		_menu_add(give, {"k": "structure", "what": "vicepresidency", "by": "player"})
		_menu_add(give, {"k": "structure", "what": "coordination", "by": "player"})
		for n in [10, 14, 18]:
			_menu_add(give, {"k": "structure", "what": "max_ministries", "n": n, "by": "player"})
		for n2 in [12, 16]:
			_menu_add(give, {"k": "structure", "what": "min_ministries", "n": n2, "by": "player"})
	# Carteras concretas: las que más le interesan al partido (las que da, si es el candidato).
	if gov_topics:
		for cid in _portfolio_candidates(id):
			_menu_add(give, {"k": "portfolio", "comp": str(cid), "by": "player"})
	if topic == "partner":
		for cid2 in _portfolio_candidates(m.pid()):
			_menu_add(ask, {"k": "portfolio", "comp": str(cid2), "by": "ai"})
	# Objetivos medibles, presupuesto y territorio.
	for issue in m.brain.top_issues(id, 3):
		for lv in [1, 2, 3]:
			_menu_add(give, m.brain.objective_term(str(issue), lv))
		for n3 in [1, 2, 3]:
			_menu_add(give, {"k": "budget", "issue": str(issue), "n": n3, "by": "player"})
	for what in m.brain.TERRITORY_WHAT.keys():
		for n4 in [1, 2, 3]:
			_menu_add(give, {"k": "territory", "what": str(what), "n": n4, "by": "player"})
	# Parlamento, instituciones y calendario.
	for pw in ["commission", "agenda", "ponencia"]:
		_menu_add(give, {"k": "parliament", "what": pw, "by": "player"})
	for n5 in [1, 2]:
		_menu_add(give, {"k": "institution", "what": "appointment", "n": n5, "by": "player"})
	_menu_add(give, {"k": "institution", "what": "reform", "by": "player"})
	for mo in [6, 12]:
		_menu_add(give, {"k": "calendar", "what": "review", "n": mo, "by": "player"})
	_menu_add(give, {"k": "calendar", "what": "deadline", "n": 12, "by": "player"})
	_menu_add(give, {"k": "calendar", "what": "resolution", "by": "player"})

func _menu_add(list: Array, term: Dictionary) -> void:
	if not _menu_has(list, term):
		list.append(term)

## Competencias de gobierno que más le interesan al partido (hasta cinco).
func _portfolio_candidates(id: String) -> Array:
	var scored: Array = []
	for c in Competencies.catalog():
		var cd: Dictionary = c
		var area := str(cd.get("area", ""))
		var fit := m.brain.salience(id, str(m.brain.AREA_ISSUE[area])) if m.brain.AREA_ISSUE.has(area) else 0.2
		scored.append({"id": str(cd["id"]), "s": fit + (0.05 if bool(cd.get("essential", false)) else 0.0)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	var out: Array = []
	for e in scored.slice(0, 5):
		out.append(str((e as Dictionary)["id"]))
	return out

func _menu_has(list: Array, term: Dictionary) -> bool:
	for t in list:
		var d: Dictionary = t
		if str(d.get("k", "")) != str(term.get("k", "")) or str(d.get("by", "")) != str(term.get("by", "")):
			continue
		match str(term.get("k", "")):
			"participation":
				if str(d.get("mode", "")) == str(term.get("mode", "")):
					return true
			"structure", "territory", "institution", "calendar", "parliament":
				if str(d.get("what", "")) == str(term.get("what", "")) and int(d.get("n", 0)) == int(term.get("n", 0)):
					return true
			"objective":
				if str(d.get("issue", "")) == str(term.get("issue", "")) and int(d.get("level", 1)) == int(term.get("level", 1)):
					return true
			"budget":
				if str(d.get("issue", "")) == str(term.get("issue", "")) and int(d.get("n", 1)) == int(term.get("n", 1)):
					return true
			"portfolio":
				if str(d.get("comp", "")) == str(term.get("comp", "")):
					return true
			"policy":
				if str(d.get("issue", "")) == str(term.get("issue", "")):
					return true
			"cordon":
				if str(d.get("target", "")) == str(term.get("target", "")):
					return true
			"cabinet", "bills":
				if int(d.get("n", 1)) == int(term.get("n", 1)):
					return true
			_:
				return true
	return false

func default_table(id: String, topic: String) -> Array:
	match topic:
		"investiture": return [{"k": "vote_yes", "by": "ai"}]
		"pre_pact": return [{"k": "vote_yes", "by": "ai"}]
		"partner": return [{"k": "vote_yes", "by": "player"}]
		"joint_list": return [{"k": "joint_list", "by": "player"}]
		"bills": return [{"k": "bills", "by": "ai", "n": 1}]
		"stability": return [{"k": "stability", "by": "ai"}]
	return []

# ---------------------------------------------------------------- contexto de valoración
func _need_votes() -> int:
	var cand := m.gov.candidate_id()
	var have := m.seats_of(cand)
	for id in m.gov.partners():
		if str(id) != cand:
			have += m.seats_of(str(id))
	return maxi(1, Rules.MAJORITY - have)

func context_for(mt: Dictionary) -> Dictionary:
	var id := str(mt.get("with", ""))
	var ctx := {"rapport": float(mt.get("rapport", 0.0)), "pressure": float(mt.get("pressure", 0.0))}
	var pivot := 0.4
	var player_pivot := 0.4
	if m.phase == "investiture":
		var need := float(_need_votes())
		player_pivot = clampf(float(m.seats_of(m.pid())) / need, 0.0, 1.0)
		if id == m.gov.candidate_id() and not m.is_player(id):
			pivot = 0.2
		else:
			pivot = clampf(float(m.seats_of(id)) / need, 0.0, 1.0)
	elif m.phase == "legislature":
		pivot = clampf(float(m.seats_of(id)) / 40.0, 0.1, 0.9)
	ctx["pivot"] = pivot
	ctx["player_pivot"] = player_pivot
	# Poder negociador y estrategia preferida del interlocutor (spec negociación §4.2-4.3).
	if id != "" and not m.is_player(id):
		var pw := m.brain.negotiating_power(id)
		ctx["power"] = float(pw["total"])
		ctx["modality"] = m.brain.preferred_modality(id, "", float(pw["total"]))
	ctx["hard"] = dyn.hardness(mt) if mt.has("round") else 0.0
	ctx["enforce_must"] = str(mt.get("topic", "")) in ["investiture", "pre_pact", "stability"] and not m.is_player(id)
	return ctx

func evaluate(mt: Dictionary = {}) -> Dictionary:
	if mt.is_empty():
		mt = current()
	var ai_id := str(mt.get("with", ""))
	# Si el jugador es quien recibe (candidato de la IA) el "otro" es el jugador igualmente.
	return m.brain.assess(ai_id, m.pid(), mt.get("table", []), context_for(mt))

## Lectura aproximada que ve el jugador (con ruido hasta que sondea a su interlocutor).
func read_the_room(mt: Dictionary = {}) -> Dictionary:
	if mt.is_empty():
		mt = current()
	var res := evaluate(mt)
	var bias := 0.0 if bool(mt.get("sounded", false)) else float(mt.get("misread", 0.0))
	var u := float(res["utility"]) + bias
	var need := float(res["need"])
	var ratio := clampf(0.5 + (u - need) / 0.6, 0.0, 1.0)
	var label := "En contra"
	var tone := "bad"
	if str(res["verdict"]) == "veto":
		label = "Veto político"
		ratio = 0.0
	elif not (res.get("must_missing", []) as Array).is_empty():
		label = "Falta su línea roja"
		ratio = minf(ratio, 0.35)
	elif u >= need:
		label = "Dispuesto a firmar"
		tone = "good"
	elif u >= need - 0.24:
		label = "Dudoso"
		tone = "warn"
	return {"ratio": ratio, "label": label, "tone": tone, "exact": res}

# ---------------------------------------------------------------- reuniones
func open(id: String, topic: String, extra: Dictionary = {}) -> Dictionary:
	var invited := bool(extra.get("invited", false))
	var chk := can_meet(id, invited)
	if not bool(chk["ok"]):
		return {"ok": false, "error": str(chk["reason"])}
	if not topics_for(id).has(topic):
		return {"ok": false, "error": "Este tema no se puede tratar ahora."}
	var blocked_pact := cordon_block(id) if topic != "relationship" else ""
	if blocked_pact != "":
		return {"ok": false, "error": blocked_pact}
	if topic == "law_deal" and m.laws.find(str(extra.get("law", ""))).is_empty():
		return {"ok": false, "error": "Elige primero la ley sobre la que quieres negociar."}
	var ideo := m.brain.topic_gate(id, topic) if topic in ["joint_list", "partner", "stability"] else ""
	if ideo != "":
		return {"ok": false, "error": "%s: %s." % [m.party_short(id), ideo]}
	if not invited:
		var log := _meet_log()
		(log["with"] as Array).append(id)
	var mt := {
		"with": id, "topic": topic, "status": "open", "round": 0, "patience": 3, "rapport": 0.0, "pressure": 0.0,
		"misread": m.rng.randf_range(-0.09, 0.09), "sounded": false, "appealed": false, "pushed": false,
		"table": default_table(id, topic), "log": [], "result": "", "period": period_key(),
		"origin": "ai" if invited else "player", "events": [], "stall": 0, "rival_bonus": 0.0, "mood": 0.0
	}
	if topic == "law_deal":
		mt["law"] = str(extra.get("law", ""))
		mt["table"] = [{"k": "law_vote", "by": "ai", "law": str(extra.get("law", ""))}]
	var ch := m.character()
	mt["rapport"] = Leader.edge(ch, "experiencia") * 4.0
	mt["patience"] = 3 + (1 if Leader.edge(ch, "mano_izquierda") >= 0.4 else 0) - (1 if Leader.edge(ch, "mano_izquierda") <= -0.6 else 0)
	# Quien tiene alternativas de Gobierno se levanta antes de la mesa; quien las necesita aguanta más (spec §4.3).
	var alt := m.brain.alternatives_of(id)
	if alt >= 0.55 and topic in ["investiture", "pre_pact", "stability", "partner"]:
		mt["patience"] = maxi(2, int(mt["patience"]) - 1)
		mt["has_alternatives"] = true
	elif alt <= 0.2 and m.brain.decisive_share(id) < 0.5:
		mt["patience"] = int(mt["patience"]) + 1
	var said: Dictionary = m.enc.said_about(id)
	if not said.is_empty():
		mt["rapport"] = float(mt["rapport"]) + (-6.0 if str(said["what"]) == "attack" else 4.0)
		mt["said"] = str(said["what"])
	m.s["meeting"] = mt
	if bool(extra.get("agenda", false)):
		for at in dyn.agenda_for(id, topic, mt):
			add_term(at as Dictionary)
		mt["agenda"] = true
	if bool(extra.get("agenda", false)):
		record_version("ai", "Su propuesta de apertura")
	var opener := _opening(id, topic, mt)
	_say(mt, "ai", opener, "neutral")
	if bool(mt.get("agenda", false)):
		_say(mt, "ai", _their_pitch(mt["table"]), "neutral")
	return {"ok": true}

func _say(mt: Dictionary, who: String, text: String, tone: String) -> void:
	(mt["log"] as Array).append({"who": who, "text": text, "tone": tone})

func add_term(term: Dictionary) -> void:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return
	var table: Array = mt["table"]
	# No se duplican términos idénticos; los de cantidad se sustituyen.
	for i in range(table.size()):
		var t: Dictionary = table[i]
		if str(t.get("k", "")) == str(term.get("k", "")) and str(t.get("by", "")) == str(term.get("by", "")):
			if str(term.get("k", "")) in ["cabinet", "bills"]:
				table[i] = term.duplicate(true)
				return
			if str(term.get("k", "")) in ["policy"] and str(t.get("issue", "")) == str(term.get("issue", "")):
				return
			if str(term.get("k", "")) in ["vote_yes", "vote_abstain", "joint_list", "stability", "law_vote", "law_abstain", "owe_vote"]:
				return
			if str(term.get("k", "")) == "law_amend" and str(t.get("measure", "")) == str(term.get("measure", "")):
				return
			if str(term.get("k", "")) == "cordon" and str(t.get("target", "")) == str(term.get("target", "")):
				return
			match str(term.get("k", "")):
				"participation":
					table[i] = term.duplicate(true)
					return
				"structure", "territory", "institution", "calendar", "parliament":
					if str(t.get("what", "")) == str(term.get("what", "")):
						if str(term.get("k", "")) == "parliament":
							return
						table[i] = term.duplicate(true)
						return
				"objective", "budget":
					if str(t.get("issue", "")) == str(term.get("issue", "")):
						table[i] = term.duplicate(true)
						return
				"portfolio":
					if str(t.get("comp", "")) == str(term.get("comp", "")):
						return
	# Sí o abstención son excluyentes entre sí para el mismo que vota.
	for i in range(table.size() - 1, -1, -1):
		var t2: Dictionary = table[i]
		if str(t2.get("by", "")) == str(term.get("by", "")) and ((str(t2.get("k", "")) in ["vote_yes", "vote_abstain"] and str(term.get("k", "")) in ["vote_yes", "vote_abstain"]) or (str(t2.get("k", "")) in ["law_vote", "law_abstain"] and str(term.get("k", "")) in ["law_vote", "law_abstain"])):
			table.remove_at(i)
	table.append(term.duplicate(true))

func remove_term(index: int) -> void:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return
	var table: Array = mt["table"]
	if index >= 0 and index < table.size():
		table.remove_at(index)

func has_term(k: String, by: String, issue: String = "") -> bool:
	for t in current().get("table", []):
		var d: Dictionary = t
		if str(d.get("k", "")) == k and str(d.get("by", "")) == by and (issue == "" or str(d.get("issue", "")) == issue):
			return true
	return false

## El jugador sondea a su interlocutor: revela prioridades, líneas rojas y la lectura exacta.
func sound() -> String:
	var mt := current()
	if mt.is_empty() or bool(mt.get("sounded", false)):
		return ""
	var id := str(mt["with"])
	m.d("known_red_lines")[id] = true
	mt["sounded"] = true
	mt["rapport"] = float(mt["rapport"]) + 5.0
	var issues: Array = []
	for i in m.brain.top_issues(id, 2):
		issues.append(Rules.issue_name(str(i)).to_lower())
	var text := "Nuestras prioridades son %s. %s" % [" y ".join(issues), m.brain.goal(id) + "."]
	var rls := m.brain.red_lines(id)
	if not rls.is_empty():
		text += " Y le diré con franqueza que %s." % str((rls[0] as Dictionary)["text"]).to_lower()
	_say(mt, "ai", text, "neutral")
	return "Sondeo realizado."

func appeal() -> String:
	var mt := current()
	if mt.is_empty() or bool(mt.get("appealed", false)) or str(mt.get("status", "")) != "open":
		return ""
	mt["appealed"] = true
	var id := str(mt["with"])
	var c := m.brain.compat(id, m.pid())
	var short := m.party_short(id)
	if c >= 0.45:
		mt["rapport"] = float(mt["rapport"]) + 10.0 + 14.0 * c + 4.0 * Leader.edge(m.character(), "mano_izquierda")
		_say(mt, "player", "Tenemos más en común de lo que se dice. Hablemos de lo que nos une.", "neutral")
		_say(mt, "ai", "Es cierto que en varios puntos coincidimos. Eso ayuda a sentarse con otro ánimo.", "good")
		return "Apelas a vuestras coincidencias: mejora el ambiente."
	mt["rapport"] = float(mt["rapport"]) - 4.0
	_say(mt, "player", "Más allá de las diferencias, creo que podemos entendernos.", "neutral")
	_say(mt, "ai", "Hay mucha distancia entre %s y su partido. Las buenas palabras no la cierran." % short, "bad")
	return "%s no se deja convencer: la distancia ideológica es grande." % short

func pressure() -> String:
	var mt := current()
	if mt.is_empty() or bool(mt.get("pushed", false)) or str(mt.get("status", "")) != "open":
		return ""
	mt["pushed"] = true
	var id := str(mt["with"])
	var chance := 0.30 + 0.18 * Leader.edge(m.character(), "firmeza") + 0.35 * float(context_for(mt)["pivot"] if m.phase != "investiture" else (1.0 - float(context_for(mt)["pivot"]))) + 0.25 * (1.0 - m.brain.trait_of(id, "rigidity"))
	_say(mt, "player", "Tengo otras opciones sobre la mesa. Si no hay acuerdo hoy, buscaré otros socios.", "warn")
	if m.rng.randf() < chance:
		mt["pressure"] = float(mt["pressure"]) + 0.10
		mt["rapport"] = float(mt["rapport"]) - 6.0
		_say(mt, "ai", "No me gusta que me apremien, pero entiendo la situación. Veamos qué se puede hacer.", "warn")
		return "La presión surte efecto (a costa del ambiente)."
	mt["rapport"] = float(mt["rapport"]) - 14.0
	mt["patience"] = int(mt["patience"]) - 1
	m.ai.change_relation(id, -4.0)
	_say(mt, "ai", "Las amenazas no son la mejor forma de empezar. Quizá debería buscar esos otros socios.", "bad")
	return "La presión sale mal: se resiente la relación."

# ---------------------------------------------------------------- herramientas de la mesa (spec negociación §5)
## Clave estable de un término para compararlo entre versiones.
func term_key(t: Dictionary) -> String:
	var extra = t.get("issue", t.get("target", t.get("comp", t.get("what", t.get("mode", t.get("law", t.get("measure", "")))))))
	return "%s|%s|%s" % [t.get("k", ""), t.get("by", ""), extra]

func _term_amount(t: Dictionary) -> String:
	return "%s/%s/%s/%s" % [t.get("n", ""), t.get("level", ""), t.get("mode", ""), t.get("to", t.get("value", ""))]

## Cambia campos de un término (cantidad, nivel…) sin retirarlo de la mesa.
func modify_term(index: int, changes: Dictionary) -> bool:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return false
	var table: Array = mt["table"]
	if index < 0 or index >= table.size():
		return false
	var t: Dictionary = table[index]
	for k in changes.keys():
		t[k] = changes[k]
	t["edited"] = true
	return true

## Sustituye un término por otro (p. ej. una cartera por otra).
func replace_term(index: int, new_term: Dictionary) -> bool:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return false
	var table: Array = mt["table"]
	if index < 0 or index >= table.size():
		return false
	var old: Dictionary = table[index]
	var nt := new_term.duplicate(true)
	nt["replaced"] = m.brain.term_text(old)
	table[index] = nt
	_say(mt, "player", "Os propongo cambiar «%s» por «%s»." % [m.brain.term_text(old), m.brain.term_text(nt)], "neutral")
	return true

## Ofrece una política alternativa a cambio de retirar una exigencia suya.
func offer_alternative(index: int, alt: Dictionary) -> bool:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return false
	var table: Array = mt["table"]
	if index < 0 or index >= table.size():
		return false
	var old: Dictionary = table[index]
	var nt := alt.duplicate(true)
	nt["by"] = str(old.get("by", "player"))
	nt["alt_for"] = m.brain.term_text(old)
	table[index] = nt
	_say(mt, "player", "En lugar de «%s», os ofrezco «%s»." % [m.brain.term_text(old), m.brain.term_text(nt)], "neutral")
	return true

## ¿Se puede aceptar solo una parte de este término? (tiene cantidad o nivel que reducir)
func can_split(t: Dictionary) -> bool:
	var k := str(t.get("k", ""))
	if int(t.get("n", 0)) > 1 and k in ["cabinet", "bills", "territory", "budget", "institution"]:
		return true
	if int(t.get("level", 0)) > 1:
		return true
	return k == "structure" and str(t.get("what", "")) == "max_ministries" and int(t.get("n", 0)) > 10

## Se acepta solo una parte de una exigencia: baja una unidad su cantidad o nivel. Devuelve false si no se puede fraccionar.
func accept_partially(index: int) -> bool:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return false
	var table: Array = mt["table"]
	if index < 0 or index >= table.size():
		return false
	var t: Dictionary = table[index]
	if not can_split(t):
		return false
	if int(t.get("level", 0)) > 1:
		t["level"] = int(t["level"]) - 1
	elif str(t.get("k", "")) == "structure":
		t["n"] = int(t["n"]) - 4
	else:
		t["n"] = int(t["n"]) - 1
	t["partial"] = true
	_say(mt, "player", "Acepto solo una parte: %s." % m.brain.term_text(t), "neutral")
	return true

## Estado de cada término según lo que el jugador sabe de la postura del otro lado:
## must (imprescindible), negotiable, rejected, unknown (sin sondear) o agreed.
func term_statuses(mt: Dictionary = {}) -> Array:
	if mt.is_empty():
		mt = current()
	var id := str(mt.get("with", ""))
	var table: Array = mt.get("table", [])
	var out: Array = []
	var sounded := bool(mt.get("sounded", false))
	var known := sounded or int(mt.get("round", 0)) > 0
	var rejected_keys: Array = mt.get("rejected_keys", [])
	var must_keys: Array = []
	if sounded or bool(mt.get("must_known", false)):
		for mt0 in m.brain.must_terms(id):
			must_keys.append(term_key(mt0 as Dictionary))
	var ctx := context_for(mt)
	for t in table:
		var td: Dictionary = t
		var key := term_key(td)
		var st := "unknown"
		var why := ""
		var block := m.brain.term_block(id, m.pid(), td)
		if str(mt.get("status", "")) == "agreed":
			st = "agreed"
		elif rejected_keys.has(key):
			st = "rejected"
			why = "Ya la han rechazado en esta mesa"
		elif block != "" and known:
			st = "rejected"
			why = block
		elif key in must_keys or bool(td.get("ultimatum", false)):
			st = "must"
			why = "Es una de sus exigencias de fondo"
		elif known:
			st = "negotiable"
			var v := float(m.brain.term_value(id, m.pid(), td, ctx)["v"])
			why = "Se puede negociar" if v > -0.35 else "Les resulta muy costosa"
		out.append({"status": st, "why": why, "key": key})
	return out

## Cuenta de términos por estado, para el resumen de la mesa.
func status_counts(mt: Dictionary = {}) -> Dictionary:
	var c := {"must": 0, "negotiable": 0, "rejected": 0, "unknown": 0, "agreed": 0}
	for sd in term_statuses(mt):
		var key := str((sd as Dictionary)["status"])
		c[key] = int(c[key]) + 1
	return c

# ---- borradores y versiones
func drafts() -> Array:
	var mt := current()
	if mt.is_empty():
		return []
	if not mt.has("drafts"):
		mt["drafts"] = []
	return mt["drafts"]

func versions() -> Array:
	var mt := current()
	if mt.is_empty():
		return []
	if not mt.has("versions"):
		mt["versions"] = []
	return mt["versions"]

func save_draft(name: String = "") -> String:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return ""
	var list := drafts()
	if (mt["table"] as Array).is_empty():
		return "No hay nada que guardar: la mesa está vacía."
	if list.size() >= Rules.MAX_DRAFTS:
		return "Ya tienes %d borradores: borra alguno para guardar otro." % Rules.MAX_DRAFTS
	var nm := name.strip_edges()
	mt["draft_seq"] = int(mt.get("draft_seq", 0)) + 1
	if nm == "":
		nm = "Borrador %d" % int(mt["draft_seq"])
	list.append({"name": nm, "table": (mt["table"] as Array).duplicate(true), "round": int(mt.get("round", 0))})
	return "Guardado «%s»." % nm

func load_draft(index: int) -> bool:
	var mt := current()
	var list := drafts()
	if mt.is_empty() or str(mt.get("status", "")) != "open" or index < 0 or index >= list.size():
		return false
	mt["table"] = ((list[index] as Dictionary)["table"] as Array).duplicate(true)
	return true

func delete_draft(index: int) -> void:
	var list := drafts()
	if index >= 0 and index < list.size():
		list.remove_at(index)

## Añade una versión al historial de la mesa (lo presentado y lo que contesta la IA).
func record_version(who: String, label: String, verdict: String = "") -> void:
	var mt := current()
	if mt.is_empty():
		return
	var list := versions()
	mt["version_seq"] = int(mt.get("version_seq", 0)) + 1
	list.append({"n": int(mt["version_seq"]), "who": who, "label": label, "round": int(mt.get("round", 0)), "verdict": verdict, "table": (mt["table"] as Array).duplicate(true)})
	while list.size() > Rules.MAX_VERSIONS:
		list.remove_at(0)

func restore_version(index: int) -> bool:
	var mt := current()
	var list := versions()
	if mt.is_empty() or str(mt.get("status", "")) != "open" or index < 0 or index >= list.size():
		return false
	mt["table"] = ((list[index] as Dictionary)["table"] as Array).duplicate(true)
	return true

## Diferencias entre dos tablas: añadidos, retirados y cambiados (misma condición con otra cantidad).
func compare_tables(a: Array, b: Array) -> Dictionary:
	var ka: Dictionary = {}
	var kb: Dictionary = {}
	for t in a:
		ka[term_key(t as Dictionary)] = t
	for t2 in b:
		kb[term_key(t2 as Dictionary)] = t2
	var added: Array = []
	var removed: Array = []
	var changed: Array = []
	for k in kb.keys():
		if not ka.has(k):
			added.append(kb[k])
		elif _term_amount(ka[k] as Dictionary) != _term_amount(kb[k] as Dictionary):
			changed.append({"before": ka[k], "after": kb[k]})
	for k2 in ka.keys():
		if not kb.has(k2):
			removed.append(ka[k2])
	return {"added": added, "removed": removed, "changed": changed}

func compare_versions(i: int, j: int) -> Dictionary:
	var list := versions()
	if i < 0 or j < 0 or i >= list.size() or j >= list.size():
		return {"added": [], "removed": [], "changed": []}
	return compare_tables((list[i] as Dictionary)["table"], (list[j] as Dictionary)["table"])

## El jugador pide la contraoferta del partido sin presentar formalmente su oferta: cuesta paciencia y no se repite sin límite.
func request_counter() -> Dictionary:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return {"ok": false, "text": ""}
	var id := str(mt["with"])
	var table: Array = mt["table"]
	if int(mt.get("counter_requests", 0)) >= 3:
		_say(mt, "ai", "Ya os he dicho lo que necesito. Presentad una oferta formal.", "warn")
		return {"ok": false, "text": "Ya has pedido tres contraofertas en esta mesa."}
	mt["counter_requests"] = int(mt.get("counter_requests", 0)) + 1
	mt["patience"] = int(mt["patience"]) - 1
	var ctx := context_for(mt)
	var res := m.brain.assess(id, m.pid(), table, ctx)
	_say(mt, "player", "¿Qué necesitaríais para cerrar esto?", "neutral")
	if str(res["verdict"]) == "veto":
		_say(mt, "ai", "%s %s" % [_line(id, "veto", mt), str(res["blocked"]) + "."], "bad")
		return {"ok": true, "text": "veto"}
	if str(res["verdict"]) == "accept" and (res.get("must_missing", []) as Array).is_empty():
		_say(mt, "ai", "Tal como está sobre la mesa, lo firmaría.", "good")
		return {"ok": true, "text": "accept"}
	var cnt := m.brain.counter(id, m.pid(), table, ctx, res)
	for idx in (cnt["remove"] as Array):
		_note_rejected(mt, table, int(idx))
		remove_term(int(idx))
	for md in (cnt.get("mods", []) as Array):
		_apply_mod(table, md as Dictionary)
	for t in (cnt["add"] as Array):
		var tt: Dictionary = (t as Dictionary).duplicate(true)
		tt["from_ai"] = true
		tt["new"] = true
		add_term(tt)
	if not (res.get("must_missing", []) as Array).is_empty():
		mt["must_known"] = true
	_say(mt, "ai", str(cnt["text"]), "warn")
	record_version("ai", "Contraoferta pedida", "counter")
	if int(mt["patience"]) <= 0:
		_say(mt, "ai", "Creo que hemos agotado el tiempo. Lo dejamos aquí.", "bad")
		_conclude(mt, false)
	return {"ok": true, "text": str(cnt["text"])}

## Anota que el partido ha rechazado un término para que la mesa lo muestre como rechazado.
func _note_rejected(mt: Dictionary, table: Array, idx: int) -> void:
	if idx < 0 or idx >= table.size():
		return
	var keys: Array = mt.get("rejected_keys", [])
	var k := term_key(table[idx] as Dictionary)
	if not keys.has(k):
		keys.append(k)
	mt["rejected_keys"] = keys

## Presenta el paquete a la IA. Devuelve {verdict, text}.
func submit() -> Dictionary:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return {"verdict": "closed", "text": ""}
	var id := str(mt["with"])
	var table: Array = mt["table"]
	if table.is_empty():
		_say(mt, "sys", "No hay nada sobre la mesa. Añade condiciones antes de presentar una oferta.", "warn")
		return {"verdict": "empty", "text": ""}
	# Un dilema sin contestar equivale a ignorarlo, y la IA lo nota.
	if mt.has("choice"):
		dyn.resolve_choice(mt, "ignore")
		mt["rival_bonus"] = float(mt.get("rival_bonus", 0.0)) + 0.02
	mt["round"] = int(mt["round"]) + 1
	mt.erase("alert")
	var sig := dyn.signature(table)
	var stalled := sig == str(mt.get("last_sig", ""))
	if stalled:
		mt["stall"] = int(mt.get("stall", 0)) + 1
		mt["patience"] = int(mt["patience"]) - 1
	_say(mt, "player", _summary_text(table), "neutral")
	record_version("player", "Tu oferta (ronda %d)" % int(mt["round"]))
	if stalled:
		_say(mt, "ai", "Me trae lo mismo que antes. Si no se mueve nada, esto no va a ninguna parte.", "warn")
	var ctx := context_for(mt)
	var res := m.brain.assess(id, m.pid(), table, ctx)
	if not (res.get("must_missing", []) as Array).is_empty() or str(res["verdict"]) == "veto":
		mt["must_known"] = true
	var verdict := str(res["verdict"])
	if verdict == "reject" and not (res.get("must_missing", []) as Array).is_empty():
		verdict = "counter"
	# Si lo que presentas es exactamente lo que ellos proponen, lo firman.
	if verdict != "veto" and (res.get("must_missing", []) as Array).is_empty() and sig == dyn.signature(their_proposal(mt)):
		verdict = "accept"
	# Última oferta: lo que no sea aceptarla rompe la mesa.
	if bool(mt.get("final", false)) and verdict != "accept":
		_say(mt, "ai", "Esa era mi última oferta y no la acepta. Lo dejamos aquí.", "bad")
		_conclude(mt, false)
		return {"verdict": "final_reject", "text": ""}
	match verdict:
		"accept":
			_say(mt, "ai", _line(id, "accept", mt), "good")
			_conclude(mt, true)
		"counter":
			var cnt := m.brain.counter(id, m.pid(), table, ctx, res)
			for idx in (cnt["remove"] as Array):
				_note_rejected(mt, table, int(idx))
				remove_term(int(idx))
			for md in (cnt.get("mods", []) as Array):
				_apply_mod(table, md as Dictionary)
			var ultimatum := int(mt["round"]) >= MAX_ROUNDS - 1 or int(mt["patience"]) <= 1
			for t in (cnt["add"] as Array):
				var tt: Dictionary = (t as Dictionary).duplicate(true)
				tt["from_ai"] = true
				if ultimatum:
					tt["ultimatum"] = true
				add_term(tt)
			var prefix := "Esta es mi última oferta. " if ultimatum else ""
			if ultimatum:
				mt["final"] = true
			_say(mt, "ai", "%s%s %s" % [prefix, _line(id, "counter", mt), str(cnt["text"])], "warn")
			mt["rapport"] = float(mt["rapport"]) + 1.5
			record_version("ai", "Su contraoferta", "counter")
		"veto":
			_say(mt, "ai", "%s %s" % [_line(id, "veto", mt), str(res["blocked"]) + "."], "bad")
			mt["patience"] = 0
			_conclude(mt, false)
		_:
			mt["patience"] = int(mt["patience"]) - 1
			_say(mt, "ai", _reject_text(id, res, mt), "bad")
	if str(mt.get("status", "")) == "open":
		if int(mt["patience"]) <= 0 or int(mt["round"]) >= MAX_ROUNDS:
			_say(mt, "ai", "Creo que hemos agotado el tiempo. Lo dejamos aquí.", "bad")
			_conclude(mt, false)
		else:
			dyn.roll_event(mt)
	mt["last_sig"] = dyn.signature(mt["table"])
	return {"verdict": verdict, "text": ""}

func _apply_mod(table: Array, md: Dictionary) -> void:
	var idx := int(md.get("idx", -1))
	if idx < 0 or idx >= table.size():
		return
	var t: Dictionary = table[idx]
	if md.has("set"):
		for k in (md["set"] as Dictionary).keys():
			t[k] = (md["set"] as Dictionary)[k]
	elif md.has("replace"):
		t = (md["replace"] as Dictionary).duplicate(true)
		table[idx] = t
	t["from_ai"] = true
	t["changed"] = true

## Lo que el partido aceptaría firmar ya: su propuesta (apertura, contraofertas y exigencias nuevas) más lo que aporta por defecto.
func their_proposal(mt: Dictionary = {}) -> Array:
	if mt.is_empty():
		mt = current()
	var out: Array = []
	for t in mt.get("table", []):
		if bool((t as Dictionary).get("from_ai", false)):
			out.append((t as Dictionary).duplicate(true))
	for d in default_table(str(mt.get("with", "")), str(mt.get("topic", ""))):
		var has := false
		for o in out:
			if str((o as Dictionary).get("k", "")) == str((d as Dictionary).get("k", "")) and str((o as Dictionary).get("by", "")) == str((d as Dictionary).get("by", "")):
				has = true
		if not has:
			out.append((d as Dictionary).duplicate(true))
	return out

## Firma su propuesta tal cual: acuerdo inmediato (salvo que haya un veto de fondo).
func sign_their_proposal() -> void:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return
	var id := str(mt["with"])
	var pr := their_proposal(mt)
	if pr.is_empty():
		return
	mt["table"] = pr
	mt["round"] = int(mt["round"]) + 1
	mt.erase("alert")
	mt.erase("choice")
	_say(mt, "player", "Acepto su propuesta tal y como me la ha planteado.", "good")
	var res := m.brain.assess(id, m.pid(), pr, context_for(mt))
	if str(res["verdict"]) == "veto":
		_say(mt, "ai", "%s %s" % [_line(id, "veto", mt), str(res["blocked"]) + "."], "bad")
		mt["patience"] = 0
		_conclude(mt, false)
		return
	_say(mt, "ai", _line(id, "accept", mt), "good")
	_conclude(mt, true)

## El jugador resuelve el dilema abierto en la mesa (p. ej. una oferta rival).
func resolve_choice(option_id: String) -> String:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return ""
	return dyn.resolve_choice(mt, option_id)

## Qué se juega en esta mesa (una línea para la cabecera).
func stakes_text(mt: Dictionary) -> String:
	var id := str(mt.get("with", ""))
	var short := m.party_short(id)
	match m.phase:
		"investiture":
			var cand := m.gov.candidate_id()
			if m.is_player(cand):
				return "Te faltan %d escaños para la mayoría absoluta (%d)." % [_need_votes(), Rules.MAJORITY]
			return "%s necesita apoyos y tus %d escaños pueden decidir." % [m.party_short(cand), m.seats_of(m.pid())]
		"campaign":
			return "Quedan %d días de campaña." % maxi(0, Rules.CAMPAIGN_LENGTH_DAYS - m.day)
		_:
			return "Apoyo al Gobierno %.0f · estabilidad de la mayoría %.0f." % [m.gov.approval(), m.gov.stability()]

## Pausa la mesa sin cerrarla: la mesa sigue abierta y se retoma desde la Bandeja o Negociación.
func is_paused() -> bool:
	return bool(current().get("paused", false))

func leave() -> void:
	var mt := current()
	if mt.is_empty() or str(mt.get("status", "")) != "open":
		return
	_say(mt, "player", "Prefiero dejarlo aquí por hoy. Gracias por recibirme.", "neutral")
	if float(mt["rapport"]) >= 10.0:
		m.ai.change_relation(str(mt["with"]), 1.5)
		m.ai.remember({"party": str(mt["with"]), "event": "meeting_good", "topic": str(mt["topic"])})
	mt["status"] = "closed"
	mt["result"] = "Te levantas de la mesa con %s sin acuerdo." % m.party_short(str(mt["with"]))
	dyn.record(mt)

# ---------------------------------------------------------------- cierre y efectos
func _conclude(mt: Dictionary, agreed: bool) -> void:
	var id := str(mt["with"])
	var short := m.party_short(id)
	if agreed:
		mt["status"] = "agreed"
		mt["result"] = "Acuerdo con %s. %s." % [short, _summary_text(mt["table"], false)]
		_apply_agreement(mt)
	else:
		mt["status"] = "broken"
		mt["result"] = "La mesa con %s termina sin acuerdo." % short
		m.ai.change_relation(id, -2.0)
		m.ai.remember({"party": id, "event": "meeting_walkout", "topic": str(mt["topic"])})
	dyn.record(mt)
	m.publish("Mesa con %s: %s" % [short, "acuerdo" if agreed else "sin acuerdo"], str(mt["result"]), "REUNIÓN", "positive" if agreed else "warning", {"key": "meeting_" + id, "read": true})
	m.enc.maybe_incident(id, agreed)
	m.save_now()

func _apply_agreement(mt: Dictionary) -> void:
	var id := str(mt["with"])
	var topic := str(mt["topic"])
	var table: Array = mt["table"]
	m.ai.change_relation(id, 7.0 + float(mt.get("rapport", 0.0)) * 0.05)
	for ct in table:
		var cd: Dictionary = ct
		if str(cd.get("k", "")) == "cordon":
			var tgt := str(cd.get("target", ""))
			m.ai.change_relation(tgt, -3.0)
			m.ai.remember({"party": tgt, "target": tgt, "event": "cordon_imposed", "topic": topic})
	m.ai.remember({"party": id, "event": "agreement_accepted", "topic": topic, "detail": _summary_text(table, false)})
	match topic:
		"investiture":
			_sync_investiture(id, table, false)
		"partner":
			_sync_investiture(id, table, true)
		"law_deal":
			_apply_law_terms(id, str(mt.get("law", "")), table)
			_register_pacts(id, topic, table)
		_:
			_register_pacts(id, topic, table)
	_react_to_pact(id)

## Si el candidato es de la IA y necesita al jugador (grupo minoritario), le hace una oferta de apoyo que el jugador acepta,
## rechaza o contesta con sus propias condiciones. Una sola oferta por candidato e intento.
func candidate_offer() -> void:
	var cand := m.gov.candidate_id()
	if cand == "" or m.is_player(cand) or m.seats_of(m.pid()) <= 0 or m.phase != "investiture":
		return
	if m.brain.blocked_by(cand, m.pid()) != "" or _need_votes() <= 0:
		return
	var key := "proposal_inv_%s_%d" % [cand, m.gov.attempts()]
	for item in m.news():
		if str((item as Dictionary).get("key", "")) == key:
			return
	var lev := m.gov.player_leverage()
	var short := m.party_short(cand)
	var terms: Array = [{"k": "vote_yes", "by": "player"}]
	var gives: Array = []
	var tops := m.brain.top_issues(m.pid(), 1)
	if not tops.is_empty():
		var pt := m.brain.policy_term(m.pid(), "ai", str(tops[0]))
		terms.append(pt)
		gives.append(str(pt.get("text", "")).to_lower())
	if lev >= 0.45:
		terms.append({"k": "cabinet", "by": "ai", "n": 1})
		gives.append("una cartera en el Gobierno")
	m.publish("%s te ofrece un acuerdo de investidura" % short,
		"Necesita tus %d escaños. A cambio de tu voto a favor ofrece: %s. Puedes aceptar, rechazar o plantear tus propias condiciones." % [m.seats_of(m.pid()), "; ".join(gives) if not gives.is_empty() else "diálogo político"],
		"INVESTIDURA", "positive", {
			"needs_response": true, "expires_in": 2, "key": key, "speaker_id": cand,
			"actions": [{"id": "diplo_accept", "label": "Aceptar su oferta", "style": "good"}, {"id": "diplo_meet", "label": "Poner mis condiciones", "style": "primary"}, {"id": "diplo_decline", "label": "Rechazar", "style": "ghost"}],
			"data": {"party": cand, "topic": "partner", "terms": terms, "law": ""}
		})

## Aplica un pacto por una ley: enmiendas a la ley, compromiso de voto del partido y favores que debe el jugador.
func _apply_law_terms(id: String, law_id: String, table: Array) -> void:
	var law := m.laws.find(law_id)
	for t in table:
		var d: Dictionary = t
		match str(d.get("k", "")):
			"law_amend":
				if not law.is_empty():
					m.laws.set_change(law, str(d["measure"]), float(d["value"]))
			"law_vote", "law_abstain":
				if not law.is_empty():
					var com: Dictionary = law.get("committed", {})
					com[id] = "yes" if str(d["k"]) == "law_vote" else "abstain"
					law["committed"] = com
			"owe_vote":
				var fav := m.d("favors")
				fav[id] = int(fav.get(id, 0)) + 1
	if not law.is_empty():
		var gw: Dictionary = law.get("goodwill", {})
		gw[id] = float(gw.get(id, 0.0)) + 0.1
		law["goodwill"] = gw

## Favores de voto que el jugador debe a un partido (se cobran cuando ese partido lleva una ley al Pleno).
func favors_owed(party_id: String) -> int:
	return int(m.d("favors").get(party_id, 0))

## Al votar una ley de `proposer`, el jugador salda (o incumple) un favor pendiente. Devuelve un texto o "".
func settle_favor(proposer: String, player_vote: String) -> String:
	if favors_owed(proposer) <= 0:
		return ""
	var fav := m.d("favors")
	var short := m.party_short(proposer)
	if player_vote == "yes":
		fav[proposer] = favors_owed(proposer) - 1
		m.ai.change_relation(proposer, 5.0)
		m.ai.remember({"party": proposer, "event": "pact_kept", "topic": "law_deal"})
		return "Saldas el favor que debías a %s." % short
	fav[proposer] = favors_owed(proposer) - 1
	m.ai.change_relation(proposer, -9.0)
	m.ai.remember({"party": proposer, "event": "pact_broken", "topic": "law_deal"})
	m.trust = m.trust - 1.0
	return "%s te recuerda que le debías el voto a esta ley: la relación se resiente." % short

func _sync_investiture(id: String, table: Array, as_partner: bool) -> void:
	var offers := m.gov.offers()
	var key := m.pid() if as_partner else id
	var offer: Dictionary = offers.get(key, {})
	if offer.is_empty():
		offer = m.gov._make_offer(key)
		offers[key] = offer
	var policies: Array = []
	var cabinet_n := 0
	var vote := "yes"
	for t in table:
		var d: Dictionary = t
		match str(d.get("k", "")):
			"policy": policies.append(d)
			"cabinet": cabinet_n = maxi(cabinet_n, int(d.get("n", 1)))
			"vote_abstain": vote = "abstain"
			"participation":
				# La modalidad pactada manda sobre lo demás: entrar, apoyar desde fuera o limitarse a abstenerse.
				match str(d.get("mode", "")):
					"coalition": cabinet_n = maxi(cabinet_n, 1)
					"abstention": vote = "abstain"
	var demands: Array = []
	var i := 0
	for p in policies:
		demands.append({"id": "%s_m%d" % [key, i], "issue": str((p as Dictionary).get("issue", "jobs")), "text": str((p as Dictionary).get("text", "")),
			"measure": str((p as Dictionary).get("measure", "")), "to": float((p as Dictionary).get("to", 0.0)), "conceded": true})
		i += 1
	if not demands.is_empty():
		offer["demands"] = demands
	else:
		for dd in offer.get("demands", []):
			(dd as Dictionary)["conceded"] = false
	offer["role"] = "cabinet" if cabinet_n > 0 else "external"
	offer["vote"] = vote
	offer["status"] = "accepted"
	offer["note"] = ""
	offer["terms_extra"] = m.agr.extract_extra(table)
	offer["agreement_id"] = m.agr.new_agreement_id()
	offer["type"] = m.agr.type_of_offer(offer)
	var claims := m.d("cabinet_claims")
	if cabinet_n > 0:
		claims[key] = cabinet_n
	else:
		claims.erase(key)
	if vote == "yes":
		if not m.gov.partners().has(key):
			m.gov.partners().append(key)
	else:
		m.gov.partners().erase(key)
	if as_partner:
		m.s["player_vote"] = vote

func _register_pacts(id: String, topic: String, table: Array) -> void:
	var seq := int(m.s.get("pact_seq", 0)) + 1
	m.s["pact_seq"] = seq
	var label := _summary_text(table, false)
	var pact := {
		"id": seq, "kind": topic, "party": id, "terms": table.duplicate(true), "label": label,
		"cycle": m.cycle, "since": m.gov_month if m.phase != "campaign" else 0, "duration": 12, "status": "active",
		"remaining_bills": 0, "due": m.gov_month + 8,
		"applies_cycle": m.cycle if m.phase == "campaign" else m.cycle + 1
	}
	for t in table:
		var d: Dictionary = t
		if str(d.get("k", "")) == "bills":
			pact["remaining_bills"] = int(pact["remaining_bills"]) + int(d.get("n", 1))
	if topic == "joint_list" or topic == "pre_pact":
		pact["duration"] = 60
	# Un pacto del mismo tipo con el mismo partido se renueva en lugar de duplicarse.
	for old in pacts():
		var od: Dictionary = old
		if str(od.get("status", "")) == "active" and str(od.get("party", "")) == id and str(od.get("kind", "")) == topic:
			od["terms"] = pact["terms"]
			od["label"] = label
			od["duration"] = pact["duration"]
			od["remaining_bills"] = pact["remaining_bills"]
			od["due"] = pact["due"]
			od["flagged"] = false
			m.publish("Pacto renovado con %s" % m.party_short(id), "%s: %s." % [TOPICS[topic]["name"], label], "NEGOCIACIONES", "positive", {"key": "pact_%d" % int(od["id"])})
			return
	pacts().append(pact)
	m.agr.register_pact(id, topic, table, seq)
	m.publish("Pacto con %s" % m.party_short(id), "%s: %s." % [TOPICS[topic]["name"], label], "NEGOCIACIONES", "positive", {"key": "pact_%d" % seq})

## El jugador acepta tal cual una propuesta que le hace un partido (desde la bandeja).
func accept_proposal(data: Dictionary) -> String:
	var id := str(data.get("party", ""))
	var topic := str(data.get("topic", "relationship"))
	var terms: Array = data.get("terms", [])
	if id == "" or terms.is_empty():
		return ""
	m.ai.change_relation(id, 6.0)
	m.ai.remember({"party": id, "event": "agreement_accepted", "topic": topic, "detail": _summary_text(terms, false)})
	if topic == "law_deal":
		_apply_law_terms(id, str(data.get("law", "")), terms)
	elif topic == "partner":
		_sync_investiture(id, terms, true)
	_register_pacts(id, topic, terms)
	_react_to_pact(id)
	m.voters.on_pact(m.pid(), id)
	m.militancy.on_pact(id)
	return "Pacto cerrado con %s." % m.party_short(id)

## Los pactos tienen eco: los afines al socio lo ven bien y sus adversarios, mal.
func _react_to_pact(id: String) -> void:
	for p in m.rivals:
		var oid := str((p as Dictionary).get("id", ""))
		if oid == id:
			continue
		var c := m.brain.compat(oid, id)
		if c < 0.22:
			m.ai.change_relation(oid, -2.0)
		elif c > 0.62:
			m.ai.change_relation(oid, 1.0)

# ---------------------------------------------------------------- mantenimiento
## Cada mes de legislatura: caducan pactos, se vigila el cumplimiento y se reparte estabilidad.
func monthly() -> void:
	for p in pacts():
		var d: Dictionary = p
		if str(d.get("status", "")) != "active":
			continue
		var id := str(d["party"])
		var kind := str(d["kind"])
		if kind == "stability":
			m.s["stability"] = clampf(m.gov.stability() + 0.7 * float(Rules.TURN_MONTHS), 0.0, 100.0)
			var sat := m.d("partner_satisfaction")
			sat[id] = clampf(float(sat.get(id, 60.0)) + 0.5 * float(Rules.TURN_MONTHS), 0.0, 100.0)
		d["duration"] = int(d["duration"]) - Rules.TURN_MONTHS
		if int(d["duration"]) <= 0:
			d["status"] = "expired"
			m.publish("Caduca el pacto con %s" % m.party_short(id), "Pueden renegociarlo en una nueva mesa: %s." % str(d["label"]), "NEGOCIACIONES", "neutral")
			continue
		# Incumplimiento: promesas temáticas del jugador sin cumplir pasada la fecha.
		if not bool(d.get("flagged", false)) and m.gov_month > int(d.get("due", 99)):
			var unmet := false
			for t in d.get("terms", []):
				var td: Dictionary = t
				if str(td.get("k", "")) == "policy" and str(td.get("by", "")) == "player":
					unmet = true
			if unmet and m.gov.player_in_government():
				d["flagged"] = true
				m.ai.change_relation(id, -5.0)
				m.ai.remember({"party": id, "event": "pact_broken", "topic": kind})
				m.publish("%s denuncia incumplimientos" % m.party_short(id), "El grupo considera que no se está respetando lo pactado: %s." % str(d["label"]), "NEGOCIACIONES", "warning")

## El jugador rompe un pacto vigente: la otra parte lo recuerda.
func break_pact(pact_id: int) -> String:
	for p in pacts():
		var d: Dictionary = p
		if int(d.get("id", -1)) == pact_id and str(d.get("status", "")) == "active":
			d["status"] = "broken"
			var id := str(d["party"])
			m.ai.change_relation(id, -14.0)
			m.ai.remember({"party": id, "event": "pact_broken", "topic": str(d["kind"])})
			m.trust = m.trust - 1.0
			m.publish("Rompes el pacto con %s" % m.party_short(id), "El grupo denuncia públicamente el incumplimiento de: %s." % str(d["label"]), "NEGOCIACIONES", "warning")
			return "Pacto roto: %s no lo olvidará." % m.party_short(id)
	return ""

## Votos que aporta un pacto de leyes a una iniciativa; consume una ley del pacto.
func bill_ally(party_id: String) -> bool:
	for p in active_pacts(party_id):
		var d: Dictionary = p
		if int(d.get("remaining_bills", 0)) > 0:
			return true
		if str(d["kind"]) == "stability":
			return true
	return false

func consume_bill(party_id: String) -> void:
	for p in active_pacts(party_id):
		var d: Dictionary = p
		if int(d.get("remaining_bills", 0)) > 0:
			d["remaining_bills"] = int(d["remaining_bills"]) - 1
			if int(d["remaining_bills"]) == 0 and str(d["kind"]) == "bills":
				d["status"] = "kept"
				m.ai.remember({"party": party_id, "event": "pact_kept", "topic": "bills"})
			return

## Los compromisos pre-electorales y las candidaturas conjuntas se activan al iniciar la investidura.
func apply_pledges(candidate: String) -> void:
	for p in active_pacts():
		var d: Dictionary = p
		if not str(d["kind"]) in ["pre_pact", "joint_list"] or int(d.get("applies_cycle", -1)) != m.cycle:
			continue
		var id := str(d["party"])
		if candidate != m.pid() or m.seats_of(id) <= 0:
			continue
		var offer: Dictionary = m.gov.offers().get(id, {})
		if offer.is_empty():
			continue
		var terms: Array = d["terms"]
		if str(d["kind"]) == "joint_list":
			terms = [{"k": "vote_yes", "by": "ai"}]
		_sync_investiture(id, terms, false)
		d["status"] = "kept"
		m.ai.remember({"party": id, "event": "pact_kept", "topic": str(d["kind"])})
		m.publish("%s cumple lo pactado antes de las elecciones" % m.party_short(id), "Su apoyo a tu investidura estaba atado: %s." % str(d["label"]), "NEGOCIACIONES", "positive")

## Efecto de las candidaturas conjuntas: cada día de campaña sus encuestas se acercan.
func joint_list_tick() -> void:
	for p in active_pacts():
		var d: Dictionary = p
		if str(d["kind"]) != "joint_list" or int(d.get("applies_cycle", -1)) != m.cycle:
			continue
		var a := m.pid()
		var b := str(d["party"])
		var bonus := 0.10 * minf(m.poll_of(a), m.poll_of(b)) / float(Rules.CAMPAIGN_LENGTH_DAYS)
		m.campaign.adjust_poll(a, bonus)
		m.campaign.adjust_poll(b, bonus)

# ---------------------------------------------------------------- texto
func _lower_first(t: String) -> String:
	return t.substr(0, 1).to_lower() + t.substr(1)

## Resumen de la mesa. first_person: "Ofrezco… A cambio pido…"; si no, "Tú ofreces… Ellos aportan…".
func _summary_text(table: Array, first_person: bool = true) -> String:
	var gives: Array = []
	var asks: Array = []
	var mutual: Array = []
	for t in table:
		var d: Dictionary = t
		var txt := _lower_first(m.brain.term_text(d))
		if str(d.get("k", "")) == "joint_list":
			mutual.append(txt)
		elif str(d.get("by", "player")) == "ai":
			asks.append(txt)
		else:
			gives.append(txt)
	var parts: Array = []
	if first_person:
		if not mutual.is_empty():
			parts.append("Propongo: " + "; ".join(mutual))
		if not gives.is_empty():
			parts.append("Ofrezco: " + "; ".join(gives))
		if not asks.is_empty():
			parts.append("A cambio pido: " + "; ".join(asks))
	else:
		if not mutual.is_empty():
			parts.append("Ambos: " + "; ".join(mutual))
		if not gives.is_empty():
			parts.append("Tú ofreces: " + "; ".join(gives))
		if not asks.is_empty():
			parts.append("Ellos aportan: " + "; ".join(asks))
	return ". ".join(parts) if not parts.is_empty() else "sin condiciones"

func _tone_of(id: String, mt: Dictionary) -> String:
	var d := m.brain.disposition(id, m.pid()) + float(mt.get("rapport", 0.0)) * 0.3
	if d >= 55.0:
		return "warm"
	if d >= 32.0:
		return "neutral"
	return "cold"

func _line(id: String, key: String, mt: Dictionary) -> String:
	var tone := _tone_of(id, mt)
	var short := m.party_short(id)
	var bank := {
		"accept": {
			"warm": ["Me parece un buen punto de encuentro. Contad con nosotros.", "Hay confianza suficiente. Lo firmamos.", "Es un acuerdo equilibrado. Adelante.", "Se nota que habéis trabajado el texto. Cerrado.", "Me quedo tranquilo con esto. Un apretón de manos y a trabajar."],
			"neutral": ["Con estos términos, podemos cerrarlo.", "Lo consultaremos con la ejecutiva, pero cuenta con nuestra palabra.", "Aceptamos. Esperamos que se cumpla cada punto.", "Es razonable. Que conste en acta cada compromiso.", "No es lo que queríamos, pero es lo que se puede. Adelante."],
			"cold": ["Lo aceptamos, aunque sin entusiasmo. Se nos juzgará por esto.", "Firmamos, pero queremos ver hechos y no solo palabras.", "Aceptamos. Y que nadie interprete esto como una luna de miel.", "De acuerdo. Pero dejaremos claro dónde están nuestros límites."]
		},
		"counter": {
			"warm": ["Estamos cerca, pero falta algo.", "Vamos bien; aún hay que pulir el acuerdo.", "Me gusta la dirección, aunque necesito un gesto más.", "Casi. Dos ajustes y lo cerramos."],
			"neutral": ["Nos acercamos, pero no basta todavía.", "Hay base para hablar, aunque hoy no firmaríamos.", "Puedo trabajar con esto, pero tiene que moverse.", "Es un primer paso. Necesito algo más sólido."],
			"cold": ["Esto es insuficiente tal y como está.", "No es una oferta que podamos defender ante nuestras bases.", "Tendrá que mejorar bastante para que lo consideremos.", "Con esto no llegamos a ninguna parte."]
		},
		"veto": {
			"warm": ["Lamentablemente no puedo avanzar:", "Me gustaría, pero hay una barrera:", "Aprecio el esfuerzo, pero no es posible:"],
			"neutral": ["No hay margen:", "Nuestra posición es firme:", "Tenemos una línea que no vamos a cruzar:"],
			"cold": ["Esta conversación no tiene recorrido:", "No vamos a sentarnos a hablar de esto:", "Queda cerrada la puerta a eso:"]
		}
	}
	var arr: Array = (bank[key] as Dictionary)[tone]
	return str(m.enc.pick(arr, "dline:%s:%s:%s" % [id, key, tone])).replace("%s", short)

func _reject_text(id: String, res: Dictionary, mt: Dictionary) -> String:
	var worst := ""
	var worst_v := 0.0
	for td in res["terms"]:
		var d: Dictionary = td
		if float(d["v"]) < worst_v:
			worst_v = float(d["v"])
			worst = str(d["label"])
	var factors: Array = res["factors"]
	var worst_f := ""
	var wf := 0.0
	for f in factors:
		var fd: Dictionary = f
		if str(fd["key"]) != "terms" and float(fd["value"]) < wf:
			wf = float(fd["value"])
			worst_f = str(fd["key"])
	var line := ""
	if worst != "" and worst_v < -0.2:
		line = "«%s» es lo que más nos cuesta aceptar." % worst
	elif worst_f == "affinity":
		line = "Hay demasiada distancia política entre nosotros."
	elif worst_f == "trust":
		line = "No tenemos la confianza necesaria."
	elif worst_f == "history":
		line = "Nuestro historial reciente no invita a fiarnos."
	elif worst_f == "risk":
		line = "Asociarnos a esto tendría un coste electoral que no asumimos."
	else:
		line = "Lo que ofrece no compensa lo que nos pide."
	var warn := " Me quedan pocas ganas de seguir si no cambia la propuesta." if int(mt["patience"]) <= 1 else ""
	return "%s %s%s" % [_line(id, "counter", mt), line, warn]

## Lo que el partido propone al sentarse, en su voz.
func _their_pitch(table: Array) -> String:
	var gives: Array = []
	var asks: Array = []
	var mutual: Array = []
	for t in table:
		var d: Dictionary = t
		var txt := _lower_first(m.brain.term_text(d))
		if str(d.get("k", "")) == "joint_list":
			mutual.append(txt)
		elif str(d.get("by", "player")) == "ai":
			gives.append(txt)
		else:
			asks.append(txt)
	var parts: Array = []
	if not mutual.is_empty():
		parts.append("Proponemos: " + "; ".join(mutual))
	if not gives.is_empty():
		parts.append("Ponemos sobre la mesa: " + "; ".join(gives))
	if not asks.is_empty():
		parts.append("A cambio, pedimos: " + "; ".join(asks))
	return ". ".join(parts) + "."

func _opening(id: String, topic: String, mt: Dictionary) -> String:
	var tone := _tone_of(id, mt)
	var short := m.party_short(id)
	var greet := {
		"warm": ["Buenos días. Es un placer recibirle.", "Pase, pase. Me alegra que haya venido.", "Gracias por venir; el café está recién hecho.", "Qué bien verle por aquí."],
		"neutral": ["Adelante, le escucho.", "Buenos días. Dígame.", "Tome asiento. Tengo media hora.", "Bienvenido. Vamos a ello."],
		"cold": ["Tengo poco tiempo. Vaya al grano.", "No esperaba esta visita. Usted dirá.", "Siéntese. Pero seré breve.", "Le recibo por cortesía institucional."],
	}
	var topic_line: Array = []
	match topic:
		"investiture": topic_line = ["Entiendo que quiere hablar de la investidura.", "Supongo que viene por mi voto en la investidura.", "Hablemos claro: ¿qué ofrece para su investidura?"]
		"partner": topic_line = ["Imagino que viene a poner condiciones a su voto.", "Sé que quiere hablar de estabilidad y de qué pido yo.", "¿Viene a asegurar mi apoyo o a pedirme algo?"]
		"joint_list": topic_line = ["¿Candidaturas conjuntas? Es un asunto delicado para nosotros.", "Una lista conjunta no es algo que se improvise.", "Hablemos de listas, pero con realismo."]
		"pre_pact": topic_line = ["¿Quiere atar pactos antes de saber el resultado?", "Un pacto antes de votar... interesante.", "Hablemos de lo que haríamos después de las urnas."]
		"bills": topic_line = ["Veamos en qué leyes podríamos coincidir.", "¿Qué ley quiere sacar adelante con nosotros?", "Dígame qué proyecto tiene en mente."]
		"stability": topic_line = ["Hablemos de cómo garantizar la mayoría.", "Sé que la mayoría pende de un hilo. Escucho.", "¿Cómo piensa asegurar el apoyo parlamentario?"]
		_: topic_line = ["¿Qué quiere trasladarme?", "¿De qué quiere hablar hoy?", "Usted dirá el motivo de la visita."]
	var g: String = str(m.enc.pick(greet[tone], "dgreet:%s:%s" % [id, tone]))
	var t: String = str(m.enc.pick(topic_line, "dtopic:%s:%s" % [id, topic]))
	var extra := ""
	match str(mt.get("said", "")):
		"attack":
			extra = " " + str(m.enc.pick(["Por cierto: lo que dijo de nosotros en los medios no ha pasado desapercibido.", "No he olvidado sus palabras de estos días.", "Me ha costado explicar a los míos lo que dijo públicamente."], "dsaid_attack"))
		"hand":
			extra = " " + str(m.enc.pick(["Agradezco el tono que ha tenido con nosotros en público.", "Me gustó lo que dijo en la entrevista sobre dialogar.", "Se nota que viene con ganas de entenderse."], "dsaid_hand"))
	return "%s %s%s" % [g, t, extra]
