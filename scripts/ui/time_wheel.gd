class_name TimeWheel
extends Control
## One small wheel showing a time, like a phone's clock app. Drag it up to add
## time and down to take it away: slowly for 5 seconds at a time, and with a
## quick flick for half a minute or a minute at a time. It can show a time that
## is counting down, so it is fine to turn it while the time runs.

signal time_adjusted(delta_seconds: int)
## A finger has touched the wheel, or let go of it.
signal grabbed(held: bool)

const ROW_HEIGHT := 84.0
const VISIBLE_ROWS := 3
const FONT_SIZE := 76
const SIDE_FONT_SIZE := 52
const MAX_SECONDS := 99 * 60 + 59
const SLOW_STEP := 5
const MEDIUM_STEP := 30
const FAST_STEP := 60
const MEDIUM_FLICK := 1500.0
const FAST_FLICK := 3500.0

var seconds := 0
## Held down by a finger, so the clock does not fight it.
var dragging := false
## Time is up: the time is drawn in red.
var alert := false
## The wheel is showing a time running out, not one being set, so it is drawn in
## another colour.
var counting := false
## A faint see-through panel behind the numbers, for a wheel that sits over a picture.
var backed := false

var _drag_remainder := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(340.0, ROW_HEIGHT * VISIBLE_ROWS)
	mouse_filter = Control.MOUSE_FILTER_STOP
	accessibility_name = "Time"


## Shows a time, unless a finger is turning the wheel.
func show_seconds(value: int, force := false) -> void:
	if dragging and not force:
		return
	seconds = clampi(value, 0, MAX_SECONDS)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			_drag_remainder = 0.0
			queue_redraw()
			grabbed.emit(dragging)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust(SLOW_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust(-SLOW_STEP)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_remainder += event.relative.y
		var rows := int(_drag_remainder / ROW_HEIGHT)
		if rows != 0:
			_drag_remainder -= rows * ROW_HEIGHT
			_adjust(-rows * _step_for(event.velocity.y))


func _step_for(speed: float) -> int:
	if absf(speed) > FAST_FLICK:
		return FAST_STEP
	if absf(speed) > MEDIUM_FLICK:
		return MEDIUM_STEP
	return SLOW_STEP


func _adjust(delta: int) -> void:
	delta = clampi(delta, -seconds, MAX_SECONDS - seconds)
	if delta == 0:
		return
	seconds += delta
	queue_redraw()
	time_adjusted.emit(delta)


func _draw() -> void:
	var font := get_theme_default_font()
	var middle := size.y / 2.0
	if backed:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.98, 0.96, 0.92, 0.3)
		panel.set_corner_radius_all(40)
		draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0, 0, 0, 0.08)
	band.set_corner_radius_all(28)
	draw_style_box(band, Rect2(0.0, middle - ROW_HEIGHT / 2.0, size.x, ROW_HEIGHT))
	var ink := Color("#E5484D") if alert else (Color("#1F8A70") if counting else UiStyle.INK)
	for offset in range(-1, 2):
		var shown := seconds + offset * SLOW_STEP
		if shown < 0 or shown > MAX_SECONDS:
			continue
		var text := TimeFormat.format(shown * 1000, false)
		var big := offset == 0
		var font_size := FONT_SIZE if big else SIDE_FONT_SIZE
		var colour := ink if big else UiStyle.INK
		if not big:
			colour.a = 0.3
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var y := middle + offset * ROW_HEIGHT + _drag_remainder
		draw_string(font, Vector2((size.x - width) / 2.0, y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
