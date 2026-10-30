extends GutTest

var _dock: ToolDock
var _slot: Control
var _tapped: Array = []
var _held: Array = []
var _moved: Array = []
var _lifted: Array = []
var _in_bar: Array = []
var _on_screen: Array = []
var _presets: Array[Preset] = []


func before_each() -> void:
	_tapped.clear()
	_held.clear()
	_moved.clear()
	_lifted.clear()
	_in_bar.clear()
	_on_screen.clear()
	_presets.clear()


## A 1080 x 1920 screen with a toolbar slot along the bottom, as the game screen has.
func _make_dock(count: int) -> void:
	var screen := Control.new()
	screen.size = Vector2(1080, 1920)
	add_child_autofree(screen)
	_slot = Control.new()
	_slot.position = Vector2(48, 1700)
	_slot.size = Vector2(800, 140)
	screen.add_child(_slot)
	_dock = ToolDock.new()
	_dock.set_slot(_slot)
	screen.add_child(_dock)
	for i in count:
		_presets.append(Preset.create_default(Preset.Type.DICE))
	_dock.tapped.connect(func(id: String) -> void: _tapped.append(id))
	_dock.held.connect(func(id: String, _at: Vector2) -> void: _held.append(id))
	_dock.finger_moved.connect(func(at: Vector2) -> void: _moved.append(at))
	_dock.finger_up.connect(func(at: Vector2) -> void: _lifted.append(at))
	_dock.placed_in_bar.connect(func(id: String, index: int) -> void: _in_bar.append([id, index]))
	_dock.placed_on_screen.connect(_on_placed_on_screen)
	_dock.sync(_presets, _presets[0].id if count > 0 else "", false)


## What the game screen does: keeps the new place with the preset.
func _on_placed_on_screen(id: String, fraction: Vector2) -> void:
	_on_screen.append([id, fraction])
	for preset in _presets:
		if preset.id == id:
			preset.has_position = true
			preset.position = fraction


func _touch(pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_dock._gui_input(event)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_dock._gui_input(event)


## Holds a finger on an icon until the dock reports it held.
func _hold(id: String) -> Vector2:
	var at := _dock.chip_center(id)
	_touch(true, at)
	await wait_seconds(ToolDock.LONG_PRESS_SECONDS + 0.2)
	return at


func test_a_tap_selects_a_tool_and_a_press_on_nothing_does_nothing() -> void:
	_make_dock(3)
	await wait_seconds(0.3)
	var at := _dock.chip_center(_presets[1].id)
	_touch(true, at)
	_touch(false, at)
	assert_eq(_tapped, [_presets[1].id])
	_touch(true, Vector2(500, 600))
	_touch(false, Vector2(500, 600))
	assert_eq(_tapped.size(), 1)
	assert_eq(_held.size(), 0)


func test_only_the_toolbar_and_loose_icons_take_touches() -> void:
	_make_dock(2)
	await wait_seconds(0.3)
	assert_false(_dock._has_point(Vector2(500, 600)), "the tool underneath gets the touch")
	assert_true(_dock._has_point(_dock.chip_center(_presets[0].id)))


func test_a_long_press_reports_the_icon_held_and_is_not_a_tap() -> void:
	_make_dock(2)
	await wait_seconds(0.3)
	var at := await _hold(_presets[1].id)
	assert_eq(_held, [_presets[1].id])
	_move(at + Vector2(10, -10))
	assert_eq(_moved.size(), 1, "the finger's moves go on to the owner")
	_touch(false, at)
	assert_eq(_lifted.size(), 1, "and its lift")
	assert_eq(_tapped.size(), 0)


func test_carrying_a_held_icon_out_leaves_it_where_it_is_dropped() -> void:
	_make_dock(3)
	await wait_seconds(0.3)
	var id := _presets[1].id
	var start := await _hold(id)
	var picked_up := start + Vector2(0, -120)
	_dock.carry(_dock.global_position + picked_up)
	_move(Vector2(540, 600))
	_touch(false, Vector2(540, 600))
	assert_eq(_on_screen.size(), 1)
	assert_eq(_on_screen[0][0], id)
	assert_almost_eq(_on_screen[0][1].x, 0.5, 0.05, "dropped where it was carried, keeping the grip it was picked up with")
	assert_eq(_in_bar.size(), 0)
	await wait_seconds(1.0)
	var fraction: Vector2 = _on_screen[0][1]
	assert_almost_eq(_dock.chip_center(id).x, fraction.x * 1080.0, 2.0, "it springs to rest where it was let go")
	assert_almost_eq(_dock.chip_center(id).y, fraction.y * 1920.0, 2.0)
	assert_eq(_dock.bar_ids().size(), 2, "the others closed up")


func test_carrying_an_icon_back_to_the_toolbar_snaps_it_in_at_that_place() -> void:
	_make_dock(3)
	await wait_seconds(0.3)
	var id := _presets[0].id
	var start := await _hold(id)
	_dock.carry(_dock.global_position + start + Vector2(0, -80))
	var over_third := _dock.chip_center(_presets[2].id) + Vector2(20, -10)
	_move(over_third)
	await wait_frames(2)
	_touch(false, over_third)
	assert_eq(_in_bar, [[id, 2]], "after the two others")
	assert_eq(_on_screen.size(), 0)
	await wait_seconds(1.2)
	var place := _dock.chip_center(id)
	assert_almost_eq(place.y, _slot.global_position.y + ToolChip.SIZE / 2.0, 3.0, "settled in the toolbar's row")
	assert_eq(_dock.chip_for(id).get_parent(), _dock._strip, "and clipped with the rest once home")


func test_the_toolbar_scrolls_when_it_holds_more_than_fits() -> void:
	_make_dock(8)
	await wait_seconds(0.3)
	assert_gt(_dock.max_scroll(), 0.0)
	var last := _presets[7].id
	assert_gt(_dock.chip_center(last).x, _slot.global_position.x + _slot.size.x, "the last is off to the side")
	var from := Vector2(400, 1770)
	_touch(true, from)
	_move(from + Vector2(-60, 0))
	_move(from + Vector2(-400, 0))
	assert_gt(_dock.scroll_offset(), 300.0)
	_touch(false, from + Vector2(-400, 0))
	assert_eq(_tapped.size(), 0, "scrolling is not a tap")
	assert_eq(_held.size(), 0)
	await wait_seconds(2.0)
	assert_between(_dock.scroll_offset(), 0.0, _dock.max_scroll() + 0.5)


func test_adding_an_icon_scrolls_the_toolbar_to_show_it() -> void:
	_make_dock(5)
	await wait_seconds(0.3)
	var added := Preset.create_default(Preset.Type.BUZZER)
	_presets.append(added)
	_dock.sync(_presets, added.id)
	_dock.reveal(added.id)
	await wait_seconds(1.5)
	var center := _dock.chip_center(added.id)
	assert_lt(center.x, _slot.global_position.x + _slot.size.x, "it is inside the toolbar")
