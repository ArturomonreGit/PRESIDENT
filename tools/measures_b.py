from dsl import lv, sp

M = []

# ---------------------------------------------------------------- TRABAJO
M += [
    lv("wage_indexation", "jobs", "Indexación salarial al IPC", "Cláusulas de revisión automática de salarios.",
       ["Sin cláusulas", "En convenios públicos", "General"],
       fx={"wages": 1.5, "inflation": 0.08, "consumption": 0.5, "unemployment": 0.03}, hits={"trabajadores": 1.2, "funcionarios": 1.0, "empresarios": -0.5}, tags={"welfare": 0.5}),
    lv("youth_contract", "jobs", "Contrato joven bonificado", "Bonificaciones a la contratación de menores de 30 años.",
       ["Sin bonificación", "Parcial", "Total"],
       fx={"youth_unemp": -1.8, "unemployment": -0.04, "wages": -0.2}, cost={"prestaciones": 0.5}, hits={"jovenes": 1.4, "autonomos": 0.6}, tags={"market": 0.1}),
    lv("remote_work", "jobs", "Derecho al teletrabajo", "Regulación del trabajo a distancia.",
       ["Sin regular", "Acuerdo entre partes", "Derecho para quien pueda"],
       fx={"productivity": 0.2, "birth": 0.01, "rural": 0.3, "gender_gap": -0.2}, hits={"jovenes": 0.5, "trabajadores": 0.5, "empresarios": -0.3}, tags={"liberty": 0.2, "welfare": 0.2}),
    lv("labour_inspection", "jobs", "Inspección de Trabajo", "Más inspectores y sanciones al fraude laboral.",
       ["Actual", "Reforzada", "Intensiva"], base=0,
       fx={"informal": -1.0, "wages": 0.4, "poverty": -0.2}, rev={"cotizaciones": 0.8}, cost={"administracion": 0.3}, hits={"trabajadores": 0.6, "autonomos": -0.6, "empresarios": -0.4}, tags={"welfare": 0.4}),
    lv("sector_bargaining", "jobs", "Convenios sectoriales", "Peso de los convenios por sector frente a los de empresa.",
       ["Prima el convenio de empresa", "Equilibrio", "Prima el sectorial"], base=1,
       fx={"wages": 1.0, "unemployment": 0.04, "gini": -0.1}, hits={"trabajadores": 0.9, "empresarios": -0.7, "autonomos": -0.5}, tags={"welfare": 0.5}),
]

# ---------------------------------------------------------------- INDUSTRIA, COMERCIO Y TURISMO
M += [
    sp("industrial_plan", "industry", "Política industrial (PERTE)", "Proyectos estratégicos de industria y semiconductores.", 2, 0, 10, 1, "bn €/año",
       fx={"productivity": 0.4, "exports": 0.5, "investment": 1.2, "growth": 0.02}, cost={"industria": 1.0}, hits={"empresarios": 0.5, "trabajadores": 0.3}, tags={"welfare": 0.2, "patriot": 0.2}),
    lv("tourism_promo", "industry", "Promoción turística", "Campañas en el exterior y apoyo al sector.",
       ["Sin campaña", "Moderada", "Intensiva"], base=1,
       fx={"tourism": 3.0, "inflation": 0.01}, cost={"industria": 0.3}, hits={"autonomos": 0.5, "empresarios": 0.3}, tags={"market": 0.1}),
    lv("export_credit", "industry", "Apoyo a la exportación", "Créditos y seguros para internacionalizar empresas.",
       ["Sin apoyo", "Básico", "Reforzado"],
       fx={"exports": 1.2, "investment": 0.3}, cost={"industria": 0.5}, hits={"empresarios": 0.5, "autonomos": 0.4}, tags={"market": 0.2}),
    sp("sme_aid", "industry", "Ayudas a pymes", "Subvenciones y avales a pequeñas empresas.", 2, 0, 8, 1, "bn €/año",
       fx={"entrepreneurship": 1.5, "investment": 0.5, "informal": -0.2}, cost={"industria": 1.0}, hits={"autonomos": 1.2}, tags={"welfare": 0.1}),
    lv("competition_law", "industry", "Política de competencia", "Control de fusiones y de abuso de posición dominante.",
       ["Laxa", "Actual", "Estricta"], base=1,
       fx={"inflation": -0.05, "consumption": 0.7, "productivity": 0.5}, hits={"empresarios": -0.4, "clase_media": 0.3}, tags={"welfare": 0.2, "eu": 0.3}),
    lv("free_trade", "industry", "Acuerdos de libre comercio", "Apertura comercial con terceros países.",
       ["Proteccionismo", "Actual", "Apertura", "Libre comercio"], base=1,
       fx={"exports": 2.5, "farm_income": -1.5, "inflation": -0.06, "productivity": 0.4}, hits={"empresarios": 0.8, "rurales": -0.7, "trabajadores": -0.2}, tags={"market": 0.4, "eu": 0.3}),
    lv("consumer_protection", "industry", "Protección del consumidor", "Reclamaciones, garantías y etiquetado.",
       ["Mínima", "Actual", "Reforzada"], base=1,
       fx={"consumption": 0.5, "trust": 0.4}, hits={"clase_media": 0.4, "autonomos": -0.2}, tags={"welfare": 0.2}),
    lv("public_enterprises", "industry", "Empresas públicas estratégicas", "Participación pública en energía, banca y telecomunicaciones.",
       ["Privatización", "Actual", "Ampliación"], base=1,
       fx={"investment": -0.5, "productivity": -0.2, "energy_price": -0.8}, cost={"industria": 0.8}, hits={"funcionarios": 0.6, "empresarios": -0.7}, tags={"socialist": 0.6}),
]

