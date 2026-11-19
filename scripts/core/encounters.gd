class_name Encounters
extends RefCounted
## Motor de encuentros con los medios: entrevistas, debates, ruedas de prensa, preguntas en la bandeja
## e incidentes tras las reuniones. Las preguntas se componen con piezas (medio, periodista, tema, gancho,
## tipo de pregunta, estilo de respuesta) y recuerdan lo que ya se dijo para no repetirse.
## Todo efecto es real: imagen ante los votantes (5 dimensiones), opinión por segmentos,
## confianza, visibilidad, encuestas, relaciones con otros partidos y memoria de lo declarado.

var m: GameModel

const SEGMENTS := {
	"obreros": {"name": "Trabajadores", "w": 0.20, "lean": -0.5},
	"urbanos": {"name": "Clases medias urbanas", "w": 0.22, "lean": -0.05},
	"jovenes": {"name": "Jóvenes", "w": 0.15, "lean": -0.35},
	"mayores": {"name": "Mayores", "w": 0.20, "lean": 0.2},
	"rurales": {"name": "Mundo rural", "w": 0.10, "lean": 0.3},
	"autonomos": {"name": "Autónomos y empresas", "w": 0.13, "lean": 0.55},
}
## Medios que solo aparecen en formatos concretos (pódcast y Pleno).
const OUTLETS_EXTRA := [
	{"id": "cafe", "name": "Café con Política", "kind": "podcast", "lean": -0.1, "reach": 0.8},
	{"id": "sinfiltro", "name": "Sin Filtro", "kind": "podcast", "lean": 0.25, "reach": 0.9},
	{"id": "larga", "name": "La Conversación Larga", "kind": "podcast", "lean": 0.0, "reach": 0.85},
	{"id": "congreso", "name": "Congreso de los Diputados", "kind": "pleno", "lean": 0.0, "reach": 1.0},
]
const IMAGE_DIMS := {
	"competence": "Competencia", "honesty": "Honradez", "empathy": "Cercanía", "strength": "Liderazgo", "closeness": "Sintonía",
}
# "closeness" se muestra como «Sintonía» con los votantes de tu bloque; "empathy" como «Cercanía».

const OUTLETS := [
	{"id": "tele1", "name": "Telediario Primera", "kind": "tv", "lean": 0.0, "reach": 1.3},
	{"id": "agora", "name": "Radio Ágora", "kind": "radio", "lean": -0.2, "reach": 0.9},
	{"id": "diario", "name": "El Diario Hispano", "kind": "prensa", "lean": -0.55, "reach": 0.9},
	{"id": "voz", "name": "La Voz de España", "kind": "prensa", "lean": 0.55, "reach": 0.9},
	{"id": "manana", "name": "Mañanas en Directo", "kind": "tv", "lean": 0.15, "reach": 1.2},
	{"id": "cadena", "name": "Cadena Popular", "kind": "radio", "lean": 0.35, "reach": 1.0},
	{"id": "red", "name": "Red Ciudadana", "kind": "digital", "lean": -0.35, "reach": 0.7},
	{"id": "tertulia", "name": "La Tertulia de la Noche", "kind": "tv", "lean": 0.0, "reach": 1.1},
]

const TOPICS := {
	"housing": {"segs": {"jovenes": 1.0, "urbanos": 0.7, "obreros": 0.5, "mayores": 0.15, "autonomos": 0.2, "rurales": 0.1},
		"hooks": ["el alquiler ha subido un {n}% en las grandes ciudades en dos años", "{n} de cada 100 jóvenes menores de 30 años sigue viviendo con sus padres", "la lista de solicitantes de vivienda protegida supera ya los {n}.000", "los desahucios han repuntado un {n}% este trimestre"], "lo": 7, "hi": 34},
	"tax": {"segs": {"autonomos": 1.0, "urbanos": 0.6, "obreros": 0.5, "mayores": 0.4, "jovenes": 0.3, "rurales": 0.4},
		"hooks": ["los autónomos denuncian que pagan un {n}% más que hace cinco años", "la recaudación ha crecido un {n}% mientras los salarios apenas se mueven", "las clases medias sienten que cada año pagan más por lo mismo", "el déficit se sitúa en torno al {n}% del PIB"], "lo": 3, "hi": 19},
	"health": {"segs": {"mayores": 1.0, "rurales": 0.7, "obreros": 0.6, "urbanos": 0.5, "jovenes": 0.3, "autonomos": 0.2},
		"hooks": ["la lista de espera quirúrgica supera los {n} días de media", "{n} centros de salud rurales funcionan sin médico fijo", "los sanitarios han convocado movilizaciones por la saturación de las urgencias", "pedir cita en atención primaria tarda ya {n} días"], "lo": 8, "hi": 70},
	"education": {"segs": {"jovenes": 0.8, "urbanos": 0.6, "obreros": 0.5, "rurales": 0.4, "mayores": 0.2, "autonomos": 0.2},
		"hooks": ["las aulas superan los {n} alumnos por clase", "el abandono escolar sigue en el {n}%", "los docentes reclaman un pacto educativo estable", "las matrículas universitarias han subido un {n}%"], "lo": 8, "hi": 28},
	"jobs": {"segs": {"obreros": 1.0, "jovenes": 0.8, "autonomos": 0.6, "urbanos": 0.5, "rurales": 0.4, "mayores": 0.3},
		"hooks": ["el paro juvenil sigue por encima del {n}%", "un {n}% de los contratos nuevos es temporal", "los salarios han perdido poder adquisitivo frente a los precios", "hay sectores que no encuentran trabajadores mientras miles buscan empleo"], "lo": 14, "hi": 32},
	"energy": {"segs": {"jovenes": 0.7, "rurales": 0.7, "urbanos": 0.6, "autonomos": 0.5, "obreros": 0.5, "mayores": 0.3},
		"hooks": ["la factura de la luz ha subido un {n}% en un año", "se acumulan proyectos renovables paralizados en {n} comarcas", "la industria advierte de que la energía cara le resta competitividad", "los incendios y la sequía vuelven a poner el clima en la agenda"], "lo": 6, "hi": 31},
	"security": {"segs": {"mayores": 0.8, "urbanos": 0.6, "rurales": 0.6, "obreros": 0.5, "autonomos": 0.5, "jovenes": 0.3},
		"hooks": ["los robos en viviendas han aumentado un {n}% en el último año", "los sindicatos policiales denuncian falta de efectivos", "crece la percepción de inseguridad en los barrios periféricos", "la llegada de inmigrantes a las costas vuelve a tensar el debate"], "lo": 3, "hi": 16},
	"territory": {"segs": {"rurales": 0.7, "urbanos": 0.5, "mayores": 0.5, "jovenes": 0.4, "autonomos": 0.4, "obreros": 0.3},
		"hooks": ["la financiación autonómica sigue sin reformarse", "los gobiernos regionales reclaman más competencias", "el reparto de inversiones vuelve a enfrentar a comunidades", "la España vaciada reclama servicios básicos"], "lo": 2, "hi": 9},
}

const PLANS := {
	"housing": {
		"left": ["Una ley de vivienda que reserve suelo público y obligue a destinar parte de cada promoción a alquiler asequible.", "Hay que topar los alquileres en zonas tensionadas y construir vivienda pública a gran escala.", "Un gran parque público de alquiler asequible y sanciones a los pisos vacíos de grandes tenedores."],
		"right": ["Agilizar licencias y dar seguridad jurídica al propietario, para que salgan al mercado miles de viviendas hoy cerradas.", "Liberar suelo, simplificar licencias y dar seguridad a los propietarios: se construye más cuando se quita burocracia.", "Incentivos fiscales a quien alquile y colaboración con el sector privado para multiplicar la oferta."],
		"centre": ["Un pacto de Estado: más vivienda pública, suelo ágil y garantías tanto para propietarios como para inquilinos."]},
	"tax": {
		"left": ["Un IRPF más progresivo, un impuesto mínimo a las multinacionales y más medios contra la evasión.", "Quien más tiene más aporta: impuestos a las grandes fortunas y a la banca para sostener los servicios.", "Una fiscalidad progresiva y una lucha implacable contra el fraude para financiar lo público."],
		"right": ["Una rebaja general del IRPF y menos cotizaciones para autónomos y pymes: así se crea empleo y se recauda más.", "Bajar impuestos a familias, autónomos y empresas: el dinero rinde más en el bolsillo de la gente.", "Simplificar y reducir la carga fiscal para que crear empleo compense."],
		"centre": ["Una reforma fiscal gradual: aliviar a las clases medias sin renunciar a los servicios esenciales."]},
	"health": {
		"left": ["Un plan de refuerzo de plantillas con salarios dignos y atención primaria abierta por las tardes.", "Más inversión en sanidad pública, refuerzo de la primaria y fin de los conciertos que la debilitan.", "Blindar la sanidad pública con financiación estable y contratar a miles de profesionales."],
		"right": ["Reducir las listas con más productividad, concertando solo lo que ahorre tiempo al paciente y dinero al sistema.", "Mejorar la gestión y colaborar con el sector privado para reducir listas de espera sin disparar el gasto.", "Libertad de elección y gestión eficiente: pagar por resultados, no por burocracia."],
		"centre": ["Un plan de choque en atención primaria con financiación estable y evaluación pública de resultados."]},
	"education": {
		"left": ["Reducir las ratios, reforzar la FP y cubrir de forma pública los libros y el comedor.", "Educación pública gratuita y de calidad, con menos alumnos por aula y más docentes.", "Becas universales y un plan contra la segregación escolar."],
		"right": ["Más autonomía a los centros, evaluaciones que sirvan para mejorar y una FP vinculada a las empresas.", "Libertad de elección de centro, exigencia y evaluación para elevar el nivel.", "Autonomía a los centros, cultura del esfuerzo y reválidas que midan resultados."],
		"centre": ["Un pacto educativo que blinde la financiación, modernice el currículo y dé estabilidad a los docentes."]},
	"jobs": {
		"left": ["Reducción de jornada, subida del salario mínimo y más inspección contra los contratos abusivos.", "Subir el salario mínimo, limitar la temporalidad y reforzar la negociación colectiva.", "Reducir la jornada sin bajar salarios y perseguir los falsos autónomos."],
		"right": ["Un contrato más flexible, menos burocracia para contratar y ayudas a quien emprende.", "Flexibilidad y menos costes laborales para que las empresas contraten más.", "Menos cargas a quien emprende: el mejor plan de empleo es una empresa que crece."],
		"centre": ["Formación, incentivos a la contratación estable y diálogo social entre sindicatos y empresarios."]},
	"energy": {
		"left": ["Un gran plan de renovables y almacenamiento públicos y una tarifa social que proteja a los más vulnerables.", "Planificación pública de renovables y transición justa, protegiendo a los consumidores vulnerables.", "Una empresa energética pública que compita y abarate la factura."],
		"right": ["Más oferta de energía de todo tipo, simplificar la tramitación y bajar los impuestos que encarecen la factura.", "Neutralidad tecnológica: nuclear, gas y renovables compitiendo para bajar la factura sin dogmas.", "Menos trabas administrativas a la inversión energética y más competencia."],
		"centre": ["Un mix equilibrado, inversión en redes y ayudas dirigidas a quien más lo necesita."]},
	"security": {
		"left": ["Más policía de proximidad, más inversión social en los barrios y una lucha firme contra las mafias, no contra los vecinos.", "Más prevención, trabajo social y policía de proximidad, sin endurecer por endurecer.", "Reforzar la seguridad con inversión en barrios y garantías para los derechos de todos."],
		"right": ["Más agentes, mejores medios y penas más duras para los reincidentes.", "Más efectivos, más autoridad y penas firmes: la seguridad es la primera libertad.", "Mano firme con la reincidencia y respaldo sin fisuras a las fuerzas de seguridad."],
		"centre": ["Dotar mejor a los cuerpos de seguridad y reforzar la prevención en los barrios con más problemas."]},
	"territory": {
		"left": ["Una financiación autonómica transparente, que garantice los mismos servicios en cualquier territorio.", "Un Estado cooperativo y federal, con financiación justa y respeto a la diversidad.", "Reconocer la pluralidad territorial y blindar los servicios en toda España vaciada."],
		"right": ["Fortalecer la unidad: una sola ley para todos, sin privilegios entre territorios ni diferencias en derechos.", "Unidad y cohesión: la ley es igual para todos y los servicios no dependen de dónde se viva.", "Coordinación estatal fuerte y racionalización de duplicidades autonómicas."],
		"centre": ["Reformar la financiación autonómica con criterios objetivos y lealtad institucional."]},
}

