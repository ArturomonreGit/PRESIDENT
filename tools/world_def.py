"""Indicadores del país y vínculos causales. start = valor inicial (España ≈ 2023); scale = variación «típica» (1 z);
rate = fracción del hueco que se cierra cada mes; good = +1 si más es mejor, -1 si menos es mejor, 0 neutro."""

def I(id, name, domain, unit, start, scale, lo, hi, good, rate, dec, desc, links=None, bf=None):
    return {"id": id, "name": name, "domain": domain, "unit": unit, "start": start, "scale": scale, "min": lo, "max": hi,
            "good": good, "rate": rate, "dec": dec, "desc": desc, "links": links or {}, "bf": bf or {}}

INDICATORS = [
    # ---------- economía
    I("wages", "Salario real", "jobs", "índice", 100, 5, 70, 140, 1, 0.05, 1, "Poder adquisitivo de los salarios (base 100).",
      {"productivity": 2.0, "unemployment": -1.6, "inflation": -1.2}),
    I("productivity", "Productividad", "science", "índice", 100, 5, 75, 130, 1, 0.04, 1, "Valor producido por hora trabajada (base 100).",
      {"r_d": 1.1, "digital": 1.0, "investment": 0.9, "skills": 0.8, "informal": -0.5}),
    I("investment", "Inversión empresarial", "industry", "índice", 100, 8, 60, 150, 1, 0.08, 1, "Inversión privada en equipos y capacidad (base 100).",
      {"growth": 2.2, "rate": -1.8, "trust": 0.9, "deficit": -0.6, "productivity": 0.5}),
    I("exports", "Exportaciones", "industry", "% PIB", 35, 4, 22, 50, 1, 0.05, 1, "Ventas al exterior sobre el PIB.",
      {"energy_price": -0.9, "productivity": 0.8, "wages": -0.4, "inflation": -0.4}),
    I("consumption", "Consumo de los hogares", "indirect", "índice", 100, 4, 75, 125, 1, 0.10, 1, "Gasto de las familias (base 100).",
      {"wages": 1.8, "unemployment": -1.5, "inflation": -1.3, "rent_burden": -0.8, "trust": 0.6}),
    I("house_price", "Precio de la vivienda", "housing", "índice", 100, 10, 60, 180, 0, 0.04, 1, "Precio medio de la vivienda (base 100).",
      {"rate": -2.0, "growth": 1.2, "housing_stock": -1.0, "net_migration": 1.0, "tourism": 0.7, "consumption": 0.4}),
    I("rent_burden", "Esfuerzo del alquiler", "housing", "% renta", 37, 5, 20, 60, -1, 0.05, 1, "Parte de la renta que gasta en alquiler un hogar joven.",
      {"house_price": 1.6, "wages": -1.0, "housing_stock": -1.0, "net_migration": 0.8, "tourism": 0.6}),
    I("youth_unemp", "Paro juvenil", "jobs", "%", 28, 5, 8, 55, -1, 0.06, 1, "Paro entre menores de 25 años.",
      {"unemployment": 5.5, "skills": -0.8, "dropout": 0.6}),
    I("informal", "Economía sumergida", "jobs", "% PIB", 17, 2.5, 6, 30, -1, 0.04, 1, "Actividad que no tributa ni cotiza.",
      {"transparency": -1.0, "poverty": 0.5, "unemployment": 0.5}),
    I("tourism", "Turismo", "industry", "índice", 100, 8, 60, 140, 1, 0.06, 1, "Llegadas y gasto turístico (base 100).",
      {"energy_price": -0.6, "inflation": -0.5, "crime": -0.8, "trust": 0.3}),
    I("entrepreneurship", "Creación de empresas", "industry", "índice", 100, 8, 60, 150, 1, 0.06, 1, "Nuevas empresas por año (base 100).",
      {"growth": 1.6, "rate": -0.9, "digital": 1.0, "informal": -0.5}),
    # ---------- sociedad
    I("poverty", "Riesgo de pobreza", "social", "%", 20.2, 3, 8, 38, -1, 0.04, 1, "Población bajo el umbral de pobreza (60 % de la mediana).",
      {"unemployment": 1.8, "wages": -1.0, "inflation": 0.7, "rent_burden": 0.9, "gini": 0.7}),
    I("gini", "Desigualdad (Gini)", "social", "puntos", 31.5, 2, 22, 45, -1, 0.03, 1, "Índice de Gini de la renta (0-100).",
      {"poverty": 0.5, "unemployment": 0.5, "wages": -0.4, "informal": 0.3}),
    I("life_exp", "Esperanza de vida", "health", "años", 83.2, 1, 76, 90, 1, 0.02, 1, "Años de vida al nacer.",
      {"health": 0.35, "poverty": -0.15, "waiting": -0.1, "environment": 0.2}),
    I("waiting", "Espera sanitaria", "health", "días", 110, 20, 30, 260, -1, 0.06, 0, "Demora media para una consulta con especialista.",
      {"health": -16.0, "net_migration": 3.0}, {"sanidad": -60.0}),
    I("dropout", "Abandono escolar", "education", "%", 13.9, 3, 4, 28, -1, 0.04, 1, "Jóvenes de 18-24 años que dejaron los estudios.",
      {"education": -2.2, "poverty": 1.0, "youth_unemp": 0.5}),
    I("skills", "Competencias (PISA)", "education", "puntos", 474, 15, 420, 540, 1, 0.03, 0, "Resultados PISA de los alumnos de 15 años.",
      {"education": 5.0, "poverty": -2.0, "digital": 1.5, "dropout": -2.0}),
    I("crime", "Criminalidad", "security", "‰ hab.", 44, 5, 20, 90, -1, 0.05, 1, "Infracciones penales por cada 1.000 habitantes.",
      {"unemployment": 1.5, "poverty": 1.2, "security": -3.0, "gini": 1.0, "polarization": 0.5}),
    I("court_delay", "Duración de los juicios", "justice", "meses", 12, 3, 4, 30, -1, 0.04, 1, "Tiempo medio de un procedimiento civil.",
      {"digital": -0.8}, {"justicia": -14.0}),
    I("trust", "Confianza institucional", "justice", "0-100", 40, 8, 10, 80, 1, 0.04, 0, "Confianza de los ciudadanos en las instituciones.",
      {"transparency": 3.0, "polarization": -2.5, "crime": -0.8, "unemployment": -1.2, "inflation": -1.0, "tension": -1.0}),
    I("transparency", "Transparencia", "justice", "0-100", 60, 6, 20, 95, 1, 0.04, 0, "Percepción de limpieza de la vida pública.",
      {"digital": 0.8}),
    I("net_migration", "Inmigración neta", "immigration", "miles/año", 640, 150, 0, 1400, 0, 0.06, 0, "Saldo migratorio anual.",
      {"growth": 60.0, "unemployment": -40.0}),
    I("birth", "Natalidad", "family", "hijos/mujer", 1.12, 0.1, 0.8, 1.9, 1, 0.02, 2, "Fecundidad.",
      {"wages": 0.03, "rent_burden": -0.03, "unemployment": -0.03}),
    I("gender_gap", "Brecha salarial de género", "family", "%", 12, 2, 2, 25, -1, 0.04, 1, "Diferencia media de salario entre mujeres y hombres.",
      {}),
    I("pensions_gap", "Déficit de pensiones", "social", "% PIB", 2.6, 0.8, -1, 8, -1, 0.04, 2, "Gasto en pensiones no cubierto por cotizaciones.",
      {"unemployment": 0.4, "wages": -0.3, "net_migration": -0.3, "productivity": -0.2}),
    I("polarization", "Polarización", "territory", "0-100", 55, 8, 15, 95, -1, 0.04, 0, "Distancia entre bloques políticos en la sociedad.",
      {"gini": 1.5, "unemployment": 1.0, "tension": 1.5, "trust": -1.5, "inflation": 0.5}),
    I("tension", "Tensión territorial", "territory", "0-100", 50, 8, 10, 95, -1, 0.04, 0, "Conflicto entre el Estado y las autonomías.",
      {"polarization": 1.0}),
    # ---------- energía, medio ambiente, territorio
    I("emissions", "Emisiones de CO₂", "energy", "Mt", 288, 25, 150, 380, -1, 0.03, 0, "Emisiones de gases de efecto invernadero.",
      {"growth": 12.0, "renewables": -10.0, "energy_price": -3.0, "transit_share": -6.0}),
    I("renewables", "Renovables en electricidad", "energy", "%", 50, 8, 20, 95, 1, 0.03, 0, "Peso de las renovables en la generación eléctrica.",
      {"investment": 1.0}),
    I("energy_price", "Precio de la energía", "energy", "índice", 100, 15, 50, 220, -1, 0.10, 0, "Factura energética de familias y empresas (base 100).",
      {"renewables": -2.0}),
    I("transit_share", "Uso del transporte público", "transport", "%", 14, 3, 5, 40, 1, 0.05, 1, "Viajes diarios en transporte colectivo.",
      {"infrastructure": 1.0, "energy_price": 0.5}),
    I("rural", "Población rural", "agriculture", "índice", 100, 3, 80, 115, 1, 0.02, 1, "Habitantes de municipios pequeños (base 100).",
      {"farm_income": 0.8, "digital": 0.4, "infrastructure": 0.5}),
    I("farm_income", "Renta agraria", "agriculture", "índice", 100, 8, 60, 150, 1, 0.06, 1, "Ingreso de agricultores y ganaderos (base 100).",
      {"energy_price": -1.8, "exports": 0.8, "inflation": -0.3}),
    I("digital", "Digitalización", "science", "0-100", 60, 6, 30, 95, 1, 0.04, 1, "Índice de economía y sociedad digitales.",
      {"r_d": 3.0, "investment": 1.0, "skills": 1.0}),
    I("r_d", "Inversión en I+D", "science", "% PIB", 1.4, 0.3, 0.6, 3.5, 1, 0.03, 2, "Gasto total en investigación y desarrollo.",
      {"growth": 0.04}, {"ciencia": 0.8}),
    I("housing_stock", "Vivienda protegida", "housing", "% parque", 2.5, 1.0, 0.5, 12, 1, 0.02, 1, "Vivienda pública y protegida sobre el total.",
      {}, {"vivienda": 3.0}),
]

