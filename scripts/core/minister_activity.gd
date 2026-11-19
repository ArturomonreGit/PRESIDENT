class_name MinisterActivity
extends RefCounted
## Actividad autónoma de los ministros: cada trimestre, según personalidad, atributos y contexto, algunos ministros
## proponen reformas o recursos, alertan, hacen declaraciones, cometen errores, protagonizan escándalos, chocan por
## competencias compartidas, logran éxitos o dimiten. Lo que requiere decisión del presidente va a la mesa de
## coalición como propuesta; lo demás se resuelve y se notifica.

var m: GameModel

const MAX_EVENTS := 3
const KIND_NAMES := {"reform": "Reforma", "resources": "Recursos", "alert": "Alerta", "statement": "Declaración", "error": "Error de gestión",
	"scandal": "Escándalo", "success": "Éxito", "clash": "Choque de competencias", "resignation": "Dimisión"}
const AREA_SCOPE := {"tax": "presupuestos", "indirect": "presupuestos", "social": "social", "health": "social", "education": "social", "housing": "social",
	"family": "social", "jobs": "leyes", "industry": "leyes", "energy": "infra", "transport": "infra", "agriculture": "infra", "territory": "territorial"}

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	return m.d("mact")

func ensure() -> void:
	var s := st()
	if not s.has("log") or typeof(s["log"]) != TYPE_ARRAY:
		s["log"] = []
	if not s.has("last_quarter"):
		s["last_quarter"] = -1

func log_entries(n: int = 8) -> Array:
	ensure()
	return (st()["log"] as Array).slice(0, n)

func _log(kind: String, idx: int, text: String) -> void:
	var lg: Array = st()["log"]
	lg.push_front({"turn": m.turn(), "kind": kind, "ministry": str(m.cab.entry(idx).get("name", "")), "text": text})
	while lg.size() > 40:
		lg.pop_back()

func _player_president() -> bool:
	return m.coal.gov_id() == m.pid()

# ---------------------------------------------------------------- etiquetas de sucesor / rival
## "Sucesor potencial" o "Rival" para ministros ambiciosos, populares y con buenos resultados dentro del partido del presidente.
func tag_of(idx: int) -> String:
	var mn := m.cab.minister(idx)
	if mn.is_empty():
		return ""
	var amb := m.ministers.attr(mn, "ambicion")
	var pop := m.ministers.attr(mn, "popularidad")
	if amb < 7 or pop < 6 or m.cab.act_of(idx) < 55.0:
		return ""
	if str(m.cab.entry(idx).get("party", "")) != m.coal.gov_id():
		return ""
	return "Rival" if m.ministers.attr(mn, "lealtad") <= 4 else "Sucesor potencial"

func tagged() -> Array:
	var out: Array = []
	for i in range(m.cab.size()):
		var t := tag_of(i)
		if t != "":
			out.append({"idx": i, "tag": t})
	return out

# ---------------------------------------------------------------- trimestre
func quarterly() -> void:
	if m.phase != "legislature":
		return
	ensure()
	st()["last_quarter"] = m.turn()
	_drift_performance()
	var cands: Array = []
	for i in range(m.cab.size()):
		if m.cab.minister(i).is_empty():
			continue
		if m.exec.post_kind() == "minister" and m.exec.post_index() == i:
			continue
		cands.append(i)
	cands.shuffle()
	var done := 0
	for ii in cands:
		if done >= MAX_EVENTS:
			break
		var idx: int = int(ii)
		var kind := _pick_kind(idx)
		if kind == "":
			continue
		if _run(kind, idx):
			done += 1
	_rivals()

