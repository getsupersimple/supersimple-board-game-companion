class_name PresetChip
extends Button
## An icon-only toolbar chip for one preset. Tap selects it. A long press asks
## for edit mode, where the chip jiggles, shows a delete "x", and can be
## dragged to reorder.

signal tapped(preset_id: String)
signal long_pressed
signal delete_requested(preset_id: String)
signal reordered(from_index: int, to_index: int)

const CHIP_SIZE := 140
const LONG_PRESS_SECONDS := 0.5
const DRAG_PAYLOAD_KEY := "chip_index"

var preset: Preset
var index: int = 0

var _editing := false
var _long_press_fired := false
var _jiggle: Tween
var _press_timer: Timer
var _delete_button: Button


func setup(chip_preset: Preset, chip_index: int, selected: bool) -> void:
	preset = chip_preset
	index = chip_index
	UiStyle.icon_button(self, preset.icon, CHIP_SIZE, 72, ColorUtils.contrast_color(preset.color))
	accessibility_name = _accessibility_label()
	add_theme_stylebox_override("normal", _box(preset.color, selected))
	add_theme_stylebox_override("hover", _box(preset.color, selected))
	add_theme_stylebox_override("pressed", _box(preset.color.darkened(0.15), selected))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = LONG_PRESS_SECONDS
	_press_timer.timeout.connect(_on_long_press)
	add_child(_press_timer)
	button_down.connect(_on_button_down)
	button_up.connect(_press_timer.stop)
	pressed.connect(_on_pressed)


func set_editing(editing: bool) -> void:
	_editing = editing
	if _jiggle != null:
		_jiggle.kill()
	rotation = 0.0
	if _delete_button != null:
		_delete_button.queue_free()
		_delete_button = null
	if not editing:
		return
	pivot_offset = size / 2.0 if size != Vector2.ZERO else Vector2(CHIP_SIZE, CHIP_SIZE) / 2.0
	var angle := deg_to_rad(2.0)
	_jiggle = create_tween().set_loops()
	_jiggle.tween_property(self, "rotation", angle, 0.09 + 0.01 * (index % 3))
	_jiggle.tween_property(self, "rotation", -angle, 0.09 + 0.01 * (index % 3))
	_add_delete_button()


func _add_delete_button() -> void:
	_delete_button = UiStyle.icon_button(Button.new(), "x", 52, 28, Color.WHITE)
	_delete_button.size = Vector2(52, 52)
	_delete_button.accessibility_name = tr("TOOLBAR_DELETE")
	var circle := UiStyle.box(UiStyle.INK, 26)
	for state in ["normal", "hover", "pressed"]:
		_delete_button.add_theme_stylebox_override(state, circle)
	_delete_button.pressed.connect(func() -> void: delete_requested.emit(preset.id))
	add_child(_delete_button)


func _on_button_down() -> void:
	_long_press_fired = false
	if not _editing:
		_press_timer.start()


func _on_long_press() -> void:
	_long_press_fired = true
	long_pressed.emit()


func _on_pressed() -> void:
	if _editing or _long_press_fired:
		return
	tapped.emit(preset.id)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _editing:
		return null
	var ghost := Control.new()
	var copy := TextureRect.new()
	copy.texture = icon
	copy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	copy.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	copy.size = Vector2(CHIP_SIZE, CHIP_SIZE)
	copy.position = -copy.size / 2.0
	copy.modulate = ColorUtils.contrast_color(preset.color)
	ghost.add_child(copy)
	set_drag_preview(ghost)
	return {DRAG_PAYLOAD_KEY: index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _editing and data is Dictionary and data.has(DRAG_PAYLOAD_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index: int = data[DRAG_PAYLOAD_KEY]
	if from_index != index:
		reordered.emit(from_index, index)


func _accessibility_label() -> String:
	match preset.type:
		Preset.Type.TIMER:
			return tr("PRESET_TIMER")
		Preset.Type.TIMER_2P:
			return tr("PRESET_TIMER_2P")
		Preset.Type.BUZZER:
			return tr("PRESET_BUZZER")
		Preset.Type.HOURGLASS:
			return tr("PRESET_HOURGLASS")
		_:
			return tr("PRESET_DICE")


func _box(fill: Color, selected: bool) -> StyleBoxFlat:
	var box := UiStyle.box(fill, 32)
	if selected:
		box.set_border_width_all(6)
		box.border_color = UiStyle.INK
	return box
