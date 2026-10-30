class_name Game
extends RefCounted
## A named collection of presets, shown as a tile on the home screen.
## Opening a game activates its first preset.

var id: String = ""
var icon: String = ""
var color: Color = Color.WHITE
var is_builtin: bool = false
var presets: Array[Preset] = []


static func create(game_icon: String, game_color: Color) -> Game:
	var game := Game.new()
	game.id = Ids.new_id()
	game.icon = game_icon
	game.color = game_color
	return game


func find_preset(preset_id: String) -> Preset:
	for preset in presets:
		if preset.id == preset_id:
			return preset
	return null


func to_dict() -> Dictionary:
	var preset_dicts: Array[Dictionary] = []
	for preset in presets:
		preset_dicts.append(preset.to_dict())
	return {
		"id": id,
		"icon": icon,
		"color": color,
		"is_builtin": is_builtin,
		"presets": preset_dicts,
	}


static func from_dict(source: Dictionary) -> Game:
	var game := Game.new()
	game.id = str(source.get("id", ""))
	if game.id.is_empty():
		game.id = Ids.new_id()
	game.icon = str(source.get("icon", ""))
	var raw_color: Variant = source.get("color", Color.WHITE)
	game.color = raw_color if raw_color is Color else Color.WHITE
	game.is_builtin = bool(source.get("is_builtin", false))
	var raw_presets: Variant = source.get("presets", [])
	if raw_presets is Array:
		for raw_preset in raw_presets:
			# Presets of a removed tool are dropped.
			if raw_preset is Dictionary and Preset.is_known_type(int(raw_preset.get("type", Preset.Type.DICE))):
				game.presets.append(Preset.from_dict(raw_preset))
	return game
