class_name Manifesto
extends RefCounted
## Programa electoral: promesas concretas por área (medida + valor prometido). Es obligatorio al empezar cada campaña,
## los votantes lo valoran (resonancia en las encuestas) y, si gobiernas, se mide su cumplimiento.
##
## Estado en `m.s["manifesto"]` = {measure_id: {"from": valor_al_prometer, "to": valor_prometido}}.
## `m.s["manifesto_locked"]` indica que el programa ya está firmado (no se puede cambiar durante la campaña).

const MIN_PROMISES := 5
const MIN_AREAS := 3
const MAX_PER_AREA := 7            # límite por área; no hay límite general de promesas
const GRACE_MONTHS := 3            # meses de cortesía antes de exigir resultados
const DELIVER_BY := 36             # mes de legislatura en que se espera todo cumplido

var m: GameModel

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- estado
func promises() -> Dictionary:
	return m.d("manifesto")

func has(measure_id: String) -> bool:
	return promises().has(measure_id)

func count() -> int:
	return promises().size()

func locked() -> bool:
	return bool(m.s.get("manifesto_locked", false))

func area_count(area_id: String) -> int:
	var n := 0
	for id in promises().keys():
		if str(Policies.measure(str(id)).get("area", "")) == area_id:
			n += 1
	return n

func areas_used() -> Array:
	var out: Array = []
	for a in Policies.areas():
		var aid := str((a as Dictionary)["id"])
		if area_count(aid) > 0:
			out.append(aid)
	return out

## Áreas (por su tema nacional) con alguna promesa: compatible con el antiguo `program()`.
func issues_covered() -> Dictionary:
	var out: Dictionary = {}
	for aid in areas_used():
		out[str(Policies.area(str(aid)).get("issue", aid))] = true
	return out

func target(measure_id: String) -> float:
	return float((promises().get(measure_id, {}) as Dictionary).get("to", m.eco.value(measure_id)))

func origin(measure_id: String) -> float:
	return float((promises().get(measure_id, {}) as Dictionary).get("from", m.eco.value(measure_id)))

# ---------------------------------------------------------------- edición
## Fija la promesa de una medida. Si el valor coincide con la situación actual, la promesa se retira.
func set_promise(measure_id: String, v: float) -> Dictionary:
	if locked():
		return {"ok": false, "error": "El programa ya está firmado y no se puede modificar."}
	var meas := Policies.measure(measure_id)
	if meas.is_empty():
		return {"ok": false, "error": "Medida desconocida."}
	if measure_id == Irpf.SPECIAL_ID:
		return {"ok": false, "error": "El IRPF se promete por tramos."}
	m.eco.ensure()
	var cur := m.eco.value(measure_id)
	var nv := Policies.snap(meas, v)
	var prom := promises()
	if is_equal_approx(nv, cur):
		prom.erase(measure_id)
		return {"ok": true}
	if not prom.has(measure_id):
		if area_count(str(meas["area"])) >= MAX_PER_AREA:
			return {"ok": false, "error": "Como máximo %d promesas por área." % MAX_PER_AREA}
	prom[measure_id] = {"from": cur, "to": nv}
	return {"ok": true}

# ---------------------------------------------------------------- IRPF por tramos
func is_irpf(measure_id: String) -> bool:
	return measure_id == Irpf.SPECIAL_ID

## Escala de IRPF prometida (o la vigente si no hay promesa).
func irpf_target() -> Array:
	var rec: Dictionary = promises().get(Irpf.SPECIAL_ID, {})
	if typeof(rec.get("brackets", null)) == TYPE_ARRAY:
		return rec["brackets"]
	return m.eco.irpf_brackets()

## Escala vigente cuando se hizo la promesa.
func irpf_base() -> Array:
	var rec: Dictionary = promises().get(Irpf.SPECIAL_ID, {})
	if typeof(rec.get("base", null)) == TYPE_ARRAY:
		return rec["base"]
	return m.eco.irpf_brackets()

