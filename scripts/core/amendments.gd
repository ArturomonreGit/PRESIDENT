class_name Amendments
extends RefCounted
## Trámite de enmiendas del Pleno. Antes de votar una ley:
## · la IA enmienda TUS leyes: los afines piden ampliarlas si se quedan cortas o suavizarlas si son abusivas, y los lejanos
##   las modifican para darte su apoyo cuando no hay mayorías claras. Cada oferta es «mi voto a cambio de este cambio».
## · tú enmiendas las leyes de la IA (cupo por ley); el proponente acepta, propone una transaccional o se niega según lo
##   que necesite tus votos.
## · los partidos de la IA se enmiendan entre sí las leyes que tú no presentas.
## Todo el estado vive dentro de la propia ley (`law["amend"]`), así que se guarda con la sesión.

var m: GameModel

const PLAYER_SLOTS := 3
const AI_MAX_OFFERS := 4
const GOODWILL := 0.22

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- estado
func state(law: Dictionary) -> Dictionary:
	if not law.has("amend"):
		law["amend"] = {"offers": [], "counters": [], "log": [], "used": 0, "opened": false, "seq": 0}
	return law["amend"]

## Solo las leyes y las proposiciones no de ley se enmiendan (no los presupuestos ni las interpelaciones).
func supports(law: Dictionary) -> bool:
	return str(law.get("kind", "")) in ["proyecto", "proposición", "pnl"]

func offers(law: Dictionary) -> Array:
	return state(law)["offers"]

func open_offers(law: Dictionary) -> Array:
	var out: Array = []
	for o in offers(law):
		if str((o as Dictionary)["status"]) == "open":
			out.append(o)
	return out

func counters(law: Dictionary) -> Array:
	return state(law)["counters"]

func log_of(law: Dictionary) -> Array:
	return state(law)["log"]

func slots_left(law: Dictionary) -> int:
	return maxi(0, PLAYER_SLOTS - int(state(law)["used"]))

func _rng(law: Dictionary, party_id: String, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("amend_%s_%s_%s_%d_%d" % [str(law["id"]), party_id, salt, m.cycle, m.gov_month])
	return r

func _log(law: Dictionary, who: String, to: String, ok: bool, text: String) -> void:
	log_of(law).append({"who": who, "to": to, "ok": ok, "text": text})

## Abre el trámite de una ley (una sola vez): la IA presenta sus enmiendas.
func open(law: Dictionary) -> void:
	var st := state(law)
	if bool(st["opened"]):
		return
	st["opened"] = true
	if not supports(law):
		return
	if m.is_player(str(law.get("proposer", ""))):
		_generate_offers(law)
	else:
		_ai_vs_ai(law)

# ---------------------------------------------------------------- opciones de enmienda desde la óptica de un partido
func _term(type: String, mid: String, value: float, s: float, w: float) -> Dictionary:
	var meas := Policies.measure(mid)
	var nm := str(meas.get("name", mid))
	var txt := ""
	match type:
		"drop": txt = "Retira «%s»" % nm
		"soften": txt = "Suaviza «%s»: %s" % [nm, Policies.value_text(meas, value)]
		"intensify": txt = "Amplía «%s»: %s" % [nm, Policies.value_text(meas, value)]
		_: txt = "Incluye «%s»: %s" % [nm, Policies.value_text(meas, value)]
	return {"type": type, "measure": mid, "value": value, "text": txt, "s": s, "w": w}

## Cambios que `party_id` querría hacer en la ley: retirar/suavizar lo que le chirría, ampliar lo que le gusta y se queda corto
## y añadir medidas suyas del mismo área. Ordenados por importancia.
func options_for(law: Dictionary, party_id: String) -> Array:
	var out: Array = []
	var core: Dictionary = m.laws._content(law, party_id)
	var changes: Dictionary = law["changes"]
	for it in core["items"]:
		var d: Dictionary = it
		var mid := str(d["measure"])
		if Policies.is_special(mid):
			continue
		var meas := Policies.measure(mid)
		if meas.is_empty():
			continue
		var cur := m.eco.value(mid)
		var nv := float(changes.get(mid, cur))
		var s := float(d["s"])
		var w := float(d["w"])
		if s <= -0.3:
			var half := Policies.snap(meas, cur + (nv - cur) * 0.5)
			if is_equal_approx(half, cur):
				out.append(_term("drop", mid, cur, s, w))
			else:
				out.append(_term("soften", mid, half, s, w))
		elif s >= 0.3:
			var dirn := 1.0 if nv > cur else -1.0
			var steps := maxf(1.0, roundf((float(meas["max"]) - float(meas["min"])) / float(meas["step"]) * 0.12))
			var v2 := Policies.snap(meas, nv + dirn * steps * float(meas["step"]))
			if not is_equal_approx(v2, nv):
				out.append(_term("intensify", mid, v2, s, w))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["s"])) * float(a["w"]) > absf(float(b["s"])) * float(b["w"]))
	# Medidas que añadiría de su cosecha
	var cands: Array = []
	for mm in Policies.measures_of(str(law["area"])):
		var md: Dictionary = mm
		var mid2 := str(md["id"])
		if changes.has(mid2):
			continue
		var pref := m.laws.measure_pref(party_id, md)
		if absf(pref) >= 0.5:
			cands.append({"meas": md, "pref": pref})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["pref"])) > absf(float(b["pref"])))
	for c in cands.slice(0, 3):
		var cd: Dictionary = c
		var md2: Dictionary = cd["meas"]
		var cur2 := m.eco.value(str(md2["id"]))
		var dirn2 := 1.0 if float(cd["pref"]) > 0.0 else -1.0
		var steps2 := maxf(1.0, roundf((float(md2["max"]) - float(md2["min"])) / float(md2["step"]) * 0.2))
		var target := Policies.snap(md2, cur2 + dirn2 * float(md2["step"]) * steps2)
		if not is_equal_approx(target, cur2):
			out.append(_term("add", str(md2["id"]), target, float(cd["pref"]) * 0.5, 1.0))
	return out

