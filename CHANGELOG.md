# Cambios

## Numeración de versiones
Desde esta entrega el juego se numera como **Alpha 0.2.x**. La fase Alpha dura hasta que el responsable del proyecto la dé por terminada; entonces se pasará a la numeración definitiva.
- **Alpha 0.2.0** es el estado que antes se llamaba 2.15.0 (sin cambios de jugabilidad: solo se renombra la versión).
- Cada entrega validada sube el último número (0.2.1, 0.2.2…). Una versión nueva de línea (0.3) la decide el responsable del proyecto.
- Las versiones anteriores (0.8 a 2.15.0) se conservan más abajo con su numeración histórica; la equivalencia está en `docs/VERSIONES.md`.
- La versión vive en un único sitio: `Rules.GAME_STAGE` y `Rules.GAME_VERSION` (se muestra con `Rules.version_label()`).

## Alpha 0.2.0 (antes 2.15.0) — Negociación de Gobierno, entrega B: perfiles de la IA, poder negociador y mesa ampliada
Primera parte de la nueva ruta de negociación (documento «Especificación de negociación, formación de Gobierno e investidura»). Todo se apoya en `PartyBrain`, `Diplomacy` y `TableDynamics`: no hay un segundo sistema de negociación.
- **Perfil persistente** (`PartyBrain.ensure_traits`): además de ambición, pragmatismo, rigidez, lealtad, riesgo y carácter territorial, cada partido tiene ahora **ambición institucional, cohesión interna, presión electoral y fiabilidad**. Las partidas antiguas los reciben al cargar sin tocar los rasgos que ya tenían.
- **Poder negociador** (`PartyBrain.negotiating_power`, `Rules.NEGOTIATION_WEIGHTS`): seis factores con los pesos de la especificación (peso parlamentario 25, carácter decisivo 25, afinidad 15, alternativas de Gobierno 15, intereses y urgencia 10, credibilidad y cohesión 10). **No decide nada por sí solo**: sube la exigencia (`need`), encarece lo que cede, abarata lo que recibe y acorta la paciencia de quien tiene alternativas. La urgencia resta poder: quien necesita el pacto negocia peor.
- **Estrategia preferida** (`PartyBrain.preferred_modality`): coalición, apoyo externo, acuerdo puntual, abstención negociada, oposición o bloqueo, calculada a partir de los rasgos, el poder y la afinidad, **nunca del tamaño ni del tipo de partido**. Un partido grande puede negarse a entrar aunque le ofrezcas carteras (factor *No le conviene entrar en el Gobierno*; la contraoferta retira lo que implica entrar y propone su fórmula). `GovernmentSim._ai_resolve` usa esa modalidad para decidir si el partido entra en el Consejo, apoya desde fuera o se abstiene.
- **Categorías nuevas en la mesa** (diez, `Rules.TABLE_CATEGORIES`): Participación, Estructura (vicepresidencia, máximo/mínimo de ministerios, coordinación), Carteras (concretas, por competencia), Políticas, Objetivos medibles (tres niveles por tema), Territorio, Presupuesto, Parlamento, Instituciones y Calendario. **Cada término lo evalúa de verdad el cerebro del partido** (`term_value`, `term_text`, `term_block`, `counter`) y se guarda en los `terms` del pacto. Una participación pactada llega a la investidura (`_sync_investiture`).
- **Herramientas de la mesa**: añadir, quitar y modificar cantidades; **sustituir** una condición por otra; **ofrecer una alternativa** a una exigencia suya; **aceptar parcialmente** (3 carteras → 2); **borradores** (hasta 6) y **versiones** de cada oferta y contraoferta con **comparación** y recuperación; **pedir contraoferta** sin presentar la oferta (cuesta paciencia, máximo 3); y el estado de cada condición según lo que se sabe: *imprescindible, negociable, rechazada o sin sondear*.
- **Pantalla**: el catálogo se organiza por las diez categorías; filas con botones −/+/½/⇄/✕, chips de estado, panel de Borradores y de Versiones con comparación, y en «Lo que sabes de…» el poder negociador (con el desglose en el tooltip) y la modalidad que prefiere cuando se sondea.
- **Lo que aún no hace** (entregas C-G de la especificación): las condiciones nuevas se evalúan, se pactan y quedan registradas, pero **materializarlas** (reclamaciones ministeriales, vicepresidencias reales, límite de ministerios aplicado, seguimiento de objetivos y plazos), los cinco candidatos por cartera, el capital político normalizado y la pantalla de investidura con diputados llegan en las siguientes versiones.
- Tests: `tests/negotiation_ai.gd` (nuevo, en `run_all.sh`), `tests/negotiation_ai_shots.gd` (capturas).

## 2.14.0 — Gabinete dinámico, ministros con vida propia y coaliciones con crisis
Sistema integral según el documento «Gabinete, ministros y coaliciones». Reutiliza `m.gov`, `m.ministers`, `m.exec`, `m.diplomacy`, `m.itrust` y los `commitments` de la investidura: no hay segunda fuente de verdad.
- **Constructor de ministerios** (`CabinetSim`, `m.cab`, `scripts/core/cabinet_sim.gd`; estado en `m.d("cab")` y en cada cartera): entre **8 y 20 ministerios**, con **competencias por etiquetas** (`Competencies`, 28 competencias en 4 categorías, cada área de política con una sola competencia). El nombre del ministerio ya no decide qué gestiona: `Executive.area_owners()` y `line_owner()` leen las etiquetas. Crear, renombrar, eliminar (con heredero), **fusionar** y **dividir** con aviso de impacto (competencias, políticas, presupuesto, titular), competencias **compartidas** y alertas (competencia esencial sin responsable, ministerio vacío o demasiado amplio, límites). Gratis al formar el Gobierno; en legislatura cuesta 3 de capital político.
- **Ministros** (`Ministers`, `scripts/core/ministers.gd`): 8 atributos (gestión, lealtad, afinidad, ambición, popularidad, experiencia, comunicación, integridad), 8 personalidades, historial, relación con el presidente y rendimiento (0-100) que se mueve cada trimestre. **Autonomía** plena/limitada/supervisada y **acciones del presidente** con coste (convocar, instruir una prioridad, respaldar, desautorizar, reprender, limitar/restaurar autonomía, exigir plan correctivo, pedir dimisión, destituir, sustituir, intercambiar). Más de tres cambios en un trimestre dan imagen de improvisación.
- **Actividad autónoma** (`MinisterActivity`, `m.mact`): cada trimestre, hasta 3 eventos (máx. 1 por cartera) según personalidad, atributos y contexto: reformas y petición de recursos (propuestas a la mesa), alertas, declaraciones polémicas, errores de gestión, escándalos, éxitos, choques por competencias compartidas y dimisiones. Etiquetas de **sucesor potencial / rival** que pueden restar confianza interna.
- **Coaliciones** (`Coalition`, `m.coal`, `scripts/core/coalition.gd`; estado en `m.d("coal")`): acuerdo con modalidad (**coalición, apoyo externo, acuerdo puntual** que caduca), reparto, líneas rojas y reglas. Las carteras de un socio están **reservadas**: el presidente no puede quitarlas ni destituir a su ministro (solo pedir que lo cambie). La **confianza del socio** es su `partner_satisfaction` (un solo número) y sube o baja con resultados, rendimiento de sus ministros, compromisos vencidos, decretos unilaterales y respuestas a sus propuestas, con los últimos motivos visibles.
- **Mesa de propuestas**: reformas y recursos de ministros, peticiones de los socios (+5 % de crédito en una partida, una ley, una competencia), declaraciones, choques, escándalos y errores, cada una con sus opciones (autorizar, moderar, aplazar, rechazar; respaldar, desautorizar, negociar…) y **efectos reales** (decreto, crédito en los PGE, compromiso, traspaso de competencia). Llegan a la Bandeja con botones. Si el presidente es la IA, las decide con una justificación. El jugador puede **proponer intercambios** a un socio y, como socio, **pedir cosas** al presidente: la IA acepta, ofrece una versión reducida o rechaza **explicando los motivos**.
- **Crisis escalonada**: Sin conflicto → Desacuerdo → Tensión → Bloqueo → Crisis pública → Ultimátum → Ruptura. **Un escalón por trimestre como máximo** (un desacuerdo aislado nunca rompe una coalición). Salidas: reunirse, mediar, conceder, aceptar/aplazar/rechazar el ultimátum. **La ruptura no convoca elecciones**: el socio se va, sus carteras vuelven al presidente, cae la estabilidad y se abre la renegociación (invitar a otros partidos como coalición, apoyo externo o puntual, con la ruptura reciente pesando en su respuesta), gobernar en minoría o convocar elecciones anticipadas (decisión del presidente).
- **Estabilidad agotada**: se elimina la convocatoria automática de elecciones; ahora abre una crisis de mayoría (`Coalition.on_stability_zero`). Con un presidente IA sin salida tras tres trimestres, convoca él (explicado).
- **Interfaz**: *Consejo de Ministros* rehecho (tablero de carteras, alertas, reparto, constructor) con **ficha de ministro** modal (Ministro / Competencias / Acciones del presidente / Estructura) y nueva pantalla **Mesa de coalición** (Socios, Propuestas, Compromisos, Crisis, Historial). Sin scroll a 1920×1080.
- Tests: `tests/cabinet.gd` (nuevo, en `run_all.sh`), `tests/cabinet_shots.gd` (capturas y desbordes). Ver docs/ARCHITECTURE.md.
- Correcciones asociadas: un ministro destituido ya no vuelve a ser nombrado de inmediato para la misma cartera (`burned` en `CabinetSim`); al crear un Gobierno se adoptan las competencias esenciales huérfanas; `HistoryGen` (modo aleatorio) reintenta colocar los hitos cercanos en lugar de descartarlos, de modo que siempre hay al menos 2 (fallo intermitente previo de `tests/history.gd`); `tests/militancy.gd` tolera el ruido de azar del estado inicial.

