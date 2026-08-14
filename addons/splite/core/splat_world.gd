@tool
class_name SplatWorld
extends Node3D
## Grid of splat tiles across height levels, plus room visibility.

const AFTERNOON_SUN := Vector3(-0.76, 0.54, -0.35)
const ENTER_CROSSFADE := 0
const ENTER_SEQUENCE := 1

signal state_finished(cell_key: Vector3i, from: StringName, to: StringName)

@export var level_height: float = 1.25
@export var batch_path: NodePath
@export var softness: float = 3.6
## Points toward the sun. Default is a 4pm WNW sun (~33° elevation).
@export var sun_dir: Vector3 = AFTERNOON_SUN:
	set(v):
		sun_dir = v
		_needs_lights = true
@export var cutaway_inner: float = 1.45
@export var cutaway_outer: float = 2.90

var defs: Dictionary[StringName, TileDef] = {}
var cells: Dictionary[Vector3i, Cell] = {}
var walk: Dictionary[Vector3i, bool] = {}
var active_rooms: Dictionary[StringName, bool] = {}

var _batch: SplatBatch
var _drops: DropShadowBatch
var _hulls: Node3D
var _surface_mat: ShaderMaterial
var _needs_static := true
var _needs_dyn := false
var _needs_lights := true
var _frustum_anchor := Vector3i(2147483647, 2147483647, 2147483647)


class Cell extends RefCounted:
	var def: TileDef
	var room: StringName = &"OUTSIDE"
	var state: StringName = &"default"
	var from_state: StringName = &"default"
	var blend: float = 1.0
	var seq_time: float = 0.0


func _ready() -> void:
	_ensure()


func _ensure() -> void:
	if _hulls == null:
		_hulls = get_node_or_null("Hulls")
		if _hulls == null:
			_hulls = Node3D.new()
			_hulls.name = "Hulls"
			add_child(_hulls)
	if _batch == null:
		if batch_path != NodePath():
			_batch = get_node_or_null(batch_path)
		if _batch == null:
			_batch = get_node_or_null("Batch") as SplatBatch
		if _batch == null:
			_batch = SplatBatch.new()
			_batch.name = "Batch"
			add_child(_batch)
		_batch.softness = softness
	if _drops == null:
		_drops = get_node_or_null("Drops") as DropShadowBatch
		if _drops == null:
			_drops = DropShadowBatch.new()
			_drops.name = "Drops"
			add_child(_drops)


func register_defs(catalog: Dictionary) -> void:
	defs.clear()
	for k in catalog:
		defs[StringName(k)] = catalog[k]


func set_cell(level: int, x: int, z: int, tile_id: StringName, room: StringName) -> void:
	var def: TileDef = defs.get(tile_id)
	if def == null:
		push_warning("Unknown tile '%s'" % tile_id)
		return
	var key := Vector3i(level, x, z)
	var cell := Cell.new()
	cell.def = def
	cell.room = room
	cell.state = def.default_state
	cell.from_state = def.default_state
	cell.blend = 1.0
	cell.seq_time = 0.0
	cells[key] = cell
	_rebuild_walk_key(key)
	_needs_static = true


func set_cell_state(level: int, x: int, z: int, to_state: StringName) -> void:
	var key := Vector3i(level, x, z)
	var cell: Cell = cells.get(key)
	if cell == null or cell.def == null:
		return
	if not cell.def.states.has(to_state):
		push_warning("Unknown state '%s' on '%s'" % [to_state, cell.def.id])
		return
	cell.from_state = cell.state
	cell.state = to_state
	cell.blend = 0.0
	cell.seq_time = 0.0
	_rebuild_walk_key(key)
	_needs_dyn = true


func set_active_rooms(rooms: Array) -> void:
	var next: Dictionary[StringName, bool] = {}
	for r in rooms:
		next[StringName(r)] = true
	if next == active_rooms:
		return
	active_rooms = next
	_needs_static = true


func floor_y(level: float) -> float:
	return level * level_height


func cell_origin(level: int, x: int, z: int) -> Vector3:
	return Vector3(float(x), floor_y(float(level)), float(z))


func is_walkable(level: int, xz: Vector2) -> bool:
	var key := Vector3i(level, int(round(xz.x)), int(round(xz.y)))
	return walk.get(key, false)


func room_at(level: int, xz: Vector2) -> StringName:
	var key := Vector3i(level, int(round(xz.x)), int(round(xz.y)))
	var cell: Cell = cells.get(key)
	if cell != null:
		return cell.room
	return &"OUTSIDE"


