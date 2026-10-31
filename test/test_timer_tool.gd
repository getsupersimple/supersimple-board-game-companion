extends GutTest

var _store: PresetStore


func before_each() -> void:
	_store = PresetStore.new("user://test_timer_tool.cfg")
	_store.load_store()


func after_each() -> void:
	DirAccess.remove_absolute("user://test_timer_tool.cfg")


func _timer(data: Dictionary = {}) -> HourglassTool:
	var preset := Preset.create_default(Preset.Type.HOURGLASS)
	preset.data = data
	var tool := HourglassTool.new()
	tool.preset = preset
	tool.store = _store
	tool.size = Vector2(1080, 1700)
	add_child_autofree(tool)
	return tool


func test_opening_one_drawer_puts_the_other_away() -> void:
	var tool := _timer()
	var first := ChoiceDrawer.new()
	first.setup(HourglassTool.KINDS, HourglassTool.KIND_ICONS)
	var second := ChoiceDrawer.new()
	second.setup(HourglassTool.KINDS, HourglassTool.KIND_ICONS)
	tool.add_child(first)
	tool.add_child(second)
	first.open(Vector2(300, 300), "", false)
	second.open(Vector2(300, 900), "", false)
	assert_false(first.is_open, "only one at a time")
	assert_true(second.is_open)
	tool._menu.open(Vector2(300, 300), "", false)
	assert_false(second.is_open, "whichever the owner")


func test_a_menu_and_the_list_it_pops_out_stay_open_together() -> void:
	var menu := HoldMenu.new()
	add_child_autofree(menu)
	menu.open(Vector2(500, 1500), Vector2(500, 1700), "star", Color.RED, true, true)
	menu.icon_drawer.open_below(menu.menu.rect(), "star", false)
	assert_true(menu.menu.is_open)
	assert_true(menu.icon_drawer.is_open)
	var tool := _timer()
	tool._menu.open(Vector2(300, 300), "", false)
	assert_false(menu.menu.is_open, "another button's drawer puts the whole menu away")
	assert_false(menu.icon_drawer.is_open)


func test_the_hourglass_menu_toggles_gravity_and_picks_the_sound() -> void:
	var tool := _timer()
	tool._open_menu(Vector2(500, 900))
	assert_true(tool._menu.is_open)
	assert_eq(tool._menu._kinds, ["gravity", "color", "sound"])
	tool._on_menu_picked("gravity")
	assert_true(tool.preset.data["timed"])
	tool._on_menu_picked("gravity")
	assert_false(tool.preset.data["timed"])
	tool._menu.close()
	tool._menu_down = false
	tool._open_menu(Vector2(500, 900))
	tool._menu.pointer_move(tool._menu.item_rect(2).get_center())
	assert_true(tool._alarm_drawer.is_open, "the sounds pop out beside it")
	assert_true(tool._menu.is_open, "and stay with it")
	tool._alarm_drawer.pointer_move(tool._alarm_drawer.item_rect(3).get_center())
	tool._release_menu(tool._alarm_drawer.item_rect(3).get_center())
	assert_eq(tool.preset.data["alarm"], "horn")
	assert_false(tool._alarm_drawer.is_open)
	assert_false(tool._menu.is_open)


func test_letting_go_on_the_menu_puts_its_list_away_with_it() -> void:
	var tool := _timer()
	tool._open_menu(Vector2(500, 900))
	var on_sound: Vector2 = tool._menu.item_rect(2).get_center()
	tool._menu.pointer_move(on_sound)
	assert_true(tool._alarm_drawer.is_open)
	tool._release_menu(on_sound)
	assert_false(tool._menu.is_open)
	assert_false(tool._alarm_drawer.is_open, "at the same time")


func test_the_digital_menu_has_no_gravity_and_colours_the_numbers() -> void:
	var tool := _timer()
	tool._choose_kind("digital")
	tool._open_menu(Vector2(500, 900))
	assert_eq(tool._menu._kinds, ["color", "sound"])
	tool._menu.pointer_move(tool._menu.item_rect(0).get_center())
	assert_true(tool._digits_drawer.is_open)
	var swatch: Vector2 = tool._digits_drawer.item_rect(2).get_center()
	tool._digits_drawer.pointer_move(swatch)
	tool._release_menu(swatch)
	assert_eq(tool.preset.data["digits"], Themes.palette(tool.preset.theme)[2])
	assert_eq(tool._digital.digit_color, Themes.palette(tool.preset.theme)[2])
	assert_false(tool._menu.is_open)
	assert_false(tool._digits_drawer.is_open)


func test_letting_go_away_from_the_menu_starts_the_timer_over() -> void:
	var tool := _timer({"timed": true, "seconds": 5})
	await wait_seconds(1.0)
	var before: int = tool._sand.remaining_ms()
	tool._open_menu(Vector2(500, 900))
	tool._release_menu(Vector2(100, 1500))
	assert_false(tool._menu.is_open)
	assert_gt(tool._sand.remaining_ms(), before - 1, "poured back to the top")