func _apply_term(law: Dictionary, t: Dictionary) -> void:
	m.laws.set_change(law, str(t["measure"]), float(t["value"]))

func _clone(law: Dictionary, terms: Array, extra_goodwill_for: String = "") -> Dictionary:
	var c := law.duplicate(true)
	for t in terms:
		_apply_term(c, t as Dictionary)
	if extra_goodwill_for != "":
		var gw: Dictionary = c["goodwill"]
		gw[extra_goodwill_for] = float(gw.get(extra_goodwill_for, 0.0)) + GOODWILL
		(c.get("committed", {}) as Dictionary).erase(extra_goodwill_for)
	return c

## Voto que daría `party_id` si la ley incorporase estos cambios y los hubiera aceptado él.
func outlook(law: Dictionary, party_id: String, terms: Array) -> String:
	var sim := _clone(law, terms, party_id)
	return str(m.laws.stance(sim, party_id)["vote"])

func _lacks(law: Dictionary) -> bool:
	var fc := m.laws.forecast(law)
	return not m.laws.passes(law, int(fc["yes"]), int(fc["no"]))

# ---------------------------------------------------------------- la IA enmienda tus leyes
func _generate_offers(law: Dictionary) -> void:
	var st := state(law)
	var lacks := _lacks(law)
	var ids: Array = m.gov.parliamentary_ids().duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool: return m.seats_of(a) > m.seats_of(b))
	var made := 0
	for id in ids:
		var pid := str(id)
		if m.is_player(pid) or made >= AI_MAX_OFFERS or m.seats_of(pid) < 3:
			continue
		var rng := _rng(law, pid, "offer")
		var sp: Dictionary = m.laws.stance(law, pid)
		var vote := str(sp["vote"])
		var aff := m.ai.affinity(pid, m.pid())
		var opts := options_for(law, pid)
		if opts.is_empty():
			continue
		var terms: Array = []
		var reason := ""
		var prob := 0.0
		if aff >= 0.5:
			for o in opts:
				if str((o as Dictionary)["type"]) == "intensify":
					terms = [o]
					reason = "corta"
					break
			if terms.is_empty():
				for o2 in opts:
					if str((o2 as Dictionary)["type"]) in ["soften", "drop"]:
						terms = [o2]
						reason = "abusiva"
						break
			prob = 0.62
			if vote == "yes" and reason == "abusiva":
				prob = 0.22
		elif vote != "yes":
			for o3 in opts:
				if str((o3 as Dictionary)["type"]) in ["soften", "drop"] and terms.size() < 2:
					terms.append(o3)
			if terms.is_empty():
				for o4 in opts:
					if str((o4 as Dictionary)["type"]) == "add":
						terms = [o4]
						break
			reason = "apoyo"
			prob = 0.85 if lacks else 0.3
		if terms.is_empty() or rng.randf() > prob:
			continue
		var out := outlook(law, pid, terms)
		if out == "no":
			continue
		var seq := int(st["seq"]) + 1
		st["seq"] = seq
		(st["offers"] as Array).append({"id": seq, "from": pid, "terms": terms, "reason": reason, "vote_if": out, "status": "open", "line": _offer_line(pid, reason, terms, out)})
		made += 1