# ---------------------------------------------------------------- ENERGÍA Y CLIMA
M += [
    lv("coal_phaseout", "energy", "Cierre del carbón y térmicas", "Calendario de clausura de centrales de carbón y gas.",
       ["Sin calendario", "2035", "2030", "Inmediato"],
       fx={"emissions": -9.0, "environment": 1.0, "energy_price": 2.0, "unemployment": 0.02, "renewables": 1.0}, cost={"transicion": 0.5}, hits={"rurales": -0.5, "trabajadores": -0.2, "jovenes": 0.3}, tags={"green": 0.7}),
    sp("energy_efficiency", "energy", "Rehabilitación energética de edificios", "Ayudas al aislamiento y a la renovación del parque de viviendas.", 2, 0, 12, 1, "bn €/año",
       fx={"emissions": -2.0, "energy_price": -1.2, "housing": 0.2, "environment": 0.4}, cost={"transicion": 1.0}, hits={"clase_media": 0.5, "vulnerables": 0.6}, tags={"green": 0.4}, sec={"construccion": 0.1}),
    lv("interconnections", "energy", "Interconexiones y gas", "Infraestructuras energéticas con Francia y el Mediterráneo.",
       ["Sin inversión", "Limitada", "Ambiciosa"],
       fx={"energy_price": -2.0, "exports": 0.2}, cost={"transicion": 0.6}, hits={"empresarios": 0.3}, tags={"eu": 0.3}),
    lv("solar_selfuse", "energy", "Autoconsumo solar", "Subvenciones y simplificación de la energía solar doméstica.",
       ["Sin ayudas", "Ayudas básicas", "Ayudas fuertes"],
       fx={"renewables": 1.5, "energy_price": -1.5, "emissions": -2.0}, cost={"transicion": 0.5}, hits={"clase_media": 0.5, "rurales": 0.3}, tags={"green": 0.5}),
    lv("fracking", "energy", "Fracking y prospecciones", "Exploración de hidrocarburos en territorio nacional.",
       ["Prohibido", "Solo gas", "Permitido"],
       fx={"energy_price": -2.5, "emissions": 6.0, "environment": -1.2, "exports": 0.2}, rev={"otros": 0.3}, hits={"empresarios": 0.4, "rurales": -0.3, "jovenes": -0.6}, tags={"brown": 0.7}),
    lv("emissions_cap", "energy", "Techo de emisiones industriales", "Límite obligatorio de CO₂ a grandes instalaciones.",
       ["Sin límite", "Sectorial", "Estricto"],
       fx={"emissions": -8.0, "environment": 0.8, "investment": -1.0, "exports": -0.3}, hits={"empresarios": -0.8, "jovenes": 0.4}, tags={"green": 0.6}),
]

