class_name Rules
extends RefCounted
## Constantes y tablas de datos del juego. No contiene estado.

const SCHEMA_VERSION := 3
const GAME_STAGE := "Alpha"  ## fase de desarrollo; pasará a la numeración definitiva cuando el usuario dé por terminada la alpha
const GAME_VERSION := "0.2.5"  ## Alpha 0.2.x: se sube el último número en cada entrega validada (ver CHANGELOG.md)
const CAMPAIGN_LENGTH_DAYS := 42
const MAJORITY := 176
const CONGRESS_SEATS := 350
const CANDIDATE_MIN_SEATS := 35
const MAX_INVESTITURE_ATTEMPTS := 2  ## el Rey propone primero al más votado y después al segundo; si ambos fracasan, elecciones
const LEGISLATURE_MONTHS := 48

## Poder negociador de un partido (spec negociación §4.3): pesos iniciales de los seis factores. No decide nada por sí
## solo: modula la dureza de lo que exige, el valor que da a lo que recibe, lo que cede y lo que le cuesta irse de la mesa.
const NEGOTIATION_WEIGHTS := {
	"seats": 0.25, "decisive": 0.25, "affinity": 0.15, "alternatives": 0.15, "interest": 0.10, "credibility": 0.10
}
const NEGOTIATION_FACTOR_NAMES := {
	"seats": "Peso parlamentario", "decisive": "Carácter decisivo", "affinity": "Afinidad ideológica",
	"alternatives": "Alternativas de Gobierno", "interest": "Intereses y urgencia", "credibility": "Credibilidad y cohesión"
}
## Cuánto sube la exigencia (`need`) por cada punto de poder negociador por encima de la media (0.4).
const POWER_NEED_SLOPE := 0.10
## Modalidades de participación posibles de un partido (spec §4.2).
const MODALITIES := {
	"coalition": {"name": "Coalición", "short": "Entrar en el Gobierno", "desc": "Entra en el Gobierno y asume carteras."},
	"external": {"name": "Apoyo externo", "short": "Apoyo externo", "desc": "Apoya la investidura sin entrar en el Ejecutivo."},
	"puntual": {"name": "Acuerdo puntual", "short": "Acuerdo puntual", "desc": "Compromete votos concretos (investidura, presupuesto, reforma)."},
	"abstention": {"name": "Abstención negociada", "short": "Abstención negociada", "desc": "Facilita la elección sin apoyo político pleno."},
	"opposition": {"name": "Oposición", "short": "Oposición", "desc": "Rechaza el acuerdo y se reserva para futuras votaciones."},
	"block": {"name": "Bloqueo o veto", "short": "Bloqueo", "desc": "Rechaza al candidato, al socio o ciertas condiciones."}
}
const MODALITY_ORDER := ["coalition", "external", "puntual", "abstention", "opposition", "block"]
## Categorías de la mesa de negociación (spec §5) y los tipos de término que contiene cada una.
const TABLE_CATEGORIES := {
	"participacion": {"name": "Participación", "kinds": ["vote_yes", "vote_abstain", "participation", "stability"]},
	"estructura": {"name": "Estructura", "kinds": ["structure"]},
	"carteras": {"name": "Carteras", "kinds": ["cabinet", "portfolio"]},
	"politicas": {"name": "Políticas", "kinds": ["policy"]},
	"objetivos": {"name": "Objetivos", "kinds": ["objective"]},
	"territorio": {"name": "Territorio", "kinds": ["territory"]},
	"presupuesto": {"name": "Presupuesto", "kinds": ["budget"]},
	"parlamento": {"name": "Parlamento", "kinds": ["bills", "law_vote", "law_abstain", "law_amend", "owe_vote", "parliament", "joint_list"]},
	"instituciones": {"name": "Instituciones", "kinds": ["institution", "cordon"]},
	"calendario": {"name": "Calendario", "kinds": ["calendar"]}
}
const TABLE_CATEGORY_ORDER := ["participacion", "estructura", "carteras", "politicas", "objetivos", "territorio", "presupuesto", "parlamento", "instituciones", "calendario"]
## Estado de un término de la mesa según lo que se sabe de la postura del otro lado.
const TERM_STATUS_NAMES := {"must": "Imprescindible", "negotiable": "Negociable", "rejected": "Rechazada", "unknown": "Sin sondear", "agreed": "Aceptada"}
const MAX_DRAFTS := 6
const MAX_VERSIONS := 12
const TURN_MONTHS := 3  ## cada turno de legislatura es un trimestre
const LEGISLATURE_TURNS := 16
const OTHERS_ID := "otros"
const MAX_EVENTS_PER_DAY := 3
const AGENDA_HOURS := [9, 11, 13, 16, 18, 20]

