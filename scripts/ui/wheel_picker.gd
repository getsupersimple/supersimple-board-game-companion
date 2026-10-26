class_name WheelPicker
extends Control
## A number wheel, like a phone's clock app: drag up or down to turn it. It wraps
## around at both ends and works without the keyboard.

signal value_changed(value: int)

const ROW_HEIGHT := 96.0
const VISIBLE_ROWS := 3
const FONT_SIZE := 72

var min_value := 0
var max_value := 59
var value := 0
var dimmed := false

var _drag_remainder := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(150.0, ROW_HEIGHT * VISIBLE_ROWS)
	mouse_filter = Control.MOUSE_FILTER_STOP
	accessibility_name = "Wheel"


func set_value(new_value: int, notify: bool = false) -> void:
	value = clampi(new_value, min_value, max_value)
	queue_redraw()
	if notify:
		value_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step(-1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_remainder += event.relative.y
		var rows := int(_drag_remainder / ROW_HEIGHT)
		if rows != 0:
			_drag_remainder -= rows * ROW_HEIGHT
			_step(-rows)
	elif event is InputEventMouseButton and not event.pressed:
		_drag_remainder = 0.0
		queue_redraw()


func _step(rows: int) -> void:
	var span := max_value - min_value + 1
	value = min_value + posmod(value - min_value + rows, span)
	queue_redraw()
	value_changed.emit(value)


func _draw() -> void:
	var font := get_theme_default_font()
	var span := max_value - min_value + 1
	var middle := size.y / 2.0
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0, 0, 0, 0.08)
	band.set_corner_radius_all(24)
	draw_style_box(band, Rect2(0.0, middle - ROW_HEIGHT / 2.0, size.x, ROW_HEIGHT))
	for offset in range(-1, 2):
		var shown := min_value + posmod(value - min_value + offset, span)
		var y := middle + offset * ROW_HEIGHT + _drag_remainder
		var fade := 1.0 - minf(absf(y - middle) / ROW_HEIGHT, 1.0) * 0.7
		var colour := Color("#1C1C1E")
		colour.a = fade * (0.35 if dimmed else 1.0)
		var text := "%02d" % shown
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE).x
		draw_string(font, Vector2((size.x - width) / 2.0, y + FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)
