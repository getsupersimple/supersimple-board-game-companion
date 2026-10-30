extends GutTest


func test_resting_phone_has_no_motion() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	for i in 100:
		table.motion_from_accelerometer(Vector3(0, 0, -9.8))
	assert_lt(table.motion_from_accelerometer(Vector3(0, 0, -9.8)).length(), 0.01)


func test_reports_in_g_are_scaled_to_metres_per_second_squared() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	for i in 100:
		table.motion_from_accelerometer(Vector3(0, 0, -1.0))
	var motion := table.motion_from_accelerometer(Vector3(0.5, 0, -1.0))
	assert_almost_eq(motion.x, 0.5 * 9.80665 * 0.95, 0.5)


func test_screen_up_acceleration_maps_to_table_back() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	for i in 100:
		table.motion_from_accelerometer(Vector3(0, 0, -9.8))
	# Device +y is screen up, which is -z on the table.
	var motion := table.motion_from_accelerometer(Vector3(0, 5.0, -9.8))
	assert_lt(motion.z, -4.0)


func test_no_sensor_means_no_motion() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	assert_eq(table.motion_from_accelerometer(Vector3.ZERO), Vector3.ZERO)


func test_known_gravity_is_subtracted_exactly() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	# Tilting the phone changes the reading but is not movement.
	var tilted := Vector3(0, -9.8, 0)
	assert_lt(table.motion_from_accelerometer(tilted, tilted).length(), 0.001)
	var shoved := table.motion_from_accelerometer(tilted + Vector3(0, 6.0, 0), tilted)
	assert_almost_eq(shoved.z, -6.0, 0.001)


func test_flat_face_up_phone_pulls_dice_down_onto_the_table() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	# The gravity reading points at the ground: flat and face up reads -z.
	assert_almost_eq(table.gravity_direction_from_sensor(Vector3(0, 0, -9.8)).y, -1.0, 0.001)


func test_upright_phone_pulls_dice_to_the_screen_bottom() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	# Top of the phone points at the sky: the ground is -y in the device frame.
	var gravity := table.gravity_direction_from_sensor(Vector3(0, -9.8, 0))
	assert_almost_eq(gravity.z, 1.0, 0.001)
	assert_almost_eq(gravity.y, 0.0, 0.001)


func test_right_edge_up_slides_dice_to_the_left() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	assert_almost_eq(table.gravity_direction_from_sensor(Vector3(-9.8, 0, 0)).x, -1.0, 0.001)


func test_face_down_phone_presses_dice_against_the_screen_glass() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	assert_almost_eq(table.gravity_direction_from_sensor(Vector3(0, 0, 9.8)).y, 1.0, 0.001)


func test_jump_all_sends_every_unlocked_die_up() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.5)
	var free := table.add_die(6, Color.RED)
	var locked := table.add_die(6, Color.BLUE)
	locked.locked = true
	await wait_seconds(2.5)
	free.linear_velocity = Vector3.ZERO
	locked.linear_velocity = Vector3.ZERO
	table.jump_all()
	assert_gt(free.linear_velocity.y, 3.0, "up")
	assert_eq(locked.linear_velocity.y, 0.0, "a locked die stays")


func test_the_walls_keep_even_a_tall_die_inside_the_view() -> void:
	# Without perspective a die is drawn where its floor point is, however tall, so the walls
	# can stand at the very edge of the view and nothing is cut off.
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.7)
	assert_lte(table._half_extents.x, DiceTable.VIEW_WIDTH / 2.0)
	assert_lte(table._half_extents.y, DiceTable.VIEW_WIDTH / 2.0 / 0.7)
	assert_gt(table._half_extents.y, DiceTable.VIEW_WIDTH / 2.0 / 0.7 * 0.95, "and the dice can go right down to the edge")
	assert_eq(table.get_viewport().get_camera_3d().projection, Camera3D.PROJECTION_ORTHOGONAL)


