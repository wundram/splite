"""Transfer evaluated source-surface normals to a fitted Godot cloud."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'import'))
from ply_to_cloud import read_ply_vertices, convert, write_tres


def main():
    parser = argparse.ArgumentParser()
    for name in ('source', 'recipe', 'ply', 'out'):
        parser.add_argument('--'+name, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    recipe = json.loads(Path(args.recipe).read_text())
    source = Path(args.source)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == recipe['source_sha256'], 'Source changed since capture'
    bpy.ops.wm.open_mainfile(filepath=str(source.resolve()))
    bpy.context.scene.frame_set(recipe.get('frame', 1))
    offset = Vector(recipe['normalization']['offset_blender'])
    scale = recipe['normalization']['scale']
    depsgraph = bpy.context.evaluated_depsgraph_get()
    vertices, triangles, normals = [], [], []
    def godot(v):
        return Vector((v.x, v.z, -v.y))
    for instance in depsgraph.object_instances:
        if instance.object.type != 'MESH' or instance.object.hide_render:
            continue
        mesh = bpy.data.meshes.new_from_object(instance.object, depsgraph=depsgraph)
        mesh.transform(instance.matrix_world)
        mesh.calc_loop_triangles()
        start = len(vertices)
        vertices.extend(godot((v.co-offset)*scale) for v in mesh.vertices)
        for tri in mesh.loop_triangles:
            triangles.append(tuple(start+i for i in tri.vertices))
            normals.append(tuple(godot(mesh.vertices[i].normal).normalized() for i in tri.vertices)
                           if tri.use_smooth else (godot(tri.normal).normalized(),)*3)
        bpy.data.meshes.remove(mesh)
    tree = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
    names, rows = read_ply_vertices(Path(args.ply))
    gaussians = convert(names, rows, 0, 'volume', reference=True)
    transferred, distances = [], []
    for gaussian in gaussians:
        hit, face_normal, index, distance = tree.find_nearest(Vector(gaussian['p']))
        assert hit is not None
        tri = triangles[index]
        normal = barycentric_transform(hit, *(vertices[i] for i in tri), *normals[index])
        if normal.length_squared < 1e-12:
            normal = face_normal
        transferred.append(tuple(normal.normalized()))
        distances.append(distance)
    write_tres(Path(args.out), gaussians, recipe.get('id', source.stem), transferred)
    print(f'bake_surface_normals: {len(gaussians)} normals; nearest distance mean={sum(distances)/len(distances):.5f}m max={max(distances):.5f}m')


if __name__ == '__main__':
    main()