## Inicio de campaña del escenario 2023 (día 42 = víspera de las elecciones).
const START_DATE := {"year": 2023, "month": 6, "day": 11, "hour": 12, "minute": 0, "second": 0}

const MONTHS_ES := ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
const WEEKDAYS_ES := ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]

## Intención de voto inicial simulada (no son sondeos oficiales). La suma es 100.
const BASE_POLL := {
	"pp": 31.0, "psoe": 26.5, "vox": 19.0, "sumar": 6.8, "podemos": 1.9, "erc": 2.3, "junts": 1.5,
	"ehbildu": 1.3, "pnv": 1.0, "bng": 0.7, "cc": 0.4, "upn": 0.3, "salf": 2.2, "adelante": 1.2, "alianca": 1.0, "otros": 2.9
}

## Territorio en el que compite cada formación regional y su peso aproximado sobre el censo total.
const REGIONALIST_TERRITORY := {
	"erc": {"communities": ["Cataluña"], "electorate": 0.16},
	"junts": {"communities": ["Cataluña"], "electorate": 0.16},
	"ehbildu": {"communities": ["País Vasco", "Navarra"], "electorate": 0.061},
	"pnv": {"communities": ["País Vasco"], "electorate": 0.047},
	"bng": {"communities": ["Galicia"], "electorate": 0.057},
	"cc": {"communities": ["Canarias"], "electorate": 0.045},
	"upn": {"communities": ["Navarra"], "electorate": 0.014},
	"adelante": {"communities": ["Andalucía"], "electorate": 0.18},
	"alianca": {"communities": ["Cataluña"], "electorate": 0.16}
}

## Sesgo territorial simulado para las formaciones estatales (1.0 = neutro).
const COMMUNITY_LEAN := {
	"Comunidad de Madrid": {"pp": 1.28, "psoe": 0.82, "vox": 1.05, "sumar": 1.0},
	"Andalucía": {"pp": 1.0, "psoe": 1.02, "vox": 0.92, "sumar": 0.78},
	"Cataluña": {"pp": 0.45, "psoe": 1.2, "vox": 0.65, "sumar": 1.1},
	"Comunitat Valenciana": {"pp": 1.05, "psoe": 0.95, "vox": 1.18, "sumar": 1.0},
	"Galicia": {"pp": 1.25, "psoe": 0.82, "vox": 0.55, "sumar": 0.75},
	"Castilla y León": {"pp": 1.3, "psoe": 0.85, "vox": 0.98, "sumar": 0.55},
	"Castilla-La Mancha": {"pp": 1.0, "psoe": 1.18, "vox": 1.05, "sumar": 0.6},
	"País Vasco": {"pp": 0.5, "psoe": 1.0, "vox": 0.3, "sumar": 0.9},
	"Región de Murcia": {"pp": 1.18, "psoe": 0.85, "vox": 1.75, "sumar": 0.5},
	"Aragón": {"pp": 1.15, "psoe": 0.9, "vox": 1.2, "sumar": 0.85},
	"Extremadura": {"pp": 1.0, "psoe": 1.25, "vox": 0.9, "sumar": 0.5},
	"Principado de Asturias": {"pp": 0.9, "psoe": 1.15, "vox": 0.55, "sumar": 1.15},
	"Canarias": {"pp": 0.85, "psoe": 1.15, "vox": 0.65, "sumar": 1.0},
	"Illes Balears": {"pp": 1.12, "psoe": 0.95, "vox": 1.0, "sumar": 1.0},
	"Navarra": {"pp": 0.7, "psoe": 1.15, "vox": 0.75, "sumar": 0.9},
	"Cantabria": {"pp": 1.15, "psoe": 0.9, "vox": 0.85, "sumar": 0.7},
	"La Rioja": {"pp": 1.2, "psoe": 0.9, "vox": 0.95, "sumar": 0.6},
	"Ceuta": {"pp": 1.2, "psoe": 0.7, "vox": 2.2, "sumar": 0.3},
	"Melilla": {"pp": 1.2, "psoe": 0.7, "vox": 1.9, "sumar": 0.3}
}

