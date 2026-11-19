from dsl import lv, sp

M = []

# ---------------------------------------------------------------- VIVIENDA
M += [
    lv("housing_credit", "housing", "Avales públicos a la compra", "Garantías del Estado para financiar la entrada de la primera vivienda.",
       ["Sin avales", "Jóvenes (ICO)", "Ampliados", "Universales"],
       fx={"housing": 0.9, "house_price": 3.0, "inflation": 0.01}, cost={"vivienda": 0.6}, hits={"jovenes": 1.6, "clase_media": 0.4}, tags={"market": 0.2}),
    lv("protected_quota", "housing", "Reserva de vivienda protegida", "Porcentaje obligatorio de VPO en los nuevos desarrollos urbanísticos.",
       ["Sin reserva", "10 %", "30 %", "50 %"],
       fx={"housing": 1.1, "house_price": -1.5, "housing_stock": 0.8, "growth": -0.01}, hits={"jovenes": 1.2, "empresarios": -0.6, "autonomos": -0.3},
       tags={"welfare": 0.6}, sec={"construccion": -0.2}),
    lv("tourist_rentals", "housing", "Pisos turísticos", "Régimen de los alquileres de corta duración.",
       ["Libre", "Con licencia", "Límites por zona", "Prohibición"],
       fx={"housing": 1.0, "tourism": -3.0, "rent_burden": -1.2, "house_price": -1.0}, hits={"jovenes": 0.8, "empresarios": -0.5, "autonomos": -0.4},
       tags={"welfare": 0.3, "green": 0.2}),
    lv("mortgage_deduction", "housing", "Deducción por vivienda habitual", "Desgravación fiscal de la hipoteca en el IRPF.",
       ["Sin deducción", "Solo jóvenes", "Para todos"],
       fx={"housing": 0.4, "house_price": 2.0}, rev={"irpf": -1.0}, hits={"clase_media": 1.0, "jovenes": 0.5}, tags={"market": 0.3}),
]

# ---------------------------------------------------------------- FISCALIDAD DIRECTA
M += [
    sp("ssc_worker", "tax", "Cotización del trabajador", "Porcentaje del salario bruto que cotiza el trabajador.", 6.4, 4.0, 9.0, 0.5, "%",
       fx={"wages": -0.15, "consumption": -0.1, "growth": -0.01}, rev={"cotizaciones": 2.6}, hits={"trabajadores": -0.5, "clase_media": -0.3}, tags={"welfare": -0.3}),
    lv("bank_levy", "tax", "Gravamen a banca y energéticas", "Impuesto extraordinario sobre márgenes de bancos y grandes energéticas.",
       ["Sin gravamen", "Temporal", "Permanente"],
       fx={"investment": -1.5, "energy_price": 0.5}, rev={"sociedades": 1.8}, hits={"empresarios": -1.0, "trabajadores": 0.2}, tags={"welfare": 0.5, "socialist": 0.2}),
    sp("capital_gains", "tax", "Impuesto sobre ganancias de capital", "Tipo máximo sobre dividendos y plusvalías del ahorro.", 26, 19, 35, 1, "%",
       fx={"investment": -0.25, "gini": -0.06}, rev={"irpf": 0.45}, hits={"empresarios": -0.4, "clase_media": -0.1}, tags={"welfare": 0.3}),
    lv("tobin_tax", "tax", "Tasa sobre transacciones financieras", "Gravamen a la compraventa de acciones y derivados.",
       ["Sin tasa", "0,2 %", "0,5 %"],
       fx={"investment": -0.6, "entrepreneurship": -0.3}, rev={"otros": 1.5}, hits={"empresarios": -0.6}, tags={"welfare": 0.4}),
    lv("sme_tax", "tax", "Tipo reducido para pymes", "Sociedades más bajo para pequeñas empresas.",
       ["Sin reducción", "Pymes < 1 M€", "Pymes < 10 M€"],
       fx={"entrepreneurship": 2.5, "investment": 0.6, "informal": -0.3}, rev={"sociedades": -1.2}, hits={"autonomos": 1.4, "empresarios": 0.4}, tags={"market": 0.4}),
    lv("ssc_cap", "tax", "Tope de cotización", "Base máxima de cotización a la Seguridad Social.",
       ["Se reduce", "Actual", "Sube un 15 %", "Sube un 30 %"], base=1,
       fx={"pensions_gap": -0.12, "investment": -0.4, "wages": -0.1}, rev={"cotizaciones": 2.0}, hits={"empresarios": -0.6, "autonomos": -0.3, "pensionistas": 0.3}, tags={"welfare": 0.4}),
]