## El rendimiento del ministro se mueve cada trimestre hacia lo que su competencia y la salud de su ámbito dictan.
func _drift_performance() -> void:
	for i in range(m.cab.size()):
		var e: Dictionary = m.cab.entry(i)
		var mn := m.cab.minister(i)
		if mn.is_empty():
			continue
		var target := 40.0 + m.ministers.skill_in(i) * 4.0
		var worst := 0.0
		for mt in m.cab.metrics(i, 3):
			var md: Dictionary = mt
			worst = maxf(worst, m.cab.need_of(str(Executive.AREA_METRIC.get(str(md.get("area", "")), ["", 1])[0]), int(Executive.AREA_METRIC.get(str(md.get("area", "")), ["", 1])[1])))
		target -= worst * 8.0
		var af := float(CabinetSim.AUTONOMY_FACTOR.get(str(e.get("autonomy", "plena")), 1.0))
		var step := clampf((target - float(mn.get("act", 55.0))) * 0.2, -4.0, 4.0)
		if step < 0.0 and af < 1.0:
			step *= 0.7  # la supervisión limita las caídas
		mn["act"] = clampf(float(mn.get("act", 55.0)) + step, 5.0, 98.0)
		if e.has("plan") and m.turn() >= int((e["plan"] as Dictionary).get("due", 99)):
			var plan: Dictionary = e["plan"]
			var better := float(mn["act"]) > float(plan.get("act0", 0.0)) + 3.0
			m.ministers.log_history(mn, "Plan correctivo: %s." % ("cumplido" if better else "sin resultados"))
			m.ministers.shift_relation(mn, 3.0 if better else -3.0)
			e.erase("plan")
			_log("success" if better else "error", i, "El plan correctivo %s." % ("da resultados" if better else "no mejora la gestión"))

func _weights(idx: int) -> Dictionary:
	var mn := m.cab.minister(idx)
	var e := m.cab.entry(idx)
	var pers := str(mn.get("personality", ""))
	var af := float(CabinetSim.AUTONOMY_FACTOR.get(str(e.get("autonomy", "plena")), 1.0))
	var act := m.cab.act_of(idx)
	var integ := m.ministers.attr(mn, "integridad")
	var exper := m.ministers.attr(mn, "experiencia")
	var party := str(e.get("party", ""))
	var partner := party != m.coal.gov_id()
	var need := 0.0
	for mt in m.cab.metrics(idx, 3):
		if not bool((mt as Dictionary).get("good", true)):
			need = maxf(need, 0.8)
	var w: Dictionary = {}
	if _player_president():
		w["reform"] = 2.5 * af * (1.0 if act >= 35.0 else 0.4) * (1.3 if pers in ["ideologico", "tecnocrata", "ambicioso"] else 1.0)
		w["resources"] = (1.8 if need > 0.0 else 0.5) * af
	w["alert"] = 1.6 if need > 0.0 else 0.0
	var stmt := 2.6 if pers == "mediatico" else (2.0 if pers == "ideologico" else (1.5 if pers == "ambicioso" else 0.3))
	w["statement"] = stmt * (1.4 if partner else 1.0)
	w["error"] = (2.6 if pers == "inexperto" else 0.0) + (1.5 if exper <= 3 else 0.0) + (0.6 if act < 45.0 else 0.0)
	w["scandal"] = (1.8 if integ <= 3 else (0.5 if integ <= 5 else 0.0)) + (0.4 if pers == "mediatico" and integ <= 6 else 0.0)
	w["success"] = 2.0 if act >= 65.0 else 0.0
	w["resignation"] = 2.0 if (m.ministers.relation(mn) < 30.0 and m.ministers.attr(mn, "lealtad") <= 4 and (m.ministers.attr(mn, "ambicion") >= 6 or act < 35.0)) else 0.0
	w["clash"] = 1.8 if not _clash_pair(idx).is_empty() else 0.0
	return w

func _pick_kind(idx: int) -> String:
	var w := _weights(idx)
	var total := 0.0
	for k in w.keys():
		total += float(w[k])
	# Probabilidad global de que ocurra algo en esta cartera este trimestre.
	if total <= 0.0 or m.rng.randf() > clampf(total / 5.0, 0.0, 0.7):
		return ""
	var r := m.rng.randf() * total
	for k in w.keys():
		r -= float(w[k])
		if r <= 0.0:
			return str(k)
	return ""

