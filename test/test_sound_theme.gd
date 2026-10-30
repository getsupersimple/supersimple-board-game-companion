extends GutTest


func after_each() -> void:
	AppSettings.sound_theme = "future"


func test_every_theme_has_an_icon_that_exists_and_a_sound_set() -> void:
	assert_eq(Themes.NAMES, ["dnd", "futuristic", "traditional", "old_school", "standard"])
	for theme_name in Themes.NAMES:
		assert_true(ResourceLoader.exists("res://assets/icons/lucide/%s.svg" % Themes.ICONS[theme_name]), "%s icon file" % theme_name)
		assert_true(["future", "rpg"].has(Themes.sound_set(theme_name)))
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
