@tool
class_name DistortionField
extends Node3D
## World-space warp applied to nearby Gaussians.

enum Mode { SWIRL, BREATHE, HEAT }

@export var mode: Mode = Mode.SWIRL
@export var radius: float = 1.6
@export var strength: float = 0.35
@export var rate: float = 1.2


func origin() -> Vector3:
	return global_position if is_inside_tree() else position


func displace(world_pos: Vector3, time: float) -> Vector3:
	var o := origin()
	var d := world_pos - o
	var dist := Vector3(d.x, 0.0, d.z).length()
	if dist > radius or radius <= 0.0001:
		return world_pos
	var t := 1.0 - dist / radius
	t *= t
	match mode:
		Mode.SWIRL:
			var ang := strength * t * sin(time * rate)
			var ca := cos(ang)
			var sa := sin(ang)
			return Vector3(o.x + d.x * ca - d.z * sa, world_pos.y, o.z + d.x * sa + d.z * ca)
		Mode.BREATHE:
			var s := 1.0 + strength * t * sin(time * rate)
			return Vector3(o.x + d.x * s, world_pos.y, o.z + d.z * s)
		Mode.HEAT:
			var wob := strength * t * 0.15
			return world_pos + Vector3(
				sin(time * 7.0 + world_pos.z * 8.0) * wob,
				0.0,
				cos(time * 6.0 + world_pos.x * 8.0) * wob
			)
	return world_pos
