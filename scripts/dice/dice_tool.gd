class_name DiceTool
extends Control
## The dice tool: a result bar on top, the physics table, and a tray row to add
## dice or roll. The tray is saved into the preset after every change.

const MAX_DICE := 12
const TRAY_SIDES: Array[int] = [6, 8, 12, 20]
const PALETTE: Array[Color] = [
	Color("#4F7CFF"), Color("#E5484D"), Color("#30A46C"),
	Color("#F5A524"), Color("#8E4EC6"), Color("#1C1C1E"),
]
const SLOT_SIZE := 72

var preset: Preset
var store: PresetStore

var _table: DiceTable
var _container: SubViewportContainer
var _total_label: Label
var _slots: HFlowContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	add_child(column)

	_total_label = Label.new()
	_total_label.add_theme_font_size_override("font_size", 72)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.custom_minimum_size = Vector2(0, 96)
	column.add_child(_total_label)

	_slots = HFlowContainer.new()
	_slots.alignment = FlowContainer.ALIGNMENT_CENTER
	_slots.custom_minimum_size = Vector2(0, SLOT_SIZE)
	_slots.add_theme_constant_override("h_separation", 8)
	_slots.add_theme_constant_override("v_separation", 8)
	column.add_child(_slots)

	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.physics_object_picking = true
	viewport.msaa_3d = Viewport.MSAA_2X
	_container.add_child(viewport)
	_table = DiceTable.new()
	viewport.add_child(_table)
	_table.results_changed.connect(_update_results)
	_container.resized.connect(_fit_table)

	column.add_child(_build_tray())
	_fit_table.call_deferred()
	_load_saved_dice.call_deferred()


func _fit_table() -> void:
	if _container.size.y > 0.0:
		_table.set_view_aspect(_container.size.x / _container.size.y)


func _load_saved_dice() -> void:
	for entry in preset.data.get("dice", []):
		if entry is Dictionary and DieShape.is_supported(int(entry.get("sides", 0))):
			var color: Variant = entry.get("color", PALETTE[0])
			_table.add_die(int(entry["sides"]), color if color is Color else PALETTE[0])


func _build_tray() -> HBoxContainer:
	var tray := HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_theme_constant_override("separation", 16)
	for sides in TRAY_SIDES:
		var button := Button.new()
		button.text = str(sides)
		button.custom_minimum_size = Vector2(128, 128)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_add_die.bind(sides))
		tray.add_child(button)
	var roll := Button.new()
	roll.icon = IconLibrary.get_icon("dices")
	roll.expand_icon = true
	roll.custom_minimum_size = Vector2(128, 128)
	roll.focus_mode = Control.FOCUS_NONE
	roll.accessibility_name = tr("DICE_ROLL")
	roll.add_theme_constant_override("icon_max_width", 64)
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		roll.add_theme_color_override(color_name, Color("#1C1C1E"))
	roll.pressed.connect(_table.roll_all)
	tray.add_child(roll)
	return tray


func _on_add_die(sides: int) -> void:
	if _table.dice.size() >= MAX_DICE:
		return
	_table.add_die(sides, PALETTE[_table.dice.size() % PALETTE.size()])
	_save()


func _on_slot_input(event: InputEvent, die: Die) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_table.remove_die(die)
		_save()


func _update_results(values: Array) -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	var total := 0
	var decided := not values.is_empty()
	for i in values.size():
		var die := _table.dice[i]
		var value: int = values[i]
		_slots.add_child(_make_slot(die, value))
		if value < 0:
			decided = false
		else:
			total += value
	_total_label.text = str(total) if decided else ""


func _make_slot(die: Die, value: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var box := StyleBoxFlat.new()
	box.bg_color = die.die_color
	box.set_corner_radius_all(16)
	slot.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = str(value) if value >= 0 else "–"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ColorUtils.contrast_color(die.die_color))
	slot.add_child(label)
	slot.gui_input.connect(_on_slot_input.bind(die))
	return slot


func _save() -> void:
	var saved: Array[Dictionary] = []
	for die in _table.dice:
		saved.append({"sides": die.sides, "color": die.die_color})
	preset.data["dice"] = saved
	store.preset_changed()
