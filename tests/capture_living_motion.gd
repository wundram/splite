extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	var scene=load("res://demos/living_garden/garden.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	var g=scene.garden
	g.place(30,8,0);g.tick(.016);g.cam.snap()
	for i in 12:await process_frame
	g.cast_spell(1)
	DirAccess.make_dir_recursive_absolute("/tmp/splite-living-motion")
	for i in 60:
		g.tick(1./24.)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/splite-living-motion/%03d.png" % i)
	print("living motion: 60 frames saved")
	quit()
