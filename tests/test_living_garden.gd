extends SceneTree
var scene: Node
var g: Node
var failed:=0
var capture_dir:="/tmp/splite-living-validation"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failed+=1;push_error(message)
func shot(name: String) -> void:
	g.cam.snap()
	for i in 8:
		g.tick(1./60.)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir+"/"+name+".png")
func walk_to(target: Vector2) -> void:
	g.set_walking(true)
	for i in 400:
		var d: Vector2=target-Vector2(g.actor.position.x,g.actor.position.z)
		if d.length()<.025:break
		var step:=d.normalized()*minf(.045,d.length())
		g.try_move(Vector3(step.x,0,step.y));g.tick(.016)
	check(Vector2(g.actor.position.x,g.actor.position.z).distance_to(target)<.08,"Walk route blocked toward "+str(target))
	g.set_walking(false);g.tick(.016)
func run() -> void:
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(capture_dir)
	scene=load("res://demos/living_garden/garden.tscn").instantiate();root.add_child(scene);scene.set_process(false);g=scene.garden
	check(g.world.cells.size()>1100,"Expanded play area")
	check(g.creatures.size()==16,"Six rabbits, four birds, six koi")
	var original: Vector3=g.creatures[0].position
	for i in 60:g.tick(.016)
	check(g.creatures[0].position.distance_to(original)>.05,"Rabbit moves peacefully")
	await shot("01-gate")
	# Continuous slopes, including the return downhill.
	g.place(11,16,0);walk_to(Vector2(11,27))
	check(absf(g.actor.position.y-1.3)<.03,"Woodland ridge is 1.3m above the lawn")
	await shot("02-woodland")
	walk_to(Vector2(11,16));check(absf(g.actor.position.y)<.03,"Ramp returns to lawn")
	# BFS through the actual blocked hedge tiles, then walk the entire solution.
	var start:=Vector2i(21,16);var goal:=Vector2i(32,25)
	var queue: Array[Vector2i]=[start];var came: Dictionary={start:start};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		if p==goal:break
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var q: Vector2i=p+d
			if q.x<21 or q.x>33 or q.y<15 or q.y>27 or came.has(q):continue
			if g.world.is_walkable(0,Vector2(q)):came[q]=p;queue.append(q)
	check(came.has(goal),"Maze has a reachable shrine")
	var route: Array[Vector2i]=[];var cursor:=goal
	while cursor!=start and came.has(cursor):route.push_front(cursor);cursor=came[cursor]
	g.place(20,16,0);walk_to(Vector2(start));await shot("03-maze-entrance")
	for point in route:walk_to(Vector2(point))
	check(g.try_interact()==&"shrine" and g.shrine_awake,"Maze shrine can be awakened")
	check(not g.cast_spell(),"Spell cooldown blocks immediate recast")
	await shot("04-shrine-spell")
	g.tick(2.5);check(g.cast_spell(1),"Second spell can be cast after recharge")
	check(g.spell.warp.mode==DistortionField.Mode.BREATHE,"Moonlight bloom uses a different spatial warp")
	check(g.fitted_trees.size()==5,"Five fitted tree placements")
	check(g.tree_stats.garden_pine.max_height_m>8.0,"Landmark pine exceeds eight metres")
	g.place(30,8,0);await shot("05-mirror-pond")
	g.place(24,3,0);await shot("06-climbing-roses")
	var event:=InputEventKey.new();event.physical_keycode=KEY_H;event.pressed=true
	scene._unhandled_key_input(event);check(scene.hud.help_open,"H opens help")
	var before: Vector3=g.actor.position
	var move:=InputEventKey.new();move.physical_keycode=KEY_W;move.pressed=true
	Input.parse_input_event(move);Input.flush_buffered_events();scene._process(.1)
	check(g.actor.position.is_equal_approx(before),"Help blocks movement")
	move=move.duplicate();move.pressed=false;Input.parse_input_event(move);Input.flush_buffered_events()
	await shot("07-help")
	event=event.duplicate();event.physical_keycode=KEY_ESCAPE;scene._unhandled_key_input(event)
	check(not scene.hud.help_open,"Escape closes help")
	event=event.duplicate();event.physical_keycode=KEY_M;scene._unhandled_key_input(event)
	check(scene.hud.map_open,"M unfolds map");await shot("08-map")
	scene.hud.map_open=false
	# Original room transition still hides all the added outdoor content.
	g.world.set_cell_state(0,5,5,&"open");g.place(5,4,0);g.tick(.016)
	check(not g.outdoor_root.visible,"Interior hides outdoor creatures and art")
	g.place(12,16,0);g.tick(.016)
	check(g.outdoor_root.visible,"Outdoor content returns")
	print("living garden: ","PASS" if failed==0 else "FAIL"," failures=",failed," maze steps=",route.size())
	scene.queue_free()
	await process_frame
	preload("res://demos/living_garden/art.gd").scenes.clear()
	preload("res://demos/living_garden/art.gd").materials.clear()
	await process_frame
	quit(1 if failed else 0)