func _offer_line(pid: String, reason: String, terms: Array, vote_if: String) -> String:
	var first: Dictionary = terms[0]
	var nm := str(Policies.measure(str(first["measure"])).get("name", ""))
	var give := "votaremos a favor" if vote_if == "yes" else "nos abstendremos"
	match reason:
		"corta": return "Vuestra ley se queda corta en «%s». Si vais más lejos, %s." % [nm, give]
		"abusiva": return "Nos parece excesivo lo de «%s». Moderadlo y %s." % [nm, give]
	return "No podemos apoyarla tal cual. Con este cambio, %s." % give

func _offer(law: Dictionary, offer_id: int) -> Dictionary:
	for o in offers(law):
		if int((o as Dictionary)["id"]) == offer_id:
			return o
	return {}

## Aceptas la oferta: los cambios entran en el texto y el grupo se compromete a votar lo ofrecido.
func accept(law: Dictionary, offer_id: int) -> Dictionary:
	var o := _offer(law, offer_id)
	if o.is_empty() or str(o["status"]) != "open":
		return {"ok": false, "text": "La enmienda ya no está sobre la mesa."}
	var pid := str(o["from"])
	var terms: Array = o["terms"]
	var vote := outlook(law, pid, terms)
	for t in terms:
		_apply_term(law, t as Dictionary)
	var gw: Dictionary = law["goodwill"]
	gw[pid] = float(gw.get(pid, 0.0)) + GOODWILL
	if vote == "no":
		vote = "abstain"
	var cm: Dictionary = law.get("committed", {})
	cm[pid] = vote
	law["committed"] = cm
	o["status"] = "accepted"
	o["vote_if"] = vote
	m.ai.change_relation(pid, 2.0)
	_obsolete(law, terms, offer_id)
	var txt := "Aceptas la enmienda de %s: %s votará %s." % [m.party_short(pid), m.party_short(pid), "a favor" if vote == "yes" else "abstención"]
	_log(law, pid, str(law.get("proposer", "")), true, txt)
	return {"ok": true, "text": txt, "vote": vote}

## Aceptas solo la primera parte de la oferta: puede que se avengan a abstenerse.
func counter(law: Dictionary, offer_id: int) -> Dictionary:
	var o := _offer(law, offer_id)
	if o.is_empty() or str(o["status"]) != "open":
		return {"ok": false, "text": "La enmienda ya no está sobre la mesa."}
	var pid := str(o["from"])
	var terms: Array = o["terms"]
	var first: Array = [terms[0]]
	var out := outlook(law, pid, first)
	var flex := 0.30 + (m.ai.relation(pid) - 50.0) / 200.0 + (0.22 if _lacks(law) else 0.0)
	var rng := _rng(law, pid, "counter")
	if out != "no" and rng.randf() < flex:
		_apply_term(law, first[0] as Dictionary)
		var gw: Dictionary = law["goodwill"]
		gw[pid] = float(gw.get(pid, 0.0)) + GOODWILL * 0.5
		var cm: Dictionary = law.get("committed", {})
		cm[pid] = "abstain"
		law["committed"] = cm
		o["status"] = "accepted"
		o["vote_if"] = "abstain"
		o["partial"] = true
		_obsolete(law, first, offer_id)
		var txt := "%s acepta tu contraoferta, pero solo se abstendrá." % m.party_short(pid)
		_log(law, pid, str(law.get("proposer", "")), true, txt)
		return {"ok": true, "text": txt, "vote": "abstain"}
	o["status"] = "rejected"
	m.ai.change_relation(pid, -1.0)
	var txt2 := "%s rechaza tu contraoferta: o todo o nada." % m.party_short(pid)
	_log(law, pid, str(law.get("proposer", "")), false, txt2)
	return {"ok": false, "text": txt2}

