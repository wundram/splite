extends SceneTree
## Run with --fixed-fps 24; encode the numbered PNGs at 24 fps.
const FPS := 24
const OUTPUT := "/tmp/splite-living-tour"
var frame_number := 0
var scene: Node
var garden: Node

func _initialize() -> void:
	call_deferred("run")

func clip(at: Vector2, seconds: int, movement := Vector2.ZERO, spell := -1) -> void:
	garden.set_walking(false)
	garden.place(at.x, at.y, 0)
	garden.tick(1.0 / FPS)
	garden.cam.snap()
	for i in 12:
		garden.tick(1.0 / FPS)
		await process_frame
	for i in seconds * FPS:
		if spell >= 0 and i == FPS:
			garden.cast_spell(spell)
		garden.set_walking(movement.length() > 0)
		garden.try_move(Vector3(movement.x, 0, movement.y) / FPS)
		garden.tick(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(OUTPUT + "/%04d.png" % frame_number)
		assert(result == OK, "Unable to save video frame")
		frame_number += 1
	print("Tour clip complete: ", frame_number, " frames")

func run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	scene = load("res://demos/living_garden/garden.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	garden = scene.garden
	await clip(Vector2(12, 16), 4)
	await clip(Vector2(11, 18), 6, Vector2(0, 1.3))
	await clip(Vector2(21, 16), 4)
	await clip(Vector2(32, 25), 4, Vector2.ZERO, 0)
	await clip(Vector2(24, 3), 4)
	await clip(Vector2(30, 8), 6, Vector2.ZERO, 1)
	print("Living garden tour: ", frame_number, " frames saved to ", OUTPUT)
	quit()
