class_name HourglassTool
extends Control
## The timer tool: a glass hourglass full of sand, of real physics, or a digital LED timer.
## The sand is in its own little world, drawn into a picture that scales to fit, so nothing
## around it ever moves a grain.
##
## The button in the top bar switches between the hourglass and the digital timer (see
## DigitalTimer). Holding a finger on the timer opens a menu under it (see ChoiceDrawer) with
## the gravity toggle (whether the sand follows the tilt of the phone, or runs on a timer with
## the glass held upright), the colour of the sand (the glass's ends are the tool's colour); the digital timer has the colour of its numbers instead) and the
## sound when time is up. The top button shows the icon of the kind it switches to. Letting go away from both starts the
## timer over, which tapping the tool's own icon in the toolbar again does too. All of it is
## kept with the preset.
##
## One small wheel shows the seconds left, in green. Touch it and it shows how long
## the whole glass lasts, which is what turning it sets: sand is poured in or lifted
## out to match, even while the sand runs, so it is never an amount added to what
## is running.

const WORLD_SIZE := SandGlass.VIEW_SIZE
const GLASS_TOP := 150.0
const DIRECTION_SMOOTHING := 0.25
const DEFAULT_SECONDS := 60
## The picture turns over once the glass is held this far upside down, and back
## once it is this far upright, so it does not flicker around the sideways point.
const FLIP_AT := 0.6
const FLIP_SECONDS := 0.4
const LONG_PRESS_SECONDS := 0.45
const KINDS: Array[String] = ["hourglass", "digital"]
const KIND_ICONS := {"hourglass": "hourglass", "digital": "timer"}
const TOP_ICON_SIZE := 72
## What the long press offers: the hourglass has gravity and the colour of its sand, the
## digital timer the colour of its numbers; both have the sound.
const DIGITAL_CHOICES: Array[String] = ["color", "sound"]
const SAND_CHOICES: Array[String] = ["gravity", "color", "sound"]
const DIGIT_COLORS: Array[Color] = [
	Color("#F2F2F2"), Color("#E5484D"), Color("#F5A524"), Color("#30A46C"),
	Color("#12A594"), Color("#4F7CFF"), Color("#8E4EC6"), Color("#E93D82"),
]

var preset: Preset
var store: PresetStore

var _sand: SandGlass
var _world: SubViewport
var _touch_area: Control
var _picture: TextureRect
var _middle: CenterContainer
var _digital: DigitalTimer
var _type_button: Button
var _menu: ChoiceDrawer
var _alarm_drawer: ChoiceDrawer
var _digits_drawer: ChoiceDrawer
var _sand_drawer: ChoiceDrawer
var _menu_down := false
var _press := 0
var _press_origin := Vector2.ZERO
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
	_world = SubViewport.new()
	_world.size = WORLD_SIZE
	_world.world_2d = World2D.new()
	_world.transparent_bg = true
	_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_world)
	_use_glass(_is_timed())

	_picture = TextureRect.new()
	_picture.texture = _world.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)

	# Under the wheel, so the wheel still gets its own touches.
	_touch_area = Control.new()
	_touch_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_touch_area.gui_input.connect(_on_touch_input)
	add_child(_touch_area)

	# The wheel floats over the neck of the glass, in the middle of the picture.
	_middle = CenterContainer.new()
	_middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_middle)
	_wheel = TimeWheel.new()
	_wheel.backed = true
	_wheel.resized.connect(func() -> void: _wheel.pivot_offset = _wheel.size / 2.0)
	_wheel.time_adjusted.connect(_on_time_adjusted)
	_wheel.grabbed.connect(_on_wheel_grabbed)
	_middle.add_child(_wheel)

	_digital = DigitalTimer.new()
	_digital.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_digital.color = preset.color
	_digital.digit_color = _digit_color()
	_digital.total_seconds = int(preset.data.get("seconds", DEFAULT_SECONDS))
	_digital.reset()
	_digital.total_changed.connect(_on_digital_total_changed)
	_digital.finished.connect(_on_drained)
	_digital.held.connect(_open_menu)
	_digital.hold_moved.connect(_move_menu)
	_digital.hold_released.connect(_release_menu)
	add_child(_digital)

	_build_buttons()
	_apply_kind()
	_show_time()


func _is_timed() -> bool:
	return bool(preset.data.get("timed", false))


func _is_digital() -> bool:
	return str(preset.data.get("kind", "hourglass")) == "digital"


func _alarm() -> String:
	var alarm := str(preset.data.get("alarm", TimerAlert.DEFAULT_ALARM))
	return alarm if TimerAlert.ALARMS.has(alarm) else TimerAlert.DEFAULT_ALARM


