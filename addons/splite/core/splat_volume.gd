@tool
class_name SplatVolume
extends Node3D
## Placed instance of a SplatVolumeDef. Transform and visibility live here.

@export var def: SplatVolumeDef
@export var room_override: StringName = &""


func world_xform() -> Transform3D:
	return global_transform if is_inside_tree() else Transform3D(Basis.IDENTITY, position)


func world_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func room() -> StringName:
	if room_override != &"":
		return room_override
	if def != null:
		return def.room
	return &""


func cutaway_height() -> float:
	if def == null:
		return 0.0
	if def.cutaway_top >= 0.0:
		return def.cutaway_top
	if def.cloud != null:
		return def.cloud.aabb.position.y + def.cloud.aabb.size.y
	return 0.0
