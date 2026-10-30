class_name DigitalTimer
extends Control
## A countdown on an LED display: a black panel in a border of the tool's colour, with the time
## in lit segments (white unless given a colour). Tap anywhere to start or pause, hold for the owner's menu, and
## drag up or down to set how long it counts, like the wheel in the hourglass.

signal finished
## A finger has been held on it for a moment; what that does is up to the owner. The same
## finger's moves and lift follow, in the timer's own coordinates.
signal held(at: Vector2)
signal hold_moved(at: Vector2)
signal hold_released(at: Vector2)
## The time the timer starts from was changed, in seconds.
signal total_changed(seconds: int)

const LONG_PRESS_SECONDS := 0.45
const TAP_SLOP := 30.0
const ROW_HEIGHT := 84.0
const MAX_SECONDS := TimeWheel.MAX_SECONDS
const BORDER := 14.0
const GLASS := Color("#09090A")
## Which of the seven segments, a to g, each digit lights.
const DIGITS := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]

var color := Color("#E5484D"):
	set(value):
		color = value
		queue_redraw()
## The colour of the lit digits.
var digit_color := Color("#F2F2F2"):
	set(value):
		digit_color = value
		queue_redraw()
var total_seconds := 60
var running := false
## True from the first start until it is started over or runs out.
var started := false
var is_finished := false

var _remaining_ms := 60000
var _last_tick := 0
var _press := 0
var _down := false
var _pressed_at := Vector2.ZERO
var _moved := false
var _long := false
var _drag_remainder := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	accessibility_name = "Timer"


func set_total(seconds: int) -> void:
	total_seconds = clampi(seconds, 1, MAX_SECONDS)
	reset()


## Back to the full time, stopped.
func reset() -> void:
	running = false
	started = false
	is_finished = false
	_remaining_ms = total_seconds * 1000
	queue_redraw()


func remaining_ms() -> int:
	return _remaining_ms


## Starts it, or pauses it. After it has run out, it starts over first.
func toggle() -> void:
	if is_finished:
		reset()
	if _remaining_ms <= 0:
		return
	running = not running
	started = true
	_last_tick = Time.get_ticks_msec()
	queue_redraw()


func _process(_delta: float) -> void:
	if running:
		var now := Time.get_ticks_msec()
		_remaining_ms = maxi(_remaining_ms - (now - _last_tick), 0)
		_last_tick = now
		if _remaining_ms == 0:
			running = false
			is_finished = true
			finished.emit()
	if is_visible_in_tree() and (running or is_finished or started):
		queue_redraw()


## Adds or takes away seconds from the time it counts from, and from the time left with it.
func adjust(delta_seconds: int) -> void:
	delta_seconds = clampi(delta_seconds, 1 - total_seconds, MAX_SECONDS - total_seconds)
	if delta_seconds == 0:
		return
	var untouched := not started
	total_seconds += delta_seconds
	if untouched:
		_remaining_ms = total_seconds * 1000
	else:
		_remaining_ms = clampi(_remaining_ms + delta_seconds * 1000, 0, total_seconds * 1000)
	if is_finished and _remaining_ms > 0:
		is_finished = false
	queue_redraw()
	total_changed.emit(total_seconds)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_moved = false
			_long = false
			_drag_remainder = 0.0
			_pressed_at = event.position
			_press += 1
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_held.bind(_press))
		elif _down:
			_down = false
			_press = 0
			if _long:
				hold_released.emit(event.position)
			elif not _moved:
				toggle()
	elif event is InputEventMouseMotion and _down:
		if _long:
			hold_moved.emit(event.position)
			return
		if not _moved and event.position.distance_to(_pressed_at) > TAP_SLOP:
			_moved = true
			_press = 0
		if _moved and not _long:
			_drag_remainder += event.relative.y
			var rows := int(_drag_remainder / ROW_HEIGHT)
			if rows != 0:
				_drag_remainder -= rows * ROW_HEIGHT
				adjust(-rows * TimeWheel.step_for(event.velocity.y))


