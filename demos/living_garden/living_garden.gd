extends "res://demos/garden_expanded/expanded_garden.gd"
const Art=preload("res://demos/living_garden/art.gd")
const Critter=preload("res://demos/living_garden/creature.gd")
const Spell=preload("res://demos/living_garden/magic.gd")
const SIZE=Vector2i(36,30)
const POND=Vector3(25,0,7)
const FLOOR_IDS=[&"grass_a",&"grass_b",&"grass_c",&"path",&"brush_a",&"brush_b",&"brush_heavy_a",&"flower_a",&"flower_b",&"trunk"]
var foliage_cache: Dictionary={}
var tree_stats: Dictionary={}
var maze: Array[String]=[]
var creatures: Array[Node3D]=[]
var vegetation_materials: Array[ShaderMaterial]=[]
var spell: Node3D
var discovered: Dictionary={}
var shrine_awake:=false
var outdoor_root: Node3D
var water_material: ShaderMaterial

func build() -> void:
	super.build()
	outdoor_root=Node3D.new();outdoor_root.name="LivingOutdoors";add_child(outdoor_root)
	_ground_batch()
	var foundation:=PlaneMesh.new();foundation.size=Vector2(13,13)
	Art.mesh(outdoor_root,foundation,Vector3(27,-.13,21),Color("536744"))
	_landscape()
	_maze_dressing()
	_rose_walls()
	_pond()
	_slopes()
	_wildlife()
	_shrines()
	spell=Spell.new();spell.garden=self;add_child(spell)
	_env.glow_enabled=true
	_env.glow_intensity=.35
	world._needs_static=true
	# The new garden gate is visible from the initial lawn.
	place(12,16,0)
	_last_actor=actor.position
	tick(0)

func _model(id: String,pos: Vector3,size: float,room: StringName=&"OUTSIDE") -> Node3D:
	var node:=Art.source(id)
	add_child(node);node.position=pos;node.scale=Vector3.ONE*size;node.rotation.y=pos.x*1.73+pos.z
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture!=null:
				var key:=str(mat.get_instance_id())+id
				var shader: ShaderMaterial=foliage_cache.get(key)
				if shader==null:
					shader=ShaderMaterial.new();shader.shader=preload("res://demos/living_garden/shaders/foliage.gdshader")
					shader.set_shader_parameter("base_texture",mat.albedo_texture)
					shader.set_shader_parameter("tint",mat.albedo_color)
					shader.set_shader_parameter("wind",.018 if mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED else 0.)
					if mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED and id in ["garden_maple","garden_birch","garden_pine"]:
						var palette: Color={"garden_maple":Color("b87c51"),"garden_birch":Color("8caa69"),"garden_pine":Color("4e775a")}[id]
						shader.set_shader_parameter("palette_color",palette)
						shader.set_shader_parameter("palette_strength",.85)
					foliage_cache[key]=shader;vegetation_materials.append(shader)
				mesh.set_surface_override_material(i,shader)
				mesh.set_instance_shader_parameter("canopy_top",pos.y+7.*size)
	if id in ["garden_maple","garden_birch","garden_pine","garden_tree_sage","garden_deadwood"]:
		var height:=0.0
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=mesh.global_transform*mesh.get_aabb()
			height=maxf(height,bounds.end.y-pos.y)
		var record: Dictionary=tree_stats.get(id,{"count":0,"max_height_m":0.0})
		record.count+=1;record.max_height_m=maxf(record.max_height_m,height);tree_stats[id]=record
	decoration.append({"node":node,"room":room})
	return node

