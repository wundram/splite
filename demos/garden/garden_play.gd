extends Node3D
## Walkable style-demo host. WASD, stairs, --shot= harness.

const WALK_SPEED := 3.4

var garden: Node
var objective: Label
var prompt: Label
var meta: Label
var debug: Node
var shot_path := ""
var shot_frames := 40


func _ready() -> void:
	garden = preload("res://demos/shared/garden.gd").new()
	garden.name = "Garden"
	add_child(garden)
	garden.build()
	debug = preload("res://demos/garden/debug_overlay.gd").new()
	debug.name = "CutawayDebug"
	debug.world = garden.world
	add_child(debug)
	_build_hud()
	_bind_keys()
	_parse_args()
	if shot_path != "":
		_take_shot()


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := dir.length() > 0.1
	garden.set_walking(moving)
	if moving:
		if abs(dir.x) > 0.1:
			garden.actor.facing = sign(dir.x)
		var step := dir.normalized() * WALK_SPEED * delta
		garden.try_move(Vector3(step.x, 0, step.y))
	if Input.is_action_just_pressed("ui_accept"):
		garden.try_interact()
	garden.tick(delta)
	if objective:
		objective.text = garden.objective()
	if prompt:
		var hint: String = garden.interact_hint()
		prompt.text = hint
		prompt.visible = hint != ""
	if meta:
		var fps := Engine.get_frames_per_second()
		var ms := (1000.0 / float(fps)) if fps > 0 else 0.0
		meta.text = "WASD move   E interact   F3 cut   %d fps  %.2f ms  %d g  level %.2f" % [
			fps, ms, garden.world.gaussian_count(), garden.elev
		]


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	objective = Label.new()
	objective.position = Vector2(16, 12)
	objective.add_theme_font_size_override("font_size", 18)
	objective.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	layer.add_child(objective)
	prompt = Label.new()
	prompt.position = Vector2(16, 40)
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	prompt.visible = false
	layer.add_child(prompt)
	meta = Label.new()
	meta.position = Vector2(16, 1160)
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	layer.add_child(meta)


func _bind_keys() -> void:
	var keys := {
		"ui_left": KEY_A,
		"ui_right": KEY_D,
		"ui_up": KEY_W,
		"ui_down": KEY_S,
		"ui_accept": KEY_E,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--px="):
			garden.actor.position.x = float(a.substr(5))
		elif a.begins_with("--pz="):
			garden.actor.position.z = float(a.substr(5))
		elif a.begins_with("--plevel="):
			garden.place(garden.actor.position.x, garden.actor.position.z, int(a.substr(9)))


func _take_shot() -> void:
	for i in shot_frames:
		await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("shot: no viewport texture (cannot --shot --headless)")
		get_tree().quit(1)
		return
	var img := tex.get_image()
	if img == null:
		push_error("shot: get_image failed")
		get_tree().quit(1)
		return
	img.save_png(shot_path)
	get_tree().quit()
