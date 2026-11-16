extends "res://demos/garden/garden_play.gd"
var hud: Control
func create_garden() -> Node:return preload("res://demos/living_garden/living_garden.gd").new()
func _build_hud() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	hud=preload("res://demos/living_garden/hud.gd").new();hud.garden=garden;layer.add_child(hud)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_H,KEY_F1:hud.help_open=not hud.help_open
		KEY_ESCAPE:
			if hud.help_open or hud.map_open:hud.help_open=false;hud.map_open=false
			else:hud.help_open=true
		KEY_I:hud.portrait_open=not hud.portrait_open
		KEY_M:hud.map_open=not hud.map_open
		KEY_Q:
			if not hud.help_open and not hud.map_open:garden.cast_spell(1)
		KEY_SPACE:
			if not hud.help_open and not hud.map_open:garden.cast_spell()
func _process(delta: float) -> void:
	if hud!=null and (hud.help_open or hud.map_open):
		garden.set_walking(false);garden.tick(delta)
	else:super._process(delta)

func _bind_keys() -> void:
	super._bind_keys()
	# Space casts only; the base Godot ui_accept action also contains Space.
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and (event.keycode==KEY_SPACE or event.physical_keycode==KEY_SPACE):
			InputMap.action_erase_event("ui_accept",event)
