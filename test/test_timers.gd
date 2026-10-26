extends GutTest


func test_countdown_runs_out_after_its_duration() -> void:
	var timer := SingleTimer.new()
	timer.configure(true, 10)
	timer.tap(1000)
	assert_eq(timer.state, SingleTimer.State.RUNNING)
	assert_false(timer.tick(10999))
	assert_true(timer.tick(11000))
	assert_eq(timer.state, SingleTimer.State.FINISHED)
	assert_eq(timer.display_ms(99999), 0)


func test_finishing_is_reported_only_once() -> void:
	var timer := SingleTimer.new()
	timer.configure(true, 1)
	timer.tap(0)
	assert_true(timer.tick(1500))
	assert_false(timer.tick(2000))


func test_pausing_stops_the_clock_and_resuming_carries_on() -> void:
	var timer := SingleTimer.new()
	timer.configure(true, 60)
	timer.tap(0)
	timer.tap(10000)
	assert_eq(timer.state, SingleTimer.State.PAUSED)
	assert_eq(timer.display_ms(50000), 50000)
	timer.tap(20000)
	assert_eq(timer.display_ms(25000), 45000)


func test_count_up_never_finishes() -> void:
	var timer := SingleTimer.new()
	timer.configure(false, 60)
	timer.tap(0)
	assert_false(timer.tick(10_000_000))
	assert_eq(timer.display_ms(90000), 90000)


func test_tapping_a_finished_timer_resets_it() -> void:
	var timer := SingleTimer.new()
	timer.configure(true, 5)
	timer.tap(0)
	timer.tick(6000)
	timer.tap(7000)
	assert_eq(timer.state, SingleTimer.State.IDLE)
	assert_eq(timer.display_ms(8000), 5000)


func test_time_comes_from_the_clock_not_from_frames() -> void:
	var timer := SingleTimer.new()
	timer.configure(true, 60)
	timer.tap(0)
	# A long gap between two frames still counts in full.
	timer.tick(1)
	assert_eq(timer.display_ms(30000), 30000)


func test_time_format_rounds_countdowns_up_and_count_ups_down() -> void:
	assert_eq(TimeFormat.format(59200, true), "1:00")
	assert_eq(TimeFormat.format(0, true), "0:00")
	assert_eq(TimeFormat.format(59900, false), "0:59")
	assert_eq(TimeFormat.format(3_725_000, false), "1:02:05")


func test_only_the_active_player_can_pass_the_turn() -> void:
	var game := TwoPlayerTimer.new()
	game.configure(true, 60, false)
	assert_true(game.tap(0, 0))
	assert_false(game.tap(1, 1000))
	assert_eq(game.active, 0)
	assert_true(game.tap(0, 5000))
	assert_eq(game.active, 1)


func test_a_time_bank_carries_across_turns() -> void:
	var game := TwoPlayerTimer.new()
	game.configure(true, 60, false)
	game.tap(0, 0)
	game.tap(0, 10000)
	game.tap(1, 25000)
	assert_eq(game.display_ms(0, 25000), 50000, "player 0 keeps what is left")
	assert_eq(game.display_ms(1, 25000), 45000, "player 1 spent 15 seconds")


func test_reset_each_turn_gives_every_turn_the_full_time() -> void:
	var game := TwoPlayerTimer.new()
	game.configure(true, 60, true)
	game.tap(0, 0)
	game.tap(0, 10000)
	assert_eq(game.display_ms(0, 10000), 60000)
	assert_eq(game.display_ms(1, 10000), 60000)
	game.tap(1, 30000)
	assert_eq(game.display_ms(0, 30000), 60000, "back to player 0 with a full turn")


