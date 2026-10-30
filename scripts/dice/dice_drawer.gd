class_name DiceDrawer
extends Control
## The drawer that adds a die. It hangs under the + button as a column naming each kind
## plainly: D2, D4, D6 and so on. Drag a finger down onto one and let go to add
## it in a random colour. Keep a finger on it and a second drawer slides out to the
## side with the colours; slide onto one and let go to add the die in that colour.
##
## A press on the + button that is held opens it already under the finger, so the
## whole thing is one movement, and the drawer goes away after the pick. A quick tap
## opens it to be touched afterwards, and then it stays open for as many dice as are
## wanted, until a tap lands outside it.

## A die or a coin was chosen. The colour is null for a random one.
signal picked(sides: int, color: Variant)
signal closed

const COLUMN_WIDTH := 124.0
const ROW_HEIGHT := 124.0
const SWATCH_SIZE := 72.0
const SWATCH_GAP := 10.0
const GAP := 8.0
## A finger kept on a die this long pulls the colours out.
const DWELL_SECONDS := 0.4
## Dice are this far apart in the picture, in table units, so a die has room to turn.
const LABEL_SIZE := 40
const SLIDE_SECONDS := 0.18
const SLIDE_DISTANCE := 60.0

var sides_list: Array[int] = []
var colors: Array[Color] = []
var is_open := false

var _anchor: Control
var _column_position := Vector2.ZERO
var _row := -1
var _swatch := -1
var _down := false
## The first release after a held press from the + button leaves the drawer open.
var _from_drag := false
## Opened by a tap: stays open after a die is picked.
var _sticky := false
var _dwell := 0.0
var _colors_row := -1
var _slide := 0.0
var _slide_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(sides: Array[int], palette: Array[Color]) -> void:
	sides_list = sides
	colors = palette


## Shows the drawer under `anchor`, lined up with its right edge. `held` says a finger
## is already down, having come from a long press on the anchor.
func open(anchor: Control, held: bool) -> void:
	ActionBars.opening(self)
	_anchor = anchor
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var corner := anchor.global_position - global_position
	var top_left := Vector2(corner.x + anchor.size.x - COLUMN_WIDTH, corner.y + anchor.size.y + GAP)
	_column_position = top_left
	is_open = true
	_down = held
	_from_drag = held
	_sticky = not held
	_row = -1
	_swatch = -1
	_colors_row = -1
	_slide = 0.0
	_dwell = 0.0
	visible = true
	queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_down = false
	visible = false
	closed.emit()


## What a kind of die is called: D2 for the coin, D6, D100.
static func die_name(sides: int) -> String:
	return "D%d" % sides


## The rectangle of the column of dice, in the drawer's own coordinates.
func column_rect() -> Rect2:
	return Rect2(_column_position, Vector2(COLUMN_WIDTH, ROW_HEIGHT * sides_list.size()))


## The rectangle of the colours that slid out beside a die.
func strip_rect(row: int) -> Rect2:
	var width := colors.size() * SWATCH_SIZE + (colors.size() + 1) * SWATCH_GAP
	var column := column_rect()
	return Rect2(column.position.x - GAP - width, column.position.y + row * ROW_HEIGHT, width, ROW_HEIGHT)


func swatch_rect(row: int, index: int) -> Rect2:
	var strip := strip_rect(row)
	return Rect2(strip.position.x + SWATCH_GAP + index * (SWATCH_SIZE + SWATCH_GAP),
			strip.position.y + (ROW_HEIGHT - SWATCH_SIZE) / 2.0, SWATCH_SIZE, SWATCH_SIZE)


func colors_are_out() -> bool:
	return _colors_row >= 0


## Which die is under a point, or -1.
func row_at(point: Vector2) -> int:
	var column := column_rect()
	if not column.has_point(point):
		return -1
	return clampi(int((point.y - column.position.y) / ROW_HEIGHT), 0, sides_list.size() - 1)


## Which colour is under a point, while the colours are out, or -1.
func swatch_at(point: Vector2) -> int:
	if _colors_row < 0 or not strip_rect(_colors_row).has_point(point):
		return -1
	for i in colors.size():
		if swatch_rect(_colors_row, i).grow(SWATCH_GAP / 2.0).has_point(point):
			return i
	return -1


## A finger came down at a point in the drawer's coordinates.
func pointer_down(point: Vector2) -> void:
	_down = true
	pointer_move(point)


