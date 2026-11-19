class_name MediaAgenda
extends RefCounted
## Agenda mediática de la legislatura: cada mes llegan ofertas de los medios (sesión de control, comparecencias,
## pódcast, entrevistas, debates). Tienes huecos limitados: aceptarlas te lleva al plató (minijuego de preguntas),
## delegarlas en el portavoz es gratis pero rinde menos, y no atender una comparecencia urgente se paga.
## Todo llega como decisión pendiente a la Bandeja.

const SLOTS_PER_TURN := 3
const KINDS := {
	"urgent": {"label": "URGENTE", "reach": 1.3},
	"prime": {"label": "ESTELAR", "reach": 1.5},
	"routine": {"label": "HABITUAL", "reach": 1.0},
}

var m: GameModel

func _init(model: GameModel) -> void:
	m = model

func st() -> Dictionary:
	var d := m.d("media")
	if not d.has("offers"):
		d["offers"] = []
		d["slots"] = SLOTS_PER_TURN
		d["seq"] = 0
		d["played"] = 0
		d["streak"] = 0
	return d

func offers() -> Array:
	return st()["offers"]

func open_offers() -> Array:
	var out: Array = []
	for o in offers():
		if str((o as Dictionary).get("status", "")) == "open":
			out.append(o)
	return out

func slots_left() -> int:
	return int(st()["slots"])

func find(oid: int) -> Dictionary:
	for o in offers():
		if int((o as Dictionary)["id"]) == oid:
			return o
	return {}

func _add(type_name: String, title: String, kind: String, stake: String, context: String = "") -> Dictionary:
	var d := st()
	d["seq"] = int(d["seq"]) + 1
	var o := {"id": int(d["seq"]), "type": type_name, "title": title, "kind": kind, "stake": stake, "context": context, "status": "open", "month": m.gov_month}
	offers().append(o)
	return o

## Un suceso de la legislatura (crisis, polémica) genera una comparecencia urgente sobre ese asunto.
func on_event(title: String) -> void:
	if m.role() != "government":
		return
	var o := _add("Rueda de prensa", "Comparecencia por: %s" % title, "urgent",
		"Los medios exigen explicaciones. Una buena comparecencia limita el daño; ausentarte lo agrava.", title)
	_publish(o)

## Caduca lo no atendido, repone los huecos y genera las ofertas del trimestre.
func monthly() -> void:
	var d := st()
	for item in offers():
		var o: Dictionary = item
		if str(o["status"]) == "open":
			o["status"] = "expired"
			if str(o["kind"]) == "urgent" and m.gov.player_in_government():
				m.gov.shift_government_approval(-1.5)
				m.publish("Silencio ante la crisis", "No compareciste a tiempo: «%s». La oposición llena el vacío y el Gobierno pierde apoyo." % str(o["title"]), "MEDIOS", "warning")
	while offers().size() > 14:
		offers().pop_front()
	d["slots"] = SLOTS_PER_TURN
	var role := m.role()
	if role == "none":
		return
	var gov_weak := m.gov.approval() < 46.0 or m.gov.stability() < 45.0
	var batch: Array = []
	# Sesión de control: la gran cita mensual del Congreso.
	if role == "opposition":
		batch.append(_add("Sesión de control", "Sesión de control: tu turno frente al Gobierno", "routine",
			"Cada buena pregunta desgasta al Gobierno y sube tu imagen de oposición; una torpe te desgasta a ti."))
	else:
		batch.append(_add("Sesión de control", "Sesión de control: la oposición te interpela", "routine",
			"Defiende al Gobierno en el Pleno: una buena sesión sube el apoyo, una mala lo hunde."))
	if gov_weak and role != "opposition":
		batch.append(_add("Rueda de prensa", "Comparecencia urgente por la situación del Gobierno", "urgent",
			"El apoyo o la estabilidad se resienten. Comparecer puede frenar la caída; no hacerlo cuesta apoyo."))
	if m.rng.randf() < 0.6:
		batch.append(_add("Podcast", "Pódcast político de la semana", "routine",
			"Conversación larga y cercana: poca presión, buen retorno de imagen y alcance entre jóvenes."))
	if m.rng.randf() < 0.65 or batch.size() < 3:
		batch.append(_add("Entrevista", "Entrevista de balance del trimestre", "routine",
			"Un medio nacional te pregunta por la actualidad. Rendimiento medio, riesgo medio."))
	if m.turn() % 2 == 0 or m.turn() == Rules.LEGISLATURE_TURNS - 1:
		batch.append(_add("Debate", "Debate sobre el estado de la nación", "prime",
			"Cara a cara con el líder rival. Alto riesgo y alta recompensa: mueve encuestas y bloques."))
	for o2 in batch:
		_publish(o2 as Dictionary)

func _publish(o: Dictionary) -> void:
	var label := str((KINDS[str(o["kind"])] as Dictionary)["label"])
	var actions: Array = [
		{"id": "studio:%d" % int(o["id"]), "label": "Ir al plató", "style": "primary"},
		{"id": "studio_auto:%d" % int(o["id"]), "label": "Delegar en el portavoz", "style": "ghost"},
		{"id": "studio_skip:%d" % int(o["id"]), "label": "Declinar", "style": "ghost"},
	]
	var msg := m.publish("%s · %s" % [label, str(o["title"])], "%s %s" % [str(o["stake"]), "Tienes %d huecos de agenda este trimestre." % SLOTS_PER_TURN],
		"MEDIOS", "warning" if str(o["kind"]) == "urgent" else "neutral",
		{"needs_response": true, "expires_in": 0, "actions": actions, "offer_id": int(o["id"])})
	o["msg_id"] = int(msg["id"])

## Evento listo para jugar en el plató.
func event_for(o: Dictionary) -> Dictionary:
	return {"type": str(o["type"]), "title": str(o["title"]), "region": "Madrid", "hour": 20, "offer_id": int(o["id"]), "context": str(o.get("context", "")), "status": "scheduled"}

## Consume un hueco al aceptar. Devuelve false si no quedan.
func take_slot() -> bool:
	var d := st()
	if int(d["slots"]) <= 0:
		return false
	d["slots"] = int(d["slots"]) - 1
	return true

func mark(oid: int, status: String) -> void:
	var o := find(oid)
	if o.is_empty():
		return
	o["status"] = status
	var msg := m.find_news(int(o.get("msg_id", -1)))
	if not msg.is_empty() and not bool(msg.get("resolved", false)):
		msg["resolved"] = true
		msg["read"] = true
		msg["needs_response"] = false
		msg["resolution"] = {"done": "Atendida en el plató.", "auto": "Delegada en el portavoz.", "declined": "Declinada."}.get(status, "Cerrada.")

## Registra el resultado de una sesión jugada: racha de buenas intervenciones.
func record(result: Dictionary) -> void:
	var d := st()
	d["played"] = int(d["played"]) + 1
	d["streak"] = (int(d["streak"]) + 1) if float(result.get("factor", 0.0)) >= 0.25 else 0

## Intervención delegada: gratis pero con peor rendimiento.
func delegate(oid: int) -> Dictionary:
	var o := find(oid)
	if o.is_empty():
		return {}
	var ev := event_for(o)
	var auto := m.enc.auto_play(ev)
	mark(oid, "auto")
	return {"type": str(o["type"]), "factor": float(auto["factor"]), "summary": "Intervención delegada en tu portavoz. %s" % str(auto["summary"]), "headline": auto["headline"], "poll_delta": 0.0}
