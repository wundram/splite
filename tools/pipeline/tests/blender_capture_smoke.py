"""Run with Blender -b --python tools/pipeline/tests/blender_capture_smoke.py.
Verifies actual view-dependent silhouettes and two preserved material colors.
"""
import bpy
import json
from pathlib import Path
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'blender'))
import cone_render

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for location, scale, color, nodes in [((0,0,.5),(.5,.3,.5),(.7,.1,.02,1),False), ((.3,.1,1.2),(.2,.15,.3),(.03,.5,.1,1),True)]:
    bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    obj = bpy.context.object
    obj.scale = scale
    mat = bpy.data.materials.new('test_color')
    mat.diffuse_color = color
    mat.use_nodes = nodes
    if nodes:
        mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = color
    obj.data.materials.append(mat)
with tempfile.TemporaryDirectory() as tmp:
    out = Path(tmp) / 'capture'
    cone_render.main(['--out',str(out),'--views','4','--resolution','96'])
    images = sorted((out / 'images').glob('*.png'))
    assert len({p.read_bytes() for p in images}) == 4, 'Identical fixture views'
    for path in images:
        image = bpy.data.images.load(str(path))
        rgba = list(image.pixels)
        opaque = [rgba[i:i+4] for i in range(0,len(rgba),4) if rgba[i+3] > .99]
        assert any(p[0] > p[1]*1.5 for p in opaque), 'Red base color lost'
        assert any(p[1] > p[0]*1.5 for p in opaque), 'Green base color lost'
        assert any(rgba[i] == 0 for i in range(3,len(rgba),4)), 'No transparent background'
        # Validate source points against each camera's image frustum.
    frames = json.loads((out / 'transforms.json').read_text())['frames']
    from mathutils import Matrix, Vector
    import math
    points = [tuple(map(float,line.split())) for line in (out / 'points3D.ply').read_text().split('end_header\n')[1].splitlines()]
    for frame in frames:
        view = Matrix(frame['transform_matrix']).inverted()
        for p in points:
            camera = view @ Vector((*p,1))
            assert camera.z < 0
            assert abs(camera.x / camera.z) < math.tan(cone_render.CAMERA_ANGLE_X/2)
            assert abs(camera.y / camera.z) < math.tan(cone_render.CAMERA_ANGLE_X/2)
print('blender_capture_smoke: PASS')