## Promete una escala de IRPF concreta (si es igual a la vigente, se retira la promesa).
func set_irpf_promise(brackets: Array) -> Dictionary:
	if locked():
		return {"ok": false, "error": "El programa ya está firmado y no se puede modificar."}
	m.eco.ensure()
	var b := Irpf.sanitize(brackets)
	var prom := promises()
	if Irpf.same(b, m.eco.irpf_brackets()):
		prom.erase(Irpf.SPECIAL_ID)
		return {"ok": true}
	if not prom.has(Irpf.SPECIAL_ID) and area_count("tax") >= MAX_PER_AREA:
		return {"ok": false, "error": "Como máximo %d promesas por área." % MAX_PER_AREA}
	var base: Array = m.eco.irpf_brackets().duplicate(true)
	prom[Irpf.SPECIAL_ID] = {"from": Irpf.average_rate(base), "to": Irpf.average_rate(b), "brackets": b, "base": base}
	return {"ok": true}

func clear() -> void:
	if locked():
		return
	promises().clear()

func ready() -> bool:
	return count() >= MIN_PROMISES and areas_used().size() >= MIN_AREAS

func missing_text() -> String:
	var bits: Array = []
	if count() < MIN_PROMISES:
		bits.append("faltan %d promesas" % (MIN_PROMISES - count()))
	if areas_used().size() < MIN_AREAS:
		bits.append("tocas %d de %d áreas mínimas" % [areas_used().size(), MIN_AREAS])
	return ", ".join(bits)

## Firma el programa: queda cerrado hasta el final de la campaña.
func sign() -> Dictionary:
	if locked():
		return {"ok": true}
	if not ready():
		return {"ok": false, "error": "Programa incompleto: %s." % missing_text()}
	m.s["manifesto_locked"] = true
	m.s["manifesto_signed_cycle"] = m.cycle
	m.publish("%s presenta su programa electoral" % m.party_short(m.pid()),
		"El partido registra %d compromisos en %d áreas: %s." % [count(), areas_used().size(), _headline()], "CAMPAÑA", "neutral")
	return {"ok": true}

func _headline() -> String:
	var names: Array = []
	var ids: Array = promises().keys()
	ids.sort_custom(func(x, y) -> bool: return absf(steps(str(x))) > absf(steps(str(y))))
	for id in ids.slice(0, 3):
		names.append(str(Policies.measure(str(id)).get("name", id)).to_lower())
	return ", ".join(names)

# ---------------------------------------------------------------- valoración de los votantes
## Pasos de cambio prometidos (con signo) sobre el valor al hacer la promesa (o actual si es hipotética).
func steps(measure_id: String, to_v: float = NAN) -> float:
	var meas := Policies.measure(measure_id)
	var t := target(measure_id) if is_nan(to_v) else to_v
	var f := origin(measure_id) if has(measure_id) else m.eco.value(measure_id)
	return (t - f) / float(meas.get("step", 1.0))

## Reacción por grupo ante una medida concreta: {group_id: puntos}.
func group_effects(measure_id: String, to_v: float = NAN) -> Dictionary:
	if is_irpf(measure_id):
		if not has(measure_id):
			return {}
		var hh: Dictionary = Irpf.delta_effects(irpf_base(), irpf_target(), m.eco.irpf_base_revenue())["hits"]
		var o2: Dictionary = {}
		for g2 in hh.keys():
			o2[str(g2)] = float(hh[g2])
		return o2
	var meas := Policies.measure(measure_id)
	var st := steps(measure_id, to_v)
	var out: Dictionary = {}
	var hits: Dictionary = meas.get("hits", {})
	for g in hits.keys():
		out[str(g)] = float(hits[g]) * st
	return out

## Atractivo de una medida: reacción de los grupos ponderada por su peso electoral.
func appeal(measure_id: String, to_v: float = NAN) -> float:
	var eff := group_effects(measure_id, to_v)
	var total := 0.0
	for g in Policies.groups():
		var gd: Dictionary = g
		total += float(gd["share"]) / 100.0 * float(eff.get(str(gd["id"]), 0.0))
	return total

## Sintonía de la promesa con la ideología del propio partido (-1 choca de frente · +1 encaja).
func alignment(measure_id: String, to_v: float = NAN) -> float:
	var meas := Policies.measure(measure_id)
	var t := target(measure_id) if is_nan(to_v) else to_v
	var f := origin(measure_id) if has(measure_id) else m.eco.value(measure_id)
	if is_equal_approx(t, f):
		return 0.0
	return m.laws.measure_pref(m.pid(), meas) * (1.0 if t > f else -1.0)

