class_name ProcCatalog
extends RefCounted
## Procedural stand-ins for CI / early PRs. Not the production style.


static func tile_defs() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	return {
		&"grass_a": _grass(rng, &"grass_a", Color(0.30, 0.38, 0.22), Color(0.32, 0.54, 0.34)),
		&"grass_b": _grass(rng, &"grass_b", Color(0.34, 0.36, 0.18), Color(0.42, 0.56, 0.26)),
		&"grass_c": _grass(rng, &"grass_c", Color(0.36, 0.38, 0.16), Color(0.50, 0.58, 0.22), 0.12),
		&"grass": _grass(rng, &"grass", Color(0.30, 0.38, 0.22), Color(0.36, 0.58, 0.30)),
		&"path": _path(rng),
		&"brush_a": _brush(rng, &"brush_a", Color(0.24, 0.48, 0.28), false),
		&"brush_b": _brush(rng, &"brush_b", Color(0.34, 0.46, 0.20), false),
		&"brush_heavy_a": _brush(rng, &"brush_heavy_a", Color(0.20, 0.40, 0.18), true),
		&"wall": _wall(rng),
		&"stone": _stone(rng),
		&"planks": _planks(rng),
		&"stair": _stair(rng),
		&"trunk": _trunk(rng),
		&"water": _water(),
		&"bridge": _bridge(rng),
		&"flower_a": _flower(rng, &"flower_a", Color(0.82, 0.28, 0.36)),
		&"flower_b": _flower(rng, &"flower_b", Color(0.86, 0.72, 0.22)),
		&"cellar_door": _cellar_door(rng),
	}


static func foam_standin() -> SplatCloud:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var c := SplatCloud.new()
	for i in 8:
		var a := float(i) * TAU / 8.0
		var r := rng.randf_range(0.15, 0.55)
		c.add(Vector3(cos(a) * r, 0.08, sin(a) * r), rng.randf_range(0.10, 0.16), Color(0.75, 0.88, 0.86), 0.55)
	c.recompute_aabb()
	return c


static func canopy_volume_def() -> SplatVolumeDef:
	var d := SplatVolumeDef.new()
	d.id = &"canopy_proc"
	d.cloud = canopy_standin()
	d.kind = SplatVolumeDef.Kind.CANOPY
	d.cutaway = TileDef.Cutaway.IF_OCCLUDES
	d.room = &"OUTSIDE"
	d.cast_model = TileDef.CastModel.BLOB
	d.cast_height = 1.8
	return d


static func foam_volume_def() -> SplatVolumeDef:
	var d := SplatVolumeDef.new()
	d.id = &"pond_foam"
	d.cloud = foam_standin()
	d.kind = SplatVolumeDef.Kind.ATMOS
	d.cutaway = TileDef.Cutaway.NEVER
	d.room = &""
	return d


static func canopy_standin() -> SplatCloud:
	## Large-kernel (≥ 0.6 m) IF_OCCLUDES stand-in. Temporary until PR10 SplatVolume.
	var rng := RandomNumberGenerator.new()
	rng.seed = 48
	var c := SplatCloud.new()
	var leaf := Color(0.22, 0.46, 0.20)
	for i in 12:
		var a := float(i) * TAU / 12.0 + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(0.55, 1.35)
		var pos := Vector3(cos(a) * r, rng.randf_range(1.25, 1.95), sin(a) * r)
		c.add(pos, rng.randf_range(0.62, 0.88), leaf.lightened(rng.randf_range(-0.06, 0.08)), 0.70)
	c.recompute_aabb()
	return c


static func player_splite() -> Splite:
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	var s := Splite.new()
	s.id = &"player"
	s.fps = 10.0
	s.hitbox = AABB(Vector3(-0.18, 0.0, -0.18), Vector3(0.36, 0.72, 0.36))
	s.facing_mode = Splite.Facing.FLIP_Y
	var idle := _figure(rng, 0.0)
	s.clips = {
		&"idle": [idle],
		&"walk": [_figure(rng, 0.10), _figure(rng, 0.0), _figure(rng, -0.10), _figure(rng, 0.0)],
	}
	return s


static func _one_state(
		id: StringName,
		hull: AABB,
		walkable: bool,
		cutaway: TileDef.Cutaway = TileDef.Cutaway.NEVER
) -> TileState:
	var st := TileState.new()
	st.display_name = String(id)
	st.cloud = SplatCloud.new()
	st.hull = hull
	st.walkable = walkable
	st.cutaway = cutaway
	st.next_state = &""
	return st


