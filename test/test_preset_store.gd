extends GutTest
## Run with the GUT addon (res://addons/gut), which is not installed yet.

const TEST_PATH := "user://test_games.cfg"

var store: PresetStore


func before_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	store = PresetStore.new(TEST_PATH)
	store.load_store()


func after_all() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func test_quick_game_exists_by_default() -> void:
	assert_not_null(store.get_game(PresetStore.QUICK_ID))
	assert_eq(store.games[0].id, PresetStore.QUICK_ID)


func test_quick_game_cannot_be_deleted() -> void:
	store.delete_game(PresetStore.QUICK_ID)
	assert_not_null(store.get_game(PresetStore.QUICK_ID))


func test_presets_round_trip_through_disk() -> void:
	var preset := Preset.create(Preset.Type.HOURGLASS, "hourglass", Color.RED)
	preset.data = {"seconds": 60}
	store.add_preset(PresetStore.QUICK_ID, preset)

	var reloaded := PresetStore.new(TEST_PATH)
	reloaded.load_store()
	var loaded := reloaded.get_game(PresetStore.QUICK_ID).presets[0]
	assert_eq(loaded.type, Preset.Type.HOURGLASS)
	assert_eq(loaded.data["seconds"], 60)
	assert_eq(loaded.color, Color.RED)


func test_presets_of_the_removed_timers_are_dropped_on_load() -> void:
	var kept := Preset.create(Preset.Type.DICE, "dices", Color.WHITE)
	store.add_preset(PresetStore.QUICK_ID, kept)
	for old_type in [1, 2]:
		var old := kept.to_dict()
		old["id"] = "old_%d" % old_type
		old["type"] = old_type
		var game := store.get_game(PresetStore.QUICK_ID)
		game.presets.append(Preset.from_dict(old))
		game.presets[-1].type = old_type as Preset.Type
	store.save_store()
	var reloaded := PresetStore.new(TEST_PATH)
	reloaded.load_store()
	var presets := reloaded.get_game(PresetStore.QUICK_ID).presets
	assert_eq(presets.size(), 1)
	assert_eq(presets[0].id, kept.id)


func test_move_preset_reorders() -> void:
	var first := Preset.create(Preset.Type.DICE, "dices", Color.WHITE)
	var second := Preset.create(Preset.Type.BUZZER, "bell", Color.WHITE)
	store.add_preset(PresetStore.QUICK_ID, first)
	store.add_preset(PresetStore.QUICK_ID, second)
	store.move_preset(PresetStore.QUICK_ID, 0, 1)
	assert_eq(store.get_game(PresetStore.QUICK_ID).presets[0].id, second.id)


func test_duplicate_inserts_copy_after_original() -> void:
	var original := Preset.create(Preset.Type.DICE, "dices", Color.WHITE)
	store.add_preset(PresetStore.QUICK_ID, original)
	var copy := store.duplicate_preset(PresetStore.QUICK_ID, original.id)
	var presets := store.get_game(PresetStore.QUICK_ID).presets
	assert_eq(presets[1].id, copy.id)
	assert_ne(copy.id, original.id)


func test_corrupt_file_falls_back_to_defaults() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("this is not a config file [[[")
	file.close()
	var recovered := PresetStore.new(TEST_PATH)
	recovered.load_store()
	assert_eq(recovered.games.size(), 1)
	assert_not_null(recovered.get_game(PresetStore.QUICK_ID))


func test_place_on_screen_takes_a_preset_out_of_the_toolbar_and_back_in_at_an_index() -> void:
	var store := PresetStore.new("user://test_place.cfg")
	store.load_store()
	var ids: Array[String] = []
	for preset_type in [Preset.Type.DICE, Preset.Type.BUZZER, Preset.Type.HOURGLASS]:
		var preset := Preset.create_default(preset_type)
		store.add_preset(PresetStore.QUICK_ID, preset)
		ids.append(preset.id)
	store.place_on_screen(PresetStore.QUICK_ID, ids[1], Vector2(0.25, 0.5))
	var game := store.get_game(PresetStore.QUICK_ID)
	assert_true(game.find_preset(ids[1]).has_position)
	assert_eq(game.find_preset(ids[1]).position, Vector2(0.25, 0.5))
	store.place_in_bar(PresetStore.QUICK_ID, ids[1], 1)
	assert_false(game.find_preset(ids[1]).has_position)
	var order: Array[String] = []
	for preset in game.presets:
		order.append(preset.id)
	assert_eq(order, ids, "back between the other two")
	store.place_on_screen(PresetStore.QUICK_ID, ids[0], Vector2(0.5, 0.5))
	store.place_in_bar(PresetStore.QUICK_ID, ids[2], 0)
	var in_toolbar: Array[String] = []
	for preset in game.presets:
		if not preset.has_position:
			in_toolbar.append(preset.id)
	assert_eq(in_toolbar, [ids[2], ids[1]], "index 0 counts only the icons in the toolbar")
	var reloaded := PresetStore.new("user://test_place.cfg")
	reloaded.load_store()
	assert_true(reloaded.get_game(PresetStore.QUICK_ID).find_preset(ids[0]).has_position, "kept")
	DirAccess.remove_absolute("user://test_place.cfg")


func test_a_tools_theme_is_saved_and_an_unknown_one_becomes_standard() -> void:
	var preset := Preset.create_default(Preset.Type.DICE)
	assert_eq(preset.theme, Themes.DEFAULT)
	preset.theme = "dnd"
	assert_eq(Preset.from_dict(preset.to_dict()).theme, "dnd")
	var odd := preset.to_dict()
	odd["theme"] = "nonsense"
	assert_eq(Preset.from_dict(odd).theme, Themes.DEFAULT)
	odd.erase("theme")
	assert_eq(Preset.from_dict(odd).theme, Themes.DEFAULT, "tools saved before themes are standard")
