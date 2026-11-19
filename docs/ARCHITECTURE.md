# Arquitectura

```
scripts/
  core/      lógica de juego (sin nodos)      rules, data_store, save_manager (autoload), game_model,
                                              ai_director, campaign_sim, election_sim, election_engine, government_sim
  ui/        presentación                      ui.gd (diseño), screen.gd (base), shell.gd (carcasa)
    widgets/ controles dibujados a mano        meter_bar, line_chart, hemicycle, spain_map, party_emblem
    screens/ una pantalla por archivo          home, inbox, agenda, program, polls, map, finance, night,
                                              results, investiture, cabinet, government, parties
  startup/   menú de inicio, creador de partido, partidas, ajustes
```
**Reglas**
- La interfaz solo lee `GameModel` y llama a sus subsistemas; los subsistemas no conocen la interfaz.
- Todo el estado vive en `GameModel.s` (`save["game_state"]`) y es serializable a JSON (`d()`/`a()` crean diccionarios/listas persistentes).
- Tras JSON los enteros vuelven como `float`: convierte con `int()`/`float()` al leer.
- Fases: `campaign → election_night → results → investiture → cabinet_design → legislature → campaign (nuevo ciclo)`.
- La `Shell` decide qué pantallas ofrece cada fase (`NAV_BY_PHASE`) y qué hace el botón CONTINUAR.
- Las pantallas heredan de `Screen`, implementan `build()` y se reconstruyen con `shell.refresh()`.

## Cómo añadir una pantalla
1. Crea `scripts/ui/screens/mi_screen.gd` con `extends Screen` y `func build()`.
2. Regístrala en `Shell.SCREENS`, `NAV_LABELS` y `NAV_BY_PHASE`.
3. Añade una captura en `tests/ui_shots.gd` si procede.


## Noche electoral (1.1.0)
- `ElectionSim` guarda en `m.s` la curva de escrutinio (`election_curve`), el corte actual (`election_tick`, 0..`CUTS`=90), el historial de cortes (`election_cuts`) y la línea base para detectar vuelcos (`election_baseline`). `advance_night(n)` avanza y devuelve los eventos; `snapshot(t)` calcula votos/escaños provisionales sin mutar el estado.
- `NightScreen` es la página de aterrizaje; `open_broadcast()` monta `NightBroadcast` (overlay a pantalla completa) con `NightTopBar`, `NightPanel`, escenas (`NightScene`: `NightHemicycle`, `NightMap`, etc.) y barra de control `NightButton`.
- `TV` reúne paleta, texto, formato español y segmentos enriquecidos (chips de partido) compartidos por los widgets.


## Diplomacia e IA de partidos (1.2.0)
- `PartyBrain` (`m.brain`): ideología, rasgos (`ai_profiles[id]`), líneas rojas, disposición, `assess()` (utilidad vs necesidad), `counter()` e `initiative()`.
- `Diplomacy` (`m.diplomacy`): reuniones en `m.s["meeting"]` (5 rondas, paciencia 3), términos `{k, by, ...}` (vote_yes, vote_abstain, cabinet, policy, bills, joint_list, stability, cordon), pactos en `m.a("pacts")`. Se sincroniza con las ofertas de investidura (`gov.offers()`), listas conjuntas (`joint_list_tick`) y leyes (`bill_ally`).
- `TableDynamics` (`m.diplomacy.dyn`): agenda de la IA (`agenda_for`), vetos a terceros (`cordon_demand`), dureza, firma de la mesa, eventos de mesa (`roll_event`, `resolve_choice`) e historial (`record`). `PartyBrain.counter` devuelve `mods` y `initiative` construye propuestas reales.
- Pantallas: `negotiation` (menú), `meeting` (mesa; oculta, a pantalla completa; ver `HIDDEN_SCREENS` en `Shell`) e `inbox` (Bandeja a pantalla completa). `Shell.open_meeting(id, topic, extra)` abre siempre con la propuesta de la IA. Pendientes: `GameModel.attention_count()` / `pending_messages()` / `digest_messages()`; los mensajes de prensa, consejos y sistema nacen leídos (`digest`).
- Bandeja: `m.publish()` añade `kind`, `key` (sustituye al anterior) y caducidad; `expire_news()`, `urgent_since(seq)`, `pending_count()`.
- Avisos: `Shell.toast(text, tone, key)` fusiona repetidos (×N) y limita a 3.

