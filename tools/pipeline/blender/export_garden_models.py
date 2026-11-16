"""Export the chosen source candidates as portable glTF reference models."""
import bpy
from pathlib import Path
root=Path(__file__).resolve().parents[3]
for name in ['garden_tree_sage','garden_shrub_sage','garden_grass_sage','garden_flowers','garden_rock','player_ranger','player_mage']:
    bpy.ops.wm.open_mainfile(filepath=str(root/'assets/sources/garden'/f'{name}.blend'))
    bpy.context.scene.frame_set(1)
    # Preserve normalized capture dimensions and grounding for source/fit comparison.
    import sys
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    import cone_render
    # Save author materials in glTF; fit capture separately substitutes emission.
    bounds=[]
    from mathutils import Vector
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH':bounds.extend(obj.matrix_world @ Vector(v) for v in obj.bound_box)
    lo=Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    import json
    recipe=json.loads((root/'assets/captures'/name/'recipe.json').read_text())
    scale=recipe['normalization']['scale']
    offset=Vector(recipe['normalization']['offset_blender'])
    for obj in bpy.context.scene.objects:
        if obj.parent is None:
            obj.location=(obj.location-offset)*scale
            obj.scale *= scale
    # glTF cannot represent Blender's Hue/Saturation node. Bake base color
    # for edited foliage, retaining the original linked alpha for cutout cards.
    edited=any(n.type=='HUE_SAT' for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes)
    if edited:
        bpy.context.scene.render.engine='CYCLES'
        bpy.context.scene.cycles.samples=1
        bpy.context.scene.cycles.device='CPU'
        restore=[]
        for obj in bpy.context.scene.objects:
            obj.select_set(obj.type=='MESH')
            if obj.type=='MESH':bpy.context.view_layer.objects.active=obj
        for mat in bpy.data.materials:
            if not mat.use_nodes:continue
            nodes=mat.node_tree.nodes;links=mat.node_tree.links
            bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
            output=next((n for n in nodes if n.type=='OUTPUT_MATERIAL'),None)
            if not bsdf or not output:continue
            color=bsdf.inputs['Base Color']
            emission=nodes.new('ShaderNodeEmission')
            if color.is_linked:links.new(color.links[0].from_socket,emission.inputs['Color'])
            else:emission.inputs['Color'].default_value=color.default_value
            links.new(emission.outputs[0],output.inputs['Surface'])
            image=bpy.data.images.new(mat.name+'_baked',width=512,height=512,alpha=True)
            target=nodes.new('ShaderNodeTexImage');target.image=image
            nodes.active=target
            restore.append((mat,bsdf,output,emission,target))
        bpy.ops.object.bake(type='EMIT',margin=2,use_clear=True)
        for mat,bsdf,output,emission,target in restore:
            mat.node_tree.links.new(bsdf.outputs[0],output.inputs['Surface'])
            mat.node_tree.links.new(target.outputs['Color'],bsdf.inputs['Base Color'])
            mat.node_tree.nodes.remove(emission)
            target.image.pack()
    # Source bark/rock maps can be 4K; this small gameplay reference needs 1K.
    for image in bpy.data.images:
        width, height = image.size
        if max(width, height) > 1024:
            factor = 1024 / max(width, height)
            image.scale(max(1, round(width * factor)), max(1, round(height * factor)))
            image.pack()
    bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/garden'/f'{name}.glb'),export_format='GLB',export_animations=False,export_current_frame=True,export_rest_position_armature=False)
