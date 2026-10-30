extends GutTest

const SCENE := preload("res://scenes/game/game_screen.tscn")

var _screen: GameScreen
var _store: PresetStore


func before_each() -> void:
	_store = PresetStore.new("user://test_game_screen.cfg")
	_store.load_store()
	var game := _store.get_game(PresetStore.QUICK_ID)
	game.presets.clear()
	for preset_type in [Preset.Type.DICE, Preset.Type.HOURGLASS]:
		_store.add_preset(PresetStore.QUICK_ID, Preset.create_default(preset_type))
	_screen = SCENE.instantiate()
	_screen.size = Vector2(1080, 1920)
	add_child_autofree(_screen)
	_screen.open_game(_store, PresetStore.QUICK_ID)


func after_each() -> void:
	DirAccess.remove_absolute("user://test_game_screen.cfg")


func test_the_tools_buttons_sit_in_the_top_bar_level_with_the_back_button() -> void:
	await wait_seconds(0.4)
	var back: Rect2 = _screen._back_button.get_global_rect()
	var plus: Rect2 = _screen._tool.top_buttons()[0].get_global_rect()
	assert_eq(plus.size, back.size, "the same size")
	assert_almost_eq(plus.position.y, back.position.y, 0.5, "on the same line")
	assert_almost_eq(plus.end.x, _screen.size.x - 48.0, 0.5, "at the right edge")


func test_the_timer_has_the_kind_of_timer_button_in_the_top_bar() -> void:
	_screen._on_chip_tapped(_screen.game.presets[1].id)
	await wait_seconds(0.4)
	assert_eq(_screen._actions.get_child_count(), 1, "hourglass or digital")


func test_tapping_the_tool_that_is_showing_taps_it_again_and_another_switches() -> void:
	await wait_seconds(0.3)
	var dice: DiceTool = _screen._tool
	var rolls := [0]
	dice._table.results_changed.connect(func(_values: Array) -> void: rolls[0] += 1)
	_screen._on_chip_tapped(_screen.active_preset_id)
	assert_same(_screen._tool, dice, "the same tool, not a new one")
	_screen._on_chip_tapped(_screen.game.presets[1].id)
	assert_true(_screen._tool is HourglassTool)


