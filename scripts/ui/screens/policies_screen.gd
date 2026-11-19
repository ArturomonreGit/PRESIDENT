class_name PoliciesScreen
extends Screen
## Medidas de gobierno a pantalla completa (estilo Democracy 4): áreas | medidas | ficha con deslizador.
## El presidente actúa sobre todas las áreas; un ministro solo sobre las de su cartera (el resto en solo lectura).

var browser: PolicyBrowser
var _hud: HBoxContainer
var editable: Array = []

func wants_full() -> bool:
	return m.exec.post_kind() != "none"

func build() -> void:
	m.eco.ensure()
	m.world.ensure()
	m.exec.ensure()
	var kind := m.exec.post_kind()
	if kind == "none":
		_no_access()
		return
	editable = _editable_areas(kind)
	_hud = UI.hbox(10)
	_hud.custom_minimum_size = Vector2(0, 46)
	add_child(_hud)
	_fill_hud()
	browser = PolicyBrowser.create(shell, m, "gov", editable, _fill_hud)
	add_child(browser)

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

func _fill_hud() -> void:
	UI.clear_children(_hud)
	var cap := m.exec.capital()
	hud_stat(_hud, "Capital político", "%.0f / %.0f  (+%.1f/mes)" % [cap, Executive.MAX_CAPITAL, m.exec.monthly_income()], UI.D4_BLUE_D)
	var dir := m.exec.directive()
	hud_stat(_hud, "Directiva", "%.0f" % dir, UI.GOOD if dir >= 50.0 else (UI.WARN if dir >= 30.0 else UI.BAD))
	hud_stat(_hud, "Apoyo al Gobierno", "%.0f" % m.gov.approval())
	var bal := m.eco.balance()
	hud_stat(_hud, "Saldo público", "%s bn €  ·  %.1f %% PIB" % [UI.signed(bal, 1), m.eco.balance_pct()], UI.GOOD if bal >= 0.0 else UI.BAD)
	var changed := 0
	for it in Policies.measures():
		if not is_equal_approx(m.eco.value(str((it as Dictionary)["id"])), float((it as Dictionary)["base"])):
			changed += 1
	hud_stat(_hud, "Medidas cambiadas", "%d de %d" % [changed, Policies.measures().size()], UI.TEXT, "Medidas distintas a las del inicio de la partida")
	_hud.add_child(UI.fill())
	var kind := m.exec.post_kind()
	var who := "Presidencia del Gobierno" if kind == "president" else "Ministerio de %s" % m.exec.ministry_name(m.exec.post_index())
	_hud.add_child(UI.label(who.to_upper(), UI.FS_SMALL, Color("#3B6A99"), true))

func _no_access() -> void:
	header("Medidas de gobierno", "Estás en la oposición: el Gobierno lo dirige la IA y tu partido no tiene cartera.")
	var cl := columns(1.0, 1.0)
	var c := UI.card(cl[0], "¿Qué puedes hacer desde la oposición?", "", UI.ACCENT)
	for t in ["Presentar proposiciones de ley en el Taller de leyes (necesitan apoyo del Congreso).", "Votar cada ley en el Pleno y negociar con otros grupos.",
			"Vigilar el país en Indicadores, Economía y Sociedad para preparar tu programa.", "Ganar las elecciones o una moción de censura para gobernar."]:
		c.add_child(UI.wrap_label("• " + t, UI.FS_BODY, UI.TEXT))
	var gov := str(m.s.get("government_party_id", ""))
	var c2 := UI.card(cl[1], "Quién gobierna", "", UI.WARN)
	var r := UI.hbox(8)
	r.add_child(UI.party_tag(m, gov, UI.FS_LEAD, true))
	r.add_child(UI.label("Apoyo al Gobierno %.0f / 100" % m.gov.approval(), UI.FS_BODY, UI.MUTED))
	c2.add_child(r)
