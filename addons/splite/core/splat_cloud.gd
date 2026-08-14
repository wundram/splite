class_name SplatCloud
extends Resource
## Authored Gaussians. color[] is albedo (flat-lit), never baked radiance.

@export var positions: PackedVector3Array = PackedVector3Array()
@export var radii: PackedFloat32Array = PackedFloat32Array()
@export var colors: PackedColorArray = PackedColorArray()
@export var opacities: PackedFloat32Array = PackedFloat32Array()
## Local bent-normals used as self-shadow. Empty until recompute_aabb().
@export var shadow_vecs: PackedVector3Array = PackedVector3Array()
@export var aabb: AABB = AABB()

# Optional; empty in procedural stand-ins. Importer fills from PLY.
@export var scales: PackedVector3Array = PackedVector3Array()
@export var rotations: PackedVector4Array = PackedVector4Array()
@export var source_id: String = ""


func size() -> int:
	return positions.size()


func add(pos: Vector3, radius: float, color: Color, opacity: float = 0.85) -> void:
	positions.append(pos)
	radii.append(radius)
	colors.append(color)
	opacities.append(opacity)


func recompute_aabb() -> void:
	if positions.is_empty():
		aabb = AABB()
		return
	var lo := positions[0]
	var hi := positions[0]
	for i in positions.size():
		var r := radii[i]
		var p := positions[i]
		lo = lo.min(p - Vector3(r, r, r))
		hi = hi.max(p + Vector3(r, r, r))
	aabb = AABB(lo, hi - lo)
	_fill_shadow_vecs()


func _fill_shadow_vecs() -> void:
	shadow_vecs = PackedVector3Array()
	var c := aabb.get_center()
	for i in positions.size():
		var d: Vector3 = positions[i] - c
		d.y += 0.35
		if d.length_squared() < 0.000001:
			shadow_vecs.append(Vector3.UP)
		else:
			shadow_vecs.append(d.normalized())


func duplicate_cloud() -> SplatCloud:
	var c := SplatCloud.new()
	c.positions = positions.duplicate()
	c.radii = radii.duplicate()
	c.colors = colors.duplicate()
	c.opacities = opacities.duplicate()
	c.shadow_vecs = shadow_vecs.duplicate()
	c.aabb = aabb
	c.scales = scales.duplicate()
	c.rotations = rotations.duplicate()
	c.source_id = source_id
	return c