## Mapa y sonido (1.2.0)
- Mapa: `data/maps/spain_provinces_real.json` (generado con `python3 tools/build_map.py <geojson> <salida>`). Cada provincia tiene `polygons` (anillos), `center`, `group`, `tiny`; `insets` define recuadros. `SpainMap` triangula una vez (`_geo`) y dibuja mallas; `NightMap` reutiliza `_paint_province`.
- Sonido: `Sfx.play("click"|"page"|"notify"|"confirm"|"deny"|"alert"|"day"|"gavel"|"fanfare"|"flip"|"reveal")`. Sin recursos externos; `Sfx.enabled=false` lo desactiva en pruebas.

## Ideologías, personaje y prensa (1.3.0)
- `Ideology` (core): catálogo `CATALOG`, `compose(picks)` → ejes, perfil, coherencia, bloque; `compat(a, b)`; `preview`; `infer_picks`. `PartyBrain.gate/topic_gate` aplican las puertas ideológicas.
- `Leader` (core): atributos, oficios, rasgos, listas de aspecto y generador por partido. `GameModel.character()/leader_of()/leader_name()`.
- `LeaderPortrait` (widget): caricatura procedural; carga `res://assets/portraits/<clave>.png` si existe.
- `NewGameWizard` (startup): flujo de nueva partida; `build_party()` añade `character`, `ideology_picks`, `coherence`.
- `Encounters` (core, `m.enc`): estado en `m.s["enc"]` (imagen, segmentos, posturas, hemeroteca, rencores). API: `build_session`, `resolve`, `finish`, `auto_play`, `press_question`, `answer_press`, `maybe_incident`, `daily`. Para añadir preguntas o respuestas basta ampliar las tablas de datos (`TOPICS`, `PLANS`, `STYLE_TEXT`, `SPECIAL`, `INCIDENTS`).
- Tema claro: constantes de color en `UI` (`BG`, `PANEL`, `SIDE`, `ACCENT`…), `UI.box(..., shadow)` y `UI.make_theme()`.

## Territorio del partido del jugador (1.3.1)
- `Ideology.TERRITORIAL_IDS` (regionalismo, independentismo) marca los partidos propios territoriales; el asistente guarda `party["territory"] = [comunidad]`.
- `GameModel.territory_of(id)` devuelve `{communities, electorate}` para los regionalistas del dataset (`Rules.REGIONALIST_TERRITORY`) y para el jugador (`s["player_territory"]`); `is_regional(id)` lo usan `ElectionSim`, `CampaignSim` y `PartyBrain`. Con todas las comunidades cubiertas el partido deja de ser regional.
- `CampaignSim.expand_territory(comunidad)` / `expansion_cost` / `can_expand` gestionan la ampliación (tarjeta «Implantación territorial» en `map_screen.gd`).

## Fase 2: leyes, Congreso y economía (1.4.0)
- `data/scenarios/spain/policies.json` (generado por `tools/gen_policies.py`) define áreas, medidas, presupuesto, impuestos, grupos y ministerios. `Policies` lo lee.
- `EconomySim` (`m.eco`, estado en `m.s["eco"]`): valores de las medidas, cálculo fiscal, composición del PIB, tick **trimestral** que delega crecimiento, paro e inflación en `MacroSim` y deja snapshots para las gráficas. `preview(changes)` simula una ley sin aplicarla.
- `LawMaker` (`m.laws`): borradores, cola, posturas de partidos, condiciones y previsión de votos. `Congress` (`m.congress`): sesión plenaria mensual en `m.s["pleno"]` (ready/running/done), votación y aplicación de la ley.
- Parlamento (v2.10, ampliado en v2.11): `LawMaker.KINDS` (ley / pnl / interpelacion), `TONES` y `STYLES`; **toda** iniciativa (también las del programa) gasta un hueco de `GovernmentSim.bills_left()` (`INITIATIVES_PER_MONTH = 3`) y las PNL/interpelaciones además `Congress.control_left()` (2 al mes). Enmiendas libres: `Amendments.make_term/value_in_law/preview` (`PLAYER_SLOTS = 3`) alimentan la ventana `PlenaryScreen._open_amend`. `Amendments` (`m.congress.amend`, estado en `law["amend"]`: offers/counters/log/used) gestiona el trámite previo al voto: ofertas de la IA al jugador (`accept/counter/reject`), enmiendas del jugador (`player_options/propose/accept_counter`) y `_ai_vs_ai`; lo pactado queda en `law["committed"]`. `Congress.tally` aplica el voto de arrastre y `resolve_current` devuelve `reasons` (explicación de voto por grupo) y `followers`; `_resolve_interpelacion` resuelve el debate de control y `withdraw_current` retira una iniciativa propia. UI: `PlenaryScreen` (fases intro/debate/vote/reveal/result con estado estático que sobrevive a `rebuild()`; el resultado se calcula al votar y la animación solo lo revela), `ParliamentHall` (hemiciclo animado), `TallyBar`; `LawsScreen` (inicio = cupo + 3 módulos que abren ventanas `shell.modal` + editor con `PolicyBrowser` en modo `law` + editor de interpelaciones).
- `Ministers` (`m.ministers`): titulares por cartera y bonus por competencia.
- UI: `LawsScreen`, `PlenaryScreen` (+ `PlenaryChamber`), `EconomyScreen`, `SocietyScreen`, `HBarChart`, `DonutChart`. La animación del Pleno usa variables estáticas para sobrevivir a las reconstrucciones.
- El esquema de guardado no cambia: `eco` se inicializa de forma perezosa (`ensure()`).

