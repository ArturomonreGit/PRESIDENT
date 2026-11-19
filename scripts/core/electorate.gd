class_name Electorate
extends RefCounted
## Motor de votantes. La población se modela como «cohortes» (arquetipo social × territorio): cada una tiene
## sus ideas (tres ejes), los temas que le importan, su fidelidad a un partido, su enfado y su humor con el
## Gobierno. De ahí salen, partido a partido, la probabilidad de voto y la de abstenerse; la intención de voto
## nacional es la suma ponderada de todas las cohortes.
##
## Qué lo mueve (todo con memoria, nada se resuelve de golpe):
##  · tendencias globales (giro a la derecha, ola progresista, desafección, polarización…) que desplazan las
##    ideas de cada cohorte y los temas de moda;
##  · reacciones a leyes, pactos, escándalos, debates y entrevistas, cohorte a cohorte (cada una por sus intereses);
##  · enfado y gratitud por partido, que se olvidan despacio; la fidelidad se refuerza votando y se erosiona;
##  · gestión del Gobierno (el humor de cada cohorte con él) y memoria del último mandato;
##  · valencia de cada partido (imagen, impulso) con ruido más grande para los partidos pequeños;
##  · abstención por alejamiento, enfado y clima de desafección;
##  · el día de las elecciones hay un último vuelco, un error sistemático de las encuestas y un golpe de participación.
##
## Las encuestas que ve el jugador son esta opinión real más un error de muestreo. La clave de cada cohorte es
## «arquetipo|bloque»; los bloques son las comunidades en las que compite algún partido regional y «rest».

const PATH := "res://data/scenarios/spain/electorate.json"
const K_DIST := 3.0
const AX_W := [1.0, 0.9, 0.5]
const K_ISSUE := 1.2
const K_GOV := 1.5
const K_ANTI := 1.6
const RHO_DAY := 0.985
const SIG_DAY := 0.022
const HISTORY_CAP := 520
const ABST := "abst"

var m: GameModel
var _cfg: Dictionary = {}
var _cache: Dictionary = {}
var _arch_idx: Dictionary = {}
var _building := false

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- datos y estado
func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = DataStore.read_json(PATH)
		_cfg = d if typeof(d) == TYPE_DICTIONARY else {}
		for a in _cfg.get("archetypes", []):
			_arch_idx[str((a as Dictionary)["id"])] = a
	return _cfg

func archetype(id: String) -> Dictionary:
	cfg()
	return _arch_idx.get(id, {})

func st() -> Dictionary:
	return m.d("electorate")

func ready_state() -> bool:
	return st().has("coh")

func coh() -> Dictionary:
	return st().get("coh", {})

func parties() -> Array:
	var out: Array = []
	for k in m.polls().keys():
		if str(k) != Rules.OTHERS_ID:
			out.append(str(k))
	return out

static func _logit(p: float) -> float:
	var q := clampf(p, 0.001, 0.999)
	return log(q / (1.0 - q))

static func _sigm(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))

func _hnoise(key: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key + str(m.s.get("leader_seed", 7)))
	return r.randfn(0.0, 0.32)

func _block_ids() -> Array:
	var ids: Array = []
	for id in parties():
		for c in m.territory_of(id).get("communities", []):
			if not ids.has(str(c)):
				ids.append(str(c))
	ids.sort()
	ids.append("rest")
	return ids

func _block_share(block: String, blocks: Array) -> float:
	if block == "rest":
		var rest := 1.0
		for b in blocks:
			if str(b) != "rest":
				rest -= m.community_share([str(b)])
		return maxf(0.05, rest)
	return m.community_share([block])

func _block_cfg(block: String) -> Dictionary:
	var bl: Dictionary = cfg().get("blocks", {})
	if block == "rest":
		return {"shift": [0.0, 0.0, 0.0], "turnout": 0.0}
	return bl.get(block, bl.get("_default", {"shift": [0.0, 0.0, 0.25], "turnout": 0.0}))

func competes(id: String, block: String) -> bool:
	if not m.is_regional(id):
		return true
	return (m.territory_of(id).get("communities", []) as Array).has(block)

# ---------------------------------------------------------------- creación
func ensure() -> void:
	if ready_state():
		if _cache.is_empty():
			_cache = _compute()
		return
	if m.polls().is_empty():
		return
	_init_state()

func _make_cohort(arch: Dictionary, block: String, w: float) -> Dictionary:
	var bc := _block_cfg(block)
	var sh: Array = bc["shift"]
	var ax: Array = arch["x"]
	var x: Array = [float(ax[0]) + float(sh[0]), float(ax[1]) + float(sh[1]), float(ax[2]) + float(sh[2])]
	return {"a": str(arch["id"]), "b": block, "w": w, "x": x.duplicate(), "x0": x.duplicate(), "att": {}, "anger": {}, "fav": {},
		"eps": {}, "mood": 0.0, "t0": _logit(clampf(float(arch["turnout"]) + float(bc["turnout"]), 0.2, 0.95)), "al0": 0.0}

func _init_state() -> void:
	var s := st()
	s.clear()
	var blocks := _block_ids()
	var cohs: Dictionary = {}
	for a in cfg().get("archetypes", []):
		var ad: Dictionary = a
		for b in blocks:
			var w := float(ad["share"]) * _block_share(str(b), blocks)
			cohs["%s|%s" % [str(ad["id"]), str(b)]] = _make_cohort(ad, str(b), w)
	s["coh"] = cohs
	s["blocks"] = blocks
	s["val"] = {}
	s["bias"] = {}
	s["ppos"] = {}
	s["own"] = {}
	s["incumbent"] = []
	s["trend"] = {}
	s["fatigue"] = 0.0
	s["mobil"] = 0.0
	s["pnoise"] = {}
	s["log"] = []
	s["ref"] = {}
	for k in (cfg().get("trends", {}) as Dictionary).keys():
		(s["trend"] as Dictionary)[str(k)] = m.rng.randf_range(-0.25, 0.25)
	_reweight()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		for id in parties():
			(c["eps"] as Dictionary)[id] = _hnoise("%s|%s" % [str(ck), id])
	var target: Dictionary = {}
	for k in m.polls().keys():
		target[str(k)] = float(m.polls()[k])
	# Fidelidad inicial: cada cohorte arrastra el hábito de lo que votaría sin sesgos de marca.
	var base := _compute(true)
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var arch := archetype(str(c["a"]))
		var pr: Dictionary = (base["p"] as Dictionary).get(ck, {})
		for id in pr.keys():
			if str(id) != Rules.OTHERS_ID:
				(c["att"] as Dictionary)[str(id)] = float(arch["loyalty"]) * float(pr[id]) * 1.2
	_calibrate(target, 60)
	# La alienación de partida fija la participación «normal»; se fija y se recalibra para que el reparto cuadre.
	for _round in range(3):
		var res0 := _compute(true)
		for ck in cohs.keys():
			var c: Dictionary = cohs[ck]
			c["al0"] = float((res0["al"] as Dictionary).get(ck, 0.0))
		_calibrate(target, 40)
	var res := _compute(true)
	_snapshot_ref(res)
	recompute(false)

