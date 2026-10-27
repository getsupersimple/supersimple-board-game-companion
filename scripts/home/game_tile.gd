class_name GameTile
extends Button
## A square, icon-only tile. Used for games and for the "add game" tile.

const CORNER_RADIUS := 32


func setup(icon_name: String, tile_color: Color, label_key: String) -> void:
	UiStyle.icon_button(self, icon_name, 0, 160, ColorUtils.contrast_color(tile_color))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	accessibility_name = tr(label_key)

	add_theme_stylebox_override("normal", _box(tile_color))
	add_theme_stylebox_override("hover", _box(tile_color))
	add_theme_stylebox_override("pressed", _box(tile_color.darkened(0.15)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _box(fill: Color) -> StyleBoxFlat:
	return UiStyle.box(fill, CORNER_RADIUS)
