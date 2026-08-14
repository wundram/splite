extends Node3D
## PR3 scratch: one cloud over a mesh slab, one drop. Mesh occludes the cloud.

const SUN := Vector3(-0.76, 0.54, -0.35)
const CAM_HEIGHT := 6.6
const CAM_WEST := 0.82
const CAM_SOUTH := 0.82
const CAM_FOV := 60.0


func _ready() -> void:
	_add_sun()
	_add_camera()
	var surface := _surface_material()
	_add_slab(surface)
	_add_crate(surface)
	var cloud := _make_cloud()
	var batch := SplatBatch.new()
	batch.name = "Batch"
	add_child(batch)
	batch.add_static_cloud(cloud, Transform3D.IDENTITY)
	batch.commit()
	var drops := DropShadowBatch.new()
	drops.name = "Drops"
	add_child(drops)
	drops.add_static(Vector3(0.05, 0.004, 0.28), Vector2(0.38, 0.30), 0.48, true)
	drops.commit()
	print("one_cloud: instance_count=%d" % batch.instance_count)


func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var toward := SUN.normalized()
	sun.basis = Basis.looking_at(-toward, Vector3.UP)
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	add_child(sun)


func _add_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = CAM_FOV
	cam.near = 0.20
	cam.far = 40.0
	cam.current = true
	# SW of origin; world -Z is north / screen-up.
	cam.position = Vector3(-CAM_WEST, CAM_HEIGHT, CAM_SOUTH)
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))


func _surface_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/splite/render/surface.gdshader")
	mat.set_shader_parameter("roughness", 0.88)
	return mat


func _add_slab(mat: ShaderMaterial) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Slab"
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 0.08, 2.6)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.04, 0.0)
	mi.material_override = mat
	mi.set_instance_shader_parameter("albedo", Color(0.40, 0.39, 0.38, 1.0))
	mi.set_instance_shader_parameter("cut_policy", 0.0)
	mi.set_instance_shader_parameter("hull_top", 0.0)
	add_child(mi)


func _add_crate(mat: ShaderMaterial) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Crate"
	var box := BoxMesh.new()
	box.size = Vector3(0.56, 0.50, 0.56)
	mi.mesh = box
	mi.position = Vector3(0.02, 0.25, -0.04)
	mi.material_override = mat
	mi.set_instance_shader_parameter("albedo", Color(0.66, 0.58, 0.46, 1.0))
	mi.set_instance_shader_parameter("cut_policy", 0.0)
	mi.set_instance_shader_parameter("hull_top", 0.0)
	add_child(mi)


func _make_cloud() -> SplatCloud:
	var cloud := SplatCloud.new()
	# Mound around the crate. Several kernels overlap the crate volume so a
	# missing depth test would stain the crate top green.
	var specs: Array = [
		[Vector3(-0.38, 0.16, 0.22), 0.20, Color(0.28, 0.50, 0.22)],
		[Vector3(0.34, 0.14, 0.26), 0.18, Color(0.22, 0.46, 0.18)],
		[Vector3(-0.22, 0.22, -0.36), 0.17, Color(0.30, 0.52, 0.24)],
		[Vector3(0.30, 0.18, -0.32), 0.16, Color(0.24, 0.48, 0.20)],
		[Vector3(0.00, 0.38, 0.00), 0.22, Color(0.26, 0.54, 0.22)],
		[Vector3(0.08, 0.28, 0.10), 0.18, Color(0.20, 0.44, 0.16)],
		[Vector3(-0.10, 0.12, 0.06), 0.15, Color(0.32, 0.48, 0.20)],
		[Vector3(0.16, 0.10, -0.08), 0.14, Color(0.18, 0.40, 0.16)],
		[Vector3(-0.04, 0.48, -0.06), 0.14, Color(0.34, 0.56, 0.26)],
		[Vector3(0.00, 0.08, 0.42), 0.16, Color(0.24, 0.46, 0.18)],
		[Vector3(-0.42, 0.14, -0.08), 0.15, Color(0.28, 0.50, 0.20)],
		[Vector3(0.44, 0.16, 0.04), 0.15, Color(0.22, 0.44, 0.18)],
	]
	for s in specs:
		cloud.add(s[0], s[1], s[2], 0.84)
	cloud.recompute_aabb()
	return cloud
