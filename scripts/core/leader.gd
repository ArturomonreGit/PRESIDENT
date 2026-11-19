class_name Leader
extends RefCounted
## Personaje que dirige un partido: identidad, aspecto de caricatura, atributos y rasgo vital.
## El jugador crea el suyo; los partidos de la IA reciben líderes ficticios generados de forma determinista.

const STATS := [
	{"id": "carisma", "name": "Carisma", "desc": "Atrae miradas: más visibilidad y tirón en los medios."},
	{"id": "oratoria", "name": "Oratoria", "desc": "Mejora tus respuestas en entrevistas, debates y ruedas de prensa."},
	{"id": "honestidad", "name": "Honestidad", "desc": "Te hace creíble: pesa en la confianza y en cómo te ven los demás partidos."},
	{"id": "experiencia", "name": "Experiencia", "desc": "Conoce el sistema: más ambiente favorable al abrir una reunión."},
	{"id": "mano_izquierda", "name": "Mano izquierda", "desc": "Negocia con tacto: más paciencia de los interlocutores."},
	{"id": "firmeza", "name": "Firmeza", "desc": "Se hace respetar: la presión y las líneas rojas funcionan mejor."},
]
const STAT_BASE := 3
const STAT_MAX := 8
const STAT_POINTS := 12

const BACKGROUNDS := [
	{"id": "abogado", "name": "Abogado", "desc": "Argumenta con soltura y conoce las leyes.", "bias": {"oratoria": 1}},
	{"id": "economista", "name": "Economista", "desc": "Maneja cifras y presupuestos.", "bias": {"honestidad": 0, "experiencia": 1}},
	{"id": "sindicalista", "name": "Sindicalista", "desc": "Curtido en mesas de negociación.", "bias": {"mano_izquierda": 1}},
	{"id": "empresario", "name": "Empresario", "desc": "Viene de crear empleo y asumir riesgos.", "bias": {"firmeza": 1}},
	{"id": "medico", "name": "Médico", "desc": "Cercano y respetado por su profesión.", "bias": {"honestidad": 1}},
	{"id": "profesor", "name": "Profesor", "desc": "Didáctico y paciente.", "bias": {"oratoria": 1}},
	{"id": "periodista", "name": "Periodista", "desc": "Sabe cómo funcionan los medios.", "bias": {"carisma": 1}},
	{"id": "funcionario", "name": "Alto funcionario", "desc": "Conoce la maquinaria del Estado.", "bias": {"experiencia": 1}},
	{"id": "activista", "name": "Activista", "desc": "Viene de la calle y de las causas sociales.", "bias": {"carisma": 1}},
	{"id": "alcalde", "name": "Exalcalde", "desc": "Gestión local y trato directo con el vecino.", "bias": {"mano_izquierda": 1}},
]

const PERKS := [
	{"id": "outsider", "name": "Recién llegado", "desc": "Sin pasado político: las contradicciones de la hemeroteca duelen menos.", "stats": {"honestidad": 1, "experiencia": -1}},
	{"id": "veterano", "name": "Veterano del aparato", "desc": "Mucho recorrido y buenos contactos, poco brillo.", "stats": {"experiencia": 2, "carisma": -1}},
	{"id": "telegenico", "name": "Telegénico", "desc": "La cámara le adora: más visibilidad en cada aparición.", "stats": {"carisma": 2}},
	{"id": "palabra", "name": "Hombre de palabra", "desc": "Cumplir pactos pesa más; romperlos, también.", "stats": {"honestidad": 2}},
	{"id": "negociador", "name": "Negociador nato", "desc": "Se le da bien cerrar acuerdos difíciles.", "stats": {"mano_izquierda": 2}},
	{"id": "polemico", "name": "Polémico", "desc": "Genera titulares, para bien y para mal.", "stats": {"carisma": 1, "firmeza": 1}},
	{"id": "tecnocrata", "name": "Tecnócrata", "desc": "Datos y rigor: sube su crédito en economía.", "stats": {"honestidad": 1, "oratoria": -1, "experiencia": 1}},
	{"id": "calle", "name": "Hombre/mujer de la calle", "desc": "Conecta con la gente corriente.", "stats": {"carisma": 1, "mano_izquierda": 1}},
]

const SKIN := ["#F6D5B8", "#EFC29C", "#E0A97E", "#C98B5E", "#A66A43", "#7A4A2D"]
const HAIR_COLOR := ["#1E1A18", "#4A3224", "#7A5232", "#B98B3F", "#C9C2B8", "#8F2F1F", "#E8E4DC"]
const HAIR_STYLES := ["Calvo", "Corto", "Peinado de lado", "Rizado", "Melena", "Coleta", "Cresta", "Afro", "Moño", "Entradas"]
const EYES := ["Grandes", "Pequeños", "Achinados", "Cansados"]
const BROWS := ["Finas", "Gruesas", "Arqueadas", "Rectas"]
const NOSES := ["Pequeña", "Grande", "Aguileña", "Chata"]
const MOUTHS := ["Sonrisa", "Seria", "Sonrisa torcida", "Sonrisa amplia", "Boca pequeña"]
const FACIAL := ["Ninguno", "Barba", "Perilla", "Bigote", "Barba de tres días"]
const GLASSES := ["Sin gafas", "Gafas redondas", "Gafas cuadradas", "Gafas de pasta"]
const FACE_SHAPES := ["Ovalada", "Cuadrada", "Redonda", "Alargada"]
const FEATURES := ["Ninguna", "Nariz enorme", "Barbilla prominente", "Orejas de soplillo", "Frente enorme", "Cabezón"]
const OUTFITS := ["Traje", "Americana abierta", "Camisa remangada", "Traje con pin"]

