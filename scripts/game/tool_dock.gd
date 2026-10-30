class_name ToolDock
extends Control
## Everything about the tool icons, drawn over the whole game screen: the toolbar
## along the bottom, which scrolls sideways when it holds more than fits, and any
## icon dragged out onto the screen.
##
## A tap selects a tool and tapping the one already selected taps it again. A long press
## on an icon reports `held`, and the owner opens a menu for it; the finger, still down, is
## then reported as it moves and lifts. If the owner decides the finger is dragging the icon
## away it calls `carry`, and the icon is picked up and carried anywhere on the screen, or
## dropped back among the others in the toolbar, where the rest slide aside to make room and
## it springs into its place. The dock only reports what happened; the owner changes the
## presets and calls `sync` again.

signal tapped(preset_id: String)
## A finger has stayed on an icon, at this global point.
signal held(preset_id: String, global_point: Vector2)
## While held, the finger moved or lifted, at this global point.
signal finger_moved(global_point: Vector2)
signal finger_up(global_point: Vector2)
signal placed_in_bar(preset_id: String, bar_index: int)
## The icon was dropped on the screen, at this fraction of the screen's size.
signal placed_on_screen(preset_id: String, fraction: Vector2)

const GAP := 24.0
## Room above and below the toolbar's icons for the lift.
const PAD := 30.0
const LONG_PRESS_SECONDS := 0.5
const SLOP := 18.0
const SCREEN_MARGIN := 12.0
const DROP_ZONE_ABOVE := 110.0
const EDGE_ZONE := 90.0
const EDGE_SCROLL_SPEED := 700.0
const FRICTION := 4.0
const SETTLE_SMOOTHING := 14.0
const RUBBER_BAND := 0.4

enum Gesture { NONE, PRESSING, SCROLLING, DRAGGING, IGNORED, HELD }

var _slot: Control
var _strip: Control
var _chips := {}
var _bar_ids: Array[String] = []
var _float_ids: Array[String] = []
var _fresh := {}

var _scroll := 0.0
var _scroll_velocity := 0.0
## Icons stay on their targets exactly while the toolbar is being scrolled.
var _snap := false
var _reveal_id := ""

var _gesture := Gesture.NONE
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _last_move_msec := 0
var _press_time := 0.0
var _press_id := ""
var _press_in_strip := false

var _drag_id := ""
var _grab := Vector2.ZERO
var _pointer := Vector2.ZERO
var _gap_open := false
var _drag_index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_strip = Control.new()
	_strip.clip_contents = true
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)


## The control in the layout that the toolbar fills.
func set_slot(slot: Control) -> void:
	_slot = slot


## Shows these presets. Icons already shown are kept, so they slide to their new
## places; new ones pop in when `animate` is set, and icons that are gone shrink away.
func sync(presets: Array[Preset], active_id: String, animate: bool = true) -> void:
	_bar_ids.clear()
	_float_ids.clear()
	var wanted := {}
	for preset in presets:
		wanted[preset.id] = true
		var chip: ToolChip = _chips.get(preset.id)
		if chip == null:
			chip = ToolChip.new()
			_chips[preset.id] = chip
			_fresh[preset.id] = true
			(self if preset.has_position else _strip).add_child(chip)
			if animate:
				chip.appear()
		chip.setup(preset, preset.id == active_id)
		if preset.id == _drag_id:
			continue
		if preset.has_position:
			_float_ids.append(preset.id)
			_move_to(chip, self)
		else:
			_bar_ids.append(preset.id)
	for id in _chips.keys():
		if not wanted.has(id):
			_chips[id].dismiss()
			_chips.erase(id)
			_fresh.erase(id)
	if _drag_id != "" and not _chips.has(_drag_id):
		_gesture = Gesture.IGNORED
		_drag_id = ""
		_gap_open = false


