extends "res://demos/garden/garden_play.gd"

func create_garden() -> Node:
	return preload("res://demos/garden_expanded/expanded_garden.gd").new()

func _build_hud() -> void:
	super._build_hud()
	objective.position=Vector2(30,24)
	objective.add_theme_font_size_override("font_size",21)

func _process(delta: float) -> void:
	super._process(delta)
	meta.text="WASD / arrows  Move     E  Interact     [ / ]  Time     F3  Cutaway     ·     %04.1fh" % garden.clock.time
