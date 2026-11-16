class_name FittedSplatBatch
extends SplatBatch
## Reference path for trained ellipsoids. Sorts each Gaussian back-to-front.
## Separate from procedural world batches until source/runtime parity is accepted.

var _last_camera := Transform3D.IDENTITY
var _last_global := Transform3D.IDENTITY
@export var scene_lighting := false:
	set(value):
		scene_lighting=value
		if _mat != null:_mat.set_shader_parameter("scene_lighting", value)

func _ensure_meshes() -> void:
	super._ensure_meshes()
	_mat.shader = load("res://addons/splite/render/fitted_gaussian.gdshader")
	_mat.set_shader_parameter("scene_lighting",scene_lighting)

func _process(delta: float) -> void:
	if not is_visible_in_tree():return
	var camera := get_viewport().get_camera_3d()
	# Translation adds the same depth offset to every point in this batch.
	# Only a changed basis can alter ordering or transformed normals.
	if camera != null and (not camera.global_basis.is_equal_approx(_last_camera.basis) or not global_basis.is_equal_approx(_last_global.basis)):
		_last_camera = camera.global_transform
		_last_global = global_transform
		_static_dirty = true
		_dyn_dirty = true
	super._process(delta)

func _upload(mm: MultiMesh, entries: Array[Dictionary]) -> int:
	var items: Array[Dictionary] = []
	var camera := get_viewport().get_camera_3d()
	var view := camera.global_transform.affine_inverse() if camera != null else Transform3D.IDENTITY
	var bounds := AABB()
	var first := true
	for entry in entries:
		var cloud: SplatCloud = entry.cloud
		var xf: Transform3D = entry.xform
		var mod: Color = entry.mod
		var policy: float = entry.get("policy", 0.0)
		var top: float = entry.get("top", 0.0)
		var normal_basis := global_transform.basis.inverse().transposed() * xf.basis.inverse().transposed()
		assert(cloud.scales.size() == cloud.size() and cloud.rotations.size() == cloud.size(), "Fitted renderer requires scales and quaternions")
		for i in cloud.size():
			var q: Vector4 = cloud.rotations[i]
			var rotation := Basis(Quaternion(q.x, q.y, q.z, q.w).normalized())
			var sigma: Vector3 = cloud.scales[i]
			var axes := xf.basis * rotation * Basis.from_scale(sigma)
			var center := xf * cloud.positions[i]
			var col: Color = cloud.colors[i].srgb_to_linear()
			col = Color(col.r * mod.r, col.g * mod.g, col.b * mod.b, cloud.opacities[i] * mod.a)
			var normal := Vector3.UP
			if cloud.shadow_vecs.size() == cloud.size():
				normal = (normal_basis * cloud.shadow_vecs[i]).normalized()
			var oct := oct_encode(normal)
			items.append({"transform": Transform3D(axes, center), "color": col,
				"custom": Color(0.0, oct.x, oct.y, policy + fposmod(top / 8.0, 1.0)),
				"depth": (view * (global_transform * center)).z})
			var extent := (axes.x.abs() + axes.y.abs() + axes.z.abs()) * 3.0 + Vector3.ONE * 0.02
			var box := AABB(center - extent, extent * 2.0)
			bounds = box if first else bounds.merge(box)
			first = false
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	mm.instance_count = 0
	mm.instance_count = items.size()
	mm.custom_aabb = bounds
	for i in items.size():
		mm.set_instance_transform(i, items[i].transform)
		mm.set_instance_color(i, items[i].color)
		mm.set_instance_custom_data(i, items[i].custom)
	return items.size()
