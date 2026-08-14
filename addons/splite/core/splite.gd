class_name Splite
extends Resource
## A sprite whose frames are SplatClouds.

enum Facing { FLIP_Y, FOUR_DIR, EIGHT_DIR }

@export var id: StringName = &""
@export var fps: float = 10.0
@export var hitbox: AABB = AABB(Vector3(-0.18, 0.0, -0.18), Vector3(0.36, 0.72, 0.36))
@export var shadow_hull: AABB = AABB(Vector3(-0.22, 0.0, -0.18), Vector3(0.44, 0.04, 0.36))
@export var cast_model: TileDef.CastModel = TileDef.CastModel.BLOB
@export var receive_shadow: bool = false
@export var cast_height: float = 0.72
@export var facing_mode: Facing = Facing.FLIP_Y
## clip name -> Array[SplatCloud]
@export var clips: Dictionary = {}
## clip name -> AABB; missing keys use hitbox
@export var clip_hitboxes: Dictionary = {}


func frame_count(clip: StringName = &"idle") -> int:
	var frames: Array = clips.get(clip, [])
	return frames.size()


func frame(clip: StringName, index: int) -> SplatCloud:
	var frames: Array = clips.get(clip, [])
	if frames.is_empty():
		return null
	return frames[index % frames.size()]


func hitbox_for(clip: StringName) -> AABB:
	if clip_hitboxes.has(clip):
		return clip_hitboxes[clip]
	return hitbox