## 2.13.0 — Confianza interna, mandatos y Secretaría de Organización (prototipo fases 1-2)
Nueva capa de política interna según el documento «Sistema de confianza interna, mandatos y liderazgo del partido». Puedes ganar elecciones y aun así perder el control de tu partido.
- **Confianza interna 0-100** (`InternalTrust`, `m.itrust`, `scripts/core/internal_trust.gd`; estado persistente en `m.d("itrust")`, se guarda y carga con la partida y las partidas antiguas la crean al vuelo). **Distinta del apoyo electoral** (encuestas) y de la «Confianza» ciudadana del marcador (`m.trust`): nunca se mezclan.
- **Sin sistemas paralelos**: se construye sobre lo que ya existía y lo explica. Objetivo = 72 + 0.8·(apoyo de la militancia − 60) + 0.3·(confianza de la directiva − 60) + 0.7·(registro de mandatos − 70) + escándalos. La **militancia** (`Militancy.support()`) ya recoge coherencia ideológica, líneas rojas, promesas y resultados electorales; la **directiva** (`Executive.directive()`) la gestión del Gobierno. Cada hecho cuenta una sola vez: un mandato **no** toca a la corriente que lo plantea (su enfado está en el registro de mandatos), solo mueve a las demás corrientes, los socios, el voto y el capital político.
- **Estados** (umbrales del documento): Estabilidad ≥70, Advertencias 50-69, Rebelión interna 30-49, Crisis de liderazgo 15-29, Ruptura <15. Cada cambio de estado lo anuncia la Secretaría. **Sin destitución ni game over**: la rebelión solo tiene consecuencias de gestión (capital político ×1.08 / 1 / 0.75 / 0.55 / 0.4, una iniciativa menos por trimestre y filtraciones que dañan la imagen).
- **Mandatos ideológicos y retos políticos** con identificador, tipo, título, quién los plantea y qué corriente representa, motivo contextual, plazo en trimestres, importancia (baja/media/alta), meta medible y estado (nuevo, aceptado, negociado, rechazado, cumplido, incumplido, caducado). Nacen del contexto: **rectificar una ley** que choca con el eje del partido (`Militancy.on_law`), **cumplir una promesa** atrasada del programa, **recuperar encuestas** y **sacar adelante una ley propia**. Máximo 2 abiertos.
- **Respuestas**: *Aceptar* (te comprometes: cumplir sube mucho, fallar baja más), *Negociar* (probabilidad según la corriente, tu «mano izquierda», el capital político y la importancia; si acepta, la meta se rebaja a la mitad y el plazo se amplía un trimestre; si no, el asunto se endurece y no admite más negociación), *Rechazar* (coste atenuado o agravado según la **justificación** que te den las encuestas) o dejar caducar (peor que responder). Cada opción muestra su efecto estimado y sus consecuencias cruzadas (la corriente contraria, los socios de Gobierno, el electorado) y la respuesta queda **explicada en el registro de motivos**.
- **Alertas de gestión** de la Secretaría (inflación, paro, déficit, alquiler): sugieren medidas pero no son órdenes ni cuestan confianza.
- **Interfaz**: la pantalla *Militancia* (Partido) pasa a ser el panel interno: confianza y estado, **mandatos con botones y consecuencias previstas**, componentes de la confianza con su aportación, **por qué ha cambiado** y corrientes/líneas rojas. Marcador superior «Partido» con el estado, casilla en el Resumen y los mandatos llegan a la **Bandeja** con sus tres acciones.
- Ajuste de compatibilidad: la IA de la militancia converge ahora al ritmo de un trimestre (`1 − 0.89³`), y su cooldown de crisis son 2 turnos.
- Tests: `tests/trust.gd` (nuevo, en `run_all.sh`); `tests/design_shots.gd militancy` crea mandatos de ejemplo.

## 2.12.0 — País rehecho, turnos trimestrales y un motor macroeconómico dinámico
- **Turnos trimestrales**: cada CONTINUAR avanza **un trimestre** (`Rules.TURN_MONTHS = 3`, 16 turnos por legislatura, `m.turn()`). Todo se reescala: cupo de **3 iniciativas y 2 acciones de control por trimestre**, huecos de agenda, plazos de pactos y promesas, PGE (turnos 4/16/28/40), capital político, encuestas, relaciones y estabilidad de los socios (cambios ×3). Textos de la interfaz en «trimestre»/«T3».
- **Motor macroeconómico nuevo** (`MacroSim`, `m.macro`, `scripts/core/macro_sim.gd`; estado en `m.d("macro")`): cada trimestre recalcula toda la economía con agentes que se responden entre sí.
  - **Hogares** (renta real, ahorro precautorio, confianza, efecto riqueza de la vivienda) → consumo; **empresas** (acelerador, márgenes por costes laborales unitarios, confianza) → inversión y salarios; **bancos** (crédito, morosidad, tensión bancaria); **BCE** con regla de Taylor e inercia (movimientos de 0,25); **mercados** (prima de riesgo según deuda, déficit, crecimiento y aversión global); **vivienda** con burbuja y precio fundamental; **sector exterior** (crecimiento mundial, petróleo, turismo, competitividad); **expectativas de inflación** ancladas a la meta del 2 %.
  - **Crecimiento, paro e inflación son la suma de componentes con estado** (potencial, consumo, inversión, gasto público, exterior, ciclo, expectativas, medidas, crisis…): se puede decir exactamente cuánto de cada cambio se debe a cada ley, medida o crisis.
  - **Medidas con retardo** (55 % por turno hacia su efecto pleno) y **atribución a la ley de origen** (`note_law`).
  - **Director de shocks**: 13 crisis y booms (recesión mundial, crisis energética, financiera o de deuda, pinchazo inmobiliario, parón sanitario, guerra comercial, sequía, alimentos / boom turístico, recuperación mundial, boom tecnológico, fondos europeos) con **probabilidad condicionada a tus fragilidades** (burbuja, deuda, banca, tipos) y duración propia; publican noticia y dejan huella en el historial.
  - `project(n)` calcula la **previsión sin sorpresas** sin consumir azar de la partida; `alerts()` y un **informe trimestral** en prensa.
  - Los 7 indicadores propios (salarios, productividad, consumo, inversión, exportaciones, precio de la vivienda, precio de la energía) los calcula el motor; el resto de la red `WorldSim` sigue su propia dinámica (también trimestral).