static func _def(id: StringName, st: TileState) -> TileDef:
	var def := TileDef.new()
	def.id = id
	def.default_state = &"default"
	def.states[&"default"] = st
	return def


static func _blob(
		c: SplatCloud,
		rng: RandomNumberGenerator,
		center: Vector3,
		rad: float,
		color: Color,
		n: int,
		flatten: float,
		rmin: float,
		rmax: float,
		op: float = 0.82
) -> void:
	for _i in n:
		var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if o.length_squared() > 1.0:
			o = o.normalized()
		o.y *= flatten
		c.add(center + o * rad, rng.randf_range(rmin, rmax), color.lightened(rng.randf_range(-0.05, 0.06)), op)
	c.recompute_aabb()


static func _slab(
		c: SplatCloud,
		rng: RandomNumberGenerator,
		y: float,
		color: Color,
		radius: float = 0.31,
		op: float = 0.94
) -> void:
	var offs := [
		Vector3(0, y, 0),
		Vector3(0.22, y, 0.18),
		Vector3(-0.2, y, 0.2),
		Vector3(0.2, y, -0.2),
		Vector3(-0.18, y, -0.18),
	]
	for o in offs:
		c.add(o, radius * rng.randf_range(0.92, 1.05), color.lightened(rng.randf_range(-0.04, 0.05)), op)
	c.recompute_aabb()


static func _grass(rng: RandomNumberGenerator, id: StringName, ground: Color, blade: Color, extra_y: float = 0.04) -> TileDef:
	var st := _one_state(id, AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.08 + extra_y * 0.5, 1)), true)
	st.receive_shadow = true
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = ground
	_slab(st.cloud, rng, extra_y, blade, 0.31, 0.95)
	return _def(id, st)


static func _path(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"path", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.08, 1)), true)
	st.receive_shadow = true
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.42, 0.34, 0.24)
	_slab(st.cloud, rng, 0.04, Color(0.50, 0.40, 0.28), 0.28, 0.9)
	return _def(&"path", st)


static func _brush(rng: RandomNumberGenerator, id: StringName, color: Color, heavy: bool) -> TileDef:
	var h := 0.16 if not heavy else 0.20
	var st := _one_state(id, AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, h, 1)), true)
	st.cast_model = TileDef.CastModel.BLOB
	st.cast_height_override = 0.85 if heavy else 0.45
	st.receive_shadow = true
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.28, 0.36, 0.20)
	_slab(st.cloud, rng, 0.04, Color(0.32, 0.50, 0.26), 0.38, 0.92)
	_blob(st.cloud, rng, Vector3(0, 0.32 if heavy else 0.20, 0), 0.36, color, 10 if heavy else 6, 0.45, 0.14, 0.22, 0.78)
	if heavy:
		_blob(st.cloud, rng, Vector3(0, 0.62, 0), 0.28, color.darkened(0.12), 8, 0.4, 0.13, 0.20, 0.72)
	return _def(id, st)


static func _wall(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"wall", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 1.15, 1)), false, TileDef.Cutaway.IF_ABOVE)
	st.blocks_los = true
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.78, 0.75, 0.70)
	st.cast_model = TileDef.CastModel.HULL
	st.receive_shadow = false
	_slab(st.cloud, rng, 1.16, Color(0.88, 0.85, 0.78), 0.28, 0.7)
	return _def(&"wall", st)


static func _stone(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"stone", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.18, 1)), true, TileDef.Cutaway.IF_ABOVE)
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.56, 0.56, 0.60)
	st.cast_model = TileDef.CastModel.HULL
	st.receive_shadow = true
	_slab(st.cloud, rng, 0.12, Color(0.62, 0.62, 0.66), 0.28, 0.75)
	return _def(&"stone", st)


static func _planks(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"planks", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.10, 1)), true)
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.42, 0.30, 0.22)
	st.receive_shadow = true
	_slab(st.cloud, rng, 0.06, Color(0.50, 0.36, 0.26), 0.26, 0.7)
	return _def(&"planks", st)


static func _stair(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"stair", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.18, 1)), true, TileDef.Cutaway.IF_ABOVE)
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.58, 0.58, 0.62)
	st.cast_model = TileDef.CastModel.HULL
	st.receive_shadow = true
	_slab(st.cloud, rng, 0.10, Color(0.64, 0.64, 0.68), 0.28, 0.75)
	return _def(&"stair", st)


