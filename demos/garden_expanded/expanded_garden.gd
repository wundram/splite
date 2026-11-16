extends "res://demos/shared/garden.gd"
## Larger fitted-asset garden using the original rooms, states and stair contracts.
const RANGER = preload("res://demos/garden_expanded/ranger_visual.gd")
const FITTED = preload("res://addons/splite/render/fitted_splat_batch.gd")
const RUNS := [
	{"level":0,"x":10,"bot":8,"top":7,"exit":"N"},
	{"level":1,"x":12,"bot":5,"top":4,"exit":"N"},
	{"level":2,"x":2,"bot":4,"top":3,"exit":"N"},
]
var ranger: Node3D
var decoration: Array[Dictionary] = []
var fitted_trees: Array[SplatBatch] = []
var _last_actor := Vector3.ZERO
var _walk_time := 0.0
var door_hinge: Node3D
var stair_meshes: Array[MeshInstance3D] = []

func stair_runs() -> Array:return RUNS

func build() -> void:
	super.build()
	# The fitted renderer owns the Ranger; retain the original navigation footprint.
	actor.splite=null
	ranger=RANGER.new()
	ranger.scale=Vector3.ONE*.72
	actor.add_child(ranger)
	# Keep the accepted study's afternoon palette while retaining clock interpolation.
	clock._knots[1]["color"]=Color("ffe4bf")
	clock._knots[1]["amb"]=Color("b4c1cc")
	clock._knots[1]["amb_e"]=.55
	clock._knots[1]["energy"]=1.6
	_sun_node.shadow_enabled=true
	_sun_node.directional_shadow_max_distance=24
	_env.adjustment_enabled=true
	_env.adjustment_saturation=1.13
	_env.adjustment_contrast=1.04
	_env.ssao_intensity=.6
	world._drops.visible=false # Source meshes and tile hulls now cast real shadows.
	torch.light_energy=1.2
	lantern.energy=1.4
	cam.dof_blur=0.0
	hint._label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	hint._label.pixel_size=.0035
	hint.offset=Vector3(0,.85,0)
	_dress_models()
	_build_door()
	_build_stairs()
	_last_actor=actor.position
	tick(0)

func _paint() -> void:
	# Replace procedural lawn blobs with solid tiled surfaces and source dressing.
	var colors := {"grass_a":"687f50","grass_b":"6b8152","grass_c":"6e8455",
		"path":"b4a480","brush_a":"617848","brush_b":"6a8050","brush_heavy_a":"587245",
		"flower_a":"687f50","flower_b":"687f50","stone":"a39b84","planks":"98764f",
		"bridge":"a58759","wall":"a99c80","water":"306d68","trunk":"687f50"}
	for id in colors:
		var st: TileState=world.defs[StringName(id)].states[&"default"]
		st.cloud=null
		if st.surface==null:st.surface=TileSurface.new()
		st.surface.visible=true
		st.surface.color=Color(colors[id])
		if id in ["grass_a","grass_b","grass_c","path","brush_a","brush_b","brush_heavy_a","flower_a","flower_b","trunk"]:
			st.hull=AABB(Vector3(-.5,-.18,-.5),Vector3(1,.20,1))
			st.cast_model=TileDef.CastModel.NONE
	for id in [&"stone",&"planks"]:
		world.defs[id].states[&"default"].hull=AABB(Vector3(-.49,-.12,-.49),Vector3(.98,.14,.98))
	for st in world.defs[&"cellar_door"].states.values():
		st.cloud=null
		st.surface.visible=false
		for i in st.sequence.size():st.sequence[i]=SplatCloud.new()
	world.defs[&"stair"].states[&"default"].cloud=null
	world.defs[&"stair"].states[&"default"].surface.visible=false
	# Ground-floor layout and cellar retain the previous demo's interactions.
	for z in MAPS[0].size():
		var row: String=MAPS[0][z]
		for x in row.length():
			var ch:=row[x]
			world.set_cell(0,x,z,_tile_for(ch),_room_of(0,x,z,ch))
			if ch=="T":_spawn_torch(0,x,z)
	# A connected dog-leg ascent, rather than two stair flights at the same XZ.
	for z in [5,6]:
		for x in range(10,14):world.set_cell(1,x,z,&"stone",&"OUTSIDE")
	for z in range(2,7):
		for x in range(2,14):
			if z>=5 and x>=11:continue
			world.set_cell(2,x,z,&"stone",&"OUTSIDE")
	for z in [1,2]:
		for x in [1,2,3]:world.set_cell(3,x,z,&"planks",&"OUTSIDE")
	for run in RUNS:
		for z in [run.bot,run.top]:
			world.set_cell(run.level,run.x,z,&"stair",&"OUTSIDE")
			# Do not leave an upper slab across the stairwell.
			world.cells.erase(Vector3i(run.level+1,run.x,z))