## Takes every icon away, for a different game.
func clear() -> void:
	for chip in _chips.values():
		chip.queue_free()
	_chips.clear()
	_fresh.clear()
	_bar_ids.clear()
	_float_ids.clear()
	_drag_id = ""
	_gap_open = false
	_gesture = Gesture.NONE
	_scroll = 0.0
	_scroll_velocity = 0.0


## Picks up the icon that was held, with the finger at a global point: it follows the finger
## until it is let go.
func carry(global_point: Vector2) -> void:
	if _gesture == Gesture.HELD and _press_id != "" and _chips.has(_press_id):
		_begin_drag(global_point - global_position)


## Scrolls the toolbar just far enough to show an icon.
func reveal(preset_id: String) -> void:
	_reveal_id = preset_id


func scroll_offset() -> float:
	return _scroll


func chip_for(preset_id: String) -> ToolChip:
	return _chips.get(preset_id)


func bar_ids() -> Array[String]:
	return _bar_ids


## Where an icon is, in the dock's own coordinates.
func chip_center(preset_id: String) -> Vector2:
	return _chip_center(_chips[preset_id])


## Whether an icon is under a global point.
func has_chip_at(global_point: Vector2) -> bool:
	return _chip_at(global_point - global_position) != ""


func max_scroll() -> float:
	var count := _bar_ids.size() + (1 if _gap_open else 0)
	if count == 0:
		return 0.0
	return maxf(count * ToolChip.SIZE + (count - 1) * GAP + PAD - _slot_rect().size.x, 0.0)


func _has_point(point: Vector2) -> bool:
	if _gesture != Gesture.NONE:
		return true
	if _strip != null and _strip.get_rect().has_point(point):
		return true
	for id in _float_ids:
		if _is_over(_chips[id], point):
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and _gesture != Gesture.NONE:
		_on_move(event.position)


func _on_press(point: Vector2) -> void:
	_gesture = Gesture.PRESSING
	_press_pos = point
	_last_pos = point
	_pointer = point
	_last_move_msec = Time.get_ticks_msec()
	_press_time = 0.0
	_scroll_velocity = 0.0
	_reveal_id = ""
	_press_in_strip = _strip.get_rect().has_point(point)
	_press_id = _chip_at(point)


func _on_move(point: Vector2) -> void:
	var step := point - _last_pos
	_last_pos = point
	_pointer = point
	match _gesture:
		Gesture.PRESSING:
			_on_move_pressing(point)
		Gesture.SCROLLING:
			_scroll_by(-step.x)
			var now := Time.get_ticks_msec()
			var seconds := maxf((now - _last_move_msec) / 1000.0, 0.001)
			_scroll_velocity = lerpf(_scroll_velocity, -step.x / seconds, 0.5)
			_last_move_msec = now
		Gesture.DRAGGING:
			_chips[_drag_id].set_target(point - _grab - _half())
			_update_drop_slot()
		Gesture.HELD:
			finger_moved.emit(global_position + point)


func _on_move_pressing(point: Vector2) -> void:
	var travelled := point.distance_to(_press_pos)
	var sideways := absf(point.x - _press_pos.x)
	if travelled <= SLOP:
		return
	var scrollable := _press_in_strip and (_press_id == "" or _bar_ids.has(_press_id))
	if scrollable and sideways > travelled * 0.5:
		_gesture = Gesture.SCROLLING
		_scroll_by(-(point.x - _press_pos.x))
	else:
		_gesture = Gesture.IGNORED


func _on_release(point: Vector2) -> void:
	var gesture := _gesture
	_gesture = Gesture.NONE
	match gesture:
		Gesture.PRESSING:
			_finish_press(point)
		Gesture.SCROLLING:
			if Time.get_ticks_msec() - _last_move_msec > 80:
				_scroll_velocity = 0.0
		Gesture.DRAGGING:
			_drop(point)
		Gesture.HELD:
			finger_up.emit(global_position + point)


