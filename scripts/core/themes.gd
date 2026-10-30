class_name Themes
extends RefCounted
## A tool's theme: the icon that stands for it and the set of sounds it uses. Only two
## sound sets exist so far ("future" synthesised, "rpg" recorded); the rest use "future".

const DEFAULT := "standard"
## In the order they are offered.
const NAMES: Array[String] = ["dnd", "futuristic", "traditional", "old_school", "standard"]
const ICONS := {
	"dnd": "dices", "futuristic": "orbit", "traditional": "landmark",
	"old_school": "joystick", "standard": "palette",
}
const SOUND_SETS := {
	"dnd": "rpg", "futuristic": "future", "traditional": "future",
	"old_school": "future", "standard": "future",
}


static func is_known(theme_name: String) -> bool:
	return NAMES.has(theme_name)


static func sound_set(theme_name: String) -> String:
	return SOUND_SETS.get(theme_name, "future")
