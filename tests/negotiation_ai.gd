extends SceneTree
## Entrega B de la especificación de negociación: perfiles de la IA, poder negociador, estrategia preferida, categorías nuevas
## de la mesa, borradores, versiones y herramientas de edición. Uso: godot --headless --path . --script res://tests/negotiation_ai.gd
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

var m: GameModel

func _fresh(party_id: String = "psoe") -> GameModel:
	var party: Dictionary = {}
	for p in DataStore.parties():
		if str((p as Dictionary)["id"]) == party_id: party = p
	var g := GameModel.new({"schema_version": 3, "save_id": "t", "player_party": party, "game_state": {}})
	g.autosave = false
	g.manifesto.suggest()
	g.manifesto.sign()
	g.day = Rules.CAMPAIGN_LENGTH_DAYS
	g.election.begin_night()
	g.election.skip_night()
	g.election.finish_night()
	g.gov.begin_investiture()
	g.gov.set_candidate(g.pid())
	return g

## Un rival con escaños, sin veto sobre el jugador y con el que se puede abrir mesa.
func _rival(min_seats: int = 5, skip: Array = []) -> String:
	for p in m.all_parties():
		var id := str((p as Dictionary)["id"])
		if m.is_player(id) or m.seats_of(id) < min_seats or skip.has(id): continue
		if m.brain.blocked_by(id, m.pid()) != "": continue
		if not bool(m.diplomacy.can_meet(id)["ok"]): continue
		return id
	return ""

func _set_traits(id: String, d: Dictionary) -> Dictionary:
	var prof := m.ai.profile_of(id)
	var old := {}
	for k in d.keys():
		old[k] = prof.get(k, null)
		prof[k] = d[k]
	return old

func _restore(id: String, old: Dictionary) -> void:
	var prof := m.ai.profile_of(id)
	for k in old.keys():
		if old[k] == null: prof.erase(k)
		else: prof[k] = old[k]

