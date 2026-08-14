@tool
class_name SplatBatch
extends MultiMeshInstance3D
## v0 splat rasterizer: camera-facing Gaussian quads.
## Static tiles live on this MultiMesh; actors on a child mesh so we
## do not rebuild the world every frame.

const AFTERNOON_SUN := Vector3(-0.76, 0.54, -0.35)

@export var softness: float = 3.6:
	set(v):
		softness = v
		_apply_style()
@export var saturate: float = 1.08:
	set(v):
		saturate = v
		_apply_style()
@export var lift: float = 0.02:
	set(v):
		lift = v
		_apply_style()

## Static + dynamic Gaussian count after the last commit().
var instance_count: int = 0

var _static: Array[Dictionary] = []
var _dynamic: Array[Dictionary] = []
var _mat: ShaderMaterial
var _dyn_mm: MultiMeshInstance3D
var _static_dirty := true
var _dyn_dirty := true
var _static_n := 0
var _dyn_n := 0

var _light_dir: Vector3 = AFTERNOON_SUN.normalized()
var _light_color: Color = Color(1.0, 0.78, 0.52)
var _light_energy: float = 1.35
var _ambient_color: Color = Color(0.55, 0.50, 0.48)
var _ambient_energy: float = 0.28
var _lantern_pos: Vector3 = Vector3.ZERO
var _lantern_color: Color = Color(1.0, 0.72, 0.38)
var _lantern_energy: float = 0.0
var _lantern_range: float = 5.5


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ensure_meshes()
	_apply_style()
	_apply_lighting()


func clear_static() -> void:
	_static.clear()
	_static_dirty = true


func clear_dynamic() -> void:
	_dynamic.clear()
	_dyn_dirty = true


func add_static_cloud(cloud: SplatCloud, xform: Transform3D, modulate: Color = Color.WHITE, policy: float = 0.0, hull_top: float = 0.0) -> void:
	if cloud == null or cloud.size() == 0:
		return
	_static.append({"cloud": cloud, "xform": xform, "mod": modulate, "policy": policy, "top": hull_top})
	_static_dirty = true


func add_dynamic_cloud(cloud: SplatCloud, xform: Transform3D, modulate: Color = Color.WHITE, policy: float = 0.0, hull_top: float = 0.0) -> void:
	if cloud == null or cloud.size() == 0:
		return
	_dynamic.append({"cloud": cloud, "xform": xform, "mod": modulate, "policy": policy, "top": hull_top})
	_dyn_dirty = true


func set_cutaway(origin: Vector3, inner: float = 1.45, outer: float = 2.90) -> void:
	_ensure_meshes()
	if _mat == null:
		return
	_mat.set_shader_parameter("cut_origin", origin)
	_mat.set_shader_parameter("cut_inner", inner)
	_mat.set_shader_parameter("cut_outer", outer)


func set_lighting(
		dir: Vector3,
		color: Color,
		energy: float,
		ambient_color: Color,
		ambient_energy: float,
		lantern_pos: Vector3 = Vector3.ZERO,
		lantern_color: Color = Color(1.0, 0.72, 0.38),
		lantern_energy: float = 0.0,
		lantern_range: float = 5.5
) -> void:
	_light_dir = dir.normalized()
	_light_color = color
	_light_energy = energy
	_ambient_color = ambient_color
	_ambient_energy = ambient_energy
	_lantern_pos = lantern_pos
	_lantern_color = lantern_color
	_lantern_energy = lantern_energy
	_lantern_range = lantern_range
	_apply_lighting()


func commit() -> void:
	_ensure_meshes()
	if _static_dirty:
		_static_n = _upload(multimesh, _static)
		_static_dirty = false
	if _dyn_dirty:
		_dyn_n = _upload(_dyn_mm.multimesh, _sorted_dynamic())
		_dyn_dirty = false
	instance_count = _static_n + _dyn_n


func _process(_delta: float) -> void:
	if _static_dirty or _dyn_dirty:
		commit()


