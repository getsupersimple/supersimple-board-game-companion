extends GutTest


func test_the_glass_is_narrowest_at_the_neck_and_mirrored() -> void:
	assert_almost_eq(HourglassShape.half_width(HourglassShape.NECK_Y), HourglassShape.NECK_HALF_WIDTH, 0.01)
	for y in [0.0, 100.0, 300.0, 450.0, 520.0]:
		assert_almost_eq(HourglassShape.half_width(y), HourglassShape.half_width(HourglassShape.HEIGHT - y), 0.01)
		assert_gte(HourglassShape.half_width(y), HourglassShape.NECK_HALF_WIDTH)


func test_all_the_sand_starts_inside_the_top_chamber() -> void:
	var spots := HourglassShape.spawn_positions(HourglassSand.BASE_GRAINS, HourglassSand.GRAIN_RADIUS, true)
	assert_eq(spots.size(), HourglassSand.BASE_GRAINS, "room for every grain")
	for spot in spots:
		assert_lt(spot.y, HourglassShape.NECK_Y - HourglassSand.GRAIN_RADIUS * 3.0, "above the neck")
		assert_lte(absf(spot.x), HourglassShape.half_width(spot.y) - HourglassSand.GRAIN_RADIUS, "inside the glass")


func test_the_bottom_chamber_has_room_for_all_of_it() -> void:
	var spots := HourglassShape.spawn_positions(HourglassSand.BASE_GRAINS, HourglassSand.GRAIN_RADIUS, false)
	assert_eq(spots.size(), HourglassSand.BASE_GRAINS)
	for spot in spots:
		assert_gt(spot.y, HourglassShape.NECK_Y)


func test_the_sand_runs_only_when_the_glass_is_near_upright_either_way_up() -> void:
	var sand := HourglassSand.new()
	add_child_autofree(sand)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.DOWN
	assert_true(sand.is_flowing(), "upright")
	sand.gravity_direction = Vector2.UP
	assert_true(sand.is_flowing(), "upside down")
	sand.gravity_direction = Vector2.LEFT
	assert_false(sand.is_flowing(), "on its side")
	sand.gravity_direction = Vector2.DOWN
	sand.gravity_strength = 0.1
	assert_false(sand.is_flowing(), "lying flat")


func _glass(seconds: int) -> HourglassSand:
	var sand := HourglassSand.new()
	sand.set_total_ms(seconds * 1000)
	add_child_autofree(sand)
	return sand


func test_time_left_is_read_from_the_sand() -> void:
	var sand := _glass(60)
	assert_almost_eq(float(sand.remaining_ms()), 60000.0, 100.0)
	assert_eq(sand.grains.size(), HourglassSand.BASE_GRAINS + HourglassSand.DUST_GRAINS)


func test_adding_time_pours_in_sand() -> void:
	var sand := _glass(60)
	var before := sand.grains.size()
	sand.add_time(30000)
	assert_almost_eq(float(sand.remaining_ms()), 90000.0, 400.0)
	assert_gt(sand.grains.size(), before)


func test_taking_time_away_lifts_sand_out() -> void:
	var sand := _glass(60)
	var before := sand.grains.size()
	sand.add_time(-20000)
	await wait_physics_frames(2)
	assert_almost_eq(float(sand.remaining_ms()), 40000.0, 400.0)
	assert_lt(sand.grains.size(), before)


func test_time_cannot_go_below_nothing() -> void:
	var sand := _glass(10)
	sand.add_time(-60000)
	assert_eq(sand.remaining_ms(), 0)


func test_a_huge_time_is_held_by_making_each_grain_worth_more() -> void:
	var sand := _glass(60)
	sand.add_time(90 * 60 * 1000)
	assert_lte(sand.upstream_count(), HourglassSand.MAX_UPSTREAM)
	assert_almost_eq(float(sand.remaining_ms()), 90.0 * 60.0 * 1000.0 + 60000.0, 20000.0)


func test_a_short_time_uses_fewer_grains_so_the_neck_can_keep_up() -> void:
	var sand := _glass(5)
	assert_lt(sand.grains.size(), HourglassSand.BASE_GRAINS)
	assert_almost_eq(float(sand.remaining_ms()), 5000.0, 100.0)


func test_resetting_pours_back_all_the_time_that_was_set() -> void:
	var sand := _glass(60)
	sand.add_time(30000)
	sand.reset()
	assert_almost_eq(float(sand.remaining_ms()), 90000.0, 600.0)


func test_the_wheel_steps_in_fives_and_cannot_go_below_zero() -> void:
	var wheel := TimeWheel.new()
	add_child_autofree(wheel)
	var adjustments: Array[int] = []
	wheel.time_adjusted.connect(func(delta: int) -> void: adjustments.append(delta))
	wheel.show_seconds(12)
	wheel._adjust(5)
	wheel._adjust(-30)
	assert_eq(adjustments, [5, -17], "the second turn stops at zero")
	assert_eq(wheel.seconds, 0)


func test_a_fast_flick_turns_the_wheel_in_bigger_steps() -> void:
	var wheel := TimeWheel.new()
	assert_eq(wheel._step_for(200.0), 5)
	assert_eq(wheel._step_for(2000.0), 30)
	assert_eq(wheel._step_for(-5000.0), 60)
	wheel.free()


func test_the_wheel_is_left_alone_while_a_finger_is_on_it() -> void:
	var wheel := TimeWheel.new()
	add_child_autofree(wheel)
	wheel.show_seconds(40)
	wheel.dragging = true
	wheel.show_seconds(10)
	assert_eq(wheel.seconds, 40)


func test_the_hourglass_is_a_preset_type_that_saves_and_loads() -> void:
	var preset := Preset.create_default(Preset.Type.HOURGLASS)
	preset.data = {"seconds": 90}
	var copy := Preset.from_dict(preset.to_dict())
	assert_eq(copy.type, Preset.Type.HOURGLASS)
	assert_eq(copy.data["seconds"], 90)
	assert_eq(Preset.Type.BUZZER, 3, "older presets keep their number")
