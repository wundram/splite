"""Bake a source-rig animation onto a trained cloud with persistent point identity.

Blender --background --python this.py -- --out assets/clouds/garden/ranger_walk
This is skeletal deformation of a fitted idle cloud, not independent pose fits.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Matrix, Vector, Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'import'))
from ply_to_cloud import read_ply_vertices, convert, write_tres


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',required=True)
    parser.add_argument('--frames',type=int,default=10)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    assert args.frames >= 2, 'A loop requires at least two frames'
    root=Path(__file__).resolve().parents[3]
    source=root/'assets/sources/garden/player_ranger.blend'
    recipe=json.loads((root/'assets/captures/player_ranger_32/recipe.json').read_text())
    assert hashlib.sha256(source.read_bytes()).hexdigest()==recipe['source_sha256']
    fitted=root/'assets/training/ranger-normals-refined'
    names,rows=read_ply_vertices(fitted/'refined.ply')
    gs=convert(names,rows,0,'volume',reference=True)
    normal=np.asarray(json.loads((fitted/'normals.json').read_text()),dtype=float)
    out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=False)
    proxy_dir=root/'assets/models/garden/ranger_walk';proxy_dir.mkdir(exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    bpy.context.scene.frame_set(recipe['frame'])
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    bones=list(rig.pose.bones);bone_ids={b.name:i for i,b in enumerate(bones)}
    idle=[(rig.matrix_world@b.matrix).copy() for b in bones]
    scale=recipe['normalization']['scale'];offset=np.asarray(recipe['normalization']['offset_blender'])
    axis=np.array([[1,0,0],[0,0,1],[0,-1,0]],dtype=float)
    normalize=np.eye(4);normalize[:3,:3]=axis*scale;normalize[:3,3]=-axis@offset*scale
    inverse=np.linalg.inv(normalize)
    verts=[];triangles=[];weights=[]
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in list(bpy.context.scene.objects):
        if obj.type!='MESH' or obj.hide_render:continue
        assert all(m.type=='ARMATURE' for m in obj.modifiers),'Topology-changing modifiers need explicit vertex correspondence'
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph),depsgraph=depsgraph)
        assert len(mesh.vertices)==len(obj.data.vertices)
        mesh.transform(obj.matrix_world);mesh.calc_loop_triangles()
        start=len(verts)
        for vertex,original in zip(mesh.vertices,obj.data.vertices):
            verts.append(Vector((normalize@np.array([*vertex.co,1]))[:3]))
            row=np.zeros(len(bones)+1)
            for group in original.groups:
                name=obj.vertex_groups[group.group].name
                if name in bone_ids:row[bone_ids[name]]+=group.weight
            if row.sum()<1e-8:row[-1]=1
            weights.append(row/row.sum())
        triangles.extend(tuple(start+i for i in t.vertices) for t in mesh.loop_triangles)
        bpy.data.meshes.remove(mesh)
    tree=BVHTree.FromPolygons(verts,triangles,all_triangles=True)
    transferred=[];distances=[]
    for g in gs:
        hit,_,index,distance=tree.find_nearest(Vector(g['p']))
        ids=triangles[index]
        bary=barycentric_transform(hit,*(verts[i] for i in ids),Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
        bary=np.maximum(np.array(bary),0);bary/=bary.sum()
        transferred.append(sum(bary[j]*weights[i] for j,i in enumerate(ids)))
        distances.append(distance)
    skin=np.asarray(transferred)
    original_objects=set(bpy.data.objects)
    animation=root/'assets/sources/kaykit-adventurers/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb'
    bpy.ops.import_scene.gltf(filepath=str(animation))
    actions=[a for a in bpy.data.actions if a.name.startswith('Walking_A_')]
    assert len(actions)==1
    action=actions[0]
    for obj in set(bpy.data.objects)-original_objects:bpy.data.objects.remove(obj,do_unlink=True)
    rig.animation_data.action=action
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    start,end=map(float,action.frame_range)
    positions=np.array([g['p'] for g in gs]);homogeneous=np.column_stack([positions,np.ones(len(gs))])
    rotations=np.array([Quaternion((g['q'][3],*g['q'][:3])).to_matrix() for g in gs])
    scales=np.array([g['s'] for g in gs])
    axes=rotations*scales[:,None,:]
    covariance=axes@axes.transpose(0,2,1)
    frames=[];bounds=[]
    for index in range(args.frames):
        sample=start+(end-start)*index/args.frames
        frame=int(sample);bpy.context.scene.frame_set(frame,subframe=sample-frame)
        transforms=np.array([normalize@np.array(rig.matrix_world@b.matrix@bind.inverted())@inverse for b,bind in zip(bones,idle)]+[np.eye(4)])
        blended=np.einsum('nb,bij->nij',skin,transforms)
        posed=np.einsum('nij,nj->ni',blended,homogeneous)[:,:3]
        linear=blended[:,:3,:3]
        cov=linear@covariance@linear.transpose(0,2,1)
        eigenvalues,eigenvectors=np.linalg.eigh(cov)
        assert np.isfinite(posed).all() and np.all(eigenvalues>0)
        eigenvectors[:,:,0]*=np.where(np.linalg.det(eigenvectors)<0,-1,1)[:,None]
        ns=np.einsum('nij,nj->ni',np.linalg.inv(linear).transpose(0,2,1),normal)
        ns/=np.linalg.norm(ns,axis=1,keepdims=True)
        animated=[]
        for i,g in enumerate(gs):
            q=Matrix(eigenvectors[i].tolist()).to_quaternion()
            s=np.sqrt(eigenvalues[i])
            animated.append({**g,'p':tuple(posed[i]),'s':tuple(s),'q':(q.x,q.y,q.z,q.w),'r':float(np.prod(s)**(1/3))})
        path=out/f'{index:02d}.tres';write_tres(path,animated,f'player_ranger_walk_{index:02d}',ns.tolist())
        frames.append({'resource':str(path.relative_to(root)),'source_frame':sample})
        bounds.append({'min':posed.min(0).tolist(),'max':posed.max(0).tolist()})
        # Exact posed source geometry remains available for shadow proxies and QA.
        roots=[o for o in bpy.context.scene.objects if o.parent is None]
        saved=[(o,o.location.copy(),o.scale.copy()) for o in roots]
        for obj,location,size in saved:
            obj.location=(location-Vector(offset))*scale;obj.scale=size*scale
        bpy.ops.export_scene.gltf(filepath=str(proxy_dir/f'{index:02d}.glb'),export_format='GLB',export_animations=False,export_current_frame=True,export_rest_position_armature=False)
        for obj,location,size in saved:obj.location=location;obj.scale=size
        bpy.context.view_layer.update()
    manifest={'method':'source-rig deformation of normal-supervised fitted idle cloud','gaussians_per_frame':len(gs),
              'source_sha256':recipe['source_sha256'],'input_ply_sha256':hashlib.sha256((fitted/'refined.ply').read_bytes()).hexdigest(),
              'animation_sha256':hashlib.sha256(animation.read_bytes()).hexdigest(),'action':action.name,
              'normalization':recipe['normalization'],'fps':10,'frames':frames,'frame_bounds':bounds,
              'correspondence':'same Gaussian index, color and opacity in every frame',
              'nearest_source_distance_mean':float(np.mean(distances)),'nearest_source_distance_max':max(distances)}
    manifest['input_normals_sha256']=hashlib.sha256((fitted/'normals.json').read_bytes()).hexdigest()
    (out/'clip.json').write_text(json.dumps(manifest,indent=2)+'\n')
    resource=f'[gd_resource type="Resource" script_class="Splite" load_steps={len(frames)+3} format=3]\n\n'
    resource+='[ext_resource type="Script" path="res://addons/splite/core/splite.gd" id="script"]\n'
    resource+='[ext_resource type="Resource" path="res://assets/clouds/garden/ranger.tres" id="idle"]\n'
    for i,frame in enumerate(frames):
        resource+=f'[ext_resource type="Resource" path="res://{frame["resource"]}" id="f{i}"]\n'
    resource+='\n[resource]\nscript = ExtResource("script")\nid = &"ranger"\nfps = 10.0\n'
    resource+='hitbox = AABB(-0.39, 0, -0.30, 0.79, 1.34, 0.60)\n'
    resource+='clips = {&"idle": [ExtResource("idle")], &"walk": ['
    resource+=', '.join(f'ExtResource("f{i}")' for i in range(len(frames)))+']}\n'
    (out/'actor.tres').write_text(resource)
    np.savez_compressed(out/'skin_weights.npz',weights=skin,bone_names=np.array([b.name for b in bones]+['identity']))
    print('bake_skinned_clip:',len(frames),'frames;',len(gs),'persistent Gaussians')

if __name__=='__main__':main()
