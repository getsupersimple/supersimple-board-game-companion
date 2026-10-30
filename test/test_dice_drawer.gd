extends GutTest


func _tool(dice: Array = []) -> DiceTool:
	var preset := Preset.create_default(Preset.Type.DICE)
	preset.data["dice"] = dice
	var tool := DiceTool.new()
	tool.preset = preset
	tool.store = PresetStore.new("user://test_dice_drawer.cfg")
	tool.size = Vector2(900, 1500)
	add_child_autofree(tool)
	return tool


func _row_centre(drawer: DiceDrawer, row: int) -> Vector2:
	return drawer.column_rect().position + Vector2(DiceDrawer.COLUMN_WIDTH / 2.0, (row + 0.5) * DiceDrawer.ROW_HEIGHT)


func _press(button: Control, pressed: bool, at: Vector2 = Vector2(10, 10)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	button.gui_input.emit(event)


func after_all() -> void:
	DirAccess.remove_absolute("user://test_dice_drawer.cfg")


func test_the_plus_button_is_at_the_top_right_and_the_tray_has_no_die_buttons() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	var plus: Rect2 = tool._plus.get_global_rect()
	assert_almost_eq(plus.end.x, tool.size.x, 0.5, "at the right edge")
	assert_almost_eq(plus.position.y, 0.0, 0.5, "at the top")
	var numbered := 0
	for button in tool.find_children("*", "Button", true, false):
		if button.text.is_valid_int():
			numbered += 1
	assert_eq(numbered, 0, "no row of numbered buttons any more")


func test_the_drawer_hangs_under_the_plus_with_a_real_die_for_each_kind() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	var drawer: DiceDrawer = tool._drawer
	assert_false(drawer.visible)
	drawer.open(tool._plus, false)
	var column := drawer.column_rect()
	assert_gt(column.position.y, tool._plus.get_global_rect().end.y, "below the button")
	assert_almost_eq(column.end.x, tool._plus.get_global_rect().end.x, 0.5, "lined up with its right edge")
	assert_eq(DiceDrawer.die_name(6), "D6")
	assert_eq(DiceDrawer.die_name(100), "D100")
	assert_true(Rect2(Vector2.ZERO, tool.size).encloses(column), "all of it on screen")


func test_dragging_onto_a_die_and_letting_go_adds_it_in_a_random_colour() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	var drawer: DiceDrawer = tool._drawer
	var picked := []
	drawer.picked.connect(func(sides: int, color: Variant) -> void: picked.append([sides, color]))
	drawer.open(tool._plus, true)
	drawer.pointer_move(_row_centre(drawer, 2))
	drawer.pointer_up(_row_centre(drawer, 2))
	assert_eq(picked, [[6, null]])
	assert_false(drawer.is_open, "the drawer puts itself away")


func test_keeping_the_finger_on_a_die_pulls_out_the_colours_to_pick_from() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	var drawer: DiceDrawer = tool._drawer
	var picked := []
	drawer.picked.connect(func(sides: int, color: Variant) -> void: picked.append([sides, color]))
	drawer.open(tool._plus, true)
	drawer.pointer_move(_row_centre(drawer, 6))
	assert_false(drawer.colors_are_out(), "not at once")
	drawer._process(DiceDrawer.DWELL_SECONDS + 0.1)
	assert_true(drawer.colors_are_out())
	await wait_seconds(DiceDrawer.SLIDE_SECONDS + 0.1)
	var strip := drawer.strip_rect(6)
	assert_lt(strip.end.x, drawer.column_rect().position.x, "out to the side of the die")
	assert_almost_eq(strip.position.y, drawer.column_rect().position.y + 6 * DiceDrawer.ROW_HEIGHT, 0.5, "level with it")
	var swatch := drawer.swatch_rect(6, 4).get_center()
	drawer.pointer_move(swatch)
	drawer.pointer_up(swatch)
	assert_eq(picked, [[20, DiceTool.PALETTE[4]]])


func test_moving_to_another_die_puts_the_colours_away() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	var drawer: DiceDrawer = tool._drawer
	drawer.open(tool._plus, true)
	drawer.pointer_move(_row_centre(drawer, 3))
	drawer._process(DiceDrawer.DWELL_SECONDS + 0.1)
	await wait_seconds(0.3)
	drawer.pointer_move(_row_centre(drawer, 4))
	await wait_seconds(DiceDrawer.SLIDE_SECONDS + 0.2)
	assert_false(drawer.colors_are_out())


func test_letting_go_on_the_plus_leaves_the_drawer_open_and_a_tap_outside_closes_it() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	var drawer: DiceDrawer = tool._drawer
	drawer.open(tool._plus, true)
	drawer.pointer_up(Vector2(5, 5))
	assert_true(drawer.is_open, "left open to be touched")
	drawer.pointer_down(Vector2(5, 5))
	drawer.pointer_up(Vector2(5, 5))
	assert_false(drawer.is_open)


func test_tapping_the_plus_opens_the_drawer_and_a_tap_on_a_die_adds_it() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	_press(tool._plus, true)
	_press(tool._plus, false)
	var drawer: DiceDrawer = tool._drawer
	assert_true(drawer.is_open)
	var before := tool._table.dice.size()
	var spot := _row_centre(drawer, 1)
	drawer.pointer_down(spot)
	drawer.pointer_up(spot)
	assert_eq(tool._table.dice.size(), before + 1)
	assert_eq(tool._table.dice[before].sides, 4)
	assert_true(DiceTool.PALETTE.has(tool._table.dice[before].die_color))
	assert_eq(tool.preset.data["dice"].size(), 1, "and it is saved")
	assert_true(drawer.is_open, "opened by a tap, it stays open for more dice")
	var again := _row_centre(drawer, 2)
	drawer.pointer_down(again)
	drawer.pointer_up(again)
	assert_eq(tool._table.dice.size(), before + 2, "a second die without reopening it")
	drawer.pointer_down(Vector2(5, 5))
	drawer.pointer_up(Vector2(5, 5))
	assert_false(drawer.is_open, "a tap outside puts it away")


func test_holding_the_plus_opens_the_drawer_under_the_finger() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	_press(tool._plus, true)
	assert_false(tool._drawer.is_open)
	await wait_seconds(DiceTool.LONG_PRESS_SECONDS + 0.2)
	assert_true(tool._drawer.is_open)
	var spot := tool._drawer.global_position + _row_centre(tool._drawer, 0) - tool._plus.global_position
	var move := InputEventMouseMotion.new()
	move.position = spot
	tool._plus.gui_input.emit(move)
	_press(tool._plus, false, spot)
	assert_eq(tool._table.dice.size(), 1, "released over the coin: a coin")
	assert_eq(tool._table.dice[0].sides, 2)


func test_a_chosen_colour_is_used_and_a_percentile_is_a_pair() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	tool._add_die(8, DiceTool.PALETTE[2])
	assert_eq(tool._table.dice[0].die_color, DiceTool.PALETTE[2])
	tool._add_die(DiceTool.PERCENTILE, null)
	assert_eq(tool._table.dice.size(), 3)
	assert_eq(tool._table.dice[1].die_color, tool._table.dice[2].die_color, "both halves match")


func test_no_die_is_added_past_the_limit() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	for i in DiceTool.MAX_DICE + 3:
		tool._add_die(6, null)
	assert_eq(tool._table.dice.size(), DiceTool.MAX_DICE)


func test_tapping_d100_in_the_drawer_adds_just_the_pair() -> void:
	var tool := _tool()
	await wait_seconds(0.3)
	_press(tool._plus, true)
	_press(tool._plus, false)
	var drawer: DiceDrawer = tool._drawer
	var spot := _row_centre(drawer, DiceTool.DIE_KINDS.find(DiceTool.PERCENTILE))
	drawer.pointer_down(spot)
	drawer.pointer_up(spot)
	assert_eq(tool._table.dice.size(), 2, "a tens die and a units die, nothing else")
	for die in tool._table.dice:
		assert_eq(die.sides, 10)