func _press_add(pressed: bool, at: Vector2 = Vector2(10, 10)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_screen._add_button.gui_input.emit(event)


func test_a_tap_on_the_add_button_opens_the_drawer_and_a_tap_on_a_kind_adds_it() -> void:
	await wait_seconds(0.3)
	_press_add(true)
	_press_add(false)
	assert_true(_screen._picker.is_open)
	var before := _screen.game.presets.size()
	var spot := _screen._picker.row_rect(1).get_center()
	_screen._picker.pointer_down(spot)
	_screen._picker.pointer_up(spot)
	assert_eq(_screen.game.presets.size(), before + 1)
	assert_true(_screen._tool is BuzzerTool)
	assert_eq(_screen.game.presets[before].icon, "bell", "with its own icon")
	assert_false(_screen._picker.is_open)


func test_holding_the_add_button_opens_the_drawer_under_the_finger_and_letting_go_closes_it() -> void:
	await wait_seconds(0.3)
	_press_add(true)
	await wait_seconds(GameScreen.ADD_LONG_PRESS_SECONDS + 0.2)
	assert_true(_screen._picker.is_open)
	var before := _screen.game.presets.size()
	# The finger slides from the button onto a kind and lets go.
	var spot: Vector2 = _screen._picker.row_rect(2).get_center() + _screen._picker.global_position - _screen._add_button.global_position
	_press_add(false, spot)
	assert_false(_screen._picker.is_open, "closed by the release")
	assert_eq(_screen.game.presets.size(), before + 1)
	assert_true(_screen._tool is HourglassTool)


func test_holding_a_kind_pulls_out_the_theme_drawer_to_its_left_and_one_can_be_chosen() -> void:
	await wait_seconds(0.3)
	_press_add(true)
	_press_add(false)
	var picker: ToolPicker = _screen._picker
	var row := 0
	picker.pointer_down(picker.row_rect(row).get_center())
	await wait_seconds(ToolPicker.DWELL_SECONDS + 0.2)
	assert_true(picker.themes_are_out())
	var drawer := picker.theme_drawer()
	assert_lt(drawer.rect().end.x, picker.row_rect(row).position.x, "to its left")
	assert_eq(drawer._kinds, Themes.NAMES, "the themes, in place of icons")
	var before := _screen.game.presets.size()
	var dnd := drawer.item_rect(0).get_center()
	picker.pointer_move(dnd)
	picker.pointer_up(dnd)
	assert_eq(_screen.game.presets.size(), before + 1)
	assert_eq(_screen.game.presets[before].theme, "dnd", "wearing the chosen theme")
	assert_eq(AppSettings.sound_theme, "rpg", "and making its sounds")
	assert_eq(_screen.game.presets[before].type, Preset.Type.DICE)
	assert_false(picker.is_open)


func test_sliding_from_a_kind_across_the_gap_onto_its_themes_keeps_them_out() -> void:
	await wait_seconds(0.3)
	_press_add(true)
	_press_add(false)
	var picker: ToolPicker = _screen._picker
	picker.pointer_down(picker.row_rect(1).get_center())
	await wait_seconds(ToolPicker.DWELL_SECONDS + 0.2)
	assert_true(picker.themes_are_out())
	# Along the way the finger is over neither a kind nor an icon.
	var gap_point := Vector2(picker.column_rect().position.x - 2.0, picker.row_rect(1).get_center().y)
	picker.pointer_move(gap_point)
	assert_true(picker.themes_are_out(), "still out in the gap")
	var target := picker.theme_drawer().item_rect(3).get_center()
	picker.pointer_move(target)
	assert_true(picker.themes_are_out())
	var before := _screen.game.presets.size()
	picker.pointer_up(target)
	assert_eq(_screen.game.presets[before].theme, Themes.NAMES[3])


func test_many_tools_keep_the_add_button_in_view_and_the_toolbar_scrolls() -> void:
	for i in 20:
		_store.add_preset(PresetStore.QUICK_ID, Preset.create_default(Preset.Type.BUZZER))
	_screen.open_game(_store, PresetStore.QUICK_ID)
	await wait_seconds(0.4)
	assert_gt(_screen._dock.max_scroll(), 0.0)
	var add: Rect2 = _screen._add_button.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, _screen.size).encloses(add), "the add button is on screen")
	assert_lt(_screen._bar_slot.get_global_rect().end.x, add.position.x, "beside the toolbar, not in it")
	assert_lt(add.end.y, _screen.size.y - 100.0, "clear of the swipe-up edge")


func test_dropping_a_tool_on_the_screen_keeps_it_there_and_out_of_the_toolbar() -> void:
	await wait_seconds(0.3)
	var id := _screen.game.presets[1].id
	_screen._on_placed_on_screen(id, Vector2(0.3, 0.4))
	assert_true(_screen.game.find_preset(id).has_position)
	assert_eq(_screen._dock.bar_ids(), [_screen.game.presets[0].id])
	_screen._on_placed_in_bar(id, 0)
	assert_false(_screen.game.find_preset(id).has_position)
	assert_eq(_screen.game.presets[0].id, id)


func test_leaving_the_game_frees_the_tool_so_nothing_runs_on() -> void:
	await wait_seconds(0.3)
	var tool: Control = _screen._tool
	assert_true(tool.is_inside_tree())
	_screen.close_game()
	assert_null(_screen._tool)
	assert_false(tool.is_inside_tree(), "taken out of the tree at once")
	assert_eq(_screen._actions.get_child_count(), 0)


