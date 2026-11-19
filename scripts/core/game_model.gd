class_name GameModel
extends RefCounted
## Estado de la partida y reglas transversales. La interfaz solo lee este modelo y llama a sus
## subsistemas (campaign, election, gov, ai); ninguna regla de juego depende de nodos visuales.

var save: Dictionary
var s: Dictionary
var party: Dictionary
var rivals: Array = []
var constituencies: Array = []
var rng := RandomNumberGenerator.new()
var ai: AIDirector
var brain: PartyBrain
var diplomacy: Diplomacy
var campaign: CampaignSim
var voters: Electorate
var militancy: Militancy
var itrust: InternalTrust
var enc: Encounters
var media: MediaAgenda
var election: ElectionSim
var gov: GovernmentSim
var eco: EconomySim
var world: WorldSim
var macro: MacroSim
var laws: LawMaker
var congress: Congress
var ministers: Ministers
var exec: Executive
var manifesto: Manifesto
var cab: CabinetSim
var coal: Coalition
var agr: Agreements
var mact: MinisterActivity
var autosave := true
var _by_id: Dictionary = {}

# ---------------------------------------------------------------- propiedades de estado
var trust: float:
	get: return float(s.get("trust", 52.0))
	set(v): s["trust"] = clampf(v, 0.0, 100.0)
var visibility: float:
	get: return float(s.get("visibility", 24.0))
	set(v): s["visibility"] = clampf(v, 0.0, 100.0)
var momentum: float:
	get: return float(s.get("momentum", 0.0))
	set(v): s["momentum"] = clampf(v, -12.0, 12.0)
var funds: float:
	get: return float(s.get("money", 0.0))
	set(v): s["money"] = v
var day: int:
	get: return int(s.get("campaign_day", 1))
	set(v): s["campaign_day"] = v
var phase: String:
	get: return str(s.get("phase", "campaign"))
	set(v): s["phase"] = v
var gov_month: int:
	get: return int(s.get("government_month", 1))
	set(v): s["government_month"] = v
var cycle: int:
	get: return int(s.get("cycle", 1))

## Turno (trimestre) de la legislatura en curso, 1..16.
func turn() -> int:
	return Rules.turn_of(gov_month)

func _init(save_dict: Dictionary) -> void:
	save = save_dict
	if not save.has("game_state") or typeof(save["game_state"]) != TYPE_DICTIONARY:
		save["game_state"] = {}
	s = save["game_state"]
	if not save.has("player_party") or typeof(save["player_party"]) != TYPE_DICTIONARY:
		save["player_party"] = {}
	party = save["player_party"]
	rng.randomize()
	constituencies = DataStore.constituencies()
	for p in DataStore.parties():
		if str((p as Dictionary).get("id", "")) != pid():
			rivals.append(p)
	_rebuild_index()
	ai = AIDirector.new(self)
	brain = PartyBrain.new(self)
	diplomacy = Diplomacy.new(self)
	campaign = CampaignSim.new(self)
	voters = Electorate.new(self)
	militancy = Militancy.new(self)
	itrust = InternalTrust.new(self)
	enc = Encounters.new(self)
	media = MediaAgenda.new(self)
	election = ElectionSim.new(self)
	gov = GovernmentSim.new(self)
	eco = EconomySim.new(self)
	world = WorldSim.new(self)
	macro = MacroSim.new(self)
	laws = LawMaker.new(self)
	congress = Congress.new(self)
	ministers = Ministers.new(self)
	exec = Executive.new(self)
	manifesto = Manifesto.new(self)
	cab = CabinetSim.new(self)
	coal = Coalition.new(self)
	agr = Agreements.new(self)
	mact = MinisterActivity.new(self)
	_migrate()
	eco.ensure()

func _rebuild_index() -> void:
	_by_id.clear()
	for p in rivals:
		_by_id[str((p as Dictionary).get("id", ""))] = p
	_by_id[pid()] = party

# ---------------------------------------------------------------- acceso a datos
func pid() -> String:
	return str(party.get("id", "player"))

func party_by_id(id: String) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	return {}

