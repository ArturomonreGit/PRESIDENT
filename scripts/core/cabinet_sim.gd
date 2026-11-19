class_name CabinetSim
extends RefCounted
## Gabinete vivo: constructor dinámico de ministerios (8-20, competencias por etiquetas, crear/renombrar/eliminar/
## fusionar/dividir), estado de gestión y acciones presidenciales sobre los ministros. Las carteras son las mismas
## entradas de `m.gov.cabinet()`: aquí solo se amplían con id estable, competencias, autonomía y prioridad.

var m: GameModel

const CHANGE_COST := 3.0
const ACTION_COST := {"convene": 1.0, "instruct": 1.0, "back": 0.0, "disown": 0.0, "rebuke": 0.0, "limit": 0.0, "plan": 1.0, "ask_resign": 1.0, "fire": 3.0, "swap": 2.0, "replace": 2.0}
const AUTONOMY := ["plena", "limitada", "supervisada"]
const AUTONOMY_NAMES := {"plena": "Autonomía plena", "limitada": "Autonomía limitada", "supervisada": "Supervisada"}
const AUTONOMY_FACTOR := {"plena": 1.0, "limitada": 0.5, "supervisada": 0.2}

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	return m.d("cab")

func list() -> Array:
	return m.gov.cabinet()

func size() -> int:
	return list().size()

func gov_id() -> String:
	return str(m.s.get("government_party_id", ""))

## Garantiza id estable, competencias y valores por defecto en todas las carteras (también en partidas antiguas).
func ensure() -> void:
	var seq := int(st().get("seq", 0))
	var fresh := false
	var taken: Dictionary = {}
	for e in list():
		var ed: Dictionary = e
		for c in ed.get("comps", []):
			taken[str(c)] = true
	for e in list():
		var ed: Dictionary = e
		if not ed.has("id"):
			seq += 1
			ed["id"] = "mn_%d" % seq
		if not ed.has("key"):
			ed["key"] = str(ed.get("name", ""))
		if not ed.has("comps"):
			fresh = true
			var cs: Array = []
			for c in Competencies.defaults_for(str(ed["key"])):
				if not taken.has(str(c)):
					cs.append(str(c))
					taken[str(c)] = true
			ed["comps"] = cs
		if not ed.has("shared"):
			ed["shared"] = []
		if not ed.has("desc"):
			ed["desc"] = ""
		if not ed.has("autonomy"):
			ed["autonomy"] = "plena"
	st()["seq"] = seq
	if fresh:
		_adopt_essentials(taken)

## Un Consejo recién formado no deja competencias esenciales huérfanas: las asume la cartera más afín (del mismo ámbito).
func _adopt_essentials(taken: Dictionary) -> void:
	for cid in Competencies.essentials():
		if taken.has(str(cid)):
			continue
		var cat := str(Competencies.by_id(str(cid)).get("cat", ""))
		var best := -1
		var best_n := 999
		for i in range(size()):
			var cs: Array = comps_of(i)
			var same := false
			for c in cs:
				if str(Competencies.by_id(str(c)).get("cat", "")) == cat:
					same = true
			if same and cs.size() < best_n:
				best_n = cs.size()
				best = i
		if best >= 0:
			comps_of(best).append(str(cid))
			taken[str(cid)] = true

func _next_id() -> String:
	var seq := int(st().get("seq", 0)) + 1
	st()["seq"] = seq
	return "mn_%d" % seq

func entry(idx: int) -> Dictionary:
	var l := list()
	return l[idx] if idx >= 0 and idx < l.size() else {}

func idx_of(id: String) -> int:
	var l := list()
	for i in range(l.size()):
		if str((l[i] as Dictionary).get("id", "")) == id:
			return i
	return -1

func minister(idx: int) -> Dictionary:
	return (entry(idx).get("minister", {}) as Dictionary)

# ---------------------------------------------------------------- permisos
## El jugador es el presidente y el Gobierno está en formación o en funciones.
func can_edit() -> bool:
	return gov_id() == m.pid() and m.phase in ["cabinet_design", "legislature"]

## En legislatura, las carteras de un socio son suyas por acuerdo: el presidente no puede quitárselas ni cesar a su titular.
func is_reserved(idx: int) -> bool:
	var e := entry(idx)
	return m.phase == "legislature" and not e.is_empty() and str(e.get("party", "")) != gov_id()

func structural_cost() -> float:
	return 0.0 if m.phase == "cabinet_design" else CHANGE_COST

func _pay(cost: float) -> String:
	if cost <= 0.0:
		return ""
	m.exec.ensure()
	if m.exec.capital() < cost:
		return "Capital político insuficiente (%d necesario)." % int(ceilf(cost))
	m.exec.add_capital(-cost)
	return ""

func _fail(text: String) -> Dictionary:
	return {"ok": false, "error": text}

# ---------------------------------------------------------------- competencias
func owner_of(comp_id: String) -> int:
	var l := list()
	for i in range(l.size()):
		if ((l[i] as Dictionary).get("comps", []) as Array).has(comp_id):
			return i
	return -1

