class_name UiStyle
extends RefCounted
## Looks shared by the screens, so each icon button, pill and panel is styled in
## one place.

const INK := Color("#1C1C1E")
const PANEL := Color("#EDEDF2")
## The square buttons along the top of a screen, all this size so they line up.
const TOP_BUTTON := 120

const _ICON_STATES: Array[String] = ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]
const _FONT_STATES: Array[String] = ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]


## Sets the icon of a button, centred and scaled to `icon_max` pixels (0 for the default), and makes the
## button `min_size` square. Pass `min_size` 0 to leave its size alone.
static func icon_button(button: Button, icon_name: String, min_size: float, icon_max: int, ink: Color = INK) -> Button:
	button.icon = IconLibrary.get_icon(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if icon_max > 0:
		button.add_theme_constant_override("icon_max_width", icon_max)
	if min_size > 0.0:
		button.custom_minimum_size = Vector2(min_size, min_size)
	tint_icon(button, ink)
	return button


## Colours the icon (and the text) of a button the same in every state.
static func tint_icon(button: Button, ink: Color) -> void:
	for state in _ICON_STATES:
		button.add_theme_color_override(state, ink)
	for state in _FONT_STATES:
		button.add_theme_color_override(state, ink)


## A button that turns into a dark pill with a white icon while it is switched on.
static func dark_toggle(button: Button, min_size: float, icon_name: String) -> Button:
	icon_button(button, icon_name, min_size, 72)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["icon_pressed_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	var on_box := box(INK, 32)
	button.add_theme_stylebox_override("pressed", on_box)
	button.add_theme_stylebox_override("hover_pressed", on_box)
	return button


## The round "back" button at the top left of a screen.
static func back_button(on_pressed: Callable) -> Button:
	var back := icon_button(Button.new(), "arrow-left", 120, 0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.accessibility_name = back.tr("GAME_BACK")
	back.pressed.connect(on_pressed)
	return back


static func box(fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style