const STYLE_TEXT := {
	"data": ["Los datos son claros y no voy a esconderlos: {issue} necesita medidas medibles, con calendario y evaluación independiente.", "Permítame ser concreto: objetivos trimestrales en {issue}, un responsable con nombre y cifras publicadas cada mes.", "He estudiado el asunto: lo que falla en {issue} es la ejecución, y eso se arregla con gestión y control.", "No le voy a dar un eslogan sino una hoja de ruta de {issue}, con costes y plazos."],
	"empathy": ["A las familias afectadas por {issue} les diría que las escucho, que sé lo que cuesta y que no las voy a dejar solas.", "Cuando hablo con la gente en la calle, {issue} es lo primero que sale. Lo vivo como ellos y por eso me comprometo.", "Detrás de cada cifra de {issue} hay una persona con nombre. Empezaría por escucharla.", "Entiendo la rabia. Yo también la he sentido con {issue}, y quiero convertirla en soluciones."],
	"honest": ["Sinceramente: no hay solución mágica en {issue}. Habrá cosas que no podremos hacer el primer año y prefiero decirlo ahora.", "Le doy una respuesta incómoda: parte del problema de {issue} no se arregla en una legislatura, y quien diga lo contrario le miente.", "No tengo todas las respuestas sobre {issue}, pero sí el compromiso de rectificar si me equivoco.", "Reconozco que en {issue} nadie lo ha hecho bien, tampoco los nuestros, y eso hay que corregirlo."],
	"deflect": ["Lo importante ahora es hablar de lo que preocupa a la gente, y eso va mucho más allá de {issue}.", "Esa pregunta mejor se la hace al Gobierno; nosotros presentaremos nuestro plan a su debido tiempo.", "Ya hemos explicado nuestra posición sobre {issue} muchas veces; no voy a entrar en el juego de los titulares.", "Me gustaría contestarle, pero creo que el debate de fondo es otro."],
	"attack": ["{rival} lleva años hablando de {issue} sin mover un dedo. Que no den lecciones.", "Es llamativo que lo pregunte cuando el responsable de este desastre en {issue} es {rival}.", "Cada vez que {rival} abre la boca sobre {issue} empeora el problema: su gestión es la prueba.", "Quienes han gobernado {issue} como {rival} no están en posición de exigirnos nada."],
	"humor": ["Si me dieran un euro por cada promesa vacía sobre {issue}, pagaba la deuda yo solo. Lo nuestro es otra cosa.", "Dicho así parece un examen sorpresa de {issue}. Por suerte, me lo sé.", "Prefiero tomármelo con humor: si {issue} se arreglara con tertulias, ya estaría resuelto.", "Con todo cariño: {issue} no se soluciona con un tuit ingenioso, aunque a más de uno le encantaría."],
	"hardline": ["No vamos a ceder en {issue}: es una línea roja y se lo digo a quien haga falta.", "En {issue} no hay negociación posible sobre lo esencial. O se hace así o no se hace.", "Quien quiera nuestro apoyo sabrá que {issue} no se toca. Lo digo claro.", "Hemos prometido algo en {issue} y lo vamos a cumplir, nos cueste lo que nos cueste."],
	"concede": ["Estoy dispuesto a sentarme con quien haga falta para avanzar en {issue}, incluso con quien piensa distinto.", "En {issue} los acuerdos amplios duran más. Tenderé la mano a {rival} si hay buena fe.", "No tengo la verdad absoluta sobre {issue}: escucharé propuestas de todos los grupos.", "Un pacto por {issue} vale más que una victoria parcial. Mi puerta está abierta."],
	"promise": ["Si gobernamos, en cien días habrá medidas concretas sobre {issue} y me podrán pedir cuentas.", "Me comprometo hoy aquí a que {issue} será nuestra prioridad número uno desde el primer día.", "Les doy mi palabra: {issue} mejorará de forma visible en esta legislatura.", "Aprobaremos un plan de choque en {issue} en el primer Consejo de Ministros."],
}

# Tipo de respuesta: etiqueta, atributo que la sostiene, calidad base, efectos con calidad = 1 (gain) y costes fijos (cost).
const ARCH := {
	"plan_left": {"label": "Plan de izquierdas", "stat": "oratoria", "base": 0.05, "gain": {"competence": 2.0, "strength": 1.0}, "trust": 1.0, "vis": 0.8, "mom": 0.4, "flavor": -0.7},
	"plan_right": {"label": "Plan de derechas", "stat": "oratoria", "base": 0.05, "gain": {"competence": 2.0, "strength": 1.0}, "trust": 1.0, "vis": 0.8, "mom": 0.4, "flavor": 0.7},
	"plan_centre": {"label": "Plan de consenso", "stat": "experiencia", "base": 0.0, "gain": {"competence": 1.6, "closeness": 1.4}, "trust": 1.2, "vis": 0.4, "mom": 0.2, "flavor": 0.0},
	"data": {"label": "Datos y gestión", "stat": "experiencia", "base": 0.1, "gain": {"competence": 3.0, "honesty": 0.8}, "trust": 1.4, "vis": 0.3, "mom": 0.1, "flavor": 0.0},
	"empathy": {"label": "Cercanía", "stat": "carisma", "base": 0.05, "gain": {"empathy": 3.2, "closeness": 1.2}, "trust": 1.0, "vis": 0.6, "mom": 0.3, "flavor": 0.0},
	"honest": {"label": "Franqueza", "stat": "honestidad", "base": 0.0, "gain": {"honesty": 3.5, "empathy": 0.8}, "trust": 2.0, "vis": 0.2, "mom": -0.1, "cost": {"strength": -0.7}, "flavor": 0.0},
	"deflect": {"label": "Esquivar", "stat": "experiencia", "base": -0.2, "gain": {"strength": 0.4}, "trust": -0.5, "vis": -0.4, "mom": -0.2, "cost": {"honesty": -1.5, "competence": -0.6}, "flavor": 0.0},
	"attack": {"label": "Atacar", "stat": "firmeza", "base": -0.05, "gain": {"strength": 2.8, "closeness": 1.4}, "trust": -0.5, "vis": 1.6, "mom": 0.7, "cost": {"empathy": -1.2}, "rel": -3.0, "flavor": 0.0},
	"humor": {"label": "Ironía", "stat": "carisma", "base": -0.1, "gain": {"empathy": 2.2, "strength": 1.4}, "trust": 0.0, "vis": 1.4, "mom": 0.5, "cost": {"competence": -0.8}, "var": 0.18, "flavor": 0.0},
	"hardline": {"label": "Línea roja", "stat": "firmeza", "base": 0.0, "gain": {"strength": 3.2, "closeness": 1.4}, "trust": 0.2, "vis": 0.9, "mom": 0.5, "cost": {"empathy": -0.8}, "rel": -1.6, "flavor": 0.0},
	"concede": {"label": "Tender la mano", "stat": "mano_izquierda", "base": 0.0, "gain": {"empathy": 1.6, "competence": 1.0, "honesty": 0.6}, "trust": 0.8, "vis": 0.1, "mom": 0.1, "cost": {"strength": -1.2}, "rel": 3.0, "flavor": 0.0},
	"promise": {"label": "Gran promesa", "stat": "carisma", "base": 0.05, "gain": {"empathy": 2.2, "strength": 1.5}, "trust": 0.6, "vis": 1.0, "mom": 0.6, "cost": {"honesty": -0.9}, "flavor": 0.0},
}

const KIND_ARCHS := {
	"policy": ["plan_left", "plan_right", "plan_centre", "data", "empathy", "promise", "honest", "deflect"],
	"cost": ["data", "honest", "promise", "deflect", "attack", "plan_left", "plan_right", "plan_centre"],
	"rival": ["attack", "data", "humor", "concede", "hardline", "honest"],
	"crisis": ["empathy", "data", "attack", "promise", "honest", "plan_centre", "deflect"],
	"ideology": ["data", "honest", "hardline", "plan_centre", "humor", "deflect", "plan_left", "plan_right"],
	"record": ["data", "honest", "attack", "deflect", "empathy", "promise", "plan_centre"],
	"control": ["data", "honest", "attack", "deflect", "empathy", "humor", "hardline"],
	"control_ask": ["attack", "data", "hardline", "humor", "empathy", "honest"],
	"human": ["honest", "empathy", "humor", "deflect", "hardline", "data"],
	"replica": ["attack", "humor", "concede", "deflect", "hardline"],
}

# Frases por tipo de pregunta con otro vocabulario (no usan los textos genéricos).
const SPECIAL := {
	"pact": {
		"concede": ["No descarto nada si el programa de {rival} sirve a la gente: gobernar es hablar con quien piensa distinto.", "Me sentaría con {rival} sin complejos, siempre que sus condiciones sean razonables."],
		"hardline": ["Con {rival}, ni una coalición ni un pacto de gobierno. Se lo digo con toda claridad.", "No vamos a pactar con {rival}: nuestros votantes nos han votado precisamente para eso."],
		"honest": ["Depende de las cifras y del programa. Prefiero no prometer lo que no sé si podré cumplir.", "Hablaré con todos, pero dentro de los límites de lo que defendemos. No daré cheques en blanco."],
		"attack": ["Más que con quién pacto yo, la pregunta es con quién pactó {rival} para llegar donde está.", "Que {rival} aclare primero con quién gobernó y a costa de qué; después hablamos de mí."],
		"deflect": ["Lo que importa ahora es ganar el apoyo de los españoles, no hacer cuentas de la lechera.", "Los pactos se hacen después de las elecciones; hoy toca pedir el voto."],
		"humor": ["Me pregunta por una boda cuando ni siquiera hemos empezado el noviazgo, ¿no cree?", "Si cada vez que me preguntan por un pacto me dieran un café, ya habría montado una cafetería."],
		"data": ["Los números mandan: sumaremos con quien nos dé una mayoría estable y un programa verificable.", "Haré cuentas: aritmética parlamentaria, programa y garantías. En ese orden."],
	},
	"scandal": {
		"honest": ["Asumo la responsabilidad política. Hemos fallado en este caso y se van a tomar medidas hoy mismo.", "Es un error grave y no voy a esconderlo: se abre una investigación interna y se colaborará con quien corresponda."],
		"deflect": ["Es un asunto aislado que ya está en manos de quien debe resolverlo. No voy a especular.", "Esperaré a que se aclaren los hechos antes de hacer ninguna valoración."],
		"attack": ["Me sorprende la sensibilidad de quienes callaron en casos mucho peores. Esto es una cortina de humo.", "Detrás de esta filtración hay intereses: me preocupa más quién la mueve que lo que dice."],
		"data": ["Hemos revisado los documentos: los hechos que se publican no coinciden con lo que consta en nuestras cuentas, y lo demostraremos.", "Pongo a su disposición la contabilidad completa: que cada uno saque sus conclusiones."],
		"empathy": ["Entiendo el enfado de la gente, y lo comparto. Quien ha defraudado esa confianza no tiene sitio con nosotros.", "A quienes confiaron en nosotros les debo una disculpa sin excusas."],
		"hardline": ["No vamos a tolerar nada parecido. Si hay culpables, se irán, sean quienes sean.", "Tolerancia cero: quien haya fallado, fuera. Sin discusión."],
	},
	"gotcha": {
		"honest": ["No me sé esa cifra de memoria y no voy a inventármela. Se la daré revisada en cuanto la compruebe.", "Reconozco que no la tengo presente; prefiero decirlo antes que improvisar."],
		"data": ["Se la doy exacta: {fact}.", "Sin necesidad de papeles: {fact}."],
		"humor": ["Si me lo hubieran dicho, habría traído una chuleta. Se lo confirmo mañana con la cifra buena.", "Vaya, un examen oral. Le prometo estudiar para la próxima; hoy me quedo con lo importante."],
		"deflect": ["Los detalles técnicos los tiene mi equipo; yo me ocupo de la visión de conjunto.", "No voy a entrar en una pregunta de concurso, hay asuntos más relevantes."],
		"attack": ["Es la pregunta típica de quien no tiene nada de fondo que discutir. Hablemos de política, no de trivial.", "Me parece una pregunta tramposa y poco útil para los ciudadanos."],
		"empathy": ["Quizá no recuerde esa cifra, pero sí sé cómo la viven las familias cada mes. Eso es lo que me importa.", "Las cifras importan menos que las personas que hay detrás."],
	},
	"flipflop": {
		"honest": ["Es verdad que dije eso. La situación ha cambiado y rectifico: prefiero cambiar de opinión que insistir en un error.", "Me equivoqué entonces y lo reconozco. Ahora tengo más datos."],
		"deflect": ["Se está sacando una frase de contexto; mi posición es coherente.", "No hay contradicción alguna; lo que cambia es la forma en que ustedes lo cuentan."],
		"attack": ["Me sorprende que me hable de hemeroteca quien ha cambiado más veces de postura que de corbata.", "Si vamos a repasar archivos, empiecen por los de quienes han gobernado."],
		"data": ["La contradicción es aparente: entonces hablaba de un escenario y hoy hablamos de otro, y le explico por qué.", "Los matices importan: aquí está la diferencia entre ambas posiciones."],
		"humor": ["Es el privilegio de cambiar de opinión: lo practicamos los que pensamos.", "Si por cambiar de opinión se pierde un partido, me retiro mañana mismo."],
		"hardline": ["Mi posición es la misma y no la voy a modificar. Lo que ven es el ruido de quienes quieren verme dudar.", "Nunca he dado un paso atrás en lo esencial."],
	},
}