- **País rehecho** (`CountryScreen`, `CountryVars`, `ChartWindow`; sustituye a Indicadores, Análisis, Economía y Sociedad): **panel izquierdo jerárquico** (Economía → Actividad, Empleo y rentas, Precios, Dinero y bancos, Confianza, Vivienda, Cuentas públicas, Ingresos por impuesto, Gasto por área, Estructura productiva, Mundo; Sociedad → 8 ámbitos; Servicios y grupos) con buscador; **Resumen** (casillas, previsión, avisos, crisis en curso, qué ha movido la economía); **ficha** de cada variable con gráfica, **¿por qué ha cambiado este trimestre?** (medida con su ley de origen, crisis, agente), efectos que siguen actuando, variables que influyen y tus leyes que la mueven; **Crisis y oportunidades** y **Efecto de mis leyes**.
- **Cada gráfica se abre en una ventana interactiva**: periodo (2/3/5 años/todo), previsión punteada, marcas de leyes y crisis, comparación con una variable relacionada (base 100) y, al **hacer clic en un trimestre**, qué lo movió entonces. `LineChart` admite `offset`, series punteadas y clic en un punto.
- Tests: `tests/macro.gd` (nuevo: 40 semillas × 16 turnos sin NaN y acotadas, determinismo de `project`, atribución a una ley, crisis financiera encadenada, medidas extremas); `run_all.sh` lo incluye.

## 2.11.0 — Taller simplificado por ventanas, enmiendas libres, preguntas y respuestas que casan, cupo de 3 iniciativas
- **Taller de leyes simplificado** (`LawsScreen`): el inicio es una mesa con el **cupo del mes** (3 huecos: lo registrado, lo ya tramitado y lo libre) y tres módulos grandes (*Nueva iniciativa*, *Borradores*, *Programa electoral*) que abren su **ventana** encima. Ya no hay tarjetas largas con scroll; el editor de medidas sigue siendo el navegador de áreas → medidas → ficha.
- **Máximo 3 iniciativas parlamentarias al mes, también las del programa electoral** (`GovernmentSim.INITIATIVES_PER_MONTH`). `LawMaker.register` rechaza la cuarta («El cupo se renueva el mes que viene»); retirar una iniciativa devuelve el hueco. Las promesas del programa ya no están exentas.
- **Enmiendas libres del jugador** (`Amendments.make_term`, `value_in_law`, `preview`): en el Pleno, «Redactar una enmienda» abre una ventana donde eliges **cualquier medida de cualquier área** y fijas el valor con el deslizador; ves en directo si te favorece, cómo le sienta al proponente y si la aceptará, negociará (transaccional) o rechazará. Hasta 3 enmiendas por ley (`PLAYER_SLOTS`). Las tres «ideas rápidas» y el botón «Enmendar» por medida de la ley abren la misma ventana ya rellena.
- **Entrevistas, debates y entrevistas: las respuestas casan con la pregunta**. La base de respuestas se etiqueta ahora por **subtipo de pregunta** (una pregunta con subtipo solo recibe respuestas de ese subtipo; sin subtipo, solo respuestas genéricas). Marcos de pregunta (`FRAMES`), artículos y concordancias correctos (`_issue_l`, `_fixup`, `_ideo_name`), y reescritura de textos con erratas o concordancia errónea.
- **Base de datos ampliada**: `data/media/questions.json` (246 preguntas) y `answers.json` (390 respuestas, ≥4 por pregunta y ≥3 estilos por subtipo), más variantes de planes por tema y de datos «trampa».
- Tests: `tests/encounters_match.gd` (nueva: ninguna pregunta sin respuesta compatible), `tests/parliament.gd` (cupo y enmiendas libres), `tests/manifesto.gd` (las promesas gastan cupo), `tests/media_db.gd` (umbrales más altos); `tests/parliament_shots.gd` recorre las nuevas ventanas.

## 2.10.0 — Parlamento rehecho: Taller de iniciativas, enmiendas bidireccionales y Pleno interactivo
- **Pleno interactivo** (`PlenaryScreen`, pantalla de juego): cada iniciativa pasa por *Presentación → Enmiendas → Votación → Resultado*. Columna izquierda con quién la propone (retrato del líder), título, tipo, descripción breve, medidas y efecto previsto; en el centro el **hemiciclo animado** (`ParliamentHall`) con el recuento (`TallyBar`); a la derecha la tramitación de cada fase. **Votas tú primero** (con la previsión sobre el hemiciclo, que puedes ocultar) y después **votan los demás grupos de izquierda a derecha**: los escaños se encienden en ola, el recuento crece, aparece el retrato del grupo con su **explicación de voto** y, al cerrar, cae un sello APROBADA/RECHAZADA con confeti (o temblor si cae). «Saltar animación» disponible. Orden del día previo y resumen de la sesión también en pantalla de juego.
- **Enmiendas en los dos sentidos** (`Amendments`, `m.congress.amend`): antes de votar la **IA enmienda tus leyes** (los afines piden ampliar si se queda corta o suavizar si es abusiva; los lejanos piden cambios a cambio de su apoyo cuando no hay mayorías claras; cada oferta es «mi voto a cambio de esto»: aceptar, contraoferta —solo abstención— o rechazar) y **tú enmiendas las suyas** (2 por ley; el proponente acepta, propone una transaccional o se niega según cuánto necesite tus votos). Los partidos de la IA también se enmiendan entre sí y lo ves en «Pasillos y acuerdos». Lo pactado compromete el voto (`law["committed"]`) y mejora la relación; el registro del trámite se guarda con la ley.
- **Taller de iniciativas** rehecho (pantalla de juego, módulos al estilo D4): inicio con *Presentar una iniciativa* (tres tipos y área), borradores, tu programa como proposiciones, lo registrado (con previsión y botón «Retirar») y una guía del trámite. El **editor reutiliza el navegador de medidas** (`PolicyBrowser`, nuevo modo `law`: *Incluir en la ley / Actualizar / Quitar*, IRPF por tramos incluido) con un panel de **tramitación** a la derecha: tono del texto, qué incluye, visto bueno de los partidos con condiciones aceptables, efectos y *Registrar en el Congreso*.
- **Nuevos tipos de iniciativa** (`LawMaker.KINDS`): proposición de ley, **proposición no de ley** (no cambia medidas; da visibilidad y retrata a quien vota en contra) e **interpelación al Gobierno** (sin votación; resultado por clima político y tono: golpe de efecto / bien debatida / sin pena ni gloria / tiro por la culata). PNL e interpelaciones gastan **acciones de control** (2 al mes), aparte de las iniciativas legislativas. **Tono del texto** (consenso / estándar / bandera) que modifica cómo lo reciben los grupos y las consecuencias si sale. Se puede **retirar** una iniciativa registrada o ante el Pleno y recuperar el cupo.
- **Voto de arrastre**: un grupo dudoso con buena relación contigo se deja llevar por lo que votas tú (se marca «Te sigue»).
- Tests: `tests/parliament.gd` (iniciativas, cupos, tono, ofertas de la IA, propuestas del jugador, IA contra IA, arrastre, PNL, interpelación, retirada, JSON) añadido a `run_all.sh`; `tests/parliament_shots.gd` recorre Taller y Pleno a 1920×1080; auditoría de desbordes a 0 px.

## 2.9.0 — Bandeja rehecha, mesa de negociación única y una IA mucho más dura
- **Bandeja rehecha** (pantalla de juego, sin scroll, estilo D4): tres columnas — *Requieren tu decisión* (solo lo que caduca, con portada del interlocutor y botones de respuesta, paginado de 3 en 3), *Negociaciones y pactos* (mesas recientes con su resultado y pactos vigentes con su estado) y *Novedades* (prensa, consejos y avisos; nacen leídos y **no cuentan como pendientes**). La insignia de la barra superior solo cuenta decisiones reales y la mesa abierta, y se pone ámbar/roja cuando algo caduca. Ya no abruma en campaña y da motivo para entrar fuera de ella.
- **Avisos fuera de la Bandeja**: franja *Asuntos pendientes* en el Resumen (qué caduca, volver a la mesa abierta, abrir la Bandeja) y aviso al pulsar CONTINUAR si algo caduca hoy.
- **Mesa de negociación** (`MeetingScreen`, pantalla única a pantalla completa como los debates): cabecera con el interlocutor, paciencia, ronda, relación y ambiente; *Lo que sabes*, conversación, **la mesa** en dos columnas (lo que tú pones / lo que pone el partido, con marcas «su propuesta», «cambiado», «ultimátum», «última oferta»), lectura de la sala con desglose del balance y menú de condiciones (medidas, leyes, carteras, listas, estabilidad, vetos a terceros). Pie con Presentar mi oferta, Firmar su propuesta, Sondear, Apelar, Presionar y Dejar la mesa.
- **Las reuniones ya no se «celebran solas»**: siempre llegan con la propuesta de la IA sobre la mesa (también las que te piden ellos, que no gastan hueco). Textos reescritos: mesa abierta / mesa cerrada, no «reunión».
- **IA dura y dinámica** (`TableDynamics`): ancla su primera oferta, castiga repetir lo mismo (pierde paciencia), pide contrapartidas nuevas, exige **vetos a terceros** (no apoyar a X) que se cumplen y penalizan a ese partido, acepta o rechaza mods concretos, lanza **ultimátum** y **última oferta** (si no la aceptas, la mesa se rompe), filtra lo negociado y plantea **eventos de mesa** (oferta de un rival, filtración a la prensa, rebelión de las bases, nuevas exigencias) con dilemas que hay que resolver o se ignoran con coste.
- Corregido: aceptar «su propuesta» no se salta ya sus exigencias inegociables.
- Tests: `tests/table.gd`; la auditoría de desbordes mide Bandeja y mesas largas (0 px a 1920×1080); `diplo_shots` espera a la generación del historial.

