class_name SandGlass
extends Node2D
## What the hourglass tool needs from a glass of sand. The time is the sand
## itself: what is left is the sand on the falling side.

signal drained

## The size of the picture the glass is drawn into, in pixels.
const VIEW_SIZE := Vector2i(660, 1430)
## How close to vertical the glass must be for the sand to run, as the share of
## gravity that lies along the screen's up and down. Below it the glass is paused.
const FLOW_THRESHOLD := 0.5

## Which way gravity pulls on the screen, from 0 (none) to 1 (a full pull). The
## direction is a unit vector in screen axes, with y pointing down the screen.
var gravity_direction := Vector2.DOWN
var gravity_strength := 1.0
var sand_color := Color("#9B59D0"):
	set(value):
		sand_color = value
		cap_color = HourglassArt.complement(value)
## The caps at each end of the glass.
var cap_color := HourglassArt.complement(sand_color)
## Muted while the glass is out of sight, so it does not hiss from behind another screen.
var muted := false
## Holds the sand still for as long as it is true, and lets it go again after.
var frozen := false:
	set = set_frozen


func set_frozen(value: bool) -> void:
	frozen = value


## Fills the glass with enough sand for this long, all in the top chamber.
func set_total_ms(_total_ms: int) -> void:
	pass


## Pours the sand back into the top chamber, ready to run again.
func reset() -> void:
	set_total_ms(total_ms())


## What the whole glass is worth, in milliseconds.
func total_ms() -> int:
	return 0


## The time left, read from how much sand is still on the falling side.
func remaining_ms() -> int:
	return 0


## Zero once nothing is left on the falling side.
func upstream_count() -> int:
	return 0


## Changes how long the whole glass lasts, which is all of the sand in it.
func set_duration(_duration_ms: int) -> void:
	pass


## True while the sand is running: the glass is near enough to upright either way up.
func is_flowing() -> bool:
	return gravity_strength > 0.05 and absf(gravity_direction.y) * gravity_strength >= FLOW_THRESHOLD


## The frame on top of the sand, so the sand sits inside the glass.
func _add_front() -> void:
	var front := ArtLayer.new()
	front.draw_function = HourglassArt.draw_front.bind(cap_color)
	add_child(front)