static func oct_encode(n: Vector3) -> Vector2:
	if n.length_squared() < 0.000001:
		n = Vector3.UP
	n = n.normalized()
	var denom := absf(n.x) + absf(n.y) + absf(n.z)
	var p := Vector2(n.x / denom, n.y / denom)
	if n.z < 0.0:
		p = Vector2(
			(1.0 - absf(p.y)) * (1.0 if p.x >= 0.0 else -1.0),
			(1.0 - absf(p.x)) * (1.0 if p.y >= 0.0 else -1.0)
		)
	return p * 0.5 + Vector2(0.5, 0.5)


func _sorted_dynamic() -> Array[Dictionary]:
	if _dynamic.size() <= 1 or not is_inside_tree():
		return _dynamic
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return _dynamic
	var origin := cam.global_transform.origin
	var ray := -cam.global_transform.basis.z
	var order: Array[Dictionary] = _dynamic.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector3 = (a.xform as Transform3D) * (a.cloud as SplatCloud).aabb.get_center()
		var cb: Vector3 = (b.xform as Transform3D) * (b.cloud as SplatCloud).aabb.get_center()
		return (ca - origin).dot(ray) > (cb - origin).dot(ray)
	)
	return order


func _upload(mm: MultiMesh, entries: Array[Dictionary]) -> int:
	var total := 0
	for e in entries:
		total += (e.cloud as SplatCloud).size()
	mm.instance_count = 0
	if total == 0:
		return 0
	mm.instance_count = total
	var ident := Basis.IDENTITY
	var n := 0
	for e in entries:
		var cloud: SplatCloud = e.cloud
		var xf: Transform3D = e.xform
		var mod: Color = e.mod
		var scale: float = xf.basis.get_scale().x
		var policy: float = float(e.get("policy", 0.0))
		var top: float = float(e.get("top", 0.0))
		var packed := policy + fposmod(top / 8.0, 1.0)
		var has_sv := cloud.shadow_vecs.size() == cloud.size()
		var basis := xf.basis
		for i in cloud.size():
			var col: Color = cloud.colors[i]
			var albedo := Color(col.r * mod.r, col.g * mod.g, col.b * mod.b, cloud.opacities[i] * mod.a)
			var sv := Vector3.UP
			if has_sv:
				var raw: Vector3 = cloud.shadow_vecs[i]
				if raw.length_squared() > 0.0001:
					sv = (basis * raw).normalized()
			var oct := oct_encode(sv)
			mm.set_instance_transform(n, Transform3D(ident, xf * cloud.positions[i]))
			mm.set_instance_color(n, albedo)
			mm.set_instance_custom_data(n, Color(cloud.radii[i] * scale, oct.x, oct.y, packed))
			n += 1
	return total


func _ensure_meshes() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://addons/splite/render/gaussian.gdshader")
		_mat.render_priority = 0
		_apply_style()
		_apply_lighting()
	if multimesh == null:
		multimesh = _make_mm()
	material_override = _mat
	if _dyn_mm == null:
		_dyn_mm = MultiMeshInstance3D.new()
		_dyn_mm.name = "Dynamic"
		_dyn_mm.multimesh = _make_mm()
		_dyn_mm.material_override = _mat
		_dyn_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_dyn_mm)


func _make_mm() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mm.mesh = quad
	return mm


func _apply_style() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("softness", softness)
	_mat.set_shader_parameter("saturate", saturate)
	_mat.set_shader_parameter("lift", lift)


func _apply_lighting() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("light_dir", _light_dir)
	_mat.set_shader_parameter("light_color", Vector3(_light_color.r, _light_color.g, _light_color.b))
	_mat.set_shader_parameter("light_energy", _light_energy)
	_mat.set_shader_parameter("ambient_color", Vector3(_ambient_color.r, _ambient_color.g, _ambient_color.b))
	_mat.set_shader_parameter("ambient_energy", _ambient_energy)
	_mat.set_shader_parameter("lantern_pos", _lantern_pos)
	_mat.set_shader_parameter("lantern_color", Vector3(_lantern_color.r, _lantern_color.g, _lantern_color.b))
	_mat.set_shader_parameter("lantern_energy", _lantern_energy)
	_mat.set_shader_parameter("lantern_range", _lantern_range)
