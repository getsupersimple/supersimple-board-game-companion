class_name TapArea
extends PanelContainer
## A large tap target with an icon and a big number. Used for the timers, where
## the whole area is the button. It can be turned upside down for the player
## sitting on the other side of the table.

signal tapped

var upside_down := false

var _box := StyleBoxFlat.new()
var _holder: Control
var _icon: TextureRect
var _label: Label
var _pulse: Tween


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box.set_corner_radius_all(48)
	add_theme_stylebox_override("panel", _box)

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(120, 120)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_icon)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	if upside_down:
		# Not the holder itself: a container resets the rotation of its children.
		centre.resized.connect(func() -> void: centre.pivot_offset = centre.size / 2.0)
		centre.rotation = PI


## Sets how the area looks. An empty icon name hides the icon.
func look(fill: Color, icon_name: String, text: String, text_size: int) -> void:
	_box.bg_color = fill
	var ink := ColorUtils.contrast_color(fill)
	_label.add_theme_color_override("font_color", ink)
	_label.add_theme_font_size_override("font_size", text_size)
	_label.text = text
	_icon.visible = not icon_name.is_empty()
	if _icon.visible:
		_icon.texture = IconLibrary.get_icon(icon_name)
		_icon.modulate = ink


func set_text(text: String) -> void:
	_label.text = text


## Flashes the whole area, to say that time is up.
func pulse(on: bool) -> void:
	if _pulse != null:
		_pulse.kill()
	self_modulate = Color.WHITE
	if on:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "self_modulate", Color(1, 1, 1, 0.55), 0.35)
		_pulse.tween_property(self, "self_modulate", Color.WHITE, 0.35)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
