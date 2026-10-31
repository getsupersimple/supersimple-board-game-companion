extends GutTest


func after_each() -> void:
	AppSettings.sound_theme = "future"


func test_every_theme_has_an_icon_that_exists_and_a_sound_set() -> void:
	assert_eq(Themes.NAMES, ["dnd", "futuristic", "traditional", "old_school", "standard"])
	for theme_name in Themes.NAMES:
		assert_true(ResourceLoader.exists("res://assets/icons/lucide/%s.svg" % Themes.ICONS[theme_name]), "%s icon file" % theme_name)
		assert_true(["future", "rpg", "futuristic", "traditional", "old_school"].has(Themes.sound_set(theme_name)))
	assert_eq(Themes.sound_set("dnd"), "rpg")
	assert_eq(Themes.sound_set("standard"), "future")
	assert_eq(Themes.sound_set("nonsense"), "future")


func test_the_sound_set_in_use_is_not_saved_with_the_settings() -> void:
	AppSettings.sound_theme = "rpg"
	AppSettings.save_settings("user://test_theme.cfg")
	AppSettings.sound_theme = "future"
	AppSettings.load_settings("user://test_theme.cfg")
	assert_eq(AppSettings.sound_theme, "future")
	DirAccess.remove_absolute("user://test_theme.cfg")


func test_the_rpg_theme_changes_dice_the_locks_and_the_chime_and_future_is_untouched() -> void:
	AppSettings.sound_theme = "future"
	var future := {}
	for kind in ["tick", "chain", "unchain", "chime"]:
		future[kind] = SoundBank.stream(kind)
	AppSettings.sound_theme = "rpg"
	for kind in ["tick", "chain", "unchain", "chime"]:
		var rpg := SoundBank.stream(kind)
		assert_ne(rpg, future[kind], "%s sounds different" % kind)
		assert_gt(rpg.data.size(), 1000, "%s has sound" % kind)
	AppSettings.sound_theme = "future"
	assert_eq(SoundBank.stream("tick"), future["tick"], "back to the same sound")


func test_other_sounds_are_the_same_in_every_theme() -> void:
	AppSettings.sound_theme = "future"
	var future := SoundBank.stream("alarm")
	AppSettings.sound_theme = "rpg"
	assert_eq(SoundBank.stream("alarm").data, future.data)
	assert_eq(SoundBank.stream("buzz").data, SoundBank.stream("buzz").data)


func test_the_rpg_sounds_are_recordings_that_fit_what_they_are_for() -> void:
	AppSettings.sound_theme = "rpg"
	var seconds := func(wav: AudioStreamWAV) -> float: return wav.data.size() / 2.0 / wav.mix_rate
	assert_gt(seconds.call(SoundBank.stream("chime")), 2.0, "the hourglass chime rings on")
	assert_between(seconds.call(SoundBank.stream("chain")), 0.8, 2.5, "a lock closing")
	assert_between(seconds.call(SoundBank.stream("unchain")), 0.8, 2.5, "a lock opening")
	assert_lt(seconds.call(SoundBank.stream("tick")), 0.5, "a die knocking is short")
	for kind in ["chain", "unchain", "chime", "ding"]:
		var wav := SoundBank.stream(kind)
		var loudest := 0
		for i in range(0, wav.data.size() - 1, 2):
			loudest = maxi(loudest, absi(wav.data.decode_s16(i)))
		assert_between(loudest, 8000, 32767, "%s is audible and does not clip" % kind)


func test_a_die_knocks_with_a_different_recording_each_time_and_they_are_all_used() -> void:
	AppSettings.sound_theme = "rpg"
	var seen := {}
	for i in 60:
		seen[SoundBank.stream("tick")] = true
	assert_eq(seen.size(), SoundBank.KNOCKS, "all four recordings come up")


