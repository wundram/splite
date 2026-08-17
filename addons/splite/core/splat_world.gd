@tool
class_name SplatWorld
extends Node3D
## Grid of splat tiles across height levels, plus room visibility.

const AFTERNOON_SUN := Vector3(-0.76, 0.54, -0.35)
const ENTER_CROSSFADE := 0
const ENTER_SEQUENCE := 1
const _ACTOR_HEAD := 0.72
const _CUT_FOLLOW_HZ := 14.0

signal state_finished(cell_key: Vector3i, from: StringName, to: StringName)

@export var level_height: float = 1.25
@export var batch_path: NodePath
@export var softness: float = 3.6
## Points toward the sun. Default is a 4pm WNW sun (~33° elevation).
@export var sun_dir: Vector3 = AFTERNOON_SUN:
	set(v):
		if sun_dir.distance_to(v) > 0.002:
			_needs_drops = true
		sun_dir = v
		_needs_lights = true
@export var cutaway_enabled: bool = true
@export var cutaway_inner: float = 1.45
@export var cutaway_outer: float = 2.90
@export var cutaway_y_soft: float = 0.22
@export var cutaway_y_bias: float = 0.25

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
var _needs_drops := false
var clock: DayClock
var lantern: Lantern
var sun_light: DirectionalLight3D
var environment: Environment
var _actor_cloud: SplatCloud
var _actor_xform := Transform3D.IDENTITY
var _actor_mod := Color.WHITE
var _extras: Array[Dictionary] = []
var _cut_xz := Vector2.ZERO
var _cut_y := 0.72
var _cut_ready := false


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


func gaussian_count() -> int:
	_ensure()
	return _batch.instance_count if _batch else 0


func set_actor(cloud: SplatCloud, xform: Transform3D, modulate: Color = Color.WHITE) -> void:
	_actor_cloud = cloud
	_actor_xform = xform
	_actor_mod = modulate
	_needs_dyn = true


func add_extra_cloud(cloud: SplatCloud, xform: Transform3D, policy: float, hull_top: float) -> void:
	_extras.append({
		"cloud": cloud,
		"xform": xform,
		"policy": policy,
		"top": hull_top,
	})
	_needs_static = true


func clear_extra_clouds() -> void:
	_extras.clear()
	_needs_static = true


func extra_count() -> int:
	return _extras.size()


func hull_count() -> int:
	return 0 if _hulls == null else _hulls.get_child_count()


func cut_origin() -> Vector3:
	return Vector3(_cut_xz.x, _cut_y, _cut_xz.y)


func actor_head() -> Vector3:
	return _actor_xform.origin + Vector3(0.0, _ACTOR_HEAD, 0.0)


func cutaway_amount(world_pos: Vector3, policy: float, hull_top: float) -> float:
	# Mirrors cutaway.gdshaderinc. Tests use this; shaders stay the draw path.
	if not cutaway_enabled or policy < 0.5:
		return 0.0
	var origin := cut_origin()
	var ref_y := origin.y + cutaway_y_bias
	if policy < 1.5:
		ref_y = origin.y - _ACTOR_HEAD + cutaway_y_bias
	var above := _glsl_smoothstep(ref_y, ref_y + cutaway_y_soft, hull_top)
	var d := Vector2(world_pos.x - origin.x, world_pos.z - origin.z).length()
	var ring := 1.0 - _glsl_smoothstep(cutaway_inner, cutaway_outer, d)
	return clampf(above * ring, 0.0, 1.0)


static func _glsl_smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 1.0 if x >= edge1 else 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func refresh(time: float, delta: float) -> void:
	_ensure()
	if _batch == null:
		return
	_tick_transitions(delta)
	if clock:
		clock.advance(delta)
		_apply_clock()
	if lantern:
		lantern.tick(delta)
	_update_cut_origin(delta)
	var origin := cut_origin()
	var inner := cutaway_inner
	var outer := cutaway_outer
	if not cutaway_enabled:
		inner = 1000.0
		outer = 1001.0
	_batch.set_cutaway(origin, inner, outer, cutaway_y_soft, cutaway_y_bias, _ACTOR_HEAD)
	if _needs_lights:
		_apply_lights()
	if _needs_static:
		_rebuild_static()
		_rebuild_hulls()
		_rebuild_static_drops()
		_needs_static = false
		_needs_drops = false
	elif _needs_drops:
		_rebuild_static_drops()
		_needs_drops = false
	if _needs_dyn:
		_rebuild_dynamic(time)
		_needs_dyn = false
	_apply_surface_cutaway(origin, inner, outer)
	_batch.commit()
	if _drops:
		_drops.commit()


