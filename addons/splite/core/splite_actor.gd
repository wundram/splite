@tool
class_name SpliteActor
extends Node3D
## Places a Splite in the world and advances its clip.

@export var splite: Splite
@export var clip: StringName = &"idle"
@export var playing: bool = false

var facing := 1.0
var _time := 0.0


func _process(delta: float) -> void:
	if playing:
		_time += delta
	else:
		_time = 0.0


func current_cloud() -> SplatCloud:
	if splite == null:
		return null
	var use_clip := clip if playing else &"idle"
	if splite.frame_count(use_clip) == 0:
		use_clip = &"idle"
	var fps := maxf(splite.fps, 0.01)
	var idx := int(_time * fps)
	return splite.frame(use_clip, idx)


func current_xform() -> Transform3D:
	var b := Basis.IDENTITY
	if splite == null or splite.facing_mode == Splite.Facing.FLIP_Y:
		if facing < 0.0:
			b = Basis.from_euler(Vector3(0.0, PI, 0.0))
	var origin := global_position if is_inside_tree() else position
	return Transform3D(b, origin)
