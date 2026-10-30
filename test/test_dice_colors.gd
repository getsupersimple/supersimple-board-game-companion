extends GutTest


func _tool(dice: Array) -> DiceTool:
	var preset := Preset.create_default(Preset.Type.DICE)
	preset.data["dice"] = dice
	var tool := DiceTool.new()
	tool.preset = preset
	tool.store = PresetStore.new("user://test_dice_colors.cfg")
	tool.size = Vector2(900, 1500)
	add_child_autofree(tool)
	return tool


func after_all() -> void:
	DirAccess.remove_absolute("user://test_dice_colors.cfg")


func _hold(tool: DiceTool, die: Die) -> void:
	tool._table.die_held.emit(die, Vector2(300, 300))


## Where the middle of choice `index` of a drawer is, as a point of the table's view.
func _choice_at(tool: DiceTool, drawer: ChoiceDrawer, index: int) -> Vector2:
	return drawer.item_rect(index).get_center() + drawer.global_position - tool._container.global_position


func _let_go_at(tool: DiceTool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = at
	tool._on_table_input(event)


func test_there_is_no_list_of_dice_along_the_top_any_more() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.4)
	assert_eq(tool.find_children("*", "DiceStrip", true, false).size(), 0)


func test_holding_a_die_on_the_table_offers_colour_lock_and_remove() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}, {"sides": 8, "color": DiceTool.PALETTE[1]}])
	await wait_seconds(0.5)
	var die: Die = tool._table.dice[1]
	_hold(tool, die)
	var drawer: ChoiceDrawer = tool._die_drawer
	assert_true(drawer.is_open)
	assert_eq(drawer._kinds, ["color", "lock", "remove"], "lock, because the die is not locked")
	die.global_position = Vector3(0, 2.5, 0)
	die.linear_velocity = Vector3(2, 0, 2)
	await wait_seconds(1.0)
	assert_lt(die.global_position.y, 1.2, "pulled down onto the table")
	assert_lt(die.linear_velocity.length(), 0.5, "and settled")
	_let_go_at(tool, Vector2(-300, 900))
	assert_false(die.heavy, "and is free again once the drawer closes")
	assert_false(drawer.is_open, "letting go off the choices closes it")
	assert_eq(tool._table.dice.size(), 2, "and nothing was done")


func test_lock_is_dimmed_and_cannot_be_picked_when_the_die_cannot_lie_flat() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}, {"sides": 6, "color": DiceTool.PALETTE[1]}])
	await wait_seconds(2.5)
	var low: Die = tool._table.dice[0]
	var high: Die = tool._table.dice[1]
	_hold(tool, low)
	assert_false(tool._die_drawer.is_disabled("lock"), "a die lying clear can be locked")
	_let_go_at(tool, Vector2(-300, 900))
	# One die on top of the other cannot be chained.
	high.freeze = true
	high.global_position = low.global_position + Vector3(0, 1.0, 0)
	_hold(tool, high)
	assert_true(tool._die_drawer.is_disabled("lock"), "so the choice is dimmed")
	var at := _choice_at(tool, tool._die_drawer, 1)
	_let_go_at(tool, at)
	assert_false(high.locked, "and letting go on it does nothing")
	assert_false(tool._die_drawer.is_open)


func test_a_locked_die_is_offered_unlock_instead_of_lock() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(2.5)
	var die: Die = tool._table.dice[0]
	_hold(tool, die)
	_let_go_at(tool, _choice_at(tool, tool._die_drawer, 1))
	await wait_seconds(0.6)
	assert_true(die.locked, "the middle choice locked it")
	_hold(tool, die)
	assert_eq(tool._die_drawer._kinds[1], "unlock")
	_let_go_at(tool, _choice_at(tool, tool._die_drawer, 1))
	assert_false(die.locked, "and now the middle choice unlocks it")


func test_remove_takes_the_die_off_the_table_and_it_is_saved() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}, {"sides": 8, "color": DiceTool.PALETTE[1]}])
	await wait_seconds(0.5)
	_hold(tool, tool._table.dice[0])
	_let_go_at(tool, _choice_at(tool, tool._die_drawer, 2))
	assert_eq(tool._table.dice.size(), 1)
	assert_eq(tool.preset.data["dice"].size(), 1, "saved with the preset")