func _reweight() -> void:
	var cohs := coh()
	var blocks: Array = st().get("blocks", [])
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		c["w"] = float(archetype(str(c["a"])).get("share", 0.0)) * _block_share(str(c["b"]), blocks)

## Si el jugador amplía su territorio aparecen nuevos bloques, que heredan el estado de «rest».
func on_territory_changed() -> void:
	if not ready_state():
		return
	var s := st()
	var blocks: Array = _block_ids()
	var cohs := coh()
	for b in blocks:
		if (s["blocks"] as Array).has(str(b)):
			continue
		for a in cfg().get("archetypes", []):
			var ad: Dictionary = a
			var src: Dictionary = cohs.get("%s|rest" % str(ad["id"]), {})
			var nc := _make_cohort(ad, str(b), 0.0)
			if not src.is_empty():
				for k in ["att", "anger", "fav", "eps"]:
					nc[k] = (src[k] as Dictionary).duplicate()
				nc["mood"] = src["mood"]
				nc["al0"] = src["al0"]
				var bc := _block_cfg(str(b))
				var sh: Array = bc["shift"]
				var xs: Array = (src["x"] as Array).duplicate()
				for i in range(3):
					xs[i] = float(xs[i]) + float(sh[i])
				nc["x"] = xs
				nc["x0"] = [float((src["x0"] as Array)[0]) + float(sh[0]), float((src["x0"] as Array)[1]) + float(sh[1]), float((src["x0"] as Array)[2]) + float(sh[2])]
			cohs["%s|%s" % [str(ad["id"]), str(b)]] = nc
	s["blocks"] = blocks
	_reweight()
	recompute(true)

# ---------------------------------------------------------------- tendencias globales
func trend_levels() -> Dictionary:
	return st().get("trend", {})

func _trend_fx() -> Dictionary:
	var out := {"x": [0.0, 0.0, 0.0], "sal": {}, "anti": 0.0, "turn": 0.0, "spread": 0.0}
	var tr := trend_levels()
	var defs: Dictionary = cfg().get("trends", {})
	for k in tr.keys():
		var lv := float(tr[k])
		var d: Dictionary = defs.get(str(k), {})
		var xs: Array = d.get("x", [0, 0, 0])
		for i in range(3):
			(out["x"] as Array)[i] = float((out["x"] as Array)[i]) + lv * float(xs[i])
		for iss in (d.get("salience", {}) as Dictionary).keys():
			(out["sal"] as Dictionary)[iss] = float((out["sal"] as Dictionary).get(iss, 0.0)) + lv * float(d["salience"][iss])
		out["anti"] = float(out["anti"]) + lv * float(d.get("anti", 0.0))
		out["turn"] = float(out["turn"]) + lv * float(d.get("turnout", 0.0))
		out["spread"] = float(out["spread"]) + maxf(0.0, lv) * float(d.get("spread", 0.0))
	return out

func trend_summary() -> Array:
	var out: Array = []
	var defs: Dictionary = cfg().get("trends", {})
	for k in trend_levels().keys():
		out.append({"id": str(k), "name": str((defs.get(str(k), {}) as Dictionary).get("name", k)), "level": float(trend_levels()[k])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["level"])) > absf(float(b["level"])))
	return out

func _evolve_trends(dt: float) -> void:
	var tr := trend_levels()
	var defs: Dictionary = cfg().get("trends", {})
	for k in tr.keys():
		var old := float(tr[k])
		var lv := old + (-0.05 * old) * dt / 30.0 + m.rng.randfn(0.0, 0.07) * sqrt(dt / 30.0)
		# Giros de opinión ocasionales (cada pocos meses alguna tendencia se dispara).
		if m.rng.randf() < 0.045 * dt / 30.0:
			lv += (0.4 if m.rng.randf() < 0.5 else -0.4) * (0.7 + m.rng.randf() * 0.6)
		lv = clampf(lv, -1.0, 1.0)
		tr[k] = lv
		var d: Dictionary = defs.get(str(k), {})
		if absf(lv - old) > 0.3 and absf(lv) > 0.3 and m.phase in ["legislature", "campaign"]:
			var up := lv > old
			m.publish(str(d.get("up", "")) if up else str(d.get("down", "")),
				"Los estudios de opinión detectan un cambio de clima: «%s» %s. Afectará a la intención de voto de forma desigual según el tipo de elector." % [str(d.get("name", k)).to_lower(), "gana peso" if up else "pierde peso"],
				"ELECTORADO", "neutral")
			_log("Tendencia: %s %s" % [str(d.get("name", k)), "al alza" if up else "a la baja"])
	# La tendencia que dura se cuela poco a poco en las ideas de base.
	var fx := _trend_fx()
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var arch := archetype(str(c["a"]))
		var sus := float(arch.get("sus", 0.6))
		var xb: Array = c["x"]
		var x0: Array = c["x0"]
		for i in range(3):
			xb[i] = clampf(float(xb[i]) + float((fx["x"] as Array)[i]) * sus * 0.03 * dt / 30.0 + (float(x0[i]) - float(xb[i])) * 0.004 * dt / 30.0, -1.1, 1.1)

# ---------------------------------------------------------------- cálculo del voto
func incumbents() -> Array:
	if m.phase in ["legislature", "cabinet_design", "cabinet_negotiation"] and m.s.has("government_party_id"):
		return m.gov.government_parties()
	return st().get("incumbent", [])

func _own_of(id: String) -> Dictionary:
	var sm: Dictionary = m.brain.salience_map(id)
	var extra: Dictionary = (st().get("own", {}) as Dictionary).get(id, {})
	var out: Dictionary = {}
	for iss in sm.keys():
		out[iss] = float(sm[iss]) + float(extra.get(iss, 0.0))
	return out