## Personaje del jugador (si la partida es antigua, se genera uno por defecto de forma estable).
func character() -> Dictionary:
	if not party.has("character") or typeof(party["character"]) != TYPE_DICTIONARY:
		var ch := Leader.generate("player_" + pid(), int(s.get("leader_seed", 7)))
		ch["ai"] = false
		ch["name"] = str(party.get("leader", "")).get_slice(" ", 0) if str(party.get("leader", "")) != "" else str(ch["name"])
		party["character"] = ch
	return party["character"]

## Líder de cualquier partido: el personaje del jugador o un líder ficticio estable para los de la IA.
func leader_of(id: String) -> Dictionary:
	if is_player(id):
		return character()
	var book := d("leaders")
	if not book.has(id):
		if not s.has("leader_seed"):
			s["leader_seed"] = int(randi() % 100000)
		book[id] = Leader.generate(id, int(s["leader_seed"]))
	return book[id]

func leader_name(id: String) -> String:
	return Leader.full_name(leader_of(id))

func party_short(id: String) -> String:
	if id == Rules.OTHERS_ID:
		return "Otros"
	return str(party_by_id(id).get("short_name", id.to_upper()))

func party_name(id: String) -> String:
	if id == Rules.OTHERS_ID:
		return "Otros partidos y voto en blanco"
	return str(party_by_id(id).get("name", id))

func party_color(id: String) -> Color:
	if id == Rules.OTHERS_ID:
		return Color("#6F7F90")
	return Color(str(party_by_id(id).get("color", "#6F7F90")))

func all_parties() -> Array:
	var all: Array = rivals.duplicate()
	all.append(party)
	return all

## Comunidades autónomas del mapa (sin repetir).
func communities() -> Array:
	var out: Array = []
	for c in constituencies:
		var cname := str((c as Dictionary).get("autonomous_community", ""))
		if cname != "" and not out.has(cname):
			out.append(cname)
	return out

## Peso aproximado de unas comunidades sobre el censo total (mismo reparto de votos que usa ElectionSim).
func community_share(names: Array) -> float:
	var total := 0.0
	var part := 0.0
	for c in constituencies:
		var cd: Dictionary = c
		var votes := float(int(cd.get("seats", 4)) * 18000 + 12000)
		total += votes
		if names.has(str(cd.get("autonomous_community", ""))):
			part += votes
	return part / maxf(total, 1.0)

## Territorio en el que se presenta una formación: {communities, electorate} o {} si es estatal.
func territory_of(id: String) -> Dictionary:
	if Rules.REGIONALIST_TERRITORY.has(id):
		return Rules.REGIONALIST_TERRITORY[id]
	if is_player(id):
		var t: Array = s.get("player_territory", [])
		if t.is_empty() or t.size() >= communities().size():
			return {}
		return {"communities": t, "electorate": community_share(t)}
	return {}

func is_regional(id: String) -> bool:
	return not territory_of(id).is_empty()

func is_player(id: String) -> bool:
	return id == pid()

## Diccionario persistente dentro del estado (se crea si no existe).
func d(key: String) -> Dictionary:
	if not s.has(key) or typeof(s[key]) != TYPE_DICTIONARY:
		s[key] = {}
	return s[key]

## Array persistente dentro del estado (se crea si no existe).
func a(key: String) -> Array:
	if not s.has(key) or typeof(s[key]) != TYPE_ARRAY:
		s[key] = []
	return s[key]

func polls() -> Dictionary:
	return d("polls")

func poll_of(id: String) -> float:
	return float(polls().get(id, 0.0))

func player_poll() -> float:
	return poll_of(pid())

func seats_of(id: String) -> int:
	return int(d("election_totals").get(id, 0))

func vote_share_of(id: String) -> float:
	var totals: Dictionary = d("election_vote_totals")
	var total := 0
	for v in totals.values():
		total += int(v)
	if total <= 0:
		return 0.0
	return float(int(totals.get(id, 0))) / float(total) * 100.0

## Lista ordenada de {id, share} por intención de voto (sin "otros").
func ranked_polls() -> Array:
	var rows: Array = []
	for id in polls().keys():
		if str(id) == Rules.OTHERS_ID:
			continue
		rows.append({"id": str(id), "share": float(polls()[id])})
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["share"]) > float(y["share"]))
	return rows

