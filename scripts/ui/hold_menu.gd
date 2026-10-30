class_name HoldMenu
extends Control
## What a long press on a game's tile, or on a tool in the toolbar, opens: a menu of Icon,
## Colour, Delete and, for a tool, Theme. Keeping the finger on Icon or Colour pops a list out beside the menu;
## slide onto an entry and let go. If instead the finger drags the thing away, not towards the
## menu, the menu goes and `drag_started` says to pick it up, which the owner does. The owner
## feeds it the finger's moves and its lift, in global coordinates, because the finger is
## still down on the thing that was pressed.

signal icon_chosen(icon_name: String)
signal color_chosen(color: Color)
signal theme_chosen(theme_name: String)
signal delete_chosen
## The finger took the thing for a drag, at this global point.
signal drag_started(global_point: Vector2)
## A touch outside the menu put it away while it was waiting to be tapped.
signal dismissed

const CHOICE_ICONS := {"icon": "star", "color": "palette", "theme": "orbit", "delete": "trash-2"}
## What things can be coloured.
const COLORS: Array[Color] = [
	Color("#4F7CFF"), Color("#E5484D"), Color("#30A46C"), Color("#F5A524"),
	Color("#8E4EC6"), Color("#1C1C1E"), Color("#12A594"), Color("#E93D82"),
]
const ICON_COLUMNS := 5
## A finger that has moved this far from where the menu opened, and not towards the menu,
## is dragging the thing.
const DRAG_AWAY := 56.0
## How far past the menu's edge a movement can aim and still be heading for it.
const AIM_MARGIN := 40.0

var is_open := false
var menu: ChoiceDrawer
var icon_drawer: ChoiceDrawer
var color_drawer: ChoiceDrawer
var theme_drawer: ChoiceDrawer
var hold_origin := Vector2.ZERO
## Asked, with the global point, whether a touch that puts the menu away should also reach what
## is under it (another thing to long press, say). With none set, such a touch only puts the
## menu away.
var let_through := Callable()
## Letting go of the finger anywhere but on a choice puts the menu away, rather than leaving it open to be tapped.
var close_on_release := false

var _sub: ChoiceDrawer
var _engaged := false
var _can_drag := false
var _current_icon := ""
var _current_color := Color.WHITE
var _current_theme := ""
var _down := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = ChoiceDrawer.new()
	menu.modal = false
	_setup_menu(false)
	menu.picked.connect(_on_menu_picked)
	menu.hovered.connect(_on_menu_hovered)
	menu.closed.connect(func() -> void: is_open = false)
	add_child(menu)

	icon_drawer = ChoiceDrawer.new()
	var identity := {}
	for icon_name in IconLibrary.GAME_ICONS:
		identity[icon_name] = icon_name
	icon_drawer.setup(IconLibrary.GAME_ICONS, identity)
	icon_drawer.modal = false
	icon_drawer.columns = ICON_COLUMNS
	icon_drawer.picked.connect(func(icon_name: String) -> void: _finish(); icon_chosen.emit(icon_name))
	add_child(icon_drawer)

	color_drawer = ChoiceDrawer.new()
	color_drawer.modal = false
	color_drawer.setup_colors(COLORS)
	color_drawer.picked.connect(func(kind: String) -> void: _finish(); color_chosen.emit(COLORS[int(kind)]))
	add_child(color_drawer)

	theme_drawer = ChoiceDrawer.new()
	theme_drawer.setup(Themes.NAMES, Themes.ICONS)
	theme_drawer.modal = false
	theme_drawer.columns = Themes.NAMES.size()
	theme_drawer.picked.connect(func(theme_name: String) -> void: _finish(); theme_chosen.emit(theme_name))
	add_child(theme_drawer)
	ActionBars.family(self, [menu, icon_drawer, color_drawer, theme_drawer])


## Lists Theme among the choices only for things that have a theme (tools, not games).
func _setup_menu(with_theme: bool) -> void:
	var kinds: Array[String] = ["icon", "color"]
	if with_theme:
		kinds.append("theme")
	kinds.append("delete")
	menu.setup(kinds, CHOICE_ICONS, {
		"icon": tr("HOME_MENU_ICON"), "color": tr("HOME_MENU_COLOR"),
		"theme": tr("HOME_MENU_THEME"), "delete": tr("HOME_MENU_DELETE"),
	})