func _pos(id: String) -> Array:
	var ax: Dictionary = m.party_by_id(id).get("ideology", {})
	var dr: Array = (st().get("ppos", {}) as Dictionary).get(id, [0.0, 0.0, 0.0])
	return [clampf(float(ax.get("economic", 0.0)) + float(dr[0]), -1.2, 1.2), clampf(float(ax.get("social", 0.0)) + float(dr[1]), -1.2, 1.2),
		clampf(float(ax.get("territorial", 0.0)) + float(dr[2]), -1.2, 1.2)]

func _vol(id: String, share: float) -> float:
	return 1.0 + 1.8 * exp(-share / 5.0)

## Un cálculo completo del voto. `fresh` ignora la caché de partidos (para calibrar).
func _compute(_fresh: bool = false) -> Dictionary:
	var s := st()
	var ids := parties()
	var val: Dictionary = s["val"]
	var bias: Dictionary = s["bias"]
	var inc: Array = incumbents()
	var fx := _trend_fx()
	var gsal: Dictionary = m.campaign.salience()
	var gmean := 0.0
	for k in gsal.keys():
		gmean += float(gsal[k])
	gmean = gmean / maxf(1.0, float(gsal.size()))
	var poss: Dictionary = {}
	var owns: Dictionary = {}
	var own_mean: Dictionary = {}
	for id in ids:
		poss[id] = _pos(id)
		owns[id] = _own_of(id)
		for iss in (owns[id] as Dictionary).keys():
			own_mean[iss] = float(own_mean.get(iss, 0.0)) + float((owns[id] as Dictionary)[iss]) / float(maxi(1, ids.size()))
	var out_p: Dictionary = {}
	var out_t: Dictionary = {}
	var out_al: Dictionary = {}
	var share_acc: Dictionary = {}
	for id in ids:
		share_acc[id] = 0.0
	share_acc[Rules.OTHERS_ID] = 0.0
	var vw := 0.0
	var tw := 0.0
	var wsum := 0.0
	var spread := float(fx["spread"])
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var arch := archetype(str(c["a"]))
		var block := str(c["b"])
		var sus := float(arch.get("sus", 0.6))
		var xb: Array = c["x"]
		var xe: Array = []
		for i in range(3):
			var xv := float(xb[i]) + float((fx["x"] as Array)[i]) * sus
			if spread > 0.0:
				xv += signf(xv) * spread * sus
			xe.append(clampf(xv, -1.3, 1.3))
		var terr_mult := (2.2 if block != "rest" else 1.0) * (0.8 + 3.0 * float(gsal.get("territory", 0.1)) + float((fx["sal"] as Dictionary).get("territory", 0.0)))
		var issues: Dictionary = arch["issues"]
		var sal: Dictionary = {}
		for iss in issues.keys():
			var g := float(gsal.get(iss, gmean)) / maxf(gmean, 0.01)
			sal[iss] = maxf(0.0, float(issues[iss]) * (0.65 + 0.35 * g) + float((fx["sal"] as Dictionary).get(iss, 0.0)) * 0.5)
		var u: Dictionary = {}
		var dists: Dictionary = {}
		var dmin := 9.0
		var mood := float(c["mood"])
		var att: Dictionary = c["att"]
		var anger: Dictionary = c["anger"]
		var fav: Dictionary = c["fav"]
		var eps: Dictionary = c["eps"]
		var maxu := -1e9
		for id in ids:
			if not competes(id, block):
				continue
			var pp: Array = poss[id]
			var d2 := 0.0
			for a in range(3):
				var dd := float(xe[a]) - float(pp[a])
				d2 += float(AX_W[a]) * (terr_mult if a == 2 else 1.0) * dd * dd
			dists[id] = sqrt(d2)
			dmin = minf(dmin, sqrt(d2))
			var ow: Dictionary = owns[id]
			var iss_term := 0.0
			for iss in sal.keys():
				iss_term += float(sal[iss]) * (float(ow.get(iss, 0.0)) - float(own_mean.get(iss, 0.0)))
			var uu := -K_DIST * d2 + float(bias.get(id, 0.0)) + float(val.get(id, 0.0)) + K_ISSUE * iss_term
			uu += float(att.get(id, 0.0)) - float(anger.get(id, 0.0)) + float(fav.get(id, 0.0)) + float(eps.get(id, 0.0))
			if not inc.is_empty():
				if inc.has(id):
					uu += K_GOV * mood * (1.0 if id == str(inc[0]) else 0.5)
				else:
					uu -= 0.35 * K_GOV * mood
			u[id] = uu
			maxu = maxf(maxu, uu)
		var anti := float(arch.get("anti", 0.3)) + float(fx["anti"]) * sus
		var uo := float(bias.get(Rules.OTHERS_ID, 0.0)) + float(val.get(Rules.OTHERS_ID, 0.0)) + K_ANTI * (anti - 0.35) + 0.7 * maxf(0.0, dmin - 0.8) - 0.2 * K_GOV * mood * (1.0 if not inc.is_empty() else 0.0)
		u[Rules.OTHERS_ID] = uo
		maxu = maxf(maxu, uo)
		var z := 0.0
		for id in u.keys():
			u[id] = exp(float(u[id]) - maxu)
			z += float(u[id])
		var pr: Dictionary = {}
		var alien := 0.0
		var ang := 0.0
		for id in u.keys():
			var pv := float(u[id]) / z
			pr[id] = pv
			if str(id) != Rules.OTHERS_ID:
				alien += pv * float(dists.get(id, 0.0))
				ang += pv * (float(anger.get(id, 0.0)) - 0.5 * float(fav.get(id, 0.0)))
		var lt := float(c["t0"]) - 1.4 * (alien - float(c["al0"])) - 1.1 * maxf(ang, -0.4) + float(fx["turn"]) + float(s.get("fatigue", 0.0)) + float(s.get("mobil", 0.0))
		var t := clampf(_sigm(lt), 0.18, 0.97)
		out_p[ck] = pr
		out_t[ck] = t
		out_al[ck] = alien
		var wgt := float(c["w"])
		wsum += wgt
		tw += wgt * t
		for id in pr.keys():
			share_acc[id] = float(share_acc.get(id, 0.0)) + wgt * t * float(pr[id])
		vw += wgt * t
	var share: Dictionary = {}
	for id in share_acc.keys():
		share[id] = float(share_acc[id]) / maxf(vw, 0.0001) * 100.0
	return {"p": out_p, "t": out_t, "al": out_al, "share": share, "turnout": tw / maxf(wsum, 0.0001)}