const ISSUES := [
	{"id": "housing", "name": "Vivienda"},
	{"id": "tax", "name": "Impuestos"},
	{"id": "health", "name": "Sanidad"},
	{"id": "education", "name": "Educación"},
	{"id": "jobs", "name": "Empleo y salarios"},
	{"id": "energy", "name": "Transición energética"},
	{"id": "security", "name": "Seguridad"},
	{"id": "territory", "name": "Modelo territorial"}
]

const POLICIES := [
	{"id": "housing", "name": "Vivienda asequible", "desc": "Impulsar vivienda pública y facilitar el acceso al alquiler.", "cost": "Coste medio · efecto a medio plazo"},
	{"id": "tax", "name": "Bajada de impuestos", "desc": "Reducir la presión fiscal sobre familias y empresas.", "cost": "Atrae voto de centro-derecha · reduce margen fiscal"},
	{"id": "health", "name": "Refuerzo de sanidad", "desc": "Aumentar recursos y reducir listas de espera.", "cost": "Alto coste · gran respaldo ciudadano"},
	{"id": "education", "name": "Educación pública", "desc": "Mejorar financiación, becas y formación profesional.", "cost": "Coste medio · efecto lento"},
	{"id": "jobs", "name": "Empleo y salarios", "desc": "Impulsar empleo estable y mejorar salarios.", "cost": "Tema central en toda campaña"},
	{"id": "energy", "name": "Transición energética", "desc": "Acelerar renovables y eficiencia energética.", "cost": "Voto joven y urbano · sensible en el sector industrial"},
	{"id": "security", "name": "Seguridad", "desc": "Reforzar medios policiales y prevención del delito.", "cost": "Visibilidad alta · tema volátil"},
	{"id": "territory", "name": "Reforma territorial", "desc": "Revisar la financiación autonómica y el reparto competencial.", "cost": "Polariza · decisivo para los socios"}
]

const CAMPAIGN_TONES := {
	"positive": {"name": "Propositivo", "desc": "Defender tus propuestas sin entrar al choque. Gana confianza, poca notoriedad."},
	"contrast": {"name": "Contraste", "desc": "Comparar tu programa con el de los rivales. Equilibrio entre confianza y visibilidad."},
	"attack": {"name": "Ataque", "desc": "Confrontación directa. Mucha visibilidad y desgaste del principal rival, pero erosiona tu credibilidad."}
}

const EVENT_TYPES := {
	"Mitin": {"cost": 18000.0, "color": "#F2A33A", "desc": "Gran acto público. Aumenta visibilidad y refuerza la provincia anfitriona."},
	"Entrevista": {"cost": 5000.0, "color": "#4DA8FF", "desc": "Entrevista política en medios nacionales. Puedes participar personalmente.", "interview": true},
	"Debate": {"cost": 10000.0, "color": "#A78BFA", "desc": "Debate con rivales. Alto riesgo y alta visibilidad.", "interview": true},
	"Podcast": {"cost": 4000.0, "color": "#D08BFF", "desc": "Conversación larga en un pódcast político. Poca presión, buen alcance entre los jóvenes.", "interview": true},
	"Rueda de prensa": {"cost": 7000.0, "color": "#FF7A8A", "desc": "Preguntas de la prensa sobre la actualidad.", "interview": true},
	"Visita territorial": {"cost": 9000.0, "color": "#34D3A0", "desc": "Visita a una provincia: refuerza tu implantación local."},
	"Reunión de equipo": {"cost": 1500.0, "color": "#8FA3B8", "desc": "Cohesión interna y coordinación de la campaña."},
	"Recaudación de fondos": {"cost": 2000.0, "color": "#F5D04B", "desc": "Cena o acto para captar donaciones. Genera ingresos."},
	"Descanso": {"cost": 0.0, "color": "#6F7F90", "desc": "Recupera energías del candidato."}
}