const MALE := ["Álvaro", "Ignacio", "Rafael", "Tomás", "Gonzalo", "Joaquín", "Néstor", "Aurelio", "Emilio", "Baltasar", "Ramiro", "Casimiro", "Eugenio", "Leandro", "Hilario", "Anselmo", "Marcelino", "Eladio", "Fulgencio", "Teodoro"]
const FEMALE := ["Elvira", "Remedios", "Matilde", "Rosario", "Amparo", "Consuelo", "Leonor", "Soledad", "Fermina", "Genoveva", "Aurora", "Delfina", "Natividad", "Herminia", "Visitación", "Encarna", "Purificación", "Clotilde", "Adoración", "Macarena"]
const SURNAME := ["Valderrama", "Quintanilla", "Escobedo", "Maldonado", "Ibarrola", "Cárdenas", "Montalbán", "Sotomayor", "Arrieta", "Villarroel", "Echevarría", "Carrasco", "Berrocal", "Lazcano", "Peñalver", "Altamira", "Bermejo", "Cordero", "Zubiaurre", "Olmedo", "Salcedo", "Garcés", "Mondéjar", "Ruanova", "Tejedor", "Calderón", "Lorente", "Fontanals", "Nieto", "Briones"]
const CAT_M := ["Oriol", "Ramon", "Pere", "Quim", "Albert", "Genís", "Bernat", "Cebrià"]
const CAT_F := ["Montserrat", "Núria", "Roser", "Laia", "Mercè", "Carme", "Anaïs", "Griselda"]
const CAT_S := ["Vilaseca", "Puigdomènech", "Soler", "Ferrer", "Camprubí", "Sala", "Castellví", "Roca"]
const EUS_M := ["Iñaki", "Xabier", "Unai", "Mikel", "Aitor", "Koldo", "Gorka", "Jon"]
const EUS_F := ["Amaia", "Nerea", "Itziar", "Maite", "Garazi", "Leire", "Idoia", "Arantza"]
const EUS_S := ["Etxeberria", "Goikoetxea", "Olazábal", "Arrizabalaga", "Zugasti", "Mendiola", "Larrañaga", "Urkijo"]
const GAL_M := ["Xoán", "Breixo", "Anxo", "Manoel", "Brais", "Suso", "Fiz", "Roi"]
const GAL_F := ["Uxía", "Noa", "Carme", "Brais", "Anxela", "Maruxa", "Rosalía", "Iria"]
const GAL_S := ["Rodríguez Tato", "Vilanova", "Barreiro", "Outeiro", "Pazos", "Loureiro", "Seoane", "Carballo"]

static func stat_ids() -> Array:
	var out: Array = []
	for s in STATS:
		out.append(str((s as Dictionary)["id"]))
	return out

static func perk_by_id(id: String) -> Dictionary:
	for p in PERKS:
		if str((p as Dictionary)["id"]) == id:
			return p
	return {}

static func background_by_id(id: String) -> Dictionary:
	for b in BACKGROUNDS:
		if str((b as Dictionary)["id"]) == id:
			return b
	return {}

## Atributo efectivo (base asignada + sesgo del oficio + rasgo vital), limitado a 1..10.
static func stat(ch: Dictionary, key: String) -> int:
	var v := int((ch.get("stats", {}) as Dictionary).get(key, STAT_BASE))
	v += int(((background_by_id(str(ch.get("background", ""))).get("bias", {})) as Dictionary).get(key, 0))
	v += int(((perk_by_id(str(ch.get("perk", ""))).get("stats", {})) as Dictionary).get(key, 0))
	return clampi(v, 1, 10)

## Efecto -1..+1 de un atributo (5 es neutro).
static func edge(ch: Dictionary, key: String) -> float:
	return clampf((float(stat(ch, key)) - 5.0) / 5.0, -1.0, 1.0)

static func has_perk(ch: Dictionary, id: String) -> bool:
	return str(ch.get("perk", "")) == id

static func points_spent(stats: Dictionary) -> int:
	var t := 0
	for k in stat_ids():
		t += int(stats.get(k, STAT_BASE)) - STAT_BASE
	return t

static func default_appearance() -> Dictionary:
	return {"skin": 1, "hair": 1, "hair_color": 1, "face": 0, "eyes": 0, "brows": 0, "nose": 0, "mouth": 0, "facial": 0, "glasses": 0, "outfit": 0, "feature": 0, "age_look": 0.4}

