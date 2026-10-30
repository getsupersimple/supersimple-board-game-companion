extends GutTest


func test_the_glass_is_narrowest_at_the_neck_and_mirrored() -> void:
	assert_almost_eq(HourglassShape.half_width(HourglassShape.NECK_Y), HourglassShape.NECK_HALF_WIDTH, 0.01)
	for y in [0.0, 100.0, 300.0, 450.0, 520.0]:
		assert_almost_eq(HourglassShape.half_width(y), HourglassShape.half_width(HourglassShape.HEIGHT - y), 0.01)
		if y >= 100.0:
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
	assert_eq(sand.grains.size(), HourglassSand.BASE_GRAINS)


func test_setting_a_longer_time_pours_in_sand_to_make_it_the_whole_time() -> void:
	var sand := _glass(60)
	var before := sand.grains.size()
	sand.set_duration(90000)
	assert_almost_eq(float(sand.total_ms()), 90000.0, 1.0)
	assert_gt(sand.grains.size(), before)


func test_setting_a_shorter_time_lifts_sand_out() -> void:
	var sand := _glass(60)
	var before := sand.grains.size()
	sand.set_duration(40000)
	await wait_physics_frames(2)
	assert_almost_eq(float(sand.total_ms()), 40000.0, 1.0)
	assert_lt(sand.grains.size(), before)


func test_setting_the_same_time_again_changes_nothing() -> void:
	var sand := _glass(60)
	sand.set_duration(60000)
	sand.set_duration(60000)
	assert_almost_eq(float(sand.total_ms()), 60000.0, 1.0)


func test_less_time_empties_the_emptier_side_first_then_the_fuller() -> void:
	var sand := _glass(60)
	sand.gravity_strength = 1.0
	await wait_seconds(4.0)
	var above := 0
	for grain in sand.grains:
		if grain.position.y < HourglassShape.NECK_Y:
			above += 1
	var below := sand.grains.size() - above
	assert_gt(above, 0)
	assert_gt(below, 0)
	var emptier_is_upper := above < below
	var emptier := mini(above, below)
	var fuller := maxi(above, below)
	var one_grain := float(sand.total_ms()) / sand.grains.size()
	sand.set_duration(int(round(sand.total_ms() - (emptier - 2) * one_grain)))
	assert_eq(sand.grains.size(), above + below - emptier + 2, "only the emptier side gave sand so far")
	sand.set_duration(int(round(sand.total_ms() - (emptier + 5) * one_grain)))
	var left_in_emptier := 0
	for grain in sand.grains:
		if (grain.position.y < HourglassShape.NECK_Y) == emptier_is_upper:
			left_in_emptier += 1
	assert_eq(left_in_emptier, 0, "the emptier side is gone")
	assert_lt(sand.grains.size(), fuller, "then the fuller side gave some")


func test_more_time_goes_onto_the_fuller_side() -> void:
	var sand := _glass(60)
	sand.gravity_strength = 1.0
	await wait_seconds(4.0)
	var above := 0
	for grain in sand.grains:
		if grain.position.y < HourglassShape.NECK_Y:
			above += 1
	var upper_is_fuller := above > sand.grains.size() - above
	var count := sand.grains.size()
	sand.set_duration(sand.total_ms() + 10000)
	var new_above := 0
	for grain in sand.grains.slice(count):
		if grain.position.y < HourglassShape.NECK_Y:
			new_above += 1
	var added := sand.grains.size() - count
	assert_gt(added, 0)
	assert_eq(new_above == added, upper_is_fuller, "all of it on the fuller side")


func test_time_cannot_go_below_nothing() -> void:
	var sand := _glass(10)
	sand.set_duration(0)
	assert_eq(sand.grains.size(), 0)


func test_a_huge_time_is_held_by_making_each_grain_worth_more() -> void:
	var sand := _glass(60)
	sand.set_duration(90 * 60 * 1000)
	assert_lte(sand.grains.size(), HourglassSand.MAX_UPSTREAM)
	assert_almost_eq(float(sand.total_ms()), 90.0 * 60.0 * 1000.0, 1.0)


func test_a_short_time_uses_fewer_grains_so_the_neck_can_keep_up() -> void:
	var sand := _glass(5)
	assert_lt(sand.grains.size(), HourglassSand.BASE_GRAINS)
	assert_almost_eq(float(sand.remaining_ms()), 5000.0, 100.0)


