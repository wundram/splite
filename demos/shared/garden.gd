extends Node3D
## Shared garden scaffold. §8 MAPS. No pale environment, no ground plane.

const SUN := Vector3(-0.76, 0.54, -0.35)
const BG := Color(0.015, 0.016, 0.020)
const CELLAR_DOOR := Vector3i(0, 5, 5)
const EMBER_POS := Vector3(5.0, 0.28, 3.4)
const SPAWN := Vector3(8.0, 0.0, 11.0)
const POND_MARK := Vector3(12.0, 0.0, 9.5)
const TRUNK_MARK := Vector3(12.0, 0.0, 2.0)

const STAIRS := [
	{"level": 0, "x": 10, "bot": 8, "top": 7, "exit": "N"},
	{"level": 1, "x": 10, "bot": 8, "top": 7, "exit": "N"},
	{"level": 2, "x": 1, "bot": 4, "top": 3, "exit": "N"},
]

const MAPS := {
	0: [
		"################",
		"#.,;.,__;.,;.,;#",
		"#.wwwwww.,;.t,;#",
		"#.wcTccw.,;;;;.#",
		"#.wccccw._;;;;.#",
		"#.wwwdww._.,;.,#",
		"#....__....,;.,#",
		"#....__...^.,;.#",
		"#.,;.__...^nbn.#",
		"#f,;nbn...,~H~.#",
		"#.,bBBBb..,~H~.#",
		"#f,;bbn...,;.,;#",
		"#.,;.,;..,;F,;.#",
		"################",
	],
	1: [
		"",
		"",
		"",
		"",
		"",
		"          PP",
		"          PP",
		"          ^",
		"          ^",
	],
	2: [
		"",
		"",
		"  Pwwww  PPPPP",
		" ^Pwhhhw PP",
		" ^Pwhhhw",
		"  PPwwww",
		"  PPPPPPP",
	],
	3: [
		"",
		"",
		" LL",
		" LL",
	],
}

var world: SplatWorld
var actor: SpliteActor
var cam: SplatCameraRig
var torch: OmniLight3D
var ember: MeshInstance3D
var door: TileInteractable
var ember_item: Interactable
var hint: WorldHint
var clock: DayClock
var lantern: Lantern
var _sun_node: DirectionalLight3D
var _env: Environment
var player_level := 0
var elev := 0.0
var current_run = null
var ember_taken := false
var canopy_cloud: SplatCloud
var canopy_volume: SplatVolume
var foam_volume: SplatVolume
var pond_field: DistortionField
var _time := 0.0


func build() -> void:
	_add_environment()
	world = SplatWorld.new()
	world.name = "World"
	add_child(world)
	world.register_defs(ProcCatalog.tile_defs())
	_paint()
	for run in STAIRS:
		for z in [run.bot, run.top]:
			world.walk[Vector3i(run.level, run.x, z)] = true
			world.walk[Vector3i(run.level + 1, run.x, z)] = true
	_spawn_door()
	_spawn_ember()
	_add_markers()
	_add_volumes_and_field()
	_spawn_hint()

	actor = SpliteActor.new()
	actor.name = "Player"
	actor.splite = ProcCatalog.player_splite()
	add_child(actor)
	_spawn_clock()

	cam = SplatCameraRig.new()
	cam.name = "Cam"
	cam.target = actor
	add_child(cam)
	place(SPAWN.x, SPAWN.z, 0)
	print("garden: cells=%d gaussians=%d" % [world.cells.size(), world.gaussian_count()])


func place(x: float, z: float, level: int, facing: float = 1.0) -> void:
	player_level = level
	elev = float(level)
	current_run = null
	actor.facing = facing
	actor.position = Vector3(x, world.floor_y(elev), z)
	_update_room()
	if cam:
		cam.snap()
	world.set_actor(actor.current_cloud(), actor.current_xform())
	world.refresh(_time, 0.0)


func set_walking(on: bool) -> void:
	actor.playing = on
	actor.clip = &"walk" if on else &"idle"


func tick(delta: float) -> void:
	_time += delta
	if current_run != null:
		_update_stairs()
		actor.position.y = world.floor_y(elev)
	_update_room()
	if ember:
		ember.visible = (not ember_taken) and world.active_rooms.has(&"CELLAR_IN")
	if ember_item:
		ember_item.enabled = (not ember_taken) and world.active_rooms.has(&"CELLAR_IN")
	_sync_lantern()
	world.set_actor(actor.current_cloud(), actor.current_xform())
	world.refresh(_time, delta)
	if hint:
		hint.retarget(nearest_interactable(actor))


