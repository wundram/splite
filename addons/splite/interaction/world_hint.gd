@tool
class_name WorldHint
extends Node3D
## One Label3D, retargeted to the nearest in-range Interactable.

@export var text: String = "":
	set(v):
		text = v
		if _label:
			_label.text = v
@export var follow: Node3D
@export var offset: Vector3 = Vector3(0, 1.1, 0)
@export var fade_distance: float = 4.0

var _label: Label3D


func _ready() -> void:
	_label = Label3D.new()
	_label.name = "Label"
	_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_label.font_size = 28
	_label.pixel_size = 0.012
	_label.outline_size = 10
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.modulate = Color(1.0, 0.90, 0.55, 1.0)
	_label.shaded = false
	_label.no_depth_test = false
	_label.double_sided = true
	_label.text = text
	add_child(_label)


func retarget(target: Interactable) -> void:
	follow = target
	if target == null or not target.enabled:
		visible = false
		text = ""
		return
	visible = true
	text = target.prompt


func _process(_delta: float) -> void:
	if not visible or follow == null:
		return
	var origin := follow.global_position if follow.is_inside_tree() else follow.position
	global_position = origin + offset
	if _label == null:
		return
	_label.text = text
	if fade_distance <= 0.0 or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := global_position.distance_to(cam.global_position)
	var a := clampf(1.0 - (d - fade_distance) / maxf(fade_distance, 0.001), 0.35, 1.0)
	_label.modulate.a = a