const RIVAL_CLAIM := {
	"right": ["su programa es gasto sin control y acabará pagándolo la clase media", "hay que bajar impuestos y no inventar nuevos", "su propuesta es un salto al vacío económico", "su partido ha perdido el contacto con los problemas reales de la gente"],
	"left": ["su programa abandona a los trabajadores a su suerte", "solo defiende a quienes ya tienen de todo", "recortará servicios públicos en cuanto gobierne", "su política social es pura propaganda"],
	"centre": ["su partido no tiene un proyecto claro", "gobernar es algo más que dar buenos titulares", "sus promesas no están financiadas", "su propuesta es improvisación y nada más"],
}

const SCANDALS := [
	"un exconcejal de su partido aparece en una investigación por contratos",
	"un audio filtrado de un dirigente de su formación en el que habla con desprecio de sus votantes",
	"las cuentas de la última campaña, que según un medio no cuadran",
	"un asesor suyo que habría cobrado por un trabajo que no se aprecia",
	"un mensaje antiguo suyo en redes que ha vuelto a circular",
	"una donación de una empresa que ahora piensa participar en concursos públicos",
	"un dirigente territorial que habría usado el coche oficial para fines privados",
]
const CRISES := [
	{"txt": "una oleada de incendios forestales que arrasa varias comarcas", "issue": "energy"},
	{"txt": "una huelga de transporte que paraliza ciudades", "issue": "jobs"},
	{"txt": "un nuevo dato de inflación que ha disparado la cesta de la compra", "issue": "tax"},
	{"txt": "una sentencia que reabre el debate territorial", "issue": "territory"},
	{"txt": "un colapso de urgencias en varios hospitales", "issue": "health"},
	{"txt": "un episodio de violencia en un barrio que ha conmocionado a la opinión pública", "issue": "security"},
	{"txt": "el cierre de una fábrica con cientos de despidos", "issue": "jobs"},
	{"txt": "una ola de calor que dispara la factura eléctrica", "issue": "energy"},
	{"txt": "el desplome de la matrícula en la escuela rural", "issue": "education"},
	{"txt": "una nueva subida de los precios del alquiler", "issue": "housing"},
]
const HUMAN_QS := [
	["¿Qué le hace levantarse cada mañana para dedicarse a esto?", "mot"],
	["¿Cuál ha sido el peor momento de su carrera y qué aprendió?", "past"],
	["¿Qué defecto suyo temen más sus colaboradores?", "self"],
	["¿Quién es la persona que mejor le conoce?", "home"],
	["¿Qué libro o disco ha vuelto a leer o escuchar más veces?", "taste"],
	["¿Qué le diría hoy al chaval o la chavala que fue usted a los 18?", "past"],
]
const FRAMES := {
	"hostile": ["Con todo respeto, pero la gente está harta: ", "Voy a ser claro: ", "Seamos serios, ", "No me conteste con lo de siempre: ", "Se lo pregunto sin rodeos: "],
	"neutral": ["Una cuestión que preocupa a los espectadores: ", "Nos llegan muchas preguntas sobre esto: ", "Veamos: ", "Una pregunta que nos hacen mucho: ", "Vamos con un asunto de actualidad: "],
	"friendly": ["Le doy la oportunidad de explicar algo: ", "Sé que es un tema que le importa: ", "Para que lo cuente con sus palabras: ", "Es un asunto en el que su partido tiene propuestas: ", "Aprovecho para preguntarle: "],
}
const ASKS := ["¿Qué piensa hacer usted?", "¿Cuál es su respuesta?", "¿Qué le dice a quienes lo sufren?", "¿Tiene alguna solución concreta?", "¿Qué compromiso asume hoy?", "¿Cómo lo va a resolver?"]
const COST_ASKS := ["¿De dónde sale el dinero?", "¿Con qué recursos lo piensa pagar?", "¿Quién lo paga, al final?", "¿Cuánto cuesta y cómo lo financia?"]
const REBUT := ["¿Qué responde?", "¿Cómo contesta a esa acusación?", "¿Es así de grave?", "¿Tiene algo que decir al respecto?"]

const REACT := {
	"great": {
		"hostile": ["Vaya, no esperaba una respuesta tan sólida.", "Tengo que reconocer que ha sabido salir del paso con solvencia.", "No era la respuesta que esperaba, pero es difícil rebatirla."],
		"neutral": ["Una respuesta clara; el público lo agradece.", "Muy claro. Es de las contestaciones que se recuerdan.", "Bien explicado, sin duda."],
		"friendly": ["Exacto, justo lo que mucha gente quería oír.", "Eso era lo que queríamos que explicara. Gracias.", "Una gran respuesta, y se nota que conoce el asunto."]},
	"good": {
		"hostile": ["Hmm, algo es algo. Pero seguiré insistiendo.", "Aceptable, aunque no cierra la cuestión.", "Puede ser, aunque hay quien no lo verá así."],
		"neutral": ["Entendido. Pasamos a otra cuestión.", "Respuesta correcta; veremos cómo se concreta.", "Es una postura clara, al menos."],
		"friendly": ["Muy bien, creo que se ha entendido.", "Perfecto, así se entiende mejor su posición.", "Gracias por la claridad."]},
	"weak": {
		"hostile": ["¿Eso es todo? No ha respondido a lo que le pregunté.", "Perdone, pero esa respuesta no convence a nadie.", "Eso suena a lo de siempre."],
		"neutral": ["Una respuesta algo vaga, si me permite.", "Puede que se quede corto, pero sigamos.", "No me queda del todo claro, pero adelante."],
		"friendly": ["Quizá podría haberlo explicado mejor.", "Creo que ahí le faltó un poco de contundencia.", "Sigamos, pero eso podría pulirse."]},
	"bad": {
		"hostile": ["Esto va a salir mañana en todos los periódicos, y no precisamente bien.", "Vaya, acaba de abrir un frente que no tenía.", "Creo que no era consciente de lo que acaba de decir."],
		"neutral": ["Eso va a dar mucho que hablar.", "Puede que esa respuesta le acompañe unos días.", "No parece que esa respuesta le haya favorecido."],
		"friendly": ["Vaya, eso no ha salido como esperábamos.", "Lo lamento, pero esa respuesta no ayuda.", "Creo que no es lo que quería decir."]},
}

const HEAD_GOOD := ["{L} se crece ante {O}: {T}, su mejor momento", "Aplomo de {L} al hablar de {T}", "{L} convence con su respuesta sobre {T}", "Buen paso de {L} por {O}: {T} deja de ser un flanco", "{L} cierra una buena noche con {T}"]
const HEAD_BAD := ["{L} tropieza con {T} en {O}", "Titubeos de {L}: la respuesta sobre {T} abre un flanco", "{L} esquiva {T} y la hemeroteca se lo recuerda", "Polémica: lo que dijo {L} sobre {T}", "Mal rato de {L} en {O} al hablar de {T}"]
const HEAD_MIX := ["{L} pasa por {O} sin grandes sobresaltos", "Una intervención de {L} más correcta que memorable", "{L} deja titulares sobre {T} sin cerrar el debate", "Balance gris para {L} en {O}"]

var _fact_pool := ["inflación", "paro", "déficit", "salario mínimo"]

func _init(model: GameModel) -> void:
	m = model

# ---------------------------------------------------------------- estado
func st() -> Dictionary:
	var e := m.d("enc")
	if not e.has("image"):
		e["image"] = {"competence": 50.0, "honesty": 50.0, "empathy": 50.0, "strength": 50.0, "closeness": 50.0}
		e["seg"] = {}
		for k in SEGMENTS.keys():
			(e["seg"] as Dictionary)[k] = 50.0
		e["seen"] = {}
		e["recent_topics"] = []
		e["stances"] = {}
		e["hemeroteca"] = []
		e["said"] = {}
		e["grudges"] = []
		e["count"] = 0
		e["last_press_day"] = 0
	return e

func image() -> Dictionary:
	return st()["image"]

func seg() -> Dictionary:
	return st()["seg"]

func image_avg() -> float:
	var t := 0.0
	var im := image()
	for k in IMAGE_DIMS.keys():
		t += float(im.get(k, 50.0))
	return t / float(IMAGE_DIMS.size())

func hemeroteca() -> Array:
	return st()["hemeroteca"]

func _bump_image(dim: String, delta: float) -> void:
	var im := image()
	im[dim] = clampf(float(im.get(dim, 50.0)) + delta, 0.0, 100.0)

func _bump_seg(id: String, delta: float) -> void:
	var sg := seg()
	sg[id] = clampf(float(sg.get(id, 50.0)) + delta, 0.0, 100.0)

## Elige un elemento evitando repetir los usados con esa clave hasta agotar el repertorio.
func pick(pool: Array, key: String) -> Variant:
	var seen: Dictionary = st()["seen"]
	var used: Array = seen.get(key, [])
	var free: Array = []
	for i in range(pool.size()):
		var taken := false
		for u in used:
			if int(u) == i:
				taken = true
				break
		if not taken:
			free.append(i)
	if free.is_empty():
		used = []
		for i in range(pool.size()):
			free.append(i)
	var idx: int = int(free[m.rng.randi_range(0, free.size() - 1)])
	used.append(idx)
	seen[key] = used
	return pool[idx]

## Elige un texto de la lista sin repetir los ya usados (se recuerdan por contenido, no por posición,
## así que el banco puede crecer entre versiones sin descuadrar las partidas guardadas).
func pick_h(key: String, texts: Array) -> String:
	if texts.is_empty():
		return ""
	var seen: Dictionary = st().get("seen_h", {})
	st()["seen_h"] = seen
	var used: Array = seen.get(key, [])
	var free: Array = []
	for t in texts:
		if not used.has(hash(str(t))):
			free.append(str(t))
	if free.is_empty():
		used = []
		for t2 in texts:
			free.append(str(t2))
	var choice: String = str(free[m.rng.randi_range(0, free.size() - 1)])
	used.append(hash(choice))
	while used.size() > 400:
		used.pop_front()
	seen[key] = used
	return choice