func try_move(step: Vector3) -> void:
	var levels := [player_level] if current_run == null else [current_run.level, current_run.level + 1]
	var np := actor.position + Vector3(step.x, 0, 0)
	if _can_stand(np, levels):
		actor.position = np
	np = actor.position + Vector3(0, 0, step.z)
	if _can_stand(np, levels):
		actor.position = np
	_update_stairs()
	actor.position.y = world.floor_y(elev)


func objective() -> String:
	if not _door_is_open():
		return "Open the cellar door on the south face of the house."
	if not ember_taken:
		return "Step inside and take the ember."
	return "That’s the scene. Walk the garden, the brush, the walkway."


func nearest_interactable(who: Node3D) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for child in get_children():
		if not (child is Interactable):
			continue
		var it: Interactable = child
		if not it.enabled or not it.is_in_range(who):
			continue
		var origin: Vector3 = it.global_position if it.is_inside_tree() else it.position
		var here: Vector3 = who.global_position if who.is_inside_tree() else who.position
		var d := Vector2(origin.x - here.x, origin.z - here.z).length()
		if d < best_d:
			best_d = d
			best = it
	return best


func try_interact() -> StringName:
	var it := nearest_interactable(actor)
	if it == null:
		return &""
	it.use(actor)
	return it.verb


func _paint() -> void:
	for level in MAPS:
		var rows: Array = MAPS[level]
		if int(level) == 0:
			for row in rows:
				assert(String(row).length() == 16, "PR6: level-0 row must be 16 glyphs")
		for z in rows.size():
			var row: String = rows[z]
			for x in row.length():
				var ch := row[x]
				if ch == " " or ch == "":
					continue
				var tile := _tile_for(ch)
				if tile == &"":
					continue
				world.set_cell(int(level), x, z, tile, _room_of(int(level), x, z, ch))
				if ch == "T":
					_spawn_torch(int(level), x, z)


func _tile_for(ch: String) -> StringName:
	match ch:
		".": return &"grass_a"
		",": return &"grass_b"
		";": return &"grass_c"
		"_": return &"path"
		"b": return &"brush_a"
		"n": return &"brush_b"
		"B": return &"brush_heavy_a"
		"#", "w": return &"wall"
		"d": return &"cellar_door"
		"c", "T", "h": return &"planks"
		"t": return &"trunk"
		"~": return &"water"
		"H": return &"bridge"
		"f": return &"flower_a"
		"F": return &"flower_b"
		"^": return &"stair"
		"P", "L": return &"stone"
	return &""


func _room_of(level: int, x: int, z: int, ch: String) -> StringName:
	if level == 0:
		if ch == "c" or ch == "T":
			return &"CELLAR_IN"
		if (ch == "w" or ch == "d") and x >= 2 and x <= 7 and z >= 2 and z <= 5:
			return &"CWALLS"
	elif level == 2:
		if ch == "h":
			return &"HOUSE_IN"
		if ch == "w":
			return &"HWALLS"
	elif level == 3:
		return &"ROOFH"
	return &"OUTSIDE"


func _update_room() -> void:
	var room := world.room_at(player_level, Vector2(actor.position.x, actor.position.z))
	var visible: Array
	match room:
		&"CELLAR_IN":
			visible = [&"CELLAR_IN", &"CWALLS"]
		&"HOUSE_IN":
			visible = [&"HOUSE_IN", &"HWALLS"]
		_:
			visible = [&"OUTSIDE", &"CWALLS", &"HWALLS", &"ROOFH"]
	world.set_active_rooms(visible)
	if torch:
		torch.visible = world.active_rooms.has(&"CELLAR_IN")
	if ember_item:
		ember_item.enabled = (not ember_taken) and world.active_rooms.has(&"CELLAR_IN")
	_sync_lantern()


func _sync_lantern() -> void:
	if lantern == null:
		return
	var dark := world != null and world.active_rooms.has(&"CELLAR_IN")
	var night := clock != null and clock.is_night()
	lantern.enabled = night or dark


func _spawn_clock() -> void:
	clock = DayClock.new()
	clock.name = "Clock"
	clock.time = 16.0
	clock.paused = true
	add_child(clock)
	lantern = Lantern.new()
	lantern.name = "Lantern"
	actor.add_child(lantern)
	world.clock = clock
	world.lantern = lantern
	world.sun_light = _sun_node
	world.environment = _env
	_sync_lantern()


func _door_is_open() -> bool:
	var rec: SplatWorld.Cell = world.cells.get(CELLAR_DOOR)
	return rec != null and rec.state == &"open"


func _spawn_door() -> void:
	door = TileInteractable.new()
	door.name = "CellarDoor"
	door.world = world
	door.cell = CELLAR_DOOR
	door.to_state = &"opening"
	door.disable_when_state = &"open"
	door.prompt = "Open the door"
	door.verb = &"door"
	door.radius = 1.15
	door.require_outside_facing = true
	door.facing_axis = Vector3(0, 0, 1)
	door.position = world.cell_origin(CELLAR_DOOR.x, CELLAR_DOOR.y, CELLAR_DOOR.z) + Vector3(0, 0.55, 0.15)
	add_child(door)


