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
	assert_eq(sand.grains.size(), HourglassSand.BASE_GRAINS)


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


func test_a_glass_lying_flat_pulls_sand_to_the_middle_of_its_curve() -> void:
	# Off to the right it pulls left, off to the left it pulls right.
	assert_lt(HourglassSand.depth_pull(Vector2(80, 200)).x, 0.0)
	assert_gt(HourglassSand.depth_pull(Vector2(-80, 200)).x, 0.0)
	assert_almost_eq(HourglassSand.depth_pull(Vector2(0, 200)).x, 0.0, 0.001)


func test_a_glass_lying_flat_pulls_sand_towards_the_wide_part_of_each_bulb() -> void:
	# Near the neck of the top bulb the floor rises, so the sand slides up away from it.
	assert_lt(HourglassSand.depth_pull(Vector2(0, 450)).y, 0.0)
	# The bottom bulb is the mirror image: the sand slides down.
	assert_gt(HourglassSand.depth_pull(Vector2(0, HourglassShape.HEIGHT - 450)).y, 0.0)
	# At the widest part of the belly the floor is level along the glass: no pull along it.
	assert_almost_eq(HourglassSand.depth_pull(Vector2(0, HourglassShape.BELLY_CENTRE_Y)).y, 0.0, 0.05)
	# Between the cap and the belly, where the glass widens, the sand slides towards the belly.
	assert_gt(HourglassSand.depth_pull(Vector2(0, 50)).y, 0.0)


func test_the_pull_of_the_curve_never_exceeds_gravity() -> void:
	for y in [10.0, 200.0, 450.0, 540.0, 560.0, 900.0]:
		for x in [-200.0, -50.0, 0.0, 50.0, 200.0]:
			assert_lte(HourglassSand.depth_pull(Vector2(x, y)).length(), 1.0001)


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


func test_the_glass_shader_gets_the_same_shape_as_the_physics() -> void:
	var texture := HourglassShape.widths_texture()
	assert_eq(texture.get_width(), int(HourglassShape.HEIGHT) + 1)
	var image := texture.get_image()
	for y in [0, 205, 400, 550, 700, 1100]:
		assert_almost_eq(image.get_pixel(y, 0).r, HourglassShape.half_width(float(y)), 0.3, "width at %d" % y)
	# The slope changes sign at the neck: the glass narrows, then widens again.
	assert_lt(image.get_pixel(450, 0).g, 0.0)
	assert_gt(image.get_pixel(650, 0).g, 0.0)


func test_the_glass_pane_covers_the_widest_part_of_the_glass() -> void:
	var pane := GlassPane.new()
	add_child_autofree(pane)
	assert_gte(pane.size.x * 0.5, HourglassShape.half_width(HourglassShape.BELLY_CENTRE_Y))
	assert_almost_eq(pane.size.y, HourglassShape.HEIGHT, 0.01)


func _count_taps(sand: HourglassSand) -> Array:
	var taps := []
	sand.grain_tapped.connect(func(strength: float, on_glass: bool) -> void: taps.append([strength, on_glass]))
	return taps


func test_sand_falling_patters_softly() -> void:
	var sand := _glass(30)
	var taps := _count_taps(sand)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.DOWN
	await wait_seconds(4.0)
	assert_gt(taps.size(), 8, "grains tap as they land")
	var loudest := 0.0
	for tap in taps:
		loudest = maxf(loudest, tap[0])
		assert_between(tap[0], 0.0, 1.0)
	assert_gt(loudest, 0.0)


func test_a_resting_glass_is_quiet() -> void:
	var sand := _glass(30)
	sand.gravity_strength = 1.0
	sand.gravity_direction = Vector2.RIGHT
	await wait_seconds(3.0)
	var taps := _count_taps(sand)
	await wait_seconds(1.5)
	assert_lte(taps.size(), 2, "a few stray taps at most once the sand has settled")


func test_a_tap_plays_a_glass_tink_or_a_sand_pat_and_follows_the_switches() -> void:
	AppSettings.sand_sound = true
	var sand := _glass(30)
	sand._play_tap(0.8, true)
	var played := 0
	for voice in sand._voices:
		if voice.playing:
			played += 1
	assert_eq(played, 1)
	for voice in sand._voices:
		voice.stop()
	AppSettings.sand_sound = false
	sand._play_tap(0.8, false)
	for voice in sand._voices:
		assert_false(voice.playing, "silent when switched off")
	AppSettings.sand_sound = true
	sand.muted = true
	sand._play_tap(0.8, true)
	for voice in sand._voices:
		assert_false(voice.playing, "silent when out of sight")


func test_every_grain_sound_exists_and_is_tiny_and_soft() -> void:
	for on_glass in [true, false]:
		for variant in HourglassSand.TAP_VARIANTS:
			var tap := SoundBank.grain_tap(on_glass, variant)
			assert_lt(tap.data.size() / 2.0 / SoundBank.SAMPLE_RATE, 0.1, "shorter than a tenth of a second")
			var peak := 0.0
			for i in tap.data.size() / 2:
				peak = maxf(peak, absf(tap.data.decode_s16(i * 2) / 32768.0))
			assert_between(peak, 0.15, 0.85, "audible but not harsh")
