class_name Themes
extends RefCounted
## A tool's theme: the icon that stands for it and the set of sounds it uses. Only two
## sound sets exist so far ("future" synthesised, "rpg", "futuristic" and "traditional" recorded); the rest use "future".

const DEFAULT := "standard"
## In the order they are offered.
const NAMES: Array[String] = ["dnd", "futuristic", "traditional", "old_school", "standard"]
const ICONS := {
	"dnd": "dices", "futuristic": "orbit", "traditional": "landmark",
	"old_school": "joystick", "standard": "palette",
}
## The six colours each theme offers wherever a colour is chosen for one of its tools (a die, the
## tool itself, the sand). 
const STANDARD_PALETTE: Array[Color] = [
	Color("#3B82F6"), Color("#22C55E"), Color("#F59E0B"), Color("#EF4444"), Color("#8B5CF6"), Color("#64748B"),
]
const PALETTES := {
	"dnd": [Color("#742C3B"), Color("#E8D5A9"), Color("#D8A441"), Color("#356B4B"), Color("#69458B"), Color("#222D48")],
	"futuristic": [Color("#101827"), Color("#00E5FF"), Color("#9254FF"), Color("#FF4DA6"), Color("#BAFF39"), Color("#B9C7D6")],
	"traditional": [Color("#873E44"), Color("#F4E8CF"), Color("#30455B"), Color("#747C51"), Color("#C49B55"), Color("#654638")],
	"old_school": [Color("#E85D4A"), Color("#E5B94F"), Color("#378C86"), Color("#4569A1"), Color("#C87540"), Color("#F4E7C9")],
	"standard": STANDARD_PALETTE,
}
## Which of a palette a new tool starts in, by kind: dice the first, buzzer the third, hourglass the fourth.
## Keyed by the saved type numbers of Preset.Type (dice 0, buzzer 3, hourglass 4), which are never reused.
const NEW_TOOL_COLOR := {0: 0, 3: 2, 4: 3}
const SOUND_SETS := {
	"dnd": "rpg", "futuristic": "futuristic", "traditional": "traditional",
	"old_school": "future", "standard": "future",
}


static func is_known(theme_name: String) -> bool:
	return NAMES.has(theme_name)


static func palette(theme_name: String) -> Array[Color]:
	var colors: Array[Color] = []
	colors.assign(PALETTES.get(theme_name, STANDARD_PALETTE))
	return colors


## The colour a new tool of this kind starts in when it has this theme.
static func new_tool_color(theme_name: String, preset_type: int) -> Color:
	return palette(theme_name)[int(NEW_TOOL_COLOR.get(preset_type, 0))]


static func sound_set(theme_name: String) -> String:
	return SOUND_SETS.get(theme_name, "future")