func test_the_top_right_button_switches_between_hourglass_and_digital() -> void:
	var tool := _timer()
	assert_eq(tool.top_buttons().size(), 1)
	assert_eq(tool._type_button.icon, IconLibrary.get_icon("timer"), "the hourglass view offers the clock")
	tool._type_button.pressed.emit()
	assert_eq(tool._type_button.icon, IconLibrary.get_icon("hourglass"), "and the digital view the hourglass")
	assert_eq(tool.preset.data["kind"], "digital")
	assert_true(tool._digital.visible)
	tool._type_button.pressed.emit()
	assert_eq(tool.preset.data["kind"], "hourglass")


func test_the_alarm_is_chosen_by_icon_and_kept() -> void:
	var tool := _timer()
	tool._choose_alarm("horn")
	assert_eq(tool.preset.data["alarm"], "horn")
	assert_eq(tool._alarm(), "horn")
	var other := _timer({"alarm": "nonsense"})
	assert_eq(other._alarm(), TimerAlert.DEFAULT_ALARM, "an unknown one falls back")


func test_the_digital_kind_shows_the_led_display_and_turns_gravity_off() -> void:
	var tool := _timer()
	assert_false(tool._digital.visible)
	tool._choose_kind("digital")
	assert_eq(tool.preset.data["kind"], "digital")
	assert_true(tool._digital.visible)
	assert_false(tool._picture.visible)
	tool._choose_kind("hourglass")
	assert_false(tool._digital.visible)
	assert_true(tool._picture.visible)


func test_the_digital_timer_starts_pauses_and_counts_down() -> void:
	var timer := DigitalTimer.new()
	timer.total_seconds = 5
	add_child_autofree(timer)
	timer.reset()
	timer.toggle()
	assert_true(timer.running)
	await wait_seconds(1.2)
	assert_lt(timer.remaining_ms(), 4000)
	timer.toggle()
	assert_false(timer.running)
	var paused := timer.remaining_ms()
	await wait_seconds(0.4)
	assert_eq(timer.remaining_ms(), paused, "paused time stands still")


func test_the_digital_timer_runs_out_once_and_starts_over_on_the_next_tap() -> void:
	var timer := DigitalTimer.new()
	timer.total_seconds = 1
	add_child_autofree(timer)
	timer.reset()
	var count := []
	timer.finished.connect(func() -> void: count.append(1))
	timer.toggle()
	await wait_seconds(1.3)
	assert_eq(count.size(), 1)
	assert_true(timer.is_finished)
	timer.toggle()
	assert_true(timer.running, "starts again from the top")
	assert_gt(timer.remaining_ms(), 900)


func test_a_held_finger_on_the_digital_timer_opens_the_menu_and_a_tap_starts_it() -> void:
	var timer := DigitalTimer.new()
	timer.total_seconds = 30
	timer.size = Vector2(800, 800)
	add_child_autofree(timer)
	timer.reset()
	var held := []
	timer.held.connect(func(at: Vector2) -> void: held.append(at))
	var press := func(down: bool) -> void:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = Vector2(400, 400)
		timer._gui_input(event)
	press.call(true)
	press.call(false)
	assert_true(timer.running, "a tap starts it")
	await wait_seconds(0.6)
	press.call(true)
	await wait_seconds(DigitalTimer.LONG_PRESS_SECONDS + 0.2)
	press.call(false)
	assert_eq(held, [Vector2(400, 400)], "the owner is told")
	assert_true(timer.running, "and the hold is not a tap")


func test_dragging_the_digital_timer_sets_how_long_it_counts() -> void:
	var timer := DigitalTimer.new()
	timer.total_seconds = 60
	add_child_autofree(timer)
	timer.reset()
	var saved := []
	timer.total_changed.connect(func(seconds: int) -> void: saved.append(seconds))
	timer.adjust(5)
	assert_eq(timer.total_seconds, 65)
	assert_eq(timer.remaining_ms(), 65000, "untouched, the time left follows")
	assert_eq(saved, [65])
	timer.adjust(-1000)
	assert_eq(timer.total_seconds, 1, "never less than a second")


func test_the_display_reads_minutes_and_seconds() -> void:
	assert_eq(DigitalTimer.digits_for(83000), [0, 1, 2, 3, 0, 0, 0])
	assert_eq(DigitalTimer.digits_for(59001), [0, 0, 5, 9, 0, 0, 1])
	assert_eq(DigitalTimer.digits_for(0), [0, 0, 0, 0, 0, 0, 0])


func test_the_glass_ends_wear_the_tools_colour_and_the_sand_its_own() -> void:
	var tool := _timer()
	assert_eq(tool._sand.cap_color, tool.preset.color)
	assert_eq(tool._sand.sand_color, HourglassArt.complement(tool.preset.color), "the opposite until one is chosen")
	tool._open_menu(Vector2(500, 900))
	assert_eq(tool._menu._kinds, ["gravity", "color", "sound"])
	tool._choose_sand_color("3")
	assert_eq(tool.preset.data["sand"], Themes.palette(tool.preset.theme)[3])
	assert_eq(tool._sand_color(), Themes.palette(tool.preset.theme)[3])
	assert_eq(tool._sand.cap_color, tool.preset.color, "the ends stay put")


func test_lists_pop_out_above_the_timer_menu() -> void:
	var tool := _timer()
	tool._open_menu(Vector2(540, 1000))
	tool._menu.pointer_move(tool._menu.item_rect(2).get_center())
	assert_true(tool._alarm_drawer.is_open)
	assert_lt(tool._alarm_drawer.rect().end.y, tool._menu.rect().position.y, "up, the way the finger came")