## Sedes de actos: ciudad → circunscripción en la que tienen efecto.
const VENUES := {
	"Madrid": "Madrid", "Barcelona": "Barcelona", "Valencia": "Valencia/València", "Sevilla": "Sevilla",
	"Málaga": "Málaga", "Zaragoza": "Zaragoza", "Bilbao": "Bizkaia", "A Coruña": "A Coruña",
	"Valladolid": "Valladolid", "Toledo": "Toledo", "Mérida": "Badajoz", "Las Palmas": "Las Palmas",
	"Murcia": "Murcia", "Oviedo": "Asturias", "Palma": "Illes Balears", "Pamplona": "Navarra"
}

const DEMANDS := {
	"economy": [
		{"issue": "tax", "text": "Garantías sobre la política fiscal"},
		{"issue": "jobs", "text": "Un calendario de inversión y empleo"},
		{"issue": "jobs", "text": "Compromiso de estabilidad presupuestaria"}
	],
	"housing": [
		{"issue": "housing", "text": "Un pacto estatal de vivienda"},
		{"issue": "housing", "text": "Medidas de alquiler y ampliación de oferta residencial"}
	],
	"territory": [
		{"issue": "territory", "text": "Reforma de la financiación autonómica"},
		{"issue": "territory", "text": "Más competencias y respeto al autogobierno"},
		{"issue": "territory", "text": "Inversiones territoriales plurianuales"}
	],
	"public": [
		{"issue": "health", "text": "Refuerzo de sanidad"},
		{"issue": "education", "text": "Blindaje de la financiación de la educación pública"}
	],
	"energy": [
		{"issue": "energy", "text": "Calendario vinculante de transición energética"},
		{"issue": "energy", "text": "Inversiones en transporte sostenible"}
	],
	"security": [
		{"issue": "security", "text": "Refuerzo de medios de seguridad"},
		{"issue": "security", "text": "Plan de prevención y seguridad ciudadana"}
	]
}

const MINISTRY_CATALOG := [
	"Presidencia y Relaciones con las Cortes", "Hacienda", "Asuntos Exteriores", "Defensa",
	"Interior", "Justicia", "Transportes y Movilidad", "Vivienda", "Sanidad",
	"Educación y Formación Profesional", "Trabajo y Economía Social", "Economía y Empresa",
	"Industria y Comercio", "Agricultura y Alimentación", "Transición Ecológica",
	"Cultura", "Ciencia y Universidades", "Igualdad", "Política Territorial",
	"Derechos Sociales", "Turismo", "Deportes", "Transformación Digital", "Consumo"
]

const BILLS := [
	{"id": "housing_pact", "name": "Ley de vivienda y alquiler", "issue": "housing", "impact": 2.2},
	{"id": "tax_reform", "name": "Reforma fiscal", "issue": "tax", "impact": 1.8},
	{"id": "health_plan", "name": "Plan de refuerzo sanitario", "issue": "health", "impact": 2.4},
	{"id": "education_law", "name": "Ley de educación y FP", "issue": "education", "impact": 1.8},
	{"id": "labour_reform", "name": "Reforma laboral", "issue": "jobs", "impact": 2.2},
	{"id": "energy_plan", "name": "Plan de transición energética", "issue": "energy", "impact": 1.6},
	{"id": "security_law", "name": "Ley de seguridad ciudadana", "issue": "security", "impact": 1.5},
	{"id": "territorial_funding", "name": "Nueva financiación autonómica", "issue": "territory", "impact": 2.0}
]