# Efecto de los indicadores nuevos sobre los «mandos» centrales de la economía (por z de desviación, sobre el objetivo).
FEEDS = {
    "growth": {"productivity": 0.12, "investment": 0.10, "exports": 0.05, "consumption": 0.12, "tourism": 0.04, "trust": 0.05,
               "informal": -0.03, "entrepreneurship": 0.05, "energy_price": -0.07, "poverty": -0.03},
    "unemployment": {"wages": 0.06, "entrepreneurship": -0.10, "tourism": -0.08, "skills": -0.05, "informal": 0.04},
    "inflation": {"energy_price": 0.22, "wages": 0.10, "consumption": 0.10, "house_price": 0.05, "tourism": 0.03},
}

# Gustos adicionales de los grupos (puntos de satisfacción por z de desviación del indicador). Signo según convenga al grupo.
GROUP_LIKES = {
    "jovenes": {"rent_burden": -1.6, "youth_unemp": -1.2, "house_price": -0.6, "emissions": -0.5, "digital": 0.4, "gender_gap": -0.3},
    "trabajadores": {"wages": 1.6, "informal": -0.2, "poverty": -0.3, "crime": -0.3, "energy_price": -0.8},
    "clase_media": {"house_price": 0.4, "energy_price": -0.8, "crime": -0.5, "wages": 1.0, "waiting": -0.4, "skills": 0.4},
    "autonomos": {"entrepreneurship": 0.8, "energy_price": -0.6, "informal": -0.3, "digital": 0.3},
    "empresarios": {"investment": 0.9, "exports": 0.8, "productivity": 0.6, "energy_price": -0.5, "r_d": 0.4},
    "funcionarios": {"wages": 0.6, "trust": 0.4, "waiting": -0.3, "skills": 0.4},
    "pensionistas": {"waiting": -0.8, "life_exp": 0.4, "crime": -0.5, "energy_price": -0.6, "pensions_gap": -0.4},
    "parados": {"youth_unemp": -0.6, "poverty": -0.6, "wages": 0.3},
    "rurales": {"rural": 1.2, "farm_income": 0.9, "digital": 0.5, "energy_price": -0.6, "transit_share": 0.3},
    "vulnerables": {"poverty": -1.4, "rent_burden": -0.9, "energy_price": -0.9, "gini": -0.5},
}

