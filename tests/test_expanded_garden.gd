extends SceneTree
var g: Node
var failures := 0
var captures := "/tmp/splite-expanded-validation"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)

func walk_to(x: float,z: float) -> void:
	g.set_walking(true)
	for i in 1200:
		var d:=Vector3(x,0,z)-Vector3(g.actor.position.x,0,g.actor.position.z)
		if d.length()<.025:break
		g.try_move(d.normalized()*minf(d.length(),.04))
		g.tick(.016)
	check(Vector2(g.actor.position.x-x,g.actor.position.z-z).length()<.08,"Route blocked at "+str(g.actor.position)+" toward "+str(Vector2(x,z)))
	g.set_walking(false)
	g.tick(.016)

func shot(id: String) -> void:
	g.cam.snap()
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures+"/"+id+".png")

func run() -> void:
	root.size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(captures)
	g=load("res://demos/garden_expanded/expanded_garden.gd").new()
	root.add_child(g)
	g.build()
	await shot("01-garden")
	var basis: Basis=g.cam.camera.global_basis
	g.actor.position.x+=.2
	g.cam._process(.02)
	check(g.cam.camera.global_basis.is_equal_approx(basis),"Camera pan preserves locked orientation")
	g.actor.position.x-=.2

	walk_to(10,11)
	walk_to(10,6)
	check(g.player_level==1 and is_equal_approx(g.elev,1),"First stair reaches L1")
	await shot("02-walkway")
	walk_to(12,6)
	walk_to(12,3)
	check(g.player_level==2 and is_equal_approx(g.elev,2),"Second stair reaches L2")
	walk_to(10,3)
	walk_to(10,5.8)
	walk_to(2,5.8)
	await shot("03-terrace")
	walk_to(2,2)
	check(g.player_level==3,"Third stair reaches lookout")
	await shot("04-lookout")
	walk_to(2,5.8)
	check(g.player_level==2,"Lookout descends to L2")
	walk_to(10,5.8)
	walk_to(10,3)
	walk_to(12,3)
	walk_to(12,6)
	check(g.player_level==1,"Second stair descends to L1")
	walk_to(10,6)
	walk_to(10,9)
	check(g.player_level==0,"First stair descends to ground")
	walk_to(8,9)
	walk_to(8,6.2)
	walk_to(5,6.2)
	check(not g.world.is_walkable(0,Vector2(5,5)),"Closed door blocks walking")
	check(g.try_interact()==&"door","Door interaction available")
	g.tick(.2)
	check(not g.world.is_walkable(0,Vector2(5,5)),"Opening door still blocks walking")
	check(g.door_hinge.rotation.y<-.2 and g.door_hinge.rotation.y>-1.4,"Door mesh is partway through its swing")
	g.tick(.25)
	check(g.world.is_walkable(0,Vector2(5,5)),"Open door permits walking")
	walk_to(5,4)
	check(g.world.active_rooms.has(&"CELLAR_IN") and not g.world.active_rooms.has(&"OUTSIDE"),"Entering switches rooms")
	check(g.lantern.enabled,"Interior enables lantern")
	await shot("05-cellar")
	check(g.try_interact()==&"ember" and g.ember_taken,"Ember pickup works")
	walk_to(5,6.2)
	check(g.world.active_rooms.has(&"OUTSIDE") and not g.world.active_rooms.has(&"CELLAR_IN"),"Leaving restores outdoors")
	g.clock.time=23
	g.tick(.016)
	check(g.lantern.enabled,"Night enables lantern")
	await shot("06-night")
	check(g.ranger.pose==-1,"Stopped Ranger is idle")
	print("expanded garden: ","PASS" if failures==0 else "FAIL", " (",failures," failures)")
	quit(1 if failures else 0)