## Núcleo ministerial (1.5.0)
- `Executive` (`m.exec`, estado en `m.s["exec"]`): `area_owners()`/`line_owner()` reparten competencias según las carteras (`key` conserva el nombre de catálogo aunque se renombre); `post_kind()` ("president"/"minister"/"none") y `set_post()` fijan la cartera del jugador; `issue()` ejecuta decretos (coste en capital, `consent()`, `incoherence()`); `adjust_line()` modifica crédito; `monthly()` regenera capital, hace actuar a los ministros IA, evalúa objetivos y abre los PGE.
- PGE: `pge()` guarda `factors` (dotación aprobada), `adjust` (créditos del año), `draft`, `requests` e historial. La ley de presupuestos es una ley con `kind == "presupuestos"` y `budget`; `LawMaker.stance` delega en `Executive.budget_stance`, y `Congress.resolve_current` llama a `apply_pge`/`reject_pge`. `EconomySim.budget_factor()` multiplica el gasto de cada partida y empuja la calidad del servicio.
- UI: `MinistryScreen` (pestañas por ministerio y de Presupuestos), tarjetas de competencias y rol en `CabinetScreen`. Prueba: `tests/executive.gd`.
- Pendiente de fases siguientes: castigo de votantes con escraches y encuestas por casas, moción de censura, Senado y decretos-ley con convalidación (ver el documento de propuesta).


## Rediseño 2.0.0
- **Shell**: `HUBS_BY_PHASE` agrupa pantallas en bloques; `hubs()/nav_ids()/hub_of()` derivan la navegación. `UI.pill`/`UI.mini_button` dibujan los botones del marco.
- **DisplayManager** (autoload): pantalla completa y factor de escala (`content_scale_factor`) calculado sobre la ventana real con un mínimo virtual de 1280×720.
- **Manifesto** (`m.manifesto`): `m.s["manifesto"] = {medida: {from, to}}`, `manifesto_locked`. `campaign.program()` se deriva de él. `resonance()` alimenta el cálculo diario de encuestas; `monthly()` y `close_term()` miden el cumplimiento.
- **Negociación**: `PartyBrain.policy_demand/policy_term` generan términos de política con `measure`/`to`; `must_terms/missing_must` definen las exigencias inegociables (`ctx.enforce_must`, activo en reuniones de investidura/pre-pacto/estabilidad); `measure_pref_of_term` detecta líneas rojas. `create_commitments` guarda `measure/to/from` y `_measure_done` los cierra.
- **Datos**: `tools/gen_policies.py` escala partidas e ingresos a los datos reales; `EconomySim.BASE_DEFICIT_PCT = 3.6`.

## 2.1.0
- **Fuentes**: `assets/fonts/Inter-*.otf` + `[gui] theme/custom_font`; `UI.regular_font()/bold_font()`. No se fuerzan opciones globales de hinting/antialiasing.
- **Irpf** (`scripts/core/irpf.gd`): escala = `[{from (miles €), rate (%)}]`, estado en `eco.st()["irpf"]`. `Policies.irpf_measure()` es una medida especial (`irpf_scale`, valor escalar = tipo medio) que sólo editan las pantallas con `IrpfEditor`. `preview(changes, irpf)` y `apply_law` aceptan la escala (`law["irpf"]`).
- **Manifesto**: promesas por área (`MAX_PER_AREA = 7`), sin tope global. La promesa del IRPF guarda `brackets`/`base`. `create_bills()` / `ensure_bills()` crean un borrador por promesa (`law["promise"]`); `on_bill()` recibe `registered/passed/rejected` desde `LawMaker.register` y `Congress`. `disappointment()` y `monthly()` aplican el castigo; `close_term()` la factura final.

