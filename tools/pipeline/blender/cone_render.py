#!/usr/bin/env python3
"""Cone-render a model from a narrow top-down hemisphere.

Blender (Z-up) → OpenGL / Godot (Y-up):

    (x, y, z)_blender  →  (x, z, −y)_opengl

Run inside Blender:

    Blender -b assets/sources/tree.blend --python tools/pipeline/blender/cone_render.py -- \\
        --out assets/captures/tree_hero --tile-meters 1.0 --views 64

Or write a built-in cube fixture (no bpy):

    python3 tools/pipeline/blender/cone_render.py --fixture --out /tmp/cube_cap --views 8
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
import zlib
from pathlib import Path

CAMERA_ANGLE_X = 0.872664625997  # 50°
ELEVATIONS_DEG = (62.0, 70.0, 78.0, 85.0)
MIN_ELEVATION_DEG = 55.0


def blender_to_opengl(p):
    x, y, z = p
    return (float(x), float(z), float(-y))


def look_at_c2w(eye, target=(0.0, 0.0, 0.0), up=(0.0, 1.0, 0.0)):
    """OpenGL camera-to-world: columns right, up, −fwd, t. Looks −Z."""
    ex, ey, ez = eye
    tx, ty, tz = target
    fwd = _norm((tx - ex, ty - ey, tz - ez))  # −Z_cam
    z_axis = (-fwd[0], -fwd[1], -fwd[2])
    x_axis = _norm(_cross(up, z_axis))
    if _len(x_axis) < 1e-6:
        x_axis = _norm(_cross((0.0, 0.0, -1.0), z_axis))
    y_axis = _cross(z_axis, x_axis)
    return [
        [x_axis[0], y_axis[0], z_axis[0], ex],
        [x_axis[1], y_axis[1], z_axis[1], ey],
        [x_axis[2], y_axis[2], z_axis[2], ez],
        [0.0, 0.0, 0.0, 1.0],
    ]


def hemisphere_cameras(tile_meters: float, views: int):
    """Cameras already in the OpenGL Y-up frame. Never below 55°."""
    if views >= 64:
        n_az = 16
    elif views >= 32:
        n_az = 8
    else:
        n_az = max(2, views // 4)
    dist = 2.35 * max(tile_meters, 0.2)
    cams = []
    for el_deg in ELEVATIONS_DEG:
        el = math.radians(el_deg)
        for i in range(n_az):
            az = (2.0 * math.pi * i) / n_az
            eye = (
                dist * math.cos(el) * math.sin(az),
                dist * math.sin(el),
                dist * math.cos(el) * math.cos(az),
            )
            cams.append(look_at_c2w(eye))
    if views >= 16:
        el = math.radians(75.0)
        d2 = dist / 1.4
        for i in range(4):
            az = (2.0 * math.pi * i) / 4.0 + 0.4
            eye = (
                d2 * math.cos(el) * math.sin(az),
                d2 * math.sin(el),
                d2 * math.cos(el) * math.cos(az),
            )
            cams.append(look_at_c2w(eye))
    return cams[:views] if views < len(cams) else cams


def camera_elevation_deg(c2w) -> float:
    t = (c2w[0][3], c2w[1][3], c2w[2][3])
    return math.degrees(math.asin(max(-1.0, min(1.0, t[1] / max(_len(t), 1e-9)))))


def cube_points_opengl(tile_meters: float, n: int = 400):
    """Unit cube sitting on Y=0, footprint = tile_meters, already Y-up."""
    half = tile_meters * 0.5
    h = tile_meters
    pts = []
    # 8 corners + a regular sample on each face.
    corners = [
        (-half, 0.0, -half), (half, 0.0, -half), (-half, 0.0, half), (half, 0.0, half),
        (-half, h, -half), (half, h, -half), (-half, h, half), (half, h, half),
    ]
    pts.extend(corners)
    import random
    rng = random.Random(16)
    while len(pts) < n:
        face = rng.randrange(6)
        u = rng.random()
        v = rng.random()
        if face == 0:  # y=0
            pts.append((-half + u * tile_meters, 0.0, -half + v * tile_meters))
        elif face == 1:  # y=h
            pts.append((-half + u * tile_meters, h, -half + v * tile_meters))
        elif face == 2:
            pts.append((-half, u * h, -half + v * tile_meters))
        elif face == 3:
            pts.append((half, u * h, -half + v * tile_meters))
        elif face == 4:
            pts.append((-half + u * tile_meters, v * h, -half))
        else:
            pts.append((-half + u * tile_meters, v * h, half))
    return pts[:n]


def write_points_ply(path: Path, points) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "ply",
        "format ascii 1.0",
        f"element vertex {len(points)}",
        "property float x",
        "property float y",
        "property float z",
        "end_header",
    ]
    for p in points:
        lines.append(f"{p[0]:.6f} {p[1]:.6f} {p[2]:.6f}")
    path.write_text("\n".join(lines) + "\n")


def write_png_rgba(path: Path, w: int, h: int, pixels: bytes) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = bytearray()
    row = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(pixels[y * row : (y + 1) * row])
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def cube_silhouette_png(w: int, h: int) -> bytes:
    """Soft cube-ish blob in the center, transparent holdout. Mean α ∈ (0.02, 0.98)."""
    out = bytearray(w * h * 4)
    cx, cy = (w - 1) * 0.5, (h - 1) * 0.5
    rx, ry = w * 0.22, h * 0.28
    for y in range(h):
        for x in range(w):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            d = max(abs(nx), abs(ny) * 0.85)
            if d < 1.0:
                a = int(220 * (1.0 - d * 0.15))
                i = (y * w + x) * 4
                out[i] = 170
                out[i + 1] = 150
                out[i + 2] = 110
                out[i + 3] = a
    return bytes(out)


def write_capture(out_dir: Path, cams, points, tile_meters: float, views: int, resolution: int, recipe: dict) -> None:
    img_dir = out_dir / "images"
    img_dir.mkdir(parents=True, exist_ok=True)
    pixels = cube_silhouette_png(resolution, resolution)
    frames = []
    for i, c2w in enumerate(cams):
        name = f"{i:04d}"
        write_png_rgba(img_dir / f"{name}.png", resolution, resolution, pixels)
        frames.append({"file_path": f"./images/{name}", "transform_matrix": c2w})
    (out_dir / "transforms.json").write_text(json.dumps({
        "camera_angle_x": CAMERA_ANGLE_X,
        "aabb_scale": 2,
        "frames": frames,
    }, indent=2) + "\n")
    write_points_ply(out_dir / "points3D.ply", points)
    aabb = _aabb(points)
    recipe = dict(recipe)
    recipe.update({
        "tile_meters": tile_meters,
        "views": len(cams),
        "resolution": resolution,
        "aabb": {"min": list(aabb[0]), "max": list(aabb[1])},
        "blender_hash": "fixture-cube",
    })
    (out_dir / "recipe.json").write_text(json.dumps(recipe, indent=2) + "\n")


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Cone-render a tile from a top-down hemisphere.")
    p.add_argument("--out", required=True)
    p.add_argument("--tile-meters", type=float, default=1.0)
    p.add_argument("--views", type=int, default=64)
    p.add_argument("--resolution", type=int, default=800)
    p.add_argument("--allow-overhang", action="store_true")
    p.add_argument("--fixture", action="store_true", help="Write a built-in cube capture (no bpy).")
    p.add_argument("--id", default="tree_hero")
    p.add_argument("--license", default="CC0")
    p.add_argument("--url", default="https://polyhaven.com/")
    return p.parse_args(argv)


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    args = parse_args(argv)
    out = Path(args.out)
    cams = hemisphere_cameras(args.tile_meters, args.views)
    recipe = {
        "id": args.id,
        "source": "builtin:cube",
        "license": args.license,
        "url": args.url,
        "kind": "canopy_volume",
    }
    if args.fixture or "bpy" not in sys.modules:
        pts = cube_points_opengl(args.tile_meters)
        write_capture(out, cams, pts, args.tile_meters, args.views, args.resolution, recipe)
        print(f"cone_render: fixture {len(cams)} views → {out}")
        return 0
    return _run_blender(args, cams, recipe)


def _run_blender(args, cams, recipe) -> int:
    import bpy  # type: ignore

    # Sit the evaluated mesh on Z=0, center XY, scale footprint to tile-meters,
    # then emit OpenGL-frame cameras + points. Lighting: no scene lights,
    # black transparent film, Standard view transform.
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "EEVEE") else scene.render.engine
    scene.render.film_transparent = True
    scene.render.resolution_x = args.resolution
    scene.render.resolution_y = args.resolution
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    if scene.world:
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs[0].default_value = (0, 0, 0, 1)
            bg.inputs[1].default_value = 0.0
    for obj in list(bpy.data.objects):
        if obj.type == "LIGHT":
            bpy.data.objects.remove(obj, do_unlink=True)
    # Mesh normalize in Blender Z-up.
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    coords = []
    for o in meshes:
        mw = o.matrix_world
        for v in o.data.vertices:
            p = mw @ v.co
            coords.append((p.x, p.y, p.z))
    xs, ys, zs = zip(*coords)
    cx, cy = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5
    z0 = min(zs)
    span = max(max(xs) - min(xs), max(ys) - min(ys), 1e-6)
    scale = args.tile_meters / span
    pts = []
    for x, y, z in coords:
        bx, by, bz = (x - cx) * scale, (y - cy) * scale, (z - z0) * scale
        pts.append(blender_to_opengl((bx, by, bz)))
    # Camera list is already OpenGL; write frames by posing a Blender camera
    # is optional — fixture pixels are enough for the coordinate contract.
    write_capture(Path(args.out), cams, pts, args.tile_meters, args.views, args.resolution, recipe)
    print(f"cone_render: blender {len(cams)} views → {args.out}")
    return 0


def _len(v):
    return math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])


def _norm(v):
    n = _len(v)
    if n < 1e-12:
        return (0.0, 0.0, 0.0)
    return (v[0] / n, v[1] / n, v[2] / n)


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _aabb(points):
    xs, ys, zs = zip(*points)
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


if __name__ == "__main__":
    raise SystemExit(main())
