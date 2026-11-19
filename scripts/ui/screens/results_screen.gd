class_name ResultsScreen
extends Screen
## Resultados electorales: hemiciclo, tabla y mayorías posibles.

static func economic_order(model: GameModel, ids: Array) -> Array:
	var list := ids.duplicate()
	list.sort_custom(func(x, y) -> bool:
		var ix: Dictionary = model.party_by_id(str(x)).get("ideology", {})
		var iy: Dictionary = model.party_by_id(str(y)).get("ideology", {})
		return float(ix.get("economic", 0.0)) < float(iy.get("economic", 0.0)))
	return list

static func make_hemicycle(model: GameModel, highlight: Array = []) -> Hemicycle:
	var totals: Dictionary = model.d("election_totals")
	if totals.is_empty():
		totals = model.election.project_seats()
	var ids: Array = []
	for id in totals.keys():
		if int(totals[id]) > 0:
			ids.append(str(id))
	var entries: Array = []
	for id in economic_order(model, ids):
		entries.append({"id": str(id), "color": model.party_color(str(id)), "seats": int(totals[id])})
	var h := Hemicycle.new()
	h.entries = entries
	h.highlight = highlight
	h.set_center("350", "escaños · mayoría %d" % Rules.MAJORITY)
	return h

func build() -> void:
	var totals := m.d("election_totals")
	if totals.is_empty():
		var c := UI.card(self, "Sin resultados todavía")
		empty_note(c, "Aún no se han celebrado elecciones en este ciclo.")
		return
	var ids: Array = totals.keys()
	ids.sort_custom(func(x, y) -> bool: return m.seats_of(str(x)) > m.seats_of(str(y)))
	var cols := columns(1.25, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var hc := UI.card(left, "Congreso de los Diputados", "Elecciones del %s" % Rules.date_string(m.election_unix()), UI.ACCENT)
	var h := make_hemicycle(m)
	h.custom_minimum_size = Vector2(300, 330)
	hc.add_child(h)
	var obj := m.d("objective")
	var oc := UI.card(left, "Objetivo de la dirección", "", UI.WARN)
	var met := bool(obj.get("met", false))
	oc.add_child(UI.label("%d escaños previstos · conseguidos: %d" % [int(obj.get("target_seats", 0)), m.seats_of(m.pid())], UI.FS_LEAD, UI.TEXT, true))
	oc.add_child(UI.chip("Objetivo cumplido" if met else "Objetivo no cumplido", UI.GOOD if met else UI.BAD))

	var tc := UI.card(right, "Resultados", "votos · % · escaños", UI.GOOD)
	for id in ids:
		var votes := int(m.d("election_vote_totals").get(str(id), 0))
		party_row(tc, str(id), [
			{"text": Rules.money(float(votes)), "w": 80, "color": UI.MUTED},
			{"text": "%.1f%%" % m.vote_share_of(str(id)), "w": 52},
			{"text": str(m.seats_of(str(id))), "w": 40, "bold": true},
		])
	var mc := UI.card(right, "Mayorías posibles", "Combinaciones que suman %d o más" % Rules.MAJORITY, UI.ACCENT)
	var combos := _majorities(ids)
	if combos.is_empty():
		empty_note(mc, "Ninguna combinación sencilla alcanza la mayoría: habrá que negociar con muchos grupos.")
	for combo in combos.slice(0, 6):
		var row := UI.hbox(6)
		var total := 0
		for id in combo:
			var chip := UI.chip("%s %d" % [m.party_short(str(id)), m.seats_of(str(id))], m.party_color(str(id)))
			row.add_child(chip)
			total += m.seats_of(str(id))
		row.add_child(UI.fill())
		row.add_child(UI.label(str(total), UI.FS_BODY, UI.TEXT, true))
		mc.add_child(row)

func _majorities(ids: Array) -> Array:
	var pool: Array = []
	for id in ids:
		if m.seats_of(str(id)) >= 7:
			pool.append(str(id))
	pool = pool.slice(0, 8)
	var found: Array = []
	for i in range(pool.size()):
		for j in range(i + 1, pool.size()):
			var s2 := m.seats_of(pool[i]) + m.seats_of(pool[j])
			if s2 >= Rules.MAJORITY:
				found.append({"c": [pool[i], pool[j]], "n": s2})
			for k in range(j + 1, pool.size()):
				var s3 := s2 + m.seats_of(pool[k])
				if s2 < Rules.MAJORITY and s3 >= Rules.MAJORITY:
					found.append({"c": [pool[i], pool[j], pool[k]], "n": s3})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if (x["c"] as Array).size() != (y["c"] as Array).size():
			return (x["c"] as Array).size() < (y["c"] as Array).size()
		return int(x["n"]) < int(y["n"]))
	var out: Array = []
	for f in found:
		out.append((f as Dictionary)["c"])
	return out
