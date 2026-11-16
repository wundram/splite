extends SceneTree
## Real GPU render check: a thin rotated Gaussian must stay thin and rotated.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(512, 512)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 0, 3)
	camera.look_at(Vector3.ZERO)
	camera.fov = 45.0
	camera.current = true
	var batch = load("res://addons/splite/render/fitted_splat_batch.gd").new()
	scene.add_child(batch)
	batch.saturate = 1.0
	batch.lift = 0.0
	batch.set_lighting(Vector3.UP, Color.WHITE, 0.0, Color.WHITE, 1.0)
	var cloud := SplatCloud.new()
	cloud.add(Vector3.ZERO, 0.3, Color(0.8, 0.4, 0.2), 0.9)
	cloud.scales.append(Vector3(0.3, 0.03, 0.03))
	var q := Quaternion(Vector3.FORWARD, PI / 4.0)
	cloud.rotations.append(Vector4(q.x, q.y, q.z, q.w))
	cloud.recompute_aabb()
	batch.add_static_cloud(cloud, Transform3D.IDENTITY)
	batch.commit()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var points: Array[Vector2] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).r > 0.15: points.append(Vector2(x,y))
	assert(points.size()>50, "No Gaussian pixels rendered")
	var mean := Vector2.ZERO
	for p in points:mean += p
	mean /= points.size()
	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for p in points:
		var d := p-mean
		xx += d.x*d.x
		yy += d.y*d.y
		xy += d.x*d.y
	var spread := sqrt((xx-yy)*(xx-yy)+4.0*xy*xy)
	var ratio := (xx+yy+spread)/maxf(xx+yy-spread,0.0001)
	assert(ratio > 25.0, "Anisotropy lost")
	assert(absf(xy)/maxf(xx,0.001)>0.7, "Gaussian rotation lost")
	image.save_png("/tmp/splite-fitted-renderer-smoke.png")
	print("fitted_renderer_smoke: PASS ratio=", ratio, " pixels=", points.size())
	quit()