## A swipe has taken the finger: it neither taps nor becomes a long press.
func cancel_press() -> void:
	_press = 0
	_moved = true


func _on_held(press_id: int) -> void:
	if _press != press_id or not _down:
		return
	_press = 0
	_long = true
	held.emit(_pressed_at)


## The display's text as digits: minutes and seconds, always four.
static func digits_for(ms: int) -> Array[int]:
	var total := int(ceil(ms / 1000.0))
	var minutes := mini(total / 60, 99)
	var seconds := total % 60
	return [minutes / 10, minutes % 10, seconds / 10, seconds % 10]


func _draw() -> void:
	var panel := UiStyle.box(GLASS, 56)
	panel.set_border_width_all(int(BORDER))
	panel.border_color = color
	var area := Rect2(Vector2(40.0, 0.0), Vector2(maxf(size.x - 80.0, 10.0), 0.0))
	var digit_width := area.size.x / 7.3
	var digit_height := digit_width * 1.8
	area.size.y = digit_height + digit_width * 1.2
	area.position.y = (size.y - area.size.y) / 2.0
	draw_style_box(panel, area)
	var digits := digits_for(_remaining_ms)
	var blink := int(Time.get_ticks_msec() / 500) % 2 == 0
	var shown := true
	if is_finished:
		shown = int(Time.get_ticks_msec() / 250) % 2 == 0
	elif started and not running:
		shown = blink
	var thickness := digit_width * 0.2
	var x := area.position.x + digit_width * 0.6
	var y := area.position.y + (area.size.y - digit_height) / 2.0
	for i in 4:
		_draw_digit(Rect2(x, y, digit_width, digit_height), thickness, digits[i], shown)
		x += digit_width + digit_width * 0.5
		if i == 1:
			_draw_colon(Vector2(x + digit_width * 0.05, y), digit_width, digit_height, thickness, not running or blink)
			x += digit_width * 0.6


## Unlit segments: the same colour, nearly black.
func _faint() -> Color:
	return digit_color.darkened(0.88)


func _draw_colon(at: Vector2, digit_width: float, digit_height: float, thickness: float, lit: bool) -> void:
	var tint := digit_color if lit else _faint()
	for fraction in [0.3, 0.7]:
		draw_rect(Rect2(at.x - thickness / 2.0, at.y + digit_height * fraction - thickness / 2.0, thickness, thickness), tint)


func _draw_digit(rect: Rect2, thickness: float, digit: int, shown: bool) -> void:
	var lit: String = DIGITS[digit]
	for segment in "abcdefg":
		var on := shown and lit.contains(segment)
		draw_colored_polygon(_segment(rect, thickness, segment), digit_color if on else _faint())


## The six corners of one of the seven segments of a digit drawn in `rect`.
static func _segment(rect: Rect2, thickness: float, which: String) -> PackedVector2Array:
	var half := thickness / 2.0
	var gap := thickness * 0.12
	var left := rect.position.x + half
	var right := rect.end.x - half
	var top := rect.position.y + half
	var middle := rect.position.y + rect.size.y / 2.0
	var bottom := rect.end.y - half
	match which:
		"a":
			return _across(left + gap, right - gap, top, half)
		"g":
			return _across(left + gap, right - gap, middle, half)
		"d":
			return _across(left + gap, right - gap, bottom, half)
		"f":
			return _upright(left, top + gap, middle - gap, half)
		"b":
			return _upright(right, top + gap, middle - gap, half)
		"e":
			return _upright(left, middle + gap, bottom - gap, half)
	return _upright(right, middle + gap, bottom - gap, half)


static func _across(from: float, to: float, y: float, half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(from, y), Vector2(from + half, y - half), Vector2(to - half, y - half),
		Vector2(to, y), Vector2(to - half, y + half), Vector2(from + half, y + half)])


static func _upright(x: float, from: float, to: float, half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, from), Vector2(x + half, from + half), Vector2(x + half, to - half),
		Vector2(x, to), Vector2(x - half, to - half), Vector2(x - half, from + half)])