func _calibrate(target: Dictionary, iters: int = 40) -> void:
	var s := st()
	var bias: Dictionary = s["bias"]
	var tsum := 0.0
	for k in target.keys():
		tsum += float(target[k])
	for k in target.keys():
		if not bias.has(str(k)):
			bias[str(k)] = 0.0
	for _i in range(iters):
		var res := _compute(true)
		var sh: Dictionary = res["share"]
		var worst := 0.0
		for k in target.keys():
			var tgt := maxf(float(target[k]) / maxf(tsum, 0.0001) * 100.0, 0.001)
			var mdl := maxf(float(sh.get(str(k), 0.001)), 0.001)
			var dlt := log(tgt / mdl)
			bias[str(k)] = float(bias[str(k)]) + 0.85 * dlt
			worst = maxf(worst, absf(dlt))
		if worst < 0.003:
			break

## Recalcula la opinión y publica la intención de voto (con error de muestreo si `noise`).
func recompute(noise: bool = true) -> void:
	if not ready_state():
		return
	var res := _compute()
	_cache = res
	var s := st()
	var truth: Dictionary = {}
	for k in (res["share"] as Dictionary).keys():
		truth[str(k)] = float((res["share"] as Dictionary)[k])
	s["true"] = truth
	s["turnout"] = float(res["turnout"])
	var pn: Dictionary = s["pnoise"]
	var polls := m.polls()
	var tot := 0.0
	var newp: Dictionary = {}
	for k in truth.keys():
		var tv := float(truth[k])
		var nv := 0.0
		if noise:
			nv = float(pn.get(str(k), 0.0))
		newp[str(k)] = maxf(0.05, tv + nv)
		tot += float(newp[str(k)])
	for k in newp.keys():
		polls[str(k)] = float(newp[str(k)]) / tot * 100.0
	# Partidos que ya no figuran en las encuestas se conservan.

func _roll_pollster_noise() -> void:
	var s := st()
	var pn: Dictionary = s["pnoise"]
	var truth: Dictionary = s.get("true", {})
	for k in truth.keys():
		var share := float(truth[k])
		var sd := 0.09 * sqrt(maxf(share, 0.3))
		pn[str(k)] = float(pn.get(str(k), 0.0)) * 0.55 + m.rng.randfn(0.0, sd)

func true_share(id: String) -> float:
	return float(st().get("true", {}).get(id, m.poll_of(id)))

func turnout() -> float:
	return float(st().get("turnout", 0.7))

func cache() -> Dictionary:
	if _cache.is_empty() and ready_state():
		_cache = _compute()
	return _cache

# ---------------------------------------------------------------- impulsos desde el resto del juego
func _slope(id: String) -> float:
	var res := cache()
	if res.is_empty():
		return 0.2
	var num := 0.0
	var den := 0.0
	var cohs := coh()
	for ck in (res["p"] as Dictionary).keys():
		var pr: Dictionary = res["p"][ck]
		if not pr.has(id):
			continue
		var w := float((cohs[ck] as Dictionary)["w"]) * float((res["t"] as Dictionary)[ck])
		num += w * float(pr[id]) * (1.0 - float(pr[id]))
		den += w
	return maxf(num / maxf(den, 0.0001), 0.004)

## Sube o baja `delta` puntos de intención de voto a un partido (el resto cede o recupera proporcionalmente).
func nudge(id: String, delta_pts: float) -> void:
	if not ready_state() or is_zero_approx(delta_pts):
		return
	var s := st()
	var val: Dictionary = s["val"]
	if not (s["bias"] as Dictionary).has(id):
		return
	var sh := float((s.get("true", {}) as Dictionary).get(id, 1.0))
	var slope := _slope(id)
	var dv := clampf((delta_pts / 100.0) / slope, -0.7, 0.7)
	val[id] = clampf(float(val.get(id, 0.0)) + dv, -2.5, 2.5)
	recompute(true)

## Varios impulsos a la vez (sólo se recalcula una vez).
func nudge_many(deltas: Dictionary) -> void:
	if not ready_state():
		return
	var s := st()
	var val: Dictionary = s["val"]
	for id in deltas.keys():
		if not (s["bias"] as Dictionary).has(str(id)):
			continue
		var slope := _slope(str(id))
		var dv := clampf((float(deltas[id]) / 100.0) / slope, -0.7, 0.7)
		val[str(id)] = clampf(float(val.get(str(id), 0.0)) + dv, -2.5, 2.5)
	recompute(true)

func _log(text: String) -> void:
	var lg: Array = st().get("log", [])
	lg.push_front({"t": m.clock_unix(), "text": text})
	while lg.size() > 40:
		lg.pop_back()
	st()["log"] = lg

func log_entries() -> Array:
	return st().get("log", [])

## Reacción de los votantes a algo que ha pasado.
## stim = {party, partners:[], dir:[e,s,t], groups:{grupo:puntos}, issue, mag, label}
func react(stim: Dictionary) -> Dictionary:
	if not ready_state():
		return {}
	var party_id := str(stim.get("party", ""))
	var partners: Array = stim.get("partners", [])
	var mag := float(stim.get("mag", 1.0))
	var groups: Dictionary = stim.get("groups", {})
	var dir: Array = stim.get("dir", [0.0, 0.0, 0.0])
	var issue := str(stim.get("issue", ""))
	var cohs := coh()
	var best_key := ""
	var best_val := 0.0
	var tot_pos := 0.0
	var tot_neg := 0.0
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var arch := archetype(str(c["a"]))
		var benefit := 0.0
		for g in (arch["groups"] as Dictionary).keys():
			benefit += float(arch["groups"][g]) * float(groups.get(str(g), 0.0)) / 10.0
		var x: Array = c["x"]
		var align := float(dir[0]) * float(x[0]) + float(dir[1]) * float(x[1]) + float(dir[2]) * float(x[2])
		var sal := 0.6 + 3.0 * float((arch["issues"] as Dictionary).get(issue, 0.1))
		var r := clampf((benefit + 1.4 * align) * sal * mag, -1.6, 1.6)
		var w := float(c["w"])
		if r > 0.0:
			tot_pos += w * r
		else:
			tot_neg -= w * r
		if absf(r) * w > best_val:
			best_val = absf(r) * w
			best_key = ck
		_apply_reaction(c, party_id, r, 1.0)
		for pa in partners:
			_apply_reaction(c, str(pa), r, 0.4)
	recompute(true)
	var res := {"pos": tot_pos, "neg": tot_neg, "top": best_key}
	if best_key != "" and (tot_neg > 0.12 or tot_pos > 0.12) and stim.has("label"):
		var arch2 := archetype(str((cohs[best_key] as Dictionary)["a"]))
		var angry := float((cohs[best_key] as Dictionary).get("last_r", 0.0))
		_log("%s: reacciones encontradas según el tipo de elector (el que más se mueve: %s)." % [str(stim["label"]), str(arch2.get("name", ""))])
	return res