func _paint() -> void:
	super._paint()
	var hedge:=TileDef.new();hedge.id=&"rose_hedge"
	var st:=TileState.new();st.walkable=false;st.blocks_los=true;st.cutaway=TileDef.Cutaway.IF_OCCLUDES
	st.hull=AABB(Vector3(-.5,0,-.5),Vector3(1,1.35,1));st.surface=TileSurface.new();st.surface.visible=true;st.surface.color=Color("375b42")
	hedge.states[&"default"]=st;world.defs[hedge.id]=hedge
	var rose_wall: TileDef=world.defs[&"wall"].duplicate(true)
	rose_wall.id=&"rose_wall"
	rose_wall.states[&"default"].hull=AABB(Vector3(-.5,0,-.225),Vector3(1,1.3,.45))
	rose_wall.states[&"default"].surface.color=Color("8e9380")
	world.defs[&"rose_wall"]=rose_wall
	for z in SIZE.y:
		for x in SIZE.x:
			var key:=Vector3i(0,x,z)
			if not world.cells.has(key):
				var id:=&"grass_a" if (x+z*3)%3==0 else &"grass_b"
				if x==0 or z==0 or x==35 or z==29:id=&"wall"
				world.set_cell(0,x,z,id,&"OUTSIDE")
	# Open the former boundary into broad paths, preserving the original cellar.
	for z in range(4,13):world.set_cell(0,15,z,&"path",&"OUTSIDE")
	for x in range(3,15):world.set_cell(0,x,13,&"path",&"OUTSIDE")
	for z in range(14,29):
		for x in [17,18,19]:world.set_cell(0,x,z,&"path",&"OUTSIDE")
	for x in range(13,35):
		for z in [12,13,14]:world.set_cell(0,x,z,&"path",&"OUTSIDE")
	# Deeper pond basin: fish remain just below the transparent water surface.
	for z in range(4,11):
		for x in range(21,30):world.set_cell(0,x,z,&"water",&"OUTSIDE")
	for z in range(4,11):world.set_cell(0,28,z,&"bridge",&"OUTSIDE")
	for x in range(17,35):
		if x not in [19,20,28,29]:world.set_cell(0,x,2,&"rose_wall",&"OUTSIDE")
	_build_maze()
	for id in FLOOR_IDS:world.defs[id].states[&"default"].surface.visible=false

func _build_maze() -> void:
	var grid: Array=[]
	for z in 13:
		var row: Array=[]
		for x in 13:row.append(true)
		grid.append(row)
	var rng:=RandomNumberGenerator.new();rng.seed=931
	var stack: Array[Vector2i]=[Vector2i(1,1)];grid[1][1]=false
	while not stack.is_empty():
		var p: Vector2i=stack.back();var options: Array[Vector2i]=[]
		for d in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
			var q: Vector2i=p+d
			if q.x>0 and q.x<12 and q.y>0 and q.y<12 and grid[q.y][q.x]:options.append(q)
		if options.is_empty():stack.pop_back();continue
		var q: Vector2i=options[rng.randi_range(0,options.size()-1)]
		grid[q.y][q.x]=false;grid[int((p.y+q.y)/2)][int((p.x+q.x)/2)]=false;stack.append(q)
	grid[1][0]=false;grid[11][12]=false
	for z in range(9,12):
		for x in range(9,12):grid[z][x]=false
	for z in 13:
		var line:=""
		for x in 13:
			line+="#" if grid[z][x] else "."
			world.set_cell(0,21+x,15+z,&"rose_hedge" if grid[z][x] else &"path",&"OUTSIDE")
		maze.append(line)

func _landscape() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=145
	# Distinct source species, including pines reaching above the camera.
	for i in 38:
		var x:=rng.randf_range(2,16);var z:=rng.randf_range(17,27)
		if x>9 and x<13:continue # Keep an open north/south woodland walk.
		var id: String=["garden_birch","garden_pine","garden_maple","garden_tree_sage"][i%4]
		var size:=rng.randf_range(.65,1.2)
		if i%9==0:size=1.7
		var y:=slope_height(Vector2(x,z))
		var tree:=_model(id,Vector3(x,y+.025,z),size)
		world.walk[Vector3i(0,roundi(x),roundi(z))]=false
		if id=="garden_tree_sage" and fitted_trees.size()<5:
			for mesh in tree.find_children("*","MeshInstance3D",true,false):
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			var batch=FITTED.new();batch.scene_lighting=true;tree.add_child(batch)
			batch.add_static_cloud(preload("res://assets/clouds/garden/tree.tres"),Transform3D.IDENTITY,Color.WHITE,float(TileDef.Cutaway.IF_OCCLUDES),y+3.5*size)
			fitted_trees.append(batch)
	for pos in [Vector3(19,0,3),Vector3(32,0,3),Vector3(32,0,10),Vector3(17,0,8)]:_model("garden_maple",pos,1.2)
	_model("garden_deadwood",Vector3(31,0,25),1.1)
	_model("garden_pine",Vector3(4,1.3,26),3.0)
	world.walk[Vector3i(0,4,26)]=false
	for i in 95:
		var p:=Vector3(rng.randf_range(1,34),0,rng.randf_range(14,28))
		if not world.is_walkable(0,Vector2(p.x,p.z)) or p.x>20 or (p.x>9 and p.x<13):continue
		p.y=slope_height(Vector2(p.x,p.z))+.04
		_model("garden_flowers" if i%3==0 else "garden_grass_sage",p,rng.randf_range(.35,.7))

