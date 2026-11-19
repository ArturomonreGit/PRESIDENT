class_name IrpfEditor
extends RefCounted
## Editor de la escala del IRPF: añade o quita tramos y fija desde qué renta (miles de €) y qué tipo marginal se aplica en cada uno.

## `scale`: escala que se edita. `baseline`: escala vigente (para comparar). `on_change(nueva_escala)` se llama al editar.
static func build(parent: Control, m: GameModel, scale: Array, baseline: Array, on_change: Callable, editable: bool = true) -> void:
	var cur := Irpf.sanitize(scale)
	# Hasta 5 tramos en una columna; con más, dos columnas para que quepa sin desplazarse.
	var halves := 1 if cur.size() <= 5 else 2
	var per := int(ceil(float(cur.size()) / float(halves)))
	var wrap := UI.hbox(24)
	parent.add_child(wrap)
	for h in range(halves):
		var col := UI.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_child(col)
		var head := UI.hbox(6)
		for pair in [["TRAMO", 46.0], ["DESDE (k€)", 120.0], ["TIPO", 110.0], ["HASTA", 80.0]]:
			var l := UI.label(str(pair[0]), UI.FS_TINY, UI.FAINT, true)
			l.custom_minimum_size = Vector2(float(pair[1]), 0)
			head.add_child(l)
		col.add_child(head)
		for i in range(h * per, mini(cur.size(), (h + 1) * per)):
			_row(col, m, cur, i, editable, on_change)
	if editable:
		var act := UI.hbox(8)
		var add := UI.button("+ Añadir tramo", "secondary", func() -> void:
			var last: Dictionary = cur[cur.size() - 1]
			var nb3: Array = cur.duplicate(true)
			var nf := snappedf(float(last["from"]) * 1.4 + 10.0, 0.5)
			nb3.append({"from": nf, "rate": minf(Irpf.MAX_RATE, float(last["rate"]) + 2.0)})
			on_change.call_deferred(Irpf.sanitize(nb3)))
		add.disabled = cur.size() >= Irpf.MAX_BRACKETS
		act.add_child(add)
		act.add_child(UI.button("Volver a la escala vigente", "ghost", func() -> void:
			on_change.call_deferred(baseline.duplicate(true))))
		parent.add_child(act)
	# Resumen
	var avg := Irpf.average_rate(cur)
	var avg0 := Irpf.average_rate(baseline)
	var fx := Irpf.delta_effects(baseline, cur, m.eco.irpf_base_revenue())
	var rev := float(fx["rev"]) * m.eco.gdp() / float(m.eco.st().get("gdp0", 1462.0))
	parent.add_child(UI.label("Tipo medio efectivo %.1f %% (vigente %.1f %%) · Tipo máximo %s %% · Recaudación %s bn €/año" % [avg, avg0, _num(Irpf.top_rate(cur)), UI.signed(rev, 1)], UI.FS_SMALL, UI.TEXT, true))
	var samples := []
	for inc in [15.0, 30.0, 60.0, 120.0]:
		samples.append("%s k€ → %.1f %%" % [_num(float(inc)), Irpf.rate_at(cur, float(inc))])
	parent.add_child(UI.label("Lo que paga de media quien gana: " + " · ".join(samples), UI.FS_TINY, UI.MUTED))

static func _row(parent: Control, m: GameModel, cur: Array, i: int, editable: bool, on_change: Callable) -> void:
	var idx := i
	var b: Dictionary = cur[i]
	var row := UI.hbox(6)
	var n := UI.label("%d" % (i + 1), UI.FS_BODY, UI.TEXT, true)
	n.custom_minimum_size = Vector2(46, 0)
	row.add_child(n)
	var from_sb := SpinBox.new()
	from_sb.min_value = 0.0
	from_sb.max_value = 1000.0
	from_sb.step = 0.05
	from_sb.value = float(b["from"])
	from_sb.editable = editable and i > 0
	from_sb.custom_minimum_size = Vector2(120, 0)
	from_sb.value_changed.connect(func(v: float) -> void:
		var nb := Irpf.sanitize(_with(cur, idx, "from", v))
		on_change.call_deferred(nb))
	row.add_child(from_sb)
	var rate_sb := SpinBox.new()
	rate_sb.min_value = 0.0
	rate_sb.max_value = Irpf.MAX_RATE
	rate_sb.step = 0.5
	rate_sb.suffix = "%"
	rate_sb.value = float(b["rate"])
	rate_sb.editable = editable
	rate_sb.custom_minimum_size = Vector2(110, 0)
	rate_sb.value_changed.connect(func(v: float) -> void:
		on_change.call_deferred(Irpf.sanitize(_with(cur, idx, "rate", v))))
	row.add_child(rate_sb)
	var hi := "en adelante" if i + 1 >= cur.size() else "%s k€" % _num(float((cur[i + 1] as Dictionary)["from"]))
	var hl := UI.label(hi, UI.FS_SMALL, UI.MUTED)
	hl.custom_minimum_size = Vector2(80, 0)
	hl.clip_text = true
	row.add_child(hl)
	if editable:
		var del := UI.button("✕", "ghost", func() -> void:
			var nb2: Array = cur.duplicate(true)
			nb2.remove_at(idx)
			on_change.call_deferred(Irpf.sanitize(nb2)))
		del.tooltip_text = "Quitar tramo"
		del.disabled = cur.size() <= 1
		row.add_child(del)
	parent.add_child(row)

static func _with(scale: Array, idx: int, key: String, v: float) -> Array:
	var nb: Array = scale.duplicate(true)
	(nb[idx] as Dictionary)[key] = v
	return nb

static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")
