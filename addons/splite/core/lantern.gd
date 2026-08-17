class_name Lantern
extends Node3D
## Handheld omni + sway. Radial drops are requested by SplatWorld.

@export var energy: float = 2.2
@export var color: Color = Color(1.0, 0.72, 0.38)
@export var omni_range: float = 5.5
@export var sway_amp: float = 0.045
@export var sway_hz: float = 1.35
@export var drop_radius: float = 4.0
@export var enabled: bool = false:
	set(v):
		enabled = v
		if _omni:
			_omni.visible = v

var _omni: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_omni = OmniLight3D.new()
	_omni.name = "Omni"
	_omni.light_color = color
	_omni.light_energy = energy
	_omni.omni_range = omni_range
	_omni.shadow_enabled = false
	_omni.position = Vector3(0.0, 0.72, 0.0)
	_omni.visible = enabled
	add_child(_omni)


func tick(delta: float) -> void:
	_t += delta
	if _omni == null:
		return
	_omni.visible = enabled
	_omni.light_color = color
	_omni.light_energy = energy if enabled else 0.0
	_omni.omni_range = omni_range
	var s := _t * sway_hz * TAU
	_omni.position = Vector3(sin(s) * sway_amp, 0.72, cos(s * 0.85) * sway_amp)


func world_pos() -> Vector3:
	if _omni != null and _omni.is_inside_tree():
		return _omni.global_position
	if is_inside_tree():
		return global_position + Vector3(0.0, 0.72, 0.0)
	return position + Vector3(0.0, 0.72, 0.0)
