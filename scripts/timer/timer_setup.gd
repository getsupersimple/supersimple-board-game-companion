class_name TimerSetup
extends HBoxContainer
## Sets up a timer before it starts: minute and second wheels, an infinity toggle
## for counting up, and optionally a toggle for resetting every turn.

signal changed

const TOGGLE_SIZE := 150

var limited := true
var seconds := 60
var reset_each_turn := false

var _minutes_wheel: WheelPicker
var _seconds_wheel: WheelPicker
var _infinity_button: Button
var _repeat_button: Button
var _with_repeat := false
var _with_infinity := true


func configure(data: Dictionary, with_repeat_toggle: bool, with_infinity_toggle: bool = true) -> void:
	limited = bool(data.get("limited", true))
	seconds = clampi(int(data.get("seconds", 60)), 1, 99 * 60 + 59)
	reset_each_turn = bool(data.get("reset_each_turn", false))
	_with_repeat = with_repeat_toggle
	_with_infinity = with_infinity_toggle
	if is_inside_tree():
		_refresh()


func to_data() -> Dictionary:
	return {"limited": limited, "seconds": seconds, "reset_each_turn": reset_each_turn}


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 24)
	_minutes_wheel = _make_wheel(99)
	_seconds_wheel = _make_wheel(59)
	add_child(_minutes_wheel)
	var colon := Label.new()
	colon.text = ":"
	colon.add_theme_font_size_override("font_size", 72)
	add_child(colon)
	add_child(_seconds_wheel)
	_infinity_button = _make_toggle("infinity", "TIMER_COUNT_UP")
	_infinity_button.toggled.connect(func(on: bool) -> void:
		limited = not on
		_commit())
	add_child(_infinity_button)
	_repeat_button = _make_toggle("repeat", "TIMER_RESET_EACH_TURN")
	_repeat_button.toggled.connect(func(on: bool) -> void:
		reset_each_turn = on
		_commit())
	add_child(_repeat_button)
	_refresh()


func _make_wheel(top: int) -> WheelPicker:
	var wheel := WheelPicker.new()
	wheel.max_value = top
	wheel.value_changed.connect(func(_value: int) -> void:
		seconds = maxi(_minutes_wheel.value * 60 + _seconds_wheel.value, 1)
		_commit())
	return wheel


func _make_toggle(icon_name: String, label_key: String) -> Button:
	var button := UiStyle.dark_toggle(Button.new(), TOGGLE_SIZE, icon_name)
	button.accessibility_name = tr(label_key)
	return button


func _refresh() -> void:
	_minutes_wheel.set_value(seconds / 60)
	_seconds_wheel.set_value(seconds % 60)
	_infinity_button.set_pressed_no_signal(not limited)
	_repeat_button.set_pressed_no_signal(reset_each_turn)
	_repeat_button.visible = _with_repeat
	_infinity_button.visible = _with_infinity
	_minutes_wheel.dimmed = not limited
	_seconds_wheel.dimmed = not limited
	_minutes_wheel.queue_redraw()
	_seconds_wheel.queue_redraw()


func _commit() -> void:
	_refresh()
	changed.emit()