func reject(law: Dictionary, offer_id: int) -> Dictionary:
	var o := _offer(law, offer_id)
	if o.is_empty() or str(o["status"]) != "open":
		return {"ok": false, "text": ""}
	o["status"] = "rejected"
	var pid := str(o["from"])
	m.ai.change_relation(pid, -0.5)
	var txt := "Rechazas la enmienda de %s." % m.party_short(pid)
	_log(law, pid, str(law.get("proposer", "")), false, txt)
	return {"ok": true, "text": txt}

func _obsolete(law: Dictionary, terms: Array, except_id: int) -> void:
	var touched: Array = []
	for t in terms:
		touched.append(str((t as Dictionary)["measure"]))
	for o in offers(law):
		var od: Dictionary = o
		if int(od["id"]) == except_id or str(od["status"]) != "open":
			continue
		for t2 in od["terms"]:
			if touched.has(str((t2 as Dictionary)["measure"])):
				od["status"] = "obsolete"
				break

# ---------------------------------------------------------------- tú enmiendas las leyes de la IA
## Qué enmiendas te convienen (de más a menos), con la mejora que suponen para tu postura.
func player_options(law: Dictionary) -> Array:
	var out: Array = []
	var base := m.laws.raw_score(law, m.pid())
	for t in options_for(law, m.pid()):
		var term: Dictionary = (t as Dictionary).duplicate(true)
		var gain := m.laws.raw_score(_clone(law, [term]), m.pid()) - base
		if gain < 0.015:
			continue
		term["gain"] = gain
		out.append(term)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["gain"]) > float(b["gain"]))
	return out.slice(0, 6)

# ---------------------------------------------------------------- enmiendas libres del jugador
## Valor que tiene la medida en la ley (o el vigente si la ley no la toca).
func value_in_law(law: Dictionary, mid: String) -> float:
	return float((law["changes"] as Dictionary).get(mid, m.eco.value(mid)))

## Convierte el valor que elige el jugador en una enmienda: añadir, ampliar, suavizar o retirar. Vacío si no cambia nada.
func make_term(law: Dictionary, mid: String, value: float) -> Dictionary:
	var meas := Policies.measure(mid)
	if meas.is_empty() or Policies.is_special(mid):
		return {}
	var cur := m.eco.value(mid)
	var here := value_in_law(law, mid)
	var v := Policies.snap(meas, value)
	if is_equal_approx(v, here):
		return {}
	var type := "add"
	if (law["changes"] as Dictionary).has(mid):
		if is_equal_approx(v, cur):
			type = "drop"
		else:
			type = "intensify" if absf(v - cur) > absf(here - cur) else "soften"
	return _term(type, mid, v, 0.0, 1.0)

## Qué supone la enmienda: lo que ganas tú, lo que le cuesta al proponente y cómo la recibirá.
## verdict: accept (la admitirá), talk (querrá negociar) o reject (la rechazará).
func preview(law: Dictionary, term: Dictionary) -> Dictionary:
	if term.is_empty():
		return {}
	var proposer := str(law.get("proposer", ""))
	var mine := m.laws.raw_score(_clone(law, [term]), m.pid()) - m.laws.raw_score(law, m.pid())
	var theirs := m.laws.raw_score(_clone(law, [term]), proposer) - m.laws.raw_score(law, proposer)
	var tol := tolerance(law)
	var verdict := "reject"
	if theirs >= -tol:
		verdict = "accept"
	elif theirs >= -(tol + 0.35):
		verdict = "talk"
	return {"mine": mine, "theirs": theirs, "tol": tol, "verdict": verdict}

