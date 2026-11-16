"""Export additional CC0 Quaternius source trees; these are mesh assets, not fits."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector
root=Path(__file__).resolve().parents[3]
pack=root/'assets/sources/quaternius-nature'
# Exact object names are validated before deleting anything from the loaded scene.
choices={'MapleTree_4':('garden_maple',3.0), 'PineTree_3':('garden_pine',2.6), 'BirchTree_3':('garden_birch',2.2), 'DeadTree_4':('garden_deadwood',2.1)}
for name,(asset,width) in choices.items():
    bpy.ops.wm.open_mainfile(filepath=str(pack/'AllModels.blend'))
    keep=bpy.data.objects[name]
    for o in list(bpy.data.objects):
        if o!=keep:bpy.data.objects.remove(o,do_unlink=True)
    keep.location=(0,0,0);keep.hide_render=False;keep.hide_set(False)
    for mat in keep.data.materials:
        if not mat or not mat.use_nodes:continue
        for n in mat.node_tree.nodes:
            if n.type=='TEX_IMAGE' and n.image and not n.image.packed_file:
                stem=Path(n.image.filepath.replace('\\','/')).stem
                n.image.filepath=str(pack/'Textures/Textures'/f'{stem}.png');n.image.reload();n.image.pack()
    bpy.context.view_layer.update()
    points=[keep.matrix_world@Vector(v) for v in keep.bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
    factor=width/max(hi.x-lo.x,hi.y-lo.y)
    keep.location=-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))*factor;keep.scale*=factor
    for im in bpy.data.images:
        if max(im.size)>1024:
            f=1024/max(im.size);im.scale(int(im.size[0]*f),int(im.size[1]*f));im.pack()
    out=root/'assets/models/garden'/f'{asset}.glb'
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_animations=False)
    (out.with_suffix('.json')).write_text(json.dumps({'license':'CC0-1.0','url':'https://quaternius.com/packs/ultimatestylizednature.html','source_object':name,'source_sha256':hashlib.sha256((pack/'AllModels.blend').read_bytes()).hexdigest(),'width_m':width},indent=2)+'\n')
