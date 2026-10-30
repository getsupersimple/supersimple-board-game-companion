class_name IconLibrary
extends RefCounted
## Single place that maps an icon name to its SVG. Icons are white so they can
## be tinted with any color. To use custom icons, drop SVGs in the folder.

const FOLDER := "res://assets/icons/lucide/"
const FALLBACK := "dices"

## What a new game starts with, one after another.
const DEFAULT_GAME_ICONS: Array[String] = ["dices", "swords", "shield", "timer", "zap"]
## Icons a game can be given, from things that belong in games.
const GAME_ICONS: Array[String] = [
	"dices", "swords", "sword", "shield", "crown",
	"trophy", "gem", "diamond", "spade", "heart",
	"cross", "star", "target", "ghost", "moon",
	"flask", "rook", "zap", "timer", "music",
]


static func get_icon(icon_name: String) -> Texture2D:
	var path := FOLDER + icon_name + ".svg"
	if not ResourceLoader.exists(path):
		path = FOLDER + FALLBACK + ".svg"
	return load(path) as Texture2D
