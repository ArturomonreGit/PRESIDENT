extends Screen
## Finanzas del partido.

func build() -> void:
	var income := m.weekly_income_forecast()
	var expense := m.weekly_expense_forecast()
	kpi_row([
		{"title": "Fondos", "value": Rules.money(m.funds), "color": UI.WARN if m.funds < 60000.0 else UI.TEXT},
		{"title": "Ingresos semanales", "value": Rules.money(income), "color": UI.GOOD, "sub": "cuotas y donaciones"},
		{"title": "Gastos semanales", "value": Rules.money(expense), "color": UI.BAD, "sub": "estructura"},
		{"title": "Militancia", "value": Rules.money(float(int(m.s.get("members", 1200)))), "sub": "afiliados"},
	])
	var c := UI.card(self, "Movimientos recientes", "", UI.WARN)
	var log := m.a("finance_log")
	if log.is_empty():
		empty_note(c, "Todavía no hay movimientos.")
	for item in log.slice(0, 30):
		var e: Dictionary = item
		var row := UI.hbox(12)
		var d := UI.label(str(e.get("date", "")), UI.FS_SMALL, UI.FAINT)
		d.custom_minimum_size = Vector2(110, 0)
		row.add_child(d)
		var l := UI.label(str(e.get("label", "")), UI.FS_BODY, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var amt := float(e.get("amount", 0.0))
		var al := UI.label(("+" if amt > 0 else "−") + Rules.money(absf(amt)), UI.FS_BODY, UI.GOOD if amt > 0 else UI.BAD, true)
		al.custom_minimum_size = Vector2(120, 0)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(al)
		c.add_child(row)