func _add_volumes_and_field() -> void:
	super._add_volumes_and_field()
	world.volumes.erase(canopy_volume)
	canopy_volume.queue_free()
	canopy_volume=null
	foam_volume.def.room=&"OUTSIDE"

func _model(id: String, pos: Vector3, size: float, room: StringName=&"OUTSIDE") -> Node3D:
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(doc.append_from_file("res://assets/models/garden/"+id+".glb",state)==OK)
	var node:=doc.generate_scene(state) as Node3D
	add_child(node)
	node.position=pos
	node.scale=Vector3.ONE*size
	node.rotation.y=pos.x*1.73+pos.z
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.get_active_material(i)
			if mat is StandardMaterial3D:
				mat.roughness=.95
				if mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA:
					mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold=.45
	decoration.append({"node":node,"room":room})
	return node

func _dress_models() -> void:
	for key in world.cells:
		if key.x!=0:continue
		var cell: SplatWorld.Cell=world.cells[key]
		var id:=String(cell.def.id)
		var pos:=world.cell_origin(key.x,key.y,key.z)+Vector3(0,.035,0)
		if id.begins_with("brush"):
			_model("garden_shrub_sage",pos,.63 if id!="brush_heavy_a" else .85)
		elif id.begins_with("flower"):
			_model("garden_flowers",pos,.62)
		elif id=="path":
			var stone:=_box(pos+Vector3(0,.01,0),Vector3(.78,.05,.72),Color("c2b698"))
			stone.rotation.y=sin(float(key.y*3+key.z))*.12
		elif id=="bridge":
			for i in 5:
				_box(pos+Vector3(0,.15,(float(i)-2)*.19),Vector3(.94,.055,.17),Color("ac895b"))
			for x in [-.43,.43]:
				_box(pos+Vector3(x,.4,0),Vector3(.045,.045,.98),Color("94734c"))
		elif id.begins_with("grass") and (key.y*7+key.z*3)%9==0:
			_model("garden_grass_sage",pos,.40)
	for pos in [Vector3(12,.03,2),Vector3(2,.03,11)]:
		var tree:=_model("garden_tree_sage",pos,1.0)
		for mesh in tree.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var batch=FITTED.new()
		batch.scene_lighting=true
		tree.add_child(batch)
		batch.add_static_cloud(preload("res://assets/clouds/garden/tree.tres"),Transform3D.IDENTITY,Color.WHITE,float(TileDef.Cutaway.IF_OCCLUDES),2.6)
		fitted_trees.append(batch)
	for pos in [Vector3(13,.02,11),Vector3(8,.02,2),Vector3(1,.02,7)]:
		_model("garden_rock",pos,.65)
	# Pots and furniture make the high terrace and cellar read as places.
	for pos in [Vector3(4,2.53,2),Vector3(8,2.53,2),Vector3(3,2.53,6)]:
		_box(pos+Vector3(0,.15,0),Vector3(.55,.3,.55),Color("a97555"))
		_model("garden_flowers",pos+Vector3(0,.30,0),.6)
	for x in [3,6]:
		_box(Vector3(x,.30,3),Vector3(.65,.6,.65),Color("806342"),&"CELLAR_IN")
	_box(Vector3(4,.52,3),Vector3(1.4,.12,.6),Color("ad8553"),&"CELLAR_IN")
	# Edge rails emphasize depth without blocking the marked stair openings.
	for x in range(3,14):
		_box(Vector3(x,2.86,1.55),Vector3(.95,.07,.07),Color("87714f"))
		_box(Vector3(x,2.71,1.55),Vector3(.075,.43,.075),Color("756244"))
	for z in [1,2]:
		for x in [.55,3.45]:
			_box(Vector3(x,4.05,z),Vector3(.06,.5,.08),Color("876a43"))
			_box(Vector3(x,4.25,z),Vector3(.06,.06,.98),Color("a18459"))
	# Two garden benches face across the upper terrace.
	for x in [6,9]:
		_box(Vector3(x,2.83,3),Vector3(1.25,.10,.45),Color("9d8053"))
		_box(Vector3(x,3.09,2.8),Vector3(1.25,.4,.075),Color("90744b"))
		for dx in [-.46,.46]:_box(Vector3(x+dx,2.66,3),Vector3(.08,.3,.35),Color("6e6147"))
	# Raised foundations and inset walkway joints establish the height layers.
	for x in [3,8,13]:
		_box(Vector3(x,1.18,2),Vector3(.28,2.4,.28),Color("8d8067"))

