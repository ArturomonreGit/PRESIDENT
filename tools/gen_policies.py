#!/usr/bin/env python3
"""Genera data/scenarios/spain/policies.json y world.json a partir de src/policies_base.json + medidas nuevas."""
import json, os, sys, copy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measures_a, measures_b, measures_c, world_def as W

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "scenarios", "spain")
base = json.load(open(os.path.join(os.path.dirname(__file__), "src", "policies_base.json"), encoding="utf-8"))
P = copy.deepcopy(base)

# --- áreas
for a in W.AREAS_NEW:
    P["areas"].append(a)
for a in P["areas"]:
    if a["id"] == "security":
        a["desc"] = "Policía, ciberseguridad, orden público y política penal."
        a["name"] = "Seguridad"
    if a["id"] == "energy":
        a["name"] = "Energía y clima"
        a["desc"] = "Renovables, nuclear, fiscalidad verde y transición energética."
    if a["id"] == "tax":
        a["name"] = "Impuestos directos y cotizaciones"
        a["desc"] = "IRPF, sociedades, patrimonio, cotizaciones y lucha contra el fraude."
    if a["id"] == "social":
        a["name"] = "Pensiones y protección social"

# --- mover medidas existentes
for m in P["measures"]:
    if m["id"] in W.MOVES:
        m["area"] = W.MOVES[m["id"]]

# --- enriquecer medidas existentes con efectos sobre los indicadores nuevos (por paso)
ENRICH = {
    "rent_cap": {"rent_burden": -2.5, "house_price": -0.8, "housing_stock": -0.1, "investment": -0.4},
    "social_housing": {"housing_stock": 0.35, "rent_burden": -0.4, "house_price": -0.15},
    "rental_aid": {"rent_burden": -0.9, "house_price": 0.1},
    "land_liberalization": {"housing_stock": 0.3, "house_price": -1.5, "emissions": 1.0},
    "second_home_tax": {"house_price": -1.0, "tourism": -0.4},
    "first_home_tax": {"house_price": -0.5, "consumption": -0.2},
    "vat_general": {"consumption": -0.55, "informal": 0.1},
    "vat_basic": {"consumption": -0.15, "poverty": 0.12},
    "corp_tax": {"investment": -0.5, "entrepreneurship": -0.2, "exports": -0.05},
    "wealth_tax": {"investment": -0.5, "gini": -0.4},
    "inheritance_tax": {"gini": -0.2},
    "fuel_tax": {"emissions": -0.7, "energy_price": 0.5, "transit_share": 0.12, "farm_income": -0.3, "consumption": -0.12},
    "ssc_employer": {"wages": -0.15, "informal": 0.25, "investment": -0.2, "entrepreneurship": -0.1},
    "tax_fraud": {"informal": -0.9, "transparency": 0.2},
    "health_budget": {"waiting": -1.2, "life_exp": 0.02, "trust": 0.05},
    "health_staff": {"waiting": -1.8, "life_exp": 0.03},
    "waiting_lists": {"waiting": -8.0, "trust": 0.2},
    "pharma_copay": {"poverty": 0.1, "waiting": 0.3},
    "private_health": {"waiting": 3.0, "gini": 0.05},
    "public_health": {"life_exp": 0.05, "waiting": -0.6},
    "edu_budget": {"skills": 0.6, "dropout": -0.25, "r_d": 0.01},
    "scholarships": {"dropout": -0.3, "poverty": -0.05},
    "school_choice": {"skills": 0.0, "gini": 0.1},
    "vocational": {"youth_unemp": -0.6, "skills": 0.5, "dropout": -0.4, "productivity": 0.2},
    "tuition": {"dropout": 0.2, "skills": -0.1},
    "min_wage": {"wages": 0.35, "poverty": -0.12, "youth_unemp": 0.12, "informal": 0.08, "consumption": 0.1},
    "labour_flex": {"youth_unemp": -0.6, "wages": -0.25, "informal": -0.1, "productivity": 0.1},
    "workweek": {"productivity": 0.15, "wages": -0.1, "birth": 0.005},
    "unemp_benefit": {"poverty": -0.4, "consumption": 0.2, "informal": 0.1},
    "active_jobs": {"youth_unemp": -0.4, "skills": 0.3, "informal": -0.1},
    "self_employed_fee": {"entrepreneurship": -0.08, "informal": 0.05},
    "public_jobs": {"wages": 0.1, "productivity": -0.05, "trust": 0.02},
    "renewables": {"renewables": 1.8, "emissions": -1.6, "energy_price": -1.0, "investment": 0.4, "r_d": 0.02},
    "carbon_tax": {"emissions": -4.0, "energy_price": 2.5, "renewables": 0.8, "exports": -0.2, "poverty": 0.2},
    "nuclear": {"emissions": -3.0, "energy_price": -3.0, "renewables": -1.0, "trust": -0.1, "polarization": 0.2},
    "energy_cap": {"energy_price": -4.0, "renewables": -0.3},
    "public_transport": {"transit_share": 0.5, "emissions": -0.6},
    "zbe": {"emissions": -2.0, "transit_share": 1.0, "consumption": -0.1, "polarization": 0.2},
    "farm_aid": {"farm_income": 1.5, "rural": 0.3},
    "rural_plan": {"rural": 0.9, "farm_income": 0.3, "digital": 0.3},
    "police_budget": {"crime": -1.2, "trust": 0.1},
    "penal_code": {"crime": -1.0, "polarization": 0.3},
    "defense_budget": {"exports": 0.05},
    "immigration": {"net_migration": -90.0, "tension": 0.15},
    "justice_budget": {"court_delay": -1.8, "trust": 0.2},
    "surveillance": {"crime": -0.8, "transparency": -0.5, "trust": -0.3},
    "regional_funding": {"tension": -0.4, "waiting": -1.0},
    "competencies": {"tension": -1.2, "polarization": 0.3},
    "language_policy": {"tension": -0.6, "polarization": 0.25},
    "territorial_invest": {"rural": 0.2, "tension": -0.2},
    "pension_reval": {"pensions_gap": 0.4, "consumption": 0.15, "poverty": -0.15},
    "retirement_age": {"pensions_gap": -0.3, "youth_unemp": 0.1},
    "min_pension": {"poverty": -0.3, "pensions_gap": 0.1},
    "child_benefit": {"poverty": -0.4, "birth": 0.015},
    "dependency": {"poverty": -0.1},
    "basic_income": {"poverty": -3.0, "informal": 0.5, "consumption": 0.8, "gini": -1.5},
}
CORE_KEYS = {"growth", "unemployment", "inflation"} | {q["id"] for q in P["quality"]}
for m in P["measures"]:
    for k, v in ENRICH.get(m["id"], {}).items():
        assert k not in CORE_KEYS, (m["id"], k)
        m["fx"][k] = v