## Cuánto está dispuesto a ceder el proponente (cuanto más te necesite, más).
func tolerance(law: Dictionary) -> float:
	var proposer := str(law.get("proposer", ""))
	var fc := m.laws.forecast(law)
	var pid := m.pid()
	var ps := m.seats_of(pid)
	var pv := str((fc["by_party"] as Dictionary).get(pid, "abstain"))
	var yes := int(fc["yes"]) - (ps if pv == "yes" else 0)
	var no := int(fc["no"]) - (ps if pv == "no" else 0)
	var tol := 0.12
	if m.laws.passes(law, yes, no + ps):
		tol = 0.03
	elif m.laws.passes(law, yes + ps, no):
		tol = 0.30
	tol += (m.ai.relation(proposer) - 50.0) / 250.0
	return clampf(tol, 0.0, 0.6)

func _midpoint(law: Dictionary, term: Dictionary) -> Dictionary:
	var mid := str(term["measure"])
	var meas := Policies.measure(mid)
	var cur := m.eco.value(mid)
	var here := float((law["changes"] as Dictionary).get(mid, cur))
	var v := Policies.snap(meas, here + (float(term["value"]) - here) * 0.5)
	if is_equal_approx(v, here):
		return {}
	var t := _term("soften" if str(term["type"]) in ["drop", "soften"] else str(term["type"]), mid, v, float(term.get("s", 0.0)), float(term.get("w", 1.0)))
	t["text"] = "Transaccional: %s" % str(t["text"])
	return t

## Presentas una enmienda a una ley ajena. Devuelve {ok, verdict: accepted|counter|rejected, text}.
func propose(law: Dictionary, term: Dictionary) -> Dictionary:
	if slots_left(law) <= 0:
		return {"ok": false, "verdict": "none", "text": "Ya has agotado tus enmiendas para esta ley."}
	var st := state(law)
	st["used"] = int(st["used"]) + 1
	var proposer := str(law.get("proposer", ""))
	var short := m.party_short(proposer)
	var before := m.laws.raw_score(law, proposer)
	var tol := tolerance(law)
	var delta := m.laws.raw_score(_clone(law, [term]), proposer) - before
	if delta >= -tol:
		_apply_term(law, term)
		m.ai.change_relation(proposer, 1.0)
		var txt := "%s acepta tu enmienda: %s." % [short, str(term["text"]).to_lower()]
		_log(law, m.pid(), proposer, true, txt)
		return {"ok": true, "verdict": "accepted", "text": txt}
	if delta >= -(tol + 0.35):
		var mid_t := _midpoint(law, term)
		if not mid_t.is_empty():
			var d2 := m.laws.raw_score(_clone(law, [mid_t]), proposer) - before
			if d2 >= -(tol * 1.5 + 0.04):
				(st["counters"] as Array).append(mid_t)
				var txt2 := "%s no acepta tu enmienda tal cual, pero propone una transaccional." % short
				_log(law, m.pid(), proposer, false, txt2)
				return {"ok": true, "verdict": "counter", "text": txt2, "counter": mid_t}
	m.ai.change_relation(proposer, -0.3)
	var why := "No necesitamos vuestros votos para sacarla adelante." if tol <= 0.06 else "Eso desvirtúa nuestra ley."
	var txt3 := "%s rechaza tu enmienda. %s" % [short, why]
	_log(law, m.pid(), proposer, false, txt3)
	return {"ok": false, "verdict": "rejected", "text": txt3}

func accept_counter(law: Dictionary, idx: int) -> Dictionary:
	var list := counters(law)
	if idx < 0 or idx >= list.size():
		return {"ok": false, "text": ""}
	var t: Dictionary = list[idx]
	_apply_term(law, t)
	list.remove_at(idx)
	var proposer := str(law.get("proposer", ""))
	m.ai.change_relation(proposer, 1.0)
	var txt := "Aceptas la transaccional de %s." % m.party_short(proposer)
	_log(law, m.pid(), proposer, true, txt)
	return {"ok": true, "text": txt}

func dismiss_counter(law: Dictionary, idx: int) -> void:
	var list := counters(law)
	if idx >= 0 and idx < list.size():
		list.remove_at(idx)