func refresh(time: float, delta: float) -> void:
	_ensure()
	if _batch == null:
		return
	_tick_transitions(delta)
	_update_frustum_anchor()
	var head := Vector3(0.0, 0.72, 0.0)
	_batch.set_cutaway(head, cutaway_inner, cutaway_outer)
	_apply_surface_cutaway(head)
	if _needs_lights:
		_apply_lights()
	if _needs_static:
		_rebuild_static()
		_rebuild_hulls()
		_rebuild_static_drops()
		_needs_static = false
	if _needs_dyn:
		_rebuild_dynamic(time)
		_needs_dyn = false
	_batch.commit()
	if _drops:
		_drops.commit()


func _state(cell: Cell) -> TileState:
	if cell == null or cell.def == null:
		return null
	var st: TileState = cell.def.states.get(cell.state)
	if st == null:
		st = cell.def.states.get(cell.def.default_state)
	return st


func _from_state(cell: Cell) -> TileState:
	if cell == null or cell.def == null:
		return null
	var st: TileState = cell.def.states.get(cell.from_state)
	if st == null:
		return _state(cell)
	return st


func _gameplay_state(cell: Cell) -> TileState:
	var to_st := _state(cell)
	var from_st := _from_state(cell)
	if to_st == null:
		return from_st
	if from_st == null or cell.from_state == cell.state:
		return to_st
	if to_st.enter_mode == ENTER_SEQUENCE:
		return from_st
	if cell.blend < 0.5:
		return from_st
	return to_st


func _is_transitioning(cell: Cell) -> bool:
	var st := _state(cell)
	if st == null or cell.from_state == cell.state:
		return false
	if st.enter_mode == ENTER_SEQUENCE:
		return not st.sequence.is_empty() and cell.seq_time * st.sequence_fps < float(st.sequence.size())
	return cell.blend < 1.0


func _room_active(room: StringName) -> bool:
	return active_rooms.is_empty() or active_rooms.has(room)


func _rebuild_walk_key(key: Vector3i) -> void:
	var cell: Cell = cells.get(key)
	var st := _gameplay_state(cell)
	if st != null and st.walkable:
		walk[key] = true
	else:
		walk.erase(key)


func _tick_transitions(delta: float) -> void:
	for key in cells:
		var cell: Cell = cells[key]
		if not _is_transitioning(cell):
			continue
		var st := _state(cell)
		_needs_dyn = true
		if st.enter_mode == ENTER_SEQUENCE:
			cell.seq_time += delta
			if cell.seq_time * st.sequence_fps >= float(st.sequence.size()):
				_finish_state(key, cell, st)
		else:
			if st.enter_duration <= 0.0:
				cell.blend = 1.0
			else:
				cell.blend = minf(cell.blend + delta / st.enter_duration, 1.0)
			_rebuild_walk_key(key)
			if cell.blend >= 1.0:
				_finish_state(key, cell, st)


func _finish_state(key: Vector3i, cell: Cell, st: TileState) -> void:
	var from := cell.from_state
	var completed := cell.state
	if st.next_state != &"":
		cell.from_state = cell.state
		cell.state = st.next_state
		cell.blend = 1.0
		cell.seq_time = 0.0
		state_finished.emit(key, from, cell.state)
	else:
		cell.from_state = cell.state
		cell.blend = 1.0
		cell.seq_time = 0.0
		state_finished.emit(key, from, completed)
	_rebuild_walk_key(key)
	_needs_static = true


func _rebuild_static() -> void:
	_batch.clear_static()
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room) or _is_transitioning(cell):
			continue
		var st := _state(cell)
		if st == null or st.cloud == null:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
		if not _cell_in_frustum(origin, st.hull):
			continue
		_batch.add_static_cloud(
			st.cloud,
			Transform3D(Basis.IDENTITY, origin),
			Color.WHITE,
			float(st.cutaway),
			_cut_measure(st, origin)
		)


func _rebuild_dynamic(_time: float) -> void:
	_batch.clear_dynamic()
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room) or not _is_transitioning(cell):
			continue
		var st := _state(cell)
		if st == null:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
		var xf := Transform3D(Basis.IDENTITY, origin)
		var top := _cut_measure(st, origin)
		if st.enter_mode == ENTER_SEQUENCE and not st.sequence.is_empty():
			var idx := clampi(int(cell.seq_time * st.sequence_fps), 0, st.sequence.size() - 1)
			_batch.add_dynamic_cloud(st.sequence[idx], xf, Color.WHITE, float(st.cutaway), top)
		else:
			var from_st := _from_state(cell)
			if from_st != null and from_st.cloud != null:
				var a := Color(1, 1, 1, 1.0 - cell.blend)
				_batch.add_dynamic_cloud(from_st.cloud, xf, a, float(from_st.cutaway), _cut_measure(from_st, origin))
			if st.cloud != null:
				var b := Color(1, 1, 1, cell.blend)
				_batch.add_dynamic_cloud(st.cloud, xf, b, float(st.cutaway), top)