## Los `limit` primeros del ranking, garantizando que el partido del jugador aparece siempre (con su puesto en `rank`).
func ranked_polls_with_player(limit: int) -> Array:
	var all := ranked_polls()
	for i in range(all.size()):
		(all[i] as Dictionary)["rank"] = i + 1
	var rows: Array = all.slice(0, limit)
	var has_player := false
	for r in rows:
		if is_player(str((r as Dictionary)["id"])):
			has_player = true
	if not has_player:
		for r in all:
			if is_player(str((r as Dictionary)["id"])):
				if rows.size() >= limit:
					rows.pop_back()
				rows.append(r)
	return rows

# ---------------------------------------------------------------- tiempo
func campaign_start_unix() -> int:
	return int(s.get("campaign_start_unix", Rules.start_unix()))

func election_unix() -> int:
	return campaign_start_unix() + Rules.CAMPAIGN_LENGTH_DAYS * 86400

func clock_unix() -> int:
	return int(s.get("clock_unix", campaign_start_unix()))

func set_clock_to_campaign_day() -> void:
	s["clock_unix"] = campaign_start_unix() + (day - 1) * 86400

func advance_clock_days(days: int) -> void:
	s["clock_unix"] = clock_unix() + days * 86400

func date_label(with_weekday := true) -> String:
	return Rules.date_string(clock_unix(), with_weekday)

func date_for_campaign_day(d_value: int) -> String:
	return Rules.date_string(campaign_start_unix() + (d_value - 1) * 86400, true)

func week_of_campaign() -> int:
	return int(floor(float(day - 1) / 7.0)) + 1

# ---------------------------------------------------------------- noticias y mensajes
func news() -> Array:
	return a("campaign_news")

## Mensajes sin leer que importan: decisiones y novedades de negociación. La prensa, los consejos y los avisos del
## sistema son «novedades»: llegan ya leídos y no cuentan (así la insignia solo se enciende cuando hay algo que hacer).
func unread_count() -> int:
	var n := 0
	for item in news():
		var msg: Dictionary = item
		if not bool(msg.get("read", true)) and str(msg.get("kind", "press")) in ["action", "deal"]:
			n += 1
	return n

## Asuntos que piden tu atención ahora: decisiones pendientes y la mesa de negociación abierta.
func attention_count() -> int:
	return pending_count() + (1 if diplomacy.active() else 0)

## Decisiones pendientes, las más urgentes primero (las que antes caducan) y, a igualdad, las más recientes.
func pending_messages() -> Array:
	var out: Array = []
	var clock := day if phase == "campaign" else gov_month
	for item in news():
		var msg: Dictionary = item
		if bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)):
			out.append(msg)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var la := int(a.get("expires_day", clock + 99)) - clock
		var lb := int(b.get("expires_day", clock + 99)) - clock
		if la != lb:
			return la < lb
		return int(a["id"]) > int(b["id"]))
	return out

## Novedades (prensa, consejos, avisos): lo último, sin decisiones pendientes.
func digest_messages(limit: int = 30) -> Array:
	var out: Array = []
	for item in news():
		var msg: Dictionary = item
		if bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)):
			continue
		out.append(msg)
		if out.size() >= limit:
			break
	return out

## Categorías que no requieren acción y se agrupan como "ruido" en la bandeja.
const NEWS_KIND := {
	"INVITACIÓN": "action", "NEGOCIACIONES": "deal", "INVESTIDURA": "deal", "PARLAMENTO": "deal", "GOBIERNO": "deal",
	"ASESOR": "advice", "SONDEO INTERNO": "advice", "DECLARACIONES": "press", "DECLARACIÓN DEL CANDIDATO": "press",
	"AGENDA PÚBLICA": "press", "CAMPAÑA": "press", "AGENDA": "system", "REUNIÓN": "deal",
	"ELECTORADO": "advice", "PARTIDO": "deal", "SONDEOS": "press"
}

