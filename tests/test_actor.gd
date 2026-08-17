extends SceneTree
## Headless smoke: §8 spawn, sealed door, pond/bridge, stair climb, cut-away.
##
##   Godot --path . --headless --script res://tests/test_actor.gd


const Garden := preload("res://demos/shared/garden.gd")

var _failed := 0


func _initialize() -> void:
	_test_map_and_motion()
	if _failed == 0:
		print("test_actor: PASS")
		quit(0)
	else:
		print("test_actor: FAIL (%d)" % _failed)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_failed += 1
	push_error("test_actor: " + msg)


func _test_map_and_motion() -> void:
	var g: Node = Garden.new()
	root.add_child(g)
	g.build()
	for row in g.MAPS[0]:
		_check(String(row).length() == 16, "level-0 row length 16")
	_check(g.world.cells.has(Vector3i(0, 12, 2)), "trunk at (12,2)")
	_check(g.world.cells[Vector3i(0, 12, 2)].def.id == &"trunk", "trunk def")
	_check(not g.world.is_walkable(0, Vector2(11, 9)), "water is not walkable")
	_check(g.world.is_walkable(0, Vector2(12, 9)), "bridge is walkable")
	_check(not g.world.is_walkable(0, Vector2(5, 5)), "cellar door sealed")
	_check(g.get_node_or_null("PondMarker") != null, "pond marker")
	_check(g.get_node_or_null("TrunkMarker") != null, "trunk marker")
	_check(g.world.is_walkable(0, Vector2(8, 11)), "spawn is walkable")
	_check(not g.world.is_walkable(0, Vector2(-1, 5)), "off-map is not walkable")

	var start: Vector3 = g.actor.position
	g.try_move(Vector3(1.2, 0, 0))
	_check(g.actor.position.x > start.x, "moved east on grass")
	g.try_move(Vector3(20.0, 0, 0))
	_check(g.actor.position.x < 15.0, "blocked at border wall")

	g.place(10.0, 8.2, 0)
	g.try_move(Vector3(0, 0, -1.3))
	_check(g.elev > 0.5, "walking north on stairs raises elev (got %.2f)" % g.elev)
	_check(g.current_run != null, "on a stair run")
	g.try_move(Vector3(0, 0, -0.8))
	_check(g.player_level == 1, "left the run onto the level-1 landing")

	g.place(5.0, 4.5, 0)
	_check(g.try_interact() == &"", "E from north of door does nothing")
	_check(not g.world.is_walkable(0, Vector2(5, 5)), "door still sealed from north")

	g.place(5.0, 6.2, 0)
	g.tick(0.0)
	_check(g.hint != null and g.hint.visible and g.hint.text == "Open the door", "WorldHint on door")
	_check(g.try_interact() == &"door", "E from south lawn starts opening")
	var door_cell: SplatWorld.Cell = g.world.cells[Vector3i(0, 5, 5)]
	_check(door_cell.state == &"opening", "door enters opening")
	_check(not g.world.is_walkable(0, Vector2(5, 5)), "SEQUENCE keeps closed walkable")
	g.tick(0.41)
	_check(g.world.cells[Vector3i(0, 5, 5)].state == &"open", "opening.next_state -> open")
	_check(g.world.is_walkable(0, Vector2(5, 5)), "open door is walkable")
	_check(g.door != null and not g.door.enabled, "door interactable disables when open")
	_check(g.hint != null and g.hint.text == "", "WorldHint hidden after door opens")

	g.place(5.0, 3.4, 0)
	_check(g.try_interact() == &"ember", "E in cellar takes ember")
	_check(g.ember_taken, "ember_taken")
	_check(g.ember_item != null and not g.ember_item.enabled, "ember interactable disables")

	_check(g.world.cells.has(Vector3i(1, 10, 5)), "walkway landing at (10,5) L1")
	var walkway: SplatWorld.Cell = g.world.cells[Vector3i(1, 10, 5)]
	var wst: TileState = walkway.def.states[walkway.state]
	_check(wst.cutaway == TileDef.Cutaway.IF_ABOVE, "walkway IF_ABOVE")
	g.place(10.0, 5.5, 0)
	var hull_top: float = g.world.floor_y(1) + wst.hull.position.y
	var under: float = g.world.cutaway_amount(Vector3(10.0, hull_top, 5.5), float(wst.cutaway), hull_top)
	_check(under > 0.85, "under walkway cuts (got %.3f)" % under)
	g.actor.position.y = 0.625
	g.world.set_actor(g.actor.current_cloud(), g.actor.current_xform())
	g.world.refresh(0.0, 0.0)
	var mid: float = g.world.cutaway_amount(Vector3(10.0, hull_top, 5.5), float(wst.cutaway), hull_top)
	_check(mid > 0.85, "mid-height under walkway still cuts (got %.3f)" % mid)
	g.place(10.0, 5.5, 1)
	var on_top: float = g.world.cutaway_amount(Vector3(10.0, hull_top, 5.5), float(wst.cutaway), hull_top)
	_check(on_top < 0.05, "on walkway does not cut (got %.3f)" % on_top)

	_check(g.canopy_cloud != null, "canopy stand-in exists")
	_check(g.canopy_volume != null, "canopy is a SplatVolume")
	_check(g.canopy_volume.def.cutaway == TileDef.Cutaway.IF_OCCLUDES, "canopy IF_OCCLUDES")
	_check(g.canopy_volume.def.kind == SplatVolumeDef.Kind.CANOPY, "canopy kind")
	_check(g.foam_volume != null and g.foam_volume.def.kind == SplatVolumeDef.Kind.ATMOS, "pond ATMOS foam")
	_check(g.pond_field != null and g.pond_field.mode == DistortionField.Mode.HEAT, "pond HEAT field")
	_check(g.world.extra_count() == 0, "no extra-cloud stand-in after PR10")
	var sky_n := 0
	for vol in g.world.volumes:
		if vol.def.kind == SplatVolumeDef.Kind.SKY:
			sky_n += 1
	_check(sky_n == 0, "no SKY volume")
	var min_r := 99.0
	for r in g.canopy_cloud.radii:
		if r < min_r:
			min_r = r
	_check(min_r >= 0.6, "canopy kernels >= 0.6 m (got %.3f)" % min_r)
	g.place(12.0, 2.0, 0)
	var canopy_top: float = g.TRUNK_MARK.y + g.canopy_cloud.aabb.position.y + g.canopy_cloud.aabb.size.y
	var occ: float = g.world.cutaway_amount(
		g.TRUNK_MARK, float(TileDef.Cutaway.IF_OCCLUDES), canopy_top
	)
	_check(occ > 0.85, "same-level canopy IF_OCCLUDES opens (got %.3f)" % occ)

	var hulls0: int = g.world.hull_count()
	var gaussians0: int = g.world.gaussian_count()
	g.place(8.0, 11.0, 0)
	for i in 400:
		var t := float(i) * 0.35
		g.try_move(Vector3(cos(t) * 0.08, 0.0, sin(t) * 0.08))
		g.tick(0.016)
	_check(g.world.hull_count() == hulls0, "walk does not grow hulls (%d -> %d)" % [hulls0, g.world.hull_count()])
	_check(g.world.gaussian_count() == gaussians0, "walk does not grow gaussians (%d -> %d)" % [gaussians0, g.world.gaussian_count()])
	g.free()
