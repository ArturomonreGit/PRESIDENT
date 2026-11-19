from dsl import lv, sp

M = []

# ---------------------------------------------------------------- SEGURIDAD
M += [
    lv("community_police", "security", "Policía de proximidad", "Agentes de barrio y patrullas a pie.",
       ["Sin programa", "Piloto", "Generalizada"],
       fx={"crime": -1.5, "security": 0.4, "trust": 0.2}, cost={"interior": 0.6}, hits={"clase_media": 0.4, "vulnerables": 0.3}, tags={"order": 0.2, "welfare": 0.1}),
    sp("cybersecurity", "security", "Ciberseguridad nacional", "Centro nacional y protección de infraestructuras críticas.", 1, 0, 5, 1, "bn €/año",
       fx={"security": 0.3, "digital": 0.3, "crime": -0.4}, cost={"interior": 1.0}, hits={"empresarios": 0.3}, tags={"order": 0.1}),
    lv("gun_control", "security", "Control de armas", "Licencias, registro y tenencia de armas.",
       ["Laxo", "Actual", "Restrictivo"], base=1,
       fx={"crime": -0.4, "tension": -0.2}, hits={"rurales": -0.5, "jovenes": 0.2}, tags={"prog": 0.2}),
    lv("drug_policy", "security", "Política de drogas", "Persecución frente a regulación y reducción de daños.",
       ["Prohibición dura", "Actual", "Despenalización", "Regulación del cannabis"], base=1,
       fx={"crime": -0.3, "health": 0.2, "tension": -0.2}, rev={"otros": 0.4}, hits={"jovenes": 0.9, "rurales": -0.3}, tags={"liberty": 0.5, "prog": 0.4}),
    lv("prison_reform", "security", "Reforma penitenciaria", "Reinserción frente a mayor encarcelamiento.",
       ["Mano dura", "Actual", "Reinserción"], base=1,
       fx={"crime": -0.5, "trust": 0.1}, cost={"interior": 0.4}, hits={"vulnerables": 0.3, "clase_media": -0.2}, tags={"prog": 0.3, "welfare": 0.2}),
    sp("terror_plan", "security", "Plan antiterrorista", "Inteligencia, prevención y coordinación europea.", 1, 0, 5, 1, "bn €/año",
       fx={"security": 0.5, "crime": -0.3}, cost={"interior": 1.0}, hits={"clase_media": 0.3}, tags={"order": 0.3, "eu": 0.1}),
    lv("traffic_safety", "security", "Seguridad vial", "Límites de velocidad, control y campañas.",
       ["Laxa", "Actual", "Estricta"], base=1,
       fx={"life_exp": 0.1, "emissions": -0.5}, rev={"otros": 0.3}, hits={"trabajadores": -0.2, "clase_media": -0.1}, tags={"order": 0.2}),
]

# ---------------------------------------------------------------- JUSTICIA
M += [
    sp("judicial_reform", "justice", "Modernización de la Justicia", "Más juzgados, jueces y fiscales.", 2, 0, 8, 1, "bn €/año",
       fx={"court_delay": -2.0, "trust": 0.4, "investment": 0.2}, cost={"justicia": 1.0}, hits={"funcionarios": 0.3, "empresarios": 0.3}, tags={"welfare": 0.1}),
    lv("legal_aid", "justice", "Justicia gratuita", "Asistencia jurídica para rentas bajas.",
       ["Restringida", "Actual", "Ampliada"], base=1,
       fx={"equality": 0.2, "trust": 0.2}, cost={"justicia": 0.4}, hits={"vulnerables": 0.6}, tags={"welfare": 0.4}),
    sp("court_digital", "justice", "Justicia digital", "Expediente electrónico y procesos telemáticos.", 1, 0, 4, 1, "bn €/año",
       fx={"court_delay": -1.0, "digital": 0.3, "transparency": 0.3}, cost={"justicia": 1.0}, hits={"empresarios": 0.2}, tags={"market": 0.1}),
    lv("anticorruption", "justice", "Lucha anticorrupción", "Fiscalía anticorrupción, canales de denuncia y transparencia.",
       ["Actual", "Reforzada", "Agencia independiente"],
       fx={"transparency": 1.5, "trust": 0.9, "polarization": -0.2}, cost={"justicia": 0.4}, hits={"clase_media": 0.5, "funcionarios": -0.3}, tags={"prog": 0.1}),
    lv("euthanasia", "justice", "Eutanasia y muerte digna", "Regulación del final de la vida.",
       ["Prohibida", "Cuidados paliativos", "Eutanasia regulada"], base=2,
       fx={"polarization": 0.1}, hits={"jovenes": 0.4, "pensionistas": -0.2, "rurales": -0.4}, tags={"liberty": 0.6, "prog": 0.5}),
    lv("abortion", "justice", "Interrupción del embarazo", "Marco legal del aborto.",
       ["Prohibición", "Supuestos", "Plazos", "Plazos ampliados"], base=2,
       fx={"gender_gap": -0.1, "polarization": 0.2}, hits={"jovenes": 0.5, "rurales": -0.5, "pensionistas": -0.3}, tags={"liberty": 0.5, "fem": 0.5, "prog": 0.4}),
    lv("lgbt_rights", "justice", "Derechos LGTBI", "Igualdad y protección legal.",
       ["Sin protección", "Actual", "Ampliados"], base=1,
       fx={"polarization": 0.1, "trust": 0.1}, hits={"jovenes": 0.5, "rurales": -0.3}, tags={"liberty": 0.5, "prog": 0.5}),
]

