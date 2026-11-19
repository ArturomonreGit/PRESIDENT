class_name PanelScreen
extends Screen
## Panel de gobierno (presidente) o de ministerio (ministro): red de medidas, indicadores y grupos al estilo Democracy 4.
## Las medidas del ámbito del jugador se decretan (coste de capital político y retardo de efectos) o se llevan al Congreso como ley.

static var sel_kind := ""
static var sel_id := ""
static var focus := ""
static var pending: Dictionary = {}
static var forced: Dictionary = {}

var net: PolicyNetwork
var detail: VBoxContainer
var editable: Array = []

func build() -> void:
	m.eco.ensure()
	m.world.ensure()
	m.exec.ensure()
	var kind := m.exec.post_kind()
	if kind == "none":
		_no_access()
		return
	editable = _editable_areas(kind)
	if focus != "" and not editable.has(focus):
		focus = ""
	var title := "Panel de gobierno" if kind == "president" else "Panel del ministerio de %s" % m.exec.ministry_name(m.exec.post_index())
	var sub := "Pasa el ratón por un nodo para ver sus vínculos: verde = favorable, rojo = adverso. Haz clic para actuar sobre una medida."
	if kind == "minister":
		sub = "Solo puedes actuar sobre las medidas de tu ámbito (anillo coloreado); el resto del país lo ves en gris."
	header(title, sub)
	_topbar(kind)
	_area_pills()
	var row := UI.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	net = PolicyNetwork.new()
	net.custom_minimum_size = Vector2(520, maxf(560.0, shell.scroll.size.y - 205.0))
	row.add_child(net)
	net.setup(m, editable)
	net.focus_area = focus
	net.set_focus(focus)
	net.picked.connect(_on_pick)
	detail = UI.vbox(10)
	detail.custom_minimum_size = Vector2(420, 0)
	row.add_child(detail)
	if sel_kind != "" and net.nodes.has(_key(sel_kind, sel_id)):
		net.select(_key(sel_kind, sel_id))
	_refresh_marks()
	_detail()

func _key(kind: String, id: String) -> String:
	match kind:
		"policy": return "p:" + id
		"ind": return "i:" + id
		"core": return "q:" + id
		"group": return "g:" + id
		"center": return "c:gov"
	return ""

func _editable_areas(kind: String) -> Array:
	var out: Array = []
	var owners := m.exec.area_owners()
	for a in Policies.areas():
		var aid := str((a as Dictionary)["id"])
		var idx := int(owners.get(aid, -1))
		if kind == "minister":
			if idx == m.exec.post_index():
				out.append(aid)
		elif m.exec.can_manage(idx):
			out.append(aid)
	return out

# ---------------------------------------------------------------- sin acceso (oposición)
func _no_access() -> void:
	header("Panel de gobierno", "Estás en la oposición: el Gobierno lo dirige la IA y tu partido no tiene cartera, así que no tienes acceso al panel.")
	var cl := columns(1.0, 1.0)
	var c := UI.card(cl[0], "¿Qué puedes hacer desde la oposición?", "", UI.ACCENT)
	for t in ["Presentar proposiciones de ley en el Taller de leyes (necesitan apoyo del Congreso).", "Votar cada ley en el Pleno y negociar con otros grupos.",
			"Vigilar el país en Indicadores, Economía y Sociedad para preparar tu programa.", "Ganar las elecciones o una moción de censura para gobernar."]:
		c.add_child(UI.wrap_label("• " + t, UI.FS_BODY, UI.TEXT))
	var gov := str(m.s.get("government_party_id", ""))
	var c2 := UI.card(cl[1], "Quién gobierna", "", UI.WARN)
	c2.add_child(UI.hbox(8))
	var r := UI.hbox(8)
	r.add_child(UI.party_tag(m, gov, UI.FS_LEAD, true))
	r.add_child(UI.label("Apoyo al Gobierno %.0f / 100" % m.gov.approval(), UI.FS_BODY, UI.MUTED))
	c2.add_child(r)
	var log: Array = m.exec.st().get("decrees", [])
	c2.add_child(UI.label("ÚLTIMAS DECISIONES DEL GOBIERNO", UI.FS_TINY, UI.MUTED, true))
	var shown := 0
	for i in range(log.size() - 1, -1, -1):
		var ld: Dictionary = log[i]
		c2.add_child(UI.wrap_label("• %s" % str(ld.get("text", ld.get("title", ""))), UI.FS_SMALL, UI.TEXT))
		shown += 1
		if shown >= 7:
			break
	if shown == 0:
		empty_note(c2, "Todavía no ha tomado decisiones por decreto.")