func _issue_weight(measure_id: String) -> float:
	var issue := str(Policies.area(str(Policies.measure(measure_id).get("area", ""))).get("issue", ""))
	return 0.6 + 4.0 * float(m.campaign.salience().get(issue, 0.1))

## Efecto de las promesas sobre la intención de voto, de -1 a 1 (se aplica a diario en campaña).
func resonance() -> float:
	var total := 0.0
	for id in promises().keys():
		var mid := str(id)
		total += appeal(mid) * _issue_weight(mid) + 0.3 * alignment(mid)
	total -= maxf(0.0, -fiscal_pct() - 0.8) * 1.5
	return clampf(total / 12.0, -1.0, 1.0)

## Reacción agregada por grupo: [{id, v}] ordenado por magnitud.
func group_summary() -> Array:
	var sum: Dictionary = {}
	for id in promises().keys():
		var eff := group_effects(str(id))
		for g in eff.keys():
			sum[g] = float(sum.get(g, 0.0)) + float(eff[g])
	var out: Array = []
	for g in sum.keys():
		out.append({"id": str(g), "v": float(sum[g])})
	out.sort_custom(func(a, b) -> bool: return absf(float(a["v"])) > absf(float(b["v"])))
	return out

## Impacto fiscal anual del programa en bn € (negativo = más déficit) y en % del PIB.
func fiscal_bn() -> float:
	var changes: Dictionary = {}
	var irpf: Array = []
	for id in promises().keys():
		if is_irpf(str(id)):
			irpf = irpf_target()
		else:
			changes[str(id)] = target(str(id))
	if changes.is_empty() and irpf.is_empty():
		return 0.0
	return float(m.eco.preview(changes, irpf)["balance"])

func fiscal_pct() -> float:
	return fiscal_bn() / maxf(1.0, m.eco.gdp()) * 100.0

## Promesas contrarias a la ideología del partido (alineación muy negativa).
func off_line() -> Array:
	var out: Array = []
	for id in promises().keys():
		if alignment(str(id)) < -0.25:
			out.append(str(id))
	return out

# ---------------------------------------------------------------- borrador sugerido
## Propone un programa coherente con la ideología del partido y atractivo para el electorado.
func suggest(n: int = 8) -> void:
	if locked():
		return
	m.eco.ensure()
	var cands: Array = []
	for it in Policies.measures():
		var meas: Dictionary = it
		var mid := str(meas["id"])
		var cur := m.eco.value(mid)
		for dirn in [-1.0, 1.0]:
			var nv := Policies.snap(meas, cur + dirn * float(meas["step"]))
			if is_equal_approx(nv, cur):
				continue
			var pref: float = m.laws.measure_pref(m.pid(), meas) * dirn
			if pref <= 0.05:
				continue
			var iss := str(Policies.area(str(meas["area"])).get("issue", ""))
			var sc: float = pref + appeal(mid, nv) * 0.5 + float(m.campaign.salience().get(iss, 0.1)) * 1.5
			cands.append({"id": mid, "to": nv, "area": str(meas["area"]), "score": sc})
	cands.sort_custom(func(a, b) -> bool: return float(a["score"]) > float(b["score"]))
	promises().clear()
	var per_area: Dictionary = {}
	for c in cands:
		if count() >= n:
			break
		var cd: Dictionary = c
		if has(str(cd["id"])) or int(per_area.get(cd["area"], 0)) >= 2:
			continue
		set_promise(str(cd["id"]), float(cd["to"]))
		per_area[cd["area"]] = int(per_area.get(cd["area"], 0)) + 1
	# Garantiza el mínimo de áreas aunque haya que tomar medidas menos afines.
	if areas_used().size() < MIN_AREAS:
		for c in cands:
			var cd2: Dictionary = c
			if not has(str(cd2["id"])) and area_count(str(cd2["area"])) == 0:
				set_promise(str(cd2["id"]), float(cd2["to"]))
			if areas_used().size() >= MIN_AREAS:
				break

