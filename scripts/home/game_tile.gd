class_name GameTile
extends Button
## A square, icon-only tile. Used for games and for the "add game" tile.

const CORNER_RADIUS := 32


func setup(icon_name: String, tile_color: Color, label_key: String) -> void:
	icon = IconLibrary.get_icon(icon_name)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	accessibility_name = tr(label_key)

	var icon_color := ColorUtils.contrast_color(tile_color)
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(color_name, icon_color)
	add_theme_constant_override("icon_max_width", 160)
	add_theme_stylebox_override("normal", _box(tile_color))
	add_theme_stylebox_override("hover", _box(tile_color))
	add_theme_stylebox_override("pressed", _box(tile_color.darkened(0.15)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(CORNER_RADIUS)
	return box