# ---------------------------------------------------------------- IMPUESTOS AL CONSUMO
M += [
    sp("vat_reduced", "indirect", "IVA reducido", "Tipo del 10 % en restauración, transporte y hostelería.", 10, 4, 15, 1, "%",
       fx={"tourism": -0.5, "inflation": 0.03, "consumption": -0.1}, rev={"iva": 1.0}, hits={"clase_media": -0.3, "autonomos": -0.4}, tags={"welfare": 0.1}),
    sp("tobacco_alcohol", "indirect", "Impuestos al tabaco y alcohol", "Nivel de los impuestos especiales sobre tabaco y alcohol.", 100, 70, 170, 10, "índice",
       fx={"health": 0.2, "life_exp": 0.02}, rev={"iiee": 0.9}, hits={"vulnerables": -0.2}, tags={"welfare": 0.1, "cons": 0.1}),
    lv("sugar_tax", "indirect", "Impuesto a bebidas azucaradas", "Gravamen sobre refrescos y bollería industrial.",
       ["Sin impuesto", "Bebidas", "Bebidas y ultraprocesados"],
       fx={"health": 0.6, "life_exp": 0.05, "inflation": 0.01}, rev={"iiee": 0.4}, hits={"vulnerables": -0.4, "clase_media": -0.2}, tags={"green": 0.2, "welfare": 0.1}),
    lv("plastic_tax", "indirect", "Impuesto a plásticos y envases", "Tasa sobre plásticos de un solo uso.",
       ["Sin tasa", "Plástico no reutilizable", "Todos los envases"],
       fx={"environment": 0.8, "emissions": -1.0, "inflation": 0.02}, rev={"iiee": 0.5}, hits={"empresarios": -0.3}, tags={"green": 0.6}),
    lv("tourist_tax", "indirect", "Tasa turística", "Ecotasa por pernoctación en zonas turísticas.",
       ["Sin tasa", "Local", "Estatal"],
       fx={"tourism": -1.2, "environment": 0.3, "rural": 0.0}, rev={"otros": 0.5}, hits={"autonomos": -0.4}, tags={"green": 0.3, "welfare": 0.2}),
    lv("digital_tax", "indirect", "Tasa a las tecnológicas", "Impuesto sobre servicios digitales de las grandes plataformas.",
       ["Sin tasa", "3 %", "5 %"],
       fx={"digital": -0.4, "investment": -0.3, "innovation": -0.1}, rev={"sociedades": 0.7}, hits={"empresarios": -0.4, "jovenes": 0.1}, tags={"welfare": 0.3, "eu": 0.2}),
    lv("luxury_tax", "indirect", "Impuesto al lujo", "Recargo sobre yates, joyas y coches de alta gama.",
       ["Sin recargo", "Recargo moderado", "Recargo alto"],
       fx={"gini": -0.08}, rev={"iiee": 0.5}, hits={"empresarios": -0.5}, tags={"welfare": 0.4, "socialist": 0.2}),
]

# ---------------------------------------------------------------- SANIDAD
M += [
    lv("dental_cover", "health", "Cobertura dental y óptica", "Prestaciones públicas de salud bucodental y visión.",
       ["Sin cobertura", "Infancia", "Mayores y niños", "Universal"],
       fx={"health": 0.9, "life_exp": 0.03, "equality": 0.5}, cost={"sanidad": 1.5}, hits={"vulnerables": 1.2, "pensionistas": 0.9, "clase_media": 0.6}, tags={"welfare": 0.5}),
    lv("drug_prices", "health", "Compra pública de medicamentos", "Centralización y negociación de precios de fármacos.",
       ["Sin cambios", "Compra conjunta", "Genéricos obligatorios"],
       fx={"health": 0.1, "innovation": -0.2}, cost={"sanidad": -0.8}, hits={"empresarios": -0.3, "pensionistas": 0.2}, tags={"welfare": 0.3}),
    lv("mental_health", "health", "Plan de salud mental", "Psicólogos en atención primaria y prevención del suicidio.",
       ["Sin plan", "Básico", "Reforzado", "Integral"],
       fx={"health": 0.8, "trust": 0.4, "life_exp": 0.03}, cost={"sanidad": 1.0}, hits={"jovenes": 1.0, "clase_media": 0.5}, tags={"welfare": 0.3, "prog": 0.2}),
    lv("primary_care", "health", "Atención primaria", "Refuerzo de centros de salud y médicos de familia.",
       ["Sin refuerzo", "Moderado", "Intensivo", "Máximo"],
       fx={"health": 1.0, "waiting": -9.0, "life_exp": 0.04}, cost={"sanidad": 2.0}, hits={"rurales": 1.0, "pensionistas": 1.0, "clase_media": 0.5}, tags={"welfare": 0.4}),
]

