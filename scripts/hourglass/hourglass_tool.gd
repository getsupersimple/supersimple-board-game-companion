class_name HourglassTool
extends Control
## A glass hourglass full of sand that runs on the phone's tilt. Held upright
## the sand runs down, held upside down it runs back up, and held on its side
## (or flat) it stops. The sand is physics in its own little world, drawn into a
## picture that scales to fit, so nothing around it ever moves a grain.
##
## One small wheel shows the time left and counts down as the sand runs. Turn it,
## even while the sand runs, and sand is poured in or lifted out to match.

const WORLD_SIZE := HourglassSand.VIEW_SIZE
const GLASS_TOP := 150.0
const DIRECTION_SMOOTHING := 0.25
const DEFAULT_SECONDS := 60

var preset: Preset
var store: PresetStore

var _sand: HourglassSand
var _wheel: TimeWheel
var _finished := false
## For trying it without a phone: the arrow keys hold the glass in a direction.
var _key_gravity: Variant = null
var _direction := Vector2.DOWN
var _strength := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	add_child(column)

	var world := SubViewport.new()
	world.size = WORLD_SIZE
	world.world_2d = World2D.new()
	world.transparent_bg = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	_sand = HourglassSand.new()
	_sand.position = Vector2(WORLD_SIZE.x / 2.0, GLASS_TOP)
	_sand.sand_color = preset.color
	_sand.set_total_ms(int(preset.data.get("seconds", DEFAULT_SECONDS)) * 1000)
	world.add_child(_sand)
	_sand.drained.connect(_on_drained)

	var picture := TextureRect.new()
	picture.texture = world.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(picture)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 40)
	column.add_child(controls)
	_wheel = TimeWheel.new()
	_wheel.time_adjusted.connect(_on_time_adjusted)
	controls.add_child(_wheel)
	var reset := SingleTimerTool.make_reset_button(_reset)
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(reset)
	_show_time()


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


func _process(_delta: float) -> void:
	_follow_gravity()
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


func _show_time() -> void:
	_wheel.alert = _finished
	_wheel.show_seconds(int(ceil(_sand.remaining_ms() / 1000.0)))


func _on_time_adjusted(delta_seconds: int) -> void:
	_sand.add_time(delta_seconds * 1000)
	preset.data["seconds"] = maxi(int(round(_sand.total_ms() / 1000.0)), 1)
	store.preset_changed()


func _on_drained() -> void:
	if _finished:
		return
	_finished = true
	TimerAlert.sound_the_alarm(self)


func _reset() -> void:
	_sand.set_total_ms(int(preset.data.get("seconds", DEFAULT_SECONDS)) * 1000)
	_finished = false