## 2.8.0 — Menú principal y asistente de partida rehechos, nuevos partidos
- **Menú principal nuevo**: barra superior azul marino (marca PS, sección y botón «Menú principal»), fondo en degradado azul con el mapa de España al fondo, título grande con regla naranja, bloques de menú (Nueva partida, Continuar con resumen de la partida, Cargar, Ajustes, Salir) y tarjeta lateral con el barómetro inicial. Cargar partida y Ajustes usan el mismo estilo de tarjetas.
- **Asistente de nueva partida rehecho** con la misma línea visual: indicador de pasos numerado (los pasos hechos son clicables), pie de navegación fijo (Atrás / aviso / Siguiente o Empezar la campaña), selección de partido en cuadrícula de 4 columnas con filtro (todos, estatales, territoriales), ficha del partido con emblema, indicadores, ejes ideológicos, afinidades y «Tu reto», creación de partido con cartel de color y emblema, ideologías en píldoras con análisis de afinidades, personaje con píldoras y retrato, y resumen final con banner. Sin scroll en ningún paso, ni siquiera en el peor caso (6 ideologías + territorio).
- **Menú de pausa** y ajustes de sonido con el mismo estilo (`UI.menu_block`, `DisplayPanel.build_sound`).
- **Nuevos partidos** (15 en total): **Frente Amplio** (sustituye a Sumar en pantalla; el id interno sigue siendo `sumar` por compatibilidad con guardados y pruebas), **Podemos**, **SALF**, **Adelante Andalucía** (Andalucía) y **Aliança Catalana** (Cataluña). Con ideología completa (20 ejes), color, emblema propio, encuestas de partida (`Rules.BASE_POLL` suma 100), territorio y nombres regionales para los líderes.
- **Pantallas de juego compactadas** para el censo ampliado: Encuestas (ranking de 11 filas y proyección de 10), Gobierno (consejo y socios en dos columnas, compromisos pendientes primero), Resumen e Investidura. Corregido el fallo de «Decisión pendiente», cuyos botones se colapsaban en barras verticales.
- Tests: `tests/party_roster.gd` (plantilla de partidos), `tests/wizard_worst.gd` (peor caso del asistente) y `tests/menu_shot.gd`; `run_all.sh` simula también podemos, salf, adelante y alianca.

## 2.7.0 — Rediseño de la interfaz al estilo Democracy 4
- **Navegador de medidas a pantalla completa (`PolicyBrowser`)**: tres columnas como en Democracy 4. A la izquierda las 18 áreas como bloques verticales (naranja la elegida, azul el resto, icono y contador de medidas cambiadas o prometidas); en el centro las medidas del área con icono (azul disponible, verde cambiada o prometida, ámbar pendiente, gris de solo lectura, triángulo blanco en la elegida); a la derecha la ficha grande. Sin desplazamiento: se comprobó con las 167 medidas en los dos modos (presidente y ministro) y en el programa.
- **Ficha de medida**: título grande, tabla de cifras con filas subrayadas (valor actual, de partida, coste de introducción en capital político, implantación, saldo público), barra de popularidad estimada, **cuadro de efectos estimados** con etiquetas de flecha ▲▼ (votantes e indicadores del país, flecha doble si el efecto es fuerte) y **gráfico de evolución** de 5 años del indicador que más mueve la medida.
- **Deslizador propio (`PolicySlider`)**: pista gruesa con el tramo alcanzable resaltado, marca del valor vigente, muesca dorada en el valor de partida, relleno verde/rojo entre el valor vigente y el propuesto, burbuja con el valor sobre el tirador, muescas por paso y etiquetas de nivel (escalonadas si no caben). Ratón y teclado (← →). Recuadro lateral «Capital político» con el coste de subir o bajar un paso, como en Democracy 4.
- **Programa electoral** y **Medidas de gobierno** usan el navegador a pantalla completa. El programa pierde las tarjetas apiladas: una barra superior con promesas, áreas, impacto fiscal, tirón, línea del partido, tono de campaña, borrador sugerido, vaciar y **Firmar y presentar**; el IRPF por tramos tiene su propia ficha con el editor de escala. En gobierno: barra con capital político, directiva, apoyo y saldo; acciones **Implementar / Forzar / Como ley / Restablecer**.
- **Nueva pantalla «Medidas de gobierno»** (Gobierno → primera pestaña; «Mi ministerio» para ministros). El antiguo Panel en red pasa a llamarse «Mapa de efectos». La ventana emergente `PolicyDialog` es ahora un envoltorio del mismo navegador.
- **Carcasa**: barra superior azul marino, fondo en degradado azul, subbarra clara. Las pantallas «de juego» ocupan todo el área útil (sin panel lateral ni scroll). Tarjetas planas con banda azul de título y esquinas rectas; casillas de indicadores con franja de color.
- **Resumen más limpio**: dos columnas en lugar de tres; las tarjetas vacías (agenda mediática, compromisos, mensajes) ya no ocupan sitio.
- Tests: la auditoría de desbordes mide las pantallas de juego con las 167 medidas; `design_shots` admite `policies:AREA:MEDIDA[:valor]`, `program:AREA:MEDIDA` (con `PHASE=campaign`) y `auditfull`.

## 2.6.0 — Historial del país, ficha de medidas estilo Democracy 4, pactos por leyes e investidura del Rey
- **Historial previo al empezar**: al iniciar partida ya existe una legislatura anterior completa (5 años de datos mensuales —60 meses— de 36 indicadores, paro, PIB, inflación, deuda, déficit y tipos, y 260 semanas de encuestas). En el asistente de partida eliges **Realista** (series reales de España 2018-2023 con ruido y eventos reales como la pandemia o la crisis energética), **Aleatorio** (misma estructura, otra historia) o **Sin historial**. Pantalla de carga con barra de progreso mientras se genera.
- **Nueva pantalla «Análisis»** (País → Análisis): líneas con marcadores de eventos y rango, **áreas apiladas** (votos, gasto, sectores), **columnas anuales**, comparativas por años y modos de normalización (valor, σ, índice 100). Tooltips con el valor exacto.
- **Ficha de medida (`PolicyDialog`)**: ventana a pantalla completa como en Democracy 4 con áreas a la izquierda, medidas del área en el centro y la ficha a la derecha: descripción, valor actual y de partida, coste de capital político, retraso, saldo público, popularidad (barra) con tu configuración y con tu propuesta, a quién afecta y qué indicadores mueve (barras en σ), control (botones o deslizador) y acciones **Decretar / Forzar / Como ley / Restablecer**. Se abre al hacer clic en cualquier medida del Panel de Gobierno o en una baldosa de Cartera. Esc o clic fuera la cierra. Corregido el rótulo «Actual ·actual».
- **Cartera y PGE rediseñada**: sin sliders apilados ni scroll; cada área es una baldosa con icono, número de medidas decretables y cambiadas y tres medidas destacadas; clic abre la ficha completa.
- **Resumen** con franja «Estado del país» (PIB, paro, inflación, déficit, deuda y satisfacción con minigráficas de 5 años) que aprovecha el espacio libre.
- **Investidura del Rey**: se propone primero a la fuerza más votada, después a la segunda; **máximo dos intentos** y, si ambos fracasan, se disuelven las Cortes y hay elecciones. Se elimina la posibilidad de elegir candidato a voluntad; la pantalla muestra la cadena de intentos (en curso / fracasó / si falla el primero).
- **Grupo minoritario**: cuando el candidato es de la IA y necesita tus escaños, te llega a la Bandeja una **oferta de investidura** (voto a cambio de una medida de tu prioridad y, si tu fuerza es decisiva, una cartera). Puedes aceptarla, rechazarla o **poner tus condiciones** en una reunión.
- **Pacto por una ley (nuevo tema de negociación)**: eliges una ley tuya (borrador o registrada) y negocias con un grupo su voto o abstención. Puedes **aceptar sus enmiendas** (suavizar, retirar o añadir medidas), ofrecer un **favor de voto** (te comprometes a votar una ley suya), leyes juntos, una prioridad temática o una cartera. La IA responde con contraofertas de enmiendas. Si se firma, el partido **vota lo pactado** y el pacto aparece en Negociación (cumplido o roto). Los favores se cobran en el Pleno: saldarlo mejora la relación; incumplirlo la daña y resta confianza.
- **La IA también propone cambios**: los partidos que no votarían tu ley tal cual te envían a la Bandeja una propuesta con las enmiendas que exigen (aceptar tal cual o reunirse).
- **Pruebas**: `tests/law_deals.gd` y `tests/history.gd` entran en `run_all.sh` junto a `tests/diplomacy.gd`; capturas nuevas en `design_shots.gd` (`dialog:<medida>[:valor]`, `ministry:<n>`) y `diplo_shots.gd`.