func _apply_reaction(c: Dictionary, party_id: String, r: float, weight: float) -> void:
	if party_id == "" or party_id == Rules.OTHERS_ID:
		return
	var anger: Dictionary = c["anger"]
	var fav: Dictionary = c["fav"]
	var att: Dictionary = c["att"]
	var arch := archetype(str(c["a"]))
	var rr := r * weight
	c["last_r"] = r
	if rr > 0.0:
		fav[party_id] = minf(float(fav.get(party_id, 0.0)) + rr * 0.8, 1.6)
		anger[party_id] = maxf(0.0, float(anger.get(party_id, 0.0)) - rr * 0.4)
	else:
		var pain := -rr
		# Los votantes muy fieles tardan más en enfadarse, pero cuando lo hacen duele más recuperarlos.
		anger[party_id] = minf(float(anger.get(party_id, 0.0)) + pain * (1.0 - 0.25 * minf(float(arch.get("loyalty", 0.8)), 1.4)), 2.0)
		fav[party_id] = maxf(0.0, float(fav.get(party_id, 0.0)) - pain * 0.5)
		att[party_id] = maxf(0.0, float(att.get(party_id, 0.0)) * (1.0 - 0.18 * minf(pain, 1.0)))

## Una ley aprobada: castigo o premio por cohortes según a quién beneficia, quién la presenta y quién la apoya.
func on_law(law: Dictionary, res: Dictionary) -> void:
	if not ready_state() or not bool(res.get("passed", false)):
		return
	var prev: Dictionary = res.get("preview", {})
	var groups: Dictionary = prev.get("groups", {})
	var proposer := str(law.get("proposer", ""))
	var partners: Array = []
	var by_party: Dictionary = res.get("by_party", {})
	for pid in by_party.keys():
		if str(by_party[pid]) == "yes" and str(pid) != proposer:
			partners.append(str(pid))
	var dir: Array = [0.0, 0.0, 0.0]
	var changes: Dictionary = law.get("changes", {})
	for mid in changes.keys():
		var meas := Policies.measure(str(mid))
		if meas.is_empty():
			continue
		var lean: Dictionary = meas.get("lean", {})
		var stp := (float(changes[mid]) - m.eco.value(str(mid))) / maxf(float(meas.get("step", 1.0)), 0.0001)
		if is_zero_approx(stp):
			stp = 0.0
		var sgn := signf(float(changes[mid]) - float(meas.get("base", 0.0)))
		dir[0] = float(dir[0]) + float(lean.get("economic", 0.0)) * sgn * 0.03
		dir[1] = float(dir[1]) + float(lean.get("social", 0.0)) * sgn * 0.03
		dir[2] = float(dir[2]) + float(lean.get("territorial", 0.0)) * sgn * 0.03
	for i in range(3):
		dir[i] = clampf(float(dir[i]), -0.12, 0.12)
	var issue := str(Policies.area(str(law.get("area", ""))).get("issue", ""))
	var mag := 1.0
	var lbl := "La ley «%s»" % str(law.get("title", ""))
	react({"party": proposer, "partners": partners, "dir": dir, "groups": groups, "issue": issue, "mag": mag, "label": lbl})
	# El que presenta una ley que toca un tema gana credibilidad en él.
	if issue != "" and proposer != "":
		var own: Dictionary = st()["own"]
		var o: Dictionary = own.get(proposer, {})
		o[issue] = minf(float(o.get(issue, 0.0)) + 0.06, 0.3)
		own[proposer] = o
	# El electorado reacciona en sentido contrario al giro de la política (efecto termostato).
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var sus := float(archetype(str(c["a"])).get("sus", 0.6))
		var xb: Array = c["x"]
		for i in range(3):
			xb[i] = clampf(float(xb[i]) - float(dir[i]) * 0.1 * sus, -1.1, 1.1)
	# El partido se percibe un poco más cerca de lo que legisla.
	var pp: Dictionary = st()["ppos"]
	var cur: Array = pp.get(proposer, [0.0, 0.0, 0.0])
	for i in range(3):
		cur[i] = clampf(float(cur[i]) + float(dir[i]) * 0.5, -0.35, 0.35)
	pp[proposer] = cur

## Pactar con alguien que parte de tus votantes rechaza cuesta apoyo en esa parte del electorado.
func on_pact(a: String, b: String) -> void:
	if not ready_state() or a == "" or b == "":
		return
	var pa: Array = _pos(a)
	var pb: Array = _pos(b)
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var x: Array = c["x"]
		var da := _dist3(x, pa)
		var db := _dist3(x, pb)
		# El cohorte cercano a A y lejano de B se enfada con A por pactar con B.
		if da < 0.9 and db > 1.0:
			_apply_reaction(c, a, -0.35 * (db - 0.9), 1.0)
		if db < 0.9 and da > 1.0:
			_apply_reaction(c, b, -0.35 * (da - 0.9), 1.0)
	recompute(true)

func _dist3(x: Array, p: Array) -> float:
	var d2 := 0.0
	for i in range(3):
		var dd := float(x[i]) - float(p[i])
		d2 += float(AX_W[i]) * dd * dd
	return sqrt(d2)

## Un acto o una visita en una comunidad mueve más a los votantes de ese territorio.
func on_event_region(community: String, mag: float) -> void:
	if not ready_state() or community == "":
		return
	var cohs := coh()
	var pid := m.pid()
	var hit := false
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		if str(c["b"]) == community or (str(c["b"]) == "rest" and not (st()["blocks"] as Array).has(community)):
			var fav: Dictionary = c["fav"]
			fav[pid] = clampf(float(fav.get(pid, 0.0)) + mag * 0.08, 0.0, 1.6)
			hit = true
	if hit:
		recompute(true)

## Cambio en el apoyo al Gobierno: el humor de las cohortes se mueve en el mismo sentido.
func on_approval(delta: float) -> void:
	if not ready_state() or is_zero_approx(delta):
		return
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		c["mood"] = clampf(float(c["mood"]) + delta / 50.0 * 0.5, -1.0, 1.0)
	recompute(true)

