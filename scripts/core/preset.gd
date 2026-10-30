class_name Preset
extends RefCounted
## A configured tool shown in a game's toolbar. Identified by a colorable icon,
## never by a name. `data` holds the tool-specific settings.

## Saved presets store the number, so numbers are never reused: 1 and 2 were the
## standard and the two-player timer, which were removed. New types go on the end.
enum Type { DICE = 0, BUZZER = 3, HOURGLASS = 4 }

var id: String = ""
var type: Type = Type.DICE
var icon: String = ""
var color: Color = Color.WHITE
var data: Dictionary = {}
## Which Themes name the tool wears; it picks the sounds the tool makes.
var theme: String = Themes.DEFAULT
## Set when the preset has been dragged out of the toolbar. Stored as a
## fraction of the screen size so it survives different phone sizes.
var has_position: bool = false
var position: Vector2 = Vector2.ZERO


static func default_icon(preset_type: Type) -> String:
	match preset_type:
		Type.BUZZER:
			return "bell"
		Type.HOURGLASS:
			return "hourglass"
		_:
			return "dices"


static func default_color(preset_type: Type) -> Color:
	match preset_type:
		Type.BUZZER:
			return Color("#F5A524")
		Type.HOURGLASS:
			return Color("#E5484D")
		_:
			return Color("#4F7CFF")


## Whether a saved type number is one this version of the app still has.
static func is_known_type(raw_type: int) -> bool:
	return Type.values().has(raw_type)


static func create_default(preset_type: Type) -> Preset:
	return create(preset_type, default_icon(preset_type), default_color(preset_type))


static func create(preset_type: Type, preset_icon: String, preset_color: Color) -> Preset:
	var preset := Preset.new()
	preset.id = Ids.new_id()
	preset.type = preset_type
	preset.icon = preset_icon
	preset.color = preset_color
	return preset


func duplicate_preset() -> Preset:
	var copy := Preset.from_dict(to_dict())
	copy.id = Ids.new_id()
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": int(type),
		"icon": icon,
		"color": color,
		"data": data.duplicate(true),
		"theme": theme,
		"has_position": has_position,
		"position": position,
	}


static func from_dict(source: Dictionary) -> Preset:
	var preset := Preset.new()
	preset.id = str(source.get("id", ""))
	if preset.id.is_empty():
		preset.id = Ids.new_id()
	var raw_type: int = int(source.get("type", Type.DICE))
	preset.type = (raw_type as Type) if is_known_type(raw_type) else Type.DICE
	preset.icon = str(source.get("icon", ""))
	var raw_color: Variant = source.get("color", Color.WHITE)
	preset.color = raw_color if raw_color is Color else Color.WHITE
	var raw_data: Variant = source.get("data", {})
	preset.data = raw_data if raw_data is Dictionary else {}
	var raw_theme := str(source.get("theme", Themes.DEFAULT))
	preset.theme = raw_theme if Themes.is_known(raw_theme) else Themes.DEFAULT
	preset.has_position = bool(source.get("has_position", false))
	var raw_position: Variant = source.get("position", Vector2.ZERO)
	preset.position = raw_position if raw_position is Vector2 else Vector2.ZERO
	return preset
