#!/usr/bin/env python3
"""PLY (Inria / splatfacto / gsplat) → SplatCloud .tres

    python3 tools/pipeline/import/ply_to_cloud.py \
        --ply assets/clouds/tree_hero.ply \
        --out assets/clouds/tree_hero.tres \
        --budget 600 --kind volume
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from pathlib import Path

SH_C0 = 0.28209479177387814


def read_ply_vertices(path: Path) -> tuple[list[str], list[tuple]]:
    data = path.read_bytes()
    header, _, body = data.partition(b"end_header")
    if not _:
        raise ValueError("PLY missing end_header")
    header_txt = header.decode("ascii", errors="replace").splitlines()
    fmt = "ascii"
    names: list[str] = []
    n = 0
    types = []
    element = None
    for line in header_txt:
        bits = line.split()
        if not bits:
            continue
        if bits[0] == "format":
            fmt = bits[1]
        elif bits[0] == "element":
            element = bits[1]
            if element == "vertex":
                n = int(bits[2])
        elif bits[0] == "property" and element == "vertex":
            if bits[1] == "list":
                raise ValueError("List vertex properties are unsupported")
            names.append(bits[-1])
            types.append(bits[1])
    if fmt.startswith("binary"):
        endian = "<" if "little" in fmt else ">"
        formats = {"float": "f", "float32": "f", "double": "d", "float64": "d", "uchar": "B", "uint8": "B", "char": "b", "int8": "b", "short": "h", "ushort": "H", "int": "i", "uint": "I"}
        rec = struct.Struct(endian + "".join(formats[t] for t in types))
        body = body[2:] if body.startswith(b"\r\n") else body[1:] if body.startswith(b"\n") else body
        rows = [rec.unpack_from(body, i * rec.size) for i in range(n)]
        return names, rows
    text = body.decode("ascii", errors="replace").splitlines()
    rows = []
    for line in text:
        if not line.strip():
            continue
        vals = [float(x) for x in line.split()[: len(names)]]
        if len(vals) < len(names):
            continue
        rows.append(tuple(vals))
        if len(rows) == n:
            break
    if len(rows) != n:
        raise ValueError("Truncated PLY vertices")
    return names, rows


def farthest_point(positions: list[tuple], budget: int) -> list[int]:
    if len(positions) <= budget:
        return list(range(len(positions)))
    chosen = [0]
    selected = {0}
    d2 = [_dist2(positions[0], p) for p in positions]
    while len(chosen) < budget:
        nxt = max((i for i in range(len(positions)) if i not in selected), key=lambda i: d2[i])
        chosen.append(nxt)
        selected.add(nxt)
        pn = positions[nxt]
        for i, p in enumerate(positions):
            di = _dist2(pn, p)
            if di < d2[i]:
                d2[i] = di
    return chosen


def _dist2(a, b):
    dx, dy, dz = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return dx * dx + dy * dy + dz * dz


def convert(names, rows, budget: int, kind: str, aabb=None, reference: bool = False):
    idx = {n: i for i, n in enumerate(names)}

    def get(row, key, default=0.0):
        i = idx.get(key)
        return float(row[i]) if i is not None else default

    required = {"x", "y", "z", "opacity", "scale_0", "scale_1", "scale_2", "f_dc_0", "f_dc_1", "f_dc_2", "rot_0", "rot_1", "rot_2", "rot_3"}
    if not required.issubset(idx):
        raise ValueError(f"Missing Gaussian properties: {sorted(required - idx.keys())}")
    rmax = 2.5 if kind == "volume" else 0.85
    gaussians = []
    for row in rows:
        if not all(math.isfinite(float(v)) for v in row):
            continue
        x, y, z = get(row, "x"), get(row, "y"), get(row, "z")
        logit = get(row, "opacity", 0.0)
        alpha = 1.0 / (1.0 + math.exp(-max(-80, min(80, logit))))
        if any(abs(get(row, f"scale_{i}")) > 80 for i in range(3)):
            continue
        sx = math.exp(get(row, "scale_0", -2.0))
        sy = math.exp(get(row, "scale_1", -2.0))
        sz = math.exp(get(row, "scale_2", -2.0))
        radius = (sx * sy * sz) ** (1.0 / 3.0)
        if not reference and (alpha < 0.04 or radius < 0.005 or radius > rmax):
            continue
        albedo = (
            max(0.0, min(1.0, SH_C0 * get(row, "f_dc_0") + 0.5)),
            max(0.0, min(1.0, SH_C0 * get(row, "f_dc_1") + 0.5)),
            max(0.0, min(1.0, SH_C0 * get(row, "f_dc_2") + 0.5)),
        )
        rot = (
            get(row, "rot_1"),
            get(row, "rot_2"),
            get(row, "rot_3"),
            get(row, "rot_0"),
        )
        norm = math.sqrt(sum(v*v for v in rot))
        if norm < 1e-12:
            continue
        rot = tuple(v / norm for v in rot)
        gaussians.append({
            "p": (x, y, z),
            "r": radius,
            "c": albedo,
            "a": alpha,
            "s": (sx, sy, sz),
            "q": rot,
        })

    if aabb is not None and not reference:
        (mn, mx) = aabb
        pad = [(mx[i] - mn[i]) * 0.05 for i in range(3)]
        lo = [mn[i] - pad[i] for i in range(3)]
        hi = [mx[i] + pad[i] for i in range(3)]
        gaussians = [
            g for g in gaussians
            if all(lo[i] <= g["p"][i] <= hi[i] for i in range(3))
        ]

    if not reference and budget > 0 and len(gaussians) > budget:
        keep = farthest_point([g["p"] for g in gaussians], budget)
        gaussians = [gaussians[i] for i in keep]
    return gaussians


def fill_shadow_and_aabb(gaussians):
    if not gaussians:
        return (0, 0, 0), (0, 0, 0), []
    lo = [min(g["p"][i] - g["r"] for g in gaussians) for i in range(3)]
    hi = [max(g["p"][i] + g["r"] for g in gaussians) for i in range(3)]
    c = ((lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, (lo[2] + hi[2]) * 0.5)
    sv = []
    for g in gaussians:
        d = (g["p"][0] - c[0], g["p"][1] - c[1] + 0.35, g["p"][2] - c[2])
        n = math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2])
        sv.append((0.0, 1.0, 0.0) if n < 1e-8 else (d[0] / n, d[1] / n, d[2] / n))
    return tuple(lo), tuple(hi), sv


def write_tres(path: Path, gaussians, source_id: str, shadow_vecs=None) -> None:
    lo, hi, sv = fill_shadow_and_aabb(gaussians)
    if shadow_vecs is not None:
        if len(shadow_vecs) != len(gaussians):
            raise ValueError("Surface normal count must match Gaussian count")
        sv = []
        for normal in shadow_vecs:
            if len(normal) != 3 or not all(math.isfinite(float(v)) for v in normal):
                raise ValueError("Surface normals must contain three finite components")
            length = math.sqrt(sum(float(v)**2 for v in normal))
            if length < 1e-12:
                raise ValueError("Surface normals must be nonzero")
            sv.append(tuple(float(v)/length for v in normal))
    def f3(arr, key=None):
        if key:
            vals = []
            for g in gaussians:
                vals.extend(g[key])
            return ", ".join(f"{v:.6g}" for v in vals)
        return ", ".join(f"{v:.6g}" for v in arr)

    pos = []
    rad = []
    col = []
    opa = []
    sca = []
    rot = []
    for g in gaussians:
        pos.extend(g["p"])
        rad.append(g["r"])
        col.extend([g["c"][0], g["c"][1], g["c"][2], 1.0])
        opa.append(g["a"])
        sca.extend(g["s"])
        rot.extend(g["q"])
    sh = ", ".join(f"{v:.6g}" for v in sum((list(s) for s in sv), []))
    size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    text = f"""[gd_resource type="Resource" script_class="SplatCloud" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/splite/core/splat_cloud.gd" id="1"]

[resource]
script = ExtResource("1")
positions = PackedVector3Array({", ".join(f"{v:.6g}" for v in pos)})
radii = PackedFloat32Array({", ".join(f"{v:.6g}" for v in rad)})
colors = PackedColorArray({", ".join(f"{v:.6g}" for v in col)})
opacities = PackedFloat32Array({", ".join(f"{v:.6g}" for v in opa)})
shadow_vecs = PackedVector3Array({sh})
aabb = AABB({lo[0]:.6g}, {lo[1]:.6g}, {lo[2]:.6g}, {size[0]:.6g}, {size[1]:.6g}, {size[2]:.6g})
scales = PackedVector3Array({", ".join(f"{v:.6g}" for v in sca)})
rotations = PackedVector4Array({", ".join(f"{v:.6g}" for v in rot)})
source_id = "{source_id}"
"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def write_ply(path: Path, gaussians) -> None:
    """Hand-export fixture in splatfacto vertex layout (ascii)."""
    lines = [
        "ply",
        "format ascii 1.0",
        f"element vertex {len(gaussians)}",
        "property float x",
        "property float y",
        "property float z",
        "property float f_dc_0",
        "property float f_dc_1",
        "property float f_dc_2",
        "property float opacity",
        "property float scale_0",
        "property float scale_1",
        "property float scale_2",
        "property float rot_0",
        "property float rot_1",
        "property float rot_2",
        "property float rot_3",
        "end_header",
    ]
    for g in gaussians:
        fd = [(c - 0.5) / SH_C0 for c in g["c"]]
        logit = math.log(g["a"] / max(1.0 - g["a"], 1e-6))
        ls = [math.log(max(s, 1e-6)) for s in g["s"]]
        q = (g["q"][3], *g["q"][:3])
        p = g["p"]
        lines.append(
            f"{p[0]:.6f} {p[1]:.6f} {p[2]:.6f} "
            f"{fd[0]:.6f} {fd[1]:.6f} {fd[2]:.6f} {logit:.6f} "
            f"{ls[0]:.6f} {ls[1]:.6f} {ls[2]:.6f} "
            f"{q[0]:.6f} {q[1]:.6f} {q[2]:.6f} {q[3]:.6f}"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def make_canopy(n: int = 80):
    """Procedural canopy-shaped cloud used as the checked-in stand-in ply."""
    import random
    rng = random.Random(18)
    gs = []
    for i in range(n):
        a = (i / n) * math.tau + rng.uniform(-0.1, 0.1)
        rad = rng.uniform(0.35, 1.15)
        y = rng.uniform(1.15, 2.15)
        p = (math.cos(a) * rad, y, math.sin(a) * rad)
        r = rng.uniform(0.18, 0.42)
        g = rng.uniform(0.28, 0.52)
        gs.append({
            "p": p,
            "r": r,
            "c": (g * 0.45, g, g * 0.38),
            "a": rng.uniform(0.55, 0.88),
            "s": (r, r * 0.85, r),
            "q": (0.0, 0.0, 0.0, 1.0),
        })
    return gs


def parse_args(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--ply")
    p.add_argument("--out", required=True)
    p.add_argument("--budget", type=int, default=600)
    p.add_argument("--reference", action="store_true",
                   help="Preserve all finite valid Gaussians; bypass pruning and budget for renderer comparison")
    p.add_argument("--kind", choices=("tile", "volume"), default="volume")
    p.add_argument("--recipe", help="optional recipe.json with aabb")
    p.add_argument("--normals", help="Optional per-Gaussian normals JSON; requires --reference to preserve ordering")
    p.add_argument("--id", default="")
    p.add_argument("--write-fixture-ply", action="store_true",
                    help="Write a hand-exported canopy PLY, then import it.")
    p.add_argument("--license-line", default="Source license: see capture recipe / assets attribution")
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    aabb = None
    if args.recipe:
        rec = json.loads(Path(args.recipe).read_text())
        if "aabb" in rec:
            aabb = (tuple(rec["aabb"]["min"]), tuple(rec["aabb"]["max"]))
    if args.write_fixture_ply:
        ply = Path(args.ply) if args.ply else Path(args.out).with_suffix(".ply")
        write_ply(ply, make_canopy(80))
        args.ply = str(ply)
    if not args.ply:
        print("ply_to_cloud: --ply is required (or --write-fixture-ply)", file=sys.stderr)
        return 2
    names, rows = read_ply_vertices(Path(args.ply))
    gs = convert(names, rows, args.budget, args.kind, aabb, reference=args.reference)
    if not gs:
        raise ValueError("No valid Gaussians remain; refusing to write an empty cloud")
    sid = args.id or Path(args.ply).stem
    if args.normals and not args.reference:
        raise ValueError('--normals requires --reference so Gaussian ordering is preserved')
    normals = json.loads(Path(args.normals).read_text()) if args.normals else None
    write_tres(Path(args.out), gs, sid, normals)
    lo, hi, _sv = fill_shadow_and_aabb(gs)
    mean_r = sum(g["r"] for g in gs) / max(len(gs), 1)
    mean_a = sum(g["a"] for g in gs) / max(len(gs), 1)
    print(
        f"ply_to_cloud: n={len(gs)} aabb=({lo[0]:.2f},{lo[1]:.2f},{lo[2]:.2f})-"
        f"({hi[0]:.2f},{hi[1]:.2f},{hi[2]:.2f}) mean_r={mean_r:.3f} "
        f"mean_a={mean_a:.3f}  {args.license_line}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
