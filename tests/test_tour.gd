extends SceneTree
## Tour reel + fitted canopy swap.
##
##   Godot --path . --headless --script res://tests/test_tour.gd


var _failed := 0


func _initialize() -> void:
	_test_beats()
	_test_garden_fit()
	if _failed == 0:
		print("test_tour: PASS")
		quit(0)
	else:
		print("test_tour: FAIL (%d)" % _failed)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_failed += 1
	push_error("test_tour: " + msg)


func _test_beats() -> void:
	var beats: Array[Dictionary] = TourBeats.all()
	var ids: Array[String] = []
	for b in beats:
		ids.append(str(b.id))
	for need in [
		"intro", "parallax", "splat-tiles", "brush", "mesh-surfaces", "hybrid",
		"drop-shadows", "splite", "cutaway", "verticality", "room-outside",
		"room-inside", "door-states", "world-hint", "pond", "distortion",
		"day-night", "end",
	]:
		_check(need in ids, "beat %s" % need)
	_check(ids[0] == "intro", "intro first")
	_check(ids[ids.size() - 1] == "end", "end last")
	_check("tree" in ids, "fitted tree_hero.tres includes beat 18")
	var night: Dictionary
	for b in beats:
		if str(b.id) == "day-night":
			night = b
	_check(night.has("clock") and is_equal_approx(float(night.clock), 23.0), "day-night scrubs to 23")


func _test_garden_fit() -> void:
	var Garden := load("res://demos/shared/garden.gd")
	var g: Node = Garden.new()
	root.add_child(g)
	g.build()
	_check(g.canopy_cloud != null, "canopy cloud")
	_check(g.canopy_cloud.source_id == "tree_hero", "canopy is fitted tree_hero")
	_check(g.canopy_volume.def.kind == SplatVolumeDef.Kind.CANOPY, "still a CANOPY volume")
	g.slide(10.0, 5.5, 0)
	_check(is_equal_approx(g.actor.position.x, 10.0), "slide x")
	_check(is_equal_approx(g.actor.position.z, 5.5), "slide z")
	g.free()
