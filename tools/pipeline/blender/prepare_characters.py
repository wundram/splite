"""Pose CC0 KayKit candidates in a shared idle animation for source audition."""
import bpy
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import cone_render
root=Path(__file__).resolve().parents[3]
pack=root/'assets/sources/kaykit-adventurers/KayKit_Adventurers_2.0_FREE'
for name in ['Ranger','Mage','Rogue_Hooded']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(pack/'Characters/gltf'/f'{name}.glb'))
    original=set(bpy.data.objects)
    rig=next(o for o in original if o.type=='ARMATURE')
    bpy.ops.import_scene.gltf(filepath=str(pack/'Animations/gltf/Rig_Medium/Rig_Medium_General.glb'))
    actions=[a for a in bpy.data.actions if a.name.startswith('Idle_A')]
    assert len(actions)==1, [a.name for a in bpy.data.actions]
    rig.animation_data_create()
    rig.animation_data.action=actions[0]
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    for obj in set(bpy.data.objects)-original:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.context.scene.frame_set(1)
    bpy.ops.file.pack_all()
    asset='player_'+name.lower()
    source=root/'assets/sources/garden'/f'{asset}.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    cone_render.main(['--source',str(source),'--out',str(root/'assets/captures'/asset),
                      '--id',asset,'--views','16','--resolution','256','--frame','1',
                      '--tile-meters','.7','--license','CC0-1.0',
                      '--url','https://kaylousberg.itch.io/kaykit-adventurers'])