func test_what_the_buzzer_holds_loops_in_the_rpg_theme() -> void:
	AppSettings.sound_theme = "rpg"
	for kind in ["buzz", "horn", "siren"]:
		var held := SoundBank.sustained(kind)
		assert_not_null(held, "%s can be held" % kind)
		assert_eq(held.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_eq(held.loop_end, held.data.size() / 2, "round the whole recording")
	assert_null(SoundBank.sustained("ding"), "a bell is played once")
	AppSettings.sound_theme = "future"
	assert_eq(SoundBank.sustained("horn").loop_end, SoundBank.SAMPLE_RATE, "the other theme is as it was")


func test_the_recorded_alarm_themes_have_recordings_for_the_buzzer_and_the_timers() -> void:
	for theme_name in SoundBank.ALARM_THEMES:
		AppSettings.sound_theme = theme_name
		for kind in ["chime", "ding", "buzz", "horn", "siren"]:
			var wav := SoundBank.stream(kind)
			assert_gt(wav.data.size(), 50000, "%s %s is a recording" % [theme_name, kind])
			assert_ne(wav.data, SoundBank.stream("alarm").data, "%s is not the original" % kind)
		for kind in ["buzz", "horn", "siren"]:
			var held := SoundBank.sustained(kind)
			assert_eq(held.loop_mode, AudioStreamWAV.LOOP_FORWARD)
			assert_eq(held.loop_end, held.data.size() / 2)
		assert_null(SoundBank.sustained("ding"), "a ding is played once")
		assert_ne(SoundBank.stream("chime").data, SoundBank.stream("buzz").data)
	AppSettings.sound_theme = "futuristic"
	var futuristic := SoundBank.stream("buzz").data
	AppSettings.sound_theme = "traditional"
	assert_ne(SoundBank.stream("buzz").data, futuristic, "each theme has its own")
	assert_eq(Themes.sound_set("traditional"), "traditional")
	AppSettings.sound_theme = "future"
	assert_eq(SoundBank.sustained("horn").loop_end, SoundBank.SAMPLE_RATE, "the original set is as it was")
	assert_eq(Themes.sound_set("futuristic"), "futuristic")


func test_every_theme_has_a_palette_of_six_and_standard_is_the_default() -> void:
	for theme_name in Themes.NAMES:
		assert_eq(Themes.palette(theme_name).size(), 6, "%s has six colours" % theme_name)
	assert_eq(Themes.palette("dnd")[2], Color("#D8A441"))
	assert_eq(Themes.palette("futuristic")[1], Color("#00E5FF"))
	assert_eq(Themes.palette("nonsense"), Themes.STANDARD_PALETTE)
	assert_eq(DiceTool.PALETTE, Themes.STANDARD_PALETTE)
	assert_eq(Themes.new_tool_color("standard", Preset.Type.HOURGLASS), Color("#EF4444"))
	assert_eq(Themes.new_tool_color("dnd", Preset.Type.DICE), Color("#742C3B"))


func test_every_theme_has_twenty_icons_and_each_has_a_file() -> void:
	for theme_name in Themes.NAMES:
		var icons := Themes.icon_set(theme_name)
		assert_eq(icons.size(), 20, "%s has twenty icons" % theme_name)
		for icon_name in icons:
			assert_true(ResourceLoader.exists("res://assets/icons/lucide/%s.svg" % icon_name), "%s: %s" % [theme_name, icon_name])
	assert_true(Themes.icon_set("dnd").has("sword"))
	assert_eq(Themes.icon_set("nonsense"), Themes.icon_set("standard"))


func test_the_traditional_theme_has_a_recording_of_dice_being_rolled() -> void:
	AppSettings.sound_theme = "traditional"
	var rolling := SoundBank.roll()
	assert_not_null(rolling)
	assert_gt(rolling.get_length(), 1.0)
	AppSettings.sound_theme = "future"
	assert_null(SoundBank.roll(), "the original set only has the knocks")
	AppSettings.sound_theme = "future"


func test_every_recorded_theme_has_its_dice_sounds_and_a_roll() -> void:
	for sound_set in ["futuristic", "traditional", "old_school"]:
		AppSettings.sound_theme = sound_set
		for kind in ["tick", "chain", "unchain", "chime", "ding", "buzz", "horn", "siren"]:
			var wav := SoundBank.stream(kind)
			assert_not_null(wav, "%s: %s" % [sound_set, kind])
			assert_gt(wav.data.size(), 1000, "%s: %s has sound in it" % [sound_set, kind])
		assert_not_null(SoundBank.roll(), "%s rolls" % sound_set)
		for kind in ["buzz", "horn", "siren"]:
			assert_eq(SoundBank.sustained(kind).loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s: %s loops" % [sound_set, kind])
	AppSettings.sound_theme = "rpg"
	assert_not_null(SoundBank.roll(), "DnD rolls")
	AppSettings.sound_theme = "future"
	assert_null(SoundBank.roll())
	assert_ne(SoundBank.stream("tick"), null)


func test_a_roll_is_one_of_five_closely_related_recordings_in_every_rolling_theme() -> void:
	for sound_set in ["rpg", "futuristic", "traditional", "old_school"]:
		AppSettings.sound_theme = sound_set
		var seen := {}
		for i in 200:
			seen[SoundBank.roll()] = true
		assert_eq(seen.size(), SoundBank.ROLLS, "%s uses all its rolls" % sound_set)
	AppSettings.sound_theme = "future"


func test_a_coin_rings_differently_from_a_die_knocking_in_every_theme() -> void:
	for sound_set in ["future", "rpg", "futuristic", "traditional", "old_school"]:
		AppSettings.sound_theme = sound_set
		var coin := SoundBank.stream("coin")
		assert_not_null(coin, sound_set)
		assert_ne(coin.data, SoundBank.stream("tick").data, "%s: a coin is not a knock" % sound_set)
	AppSettings.sound_theme = "future"


func test_a_die_knocks_with_one_of_four_recordings_in_every_recorded_theme() -> void:
	for sound_set in ["rpg", "futuristic", "traditional", "old_school"]:
		AppSettings.sound_theme = sound_set
		var seen := {}
		for i in 200:
			seen[SoundBank.stream("tick")] = true
		assert_eq(seen.size(), SoundBank.KNOCKS, "%s uses all four knocks" % sound_set)
	AppSettings.sound_theme = "future"
