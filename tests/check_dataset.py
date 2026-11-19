import json
from pathlib import Path

data = json.loads(Path("data/scenarios/spain/constituencies_2023.json").read_text(encoding="utf-8"))
constituencies = data["constituencies"]
assert len(constituencies) == 52, len(constituencies)
assert sum(c["seats"] for c in constituencies) == 350
assert sum(1 for c in constituencies if c["autonomous_community"] not in ("Ceuta", "Melilla")) == 50
print("OK: 52 circunscripciones y 350 escaños.")

# Medidas e indicadores (generados por tools/gen_policies.py)
pol = json.loads(Path("data/scenarios/spain/policies.json").read_text(encoding="utf-8"))
world = json.loads(Path("data/scenarios/spain/world.json").read_text(encoding="utf-8"))
area_ids = {a["id"] for a in pol["areas"]}
assert len(area_ids) == 18, len(area_ids)
ind_ids = {i["id"] for i in world["indicators"]}
core = {"growth", "unemployment", "inflation"} | {q["id"] for q in pol["quality"]}
meas_ids = set()
for ms in pol["measures"]:
    assert ms["id"] not in meas_ids, "medida duplicada " + ms["id"]
    meas_ids.add(ms["id"])
    assert ms["area"] in area_ids, ms["id"]
    assert ms["min"] <= ms["base"] <= ms["max"], ms["id"]
    for k in ms.get("fx", {}):
        assert k in ind_ids or k in core, (ms["id"], k)
per = {a: sum(1 for ms in pol["measures"] if ms["area"] == a) for a in area_ids}
assert min(per.values()) >= 7, per
print("OK: %d medidas en %d áreas, %d indicadores." % (len(meas_ids), len(area_ids), len(ind_ids)))
