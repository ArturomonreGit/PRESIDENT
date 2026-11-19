extends SceneTree
## Coherencia del reparto de partidos: cada partido tiene encuesta, perfil ideológico completo y territorio si es regional.
var failures := 0
func check(cond: bool, label: String) -> void:
	if cond: print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)

func _initialize() -> void:
	var ids: Array = []
	for p in DataStore.parties():
		var d: Dictionary = p
		var id := str(d["id"])
		ids.append(id)
		check(Rules.BASE_POLL.has(id), "%s tiene encuesta inicial" % id)
		check((d["ideology_profile"] as Dictionary).size() == 20, "%s tiene perfil de 20 ideologías" % id)
		check(str(d.get("color", "")).begins_with("#") and str(d.get("short_name", "")) != "", "%s tiene color y siglas" % id)
	for need in ["pp", "psoe", "vox", "sumar", "podemos", "salf", "adelante", "alianca", "erc", "junts"]:
		check(ids.has(need), "el escenario incluye %s" % need)
	var total := 0.0
	for k in Rules.BASE_POLL.keys():
		total += float(Rules.BASE_POLL[k])
	check(absf(total - 100.0) < 0.01, "las encuestas iniciales suman 100 (%.2f)" % total)
	check(Rules.REGIONALIST_TERRITORY.has("adelante") and (Rules.REGIONALIST_TERRITORY["adelante"]["communities"] as Array).has("Andalucía"), "Adelante Andalucía solo se presenta en Andalucía")
	check(Rules.REGIONALIST_TERRITORY.has("alianca") and (Rules.REGIONALIST_TERRITORY["alianca"]["communities"] as Array).has("Cataluña"), "Aliança Catalana solo se presenta en Cataluña")
	for id in ids:
		var l := Leader.generate(str(id), 1)
		check(str(l["name"]) != "" and str(l["surname"]) != "", "líder generado para %s" % id)
	print("Fallos: ", failures)
	quit(1 if failures > 0 else 0)