func test_colour_opens_a_row_of_colours_and_a_tap_on_one_paints_the_die() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	var die: Die = tool._table.dice[0]
	_hold(tool, die)
	_let_go_at(tool, _choice_at(tool, tool._die_drawer, 0))
	assert_false(tool._color_drawer.is_open, "the colours go with the drawer when the finger lifts")
	tool._on_color_chosen(die, DiceTool.PALETTE[3])
	assert_eq(die.die_color, DiceTool.PALETTE[3])
	assert_eq(die._surface.albedo_color, DiceTool.PALETTE[3].darkened(0.1))
	assert_eq(die._numerals[0].outline_modulate, DiceTool.PALETTE[3].darkened(0.55), "numerals are outlined in a deep shade of the die")
	assert_eq(tool.preset.data["dice"][0]["color"], DiceTool.PALETTE[3], "saved with the preset")
	assert_false(tool._color_drawer.is_open)


func test_both_halves_of_a_percentile_pair_change_together() -> void:
	var tool := _tool([{"sides": DiceTool.PERCENTILE, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	tool._on_color_chosen(tool._table.dice[0], DiceTool.PALETTE[2])
	for die in tool._table.dice:
		assert_eq(die.die_color, DiceTool.PALETTE[2])


func _finger_on_table(tool: DiceTool, pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	tool._on_table_input(event)


func test_holding_the_bare_table_opens_the_lock_drawer_and_auto_lock_toggles() -> void:
	var tool := _tool([])
	await wait_seconds(0.5)
	var corner := Vector2(30, 30)
	_finger_on_table(tool, true, corner)
	await wait_seconds(DiceTool.LONG_PRESS_SECONDS + 0.2)
	assert_true(tool._lock_drawer.is_open)
	var auto_at: Vector2 = tool._lock_drawer.item_rect(0).get_center() + tool._lock_drawer.global_position - tool._container.global_position
	_finger_on_table(tool, false, auto_at)
	assert_true(tool._table.auto_lock, "slid onto the first and let go")
	assert_true(tool.preset.data["auto_lock"], "kept with the preset")
	assert_false(tool._lock_drawer.is_open)


func test_auto_lock_locks_dice_that_land_flat_and_unlock_all_frees_them() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	tool._table.auto_lock = true
	await wait_seconds(4.0)
	var die: Die = tool._table.dice[0]
	assert_true(die.locked, "it locked once it lay flat")
	tool._table.unlock_all()
	assert_false(die.locked)


func _move_to(tool: DiceTool, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	tool._on_table_input(event)


func test_pointing_at_colour_pops_the_colours_out_above_at_once_and_letting_go_on_one_paints() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	var die: Die = tool._table.dice[0]
	tool._table.die_held.emit(die, Vector2(300, 800))
	assert_false(tool._color_drawer.is_open, "not before the finger points at it")
	_move_to(tool, _choice_at(tool, tool._die_drawer, 0))
	assert_true(tool._color_drawer.is_open, "out as soon as it is pointed at")
	assert_lt(tool._color_drawer.rect().end.y, tool._die_drawer.rect().position.y, "above the drawer")
	var swatch := _choice_at(tool, tool._color_drawer, 4)
	_move_to(tool, swatch)
	_let_go_at(tool, swatch)
	assert_eq(die.die_color, DiceTool.PALETTE[4])
	assert_false(tool._color_drawer.is_open)
	assert_false(tool._die_drawer.is_open, "and the drawer goes with it")
	assert_false(die.heavy, "the die is let go")


func test_unlock_all_leaves_dice_free_for_a_second_even_with_auto_lock_on() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	tool._table.auto_lock = true
	await wait_seconds(4.0)
	var die: Die = tool._table.dice[0]
	assert_true(die.locked)
	tool._table.unlock_all()
	await wait_seconds(0.8)
	assert_false(die.locked, "still free just after")
	await wait_seconds(2.0)
	assert_true(die.locked, "and locked again afterwards")


func _finger_at_table(tool: DiceTool, pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	tool._on_table_input(event)


func test_a_swipe_after_a_long_press_on_the_bare_table_throws_the_dice() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(1.5)
	var die: Die = tool._table.dice[0]
	die.linear_velocity = Vector3.ZERO
	_finger_at_table(tool, true, Vector2(100, 400))
	await wait_seconds(DiceTool.LONG_PRESS_SECONDS + 0.2)
	assert_true(tool._lock_drawer.is_open)
	_finger_at_table(tool, false, Vector2(500, 400))
	assert_gt(die.linear_velocity.x, 3.0, "thrown to the right")


func test_a_swipe_without_a_long_press_does_not_throw_and_is_left_for_the_screen() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(1.5)
	assert_true(tool.accepts_swipe(), "the screen may take it")
	var die: Die = tool._table.dice[0]
	die.linear_velocity = Vector3.ZERO
	_finger_at_table(tool, true, Vector2(100, 400))
	_finger_at_table(tool, false, Vector2(500, 400))
	assert_lt(die.linear_velocity.length(), 1.0, "nothing was thrown")


func test_a_swipe_that_has_begun_drops_the_press_waiting_to_become_a_long_press() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	_finger_at_table(tool, true, Vector2(100, 400))
	tool.cancel_press()
	await wait_seconds(DiceTool.LONG_PRESS_SECONDS + 0.2)
	assert_false(tool._lock_drawer.is_open, "no action bar opens during a swipe")


func test_every_colours_tally_is_the_same_width() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}, {"sides": 6, "color": DiceTool.PALETTE[1]}])
	await wait_seconds(0.5)
	tool._show_totals({DiceTool.PALETTE[0]: 7, DiceTool.PALETTE[1]: 123})
	await wait_frames(2)
	var widths := []
	for pill in tool._totals.get_children():
		widths.append(pill.size.x)
	assert_eq(widths.size(), 2)
	assert_eq(widths[0], widths[1])


func test_totals_for_a_die_of_every_colour_fit_across_the_screen() -> void:
	var saved: Array = []
	for color in DiceTool.PALETTE:
		saved.append({"sides": 6, "color": color})
	var tool := _tool(saved)
	await wait_seconds(0.5)
	tool._show_totals({
		DiceTool.PALETTE[0]: 1600, DiceTool.PALETTE[1]: 1600, DiceTool.PALETTE[2]: 1600,
		DiceTool.PALETTE[3]: 1600, DiceTool.PALETTE[4]: 1600, DiceTool.PALETTE[5]: 1600,
	})
	await wait_seconds(0.2)
	var last: Control = tool._totals.get_child(tool._totals.get_child_count() - 1)
	assert_lte(last.get_global_rect().end.x, tool.get_global_rect().end.x, "the last total is on the screen")


func test_each_die_that_has_settled_gets_a_pill_beside_it_with_what_it_shows() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}, {"sides": 20, "color": DiceTool.PALETTE[1]}])
	await wait_seconds(3.0)
	assert_eq(tool._scores.size(), 2, "one pill for each die")
	for die: Die in tool._scores:
		var pill: PanelContainer = tool._scores[die]
		assert_eq((pill.get_child(0) as Label).text, str(die.read_value()))
		var centre := tool._table.camera.unproject_position(die.global_position)
		assert_true(pill.position.x > centre.x or pill.position.x + pill.size.x < centre.x, "beside the die, not over its middle")
	tool._table.remove_die(tool._table.dice[0])
	await wait_seconds(0.3)
	assert_eq(tool._scores.size(), 1, "a die taken off takes its pill")