func test_resetting_pours_back_all_the_time_that_was_set() -> void:
	var sand := _glass(60)
	sand.set_duration(90000)
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
	assert_eq(TimeWheel.step_for(200.0), 5)
	assert_eq(TimeWheel.step_for(2000.0), 30)
	assert_eq(TimeWheel.step_for(-5000.0), 60)
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


func test_sand_lying_flat_comes_to_rest_and_does_not_run() -> void:
	var sand := _glass(60)
	sand.gravity_strength = 0.0
	await wait_seconds(3.0)
	var fastest := 0.0
	for grain in sand.grains:
		fastest = maxf(fastest, grain.linear_velocity.length())
	assert_lt(fastest, 5.0, "settled")
	assert_false(sand.is_flowing())
	assert_eq(sand.upstream_count(), sand.grains.size(), "none has run through")


func test_every_last_grain_goes_through_before_time_is_up() -> void:
	var sand := _glass(8)
	var finished := [false]
	sand.drained.connect(func() -> void: finished[0] = true)
	sand.gravity_direction = Vector2.RIGHT
	await wait_seconds(1.5)
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(11.0)
	assert_true(finished[0], "time ran out")
	var above := 0
	for grain in sand.grains:
		if grain.position.y < HourglassShape.NECK_Y:
			above += 1
	assert_eq(above, 0, "no grain is left in the top")
	assert_eq(sand.remaining_ms(), 0)


func test_sand_pouring_makes_a_soft_shh() -> void:
	AppSettings.sand_sound = true
	var sand := _glass(30)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(3.0)
	assert_true(sand._hiss.player.playing, "the shh plays while sand pours")
	assert_lt(sand._hiss.player.volume_db, -30.0, "and it is soft")
	assert_gt(sand._hiss.player.volume_db, -61.0)


func test_the_shh_fades_in_at_the_start_and_out_before_the_end() -> void:
	AppSettings.sand_sound = true
	var sand := _glass(10)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(0.3)
	var early := sand._hiss._level
	await wait_seconds(3.0)
	var middle := sand._hiss._level
	assert_lt(early, middle, "it fades in rather than starting at once")
	assert_gt(middle, 0.9, "at full by the middle")
	var lowest := 1.0
	for _step in 80:
		await wait_seconds(0.1)
		if sand.remaining_ms() < 600:
			lowest = minf(lowest, sand._hiss._level)
	assert_lt(lowest, 0.4, "nearly faded away as the last sand goes through")


func test_a_resting_glass_is_silent() -> void:
	AppSettings.sand_sound = true
	var sand := _glass(30)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.RIGHT
	await wait_seconds(3.0)
	assert_false(sand._hiss.player.playing)


func test_the_shh_follows_the_switches() -> void:
	AppSettings.sand_sound = false
	var sand := _glass(30)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(2.0)
	assert_false(sand._hiss.player.playing, "silent when switched off")
	AppSettings.sand_sound = true
	sand.muted = true
	await wait_seconds(1.0)
	assert_false(sand._hiss.player.playing, "silent when out of sight")
	sand.muted = false
	await wait_seconds(1.0)
	assert_true(sand._hiss.player.playing, "and back again")