# --- medidas nuevas
new = measures_a.M + measures_b.M + measures_c.M
# Los efectos de las medidas nuevas sobre estos indicadores se escribieron en «puntos relativos»: se pasan a su unidad.
FXMUL = {"net_migration": 130.0, "trust": 4.0, "polarization": 4.0, "tension": 4.0}
for m in new:
    for k in list(m["fx"].keys()):
        if k in FXMUL:
            m["fx"][k] = round(m["fx"][k] * FXMUL[k], 3)
ids = [m["id"] for m in P["measures"]]
for m in new:
    if m["id"] in ids:
        sys.exit("id duplicado: " + m["id"])
    ids.append(m["id"])
P["measures"] += new

# --- gustos de los grupos
for g in P["groups"]:
    g.setdefault("likes", {})
    for k, v in W.GROUP_LIKES.get(g["id"], {}).items():
        g["likes"][k] = v

# --- validación
area_ids = {a["id"] for a in P["areas"]}
quality = {q["id"] for q in P["quality"]}
core = {"growth", "unemployment", "inflation"} | quality
ind = {i["id"] for i in W.INDICATORS}
budget = {b["id"] for b in P["budget"]}
taxes = {t["id"] for t in P["taxes"]}
groups = {g["id"] for g in P["groups"]}
sectors = {s["id"] for s in P["sectors"]}
errs = []
for m in P["measures"]:
    if m["area"] not in area_ids: errs.append((m["id"], "area", m["area"]))
    for k in m["fx"]:
        if k not in core and k not in ind: errs.append((m["id"], "fx", k))
    for k in m["cost"]:
        if k not in budget: errs.append((m["id"], "cost", k))
    for k in m["rev"]:
        if k not in taxes: errs.append((m["id"], "rev", k))
    for k in m["hits"]:
        if k not in groups: errs.append((m["id"], "hits", k))
    for k in m["sec"]:
        if k not in sectors: errs.append((m["id"], "sec", k))
    if m["labels"] and len(m["labels"]) != int(m["max"] - m["min"]) + 1: errs.append((m["id"], "labels", len(m["labels"])))
    if not (m["min"] <= m["base"] <= m["max"]): errs.append((m["id"], "base", m["base"]))
for i in W.INDICATORS:
    for k in list(i["links"]) + list(i["bf"]):
        if k not in ind and k not in core and k not in budget and k not in ("rate", "deficit"): errs.append((i["id"], "link", k))
for g, d in W.GROUP_LIKES.items():
    for k in d:
        if k not in ind: errs.append((g, "glike", k))
for g, d in W.FEEDS.items():
    for k in d:
        if k not in ind: errs.append((g, "feed", k))
if errs:
    for e in errs: print("ERROR", e)
    sys.exit(1)

json.dump(P, open(os.path.join(OUT, "policies.json"), "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
world = {"indicators": W.INDICATORS, "feeds": W.FEEDS}
json.dump(world, open(os.path.join(OUT, "world.json"), "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
from collections import Counter
c = Counter(m["area"] for m in P["measures"])
print(len(P["measures"]), "medidas;", len(P["areas"]), "áreas;", len(W.INDICATORS), "indicadores")
print(dict(c))
