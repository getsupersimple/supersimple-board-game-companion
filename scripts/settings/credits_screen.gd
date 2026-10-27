class_name CreditsScreen
extends Control
## Who made the app and why, with links to the maker's PayPal page and the
## open-source repositories.

signal back_pressed

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

	column.add_child(UiStyle.back_button(func() -> void: back_pressed.emit()))

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
	blurb.add_theme_color_override("font_color", UiStyle.INK)
	body.add_child(blurb)

	body.add_child(_make_link("heart", "CREDITS_SUPPORT", PAYPAL_URL))
	body.add_child(_make_link("swords", "CREDITS_SOURCE", GITHUB_URL))


func _make_link(icon_name: String, label_key: String, url: String) -> Button:
	var link := Button.new()
	link.text = tr(label_key)
	UiStyle.icon_button(link, icon_name, 0, 64)
	link.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.focus_mode = Control.FOCUS_NONE
	link.custom_minimum_size = Vector2(0, 140)
	link.add_theme_font_size_override("font_size", 48)
	var fill := UiStyle.box(UiStyle.PANEL, 40)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		link.add_theme_stylebox_override(state, fill)
	link.pressed.connect(func() -> void: OS.shell_open(url))
	return link