static func default_character() -> Dictionary:
	var st: Dictionary = {}
	for k in stat_ids():
		st[k] = STAT_BASE
	return {"name": "", "surname": "", "gender": "f", "age": 48, "background": "abogado", "perk": "outsider", "stats": st, "appearance": default_appearance()}

static func full_name(ch: Dictionary) -> String:
	var n := str(ch.get("name", "")).strip_edges()
	var s := str(ch.get("surname", "")).strip_edges()
	return (n + " " + s).strip_edges()

static func randomize_appearance(rng: RandomNumberGenerator, gender: String) -> Dictionary:
	var a := default_appearance()
	a["skin"] = rng.randi_range(0, 3) if rng.randf() < 0.85 else rng.randi_range(4, 5)
	a["hair"] = rng.randi_range(0, HAIR_STYLES.size() - 1)
	if gender == "m" and rng.randf() < 0.55:
		a["hair"] = [0, 1, 2, 3, 9, 7][rng.randi_range(0, 5)]
	elif gender == "f" and rng.randf() < 0.7:
		a["hair"] = [1, 2, 3, 4, 5, 8, 7][rng.randi_range(0, 6)]
	a["hair_color"] = rng.randi_range(0, HAIR_COLOR.size() - 1)
	a["face"] = rng.randi_range(0, FACE_SHAPES.size() - 1)
	a["eyes"] = rng.randi_range(0, EYES.size() - 1)
	a["brows"] = rng.randi_range(0, BROWS.size() - 1)
	a["nose"] = rng.randi_range(0, NOSES.size() - 1)
	a["mouth"] = rng.randi_range(0, MOUTHS.size() - 1)
	a["facial"] = rng.randi_range(0, FACIAL.size() - 1) if gender == "m" and rng.randf() < 0.45 else 0
	a["glasses"] = rng.randi_range(0, GLASSES.size() - 1) if rng.randf() < 0.4 else 0
	a["outfit"] = rng.randi_range(0, OUTFITS.size() - 1)
	a["feature"] = rng.randi_range(0, FEATURES.size() - 1) if rng.randf() < 0.6 else 0
	a["age_look"] = rng.randf_range(0.15, 0.9)
	return a

## Líder ficticio de un partido de la IA. Determinista: mismo partido y semilla, mismo personaje.
static func generate(party_id: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(party_id) ^ seed_value
	var gender := "f" if rng.randf() < 0.42 else "m"
	var pool_m := MALE
	var pool_f := FEMALE
	var pool_s := SURNAME
	match party_id:
		"erc", "junts", "alianca":
			pool_m = CAT_M; pool_f = CAT_F; pool_s = CAT_S
		"pnv", "ehbildu":
			pool_m = EUS_M; pool_f = EUS_F; pool_s = EUS_S
		"bng":
			pool_m = GAL_M; pool_f = GAL_F; pool_s = GAL_S
	var pool := pool_f if gender == "f" else pool_m
	var st: Dictionary = {}
	for k in stat_ids():
		st[k] = clampi(rng.randi_range(2, 7), 1, 8)
	return {
		"name": str(pool[rng.randi_range(0, pool.size() - 1)]), "surname": str(pool_s[rng.randi_range(0, pool_s.size() - 1)]),
		"gender": gender, "age": rng.randi_range(38, 66), "background": str((BACKGROUNDS[rng.randi_range(0, BACKGROUNDS.size() - 1)] as Dictionary)["id"]),
		"perk": str((PERKS[rng.randi_range(0, PERKS.size() - 1)] as Dictionary)["id"]), "stats": st, "appearance": randomize_appearance(rng, gender), "ai": true
	}

static func random_player(rng: RandomNumberGenerator) -> Dictionary:
	var ch := default_character()
	ch["gender"] = "f" if rng.randf() < 0.5 else "m"
	var pool := FEMALE if ch["gender"] == "f" else MALE
	ch["name"] = str(pool[rng.randi_range(0, pool.size() - 1)])
	ch["surname"] = str(SURNAME[rng.randi_range(0, SURNAME.size() - 1)])
	ch["age"] = rng.randi_range(36, 62)
	ch["background"] = str((BACKGROUNDS[rng.randi_range(0, BACKGROUNDS.size() - 1)] as Dictionary)["id"])
	ch["perk"] = str((PERKS[rng.randi_range(0, PERKS.size() - 1)] as Dictionary)["id"])
	ch["appearance"] = randomize_appearance(rng, str(ch["gender"]))
	var st := ch["stats"] as Dictionary
	var ids := stat_ids()
	var left := STAT_POINTS
	while left > 0:
		var k := str(ids[rng.randi_range(0, ids.size() - 1)])
		if int(st[k]) < STAT_MAX:
			st[k] = int(st[k]) + 1
			left -= 1
	return ch

## Resumen de una línea: oficio · rasgo.
static func tagline(ch: Dictionary) -> String:
	var b := str(background_by_id(str(ch.get("background", ""))).get("name", ""))
	var p := str(perk_by_id(str(ch.get("perk", ""))).get("name", ""))
	return "%s · %s · %d años" % [b, p, int(ch.get("age", 45))]
