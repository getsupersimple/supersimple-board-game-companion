class_name Spring
extends RefCounted
## A value that chases a target like a weight on a spring, so it overshoots a little
## and settles instead of stopping dead. Works for a float or a Vector2. Give it
## a starting value, set `target`, and call `step` every frame.

var value: Variant
var target: Variant
var velocity: Variant
var stiffness := 380.0
## Less than twice the square root of the stiffness overshoots; that much exactly does not.
var damping := 24.0


func _init(start: Variant = 0.0) -> void:
	value = start
	target = start
	velocity = start * 0.0


func step(delta: float) -> void:
	var remaining := minf(delta, 0.1)
	while remaining > 0.0:
		var slice := minf(remaining, 1.0 / 120.0)
		velocity += ((target - value) * stiffness - velocity * damping) * slice
		value += velocity * slice
		remaining -= slice


## Jumps straight to a value and stops there.
func snap(to: Variant) -> void:
	value = to
	target = to
	velocity = to * 0.0


func is_settled(tolerance: float = 0.05) -> bool:
	return _length(target - value) < tolerance and _length(velocity) < tolerance * 10.0


static func _length(amount: Variant) -> float:
	return absf(amount) if amount is float else (amount as Vector2).length()
