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
import hashlib
import random
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
    if views < 1 or tile_meters <= 0:
        raise ValueError("views and tile-meters must be positive")
    cams = []
    dist = 2.35 * max(tile_meters, 0.2)
    # Interleave elevation rings so small captures still cover the entire cone.
    for i in range(views):
        el = math.radians(ELEVATIONS_DEG[i % len(ELEVATIONS_DEG)])
        az = i * math.pi * (3.0 - math.sqrt(5.0))
        cams.append(look_at_c2w((dist * math.cos(el) * math.sin(az),
                                dist * math.sin(el),
                                dist * math.cos(el) * math.cos(az))))
    return cams


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
    p.add_argument("--source", help="Import a .glb/.gltf or .blend; otherwise use the open Blender scene")
    p.add_argument("--frame", type=int, default=1, help="Evaluated animation frame")
    p.add_argument("--seed-points", type=int, default=4096)
    p.add_argument("--tile-meters", type=float, default=1.0)
    p.add_argument("--views", type=int, default=64)
    p.add_argument("--resolution", type=int, default=800)
    p.add_argument("--material-pass", choices=("albedo", "normals"), default="albedo")
    p.add_argument("--allow-overhang", action="store_true")
    p.add_argument("--fixture", action="store_true", help="Write a built-in cube capture (no bpy).")
    p.add_argument("--id", default="tree_hero")
    p.add_argument("--license", default="unspecified")
    p.add_argument("--url", default="")
    return p.parse_args(argv)


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    args = parse_args(argv)
    if args.resolution < 16 or args.seed_points < 4:
        raise ValueError("resolution must be >=16 and seed-points >=4")
    out = Path(args.out)
    if out.exists() and any(out.iterdir()):
        raise ValueError(f"Capture directory must be empty: {out}")
    cams = hemisphere_cameras(args.tile_meters, args.views)
    recipe = {
        "id": args.id,
        "source": "builtin:cube",
        "license": args.license,
        "url": args.url,
        "kind": "canopy_volume",
    }
    if args.fixture:
        pts = cube_points_opengl(args.tile_meters)
        write_capture(out, cams, pts, args.tile_meters, args.views, args.resolution, recipe)
        print(f"cone_render: fixture {len(cams)} views → {out}")
        return 0
    try:
        import bpy
    except ImportError:
        print("cone_render: real capture requires Blender; use --fixture only for tests", file=sys.stderr)
        return 2
    return _run_blender(args, cams, recipe)