func comps_of(idx: int) -> Array:
	return (entry(idx).get("comps", []) as Array)

func shared_of(idx: int) -> Array:
	return (entry(idx).get("shared", []) as Array)

func comp_names(idx: int, limit: int = 3) -> String:
	var names: Array = []
	for c in comps_of(idx):
		names.append(Competencies.name_of(str(c)))
	if names.is_empty():
		return "Sin competencias"
	var shown := names.slice(0, limit)
	var txt := ", ".join(shown)
	if names.size() > limit:
		txt += " (+%d)" % (names.size() - limit)
	return txt

## Conflictos al asignar competencias a una cartera: las que ya gestiona otra.
func conflicts_for(idx: int, comps: Array) -> Array:
	var out: Array = []
	for c in comps:
		var o := owner_of(str(c))
		if o >= 0 and o != idx:
			out.append({"comp": str(c), "owner": o, "owner_name": str(entry(o).get("name", "")), "reserved": is_reserved(o)})
	return out

## Fija las competencias principales de una cartera. Con `take` las quita a quien las gestionaba.
func set_comps(idx: int, comps: Array, take: bool = false) -> Dictionary:
	if not can_edit() or idx < 0 or idx >= size():
		return _fail("Solo el presidente puede reorganizar las competencias.")
	if is_reserved(idx):
		return _fail("Esta cartera está reservada a su partido por el acuerdo de coalición.")
	if m.agr.pledge_text(idx) != "":
		return _fail(m.agr.pledge_text(idx))
	var conf := conflicts_for(idx, comps)
	for cf in conf:
		if bool((cf as Dictionary)["reserved"]):
			return _fail("«%s» es una competencia reservada al socio que gestiona «%s»." % [Competencies.name_of(str((cf as Dictionary)["comp"])), str((cf as Dictionary)["owner_name"])])
	if not conf.is_empty() and not take:
		return {"ok": false, "error": "Hay competencias que ya gestiona otra cartera.", "conflicts": conf}
	var cur: Array = comps_of(idx).duplicate()
	var new_list: Array = []
	for c in comps:
		if Competencies.exists(str(c)) and not new_list.has(str(c)):
			new_list.append(str(c))
	if new_list.size() == cur.size() and cur.all(func(c) -> bool: return new_list.has(c)):
		return {"ok": true, "changed": false}
	var err := _pay(structural_cost())
	if err != "":
		return _fail(err)
	for cf2 in conf:
		var oi := int((cf2 as Dictionary)["owner"])
		var oc: Array = comps_of(oi)
		oc.erase(str((cf2 as Dictionary)["comp"]))
	var e := entry(idx)
	e["comps"] = new_list
	var sh: Array = shared_of(idx)
	for c in new_list:
		sh.erase(c)
	_note("Competencias de «%s» actualizadas: %s." % [str(e["name"]), comp_names(idx, 6)])
	return {"ok": true, "changed": true}

func toggle_comp(idx: int, comp_id: String, take: bool = false) -> Dictionary:
	var cur: Array = comps_of(idx).duplicate()
	if cur.has(comp_id):
		cur.erase(comp_id)
	else:
		cur.append(comp_id)
	return set_comps(idx, cur, take)

func toggle_shared(idx: int, comp_id: String) -> Dictionary:
	if not can_edit() or idx < 0 or idx >= size():
		return _fail("Solo el presidente puede reorganizar las competencias.")
	var o := owner_of(comp_id)
	if o < 0 or o == idx:
		return _fail("Una competencia compartida debe tener otro responsable principal.")
	var sh: Array = shared_of(idx)
	if sh.has(comp_id):
		sh.erase(comp_id)
	else:
		sh.append(comp_id)
	return {"ok": true}

# ---------------------------------------------------------------- constructor
func rename(idx: int, new_name: String) -> void:
	var e := entry(idx)
	var n := new_name.strip_edges()
	if not e.is_empty() and n != "" and not is_reserved(idx):
		e["name"] = n

func set_desc(idx: int, text: String) -> void:
	var e := entry(idx)
	if not e.is_empty():
		e["desc"] = text.strip_edges()