func _cut_measure(st: TileState, origin: Vector3) -> float:
	if st.cutaway == TileDef.Cutaway.IF_OCCLUDES:
		return origin.y + st.cutaway_height()
	return origin.y + st.hull.position.y


func _ensure_surface_mat() -> void:
	if _surface_mat != null:
		return
	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = load("res://addons/splite/render/surface.gdshader")
	_surface_mat.set_shader_parameter("roughness", 0.88)


func _apply_surface_cutaway(head: Vector3) -> void:
	if _surface_mat == null:
		return
	_surface_mat.set_shader_parameter("cut_origin", head)
	_surface_mat.set_shader_parameter("cut_inner", cutaway_inner)
	_surface_mat.set_shader_parameter("cut_outer", cutaway_outer)


func _apply_lights() -> void:
	_batch.set_lighting(
		_sun(),
		Color(1.0, 0.78, 0.52),
		1.35,
		Color(0.55, 0.50, 0.48),
		0.28
	)
	_needs_lights = false


func _sun() -> Vector3:
	var s := sun_dir
	if s.y < 0.15:
		s.y = 0.15
	return s.normalized()


func _ground_offset(lift: float) -> Vector3:
	var s := _sun()
	return Vector3(-s.x / s.y, 0.0, -s.z / s.y) * lift


func _receiver_y(level: int, x: int, z: int) -> float:
	# Same cell first: tiles *are* the ground (no oversized plane). A hybrid
	# bush lands its drop on its own visible slab.
	for m in range(level, -1, -1):
		var key := Vector3i(m, x, z)
		var cell: Cell = cells.get(key)
		if cell == null:
			continue
		var st := _state(cell)
		if st != null and st.receive_shadow:
			return floor_y(float(m)) + st.hull.position.y + st.hull.size.y
	return 0.02


func _rebuild_static_drops() -> void:
	if _drops == null:
		return
	_drops.clear_static()
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room):
			continue
		var st := _state(cell)
		if st == null or st.cast_model == TileDef.CastModel.NONE:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
		if not _cell_in_frustum(origin, st.hull):
			continue
		var top := origin.y + st.cast_height()
		var rec_y := _receiver_y(key.x, key.y, key.z)
		var lift := top - rec_y
		if lift < 0.22:
			continue
		var pos := origin + _ground_offset(lift)
		pos.y = rec_y + 0.03
		var blob := st.cast_model == TileDef.CastModel.BLOB
		var half := Vector2(st.hull.size.x, st.hull.size.z) * (0.58 if blob else 0.52)
		if blob:
			half *= 1.15
		var str := clampf(0.18 + lift * 0.05, 0.22, 0.40)
		_drops.add_static(pos, half, str, blob)


func _rebuild_hulls() -> void:
	for c in _hulls.get_children():
		c.queue_free()
	_ensure_surface_mat()
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room):
			continue
		var st := _state(cell)
		if st == null or st.surface == null or not st.surface.visible:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
		if not _cell_in_frustum(origin, st.hull):
			continue
		var mi := MeshInstance3D.new()
		if st.surface.mesh != null:
			mi.mesh = st.surface.mesh
			mi.position = origin
		else:
			var box := BoxMesh.new()
			box.size = st.hull.size
			mi.mesh = box
			mi.position = origin + st.hull.get_center()
		mi.material_override = _surface_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.set_instance_shader_parameter("albedo", st.surface.color)
		mi.set_instance_shader_parameter("cut_policy", float(st.cutaway))
		mi.set_instance_shader_parameter("hull_top", _cut_measure(st, origin))
		_hulls.add_child(mi)


func _update_frustum_anchor() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Quantize camera XZ so a walk rebuilds static once per tile, not per frame.
	var next := Vector3i(0, int(round(cam.global_position.x)), int(round(cam.global_position.z)))
	if next != _frustum_anchor:
		_frustum_anchor = next
		_needs_static = true


func _cell_in_frustum(origin: Vector3, hull: AABB) -> bool:
	if not is_inside_tree():
		return true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	var pad := Vector3(2.0, 1.0, 2.0)
	var center := origin + hull.get_center()
	if cam.is_position_in_frustum(center):
		return true
	var p := origin + hull.position - pad
	var s := hull.size + pad * 2.0
	var pts := [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(s.x * 0.5, s.y, s.z * 0.5),
	]
	for pt in pts:
		if cam.is_position_in_frustum(pt):
			return true
	return false
