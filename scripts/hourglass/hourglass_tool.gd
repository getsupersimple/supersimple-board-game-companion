class_name HourglassTool
extends Control
## A glass hourglass full of sand that runs on the phone's tilt. Held upright
## the sand runs down, held upside down it runs back up, and held on its side
## (or flat) it stops. The sand is physics in its own little world, drawn into a
## picture that scales to fit, so nothing around it ever moves a grain.
##
## One small wheel shows the seconds left, in green. Touch it and it shows how long
## the whole glass lasts, which is what turning it sets: sand is poured in or lifted
## out to match, even while the sand runs, so it is never an amount added to what
## is running.

const WORLD_SIZE := HourglassSand.VIEW_SIZE
const GLASS_TOP := 150.0
const DIRECTION_SMOOTHING := 0.25
const DEFAULT_SECONDS := 60
## The picture turns over once the glass is held this far upside down, and back
## once it is this far upright, so it does not flicker around the sideways point.
const FLIP_AT := 0.6
const FLIP_SECONDS := 0.4

var preset: Preset
var store: PresetStore

var _sand: HourglassSand
var _wheel: TimeWheel
var _finished := false
## For trying it without a phone: the arrow keys hold the glass in a direction.
var _key_gravity: Variant = null
var _direction := Vector2.DOWN
var _strength := 0.0
var _turned := false
var _turn: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var world := SubViewport.new()
	world.size = WORLD_SIZE
	world.world_2d = World2D.new()
	world.transparent_bg = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	_sand = HourglassSand.new()
	_sand.position = Vector2(WORLD_SIZE.x / 2.0, GLASS_TOP)
	_sand.cap_color = preset.color
	_sand.set_total_ms(int(preset.data.get("seconds", DEFAULT_SECONDS)) * 1000)
	world.add_child(_sand)
	_sand.drained.connect(_on_drained)

	var picture := TextureRect.new()
	picture.texture = world.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)

	# The wheel floats over the neck of the glass, in the middle of the picture.
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	_wheel = TimeWheel.new()
	_wheel.backed = true
	_wheel.resized.connect(func() -> void: _wheel.pivot_offset = _wheel.size / 2.0)
	_wheel.time_adjusted.connect(_on_time_adjusted)
	_wheel.grabbed.connect(_on_wheel_grabbed)
	middle.add_child(_wheel)
	_show_time()


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


func _process(_delta: float) -> void:
	_sand.muted = not is_visible_in_tree()
	_follow_gravity()
	_turn_with_the_glass()
	if _finished and _sand.upstream_count() > 0:
		_finished = false
	_show_time()
	DisplayServer.screen_set_keep_on(_sand.is_flowing() and not _finished)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_DOWN:
				_key_gravity = Vector2.DOWN
			KEY_UP:
				_key_gravity = Vector2.UP
			KEY_LEFT:
				_key_gravity = Vector2.LEFT
			KEY_RIGHT:
				_key_gravity = Vector2.RIGHT
			KEY_SPACE:
				_key_gravity = Vector2.ZERO


## Gravity on the glass, from the phone: what pulls along the screen's own axes.
## Held flat, almost none of gravity lies along the screen, so the sand rests.
func _follow_gravity() -> void:
	var target_direction := _direction
	var target_strength := 0.0
	var sensor := Input.get_gravity()
	if _key_gravity != null:
		# Space lays the glass flat: no gravity along the screen at all.
		if _key_gravity != Vector2.ZERO:
			target_direction = _key_gravity
			target_strength = 1.0
	elif sensor.length() > 1.0:
		var along_screen := Vector2(sensor.x, -sensor.y)
		target_strength = clampf(along_screen.length() / sensor.length(), 0.0, 1.0)
		if target_strength > 0.1:
			target_direction = along_screen.normalized()
	_direction = _direction.lerp(target_direction, DIRECTION_SMOOTHING).normalized()
	_strength = lerpf(_strength, target_strength, DIRECTION_SMOOTHING)
	_sand.gravity_direction = _direction
	_sand.gravity_strength = _strength


## When the phone is turned upside down the wheel turns with it, so the time stays
## the right way up for the player. The glass itself stays as it is.
func _turn_with_the_glass() -> void:
	var held_up := -_direction.y * _strength
	var wanted := _turned
	if held_up > FLIP_AT:
		wanted = true
	elif held_up < -FLIP_AT:
		wanted = false
	if wanted == _turned:
		return
	_turned = wanted
	if _turn != null:
		_turn.kill()
	_turn = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_property(_wheel, "rotation", PI if _turned else 0.0, FLIP_SECONDS)


## Left alone, the wheel shows the seconds still to run, in its own colour. Under a
## finger it shows the whole time of the glass, which is what turning it sets.
func _show_time() -> void:
	_wheel.alert = _finished
	_wheel.counting = not _wheel.dragging
	if not _wheel.dragging:
		_wheel.show_seconds(int(ceil(_sand.remaining_ms() / 1000.0)))


func _on_wheel_grabbed(held: bool) -> void:
	_sand.frozen = held
	_wheel.counting = not held
	if held:
		_wheel.show_seconds(int(round(_sand.total_ms() / 1000.0)), true)


## The wheel says how long the glass lasts, all told: that is the amount of sand in it.
func _on_time_adjusted(_delta_seconds: int) -> void:
	_sand.set_duration(_wheel.seconds * 1000)
	preset.data["seconds"] = maxi(_wheel.seconds, 1)
	store.preset_changed()


func _on_drained() -> void:
	if _finished:
		return
	_finished = true
	TimerAlert.chime(self)