func create(new_name: String, comps: Array, party_id: String = "", take: bool = false) -> Dictionary:
	ensure()
	if not can_edit():
		return _fail("Solo el presidente del Gobierno puede crear ministerios.")
	if size() >= Competencies.MAX_MINISTRIES:
		return _fail("El Gobierno no puede tener más de %d ministerios." % Competencies.MAX_MINISTRIES)
	if m.agr.size_block(true) != "":
		return _fail(m.agr.size_block(true))
	var pid := party_id if party_id != "" else gov_id()
	if not m.gov.government_parties().has(pid):
		return _fail("Ese partido no forma parte del Gobierno.")
	if m.phase == "legislature" and pid != gov_id():
		return _fail("Las carteras de un socio se acuerdan en la mesa de coalición.")
	var n := new_name.strip_edges()
	if n == "":
		n = Competencies.suggest_name(comps)
	var conf := conflicts_for(-1, comps)
	for cf in conf:
		if bool((cf as Dictionary)["reserved"]):
			return _fail("«%s» es una competencia reservada a un socio." % Competencies.name_of(str((cf as Dictionary)["comp"])))
	if not conf.is_empty() and not take:
		return {"ok": false, "error": "Hay competencias que ya gestiona otra cartera.", "conflicts": conf}
	var err := _pay(structural_cost())
	if err != "":
		return _fail(err)
	for cf2 in conf:
		comps_of(int((cf2 as Dictionary)["owner"])).erase(str((cf2 as Dictionary)["comp"]))
	var id := _next_id()
	var cs: Array = []
	for c in comps:
		if Competencies.exists(str(c)) and not cs.has(str(c)):
			cs.append(str(c))
	list().append({"id": id, "name": n, "key": "custom:" + id, "party": pid, "desc": "", "comps": cs, "shared": [], "autonomy": "plena"})
	m.ministers.ensure_cabinet()
	_note("Se crea el ministerio «%s»." % n)
	m.publish("Nuevo ministerio: %s" % n, "El Gobierno crea la cartera de %s, que gestionará: %s." % [n, comp_names(size() - 1, 6)], "GOBIERNO", "neutral")
	return {"ok": true, "index": size() - 1}

## Efectos de eliminar o fusionar una cartera: competencias, políticas, presupuesto y titular afectados.
func impact(idx: int) -> Dictionary:
	var e := entry(idx)
	if e.is_empty():
		return {}
	var areas: Array = []
	for aid in m.exec.areas_of(idx):
		areas.append(str(Policies.area(str(aid)).get("name", aid)))
	var lines: Array = m.exec.lines_of(idx)
	var essential: Array = []
	for c in comps_of(idx):
		if Competencies.essentials().has(str(c)):
			essential.append(Competencies.name_of(str(c)))
	var mn := minister(idx)
	return {"name": str(e["name"]), "comps": comps_of(idx).duplicate(), "areas": areas, "lines": lines, "budget": budget_of(idx),
		"essential": essential, "minister": Leader.full_name(mn) if not mn.is_empty() else "", "party": str(e["party"])}

func impact_text(idx: int) -> String:
	var im := impact(idx)
	if im.is_empty():
		return ""
	var bits: Array = []
	bits.append("Competencias que cambian de manos: %s." % comp_names(idx, 8))
	if not (im["areas"] as Array).is_empty():
		bits.append("Políticas afectadas: %s." % ", ".join(im["areas"]))
	bits.append("Presupuesto que gestiona: %.1f mM€ en %d partidas." % [float(im["budget"]), (im["lines"] as Array).size()])
	if str(im["minister"]) != "":
		bits.append("%s dejará la cartera y perderá su cargo." % str(im["minister"]))
	if not (im["essential"] as Array).is_empty():
		bits.append("Incluye competencias esenciales: %s." % ", ".join(im["essential"]))
	return " ".join(bits)

func budget_of(idx: int) -> float:
	var total := 0.0
	for lid in m.exec.lines_of(idx):
		total += m.eco.budget_spending(str(lid))
	return total

func _fix_post(removed: int) -> void:
	var e := m.exec.st()
	if not e.has("post"):
		return
	var p := int(e["post"])
	if p == removed:
		e["post"] = -1
	elif p > removed:
		e["post"] = p - 1

func _default_heir(idx: int) -> int:
	var party_id := str(entry(idx).get("party", ""))
	var best := -1
	var best_n := -1
	for i in range(size()):
		if i == idx or str(entry(i).get("party", "")) != party_id:
			continue
		var n := comps_of(i).size()
		if "presidencia" in comps_of(i):
			return i
		if n > best_n:
			best_n = n
			best = i
	return best

func delete(idx: int, heir: int = -1) -> Dictionary:
	if not can_edit() or idx < 0 or idx >= size():
		return _fail("Solo el presidente puede eliminar ministerios.")
	if is_reserved(idx):
		return _fail("Esta cartera está reservada a su partido por el acuerdo de coalición.")
	if size() <= Competencies.MIN_MINISTRIES:
		return _fail("El Gobierno necesita al menos %d ministerios." % Competencies.MIN_MINISTRIES)
	if m.agr.pledge_text(idx) != "":
		return _fail(m.agr.pledge_text(idx))
	if m.agr.size_block(false) != "":
		return _fail(m.agr.size_block(false))
	if not comps_of(idx).is_empty() or not shared_of(idx).is_empty():
		if heir < 0:
			heir = _default_heir(idx)
		if heir < 0 or heir == idx:
			return _fail("Hace falta otra cartera de su partido que herede sus competencias.")
	var e := entry(idx)
	var gone_name := str(e["name"])
	var err := _pay(structural_cost())
	if err != "":
		return _fail(err)
	var mn := minister(idx)
	if not mn.is_empty():
		m.ministers.log_history(mn, "Cesado/a por la supresión de %s." % gone_name)
		m.ministers.shift_relation(mn, -10.0)
	if heir >= 0:
		var hc: Array = comps_of(heir)
		for c in comps_of(idx):
			if not hc.has(c):
				hc.append(c)
		for c in shared_of(idx):
			if not shared_of(heir).has(c) and not hc.has(c):
				shared_of(heir).append(c)
	list().remove_at(idx)
	_fix_post(idx)
	_note("Se suprime el ministerio «%s»." % gone_name)
	m.publish("Se suprime un ministerio", "Desaparece «%s»; sus competencias pasan a otra cartera." % gone_name, "GOBIERNO", "neutral")
	if m.phase == "legislature":
		m.gov.shift_government_approval(-0.3)
	return {"ok": true}