# ---------------------------------------------------------------- EDUCACIÓN
M += [
    sp("class_size", "education", "Alumnos por aula", "Ratio máxima de alumnos por clase en la escuela pública.", 25, 15, 30, 1, "alumnos",
       fx={"education": -0.35, "dropout": 0.12, "skills": -1.0}, cost={"educacion": -0.7}, hits={"funcionarios": -0.4, "clase_media": -0.2}, tags={"welfare": 0.2}),
    lv("early_ed", "education", "Educación infantil gratuita (3-6)", "Plazas públicas y gratuitas de escuela infantil.",
       ["Parcial", "Universal 3-6", "Universal 0-6"],
       fx={"education": 0.6, "equality": 0.6, "birth": 0.02, "gender_gap": -0.3}, cost={"educacion": 1.8}, hits={"clase_media": 0.8, "vulnerables": 0.8, "trabajadores": 0.6}, tags={"welfare": 0.4, "fem": 0.3}),
    lv("digital_school", "education", "Aulas digitales", "Equipamiento y formación digital en los centros.",
       ["Sin plan", "Básico", "Avanzado", "Total"],
       fx={"skills": 2.0, "digital": 1.0, "education": 0.3}, cost={"educacion": 0.6, "ciencia": 0.2}, hits={"jovenes": 0.4, "funcionarios": 0.3}, tags={"market": 0.1}),
    lv("external_exams", "education", "Evaluaciones externas", "Pruebas estandarizadas y rendición de cuentas de los centros.",
       ["Sin pruebas", "Muestrales", "Censales"],
       fx={"skills": 3.0, "dropout": 0.4, "equality": -0.2}, hits={"funcionarios": -0.5}, tags={"market": 0.3, "cons": 0.2}),
]

# ---------------------------------------------------------------- CIENCIA Y DIGITALIZACIÓN
M += [
    sp("rd_budget", "science", "Inversión pública en I+D+i", "Presupuesto estatal de investigación e innovación.", 6, 3, 20, 1, "bn €/año",
       fx={"innovation": 0.35, "r_d": 0.05, "productivity": 0.2, "growth": 0.01}, cost={"ciencia": 1.0}, hits={"jovenes": 0.15, "funcionarios": 0.1}, tags={"market": 0.0, "eu": 0.2}),
    sp("uni_funding", "science", "Financiación universitaria", "Transferencias a las universidades públicas.", 8, 5, 18, 1, "bn €/año",
       fx={"education": 0.25, "skills": 0.6, "innovation": 0.2, "equality": 0.1}, cost={"educacion": 1.0}, hits={"jovenes": 0.3, "funcionarios": 0.2}, tags={"welfare": 0.2}),
    lv("rd_credit", "science", "Deducciones por I+D", "Incentivos fiscales a la inversión privada en innovación.",
       ["Sin incentivos", "Actuales", "Ampliados", "Máximos"], base=1,
       fx={"innovation": 0.3, "r_d": 0.05, "investment": 0.8, "productivity": 0.2}, rev={"sociedades": -0.4}, hits={"empresarios": 0.6}, tags={"market": 0.3}),
    lv("digital_admin", "science", "Administración digital", "Trámites online, datos abiertos e identidad digital.",
       ["Sin plan", "Básica", "Avanzada", "Total"],
       fx={"transparency": 1.0, "digital": 1.5, "informal": -0.3, "productivity": 0.3}, cost={"administracion": 0.5}, hits={"autonomos": 0.5, "jovenes": 0.3}, tags={"eu": 0.1}),
    lv("rural_broadband", "science", "Banda ancha rural", "Fibra y cobertura móvil en municipios pequeños.",
       ["Sin plan", "Parcial", "Total"],
       fx={"digital": 1.5, "rural": 0.4, "infrastructure": 0.5}, cost={"ciencia": 0.4}, hits={"rurales": 1.2}, tags={"welfare": 0.1}),
    lv("startup_law", "science", "Ley de startups", "Visados, opciones sobre acciones y capital riesgo.",
       ["Sin ley", "Básica", "Avanzada"],
       fx={"entrepreneurship": 4.0, "innovation": 0.3, "digital": 0.5, "investment": 0.5}, rev={"irpf": -0.1}, hits={"jovenes": 0.5, "autonomos": 0.6}, tags={"market": 0.3}),
    lv("talent_return", "science", "Retorno de talento", "Incentivos para científicos y profesionales que vuelven a España.",
       ["Sin programa", "Pequeño", "Grande"],
       fx={"r_d": 0.04, "productivity": 0.3, "innovation": 0.3}, cost={"ciencia": 0.4}, hits={"jovenes": 0.5}, tags={"eu": 0.1}),
    lv("ai_regulation", "science", "Regulación de la IA y los datos", "Marco legal para algoritmos y protección de datos.",
       ["Libre", "Autorregulación", "Supervisión estatal", "Estricta"],
       fx={"digital": -0.4, "trust": 0.5, "innovation": -0.15}, cost={"administracion": 0.3}, hits={"jovenes": 0.1}, tags={"liberty": 0.3, "eu": 0.3}),
]