func _role_tag() -> String:
	var r := m.role()
	if r == "government" or r == "partner":
		return "g"
	if r == "opposition":
		return "o"
	return ""

func _times(key: String) -> int:
	return int((st()["seen"] as Dictionary).get("n:" + key, 0))

func _count(key: String) -> void:
	var seen: Dictionary = st()["seen"]
	seen["n:" + key] = int(seen.get("n:" + key, 0)) + 1

const ISSUE_PHRASE := {"housing": "la vivienda", "tax": "la fiscalidad", "health": "la sanidad", "education": "la educación", "jobs": "el empleo", "energy": "la transición energética", "security": "la seguridad", "territory": "el modelo territorial"}

## El tema con su artículo («la vivienda», «el empleo y los salarios»), para que las frases suenen naturales.
func _issue_l(issue: String) -> String:
	return str(ISSUE_PHRASE.get(issue, Rules.issue_name(issue).to_lower()))

## Contracciones («de el» → «del», «a el» → «al») tras rellenar los huecos de un texto.
func _fixup(t: String) -> String:
	var out := t.replace(" de el ", " del ").replace(" a el ", " al ").replace("¿de el ", "¿del ").replace("¿a el ", "¿al ")
	if out.begins_with("de el "):
		out = "del " + out.substr(6)
	if out.begins_with("De el "):
		out = "Del " + out.substr(6)
	return out

func _player_econ() -> float:
	return float((m.party.get("ideology", {}) as Dictionary).get("economic", 0.0))

func _player_bloc() -> float:
	return Ideology.bloc_score(m.party.get("ideology", {}))

func _party_bloc(id: String) -> float:
	return Ideology.bloc_score(m.party_by_id(id).get("ideology", {}))

# ---------------------------------------------------------------- piezas
func main_rival() -> String:
	var gov := str(m.s.get("government_party_id", ""))
	if gov != "" and not m.is_player(gov) and m.phase == "legislature":
		return gov
	var best := ""
	var best_v := -1.0
	for r in m.rivals:
		var rid := str((r as Dictionary).get("id", ""))
		if rid == "" or rid == Rules.OTHERS_ID:
			continue
		var v := m.poll_of(rid)
		# Prefiere rivales ideológicamente opuestos: son los que atacan de verdad.
		if _party_bloc(rid) * _player_bloc() < 0.0:
			v *= 1.4
		if v > best_v:
			best_v = v
			best = rid
	return best

var _last_outlet_name := ""

func _outlet_for(ev_type: String) -> Dictionary:
	var o := _outlet_pick(ev_type)
	_last_outlet_name = str(o["name"])
	return o

func _outlet_pick(ev_type: String) -> Dictionary:
	if ev_type == "Podcast":
		var pc: Array = []
		for o2 in OUTLETS_EXTRA:
			if str((o2 as Dictionary)["kind"]) == "podcast":
				pc.append(o2)
		return pick(pc, "outlet_pod") as Dictionary
	if ev_type == "Sesión de control":
		return OUTLETS_EXTRA[OUTLETS_EXTRA.size() - 1] as Dictionary
	var pool: Array = []
	for o in OUTLETS:
		var od: Dictionary = o
		if ev_type == "Debate" and str(od["kind"]) != "tv":
			continue
		if ev_type == "Rueda de prensa" and str(od["kind"]) == "tv" and m.rng.randf() < 0.4:
			continue
		pool.append(od)
	if pool.is_empty():
		pool = OUTLETS
	return pick(pool, "outlet") as Dictionary

func _journalist(outlet: Dictionary) -> Dictionary:
	var fem := m.rng.randf() < 0.5
	var first: String = str(pick(Leader.FEMALE if fem else Leader.MALE, "jn_first"))
	var last: String = str(pick(Leader.SURNAME, "jn_last"))
	var gap := float(outlet["lean"]) - _player_bloc()
	var opposed := maxf(0.0, absf(gap) - 0.35)
	var p_host := clampf(0.22 + opposed * 0.9, 0.1, 0.75)
	var p_friend := clampf(0.22 + maxf(0.0, 0.5 - absf(gap)) * 0.5, 0.05, 0.5)
	var r := m.rng.randf()
	var mood := "hostile" if r < p_host else ("friendly" if r < p_host + p_friend else "neutral")
	return {"name": "%s %s" % [first, last], "fem": fem, "mood": mood}

func _hook(topic: String) -> String:
	var t: Dictionary = TOPICS[topic]
	var h: String = str(pick(t["hooks"], "hook:" + topic))
	return h.replace("{n}", str(m.rng.randi_range(int(t["lo"]), int(t["hi"]))))

func _choose_topic() -> String:
	var recent: Array = st()["recent_topics"]
	var hot: Array = m.campaign.top_issues(3) if m.phase == "campaign" else []
	var prog: Dictionary = m.campaign.program()
	var ids: Array = []
	var ws: Array = []
	for k in TOPICS.keys():
		if recent.has(k):
			continue
		var w := 1.0
		if hot.has(k):
			w += 1.5
		if prog.has(k):
			w += 1.0
		w /= (1.0 + 1.6 * float(_times("topic:" + str(k))))
		ids.append(k)
		ws.append(w)
	if ids.is_empty():
		recent.clear()
		return str(TOPICS.keys()[0])
	var tot := 0.0
	for w2 in ws:
		tot += float(w2)
	var roll := m.rng.randf() * tot
	for i in range(ids.size()):
		roll -= float(ws[i])
		if roll <= 0.0:
			return str(ids[i])
	return str(ids[ids.size() - 1])

func _note_topic(topic: String) -> void:
	var recent: Array = st()["recent_topics"]
	recent.append(topic)
	while recent.size() > 3:
		recent.pop_front()
	_count("topic:" + topic)

# ---------------------------------------------------------------- preguntas
func _frame(mood: String) -> String:
	return str(pick(FRAMES[mood], "frame:" + mood))

## Ideología principal del jugador en minúsculas; si no ha elegido ninguna, la que sugiere su posición económica.
func _ideo_name() -> String:
	var picks: Array = m.party.get("ideology_picks", [])
	if not picks.is_empty():
		return Ideology.name_of(str((picks[0] as Dictionary)["id"])).to_lower()
	var econ := _player_econ()
	return "progresismo" if econ < -0.2 else ("conservadurismo" if econ > 0.2 else "centrismo")

func _db_vars(topic: String, rival_id: String) -> Dictionary:
	var rl := m.leader_of(rival_id) if rival_id != "" else {}
	var leader := Leader.full_name(rl) if not rl.is_empty() else "el líder rival"
	var ideo := _ideo_name()
	return {
		"issue": _issue_l(topic) if topic != "" else "la actualidad",
		"rival": m.party_short(rival_id) if rival_id != "" else "el Gobierno",
		"leader": leader, "me": str(m.party.get("short_name", "su partido")), "n": m.rng.randi_range(6, 28),
		"ideo": ideo, "approval": "%.0f" % m.gov.approval(), "stability": "%.0f" % m.gov.stability(),
		"gov_month": maxi(m.gov_month, 1), "deficit": "%.1f" % (absf(m.eco.balance_pct()) if m.eco.ready_state() else 3.0), "debt": "%.0f" % (m.eco.debt_pct() if m.eco.ready_state() else 100.0),
		"laws": m.eco.passed_laws().size() if m.eco.ready_state() else 0,
	}

var _q_sub := ""     ## subtipo de la última pregunta sacada de la base de datos (ver MediaDB.parse)

## Intenta generar el texto de la pregunta desde la base de datos de medios. Devuelve "" si no hay banco aplicable.
## Deja el subtipo elegido en `_q_sub` para que las respuestas encajen con la pregunta.
func _db_text(kind: String, topic: String, mood: String, rival_id: String, fmt: String, extra: Dictionary = {}) -> String:
	_q_sub = ""
	var bank := MediaDB.questions_tagged(kind, topic, fmt, _role_tag())
	if bank.is_empty():
		return ""
	var texts: Array = []
	for e in bank:
		texts.append(str((e as Dictionary)["t"]))
	var raw := pick_h("q:%s:%s" % [kind, topic if kind in ["policy"] else ""], texts)
	for e2 in bank:
		if str((e2 as Dictionary)["t"]) == raw:
			_q_sub = str((e2 as Dictionary)["s"])
			break
	var vars := _db_vars(topic, rival_id)
	for k in extra.keys():
		vars[k] = extra[k]
	var out := MediaDB.fill(raw, vars)
	out = _fixup(out)
	var framed := fmt != "podcast" and fmt != "control" and kind in ["policy", "cost", "rival", "pact", "ideology", "crisis"] and out.begins_with("¿") and m.rng.randf() < 0.45
	if framed:
		var second := out.substr(1, 1)
		var third := out.substr(2, 1)
		if third != "" and third == third.to_lower():
			second = second.to_lower()
		return _frame(mood) + out.substr(0, 1) + second + out.substr(2)
	return _cap_first(out)

