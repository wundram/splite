class_name SplatVolumeDef
extends Resource

enum Kind { PROP, CANOPY, SKY, ATMOS }

@export var id: StringName = &""
@export var cloud: SplatCloud
@export var kind: Kind = Kind.PROP
@export var cutaway: TileDef.Cutaway = TileDef.Cutaway.NEVER
@export var cutaway_top: float = -1.0
@export var cast_model: TileDef.CastModel = TileDef.CastModel.NONE
@export var cast_height: float = 0.0
@export var room: StringName = &""
@export var lod_radius: float = 24.0
