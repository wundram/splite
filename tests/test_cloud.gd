extends SceneTree
## Headless smoke: 3-Gaussian cloud, aabb/shadow fill, Splite.frame().
##
##   Godot --path . --headless --script res://tests/test_cloud.gd


var _failed := 0


func _initialize() -> void:
	_test_cloud()
	_test_splite()
	_test_tile_resources()
	if _failed == 0:
		print("test_cloud: PASS")
		quit(0)
	else:
		print("test_cloud: FAIL (%d)" % _failed)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_failed += 1
	push_error("test_cloud: " + msg)


func _test_cloud() -> void:
	var cloud := SplatCloud.new()
	cloud.add(Vector3(-0.4, 0.1, 0.0), 0.12, Color(0.22, 0.48, 0.20), 0.82)
	cloud.add(Vector3(0.3, 0.25, 0.1), 0.18, Color(0.18, 0.40, 0.16), 0.78)
	cloud.add(Vector3(0.0, 0.55, -0.2), 0.10, Color(0.30, 0.52, 0.24), 0.90)
	_check(cloud.size() == 3, "cloud.size() == 3")

	cloud.recompute_aabb()
	_check(cloud.aabb.size.length() > 0.0, "aabb has volume")
	for i in cloud.size():
		var p: Vector3 = cloud.positions[i]
		_check(cloud.aabb.has_point(p), "aabb contains gaussian %d" % i)

	_check(cloud.shadow_vecs.size() == 3, "shadow_vecs filled")
	for i in cloud.shadow_vecs.size():
		var n: Vector3 = cloud.shadow_vecs[i]
		_check(is_equal_approx(n.length(), 1.0), "shadow_vec %d is unit" % i)

	var empty := SplatCloud.new()
	empty.recompute_aabb()
	_check(empty.aabb == AABB(), "empty cloud aabb is default")
	_check(empty.shadow_vecs.is_empty(), "empty cloud does not fill shadows")

	var copy := cloud.duplicate_cloud()
	_check(copy.size() == 3, "duplicate keeps 3 gaussians")
	_check(copy.aabb == cloud.aabb, "duplicate keeps aabb")
	copy.positions[0] = Vector3(9, 9, 9)
	_check(cloud.positions[0] != copy.positions[0], "duplicate is a deep copy")


func _test_splite() -> void:
	var a := SplatCloud.new()
	a.add(Vector3.ZERO, 0.1, Color.WHITE)
	a.recompute_aabb()
	var b := a.duplicate_cloud()
	b.positions[0] = Vector3(0, 0.2, 0)
	b.recompute_aabb()

	var splite := Splite.new()
	splite.id = &"walker"
	splite.clips[&"walk"] = [a, b] as Array[SplatCloud]
	_check(splite.frame_count(&"walk") == 2, "walk has 2 frames")
	_check(splite.frame(&"walk", 0) == a, "frame 0")
	_check(splite.frame(&"walk", 1) == b, "frame 1")
	_check(splite.frame(&"walk", 2) == a, "frame wraps")
	_check(splite.frame(&"idle", 0) == null, "missing clip is null")
	_check(splite.facing_mode == Splite.Facing.FLIP_Y, "default facing is FLIP_Y")

	var crouch := AABB(Vector3(-0.12, 0.0, -0.12), Vector3(0.24, 0.40, 0.24))
	splite.clip_hitboxes[&"crouch"] = crouch
	_check(splite.hitbox_for(&"walk") == splite.hitbox, "missing override uses hitbox")
	_check(splite.hitbox_for(&"crouch") == crouch, "clip hitbox override")


func _test_tile_resources() -> void:
	var closed := TileState.new()
	closed.display_name = "Closed"
	closed.next_state = &""
	var opening := TileState.new()
	opening.display_name = "Opening"
	opening.enter_mode = 1
	opening.sequence_fps = 10.0
	opening.enter_duration = 0.0
	opening.next_state = &"open"
	var opened := TileState.new()
	opened.display_name = "Open"
	opened.walkable = true
	opened.next_state = &""

	var door := TileDef.new()
	door.id = &"cellar_door"
	door.default_state = &"closed"
	door.states[&"closed"] = closed
	door.states[&"opening"] = opening
	door.states[&"open"] = opened
	_check(door.states[&"opening"].next_state == &"open", "opening.next_state")
	_check(opening.enter_mode == 1, "SEQUENCE enter_mode")

	var catalog := ProcCatalog.tile_defs()
	var cellar: TileDef = catalog[&"cellar_door"]
	_check(cellar.default_state == &"closed", "catalog door default closed")
	_check(cellar.states.has(&"opening") and cellar.states.has(&"open"), "catalog door graph")
	var seq: Array = cellar.states[&"opening"].sequence
	_check(seq.size() == 4, "four rotated door frames")
	_check(cellar.states[&"opening"].sequence_fps == 10.0, "door 10 fps")
	_check(cellar.states[&"open"].walkable, "open is walkable")
	_check(not cellar.states[&"closed"].walkable, "closed blocks")

	var surface := TileSurface.new()
	_check(surface.visible == false, "surface default hidden")

	var vol := SplatVolumeDef.new()
	vol.id = &"canopy"
	vol.kind = SplatVolumeDef.Kind.CANOPY
	vol.cutaway = TileDef.Cutaway.IF_OCCLUDES
	_check(vol.kind == SplatVolumeDef.Kind.CANOPY, "volume kind")
	_check(vol.cast_model == TileDef.CastModel.NONE, "volume default cast")

	var field := DistortionField.new()
	root.add_child(field)
	field.mode = DistortionField.Mode.HEAT
	field.position = Vector3.ZERO
	field.radius = 2.0
	field.strength = 1.0
	var p0 := Vector3(0.4, 0.1, 0.0)
	var p1 := field.displace(p0, 0.4)
	_check(p1 != p0, "HEAT displaces a nearby point")
	field.mode = DistortionField.Mode.SWIRL
	var p2 := field.displace(p0, 0.8)
	_check(absf(p2.y - p0.y) < 0.0001, "SWIRL keeps Y")
	field.free()