## 2.5.0 — Panel de Gobierno en red, 167 medidas y 36 indicadores enlazados
- **Acceso por cargo**: en la **oposición** no hay panel de Gobierno ni cartera (gobierna la IA y solo ves sus decretos en las noticias); como **presidente** gestionas todo el Gobierno; como **ministro** de una coalición o minoría solo editas las áreas de tu cartera (el resto se ve en gris). Los ministerios que no controlas los lleva la IA y aprueban decretos según la ideología de su partido y las necesidades del país.
- **Panel de Gobierno (nueva pantalla «Panel»)**, inspirado en Democracy 4: red de burbujas con las medidas en el anillo exterior por áreas, los indicadores en el medio, los grupos sociales dentro y la aprobación en el centro. Al pasar el ratón aparecen las relaciones (verde = mejora, rojo = empeora, azul = efecto de segundo orden); al hacer clic se abre la ficha con controles, vista previa de efectos y retraso. Clic en un área para ampliarla.
- **Aplicación híbrida**: dentro de tu competencia puedes **decretar** (cuesta capital político y tarda en notarse); las leyes orgánicas, los impuestos y las grandes reformas pasan por el Congreso (botón «Llevar al Congreso» abre el Taller de leyes con la medida ya cargada).
- **Nuevo motor de indicadores (`WorldSim`)**: 36 indicadores (precios de la vivienda, consumo, deuda, desigualdad, innovación, migración, confianza, polarización, tensión territorial, renta agraria, retrasos judiciales…) conectados en red. Cada uno se acerca a su objetivo con inercia, según las medidas aplicadas y los demás indicadores, y realimenta crecimiento, paro e inflación y el ánimo de los grupos (`data/scenarios/spain/world.json`).
- **Pantalla «Indicadores»**: mosaico con miniaturas de tendencia, gráfico interactivo (1 año, 2 años, 5 años o todo; cursor con valor), comparación de varios indicadores, «¿Qué lo mueve?», medidas que influyen y a quién afecta.
- **167 medidas en 18 áreas** (antes ~90 en 9): vivienda, indirectos, impuestos, sanidad, educación, empleo, energía, transporte, agricultura, seguridad, defensa, inmigración, justicia, territorio, social, familia, ciencia e industria. Generadas con `tools/gen_policies.py`.
- **Programa electoral**: las 18 áreas se muestran como píldoras de color con el número de promesas (sin desplazamiento).
- **Gráficos**: el gráfico de líneas admite cursor con tooltip, línea de referencia y formato por serie.
- **Pruebas**: `tests/world.gd` (estabilidad, causalidad, guardado), `tests/roles.gd` (roles, ministros IA, áreas) y comprobación de `policies.json`/`world.json` en `check_dataset.py`; ambos entran en `run_all.sh`.

## 2.4.0 — IA de votantes, militancia con líneas rojas y encuestas vivas
- **Plató más jugable**: más tiempo para leer (tele 26 s, radio 22 s, pódcast 32 s, rueda 24 s, debate 20 s, sesión de control 22 s) y botón **Abandonar** en cualquier formato (entrevista, debate, rueda…). Pide confirmación y se paga: las preguntas sin responder cuentan como fallos, cae la confianza, se resienten honradez/liderazgo/competencia y se pierden décimas en las encuestas. El titular del día siguiente habla de «plantón».
- **Nuevo motor de votantes (`Electorate`, `data/scenarios/spain/electorate.json`)**: el electorado son 12 arquetipos sociales (progresistas urbanos, jóvenes precarios, pensionistas conservadores, mundo rural…) repartidos por bloques territoriales. Cada grupo tiene sus **ideas en tres ejes** (economía, valores, territorio), los temas que le importan, **fidelidad** a los partidos que votó, **enfado** y **simpatía** hacia cada uno y **ánimo** con el Gobierno. La intención de voto ya no es un número que se empuja: sale de lo que decide cada grupo (modelo probabilístico), con un 5 % que se va a «otros».
- **Reacciones**: leyes que se aprueban, pactos, promesas incumplidas, eventos territoriales, mítines y debates mueven a cada grupo según le favorezcan o le perjudiquen. Los de izquierdas se enfadan si apruebas algo que los daña, pero **no todos se van**: cada uno piensa por sí mismo. Las medidas de la IA también cuentan (premian o castigan a quien las propone y a sus socios) y existe un efecto termostato (el electorado corrige el giro de la política).
- **Tendencias globales** (giro a la derecha, ola progresista, desafección, preocupación climática, tensión territorial, polarización): van y vienen solas, con giros bruscos ocasionales, y desplazan ideas, temas y participación de los votantes. Con polarización crece el voto a los extremos.
- **Abstención**: la participación depende de la alienación (lejanía a todos los partidos), el enfado, el hartazgo y la movilización. Reduce o aumenta los escaños de cada partido (el voto se pondera por participación) y se muestra en el nuevo panel.
- **Trasvase de votos**: se compara con las últimas elecciones y se muestra de dónde a dónde se mueven los votos (incluida la abstención). Llegan noticias cuando hay un movimiento importante y se puede intentar recuperar a los que se fueron.
- **Encuestas dinámicas**: una encuesta por semana (cuatro al mes en la legislatura, una por día en campaña), con ruido de las casas demoscópicas, momentos virales y escándalos, y mucha más oscilación para los partidos pequeños (que pueden colarse en el Congreso). **El favorito puede perder la campaña** y el día D añade un último giro de indecisos y error sistemático de las encuestas. El gráfico muestra fechas («jul 23»), línea punteada «ahora» y selector 6 meses / 1 año / todo; la tendencia es de 7 días en campaña y 30 después.
- **Militancia (`Militancy`)**: cuatro corrientes internas (doctrina, valores, territorios y aparato) valoran lo que haces según su eje. El partido fija **líneas rojas** (no pactar con el más lejano, no legislar contra el rumbo del partido, cumplir el programa, no hundirse en las encuestas). Si cruzas una te lanza un **ultimátum** en la Bandeja (rectificar, reunirte a cambio de dinero o mantenerte). Si la corriente no se calma **retira su apoyo**: se van afiliados, bajan ingresos y confianza y caen los sondeos; si todas se rebelan, hay crisis de liderazgo.
- **Pantallas nuevas**: «Electorado» (participación, grupos de votantes, tendencias, trasvase, tu electorado y quién está enfadado contigo) en el bloque Opinión, y «Militancia» junto a Finanzas en el nuevo bloque Partido.
- **Pruebas**: `tests/electorate.gd` (calibración, reacciones, abstención, dinámica en 36 meses, guardado), `tests/militancy.gd`, `tests/voters_shots.gd` y `tests/abandon_shot.gd`; ambos tests nuevos entran en `run_all.sh`.