func _finish_press(point: Vector2) -> void:
	if _press_id != "":
		tapped.emit(_press_id)


func _begin_drag(point: Vector2) -> void:
	var chip: ToolChip = _chips[_press_id]
	_drag_id = _press_id
	_bar_ids.erase(_drag_id)
	_float_ids.erase(_drag_id)
	_move_to(chip, self)
	move_child(chip, -1)
	_grab = point - _chip_center(chip)
	chip.lift(true)
	_gesture = Gesture.DRAGGING
	TimerAlert.vibrate(10)
	chip.set_target(point - _grab - _half())
	_update_drop_slot()


## Lets go of the carried icon: into the toolbar if it is over it, onto the screen
## where it is otherwise.
func _drop(point: Vector2) -> void:
	var id := _drag_id
	var chip: ToolChip = _chips[id]
	_drag_id = ""
	chip.lift(false)
	if _gap_open:
		_gap_open = false
		_bar_ids.insert(_drag_index, id)
		placed_in_bar.emit(id, _drag_index)
		return
	var fraction := _fraction_of(point - _grab)
	_float_ids.append(id)
	chip.set_target(_screen_position(fraction))
	placed_on_screen.emit(id, fraction)


func _update_drop_slot() -> void:
	var slot := _slot_rect()
	var center := _pointer - _grab
	var zone := Rect2(0.0, slot.position.y - DROP_ZONE_ABOVE, size.x, size.y)
	_gap_open = zone.has_point(center)
	var index := floori((center.x - slot.position.x + _scroll + GAP / 2.0) / (ToolChip.SIZE + GAP))
	_drag_index = clampi(index, 0, _bar_ids.size())


func _process(delta: float) -> void:
	if _strip == null or _slot == null or not is_visible_in_tree():
		return
	var slot := _slot_rect()
	if slot.size.x <= 0.0:
		return
	_strip.position = slot.position - Vector2(0.0, PAD)
	_strip.size = slot.size + Vector2(0.0, PAD * 2.0)
	if _gesture == Gesture.PRESSING:
		_press_time += delta
		if _press_id != "" and _press_time >= LONG_PRESS_SECONDS:
			_gesture = Gesture.HELD
			TimerAlert.vibrate(20)
			held.emit(_press_id, global_position + _pointer)
	if _gesture == Gesture.DRAGGING:
		_scroll_near_edges(slot, delta)
		_update_drop_slot()
	_snap = _gesture == Gesture.SCROLLING
	if _gesture != Gesture.SCROLLING:
		_coast(delta)
	_apply_targets()


func _scroll_near_edges(slot: Rect2, delta: float) -> void:
	if not _gap_open:
		return
	var x := _pointer.x - _grab.x
	if x < slot.position.x + EDGE_ZONE:
		_scroll = clampf(_scroll - EDGE_SCROLL_SPEED * delta, 0.0, max_scroll())
	elif x > slot.end.x - EDGE_ZONE:
		_scroll = clampf(_scroll + EDGE_SCROLL_SPEED * delta, 0.0, max_scroll())


## After a flick the toolbar keeps gliding and slows down, and if it was pulled past
## either end it eases back. It also glides to show a newly added icon.
func _coast(delta: float) -> void:
	var limit := max_scroll()
	if _reveal_id != "":
		var goal := _scroll_goal_for(_reveal_id, limit)
		_scroll = lerpf(_scroll, goal, 1.0 - exp(-10.0 * delta))
		_snap = true
		if absf(goal - _scroll) < 1.0:
			_scroll = goal
			_reveal_id = ""
		return
	if absf(_scroll_velocity) > 8.0:
		_scroll += _scroll_velocity * delta
		_scroll_velocity -= _scroll_velocity * FRICTION * delta
		_snap = true
	else:
		_scroll_velocity = 0.0
	var inside := clampf(_scroll, 0.0, limit)
	if not is_equal_approx(_scroll, inside):
		_scroll = lerpf(_scroll, inside, 1.0 - exp(-SETTLE_SMOOTHING * delta))
		_scroll_velocity *= 0.5
		_snap = true
		if absf(_scroll - inside) < 0.5:
			_scroll = inside


