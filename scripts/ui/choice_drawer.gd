class_name ChoiceDrawer
extends Control
## A drawer that picks one of a few things, such as the buzzer's sound or how the
## hourglass runs. It springs open as a row of icons right where a finger has been held
## down. Slide onto one and let go to choose it. If the finger lifts elsewhere the drawer stays open to be tapped, and a
## tap anywhere else puts it away.

## `kind` is one of the names given to `setup`.
signal picked(kind: String)
signal closed
## The choice under the finger changed; `kind` is empty when it is over none.
signal hovered(kind: String)
## The finger left the whole drawer, having been over this choice as it went.
signal exited(kind: String)

const ITEM_SIZE := 130.0
const SWATCH_SIZE := 96.0
## With words under the icons, each choice is wider and taller.
const LABELED_WIDTH := 240.0
const LABELED_HEIGHT := 170.0
const LABEL_SIZE := 28
const GAP := 14.0
const EDGE := 16.0
## The row sits this far above the finger, so the finger does not hide it.
const LIFT := 90.0

var is_open := false
## Letting go away from every choice closes the drawer even when the finger came from a
## long press. The colour drawer works this way.
var close_on_release := false
## While on, the drawer catches every touch on its screen, so one outside it only puts it away. Off,
## only the drawer itself does and the rest go through to what is underneath.
var modal := true

