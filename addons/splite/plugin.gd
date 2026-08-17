@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("SplatBatch", "MultiMeshInstance3D", preload("render/splat_batch.gd"), null)
	add_custom_type("SplatWorld", "Node3D", preload("core/splat_world.gd"), null)
	add_custom_type("SplatCameraRig", "Node3D", preload("core/camera_rig.gd"), null)
	add_custom_type("SpliteActor", "Node3D", preload("core/splite_actor.gd"), null)
	add_custom_type("Interactable", "Node3D", preload("interaction/interactable.gd"), null)
	add_custom_type("TileInteractable", "Node3D", preload("interaction/tile_interactable.gd"), null)
	add_custom_type("WorldHint", "Node3D", preload("interaction/world_hint.gd"), null)
	add_custom_type("DayClock", "Node", preload("core/day_clock.gd"), null)
	add_custom_type("DistortionField", "Node3D", preload("effects/distortion_field.gd"), null)
	add_custom_type("SplatVolume", "Node3D", preload("core/splat_volume.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("SplatVolume")
	remove_custom_type("DistortionField")
	remove_custom_type("DayClock")
	remove_custom_type("WorldHint")
	remove_custom_type("TileInteractable")
	remove_custom_type("Interactable")
	remove_custom_type("SpliteActor")
	remove_custom_type("SplatCameraRig")
	remove_custom_type("SplatWorld")
	remove_custom_type("SplatBatch")
