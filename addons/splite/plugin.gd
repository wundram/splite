@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("SplatBatch", "MultiMeshInstance3D", preload("render/splat_batch.gd"), null)
	add_custom_type("SplatWorld", "Node3D", preload("core/splat_world.gd"), null)
	add_custom_type("SplatCameraRig", "Node3D", preload("core/camera_rig.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("SplatCameraRig")
	remove_custom_type("SplatWorld")
	remove_custom_type("SplatBatch")