const LEGISLATURE_EVENTS := [
	{
		"id": "scandal", "title": "Escándalo en el entorno del Ejecutivo",
		"body": "Un medio publica irregularidades en la contratación de un organismo público vinculado al Gobierno.",
		"choices": [
			{"label": "Exigir una investigación independiente", "approval": -1.0, "stability": 2.0, "trust": 2.0},
			{"label": "Defender la actuación del Gobierno", "approval": -3.0, "stability": -1.0, "trust": -2.0},
			{"label": "Destituir al responsable", "approval": -0.5, "stability": 1.0, "trust": 1.0}
		]
	},
	{
		"id": "strike", "title": "Huelga en el sector del transporte",
		"body": "Los sindicatos convocan paros que afectan a trenes y aeropuertos durante varios días.",
		"choices": [
			{"label": "Abrir una mesa de negociación", "approval": 0.5, "stability": 1.0, "trust": 1.0, "funds": -15000},
			{"label": "Decretar servicios mínimos estrictos", "approval": -1.5, "stability": -1.0, "trust": -1.0},
			{"label": "Esperar a que se desgasten las posiciones", "approval": -2.5, "stability": -2.0, "trust": 0.0}
		]
	},
	{
		"id": "budget", "title": "Tensión por los Presupuestos",
		"body": "Los socios amenazan con bloquear las cuentas si no se incorporan sus enmiendas.",
		"choices": [
			{"label": "Aceptar parte de las enmiendas", "approval": 0.0, "stability": 4.0, "trust": 0.0},
			{"label": "Mantener el proyecto sin cambios", "approval": 1.0, "stability": -5.0, "trust": 1.0},
			{"label": "Prorrogar las cuentas", "approval": -1.5, "stability": -1.0, "trust": -1.0}
		]
	},
	{
		"id": "territorial", "title": "Pulso territorial",
		"body": "Un gobierno autonómico reclama más competencias y eleva el tono en la prensa.",
		"choices": [
			{"label": "Abrir una comisión bilateral", "approval": -0.5, "stability": 2.0, "trust": 1.0},
			{"label": "Rechazar la reclamación", "approval": 0.5, "stability": -2.5, "trust": 0.0},
			{"label": "Ofrecer una mejora de financiación", "approval": -1.0, "stability": 3.0, "trust": 0.0, "funds": -10000}
		]
	},
	{
		"id": "economy_up", "title": "Buenos datos de empleo",
		"body": "El paro baja más de lo previsto y los indicadores de actividad mejoran.",
		"choices": [
			{"label": "Capitalizar el dato en campaña pública", "approval": 2.0, "stability": 0.0, "trust": 0.0},
			{"label": "Pedir prudencia y consolidar", "approval": 1.0, "stability": 1.0, "trust": 1.0}
		]
	},
	{
		"id": "economy_down", "title": "Frenazo económico",
		"body": "Los últimos datos muestran enfriamiento del consumo y caída de la inversión.",
		"choices": [
			{"label": "Aprobar un paquete de estímulo", "approval": 1.0, "stability": 1.0, "trust": 0.0, "funds": -20000},
			{"label": "Mantener la disciplina fiscal", "approval": -2.0, "stability": 0.0, "trust": 1.0},
			{"label": "Culpar al contexto internacional", "approval": -1.0, "stability": -1.0, "trust": -1.0}
		]
	},
	{
		"id": "minister", "title": "Dimisión de un ministro",
		"body": "Un miembro del Consejo de Ministros presenta su dimisión por motivos personales.",
		"choices": [
			{"label": "Nombrar a un perfil técnico", "approval": 0.5, "stability": 1.0, "trust": 1.0},
			{"label": "Nombrar a un cargo del partido", "approval": 0.0, "stability": -1.0, "trust": 0.0},
			{"label": "Remodelar el Gobierno", "approval": 1.0, "stability": 3.0, "trust": 0.0}
		]
	},
	{
		"id": "protest", "title": "Manifestación multitudinaria",
		"body": "Miles de personas se concentran frente al Congreso reclamando medidas sobre el coste de la vida.",
		"choices": [
			{"label": "Recibir a los convocantes", "approval": 1.0, "stability": 0.0, "trust": 2.0},
			{"label": "Reiterar el compromiso del programa", "approval": -0.5, "stability": 0.0, "trust": 0.0},
			{"label": "Ignorar la movilización", "approval": -2.0, "stability": -1.0, "trust": -2.0}
		]
	}
]