## 2.3.0 — Plató de medios, agenda mediática y noche electoral renovada
- **Menú de pausa con Esc** (también durante la noche electoral y en el plató): Continuar, Guardar, Ajustes (sonido, volumen, pantalla), Volver al menú principal y Salir del juego, con confirmación. Los botones Sonido/Pantalla/Guardar/Menú ya no están en la barra superior.
- **Plató de medios (pantalla nueva a pantalla completa)** para debates, entrevistas de tele y radio, pódcast, ruedas de prensa y sesión de control, cada uno con su decorado. Las preguntas salen una a una como un **minijuego**: cuenta atrás, medidor de audiencia (bronca ↔ ovación), racha de aciertos, **asesor comodín**, réplicas/interrupciones del rival en debates y ruedas de prensa, reacciones en redes en directo y balance final con titular del día siguiente. Teclas 1-4 para responder, Espacio para seguir, A para el asesor. Nuevo tipo de acto **Pódcast** en la agenda de campaña.
- **Banco de medios (`data/media/*.json` + `MediaDB`)**: ~200 preguntas y plantillas con etiquetas por formato (debate, tele, radio, pódcast, rueda) y por papel (Gobierno/oposición), variantes de respuesta, reacciones del presentador, mensajes de redes, intros y cierres. Se mezclan con el generador anterior y con preguntas dinámicas (apoyo al Gobierno, estabilidad, déficit, deuda, leyes aprobadas, hemeroteca…). **Nunca se repite una pregunta ni una respuesta hasta agotar el banco** (memoria por contenido).
- **Agenda mediática fuera de campaña**: cada mes llegan ofertas de los medios (sesión de control, comparecencia urgente si el Gobierno flaquea o estalla una crisis, pódcast, entrevista de balance, debate sobre el estado de la nación). Tienes 3 huecos al mes; puedes ir al plató, delegar en el portavoz (gratis, rinde menos) o declinar (una comparecencia urgente ignorada cuesta apoyo). Llegan a la Bandeja como decisiones y al Resumen en una tarjeta propia. En la oposición la sesión de control te toca preguntar tú. El resultado mueve el apoyo al Gobierno y tu imagen.
- **Noche electoral**: arranque automático (basta con un Play, o ninguno), columna de partidos con **escaños y % de voto a la vez** y variaciones, **barra fija «Carrera a la mayoría»** (izquierda / derecha / primer partido frente a los 176) y aviso de **cambio de líder**.
- **Pruebas**: `tests/media_db.gd`, `tests/pause_menu.gd`, `tests/media_shots.gd`; `ui_flow` juega el plató; `encounters.gd` incluido en `run_all.sh`.

## 2.2.0 — Sin scroll: toda la información en pantalla a 1920×1080
- **Ninguna pantalla necesita la rueda del ratón para llegar a un botón.** Se rediseñaron las pantallas a 1920×1080 (base de la interfaz, antes 1600×900) con columnas, listas «maestro/detalle» y paginación en lugar de listas largas.
- **Asistente de Nueva partida**: cuerpo con su propio marco y botones «Atrás/Siguiente» **fijos abajo**; el paso de Partido se reparte en rejilla + ficha, y el de Personaje en tres columnas.
- **Partidos y Negociación**: lista a la izquierda y ficha del partido seleccionado a la derecha (pactos incluidos).
- **Resumen, Economía, Gabinete**: tres columnas / rejillas de dos columnas; **Bandeja** paginada (9 por página).
- **Programa electoral y Taller de leyes**: medidas en rejilla de 2 columnas; reacciones y tono de campaña en columna lateral; el **IRPF por tramos** se resume en una fila y se edita en una vista propia («Editar la escala» / «← Medidas del área»), con hasta 10 tramos en dos columnas.
- Los subtítulos de las tarjetas se recortan con «…» (con la frase completa al pasar el ratón) para no ensanchar columnas; textos de opciones largas del personaje acortados.
- Fuente base 14 px (antes 13) y espaciados más compactos.
- **Pruebas**: `tests/overflow_audit.gd` (altura y anchura de todas las pantallas por fase y por partido), `tests/overflow_hidden.gd` (cartera, presupuestos, reuniones y editor de leyes por área) y `tests/wizard_shots.gd` (asistente). Se estabiliza una comprobación del Taller de leyes que fallaba de forma intermitente.

## 2.1.0 — Pantalla nítida a 1920×1080, IRPF por tramos y promesas convertidas en proposiciones de ley
**Pantalla**
- Los textos borrosos venían de la fuente de reserva de Godot y del negrita sintético: ahora el juego incluye **Inter** (licencia OFL, en `assets/fonts/`) y la usa en toda la interfaz, gráficos incluidos.
- Resolución elegible en Ajustes y en el botón «Pantalla» (1280×720, 1600×900, **1920×1080** por defecto, 2560×1440), además de pantalla completa (F11 / Alt+Enter) y escala de interfaz.

**Programa electoral**
- **Hasta 7 promesas por área y sin límite general.**
- **IRPF por tramos**: nuevo editor (`IrpfEditor`) para añadir o quitar tramos y fijar, en cada uno, desde qué renta (miles de €) y qué porcentaje marginal se aplica. Se usa en el programa y en el Taller de leyes. Calcula tipo medio, tipo máximo, recaudación y reacción de cada colectivo (`Irpf`, `scripts/core/irpf.gd`). Sustituye a las antiguas medidas «tipo general» y «tipo máximo».
- **Cada promesa es una proposición de ley**: al formarse la legislatura el Taller de leyes recibe un borrador por promesa, con los valores del programa (el IRPF, con sus tramos). Se registran en el Congreso sin gastar las iniciativas del mes («Registrar todas las pendientes»); si el Pleno rechaza una, se redacta de nuevo.
- **Decepción de los votantes**: a partir del mes 4 se compara lo prometido con lo esperado (todo cumplido hacia el mes 36). Si te retrasas, la promesa se marca «con retraso», baja la confianza cada mes y el partido pierde puntos en las encuestas; en la oposición cuenta haberlas llevado al Congreso. Al convocarse elecciones se pasa factura final por el incumplimiento.
- Pantalla de seguimiento con decepción acumulada, estado de cada proposición (sin registrar, en el Congreso, rechazada, cumplida) y avisos en la bandeja.

**Pruebas**: nuevo `tests/irpf.gd`; `tests/manifesto.gd` cubre límites, IRPF, proposiciones y decepción; `tests/program_shots.gd` genera capturas a 1920×1080.

## 2.0.0 — Rediseño: menú tipo Democracy 4, programa electoral obligatorio y negociaciones exigentes
**Interfaz**
- Nuevo marco: barra superior con **bloques** (Resumen · Campaña · Opinión · País · Bandeja · Finanzas; en legislatura Gobierno · Parlamento…) y **subpestañas** debajo, en lugar de la barra lateral. Botón verde de CONTINUAR siempre visible arriba a la derecha.
- **Pantalla completa**: nuevo `DisplayManager` (F11 o Alt+Enter). El factor de escala se ajusta al tamaño real de la ventana y nunca baja de 1280×720 virtuales, lo que arregla el reescalado al cambiar de ventana a pantalla completa. Escala de interfaz ajustable en Ajustes.

**País con datos reales**
- Los datos de partida se acercan a España: PIB 1.462 bn €, gasto público ≈44,5 % del PIB (con intereses), ingresos ≈41 %, déficit ≈3,6 % y deuda ≈107 %. Tarjeta «El país hoy» en el Resumen de campaña.

**Programa electoral obligatorio y dinámico** (`Manifesto`, `m.manifesto`)
- Al empezar **cada campaña** debes redactar y **firmar** un programa antes de poder continuar (el botón superior pasa a «REDACTAR EL PROGRAMA»).
- Se hace **por áreas**: dentro de cada una añades medidas concretas y el valor que prometes (5–12 promesas, mínimo 3 áreas, máximo 3 por área). Muestra impacto fiscal, tirón electoral, reacción de cada colectivo y qué promesas chocan con tu ideología. «Borrador sugerido» propone uno coherente con tu partido.
- Los votantes lo tienen en cuenta: el programa mueve las encuestas a diario en campaña. Si gobiernas, cada mes se compara lo prometido con lo hecho (confianza) y al convocarse nuevas elecciones se evalúa el cumplimiento medio. Nueva pestaña **Programa electoral** en Gobierno con el seguimiento.

**Negociaciones exigentes**
- Las peticiones de la IA son **medidas concretas** del catálogo («Tope al alquiler: Tope general (IPC+)»), elegidas según su ideología.
- Cada partido tiene una **exigencia inegociable**: sin ella no firma ningún apoyo, por mucho que ofrezcas; los más rígidos tienen dos. El resto de peticiones son negociables. Tarjeta «Qué exige…» en cada reunión.
- Existen **líneas rojas**: si le pides una medida que va contra su ideología, la rechaza de plano.
- Los pactos con medida concreta se dan por cumplidos cuando esa medida alcanza el valor acordado. Ceder en algo contrario a tu línea cuesta confianza ante tu electorado.