func pointer_move(point: Vector2) -> void:
	var swatch := swatch_at(point)
	var row := row_at(point)
	if swatch >= 0:
		_swatch = swatch
	else:
		_swatch = -1
		if row != _row:
			_row = row
			_dwell = 0.0
			# Moving to another die puts the colours away.
			if _colors_row >= 0 and row >= 0:
				_slide_colors(-1)
		elif row < 0 and _colors_row < 0:
			_dwell = 0.0
	queue_redraw()


## The finger lifted. Over a colour that is the colour, over a die a random colour.
## Anywhere else, the drawer stays if the finger only just arrived from the + button,
## and closes otherwise.
func pointer_up(point: Vector2) -> void:
	pointer_move(point)
	var was_down := _down
	_down = false
	if not was_down:
		return
	if _swatch >= 0 and _colors_row >= 0:
		picked.emit(sides_list[_colors_row], colors[_swatch])
		_finish_pick()
	elif _row >= 0:
		picked.emit(sides_list[_row], null)
		_finish_pick()
	elif _from_drag:
		_from_drag = false
	else:
		close()
	_from_drag = false


## The column hangs under the + button, which can sit above the tool, so a touch on it
## counts even where it sticks out past the drawer's own edge.
func _has_point(point: Vector2) -> bool:
	return is_open and (Rect2(Vector2.ZERO, size).has_point(point) or column_rect().grow(10.0).has_point(point))


## After a pick the drawer closes, unless it was opened by a tap: then it only puts the
## colours away and waits for the next die.
func _finish_pick() -> void:
	if not _sticky:
		close()
		return
	if _slide_tween != null:
		_slide_tween.kill()
	_colors_row = -1
	_slide = 0.0
	_swatch = -1
	_row = -1
	_dwell = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down(event.position)
		else:
			pointer_up(event.position)
	elif event is InputEventMouseMotion and _down:
		pointer_move(event.position)


func _process(delta: float) -> void:
	if not is_open:
		return
	if _down and _row >= 0 and _colors_row < 0:
		_dwell += delta
		if _dwell >= DWELL_SECONDS:
			_slide_colors(_row)


func _slide_colors(row: int) -> void:
	if _slide_tween != null:
		_slide_tween.kill()
	if row >= 0:
		_colors_row = row
	_slide_tween = create_tween()
	_slide_tween.tween_method(_set_slide, _slide, 1.0 if row >= 0 else 0.0, SLIDE_SECONDS)
	if row < 0:
		_slide_tween.tween_callback(func() -> void: _colors_row = -1)


func _set_slide(value: float) -> void:
	_slide = value
	queue_redraw()


func _draw() -> void:
	if not is_open:
		return
	var column := column_rect()
	UiStyle.box(UiStyle.PANEL, 28).draw(get_canvas_item(), column.grow(10.0))
	if _row >= 0:
		var highlight := UiStyle.box(Color(UiStyle.INK, 0.14), 20)
		highlight.draw(get_canvas_item(), Rect2(column.position.x + 4.0, column.position.y + _row * ROW_HEIGHT + 4.0, COLUMN_WIDTH - 8.0, ROW_HEIGHT - 8.0))
	var font := ThemeDB.fallback_font
	for i in sides_list.size():
		var baseline := column.position.y + (i + 0.5) * ROW_HEIGHT + LABEL_SIZE * 0.35
		draw_string(font, Vector2(column.position.x, baseline), die_name(sides_list[i]), HORIZONTAL_ALIGNMENT_CENTER, COLUMN_WIDTH, LABEL_SIZE, UiStyle.INK)
	if _colors_row < 0 or _slide <= 0.0:
		return
	var offset := Vector2((1.0 - _slide) * SLIDE_DISTANCE, 0.0)
	var strip := strip_rect(_colors_row)
	UiStyle.box(Color(UiStyle.PANEL, _slide), 28).draw(get_canvas_item(), Rect2(strip.position + offset, strip.size).grow_individual(0, -10, 0, -10))
	for i in colors.size():
		var rect := swatch_rect(_colors_row, i)
		rect.position += offset
		var fill := UiStyle.box(Color(colors[i], _slide), 18)
		if i == _swatch:
			fill.set_border_width_all(6)
			fill.border_color = Color(Color.WHITE if colors[i].get_luminance() < 0.5 else UiStyle.INK, _slide)
		fill.draw(get_canvas_item(), rect)
