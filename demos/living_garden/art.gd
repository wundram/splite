extends RefCounted
## Reusable authored primitives and cached CC0 source scenes.
static var scenes: Dictionary = {}
static var materials: Dictionary = {}
static func material(color: Color, glow: float=0.0) -> StandardMaterial3D:
	var key:=str(color)+str(glow)
	if materials.has(key):return materials[key]
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=.88
	if glow>0:
		mat.emission_enabled=true
		mat.emission=color
		mat.emission_energy_multiplier=glow
	materials[key]=mat
	return mat
static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color, glow: float=0.0) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.mesh=shape;node.position=pos;node.material_override=material(color,glow)
	parent.add_child(node)
	return node
static func ellipsoid(parent: Node3D,pos: Vector3,size: Vector3,color: Color,glow: float=0.0) -> MeshInstance3D:
	var shape:=SphereMesh.new();shape.radius=.5;shape.height=1;shape.radial_segments=12;shape.rings=6
	var node:=mesh(parent,shape,pos,color,glow);node.scale=size
	return node
static func box(parent: Node3D,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var shape:=BoxMesh.new();shape.size=size
	return mesh(parent,shape,pos,color)
static func cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,color: Color,top: float=-1.0) -> MeshInstance3D:
	var shape:=CylinderMesh.new();shape.bottom_radius=radius;shape.top_radius=radius if top<0 else top;shape.height=height;shape.radial_segments=12
	return mesh(parent,shape,pos,color)
static func segment(parent: Node3D,a: Vector3,b: Vector3,radius: float,color: Color) -> MeshInstance3D:
	var node:=cylinder(parent,(a+b)*.5,radius,a.distance_to(b),color)
	var up:=(b-a).normalized();var right:=up.cross(Vector3.FORWARD)
	if right.length()<.01:right=Vector3.RIGHT
	right=right.normalized();node.basis=Basis(right,up,right.cross(up).normalized())
	return node
static func source(id: String) -> Node3D:
	if not scenes.has(id):
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		assert(doc.append_from_file("res://assets/models/garden/"+id+".glb",state)==OK)
		var root:=doc.generate_scene(state)
		var packed:=PackedScene.new();assert(packed.pack(root)==OK)
		scenes[id]=packed;root.free()
	return scenes[id].instantiate()
static func statue(parent: Node3D,pos: Vector3,scale_factor: float=1.) -> Node3D:
	var root:=Node3D.new();parent.add_child(root);root.position=pos;root.scale=Vector3.ONE*scale_factor
	var stone:=Color("637a71");var dark:=Color("344e49")
	cylinder(root,Vector3(0,.12,0),.65,.24,Color("7c8872"))
	box(root,Vector3(0,.36,0),Vector3(.8,.3,.8),dark)
	ellipsoid(root,Vector3(0,1.02,0),Vector3(.8,1.05,.65),stone)
	ellipsoid(root,Vector3(0,1.72,.04),Vector3(.85,.77,.72),stone)
	for side in [-1,1]:
		# Folded, ribbed wings and luminous inset eyes.
		for i in 4:
			var wing:=ellipsoid(root,Vector3(side*(.38+float(i)*.12),1.2-float(i)*.08,-.18),Vector3(.20,.95-float(i)*.13,.35),dark)
			wing.rotation.z=side*-.4
		ellipsoid(root,Vector3(side*.21,1.8,.34),Vector3(.13,.065,.055),Color("78edbe"),1.8)
	for i in 5:
		var x:=(float(i)-2)*.115
		var last:=Vector3(x,1.53,.32)
		for j in range(1,8):
			var t:=float(j)/7.
			var next:=Vector3(x+sin(t*5.+float(i))*.12,1.53-t*.7,.32+sin(t*2.7)*.34)
			segment(root,last,next,.065*(1.-t*.65),stone);last=next
	return root

static func scatter(parent: Node3D, items: Array[Dictionary], color: Color) -> MultiMeshInstance3D:
	var shape:=SphereMesh.new();shape.radius=.5;shape.height=1;shape.radial_segments=8;shape.rings=4
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=shape;mm.instance_count=items.size()
	for i in items.size():
		mm.set_instance_transform(i,Transform3D(items[i].get("basis",Basis.from_scale(items[i].size)),items[i].pos))
		mm.set_instance_color(i,items[i].get("color",color).srgb_to_linear())
	var node:=MultiMeshInstance3D.new();node.multimesh=mm
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.9
	node.material_override=mat;parent.add_child(node)
	return node
