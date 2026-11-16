extends Node3D
## Source-model garden vignette. A separate visual study until fitted assets pass.
const SUN := Vector3(-0.76, 0.54, -0.35)
@export var use_fitted := false
var traveler: Node3D
var _capture := ""
var _clock := 0.0
var ranger_clip: Splite
var _ranger_batch: SplatBatch
var _idle_meshes: Array[MeshInstance3D] = []
var _walk_proxies: Array[Node3D] = []
var _pose := -2

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): _capture = arg.trim_prefix("--capture=")
	_environment()
	_island()
	_dress()
	_ui()
	if not _capture.is_empty():
		for i in 30: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture)
		print("garden_study: captured ",_capture)
		get_tree().quit()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015,0.016,0.020)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c1cc")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.13
	env.adjustment_contrast = 1.04
	var world := WorldEnvironment.new()
	world.environment=env
	add_child(world)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.basis=Basis.looking_at(-SUN.normalized(),Vector3.UP)
	sun.light_color=Color("ffe4bf")
	sun.light_energy=1.6
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=16
	var cam := Camera3D.new()
	add_child(cam)
	cam.position=Vector3(-0.82,6.6,0.82)
	cam.look_at(Vector3.ZERO,Vector3(0,0,-1))
	cam.fov=60
	cam.current=true

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=0.95
	return mat

func _mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=_material(color)
	node.position=pos
	add_child(node)
	return node