# ---------------------------------------------------------------- cabecera
func _topbar(kind: String) -> void:
	var r := UI.hbox(10)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(r)
	r.add_child(UI.chip("Capital político %.0f / %.0f  (+%.1f/mes)" % [m.exec.capital(), Executive.MAX_CAPITAL, m.exec.monthly_income()], UI.ACCENT, true))
	var dir := m.exec.directive()
	r.add_child(UI.chip("Directiva %.0f" % dir, UI.GOOD if dir >= 50.0 else (UI.WARN if dir >= 30.0 else UI.BAD)))
	r.add_child(UI.chip("Apoyo al Gobierno %.0f" % m.gov.approval(), UI.TEXT))
	var bal := m.eco.balance()
	r.add_child(UI.chip("Saldo %s bn € (%.1f %% PIB)" % [UI.signed(bal, 1), m.eco.balance_pct()], UI.GOOD if bal >= 0.0 else UI.BAD))
	r.add_child(UI.fill())
	var changed := 0
	for it in Policies.measures():
		if not is_equal_approx(m.eco.value(str((it as Dictionary)["id"])), float((it as Dictionary)["base"])):
			changed += 1
	r.add_child(UI.label("%d medidas distintas del inicio · %s" % [changed, "retardo de efectos de 6 a 18 meses"], UI.FS_SMALL, UI.FAINT))

func _area_pills() -> void:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 4)
	fl.add_child(UI.pill("Vista general", focus == "", func() -> void:
		focus = ""
		rebuild(), false))
	for aid in PolicyNetwork.AREA_ORDER:
		if not editable.has(aid):
			continue
		var a := Policies.area(str(aid))
		var col := Glyphs.area_color(str(aid))
		fl.add_child(UI.pill(str(a.get("name", aid)), focus == str(aid), func() -> void:
			focus = str(aid)
			rebuild(), false, col))
	add_child(fl)

# ---------------------------------------------------------------- selección
func _on_pick(kind: String, id: String) -> void:
	if kind == "area":
		if editable.has(id):
			focus = id
			sel_kind = ""
			sel_id = ""
			rebuild()
		else:
			sel_kind = "area"
			sel_id = id
			net.select("")
			_detail()
		return
	sel_kind = kind
	sel_id = id
	_detail()
	if kind == "policy":
		_open_dialog(id)

func _refresh_marks() -> void:
	var mk: Dictionary = {}
	for k in pending.keys():
		mk["p:" + str(k)] = true
	net.marked = mk
	net.queue_redraw()

func _detail() -> void:
	UI.clear_children(detail)
	_refresh_marks()
	match sel_kind:
		"policy": _policy(Policies.measure(sel_id))
		"ind", "core": _variable(sel_id, sel_kind == "core")
		"group": _group(sel_id)
		"center": _center()
		"area": _area_info(sel_id)
		_: _intro()

func _select_policy(mid: String) -> void:
	sel_kind = "policy"
	sel_id = mid
	var area := str(Policies.measure(mid).get("area", ""))
	if focus != "" and focus != area:
		focus = area if editable.has(area) else ""
		rebuild()
		return
	net.select("p:" + mid)
	_detail()

# ---------------------------------------------------------------- panel de inicio
func _intro() -> void:
	var c := UI.card(detail, "Cómo funciona el panel", "", UI.ACCENT)
	var tips := [
		"Círculos pequeños del borde: las medidas de cada área (sectores de color).",
		"Círculos con icono: indicadores del país y servicios públicos. Verde = mejor que al inicio, rojo = peor.",
		"Círculos con letra: grupos sociales; el centro es el apoyo al Gobierno.",
		"Toca una medida para decretarla o llevarla al Congreso. Aro dorado = medida distinta del inicio.",
		"Haz clic en el icono de un área para ampliarla.",
	]
	for t in tips:
		c.add_child(UI.wrap_label("• " + t, UI.FS_SMALL, UI.TEXT))
	var lg := UI.hbox(10)
	lg.add_child(_legend(UI.GOOD, "favorable"))
	lg.add_child(_legend(UI.BAD, "adverso"))
	lg.add_child(_legend(UI.ACCENT, "neutro"))
	c.add_child(lg)
	_decrees_card()
	_mini_objectives()

func _legend(col: Color, text: String) -> HBoxContainer:
	var h := UI.hbox(5)
	var bar := ColorRect.new()
	bar.color = col
	bar.custom_minimum_size = Vector2(22, 4)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(UI.label(text, UI.FS_SMALL, UI.MUTED))
	return h

