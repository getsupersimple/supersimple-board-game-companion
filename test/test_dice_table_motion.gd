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