func _spawn_hint() -> void:
	hint = WorldHint.new()
	hint.name = "WorldHint"
	hint.visible = false
	add_child(hint)


func _spawn_torch(level: int, x: int, z: int) -> void:
	torch = OmniLight3D.new()
	torch.name = "Torch"
	torch.light_color = Color(1.0, 0.72, 0.4)
	torch.light_energy = 2.4
	torch.omni_range = 4.5
	torch.shadow_enabled = false
	torch.position = world.cell_origin(level, x, z) + Vector3(0, 0.8, 0)
	torch.visible = false
	add_child(torch)


func _spawn_ember() -> void:
	ember_item = Interactable.new()
	ember_item.name = "EmberItem"
	ember_item.prompt = "Take the ember"
	ember_item.verb = &"ember"
	ember_item.radius = 1.05
	ember_item.position = EMBER_POS
	ember_item.enabled = false
	ember_item.used.connect(_on_ember_used)
	add_child(ember_item)
	ember = MeshInstance3D.new()
	ember.name = "Ember"
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	ember.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.08)
	mat.emission_energy_multiplier = 2.4
	ember.material_override = mat
	ember.visible = false
	ember_item.add_child(ember)


func _on_ember_used(_who: Node) -> void:
	ember_taken = true
	ember_item.enabled = false
	if ember:
		ember.visible = false


func _add_markers() -> void:
	var pond := Node3D.new()
	pond.name = "PondMarker"
	pond.position = POND_MARK
	add_child(pond)
	var trunk := Node3D.new()
	trunk.name = "TrunkMarker"
	trunk.position = TRUNK_MARK
	add_child(trunk)


func _add_volumes_and_field() -> void:
	pond_field = DistortionField.new()
	pond_field.name = "PondHeat"
	pond_field.mode = DistortionField.Mode.HEAT
	pond_field.radius = 1.7
	pond_field.strength = 0.35
	pond_field.rate = 1.2
	pond_field.position = POND_MARK
	add_child(pond_field)
	world.fields.append(pond_field)

	foam_volume = SplatVolume.new()
	foam_volume.name = "PondFoam"
	foam_volume.def = ProcCatalog.foam_volume_def()
	foam_volume.position = POND_MARK
	add_child(foam_volume)
	world.volumes.append(foam_volume)

	var cdef := ProcCatalog.canopy_volume_def()
	canopy_cloud = cdef.cloud
	canopy_volume = SplatVolume.new()
	canopy_volume.name = "Canopy"
	canopy_volume.def = cdef
	canopy_volume.position = TRUNK_MARK
	add_child(canopy_volume)
	world.volumes.append(canopy_volume)


func _add_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.basis = Basis.looking_at(-SUN.normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	add_child(sun)
	_sun_node = sun
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.50, 0.48)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	env.fog_enabled = false
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	we.environment = env
	_env = env
	add_child(we)


func _footprint() -> Array[Vector2]:
	var box := AABB(Vector3(-0.18, 0.0, -0.18), Vector3(0.36, 0.72, 0.36))
	if actor != null and actor.splite != null:
		box = actor.splite.hitbox
	var hx := box.size.x * 0.5
	var hz := box.size.z * 0.5
	return [
		Vector2(-hx, -hz),
		Vector2(hx, -hz),
		Vector2(-hx, hz),
		Vector2(hx, hz),
	]


func _can_stand(pos: Vector3, levels: Array) -> bool:
	for off in _footprint():
		var ok := false
		for l in levels:
			if world.is_walkable(int(l), Vector2(pos.x + off.x, pos.z + off.y)):
				ok = true
				break
		if not ok:
			return false
	return true


func _run_at(tile: Vector2i) -> Variant:
	for run in STAIRS:
		if tile.x == run.x and (tile.y == run.bot or tile.y == run.top):
			if player_level == run.level or player_level == run.level + 1:
				return run
	return null


func _update_stairs() -> void:
	var tile := Vector2i(int(round(actor.position.x)), int(round(actor.position.z)))
	var run = _run_at(tile)
	if run != null:
		current_run = run
		var span := 2.0
		var frac: float
		if run.exit == "N":
			frac = clampf((float(run.bot) + 0.5 - actor.position.z) / span, 0.0, 1.0)
		else:
			frac = clampf((actor.position.z - (float(run.top) - 0.5)) / span, 0.0, 1.0)
		player_level = run.level if frac < 0.5 else run.level + 1
		elev = float(run.level) + frac
	else:
		if current_run != null:
			player_level = current_run.level + 1 if elev > current_run.level + 0.5 else current_run.level
			current_run = null
		elev = float(player_level)