func test_a_single_die_unlocked_stays_free_for_a_second_even_with_auto_lock_on() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(0.5)
	tool._table.auto_lock = true
	await wait_seconds(4.0)
	var die: Die = tool._table.dice[0]
	assert_true(die.locked)
	die.set_locked(false)
	await wait_seconds(0.8)
	assert_false(die.locked, "still free just after")
	await wait_seconds(2.0)
	assert_true(die.locked, "and locked again afterwards")


func test_a_dice_tool_offers_the_colours_of_its_theme() -> void:
	var preset := Preset.create_default(Preset.Type.DICE)
	preset.theme = "dnd"
	var tool := DiceTool.new()
	tool.preset = preset
	tool.store = PresetStore.new("user://test_dice_colors.cfg")
	tool.size = Vector2(900, 1500)
	add_child_autofree(tool)
	await wait_seconds(0.3)
	assert_eq(tool._palette, Themes.palette("dnd"))
	tool._add_die(6, null)
	assert_true(Themes.palette("dnd").has(tool._table.dice[0].die_color), "a random die is one of the theme's colours")


func test_a_pill_waits_for_the_die_to_lie_still_for_300_ms_and_then_grows_out_with_a_spring() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(3.0)
	tool.set_process(false)
	var die: Die = tool._table.dice[0]
	assert_true(die.is_at_rest())
	for gone in tool._scores.values():
		gone.queue_free()
	tool._scores.clear()
	tool._pops.clear()
	tool._settled_for.clear()
	tool._place_scores(0.15)
	assert_eq(tool._scores.size(), 0, "not yet: it has only been still for 150 ms")
	tool._place_scores(0.1)
	assert_eq(tool._scores.size(), 0, "250 ms is not enough either")
	tool._place_scores(0.1)
	assert_eq(tool._scores.size(), 1, "300 ms is")
	var pill: Control = tool._scores[die]
	assert_lt(pill.scale.x, 0.9, "it starts small")
	var biggest := 0.0
	for i in 40:
		tool._place_scores(0.03)
		biggest = maxf(biggest, pill.scale.x)
	assert_gt(biggest, 1.0, "it overshoots a little, like the other animations")
	assert_almost_eq(pill.scale.x, 1.0, 0.03)


