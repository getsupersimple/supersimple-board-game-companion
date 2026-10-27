class_name CreditsScreen
extends Control
## Who made the app and why, with links to the maker's PayPal page and the
## open-source repositories.

signal back_pressed

const INK := Color("#1C1C1E")
const PAYPAL_URL := "https://paypal.me/wschleifer"
const GITHUB_URL := "https://github.com/getsupersimple"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color.WHITE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 32)
	margin.add_child(column)

	var back := Button.new()
	back.icon = IconLibrary.get_icon("arrow-left")
	back.expand_icon = true
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(120, 120)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.accessibility_name = tr("GAME_BACK")
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		back.add_theme_color_override(state, INK)
	back.pressed.connect(func() -> void: back_pressed.emit())
	column.add_child(back)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 40)
	scroll.add_child(body)

	var blurb := Label.new()
	blurb.text = tr("CREDITS_BLURB")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 48)
	blurb.add_theme_color_override("font_color", INK)
	body.add_child(blurb)

	body.add_child(_make_link("heart", "CREDITS_SUPPORT", PAYPAL_URL))
	body.add_child(_make_link("swords", "CREDITS_SOURCE", GITHUB_URL))


func _make_link(icon_name: String, label_key: String, url: String) -> Button:
	var link := Button.new()
	link.text = tr(label_key)
	link.icon = IconLibrary.get_icon(icon_name)
	link.expand_icon = true
	link.focus_mode = Control.FOCUS_NONE
	link.custom_minimum_size = Vector2(0, 140)
	link.add_theme_font_size_override("font_size", 48)
	link.add_theme_constant_override("icon_max_width", 64)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#EDEDF2")
	fill.set_corner_radius_all(40)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		link.add_theme_stylebox_override(state, fill)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		link.add_theme_color_override(state, INK)
	link.pressed.connect(func() -> void: OS.shell_open(url))
	return link