# ---------------------------------------------------------------- la IA se enmienda entre sí
func _ai_vs_ai(law: Dictionary) -> void:
	var proposer := str(law.get("proposer", ""))
	var ids: Array = m.gov.parliamentary_ids().duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool: return m.seats_of(a) > m.seats_of(b))
	var done := 0
	for id in ids:
		var pid := str(id)
		if m.is_player(pid) or pid == proposer or m.seats_of(pid) < 6 or done >= 2:
			continue
		var rng := _rng(law, pid, "ai")
		if rng.randf() > 0.55:
			continue
		var term: Dictionary = {}
		for o in options_for(law, pid):
			if str((o as Dictionary)["type"]) != "add":
				term = o
				break
		if term.is_empty():
			continue
		var out := outlook(law, pid, [term])
		if out == "no":
			continue
		var before := m.laws.raw_score(law, proposer)
		var delta := m.laws.raw_score(_clone(law, [term]), proposer) - before
		var tol := 0.08 + 0.3 * minf(1.0, float(m.seats_of(pid)) / 120.0)
		if delta >= -tol:
			_apply_term(law, term)
			var gw: Dictionary = law["goodwill"]
			gw[pid] = float(gw.get(pid, 0.0)) + GOODWILL
			var cm: Dictionary = law.get("committed", {})
			cm[pid] = out
			law["committed"] = cm
			_log(law, pid, proposer, true, "%s enmienda y %s acepta: %s." % [m.party_short(pid), m.party_short(proposer), str(term["text"]).to_lower()])
			done += 1
		else:
			_log(law, pid, proposer, false, "%s propone «%s» y %s lo rechaza." % [m.party_short(pid), str(Policies.measure(str(term["measure"])).get("name", "")), m.party_short(proposer)])
			done += 1

# ---------------------------------------------------------------- explicación de voto
const LINES := {
	"yes": ["Votamos a favor: «%s» va en la buena dirección.", "Sí. «%s» era una de nuestras prioridades.", "Apoyamos esta ley, sobre todo por «%s»."],
	"no": ["Votamos en contra: no podemos aceptar «%s».", "No. «%s» es inasumible para nosotros.", "Rechazamos la ley por «%s»."],
	"abstain": ["Nos abstenemos: «%s» no termina de convencernos.", "Abstención. Hay cosas buenas, pero «%s» nos frena.", "Ni a favor ni en contra: «%s» está a medias."],
}
const GENERIC := {
	"yes": ["Votamos a favor.", "Apoyamos la iniciativa.", "Sí, con convicción."],
	"no": ["Votamos en contra.", "No contarán con nuestro voto.", "Rechazamos la propuesta."],
	"abstain": ["Nos abstenemos.", "Abstención, por ahora.", "Ni sí ni no: nos abstenemos."],
}

## Frase corta con la que un grupo explica su voto (se muestra durante la votación animada).
func vote_line(law: Dictionary, party_id: String, vote: String) -> String:
	var proposer := str(law.get("proposer", ""))
	if party_id == proposer:
		return "Defendemos nuestra propuesta."
	var committed: Dictionary = law.get("committed", {})
	if committed.has(party_id) and str(committed[party_id]) == vote:
		return "Cumplimos lo acordado en las enmiendas."
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_%s" % [str(law["id"]), party_id, vote])
	var st: Dictionary = m.laws.stance(law, party_id)
	var best := ""
	var bv := 0.0
	for it in st.get("items", []):
		var d: Dictionary = it
		var v := absf(float(d["s"])) * float(d["w"])
		var s_ok := (vote == "yes" and float(d["s"]) > 0.0) or (vote == "no" and float(d["s"]) < 0.0) or vote == "abstain"
		if s_ok and v > bv and not Policies.is_special(str(d["measure"])):
			bv = v
			best = str(Policies.measure(str(d["measure"])).get("name", ""))
	if best == "" or str(law.get("kind", "")) == "presupuestos":
		var g: Array = GENERIC[vote]
		return str(g[rng.randi() % g.size()])
	var tpl: Array = LINES[vote]
	return str(tpl[rng.randi() % tpl.size()]) % best
