class_name IconLibrary
extends RefCounted
## Single place that maps an icon name to its SVG. Icons are white so they can
## be tinted with any color. To use custom icons, drop SVGs in the folder.

const FOLDER := "res://assets/icons/lucide/"
## Icons drawn for this app (the dice), found by the same names.
const CUSTOM_FOLDER := "res://assets/icons/custom/"
const FALLBACK := "dices"


static func get_icon(icon_name: String) -> Texture2D:
	var path := CUSTOM_FOLDER + icon_name + ".svg"
	if not ResourceLoader.exists(path):
		path = FOLDER + icon_name + ".svg"
	if not ResourceLoader.exists(path):
		path = FOLDER + FALLBACK + ".svg"
	return load(path) as Texture2D
