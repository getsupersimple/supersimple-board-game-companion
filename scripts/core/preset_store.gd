class_name PresetStore
extends RefCounted
## Owns all games and their presets and persists them in one ConfigFile.
## Every mutation saves immediately, because preset changes autosave.

const QUICK_ID := "quick"
const SECTION := "games"
const ORDER_KEY := "order"

var games: Array[Game] = []
var _path: String = ""


func _init(path: String = "user://games.cfg") -> void:
	_path = path


## Loads from disk. A missing or corrupt file falls back to defaults.
func load_store() -> void:
	games.clear()
	var config := ConfigFile.new()
	if config.load(_path) == OK:
		var order: Variant = config.get_value(SECTION, ORDER_KEY, [])
		if order is Array:
			for game_id in order:
				var raw: Variant = config.get_value(SECTION, str(game_id), null)
				if raw is Dictionary:
					games.append(Game.from_dict(raw))
	_ensure_quick_game()


func save_store() -> void:
	var config := ConfigFile.new()
	var order: Array[String] = []
	for game in games:
		order.append(game.id)
		config.set_value(SECTION, game.id, game.to_dict())
	config.set_value(SECTION, ORDER_KEY, order)
	config.save(_path)


func get_game(game_id: String) -> Game:
	for game in games:
		if game.id == game_id:
			return game
	return null


func add_game(game: Game) -> void:
	games.append(game)
	save_store()


func delete_game(game_id: String) -> void:
	var game := get_game(game_id)
	if game == null or game.is_builtin:
		return
	games.erase(game)
	save_store()


func add_preset(game_id: String, preset: Preset) -> void:
	var game := get_game(game_id)
	if game == null:
		return
	game.presets.append(preset)
	save_store()


func remove_preset(game_id: String, preset_id: String) -> void:
	var game := get_game(game_id)
	if game == null:
		return
	var preset := game.find_preset(preset_id)
	if preset != null:
		game.presets.erase(preset)
		save_store()


## Inserts a copy directly after the original and returns it.
func duplicate_preset(game_id: String, preset_id: String) -> Preset:
	var game := get_game(game_id)
	if game == null:
		return null
	var original := game.find_preset(preset_id)
	if original == null:
		return null
	var copy := original.duplicate_preset()
	game.presets.insert(game.presets.find(original) + 1, copy)
	save_store()
	return copy


func move_preset(game_id: String, from_index: int, to_index: int) -> void:
	var game := get_game(game_id)
	if game == null:
		return
	var count := game.presets.size()
	if from_index < 0 or from_index >= count or to_index < 0 or to_index >= count:
		return
	var preset := game.presets[from_index]
	game.presets.remove_at(from_index)
	game.presets.insert(to_index, preset)
	save_store()


## Call after changing a preset's data, color, icon or position.
func preset_changed() -> void:
	save_store()


func _ensure_quick_game() -> void:
	if get_game(QUICK_ID) != null:
		return
	var quick := Game.new()
	quick.id = QUICK_ID
	quick.is_builtin = true
	quick.icon = "zap"
	quick.color = Color("#1C1C1E")
	games.push_front(quick)
