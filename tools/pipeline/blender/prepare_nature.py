"""Extract a small CC0 Quaternius nature audition with packed source textures."""
import bpy
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import cone_render

root=Path(__file__).resolve().parents[3]
pack=root/'assets/sources/quaternius-nature'
textures=pack/'Textures/Textures'
choices={'NormalTree_5':('garden_tree',2.5), 'MapleTree_4':('garden_maple',2.5),
         'Bush_Small_Flowers':('garden_shrub',1.2),'Flower_4_Clump':('garden_flowers',.6),
         'Grass_Large_Extruded':('garden_grass',.7),'Rock_1':('garden_rock',.7)}
for object_name,(asset_id,footprint) in choices.items():
    bpy.ops.wm.open_mainfile(filepath=str(pack/'AllModels.blend'))
    keep=bpy.data.objects[object_name]
    for obj in list(bpy.data.objects):
        if obj != keep:bpy.data.objects.remove(obj,do_unlink=True)
    keep.location=(0,0,0)
    keep.hide_render=False
    keep.hide_set(False)
    # Original blend mixes packed images and missing glTF-side JPEG paths.
    for material in keep.data.materials:
        if not material or not material.use_nodes:continue
        for node in material.node_tree.nodes:
            if node.type!='TEX_IMAGE' or not node.image:continue
            image=node.image
            if image.packed_file:continue
            stem=Path(image.filepath.replace('\\','/')).stem
            candidate=textures/(stem+'.png')
            if not candidate.exists():raise FileNotFoundError(candidate)
            image.filepath=str(candidate)
            image.reload()
            image.pack()
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    source=root/'assets/sources/garden'/f'{asset_id}.blend'
    source.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    cone_render.main(['--source',str(source),'--out',str(root/'assets/captures'/asset_id),
                      '--id',asset_id,'--views','16','--resolution','256',
                      '--tile-meters',str(footprint),'--license','CC0-1.0',
                      '--url','https://quaternius.com/packs/ultimatestylizednature.html'])