## Publica un mensaje. extra admite: key (sustituye al anterior sin respuesta pendiente con la misma clave),
## expires_in (días hasta que caduca si requiere respuesta), pin (no se agrupa) y cualquier dato de acción.
func publish(title: String, body: String, category: String, tone: String = "neutral", extra: Dictionary = {}) -> Dictionary:
	var seq := int(s.get("news_seq", 0)) + 1
	s["news_seq"] = seq
	var msg := {
		"id": seq, "title": title, "body": body, "category": category, "tone": tone,
		"day": day, "date": Rules.date_string(clock_unix()), "read": false,
		"needs_response": false, "speaker_id": "", "actions": [], "resolved": false,
		"kind": str(NEWS_KIND.get(category, "press")), "stamp": clock_unix()
	}
	msg.merge(extra, true)
	# La prensa, los consejos y los avisos no esperan nada de ti: nacen leídos y van al resumen de novedades.
	if not bool(msg.get("needs_response", false)) and str(msg["kind"]) in ["press", "advice", "system"] and not extra.has("read"):
		msg["read"] = true
		msg["digest"] = true
	if bool(msg.get("needs_response", false)):
		msg["kind"] = "action"
		if msg.has("expires_in"):
			msg["expires_day"] = (day if phase == "campaign" else gov_month) + int(msg["expires_in"])
	var key := str(msg.get("key", ""))
	if key != "":
		var list := news()
		for i in range(list.size() - 1, -1, -1):
			var old: Dictionary = list[i]
			if str(old.get("key", "")) == key and not bool(old.get("needs_response", false)):
				list.remove_at(i)
	news().push_front(msg)
	while news().size() > 60:
		news().pop_back()
	return msg

## Caduca los mensajes que exigían respuesta y ya han vencido.
func expire_news() -> void:
	var clock := day if phase == "campaign" else gov_month
	for item in news():
		var msg: Dictionary = item
		if bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)) and msg.has("expires_day") and clock > int(msg["expires_day"]):
			msg["resolved"] = true
			msg["needs_response"] = false
			msg["expired"] = true
			msg["resolution"] = "Caducó sin respuesta."
			msg["kind"] = "press"

## Mensajes con respuesta pendiente publicados después del id indicado.
func urgent_since(seq: int) -> bool:
	for item in news():
		var msg: Dictionary = item
		if int(msg.get("id", 0)) > seq and bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)):
			return true
	return false

func pending_count() -> int:
	var n := 0
	for item in news():
		var msg: Dictionary = item
		if bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)):
			n += 1
	return n

func find_news(msg_id: int) -> Dictionary:
	for item in news():
		if int((item as Dictionary).get("id", -1)) == msg_id:
			return item
	return {}

func mark_read(msg_id: int) -> void:
	var item := find_news(msg_id)
	if not item.is_empty():
		item["read"] = true

func has_urgent_message() -> bool:
	for item in news():
		var msg: Dictionary = item
		if bool(msg.get("needs_response", false)) and not bool(msg.get("resolved", false)):
			return true
	return false

## Ejecuta una acción adjunta a un mensaje. Devuelve el texto de confirmación.
func do_news_action(msg_id: int, action_id: String) -> String:
	var msg := find_news(msg_id)
	if msg.is_empty() or bool(msg.get("resolved", false)):
		return ""
	if action_id.begins_with("studio:") or action_id.begins_with("studio_auto:") or action_id.begins_with("studio_skip:"):
		return _studio_action(msg, action_id)
	var feedback := ""
	var data: Dictionary = msg.get("data", {})
	match action_id:
		"reply_firm":
			feedback = ai.reply(str(msg.get("speaker_id", "")), "firm")
		"reply_dialogue":
			feedback = ai.reply(str(msg.get("speaker_id", "")), "dialogue")
		"media_accept":
			feedback = campaign.accept_media_invitation(data)
		"media_decline":
			feedback = "Has declinado la invitación. El medio tomará nota."
			trust = trust - 0.2
		"diplo_accept":
			feedback = diplomacy.accept_proposal(data)
		"diplo_meet":
			s["open_meeting_request"] = {"party": str(data.get("party", "")), "topic": str(data.get("topic", "relationship")), "law": str(data.get("law", "")), "invited": true}
			feedback = "Te sientas a negociar con %s: su propuesta ya está sobre la mesa." % party_short(str(data.get("party", "")))
		"diplo_decline":
			ai.change_relation(str(data.get("party", "")), -2.0)
			feedback = "Declinas la propuesta de %s." % party_short(str(data.get("party", "")))
		_:
			if action_id.begins_with("press:"):
				feedback = enc.answer_press(msg, int(action_id.get_slice(":", 1)))
			elif action_id.begins_with("incident:"):
				feedback = enc.resolve_incident(msg, int(action_id.get_slice(":", 1)))
			elif action_id.begins_with("mil:"):
				var mparts := action_id.split(":")
				if mparts.size() == 3:
					feedback = militancy.resolve(str(mparts[1]), int(mparts[2]))
			elif action_id.begins_with("mand:"):
				var dparts := action_id.split(":")
				if dparts.size() == 3:
					feedback = itrust.respond(str(dparts[1]), int(dparts[2]))
			elif action_id.begins_with("tbl:"):
				var tparts := action_id.split(":")
				if tparts.size() == 3:
					var tres := coal.respond(int(tparts[1]), str(tparts[2]))
					if not bool(tres.get("ok", false)):
						return str(tres.get("error", "No se pudo aplicar."))
					feedback = str(tres.get("text", ""))
			elif action_id.begins_with("crisis:"):
				var cparts := action_id.split(":")
				if cparts.size() == 3:
					var cres := coal.crisis_action(str(cparts[1]), str(cparts[2]))
					if not bool(cres.get("ok", false)):
						return str(cres.get("error", "No se pudo aplicar."))
					feedback = str(cres.get("text", ""))
			elif action_id.begins_with("legchoice:"):
				var parts := action_id.split(":")
				if parts.size() == 3:
					feedback = gov.apply_event_choice(str(parts[1]), int(parts[2]))
	msg["resolved"] = true
	msg["read"] = true
	msg["needs_response"] = false
	msg["resolution"] = feedback
	return feedback

