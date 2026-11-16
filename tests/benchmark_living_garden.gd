extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1200) if "--large" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene=load("res://demos/living_garden/garden.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	var g=scene.garden
	var results: Array[Dictionary]=[]
	for location in [{"name":"woodland","pos":Vector2(11,23)},{"name":"pond and spell","pos":Vector2(30,8)},{"name":"maze","pos":Vector2(21,16)}]:
		g.place(location.pos.x,location.pos.y,0);g.tick(.016);g.cam.snap()
		if location.name=="pond and spell":g.cast_spell()
		for i in 20:g.tick(1./60.);await process_frame
		var samples: Array[float]=[];var previous:=Time.get_ticks_usec()
		for i in 120:
			g.set_walking(true);g.try_move(Vector3(0,0,sin(float(i)*.05)*.015));g.tick(1./60.)
			await process_frame
			var now:=Time.get_ticks_usec();samples.append(float(now-previous)/1000.);previous=now
		var total:=0.
		for value in samples:total+=value
		samples.sort()
		results.append({"view":location.name,"frames":120,"mean_fps":120000./total,"p95_ms":samples[114]})
	var report:={"resolution":[root.size.x,root.size.y],"tree_stats":g.tree_stats,"gpu":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info().string,"hud_and_3d_portrait":true,"results":results}
	FileAccess.open("/tmp/splite-living-benchmark-%d.json" % root.size.x,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("living benchmark: ",JSON.stringify(report))
	quit()