## Opens the menu around `menu_point`, with a finger down at `finger`. `can_delete` and
## `can_drag` say what may be done to the thing.
func open(menu_point: Vector2, finger: Vector2, current_icon: String, current_color: Color, can_delete: bool, can_drag: bool, current_theme: String = "") -> void:
	_current_theme = current_theme
	_setup_menu(current_theme != "")
	_current_icon = current_icon
	_current_color = current_color
	_can_drag = can_drag
	_engaged = false
	_sub = null
	_down = true
	hold_origin = finger
	var off: Array[String] = []
	if not can_delete:
		off = ["delete"]
	menu.set_disabled(off)
	menu.open(menu_point - menu.global_position, "", true)
	is_open = true


## While the menu is left open to be tapped, a touch anywhere but on it puts it away.
func _input(event: InputEvent) -> void:
	if _down or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var open_drawers: Array[ChoiceDrawer] = []
	for drawer in [menu, icon_drawer, color_drawer, theme_drawer]:
		if drawer.is_open:
			open_drawers.append(drawer)
	if open_drawers.is_empty():
		return
	for drawer in open_drawers:
		if drawer.covers(event.global_position - drawer.global_position):
			return
	close()
	dismissed.emit()
	if not (let_through.is_valid() and let_through.call(event.global_position)):
		get_viewport().set_input_as_handled()


func close() -> void:
	_down = false
	for drawer in [menu, icon_drawer, color_drawer, theme_drawer]:
		drawer.close()
	_sub = null
	is_open = false


## The finger that is down moves.
func finger_moved(at: Vector2) -> void:
	if not _down:
		return
	if _engaged and not _over_menu(at):
		# Having been on the menu, leaving it and its list just puts the lot away; the thing is
		# not picked up from there, as the finger did not start on it.
		close()
		return
	if _is_dragging_away(at):
		_down = false
		close()
		drag_started.emit(at)
		return
	if _sub != null and _sub.covers(at - _sub.global_position):
		_sub.pointer_move(at - _sub.global_position)
	else:
		menu.pointer_move(at - menu.global_position)
		if _sub != null:
			_sub.pointer_move(Vector2(-9999.0, -9999.0))


## The finger that is down lifts.
func finger_up(at: Vector2) -> void:
	if not _down:
		return
	_down = false
	if _sub != null and _sub.covers(at - _sub.global_position):
		_sub.pointer_up(at - _sub.global_position)
		close()
	else:
		var over_choice := menu.item_at(at - menu.global_position) >= 0
		menu.pointer_up(at - menu.global_position)
		if over_choice or close_on_release:
			# Letting go on Icon or Colour does not leave its list behind: the lot goes together.
			close()


## Whether the point is on the menu or on the list popped out beside it.
func _over_menu(at: Vector2) -> bool:
	return menu.covers(at - menu.global_position) or (_sub != null and _sub.covers(at - _sub.global_position))


## Whether a finger is taking the thing for a drag: it has gone a good way, not towards the
## menu, and has not been into the menu. Heading for the menu means the line the finger has
## taken, carried on, would reach it.
func _is_dragging_away(at: Vector2) -> bool:
	if not _can_drag:
		return false
	if _engaged:
		return false
	var moved := at - hold_origin
	if moved.length() < DRAG_AWAY:
		return false
	var target := Rect2(menu.rect().position + menu.global_position, menu.rect().size).grow(AIM_MARGIN)
	var heading := moved.normalized()
	for step in 80:
		if target.has_point(hold_origin + heading * step * 20.0):
			return false
	return true


func _on_menu_hovered(kind: String) -> void:
	if kind != "":
		_engaged = true
	match kind:
		"icon":
			_pop_out(icon_drawer, _current_icon)
		"color":
			_pop_out(color_drawer, str(color_index(_current_color)))
		"theme":
			_pop_out(theme_drawer, _current_theme)
		"":
			pass
		_:
			_put_away_sub()


func _on_menu_picked(kind: String) -> void:
	match kind:
		"icon":
			_pop_out(icon_drawer, _current_icon)
		"color":
			_pop_out(color_drawer, str(color_index(_current_color)))
		"theme":
			_pop_out(theme_drawer, _current_theme)
		"delete":
			_finish()
			delete_chosen.emit()


## Pops a list out beside the menu, with the finger still down if it is.
func _pop_out(drawer: ChoiceDrawer, current: String) -> void:
	if _sub == drawer and drawer.is_open:
		return
	_put_away_sub()
	_sub = drawer
	drawer.open_below(menu.rect(), current, _down, menu.rect().get_center().y > size.y / 2.0)


func _put_away_sub() -> void:
	if _sub != null:
		_sub.close()
		_sub = null


func _finish() -> void:
	_down = false
	close()


static func color_index(color: Color) -> int:
	for i in COLORS.size():
		if COLORS[i].is_equal_approx(color):
			return i
	return -1