func _disc(pos: Vector3, radius: float, height: float, color: Color, sides: int=24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius*0.96
	mesh.height=height
	mesh.radial_segments=sides
	return _mesh(mesh,pos,color)

func _box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return _mesh(mesh,pos,color)

func _island() -> void:
	var earth := _disc(Vector3(0,-0.24,0),2.45,0.42,Color("463e35"),20)
	earth.scale.z=0.83
	var edge := _disc(Vector3(0,-0.055,0),2.44,0.16,Color("697052"),20)
	edge.scale.z=0.83
	var lawn := _disc(Vector3(0,0.025,0),2.39,0.055,Color("687f50"),20)
	lawn.scale.z=0.83
	# Small variations break up the lawn without adding visual noise.
	for i in 18:
		var angle := float(i)*2.39996
		var radius := 0.45+1.45*float(i%5)/5.0
		var patch := _disc(Vector3(cos(angle)*radius,0.057,sin(angle)*radius*.76),.27+float(i%3)*.09,.006,Color("77905b"),9)
		patch.rotation.y=angle
		patch.scale.z=.7
	# Worn stones lead the eye from the traveler to the tree.
	for i in 9:
		var t := float(i)/8.0
		var stone := _disc(Vector3(0.18-sin(t*2.1)*.95,0.092,1.55-t*2.1),.19,.075,Color("b2ad94").lerp(Color("918e7d"),float(i%3)*.15),7)
		stone.scale.z=.74
		stone.rotation.y=float(i)*.73
	# Pond with a stone rim and a short boardwalk.
	var rim := _disc(Vector3(1.08,.073,.18),.78,.075,Color("9b9b80"),24)
	rim.scale.z=.77
	var water := _disc(Vector3(1.08,.116,.18),.68,.018,Color("306d68"),40)
	water.scale.z=.77
	var water_mat := water.material_override as StandardMaterial3D
	water_mat.roughness=.32
	water_mat.metallic=.08
	for i in 7:
		var plank := _box(Vector3(.81+float(i)*.11,.18,.20),Vector3(.095,.07,.77),Color("a1845c").lerp(Color("75634d"),float(i%3)*.15))
		plank.rotation.y=.02*sin(float(i)*2)
	for x in [.82,1.47]:
		for z in [-.15,.54]:
			_box(Vector3(x,.24,z),Vector3(.065,.35,.065),Color("66523d"))
	for z in [-.15,.54]:_box(Vector3(1.14,.39,z),Vector3(.78,.05,.05),Color("89714f"))

func _source(name: String, pos: Vector3, scale_factor: float=1.0, yaw: float=0.0) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var path := "res://assets/models/garden/"+name+".glb"
	assert(doc.append_from_file(path,state)==OK,"Failed source model: "+path)
	var node := doc.generate_scene(state) as Node3D
	add_child(node)
	node.position=pos
	node.scale=Vector3.ONE*scale_factor
	node.rotation.y=yaw
	_cutout(node)
	if use_fitted and name in ["garden_tree_sage", "player_ranger"]:
		var cloud_id := "tree" if name == "garden_tree_sage" else "ranger"
		var cloud = load("res://assets/clouds/garden/"+cloud_id+".tres")
		assert(cloud != null, "Missing fitted garden asset: "+cloud_id)
		_shadow_proxy(node)
		var batch = load("res://addons/splite/render/fitted_splat_batch.gd").new()
		batch.scene_lighting=true
		node.add_child(batch)
		batch.saturate=1.0
		batch.lift=0.0
		batch.set_lighting(SUN,Color("ffe4bf").srgb_to_linear(),1.6,Color("b4c1cc").srgb_to_linear(),.55)
		batch.add_static_cloud(cloud,Transform3D.IDENTITY)
		batch.commit()
	return node

func _shadow_proxy(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for child in node.get_children():_shadow_proxy(child)

func _cutout(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i) as StandardMaterial3D
			if mat != null:
				mat.roughness = .95
				mat.metallic = 0.0
			if mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold=.45
	for child in node.get_children():_cutout(child)

func _dress() -> void:
	_source("garden_tree_sage",Vector3(-.88,.065,-.78),.86,.45)
	_source("garden_shrub_sage",Vector3(1.25,.065,-1.15),.82,-.5)
	_source("garden_shrub_sage",Vector3(-1.5,.065,.73),.72,1.3)
	for pos in [Vector3(-1.35,.065,1.06),Vector3(.61,.065,-1.42),Vector3(1.66,.065,.92),Vector3(-1.66,.065,-.23)]:
		_source("garden_flowers",pos,.58,pos.x)
	for i in 12:
		var angle := float(i)*TAU/12.0
		_source("garden_grass_sage",Vector3(cos(angle)*2.02,.062,sin(angle)*1.59),.44,angle)
	_source("garden_rock",Vector3(1.72,.066,-.52),.56,1.8)
	_source("garden_rock",Vector3(-1.85,.065,.26),.42,.3)
	traveler=_source("player_ranger",Vector3(.02,.07,1.18),.72,0)
	ranger_clip=load("res://assets/clouds/garden/ranger_walk/actor.tres")
	for mesh in traveler.find_children("*", "MeshInstance3D", true, false):
		_idle_meshes.append(mesh)
	for child in traveler.get_children():
		if child is SplatBatch:_ranger_batch=child
	for i in ranger_clip.frame_count(&"walk"):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file("res://assets/models/garden/ranger_walk/%02d.glb" % i,state)==OK)
		var proxy := doc.generate_scene(state) as Node3D
		traveler.add_child(proxy)
		_cutout(proxy)
		if use_fitted:_shadow_proxy(proxy)
		proxy.visible=false
		_walk_proxies.append(proxy)
	set_walk_pose(-1)

## -1 selects idle; nonnegative indices select persistent-Gaussian walk frames.
func set_walk_pose(index: int) -> void:
	if index >= 0:index %= ranger_clip.frame_count(&"walk")
	if index == _pose:return
	_pose=index
	for mesh in _idle_meshes:mesh.visible=index < 0
	for i in _walk_proxies.size():_walk_proxies[i].visible=i == index
	if _ranger_batch != null:
		_ranger_batch.clear_static()
		_ranger_batch.add_static_cloud(ranger_clip.frame(&"idle" if index < 0 else &"walk",maxi(index,0)),Transform3D.IDENTITY)
		# The batch uploads once during its process, after pose and world transform change.

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text="THE LITTLE GARDEN"
	title.position=Vector2(42,30)
	title.add_theme_font_size_override("font_size",25)
	title.add_theme_color_override("font_color",Color("e8dfc9"))
	layer.add_child(title)
	var caption := Label.new()
	caption.text=("Fitted garden study" if use_fitted else "Source model study")+"   •   WASD to wander"
	caption.position=Vector2(43,64)
	caption.add_theme_font_size_override("font_size",15)
	caption.add_theme_color_override("font_color",Color("9aa694"))
	layer.add_child(caption)

func _process(delta: float) -> void:
	if traveler == null:return
	var move := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if move.length_squared()>0:
		move=move.normalized()
		traveler.position += move*delta*1.3
		traveler.position.x=clampf(traveler.position.x,-1.8,1.8)
		traveler.position.z=clampf(traveler.position.z,-1.35,1.6)
		traveler.rotation.y=atan2(move.x,move.z)
		_clock += delta
		set_walk_pose(int(_clock*ranger_clip.fps))
	else:
		_clock=0.0
		set_walk_pose(-1)
	traveler.position.y=.07