# ---------------------------------------------------------------- TRANSPORTES
M += [
    sp("hsr", "transport", "Alta velocidad ferroviaria", "Nuevas líneas de AVE y mantenimiento.", 2, 0, 9, 1, "bn €/año",
       fx={"infrastructure": 0.8, "transit_share": 0.3, "growth": 0.02, "rural": 0.2}, cost={"transportes": 1.0}, hits={"clase_media": 0.3, "rurales": 0.3}, tags={"welfare": 0.1}),
    lv("road_tolls", "transport", "Peajes en autovías", "Pago por uso de las autovías gratuitas.",
       ["Sin peajes", "Camiones", "Todos los vehículos"],
       fx={"transit_share": 0.8, "emissions": -1.5, "inflation": 0.02, "infrastructure": 0.2}, rev={"otros": 1.2}, hits={"rurales": -0.8, "clase_media": -0.4, "trabajadores": -0.3}, tags={"green": 0.3, "market": 0.3}),
    sp("ev_incentives", "transport", "Ayudas al coche eléctrico", "Subvenciones a la compra y a los puntos de recarga.", 1, 0, 5, 1, "bn €/año",
       fx={"emissions": -2.0, "environment": 0.4, "innovation": 0.1}, cost={"transicion": 1.0}, hits={"clase_media": 0.3, "empresarios": 0.2}, tags={"green": 0.4}),
    lv("airports", "transport", "Ampliación de aeropuertos", "Más capacidad en grandes aeropuertos.",
       ["Congelada", "Mejoras", "Ampliación"],
       fx={"tourism": 2.0, "emissions": 2.5, "environment": -0.4, "growth": 0.02}, cost={"transportes": 0.5}, hits={"empresarios": 0.4, "autonomos": 0.3}, tags={"brown": 0.4}),
    sp("regional_rail", "transport", "Cercanías y ferrocarril regional", "Trenes de cercanías y regionales.", 2, 0, 8, 1, "bn €/año",
       fx={"infrastructure": 0.7, "transit_share": 0.7, "emissions": -1.0, "rural": 0.2}, cost={"transportes": 1.0}, hits={"trabajadores": 0.5, "rurales": 0.4, "jovenes": 0.3}, tags={"green": 0.2, "welfare": 0.1}),
    lv("ports_logistics", "transport", "Puertos y logística", "Corredores mediterráneo y atlántico y puertos.",
       ["Sin inversión", "Moderada", "Fuerte"],
       fx={"exports": 1.0, "infrastructure": 0.4, "growth": 0.02}, cost={"transportes": 0.7}, hits={"empresarios": 0.4}, tags={"eu": 0.2}),
    lv("free_transit", "transport", "Abono de transporte público", "Tarifas del transporte colectivo.",
       ["Tarifa plena", "Descuento", "Gratuito"],
       fx={"transit_share": 4.0, "emissions": -2.0, "inflation": -0.03}, cost={"transportes": 1.5}, hits={"jovenes": 1.0, "trabajadores": 0.8, "vulnerables": 0.8}, tags={"welfare": 0.4, "green": 0.3}),
]

# ---------------------------------------------------------------- AGRICULTURA Y MEDIO RURAL
M += [
    lv("water_plan", "agriculture", "Plan hidrológico y regadíos", "Obras hidráulicas, desalación y gestión del agua.",
       ["Sin plan", "Eficiencia", "Trasvases y desalación"],
       fx={"farm_income": 3.0, "environment": -0.4, "rural": 0.3}, cost={"agricultura": 0.8}, hits={"rurales": 1.0}, tags={"brown": 0.2}),
    lv("fishing_quota", "agriculture", "Cuotas de pesca", "Límites de captura y ayudas a la flota.",
       ["Cuotas estrictas", "Actuales", "Flexibles"], base=1,
       fx={"farm_income": 0.8, "environment": -0.4}, hits={"rurales": 0.5}, tags={"brown": 0.2}),
    lv("organic_farming", "agriculture", "Agricultura ecológica", "Ayudas a la producción ecológica y de proximidad.",
       ["Sin ayudas", "Moderadas", "Fuertes"],
       fx={"environment": 0.6, "farm_income": -0.4, "emissions": -1.0, "health": 0.1}, cost={"agricultura": 0.6}, hits={"rurales": 0.1, "jovenes": 0.2}, tags={"green": 0.5}),
    lv("cap_cap", "agriculture", "Tope a la PAC por explotación", "Límite de ayudas a las grandes explotaciones.",
       ["Sin tope", "Tope alto", "Tope bajo"],
       fx={"farm_income": -0.8, "equality": 0.2, "rural": 0.4}, cost={"agricultura": -0.5}, hits={"rurales": 0.3, "empresarios": -0.3}, tags={"welfare": 0.3}),
    lv("farm_tariffs", "agriculture", "Aranceles agrícolas", "Protección frente a importaciones agrarias.",
       ["Sin aranceles", "Actuales", "Reforzados"], base=1,
       fx={"farm_income": 2.5, "inflation": 0.04, "exports": -0.5}, hits={"rurales": 0.8, "clase_media": -0.2}, tags={"patriot": 0.3}),
    lv("food_margins", "agriculture", "Control de márgenes alimentarios", "Vigilancia de la cadena de valor de los alimentos.",
       ["Libre", "Observatorio", "Margen máximo"],
       fx={"inflation": -0.08, "farm_income": 0.8, "investment": -0.3}, hits={"clase_media": 0.5, "vulnerables": 0.6, "empresarios": -0.5}, tags={"welfare": 0.5}),
    lv("animal_welfare", "agriculture", "Bienestar animal y caza", "Protección animal frente a caza y tauromaquia.",
       ["Se favorece la caza", "Actual", "Protección animal reforzada"], base=1,
       fx={"environment": 0.3, "farm_income": -0.3}, hits={"rurales": -0.9, "jovenes": 0.5}, tags={"green": 0.3, "prog": 0.4}),
]
