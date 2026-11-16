extends SceneTree
## Uncapped real GPU benchmark, including moving/turning the fitted Ranger.
func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene = load("res://demos/garden_study/fitted_garden.tscn").instantiate()
	root.add_child(scene)
	for i in 40:await process_frame
	scene.set_process(false)
	var samples: Array[float]=[]
	var previous := Time.get_ticks_usec()
	for i in 240:
		scene.traveler.position.x=sin(float(i)*.025)*.6
		scene.traveler.rotation.y=float(i)*.025
		scene.set_walk_pose(int(float(i)*.025*scene.ranger_clip.fps))
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		previous=now
	var total := 0.0
	for sample in samples:total+=sample
	samples.sort()
	var report := {"frames":samples.size(),"resolution":[1280,800],"moving_character":true,"animated_walk":true,
		"mean_frame_ms":total/samples.size(),"mean_fps":1000.0*samples.size()/total,
		"p95_frame_ms":samples[int(samples.size()*.95)],"gpu":RenderingServer.get_video_adapter_name(),
		"godot":Engine.get_version_info().string}
	FileAccess.open("/tmp/splite-garden-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("benchmark_fitted_garden: ",JSON.stringify(report))
	quit()