## 1.5.0 — Núcleo ministerial: gobierna desde dentro
**Tu cartera**
- Si tu partido gobierna eres **Presidente**; si eres socio de Gobierno eliges **tu cartera** en el Consejo de Ministros («Quedarme esta cartera»). El resto de ministerios los lleva la IA.
- Nueva pantalla **Mi cartera** (`MinistryScreen`): el ministro gestiona su ministerio; el presidente puede cambiar entre todos los ministerios con competencias y, además, tiene la pestaña de Presupuestos.

**Competencias por ministerio** (`Executive`, `m.exec`)
- Al formar Gobierno, las 9 áreas de política y las 15 partidas del presupuesto se reparten según las carteras que existan (con 8 ministerios unos acumulan más; con 18 cada área tiene su titular). El Consejo muestra las competencias de cada cartera.

**Decretos sin Congreso**
- Dentro de tu competencia puedes cambiar medidas con un decreto (cambio máximo de un tercio del rango). La fiscalidad y las leyes orgánicas siguen exigiendo ley.
- Cada decreto cuesta **capital político** (se regenera cada mes según el apoyo al Gobierno) y necesita el **consenso**: el ministro si eres presidente, el presidente si eres ministro. Si se opone, puedes forzarlo pagando más capital y perjudicando la relación.
- Los efectos son los del motor económico y social: afectan a todo el país y a los grupos sociales, con vista previa antes de decretar.
- Si decretas algo contrario a tu ideología, bajan la confianza y la intención de voto, y tus votantes lo reprochan en la bandeja.
- Los ministros de la IA adoptan decretos acordes con su partido (órdenes ministeriales).

**Presupuestos Generales del Estado**
- Cada año (meses 3, 15, 27 y 39) se elaboran los PGE. Como presidente ajustas las dotaciones por partida, ves los apoyos previstos y los presentas; el Congreso los vota en el Pleno. Si caen, se **prorrogan** los anteriores y el Gobierno pierde estabilidad. Si gobierna la IA, sus Presupuestos recogen su ideología y las peticiones de tu ministerio.
- La dotación aprobada cambia el gasto de cada partida y, con el tiempo, la calidad del servicio asociado. Como ministro puedes pedir más dotación y, durante el año, mover el crédito de tus partidas ±2,5 % por decreto.

**Directiva del partido**
- Te fija objetivos (apoyo al Gobierno y déficit si presides; el indicador de cada área si eres ministro). Se evalúan cada 12 meses: cumplirlos da confianza y capital; incumplirlos te la quita. Con menos de 20 de confianza te cesan como ministro o hay crisis de liderazgo si presides.

## 1.4.1 — Corrección de texto borroso/deformado
- Se retiran los ajustes de fuente de 1.4.0 (hinting desactivado, posicionado subpíxel, mipmaps y antialiasing LCD) que en algunos equipos Windows deformaban el texto pequeño (letras con huecos o mal espaciadas). Vuelven los valores por defecto de Godot.
- Se mantiene el suavizado MSAA 2x en el dibujo 2D (mapa, retratos y gráficas) y la ventana base de 1600×900 con escalado `canvas_items`.

## 1.4.0 — Fase 2: motor legislativo, económico y social
**Correcciones**
- Si creabas un partido nuevo no aparecía en el panel de encuestas: ahora el panel muestra el top 7 con su puesto y, si estás fuera, añade tu partido con su posición real (también en Encuestas y en las gráficas).
- Nitidez: antialiasing 2D (MSAA), hinting/posicionado subpíxel de fuentes, mipmaps y ventana base de 1600×900 para que el exportado no se vea borroso.

**Taller de leyes** (`LawsScreen`, `LawMaker`)
- Crea leyes a medida en 9 áreas (vivienda, fiscalidad, sanidad, educación, empleo, energía, seguridad, territorio y protección social) con 59 medidas al estilo Democracy 4: topes de alquiler, impuesto a la primera vivienda, recargos a vacías, inversión pública, etc.
- Cada medida tiene niveles o deslizador y se ve el coste/ingreso, el efecto en servicios y la reacción de los grupos sociales antes de registrar.
- Cuantas más medidas incluyas, más condiciones plantean los partidos (suavizar, retirar o añadir demandas). Puedes aceptarlas para ganar apoyos (buena voluntad).
- Consulta previa a cada partido con su voto previsto según su ideología y la de la ley. Las leyes de competencias, lengua, penal, inmigración y vigilancia son orgánicas (176 síes).

**Pleno animado** (`PlenaryScreen`, `Congress`)
- Cada mes se votan todas las iniciativas (tuyas, del Gobierno y de los grupos), una a una. El hemiciclo se ilumina grupo a grupo (verde a favor, rojo en contra, gris abstención) y tú decides a favor, en contra o abstención cuando llega tu turno; la IA vota por ideología.
- En la oposición solo registras leyes y votas; en el Gobierno además gobiernas con decretos del Consejo. El botón de cabecera pasa a «IR AL PLENO (n)».
- Votar contra tu ideología resta confianza; coherencia la sube.

**Motor económico y social** (`EconomySim`, `Policies`)
- Presupuesto con 15 áreas de gasto y 7 impuestos, deuda e intereses, PIB nominal, crecimiento, paro e inflación con retardos.
- 8 servicios/calidad de vida (sanidad, educación, vivienda, seguridad, medio ambiente, igualdad, infraestructuras, innovación) y 10 grupos sociales con su satisfacción y los factores que la mueven.
- Las leyes aprobadas cambian de verdad la recaudación, el gasto y la sociedad; el apoyo al Gobierno depende ahora de la satisfacción media.

**Pantallas nuevas**: Economía (PIB, composición por sectores y demanda, cuentas públicas, gasto por ministerio, ingresos, gráficas de evolución y déficit/deuda) y Sociedad (grupos, servicios y su evolución).

**Ministros** (`Ministers`)
- Cada cartera tiene titular con competencia y especialidad. Eliges los de tu partido entre una cantera; en coalición la IA elige los suyos. Un buen ministro mejora el área que gestiona.

**Pruebas**: `tests/legislature.gd` (economía, leyes, votaciones, ministros), `sim_full_game.gd` y `ui_flow.gd` adaptados, capturas de las pantallas nuevas en `ui_shots.gd`.

## 1.3.1 — Asistente corregido, más ideologías y partidos territoriales
**Corrección**
- El botón «Siguiente» del asistente de nueva partida se quedaba desactivado aunque ya hubieras escrito nombre y apellidos (el estado del botón solo se calculaba al abrir el paso). Ahora se recalcula al escribir y al cambiar cualquier opción, y el aviso desaparece solo.

**Ideologías**
- Nombres claros: Liberalismo, Socialismo, Progresismo, Regionalismo.
- Nuevas: Liberalismo social, Liberal-conservadurismo, Populismo de izquierdas, Ecosocialismo, Laborismo y sindicalismo, Tecnocracia, Pacifismo, Euroescepticismo y Ruralismo (más sus incompatibilidades).

**Partidos territoriales**
- Si eliges **Regionalismo** o **Independentismo** en un partido propio, el asistente te pide la comunidad autónoma donde te presentas (obligatorio).
- Solo presentas candidatura en esa comunidad: no obtienes escaños fuera, y tu intención de voto nacional parte de ~7 % local × el peso de la comunidad en el censo.
- En el Mapa aparece **Implantación territorial**: pagas para presentarte en otras comunidades (80.000 € + 1,5 M€ × su peso en el censo; arranque local modesto). Al cubrirlas todas pasas a ser un partido estatal.
- Pruebas nuevas: `tests/territory.gd`, ampliaciones de `tests/wizard.gd` y `sim_full_game.gd regional`.

## 1.3.0 — Interfaz clara, ideologías, personaje y prensa viva
**Interfaz** (solo visual, sin cambios de mecánica)
- Nuevo tema claro al estilo de los juegos de gestión: fondo gris azulado, tarjetas blancas con sombra suave, barra lateral oscura, cabecera blanca y panel derecho blanco. Paleta centralizada en `UI`.
- Menú de inicio, mapa, gráficas y modales adaptados. La noche electoral mantiene su estética de plató.
- Los líderes aparecen en la barra lateral, en las tarjetas de negociación y en la cabecera de cada reunión.

**Sistema de ideologías** (`Ideology`)
- Catálogo de 23 ideologías (economía, valores, identidad). Cada una tiene ejes y perfil propios.
- Eliges ideologías y les das **fuerza (1–5)** con un presupuesto de 14 puntos y un máximo de 6; la mezcla calcula tus tres ejes, tu perfil de 20 dimensiones, tu **coherencia interna** (las ideologías incompatibles la reducen) y una etiqueta de bloque.
- La afinidad con cada partido sale de esa mezcla y se ve en vivo mientras la montas.
- **Fidelidad de la IA**: puertas ideológicas. Blocs opuestos no pactan candidaturas conjuntas, gabinete ni estabilidad (PSOE–Vox: afinidad 0,00); la reunión ni siquiera se abre y la tarjeta muestra el veto.