# ---------------------------------------------------------------- INMIGRACIÓN
M += [
    lv("regularization", "immigration", "Regularización de inmigrantes", "Vías para regularizar la situación administrativa.",
       ["Sin regularización", "Por arraigo", "Masiva"], base=1,
       fx={"net_migration": 0.3, "informal": -0.8, "tension": 0.2, "wages": -0.1, "unemployment": -0.01}, rev={"cotizaciones": 0.6}, hits={"trabajadores": -0.2, "vulnerables": 0.3, "rurales": -0.4}, tags={"prog": 0.4}),
    lv("border_control", "immigration", "Control de fronteras", "Vigilancia y cooperación con terceros países.",
       ["Mínimo", "Actual", "Reforzado"], base=1,
       fx={"net_migration": -0.3, "tension": -0.1, "crime": -0.2}, cost={"interior": 0.8}, hits={"rurales": 0.5, "clase_media": 0.3, "jovenes": -0.3}, tags={"order": 0.4, "patriot": 0.3}),
    sp("integration_plan", "immigration", "Plan de integración", "Idioma, vivienda y formación para recién llegados.", 1, 0, 5, 1, "bn €/año",
       fx={"tension": -0.4, "unemployment": -0.02, "informal": -0.2, "trust": 0.1}, cost={"prestaciones": 1.0}, hits={"vulnerables": 0.4}, tags={"welfare": 0.2, "prog": 0.2}),
    lv("work_visas", "immigration", "Visados de trabajo", "Contratación en origen y visados sectoriales.",
       ["Cerrados", "Cupos", "Abiertos"], base=1,
       fx={"net_migration": 0.4, "wages": -0.2, "growth": 0.03, "productivity": 0.1}, rev={"cotizaciones": 0.4}, hits={"empresarios": 0.6, "autonomos": 0.3, "trabajadores": -0.3}, tags={"market": 0.3}),
    lv("asylum", "immigration", "Política de asilo", "Acogida de refugiados y solicitantes de asilo.",
       ["Restrictiva", "Actual", "Generosa"], base=1,
       fx={"net_migration": 0.2, "tension": 0.1}, cost={"prestaciones": 0.6}, hits={"jovenes": 0.4, "rurales": -0.4}, tags={"prog": 0.4, "eu": 0.2}),
    lv("deportation", "immigration", "Expulsiones", "Ejecución de órdenes de expulsión y repatriación.",
       ["Excepcionales", "Actual", "Sistemáticas"], base=1,
       fx={"net_migration": -0.4, "tension": 0.2, "crime": -0.1}, cost={"interior": 0.5}, hits={"rurales": 0.4, "jovenes": -0.5}, tags={"order": 0.4, "patriot": 0.4}),
]