def _run_blender(args, cams, recipe) -> int:
    import bpy
    from mathutils import Matrix, Vector
    import bisect

    if args.source:
        source = Path(args.source).resolve()
        if source.suffix.lower() == ".blend":
            bpy.ops.wm.open_mainfile(filepath=str(source))
        elif source.suffix.lower() in (".glb", ".gltf"):
            bpy.ops.object.select_all(action="SELECT")
            bpy.ops.object.delete(use_global=False)
            bpy.ops.import_scene.gltf(filepath=str(source))
        else:
            raise ValueError("Source must be .blend, .glb, or .gltf")
    else:
        source = Path(bpy.data.filepath) if bpy.data.filepath else None
    scene = bpy.context.scene
    scene.frame_set(args.frame)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    # Bake the evaluated pose and modifiers, including instanced geometry, into
    # world coordinates. Never normalize bones/parents separately from meshes.
    baked = []
    for instance in depsgraph.object_instances:
        obj = instance.object
        if obj.type != "MESH" or obj.hide_render:
            continue
        mesh = bpy.data.meshes.new_from_object(obj, depsgraph=depsgraph)
        mesh.transform(instance.matrix_world)
        baked.append(mesh)
    if not baked:
        raise ValueError("Source contains no renderable meshes")
    coords = [v.co.copy() for mesh in baked for v in mesh.vertices]
    lo = Vector(tuple(min(v[i] for v in coords) for i in range(3)))
    hi = Vector(tuple(max(v[i] for v in coords) for i in range(3)))
    span = max(hi.x - lo.x, hi.y - lo.y)
    if span <= 1e-6:
        raise ValueError("Source has zero footprint")
    scale = args.tile_meters / span
    offset = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for obj in list(scene.objects):
        obj.hide_render = True
    materials = set()
    points = []
    triangles, cumulative = [], []
    area = 0.0
    for mesh in baked:
        for v in mesh.vertices:
            v.co = (v.co - offset) * scale
            points.append(blender_to_opengl(v.co))
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            a, b, c = [mesh.vertices[i].co.copy() for i in tri.vertices]
            weight = (b - a).cross(c - a).length / 2
            if weight > 0:
                area += weight
                triangles.append((a, b, c))
                cumulative.append(area)
        obj = bpy.data.objects.new("capture_mesh", mesh)
        scene.collection.objects.link(obj)
        if not mesh.materials:
            mat = bpy.data.materials.new("capture_default")
            mat.diffuse_color = (0.5, 0.5, 0.5, 1)
            mesh.materials.append(mat)
        materials.update(m for m in mesh.materials if m)
    if not triangles:
        raise ValueError("Source contains no nondegenerate triangles")
    # Preserve texture and vertex-color networks feeding Principled base color;
    # emission removes baked illumination. Unsupported graphs fail explicitly.
    for mat in materials:
        color = tuple(mat.diffuse_color)
        was_nodes = mat.use_nodes
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
        shader = output.inputs["Surface"].links[0].from_node if output and output.inputs["Surface"].is_linked else None
        if was_nodes and (shader is None or shader.type != "BSDF_PRINCIPLED"):
            raise ValueError(f"Material {mat.name}: use a Principled BSDF connected directly to Material Output")
        if output is None:
            output = nodes.new("ShaderNodeOutputMaterial")
        emission = nodes.new("ShaderNodeEmission")
        base = shader.inputs["Base Color"] if was_nodes and shader else None
        emission.inputs["Color"].default_value = base.default_value if base else color
        if base and base.is_linked:
            links.new(base.links[0].from_socket, emission.inputs["Color"])
        if args.material_pass == "normals":
            geometry = nodes.new("ShaderNodeNewGeometry")
            split = nodes.new("ShaderNodeSeparateXYZ")
            combine = nodes.new("ShaderNodeCombineXYZ")
            negate = nodes.new("ShaderNodeMath"); negate.operation = 'MULTIPLY'
            negate.inputs[1].default_value = -1
            links.new(geometry.outputs['Normal'], split.inputs[0])
            links.new(split.outputs['X'], combine.inputs['X'])
            links.new(split.outputs['Z'], combine.inputs['Y'])
            links.new(split.outputs['Y'], negate.inputs[0])
            links.new(negate.outputs[0], combine.inputs['Z'])
            multiply = nodes.new('ShaderNodeVectorMath'); multiply.operation = 'MULTIPLY'
            multiply.inputs[1].default_value = (.5, .5, .5)
            add = nodes.new('ShaderNodeVectorMath'); add.operation = 'ADD'
            add.inputs[1].default_value = (.5, .5, .5)
            links.new(combine.outputs[0], multiply.inputs[0])
            links.new(multiply.outputs[0], add.inputs[0])
            links.new(add.outputs[0], emission.inputs['Color'])
        transparent = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        alpha = shader.inputs["Alpha"] if was_nodes and shader else None
        mix.inputs[0].default_value = alpha.default_value if alpha else color[3]
        if alpha and alpha.is_linked:
            links.new(alpha.links[0].from_socket, mix.inputs[0])
        links.new(transparent.outputs[0], mix.inputs[1])
        links.new(emission.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], output.inputs["Surface"])
    rng = random.Random(16)
    seeds = []
    for _ in range(args.seed_points):
        a, b, c = triangles[bisect.bisect_left(cumulative, rng.random() * area)]
        u, v = math.sqrt(rng.random()), rng.random()
        seeds.append(blender_to_opengl((1-u)*a + u*(1-v)*b + u*v*c))
    bounds = _aabb(points)
    target = tuple((bounds[0][i] + bounds[1][i]) / 2 for i in range(3))
    radius = max(_len(tuple(p[i] - target[i] for i in range(3))) for p in points)
    distance = radius / math.sin(CAMERA_ANGLE_X / 2) * 1.15
    fitted_cams = []
    for cam in cams:
        direction = _norm(tuple(cam[i][3] for i in range(3)))
        fitted_cams.append(look_at_c2w(tuple(target[i] + direction[i] * distance for i in range(3)), target))
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = args.resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.use_compositing = False
    scene.render.use_sequencer = False
    scene.view_settings.view_transform = "Raw" if args.material_pass == "normals" else "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    camera = bpy.data.objects.new("capture_camera", bpy.data.cameras.new("capture_camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "PERSP"
    camera.data.sensor_fit = "HORIZONTAL"
    camera.data.angle = CAMERA_ANGLE_X
    camera.data.clip_start = max(0.001, distance / 1000)
    camera.data.clip_end = distance * 10
    gl_to_blender = Matrix(((1,0,0,0), (0,0,-1,0), (0,1,0,0), (0,0,0,1)))
    out = Path(args.out).resolve()
    (out / "images").mkdir(parents=True, exist_ok=True)
    frames = []
    for i, c2w in enumerate(fitted_cams):
        camera.matrix_world = gl_to_blender @ Matrix(c2w)
        scene.render.filepath = str(out / "images" / f"{i:04d}.png")
        bpy.ops.render.render(write_still=True)
        frames.append({"file_path": f"./images/{i:04d}", "transform_matrix": c2w})
    (out / "transforms.json").write_text(json.dumps({"camera_angle_x": CAMERA_ANGLE_X, "frames": frames}, indent=2) + "\n")
    write_points_ply(out / "points3D.ply", seeds)
    recipe.update({"source": str(source) if source else "unsaved:blender-scene",
                   "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest() if source and source.is_file() else None,
                   "blender_hash": bpy.app.build_hash.decode(), "frame": args.frame,
                   "fixture": False, "color_mode": "world-normal-encoded-raw" if args.material_pass == "normals" else "unlit-base-color-srgb",
                   "tile_meters": args.tile_meters, "views": len(frames), "resolution": args.resolution,
                   "normalization": {"offset_blender": list(offset), "scale": scale},
                   "aabb": {"min": bounds[0], "max": bounds[1]}})
    (out / "recipe.json").write_text(json.dumps(recipe, indent=2) + "\n")
    print(f"cone_render: rendered {len(frames)} views → {out}")
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
