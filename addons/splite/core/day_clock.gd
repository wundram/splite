@tool
class_name DayClock
extends Node
## High-latitude keyframed sun / moon. 16:00 is AFTERNOON_SUN exactly.

enum Phase { DAWN, DAY, DUSK, NIGHT }

const AFTERNOON_SUN := Vector3(-0.76, 0.54, -0.35)
const EL_MIN := deg_to_rad(8.0)
const EL_MAX := deg_to_rad(55.0)

@export var time: float = 16.0
@export var day_length_sec: float = 180.0
@export var paused: bool = true
@export var scrub_enabled: bool = true

var _knots: Array[Dictionary] = []


func _ready() -> void:
	_init_knots()


func _init_knots() -> void:
	if not _knots.is_empty():
		return
	_knots = [
		{"t": 5.5, "dir": Vector3(0.78, 0.28, -0.22).normalized(), "energy": 0.45,
			"color": Color(1.00, 0.62, 0.48), "amb": Color(0.45, 0.48, 0.62), "amb_e": 0.16, "moon": false},
		{"t": 16.0, "dir": AFTERNOON_SUN, "energy": 1.35,
			"color": Color(1.00, 0.78, 0.52), "amb": Color(0.55, 0.50, 0.48), "amb_e": 0.28, "moon": false},
		{"t": 20.0, "dir": Vector3(-0.84, 0.22, 0.12).normalized(), "energy": 0.35,
			"color": Color(1.00, 0.48, 0.28), "amb": Color(0.28, 0.24, 0.32), "amb_e": 0.12, "moon": false},
		{"t": 23.0, "dir": Vector3(0.42, 0.64, 0.54).normalized(), "energy": 0.18,
			"color": Color(0.70, 0.78, 1.00), "amb": Color(0.12, 0.14, 0.22), "amb_e": 0.07, "moon": true},
	]


func advance(delta: float) -> void:
	if paused or day_length_sec <= 0.0:
		return
	time = fposmod(time + 24.0 * delta / day_length_sec, 24.0)


func scrub(hours: float) -> void:
	if not scrub_enabled:
		return
	time = fposmod(time + hours, 24.0)


func is_night() -> bool:
	var t := fposmod(time, 24.0)
	return t >= 20.0 or t < 5.5


func phase() -> int:
	var t := fposmod(time, 24.0)
	if t >= 23.0 or t < 5.5:
		return Phase.NIGHT
	if t < 8.0:
		return Phase.DAWN
	if t >= 20.0:
		return Phase.DUSK
	return Phase.DAY


func sun_dir() -> Vector3:
	if is_night():
		return moon_dir()
	if is_equal_approx(fposmod(time, 24.0), 16.0):
		return AFTERNOON_SUN
	return _clamp_sun(_sample()["dir"])


func moon_dir() -> Vector3:
	return Vector3(0.42, 0.64, 0.54).normalized()


func sun_energy() -> float:
	if is_night():
		return 0.0
	return float(_sample()["energy"])


func moon_energy() -> float:
	if not is_night():
		return 0.0
	return float(_sample()["energy"])


func sun_color() -> Color:
	return _sample()["color"]


func ambient_color() -> Color:
	return _sample()["amb"]


func ambient_energy() -> float:
	return float(_sample()["amb_e"])


func light_dir() -> Vector3:
	return moon_dir() if is_night() else sun_dir()


func light_energy() -> float:
	return moon_energy() if is_night() else sun_energy()


func light_color() -> Color:
	return sun_color()


func _sample() -> Dictionary:
	_init_knots()
	var t := fposmod(time, 24.0)
	if is_equal_approx(t, 16.0):
		return _knots[1]
	var a: Dictionary
	var b: Dictionary
	var u := 0.0
	if t >= 23.0 or t < 5.5:
		a = _knots[3]
		b = _knots[0]
		var ta := 23.0
		var tb := 5.5 + 24.0
		var tt := t if t >= 23.0 else t + 24.0
		u = (tt - ta) / (tb - ta)
	elif t < 16.0:
		a = _knots[0]
		b = _knots[1]
		u = (t - 5.5) / (16.0 - 5.5)
	elif t < 20.0:
		a = _knots[1]
		b = _knots[2]
		u = (t - 16.0) / (20.0 - 16.0)
	else:
		a = _knots[2]
		b = _knots[3]
		u = (t - 20.0) / (23.0 - 20.0)
	u = clampf(u, 0.0, 1.0)
	var dir: Vector3 = a.dir
	if is_night():
		dir = _slerp_dir(moon_dir() if bool(a.get("moon", false)) else moon_dir(), moon_dir(), u)
		if t >= 20.0 and t < 23.0:
			dir = _slerp_dir(a.dir, moon_dir(), u)
	else:
		dir = _slerp_dir(a.dir, b.dir, u)
	return {
		"dir": dir,
		"energy": lerpf(float(a.energy), float(b.energy), u),
		"color": (a.color as Color).lerp(b.color as Color, u),
		"amb": (a.amb as Color).lerp(b.amb as Color, u),
		"amb_e": lerpf(float(a.amb_e), float(b.amb_e), u),
	}


func _clamp_sun(dir: Vector3) -> Vector3:
	dir = dir.normalized()
	var el := asin(clampf(dir.y, -1.0, 1.0))
	el = clampf(el, EL_MIN, EL_MAX)
	var xz := Vector2(dir.x, dir.z)
	var xz_len := xz.length()
	var want_xz := cos(el)
	if xz_len > 0.0001:
		xz = xz / xz_len * want_xz
	else:
		xz = Vector2(-want_xz, 0.0)
	return Vector3(xz.x, sin(el), xz.y).normalized()


static func _slerp_dir(a: Vector3, b: Vector3, t: float) -> Vector3:
	var n1 := a.normalized()
	var n2 := b.normalized()
	var d := clampf(n1.dot(n2), -1.0, 1.0)
	if absf(d) > 0.9995:
		return n1.lerp(n2, t).normalized()
	var th := acos(d)
	return (n1 * sin((1.0 - t) * th) + n2 * sin(t * th)) / sin(th)