# ---------------------------------------------------------------- DEFENSA Y EXTERIOR
M += [
    lv("nato", "defense", "Compromisos con la OTAN", "Participación en la Alianza y objetivo de gasto.",
       ["Salida", "Mínimos", "Actual", "Refuerzo"], base=2,
       fx={"security": 0.2, "exports": 0.1}, hits={"empresarios": 0.2, "jovenes": -0.3}, tags={"patriot": 0.2, "eu": 0.2}),
    lv("military_service", "defense", "Servicio militar", "Modelo de reclutamiento de las Fuerzas Armadas.",
       ["Profesional", "Reserva voluntaria", "Servicio obligatorio"], base=0,
       fx={"youth_unemp": -0.5, "security": 0.2}, cost={"defensa": 0.8}, hits={"jovenes": -1.0, "pensionistas": 0.4}, tags={"patriot": 0.5, "order": 0.3}),
    lv("arms_exports", "defense", "Exportación de armas", "Control de ventas de material militar.",
       ["Prohibidas", "Restringidas", "Libres"], base=1,
       fx={"exports": 0.4, "tension": 0.0}, rev={"otros": 0.2}, hits={"empresarios": 0.3, "jovenes": -0.4}, tags={"market": 0.1}),
    sp("foreign_aid", "defense", "Cooperación al desarrollo", "Ayuda oficial al desarrollo.", 1, 0, 6, 1, "bn €/año",
       fx={"net_migration": -0.05, "trust": 0.05}, cost={"administracion": 1.0}, hits={"jovenes": 0.3, "rurales": -0.2}, tags={"prog": 0.3, "eu": 0.1}),
    lv("eu_integration", "defense", "Integración europea", "Profundización en las decisiones comunes.",
       ["Euroescepticismo", "Actual", "Más integración", "Federalismo europeo"], base=1,
       fx={"exports": 0.3, "investment": 0.3, "polarization": 0.1}, hits={"empresarios": 0.4, "jovenes": 0.5, "rurales": -0.3}, tags={"eu": 0.6}),
    lv("military_aid", "defense", "Ayuda militar a aliados", "Envío de armamento y apoyo a terceros.",
       ["Ninguna", "Limitada", "Amplia"], base=1,
       fx={"security": -0.1, "tension": 0.1}, cost={"defensa": 0.5}, hits={"jovenes": -0.2, "pensionistas": 0.1}, tags={"patriot": 0.2, "eu": 0.2}),
]

# ---------------------------------------------------------------- TERRITORIO (nuevas)
M += [
    lv("referendum", "territory", "Referéndum de autodeterminación", "Posibilidad de consultas vinculantes en territorios.",
       ["Prohibido", "Consulta no vinculante", "Referéndum pactado"], base=0,
       fx={"tension": -0.4, "polarization": 0.3}, hits={"rurales": -0.3, "jovenes": 0.2}, tags={"federal": 0.6, "liberty": 0.3}),
    lv("fiscal_pact", "territory", "Financiación autonómica", "Reparto de recursos entre territorios.",
       ["Régimen común", "Reforma moderada", "Concierto económico"], base=0,
       fx={"tension": -0.3, "equality": -0.2}, hits={"clase_media": -0.1}, tags={"federal": 0.5}),
    lv("senate_reform", "territory", "Reforma del Senado", "Cámara de representación territorial.",
       ["Actual", "Reforma", "Cámara territorial"], base=0,
       fx={"tension": -0.2, "trust": 0.1}, hits={"clase_media": 0.1}, tags={"federal": 0.4, "prog": 0.1}),
    sp("local_gov", "territory", "Financiación local", "Transferencias a ayuntamientos y diputaciones.", 2, 0, 6, 1, "bn €/año",
       fx={"rural": 0.4, "infrastructure": 0.2, "trust": 0.1}, cost={"territorial": 1.0}, hits={"rurales": 0.6}, tags={"federal": 0.1}),
    lv("provincial", "territory", "Diputaciones provinciales", "Mantenimiento o supresión de diputaciones.",
       ["Suprimidas", "Reducidas", "Actuales"], base=2,
       fx={"rural": -0.1, "trust": 0.05}, cost={"territorial": 0.3}, hits={"funcionarios": 0.2, "rurales": 0.2}, tags={"central": 0.1}),
]