func _run(kind: String, idx: int) -> bool:
	match kind:
		"reform":
			return _ev_reform(idx)
		"resources":
			return _ev_resources(idx)
		"alert":
			return _ev_alert(idx)
		"statement":
			return _ev_statement(idx)
		"error":
			return _ev_error(idx)
		"scandal":
			return _ev_scandal(idx)
		"success":
			return _ev_success(idx)
		"clash":
			return _ev_clash(idx)
		"resignation":
			return _ev_resignation(idx)
	return false

func _who(idx: int) -> String:
	var mn := m.cab.minister(idx)
	return "%s (%s)" % [Leader.full_name(mn), str(m.cab.entry(idx).get("name", ""))]

func _party(idx: int) -> String:
	return str(m.cab.entry(idx).get("party", ""))

func _is_partner(idx: int) -> bool:
	return _party(idx) != m.coal.gov_id()

func _base(kind: String, idx: int, title: String, body: String) -> Dictionary:
	var e := m.cab.entry(idx)
	var party := _party(idx)
	return {"kind": kind, "origin": "minister", "author": party, "minister_party": party, "ministry_id": str(e.get("id", "")), "ministry": str(e.get("name", "")),
		"minister": Leader.full_name(m.cab.minister(idx)), "title": title, "body": body, "decider": m.coal.gov_id(), "scope": "leyes"}

# ---------------------------------------------------------------- eventos
func _ev_reform(idx: int) -> bool:
	var pick := m.exec._ai_pick(idx)
	if pick.is_empty():
		return false
	var meas: Dictionary = pick["meas"]
	var nv := float(pick["nv"])
	var cur := m.eco.value(str(meas["id"]))
	var inc := m.exec.incoherence(meas, nv)
	var p := _base("reform", idx, "%s propone reformar: %s" % [str(m.cab.entry(idx)["name"]), str(meas["name"])],
		"%s propone fijar «%s» en «%s» (ahora «%s»)." % [Leader.full_name(m.cab.minister(idx)), str(meas["name"]), Policies.value_text(meas, nv), Policies.value_text(meas, cur)])
	p["measure"] = str(meas["id"])
	p["nv"] = nv
	p["scope"] = str(AREA_SCOPE.get(str(meas.get("area", "")), "leyes"))
	p["cost"] = {"capital": m.exec.cost_of(meas, nv), "funds": 0.0}
	p["risk"] = "choca con la línea de tu partido y tus votantes lo notarán" if inc > 0.3 else ""
	m.coal.submit(p)
	_log("reform", idx, "%s propone «%s»." % [Leader.full_name(m.cab.minister(idx)), str(meas["name"])])
	return true

func _ev_resources(idx: int) -> bool:
	var lines: Array = m.exec.lines_of(idx)
	if lines.is_empty():
		return false
	var line := str(lines[m.rng.randi() % lines.size()])
	if m.exec.credit_delta(line) + Executive.FACTOR_STEP > 0.15 + 0.0001:
		return false
	var name := str(Policies.entry(Policies.budget(), line).get("name", line))
	var funds := m.eco.budget_spending(line) * Executive.FACTOR_STEP
	var p := _base("resources", idx, "%s pide más recursos para %s" % [str(m.cab.entry(idx)["name"]), name.to_lower()],
		"%s solicita un +%.1f %% de crédito en %s." % [Leader.full_name(m.cab.minister(idx)), Executive.FACTOR_STEP * 100.0, name.to_lower()])
	p["line"] = line
	p["scope"] = m.coal.scope_of_line(line)
	p["cost"] = {"capital": 0.0, "funds": funds}
	m.coal.submit(p)
	_log("resources", idx, "Pide más crédito para %s." % name.to_lower())
	return true

