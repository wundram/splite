extends SceneTree
## DayClock knots, elevation clamp, lantern night flag.
##
##   Godot --path . --headless --script res://tests/test_clock.gd


var _failed := 0


func _initialize() -> void:
	_test_clock()
	_test_garden_wiring()
	if _failed == 0:
		print("test_clock: PASS")
		quit(0)
	else:
		print("test_clock: FAIL (%d)" % _failed)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_failed += 1
	push_error("test_clock: " + msg)


func _test_clock() -> void:
	var c := DayClock.new()
	root.add_child(c)
	c.time = 16.0
	_check(c.sun_dir().is_equal_approx(DayClock.AFTERNOON_SUN), "16:00 is AFTERNOON_SUN")
	_check(is_equal_approx(c.sun_energy(), 1.35), "16:00 energy 1.35")
	_check(not c.is_night(), "16:00 is day")
	_check(c.phase() == DayClock.Phase.DAY, "16:00 phase DAY")

	c.time = 23.0
	_check(c.is_night(), "23:00 is night")
	_check(c.phase() == DayClock.Phase.NIGHT, "23:00 phase NIGHT")
	_check(c.sun_energy() == 0.0, "night sun energy 0")
	_check(c.moon_energy() > 0.0, "night moon energy")
	_check(c.light_dir().is_equal_approx(c.moon_dir()), "night directional is moon")

	c.time = 5.5
	_check(not c.is_night(), "dawn is not night")
	var el := asin(clampf(c.sun_dir().y, -1.0, 1.0))
	_check(el >= DayClock.EL_MIN - 0.001 and el <= DayClock.EL_MAX + 0.001, "dawn elevation in [8,55]")

	c.time = 12.0
	el = asin(clampf(c.sun_dir().y, -1.0, 1.0))
	_check(el <= DayClock.EL_MAX + 0.001, "noon-ish elevation <= 55 (got %.1f deg)" % rad_to_deg(el))

	c.time = 23.8
	c.scrub(1.0)
	_check(c.time < 1.5, "scrub wraps past 24 (got %.2f)" % c.time)

	c.time = 16.0
	c.paused = true
	c.advance(10.0)
	_check(is_equal_approx(c.time, 16.0), "paused does not advance")
	c.paused = false
	c.day_length_sec = 180.0
	c.advance(180.0)
	_check(is_equal_approx(c.time, 16.0) or absf(c.time - 16.0) < 0.01, "full cycle returns to 16")
	c.free()


func _test_garden_wiring() -> void:
	var Garden := load("res://demos/shared/garden.gd")
	var g: Node = Garden.new()
	root.add_child(g)
	g.build()
	_check(g.clock != null, "garden has DayClock")
	_check(g.lantern != null, "garden has Lantern")
	_check(is_equal_approx(g.clock.time, 16.0), "garden starts 16:00")
	_check(g.clock.paused, "garden clock paused")
	_check(not g.lantern.enabled, "lantern off at 16:00 outside")
	_check(g._env.background_color.is_equal_approx(g.BG), "clock did not write background")
	g.clock.time = 23.0
	g.tick(0.0)
	_check(g.lantern.enabled, "lantern on at night")
	g.clock.time = 16.0
	g.place(5.0, 3.4, 0)
	_check(g.lantern.enabled, "lantern on in cellar by day")
	g.free()