## Ofertas de la agenda mediática: ir al plató (lo abre la interfaz), delegar o declinar.
func _studio_action(msg: Dictionary, action_id: String) -> String:
	var oid := int(action_id.get_slice(":", 1))
	var o := media.find(oid)
	if o.is_empty() or str(o.get("status", "")) != "open":
		return ""
	var fb := ""
	if action_id.begins_with("studio:"):
		if media.slots_left() <= 0:
			return "No te quedan huecos de agenda este trimestre: delega o declina."
		s["open_studio"] = oid
		fb = "Te presentas en el plató."
		return fb
	elif action_id.begins_with("studio_auto:"):
		var res := media.delegate(oid)
		fb = str(res.get("summary", "Delegada."))
	else:
		media.mark(oid, "declined")
		if str(o.get("kind", "")) == "urgent":
			gov.shift_government_approval(-0.8)
		fb = "Declinas la invitación."
	msg["resolved"] = true
	msg["read"] = true
	msg["needs_response"] = false
	msg["resolution"] = fb
	return fb

# ---------------------------------------------------------------- finanzas
func add_finance(label: String, amount: float) -> void:
	if is_zero_approx(amount):
		return
	funds = funds + amount
	var entries := a("finance_log")
	entries.push_front({"day": day, "date": Rules.date_string(clock_unix()), "label": label, "amount": amount})
	while entries.size() > 80:
		entries.pop_back()

func weekly_income_forecast() -> float:
	return 6000.0 + player_poll() * 900.0 + visibility * 120.0 + float(int(s.get("members", 1200))) * 0.08

func weekly_expense_forecast() -> float:
	return 12000.0 + player_poll() * 600.0

# ---------------------------------------------------------------- partida
## "government" (presidencia), "partner" (ministerios sin presidir), "opposition" o "none".
func role() -> String:
	if phase != "legislature":
		return "none"
	var gov_id := str(s.get("government_party_id", ""))
	if gov_id == pid():
		return "government"
	for entry in a("cabinet"):
		if str((entry as Dictionary).get("party", "")) == pid():
			return "partner"
	return "opposition"

func save_now() -> void:
	save["game_state"] = s
	save["current_date"] = Time.get_date_string_from_unix_time(clock_unix())
	if not autosave:
		return
	var sm := _save_manager()
	if sm != null:
		sm.current_save = save
		sm.save_current()

func _save_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SaveManager")
	return null

# ---------------------------------------------------------------- inicialización y migración
func _migrate() -> void:
	var schema := int(s.get("schema", 0))
	if s.is_empty() or (schema == 0 and not s.has("campaign_day") and not s.has("turn")):
		_init_new_game()
	elif schema < Rules.SCHEMA_VERSION:
		_migrate_from_v2()
	ai.ensure_profiles()
	campaign.ensure_state()

