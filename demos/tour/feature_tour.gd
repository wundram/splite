class_name FeatureTour
extends CanvasLayer
## Plays a list of captioned beats, then quits with code 0.

signal finished
signal beat_started(beat: Dictionary)

var hold_scale := 1.0
var default_hold := 3.8
var settle := 0.55

var _title: Label
var _body: Label
var _step: Label
var _bar: ColorRect


func _ready() -> void:
	layer = 20
	_build_ui()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hold-scale="):
			hold_scale = maxf(0.05, float(a.substr(13)))


func play(beats: Array[Dictionary], place: Callable, scrub: Callable) -> void:
	var n := beats.size()
	for i in n:
		var b: Dictionary = beats[i]
		_title.text = str(b.get("title", b.get("id", "")))
		_body.text = str(b.get("body", ""))
		_step.text = "%d  /  %d" % [i + 1, n]
		beat_started.emit(b)
		var x := float(b.get("x", 0.0))
		var z := float(b.get("z", 0.0))
		var level := int(b.get("level", 0))
		var dir := float(b.get("dir", 1.0))
		var pan := float(b.get("pan", 2.4))
		var x0 := x - dir * pan * 0.5
		var x1 := x + dir * pan * 0.5
		place.call(x0, z, level, dir, true)
		var hold := float(b.get("hold", default_hold)) * hold_scale
		var wait := settle * minf(hold_scale, 1.0)
		await get_tree().create_timer(wait).timeout
		var elapsed := 0.0
		while elapsed < hold:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
			var u := clampf(elapsed / maxf(hold, 0.001), 0.0, 1.0)
			var s := u * u * (3.0 - 2.0 * u)
			scrub.call(lerpf(x0, x1, s), z, level)
		scrub.call(x1, z, level)
	finished.emit()
	get_tree().quit(0)


func _build_ui() -> void:
	_bar = ColorRect.new()
	_bar.color = Color(0.05, 0.06, 0.08, 0.78)
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -168.0
	_bar.offset_bottom = 0.0
	add_child(_bar)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_bar.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94))
	top.add_child(_title)
	_step = Label.new()
	_step.add_theme_font_size_override("font_size", 14)
	_step.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_step)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", Color(0.86, 0.86, 0.84, 0.95))
	col.add_child(_body)
	var hint := Label.new()
	hint.text = "feature tour  ·  no input  ·  exits when finished"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
	col.add_child(hint)
