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
	var preset := Preset.create(Preset.Type.TIMER, "timer", Color.RED)
	preset.data = {"seconds": 60}
	store.add_preset(PresetStore.QUICK_ID, preset)

	var reloaded := PresetStore.new(TEST_PATH)
	reloaded.load_store()
	var loaded := reloaded.get_game(PresetStore.QUICK_ID).presets[0]
	assert_eq(loaded.type, Preset.Type.TIMER)
	assert_eq(loaded.data["seconds"], 60)
	assert_eq(loaded.color, Color.RED)


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