func _init_new_game() -> void:
	s["schema"] = Rules.SCHEMA_VERSION
	s["phase"] = "campaign"
	s["campaign_day"] = 1
	s["cycle"] = 1
	s["campaign_start_unix"] = Rules.start_unix()
	s["clock_unix"] = Rules.start_unix()
	var custom := bool(party.get("is_custom", false))
	s["trust"] = 50.0 if custom else 55.0
	s["visibility"] = 14.0 if custom else 30.0
	if not s.has("leader_seed"):
		s["leader_seed"] = int(randi() % 100000)
	var ch := character()
	s["trust"] = clampf(float(s["trust"]) + Leader.edge(ch, "honestidad") * 4.0 - (1.0 - float(party.get("coherence", 1.0))) * 10.0, 20.0, 80.0)
	s["visibility"] = clampf(float(s["visibility"]) + Leader.edge(ch, "carisma") * 5.0, 5.0, 60.0)
	if custom and (party.get("territory", []) as Array).size() > 0:
		s["player_territory"] = (party["territory"] as Array).duplicate()
	s["history_pending"] = str(party.get("history_mode", "realistic"))
	s["momentum"] = 0.0
	s["program"] = {}
	s["manifesto"] = {}
	s["manifesto_locked"] = false
	s["tone"] = "contrast"
	s["campaign_events"] = []
	s["campaign_log"] = []
	s["election_history"] = []
	ai.ensure_profiles()
	campaign.init_polls()
	var start_poll := player_poll()
	s["money"] = clampf(start_poll * 40000.0, 150000.0, 1400000.0)
	s["members"] = int(clampf(start_poll * 9000.0, 1200.0, 300000.0))
	publish("La campaña echa a andar",
		"Los equipos de campaña despliegan su estrategia por todo el país. Tu dirección te pide fijar el programa, el tono de campaña y la agenda de las primeras semanas.",
		"REDACCIÓN", "neutral")
	s["objective"] = {"target_seats": maxi(1, int(election.project_seats().get(pid(), 1))), "evaluated": false}
	save_now()

func _migrate_from_v2() -> void:
	if not s.has("campaign_start_unix"):
		s["campaign_start_unix"] = Rules.start_unix()
	if not s.has("phase"):
		if bool(s.get("election_complete", false)):
			var old_phase := str(s.get("political_phase", "results"))
			s["phase"] = "cabinet_design" if old_phase == "cabinet_negotiation" else old_phase
		elif bool(s.get("election_started", false)):
			s["phase"] = "election_night"
		else:
			s["phase"] = "campaign"
	if not s.has("polls"):
		campaign.migrate_polls()
	if not s.has("cycle"):
		s["cycle"] = 1
	if not s.has("members"):
		s["members"] = 1200
	if not s.has("tone"):
		s["tone"] = "contrast"
	if not s.has("objective"):
		s["objective"] = {"target_seats": maxi(1, int(election.project_seats().get(pid(), 1))), "evaluated": bool(s.get("election_complete", false))}
	# Mensajes antiguos: añadir los campos de la nueva bandeja.
	for item in news():
		var msg: Dictionary = item
		if not msg.has("id"):
			var seq := int(s.get("news_seq", 0)) + 1
			s["news_seq"] = seq
			msg["id"] = seq
			msg["read"] = true
			msg["actions"] = []
			msg["resolved"] = true
			msg["needs_response"] = false
	# Cartera de ministerios antigua (nombres + asignaciones) → lista de {name, party}.
	if not s.has("cabinet") and s.has("cabinet_ministries"):
		var cabinet: Array = []
		var assignments: Dictionary = s.get("cabinet_assignments", {})
		for name in s.get("cabinet_ministries", []):
			cabinet.append({"name": str(name), "party": str(assignments.get(str(name), s.get("negotiation_candidate_id", "")))})
		s["cabinet"] = cabinet
	if str(s.get("phase", "")) == "legislature":
		gov.ensure_legislature_state()
	if str(s.get("phase", "")) == "investiture":
		gov.ensure_offers(true)
	if str(s.get("phase", "")) == "election_night":
		s["election_index"] = 0
		s["election_seed"] = rng.randi()
		s["election_totals"] = {}
		s["election_vote_totals"] = {}
	s["schema"] = Rules.SCHEMA_VERSION