func merge(a: int, b: int, new_name: String = "") -> Dictionary:
	if not can_edit() or a == b or a < 0 or b < 0 or a >= size() or b >= size():
		return _fail("Elige dos ministerios distintos.")
	if is_reserved(a) or is_reserved(b):
		return _fail("No se pueden fusionar carteras reservadas a un socio.")
	if m.agr.pledge_text(a) != "" or m.agr.pledge_text(b) != "":
		return _fail(m.agr.pledge_text(a) if m.agr.pledge_text(a) != "" else m.agr.pledge_text(b))
	if m.agr.size_block(false) != "":
		return _fail(m.agr.size_block(false))
	if str(entry(a)["party"]) != str(entry(b)["party"]):
		return _fail("Solo se fusionan carteras del mismo partido.")
	if size() <= Competencies.MIN_MINISTRIES:
		return _fail("El Gobierno necesita al menos %d ministerios." % Competencies.MIN_MINISTRIES)
	var err := _pay(structural_cost())
	if err != "":
		return _fail(err)
	var ea := entry(a)
	var eb := entry(b)
	var ac: Array = comps_of(a)
	for c in comps_of(b):
		if not ac.has(c):
			ac.append(c)
	for c in shared_of(b):
		if not ac.has(c) and not shared_of(a).has(c):
			shared_of(a).append(c)
	var old_names := "%s y %s" % [str(ea["name"]), str(eb["name"])]
	ea["name"] = new_name.strip_edges() if new_name.strip_edges() != "" else str(ea["name"])
	var mn := minister(b)
	if not mn.is_empty():
		m.ministers.log_history(mn, "Cesado/a por la fusión de %s." % old_names)
	list().remove_at(b)
	_fix_post(b)
	var ni := idx_of(str(ea["id"]))
	_note("Se fusionan %s en «%s»." % [old_names, str(ea["name"])])
	m.publish("Fusión de ministerios", "%s pasan a ser «%s»." % [old_names, str(ea["name"])], "GOBIERNO", "neutral")
	return {"ok": true, "index": ni}

func split(idx: int, moved: Array, new_name: String = "") -> Dictionary:
	if not can_edit() or idx < 0 or idx >= size():
		return _fail("Solo el presidente puede dividir ministerios.")
	if is_reserved(idx):
		return _fail("Esta cartera está reservada a su partido por el acuerdo de coalición.")
	if size() >= Competencies.MAX_MINISTRIES:
		return _fail("El Gobierno no puede tener más de %d ministerios." % Competencies.MAX_MINISTRIES)
	if m.agr.size_block(true) != "":
		return _fail(m.agr.size_block(true))
	if m.agr.pledge_text(idx) != "":
		return _fail(m.agr.pledge_text(idx))
	var src: Array = comps_of(idx)
	var take: Array = []
	for c in moved:
		if src.has(c) and not take.has(c):
			take.append(c)
	if take.is_empty() or take.size() >= src.size():
		return _fail("Elige algunas competencias (no todas) para la nueva cartera.")
	var err := _pay(structural_cost())
	if err != "":
		return _fail(err)
	for c in take:
		src.erase(c)
	var id := _next_id()
	var n := new_name.strip_edges() if new_name.strip_edges() != "" else Competencies.suggest_name(take)
	list().append({"id": id, "name": n, "key": "custom:" + id, "party": str(entry(idx)["party"]), "desc": "", "comps": take, "shared": [], "autonomy": "plena"})
	m.ministers.ensure_cabinet()
	_note("«%s» se divide: nace «%s»." % [str(entry(idx)["name"]), n])
	m.publish("División de un ministerio", "«%s» cede parte de sus competencias a la nueva cartera «%s»." % [str(entry(idx)["name"]), n], "GOBIERNO", "neutral")
	return {"ok": true, "index": size() - 1}

## Cambia el partido responsable de una cartera. En formación es libre; en legislatura solo lo permite un pacto.
func assign_party(idx: int, party_id: String, by_agreement: bool = false) -> Dictionary:
	var e := entry(idx)
	if e.is_empty() or not m.gov.government_parties().has(party_id):
		return _fail("Partido no válido.")
	if m.phase == "legislature" and not by_agreement:
		return _fail("En legislatura las carteras solo cambian de partido por acuerdo en la mesa de coalición.")
	if str(e.get("party", "")) != party_id:
		e.erase("minister")
		e["party"] = party_id
		m.ministers.ensure_cabinet()
	return {"ok": true}

