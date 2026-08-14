class_name TileState
extends Resource

@export var display_name: String = ""
@export var cloud: SplatCloud
@export var surface: TileSurface
@export var hull: AABB = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.2, 1.0))
@export var walkable: bool = true
@export var blocks_los: bool = false
@export var cast_model: TileDef.CastModel = TileDef.CastModel.NONE
@export var receive_shadow: bool = true
@export var cast_height_override: float = -1.0
@export var cutaway: TileDef.Cutaway = TileDef.Cutaway.NEVER
@export var cutaway_top: float = -1.0
@export var enter_duration: float = 0.0
@export var enter_mode: int = 0
@export var sequence: Array[SplatCloud] = []
@export var sequence_fps: float = 10.0
@export var next_state: StringName = &""


func cutaway_height() -> float:
	if cutaway_top >= 0.0:
		return cutaway_top
	return hull.position.y + hull.size.y


func cast_height() -> float:
	if cast_height_override >= 0.0:
		return cast_height_override
	return hull.position.y + hull.size.y
