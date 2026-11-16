extends SceneTree
## Render a fitted cloud through an exact capture camera for image comparison.
## -- --cloud=...tres --transforms=...json --frame=0 --size=256 --capture=...png

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	assert(args.has("cloud") and args.has("transforms") and args.has("capture"))
	var size := int(args.get("size","256"))
	root.size=Vector2i(size,size)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var scene := Node3D.new()
	root.add_child(scene)
	var tf = JSON.parse_string(FileAccess.get_file_as_string(args.transforms))
	var matrix = tf.frames[int(args.get("frame","0"))].transform_matrix
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.transform=Transform3D(Basis(
		Vector3(matrix[0][0],matrix[1][0],matrix[2][0]),
		Vector3(matrix[0][1],matrix[1][1],matrix[2][1]),
		Vector3(matrix[0][2],matrix[1][2],matrix[2][2])),
		Vector3(matrix[0][3],matrix[1][3],matrix[2][3]))
	camera.fov=rad_to_deg(float(tf.camera_angle_x))
	camera.current=true
	var batch = load("res://addons/splite/render/fitted_splat_batch.gd").new()
	scene.add_child(batch)
	batch.saturate=1.0
	batch.lift=0.0
	batch.set_lighting(Vector3.UP,Color.WHITE,0.0,Color.WHITE,1.0)
	var cloud = load(args.cloud)
	assert(cloud != null and cloud.size()>0)
	batch.add_static_cloud(cloud,Transform3D.IDENTITY)
	batch.commit()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(args.capture)
	assert(result==OK)
	print("render_fitted_capture: ",cloud.size()," Gaussians -> ",args.capture)
	quit()