func _maze_dressing() -> void:
	var leaves: Array[Dictionary]=[]
	var roses: Array[Dictionary]=[]
	for z in 13:
		for x in 13:
			if maze[z][x]!="#":continue
			for j in 8:
				var a:=float(j)*2.399+float(x+z)
				leaves.append({"pos":Vector3(21+x+sin(a)*.32,1.29+sin(a*2.)*.035,15+z+cos(a)*.32),"size":Vector3(.48,.28,.48),"color":Color("496c45").lightened(float(j%3)*.025)})
			if (x+z)%5==0:roses.append({"pos":Vector3(21+x,1.47,15+z),"size":Vector3(.14,.10,.14),"color":Color("d892aa")})
	var hedge_top:=Art.scatter(outdoor_root,leaves,Color.WHITE)
	# Match the maze's camera cutaway on its leaf crowns.
	var mat:=ShaderMaterial.new();mat.shader=preload("res://demos/living_garden/shaders/hedge.gdshader")
	hedge_top.material_override=mat;vegetation_materials.append(mat)
	Art.scatter(outdoor_root,roses,Color.WHITE)

func _rose_walls() -> void:
	var leaves: Array[Dictionary]=[];var blossoms: Array[Dictionary]=[];var vines: Array[Dictionary]=[]
	for x in range(17,35):
		if x in [19,20,28,29]:continue
		var z:=2.0

		Art.box(outdoor_root,Vector3(x,1.34,z),Vector3(1.02,.13,.53),Color("b5b498"))
		var last:=Vector3(float(x),.06,z+.255)
		for j in 12:
			var y:=.16+float(j)*.10
			var px:=x+sin(float(j)*.8+float(x))*.34
			var next:=Vector3(px,y,z+.255)
			var stem_size:=Vector3(.03,last.distance_to(next),.03)
			vines.append({"pos":(last+next)*.5,"size":stem_size,"basis":Basis(Quaternion(Vector3.UP,(next-last).normalized()))*Basis.from_scale(stem_size),"color":Color("5d6641")})
			last=next
			leaves.append({"pos":Vector3(px,y,z+.255),"size":Vector3(.20,.13,.065),"color":Color("426545")})
			if j%3==0:
				for petal in 5:
					var a:=float(petal)*TAU/5.
					blossoms.append({"pos":Vector3(px+cos(a)*.05,y+sin(a)*.05,z+.3),"size":Vector3(.09,.09,.07),"color":Color("d98e9e")})
	Art.scatter(outdoor_root,leaves,Color.WHITE);Art.scatter(outdoor_root,blossoms,Color.WHITE);Art.scatter(outdoor_root,vines,Color.WHITE)

func _pond() -> void:
	water_material=ShaderMaterial.new();water_material.shader=preload("res://demos/living_garden/shaders/water.gdshader")
	for spec in [{"pos":Vector3(25,.17,7),"size":Vector2(8.8,6.8)},{"pos":Vector3(12,.17,9.5),"size":Vector2(2.9,1.9)}]:
		var plane:=PlaneMesh.new();plane.size=spec.size;plane.subdivide_width=30;plane.subdivide_depth=20
		var water:=Art.mesh(outdoor_root,plane,spec.pos,Color.WHITE);water.material_override=water_material;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var probe:=ReflectionProbe.new();outdoor_root.add_child(probe)
	probe.position=Vector3(25,2,7);probe.size=Vector3(22,12,20);probe.origin_offset=Vector3(0,1,0)
	probe.max_distance=35;probe.update_mode=ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode=ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color=Color("b4c1cc");probe.ambient_color_energy=.55
	for i in 17:
		var a:=float(i)*2.399
		var p:=POND+Vector3(sin(a)*3.6,.21,cos(a)*2.7)
		var lily:=Art.cylinder(outdoor_root,p,.19,.025,Color("547b51"));lily.scale.z=.8
		if i%4==0:Art.ellipsoid(outdoor_root,p+Vector3(0,.06,0),Vector3(.15,.10,.15),Color("e5c3c5"))

func slope_height(p: Vector2) -> float:
	if p.x<1 or p.x>16 or p.y<17:return 0.
	# Two broad grassy ramps, with soft side slopes back to the surrounding lawn.
	var ridge:=1.3
	if p.y<20:ridge=(p.y-17.)/3.*.65
	elif p.y<22:ridge=.65
	elif p.y<25:ridge=.65+(p.y-22.)/3.*.65
	var edge:=minf(smoothstep(1.,3.,p.x),1.-smoothstep(14.,16.,p.x))
	return ridge*edge

