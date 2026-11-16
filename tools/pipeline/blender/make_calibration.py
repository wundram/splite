"""Create a saved, asymmetric color/coordinate calibration model and capture it."""
import bpy
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cone_render

root = Path(__file__).resolve().parents[3]
source = root / 'assets/sources/calibration.blend'
capture = root / 'assets/captures/calibration'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for name, location, scale, color in [
    ('Terracotta base', (0, 0, .35), (.55, .4, .35), (.65, .10, .035, 1)),
    ('Green tower', (.28, .08, .95), (.18, .22, .25), (.06, .5, .12, 1)),
    ('Blue marker', (-.32, -.2, .82), (.12, .12, .12), (.04, .18, .7, 1)),
]:
    bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = color
    obj.data.materials.append(material)
source.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
cone_render.main(['--source', str(source), '--out', str(capture), '--id', 'calibration',
                  '--views', '32', '--resolution', '256', '--seed-points', '2048',
                  '--license', 'CC0', '--url', 'local:tools/pipeline/blender/make_calibration.py'])