# ---------------------------------------------------------------- cumplimiento
## Progreso de una promesa (0-1): cuánto del recorrido prometido se ha cumplido.
func progress(measure_id: String) -> float:
	if is_irpf(measure_id):
		var tot := Irpf.distance(irpf_base(), irpf_target())
		if tot < 0.0001:
			return 1.0
		return clampf(1.0 - Irpf.distance(m.eco.irpf_brackets(), irpf_target()) / tot, 0.0, 1.0)
	var f := origin(measure_id)
	var t := target(measure_id)
	if is_equal_approx(f, t):
		return 1.0
	return clampf((m.eco.value(measure_id) - f) / (t - f), 0.0, 1.0)

func kept_ratio() -> float:
	if count() == 0:
		return 0.0
	var total := 0.0
	for id in promises().keys():
		total += progress(str(id))
	return total / float(count())

func report() -> Array:
	var out: Array = []
	for id in promises().keys():
		var meas := Policies.measure(str(id))
		var rec: Dictionary = promises()[id]
		out.append({"id": str(id), "name": str(meas.get("name", id)), "area": str(meas.get("area", "")),
			"from": origin(str(id)), "to": target(str(id)), "now": m.eco.value(str(id)), "progress": progress(str(id)),
			"bill_state": str(rec.get("bill_state", "")), "late": shortfall(str(id)) > 0.2, "special": is_irpf(str(id))})
	out.sort_custom(func(a, b) -> bool: return float(a["progress"]) < float(b["progress"]))
	return out

# ---------------------------------------------------------------- proposiciones de ley del programa
## Cada promesa se convierte en una proposición de ley en el Taller de leyes, con los valores del programa.
## Registrarlas en el Congreso no gasta las iniciativas mensuales.
func bill_state(measure_id: String) -> String:
	return str((promises().get(measure_id, {}) as Dictionary).get("bill_state", ""))

func _bill_needed(measure_id: String) -> bool:
	var rec: Dictionary = promises().get(measure_id, {})
	var st := str(rec.get("bill_state", ""))
	if st == "registered" or st == "passed":
		return false
	if not m.laws.draft_by_id(str(rec.get("bill", ""))).is_empty():
		return false
	return progress(measure_id) < 0.999

func _make_bill(measure_id: String) -> bool:
	var meas := Policies.measure(measure_id)
	if meas.is_empty():
		return false
	var law := m.laws.new_draft(str(meas["area"]))
	if is_irpf(measure_id):
		law["title"] = "Reforma del IRPF por tramos"
		m.laws.set_irpf(law, irpf_target())
	else:
		law["title"] = "Proposición: %s" % str(meas["name"])
		m.laws.set_change(law, measure_id, target(measure_id))
	if (law["changes"] as Dictionary).is_empty():
		m.laws.delete_draft(str(law["id"]))
		return false
	law["promise"] = measure_id
	var rec: Dictionary = promises()[measure_id]
	rec["bill"] = str(law["id"])
	rec["bill_state"] = "draft"
	return true

## Crea (o recupera) las proposiciones del programa que falten. Devuelve cuántas ha creado.
func ensure_bills() -> int:
	var n := 0
	for id in promises().keys():
		if _bill_needed(str(id)) and _make_bill(str(id)):
			n += 1
	return n

## Al empezar la legislatura: todas las promesas pasan a ser proposiciones de ley pendientes de llevar al Congreso.
func create_bills() -> int:
	var n := ensure_bills()
	if n > 0:
		m.publish("Tus promesas, listas como proposiciones de ley", "%d compromisos del programa están redactados en el Taller de leyes. Regístralos en el Congreso o los votantes te lo reprocharán." % n, "PARLAMENTO", "neutral")
	return n

## El Taller y el Congreso avisan del destino de cada proposición.
func on_bill(law: Dictionary, state: String) -> void:
	var pid := str(law.get("promise", ""))
	if pid == "" or not has(pid):
		return
	var rec: Dictionary = promises()[pid]
	rec["bill_state"] = state
	if state != "draft":
		rec["tried"] = true

# ---------------------------------------------------------------- decepción de los votantes
## Fracción del programa que debería estar cumplida a estas alturas de la legislatura.
func expected_progress() -> float:
	return clampf(float(m.gov_month - GRACE_MONTHS) / float(DELIVER_BY - GRACE_MONTHS), 0.0, 1.0)