func _ev_alert(idx: int) -> bool:
	var ms := m.cab.metrics(idx, 3)
	var bad := ""
	for mt in ms:
		if not bool((mt as Dictionary).get("good", true)):
			bad = str((mt as Dictionary)["label"])
			break
	if bad == "":
		return false
	var mn := m.cab.minister(idx)
	m.publish("Alerta en %s" % str(m.cab.entry(idx)["name"]), "%s avisa de que «%s» se deteriora en su ámbito y pide atención del Gobierno." % [Leader.full_name(mn), bad.to_lower()], "GOBIERNO", "warning")
	m.ministers.log_history(mn, "Alerta sobre %s." % bad.to_lower())
	_log("alert", idx, "Alerta: %s." % bad.to_lower())
	return true

func _offended_party(idx: int) -> String:
	var mine := _party(idx)
	var best := ""
	var worst := 2.0
	var cands: Array = [m.coal.gov_id()]
	cands.append_array(m.coal.party_ids())
	for id in cands:
		var pid := str(id)
		if pid == mine or pid == "":
			continue
		var c := m.brain.compat(mine, pid)
		if c < worst:
			worst = c
			best = pid
	return best

func _ev_statement(idx: int) -> bool:
	var off := _offended_party(idx)
	if off == "":
		return false
	var mn := m.cab.minister(idx)
	var p := _base("statement", idx, "Polémica: %s" % _who(idx),
		"%s hace unas declaraciones que incomodan a %s y obligan a posicionarse." % [Leader.full_name(mn), m.party_short(off)])
	p["offended"] = off
	p["scope"] = "crisis"
	p["risk"] = "respaldar ofende a %s; desautorizar enfría a tu ministro" % m.party_short(off)
	_log("statement", idx, "Declaraciones que incomodan a %s." % m.party_short(off))
	if _player_president():
		m.coal.submit(p)
	else:
		# La IA preside: el efecto es automático y se explica en la bandeja.
		if m.coal.party_ids().has(off):
			m.coal.shift_trust(off, -3.0, "declaraciones de un ministro de otro partido")
		m.gov.shift_government_approval(-0.2)
		m.publish(str(p["title"]), "%s Sin reacción del presidente: queda en una polémica menor." % str(p["body"]), "GOBIERNO", "neutral")
	return true

func _ev_error(idx: int) -> bool:
	var mn := m.cab.minister(idx)
	var p := _base("error", idx, "Error en %s" % str(m.cab.entry(idx)["name"]),
		"%s comete un error de gestión: una decisión mal calibrada provoca críticas." % Leader.full_name(mn))
	p["scope"] = "crisis"
	m.ministers.log_history(mn, "Error de gestión.")
	mn["act"] = clampf(float(mn.get("act", 55.0)) - 4.0, 0.0, 100.0)
	_log("error", idx, "Error de gestión.")
	if _player_president():
		m.coal.submit(p)
	else:
		m.gov.shift_government_approval(-0.3)
		m.publish(str(p["title"]), str(p["body"]), "GOBIERNO", "warning")
	return true

func _ev_scandal(idx: int) -> bool:
	var mn := m.cab.minister(idx)
	var p := _base("scandal", idx, "Escándalo en %s" % str(m.cab.entry(idx)["name"]),
		"Se publican informaciones comprometedoras sobre %s." % Leader.full_name(mn))
	p["scope"] = "crisis"
	p["risk"] = "respaldarle cuesta imagen si resulta culpable"
	m.ministers.log_history(mn, "Salpicado/a por un escándalo.")
	m.gov.shift_government_approval(-0.5)
	m.media.on_event("Escándalo en %s" % str(m.cab.entry(idx)["name"]))
	_log("scandal", idx, "Escándalo.")
	if _player_president():
		m.coal.submit(p)
	else:
		m.publish(str(p["title"]), str(p["body"]), "GOBIERNO", "negative")
		if not m.cab.is_reserved(idx) and m.ministers.attr(mn, "integridad") <= 3 and m.rng.randf() < 0.5:
			m.cab._vacate(idx, "dimite tras el escándalo", false)
	return true

