extends Node3D
## PR4 scratch: small grid of hull + splat tiles, rooms, static drops, locked camera.

const SUN := Vector3(-0.76, 0.54, -0.35)

var _world: SplatWorld
var _logged := false


func _ready() -> void:
	_add_sun()
	_world = SplatWorld.new()
	_world.name = "World"
	add_child(_world)
	_world.register_defs(_catalog())
	_paint(_world)
	_world.set_active_rooms([&"OUTSIDE", &"HOUSE_IN"])
	var look := Marker3D.new()
	look.name = "Look"
	look.position = Vector3(2.0, 0.0, 2.0)
	add_child(look)
	var rig := SplatCameraRig.new()
	rig.name = "Rig"
	rig.target = look
	add_child(rig)


func _process(delta: float) -> void:
	if _world == null:
		return
	_world.refresh(0.0, delta)
	if _logged:
		return
	_logged = true
	var hulls := 0
	if _world.get_node_or_null("Hulls"):
		hulls = _world.get_node("Hulls").get_child_count()
	var n := 0
	if _world._batch:
		n = _world._batch.instance_count
	print("grid: cells=%d walkable=%s hulls=%d gaussians=%d" % [
		_world.cells.size(),
		_world.is_walkable(0, Vector2(2, 2)),
		hulls,
		n,
	])


func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.basis = Basis.looking_at(-SUN.normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	add_child(sun)


func _catalog() -> Dictionary:
	var out := {}
	out[&"path"] = _mesh_tile(&"path", Color(0.46, 0.44, 0.40), 0.08, true)
	out[&"plank"] = _mesh_tile(&"plank", Color(0.50, 0.38, 0.26), 0.08, true)
	out[&"wall"] = _mesh_tile(&"wall", Color(0.58, 0.54, 0.48), 1.05, false)
	out[&"grass"] = _splat_tile(&"grass", _tuft(0.16, 0.22), TileDef.CastModel.NONE, 0.18, Color(0.28, 0.36, 0.22))
	out[&"bush"] = _splat_tile(&"bush", _tuft(0.38, 0.55), TileDef.CastModel.BLOB, 0.62, Color(0.30, 0.34, 0.22))
	return out


func _mesh_tile(id: StringName, color: Color, height: float, walkable: bool) -> TileDef:
	var surface := TileSurface.new()
	surface.visible = true
	surface.color = color
	var st := TileState.new()
	st.display_name = String(id)
	st.surface = surface
	st.hull = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, height, 1.0))
	st.walkable = walkable
	st.receive_shadow = true
	st.cast_model = TileDef.CastModel.NONE
	var def := TileDef.new()
	def.id = id
	def.default_state = &"default"
	def.states[&"default"] = st
	return def


func _splat_tile(id: StringName, cloud: SplatCloud, cast: TileDef.CastModel, height: float, ground: Color) -> TileDef:
	var surface := TileSurface.new()
	surface.visible = true
	surface.color = ground
	var st := TileState.new()
	st.display_name = String(id)
	st.cloud = cloud
	st.surface = surface
	st.hull = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.08, 1.0))
	st.walkable = true
	st.receive_shadow = true
	st.cast_model = cast
	st.cast_height_override = height
	var def := TileDef.new()
	def.id = id
	def.default_state = &"default"
	def.states[&"default"] = st
	return def


func _tuft(spread: float, height: float) -> SplatCloud:
	var cloud := SplatCloud.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 7:
		var a := float(i) * TAU / 7.0
		var r := spread * (0.35 + rng.randf() * 0.65)
		var p := Vector3(cos(a) * r, 0.08 + rng.randf() * height, sin(a) * r)
		var col := Color(0.22 + rng.randf() * 0.12, 0.44 + rng.randf() * 0.14, 0.18)
		cloud.add(p, 0.11 + rng.randf() * 0.07, col, 0.84)
	cloud.add(Vector3(0.0, height * 0.55, 0.0), 0.14, Color(0.28, 0.52, 0.22), 0.86)
	cloud.recompute_aabb()
	return cloud


func _paint(world: SplatWorld) -> void:
	for z in range(5):
		for x in range(5):
			var id := &"path"
			if x >= 1 and x <= 3 and z >= 1 and z <= 3:
				id = &"grass"
			if x == 2 and z == 2:
				id = &"bush"
			world.set_cell(0, x, z, id, &"OUTSIDE")
	# North alcove — a second room.
	for x in range(1, 4):
		world.set_cell(0, x, -1, &"plank", &"HOUSE_IN")
	world.set_cell(0, 1, -1, &"wall", &"HOUSE_IN")
	world.set_cell(0, 3, -1, &"wall", &"HOUSE_IN")