# ---------------------------------------------------------------- alertas y validación
func alerts() -> Array:
	var out: Array = []
	var n := size()
	if n < Competencies.MIN_MINISTRIES:
		out.append({"level": "bad", "text": "Faltan ministerios: hay %d y el mínimo es %d." % [n, Competencies.MIN_MINISTRIES]})
	elif n > Competencies.MAX_MINISTRIES:
		out.append({"level": "bad", "text": "Sobran ministerios: hay %d y el máximo es %d." % [n, Competencies.MAX_MINISTRIES]})
	var owners: Dictionary = {}
	for i in range(n):
		for c in comps_of(i):
			if owners.has(str(c)):
				out.append({"level": "bad", "text": "«%s» tiene dos responsables principales: %s y %s." % [Competencies.name_of(str(c)), str(entry(int(owners[str(c)]))["name"]), str(entry(i)["name"])]})
			owners[str(c)] = i
	for c in Competencies.essentials():
		if not owners.has(str(c)):
			out.append({"level": "warn", "text": "Competencia esencial sin responsable: %s. La asume provisionalmente otra cartera." % Competencies.name_of(str(c)), "comp": str(c)})
	for i in range(n):
		var e := entry(i)
		if comps_of(i).is_empty():
			out.append({"level": "warn", "text": "«%s» no tiene competencias: es un ministerio vacío." % str(e["name"]), "ministry": str(e["id"])})
		elif comps_of(i).size() > Competencies.BROAD_LIMIT:
			out.append({"level": "warn", "text": "«%s» es excesivamente amplio (%d competencias): su titular dispersa el esfuerzo." % [str(e["name"]), comps_of(i).size()], "ministry": str(e["id"])})
	return out

func validate() -> Dictionary:
	var n := size()
	if n < Competencies.MIN_MINISTRIES or n > Competencies.MAX_MINISTRIES:
		return {"ok": false, "error": "El Consejo debe tener entre %d y %d ministerios (ahora %d)." % [Competencies.MIN_MINISTRIES, Competencies.MAX_MINISTRIES, n]}
	var seen: Dictionary = {}
	for i in range(n):
		for c in comps_of(i):
			if seen.has(str(c)):
				return {"ok": false, "error": "«%s» tiene dos responsables principales." % Competencies.name_of(str(c))}
			seen[str(c)] = true
	return {"ok": true}

# ---------------------------------------------------------------- estado de gestión
func act_of(idx: int) -> float:
	var mn := minister(idx)
	return float(mn.get("act", 55.0)) if not mn.is_empty() else 40.0

func status(idx: int) -> Dictionary:
	var a := act_of(idx)
	if minister(idx).is_empty():
		return {"text": "Vacante", "tone": "bad", "value": a}
	if a >= 62.0:
		return {"text": "Gestión eficaz", "tone": "good", "value": a}
	if a >= 45.0:
		return {"text": "Gestión estable", "tone": "neutral", "value": a}
	if a >= 30.0:
		return {"text": "En dificultades", "tone": "warn", "value": a}
	return {"text": "En crisis", "tone": "bad", "value": a}

## Indicadores resumidos de una cartera: [{label, value, good}].
func metrics(idx: int, limit: int = 2) -> Array:
	var out: Array = []
	for aid in m.exec.areas_of(idx):
		var spec: Array = Executive.AREA_METRIC.get(str(aid), [])
		if spec.is_empty():
			continue
		var metric := str(spec[0])
		var dirn := int(spec[1])
		out.append({"label": m.exec.metric_label(metric), "value": m.exec._metric_now(metric), "good": need_of(metric, dirn) <= 0.3, "area": str(aid)})
		if out.size() >= limit:
			break
	return out

## Cuánto necesita atención un indicador (-1..1,5): positivo cuando va peor de lo deseable.
func need_of(metric: String, dirn: int) -> float:
	var z := m.world.any_z(metric)
	return clampf(z if dirn < 0 else -z, -1.0, 1.5)

func _z(metric: String) -> float:
	return m.world.any_z(metric)

# ---------------------------------------------------------------- acciones presidenciales
func _president_check(idx: int, action: String) -> String:
	if gov_id() != m.pid() or m.phase != "legislature":
		return "Solo el presidente del Gobierno puede hacerlo."
	if idx < 0 or idx >= size() or minister(idx).is_empty():
		return "Esa cartera no tiene titular."
	return ""

func _action_cost(action: String) -> String:
	return _pay(float(ACTION_COST.get(action, 0.0)))

func _partner_trust(idx: int, delta: float) -> void:
	var pid := str(entry(idx).get("party", ""))
	if pid != "" and pid != gov_id() and pid != m.pid():
		m.coal.shift_trust(pid, delta, "decisión sobre su ministro")

