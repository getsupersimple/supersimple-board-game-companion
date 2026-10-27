class_name SettingsScreen
extends Control
## The switches: dice sound, the timer's end buzzer, and haptics. Each row is
## pictures only, a feature icon and a tick or a cross, and saves at once.

signal back_pressed

const ROW_HEIGHT := 200

var _toggles: Dictionary = {}
var _credits: CreditsScreen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 32)
	margin.add_child(column)

	column.add_child(UiStyle.back_button(func() -> void: back_pressed.emit()))

	column.add_child(_make_row(["dices", "volume-2"], "dice_sound", "SETTINGS_DICE_SOUND"))
	column.add_child(_make_row(["timer", "bell"], "timer_buzzer", "SETTINGS_TIMER_BUZZER"))
	column.add_child(_make_row(["hourglass", "volume-2"], "sand_sound", "SETTINGS_SAND_SOUND"))
	column.add_child(_make_row(["vibrate"], "haptics", "SETTINGS_HAPTICS"))
	column.add_child(_make_credits_link())

	_credits = CreditsScreen.new()
	_credits.visible = false
	_credits.back_pressed.connect(func() -> void: _credits.visible = false)
	add_child(_credits)


## A small link at the end that opens the credits screen.
func _make_credits_link() -> Control:
	var link := Button.new()
	link.text = tr("SETTINGS_CREDITS")
	UiStyle.icon_button(link, "heart", 0, 56)
	link.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.flat = true
	link.focus_mode = Control.FOCUS_NONE
	link.custom_minimum_size = Vector2(0, 120)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.add_theme_font_size_override("font_size", 44)
	link.pressed.connect(func() -> void: _credits.visible = true)
	return link


func _make_row(icons: Array, setting: String, label_key: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var box := UiStyle.box(UiStyle.PANEL, 40)
	box.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	for icon_name in icons:
		var picture := TextureRect.new()
		picture.texture = IconLibrary.get_icon(icon_name)
		picture.modulate = UiStyle.INK
		picture.custom_minimum_size = Vector2(96, 96)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var toggle := Button.new()
	toggle.toggle_mode = true
	UiStyle.icon_button(toggle, "x", 0, 64)
	toggle.custom_minimum_size = Vector2(220, 120)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.accessibility_name = tr(label_key)
	toggle.set_pressed_no_signal(AppSettings.get_flag(setting))
	toggle.toggled.connect(func(on: bool) -> void:
		AppSettings.set_flag(setting, on)
		AppSettings.save_settings()
		_style_toggle(toggle, on)
		if on and setting == "haptics":
			Input.vibrate_handheld(40))
	_style_toggle(toggle, toggle.button_pressed)
	_toggles[setting] = toggle
	row.add_child(toggle)
	return panel


## On is a dark pill with a tick, off is a pale pill with a cross.
func _style_toggle(toggle: Button, on: bool) -> void:
	toggle.icon = IconLibrary.get_icon("check" if on else "x")
	var fill := UiStyle.box(UiStyle.INK if on else Color("#D9D9DF"), 60)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		toggle.add_theme_stylebox_override(state, fill)
	UiStyle.tint_icon(toggle, Color.WHITE if on else UiStyle.INK)