## 2.2.0 — Interfaz sin scroll
- **Regla**: ninguna pantalla debe necesitar desplazarse a 1920×1080 (`DisplayManager.BASE`). La interfaz se escala sola a otras ventanas manteniendo ese tamaño virtual.
- `Screen.split(left_w)` (lista fija + detalle expansible) y `Screen.cols([pesos])` (columnas con ratios) sustituyen a las pilas verticales largas. `UI.select_row()` es la fila seleccionable de las listas maestro/detalle. `UI.card()` recorta el subtítulo con «…»: **nada dentro de una columna debe tener un ancho mínimo mayor que su cuota** (si lo tiene, ensancha toda la página; usa `clip_text` o `wrap_label`).
- Las medidas se pintan en `UI.grid(2, …)`; los editores largos (IRPF) se pliegan en una fila resumen + vista propia (`ProgramScreen.irpf_open`, `LawsScreen.irpf_open`). El asistente de Nueva partida y la pantalla de inicio llevan su propio marco con el pie fijo.
- **Auditoría**: `tests/overflow_audit.gd -- <partido>` (todas las pantallas, todas las fases, programa por áreas), `tests/overflow_hidden.gd -- <partido>` (cartera, presupuestos, reuniones, editor de leyes) y `tests/wizard_shots.gd`. Se ejecutan con `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tests/<x>.gd`; deben dar `main 0` y ningún «ANCHO MIN». Con `SHOTS=1` guardan capturas.

## 2.3.0 — Medios y pausa
- `scripts/core/media_db.gd` + `data/media/{questions,answers}.json`: banco de textos con etiquetas `[d,t,r,p,c]` (formato) y `[g,o]` (papel). `Encounters.pick_h` elige sin repetir por hash de contenido.
- `Encounters.build_session` calcula el formato (`tv/radio/podcast/press/debate/control`), `replica_for`, `expected_quality` (asesor) y admite `ev["context"]`.
- `scripts/core/media_agenda.gd` (`m.media`): ofertas mensuales, huecos, delegación; se engancha en `GovernmentSim.advance_month` y en `_random_event`. Acciones de Bandeja `studio:`, `studio_auto:`, `studio_skip:` (`GameModel._studio_action`).
- `scripts/ui/widgets/media_studio.gd` (`MediaStudio`): overlay del plató; `Shell.play_studio / start_media_offer / delegate_media_offer`.
- `scripts/ui/widgets/pause_menu.gd` (`PauseMenu`): Esc en `Shell._input`; pausa el árbol.
- `NightBroadcast`: intro automática (3,5 s), `_check_lead_change`; `NightPanel` con doble columna y `_draw_race`.

## 2.4.0 — Votantes y militancia
- `Electorate` (`scripts/core/electorate.gd`, datos en `data/scenarios/spain/electorate.json`) es la fuente de las encuestas: `m.polls()` es una salida del modelo. Estado en `m.d("electorate")`. Cohortes = arquetipo × bloque territorial con ideas `x`, fidelidad `att`, enfado `anger`, simpatía `fav`, ánimo `mood` y ruido estático `eps`. Utilidad = −K·distancia² + sesgo de marca (calibrado a la encuesta inicial) + valencia (OU diaria) + propiedad de temas + hábito/enfado/simpatía; softmax entre los partidos que compiten en el bloque más una opción «otros». La participación es un logit con desviaciones respecto a la línea base calibrada.
- Los sistemas del juego **no escriben encuestas**: llaman a `nudge`/`nudge_many`, `react`, `on_law`, `on_pact`, `on_event_region`, `on_approval`, `on_broken_promises`. El tiempo avanza con `step_day()` (campaña) y `monthly()` (legislatura: cuatro encuestas semanales). `election_day()` / `finish_election()` cierran el ciclo y fijan la referencia del trasvase (`flows()`).
- `Militancy` (`scripts/core/militancy.gd`, estado `m.d("militancy")`): corrientes, líneas rojas, ultimátums (`mil:<regla>:<opción>` en `do_news_action`) y retirada de apoyo. Se engancha a `Congress._after_passed`, `Diplomacy.accept_proposal`, `GovernmentSim.form_government/advance_month` y `ElectionSim.finish_night`.
- Tras añadir una clase con `class_name` hay que abrir el proyecto una vez con `--editor --quit` para refrescar la caché de clases globales antes de ejecutar tests.
- `WorldSim` (`scripts/core/world_sim.gd`, datos en `data/scenarios/spain/world.json`, accesible como `m.world`; estado en `m.d("world")`, se autoinicializa con partidas antiguas). 36 indicadores con `start/scale/min/max/good/rate/links`. Objetivo = valor inicial + efectos de medidas (fx en unidades del indicador) + Σ vínculo·z(origen) + términos del presupuesto; el valor se relaja hacia el objetivo con `rate`. Realimenta crecimiento/paro/inflación (`feed`) y el ánimo de los grupos (`group_term`). `EconomySim.tick()` llama a `m.world.tick(eff)` tras `_compute_composition()`. Historial limitado a 120 meses.
- Medidas: `tools/gen_policies.py` combina `tools/src/policies_base.json`, `tools/measures_{a,b,c}.py` y `tools/world_def.py` (DSL en `tools/dsl.py`) y escribe `policies.json` y `world.json`. No editar los JSON a mano; ejecutar `python3 tools/gen_policies.py`.
- Acceso por cargo: `Executive.post_kind()` (`president`/`minister`/`none`); `Shell.hubs()` oculta `panel` y `ministry` sin cargo. `Executive.decreeable(meas)` decide decreto frente a ley (`LAW_ONLY_AREAS` y `LawMaker.ORGANIC` fuerzan la vía del Congreso). Ministros de la IA: `_ai_ministers`/`_ai_pick` (preferencia ideológica + `_need_bonus`).
- UI nueva: `PolicyNetwork` (widget de red de burbujas), `PanelScreen`, `IndicatorsScreen`, `Glyphs` (iconos procedurales por área), `Spark`, `DriverBars`.