## Las promesas incumplidas dejan enfado entre quienes más contaban con ellas.
func on_broken_promises(party_id: String, severity: float) -> void:
	if not ready_state() or severity <= 0.0:
		return
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var anger: Dictionary = c["anger"]
		var arch := archetype(str(c["a"]))
		var att: Dictionary = c["att"]
		var expect := 0.5 + float(att.get(party_id, 0.0)) * 0.4
		anger[party_id] = minf(float(anger.get(party_id, 0.0)) + severity * expect * 0.6, 2.0)
	recompute(true)

# ---------------------------------------------------------------- paso del tiempo
## Deriva rápida de la valencia (imagen y noticias de cada partido) durante `days` días. Los pequeños fluctúan más.
func drift(days: float) -> void:
	if not ready_state():
		return
	var s := st()
	var val: Dictionary = s["val"]
	var tr := _trend_fx()
	var damp := pow(RHO_DAY, days)
	var var_f := sqrt((1.0 - pow(RHO_DAY, 2.0 * days)) / (1.0 - RHO_DAY * RHO_DAY))
	var truth: Dictionary = s.get("true", {})
	var polar := 1.0 + float(tr["spread"]) * 0.8
	for id in parties() + [Rules.OTHERS_ID]:
		var vol := _vol(id, float(truth.get(id, 3.0)))
		val[id] = clampf(float(val.get(id, 0.0)) * damp + m.rng.randfn(0.0, SIG_DAY * vol * var_f * polar), -2.5, 2.5)
	_shocks(days)
	recompute(true)

## Sucesos que disparan o hunden a un partido (momentos virales, escándalos…).
func _shocks(days: float) -> void:
	if m.rng.randf() >= 0.02 * days:
		return
	var ids := parties()
	if ids.is_empty():
		return
	var id := str(ids[m.rng.randi_range(0, ids.size() - 1)])
	var share := float((st().get("true", {}) as Dictionary).get(id, 3.0))
	var up := m.rng.randf() < (0.62 if share < 6.0 else 0.4)
	var mag := (0.18 + m.rng.randf() * 0.3) * (1.4 if share < 6.0 else 1.0)
	var val: Dictionary = st()["val"]
	val[id] = clampf(float(val.get(id, 0.0)) + (mag if up else -mag), -2.5, 2.5)
	var nm := m.party_short(id)
	var up_txt := ["%s se dispara en las redes y en los sondeos", "Un acto de %s se vuelve viral", "%s gana tracción entre los indecisos"]
	var dn_txt := ["%s atraviesa una polémica que le cuesta apoyos", "Una filtración deja a %s en una situación incómoda", "%s pierde pie en los sondeos tras una semana torcida"]
	var title := str((up_txt if up else dn_txt)[m.rng.randi_range(0, 2)]) % nm
	if m.phase in ["legislature", "campaign"]:
		m.publish(title, "Los analistas atribuyen el movimiento a la conversación pública de los últimos días. Es un movimiento de opinión, no un cambio de fondo: puede revertirse.", "SONDEOS", "positive" if (up and m.is_player(id)) else ("warning" if (not up and m.is_player(id)) else "neutral"))

## Evolución lenta: tendencias, ideas, hábitos, enfado, humor con el Gobierno y posiciones de los partidos.
func slow_update(dt_days: float) -> void:
	if not ready_state():
		return
	var s := st()
	var dt := dt_days / 30.0
	_evolve_trends(dt_days)
	var res := cache()
	var cohs := coh()
	var fx := _trend_fx()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var arch := archetype(str(c["a"]))
		var pr: Dictionary = (res.get("p", {}) as Dictionary).get(ck, {})
		var att: Dictionary = c["att"]
		var anger: Dictionary = c["anger"]
		var fav: Dictionary = c["fav"]
		var loy := float(arch.get("loyalty", 0.8))
		for id in att.keys():
			var tgt := loy * float(pr.get(id, 0.0)) * 1.2
			att[id] = float(att[id]) + (tgt - float(att[id])) * 0.06 * dt
		for id in pr.keys():
			if str(id) != Rules.OTHERS_ID and not att.has(id):
				att[id] = 0.0
		for id in anger.keys():
			anger[id] = float(anger[id]) * pow(0.88, dt)
		for id in fav.keys():
			fav[id] = float(fav[id]) * pow(0.85, dt)
		# Humor con el Gobierno según la satisfacción de los grupos de los que depende el cohorte.
		if not incumbents().is_empty():
			var tgt_m := 0.0
			for g in (arch["groups"] as Dictionary).keys():
				tgt_m += float(arch["groups"][g]) * (m.eco.satisfaction(str(g)) - 50.0) / 50.0
			tgt_m = tgt_m * 0.8 + (m.gov.approval() - 50.0) / 50.0 * 0.6
			c["mood"] = clampf(float(c["mood"]) + (clampf(tgt_m, -1.0, 1.0) - float(c["mood"])) * minf(0.4 * dt, 1.0), -1.0, 1.0)
		else:
			c["mood"] = float(c["mood"]) * pow(0.9, dt)
		# Las ideas siguen un poco al partido al que se vota (efecto «señal»).
		var best := ""
		var bp := 0.0
		for id in pr.keys():
			if str(id) != Rules.OTHERS_ID and float(pr[id]) > bp:
				bp = float(pr[id])
				best = str(id)
		if best != "":
			var pos := _pos(best)
			var xb: Array = c["x"]
			for i in range(3):
				xb[i] = float(xb[i]) + (float(pos[i]) - float(xb[i])) * 0.01 * dt * bp * float(arch.get("loyalty", 0.8))
	# Ideas de los partidos de la IA: se acercan a donde están sus votantes; la gestión de lo público fija credibilidad.
	var pp: Dictionary = s["ppos"]
	var truth: Dictionary = s.get("true", {})
	for id in parties():
		var cur: Array = pp.get(id, [0.0, 0.0, 0.0])
		if m.is_player(id):
			for i in range(3):
				cur[i] = float(cur[i]) * pow(0.97, dt)
		else:
			var tgt: Array = [0.0, 0.0, 0.0]
			var wt := 0.0
			for ck in cohs.keys():
				var pv := float(((res.get("p", {}) as Dictionary).get(ck, {}) as Dictionary).get(id, 0.0)) * float((cohs[ck] as Dictionary)["w"])
				var xb2: Array = (cohs[ck] as Dictionary)["x"]
				for i in range(3):
					tgt[i] = float(tgt[i]) + pv * float(xb2[i])
				wt += pv
			if wt > 0.0:
				var base: Array = _base_axes(id)
				var rig := clampf(m.brain.trait_of(id, "rigidity", 0.5), 0.1, 0.95)
				for i in range(3):
					var want := float(tgt[i]) / wt - float(base[i])
					cur[i] = clampf(float(cur[i]) + (want - float(cur[i])) * 0.01 * (1.0 - rig) * dt, -0.18, 0.18)
		pp[id] = cur
	var own: Dictionary = s["own"]
	for id in own.keys():
		var o: Dictionary = own[id]
		for iss in o.keys():
			o[iss] = float(o[iss]) * pow(0.97, dt)
	s["fatigue"] = float(s.get("fatigue", 0.0)) * pow(0.9, dt)
	s["mobil"] = float(s.get("mobil", 0.0)) * pow(0.8, dt)
	_roll_pollster_noise()