func _box(pos: Vector3, size: Vector3, color: Color, room: StringName=&"OUTSIDE") -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://addons/splite/render/surface.gdshader")
	node.material_override=mat
	node.set_instance_shader_parameter("albedo",color)
	node.set_instance_shader_parameter("cut_policy",float(TileDef.Cutaway.IF_ABOVE))
	node.set_instance_shader_parameter("hull_top",pos.y+size.y*.5)
	add_child(node)
	node.position=pos
	decoration.append({"node":node,"room":room})
	return node

func _build_stairs() -> void:
	for run in RUNS:
		for i in 12:
			var h:=float(i+1)/12.0*world.level_height
			var z: float=run.bot+.5-(float(i)+.5)/6.0
			var mesh:=_box(Vector3(run.x,world.floor_y(run.level)+h*.5,z),Vector3(.98,h,1.0/6.0),Color("b1a082"))
			stair_meshes.append(mesh)

func try_move(step: Vector3) -> void:
	var before:=actor.position
	super.try_move(step)
	var moved:=actor.position-before
	if ranger!=null and Vector2(moved.x,moved.z).length_squared()>.000001:
		ranger.rotation.y=atan2(moved.x,moved.z)

func tick(delta: float) -> void:
	super.tick(delta)
	if ranger==null:return
	var moving:=actor.position.distance_squared_to(_last_actor)>.000001 and actor.playing
	_walk_time=_walk_time+delta if moving else 0.0
	ranger.set_pose(int(_walk_time*10) if moving else -1)
	_last_actor=actor.position
	for item in decoration:
		item.node.visible=world.active_rooms.has(item.room)
		if item.node is MeshInstance3D:
			var mat: ShaderMaterial=item.node.material_override
			mat.set_shader_parameter("cut_origin",world.cut_origin())
	for batch in fitted_trees:
		batch.set_cutaway(world.cut_origin(),world.cutaway_inner,world.cutaway_outer,world.cutaway_y_soft,world.cutaway_y_bias,.72)
	if door_hinge!=null:
		var cell: SplatWorld.Cell=world.cells[CELLAR_DOOR]
		var progress:=1.0 if cell.state==&"open" else (clampf(cell.seq_time/.4,0,1) if cell.state==&"opening" else 0.0)
		door_hinge.rotation.y=-PI*.5*smoothstep(0.0,1.0,progress)
	if ember!=null:
		ember.position.y=.06+sin(_time*2.4)*.07
		ember.rotation.y=_time*.8

func objective() -> String:
	if world.active_rooms.has(&"CELLAR_IN"):
		return "THE EMBER CELLAR   ·   "+("E to take the ember" if not ember_taken else "Return to the garden")
	if player_level==3:return "THE LOOKOUT   ·   Three levels above the garden"
	if player_level==2:return "THE UPPER TERRACE   ·   West stairs lead to the lookout"
	if player_level==1:return "THE WALKWAY   ·   Follow the landing east, then climb north"
	return "THE TERRACED GARDEN   ·   "+("Explore the stairs and the pond" if ember_taken else "Find the cellar door · E to open")

func _build_door() -> void:
	_box(Vector3(5,-.08,5),Vector3(1,.16,1),Color("a58b60"),&"CWALLS")
	door_hinge=Node3D.new()
	add_child(door_hinge)
	door_hinge.position=Vector3(4.53,0,5.26)
	decoration.append({"node":door_hinge,"room":&"CWALLS"})
	for i in 5:
		var panel:=_box(Vector3(.095+float(i)*.185,.54,0),Vector3(.175,1.08,.09),Color("805c39"),&"CWALLS")
		panel.reparent(door_hinge,false)
		panel.set_instance_shader_parameter("cut_policy",0.0)
	for y in [.20,.88]:
		var brace:=_box(Vector3(.46,y,.055),Vector3(.9,.07,.035),Color("4e4436"),&"CWALLS")
		brace.reparent(door_hinge,false)
		brace.set_instance_shader_parameter("cut_policy",0.0)
	var handle:=_box(Vector3(.81,.53,.08),Vector3(.055,.13,.05),Color("dbb25b"),&"CWALLS")
	handle.reparent(door_hinge,false)
	handle.set_instance_shader_parameter("cut_policy",0.0)
