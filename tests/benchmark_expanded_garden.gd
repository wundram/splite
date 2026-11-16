extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1200) if "--large" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene=load("res://demos/garden_expanded/garden.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var g=scene.garden
	for i in 30:await process_frame
	var route: Array[Vector2]=[Vector2(10,11),Vector2(10,6),Vector2(12,6),Vector2(12,3)]
	var target:=0
	var samples: Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in 360:
		var d: Vector2=route[target]-Vector2(g.actor.position.x,g.actor.position.z)
		if d.length()<.06:
			target=mini(target+1,route.size()-1)
		g.set_walking(d.length()>.02)
		var step:=d.normalized()*minf(d.length(),.05)
		g.try_move(Vector3(step.x,0,step.y))
		g.tick(1.0/60.0)
		await process_frame
		var now:=Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		previous=now
	var total:=0.0
	for s in samples:total+=s
	samples.sort()
	var report: Dictionary={"frames":360,"resolution":[root.size.x,root.size.y],"mean_fps":360000.0/total,"mean_ms":total/360,"p95_ms":samples[342],"gpu":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info().string,"final_level":g.player_level,"scenario":"moving fitted Ranger, follow camera, ascending two flights, source shadows, 2 fitted trees"}
	FileAccess.open("/tmp/splite-expanded-benchmark-%d.json" % root.size.x,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("expanded benchmark: ",JSON.stringify(report))
	quit()
