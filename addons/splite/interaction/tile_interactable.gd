@tool
class_name TileInteractable
extends Interactable
## Flips a cell into `to_state`. Door: used → opening → open via next_state.

@export var cell: Vector3i = Vector3i.ZERO
@export var to_state: StringName = &"opening"
@export var disable_when_state: StringName = &"open"

var world: SplatWorld


func _ready() -> void:
	_bind_world()


func _bind_world() -> void:
	if world == null:
		return
	if not world.state_finished.is_connected(_on_state_finished):
		world.state_finished.connect(_on_state_finished)


func _on_state_finished(key: Vector3i, _from: StringName, to: StringName) -> void:
	if key == cell and to == disable_when_state:
		enabled = false


func _sync_enabled() -> void:
	if world == null or disable_when_state == &"":
		return
	var rec: SplatWorld.Cell = world.cells.get(cell)
	if rec != null and rec.state == disable_when_state:
		enabled = false


func is_in_range(who: Node3D) -> bool:
	_sync_enabled()
	return super.is_in_range(who)


func _apply(_who: Node) -> void:
	_bind_world()
	if world == null:
		return
	var rec: SplatWorld.Cell = world.cells.get(cell)
	if rec == null:
		return
	if rec.state == disable_when_state or rec.state == to_state:
		return
	world.set_cell_state(cell.x, cell.y, cell.z, to_state)