func test_the_pour_sound_loops_and_is_audible_but_not_harsh() -> void:
	var loop := SoundBank.sand_loop()
	assert_eq(loop.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(loop.loop_end, loop.data.size() / 2)
	var peak := 0.0
	for i in loop.data.size() / 2:
		peak = maxf(peak, absf(loop.data.decode_s16(i * 2) / 32768.0))
	assert_between(peak, 0.5, 0.9)


func test_nothing_moves_while_the_sand_is_frozen_and_it_runs_again_after() -> void:
	var sand := HourglassSand.new()
	add_child_autofree(sand)
	sand.gravity_strength = 1.0
	sand.set_total_ms(20000)
	await wait_seconds(0.5)
	sand.frozen = true
	var before := PackedVector2Array()
	for grain in sand.grains:
		before.append(grain.position)
	var remaining := sand.remaining_ms()
	await wait_seconds(1.0)
	for i in sand.grains.size():
		assert_eq(sand.grains[i].position, before[i], "grain %d stayed put" % i)
	assert_eq(sand.remaining_ms(), remaining, "time stood still")
	sand.set_duration(sand.total_ms() + 5000)
	assert_true(sand.grains[sand.grains.size() - 1].freeze, "sand poured in while frozen is held too")
	sand.frozen = false
	await wait_seconds(1.5)
	assert_lt(sand.remaining_ms(), remaining + 5000, "and it runs again")


func test_only_the_wheel_turns_over_with_the_phone() -> void:
	var preset := Preset.new()
	preset.type = Preset.Type.HOURGLASS
	var tool := HourglassTool.new()
	tool.preset = preset
	tool.store = PresetStore.new()
	add_child_autofree(tool)
	await wait_frames(2)
	# A phone is always turned over through sideways, never straight from one to the other.
	tool._key_gravity = Vector2.LEFT
	await wait_seconds(0.8)
	assert_almost_eq(tool._wheel.rotation, 0.0, 0.01, "on its side it has not turned")
	tool._key_gravity = Vector2.UP
	await wait_seconds(1.0)
	assert_almost_eq(tool._wheel.rotation, PI, 0.01, "upside down")
	tool._key_gravity = Vector2.LEFT
	await wait_seconds(0.8)
	assert_almost_eq(tool._wheel.rotation, PI, 0.01, "stays turned on its side")
	tool._key_gravity = Vector2.DOWN
	await wait_seconds(1.0)
	assert_almost_eq(tool._wheel.rotation, 0.0, 0.01, "upright again")


func test_the_wheel_counts_down_until_it_is_touched_then_shows_the_whole_time() -> void:
	var preset := Preset.new()
	preset.type = Preset.Type.HOURGLASS
	preset.data["seconds"] = 30
	var tool := HourglassTool.new()
	tool.preset = preset
	tool.store = PresetStore.new()
	add_child_autofree(tool)
	await wait_frames(2)
	tool._sand.gravity_strength = 1.0
	tool._key_gravity = Vector2.DOWN
	await wait_seconds(3.0)
	assert_true(tool._wheel.counting, "its own colour while counting")
	assert_lt(tool._wheel.seconds, 30, "fewer seconds than the whole glass")
	tool._wheel.dragging = true
	tool._wheel.grabbed.emit(true)
	assert_false(tool._wheel.counting)
	assert_eq(tool._wheel.seconds, 30, "the whole time while it is being set")
	tool._wheel.dragging = false
	tool._wheel.grabbed.emit(false)
	await wait_frames(2)
	assert_true(tool._wheel.counting)
	assert_lt(tool._wheel.seconds, 30)


func test_the_chambers_are_straight_tubes_with_flat_ends_easing_into_a_smooth_neck() -> void:
	var tube := HourglassShape.TUBE_RADIUS
	assert_almost_eq(HourglassShape.half_width(HourglassShape.TUBE_END_Y - 40.0), tube, 0.5, "a straight tube")
	assert_almost_eq(HourglassShape.half_width(100.0), tube, 0.01, "all the way up")
	assert_gt(HourglassShape.half_width(0.0), tube - HourglassShape.END_CORNER - 1.0, "the end is flat, not a point")
	assert_almost_eq(HourglassShape.half_width(HourglassShape.HEIGHT), HourglassShape.half_width(0.0), 0.01)
	assert_lt(HourglassShape.half_width(HourglassShape.NECK_Y - 60.0), tube, "then easing in towards the neck")
	var steps := PackedFloat32Array()
	for y in range(int(HourglassShape.TUBE_END_Y), int(HourglassShape.NECK_Y), 10):
		steps.append(HourglassShape.half_width(float(y)) - HourglassShape.half_width(float(y + 10)))
	assert_gt(steps[steps.size() / 2], steps[0] * 2.0, "steepest halfway, so the curve is an S and not a cone")
	assert_lt(steps[steps.size() - 1], steps[steps.size() / 2] * 0.5, "and easing out again into the neck")


func test_tilting_a_glass_with_an_empty_side_does_not_finish_it() -> void:
	var sand := _glass(8)
	var finished := [false]
	sand.drained.connect(func() -> void: finished[0] = true)
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(11.0)
	assert_true(finished[0], "it finishes once the sand has run through")
	finished[0] = false
	sand.gravity_direction = Vector2.LEFT
	await wait_seconds(0.5)
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(2.0)
	assert_false(finished[0], "the top is empty, so tilting it again does not chime")


func test_the_sand_picture_is_cut_to_the_shape_of_the_glass() -> void:
	var texture := HourglassShape.widths_texture()
	assert_eq(texture.get_width(), int(HourglassShape.HEIGHT) + 1)
	var image := texture.get_image()
	for y in [0, 200, 400, 550, 700, 1100]:
		assert_almost_eq(image.get_pixel(y, 0).r, HourglassShape.half_width(float(y)), 0.3, "width at %d" % y)


func test_sand_moved_about_makes_the_shh_even_when_none_pours() -> void:
	AppSettings.sand_sound = true
	var sand := _glass(30)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.LEFT
	await wait_seconds(4.0)
	assert_false(sand._hiss.player.playing, "settled on its side, it is quiet")
	sand.gravity_direction = Vector2.RIGHT
	var heard := false
	for _step in 20:
		await wait_seconds(0.1)
		heard = heard or sand._hiss.player.playing
	assert_true(heard, "sliding across the glass is heard")


func _timed_tool(seconds: int) -> HourglassTool:
	var preset := Preset.create_default(Preset.Type.HOURGLASS)
	preset.data["timed"] = true
	preset.data["seconds"] = seconds
	var tool := HourglassTool.new()
	tool.preset = preset
	tool.store = PresetStore.new("user://test_timed_tool.cfg")
	add_child_autofree(tool)
	return tool


func test_a_timed_glass_runs_on_its_own() -> void:
	var tool := _timed_tool(10)
	await wait_seconds(2.0)
	assert_true(tool._sand.is_flowing())
	assert_lt(tool._sand.remaining_ms(), tool._sand.total_ms(), "the sand is running")


func test_a_timed_glass_ignores_the_tilt_of_the_phone() -> void:
	var tool := _timed_tool(10)
	tool._key_gravity = Vector2.LEFT
	await wait_seconds(1.0)
	assert_eq(tool._sand.gravity_direction, Vector2.DOWN)
	assert_eq(tool._sand.gravity_strength, 1.0)
	assert_true(tool._sand.is_flowing(), "on its side it still runs")
	assert_almost_eq(tool._wheel.rotation, 0.0, 0.01, "and the wheel stays put")


func test_tapping_the_tool_again_pours_all_the_sand_back_to_start_again() -> void:
	var tool := _timed_tool(5)
	await wait_seconds(2.5)
	assert_lt(tool._sand.remaining_ms(), tool._sand.total_ms())
	tool._finished = true
	tool.retap()
	assert_eq(tool._sand.remaining_ms(), tool._sand.total_ms(), "all of it is back at the top")
	assert_eq(tool._sand.total_ms(), 5000, "for the same time")
	assert_false(tool._finished)
	await wait_seconds(0.5)
	assert_true(tool._sand.is_flowing(), "and it runs again")


func test_the_tool_remembers_the_mode_and_switches_between_the_two() -> void:
	var preset := Preset.create_default(Preset.Type.HOURGLASS)
	var tool := HourglassTool.new()
	tool.preset = preset
	tool.store = PresetStore.new("user://test_timed_tool.cfg")
	add_child_autofree(tool)
	await wait_frames(2)
	tool._on_gravity_toggled(false)
	assert_true(preset.data["timed"])
	tool._on_gravity_toggled(true)
	assert_false(preset.data["timed"])
	DirAccess.remove_absolute("user://test_timed_tool.cfg")


func test_the_sand_starts_as_a_heap_at_the_bottom_of_the_top_chamber() -> void:
	var spots := HourglassShape.spawn_positions(HourglassSand.BASE_GRAINS, HourglassSand.GRAIN_RADIUS, true)
	var lowest := 0.0
	for spot in spots:
		lowest = maxf(lowest, spot.y)
	assert_gt(lowest, HourglassShape.NECK_Y - HourglassSand.GRAIN_RADIUS * 8.0, "the heap reaches down to the neck")
	var sand := _glass(60)
	var before := 0.0
	for grain in sand.grains:
		before += grain.position.y
	await wait_seconds(0.5)
	var after := 0.0
	for grain in sand.grains:
		after += grain.position.y
	var average_drop := (after - before) / sand.grains.size()
	# A heap only settles a little; sand dropped from the top would fall hundreds of pixels.
	assert_lt(average_drop, HourglassShape.NECK_Y * 0.12, "it does not fall from the top: %f" % average_drop)