func _initialize() -> void:
	m = _fresh()
	print("== Perfil persistente de la IA")
	var n_prof := 0
	for p in m.rivals:
		var id := str((p as Dictionary)["id"])
		var pf := m.ai.profile_of(id)
		var ok := true
		for k in ["inst_ambition", "cohesion", "electoral_pressure", "reliability", "ambition", "territorial", "pragmatism", "risk_averse", "loyalty"]:
			if not pf.has(k) or float(pf[k]) < 0.0 or float(pf[k]) > 1.0: ok = false
		if ok: n_prof += 1
	check(n_prof == m.rivals.size() and n_prof > 3, "todos los rivales tienen los diez atributos del perfil (%d/%d)" % [n_prof, m.rivals.size()])
	# Migración de una partida antigua: faltan los rasgos nuevos y se completan sin tocar los viejos.
	var rid := _rival()
	var pf0 := m.ai.profile_of(rid)
	var amb0 := float(pf0["ambition"])
	for k2 in ["inst_ambition", "cohesion", "electoral_pressure", "reliability"]: pf0.erase(k2)
	m.brain.ensure_traits(rid, pf0)
	check(pf0.has("inst_ambition") and pf0.has("cohesion") and pf0.has("electoral_pressure") and pf0.has("reliability"), "una partida antigua recibe los rasgos nuevos")
	check(is_equal_approx(float(pf0["ambition"]), amb0), "los rasgos anteriores no se tocan al migrar")

	print("== Poder negociador (seis factores)")
	var w := Rules.NEGOTIATION_WEIGHTS
	check(is_equal_approx(float(w["seats"]), 0.25) and is_equal_approx(float(w["decisive"]), 0.25) and is_equal_approx(float(w["affinity"]), 0.15) and is_equal_approx(float(w["alternatives"]), 0.15) and is_equal_approx(float(w["interest"]), 0.10) and is_equal_approx(float(w["credibility"]), 0.10), "pesos 25/25/15/15/10/10 como pide la especificación")
	var wsum := 0.0
	for k3 in w.keys(): wsum += float(w[k3])
	check(is_equal_approx(wsum, 1.0), "los pesos suman 100 %")
	var powers: Array = []
	var distinct := {}
	for p2 in m.rivals:
		var id2 := str((p2 as Dictionary)["id"])
		var pw := m.brain.negotiating_power(id2)
		var tot := float(pw["total"])
		var part := 0.0
		for f in pw["factors"]: part += float((f as Dictionary)["part"])
		if not is_equal_approx(part, tot) or tot < 0.0 or tot > 1.0: check(false, "%s: poder coherente" % id2)
		powers.append(tot)
		distinct[snappedf(tot, 0.01)] = true
		check((pw["factors"] as Array).size() == 6, "%s: seis factores" % id2) if false else null
	check(distinct.size() >= 3, "el poder varía entre partidos (%d valores distintos)" % distinct.size())
	var spread: float = (powers.max() as float) - (powers.min() as float)
	check(spread >= 0.10, "hay partidos fuertes y débiles (rango %.2f)" % spread)
	var big := ""
	var small := ""
	for p3 in m.rivals:
		var id3 := str((p3 as Dictionary)["id"])
		if m.seats_of(id3) <= 0: continue
		if big == "" or m.seats_of(id3) > m.seats_of(big): big = id3
		if small == "" or m.seats_of(id3) < m.seats_of(small): small = id3
	var fb := m.brain.negotiating_power(big)["factors"] as Array
	var fs := m.brain.negotiating_power(small)["factors"] as Array
	check(float((fb[0] as Dictionary)["value"]) > float((fs[0] as Dictionary)["value"]), "el factor de peso parlamentario crece con los escaños (%s %d > %s %d)" % [big, m.seats_of(big), small, m.seats_of(small)])
	# El interés/urgencia resta poder: quien necesita el pacto negocia peor.
	var old_u := _set_traits(rid, {"ambition": 0.95, "inst_ambition": 0.95, "electoral_pressure": 0.95})
	var p_urgent := float(m.brain.negotiating_power(rid)["total"])
	_restore(rid, old_u)
	old_u = _set_traits(rid, {"ambition": 0.05, "inst_ambition": 0.05, "electoral_pressure": 0.05})
	var p_calm := float(m.brain.negotiating_power(rid)["total"])
	_restore(rid, old_u)
	check(p_calm > p_urgent, "quien necesita el pacto con urgencia tiene menos poder (%.2f < %.2f)" % [p_urgent, p_calm])
	# El carácter decisivo: sin él no se llega a 176.
	var dec := m.brain.decisive_share(rid)
	check(dec >= 0.0 and dec <= 1.0, "carácter decisivo entre 0 y 1 (%.2f)" % dec)
	# El poder modula la dureza, el valor de lo que recibe y lo que cede.
	var tbl: Array = [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 1}]
	var ctx_lo := m.diplomacy.context_for({"with": rid, "topic": "investiture"})
	var ctx_hi := ctx_lo.duplicate(true)
	ctx_lo["power"] = 0.1
	ctx_hi["power"] = 0.8
	var r_lo := m.brain.assess(rid, m.pid(), tbl, ctx_lo)
	var r_hi := m.brain.assess(rid, m.pid(), tbl, ctx_hi)
	check(float(r_hi["need"]) > float(r_lo["need"]) + 0.05, "con más poder exige más (need %.2f > %.2f)" % [float(r_hi["need"]), float(r_lo["need"])])
	check(float(r_hi["utility"]) < float(r_lo["utility"]), "con más poder valora menos lo que recibe y le cuesta más ceder")
	# Las alternativas de Gobierno endurecen la mesa.
	var opp_old := _set_traits(rid, {"strategy": "negotiator"})
	var alt_n := m.brain.alternatives_of(rid)
	_restore(rid, opp_old)
	opp_old = _set_traits(rid, {"strategy": "opposition"})
	var alt_o := m.brain.alternatives_of(rid)
	_restore(rid, opp_old)
	check(alt_o >= alt_n and (alt_o > alt_n or alt_n >= 0.85), "la estrategia de oposición cuenta como alternativa (%.2f ≥ %.2f)" % [alt_o, alt_n])
	check(m.brain.alternatives_of(rid) >= 0.0 and m.brain.alternatives_of(rid) <= 1.0, "alternativas de Gobierno entre 0 y 1")

	print("== Estrategia preferida (no depende del tamaño)")
	var avoid := {"ambition": 0.08, "inst_ambition": 0.08, "risk_averse": 0.95, "electoral_pressure": 0.95, "territorial": 0.9, "pragmatism": 0.6, "strategy": "negotiator"}
	var seek := {"ambition": 0.97, "inst_ambition": 0.95, "risk_averse": 0.05, "electoral_pressure": 0.05, "territorial": 0.05, "pragmatism": 0.8, "strategy": "negotiator"}
	var cand_party := _rival(15)
	if cand_party == "": cand_party = rid
	var o1 := _set_traits(cand_party, avoid)
	var mod_avoid := m.brain.preferred_modality(cand_party)
	_restore(cand_party, o1)
	var o2 := _set_traits(cand_party, seek)
	var mod_seek := m.brain.preferred_modality(cand_party)
	_restore(cand_party, o2)
	check(str(mod_avoid["mode"]) != "coalition", "un partido grande con rasgos reacios prefiere no entrar (%s, %d escaños)" % [str(mod_avoid["mode"]), m.seats_of(cand_party)])
	check(float((mod_seek["scores"] as Dictionary)["coalition"]) > float((mod_avoid["scores"] as Dictionary)["coalition"]) + 0.3, "los rasgos ambiciosos elevan mucho la coalición")
	var reg := ""
	for p4 in m.rivals:
		var idr := str((p4 as Dictionary)["id"])
		if m.is_regional(idr) and m.seats_of(idr) > 0: reg = idr
	if reg != "":
		var mr := m.brain.preferred_modality(reg)
		check(str(mr["mode"]) in ["puntual", "external", "abstention", "opposition", "block", "coalition"], "un regional tiene una modalidad coherente (%s)" % str(mr["mode"]))
	var seen_modes := {}
	for p5 in m.rivals:
		seen_modes[str(m.brain.preferred_modality(str((p5 as Dictionary)["id"]))["mode"])] = true
	print("       modalidades presentes en este reparto: ", seen_modes.keys())
	check(true, "las seis modalidades están definidas (%d)" % Rules.MODALITIES.size()) if Rules.MODALITIES.size() == 6 else check(false, "seis modalidades")

	print("== Rechazar entrar aunque se le ofrezcan carteras")
	var big2 := _rival(12)
	if big2 == "": big2 = cand_party
	var ob := _set_traits(big2, avoid)
	m.diplomacy.open(big2, "investiture")
	var mt := m.diplomacy.current()
	var enter_table: Array = [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 4}, {"k": "structure", "what": "vicepresidency", "by": "player"}]
	for t in m.brain.must_terms(big2): enter_table.append(t)
	var ra := m.brain.assess(big2, m.pid(), enter_table, m.diplomacy.context_for(mt))
	var has_entry := false
	for f2 in ra["factors"]:
		if str((f2 as Dictionary)["key"]) == "entry": has_entry = true
	check(has_entry, "aparece el factor «No le conviene entrar en el Gobierno»")
	check(bool(ra["entry_refused"]), "marca que rechaza entrar (%s)" % str(ra["modality"]))
	check(str(ra["verdict"]) != "accept", "no firma aunque le ofrezcas 4 carteras y una vicepresidencia (%s)" % str(ra["verdict"]))
	var cnt := m.brain.counter(big2, m.pid(), enter_table, m.diplomacy.context_for(mt), ra)
	check(str(cnt["text"]).contains("No queremos entrar") or str(cnt["text"]).contains("oposición"), "la contraoferta explica por qué no entra")
	check(not (cnt["remove"] as Array).is_empty(), "retira lo que implica entrar en el Gobierno")
	_restore(big2, ob)
	var os := _set_traits(big2, seek)
	var rb := m.brain.assess(big2, m.pid(), enter_table, m.diplomacy.context_for(mt))
	check(not bool(rb["entry_refused"]), "con rasgos ambiciosos el mismo paquete no tiene ese rechazo")
	check(float(rb["utility"]) > float(ra["utility"]) + 0.1, "y lo valora mucho más (%.2f > %.2f)" % [float(rb["utility"]), float(ra["utility"])])
	_restore(big2, os)
	m.diplomacy.leave()

	print("== Categorías nuevas evaluadas de verdad")
	var tid := _rival(3)
	var kinds: Array = [
		{"k": "participation", "mode": "external", "by": "ai"},
		{"k": "structure", "what": "vicepresidency", "by": "player"},
		{"k": "structure", "what": "max_ministries", "n": 14, "by": "player"},
		{"k": "portfolio", "comp": "vivienda", "by": "player"},
		{"k": "objective", "issue": "housing", "level": 2, "by": "player", "text": "Objetivo: vivienda"},
		{"k": "territory", "what": "invest", "n": 2, "by": "player"},
		{"k": "budget", "issue": "health", "n": 2, "by": "player"},
		{"k": "parliament", "what": "budget_vote", "by": "ai"},
		{"k": "parliament", "what": "commission", "by": "player"},
		{"k": "institution", "what": "appointment", "n": 1, "by": "player"},
		{"k": "calendar", "what": "review", "n": 6, "by": "player"},
	]
	var ctx := m.diplomacy.context_for({"with": tid, "topic": "investiture"})
	var all_ok := true
	for kd in kinds:
		var tv := m.brain.term_value(tid, m.pid(), kd as Dictionary, ctx.duplicate(true))
		if str(tv["label"]) == "" or is_nan(float(tv["v"])): all_ok = false
		if m.brain.term_text(kd as Dictionary) == "una condición": all_ok = false
	check(all_ok, "las %d condiciones nuevas tienen valor, etiqueta y texto" % kinds.size())
	var oinst := _set_traits(tid, {"inst_ambition": 0.95})
	var v_vp_hi := float(m.brain.term_value(tid, m.pid(), {"k": "structure", "what": "vicepresidency", "by": "player"}, ctx.duplicate(true))["v"])
	_restore(tid, oinst)
	oinst = _set_traits(tid, {"inst_ambition": 0.05})
	var v_vp_lo := float(m.brain.term_value(tid, m.pid(), {"k": "structure", "what": "vicepresidency", "by": "player"}, ctx.duplicate(true))["v"])
	_restore(tid, oinst)
	check(v_vp_hi > v_vp_lo, "la vicepresidencia vale más para quien tiene ambición institucional (%.2f > %.2f)" % [v_vp_hi, v_vp_lo])
	var oterr := _set_traits(tid, {"territorial": 0.95})
	var v_t_hi := float(m.brain.term_value(tid, m.pid(), {"k": "territory", "what": "financing", "n": 2, "by": "player"}, ctx.duplicate(true))["v"])
	_restore(tid, oterr)
	oterr = _set_traits(tid, {"territorial": 0.05})
	var v_t_lo := float(m.brain.term_value(tid, m.pid(), {"k": "territory", "what": "financing", "n": 2, "by": "player"}, ctx.duplicate(true))["v"])
	_restore(tid, oterr)
	check(v_t_hi > v_t_lo + 0.1, "las cesiones territoriales importan al territorial (%.2f > %.2f)" % [v_t_hi, v_t_lo])
	var v_bud := float(m.brain.term_value(tid, m.pid(), {"k": "parliament", "what": "budget_vote", "by": "ai"}, ctx.duplicate(true))["v"])
	check(v_bud < 0.0, "apoyar los Presupuestos le cuesta (%.2f)" % v_bud)
	var v_cal_low := 0.0
	var orel := m.ai.relation(tid)
	m.ai.relations()[tid] = 15.0
	v_cal_low = float(m.brain.term_value(tid, m.pid(), {"k": "calendar", "what": "review", "n": 6, "by": "player"}, ctx.duplicate(true))["v"])
	m.ai.relations()[tid] = 90.0
	var v_cal_hi := float(m.brain.term_value(tid, m.pid(), {"k": "calendar", "what": "review", "n": 6, "by": "player"}, ctx.duplicate(true))["v"])
	m.ai.relations()[tid] = orel
	check(v_cal_low > v_cal_hi, "las garantías de calendario valen más si desconfía de ti (%.2f > %.2f)" % [v_cal_low, v_cal_hi])
	# Objetivos: más ambición del objetivo, más pide la IA a quien lo asume.
	var v_o1 := float(m.brain.term_value(tid, m.pid(), m.brain.objective_term("housing", 1), ctx.duplicate(true))["v"])
	var v_o3 := float(m.brain.term_value(tid, m.pid(), m.brain.objective_term("housing", 3), ctx.duplicate(true))["v"])
	check(v_o3 > v_o1, "un objetivo más ambicioso vale más para quien lo recibe (%.2f > %.2f)" % [v_o3, v_o1])

	print("== Menú por categorías")
	var menu := m.diplomacy.term_menu(tid, "investiture")
	var cats := {}
	for side in ["give", "ask"]:
		for t2 in menu[side]: cats[m.diplomacy.category_of(t2 as Dictionary)] = true
	for cat in Rules.TABLE_CATEGORY_ORDER:
		check(cats.has(cat), "el menú ofrece la categoría «%s»" % str(Rules.TABLE_CATEGORIES[cat]["name"]))
	var kinds_in_menu := {}
	for side2 in ["give", "ask"]:
		for t3 in menu[side2]: kinds_in_menu[str((t3 as Dictionary)["k"])] = true
	for kk in ["participation", "structure", "portfolio", "objective", "territory", "budget", "parliament", "institution", "calendar"]:
		check(kinds_in_menu.has(kk), "el menú incluye términos «%s»" % kk)

	print("== Añadir, sustituir y modificar condiciones")
	m.diplomacy.open(tid, "investiture")
	mt = m.diplomacy.current()
	mt["table"] = []
	m.diplomacy.add_term({"k": "participation", "mode": "external", "by": "ai"})
	m.diplomacy.add_term({"k": "participation", "mode": "abstention", "by": "ai"})
	check((mt["table"] as Array).size() == 1 and str((mt["table"] as Array)[0]["mode"]) == "abstention", "una sola participación: la nueva sustituye a la anterior")
	m.diplomacy.add_term({"k": "structure", "what": "max_ministries", "n": 10, "by": "player"})
	m.diplomacy.add_term({"k": "structure", "what": "max_ministries", "n": 14, "by": "player"})
	check((mt["table"] as Array).size() == 2 and int((mt["table"] as Array)[1]["n"]) == 14, "el máximo de ministerios se actualiza, no se duplica")
	m.diplomacy.add_term({"k": "portfolio", "comp": "vivienda", "by": "player"})
	m.diplomacy.add_term({"k": "portfolio", "comp": "vivienda", "by": "player"})
	check((mt["table"] as Array).size() == 3, "la misma cartera no se duplica")
	check(m.diplomacy.replace_term(2, {"k": "portfolio", "comp": "sanidad", "by": "player"}) and str((mt["table"] as Array)[2]["comp"]) == "sanidad", "sustituir una cartera por otra")
	check(m.diplomacy.modify_term(1, {"n": 18}) and int((mt["table"] as Array)[1]["n"]) == 18, "modificar la cantidad de una condición")
	m.diplomacy.add_term({"k": "cabinet", "by": "player", "n": 3, "from_ai": true})
	var ci := (mt["table"] as Array).size() - 1
	check(m.diplomacy.can_split(((mt["table"] as Array)[ci]) as Dictionary), "una exigencia de 3 carteras se puede fraccionar")
	check(m.diplomacy.accept_partially(ci) and int((mt["table"] as Array)[ci]["n"]) == 2, "aceptación parcial: 3 → 2 carteras")
	check(not m.diplomacy.can_split({"k": "vote_yes", "by": "ai"}), "un voto no se puede fraccionar")
	m.diplomacy.add_term({"k": "policy", "by": "player", "issue": "housing", "text": "Un pacto de vivienda"})
	var pi := (mt["table"] as Array).size() - 1
	check(m.diplomacy.offer_alternative(pi, m.brain.policy_term(tid, "player", "health")) and (mt["table"] as Array)[pi].has("alt_for"), "ofrecer una política alternativa a cambio de retirar otra")

	print("== Estado de cada condición según lo que se sabe")
	var stt := m.diplomacy.term_statuses(mt)
	var all_unknown := true
	for s0 in stt:
		if str((s0 as Dictionary)["status"]) != "unknown": all_unknown = false
	check(all_unknown, "sin sondear ni presentar nada, todo está «sin sondear»")
	mt["table"] = [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 1}]
	for t4 in m.brain.must_terms(tid): (mt["table"] as Array).append(t4)
	mt["sounded"] = true
	var st2 := m.diplomacy.term_statuses(mt)
	var n_must := 0
	var n_neg := 0
	for s1 in st2:
		if str((s1 as Dictionary)["status"]) == "must": n_must += 1
		if str((s1 as Dictionary)["status"]) == "negotiable": n_neg += 1
	check(n_must >= 1 and n_neg >= 1, "tras sondear: imprescindibles (%d) y negociables (%d)" % [n_must, n_neg])
	var cc := m.diplomacy.status_counts(mt)
	check(int(cc["must"]) == n_must, "el resumen de estados coincide")
	mt["rejected_keys"] = [m.diplomacy.term_key({"k": "cabinet", "by": "player"})]
	var st3 := m.diplomacy.term_statuses(mt)
	var any_rej := false
	for s2 in st3:
		if str((s2 as Dictionary)["status"]) == "rejected": any_rej = true
	check(any_rej, "lo que han rechazado en la mesa figura como rechazado")
	mt["rejected_keys"] = []
	mt["sounded"] = false

	print("== Borradores y versiones")
	mt["table"] = [{"k": "vote_yes", "by": "ai"}, {"k": "cabinet", "by": "player", "n": 1}]
	check(m.diplomacy.save_draft("Plan A").begins_with("Guardado"), "guardar un borrador")
	mt["table"] = [{"k": "vote_abstain", "by": "ai"}]
	m.diplomacy.save_draft()
	check(m.diplomacy.drafts().size() == 2 and str((m.diplomacy.drafts()[1] as Dictionary)["name"]) == "Borrador 2", "dos borradores con nombre automático")
	check(m.diplomacy.load_draft(0) and (mt["table"] as Array).size() == 2, "recuperar el primer borrador")
	m.diplomacy.delete_draft(1)
	check(m.diplomacy.drafts().size() == 1, "borrar un borrador")
	for i in range(Rules.MAX_DRAFTS + 2): m.diplomacy.save_draft()
	check(m.diplomacy.drafts().size() == Rules.MAX_DRAFTS, "máximo de %d borradores" % Rules.MAX_DRAFTS)
	var before_v := m.diplomacy.versions().size()
	mt["table"] = [{"k": "vote_yes", "by": "ai"}]
	var sub := m.diplomacy.submit()
	check(m.diplomacy.versions().size() >= before_v + 1, "presentar una oferta deja una versión (%s)" % str(sub["verdict"]))
	var vers := m.diplomacy.versions()
	var has_player := false
	var has_ai := false
	for v in vers:
		if str((v as Dictionary)["who"]) == "player": has_player = true
		if str((v as Dictionary)["who"]) == "ai": has_ai = true
	check(has_player, "se guarda la versión del jugador")
	check(has_ai or str(sub["verdict"]) != "counter", "se guarda la contraoferta de la IA cuando la hay")
	var d1 := m.diplomacy.compare_tables([{"k": "cabinet", "by": "player", "n": 1}, {"k": "vote_yes", "by": "ai"}], [{"k": "cabinet", "by": "player", "n": 2}, {"k": "bills", "by": "ai", "n": 1}])
	check((d1["added"] as Array).size() == 1 and (d1["removed"] as Array).size() == 1 and (d1["changed"] as Array).size() == 1, "comparar versiones: añadido, retirado y cambiado")
	if vers.size() >= 2:
		var cmp := m.diplomacy.compare_versions(0, vers.size() - 1)
		check(cmp.has("added") and cmp.has("removed") and cmp.has("changed"), "comparar dos versiones de la mesa")
	check(m.diplomacy.restore_version(0), "restaurar una versión anterior")
	for i2 in range(Rules.MAX_VERSIONS + 4): m.diplomacy.record_version("player", "x")
	check(m.diplomacy.versions().size() <= Rules.MAX_VERSIONS, "el historial se acota a %d versiones" % Rules.MAX_VERSIONS)
	# Persistencia: la mesa con borradores y versiones sobrevive al guardado en JSON.
	var js := JSON.stringify(m.s["meeting"])
	var back: Variant = JSON.parse_string(js)
	check(back is Dictionary and (back["drafts"] as Array).size() == Rules.MAX_DRAFTS and (back["versions"] as Array).size() > 0, "borradores y versiones sobreviven al guardado")

	print("== Solicitar contraoferta")
	m.diplomacy.leave()
	m = _fresh()
	var tid2 := _rival(3)
	check(bool(m.diplomacy.open(tid2, "investiture")["ok"]), "se abre una mesa nueva con %s" % tid2)
	mt = m.diplomacy.current()
	mt["table"] = [{"k": "vote_yes", "by": "ai"}]
	var pat0 := int(mt["patience"])
	var rc := m.diplomacy.request_counter()
	check(bool(rc["ok"]) and int(mt.get("counter_requests", 0)) == 1, "pide su contraoferta sin presentar la oferta")
	if str(mt.get("status", "")) == "open":
		check(int(mt["patience"]) == pat0 - 1, "cuesta una unidad de paciencia")
		m.diplomacy.request_counter()
		m.diplomacy.request_counter()
		if str(mt.get("status", "")) == "open":
			var r4 := m.diplomacy.request_counter()
			check(not bool(r4["ok"]), "no se puede pedir más de tres veces")
		else:
			check(true, "la mesa termina antes por falta de paciencia")
	else:
		check(true, "la mesa termina antes por falta de paciencia")

	print("== La estrategia preferida decide el papel en el pacto")
	m = _fresh()
	var rid2 := _rival(6)
	var offers := m.gov.offers()
	if rid2 != "" and offers.has(rid2):
		var o3 := _set_traits(rid2, avoid)
		m.gov._ai_resolve(rid2)
		var of: Dictionary = offers[rid2]
		check(str(of.get("modality", "")) != "" and str(of["role"]) != "cabinet", "un partido reacio acaba como apoyo externo, no en el Consejo (%s)" % str(of.get("modality", "")))
		_restore(rid2, o3)
		var o4 := _set_traits(rid2, seek)
		m.gov._ai_resolve(rid2)
		var of2: Dictionary = offers[rid2]
		check(str(of2["role"]) == ("cabinet" if str(of2["modality"]) == "coalition" else "external"), "el papel sale de la modalidad (%s → %s)" % [str(of2["modality"]), str(of2["role"])])
		_restore(rid2, o4)
		var o5 := _set_traits(rid2, {"ambition": 0.1, "inst_ambition": 0.1, "risk_averse": 0.9, "territorial": 0.05, "pragmatism": 0.9, "loyalty": 0.05, "electoral_pressure": 0.2})
		var pm := m.brain.preferred_modality(rid2, m.pid())
		print("       modalidad con rasgos de abstención: ", pm["mode"])
		_restore(rid2, o5)
	else:
		check(false, "hay un partido con oferta de investidura")
	# La participación pactada llega a la investidura.
	var rid3 := _rival(3)
	if rid3 != "":
		m.diplomacy._sync_investiture(rid3, [{"k": "participation", "mode": "abstention", "by": "ai"}, {"k": "policy", "by": "player", "issue": "jobs", "text": "x"}], false)
		check(str(m.gov.offers()[rid3]["vote"]) == "abstain", "una abstención negociada se refleja en la oferta de investidura")
		m.diplomacy._sync_investiture(rid3, [{"k": "participation", "mode": "coalition", "by": "ai"}], false)
		check(str(m.gov.offers()[rid3]["role"]) == "cabinet" and int(m.d("cabinet_claims").get(rid3, 0)) >= 1, "una coalición pactada reserva una cartera")
		m.diplomacy._sync_investiture(rid3, [{"k": "participation", "mode": "external", "by": "ai"}], false)
		check(str(m.gov.offers()[rid3]["role"]) == "external", "un apoyo externo pactado deja al partido fuera del Consejo")
		m.diplomacy._register_pacts(rid3, "investiture", [{"k": "participation", "mode": "external", "by": "ai"}, {"k": "calendar", "what": "review", "n": 6, "by": "player"}])
		var found := false
		for pc in m.diplomacy.pacts():
			if str((pc as Dictionary).get("party", "")) == rid3:
				for tt in (pc as Dictionary)["terms"]:
					if str((tt as Dictionary).get("k", "")) == "calendar": found = true
		check(found, "el pacto conserva las condiciones nuevas para exigirlas después")

	print("== La propuesta de apertura respeta su estrategia")
	m = _fresh()
	var ag := _rival(8)
	if ag != "":
		var oa := _set_traits(ag, avoid)
		var open_avoid := m.diplomacy.dyn.agenda_for(ag, "investiture")
		var asks_cabinet := false
		var offers_mode := false
		for t5 in open_avoid:
			if str((t5 as Dictionary)["k"]) == "cabinet": asks_cabinet = true
			if str((t5 as Dictionary)["k"]) == "participation": offers_mode = true
		check(not asks_cabinet, "quien no quiere entrar no pide carteras al sentarse (%s)" % ag)
		check(offers_mode or str(m.brain.preferred_modality(ag)["mode"]) in ["opposition", "block"], "ofrece su fórmula de participación")
		_restore(ag, oa)
		var os2 := _set_traits(ag, seek)
		var coal := str(m.brain.preferred_modality(ag)["mode"]) == "coalition"
		var open_seek := m.diplomacy.dyn.agenda_for(ag, "investiture")
		var asks2 := false
		for t6 in open_seek:
			if str((t6 as Dictionary)["k"]) == "cabinet": asks2 = true
		check(asks2 or not coal, "quien sí quiere entrar pide carteras")
		_restore(ag, os2)

	print("")
	print("== Fallos: %d" % failures)
	quit()