# ---------------------------------------------------------------- SOCIAL / PENSIONES
M += [
    lv("pension_cap", "social", "Tope de pensiones máximas", "Límite a la pensión contributiva máxima.",
       ["Sin tope", "Actual", "Tope bajo"], base=1,
       fx={"pensions_gap": 0.1, "gini": -0.1}, cost={"pensiones": -0.5}, hits={"pensionistas": -0.4}, tags={"welfare": 0.1}),
    lv("pension_private", "social", "Planes privados de pensiones", "Incentivos al ahorro complementario.",
       ["Sin incentivos", "Deducción", "Planes de empleo"],
       fx={"investment": 0.4, "pensions_gap": -0.2, "gini": 0.05}, rev={"irpf": -0.3}, hits={"clase_media": 0.3, "autonomos": 0.3, "trabajadores": 0.2}, tags={"market": 0.4}),
    lv("mei", "social", "Mecanismo de Equidad Intergeneracional", "Cotización adicional para el sostenimiento del sistema.",
       ["Sin MEI", "0,6 %", "1,2 %"], base=1,
       fx={"pensions_gap": -0.4, "wages": -0.1}, rev={"cotizaciones": 0.7}, hits={"trabajadores": -0.3, "empresarios": -0.3, "jovenes": -0.1}, tags={"welfare": 0.2}),
    lv("contrib_years", "social", "Años de cómputo de la pensión", "Periodo usado para calcular la base reguladora.",
       ["Últimos 15 años", "Últimos 25 años", "Toda la vida laboral"], base=1,
       fx={"pensions_gap": -0.3}, cost={"pensiones": -0.5}, hits={"pensionistas": -0.5, "trabajadores": -0.4}, tags={"market": 0.2}),
    lv("disability_support", "social", "Dependencia y discapacidad", "Atención a personas dependientes.",
       ["Mínima", "Actual", "Ampliada"], base=1,
       fx={"poverty": -0.3, "equality": 0.2, "health": 0.1}, cost={"prestaciones": 1.0}, hits={"vulnerables": 0.8, "pensionistas": 0.4}, tags={"welfare": 0.5}),
    sp("homeless_plan", "social", "Plan contra el sinhogarismo", "Atención a personas sin hogar.", 1, 0, 4, 1, "bn €/año",
       fx={"poverty": -0.2, "crime": -0.05, "health": 0.05}, cost={"prestaciones": 1.0}, hits={"vulnerables": 0.5}, tags={"welfare": 0.3}),
]

# ---------------------------------------------------------------- FAMILIA Y NATALIDAD
M += [
    lv("maternity_leave", "family", "Permisos de maternidad y paternidad", "Semanas de permiso por nacimiento.",
       ["16 semanas", "20 semanas", "26 semanas"], base=0,
       fx={"birth": 0.03, "gender_gap": -0.5, "productivity": -0.02}, cost={"prestaciones": 0.8}, hits={"trabajadores": 0.5, "jovenes": 0.5, "empresarios": -0.4}, tags={"fem": 0.4, "welfare": 0.3}),
    sp("childcare", "family", "Guarderías 0–3 años", "Plazas públicas de educación infantil.", 2, 0, 8, 1, "bn €/año",
       fx={"birth": 0.04, "gender_gap": -0.3, "education": 0.2, "poverty": -0.1}, cost={"educacion": 1.0}, hits={"jovenes": 0.6, "trabajadores": 0.4, "clase_media": 0.5}, tags={"fem": 0.2, "welfare": 0.4}),
    lv("gender_pay", "family", "Brecha salarial de género", "Registros salariales y sanciones.",
       ["Sin medidas", "Registros", "Sanciones"],
       fx={"gender_gap": -0.8, "wages": 0.1}, hits={"trabajadores": 0.3, "empresarios": -0.4}, tags={"fem": 0.6, "prog": 0.2}),
    sp("domestic_violence", "family", "Pacto contra la violencia de género", "Recursos y protección a víctimas.", 2, 0, 6, 1, "bn €/año",
       fx={"crime": -0.3, "gender_gap": -0.2}, cost={"interior": 1.0}, hits={"jovenes": 0.4}, tags={"fem": 0.5}),
    lv("family_tax", "family", "Deducción por hijos", "Beneficio fiscal por descendientes.",
       ["Sin deducción", "Actual", "Ampliada"], base=1,
       fx={"birth": 0.03, "poverty": -0.1}, rev={"irpf": -0.5}, hits={"clase_media": 0.5, "trabajadores": 0.3}, tags={"cons": 0.2, "welfare": 0.2}),
    lv("youth_bonus", "family", "Bono joven de emancipación", "Ayuda directa mensual para jóvenes.",
       ["Sin bono", "Alquiler", "Universal"],
       fx={"rent_burden": -1.0, "youth_unemp": -0.1, "birth": 0.01}, cost={"vivienda": 0.8}, hits={"jovenes": 1.2}, tags={"welfare": 0.2}),
    lv("birth_bonus", "family", "Cheque bebé", "Pago único por nacimiento.",
       ["Sin cheque", "1.000 €", "2.500 €"],
       fx={"birth": 0.04}, cost={"prestaciones": 0.4}, hits={"jovenes": 0.3, "clase_media": 0.3}, tags={"cons": 0.2}),
]