const INTERVIEW_QUESTIONS := [
	{
		"question": "Su partido promete cambios importantes. ¿Cómo piensa financiarlos?", "issue": "tax",
		"answers": [
			{"text": "Presentaremos una memoria económica con fases, ingresos y costes verificables.", "credibility": 3.0, "visibility": 1.0, "trust": 2.0},
			{"text": "Lo importante es la voluntad política; los recursos se encontrarán.", "credibility": -2.0, "visibility": 1.0, "trust": -1.0},
			{"text": "Primero hay que acabar con los privilegios y el despilfarro.", "credibility": 0.0, "visibility": 2.0, "trust": 0.5},
			{"text": "La pregunta demuestra que los demás partidos no tienen soluciones.", "credibility": -1.0, "visibility": 2.0, "trust": -1.0}
		]
	},
	{
		"question": "¿Qué compromiso de su programa considera irrenunciable?", "issue": "",
		"answers": [
			{"text": "La propuesta prioritaria de nuestro programa, con objetivos y calendario públicos.", "credibility": 2.0, "visibility": 1.0, "trust": 2.0},
			{"text": "No renunciaremos a ninguna promesa, aunque haya que negociar.", "credibility": -1.0, "visibility": 1.0, "trust": 1.0},
			{"text": "Dependerá de la situación económica que encontremos.", "credibility": 1.0, "visibility": 0.0, "trust": -0.5},
			{"text": "No vamos a hablar de líneas rojas antes de votar.", "credibility": 0.0, "visibility": -0.5, "trust": -1.0}
		]
	},
	{
		"question": "¿Qué le diría a una familia que no llega a final de mes?", "issue": "jobs",
		"answers": [
			{"text": "Presentaremos medidas concretas sobre vivienda, salarios y coste de la vida, con plazos medibles.", "credibility": 3.0, "visibility": 1.0, "trust": 2.0},
			{"text": "La situación es difícil, pero nuestro programa ofrece una dirección clara.", "credibility": 1.0, "visibility": 0.5, "trust": 1.0},
			{"text": "La culpa es exclusivamente del Gobierno actual.", "credibility": -1.0, "visibility": 1.5, "trust": -1.0},
			{"text": "No puedo prometer soluciones inmediatas; sí transparencia y prioridades realistas.", "credibility": 2.0, "visibility": 0.0, "trust": 2.0}
		]
	},
	{
		"question": "¿Aceptaría cambiar una parte de su programa para alcanzar un acuerdo?", "issue": "",
		"answers": [
			{"text": "Sí, si el acuerdo es público, mejora el resultado y respeta nuestras líneas fundamentales.", "credibility": 3.0, "visibility": 1.0, "trust": 2.0},
			{"text": "No. Nuestro programa es un contrato con los votantes.", "credibility": 1.0, "visibility": 1.0, "trust": 0.5},
			{"text": "Dependerá de qué partido lo proponga.", "credibility": -1.0, "visibility": 0.5, "trust": -1.0},
			{"text": "Primero escucharemos a los ciudadanos y después negociaremos.", "credibility": 1.0, "visibility": 0.5, "trust": 1.0}
		]
	},
	{
		"question": "¿Con qué partidos estaría dispuesto a pactar después de las elecciones?", "issue": "",
		"answers": [
			{"text": "Con quien acepte un acuerdo público, coherente con nuestro programa.", "credibility": 2.0, "visibility": 1.0, "trust": 2.0},
			{"text": "Con cualquiera que permita aplicar nuestras propuestas.", "credibility": -1.0, "visibility": 1.0, "trust": -1.0},
			{"text": "Hay líneas políticas que no vamos a cruzar.", "credibility": 1.0, "visibility": 1.0, "trust": 1.0},
			{"text": "Ahora estamos centrados en pedir el voto, no en repartir cargos.", "credibility": 0.0, "visibility": 1.0, "trust": 0.0}
		]
	},
	{
		"question": "El precio del alquiler se ha disparado en las grandes ciudades. ¿Qué haría usted?", "issue": "housing",
		"answers": [
			{"text": "Un plan de vivienda pública con calendario, financiación y cifras de viviendas concretas.", "credibility": 3.0, "visibility": 1.0, "trust": 2.0},
			{"text": "Topes de precios inmediatos en todo el país.", "credibility": 0.0, "visibility": 2.0, "trust": 0.0},
			{"text": "Liberar suelo y reducir trabas administrativas para que aumente la oferta.", "credibility": 2.0, "visibility": 0.5, "trust": 1.0}
		]
	},
	{
		"question": "Las listas de espera sanitarias son un problema creciente. ¿Qué propone?", "issue": "health",
		"answers": [
			{"text": "Aumentar plantillas y blindar la financiación de la atención primaria.", "credibility": 2.0, "visibility": 1.0, "trust": 2.0},
			{"text": "Derivar pacientes a la sanidad privada concertada de forma urgente.", "credibility": 0.0, "visibility": 1.5, "trust": -0.5},
			{"text": "Auditar la gestión actual antes de comprometer más gasto.", "credibility": 1.0, "visibility": 0.5, "trust": 1.0}
		]
	},
	{
		"question": "¿Reducirá usted los impuestos o los subirá a quienes más tienen?", "issue": "tax",
		"answers": [
			{"text": "Una reforma fiscal equilibrada, con estimación de ingresos publicada.", "credibility": 3.0, "visibility": 0.5, "trust": 2.0},
			{"text": "Bajaremos impuestos a las familias y pagaremos con crecimiento económico.", "credibility": -0.5, "visibility": 1.5, "trust": 0.0},
			{"text": "Subiremos impuestos a las grandes fortunas y a la banca.", "credibility": 0.5, "visibility": 2.0, "trust": 0.0}
		]
	},
	{
		"question": "¿Qué papel deben tener las energías renovables en los próximos diez años?", "issue": "energy",
		"answers": [
			{"text": "Acelerarlas, con ayudas a la industria para que la transición no destruya empleo.", "credibility": 2.5, "visibility": 1.0, "trust": 2.0},
			{"text": "Ir más despacio hasta garantizar precios estables.", "credibility": 1.0, "visibility": 0.0, "trust": 0.5},
			{"text": "Prohibir lo antes posible los combustibles fósiles.", "credibility": -1.0, "visibility": 2.0, "trust": -0.5}
		]
	},
	{
		"question": "¿Cómo debe financiarse y organizarse el Estado autonómico?", "issue": "territory",
		"answers": [
			{"text": "Con una financiación transparente, multilateral y acordada con todas las comunidades.", "credibility": 2.5, "visibility": 0.5, "trust": 2.0},
			{"text": "Recentralizando competencias clave para garantizar la igualdad.", "credibility": 0.5, "visibility": 1.5, "trust": 0.0},
			{"text": "Ampliando el autogobierno allí donde lo pida el Parlamento autonómico.", "credibility": 0.5, "visibility": 1.0, "trust": 0.5}
		]
	},
	{
		"question": "La seguridad ciudadana preocupa a muchos votantes. ¿Qué medidas adoptará?", "issue": "security",
		"answers": [
			{"text": "Más medios policiales y prevención en barrios, con evaluación pública de resultados.", "credibility": 2.5, "visibility": 1.0, "trust": 2.0},
			{"text": "Endurecer las penas de forma generalizada.", "credibility": 0.0, "visibility": 2.0, "trust": -0.5},
			{"text": "Invertir en políticas sociales como forma principal de prevención.", "credibility": 1.0, "visibility": 0.5, "trust": 1.0}
		]
	},
	{
		"question": "Muchos jóvenes no consiguen independizarse. ¿Qué les ofrece?", "issue": "education",
		"answers": [
			{"text": "Becas, formación profesional dual y ayudas al primer empleo.", "credibility": 2.5, "visibility": 1.0, "trust": 2.0},
			{"text": "Un cheque de 500 euros mensuales para todos los menores de 30.", "credibility": -1.0, "visibility": 2.0, "trust": 0.0},
			{"text": "Menos burocracia para emprender y contratar.", "credibility": 1.0, "visibility": 0.5, "trust": 0.5}
		]
	}
]

