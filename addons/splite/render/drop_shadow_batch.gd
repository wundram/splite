class_name DropShadowBatch
extends MultiMeshInstance3D
## Projected drop shadows: ground-aligned dark quads. Not a shadow map.

var _static: Array[Dictionary] = []
var _dynamic: Array[Dictionary] = []
var _dyn_mm: MultiMeshInstance3D
var _mat: ShaderMaterial
var _static_dirty := true
var _dyn_dirty := true


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ensure()


func clear_static() -> void:
	_static.clear()
	_static_dirty = true


func clear_dynamic() -> void:
	_dynamic.clear()
	_dyn_dirty = true


func add_static(pos: Vector3, half: Vector2, strength: float, blob: bool) -> void:
	_static.append({"p": pos, "h": half, "s": strength, "b": blob})
	_static_dirty = true


func add_dynamic(pos: Vector3, half: Vector2, strength: float, blob: bool) -> void:
	_dynamic.append({"p": pos, "h": half, "s": strength, "b": blob})
	_dyn_dirty = true


func add_radial(pos: Vector3, half: Vector2, strength: float) -> void:
	add_dynamic(pos, half, clampf(strength, 0.0, 0.55), true)


func commit() -> void:
	_ensure()
	if _static_dirty:
		_upload(multimesh, _static)
		_static_dirty = false
	if _dyn_dirty:
		_upload(_dyn_mm.multimesh, _dynamic)
		_dyn_dirty = false


func _upload(mm: MultiMesh, entries: Array[Dictionary]) -> void:
	mm.instance_count = 0
	if entries.is_empty():
		return
	mm.instance_count = entries.size()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var p: Vector3 = e.p
		var h: Vector2 = e.h
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_custom_data(i, Color(h.x, h.y, e.s, 1.0 if e.b else 0.0))


func _ensure() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://addons/splite/render/drop_shadow.gdshader")
		_mat.render_priority = -1
		material_override = _mat
	if multimesh == null:
		multimesh = _make_mm()
	if _dyn_mm == null:
		_dyn_mm = MultiMeshInstance3D.new()
		_dyn_mm.name = "DynamicDrops"
		_dyn_mm.multimesh = _make_mm()
		_dyn_mm.material_override = _mat
		_dyn_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_dyn_mm)


func _make_mm() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mm.mesh = quad
	return mm