## Esfuerzo percibido: en el Gobierno cuenta lo cumplido; en la oposición también cuenta haberlo llevado al Congreso.
func effort(measure_id: String) -> float:
	var p := progress(measure_id)
	if m.role() != "government" and bool((promises().get(measure_id, {}) as Dictionary).get("tried", false)):
		return maxf(p, 0.7)
	return p

func shortfall(measure_id: String) -> float:
	return clampf(expected_progress() - effort(measure_id), 0.0, 1.0)

## Decepción global (0-1): lo que falta frente a lo esperado, ponderado por la importancia de cada tema.
func disappointment() -> float:
	var num := 0.0
	var den := 0.0
	for id in promises().keys():
		var w := _issue_weight(str(id))
		num += w * shortfall(str(id))
		den += w
	return num / den if den > 0.0 else 0.0

func late_list() -> Array:
	var out: Array = []
	for id in promises().keys():
		if shortfall(str(id)) > 0.2:
			out.append(str(id))
	out.sort_custom(func(a, b) -> bool: return shortfall(str(a)) > shortfall(str(b)))
	return out

## Cada mes se comparan promesas y hechos: la decepción erosiona la confianza y el voto en las encuestas.
func monthly() -> void:
	if count() == 0:
		return
	ensure_bills()
	if m.gov_month <= GRACE_MONTHS:
		return
	var gov := m.role() == "government"
	var ratio := kept_ratio()
	var dis := disappointment()
	m.trust = clampf(m.trust + (ratio - 0.35) * 0.1 - dis * (1.2 if gov else 0.5), 5.0, 95.0)
	if dis > 0.08:
		m.campaign.adjust_poll(m.pid(), -dis * (0.55 if gov else 0.25))
		m.voters.on_broken_promises(m.pid(), dis * (1.0 if gov else 0.4))
	# Avisos por promesa que se retrasa (una sola vez).
	var warned := 0
	for id in late_list():
		var rec: Dictionary = promises()[id]
		if bool(rec.get("late_flag", false)) or warned >= 2:
			continue
		rec["late_flag"] = true
		warned += 1
		m.publish("Los votantes reclaman: «%s»" % str(Policies.measure(str(id)).get("name", id)),
			"Lo prometiste en el programa y sigue sin hacerse. Si no lo cumples, %s pagará el desgaste en las encuestas." % m.party_short(m.pid()), "ELECTORADO", "warning")
	if dis >= 0.3 and not bool(m.s.get("manifesto_anger_news", false)):
		m.s["manifesto_anger_news"] = true
		m.publish("Castigo en las encuestas por las promesas incumplidas",
			"Los votantes perciben que %s se aleja de su programa: la confianza cae y el partido pierde apoyo." % m.party_short(m.pid()), "ELECTORADO", "negative")

## Al abrirse una nueva campaña: se evalúa el programa anterior y se exige uno nuevo.
func close_term() -> void:
	var governed := str(m.s.get("government_party_id", "")) == m.pid()
	if count() > 0:
		var ratio := kept_ratio()
		var tried := 0.0
		for id in promises().keys():
			tried += effort(str(id))
		tried /= float(count())
		m.s["manifesto_prev"] = {"ratio": ratio, "count": count(), "governed": governed, "cycle": m.cycle}
		if governed:
			m.trust = clampf(m.trust + (ratio - 0.4) * 14.0, 5.0, 95.0)
			var pen := clampf((ratio - 0.5) * 6.0, -4.0, 1.5)
			m.campaign.adjust_poll(m.pid(), pen)
			if ratio < 0.4:
				m.publish("Las promesas incumplidas pasan factura", "Solo se cumplió el %d %% del programa de %s. Los votantes llegan a las urnas desencantados." % [int(ratio * 100.0), m.party_short(m.pid())], "ELECTORADO", "negative")
		else:
			m.trust = clampf(m.trust + (tried - 0.4) * 5.0, 5.0, 95.0)
	m.s.erase("manifesto")
	m.s.erase("manifesto_locked")
	m.s.erase("manifesto_anger_news")
