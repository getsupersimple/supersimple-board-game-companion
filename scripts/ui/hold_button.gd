class_name HoldButton
extends Button
## A button that only acts when it is held down, so it cannot be hit by accident
## in the middle of a game. A ring fills while it is held.

signal held

const HOLD_SECONDS := 0.6

var _held_for := 0.0
var _holding := false


func _ready() -> void:
	button_down.connect(func() -> void:
		_holding = true
		_held_for = 0.0)
	button_up.connect(_release)
	focus_mode = Control.FOCUS_NONE


func _release() -> void:
	_holding = false
	_held_for = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _holding:
		return
	_held_for += delta
	queue_redraw()
	if _held_for >= HOLD_SECONDS:
		_release()
		held.emit()


func _draw() -> void:
	if _holding and _held_for > 0.0:
		var centre := size / 2.0
		draw_arc(centre, minf(size.x, size.y) / 2.0 - 6.0, -PI / 2.0, -PI / 2.0 + TAU * _held_for / HOLD_SECONDS, 48, Color("#1C1C1E"), 8.0, true)