## 2.7.0 — Interfaz estilo Democracy 4
- `PolicyBrowser` (HBoxContainer, modos `gov`, `gov_dialog` y `program`) es el navegador de medidas: `_areas_column`, `_measures_column` y `_fill_detail` (cifras, popularidad, `PolicySlider`, acciones, efectos y gráfico). La selección se recuerda en `PolicyBrowser.memory[modo]` para sobrevivir a las reconstrucciones; `program_pending` guarda el valor propuesto antes de añadirlo al programa.
- `PolicySlider` (Control con `_draw`): `setup(meas, cur, val, lo, hi, color)`; señales `changed` (arrastre) y `committed` (soltar o teclado).
- `Screen.wants_full()` decide si una pantalla es «de juego»: el Shell la aloja en `full_holder` (Control anclado, sin ScrollContainer) y oculta el panel lateral. Las demás siguen en el área con scroll. Importante: un `ScrollContainer` no encoge su hijo si una pantalla pasa un instante con un `HFlowContainer` muy alto, por eso las pantallas de juego no usan scroll.
- `PoliciesScreen` (`policies`) y `ProgramScreen` (solo en campaña) son los anfitriones; ponen una barra `hud_stat` encima del navegador. `UI.card()` pinta la banda de título; `UI.expand_card()` hace que una tarjeta reparta el alto sobrante.

## 2.6.0 — Historial, ficha de medidas y pactos por leyes
- `HistoryGen` (`scripts/core/history_gen.gd`): reconstruye hacia atrás la legislatura anterior (series ancladas + ruido AR + eventos exógenos) y alimenta `m.eco`/`m.world` y las encuestas semanales; `steps()` devuelve los pasos para la pantalla de carga (`LoadingOverlay`). Modos `realistic`/`random`/`none` elegidos en el asistente (`history_mode`).
- `AnalysisScreen` + `StackChart`/`ColumnChart` (y `LineChart` con marcadores): gráficos complejos sobre el historial.
- `PolicyDialog` (`scripts/ui/widgets/policy_dialog.gd`): modal con tres columnas; usa `PanelScreen.pending/forced` como borrador compartido. Se abre con `PolicyDialog.open(shell, model, measure_id, editable_areas, on_close)`. `MinistryScreen` ya no tiene controles propios: `_area_tile` abre la ficha.
- Diplomacia: nuevos términos `law_vote`/`law_abstain` (la IA vota o se abstiene en `law`), `law_amend` (el jugador acepta un cambio: `type` drop/soften/add, `measure`, `value`) y `owe_vote` (favor de voto). Tema `law_deal`: `Diplomacy.open(id, "law_deal", {"law": id})`; al cerrar, `_apply_law_terms` modifica la ley, fija `law["committed"][party]` (que `LawMaker.stance` respeta) y suma `m.d("favors")`. `Congress.resolve_current` salda favores (`settle_favor`) y marca pactos cumplidos. `PartyBrain.counter` propone enmiendas desde `LawMaker.conditions`; `initiative` puede lanzar `_law_proposal`; `Diplomacy.candidate_offer()` lanza la oferta de investidura al jugador minoritario.
- Investidura: `Rules.MAX_INVESTITURE_ATTEMPTS = 2`; el candidato es `parliamentary_ids()[attempts]`; `m.a("investiture_log")` guarda los fracasos.

