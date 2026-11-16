extends SceneTree
## Structural checks and deterministic real-renderer walk frames.
func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,800)
	var source := "--source" in OS.get_cmdline_user_args()
	var output := "/tmp/splite-source-walk-frames" if source else "/tmp/splite-walk-frames"
	var scene = load("res://demos/garden_study/garden_study.tscn" if source else "res://demos/garden_study/fitted_garden.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var clip: Splite=scene.ranger_clip
	assert(clip.frame_count(&"walk")==10)
	var idle: SplatCloud=clip.frame(&"idle",0)
	var steps: Array[float]=[]
	for f in 10:
		var cloud: SplatCloud=clip.frame(&"walk",f)
		var next: SplatCloud=clip.frame(&"walk",f+1)
		assert(cloud.size()==3000 and cloud.colors==idle.colors and cloud.opacities==idle.opacities)
		var distance := 0.0
		for i in cloud.size():
			assert(cloud.positions[i].is_finite() and cloud.scales[i].is_finite())
			assert(cloud.scales[i].x>0 and cloud.scales[i].y>0 and cloud.scales[i].z>0)
			assert(absf(cloud.shadow_vecs[i].length()-1.0)<.001)
			distance+=cloud.positions[i].distance_to(next.positions[i])
		steps.append(distance/cloud.size())
	assert(steps.min()>.001, "Walk must move every frame")
	assert(steps[9]<steps.slice(0,9).max()*1.5,"Loop seam must be comparable to ordinary steps")
	DirAccess.make_dir_recursive_absolute(output)
	for f in 10:
		scene.set_walk_pose(f)
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/%02d.png" % f)
	scene.set_walk_pose(-1)
	assert(scene._pose==-1 and scene._walk_proxies.all(func(p):return not p.visible))
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/idle.png")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_W
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var before: Vector3=scene.traveler.position
	scene._process(.15)
	assert(scene._pose==1 and scene.traveler.position.z<before.z)
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	scene._process(.01)
	assert(scene._pose==-1 and scene._clock==0.0)
	var report := {"frames":10,"gaussians_per_frame":3000,"mean_point_step_m":steps,"loop_step_m":steps[9],"checks":"finite geometry, positive scales, unit normals, persistent colors/opacity, loop continuity, WASD movement and idle reset"}
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("validate_ranger_walk: PASS ",JSON.stringify(report))
	quit()