func _scroll_goal_for(id: String, limit: float) -> float:
	var index := _bar_ids.find(id)
	if index < 0:
		return clampf(_scroll, 0.0, limit)
	var left := index * (ToolChip.SIZE + GAP)
	var right := left + ToolChip.SIZE + PAD
	var visible_width := _slot_rect().size.x
	var goal := _scroll
	if left < _scroll:
		goal = left
	elif right > _scroll + visible_width:
		goal = right - visible_width
	return clampf(goal, 0.0, limit)


func _scroll_by(amount: float) -> void:
	var limit := max_scroll()
	var past := _scroll < 0.0 or _scroll > limit
	_scroll += amount * (RUBBER_BAND if past and (_scroll < 0.0) == (amount < 0.0) else 1.0)


## Sends every icon towards the place it belongs: the toolbar ones in a row, with a
## gap where the carried icon would land, and the loose ones where they were dropped.
func _apply_targets() -> void:
	for i in _bar_ids.size():
		var slot_index := i + (1 if _gap_open and i >= _drag_index else 0)
		_send_to_bar(_chips[_bar_ids[i]], Vector2(slot_index * (ToolChip.SIZE + GAP) - _scroll, PAD))
	for id in _float_ids:
		_send(_chips[id], _screen_position(_chips[id].preset.position), id)


func _send_to_bar(chip: ToolChip, local: Vector2) -> void:
	if chip.get_parent() == self:
		# Still on its way home from being carried; it goes into the toolbar's
		# clipping area only once it has arrived, so it is never cut off.
		_send(chip, local + _strip.position, chip.preset.id)
		if not chip.is_moving() and chip.preset.id != _drag_id:
			_move_to(chip, _strip)
	else:
		_send(chip, local, chip.preset.id)


func _send(chip: ToolChip, point: Vector2, id: String) -> void:
	if _fresh.has(id) or _snap:
		_fresh.erase(id)
		chip.place_at(point)
	else:
		chip.set_target(point)


func _move_to(chip: ToolChip, parent: Control) -> void:
	if chip.get_parent() == parent:
		return
	chip.reparent(parent, true)
	chip.adopt_position()


func _screen_position(fraction: Vector2) -> Vector2:
	var low := Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	var high := size - _half() * 2.0 - low
	return (fraction * size - _half()).clamp(low, high.max(low))


func _fraction_of(center: Vector2) -> Vector2:
	var placed := _screen_position(center / size)
	return (placed + _half()) / size


func _slot_rect() -> Rect2:
	if _slot == null:
		return Rect2()
	var rect := _slot.get_global_rect()
	return Rect2(rect.position - global_position, rect.size)


func _half() -> Vector2:
	return Vector2(ToolChip.SIZE, ToolChip.SIZE) / 2.0


func _chip_center(chip: ToolChip) -> Vector2:
	return chip.get_global_transform() * (chip.size / 2.0) - global_position


func _is_over(chip: ToolChip, point: Vector2) -> bool:
	var offset := (point - _chip_center(chip)).abs()
	return offset.x <= ToolChip.SIZE / 2.0 and offset.y <= ToolChip.SIZE / 2.0


## The icon under a point. Loose icons lie over the toolbar, and the toolbar's icons
## only count inside the strip they are clipped to.
func _chip_at(point: Vector2) -> String:
	for i in range(_float_ids.size() - 1, -1, -1):
		if _is_over(_chips[_float_ids[i]], point):
			return _float_ids[i]
	if _strip.get_rect().has_point(point):
		for id in _bar_ids:
			if _is_over(_chips[id], point):
				return id
	return ""
