extends GutTest


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
	await wait_seconds(BuzzerTool.START_DELAY + 0.05)
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


func test_the_hourglass_ends_with_a_soft_chime_not_the_alarm() -> void:
	AppSettings.timer_buzzer = true
	var host := Node.new()
	add_child_autofree(host)
	TimerAlert.chime(host)
	var players := []
	for child in host.get_children():
		if child is AudioStreamPlayer:
			players.append(child)
	assert_eq(players.size(), 1)
	assert_eq(players[0].stream, SoundBank.stream("chime"))
	assert_ne(players[0].stream, SoundBank.stream("alarm"))


func test_the_chime_is_silent_when_the_timer_buzzer_is_off() -> void:
	AppSettings.timer_buzzer = false
	var host := Node.new()
	add_child_autofree(host)
	TimerAlert.chime(host)
	assert_eq(host.get_child_count(), 0)
	AppSettings.timer_buzzer = true


func test_the_chime_is_soft_and_fades_to_nothing() -> void:
	var chime := SoundBank.stream("chime")
	var count := chime.data.size() / 2
	var peak := 0.0
	var last_second := 0.0
	for i in count:
		var value := absf(chime.data.decode_s16(i * 2) / 32768.0)
		peak = maxf(peak, value)
		if i > count - SoundBank.SAMPLE_RATE / 4:
			last_second = maxf(last_second, value)
	assert_lt(peak, 0.6, "gentle, never harsh")
	assert_lt(last_second, 0.01, "faded away by the end")


func test_holding_the_buzzer_opens_the_sound_row_under_the_finger_and_keeps_sounding() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	tool.size = Vector2(900, 1500)
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._on_pressed()
	await wait_seconds(BuzzerTool.START_DELAY + 0.05)
	assert_true(tool._player.playing)
	await wait_seconds(BuzzerTool.LONG_PRESS_SECONDS + 0.2)
	assert_true(tool._drawer.is_open, "the row of sounds opens")
	assert_true(tool._player.playing, "and the buzzer keeps sounding")
	assert_eq(tool.find_children("*", "Button", true, false).size(), 0, "there is no row of buttons under the buzzer any more")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = tool._drawer.item_rect(2).get_center()
	tool._area.gui_input.emit(release)
	tool._on_released()
	assert_false(tool._drawer.is_open, "the row goes away when the finger lifts")
	assert_false(tool._player.playing)
	assert_eq(tool.preset.data["sound"], SoundBank.BUZZER_SOUNDS[2])
	assert_eq(tool.preset.icon, SoundBank.BUZZER_ICONS[SoundBank.BUZZER_SOUNDS[2]])


func test_a_quick_press_on_the_buzzer_does_not_open_the_sound_row() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._on_pressed()
	tool._on_released()
	await wait_seconds(BuzzerTool.LONG_PRESS_SECONDS + 0.2)
	assert_false(tool._drawer.is_open)


func test_a_swipe_across_the_buzzer_does_not_make_it_buzz() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	tool.size = Vector2(900, 1500)
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._on_pressed()
	var move := InputEventMouseMotion.new()
	move.global_position = tool._press_point + Vector2(60, 0)
	tool._input(move)
	await wait_seconds(BuzzerTool.LONG_PRESS_SECONDS + 0.2)
	assert_false(tool._player.playing, "never started")
	assert_false(tool._drawer.is_open, "nor opened the row")
	tool._on_released()
	assert_false(tool._player.playing)


func test_a_finger_that_moves_while_it_buzzes_changes_nothing_and_cannot_swipe_until_it_lifts() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._on_pressed()
	await wait_seconds(BuzzerTool.START_DELAY + 0.05)
	assert_true(tool._player.playing)
	var move := InputEventMouseMotion.new()
	move.global_position = tool._press_point + Vector2(0, 80)
	tool._input(move)
	assert_true(tool._player.playing, "still sounding")
	assert_false(tool.accepts_swipe(), "no swipe while it sounds under the finger")
	tool._on_released()
	assert_false(tool._player.playing)
	assert_true(tool.accepts_swipe(), "and a new touch can swipe again")


func test_sliding_over_the_sounds_in_the_drawer_plays_each_one_as_a_preview() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._on_pressed()
	await wait_seconds(BuzzerTool.START_DELAY + 0.05)
	tool._preview("siren")
	assert_eq(tool._player.stream, SoundBank.sustained("siren"))
	assert_true(tool._player.playing)
	tool._preview("ding")
	assert_eq(tool._player.stream, SoundBank.stream("ding"))
	tool._preview("")
	assert_eq(tool._player.stream, SoundBank.stream("ding"), "over none, the last one carries on")
	tool._on_released()


func test_a_quick_tap_still_sounds_briefly() -> void:
	var tool := BuzzerTool.new()
	tool.preset = Preset.create_default(Preset.Type.BUZZER)
	tool.store = PresetStore.new("user://test_buzzer.cfg")
	add_child_autofree(tool)
	await wait_physics_frames(2)
	tool._on_pressed()
	tool._on_released()
	assert_true(tool._player.playing)
	await wait_seconds(BuzzerTool.TAP_SOUND_SECONDS + 0.1)
	assert_false(tool._player.playing)
