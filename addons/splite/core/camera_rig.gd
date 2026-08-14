@tool
class_name SplatCameraRig
extends Node3D
## Locked top-down camera, tilted a few degrees toward SW.

@export var target: Node3D
## Closer than a sim-cam, wider than ortho: height vs FOV is the parallax knob.
@export var height: float = 6.6
@export var south: float = 0.82
@export var west: float = 0.82
@export var fov: float = 60.0
@export var follow_speed: float = 8.0
@export var dof_blur: float = 0.034

var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	camera.near = 0.20
	camera.far = 40.0
	camera.current = true
	add_child(camera)
	_place(true)
	_look()


func _process(delta: float) -> void:
	_place(false, delta)
	_look()
	if camera.attributes == null:
		var focus_d := Vector3(west, height, south).length()
		var attr := CameraAttributesPractical.new()
		attr.dof_blur_far_enabled = true
		attr.dof_blur_far_distance = focus_d + 4.5
		attr.dof_blur_far_transition = 7.0
		attr.dof_blur_near_enabled = true
		attr.dof_blur_near_distance = maxf(focus_d - 3.2, 1.5)
		attr.dof_blur_near_transition = 3.5
		attr.dof_blur_amount = dof_blur
		camera.attributes = attr


func snap() -> void:
	_place(true)
	_look()


func offset() -> Vector3:
	# west is a magnitude; applied on -X so the tilt is SW (K10).
	# World -Z is north / screen-up.
	return Vector3(-west, height, south)


func _place(instant: bool, delta: float = 0.0) -> void:
	var focus := Vector3.ZERO
	if target:
		focus = target.global_position
	var dest := focus + offset()
	if instant or follow_speed <= 0.0:
		global_position = dest
	else:
		global_position = global_position.lerp(dest, 1.0 - exp(-follow_speed * delta))


func _look() -> void:
	if camera == null:
		return
	var focus := Vector3.ZERO
	if target:
		focus = target.global_position
	# World -Z is "north" / screen-up. Using Vector3.UP here is degenerate
	# when the view is nearly vertical and yaws the map 45°.
	camera.look_at(focus, Vector3(0.0, 0.0, -1.0))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	camera.near = 0.20
	camera.far = 40.0