## 2.8.0 — Menú, asistente y plantilla de partidos
- **Ayudas de `UI`**: `gradient_bg()` (fondo degradado), `nav_bar(alto)` (barra azul marino; su hijo 0 es un HBox), `menu_block(título, subtítulo, tipo, callback, ancho, activo)` con tipos `main|blue|quiet|danger`, `pill()` con estilo desactivado. `Shell` y `Startup` usan el mismo fondo.
- **`startup.gd`**: marco = degradado + `nav_bar` + `_wrap` con la vista. `show_home/new/load/settings` reconstruyen la vista con `_reset_view`. El asistente (`NewGameWizard`) se monta en `view` y debe conservar su API pública (`step`, `mode`, `party_id`, `_steps()`, `render()`, `_party_card`, `_problem()`, `_nav_next`, `build_party()`…) de la que dependen los tests.
- **Asistente**: `render()` = `_stepper()` + cuerpo con `ScrollContainer` (sin scroll en la práctica) + `_build_nav()`. Cada paso (`_build_party`, `_build_identity`, ideologías, personaje, resumen) usa píldoras con `Callable` con nombre (evitar lambdas multilínea como argumento intermedio).
- **Partidos**: `data/scenarios/spain/parties.json` (15). Un partido nuevo necesita: entrada con `ideology_profile` de 20 claves, `Rules.BASE_POLL` (suma 100), `Rules.REGIONALIST_TERRITORY` si es territorial, `Rules.COMMUNITY_LEAN` solo si es estatal, cantera de nombres en `Leader.generate`, `motif_for` en `ui.gd` y, opcionalmente, serie en `history_gen.REAL_POLLS`. El id `sumar` se mantiene aunque se muestre «Frente Amplio».

- Medios (v2.11): `data/media/questions.json` y `answers.json` usan etiquetas entre corchetes: `[d,t,r,p,c]` formatos, `[g,o]` roles y **cualquier otra etiqueta es un subtipo** (pregunta con subtipo → solo respuestas de ese subtipo; sin subtipo → solo respuestas sin subtipo). `MediaDB.questions_tagged/has_kind_bank/kind_answers`; `Encounters` compone con `FRAMES`, `_make_q/_make_answers`, `_issue_l` (artículo) y `_fixup` (contracciones). `tests/encounters_match.gd` garantiza que no hay preguntas sin respuesta compatible.

## Motor macroeconómico trimestral (v2.12)
- `MacroSim` (`scripts/core/macro_sim.gd`, `m.macro`, estado en `m.d("macro")`): `tick()` lo llama `EconomySim.tick()` una vez por turno (trimestre, `Rules.TURN_MONTHS`). `_step(S, X, noise, spawn)` es puro respecto al azar de la partida cuando `noise` es falso (lo usa `project(n)` sobre una copia del estado).
- Variables: `v` (nivel actual), `parts` (componentes con estado de crecimiento, paro e inflación: `x += k·(objetivo − x)`), `why` (cambios del último turno por causa: `kind` = policy|shock|agent|structural, `ref` = medida o shock), `pol` (efecto de cada medida ya llegado, retardo 55 %/turno), `origin` (ley que cambió cada medida), `shocks` (activos), `events`, `hist` (con el `why` de cada turno) y `proj`.
- `SHOCKS` define crisis y booms con efectos como desviaciones de nivel; `_haz_mult` condiciona su probabilidad a burbuja, deuda, banca, tipos y mejoras de país (`WorldSim.z`).
- `CountryVars` unifica el catálogo (core, fiscal, macro, red `WorldSim`, servicios `q:`, grupos `g:`, partidas `b:`, impuestos `t:`, sectores `s:`) para la pantalla País; `causes(id)` responde «qué lo ha movido» y `markers()` alinea leyes y crisis con la serie.