func _make_q(kind: String, topic: String, mood: String, rival_id: String, fmt: String = "tv") -> Dictionary:
	var q := {"kind": kind, "topic": topic, "issue": topic, "mood": mood, "rival": rival_id, "text": "", "answers": [], "format": fmt}
	var issue_l := _issue_l(topic)
	var rname := m.party_short(rival_id) if rival_id != "" else "el Gobierno"
	var use_db := true
	_q_sub = ""
	match kind:
		"record":
			q["issue"] = ""
			q["text"] = _db_text("record", topic, mood, rival_id, fmt)
			if str(q["text"]) == "":
				if m.role() == "opposition":
					q["text"] = "El Gobierno presume de un %.0f%% de apoyo. ¿Qué haría usted distinto desde la oposición?" % m.gov.approval()
					_q_sub = "alt"
				else:
					q["text"] = "El apoyo al Gobierno ronda el %.0f%%. ¿Es un respaldo suficiente para gobernar?" % m.gov.approval()
					_q_sub = "apoyo"
		"control":
			var facts: Array = MediaDB.control_facts(topic)
			var fact := str(pick_h("cfact:" + topic, facts)) if not facts.is_empty() else "la situación de %s empeora" % issue_l
			q["text"] = _db_text("control_ask" if m.role() == "opposition" else "control", topic, mood, rival_id, fmt, {"controlfact": fact})
		"replica":
			q["issue"] = ""
			q["topic"] = ""
			var line := str(pick_h("rivalline", MediaDB.rival_lines()))
			q["rivalline"] = line
			q["text"] = _db_text("replica", "", mood, rival_id, fmt, {"rivalline": line})
			if str(q["text"]) == "":
				q["text"] = "Le interrumpen: «%s». ¿Qué responde?" % line
	if str(q["text"]) != "":
		q["sub"] = _q_sub
		q["answers"] = _make_answers(q)
		return q
	match kind:
		"policy":
			var dbp := _db_text("policy", topic, mood, rival_id, fmt, {"hook": _hook(topic)}) if use_db else ""
			q["text"] = dbp if dbp != "" else "%s%s. %s" % [_frame(mood), _cap_first(_hook(topic)), pick(ASKS, "asks")]
		"cost":
			var prog: Dictionary = m.campaign.program()
			var item_name := ""
			for pol in Rules.POLICIES:
				if str((pol as Dictionary)["id"]) == topic and prog.has(topic):
					item_name = str((pol as Dictionary)["name"]).to_lower()
			var dbc := _db_text("cost", topic, mood, rival_id, fmt) if (use_db and item_name == "") else ""
			if dbc != "":
				q["text"] = dbc
			elif item_name != "":
				q["text"] = "%sSu programa incluye «%s». %s" % [_frame(mood), item_name, pick(COST_ASKS, "cost")]
			else:
				q["text"] = "%sUsted promete mejoras en %s, pero %s. %s" % [_frame(mood), issue_l, _hook(topic), pick(COST_ASKS, "cost")]
		"rival":
			var dbr := _db_text("rival", topic, mood, rival_id, fmt) if use_db else ""
			var bloc := _party_bloc(rival_id)
			var key := "right" if bloc > 0.25 else ("left" if bloc < -0.25 else "centre")
			var claim: String = str(pick(RIVAL_CLAIM[key], "claim:" + key))
			var lead := "%s afirma que %s" % [rname, claim]
			q["text"] = dbr if dbr != "" else "%s%s. %s" % [_frame(mood), lead, pick(REBUT, "rebut")]
		"pact":
			var target := _pact_target()
			q["rival"] = target
			q["issue"] = ""
			var tn := m.party_short(target)
			var dbpa := _db_text("pact", "", mood, target, fmt) if use_db else ""
			var opts := [
				"%s¿Gobernaría usted con %s?" % [_frame(mood), tn],
				"%s¿Descarta un pacto con %s después de las elecciones?" % [_frame(mood), tn],
				"%sSus votantes quieren saber si facilitaría un Gobierno con %s." % [_frame(mood), tn],
				"%s¿Daría sus votos a %s para gobernar?" % [_frame(mood), tn],
			]
			q["text"] = dbpa if dbpa != "" else str(pick(opts, "pactq"))
		"scandal":
			var sc: String = pick_h("scandal", SCANDALS + MediaDB.scandals())
			q["issue"] = ""
			var dbs := _db_text("scandal", "", mood, rival_id, fmt, {"scandal": sc}) if use_db else ""
			q["text"] = dbs if dbs != "" else "%sSe ha publicado que %s. %s" % [_frame(mood), sc, pick(REBUT, "rebut")]
		"human":
			q["issue"] = ""
			var dbh := _db_text("human", "", mood, rival_id, fmt) if use_db else ""
			if dbh != "":
				q["text"] = dbh
			else:
				var hq: Array = pick(HUMAN_QS, "humanq")
				q["text"] = "%s%s" % [_frame(mood), str(hq[0])]
				_q_sub = str(hq[1])
		"crisis":
			var cr_pool: Array = CRISES.duplicate()
			cr_pool.append_array(MediaDB.crises())
			var cr_texts: Array = []
			for cc in cr_pool:
				cr_texts.append("%s|%s" % [str((cc as Dictionary)["issue"]), str((cc as Dictionary)["txt"])])
			var cr_pick := pick_h("crisis", cr_texts)
			q["issue"] = cr_pick.get_slice("|", 0)
			q["topic"] = q["issue"]
			var cr_txt := cr_pick.get_slice("|", 1)
			var dbcr := _db_text("crisis", str(q["issue"]), mood, rival_id, fmt, {"crisis": cr_txt}) if use_db else ""
			q["text"] = dbcr if dbcr != "" else "%sEsta semana hemos asistido a %s. %s" % [_frame(mood), cr_txt, pick(ASKS, "asks")]
		"gotcha":
			var facts := _gotcha_fact()
			q["issue"] = ""
			q["fact"] = facts["fact"]
			q["text"] = "%s%s" % [_frame(mood), str(facts["q"])]
		"ideology":
			q["issue"] = ""
			var main := _ideo_name()
			var dbi := _db_text("ideology", "", mood, rival_id, fmt) if use_db else ""
			var opts2 := [
				"Su partido presume de ideología: %s. ¿Qué significa, en concreto, para un ciudadano de a pie?" % main,
				"¿Hasta dónde está dispuesto a llevar su ideología (%s) cuando gobierne?" % main,
				"Dicen que lo suyo, %s, es puro marketing. ¿Qué responde?" % main,
				"Entre su discurso (%s) y la realidad hay distancia. ¿Cómo la explica?" % main,
			]
			q["text"] = dbi if dbi != "" else "%s%s" % [_frame(mood), pick(opts2, "ideoq")]
		"flipflop":
			var f := _flipflop_candidate()
			q["issue"] = str(f["issue"])
			q["topic"] = str(f["issue"])
			var dbf := _db_text("flipflop", str(f["issue"]), mood, rival_id, fmt, {"outlet": str(f["outlet"]), "quote": str(f["quote"])}) if use_db else ""
			q["text"] = dbf if dbf != "" else "%sHace unos días dijo en %s: «%s». Hoy parece defender lo contrario sobre %s. %s" % [_frame(mood), str(f["outlet"]), str(f["quote"]), issue_l, pick(REBUT, "rebut")]
	q["sub"] = _q_sub
	q["answers"] = _make_answers(q)
	return q

func _cap_first(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)

func _pact_target() -> String:
	var cands: Array = []
	for r in m.rivals:
		var rid := str((r as Dictionary).get("id", ""))
		if rid == "" or rid == Rules.OTHERS_ID or Rules.REGIONALIST_TERRITORY.has(rid) and m.rng.randf() < 0.5:
			continue
		cands.append(rid)
	if cands.is_empty():
		return main_rival()
	return str(pick(cands, "pact_target"))

func _gotcha_fact() -> Dictionary:
	var prog: Dictionary = m.campaign.program()
	var options := [
		{"q": "¿Cuántas medidas concretas tiene su programa?", "fact": "mi programa recoge %d %s" % [maxi(m.manifesto.count(), 1), "compromiso concreto" if m.manifesto.count() <= 1 else "compromisos concretos"]},
		{"q": "¿Cuánto dinero tiene hoy el partido en caja?", "fact": "el partido cuenta hoy con %s €" % Rules.money(m.funds)},
		{"q": "¿En qué puesto de las encuestas está su formación esta semana?", "fact": "estamos en torno al %.1f%% de intención de voto" % m.player_poll()},
		{"q": "¿Cuántos días de campaña llevamos?", "fact": "llevamos %d %s de campaña" % [maxi(m.day, 1), "día" if m.day <= 1 else "días"]},
	]
	if m.phase != "campaign":
		options = [
			{"q": "¿Qué porcentaje de apoyo le dan hoy las encuestas?", "fact": "las encuestas nos dan en torno al %.1f%%" % m.player_poll()},
			{"q": "¿Cuánto dinero tiene hoy el partido en caja?", "fact": "el partido cuenta hoy con %s" % Rules.money(m.funds)},
		]
	return pick(options, "gotcha") as Dictionary

func _flipflop_candidate() -> Dictionary:
	var stances: Dictionary = st()["stances"]
	for k in stances.keys():
		var s: Dictionary = stances[k]
		if bool(s.get("contradicted", false)):
			return {"issue": str(k), "quote": str(s.get("text", "")), "outlet": str(s.get("outlet", "una entrevista"))}
	return {"issue": "jobs", "quote": "ya lo veremos", "outlet": "una entrevista"}

func _has_flipflop() -> bool:
	var stances: Dictionary = st()["stances"]
	for k in stances.keys():
		if bool((stances[k] as Dictionary).get("contradicted", false)) and not bool((stances[k] as Dictionary).get("asked", false)):
			return true
	return false

## Tipo de banco de respuestas que le toca a una pregunta (en la sesión de control, la oposición pregunta y el Gobierno responde).
func _bank_kind(q: Dictionary) -> String:
	var kind := str(q["kind"])
	if kind == "control" and m.role() == "opposition":
		return "control_ask"
	return kind

## ¿Esta pregunta tiene respuestas escritas a propósito (bancos por tipo y subtipo)? Si no, se usan las genéricas.
func _is_banked(kind: String) -> bool:
	return SPECIAL.has(kind) or MediaDB.has_kind_bank(kind)

## Textos posibles de una respuesta a esta pregunta: solo los que encajan con su tipo, subtipo, formato y papel.
func _bank_texts(q: Dictionary, arch: String) -> Array:
	var kind := _bank_kind(q)
	var sub := str(q.get("sub", ""))
	var out: Array = []
	if SPECIAL.has(kind) and sub == "" and (SPECIAL[kind] as Dictionary).has(arch):
		out.append_array((SPECIAL[kind] as Dictionary)[arch] as Array)
	out.append_array(MediaDB.kind_answers(kind, arch, sub, str(q.get("format", "tv")), _role_tag()))
	return out

## ¿Puede ofrecerse este estilo de respuesta a esta pregunta con un texto que venga a cuento?
func _arch_ok(q: Dictionary, arch: String) -> bool:
	var kind := _bank_kind(q)
	if _is_banked(kind):
		return not _bank_texts(q, arch).is_empty()
	if arch.begins_with("plan_"):
		return PLANS.has(str(q["topic"]))
	return true

func _make_answers(q: Dictionary) -> Array:
	var kind := _bank_kind(q)
	var topic := str(q["topic"])
	var pool: Array = []
	if KIND_ARCHS.has(kind):
		pool = (KIND_ARCHS[kind] as Array).duplicate()
	elif SPECIAL.has(kind):
		pool = (SPECIAL[kind] as Dictionary).keys()
	if _is_banked(kind):
		# Los bancos por tipo pueden aportar estilos que la lista base no incluye.
		for ar in (ARCH.keys()):
			if not pool.has(ar) and kind in ["pact", "scandal", "gotcha", "flipflop"] and not _bank_texts(q, str(ar)).is_empty():
				pool.append(ar)
	pool = pool.filter(func(a: Variant) -> bool: return _arch_ok(q, str(a)))
	# Nunca ofrecer los tres planes: dos a lo sumo, y uno cerca de la ideología del jugador.
	pool.shuffle()
	var chosen: Array = []
	var flav := 0
	if kind == "replica":
		chosen = ["attack", "humor", "concede", "deflect", "hardline"]
		chosen.shuffle()
		chosen = chosen.slice(0, 3)
		pool = []
	if kind in ["policy", "cost", "ideology", "crisis", "record", "control"] and (TOPICS.has(topic) or _is_banked(kind)):
		var aligned := "plan_left" if _player_econ() < -0.2 else ("plan_right" if _player_econ() > 0.2 else "plan_centre")
		if pool.has(aligned) and m.rng.randf() < 0.75:
			chosen.append(aligned)
			flav = 1
	for a in pool:
		if chosen.size() >= (4 if kind != "replica" else 3):
			break
		if chosen.has(a):
			continue
		if str(a).begins_with("plan_"):
			if flav >= 2:
				continue
			flav += 1
		chosen.append(a)
	var out: Array = []
	for a2 in chosen:
		out.append(_make_answer(q, str(a2)))
	out.shuffle()
	return out

## Variables que pueden aparecer en los textos de las respuestas.
func _answer_vars(q: Dictionary) -> Dictionary:
	var topic := str(q["topic"])
	var rival_id := str(q.get("rival", ""))
	var vars := _db_vars(topic, rival_id)
	vars["issue"] = _issue_l(topic if topic != "" else "jobs")
	vars["fact"] = str(q.get("fact", ""))
	vars["rival"] = m.party_short(rival_id) if rival_id != "" else "el Gobierno"
	return vars

func _make_answer(q: Dictionary, arch: String) -> Dictionary:
	var kind := _bank_kind(q)
	var topic := str(q["topic"])
	var rival_id := str(q.get("rival", ""))
	var rname := m.party_short(rival_id) if rival_id != "" else "el Gobierno"
	var text := ""
	var fmt := str(q.get("format", "tv"))
	if kind == "replica":
		text = pick_h("rep:" + arch, MediaDB.replica_answers(arch))
		if text == "":
			text = str(pick(STYLE_TEXT[arch], "style:" + arch))
		text = text.replace("{issue}", _issue_l("jobs")).replace("{rival}", rname)
	elif _is_banked(kind):
		var bank := _bank_texts(q, arch)
		text = MediaDB.fill(pick_h("ans:%s:%s:%s" % [kind, str(q.get("sub", "")), arch], bank), _answer_vars(q))
	elif arch.begins_with("plan_"):
		var flavor := arch.substr(5)
		var bank2: Array = (PLANS[topic] as Dictionary)[flavor]
		text = str(pick(bank2, "plan:%s:%s" % [topic, flavor]))
	else:
		var style_pool: Array = (STYLE_TEXT[arch] as Array).duplicate()
		style_pool.append_array(MediaDB.answers(arch, fmt))
		text = pick_h("style:" + arch, style_pool).replace("{issue}", _issue_l(topic if topic != "" else "jobs")).replace("{rival}", rname)
	text = _fixup(text)
	var a: Dictionary = ARCH[arch]
	var target := rival_id if (float(a.get("rel", 0.0)) != 0.0 or kind == "pact") else ""
	var stat_id := str(a["stat"])
	var stat_name := "—"
	for sd in Leader.STATS:
		if str((sd as Dictionary)["id"]) == stat_id:
			stat_name = str((sd as Dictionary)["name"])
	return {"arch": arch, "text": text, "tag": str(a["label"]), "stat": stat_id, "stat_name": stat_name, "target": target}