## Plantillas de declaraciones. Cada entrada: [titular, cuerpo]. Los marcadores son posicionales.
## attack_player / open_door: titular (partido, jugador) · cuerpo (partido, jugador, tema)
## own_proposal: titular (partido) · cuerpo (tema)
## attack_rival: titular (partido) · cuerpo (partido, rival)
## red_lines: titular (partido) · cuerpo (partido, tema)
const AI_STATEMENTS := {
	"attack_player": [
		["%s critica la estrategia de %s", "%s sostiene que las propuestas de %s sobre %s carecen de garantías y exige explicaciones públicas."],
		["%s acusa a %s de improvisar", "La dirección de %s afirma que %s no ha concretado su posición sobre %s y reclama transparencia."],
		["%s desafía a %s a un debate", "%s emplaza a %s a debatir en público sobre %s y a presentar cifras verificables."]
	],
	"open_door": [
		["%s abre la puerta a un acuerdo con %s", "%s reconoce coincidencias con %s en materia de %s y no descarta negociar medidas concretas."],
		["%s tiende la mano a %s", "%s considera que existe margen de entendimiento con %s sobre %s y propone una reunión discreta."]
	],
	"own_proposal": [
		["%s presenta una propuesta propia", "La formación sitúa %s entre sus prioridades y anuncia que llevará nuevas medidas al debate público."],
		["%s lanza un plan de choque", "El partido presenta un paquete de medidas sobre %s y reclama que el resto de formaciones se pronuncien."]
	],
	"attack_rival": [
		["%s cuestiona a otro grupo", "%s acusa a %s de falta de coherencia y reclama un debate centrado en propuestas."]
	],
	"red_lines": [
		["%s marca sus líneas rojas", "La dirección de %s advierte de que no apoyará acuerdos que ignoren sus prioridades en %s."]
	]
}


