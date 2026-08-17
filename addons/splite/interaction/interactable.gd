@tool
class_name Interactable
extends Node3D
## Prompt + verb + range. Garden play picks the nearest enabled one.

@export var prompt: String = "Interact"
@export var verb: StringName = &"use"
@export var radius: float = 1.15
@export var require_outside_facing: bool = false
@export var facing_axis: Vector3 = Vector3(0, 0, 1)
@export var enabled: bool = true

signal used(who: Node)


func use(who: Node) -> void:
	if not enabled:
		return
	_apply(who)
	used.emit(who)


func _apply(_who: Node) -> void:
	pass


func is_in_range(who: Node3D) -> bool:
	if not enabled or who == null:
		return false
	var a := who.global_position if who.is_inside_tree() else who.position
	var b := global_position if is_inside_tree() else position
	var d := Vector2(a.x - b.x, a.z - b.z).length()
	if d > radius:
		return false
	if require_outside_facing:
		var axis := Vector3(facing_axis.x, 0.0, facing_axis.z)
		if axis.length_squared() < 0.0001:
			axis = Vector3(0, 0, 1)
		else:
			axis = axis.normalized()
		if (a - b).dot(axis) < 0.2:
			return false
	return true