# ---------------------------------------------------------------- sesiones
func build_session(ev: Dictionary) -> Dictionary:
	var type_name := str(ev.get("type", "Entrevista"))
	var outlet := _outlet_for(type_name)
	var host := _journalist(outlet)
	var rival := main_rival()
	var fmt := MediaDB.format_of(type_name, str(outlet["kind"]))
	var fdef: Dictionary = MediaDB.FORMATS[fmt]
	var n := int(fdef["n"])
	var weights := {"policy": 3.0, "cost": 2.0, "rival": 1.0, "pact": 1.4, "scandal": 0.8, "human": 0.9, "crisis": 1.6, "gotcha": 0.6, "ideology": 1.0}
	match fmt:
		"debate":
			weights = {"rival": 3.2, "policy": 2.2, "cost": 1.6, "pact": 1.4, "ideology": 1.0, "scandal": 0.6, "crisis": 1.0, "gotcha": 0.4, "human": 0.2}
		"press":
			weights = {"crisis": 2.6, "scandal": 2.0, "policy": 1.6, "pact": 1.4, "cost": 1.2, "rival": 1.0, "gotcha": 0.8, "human": 0.2, "ideology": 0.6}
		"podcast":
			weights = {"human": 3.0, "ideology": 1.8, "policy": 1.6, "pact": 1.0, "rival": 1.0, "crisis": 0.8, "cost": 0.6, "scandal": 0.4, "gotcha": 0.5}
		"radio":
			weights = {"policy": 2.6, "cost": 1.8, "rival": 1.6, "crisis": 1.6, "pact": 1.2, "human": 0.8, "scandal": 0.8, "gotcha": 0.8, "ideology": 0.6}
		"control":
			weights = {"control": 1.0}
	var role_tag := _role_tag()
	if role_tag != "" and fmt != "control":
		weights["record"] = 2.4
		weights.erase("gotcha")
	var kinds: Array = []
	if _has_flipflop() and m.rng.randf() < 0.75 and fmt != "control":
		kinds.append("flipflop")
	var guard := 0
	while kinds.size() < n and guard < 60:
		guard += 1
		var k := _weighted_kind(weights, kinds) if fmt != "control" else "control"
		if k != "":
			kinds.append(k)
	var questions: Array = []
	var mood0 := str(host["mood"])
	for i in range(kinds.size()):
		var mood := mood0
		if fmt == "debate" or fmt == "control":
			mood = "hostile"
		elif fmt == "podcast":
			mood = "friendly" if m.rng.randf() < 0.55 else "neutral"
		elif m.rng.randf() < 0.2:
			mood = ["hostile", "neutral", "friendly"][m.rng.randi_range(0, 2)]
		var topic := _choose_topic()
		var kind := str(kinds[i])
		var q := _make_q(kind, topic, mood, rival, fmt)
		# Nunca repetir literalmente una pregunta ya vista (se recuerdan las últimas 300).
		var seen_q: Array = st().get("seen_q", [])
		st()["seen_q"] = seen_q
		var tries := 0
		while seen_q.has(hash(str(q["text"]))) and tries < 4:
			tries += 1
			q = _make_q(kind, _choose_topic(), mood, rival, fmt)
		seen_q.append(hash(str(q["text"])))
		while seen_q.size() > 300:
			seen_q.pop_front()
		_note_topic(str(q["topic"]) if str(q["topic"]) != "" else topic)
		if kind == "flipflop":
			var stances: Dictionary = st()["stances"]
			if stances.has(str(q["issue"])):
				(stances[str(q["issue"])] as Dictionary)["asked"] = true
		# Cada pregunta la formula un periodista distinto en la rueda de prensa.
		if fmt == "press":
			var jn := _journalist(_outlet_for("Rueda de prensa"))
			q["asker"] = {"name": jn["name"], "fem": jn["fem"], "outlet": _last_outlet_name}
			q["mood"] = str(jn["mood"])
		questions.append(q)
	var ctx := str(ev.get("context", ""))
	if ctx != "" and not questions.is_empty():
		var q0: Dictionary = questions[0]
		q0["text"] = "A propósito de «%s»: %s" % [ctx, str(q0["text"])]
	var ev_id := "%s·%s" % [type_name, str(ev.get("title", ""))]
	var hs := {}
	if (fmt == "debate" or fmt == "control") and rival != "":
		hs = {"name": Leader.full_name(m.leader_of(rival)), "fem": str(m.leader_of(rival).get("gender", "m")) == "f", "mood": "hostile", "party": rival}
	else:
		hs = host
	return {"id": ev_id, "type": type_name, "format": fmt, "outlet": outlet, "host": hs, "questions": questions, "i": 0, "tally": {}, "seg_tally": {}, "poll0": m.player_poll(), "trust0": m.trust, "vis0": m.visibility, "rel": {}, "grades": [], "used_arch": [], "rival": rival, "topic_tag": str(ev.get("topic", ""))}

## Pregunta de réplica (interrupción del rival en debates y ruedas de prensa).
func replica_for(session: Dictionary) -> Dictionary:
	return _make_q("replica", "", "hostile", str(session.get("rival", "")), str(session.get("format", "debate")))

func _weighted_kind(weights: Dictionary, taken: Array) -> String:
	var ids: Array = []
	var ws: Array = []
	for k in weights.keys():
		var w: float = float(weights[k])
		if taken.has(k):
			w *= 0.2
		w /= (1.0 + 0.7 * float(_times("kind:" + str(k))))
		if k == "scandal" and m.phase == "campaign" and m.day < 5:
			w *= 0.4
		ids.append(k)
		ws.append(w)
	var tot := 0.0
	for w2 in ws:
		tot += float(w2)
	var roll := m.rng.randf() * tot
	for i in range(ids.size()):
		roll -= float(ws[i])
		if roll <= 0.0:
			_count("kind:" + str(ids[i]))
			return str(ids[i])
	return ""

# ---------------------------------------------------------------- resolución
func _grade(qual: float) -> String:
	if qual >= 0.62:
		return "great"
	if qual >= 0.2:
		return "good"
	if qual >= -0.2:
		return "weak"
	return "bad"

const GRADE_NAME := {"great": "Acierto rotundo", "good": "Buena respuesta", "weak": "Respuesta floja", "bad": "Desliz"}

## Aplica una respuesta. spokes=true: responde un portavoz (atributos medios, efecto reducido).
func resolve(session: Dictionary, q: Dictionary, ans: Dictionary, spokes: bool = false) -> Dictionary:
	var arch := str(ans["arch"])
	var a: Dictionary = ARCH[arch]
	var ch := m.character()
	var skill := 0.0 if spokes else Leader.edge(ch, str(a["stat"]))
	var topic := str(q["topic"])
	var issue := str(q.get("issue", ""))
	var mood := str(q.get("mood", "neutral"))
	var fit := 0.0
	var flavor := float(a.get("flavor", 0.0))
	if arch.begins_with("plan_"):
		fit = clampf(1.0 - absf(flavor - _player_econ()) * 1.1, -1.0, 1.0)
	var used: Array = session["used_arch"]
	var repeats := 0
	for u in used:
		if str(u) == arch:
			repeats += 1
	var qual := float(a["base"]) + 0.55 * skill + 0.32 * fit - 0.12 * float(repeats) + m.rng.randfn(0.0, 0.26 + float(a.get("var", 0.0)))
	if mood == "hostile" and arch in ["deflect", "humor", "promise"]:
		qual -= 0.14
	if mood == "friendly" and arch in ["deflect", "humor"]:
		qual += 0.08
	if mood == "friendly" and arch in ["attack", "hardline"]:
		qual -= 0.04
	if str(q["kind"]) == "flipflop":
		qual -= 0.12 * (0.4 if Leader.has_perk(ch, "outsider") else 1.0)
	if str(q["kind"]) == "gotcha" and arch == "data":
		qual += 0.25
	# Incoherencia con las propias ideas: lo percibe quien conoce tu partido.
	var incoherent := arch.begins_with("plan_") and fit < -0.45
	if incoherent:
		qual -= 0.1
	if spokes:
		qual *= 0.8
	if bool(ans.get("timeout", false)):
		qual -= 0.35
	qual = clampf(qual, -1.0, 1.0)
	used.append(arch)
	var grade := _grade(qual)
	var scale := (0.6 if spokes else 1.0) * float((session["outlet"] as Dictionary).get("reach", 1.0))
	var chips: Array = []
	# Imagen
	var im_changes: Dictionary = {}
	for k in (a["gain"] as Dictionary).keys():
		var v: float = float((a["gain"] as Dictionary)[k]) * qual * scale
		im_changes[k] = float(im_changes.get(k, 0.0)) + v
	for k2 in ((a.get("cost", {})) as Dictionary).keys():
		var v2: float = float((a["cost"] as Dictionary)[k2]) * scale * (0.6 + 0.4 * maxf(0.0, -qual) + 0.4)
		im_changes[k2] = float(im_changes.get(k2, 0.0)) + v2
	if incoherent:
		im_changes["honesty"] = float(im_changes.get("honesty", 0.0)) - 1.6 * scale
	for k3 in im_changes.keys():
		_bump_image(str(k3), float(im_changes[k3]))
		(session["tally"] as Dictionary)[k3] = float((session["tally"] as Dictionary).get(k3, 0.0)) + float(im_changes[k3])
	# Segmentos y encuestas
	var poll_delta := 0.0
	var seg_w: Dictionary = {}
	if TOPICS.has(topic):
		seg_w = TOPICS[topic]["segs"]
	for sid in SEGMENTS.keys():
		var sd: Dictionary = SEGMENTS[sid]
		var tw := float(seg_w.get(sid, 0.35)) if not seg_w.is_empty() else 0.4
		var align := 0.7
		if arch.begins_with("plan_"):
			align = 0.25 + 0.75 * clampf(1.0 - absf(flavor - float(sd["lean"])) * 0.9, 0.0, 1.0)
		elif arch == "empathy" or arch == "data" or arch == "honest":
			align = 0.8
		elif arch == "attack" or arch == "hardline":
			align = 0.45 + 0.4 * clampf(1.0 - absf(_player_bloc() - float(sd["lean"])) , 0.0, 1.0)
		var d_seg := qual * tw * align * 3.2 * scale
		_bump_seg(str(sid), d_seg)
		(session["seg_tally"] as Dictionary)[sid] = float((session["seg_tally"] as Dictionary).get(sid, 0.0)) + d_seg
		poll_delta += float(sd["w"]) * d_seg * 0.05
	if arch.begins_with("plan_") and issue != "":
		pass
	# Confianza, visibilidad, impulso
	var tr := (float(a["trust"]) * qual + (0.3 if qual > 0.0 else 0.0)) * scale
	if incoherent:
		tr -= 1.0
	var vis := float(a["vis"]) * (0.5 + 0.5 * absf(qual) + (0.4 if Leader.has_perk(ch, "telegenico") else 0.0)) * scale
	if Leader.has_perk(ch, "polemico"):
		vis *= 1.25
	m.trust = m.trust + tr
	m.visibility = m.visibility + vis
	m.momentum = m.momentum + float(a["mom"]) * qual * scale
	m.campaign.adjust_poll(m.pid(), poll_delta)
	# Relaciones con partidos
	var target := str(ans.get("target", ""))
	if target != "":
		_relations_for(session, q, ans, arch, qual, target)
	# Memoria de posturas (hemeroteca)
	if issue != "" and arch != "deflect":
		_remember_stance(issue, arch, flavor, str(ans["text"]), session)
	# Rival que se siente aludido
	if arch == "attack" and target != "":
		_add_grudge(target, 3 + m.rng.randi_range(0, 3))
	var react_pool: Array = (REACT[grade][mood] as Array).duplicate()
	react_pool.append_array(MediaDB.react(grade, mood))
	var react: String = pick_h("react:%s:%s" % [grade, mood], react_pool)
	if arch == "deflect" and grade in ["weak", "bad"]:
		react = "No ha respondido a mi pregunta, así que se la repito."
	session["grades"].append(grade)
	# Chips visibles del efecto
	for k4 in im_changes.keys():
		if absf(float(im_changes[k4])) >= 0.3:
			chips.append({"label": str(IMAGE_DIMS.get(k4, k4)), "delta": float(im_changes[k4])})
	if absf(tr) >= 0.3:
		chips.append({"label": "Confianza", "delta": tr})
	if absf(poll_delta) >= 0.004:
		chips.append({"label": "Encuesta", "delta": poll_delta, "unit": "pts"})
	if target != "" and session["rel"].has(target):
		chips.append({"label": "Relación con %s" % m.party_short(target), "delta": float(session["rel"][target])})
	_count("arch:" + arch)
	st()["count"] = int(st()["count"]) + 1
	return {"grade": grade, "grade_name": str(GRADE_NAME[grade]), "quality": qual, "react": react, "chips": chips, "incoherent": incoherent,
		"mood": ("happy" if grade == "great" else ("smug" if grade == "good" else ("worried" if grade == "weak" else "angry")))}

