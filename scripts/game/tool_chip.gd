class_name ToolChip
extends Control
## The icon of one preset, in the toolbar or loose on the screen. It takes no input
## itself (ToolDock does that); it only draws, and moves by springs, so every move,
## lift and drop is fluid.

const SIZE := 140.0
const RADIUS := 32
const ICON_SIZE := 72.0
const LIFT_SCALE := 1.16
## Following a finger is stiff, settling into a slot is looser and overshoots a little.
const FOLLOW_STIFFNESS := 1100.0
const FOLLOW_DAMPING := 54.0
const SETTLE_STIFFNESS := 380.0
const SETTLE_DAMPING := 24.0

var preset: Preset
var selected := false
var lifted := false

## Loaded ahead of drawing: a texture loaded for the first time inside `_draw` comes out black.
var _icon: Texture2D
var _pos := Spring.new(Vector2.ZERO)
var _scale := Spring.new(1.0)
var _leaving := false


func _init() -> void:
	size = Vector2(SIZE, SIZE)
	custom_minimum_size = size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale.stiffness = 300.0
	_scale.damping = 16.0
	_set_settle()


func setup(chip_preset: Preset, is_selected: bool) -> void:
	preset = chip_preset
	selected = is_selected
	_icon = IconLibrary.get_icon(preset.icon)
	accessibility_name = _accessibility_label()
	queue_redraw()


## Pops in from nothing.
func appear() -> void:
	_scale.snap(0.0)
	_scale.target = 1.0


## Shrinks away and frees itself.
func dismiss() -> void:
	_leaving = true
	_scale.target = 0.0


func lift(on: bool) -> void:
	lifted = on
	_scale.target = LIFT_SCALE if on else 1.0
	if on:
		_pos.stiffness = FOLLOW_STIFFNESS
		_pos.damping = FOLLOW_DAMPING
	else:
		_set_settle()


func set_target(point: Vector2) -> void:
	_pos.target = point


## Goes to a point at once.
func place_at(point: Vector2) -> void:
	_pos.snap(point)
	position = point


## Takes the node's own position as where the spring is now, after the chip has been
## moved to another parent.
func adopt_position() -> void:
	_pos.value = position


func target_position() -> Vector2:
	return _pos.target


func is_moving() -> bool:
	return not _pos.is_settled(6.0)


func _process(delta: float) -> void:
	_pos.step(delta)
	_scale.step(delta)
	position = _pos.value
	var grown := maxf(_scale.value, 0.0)
	scale = Vector2(grown, grown)
	rotation = lerp_angle(rotation, 0.0, 1.0 - exp(-18.0 * delta))
	if lifted or not _scale.is_settled(0.01):
		queue_redraw()
	if _leaving and _scale.value < 0.04:
		queue_free()


func _draw() -> void:
	if preset == null:
		return
	var box := UiStyle.box(preset.color, RADIUS)
	var raised := clampf((_scale.value - 1.0) / (LIFT_SCALE - 1.0), 0.0, 1.0)
	if raised > 0.0:
		box.shadow_color = Color(0, 0, 0, 0.3 * raised)
		box.shadow_size = int(28.0 * raised)
		box.shadow_offset = Vector2(0, 10.0 * raised)
	if selected:
		box.set_border_width_all(6)
		box.border_color = UiStyle.INK
	box.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var icon_rect := Rect2((size - Vector2(ICON_SIZE, ICON_SIZE)) / 2.0, Vector2(ICON_SIZE, ICON_SIZE))
	draw_texture_rect(_icon, icon_rect, false, ColorUtils.contrast_color(preset.color))


func _set_settle() -> void:
	_pos.stiffness = SETTLE_STIFFNESS
	_pos.damping = SETTLE_DAMPING


func _accessibility_label() -> String:
	match preset.type:
		Preset.Type.BUZZER:
			return tr("PRESET_BUZZER")
		Preset.Type.HOURGLASS:
			return tr("PRESET_HOURGLASS")
		_:
			return tr("PRESET_DICE")