func test_a_pill_shrinks_away_when_its_die_moves_and_does_not_blink() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(3.0)
	tool.set_process(false)
	var die: Die = tool._table.dice[0]
	for i in 40:
		tool._place_scores(0.03)
	assert_eq(tool._scores.size(), 1)
	# A moment of jitter does not take it away.
	tool._moving_for[die] = 0.05
	tool._place_scores(0.01)
	assert_almost_eq((tool._scores[die] as Control).scale.x, 1.0, 0.05)
	die.linear_velocity = Vector3(5, 0, 0)
	for i in 3:
		tool._place_scores(0.05)
	assert_true(tool._scores.has(die), "still on its way out")
	assert_lt((tool._scores[die] as Control).scale.x, 0.95, "shrinking")
	for i in 40:
		tool._place_scores(0.05)
	assert_eq(tool._scores.size(), 0, "gone once it has shrunk")


func test_pressing_a_total_shows_only_the_dice_of_that_colour_until_the_finger_lifts() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}, {"sides": 8, "color": DiceTool.PALETTE[1]}, {"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(3.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	tool._on_total_input(press, DiceTool.PALETTE[1])
	for die in tool._table.dice:
		assert_eq(die.visible, die.die_color == DiceTool.PALETTE[1], "only the matching colour shows")
	var lift := InputEventMouseButton.new()
	lift.button_index = MOUSE_BUTTON_LEFT
	lift.pressed = false
	tool._on_total_input(lift, DiceTool.PALETTE[1])
	for die in tool._table.dice:
		assert_true(die.visible, "all back")


func test_a_die_is_only_picked_up_by_a_long_press_and_a_finger_that_moves_first_is_swiping() -> void:
	var tool := _tool([{"sides": 6, "color": DiceTool.PALETTE[0]}])
	await wait_seconds(3.0)
	var die: Die = tool._table.dice[0]
	var at := tool._table.camera.unproject_position(die.global_position)
	_finger_at_table(tool, true, at)
	assert_false(tool._table.is_dragging(), "a touch alone does not pick it up")
	var move := InputEventMouseMotion.new()
	move.position = at + Vector2(80, 0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	tool._on_table_input(move)
	await wait_seconds(DiceTool.LONG_PRESS_SECONDS + 0.2)
	assert_false(tool._table.is_dragging(), "moving first made it a swipe, so the long press never comes")
	assert_true(tool.accepts_swipe())
	_finger_at_table(tool, false, at + Vector2(80, 0))
	_finger_at_table(tool, true, at)
	await wait_seconds(DiceTool.LONG_PRESS_SECONDS + 0.2)
	assert_true(tool._table.is_dragging() or tool._die_drawer.is_open, "kept still, the die is picked up")
	_finger_at_table(tool, false, at)


func test_dice_saved_in_colours_from_before_palettes_become_the_nearest_of_the_palette() -> void:
	var tool := _tool([{"sides": 6, "color": Color("#4F7CFF")}, {"sides": 6, "color": Color("#F5A524")}])
	await wait_seconds(0.5)
	for die in tool._table.dice:
		assert_true(tool._palette.has(die.die_color), "a palette colour")
	assert_eq(tool._table.dice[0].die_color, Themes.palette("standard")[0])
	assert_eq(tool._table.dice[1].die_color, Themes.palette("standard")[2])