## Calidad esperada de una respuesta sin el ruido aleatorio (la usa el asesor del plató).
func expected_quality(session: Dictionary, q: Dictionary, ans: Dictionary) -> float:
	var arch := str(ans["arch"])
	var a: Dictionary = ARCH[arch]
	var ch := m.character()
	var skill := Leader.edge(ch, str(a["stat"]))
	var mood := str(q.get("mood", "neutral"))
	var fit := 0.0
	if arch.begins_with("plan_"):
		fit = clampf(1.0 - absf(float(a.get("flavor", 0.0)) - _player_econ()) * 1.1, -1.0, 1.0)
	var repeats := 0
	for u in session["used_arch"]:
		if str(u) == arch:
			repeats += 1
	var qual := float(a["base"]) + 0.55 * skill + 0.32 * fit - 0.12 * float(repeats)
	if mood == "hostile" and arch in ["deflect", "humor", "promise"]:
		qual -= 0.14
	if mood == "friendly" and arch in ["deflect", "humor"]:
		qual += 0.08
	if mood == "friendly" and arch in ["attack", "hardline"]:
		qual -= 0.04
	if str(q["kind"]) == "gotcha" and arch == "data":
		qual += 0.25
	if arch.begins_with("plan_") and fit < -0.45:
		qual -= 0.1
	return qual

func _relations_for(session: Dictionary, q: Dictionary, ans: Dictionary, arch: String, qual: float, target: String) -> void:
	var a: Dictionary = ARCH[arch]
	var base := float(a.get("rel", 0.0))
	var kind := str(q["kind"])
	if kind == "pact":
		# Responder sobre un pacto mueve la relación con ese partido y con sus opuestos.
		match arch:
			"concede": base = 4.0
			"hardline": base = -4.0
			"attack": base = -3.0
			"honest": base = 0.5
			_: base = 0.0
	if base == 0.0:
		return
	var d := base * (0.7 + 0.5 * absf(qual))
	m.ai.change_relation(target, d)
	session["rel"][target] = float(session["rel"].get(target, 0.0)) + d
	_say(target, "attack" if d < 0.0 else "hand")
	if kind == "pact" and d != 0.0:
		for r in m.rivals:
			var rid := str((r as Dictionary).get("id", ""))
			if rid == "" or rid == target or rid == Rules.OTHERS_ID:
				continue
			if _party_bloc(rid) * _party_bloc(target) < -0.1 and absf(_party_bloc(rid)) > 0.3:
				var e := -0.35 * d
				m.ai.change_relation(rid, e)
				session["rel"][rid] = float(session["rel"].get(rid, 0.0)) + e

func _say(pid: String, what: String) -> void:
	var said: Dictionary = st()["said"]
	said[pid] = {"what": what, "day": m.day if m.phase == "campaign" else 100 + m.gov_month, "cycle": m.cycle}

func said_about(pid: String) -> Dictionary:
	var s: Dictionary = st()["said"]
	if not s.has(pid):
		return {}
	var e: Dictionary = s[pid]
	var age: int = (m.day if m.phase == "campaign" else 100 + m.gov_month) - int(e.get("day", 0))
	if int(e.get("cycle", 1)) != m.cycle or age > 14:
		return {}
	return e

func _remember_stance(issue: String, arch: String, flavor: float, text: String, session: Dictionary) -> void:
	var lean := flavor
	match arch:
		"promise": lean = -0.4
		"hardline": lean = 0.0
		"honest": lean = 0.15
	var stances: Dictionary = st()["stances"]
	var old: Dictionary = stances.get(issue, {})
	var contradicted := false
	if not old.is_empty() and absf(float(old.get("lean", 0.0)) - lean) >= 0.9 and arch.begins_with("plan_") and str(old.get("arch", "")).begins_with("plan_"):
		contradicted = true
	if not old.is_empty() and str(old.get("arch", "")) == "promise" and arch == "honest" and m.day - int(old.get("day", 0)) < 20:
		contradicted = true
	var quote := text if text.length() < 110 else text.substr(0, 107) + "…"
	stances[issue] = {"lean": lean, "arch": arch, "day": m.day, "text": quote, "outlet": str((session["outlet"] as Dictionary)["name"]), "contradicted": contradicted or bool(old.get("contradicted", false)) and not bool(old.get("asked", false)), "asked": false}

func _add_grudge(pid: String, in_days: int) -> void:
	var gr: Array = st()["grudges"]
	gr.append({"pid": pid, "due": (m.day if m.phase == "campaign" else 100 + m.gov_month) + in_days, "cycle": m.cycle})

# ---------------------------------------------------------------- cierre de una sesión
const HEAD_WALKOUT := ["{L} abandona el plató de {O} a mitad de la intervención", "Plantón de {L} en {O}: se levanta y se marcha", "{L} da la espalda a {O} y deja la entrevista a medias", "Escándalo en {O}: {L} abandona sin terminar"]

func headline(session: Dictionary, grades: Array) -> Dictionary:
	if bool(session.get("abandoned", false)):
		var ol: Dictionary = session["outlet"]
		var lname := Leader.full_name(m.character()).get_slice(" ", 1) if Leader.full_name(m.character()).contains(" ") else Leader.full_name(m.character())
		var wt := str(pick(HEAD_WALKOUT, "head:walkout")).replace("{L}", lname).replace("{O}", str(ol["name"]))
		return {"text": wt, "tone": "warning", "outlet": str(ol["name"])}
	var score := 0
	for g in grades:
		score += 2 if str(g) == "great" else (1 if str(g) == "good" else (-1 if str(g) == "weak" else -2))
	var tone := "positive" if score >= 2 else ("warning" if score <= -2 else "neutral")
	var outlet: Dictionary = session["outlet"]
	var lean_align := float(outlet["lean"]) * _player_bloc()
	var topic_q: Dictionary = session["questions"][0]
	for q in session["questions"]:
		if str((q as Dictionary).get("issue", "")) != "":
			topic_q = q
			break
	var tname := _issue_l(str(topic_q.get("issue", ""))) if str(topic_q.get("issue", "")) != "" else "la actualidad"
	var pool: Array = HEAD_GOOD if tone == "positive" else (HEAD_BAD if tone == "warning" else HEAD_MIX)
	var text := str(pick(pool, "head:" + tone)).replace("{L}", Leader.full_name(m.character()).get_slice(" ", 1) if Leader.full_name(m.character()).contains(" ") else Leader.full_name(m.character())).replace("{O}", str(outlet["name"])).replace("{T}", tname)
	# Un medio afín suaviza lo malo; uno hostil lo agrava.
	var spin := ""
	if lean_align > 0.15 and tone == "warning":
		spin = " (un traspiés que el medio relativiza)"
	elif lean_align < -0.15 and tone == "warning":
		spin = " (el medio lo convierte en portada)"
	return {"text": text + spin, "tone": tone, "outlet": str(outlet["name"])}

func finish(session: Dictionary, ev: Dictionary, spokes: bool = false) -> Dictionary:
	var grades: Array = session["grades"]
	var head := headline(session, grades)
	var outlet: Dictionary = session["outlet"]
	var tally: Dictionary = session["tally"]
	var seg_t: Dictionary = session["seg_tally"]
	var net := 0.0
	for g in grades:
		net += 1.0 if str(g) == "great" else (0.5 if str(g) == "good" else (-0.4 if str(g) == "weak" else -1.0))
	var factor := clampf(net / maxf(float(grades.size()), 1.0), -1.0, 1.0)
	var body := "%s. Balance: %d respuestas, intención de voto %.1f%%." % [str(outlet["name"]), grades.size(), m.player_poll()]
	m.publish(str(head["text"]), body, "MEDIOS", str(head["tone"]))
	var hem := hemeroteca()
	hem.push_front({"day": m.day, "outlet": str(outlet["name"]), "headline": str(head["text"]), "tone": str(head["tone"])})
	while hem.size() > 30:
		hem.pop_back()
	ev["status"] = "done"
	# Fuera de campaña, el desempeño mediático también mueve el apoyo al Gobierno.
	if m.phase == "legislature":
		var gain := factor * float(outlet.get("reach", 1.0)) * 1.6
		if m.gov.player_in_government():
			m.s["gov_approval"] = clampf(m.gov.approval() + gain, 5.0, 95.0)
		elif m.role() == "opposition":
			m.gov.shift_government_approval(-gain * 0.5)
	m.a("campaign_log").append("%s en %s · %s" % [str(session["type"]), str(outlet["name"]), "bien" if factor >= 0.25 else ("mal" if factor < -0.2 else "mixto")])
	m.campaign.record_snapshot()
	return {"type": str(session["type"]), "format": str(session.get("format", "tv")), "factor": factor, "title": str(ev.get("title", "")), "venue": str(ev.get("region", "")), "headline": head, "tally": tally, "seg_tally": seg_t, "rel": session["rel"],
		"summary": "%s: %s" % [str(outlet["name"]), str(head["text"])], "poll_delta": m.player_poll() - float(session["poll0"])}

## Abandonar el acto a mitad: castiga la imagen en proporción a lo que queda por responder.
## `remaining` = preguntas principales sin contestar. Siempre es peor que acabar mal, pero menos que un desastre total.
func abandon(session: Dictionary, ev: Dictionary, remaining: int) -> Dictionary:
	var left := clampi(remaining, 0, 8)
	session["abandoned"] = true
	for _i in range(left):
		(session["grades"] as Array).append("bad")
	if (session["grades"] as Array).is_empty():
		(session["grades"] as Array).append("bad")
	var pen := 2.5 + 1.2 * float(left)
	m.trust = m.trust - pen
	m.visibility = m.visibility + 1.0
	m.momentum = m.momentum - 1.0 - 0.3 * float(left)
	var tally: Dictionary = session["tally"]
	for k in ["honesty", "strength", "competence"]:
		var d := -1.2 - 0.5 * float(left)
		_bump_image(k, d)
		tally[k] = float(tally.get(k, 0.0)) + d
	m.campaign.adjust_poll(m.pid(), -(0.05 + 0.03 * float(left)))
	var res := finish(session, ev)
	res["abandoned"] = true
	res["trust_penalty"] = pen
	return res

## Intervención delegada en el portavoz: responde sola con criterios razonables.
func auto_play(ev: Dictionary) -> Dictionary:
	var s := build_session(ev)
	for qd in s["questions"]:
		var q: Dictionary = qd
		var best: Dictionary = (q["answers"] as Array)[m.rng.randi_range(0, (q["answers"] as Array).size() - 1)]
		var safe: Array = []
		for ad in q["answers"]:
			if str((ad as Dictionary)["arch"]) in ["data", "honest", "empathy", "plan_centre", "concede"]:
				safe.append(ad)
		if not safe.is_empty() and m.rng.randf() < 0.7:
			best = safe[m.rng.randi_range(0, safe.size() - 1)]
		resolve(s, q, best, true)
	return finish(s, ev, true)

