extends Node3D
## F3 cut-away cylinder. Demo debug, not a plugin type.

var world: SplatWorld
var shown := false

var _inner: MeshInstance3D
var _outer: MeshInstance3D
var _last_inner := -1.0
var _last_outer := -1.0


func _ready() -> void:
	_inner = _make_cyl(Color(0.25, 0.92, 1.0, 0.16))
	_outer = _make_cyl(Color(1.0, 0.42, 0.18, 0.10))
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			shown = not shown
			visible = shown
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not shown or world == null:
		return
	global_position = world.cut_origin()
	_sync_radii(world.cutaway_inner, world.cutaway_outer)


func _sync_radii(inner: float, outer: float) -> void:
	if is_equal_approx(inner, _last_inner) and is_equal_approx(outer, _last_outer):
		return
	_last_inner = inner
	_last_outer = outer
	(_inner.mesh as CylinderMesh).top_radius = inner
	(_inner.mesh as CylinderMesh).bottom_radius = inner
	(_outer.mesh as CylinderMesh).top_radius = outer
	(_outer.mesh as CylinderMesh).bottom_radius = outer


func _make_cyl(color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.45
	mesh.bottom_radius = 1.45
	mesh.height = 3.2
	mesh.radial_segments = 28
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