## Convocar al ministro y pedir explicaciones: la supervisión mejora su rendimiento y revela lo que ocurre en la cartera.
func convene(idx: int) -> Dictionary:
	var err := _president_check(idx, "convene")
	if err != "":
		return _fail(err)
	err = _action_cost("convene")
	if err != "":
		return _fail(err)
	var mn := minister(idx)
	var e := entry(idx)
	mn["act"] = clampf(float(mn.get("act", 55.0)) + 4.0, 0.0, 100.0)
	if m.ministers.attr(mn, "ambicion") >= 7:
		m.ministers.shift_relation(mn, -2.0)
	_partner_trust(idx, -1.0 if is_reserved(idx) else 0.0)
	var why := _diagnosis(idx)
	m.ministers.log_history(mn, "Convocado/a por el presidente para dar explicaciones.")
	return {"ok": true, "text": "Explicaciones de %s: %s" % [Leader.full_name(mn), why]}

func _diagnosis(idx: int) -> String:
	var mn := minister(idx)
	var bits: Array = []
	var sk := m.ministers.skill_in(idx)
	if sk < 5.0:
		bits.append("la cartera se le queda grande (competencia %.0f)" % sk)
	elif sk >= 7.5:
		bits.append("domina la cartera (competencia %.0f)" % sk)
	for mt in metrics(idx, 2):
		if not bool((mt as Dictionary)["good"]):
			bits.append("%s está en un nivel preocupante" % str((mt as Dictionary)["label"]).to_lower())
	if m.ministers.attr(mn, "integridad") <= 3:
		bits.append("hay dudas sobre su integridad")
	if m.ministers.relation(mn) < 35.0:
		bits.append("su relación con el presidente es mala")
	if bits.is_empty():
		bits.append("sin problemas relevantes")
	return "; ".join(bits) + "."

## Fija la prioridad de la cartera entre sus áreas: los avisos y propuestas del ministro se concentran en ella.
func instruct(idx: int, area_id: String) -> Dictionary:
	var err := _president_check(idx, "instruct")
	if err != "":
		return _fail(err)
	if not m.exec.areas_of(idx).has(area_id):
		return _fail("Esa área no es de este ministerio.")
	err = _action_cost("instruct")
	if err != "":
		return _fail(err)
	var e := entry(idx)
	e["priority"] = area_id
	var mn := minister(idx)
	var afin := m.ministers.attr(mn, "afinidad")
	m.ministers.shift_relation(mn, 1.0 if afin >= 5 else -2.0)
	m.ministers.log_history(mn, "Recibe la instrucción de priorizar %s." % str(Policies.area(area_id).get("name", area_id)))
	return {"ok": true, "text": "Prioridad fijada: %s." % str(Policies.area(area_id).get("name", area_id))}

func back(idx: int) -> Dictionary:
	var err := _president_check(idx, "back")
	if err != "":
		return _fail(err)
	var mn := minister(idx)
	m.ministers.shift_relation(mn, 5.0)
	m.ministers.log_history(mn, "Respaldado/a públicamente por el presidente.")
	var troubled := act_of(idx) < 40.0 or m.ministers.attr(mn, "integridad") <= 3
	m.gov.shift_government_approval(-0.4 if troubled else 0.2)
	_partner_trust(idx, 3.0)
	return {"ok": true, "text": "Respaldas a %s en público." % Leader.full_name(mn)}

func disown(idx: int) -> Dictionary:
	var err := _president_check(idx, "disown")
	if err != "":
		return _fail(err)
	var mn := minister(idx)
	m.ministers.shift_relation(mn, -10.0)
	m.ministers.shift_attr(mn, "lealtad", -1)
	m.ministers.log_history(mn, "Desautorizado/a públicamente por el presidente.")
	var troubled := act_of(idx) < 40.0 or m.ministers.attr(mn, "integridad") <= 3
	m.gov.shift_government_approval(0.3 if troubled else -0.5)
	_partner_trust(idx, -8.0)
	return {"ok": true, "text": "Desautorizas a %s: la ruptura de confianza se nota." % Leader.full_name(mn)}

func rebuke(idx: int) -> Dictionary:
	var err := _president_check(idx, "rebuke")
	if err != "":
		return _fail(err)
	var mn := minister(idx)
	m.ministers.shift_relation(mn, -5.0)
	mn["act"] = clampf(float(mn.get("act", 55.0)) + 2.0, 0.0, 100.0)
	m.ministers.log_history(mn, "Reprendido/a por el presidente.")
	_partner_trust(idx, -3.0)
	return {"ok": true, "text": "Reprendes a %s: mejora la disciplina, empeora la relación." % Leader.full_name(mn)}

func limit_autonomy(idx: int) -> Dictionary:
	var err := _president_check(idx, "limit")
	if err != "":
		return _fail(err)
	var e := entry(idx)
	var cur := AUTONOMY.find(str(e.get("autonomy", "plena")))
	if cur >= AUTONOMY.size() - 1:
		return _fail("Ya está bajo supervisión total.")
	e["autonomy"] = AUTONOMY[cur + 1]
	var mn := minister(idx)
	m.ministers.shift_relation(mn, -6.0)
	m.ministers.log_history(mn, "Su autonomía pasa a «%s»." % str(AUTONOMY_NAMES[e["autonomy"]]).to_lower())
	_partner_trust(idx, -4.0)
	return {"ok": true, "text": "%s: %s." % [str(e["name"]), AUTONOMY_NAMES[e["autonomy"]]]}

