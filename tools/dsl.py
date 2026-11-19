"""DSL para definir medidas: cada medida es un «mando» con efectos por paso respecto a su valor base."""
TAGS = {
    "welfare": ((-0.6, 0, 0), {"igualdad": 0.4, "socialdemocracia": 0.4, "liberalismo_economico": -0.5}),
    "market": ((0.6, 0, 0), {"liberalismo_economico": 0.6, "igualdad": -0.2}),
    "green": ((-0.1, -0.2, 0), {"ecologismo": 0.6, "progresismo": 0.2}),
    "brown": ((0.2, 0.1, 0), {"ecologismo": -0.5, "liberalismo_economico": 0.2}),
    "prog": ((0, -0.6, 0), {"progresismo": 0.5, "feminismo": 0.2, "laicismo": 0.2, "conservadurismo": -0.4}),
    "cons": ((0, 0.6, 0), {"conservadurismo": 0.5, "cristianodemocracia": 0.3, "progresismo": -0.3}),
    "order": ((0, 0.4, 0), {"conservadurismo": 0.2, "patriotismo": 0.3}),
    "liberty": ((0, -0.4, 0), {"progresismo": 0.3, "anarquismo": 0.1}),
    "central": ((0, 0, -0.6), {"centralismo": 0.6, "nacionalismo": -0.4, "patriotismo": 0.3, "federalismo": -0.4}),
    "federal": ((0, 0, 0.6), {"federalismo": 0.4, "nacionalismo": 0.5, "centralismo": -0.5}),
    "eu": ((0, 0, 0), {"europeismo": 0.5}),
    "patriot": ((0, 0.2, -0.2), {"patriotismo": 0.5, "nacionalismo": -0.2}),
    "fem": ((0, -0.3, 0), {"feminismo": 0.6, "igualdad": 0.2}),
    "socialist": ((-0.8, 0, 0), {"socialismo": 0.5, "comunismo": 0.2, "liberalismo_economico": -0.7}),
}

def _tags(t):
    lean = [0.0, 0.0, 0.0]
    likes = {}
    for k, w in (t or {}).items():
        lv, lk = TAGS[k]
        for i in range(3):
            lean[i] += lv[i] * w
        for g, x in lk.items():
            likes[g] = round(likes.get(g, 0.0) + x * w, 2)
    cl = lambda v: round(max(-1.0, min(1.0, v)), 2)
    return {"economic": cl(lean[0]), "social": cl(lean[1]), "territorial": cl(lean[2])}, {k: cl(v) for k, v in likes.items() if abs(v) >= 0.05}

def measure(id, area, name, desc, base, lo, hi, step, unit="", labels=None, fx=None, cost=None, rev=None, hits=None, tags=None, sec=None):
    lean, likes = _tags(tags)
    return {"id": id, "area": area, "name": name, "desc": desc, "base": base, "min": lo, "max": hi, "step": step, "unit": unit,
            "labels": labels or [], "fx": fx or {}, "cost": cost or {}, "rev": rev or {}, "hits": hits or {},
            "lean": lean, "likes": likes, "sec": sec or {}}

def lv(id, area, name, desc, labels, base=0, **kw):
    """Medida de niveles (0…n-1) con etiquetas."""
    return measure(id, area, name, desc, base, 0, len(labels) - 1, 1, "", labels, **kw)

def sp(id, area, name, desc, base, lo, hi, step, unit="bn €/año", **kw):
    """Medida de gasto o magnitud numérica."""
    return measure(id, area, name, desc, base, lo, hi, step, unit, None, **kw)
