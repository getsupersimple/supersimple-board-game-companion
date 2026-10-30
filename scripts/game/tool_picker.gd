class_name ToolPicker
extends Control
## The drawer that adds a tool. It springs up out of the + button as a column with one
## button for each kind of tool. A tap on the + opens it to be touched; holding the + opens
## it under the finger, and letting go closes it, so a tool can be picked in one movement.
## Either way, a touch on a kind adds it. Keeping the finger on a kind a moment pulls out a
## drawer of themes (see Themes), to its left; slide onto one and let go to add the tool wearing
## that theme, and so making its sounds.

## `theme_name` is Themes.DEFAULT when a kind was touched without choosing a theme.
signal picked(preset_type: Preset.Type, theme_name: String)
signal closed

const BUTTON := 140.0
const GAP := 16.0
const PADDING := 16.0
const ABOVE := 16.0
## A finger kept on a kind this long pulls the icons out.
const DWELL_SECONDS := 0.4

var is_open := false

var _types: Array[Preset.Type] = []
var _textures := {}
var _column := Rect2()
var _row := -1
var _theme_row := -1
var _down := false
var _dwell := 0.0
var _pop := Spring.new(0.0)
var _themes: ChoiceDrawer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_pop.stiffness = 420.0
	_pop.damping = 22.0


func setup(types: Array[Preset.Type]) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_types = types
	# Loaded ahead of drawing: a texture loaded for the first time inside `_draw` comes out black.
	for preset_type in types:
		_textures[Preset.default_icon(preset_type)] = IconLibrary.get_icon(Preset.default_icon(preset_type))
	_themes = ChoiceDrawer.new()
	_themes.setup(Themes.NAMES, Themes.ICONS)
	_themes.columns = Themes.NAMES.size()
	_themes.picked.connect(_on_theme_picked)
	add_child(_themes)
	ActionBars.family(self, [self, _themes])


## Springs the drawer up out of `anchor`, lined up with its left edge. `held` says a finger
## is already down, having come from a long press on the anchor.
func open(anchor: Control, held: bool) -> void:
	if held:
		Haptics.pulse(20)
	ActionBars.opening(self)
	var rect := anchor.get_global_rect()
	var height := _types.size() * BUTTON + (_types.size() - 1) * GAP + PADDING * 2.0
	_column = Rect2(rect.position.x - global_position.x, rect.position.y - global_position.y - ABOVE - height, BUTTON + PADDING * 2.0, height)
	is_open = true
	_down = held
	_row = -1
	_theme_row = -1
	_dwell = 0.0
	_pop.snap(0.0)
	_pop.target = 1.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_down = false
	_themes.close()
	_pop.target = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func column_rect() -> Rect2:
	return _column


func row_rect(index: int) -> Rect2:
	return Rect2(_column.position.x + PADDING, _column.position.y + PADDING + index * (BUTTON + GAP), BUTTON, BUTTON)


func themes_are_out() -> bool:
	return _themes.is_open


## The drawer of themes, which pops out to the left of a kind that has been held.
func theme_drawer() -> ChoiceDrawer:
	return _themes


## Which kind is under a point, or -1.
func row_at(point: Vector2) -> int:
	for i in _types.size():
		if row_rect(i).grow(GAP / 2.0).has_point(point):
			return i
	return -1


func pointer_down(point: Vector2) -> void:
	_down = true
	pointer_move(point)


func pointer_move(point: Vector2) -> void:
	if _themes.is_open and _themes.covers(point):
		_themes.pointer_move(point)
		return
	_themes.pointer_move(Vector2(-9999.0, -9999.0))
	var row := row_at(point)
	if row != _row:
		_row = row
		_dwell = 0.0
		# Moving to another kind puts its themes away.
		if _themes.is_open and row >= 0 and row != _theme_row:
			_themes.close()
			_theme_row = -1


## The finger lifted. Over a theme that is that theme, over a kind the default theme; the
## drawer closes whichever.
func pointer_up(point: Vector2) -> void:
	pointer_move(point)
	var was_down := _down
	_down = false
	if not was_down:
		return
	if _themes.is_open and _themes.covers(point):
		_themes.pointer_up(point)
	elif _row >= 0:
		var kind := _types[_row]
		close()
		picked.emit(kind, Themes.DEFAULT)
	else:
		close()


func _on_theme_picked(theme_name: String) -> void:
	var kind := _types[_theme_row]
	close()
	picked.emit(kind, theme_name)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down(event.position)
		else:
			pointer_up(event.position)
	elif event is InputEventMouseMotion and _down:
		pointer_move(event.position)


func _process(delta: float) -> void:
	if not visible:
		return
	_pop.step(delta)
	if not is_open and _pop.value < 0.02:
		visible = false
		return
	if _down and _row >= 0 and not _themes.is_open:
		_dwell += delta
		if _dwell >= DWELL_SECONDS:
			_theme_row = _row
			_themes.open_left_of(row_rect(_row), Themes.DEFAULT, true)
	queue_redraw()


func _draw() -> void:
	if _column.size == Vector2.ZERO:
		return
	var grown := maxf(_pop.value, 0.0)
	# It grows out of the + button, at the bottom left of the column.
	var pivot := Vector2(_column.position.x, _column.end.y)
	draw_set_transform(pivot, 0.0, Vector2(grown, grown))
	var shift := -pivot
	var panel := UiStyle.box(UiStyle.PANEL, 44)
	panel.shadow_color = Color(0, 0, 0, 0.2)
	panel.shadow_size = 22
	panel.draw(get_canvas_item(), Rect2(_column.position + shift, _column.size))
	for i in _types.size():
		var color := Preset.default_color(_types[i])
		var rect := row_rect(i)
		rect.position += shift
		if i == _row:
			rect = rect.grow(6.0)
		UiStyle.box(color, 32).draw(get_canvas_item(), rect)
		var icon_size := Vector2(72.0, 72.0)
		var at := rect.position + (rect.size - icon_size) / 2.0
		draw_texture_rect(_textures[Preset.default_icon(_types[i])], Rect2(at, icon_size), false, ColorUtils.contrast_color(color))