# Medidas existentes que cambian de área al ampliar el catálogo.
MOVES = {
    "vat_general": "indirect", "vat_basic": "indirect", "fuel_tax": "indirect",
    "public_transport": "transport", "farm_aid": "agriculture", "rural_plan": "agriculture",
    "defense_budget": "defense", "immigration": "immigration", "justice_budget": "justice", "child_benefit": "family",
}

AREAS_NEW = [
    {"id": "indirect", "name": "Impuestos al consumo", "issue": "tax", "ministry": "Hacienda", "color": "#A8741A", "desc": "IVA, impuestos especiales y tasas sobre el consumo."},
    {"id": "science", "name": "Ciencia y digitalización", "issue": "education", "ministry": "Ciencia y Universidades", "color": "#0E7490", "desc": "I+D, universidades, banda ancha y administración digital."},
    {"id": "industry", "name": "Industria, comercio y turismo", "issue": "jobs", "ministry": "Industria y Comercio", "color": "#8B5E3C", "desc": "Política industrial, comercio exterior, pymes y turismo."},
    {"id": "transport", "name": "Transportes", "issue": "energy", "ministry": "Transportes y Movilidad", "color": "#4C6EF5", "desc": "Ferrocarril, carreteras, aeropuertos y movilidad urbana."},
    {"id": "agriculture", "name": "Agricultura y medio rural", "issue": "territory", "ministry": "Agricultura y Alimentación", "color": "#7CB518", "desc": "PAC, regadíos, pesca, alimentación y despoblación."},
    {"id": "justice", "name": "Justicia y derechos", "issue": "security", "ministry": "Justicia", "color": "#6D597A", "desc": "Tribunales, anticorrupción, derechos civiles y libertades."},
    {"id": "immigration", "name": "Inmigración", "issue": "security", "ministry": "Interior", "color": "#20C997", "desc": "Fronteras, regularización, asilo e integración."},
    {"id": "defense", "name": "Defensa y exteriores", "issue": "security", "ministry": "Defensa", "color": "#495057", "desc": "Defensa, OTAN, cooperación y relaciones con Europa."},
    {"id": "family", "name": "Familia e igualdad", "issue": "jobs", "ministry": "Igualdad", "color": "#AE3EC9", "desc": "Natalidad, conciliación, igualdad y juventud."},
]