# ---------------------------------------------------------------- bandeja: preguntas de prensa
const PRESS_KINDS := ["policy", "cost", "pact", "crisis", "scandal", "rival", "ideology", "flipflop"]

func press_question() -> Dictionary:
	var ev := {"type": "Rueda de prensa", "title": "Pregunta de la prensa"}
	var outlet := _outlet_for("Entrevista")
	var host := _journalist(outlet)
	var kinds: Array = PRESS_KINDS.duplicate()
	if not _has_flipflop():
		kinds.erase("flipflop")
	var kind := str(pick(kinds, "press_kind"))
	var q := _make_q(kind, _choose_topic(), str(host["mood"]), main_rival())
	_note_topic(str(q["topic"]))
	var data := {"q": q, "outlet": outlet, "host": host}
	var actions: Array = []
	for i in range((q["answers"] as Array).size()):
		var ad: Dictionary = (q["answers"] as Array)[i]
		actions.append({"id": "press:%d" % i, "label": "%s — %s" % [str(ad["tag"]), str(ad["text"])], "style": "secondary"})
	var title := "%s pregunta: %s" % [str(outlet["name"]), str(host["name"])]
	return m.publish(title, str(q["text"]), "MEDIOS", "warning" if str(host["mood"]) == "hostile" else "neutral", {"needs_response": true, "actions": actions, "data": data, "expires_in": 3, "speaker_id": ""})

func answer_press(msg: Dictionary, idx: int) -> String:
	var data: Dictionary = msg.get("data", {})
	var q: Dictionary = data["q"]
	var answers: Array = q["answers"]
	if idx < 0 or idx >= answers.size():
		return ""
	var s := {"outlet": data["outlet"], "host": data["host"], "type": "Pregunta", "used_arch": [], "tally": {}, "seg_tally": {}, "rel": {}, "grades": [], "poll0": m.player_poll(), "questions": [q]}
	var r := resolve(s, q, answers[idx] as Dictionary)
	var hl := headline(s, s["grades"])
	m.publish(str(hl["text"]), "Respuesta a %s en la bandeja." % str((data["outlet"] as Dictionary)["name"]), "MEDIOS", str(hl["tone"]))
	var hem := hemeroteca()
	hem.push_front({"day": m.day, "outlet": str((data["outlet"] as Dictionary)["name"]), "headline": str(hl["text"]), "tone": str(hl["tone"])})
	return "%s. %s" % [str(r["grade_name"]), str(r["react"])]

# ---------------------------------------------------------------- paso del tiempo
func daily() -> void:
	var e := st()
	var today := m.day if m.phase == "campaign" else 100 + m.gov_month
	# Imagen: efecto lento sobre las encuestas y vuelta a la media.
	if m.phase == "campaign":
		m.campaign.adjust_poll(m.pid(), (image_avg() - 50.0) / 50.0 * 0.012)
	for k in IMAGE_DIMS.keys():
		var v: float = float(image().get(k, 50.0))
		image()[k] = v + (50.0 - v) * 0.004
	for k2 in seg().keys():
		var v2: float = float(seg()[k2])
		seg()[k2] = v2 + (50.0 - v2) * 0.006
	# Rivales aludidos que responden.
	var gr: Array = e["grudges"]
	for i in range(gr.size() - 1, -1, -1):
		var g: Dictionary = gr[i]
		if int(g.get("cycle", 1)) != m.cycle:
			gr.remove_at(i)
			continue
		if int(g["due"]) <= today:
			_rival_reply(str(g["pid"]))
			gr.remove_at(i)
	# Pregunta de prensa cada pocos días.
	if m.phase == "campaign" and m.day >= 3 and m.day - int(e.get("last_press_day", 0)) >= 6 and m.rng.randf() < 0.28:
		e["last_press_day"] = m.day
		press_question()

func _rival_reply(pid: String) -> void:
	var short := m.party_short(pid)
	var leader := Leader.full_name(m.leader_of(pid))
	var lines := [
		"%s responde a tus críticas: «Quien ataca sin propuestas confiesa que no las tiene»." % leader,
		"%s te acusa de «faltar al respeto» y pide que dejes de dar lecciones." % leader,
		"Desde %s replican que tus ataques son «una cortina de humo»." % short,
		"%s devuelve el golpe y recuerda tu hemeroteca ante los micrófonos." % leader,
		"Fuentes de %s aseguran que tus palabras «han sido recibidas con indignación»." % short,
	]
	var line := str(pick(lines, "grudge"))
	m.publish("%s contraataca" % short, line, "RIVALES", "warning")
	m.ai.change_relation(pid, -1.5)
	m.campaign.adjust_poll(pid, 0.02)
	m.campaign.adjust_poll(m.pid(), -0.015)

# ---------------------------------------------------------------- incidentes tras las reuniones
const INCIDENTS := [
	{"id": "leak", "title": "Filtración de la reunión con {P}", "body": "Un medio publica detalles de lo hablado con {P}. Nadie sabe quién ha filtrado.",
		"options": [
			{"label": "Desmentirlo con firmeza", "image": {"strength": 1.5, "honesty": -1.0}, "rel": -1.0, "trust": -0.3},
			{"label": "Confirmar lo hablado y explicar los motivos", "image": {"honesty": 2.0, "competence": 0.6}, "rel": -2.0, "trust": 0.8},
			{"label": "Pedir discreción a {P} en privado", "image": {"closeness": 0.6}, "rel": 1.2, "trust": 0.1}]},
	{"id": "rival_comment", "title": "{O} comenta tu reunión con {P}", "body": "{O} ha dicho que tu acercamiento a {P} demuestra «que no tienes principios».",
		"options": [
			{"label": "Responder con ironía", "image": {"empathy": 1.2, "strength": 0.8}, "rel": -1.0, "rel_o": -1.5, "trust": 0.0},
			{"label": "Ignorarlo", "image": {"strength": -0.5}, "rel": 0.0, "trust": 0.0},
			{"label": "Aclarar que hablas con todos", "image": {"honesty": 1.0, "closeness": -0.5}, "rel": 0.6, "trust": 0.4}]},
	{"id": "ally_public", "title": "{P} hace públicas sus condiciones", "body": "{P} explica en rueda de prensa lo que te ha exigido, sin avisar. Presiona para cerrar rápido.",
		"options": [
			{"label": "Aceptar el pulso y endurecer tu posición", "image": {"strength": 2.0, "empathy": -0.8}, "rel": -2.0, "trust": 0.0},
			{"label": "Rebajar el tono y proponer retomar la mesa", "image": {"closeness": 1.0, "strength": -1.0}, "rel": 1.8, "trust": 0.3},
			{"label": "Responder con otra exigencia pública", "image": {"strength": 1.0, "honesty": -0.5}, "rel": -1.0, "trust": -0.2}]},
	{"id": "rumor", "title": "Rumores de un pacto con {P}", "body": "Circula la versión de que ya habéis cerrado un acuerdo secreto con {P}. Tus bases están nerviosas.",
		"options": [
			{"label": "Convocar a los medios y negarlo", "image": {"honesty": 0.8, "competence": 0.4}, "rel": -1.2, "trust": 0.5},
			{"label": "Dejar que corra: da juego", "image": {"strength": 0.8, "honesty": -1.2}, "rel": 0.8, "trust": -0.5},
			{"label": "Explicar las condiciones que pides", "image": {"honesty": 1.5, "competence": 1.0}, "rel": 0.0, "trust": 0.8}]},
	{"id": "ambush", "title": "Preguntas incómodas a la salida", "body": "Un grupo de periodistas te asalta a la salida de la reunión con {P} y te pregunta por lo que cedes.",
		"options": [
			{"label": "Responder con calma y datos", "image": {"competence": 1.5, "honesty": 0.6}, "rel": 0.3, "trust": 0.5},
			{"label": "No hacer declaraciones", "image": {"strength": -0.3, "honesty": -0.5}, "rel": 0.2, "trust": -0.2},
			{"label": "Reprochar a la prensa su insistencia", "image": {"strength": 1.2, "empathy": -1.2}, "rel": 0.0, "trust": -0.3}]},
	{"id": "third_party", "title": "{O} se ofrece como alternativa", "body": "Al enterarse de tu reunión con {P}, {O} te hace llegar una oferta paralela «mejor y sin condiciones».",
		"options": [
			{"label": "Sondear la oferta de {O}", "image": {"competence": 0.8, "honesty": -0.6}, "rel": -1.5, "rel_o": 2.0, "trust": 0.0},
			{"label": "Rechazarla: ya hablas con {P}", "image": {"honesty": 1.0, "strength": 0.4}, "rel": 1.5, "rel_o": -0.8, "trust": 0.4},
			{"label": "Usarla para presionar a {P}", "image": {"strength": 1.4, "honesty": -1.0}, "rel": -2.0, "rel_o": 1.0, "trust": -0.2}]},
]

func maybe_incident(pid: String, agreed: bool) -> bool:
	var p := 0.22 if agreed else 0.3
	if m.rng.randf() > p:
		return false
	var sc: Dictionary = pick(INCIDENTS, "incident") as Dictionary
	var other := ""
	var cands: Array = []
	for r in m.rivals:
		var rid := str((r as Dictionary).get("id", ""))
		if rid != "" and rid != pid and rid != Rules.OTHERS_ID:
			cands.append(rid)
	if not cands.is_empty():
		other = str(cands[m.rng.randi_range(0, cands.size() - 1)])
	var short := m.party_short(pid)
	var oshort := m.party_short(other) if other != "" else "un rival"
	var actions: Array = []
	var opts: Array = sc["options"]
	for i in range(opts.size()):
		actions.append({"id": "incident:%d" % i, "label": str((opts[i] as Dictionary)["label"]).replace("{P}", short).replace("{O}", oshort), "style": "primary" if i == 0 else "secondary"})
	var title := str(sc["title"]).replace("{P}", short).replace("{O}", oshort)
	var body := str(sc["body"]).replace("{P}", short).replace("{O}", oshort)
	m.publish(title, body, "DIPLOMACIA", "warning", {"needs_response": true, "actions": actions, "data": {"incident": str(sc["id"]), "party": pid, "other": other}, "speaker_id": pid, "expires_in": 3})
	return true

func resolve_incident(msg: Dictionary, idx: int) -> String:
	var data: Dictionary = msg.get("data", {})
	var sc: Dictionary = {}
	for it in INCIDENTS:
		if str((it as Dictionary)["id"]) == str(data.get("incident", "")):
			sc = it
	if sc.is_empty():
		return ""
	var opts: Array = sc["options"]
	if idx < 0 or idx >= opts.size():
		return ""
	var o: Dictionary = opts[idx]
	var pid := str(data.get("party", ""))
	var other := str(data.get("other", ""))
	var ch := m.character()
	var tact := 1.0 + 0.25 * Leader.edge(ch, "mano_izquierda")
	for k in (o.get("image", {}) as Dictionary).keys():
		_bump_image(str(k), float((o["image"] as Dictionary)[k]))
	m.trust = m.trust + float(o.get("trust", 0.0))
	if float(o.get("rel", 0.0)) != 0.0 and pid != "":
		m.ai.change_relation(pid, float(o["rel"]) * (tact if float(o["rel"]) > 0.0 else 1.0 / tact))
	if float(o.get("rel_o", 0.0)) != 0.0 and other != "":
		m.ai.change_relation(other, float(o["rel_o"]))
	return "Has optado por «%s». %s" % [str(o["label"]).replace("{P}", m.party_short(pid)).replace("{O}", m.party_short(other) if other != "" else "el rival"), _incident_aftermath(o)]

func _incident_aftermath(o: Dictionary) -> String:
	var r := float(o.get("rel", 0.0))
	if r >= 1.0:
		return "La relación sale algo reforzada."
	if r <= -1.0:
		return "La relación queda tocada."
	return "El incidente se enfría sin mayores consecuencias."