static func _trunk(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"trunk", AABB(Vector3(-0.28, 0.0, -0.28), Vector3(0.56, 0.7, 0.56)), true)
	st.cast_model = TileDef.CastModel.BLOB
	st.cast_height_override = 0.7
	st.receive_shadow = true
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.30, 0.38, 0.22)
	_slab(st.cloud, rng, 0.04, Color(0.36, 0.58, 0.30), 0.38, 0.94)
	_blob(st.cloud, rng, Vector3(0, 0.22, 0), 0.16, Color(0.40, 0.26, 0.16), 7, 0.7, 0.10, 0.15, 0.92)
	return _def(&"trunk", st)


static func _water() -> TileDef:
	var st := _one_state(&"water", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.06, 1)), false)
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.08, 0.18, 0.20)
	st.receive_shadow = true
	st.cutaway = TileDef.Cutaway.NEVER
	st.cloud = null
	return _def(&"water", st)


static func _bridge(rng: RandomNumberGenerator) -> TileDef:
	var st := _one_state(&"bridge", AABB(Vector3(-0.5, 0.04, -0.5), Vector3(1, 0.10, 1)), true)
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.46, 0.32, 0.22)
	st.cast_model = TileDef.CastModel.HULL
	st.receive_shadow = true
	_slab(st.cloud, rng, 0.10, Color(0.52, 0.36, 0.24), 0.24, 0.7)
	return _def(&"bridge", st)


static func _flower(rng: RandomNumberGenerator, id: StringName, petal: Color) -> TileDef:
	var st := _one_state(id, AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.10, 1)), true)
	st.receive_shadow = true
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.30, 0.38, 0.22)
	_slab(st.cloud, rng, 0.04, Color(0.36, 0.54, 0.28), 0.30, 0.92)
	_blob(st.cloud, rng, Vector3(0.08, 0.16, -0.06), 0.12, petal, 4, 0.5, 0.06, 0.10, 0.88)
	return _def(id, st)


static func _door_frame(yaw: float) -> SplatCloud:
	# Same slab + handle; yaw rotates the dark blob about +Y. Seed is fixed
	# so the four SEQUENCE frames share one blob, not four random ones.
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	var c := SplatCloud.new()
	_slab(c, rng, 1.16, Color(0.86, 0.83, 0.76), 0.28, 0.7)
	var b := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var handle := Vector3(0.0, 0.4, 0.42)
	for _i in 4:
		var o := Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
		c.add(b * (handle + o), rng.randf_range(0.07, 0.11), Color(0.16, 0.10, 0.08), 0.8)
	c.recompute_aabb()
	return c


static func _door_state(id: StringName, walkable: bool, yaw: float) -> TileState:
	var st := TileState.new()
	st.display_name = String(id)
	st.hull = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 1.15, 1))
	st.walkable = walkable
	st.cutaway = TileDef.Cutaway.IF_ABOVE
	st.cast_model = TileDef.CastModel.HULL
	st.receive_shadow = false
	st.surface = TileSurface.new()
	st.surface.visible = true
	st.surface.color = Color(0.70, 0.66, 0.60)
	st.cloud = _door_frame(yaw)
	st.next_state = &""
	return st


static func _cellar_door(_rng: RandomNumberGenerator) -> TileDef:
	var closed := _door_state(&"closed", false, 0.0)
	var opening := _door_state(&"opening", false, 0.0)
	opening.enter_mode = 1
	opening.sequence_fps = 10.0
	opening.enter_duration = 0.0
	opening.next_state = &"open"
	opening.sequence = [
		_door_frame(deg_to_rad(0.0)),
		_door_frame(deg_to_rad(25.0)),
		_door_frame(deg_to_rad(52.0)),
		_door_frame(deg_to_rad(80.0)),
	]
	var opened := _door_state(&"open", true, deg_to_rad(80.0))
	var def := TileDef.new()
	def.id = &"cellar_door"
	def.default_state = &"closed"
	def.tags = PackedStringArray(["door"])
	def.states[&"closed"] = closed
	def.states[&"opening"] = opening
	def.states[&"open"] = opened
	return def


static func _figure(rng: RandomNumberGenerator, swing: float) -> SplatCloud:
	var c := SplatCloud.new()
	c.add(Vector3(0, 0.50, 0), 0.28, Color(0.18, 0.40, 0.90), 0.98)
	c.add(Vector3(-0.14, 0.16, swing), 0.13, Color(0.16, 0.14, 0.22), 0.96)
	c.add(Vector3(0.14, 0.16, -swing), 0.13, Color(0.16, 0.14, 0.22), 0.96)
	c.add(Vector3(0, 0.88, 0), 0.22, Color(0.98, 0.84, 0.72), 0.98)
	c.add(Vector3(0, 1.04, 0.02), 0.18, Color(0.34, 0.20, 0.12), 0.96)
	c.recompute_aabb()
	return c
