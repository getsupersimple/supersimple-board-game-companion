class_name ClockSide
extends Control
## One side of a chess clock: a dark case with a pale LCD window of seven-segment
## digits, a little lamp that lights for the player whose turn it is, and a small
## symbol under the digits. The whole side is the button. It can be turned round
## for the player sitting on the other side of the table.

signal tapped
## The finger came off, wherever it ended up.
signal released

const CASE_COLOR := Color("#2A2A2D")
const CASE_EDGE := Color("#4A4A4F")
const LCD_BRIGHT := Color("#CBD6B8")
const LCD_DIM := Color("#97A088")
const LCD_INK := Color("#1B2216")
const LAMP_OFF := Color("#3A3A3F")
const FLAG_RED := Color("#E5484D")
const CASE_MARGIN := 36.0
const SYMBOL_SIZE := 72.0

## Segments of a digit, as a, b, c, d, e, f, g: top, top right, bottom right,
## bottom, bottom left, top left and middle.
const DIGITS := {
	"0": [1, 1, 1, 1, 1, 1, 0], "1": [0, 1, 1, 0, 0, 0, 0], "2": [1, 1, 0, 1, 1, 0, 1],
	"3": [1, 1, 1, 1, 0, 0, 1], "4": [0, 1, 1, 0, 0, 1, 1], "5": [1, 0, 1, 1, 0, 1, 1],
	"6": [1, 0, 1, 1, 1, 1, 1], "7": [1, 1, 1, 0, 0, 0, 0], "8": [1, 1, 1, 1, 1, 1, 1],
	"9": [1, 1, 1, 1, 0, 1, 1],
}

var upside_down := false
## The lamp's colour when it is lit.
var lamp_color := Color.WHITE

var _text := ""
var _symbol := ""
var _lit := false
var _awake := true
var _flagged := false
var _pulse: Tween


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, 200.0)


## How the side looks: whether its lamp is lit, whether the LCD is switched on
## (a waiting player's is dimmed), whether time is up on it, and the symbol shown.
func look(lamp_lit: bool, awake: bool, flagged: bool, symbol: String) -> void:
	_lit = lamp_lit
	_awake = awake
	_flagged = flagged
	_symbol = symbol
	queue_redraw()


func set_text(text: String) -> void:
	if text == _text:
		return
	_text = text
	queue_redraw()


## Flashes the whole side, to say that time is up.
func pulse(on: bool) -> void:
	if _pulse != null:
		_pulse.kill()
	self_modulate = Color.WHITE
	modulate = Color.WHITE
	if on:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "modulate", Color(1, 1, 1, 0.6), 0.35)
		_pulse.tween_property(self, "modulate", Color.WHITE, 0.35)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tapped.emit()
		else:
			released.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if upside_down:
		draw_set_transform(size, PI, Vector2.ONE)
	var case := StyleBoxFlat.new()
	case.bg_color = CASE_COLOR
	case.border_color = CASE_EDGE
	case.set_border_width_all(4)
	case.set_corner_radius_all(48)
	draw_style_box(case, Rect2(Vector2.ZERO, size))

	# The lamp sits at the top edge of the case, above the window.
	var lamp_at := Vector2(size.x / 2.0, CASE_MARGIN * 0.5 + 6.0)
	var lamp := FLAG_RED if _flagged else (lamp_color if _lit else LAMP_OFF)
	if _lit or _flagged:
		draw_circle(lamp_at, 22.0, Color(lamp, 0.25))
	draw_circle(lamp_at, 12.0, lamp)

	var window := Rect2(Vector2(CASE_MARGIN, CASE_MARGIN + 14.0), size - Vector2(CASE_MARGIN * 2.0, CASE_MARGIN * 2.0 + 14.0))
	var glass := StyleBoxFlat.new()
	glass.bg_color = LCD_BRIGHT if _awake else LCD_DIM
	glass.set_corner_radius_all(28)
	draw_style_box(glass, window)

	var symbol_room := SYMBOL_SIZE + 16.0 if not _symbol.is_empty() else 0.0
	var digits_area := Rect2(window.position + Vector2(24.0, 24.0), window.size - Vector2(48.0, 48.0 + symbol_room))
	_draw_digits(digits_area)
	if not _symbol.is_empty():
		var icon := IconLibrary.get_icon(_symbol)
		var spot := Rect2(Vector2(window.get_center().x - SYMBOL_SIZE / 2.0, window.end.y - SYMBOL_SIZE - 20.0), Vector2(SYMBOL_SIZE, SYMBOL_SIZE))
		draw_texture_rect(icon, spot, false, Color(LCD_INK, 0.75))


## The time, in seven-segment digits as large as the window allows, with the unlit
## segments faintly showing as on a real LCD.
func _draw_digits(area: Rect2) -> void:
	var count := 0
	var colons := 0
	for character in _text:
		if character == ":":
			colons += 1
		else:
			count += 1
	# A digit is 0.55 as wide as it is tall, with a gap; a colon is 0.28.
	var width_in_heights := count * 0.7 + colons * 0.34
	var height := minf(area.size.y, area.size.x / maxf(width_in_heights, 0.1))
	var thick := height * 0.13
	var x := area.position.x + (area.size.x - width_in_heights * height) / 2.0
	var top := area.position.y + (area.size.y - height) / 2.0
	var ghost := Color(LCD_INK, 0.07)
	var ink := LCD_INK if _awake else Color(LCD_INK, 0.55)
	for character in _text:
		if character == ":":
			var gap := height * 0.34
			for dot_y in [0.32, 0.68]:
				draw_rect(Rect2(x + gap / 2.0 - thick / 2.0, top + height * dot_y - thick / 2.0, thick, thick), ink)
			x += gap
			continue
		_draw_digit(Vector2(x, top), height, thick, character, ink, ghost)
		x += height * 0.7


func _draw_digit(origin: Vector2, height: float, thick: float, character: String, ink: Color, ghost: Color) -> void:
	var width := height * 0.55
	var gap := thick * 0.6
	var middle := height / 2.0
	var lines := [
		[Vector2(gap, 0.0), Vector2(width - gap, 0.0)],
		[Vector2(width, gap), Vector2(width, middle - gap)],
		[Vector2(width, middle + gap), Vector2(width, height - gap)],
		[Vector2(gap, height), Vector2(width - gap, height)],
		[Vector2(0.0, middle + gap), Vector2(0.0, height - gap)],
		[Vector2(0.0, gap), Vector2(0.0, middle - gap)],
		[Vector2(gap, middle), Vector2(width - gap, middle)],
	]
	var on: Array = DIGITS.get(character, DIGITS["8"])
	for i in 7:
		var from: Vector2 = origin + lines[i][0]
		var to: Vector2 = origin + lines[i][1]
		draw_colored_polygon(_segment(from, to, thick), ink if on[i] == 1 else ghost)


## A hexagonal bar between two points, pointed at both ends.
func _segment(from: Vector2, to: Vector2, thick: float) -> PackedVector2Array:
	var along := (to - from).normalized()
	var across := along.orthogonal() * (thick / 2.0)
	var inset := along * (thick / 2.0)
	return PackedVector2Array([from, from + inset + across, to - inset + across, to, to - inset - across, from + inset - across])
