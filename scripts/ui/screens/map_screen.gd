extends Screen
## Mapa de circunscripciones: proyección con las encuestas o resultado real.

static var mode := "projection"
static var selected_pid := ""

func build() -> void:
	var has_result := not m.d("election_alloc").is_empty() and m.phase != "campaign"
	if not has_result:
		mode = "projection"
	var top := UI.hbox(8)
	add_child(top)
	top.add_child(UI.button("Proyección actual", "primary" if mode == "projection" else "ghost", func() -> void:
		mode = "projection"
		rebuild()))
	if has_result:
		top.add_child(UI.button("Resultado de las elecciones", "primary" if mode == "result" else "ghost", func() -> void:
			mode = "result"
			rebuild()))
	var proj := m.election.project_full()
	var by_prov: Dictionary = proj["by_province"]
	var fills := {}
	var tips := {}
	for c in m.constituencies:
		var cd: Dictionary = c
		var cid := str(cd["id"])
		var alloc: Dictionary = by_prov.get(cid, {}) if mode == "projection" else m.election.result_alloc(cid)
		var winner := _winner(alloc)
		fills[str(cd["name"])] = m.party_color(winner) if winner != "" else Color("#C9D2DF")
		tips[str(cd["name"])] = "%s · %d escaños · gana %s" % [str(cd["name"]), int(cd["seats"]), m.party_short(winner)]
	var cols := columns(1.7, 1.0)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var card := UI.card(left, "Mapa electoral", "Color = partido con más escaños en la circunscripción", UI.ACCENT)
	var map := SpainMap.new()
	map.custom_minimum_size = Vector2(520, 620)
	map.fills = fills
	map.tooltips = tips
	map.selected = selected_pid
	map.province_clicked.connect(func(n: String) -> void:
		selected_pid = n
		rebuild())
	card.add_child(map)
	var legend := UI.hbox(12)
	for id in _legend_ids(by_prov):
		legend.add_child(UI.party_tag(m, str(id), UI.FS_SMALL, false))
	card.add_child(legend)

	_territory_card(right)
	var det := UI.card(right, selected_pid if selected_pid != "" else "Circunscripción", "", UI.WARN)
	if selected_pid == "":
		empty_note(det, "Selecciona una provincia en el mapa para ver su reparto de escaños.")
		return
	var cons: Dictionary = {}
	for c in m.constituencies:
		if str((c as Dictionary)["name"]) == selected_pid:
			cons = c
	det.add_child(UI.label("%s · %d escaños" % [str(cons.get("autonomous_community", "")), int(cons.get("seats", 0))], UI.FS_BODY, UI.MUTED))
	var alloc2: Dictionary = by_prov.get(str(cons.get("id", "")), {}) if mode == "projection" else m.election.result_alloc(str(cons.get("id", "")))
	var ids: Array = alloc2.keys()
	ids.sort_custom(func(x, y) -> bool: return int(alloc2[x]) > int(alloc2[y]))
	for id in ids:
		if int(alloc2[id]) <= 0:
			continue
		var row := UI.hbox(8)
		var tag := UI.party_tag(m, str(id))
		tag.custom_minimum_size = Vector2(110, 0)
		row.add_child(tag)
		row.add_child(UI.meter(float(alloc2[id]), float(maxi(1, int(cons.get("seats", 1)))), m.party_color(str(id)), 8))
		row.add_child(UI.label("%d" % int(alloc2[id]), UI.FS_BODY, UI.TEXT, true))
		det.add_child(row)
	if mode == "projection":
		var shares: Dictionary = (proj["shares"] as Dictionary).get(selected_pid, {})
		det.add_child(UI.hsep())
		det.add_child(UI.label("VOTO ESTIMADO", UI.FS_TINY, UI.MUTED, true))
		var sids: Array = shares.keys()
		sids.sort_custom(func(x, y) -> bool: return float(shares[x]) > float(shares[y]))
		for id in sids.slice(0, 6):
			var r2 := UI.hbox(8)
			var tg := UI.party_tag(m, str(id), UI.FS_SMALL, false)
			tg.custom_minimum_size = Vector2(110, 0)
			r2.add_child(tg)
			r2.add_child(UI.fill())
			r2.add_child(UI.label("%.1f%%" % float(shares[id]), UI.FS_SMALL, UI.TEXT))
			det.add_child(r2)
		var bonus := float(m.d("province_bonus").get(selected_pid, 0.0))
		if bonus > 0.0:
			det.add_child(UI.label("Tu implantación local suma +%.1f%% de voto por tus actos." % (bonus * 100.0), UI.FS_SMALL, UI.GOOD))

## Un partido territorial (regionalista / independentista) solo presenta listas donde ha pagado para hacerlo.
func _territory_card(parent: Node) -> void:
	var terr: Array = m.a("player_territory")
	if terr.is_empty() or Rules.REGIONALIST_TERRITORY.has(m.pid()):
		return
	var all := m.communities()
	var covered := terr.size() >= all.size()
	var c := UI.card(parent, "Implantación territorial", "%d de %d comunidades" % [terr.size(), all.size()], UI.GOOD)
	c.add_child(UI.wrap_label("Te presentas en: %s." % ", ".join(terr), UI.FS_BODY, UI.TEXT))
	if covered:
		return
	var why: String = m.campaign.can_expand()
	if why != "":
		c.add_child(UI.wrap_label(why, UI.FS_SMALL, UI.FAINT))
		return
	c.add_child(UI.wrap_label("Presentar candidatura en otra comunidad cuesta dinero y arranca con poco apoyo. Tienes %s." % Rules.money(m.funds), UI.FS_SMALL, UI.MUTED))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	var names: Array = []
	for cn in all:
		if not terr.has(cn):
			names.append(cn)
	names.sort_custom(func(a, b) -> bool: return m.community_share([a]) > m.community_share([b]))
	for cn in names:
		var cname := str(cn)
		var cost: int = m.campaign.expansion_cost(cname)
		var b := UI.button("%s · %s" % [cname, Rules.money(float(cost))], "secondary", func() -> void:
			var err: String = m.campaign.expand_territory(cname)
			if err != "":
				m.publish("No se puede ampliar", err, "REDACCIÓN", "negative")
			rebuild())
		b.custom_minimum_size = Vector2(0, 30)
		b.disabled = m.funds < float(cost)
		fl.add_child(b)
	c.add_child(fl)

func _winner(alloc: Dictionary) -> String:
	var best := ""
	var n := -1
	for id in alloc.keys():
		if int(alloc[id]) > n:
			n = int(alloc[id])
			best = str(id)
	return best

func _legend_ids(by_prov: Dictionary) -> Array:
	var seen := {}
	for cid in by_prov.keys():
		var w := _winner(by_prov[cid])
		if w != "":
			seen[w] = true
	var ids: Array = seen.keys()
	ids.sort()
	return ids