## The one button that joins the top bar: it switches between the hourglass and the digital
## timer. The rest is in the menu that a long press opens.
func _build_buttons() -> void:
	_type_button = UiStyle.icon_button(Button.new(), KIND_ICONS[_other_kind()], UiStyle.TOP_BUTTON, TOP_ICON_SIZE)
	_type_button.focus_mode = Control.FOCUS_NONE
	_type_button.accessibility_name = tr("TIMER_TYPE")
	_type_button.pressed.connect(func() -> void: _choose_kind("hourglass" if _is_digital() else "digital"))
	add_child(_type_button)

	_menu = ChoiceDrawer.new()
	_menu.close_on_release = true
	_menu.picked.connect(_on_menu_picked)
	_menu.hovered.connect(_on_menu_hovered)
	add_child(_menu)
	_alarm_drawer = ChoiceDrawer.new()
	_alarm_drawer.setup(TimerAlert.ALARMS, TimerAlert.ALARM_ICONS)
	_alarm_drawer.picked.connect(_choose_alarm)
	add_child(_alarm_drawer)
	_digits_drawer = ChoiceDrawer.new()
	_digits_drawer.setup_colors(DIGIT_COLORS)
	_digits_drawer.picked.connect(_choose_digit_color)
	add_child(_digits_drawer)
	_sand_drawer = ChoiceDrawer.new()
	_sand_drawer.setup_colors(HoldMenu.COLORS)
	_sand_drawer.picked.connect(_choose_sand_color)
	add_child(_sand_drawer)
	ActionBars.family(_menu, [_menu, _alarm_drawer, _digits_drawer, _sand_drawer])
	_setup_menu()


func _setup_menu() -> void:
	var choices := DIGITAL_CHOICES if _is_digital() else SAND_CHOICES
	_menu.setup(choices, {"gravity": "vibrate", "color": "palette", "sound": TimerAlert.ALARM_ICONS[_alarm()]}, {
		"gravity": tr("TIMER_MENU_GRAVITY"), "color": tr("HOME_MENU_COLOR"), "sound": tr("TIMER_MENU_SOUND"),
	})


## The buttons that belong in the screen's top bar, beside the back button.
func top_buttons() -> Array[Button]:
	return [_type_button]


## The kind the top button would switch to, which is the icon it shows.
func _other_kind() -> String:
	return "hourglass" if _is_digital() else "digital"


func _kind() -> String:
	return "digital" if _is_digital() else "hourglass"


## Puts a new glass of sand in the world, full for the preset's time, in place of
## any glass already there.
func _use_glass(timed: bool) -> void:
	if _sand != null:
		_world.remove_child(_sand)
		_sand.queue_free()
	_sand = HourglassSand.new()
	if timed:
		_sand.gravity_direction = Vector2.DOWN
		_sand.gravity_strength = 1.0
	_sand.sand_color = _sand_color()
	_sand.cap_color = preset.color
	_sand.position = Vector2(WORLD_SIZE.x / 2.0, GLASS_TOP)
	_sand.set_total_ms(int(preset.data.get("seconds", DEFAULT_SECONDS)) * 1000)
	_world.add_child(_sand)
	_sand.drained.connect(_on_drained)
	_finished = false


## Holding a finger on the glass opens the menu under it. Letting go away from its choices
## starts the timer over.
func _on_touch_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press += 1
			_press_origin = event.position
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_held.bind(_press, event.position))
		else:
			_press = 0
			_release_menu(event.position)
	elif event is InputEventMouseMotion:
		if _menu_down:
			_move_menu(event.position)
		elif event.position.distance_to(_press_origin) > 30.0:
			_press = 0


func _on_held(press_id: int, point: Vector2) -> void:
	if _press != press_id:
		return
	_press = 0
	_open_menu(point)


func _open_menu(point: Vector2) -> void:
	_menu_down = true
	_menu.open(point, "" if _is_digital() or _is_timed() else "gravity", true)


## The list that has popped out beside the menu, if one has.
func _open_list() -> ChoiceDrawer:
	for list in [_alarm_drawer, _digits_drawer, _sand_drawer]:
		if list.is_open:
			return list
	return null


## The finger that opened the menu moves: over the list that popped out beside it, it moves
## among its choices.
func _move_menu(point: Vector2) -> void:
	var list := _open_list()
	if list != null and list.covers(point):
		list.pointer_move(point)
		return
	if list != null:
		list.pointer_move(Vector2(-9999.0, -9999.0))
	_menu.pointer_move(point)