func _base_axes(id: String) -> Array:
	var ax: Dictionary = m.party_by_id(id).get("ideology", {})
	return [float(ax.get("economic", 0.0)), float(ax.get("social", 0.0)), float(ax.get("territorial", 0.0))]

## Un día de campaña.
func step_day() -> void:
	if not ready_state():
		return
	slow_update(1.0)
	drift(1.0)

## Un turno de legislatura (un trimestre): la opinión se actualiza de golpe y se toman cuatro encuestas repartidas en el trimestre.
func monthly() -> void:
	if not ready_state():
		return
	var span := float(Rules.TURN_MONTHS)
	slow_update(30.0 * span)
	_flow_news()
	var now := m.clock_unix()
	for w in range(4):
		drift(7.5 * span)
		_roll_pollster_noise()
		recompute(true)
		m.campaign.record_snapshot(("T%d" % m.turn()) if w == 3 else ("T%d · sondeo %d" % [m.turn(), w + 1]), now - (3 - w) * 21 * 86400)

# ---------------------------------------------------------------- ciclos electorales
## Se llama al empezar una nueva campaña, antes de borrar los datos del Gobierno.
func on_new_cycle() -> void:
	if not ready_state():
		return
	var s := st()
	if m.s.has("government_party_id") and m.phase == "legislature":
		s["incumbent"] = m.gov.government_parties().duplicate()
	var res := cache()
	# Las encuestas de la nueva campaña mezclan el último resultado con la opinión que quedaba.
	var target: Dictionary = {}
	var vt := m.d("election_vote_totals")
	var tot := 0.0
	for v in vt.values():
		tot += float(v)
	for id in (s["true"] as Dictionary).keys():
		var cur := float((s["true"] as Dictionary)[id])
		var result := float(vt.get(str(id), 0)) / tot * 100.0 if tot > 0.0 else cur
		target[str(id)] = 0.5 * result + 0.5 * cur
	# Humor: el mandato deja una huella en el humor y en el hartazgo.
	var val: Dictionary = s["val"]
	for id in val.keys():
		val[id] = 0.0
	_calibrate(target, 60)
	s["fatigue"] = -0.12
	recompute(false)
	var res2 := _compute(true)
	var cohs := coh()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		c["al0"] = float((res2["al"] as Dictionary).get(ck, 0.0))
		c["mood"] = float(c["mood"]) * 0.6
	_snapshot_ref(res2)
	recompute(false)

func _snapshot_ref(res: Dictionary) -> void:
	var ref: Dictionary = {}
	for ck in (res["p"] as Dictionary).keys():
		var t := float((res["t"] as Dictionary)[ck])
		var one: Dictionary = {ABST: snappedf(1.0 - t, 0.0001)}
		for id in (res["p"][ck] as Dictionary).keys():
			one[str(id)] = snappedf(t * float(res["p"][ck][id]), 0.0001)
		ref[ck] = one
	st()["ref"] = ref

## Cálculo del día de las elecciones: último vuelco, error de las encuestas y golpe de participación.
## Devuelve {shares, turnout} sin tocar la opinión (la opinión sólo cambia con el resultado real).
func election_day() -> Dictionary:
	ensure()
	var s := st()
	var val: Dictionary = s["val"]
	var saved: Dictionary = val.duplicate()
	var saved_mobil := float(s.get("mobil", 0.0))
	var truth: Dictionary = s.get("true", {})
	# Los indecisos deciden en las últimas horas: más ruido cuanto más pequeño es el partido.
	for id in parties() + [Rules.OTHERS_ID]:
		var vol := _vol(id, float(truth.get(id, 3.0)))
		val[id] = float(val.get(id, 0.0)) + m.rng.randfn(0.0, 0.07 * vol)
	# Error sistemático de los sondeos: favorece a un bloque y perjudica al otro.
	var bloc_err := m.rng.randfn(0.0, 0.07)
	for id in parties():
		var ec := float(m.party_by_id(id).get("ideology", {}).get("economic", 0.0))
		val[id] = float(val.get(id, 0.0)) + bloc_err * signf(ec) * minf(absf(ec) + 0.3, 1.0)
	s["mobil"] = saved_mobil + m.rng.randfn(0.0, 0.14)
	var res := _compute(true)
	var shares: Dictionary = {}
	for k in (res["share"] as Dictionary).keys():
		shares[str(k)] = float((res["share"] as Dictionary)[k])
	var out := {"shares": shares, "turnout": float(res["turnout"]), "bloc_error": bloc_err}
	# Se restituye la opinión previa: el resultado real se aplica en finish_election.
	for k in val.keys():
		val[k] = saved.get(k, 0.0)
	s["mobil"] = saved_mobil
	_cache = {}
	recompute(false)
	return out

## Tras el escrutinio: las cohortes recuerdan a quién votaron, se refuerza ese hábito y se fija la nueva referencia de flujos.
func finish_election(result_shares: Dictionary, turnout_v: float) -> void:
	if not ready_state():
		return
	var s := st()
	s["last_turnout"] = turnout_v
	var cohs := coh()
	var res := cache()
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var arch := archetype(str(c["a"]))
		var pr: Dictionary = (res.get("p", {}) as Dictionary).get(ck, {})
		var att: Dictionary = c["att"]
		for id in pr.keys():
			if str(id) == Rules.OTHERS_ID:
				continue
			att[id] = float(att.get(id, 0.0)) * 0.7 + float(arch.get("loyalty", 0.8)) * float(pr[id]) * 1.2 * 0.3
	s["fatigue"] = 0.1

