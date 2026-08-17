extends Node3D
## PR11c scratch: fitted tree_hero next to a proc trunk. Clone-without-CUDA loads .tres.

const SUN := Vector3(-0.76, 0.54, -0.35)


func _ready() -> void:
	_env()
	var batch := SplatBatch.new()
	batch.name = "Batch"
	add_child(batch)
	var fitted: SplatCloud = load("res://assets/clouds/tree_hero.tres")
	if fitted:
		batch.add_static_cloud(fitted, Transform3D(Basis.IDENTITY, Vector3(-1.2, 0, 0)), Color.WHITE, 2.0, 2.2)
	var trunk: TileDef = ProcCatalog.tile_defs()[&"trunk"]
	var st: TileState = trunk.states[trunk.default_state]
	batch.add_static_cloud(st.cloud, Transform3D(Basis.IDENTITY, Vector3(1.2, 0, 0)))
	batch.commit()
	print("fitted_cloud: gaussians=%d fitted=%s" % [batch.instance_count, fitted != null])


func _env() -> void:
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(-SUN.normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 1.35
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60.0
	cam.near = 0.2
	cam.far = 40.0
	cam.current = true
	cam.position = Vector3(-0.82, 6.6, 0.82)
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.016, 0.020)
	we.environment = env
	add_child(we)
