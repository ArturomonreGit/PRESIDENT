#!/usr/bin/env python3
"""Genera data/maps/spain_provinces_real.json a partir de un GeoJSON de provincias de España.

Fuente de geometría: click_that_hood (spain-provinces.geojson), basado en los límites provinciales del IGN/INE.
Uso: python3 tools/build_map.py spain-provinces.geojson data/maps/spain_provinces_real.json
"""
import json, math, sys

NAME_FIX = {
    "Alacant/Alicante": "Alicante/Alacant",
    "Bizkaia/Vizcaya": "Bizkaia",
    "Castelló/Castellón": "Castellón/Castelló",
    "Gipuzkoa/Guipúzcoa": "Gipuzkoa",
    "Santa Cruz De Tenerife": "Santa Cruz de Tenerife",
    "València/Valencia": "Valencia/València",
}
CANARIAS = {"Las Palmas", "Santa Cruz de Tenerife"}
TOL = 0.02  # grados
VIEW_W = 1000.0

def rdp(pts, eps):
    if len(pts) < 4:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        ax, ay = pts[a]; bx, by = pts[b]
        dx, dy = bx - ax, by - ay
        norm = math.hypot(dx, dy) or 1e-12
        dmax, idx = 0.0, -1
        for i in range(a + 1, b):
            px, py = pts[i]
            d = abs(dy * (px - ax) - dx * (py - ay)) / norm
            if d > dmax:
                dmax, idx = d, i
        if dmax > eps and idx > 0:
            keep[idx] = True
            stack.append((a, idx)); stack.append((idx, b))
    return [p for p, k in zip(pts, keep) if k]

def ring_area(r):
    s = 0.0
    for i in range(len(r)):
        x1, y1 = r[i]; x2, y2 = r[(i + 1) % len(r)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0

def main(src, dst):
    gj = json.load(open(src, encoding="utf-8"))
    provs = []
    for f in gj["features"]:
        name = NAME_FIX.get(f["properties"]["name"], f["properties"]["name"])
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        rings = []
        for poly in polys:
            ring = [(x, y) for x, y in poly[0]]
            if ring[0] == ring[-1]:
                ring = ring[:-1]
            rings.append(ring)
        provs.append({"name": name, "rings": rings})
    # Canarias: se traslada a un recuadro inferior izquierdo
    def proj(lon, lat, can):
        if can:
            lon += 7.0   # Canarias se acerca al suroeste peninsular (recuadro)
            lat += 6.0
        return lon * math.cos(math.radians(40.0)), -lat
    allpts = []
    for p in provs:
        can = p["name"] in CANARIAS
        p["proj"] = [[proj(x, y, can) for x, y in r] for r in p["rings"]]
        for r in p["proj"]:
            allpts.extend(r)
    minx = min(x for x, _ in allpts); maxx = max(x for x, _ in allpts)
    miny = min(y for _, y in allpts); maxy = max(y for _, y in allpts)
    sc = (VIEW_W - 40.0) / (maxx - minx)
    view_h = (maxy - miny) * sc + 40.0
    out = []
    for p in provs:
        rings = []
        for r in p["proj"]:
            # simplificación en espacio proyectado (tolerancia en grados * cos)
            eps = TOL * math.cos(math.radians(40.0))
            far = max(range(len(r)), key=lambda i: math.hypot(r[i][0] - r[0][0], r[i][1] - r[0][1]))
            a = rdp(r[:far + 1], eps)
            b = rdp(r[far:] + [r[0]], eps)
            s = a[:-1] + b[:-1]
            if len(s) < 3:
                continue
            rings.append(s)
        if not rings:
            continue
        rings.sort(key=ring_area, reverse=True)
        total = sum(ring_area(r) for r in rings)
        keep = [r for r in rings if ring_area(r) * sc * sc >= 7.0] or rings[:1]
        rings = keep
        total = sum(ring_area(r) for r in rings)
        scaled = [[[round(20.0 + (x - minx) * sc, 1), round(20.0 + (y - miny) * sc, 1)] for x, y in r] for r in rings]
        big = scaled[0]
        cx = sum(pt[0] for pt in big) / len(big)
        cy = sum(pt[1] for pt in big) / len(big)
        area_px = total * sc * sc
        out.append({
            "name": p["name"], "polygon": big, "polygons": scaled, "center": [round(cx, 1), round(cy, 1)],
            "group": "canarias" if p["name"] in CANARIAS else ("islands" if p["name"] == "Illes Balears" else "peninsula"),
            "tiny": area_px < 260.0,
        })
    # recuadro de Canarias
    can = [pt for p in out if p["group"] == "canarias" for ring in p["polygons"] for pt in ring]
    inset = []
    if can:
        x0 = min(pt[0] for pt in can) - 10; x1 = max(pt[0] for pt in can) + 10
        y0 = min(pt[1] for pt in can) - 10; y1 = max(pt[1] for pt in can) + 10
        inset = [{"rect": [round(x0, 1), round(y0, 1), round(x1 - x0, 1), round(y1 - y0, 1)], "label": "Canarias"}]
    json.dump({"view_size": [round(VIEW_W, 1), round(view_h, 1)], "provinces": out, "insets": inset,
               "source": "click_that_hood spain-provinces.geojson (límites provinciales), simplificado"},
              open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    n = sum(len(r) for p in out for r in p["polygons"])
    print("provincias:", len(out), "puntos:", n, "vista:", VIEW_W, round(view_h, 1))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