func _slopes() -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(17,29):
		for x in range(1,17):
			var a:=Vector3(x-.5,slope_height(Vector2(x-.5,z-.5)),z-.5)
			var b:=Vector3(x+.5,slope_height(Vector2(x+.5,z-.5)),z-.5)
			var c:=Vector3(x+.5,slope_height(Vector2(x+.5,z+.5)),z+.5)
			var d:=Vector3(x-.5,slope_height(Vector2(x-.5,z+.5)),z+.5)
			for v in [a,c,b,a,d,c]:surface.add_vertex(v+Vector3(0,.025,0))
	surface.generate_normals()
	Art.mesh(outdoor_root,surface.commit(),Vector3.ZERO,Color("70854e"))
	# Low retaining walls leave a broad path up the center.
	for z in [20,25]:
		for x in range(2,16):
			if x>=9 and x<=12:continue
			var y:=slope_height(Vector2(x,z))
			Art.box(outdoor_root,Vector3(x,y-.20,z),Vector3(.96,.38,.34),Color("858b6b"))

func _wildlife() -> void:
	for i in 16:
		var mob=Critter.new();mob.garden=self;mob.phase=float(i)*1.7
		if i<6:
			mob.species="rabbit";mob.home=Vector3(14+float(i%2)*2,.03,15+float(i/2))
		elif i<10:
			mob.species="bird";mob.home=Vector3(17+float(i%3)*3,2.2,9+float(i%2)*4)
		else:
			mob.species="koi";mob.home=Vector3(24+float(i%2),.11,6.5+float(i%3)*.4)
		outdoor_root.add_child(mob);creatures.append(mob)

func _shrines() -> void:
	Art.statue(outdoor_root,Vector3(31,0,7),1.3)
	Art.statue(outdoor_root,Vector3(32,0,26),.65)
	world.walk[Vector3i(0,32,26)]=false
	world.walk[Vector3i(0,31,7)]=false
	var altar:=Interactable.new();altar.name="WhisperingStone";altar.position=Vector3(32,.3,26)
	altar.radius=1.3;altar.prompt="E · Awaken the sleeping garden";altar.verb=&"shrine"
	altar.used.connect(func(_who):shrine_awake=true;cast_spell();altar.prompt="The stone remembers you")
	add_child(altar)

func try_move(step: Vector3) -> void:
	super.try_move(step)
	if player_level==0:actor.position.y=slope_height(Vector2(actor.position.x,actor.position.z))

func tick(delta: float) -> void:
	# Match actor height to the terrain before room/cutaway uniforms are updated.
	if actor!=null and player_level==0 and current_run==null:
		actor.position.y=slope_height(Vector2(actor.position.x,actor.position.z))
	super.tick(delta)
	if outdoor_root==null:return
	outdoor_root.visible=world.active_rooms.has(&"OUTSIDE")
	for mat in vegetation_materials:mat.set_shader_parameter("cut_origin",world.cut_origin())
	for mob in creatures:mob.tick(delta)
	if spell!=null:spell.tick(delta)
	discovered[area_name()]=true

func cast_spell(kind: int=0) -> bool:
	return spell.cast(actor.position,kind) if spell!=null else false

func area_name() -> String:
	if world.active_rooms.has(&"CELLAR_IN"):return "The Ember Cellar"
	if player_level>0:return "The Hanging Terraces"
	var p:=actor.position
	if p.x>=20.5 and p.z>=14.5:return "The Rose Labyrinth"
	if p.x>=20 and p.z<12:return "The Mirror Pond"
	if p.z>=17 and p.x<17:return "The Whispering Wood"
	return "The Walled Garden"

func objective() -> String:return area_name()

func _ground_batch() -> void:
	var entries: Array[Dictionary]=[]
	for key in world.cells:
		var cell: SplatWorld.Cell=world.cells[key]
		if key.x!=0 or cell.def.id not in FLOOR_IDS:continue
		var st: TileState=cell.def.states[cell.state]
		entries.append({"at":world.cell_origin(key.x,key.y,key.z)+st.hull.get_center(),"size":st.hull.size,"color":st.surface.color})
	var shape:=BoxMesh.new();shape.size=Vector3.ONE
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=shape;mm.instance_count=entries.size()
	for i in entries.size():
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(entries[i].size),entries[i].at))
		mm.set_instance_color(i,entries[i].color.srgb_to_linear())
	var node:=MultiMeshInstance3D.new();node.multimesh=mm
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.95
	node.material_override=material;outdoor_root.add_child(node)