func _update_cut_origin(delta: float) -> void:
	var head := actor_head()
	var target := Vector2(head.x, head.z)
	if not _cut_ready or delta <= 0.0:
		_cut_xz = target
		_cut_ready = true
	else:
		var a := 1.0 - exp(-_CUT_FOLLOW_HZ * delta)
		_cut_xz = _cut_xz.lerp(target, a)
	_cut_y = head.y


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
	# Room / cell change only. Walking must not recreate the static batch
	# or hull MeshInstance3Ds — that is what locked the garden after ~30s.
	_batch.clear_static()
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room) or _is_transitioning(cell):
			continue
		var st := _state(cell)
		if st == null or st.cloud == null:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
		_batch.add_static_cloud(
			st.cloud,
			Transform3D(Basis.IDENTITY, origin),
			Color.WHITE,
			float(st.cutaway),
			_cut_measure(st, origin)
		)
	for extra in _extras:
		_batch.add_static_cloud(
			extra.cloud,
			extra.xform,
			Color.WHITE,
			float(extra.policy),
			float(extra.top)
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
	if _actor_cloud:
		_batch.add_dynamic_cloud(_actor_cloud, _actor_xform, _actor_mod)
	_update_actor_drop()


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


func _apply_surface_cutaway(origin: Vector3, inner: float, outer: float) -> void:
	if _surface_mat == null:
		return
	_surface_mat.set_shader_parameter("cut_origin", origin)
	_surface_mat.set_shader_parameter("cut_inner", inner)
	_surface_mat.set_shader_parameter("cut_outer", outer)
	_surface_mat.set_shader_parameter("cut_y_soft", cutaway_y_soft)
	_surface_mat.set_shader_parameter("cut_y_bias", cutaway_y_bias)
	_surface_mat.set_shader_parameter("cut_head", _ACTOR_HEAD)


func _apply_clock() -> void:
	if clock == null:
		return
	sun_dir = clock.light_dir()
	if sun_light:
		sun_light.basis = Basis.looking_at(-_sun(), Vector3.UP)
		sun_light.light_color = clock.light_color()
		sun_light.light_energy = clock.light_energy()
	if environment:
		environment.ambient_light_color = clock.ambient_color()
		environment.ambient_light_energy = clock.ambient_energy()


func _apply_lights() -> void:
	var col := Color(1.0, 0.78, 0.52)
	var energy := 1.35
	var amb := Color(0.55, 0.50, 0.48)
	var amb_e := 0.28
	if clock:
		col = clock.light_color()
		energy = clock.light_energy()
		amb = clock.ambient_color()
		amb_e = clock.ambient_energy()
	var lpos := Vector3.ZERO
	var lcol := Color(1.0, 0.72, 0.38)
	var lenergy := 0.0
	var lrange := 5.5
	if lantern != null and lantern.enabled:
		lpos = lantern.world_pos()
		lcol = lantern.color
		lenergy = lantern.energy
		lrange = lantern.omni_range
	_batch.set_lighting(_sun(), col, energy, amb, amb_e, lpos, lcol, lenergy, lrange)
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


func _update_actor_drop() -> void:
	if _drops == null:
		return
	_drops.clear_dynamic()
	if _actor_cloud != null:
		var origin := _actor_xform.origin
		var rec_y := _receiver_y(
			int(round(origin.y / maxf(level_height, 0.001))),
			int(round(origin.x)),
			int(round(origin.z))
		)
		var pos := origin + _ground_offset(0.72)
		pos.y = rec_y + 0.035
		_drops.add_dynamic(pos, Vector2(0.28, 0.22), 0.38, true)
	_add_lantern_drops()


func _add_lantern_drops() -> void:
	if lantern == null or not lantern.enabled or _drops == null:
		return
	var lp := lantern.world_pos()
	var hits: Array[Dictionary] = []
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room):
			continue
		var st := _state(cell)
		if st == null or not st.receive_shadow:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
		var rec_y := origin.y + st.hull.position.y + st.hull.size.y
		var rec := Vector3(origin.x, rec_y, origin.z)
		var r := lp.distance_to(rec)
		if r > lantern.drop_radius or r < 0.08:
			continue
		hits.append({
			"r": r,
			"rec": rec,
			"half": Vector2(st.hull.size.x, st.hull.size.z) * 0.42,
		})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.r) < float(b.r))
	var n := mini(hits.size(), 12)
	for i in n:
		var h: Dictionary = hits[i]
		var r: float = h.r
		var str := clampf(0.42 / (r * r), 0.08, 0.50)
		_drops.add_radial(h.rec + Vector3(0, 0.03, 0), h.half, str)


func _rebuild_hulls() -> void:
	while _hulls.get_child_count() > 0:
		var old := _hulls.get_child(0)
		_hulls.remove_child(old)
		old.free()
	_ensure_surface_mat()
	for key in cells:
		var cell: Cell = cells[key]
		if not _room_active(cell.room):
			continue
		var st := _state(cell)
		if st == null or st.surface == null or not st.surface.visible:
			continue
		var origin := cell_origin(key.x, key.y, key.z)
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