func restore_autonomy(idx: int) -> Dictionary:
	var err := _president_check(idx, "limit")
	if err != "":
		return _fail(err)
	var e := entry(idx)
	var cur := AUTONOMY.find(str(e.get("autonomy", "plena")))
	if cur <= 0:
		return _fail("Ya tiene autonomía plena.")
	e["autonomy"] = AUTONOMY[cur - 1]
	m.ministers.shift_relation(minister(idx), 4.0)
	return {"ok": true, "text": "%s: %s." % [str(e["name"]), AUTONOMY_NAMES[e["autonomy"]]]}

## Exige un plan correctivo: en dos trimestres debe mejorar su rendimiento o habrá consecuencias.
func demand_plan(idx: int) -> Dictionary:
	var err := _president_check(idx, "plan")
	if err != "":
		return _fail(err)
	var e := entry(idx)
	if e.has("plan"):
		return _fail("Ya tiene un plan correctivo en marcha.")
	err = _action_cost("plan")
	if err != "":
		return _fail(err)
	e["plan"] = {"due": m.turn() + 2, "act0": act_of(idx)}
	var mn := minister(idx)
	m.ministers.shift_relation(mn, -3.0)
	m.ministers.log_history(mn, "Debe presentar un plan correctivo (plazo: dos trimestres).")
	return {"ok": true, "text": "Plan correctivo exigido a %s: plazo de dos trimestres." % Leader.full_name(mn)}

## Pide la dimisión: el ministro puede aceptar o negarse según su lealtad y la relación con el presidente.
func ask_resignation(idx: int) -> Dictionary:
	var err := _president_check(idx, "ask_resign")
	if err != "":
		return _fail(err)
	if is_reserved(idx):
		return _request_partner(idx, "pedir la dimisión")
	err = _action_cost("ask_resign")
	if err != "":
		return _fail(err)
	var mn := minister(idx)
	var willing := m.ministers.attr(mn, "lealtad") >= 5 or m.ministers.relation(mn) < 35.0 or act_of(idx) < 30.0
	if willing:
		return _vacate(idx, "dimite a petición del presidente", true)
	m.ministers.shift_relation(mn, -12.0)
	m.ministers.log_history(mn, "Se niega a dimitir cuando se lo pide el presidente.")
	return {"ok": true, "refused": true, "text": "%s se niega a dimitir. Si quieres echarlo, tendrás que destituirlo." % Leader.full_name(mn)}

func fire(idx: int) -> Dictionary:
	var err := _president_check(idx, "fire")
	if err != "":
		return _fail(err)
	if is_reserved(idx):
		return _fail("No puedes destituir al ministro de un socio: la cartera es suya por el acuerdo. Puedes pedirle a su partido que lo sustituya.")
	err = _action_cost("fire")
	if err != "":
		return _fail(err)
	return _vacate(idx, "es destituido/a por el presidente", false)

## Solicita al partido socio que cambie a su ministro: acepta según confianza y rendimiento del ministro.
func _request_partner(idx: int, what: String) -> Dictionary:
	var e := entry(idx)
	var pid := str(e["party"])
	var mn := minister(idx)
	var trust := m.coal.trust(pid)
	var poor := act_of(idx) < 40.0 or m.ministers.attr(mn, "integridad") <= 3
	var ok := (poor and trust >= 35.0) or trust >= 75.0
	if ok:
		m.coal.shift_trust(pid, -2.0, "sustitución de su ministro a petición del presidente")
		return _vacate(idx, "es sustituido/a a petición del presidente y con el visto bueno de su partido", false)
	m.coal.shift_trust(pid, -6.0, "petición de dimisión de su ministro")
	m.coal.add_cause(pid, "El presidente pidió %s de su ministro." % what)
	return {"ok": true, "refused": true, "text": "%s rechaza: la cartera de «%s» es suya y su ministro rinde lo suficiente." % [m.party_short(pid), str(e["name"])]}

## Deja la cartera sin titular y nombra a otro; la cartera se resiente.
func _vacate(idx: int, text: String, voluntary: bool) -> Dictionary:
	var e := entry(idx)
	var mn := minister(idx)
	var old_name := Leader.full_name(mn)
	var sec := "%s %s." % [old_name, text]
	m.ministers.log_history(mn, "Deja el cargo: %s." % text)
	var ambitious := m.ministers.attr(mn, "ambicion") >= 6 and m.ministers.attr(mn, "popularidad") >= 6
	if str(e.get("party", "")) == m.pid() and int(mn.get("pool_id", -1)) >= 0:
		var burned: Array = st().get("burned", [])
		burned.append(int(mn["pool_id"]))
		st()["burned"] = burned
	m.cands.retire(idx, int(mn.get("pool_id", -1)))
	e.erase("minister")
	e.erase("plan")
	e["autonomy"] = "plena"
	m.ministers.ensure_cabinet()
	var nw := minister(idx)
	if not nw.is_empty():
		nw["act"] = 45.0
	var cost_app := -0.3 if voluntary else -0.6
	m.gov.shift_government_approval(cost_app)
	_count_reshuffle()
	if ambitious:
		m.itrust.shock(-1.5, "%s, con peso propio, se convierte en crítico tras salir del Gobierno." % old_name)
	m.publish("Cambio en el Consejo de Ministros: %s" % str(e["name"]), "%s Le sustituye %s." % [sec, Leader.full_name(nw)], "GOBIERNO", "warning" if not voluntary else "neutral")
	_note(sec)
	return {"ok": true, "text": "%s Le sustituye %s." % [sec, Leader.full_name(nw)]}

