extends Node3D
## Zero-input walk through every shipping feature. Quits 0 at the end.
##
##   Godot --path . res://demos/tour/tour.tscn
##   Godot --path . res://demos/tour/tour.tscn -- --hold-scale=0.25

var garden: Node
var tour: FeatureTour


func _ready() -> void:
	garden = preload("res://demos/shared/garden.gd").new()
	garden.name = "Garden"
	add_child(garden)
	garden.build()
	tour = FeatureTour.new()
	tour.name = "Tour"
	add_child(tour)
	tour.beat_started.connect(_on_beat)
	await get_tree().process_frame
	await get_tree().process_frame
	tour.play(TourBeats.all(), _place, _scrub)


func _place(x: float, z: float, level: int, facing: float, moving: bool) -> void:
	garden.place(x, z, level, facing)
	garden.set_walking(moving)


func _scrub(x: float, z: float, level: int) -> void:
	garden.slide(x, z, level)


func _on_beat(beat: Dictionary) -> void:
	if beat.has("clock") and garden.clock:
		garden.clock.time = float(beat["clock"])
	if bool(beat.get("interact", false)):
		garden.try_interact()


func _process(delta: float) -> void:
	if garden:
		garden.tick(delta)