## Confianza interna y mandatos (v2.13)
- `InternalTrust` (`m.itrust`, estado en `m.d("itrust")`: `v`, `rec`, `shock`, `mandates`, `log`, `hist`, `alerts`, `cool`, `sec`, `counts`, `laws_passed`). Variable **separada** de las encuestas y de `m.trust`.
- Se alimenta de `Militancy.support()`, `Executive.directive()` (solo con cartera) y de su propio registro de mandatos; el objetivo es una suma lineal con ganancias constantes (`BASE`, `GAIN_*`), y el valor converge un 45 % por trimestre. Los cambios inmediatos al responder un mandato son la mitad del cambio de objetivo (`IMMEDIATE`) para que cada hecho cuente una vez.
- Ganchos: `Militancy.on_law` → `on_law` (crea mandatos de rectificación y cuenta leyes propias), `Militancy.on_election` → `on_election` (cierra mandatos sin penalizar), `GovernmentSim.advance_turn` → `quarterly()` (revisa mandatos, converge, explica el cambio, anuncia estados, filtraciones, genera mandatos y alertas), `Executive.monthly_income` × `capital_factor()` y `GovernmentSim.advance_turn` usa `bills_penalty()`.
- Bandeja: los mandatos son mensajes `PARTIDO` con acciones `mand:<id>:0|1|2` resueltas en `GameModel.do_news_action` → `itrust.respond`. La interfaz (`MilitancyScreen`) llama a la misma API.
- Fases futuras previstas por el documento (facciones desglosadas, rival/congreso, personalidad del secretario) no están implementadas; `Militancy` ya aporta las cuatro corrientes que servirán de base.

## Gabinete, ministros y coaliciones (v2.14)
Subsistemas nuevos de `GameModel`: `cab` (`CabinetSim`), `coal` (`Coalition`), `mact` (`MinisterActivity`), más el catálogo estático `Competencies`.
- **Datos**: cada cartera de `m.a("cabinet")` lleva `id`, `comps` (competencias principales, una sola cartera por competencia), `shared`, `desc`, `autonomy`, `priority`, `plan`. `m.d("cab")` guarda contador y registro de cambios; `m.d("coal")` el acuerdo (socios y modalidad, líneas rojas, reglas, crisis por partido, factores de confianza, registro); `m.a("table_proposals")` las propuestas de la mesa; `m.d("mact")` el registro de actividad. La confianza del socio es `m.d("partner_satisfaction")`; los compromisos son `m.a("commitments")`.
- **Flujo trimestral** (`GovernmentSim.advance_turn`): `cab.ensure` → `ministers.ensure_cabinet` → … → `_update_partners` → `mact.quarterly` (rendimiento y hasta 3 eventos) → `coal.quarterly` (acuerdos puntuales que caducan, factores de confianza, propuestas caducadas, escalera de crisis, nuevas peticiones, máx. 2) → estabilidad ≤ 0 → `coal.on_stability_zero` (ya no elecciones automáticas).
- **Formación** (`form_government`): `cab.ensure` y `coal.on_formed` (registra socios, modalidad, líneas rojas, reglas).
- **Decisiones**: las propuestas pasan por `coal.submit` y `coal.respond`; en la Bandeja, las acciones `tbl:<id>:<opción>` y `crisis:<partido>:<acción>` (`GameModel.do_news_action`).
- **Reglas clave**: cartera de un socio reservada en legislatura (`cab.is_reserved`); una competencia no puede tener dos responsables principales; entre 8 y 20 ministerios; la crisis sube como mucho un escalón por trimestre y solo un ultimátum vencido o rechazado provoca ruptura; la ruptura no convoca elecciones.
- **Ejecutivo**: `Executive.area_owners/line_owner` usan las competencias; con el jugador presidente, `_ai_ministers` no decreta (las reformas llegan como propuestas); decretar contra el criterio de un socio llama a `coal.unilateral`.
- **UI**: `CabinetScreen` (tablero y constructor), `MinistrySheet` (ficha modal con pestañas), `CoalitionScreen` (mesa).