func _dock_touch(pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_screen._dock._gui_input(event)


func _dock_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_screen._dock._gui_input(event)


func _hold_tool(index: int) -> Vector2:
	var at: Vector2 = _screen._dock.chip_center(_screen.game.presets[index].id)
	_dock_touch(true, at)
	await wait_seconds(ToolDock.LONG_PRESS_SECONDS + 0.2)
	return at


func _menu_at(index: int) -> Vector2:
	var menu: ChoiceDrawer = _screen._hold_menu.menu
	return menu.item_rect(index).get_center() + menu.global_position


func test_holding_a_tool_opens_the_menu_and_the_icon_can_be_changed_with_the_same_drawer() -> void:
	await wait_seconds(0.4)
	await _hold_tool(1)
	assert_true(_screen._hold_menu.is_open)
	assert_eq(_screen._hold_menu.menu._kinds, ["icon", "color", "theme", "delete"])
	_dock_move(_menu_at(0))
	var drawer: ChoiceDrawer = _screen._hold_menu.icon_drawer
	assert_true(drawer.is_open, "the icons pop out")
	assert_eq(drawer._kinds, Themes.icon_set("standard"), "the icons of the tool's theme")
	var target := drawer.item_rect(7).get_center() + drawer.global_position
	_dock_move(target)
	_dock_touch(false, target)
	assert_eq(_screen.game.presets[1].icon, Themes.icon_set("standard")[7])
	assert_eq(_screen._dock.chip_for(_screen.game.presets[1].id).preset.icon, Themes.icon_set("standard")[7])


func test_letting_go_of_the_long_press_away_from_the_choices_closes_the_menu() -> void:
	await wait_seconds(0.4)
	var at := await _hold_tool(1)
	assert_true(_screen._hold_menu.is_open)
	_dock_touch(false, at)
	assert_false(_screen._hold_menu.is_open, "the bar goes with the finger")
	assert_false(_screen._hold_menu.menu.is_open)


func test_a_tool_can_be_given_another_theme_from_the_menu() -> void:
	await wait_seconds(0.4)
	await _hold_tool(0)
	_dock_move(_menu_at(2))
	var drawer: ChoiceDrawer = _screen._hold_menu.theme_drawer
	assert_true(drawer.is_open, "the themes pop out")
	assert_eq(drawer._kinds, Themes.NAMES)
	var target := drawer.item_rect(0).get_center() + drawer.global_position
	_dock_move(target)
	_dock_touch(false, target)
	assert_eq(_screen.game.presets[0].theme, "dnd")
	assert_eq(AppSettings.sound_theme, "rpg", "the tool on show makes the sounds of its theme")


func test_a_tool_added_with_a_theme_starts_in_its_colour_and_the_menu_offers_its_palette() -> void:
	await wait_seconds(0.3)
	_screen._on_type_picked(Preset.Type.BUZZER, "futuristic")
	var added: Preset = _screen.game.presets[_screen.game.presets.size() - 1]
	assert_eq(added.color, Themes.palette("futuristic")[2])
	_screen._on_dock_held(added.id, Vector2(100, 100))
	assert_eq(_screen._hold_menu.color_drawer._swatches, Themes.palette("futuristic"))


func test_each_tool_on_show_sets_the_sounds_of_its_own_theme() -> void:
	await wait_seconds(0.3)
	_screen.game.presets[1].theme = "dnd"
	_screen.step_tool(1)
	assert_eq(AppSettings.sound_theme, "rpg")
	_screen.step_tool(-1)
	assert_eq(AppSettings.sound_theme, "future")


func test_a_tool_comes_back_as_it_was_left_when_you_go_to_another_and_return() -> void:
	await wait_seconds(0.5)
	var dice: DiceTool = _screen._tool
	dice._add_die(6, DiceTool.PALETTE[0])
	await wait_seconds(1.5)
	var die: Die = dice._table.dice[0]
	die.set_locked(true)
	_screen.step_tool(1)
	await wait_seconds(0.5)
	assert_true(_screen._tool is HourglassTool)
	assert_false(dice.is_inside_tree(), "kept out of the tree while away")
	_screen.step_tool(-1)
	await wait_seconds(0.5)
	assert_same(_screen._tool, dice, "the same tool, not a new one")
	assert_true(dice._table.dice[0].locked, "the die is still locked")
	assert_not_null(dice.top_buttons()[0].get_parent())
	assert_eq(dice.top_buttons()[0].get_parent(), _screen._actions, "its + button is back in the top bar")


func test_a_tool_that_comes_back_fills_the_screen_as_it_did_before() -> void:
	await wait_seconds(0.5)
	var dice: Control = _screen._tool
	var size_before := dice.size
	_screen.step_tool(1)
	await wait_seconds(0.5)
	_screen.step_tool(-1)
	await wait_seconds(0.5)
	assert_same(_screen._tool, dice)
	assert_eq(dice.size, size_before, "not twice the size")
	assert_eq(dice.position, Vector2.ZERO)


func test_deleting_a_tool_frees_the_one_that_was_kept() -> void:
	await wait_seconds(0.4)
	var dice: Control = _screen._tool
	var id := _screen.game.presets[0].id
	_screen.step_tool(1)
	await wait_seconds(0.4)
	_screen._on_delete_requested(id)
	await wait_seconds(0.4)
	assert_false(is_instance_valid(dice) and dice.is_inside_tree())
	assert_false(_screen._kept.has(id))


func test_a_tool_can_be_given_another_colour_from_the_menu() -> void:
	await wait_seconds(0.4)
	await _hold_tool(1)
	_dock_move(_menu_at(1))
	var drawer: ChoiceDrawer = _screen._hold_menu.color_drawer
	assert_true(drawer.is_open)
	var target := drawer.item_rect(2).get_center() + drawer.global_position
	_dock_move(target)
	_dock_touch(false, target)
	assert_eq(_screen.game.presets[1].color, Themes.palette("standard")[2])


func test_delete_in_the_menu_removes_the_tool() -> void:
	await wait_seconds(0.4)
	var gone := _screen.game.presets[1].id
	await _hold_tool(1)
	var target := _menu_at(3)
	_dock_move(target)
	_dock_touch(false, target)
	assert_null(_screen.game.find_preset(gone))


func test_dragging_a_held_tool_away_from_the_menu_picks_it_up_and_places_it_on_the_screen() -> void:
	await wait_seconds(0.4)
	var moved := _screen.game.presets[1].id
	var at := await _hold_tool(1)
	_dock_move(at + Vector2(-300, 0))
	assert_false(_screen._hold_menu.is_open, "the menu goes")
	_dock_move(Vector2(500, 600))
	_dock_touch(false, Vector2(500, 600))
	assert_true(_screen.game.find_preset(moved).has_position, "left on the screen")


func test_the_colours_pop_out_above_the_menu_like_the_icons_do() -> void:
	await wait_seconds(0.4)
	await _hold_tool(1)
	_dock_move(_menu_at(1))
	var colors: ChoiceDrawer = _screen._hold_menu.color_drawer
	var menu: ChoiceDrawer = _screen._hold_menu.menu
	assert_true(colors.is_open)
	assert_lt(colors.rect().end.y, menu.rect().position.y, "above, not below")


func test_swiping_steps_to_the_next_and_previous_tool_and_stops_at_the_ends() -> void:
	await wait_seconds(0.4)
	assert_true(_screen._tool is DiceTool)
	assert_false(_screen.step_tool(-1), "nothing before the first")
	assert_true(_screen.step_tool(1))
	assert_true(_screen._tool is HourglassTool)
	assert_eq(_screen.active_preset_id, _screen.game.presets[1].id)
	assert_false(_screen.step_tool(1), "nothing after the last")
	assert_true(_screen.step_tool(-1))
	assert_true(_screen._tool is DiceTool)


func _finger(pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	_screen._input(event)


func _finger_to(at: Vector2, step: float = 0.0) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	move.relative = Vector2(step, 0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	_screen._input(move)


func _swipe(from: Vector2, to: Vector2) -> void:
	_finger(true, from)
	_finger_to(to)
	_finger(false, to)


## The tests of swiping between tools start on the timer, so the next tool is the dice.
func _timer_first() -> void:
	_screen.game.presets.reverse()
	_screen.open_game(_store, PresetStore.QUICK_ID)


func test_the_tool_follows_the_finger_and_slides_back_if_the_finger_does() -> void:
	_timer_first()
	await wait_seconds(0.4)
	var middle: Vector2 = _screen._tool_host.get_global_rect().get_center()
	var dice: Control = _screen._tool
	_finger(true, middle)
	_finger_to(middle + Vector2(-200, 10))
	assert_almost_eq(dice.position.x, -200.0, 0.5, "it goes where the finger goes")
	assert_eq(dice.modulate.a, 1.0, "and does not fade")
	_finger_to(middle + Vector2(-50, 10))
	assert_almost_eq(dice.position.x, -50.0, 0.5, "and comes back with it, without lifting")
	_finger(false, middle + Vector2(-50, 10))
	assert_same(_screen._tool, dice, "let go short of the way: the same tool")
	await wait_seconds(0.5)
	assert_almost_eq(dice.position.x, 0.0, 0.5, "springs home")
	assert_almost_eq(dice.modulate.a, 1.0, 0.01)


func test_the_next_tool_is_already_running_and_comes_in_with_the_finger() -> void:
	_timer_first()
	await wait_seconds(0.4)
	var middle: Vector2 = _screen._tool_host.get_global_rect().get_center()
	var width: float = _screen._tool_host.size.x
	var dice: Control = _screen._tool
	_finger(true, middle)
	_finger_to(middle + Vector2(-200, 10))
	var glass: Control = _screen._incoming
	assert_true(glass is DiceTool, "the next tool is there while the finger is down")
	assert_true(glass.is_inside_tree(), "and running")
	assert_almost_eq(glass.position.x, _screen.get_viewport_rect().size.x - 200.0, 0.5, "a screen width behind the first")
	_finger_to(middle + Vector2(200, 10))
	assert_true(_screen._incoming == null or _screen._incoming_direction == -1, "heading the other way, the right-hand tool goes")
	_finger_to(middle + Vector2(-200, 10))
	var again: Control = _screen._incoming
	_finger(false, middle + Vector2(-width * 0.4, 10))
	assert_same(_screen._tool, again, "the very tool that came in is the one shown, not a fresh one")
	await wait_seconds(0.5)
	assert_almost_eq(again.position.x, 0.0, 0.5)
	assert_false(is_instance_valid(dice) and dice.is_inside_tree(), "the old one has gone")


func test_a_sideways_swipe_across_the_tool_switches_tools_and_a_vertical_or_short_one_does_not() -> void:
	_timer_first()
	await wait_seconds(0.4)
	var middle: Vector2 = _screen._tool_host.get_global_rect().get_center()
	_swipe(middle, middle + Vector2(-100, 0))
	assert_true(_screen._tool is HourglassTool, "too short")
	_swipe(middle, middle + Vector2(-100, 400))
	assert_true(_screen._tool is HourglassTool, "mostly vertical")
	var far: float = _screen._tool_host.size.x * 0.4
	_swipe(middle, middle + Vector2(-far, 20))
	assert_true(_screen._tool is DiceTool, "left goes to the next")
	await wait_seconds(0.5)
	_swipe(middle, middle + Vector2(far, 20))
	assert_true(_screen._tool is HourglassTool, "right goes back")


func test_a_swipe_that_starts_on_the_toolbar_does_nothing() -> void:
	await wait_seconds(0.4)
	var low: Vector2 = _screen._bar_slot.get_global_rect().get_center()
	_swipe(low, low + Vector2(-400, 0))
	assert_true(_screen._tool is DiceTool)


func test_deleting_the_tool_on_show_slides_to_the_one_on_its_left() -> void:
	_store.add_preset(PresetStore.QUICK_ID, Preset.create_default(Preset.Type.BUZZER))
	_screen._on_chip_tapped(_screen.game.presets[1].id)
	await wait_seconds(0.5)
	var gone: String = _screen.active_preset_id
	var left: String = _screen.game.presets[0].id
	var old_tool: Control = _screen._tool
	_screen._on_delete_requested(gone)
	assert_eq(_screen.active_preset_id, left, "the one on its left")
	assert_lt(_screen._tool.position.x, 0.0, "coming in from the left")
	assert_true(is_instance_valid(old_tool) and old_tool.is_inside_tree(), "and the deleted one still on show, sliding out")
	await wait_seconds(0.6)
	assert_almost_eq(_screen._tool.position.x, 0.0, 1.0)
	assert_false(is_instance_valid(old_tool) and old_tool.is_inside_tree(), "gone")


func test_deleting_the_first_tool_slides_in_the_one_that_takes_its_place() -> void:
	var first: String = _screen.active_preset_id
	var next: String = _screen.game.presets[1].id
	_screen._on_delete_requested(first)
	assert_eq(_screen.active_preset_id, next)
	assert_gt(_screen._tool.position.x, 0.0, "from the right, as there is nothing on the left")
