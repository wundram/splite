extends Node3D
## Persistent fitted frames and frame-matched source shadow geometry.
const BATCH = preload("res://addons/splite/render/fitted_splat_batch.gd")
var clip: Splite = preload("res://assets/clouds/garden/ranger_walk/actor.tres")
var batch: SplatBatch
var proxies: Array[Node3D] = []
var pose := -2

func _ready() -> void:
	batch=BATCH.new()
	batch.scene_lighting=true
	add_child(batch)
	proxies.append(model("player_ranger"))
	for i in clip.frame_count(&"walk"):proxies.append(model("ranger_walk/%02d" % i))
	set_pose(-1)

func model(id: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file("res://assets/models/garden/"+id+".glb",state)==OK)
	var node := doc.generate_scene(state) as Node3D
	add_child(node)
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	node.visible=false
	return node

func set_pose(index: int) -> void:
	if index>=0:index%=clip.frame_count(&"walk")
	if pose==index:return
	pose=index
	for i in proxies.size():proxies[i].visible=i==index+1
	batch.clear_static()
	batch.add_static_cloud(clip.frame(&"idle" if index<0 else &"walk",maxi(index,0)),Transform3D.IDENTITY)