## Negociación de Gobierno, entrega B (v2.15)
- **Perfil y poder**: `PartyBrain.ensure_traits` completa diez atributos por partido (los seis anteriores más `inst_ambition`, `cohesion`, `electoral_pressure`, `reliability`). `negotiating_power(id)` devuelve `{total, factors[]}` con los seis pesos de `Rules.NEGOTIATION_WEIGHTS`; `decisive_share` y `alternatives_of` salen de `seats_without` (escaños del bloque anclaje + socios + afines sin veto). `Diplomacy.context_for` lo mete en `ctx["power"]` y `ctx["modality"]` para que `assess`/`term_value` no lo recalculen.
- **Estrategia**: `preferred_modality(id)` puntúa las seis modalidades de `Rules.MODALITIES` con los rasgos; `assess` añade el factor `entry` si la mesa implica entrar en el Gobierno (`table_enters_government`) y la modalidad preferida no es coalición, y devuelve `modality`, `power` y `entry_refused`. `counter` sustituye lo que implica entrar por `participation` con su fórmula.
- **Términos nuevos** (`k`): `participation{mode}`, `structure{what: vicepresidency|max_ministries|min_ministries|coordination, n}`, `portfolio{comp}`, `objective{issue, level, text}`, `territory{what: invest|competences|financing, n}`, `budget{issue, n}`, `parliament{what}`, `institution{what, n}`, `calendar{what, n}`. Se añaden al menú en `Diplomacy._category_menu`, se clasifican con `category_of`, se deduplican en `add_term` y viajan en `pact.terms`.
- **Mesa**: el diccionario `meeting` guarda además `drafts`, `versions`, `rejected_keys`, `must_known`, `counter_requests`. API: `modify_term`, `replace_term`, `offer_alternative`, `accept_partially`/`can_split`, `term_statuses`/`status_counts`, `save_draft`/`load_draft`/`delete_draft`, `record_version`/`restore_version`/`compare_tables`/`compare_versions`, `request_counter`.
- **Investidura**: `_sync_investiture` interpreta `participation` (coalición → cartera reclamada, abstención → voto «abstain», apoyo externo/puntual → fuera del Consejo). `GovernmentSim._ai_resolve` fija `role` y `vote` según la modalidad.
- Pendiente (C-G): materializar las condiciones (campos §6 en `commitments`, reclamaciones, vicepresidencias, límite 8-20 unificado), cinco candidatos, capital normalizado, capa de diputados.


## Negociación de Gobierno, entrega C (Alpha 0.2.1)
- **`Agreements` (`m.agr`)**: capa única de compromisos sobre `m.a("commitments")`. `normalize` completa los campos de la especificación §6 (id, agreement_id, category, binding, type, kind, parties, responsible, consequence, history, state, progress); `spec_for_term` / `specs_for_offer` convierten los términos de una mesa en compromisos (`verify`: metric, manual, review, meeting, structural). Convención de lados: el presidente da ⇔ (`by=="player"`) XOR `as_partner`.
- **Formación**: `GovernmentSim._start_cabinet_design` usa `cabinet_limits()` (8–20, mínimo/máximo pactados) y `apply_to_cabinet()` (carteras y vicepresidencia con `rank="vice"`); `assign_ministry` y `CabinetSim` (crear, dividir, fusionar, borrar) respetan lo pactado vía `pledge_text`/`size_block`; `form_government` llama a `validate_formation()` y después a `on_government_formed()`.
- **Mensual**: `GovernmentSim` llama a `m.agr.tick()` tras `m.diplomacy.monthly()`; los bucles heredados de cumplimiento por materia ignoran `source=="acuerdo"`.
- **Acciones**: `fulfil` (capital político), `renegotiate`, `abandon`; el resto de la lógica (confianza, crisis) pasa por `Coalition.shift_trust`.
- **UI de negociación**: `NegUI` agrupa los widgets comunes (`side_header`, `origin_tag`, `stat_tile`, `pips`, `Gauge`, `commitment_row`). `MeetingScreen._table` pinta dos carriles por `by` con `_term_row` y `_origin`; `_balance` sustituye a la antigua tarjeta de lectura de la sala.
- Pendiente (D-G): cinco candidatos por cartera, capital político normalizado, diputados y pantalla de investidura, QA y migraciones.

## Negociación de Gobierno, entrega D (Alpha 0.2.2)
- **`MinistryCandidates` (`m.cands`)**: `shortlist(index)` devuelve y persiste (`m.s["cand_sets"][id de cartera]` con firma ciclo+partido+competencias) cinco candidatos; se completa con `_pick` (cantera del jugador por papel) o `_make` (personas nuevas con `Ministers.generate`, `pool_id` ≥ 100000 desde `m.s["cand_seq"]`). `dominates`/`_dominance_conflict` aplican la regla de no dominancia; `notes` calcula fortalezas, debilidades y riesgos; `fit` reutiliza `Ministers.effective_skill`.
- **Integración**: `Ministers.available_for` y `assign` usan la lista; `ensure_cabinet` nombra al jugador el mejor encaje de su lista y al socio vía `ai_choose` (rasgos pragmatism/rigidity/loyalty/ambition de `PartyBrain`). `CabinetSim.replace_with` sigue pasando por `assign`.
- **UI**: `MinistrySheet` tiene la pestaña `cands` (`_tab_cands`, `_cand_card`).
- Pendiente (E-G): capital político normalizado, diputados y pantalla de investidura, QA y migraciones; cláusula de acuerdo que autorice independientes en carteras de socios.