var _kinds: Array[String] = []
var _icons := {}
## The icons as textures, loaded ahead of drawing: one loaded for the first time inside
## `_draw` comes out black.
var _textures := {}
var _current := ""
var _origin := Vector2.ZERO
var _rect := Rect2()
var _hover := -1
var _down := false
## How many choices go across before the next row. Zero puts them all in one row.
var columns := 0
var _item := ITEM_SIZE
var _item_height := ITEM_SIZE
var _labels := {}
## Choices shown dimmed that cannot be picked.
var _disabled: Array[String] = []
var _swatches: Array[Color] = []
var _pop := Spring.new(0.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_pop.stiffness = 420.0
	_pop.damping = 22.0


func setup(kinds: Array[String], icons: Dictionary, labels: Dictionary = {}) -> void:
	_kinds = kinds
	_icons = icons
	_labels = labels
	_disabled = []
	if not labels.is_empty():
		_item = LABELED_WIDTH
		_item_height = LABELED_HEIGHT
	for kind in kinds:
		_textures[kind] = IconLibrary.get_icon(icons[kind])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Sets the drawer up to pick a colour instead: the choices are named "0", "1" and so on, by
## their place in `palette`.
func setup_colors(palette: Array[Color]) -> void:
	var names: Array[String] = []
	for i in palette.size():
		names.append(str(i))
	_kinds = names
	_swatches = palette
	_item = SWATCH_SIZE
	_item_height = SWATCH_SIZE
	close_on_release = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Opens the row around `point`. `held` says a finger is still down there.
func open(point: Vector2, current: String, held: bool) -> void:
	var panel := _panel_size()
	var width := panel.x
	var height := panel.y
	_current = current
	_origin = point
	_down = held
	_hover = -1
	var top := point.y - LIFT - height
	if top < EDGE:
		top = point.y + LIFT
	_rect = Rect2(
			clampf(point.x - width / 2.0, EDGE, maxf(size.x - width - EDGE, EDGE)),
			clampf(top, EDGE, maxf(size.y - height - EDGE, EDGE)),
			width, height)
	ActionBars.opening(self)
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.snap(0.0)
	_pop.target = 1.0
	queue_redraw()


## Opens the drawer just under a rectangle, popping out from beneath it. `held` says a finger
## is still down.
## When there is no room underneath, or `prefer_above` is set, it opens above instead.
func open_below(anchor: Rect2, current: String, held: bool, prefer_above: bool = false) -> void:
	var panel := _panel_size()
	var top := anchor.end.y + GAP
	_origin = Vector2(anchor.get_center().x, anchor.end.y)
	var fits_above := anchor.position.y - GAP - panel.y >= EDGE
	if (prefer_above or top + panel.y > size.y - EDGE) and fits_above:
		top = anchor.position.y - GAP - panel.y
		_origin = Vector2(anchor.get_center().x, anchor.position.y)
	_rect = Rect2(
			clampf(anchor.get_center().x - panel.x / 2.0, EDGE, maxf(size.x - panel.x - EDGE, EDGE)),
			clampf(top, EDGE, maxf(size.y - panel.y - EDGE, EDGE)),
			panel.x, panel.y)
	_start(current, held)


## Opens the drawer just to the left of a rectangle, level with it, popping out from its side.
func open_left_of(anchor: Rect2, current: String, held: bool) -> void:
	var panel := _panel_size()
	_origin = Vector2(anchor.position.x, anchor.get_center().y)
	_rect = Rect2(
			clampf(anchor.position.x - GAP - panel.x, EDGE, maxf(size.x - panel.x - EDGE, EDGE)),
			clampf(anchor.get_center().y - panel.y / 2.0, EDGE, maxf(size.y - panel.y - EDGE, EDGE)),
			panel.x, panel.y)
	_start(current, held)


func _start(current: String, held: bool) -> void:
	_current = current
	_down = held
	_hover = -1
	ActionBars.opening(self)
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.snap(0.0)
	_pop.target = 1.0
	queue_redraw()


func _panel_size() -> Vector2:
	var across := _columns()
	var down := ceili(float(_kinds.size()) / across)
	return Vector2(across * _item + (across + 1) * GAP, down * _item_height + (down + 1) * GAP)


## Whether a point is over the drawer, panel and all.
func covers(point: Vector2) -> bool:
	return is_open and _rect.grow(GAP).has_point(point)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_down = false
	_pop.target = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _has_point(point: Vector2) -> bool:
	return modal or covers(point)


func rect() -> Rect2:
	return _rect


func item_rect(index: int) -> Rect2:
	var across := _columns()
	return Rect2(_rect.position.x + GAP + (index % across) * (_item + GAP), _rect.position.y + GAP + (index / across) * (_item_height + GAP), _item, _item_height)


func _columns() -> int:
	return columns if columns > 0 else maxi(_kinds.size(), 1)


## Dims some of the choices and stops them being picked. Call after `setup`.
func set_disabled(kinds: Array[String]) -> void:
	_disabled = kinds


func is_disabled(kind: String) -> bool:
	return _disabled.has(kind)


## Which choice is under a point, or -1.
func item_at(point: Vector2) -> int:
	for i in _kinds.size():
		if item_rect(i).grow(GAP / 2.0).has_point(point) and not _disabled.has(_kinds[i]):
			return i
	return -1


func pointer_move(point: Vector2) -> void:
	var over := item_at(point)
	if over != _hover:
		var before := _hover
		_hover = over
		queue_redraw()
		hovered.emit(_kinds[over] if over >= 0 else "")
		if before >= 0 and over < 0 and not covers(point):
			exited.emit(_kinds[before])


## The finger lifted. Over an icon, that choice is made. Anywhere else the drawer stays
## when the finger only just arrived from the long press, and closes otherwise.
func pointer_up(point: Vector2) -> void:
	pointer_move(point)
	var was_down := _down
	_down = false
	var chosen := item_at(point)
	if chosen >= 0:
		picked.emit(_kinds[chosen])
		close()
	elif not was_down or close_on_release:
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = false
			pointer_up(event.position)
	elif event is InputEventMouseMotion:
		pointer_move(event.position)


func _process(delta: float) -> void:
	if not visible:
		return
	_pop.step(delta)
	if not is_open and _pop.value < 0.02:
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	if _rect.size == Vector2.ZERO:
		return
	var grown := maxf(_pop.value, 0.0)
	draw_set_transform(_origin, 0.0, Vector2(grown, grown))
	var shift := -_origin
	var panel := UiStyle.box(UiStyle.PANEL, 44)
	panel.shadow_color = Color(0, 0, 0, 0.22)
	panel.shadow_size = 24
	panel.draw(get_canvas_item(), Rect2(_rect.position + shift, _rect.size))
	for i in _kinds.size():
		var rect := item_rect(i)
		rect.position += shift
		var chosen := _kinds[i] == _current
		var dimmed := _disabled.has(_kinds[i])
		if not _swatches.is_empty():
			_draw_swatch(_swatches[i], rect, chosen, i == _hover)
			continue
		if chosen:
			UiStyle.box(UiStyle.INK, 32).draw(get_canvas_item(), rect)
		elif i == _hover:
			UiStyle.box(Color(UiStyle.INK, 0.14), 32).draw(get_canvas_item(), rect)
		var icon_size := Vector2(72.0, 72.0)
		var ink := Color.WHITE if chosen else UiStyle.INK
		if dimmed:
			ink = Color(UiStyle.INK, 0.28)
		if _labels.has(_kinds[i]):
			var top := rect.position + Vector2((rect.size.x - icon_size.x) / 2.0, 18.0)
			draw_texture_rect(_textures[_kinds[i]], Rect2(top, icon_size), false, ink)
			draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.end.y - 24.0), _labels[_kinds[i]], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, LABEL_SIZE, ink)
			continue
		draw_texture_rect(_textures[_kinds[i]], Rect2(rect.position + (rect.size - icon_size) / 2.0, icon_size), false, ink)


func _draw_swatch(color: Color, rect: Rect2, chosen: bool, hovered: bool) -> void:
	if hovered:
		rect = rect.grow(6.0)
	var fill := UiStyle.box(color, 24)
	if chosen or hovered:
		fill.set_border_width_all(6)
		fill.border_color = Color.WHITE if color.get_luminance() < 0.5 else UiStyle.INK
	fill.draw(get_canvas_item(), rect)