**Nueva partida** (`NewGameWizard`)
- Asistente de pasos: Partido → Identidad → Ideología → Personaje → Resumen.
- Selección de partido con tarjetas (bloque, ideologías principales, dificultad), ficha con aliados e incompatibles; creación de partido propio con nombre, siglas, lema, color y símbolo.

**Personaje** (`Leader`, `LeaderPortrait`)
- Líder caricaturesco dibujado por código: piel, pelo y color, cara, ojos, cejas, nariz, boca, vello, gafas, atuendo, rasgo exagerado y edad aparente; cinco estados de ánimo.
- Oficio, rasgo vital y seis atributos (carisma, oratoria, honestidad, experiencia, mano izquierda, firmeza) con 12 puntos a repartir. Los líderes de la IA se generan por partido.
- Para usar tus propias imágenes: `res://assets/portraits/<clave>.png` (`player`, `pp`, `psoe`…).

**Prensa y reuniones variables** (`Encounters`)
- Preguntas compuestas con piezas (medio, periodista y su talante, tema, gancho con cifras, tipo de pregunta, estilo de respuesta). 9 tipos: política, coste, rival, pacto, escándalo, personal, crisis, trampa y hemeroteca. Memoria de lo ya preguntado para no repetirse.
- Doce estilos de respuesta; las respuestas con plan (izquierda/derecha/consenso) se miden contra tu ideología. Si respondes algo incoherente, se nota.
- **Efectos reales**: imagen pública (competencia, honradez, cercanía, liderazgo, sintonía), opinión por seis segmentos, confianza, visibilidad, impulso, encuestas, relaciones con partidos y memoria de lo dicho. Los atributos del líder cambian la calidad de las respuestas.
- Si te contradices, la prensa te lo recuerda más adelante (hemeroteca). Atacar a un rival provoca réplica días después.
- Las preguntas también llegan a la **bandeja** con opciones de respuesta; tras cada reunión puede haber incidentes (filtración, rumor, pulso público…).
- La diplomacia usa tus atributos, la imagen y lo que dijiste en público: aperturas, tono y paciencia cambian; los textos de reunión son más variados.

**Pruebas**: `tests/ideology.gd`, `tests/wizard.gd`, `tests/wizard_shots.gd`, `tests/portrait_shots.gd`, `tests/encounters.gd`.

## 1.2.0 — Diplomacia, IA de partidos, mapa real y sonido
**Bandeja**
- Mensajes con tipo (acción, negociación, prensa, asesor, sistema), clave de sustitución y caducidad: ya no se acumulan avisos repetidos al saltar días.
- Nueva bandeja con pestañas (Pendientes, Negociación, Prensa, Asesor, Todos) y contadores, agrupada por fecha, con mensajes idénticos colapsados (×N) y acciones directas.
- CONTINUAR solo se detiene ante mensajes urgentes nuevos. Los avisos emergentes (máx. 3) se fusionan con contador y se colocan fuera de la columna derecha.

**IA de partidos** (`PartyBrain`)
- Cada partido tiene ideología en 3 ejes y perfil de 20 dimensiones, postura y prioridad por tema, rasgos (pragmatismo, agresividad, rigidez, ambición, lealtad, territorialismo, aversión al riesgo), líneas rojas, memoria de favores y agravios, y disposición hacia ti.
- Evalúa ofertas (utilidad frente a necesidad) con veredicto aceptar / contraoferta / rechazar / veto, explica sus factores y contraofertas sin romper el apoyo de voto.
- Toma la iniciativa: propone pactos y reuniones durante campaña y legislatura.

**Negociación por reuniones** (`Diplomacy`)
- Pantalla *Negociación* (partidos, disposición, pactos activos) y pantalla de *Reunión* (conversación, mesa de términos, sondeo "lectura de la sala", apelar, presionar, levantarse; 5 rondas, paciencia 3).
- Temas: investidura, coalición, listas conjuntas, pacto preelectoral, leyes, estabilidad y relación. Máximo 3 reuniones por periodo y 1 por partido.
- Pactos con estado (activo, cumplido, roto, caducado); cumplirlos mejora la relación y romperlos la daña. Los acuerdos se aplican a la investidura, a las listas conjuntas (bonus en encuestas) y a las votaciones de leyes.

**Investidura renovada**: pasos, barra de votos con la línea de 176, siguiente paso sugerido, tabla de grupos con botón *Reunirse* y vista de socio.

**Mapa real de España**: provincias a partir de límites oficiales simplificados (`tools/build_map.py`), varios anillos por provincia (islas), recuadro de Canarias y marcadores para Ceuta y Melilla. Geometría triangulada una vez y dibujada como malla.

**Sonido**: efectos sintetizados en código (`Sfx`): clic, página, aviso, confirmar, rechazo, alerta de vuelco, mazo, fanfarria. Interruptor en el menú lateral; ajuste guardado en `user://settings.cfg`.

**Interfaz**: panel derecho más ancho, mapa electoral más grande y botón de sonido.

**Pruebas**: `tests/diplomacy.gd`, `tests/diplo_shots.gd`.

## 1.1.0 — Noche electoral en directo
Retransmisión a pantalla completa inspirada en la experiencia de objetivo176.es/generales.
- **Motor** (`ElectionSim`): escrutinio por cortes (0–90) con curva propia por provincia, voto parcial con sesgo inicial y escaños provisionales recalculados con D'Hondt en cada corte. Sondeo a pie de urna con horquillas, detección de vuelcos (frente a la legislatura anterior o a la encuesta), provincias en juego, `skip_night()` y `snapshot()`.
- **Retransmisión** (`NightBroadcast`): barra de última hora con titulares y teletipo, panel lateral con ESCRUTADO %, filas animadas y variaciones, reloj de la noche y controles (reproducir/pausa, velocidad, saltar, cierre) con atajos de teclado.
- **Escenas**: antes del cierre, sondeo, resultados, mapa (escaños/votos), hemiciclo con esferas y línea de 176, "En juego", evolución del escrutinio y "Tú eliges" (comunidades y provincias); modo AUTO que rota las escenas.
- **Eventos**: píldoras de vuelco/recupera, cartel de mayoría y cartel final con acceso directo a resultados.
- La pantalla de noche abre la retransmisión automáticamente (no en modo headless).
- Pruebas nuevas: `tests/night_engine.gd` y `tests/night_shots.gd`; `ui_flow`, `ui_shots` y `sim_full_game` adaptadas.

## 1.0.0 — Rediseño completo
**Arquitectura**
- Núcleo sin interfaz: `Rules`, `DataStore`, `GameModel` y subsistemas `AIDirector`, `CampaignSim`, `ElectionSim`, `GovernmentSim`.
- Capa de interfaz nueva: `UI` (diseño), widgets (`MeterBar`, `LineChart`, `Hemicycle`, `SpainMap`, `PartyEmblem`), `Shell` y 13 pantallas.
- Estado único en `GameModel.s`, esquema de guardado 3 con migración desde 0.8/0.9.

**Jugabilidad**
- Botón CONTINUAR contextual por fase; avance inteligente hasta el próximo evento o mensaje.
- Encuestas multipartido con tendencias; programa de hasta seis compromisos y tono de campaña.
- Agenda: ocho tipos de acto, entrevistas jugables, delegación, reembolso al cancelar.
- Investidura: vetos por afinidad, concesiones, rol (apoyo externo/cartera), segunda votación, disolución tras tres intentos.
- Consejo de Ministros editable (8–18 carteras) con reparto proporcional inicial.
- Legislatura: apoyo, estabilidad, economía, satisfacción de socios, compromisos, leyes y acciones de oposición.

**Errores corregidos respecto a 0.9.2**
- Error al iniciar la escena principal (`remove_child` con el padre ocupado).
- Las encuestas no sumaban 100 tras ciertos eventos; ahora se normalizan en cada cambio.
- Votos a favor/en contra de la investidura inconsistentes con el estado de los pactos.
- Presupuesto desbalanceado (ingresos/gastos y subvención por voto).
- Guardado no atómico: ahora se escribe a fichero temporal, se renombra y se conserva `.bak`.
- Fechas y calendario de campaña desincronizados con el reloj de la partida.