## «Alpha 0.2.0»: lo que se muestra al jugador.
static func version_label() -> String:
	return "%s %s" % [GAME_STAGE, GAME_VERSION]

static func issue_name(issue_id: String) -> String:
	for item in ISSUES:
		if str(item["id"]) == issue_id:
			return str(item["name"])
	return issue_id

static func date_string(unix_seconds: float, with_weekday := false) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_seconds))
	var base := "%d %s %d" % [int(dt["day"]), MONTHS_ES[int(dt["month"]) - 1], int(dt["year"])]
	if with_weekday:
		return "%s %s" % [WEEKDAYS_ES[int(dt["weekday"])], base]
	return base

static func start_unix() -> int:
	return int(Time.get_unix_time_from_datetime_dict(START_DATE))

static func money(value: float) -> String:
	var n := int(round(value))
	var text := str(absi(n))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out

## Número de turno (trimestre) de la legislatura que corresponde a un mes de legislatura (1..48 → 1..16).
static func turn_of(month: int) -> int:
	return int((maxi(month, 1) - 1) / TURN_MONTHS) + 1

## «T3 23»: trimestre natural y año de dos cifras de una marca de tiempo.
static func quarter_label(unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "T%d %02d" % [int((int(dt["month"]) - 1) / 3) + 1, int(dt["year"]) % 100]

## «jul 23»: mes abreviado y año de dos cifras de una marca de tiempo.
static func month_label(unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%s %02d" % [MONTHS_ES[int(dt["month"]) - 1], int(dt["year"]) % 100]