func _count_reshuffle() -> void:
	var s := st()
	var t := m.turn()
	if int(s.get("reshuffle_turn", -1)) != t:
		s["reshuffle_turn"] = t
		s["reshuffles"] = 0
	s["reshuffles"] = int(s.get("reshuffles", 0)) + 1
	if int(s["reshuffles"]) >= 3:
		m.gov.shift_government_approval(-1.0)
		m.itrust.shock(-1.0, "Tantos cambios en el Gobierno en un trimestre dan imagen de improvisación.")

## Intercambia a los titulares de dos carteras del mismo partido (remodelación).
func swap(a: int, b: int) -> Dictionary:
	var err := _president_check(a, "swap")
	if err != "":
		return _fail(err)
	if b < 0 or b >= size() or a == b or minister(b).is_empty():
		return _fail("Elige otra cartera con titular.")
	if str(entry(a)["party"]) != str(entry(b)["party"]) or is_reserved(a) or is_reserved(b):
		return _fail("Solo puedes intercambiar ministros de tu propio partido.")
	err = _action_cost("swap")
	if err != "":
		return _fail(err)
	var ma := minister(a)
	var mb := minister(b)
	entry(a)["minister"] = mb
	entry(b)["minister"] = ma
	m.ministers.log_history(ma, "Trasladado/a a %s." % str(entry(b)["name"]))
	m.ministers.log_history(mb, "Trasladado/a a %s." % str(entry(a)["name"]))
	var sa := m.ministers.specialty_match(ma, str(entry(b)["name"]), entry(b))
	var sb := m.ministers.specialty_match(mb, str(entry(a)["name"]), entry(a))
	# Un ascenso a una cartera más relevante agrada; un traslado a una peor, no.
	m.ministers.shift_relation(ma, 3.0 if sa else -2.0)
	m.ministers.shift_relation(mb, 3.0 if sb else -2.0)
	_count_reshuffle()
	m.publish("Remodelación del Gobierno", "%s pasa a %s y %s a %s." % [Leader.full_name(ma), str(entry(b)["name"]), Leader.full_name(mb), str(entry(a)["name"])], "GOBIERNO", "neutral")
	return {"ok": true, "text": "Remodelación hecha: %s ↔ %s." % [str(entry(a)["name"]), str(entry(b)["name"])]}

## Sustituye al titular de una cartera de tu partido por uno de la cantera.
func replace_with(idx: int, pool_id: int) -> Dictionary:
	var err := _president_check(idx, "replace")
	if err != "":
		return _fail(err)
	if str(entry(idx)["party"]) != m.pid() or is_reserved(idx):
		return _fail("Solo puedes nombrar ministros de tu partido.")
	var cur_pool := int(minister(idx).get("pool_id", -2))
	if cur_pool == pool_id:
		return _fail("Ya es el titular.")
	err = _action_cost("replace")
	if err != "":
		return _fail(err)
	var old := minister(idx)
	var ambitious := m.ministers.attr(old, "ambicion") >= 6 and m.ministers.attr(old, "popularidad") >= 6
	m.ministers.log_history(old, "Sustituido/a por el presidente.")
	m.ministers.assign(idx, pool_id)
	minister(idx)["act"] = 45.0
	entry(idx).erase("plan")
	m.gov.shift_government_approval(-0.3)
	_count_reshuffle()
	if ambitious:
		m.itrust.shock(-1.5, "%s, con peso propio, se convierte en crítico tras su sustitución." % Leader.full_name(old))
	m.publish("Nuevo titular en %s" % str(entry(idx)["name"]), "%s sustituye a %s." % [Leader.full_name(minister(idx)), Leader.full_name(old)], "GOBIERNO", "neutral")
	return {"ok": true, "text": "%s es el nuevo titular de %s." % [Leader.full_name(minister(idx)), str(entry(idx)["name"])]}

func is_burned(pool_id: int) -> bool:
	return (st().get("burned", []) as Array).has(pool_id)

func _note(text: String) -> void:
	var lg: Array = st().get("log", [])
	lg.push_front({"turn": m.turn(), "text": text})
	while lg.size() > 30:
		lg.pop_back()
	st()["log"] = lg

func log_entries(n: int = 6) -> Array:
	return (st().get("log", []) as Array).slice(0, n)