# ---------------------------------------------------------------- consultas para la interfaz
func cohort_overview() -> Array:
	var res := cache()
	var rows: Array = []
	if res.is_empty():
		return rows
	var by_arch: Dictionary = {}
	for ck in (res["p"] as Dictionary).keys():
		var c: Dictionary = coh()[ck]
		var aid := str(c["a"])
		var w := float(c["w"])
		var t := float((res["t"] as Dictionary)[ck])
		if not by_arch.has(aid):
			by_arch[aid] = {"w": 0.0, "t": 0.0, "p": {}, "mood": 0.0, "anger": {}, "x": [0.0, 0.0, 0.0]}
		var rec: Dictionary = by_arch[aid]
		rec["w"] = float(rec["w"]) + w
		rec["t"] = float(rec["t"]) + w * t
		rec["mood"] = float(rec["mood"]) + w * float(c["mood"])
		for id in (res["p"][ck] as Dictionary).keys():
			(rec["p"] as Dictionary)[id] = float((rec["p"] as Dictionary).get(id, 0.0)) + w * t * float(res["p"][ck][id])
		for id in (c["anger"] as Dictionary).keys():
			(rec["anger"] as Dictionary)[id] = float((rec["anger"] as Dictionary).get(id, 0.0)) + w * float(c["anger"][id])
		for i in range(3):
			(rec["x"] as Array)[i] = float((rec["x"] as Array)[i]) + w * float((c["x"] as Array)[i])
	for aid in by_arch.keys():
		var rec2: Dictionary = by_arch[aid]
		var w2 := float(rec2["w"])
		var tt := float(rec2["t"]) / maxf(w2, 0.0001)
		var votes: Dictionary = {}
		for id in (rec2["p"] as Dictionary).keys():
			votes[id] = float(rec2["p"][id]) / maxf(float(rec2["t"]), 0.0001) * 100.0
		var ang: Dictionary = {}
		for id in (rec2["anger"] as Dictionary).keys():
			ang[id] = float(rec2["anger"][id]) / maxf(w2, 0.0001)
		var arch := archetype(str(aid))
		rows.append({"id": str(aid), "name": str(arch.get("name", aid)), "desc": str(arch.get("desc", "")), "w": w2 * 100.0, "turnout": tt * 100.0,
			"votes": votes, "mood": float(rec2["mood"]) / maxf(w2, 0.0001), "anger": ang,
			"x": [float((rec2["x"] as Array)[0]) / w2, float((rec2["x"] as Array)[1]) / w2, float((rec2["x"] as Array)[2]) / w2],
			"vol": float(arch.get("vol", 1.0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["w"]) > float(b["w"]))
	return rows

## Trasvase de votos respecto a la última elección: lista [{from, to, pts}] (pts del censo).
func flows(limit: int = 8) -> Array:
	var res := cache()
	var ref: Dictionary = st().get("ref", {})
	if res.is_empty() or ref.is_empty():
		return []
	var acc: Dictionary = {}
	var cohs := coh()
	for ck in (res["p"] as Dictionary).keys():
		if not ref.has(ck):
			continue
		var w := float((cohs[ck] as Dictionary)["w"])
		var t := float((res["t"] as Dictionary)[ck])
		var cur: Dictionary = {ABST: 1.0 - t}
		for id in (res["p"][ck] as Dictionary).keys():
			cur[str(id)] = t * float(res["p"][ck][id])
		var old: Dictionary = ref[ck]
		var gains: Dictionary = {}
		var gsum := 0.0
		for id in cur.keys():
			var g := float(cur[id]) - float(old.get(id, 0.0))
			if g > 0.0:
				gains[id] = g
				gsum += g
		if gsum <= 0.0:
			continue
		for id in old.keys():
			var loss := float(old[id]) - float(cur.get(id, 0.0))
			if loss <= 0.0:
				continue
			for g2 in gains.keys():
				if str(g2) == str(id):
					continue
				var key := "%s>%s" % [str(id), str(g2)]
				acc[key] = float(acc.get(key, 0.0)) + w * loss * float(gains[g2]) / gsum
	var rows: Array = []
	for k in acc.keys():
		var pts := float(acc[k]) * 100.0
		if pts >= 0.03:
			rows.append({"from": str(k).get_slice(">", 0), "to": str(k).get_slice(">", 1), "pts": pts})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["pts"]) > float(b["pts"]))
	return rows.slice(0, limit)

func ref_share(id: String) -> float:
	var ref: Dictionary = st().get("ref", {})
	var cohs := coh()
	var num := 0.0
	var den := 0.0
	for ck in ref.keys():
		if not cohs.has(ck):
			continue
		var w := float((cohs[ck] as Dictionary)["w"])
		var o: Dictionary = ref[ck]
		for k in o.keys():
			if str(k) != ABST:
				den += w * float(o[k])
		num += w * float(o.get(id, 0.0))
	return num / maxf(den, 0.0001) * 100.0

func _flow_news() -> void:
	if m.phase != "legislature":
		return
	var fl := flows(3)
	if fl.is_empty():
		return
	var top: Dictionary = fl[0]
	if float(top["pts"]) < 0.8 or m.rng.randf() > 0.35:
		return
	var nf := "la abstención" if str(top["from"]) == ABST else m.party_short(str(top["from"]))
	var nt := "la abstención" if str(top["to"]) == ABST else m.party_short(str(top["to"]))
	var cause := _flow_cause(str(top["from"]), str(top["to"]))
	m.publish("Trasvase de votos: de %s a %s" % [nf, nt],
		"Los estudios cualitativos detectan un movimiento de %.1f puntos del censo entre ambas opciones%s." % [float(top["pts"]), cause], "ELECTORADO", "neutral")

func _flow_cause(from_id: String, to_id: String) -> String:
	var rows := cohort_overview()
	var best := ""
	var bv := 0.0
	for r in rows:
		var rd: Dictionary = r
		var ref_w := float(rd["w"])
		var v := float((rd["votes"] as Dictionary).get(to_id, 0.0)) * ref_w
		if v > bv:
			bv = v
			best = str(rd["name"])
	return ", sobre todo entre «%s»" % best.to_lower() if best != "" else ""

## Opinión media del electorado sobre un partido (de -1 enfado a +1 simpatía), para la ficha del electorado.
func opinion_of(id: String) -> float:
	var cohs := coh()
	var num := 0.0
	var den := 0.0
	for ck in cohs.keys():
		var c: Dictionary = cohs[ck]
		var w := float(c["w"])
		num += w * (float((c["fav"] as Dictionary).get(id, 0.0)) - float((c["anger"] as Dictionary).get(id, 0.0)))
		den += w
	return clampf(num / maxf(den, 0.0001), -1.0, 1.0)