func _decrees_card() -> void:
	var c := UI.card(detail, "Decisiones recientes", "", UI.GOLD)
	var log: Array = m.exec.st().get("decrees", [])
	var shown := 0
	for i in range(log.size() - 1, -1, -1):
		var ld: Dictionary = log[i]
		c.add_child(UI.wrap_label("• %s" % str(ld.get("text", ld.get("title", ""))), UI.FS_SMALL, UI.TEXT))
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		empty_note(c, "Aún no hay decretos. Elige una medida del panel para empezar.")

func _mini_objectives() -> void:
	var list := m.exec.objectives()
	if list.is_empty():
		return
	var c := UI.card(detail, "Mínimos de la directiva", "", UI.WARN)
	for o in list:
		var od: Dictionary = o
		var metric := str(od["metric"])
		var now := _metric_now(metric)
		var status := str(od["status"])
		var r := UI.hbox(8)
		var t := UI.wrap_label("%s: %.1f → %.1f (ahora %.1f)" % [m.exec.metric_label(metric), float(od["start"]), float(od["target"]), now], UI.FS_SMALL, UI.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		r.add_child(UI.chip("Cumplido" if status == "met" else ("Incumplido" if status == "failed" else "T%d" % Rules.turn_of(int(od["due"]))), UI.GOOD if status == "met" else (UI.BAD if status == "failed" else UI.MUTED)))
		c.add_child(r)

func _metric_now(metric: String) -> float:
	match metric:
		"deficit": return -m.eco.balance_pct()
		"unemployment": return float(m.eco.st().get("unemployment", 12.0))
		"approval": return m.gov.approval()
	if WorldSim.has(metric):
		return m.world.value(metric)
	return m.eco.quality(metric)

# ---------------------------------------------------------------- medida
func _policy(meas: Dictionary) -> void:
	if meas.is_empty():
		_intro()
		return
	var mid := str(meas["id"])
	var area := str(meas["area"])
	var owner := int(m.exec.area_owners().get(area, -1))
	var ed := editable.has(area)
	var can_decree := ed and m.exec.decreeable(meas) and m.exec.can_manage(owner)
	var cur := m.eco.value(mid)
	var acol := Glyphs.area_color(area)
	var c := UI.card(detail, str(meas["name"]), str(Policies.area(area).get("name", "")), acol)
	c.add_child(UI.wrap_label(str(meas["desc"]), UI.FS_SMALL, UI.MUTED))
	var badge := UI.hbox(6)
	if not ed:
		badge.add_child(UI.chip("Otro ministerio · solo lectura", UI.FAINT))
	elif can_decree:
		badge.add_child(UI.chip("Se puede decretar", UI.GOOD))
	else:
		badge.add_child(UI.chip("Exige una ley del Congreso", UI.WARN))
	c.add_child(badge)
	var vr := UI.hbox(10)
	vr.add_child(UI.label(Policies.value_text(meas, cur), UI.FS_H2, UI.TEXT, true))
	if pending.has(mid) and not is_equal_approx(float(pending[mid]), cur):
		vr.add_child(UI.label("→  %s" % Policies.value_text(meas, float(pending[mid])), UI.FS_LEAD, UI.ACCENT, true))
	vr.add_child(UI.fill())
	vr.add_child(UI.label("inicio: %s" % Policies.value_text(meas, float(meas["base"])), UI.FS_TINY, UI.FAINT))
	c.add_child(vr)
	c.add_child(UI.button("Abrir ficha de la medida" if ed else "Ver ficha de la medida", "primary", func() -> void: _open_dialog(mid)))
	_effects_card(meas)

func _open_dialog(mid: String) -> void:
	PolicyDialog.open(shell, m, mid, editable, func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			rebuild())

## Qué indicadores mueve la medida (siempre visible), con la dirección por paso.
func _effects_card(meas: Dictionary) -> void:
	var fx: Dictionary = meas.get("fx", {})
	var hits: Dictionary = meas.get("hits", {})
	if fx.is_empty() and hits.is_empty():
		return
	var c := UI.card(detail, "Qué mueve esta medida", "Por cada paso adicional", UI.GOLD)
	var rows: Array = []
	for k in fx.keys():
		var sc := float(WorldSim.def(str(k))["scale"]) if WorldSim.has(str(k)) else float(WorldSim.CORE_SCALE.get(str(k), WorldSim.QUALITY_SCALE))
		var good := int(WorldSim.def(str(k)).get("good", 0)) if WorldSim.has(str(k)) else int((PolicyNetwork.CORES.get(str(k), ["", "", 1]) as Array)[2])
		var d := float(fx[k])
		rows.append({"label": WorldSim.name_of(str(k)), "value": d / maxf(0.0001, sc), "color": UI.ACCENT if good == 0 else (UI.GOOD if d * float(good) > 0.0 else UI.BAD), "id": str(k)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	if not rows.is_empty():
		var bars := DriverBars.new()
		bars.custom_minimum_size.x = 220.0
		bars.label_w = 130.0
		bars.value_fmt = "%+.2f σ"
		bars.rows = rows.slice(0, 7)
		c.add_child(bars)
	var ks: Array = hits.keys()
	ks.sort_custom(func(a, b) -> bool: return absf(float(hits[a])) > absf(float(hits[b])))
	var parts: Array = []
	for g in ks.slice(0, 5):
		parts.append("%s %s" % [Policies.group_name(str(g)), UI.signed(float(hits[g]), 1)])
	if not parts.is_empty():
		c.add_child(UI.wrap_label("Grupos: " + " · ".join(parts), UI.FS_SMALL, UI.MUTED))

# ---------------------------------------------------------------- indicador / servicio
func _variable(id: String, is_core: bool) -> void:
	var name := WorldSim.name_of(id)
	var domain := str(WorldSim.def(id).get("domain", str((PolicyNetwork.CORES.get(id, ["", "tax", 1]) as Array)[1])))
	var acol := Glyphs.area_color(domain)
	var c := UI.card(detail, name, str(Policies.area(domain).get("name", "")), acol)
	var nd := {"kind": "core" if is_core else "ind", "id": id}
	var vtxt := net.value_text(nd) if net != null else ""
	var top := UI.hbox(10)
	top.add_child(UI.label(vtxt, UI.FS_H1, UI.TEXT, true))
	top.add_child(UI.fill())
	c.add_child(top)
	if not is_core:
		c.add_child(UI.wrap_label(str(WorldSim.def(id)["desc"]), UI.FS_SMALL, UI.MUTED))
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(300, 150)
	chart.show_end_labels = false
	chart.allow_negative = true
	var vals: Array = []
	var labels: Array = []
	if not is_core:
		vals = m.world.series(id)
		labels = m.world.labels()
		chart.value_fmt = "%." + str(int(WorldSim.def(id).get("dec", 1))) + "f"
		chart.ref_line = float(WorldSim.def(id)["start"])
		chart.ref_label = "inicio"
	else:
		for h in m.eco.history():
			var hd: Dictionary = h
			match id:
				"growth", "unemployment", "inflation": vals.append(float(hd.get(id, 0.0)))
				"deficit": vals.append(float(hd.get("deficit_pct", 0.0)))
				_: vals.append(float((hd.get("quality", {}) as Dictionary).get(id, 0.0)))
			labels.append(str(hd.get("label", "")))
		chart.value_fmt = "%.1f"
	chart.series = [{"id": id, "name": name, "color": acol, "values": vals, "width": 3.0}]
	chart.x_labels = labels
	c.add_child(chart)
	if not is_core:
		var parts := m.world.target_parts(id)
		var good := int(WorldSim.def(id).get("good", 0))
		var rows: Array = []
		for p in parts:
			var pd: Dictionary = p
			var v := float(pd["value"])
			rows.append({"label": str(pd["label"]), "value": v, "color": UI.ACCENT if good == 0 else (UI.GOOD if v * float(good) > 0.0 else UI.BAD)})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
		if not rows.is_empty():
			c.add_child(UI.label("¿QUÉ LO EMPUJA?", UI.FS_TINY, UI.MUTED, true))
			var bars := DriverBars.new()
			bars.custom_minimum_size.x = 220.0
			bars.label_w = 130.0
			bars.value_fmt = "%+." + str(maxi(1, int(WorldSim.def(id).get("dec", 1)))) + "f"
			bars.rows = rows.slice(0, 5)
			c.add_child(bars)
		c.add_child(UI.button("Abrir en País", "ghost", func() -> void:
			CountryScreen.sel = id
			shell.go("country")))
	_moving_measures(id)

func _moving_measures(id: String) -> void:
	var list := m.world.policy_drivers(id)
	if list.is_empty():
		return
	var c := UI.card(detail, "Medidas que lo mueven", "Haz clic para abrirlas", UI.GOLD)
	var shown := 0
	for it in list:
		var pd: Dictionary = it
		var meas := Policies.measure(str(pd["measure"]))
		var mid := str(pd["measure"])
		var good := int(WorldSim.def(id).get("good", 0)) if WorldSim.has(id) else int((PolicyNetwork.CORES.get(id, ["", "", 1]) as Array)[2])
		var ps := float(pd["per_step"]) * float(good)
		var row := UI.select_row(c, false, func() -> void: _select_policy(mid), Glyphs.area_color(str(meas["area"])), 30.0)
		var nm := UI.label(str(meas["name"]), UI.FS_SMALL, UI.TEXT)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UI.label(Policies.value_text(meas, m.eco.value(mid)), UI.FS_TINY, UI.FAINT))
		row.add_child(UI.label("al subir: mejora" if ps > 0.0 else ("al subir: empeora" if ps < 0.0 else "·"), UI.FS_TINY, UI.GOOD if ps > 0.0 else (UI.BAD if ps < 0.0 else UI.MUTED), true))
		UI.pass_clicks(row)
		shown += 1
		if shown >= 7:
			break

# ---------------------------------------------------------------- grupo
func _group(id: String) -> void:
	var g := Policies.entry(Policies.groups(), id)
	var sat := m.eco.satisfaction(id)
	var c := UI.card(detail, str(g.get("name", id)), "%d %% de la población" % int(g.get("share", 0)), UI.GOOD)
	c.add_child(UI.label("%.0f / 100" % sat, UI.FS_H1, UI.GOOD if sat >= 55.0 else (UI.BAD if sat < 40.0 else UI.WARN), true))
	var d := m.eco.sat_delta(id, 6)
	c.add_child(UI.label("%s en 6 meses" % UI.signed(d, 1), UI.FS_SMALL, UI.delta_color(d)))
	c.add_child(UI.wrap_label(str(g.get("desc", "")), UI.FS_SMALL, UI.MUTED))
	var rows: Array = []
	for it in m.eco.group_drivers(id):
		var dd: Dictionary = it
		var v := float(dd["value"])
		rows.append({"label": str(dd["label"]), "value": v, "color": UI.GOOD if v >= 0.0 else UI.BAD})
	var pos: Array = rows.filter(func(r): return float((r as Dictionary)["value"]) > 0.0).slice(0, 4)
	var neg: Array = rows.filter(func(r): return float((r as Dictionary)["value"]) < 0.0)
	neg = neg.slice(maxi(0, neg.size() - 4))
	var all: Array = pos + neg
	if all.is_empty():
		empty_note(c, "Nada les mueve de su punto de partida por ahora.")
	else:
		c.add_child(UI.label("¿QUÉ LES MUEVE?", UI.FS_TINY, UI.MUTED, true))
		var bars := DriverBars.new()
		bars.custom_minimum_size.x = 220.0
		bars.label_w = 150.0
		bars.rows = all
		c.add_child(bars)

func _center() -> void:
	var c := UI.card(detail, "Apoyo al Gobierno", "", UI.ACCENT)
	c.add_child(UI.label("%.0f / 100" % m.gov.approval(), UI.FS_H1, UI.TEXT, true))
	c.add_child(UI.label("Estabilidad parlamentaria %.0f" % m.gov.stability(), UI.FS_SMALL, UI.MUTED))
	var rows: Array = []
	for g in Policies.groups():
		var gd: Dictionary = g
		var v := (m.eco.satisfaction(str(gd["id"])) - 50.0) * float(gd["share"]) / 100.0
		rows.append({"label": str(gd["name"]), "value": v, "color": UI.GOOD if v >= 0.0 else UI.BAD})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	c.add_child(UI.label("APORTACIÓN DE CADA GRUPO", UI.FS_TINY, UI.MUTED, true))
	var bars := DriverBars.new()
	bars.custom_minimum_size.x = 220.0
	bars.label_w = 120.0
	bars.rows = rows.slice(0, 5) + rows.slice(maxi(5, rows.size() - 3))
	c.add_child(bars)

func _area_info(aid: String) -> void:
	var a := Policies.area(aid)
	var c := UI.card(detail, str(a.get("name", aid)), "", Glyphs.area_color(aid))
	c.add_child(UI.wrap_label(str(a.get("desc", "")), UI.FS_SMALL, UI.MUTED))
	var owners := m.exec.area_owners()
	var idx := int(owners.get(aid, -1))
	c.add_child(UI.label("Ministerio: %s" % m.exec.ministry_name(idx), UI.FS_BODY, UI.TEXT, true))
	c.add_child(UI.label("Partido: %s" % m.party_short(m.exec.party_of(idx)), UI.FS_SMALL, UI.MUTED))
	c.add_child(UI.wrap_label("No es tu ámbito: puedes ver sus medidas e indicadores, pero no decretarlas.", UI.FS_SMALL, UI.FAINT))