## The finger lifts: over a list it picks from it, over the menu's own choices it does that
## one, and anywhere else it starts the timer over. The menu and its list go together.
func _release_menu(point: Vector2) -> void:
	if not _menu_down:
		return
	_menu_down = false
	var list := _open_list()
	if list != null and list.covers(point):
		list.pointer_up(point)
	elif _menu.item_at(point) < 0:
		Haptics.pulse(30, 0.5)
		retap()
	else:
		_menu.pointer_up(point)
	_menu.close()
	_alarm_drawer.close()
	_digits_drawer.close()
	_sand_drawer.close()


func _on_menu_hovered(kind: String) -> void:
	if kind == "":
		return
	var wanted: ChoiceDrawer = {"sound": _alarm_drawer, "color": _digits_drawer if _is_digital() else _sand_drawer}.get(kind)
	for list in [_alarm_drawer, _digits_drawer, _sand_drawer]:
		if list != wanted:
			list.close()
	if wanted != null and not wanted.is_open:
		# The finger came up to the menu, so the next list goes on up above it.
		var current := _alarm() if wanted == _alarm_drawer else str(_digit_color_index() if wanted == _digits_drawer else HoldMenu.color_index(_sand_color()))
		wanted.open_below(_menu.rect(), current, _menu_down, true)


func _on_menu_picked(kind: String) -> void:
	if kind == "gravity":
		_on_gravity_toggled(_is_timed())


func _digit_color() -> Color:
	var saved: Variant = preset.data.get("digits", DIGIT_COLORS[0])
	return saved if saved is Color else DIGIT_COLORS[0]


## The sand: its own colour if one was picked, else the opposite of the tool's colour.
func _sand_color() -> Color:
	var saved: Variant = preset.data.get("sand", null)
	return saved if saved is Color else HourglassArt.complement(preset.color)


func _choose_sand_color(kind: String) -> void:
	var color := HoldMenu.COLORS[int(kind)]
	preset.data["sand"] = color
	store.preset_changed()
	for mass in _sand.find_children("*", "SandMass", true, false):
		mass.recolor(color)


func _digit_color_index() -> int:
	return DIGIT_COLORS.find(_digit_color())


func _choose_digit_color(kind: String) -> void:
	var color := DIGIT_COLORS[int(kind)]
	preset.data["digits"] = color
	store.preset_changed()
	_digital.digit_color = color


func _on_gravity_toggled(follows_tilt: bool) -> void:
	var timed := not follows_tilt
	if timed == _is_timed():
		return
	preset.data["timed"] = timed
	store.preset_changed()
	_use_glass(timed)
	# The wheel stops turning with the phone, and the next glass starts upright.
	if _turn != null:
		_turn.kill()
	_turned = false
	_wheel.rotation = 0.0
	_direction = Vector2.DOWN
	_strength = 0.0


func _choose_alarm(alarm: String) -> void:
	preset.data["alarm"] = alarm
	store.preset_changed()
	_setup_menu()
	SoundBank.play_once(self, alarm)


func _choose_kind(kind: String) -> void:
	if kind == _kind():
		return
	preset.data["kind"] = kind
	store.preset_changed()
	_apply_kind()


## Shows the hourglass or the digital display, whichever the preset is set to, and puts the
## other one to sleep. A kind that is switched to starts over.
func _apply_kind() -> void:
	var digital := _is_digital()
	_picture.visible = not digital
	_middle.visible = not digital
	_touch_area.visible = not digital
	_digital.visible = digital
	_world.render_target_update_mode = SubViewport.UPDATE_DISABLED if digital else SubViewport.UPDATE_ALWAYS
	UiStyle.icon_button(_type_button, KIND_ICONS[_other_kind()], 0.0, TOP_ICON_SIZE)
	_setup_menu()
	_finished = false
	if digital:
		_sand.frozen = true
		_digital.total_seconds = int(preset.data.get("seconds", DEFAULT_SECONDS))
		_digital.reset()
	elif _sand.frozen:
		# Coming back from the digital timer: a fresh glass.
		_use_glass(_is_timed())


## A swipe across the glass goes to another tool, unless its drawer is out.
func accepts_swipe() -> bool:
	return not _menu_down and not _menu.is_open and _open_list() == null


## A swipe has taken the finger: a press waiting to become a long press is dropped.
func cancel_press() -> void:
	_press = 0
	_digital.cancel_press()


func retap() -> void:
	if _is_digital():
		_digital.reset()
	else:
		_sand.reset()
	_finished = false


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


func _process(_delta: float) -> void:
	if _is_digital():
		_sand.muted = true
		DisplayServer.screen_set_keep_on(_digital.running)
		return
	_sand.muted = not is_visible_in_tree()
	if not _is_timed():
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


func _on_digital_total_changed(seconds: int) -> void:
	preset.data["seconds"] = seconds
	store.preset_changed()


func _on_drained() -> void:
	if _finished:
		return
	_finished = true
	TimerAlert.chime(self, _alarm())
