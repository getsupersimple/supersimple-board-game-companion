class_name BuzzerTool
extends Control
## A big buzzer: tap it for a loud sound and a buzz in the hand. A row of icons
## picks which sound it makes, so one game can have a "right" and a "wrong"
## buzzer as two presets.

## The preset's own icon changes with its sound, so presets tell apart in the toolbar.
signal appearance_changed

const DEFAULT_SOUND := "buzz"

var preset: Preset
var store: PresetStore

var _area: TapArea
var _player: AudioStreamPlayer
var _sound := DEFAULT_SOUND
var _sound_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sound = str(preset.data.get("sound", DEFAULT_SOUND))
	if not SoundBank.BUZZER_SOUNDS.has(_sound):
		_sound = DEFAULT_SOUND

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 24)
	add_child(column)

	_area = TapArea.new()
	_area.tapped.connect(_on_tapped)
	column.add_child(_area)

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 16)
	column.add_child(choices)
	var group := ButtonGroup.new()
	for kind in SoundBank.BUZZER_SOUNDS:
		var button := _make_choice(kind, group)
		choices.add_child(button)
		_sound_buttons[kind] = button

	_player = AudioStreamPlayer.new()
	add_child(_player)
	_show_sound()


func _make_choice(kind: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.icon = IconLibrary.get_icon(SoundBank.BUZZER_ICONS[kind])
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(150, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.accessibility_name = tr("BUZZER_" + kind.to_upper())
	button.add_theme_constant_override("icon_max_width", 72)
	for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Color("#1C1C1E"))
	for state in ["icon_pressed_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	var on_box := StyleBoxFlat.new()
	on_box.bg_color = Color("#1C1C1E")
	on_box.set_corner_radius_all(32)
	button.add_theme_stylebox_override("pressed", on_box)
	button.add_theme_stylebox_override("hover_pressed", on_box)
	button.pressed.connect(func() -> void: _choose(kind))
	return button


func _choose(kind: String) -> void:
	_sound = kind
	preset.data["sound"] = kind
	preset.icon = SoundBank.BUZZER_ICONS[kind]
	store.preset_changed()
	_show_sound()
	appearance_changed.emit()
	_sound_it()


func _show_sound() -> void:
	_sound_buttons[_sound].set_pressed_no_signal(true)
	_area.look(preset.color, SoundBank.BUZZER_ICONS[_sound], "", 16)


func _on_tapped() -> void:
	_sound_it()
	TimerAlert.vibrate(80)
	_flash()


## The buzzer is the point of this tool, so it always sounds. The haptics switch
## still applies to the buzz in the hand.
func _sound_it() -> void:
	_player.stream = SoundBank.stream(_sound)
	_player.play()


func _flash() -> void:
	_area.self_modulate = Color(1, 1, 1, 0.45)
	create_tween().tween_property(_area, "self_modulate", Color.WHITE, 0.25)