func test_count_up_can_add_up_or_reset_per_turn() -> void:
	var total := TwoPlayerTimer.new()
	total.configure(false, 60, false)
	total.tap(0, 0)
	total.tap(0, 10000)
	total.tap(1, 20000)
	total.tap(0, 25000)
	assert_eq(total.display_ms(0, 30000), 15000, "10 seconds plus 5 more")
	var per_turn := TwoPlayerTimer.new()
	per_turn.configure(false, 60, true)
	per_turn.tap(0, 0)
	per_turn.tap(0, 10000)
	per_turn.tap(1, 20000)
	assert_eq(per_turn.display_ms(0, 23000), 3000, "only the turn in progress")
	assert_eq(per_turn.display_ms(1, 23000), 0, "the last turn is cleared when it is passed")


func test_running_out_ends_the_game_and_names_the_loser() -> void:
	var game := TwoPlayerTimer.new()
	game.configure(true, 5, false)
	game.tap(1, 0)
	assert_false(game.tick(4999))
	assert_true(game.tick(5000))
	assert_eq(game.state, TwoPlayerTimer.State.FINISHED)
	assert_eq(game.loser, 1)
	assert_true(game.tap(0, 6000))
	assert_eq(game.state, TwoPlayerTimer.State.IDLE, "a tap resets after the end")


func test_pause_freezes_the_active_clock() -> void:
	var game := TwoPlayerTimer.new()
	game.configure(true, 60, false)
	game.tap(0, 0)
	game.toggle_pause(10000)
	assert_eq(game.state, TwoPlayerTimer.State.PAUSED)
	assert_false(game.tap(0, 15000), "taps do nothing while paused")
	game.toggle_pause(30000)
	assert_eq(game.display_ms(0, 35000), 45000)


func test_settings_are_saved_and_loaded() -> void:
	var path := "user://test_settings.cfg"
	AppSettings.dice_sound = false
	AppSettings.timer_buzzer = true
	AppSettings.haptics = false
	AppSettings.save_settings(path)
	AppSettings.dice_sound = true
	AppSettings.haptics = true
	AppSettings.load_settings(path)
	assert_false(AppSettings.dice_sound)
	assert_true(AppSettings.timer_buzzer)
	assert_false(AppSettings.haptics)
	AppSettings.dice_sound = true
	AppSettings.haptics = true
	DirAccess.remove_absolute(path)


func test_a_missing_settings_file_leaves_everything_on() -> void:
	AppSettings.dice_sound = true
	AppSettings.load_settings("user://does_not_exist.cfg")
	assert_true(AppSettings.dice_sound)


func test_every_buzzer_sound_exists_and_has_an_icon() -> void:
	for kind in SoundBank.BUZZER_SOUNDS:
		var stream := SoundBank.stream(kind)
		assert_gt(stream.data.size(), 1000, "%s has sound" % kind)
		assert_true(SoundBank.BUZZER_ICONS.has(kind), "%s has an icon" % kind)
		assert_true(ResourceLoader.exists("res://assets/icons/lucide/%s.svg" % SoundBank.BUZZER_ICONS[kind]), "%s icon file" % kind)
	assert_gt(SoundBank.stream("alarm").data.size(), 1000)
	assert_gt(SoundBank.stream("tick").data.size(), 100)


func test_the_buzzer_sounds_only_while_held_and_stops_at_once() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	add_child_autofree(tool)
	await wait_physics_frames(2)
	assert_false(tool._player.playing, "silent until pressed")
	tool._on_pressed()
	assert_true(tool._player.playing, "sounds while held")
	tool._on_released()
	assert_false(tool._player.playing, "stops the moment the finger lifts")


func test_choosing_a_sound_does_not_play_it() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._choose("siren")
	assert_false(tool._player.playing)
	assert_eq(tool.preset.data["sound"], "siren")


func test_sounds_that_can_go_on_loop_and_a_bell_does_not() -> void:
	for kind in ["buzz", "horn", "siren"]:
		var held := SoundBank.sustained(kind)
		assert_eq(held.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops while held" % kind)
		assert_eq(held.loop_end, SoundBank.SAMPLE_RATE, "%s loops over a whole second" % kind)
	assert_null(SoundBank.sustained("ding"), "a bell plays once")
