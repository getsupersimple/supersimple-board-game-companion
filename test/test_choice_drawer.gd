extends GutTest


func _drawer() -> ChoiceDrawer:
	var host := Control.new()
	host.size = Vector2(1000, 1600)
	add_child_autofree(host)
	var drawer := ChoiceDrawer.new()
	host.add_child(drawer)
	drawer.size = host.size
	drawer.setup(SoundBank.BUZZER_SOUNDS, SoundBank.BUZZER_ICONS)
	return drawer


func test_the_row_opens_just_above_the_finger_and_stays_on_screen() -> void:
	var drawer := _drawer()
	drawer.open(Vector2(500, 800), "buzz", true)
	var rect := drawer.rect()
	assert_lt(rect.end.y, 800.0, "above the finger")
	assert_almost_eq(rect.get_center().x, 500.0, 1.0)
	drawer.open(Vector2(10, 20), "buzz", true)
	assert_true(Rect2(Vector2.ZERO, Vector2(1000, 1600)).encloses(drawer.rect()), "pushed inside the screen")
	assert_gt(drawer.rect().position.y, 20.0, "and below a finger at the very top")


func test_letting_go_over_a_sound_picks_it_and_elsewhere_puts_the_row_away() -> void:
	var drawer := _drawer()
	var picked: Array = []
	drawer.picked.connect(func(kind: String) -> void: picked.append(kind))
	drawer.open(Vector2(500, 800), "buzz", true)
	drawer.pointer_up(Vector2(500, 1300))
	assert_false(drawer.is_open, "the finger lifted elsewhere, so the row goes")
	assert_eq(picked.size(), 0)
	drawer.open(Vector2(500, 800), "buzz", true)
	drawer.pointer_move(drawer.item_rect(2).get_center())
	drawer.pointer_up(drawer.item_rect(2).get_center())
	assert_eq(picked, [SoundBank.BUZZER_SOUNDS[2]])
	assert_false(drawer.is_open)


func test_a_later_tap_off_the_row_closes_it() -> void:
	var drawer := _drawer()
	drawer.open(Vector2(500, 800), "buzz", false)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 1500)
	drawer._gui_input(press)
	assert_false(drawer.is_open)
