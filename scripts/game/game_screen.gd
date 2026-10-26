class_name GameScreen
extends Control
## One game: the active preset fills the main area, and a toolbar of presets
## runs along the bottom. The tools themselves are built later.

signal back_pressed

const PICKER_TYPES: Array[Preset.Type] = [
	Preset.Type.DICE, Preset.Type.TIMER, Preset.Type.TIMER_2P, Preset.Type.BUZZER,
]

var store: PresetStore
var game: Game
var active_preset_id: String = ""

var _editing := false
var _tool_host: Control
var _tool: Control

@onready var _back_button: Button = %BackButton
@onready var _done_button: Button = %DoneButton
@onready var _active_icon: TextureRect = %ActiveIcon
@onready var _picker: HBoxContainer = %Picker
@onready var _bar: HBoxContainer = %Bar


func _ready() -> void:
	_back_button.icon = IconLibrary.get_icon("arrow-left")
	_back_button.accessibility_name = tr("GAME_BACK")
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_done_button.icon = IconLibrary.get_icon("check")
	_done_button.accessibility_name = tr("TOOLBAR_DONE")
	_done_button.pressed.connect(func() -> void: _set_editing(false))
	for button in [_back_button, _done_button]:
		for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			button.add_theme_color_override(color_name, Color("#1C1C1E"))
	_build_picker()
	_tool_host = Control.new()
	_tool_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tool_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := _active_icon.get_parent().get_parent()
	column.add_child(_tool_host)
	column.move_child(_tool_host, _active_icon.get_parent().get_index() + 1)


func open_game(game_store: PresetStore, game_id: String) -> void:
	store = game_store
	game = store.get_game(game_id)
	_picker.visible = false
	_editing = false
	active_preset_id = game.presets[0].id if not game.presets.is_empty() else ""
	_refresh(true)


func _refresh(rebuild_tool: bool = false) -> void:
	_done_button.visible = _editing
	for child in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	for i in game.presets.size():
		var preset := game.presets[i]
		var chip := PresetChip.new()
		chip.setup(preset, i, preset.id == active_preset_id)
		chip.tapped.connect(_on_chip_tapped)
		chip.long_pressed.connect(func() -> void: _set_editing(true))
		chip.delete_requested.connect(_on_delete_requested)
		chip.reordered.connect(_on_reordered)
		_bar.add_child(chip)
		chip.set_editing(_editing)
	if not _editing:
		_bar.add_child(_make_add_chip())
	if rebuild_tool:
		_show_active_preset()


func _show_active_preset() -> void:
	if _tool != null:
		_tool_host.remove_child(_tool)
		_tool.queue_free()
		_tool = null
	_set_toolbar_visible(true)
	var active := game.find_preset(active_preset_id)
	_tool = _make_tool(active)
	if _tool != null:
		_tool_host.add_child(_tool)
		_active_icon.get_parent().visible = false
		_tool_host.visible = true
		return
	_tool_host.visible = false
	_active_icon.get_parent().visible = true
	_active_icon.visible = active != null
	if active != null:
		_active_icon.texture = IconLibrary.get_icon(active.icon)
		_active_icon.modulate = active.color


## The tool for a preset, or null for one that has no screen yet.
func _make_tool(active: Preset) -> Control:
	if active == null:
		return null
	match active.type:
		Preset.Type.DICE:
			var dice_tool := DiceTool.new()
			dice_tool.preset = active
			dice_tool.store = store
			return dice_tool
		Preset.Type.TIMER:
			var timer_tool := SingleTimerTool.new()
			timer_tool.preset = active
			timer_tool.store = store
			timer_tool.toolbar_visible_changed.connect(_set_toolbar_visible)
			return timer_tool
		Preset.Type.TIMER_2P:
			var game_tool := TwoPlayerTimerTool.new()
			game_tool.preset = active
			game_tool.store = store
			game_tool.toolbar_visible_changed.connect(_set_toolbar_visible)
			return game_tool
		Preset.Type.BUZZER:
			var buzzer_tool := BuzzerTool.new()
			buzzer_tool.preset = active
			buzzer_tool.store = store
			buzzer_tool.appearance_changed.connect(_refresh)
			return buzzer_tool
	return null


## A running timer hides the toolbar, so a stray touch cannot change the settings
## in the middle of a game. It returns when the timer is idle or has finished.
func _set_toolbar_visible(toolbar_visible: bool) -> void:
	_bar.get_parent().visible = toolbar_visible
	_picker.visible = _picker.visible and toolbar_visible


func _make_add_chip() -> Button:
	var chip := Button.new()
	chip.custom_minimum_size = Vector2(PresetChip.CHIP_SIZE, PresetChip.CHIP_SIZE)
	chip.icon = IconLibrary.get_icon("plus")
	chip.expand_icon = true
	chip.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_constant_override("icon_max_width", 72)
	chip.accessibility_name = tr("TOOLBAR_ADD")
	chip.focus_mode = Control.FOCUS_NONE
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		chip.add_theme_color_override(color_name, Color("#1C1C1E"))
	chip.pressed.connect(func() -> void: _picker.visible = not _picker.visible)
	return chip


func _build_picker() -> void:
	for preset_type in PICKER_TYPES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(PresetChip.CHIP_SIZE, PresetChip.CHIP_SIZE)
		button.icon = IconLibrary.get_icon(Preset.default_icon(preset_type))
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 72)
		button.focus_mode = Control.FOCUS_NONE
		var color := Preset.default_color(preset_type)
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(32)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, box)
		for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			button.add_theme_color_override(color_name, ColorUtils.contrast_color(color))
		button.pressed.connect(_on_type_picked.bind(preset_type))
		_picker.add_child(button)


func _on_type_picked(preset_type: Preset.Type) -> void:
	var preset := Preset.create_default(preset_type)
	store.add_preset(game.id, preset)
	active_preset_id = preset.id
	_picker.visible = false
	_refresh(true)


func _on_chip_tapped(preset_id: String) -> void:
	active_preset_id = preset_id
	_refresh(true)


func _on_delete_requested(preset_id: String) -> void:
	store.remove_preset(game.id, preset_id)
	if active_preset_id == preset_id:
		active_preset_id = game.presets[0].id if not game.presets.is_empty() else ""
	_refresh(true)


func _on_reordered(from_index: int, to_index: int) -> void:
	store.move_preset(game.id, from_index, to_index)
	_refresh()


func _set_editing(editing: bool) -> void:
	_editing = editing
	_picker.visible = false
	_refresh()