func test_a_finger_held_still_on_a_die_reports_it_instead_of_locking_it() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	var die := table.add_die(6, Color.RED)
	var held := []
	table.die_held.connect(func(which: Die, _at: Vector2) -> void: held.append(which))
	table._grabbed = die
	table._grab_travel = 0.0
	table._grab_time = DiceTable.LONG_PRESS_SECONDS
	table._check_long_press(0.1)
	assert_eq(held, [die])
	assert_false(die.locked, "the owner decides what to do")


func test_pressing_down_forces_a_die_lying_on_another_out_from_under_it() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.6)
	var low := table.add_die(6, Color.RED)
	var high := table.add_die(6, Color.BLUE)
	low.position = Vector3(0, 0.6, 0)
	high.position = Vector3(0.1, 2.6, 0)
	low.linear_velocity = Vector3.ZERO
	high.linear_velocity = Vector3.ZERO
	table.press_down(true)
	await wait_seconds(2.5)
	table.press_down(false)
	assert_lt(high.global_position.y, 1.2, "the upper die was driven down to the table")
	var apart := Vector2(high.global_position.x - low.global_position.x, high.global_position.z - low.global_position.z).length()
	assert_gt(apart, 1.2, "by pushing the lower one aside")


func test_pressing_down_turns_a_cocked_die_towards_flat() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.6)
	var die := table.add_die(6, Color.RED)
	die.position = Vector3(0, 8.0, 0)
	die.rotation = Vector3(0.0, 0.0, 0.7)
	die.linear_velocity = Vector3.ZERO
	var angle_to_flat := func() -> float:
		return Quaternion(die.flat_transform().basis.orthonormalized() * die.global_transform.basis.orthonormalized().inverse()).get_angle()
	var before: float = angle_to_flat.call()
	table.press_down(true)
	await wait_seconds(0.3)
	assert_lt(angle_to_flat.call(), before - 0.1, "a force turns it flat while it is pressed")


func test_a_die_that_has_landed_is_read_while_another_is_still_rolling() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.6)
	var landed := table.add_die(6, Color.RED)
	var falling := table.add_die(6, Color.BLUE)
	landed.global_transform = Transform3D(Basis.IDENTITY, Vector3(-2.0, 0.55, 0))
	landed.linear_velocity = Vector3.ZERO
	falling.global_transform = Transform3D(Basis.IDENTITY, Vector3(2.0, 16.0, 0))
	falling.linear_velocity = Vector3.ZERO
	await wait_seconds(1.3)
	assert_ne(table._last_values[0], -1, "the die on the table is read")
	assert_eq(table._last_values[1], -1, "and the one in the air is not")


func test_a_die_locked_during_a_press_is_not_left_weighted_when_the_press_ends() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.6)
	var die := table.add_die(6, Color.RED)
	table.press_down(true)
	assert_true(die.heavy)
	die.set_locked(true)
	table.press_down(false)
	assert_false(die.heavy, "released although it was locked")
	assert_almost_eq(die.linear_damp, Die.FREE_LINEAR_DAMPING, 0.001)


func test_a_die_being_pressed_down_does_not_count_as_settled() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.6)
	var die := table.add_die(6, Color.RED)
	die.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0))
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	table.press_down(true)
	await wait_seconds(1.0)
	assert_eq(table._last_values[0], -1, "slow under the press is not landed")
	table.press_down(false)
	await wait_seconds(1.0)
	assert_ne(table._last_values[0], -1, "read once let go")


func test_throw_all_sends_every_unlocked_die_the_way_of_the_swipe() -> void:
	var table := DiceTable.new()
	add_child_autofree(table)
	table.set_view_aspect(0.5)
	var free := table.add_die(6, Color.RED)
	var locked := table.add_die(6, Color.BLUE)
	locked.locked = true
	await wait_seconds(2.0)
	free.linear_velocity = Vector3.ZERO
	locked.linear_velocity = Vector3.ZERO
	table.throw_all(Vector2(1, 0), 10.0)
	assert_gt(free.linear_velocity.x, 6.0, "to the right")
	assert_almost_eq(free.linear_velocity.z, 0.0, 0.5)
	assert_eq(locked.linear_velocity.x, 0.0, "a locked die stays")