func _ev_success(idx: int) -> bool:
	var mn := m.cab.minister(idx)
	m.gov.shift_government_approval(0.4)
	if m.rng.randf() < 0.35:
		m.ministers.shift_attr(mn, "popularidad", 1)
	m.ministers.shift_relation(mn, 1.0)
	m.ministers.log_history(mn, "Logro destacado en su gestión.")
	if _is_partner(idx) and not m.is_player(_party(idx)):
		m.coal.shift_trust(_party(idx), 1.5, "éxito de su ministro")
	m.publish("Éxito de %s" % str(m.cab.entry(idx)["name"]), "%s consigue un resultado destacado al frente de su cartera." % Leader.full_name(mn), "GOBIERNO", "positive")
	_log("success", idx, "Logro destacado.")
	return true

func _clash_pair(idx: int) -> Array:
	for sc in m.cab.shared_of(idx):
		var owner := m.cab.owner_of(str(sc))
		if owner >= 0 and owner != idx and str(m.cab.entry(owner).get("party", "")) != _party(idx) and not m.cab.minister(owner).is_empty():
			return [idx, owner, str(sc)]
	return []

func _ev_clash(idx: int) -> bool:
	var pair := _clash_pair(idx)
	if pair.is_empty():
		return false
	var a: int = int(pair[0])
	var b: int = int(pair[1])
	var comp := str(pair[2])
	var p := _base("clash", a, "Choque por %s" % Competencies.name_of(comp).to_lower(),
		"«%s» y «%s» discrepan sobre quién lidera %s." % [str(m.cab.entry(a)["name"]), str(m.cab.entry(b)["name"]), Competencies.name_of(comp).to_lower()])
	p["name_a"] = str(m.cab.entry(a)["name"])
	p["name_b"] = str(m.cab.entry(b)["name"])
	p["party_a"] = _party(a)
	p["party_b"] = _party(b)
	p["scope"] = "nombramientos"
	_log("clash", a, "Choque con «%s» por %s." % [str(m.cab.entry(b)["name"]), Competencies.name_of(comp).to_lower()])
	if _player_president():
		m.coal.submit(p)
	else:
		for pid in [_party(a), _party(b)]:
			if m.coal.party_ids().has(str(pid)):
				m.coal.shift_trust(str(pid), -1.0, "choque de competencias entre ministerios")
		m.publish(str(p["title"]), str(p["body"]), "GOBIERNO", "warning")
	return true

func _ev_resignation(idx: int) -> bool:
	var e := m.cab.entry(idx)
	var mn := m.cab.minister(idx)
	var reserved := m.cab.is_reserved(idx)
	var name := Leader.full_name(mn)
	var r := m.cab._vacate(idx, "dimite por discrepancias con el presidente", true)
	_log("resignation", idx, "%s dimite." % name)
	if reserved and not m.is_player(str(e.get("party", ""))):
		m.coal.shift_trust(str(e.get("party", "")), -2.0, "la dimisión de su ministro")
	return bool(r.get("ok", false))

# ---------------------------------------------------------------- sucesores y rivales
func _rivals() -> void:
	if not _player_president() or m.gov.approval() >= 50.0:
		return
	for t in tagged():
		var td: Dictionary = t
		if str(td["tag"]) == "Rival" and m.rng.randf() < 0.25:
			var mn := m.cab.minister(int(td["idx"]))
			m.itrust.shock(-0.8, "%s, con aspiraciones propias, cuestiona el liderazgo del presidente." % Leader.full_name(mn))
			m.ministers.log_history(mn, "Cuestiona veladamente el liderazgo del presidente.")
			break
