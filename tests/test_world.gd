extends SceneTree
## Headless smoke for SplatWorld cells, rooms, walk, and state clocks.
##
##   Godot --path . --headless --script res://tests/test_world.gd


var _failed := 0


func _initialize() -> void:
	_test_grid()
	_test_state_clock()
	_test_camera_offset()
	_test_cutaway()
	if _failed == 0:
		print("test_world: PASS")
		quit(0)
	else:
		print("test_world: FAIL (%d)" % _failed)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_failed += 1
	push_error("test_world: " + msg)


func _one_state(id: StringName, walkable: bool, height: float = 0.2) -> TileDef:
	var st := TileState.new()
	st.display_name = String(id)
	st.walkable = walkable
	st.hull = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, height, 1.0))
	var def := TileDef.new()
	def.id = id
	def.default_state = &"default"
	def.states[&"default"] = st
	return def


func _test_grid() -> void:
	var world := SplatWorld.new()
	root.add_child(world)
	world.register_defs({
		&"grass": _one_state(&"grass", true),
		&"wall": _one_state(&"wall", false, 1.0),
	})
	world.set_cell(0, 1, 2, &"grass", &"OUTSIDE")
	world.set_cell(0, 3, 2, &"wall", &"HOUSE_IN")
	_check(world.is_walkable(0, Vector2(1, 2)), "grass is walkable")
	_check(not world.is_walkable(0, Vector2(3, 2)), "wall is not walkable")
	_check(not world.is_walkable(0, Vector2(0, 0)), "empty cell is not walkable")
	_check(world.room_at(0, Vector2(1, 2)) == &"OUTSIDE", "grass room")
	_check(world.room_at(0, Vector2(3, 2)) == &"HOUSE_IN", "wall room")
	_check(is_equal_approx(world.floor_y(2), 2.5), "level_height 1.25")
	_check(world.cell_origin(1, 3, 4) == Vector3(3, 1.25, 4), "cell origin")
	world.set_active_rooms([&"OUTSIDE"])
	_check(world.active_rooms.has(&"OUTSIDE"), "OUTSIDE active")
	_check(not world.active_rooms.has(&"HOUSE_IN"), "HOUSE_IN inactive")
	world.free()


func _test_state_clock() -> void:
	var opening := TileState.new()
	opening.enter_mode = 1
	opening.sequence_fps = 10.0
	opening.enter_duration = 0.0
	opening.next_state = &"open"
	opening.walkable = false
	opening.sequence = [SplatCloud.new(), SplatCloud.new(), SplatCloud.new(), SplatCloud.new()]
	var opened := TileState.new()
	opened.walkable = true
	opened.next_state = &""
	var closed := TileState.new()
	closed.walkable = false
	var def := TileDef.new()
	def.id = &"door"
	def.default_state = &"closed"
	def.states[&"closed"] = closed
	def.states[&"opening"] = opening
	def.states[&"open"] = opened

	var world := SplatWorld.new()
	root.add_child(world)
	world.register_defs({&"door": def})
	world.set_cell(0, 0, 0, &"door", &"OUTSIDE")
	_check(not world.is_walkable(0, Vector2.ZERO), "closed door blocks")
	world.set_cell_state(0, 0, 0, &"opening")
	_check(not world.is_walkable(0, Vector2.ZERO), "SEQUENCE keeps from walkable")
	# 4 frames at 10 fps = 0.40s
	world.refresh(0.0, 0.41)
	var cell: SplatWorld.Cell = world.cells[Vector3i(0, 0, 0)]
	_check(cell.state == &"open", "opening.next_state -> open")
	_check(world.is_walkable(0, Vector2.ZERO), "open door is walkable")
	world.free()


func _test_camera_offset() -> void:
	var rig := SplatCameraRig.new()
	var off := rig.offset()
	_check(is_equal_approx(off.x, -0.82), "west is -X")
	_check(is_equal_approx(off.y, 6.6), "height 6.6")
	_check(is_equal_approx(off.z, 0.82), "south is +Z")
	var tilt := rad_to_deg(atan(Vector2(off.x, off.z).length() / off.y))
	_check(tilt > 8.0 and tilt < 12.0, "tilt ~10° (got %.2f)" % tilt)
	rig.free()


func _test_cutaway() -> void:
	var world := SplatWorld.new()
	root.add_child(world)
	var empty := SplatCloud.new()
	world.set_actor(empty, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	world.refresh(0.0, 0.0)
	_check(world.cut_origin().is_equal_approx(Vector3(0.0, 0.72, 0.0)), "delta 0 snaps to head")

	world.set_actor(empty, Transform3D(Basis.IDENTITY, Vector3(8.0, 1.25, 3.0)))
	world.refresh(0.0, 1.0 / 60.0)
	var o := world.cut_origin()
	var a := 1.0 - exp(-14.0 / 60.0)
	_check(absf(o.x - 8.0 * a) < 0.05, "xz follows at ~14 Hz (got %.3f, want %.3f)" % [o.x, 8.0 * a])
	_check(absf(o.z - 3.0 * a) < 0.05, "z follows at ~14 Hz (got %.3f)" % o.z)
	_check(is_equal_approx(o.y, 1.97), "Y tracks head immediately (got %.3f)" % o.y)

	world.refresh(0.0, 0.0)
	_check(world.cut_origin().is_equal_approx(Vector3(8.0, 1.97, 3.0)), "delta 0 snaps after teleport")

	_check(is_equal_approx(world.cutaway_amount(Vector3(8, 2, 3), 0.0, 3.0), 0.0), "NEVER is 0")
	world.cutaway_enabled = false
	_check(is_equal_approx(world.cutaway_amount(Vector3(8, 2, 3), 1.0, 4.0), 0.0), "disabled is 0")
	world.cutaway_enabled = true

	var canopy := SplatCloud.new()
	canopy.add(Vector3(0, 1.6, 0), 0.65, Color(0.2, 0.5, 0.2), 0.7)
	canopy.recompute_aabb()
	world.add_extra_cloud(canopy, Transform3D.IDENTITY, float(TileDef.Cutaway.IF_OCCLUDES), 2.4)
	_check(world.extra_count() == 1, "extra cloud stored")
	world.clear_extra_clouds()
	_check(world.extra_count() == 0, "extras cleared")
	world.free()
