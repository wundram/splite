class_name TileDef
extends Resource

enum Cutaway { NEVER, IF_ABOVE, IF_OCCLUDES }
enum CastModel { NONE, HULL, BLOB }

@export var id: StringName = &""
@export var default_state: StringName = &"default"
@export var states: Dictionary[StringName, TileState] = {}
@export var tags: PackedStringArray = []
