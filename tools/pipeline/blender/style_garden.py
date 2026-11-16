"""Create palette-adjusted foliage variants from the preserved CC0 source assets."""
import bpy
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import cone_render
root=Path(__file__).resolve().parents[3]
for name,footprint in [('garden_tree',2.5),('garden_shrub',1.2),('garden_grass',.7)]:
    bpy.ops.wm.open_mainfile(filepath=str(root/'assets/sources/garden'/f'{name}.blend'))
    for mat in bpy.data.materials:
        if not mat.use_nodes or not any(s in mat.name.lower() for s in ('leaves','grass')):continue
        nodes=mat.node_tree.nodes;links=mat.node_tree.links
        principled=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
        color=principled.inputs['Base Color']
        if not color.is_linked:continue
        source=color.links[0].from_socket
        desaturate=nodes.new('ShaderNodeHueSaturation')
        desaturate.inputs['Saturation'].default_value=.25
        desaturate.inputs['Value'].default_value=.55
        links.new(source,desaturate.inputs['Color'])
        links.new(desaturate.outputs['Color'],color)
    asset=name+'_sage'
    source=root/'assets/sources/garden'/f'{asset}.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    cone_render.main(['--source',str(source),'--out',str(root/'assets/captures'/asset),
                      '--id',asset,'--views','32','--resolution','384',
                      '--tile-meters',str(footprint),'--license','CC0-1.0',
                      '--url','https://quaternius.com/packs/ultimatestylizednature.html'])
