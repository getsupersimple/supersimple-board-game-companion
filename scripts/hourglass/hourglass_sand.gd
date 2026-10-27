class_name HourglassSand
extends Node2D
## An hourglass whose sand is real physics. Grains are small rigid bodies in a
## glass-shaped container, pulled by whichever way gravity points on the screen.
##
## The time is read from the sand itself: what is left is the number of grains
## upstream of the neck, whichever way up the glass is, times what one grain is
## worth. To make that time accurate, a gate in the neck lets grains through at
## one per grain-worth of time, measured on the system clock. Adding time pours
## more grains in at the top, and taking time away lifts some out.

signal drained
## A grain has hit something: how hard (0 to 1), and whether it hit the glass or other sand.

## The size of the picture the glass is drawn into, in pixels.
const VIEW_SIZE := Vector2i(660, 1430)
## About how many grains a glass starts with.
const BASE_GRAINS := 550
## The most grains the falling side holds. Past it, each grain is worth more time.
const MAX_UPSTREAM := 900
const GRAIN_RADIUS := 3.6
const GRAVITY := 2000.0
const GATE_THICKNESS := 14.0
const WALL_THICKNESS := 40.0
## How close to vertical the glass must be for the sand to run, as the share of
## gravity that lies along the screen's up and down. Below it the glass is paused.
const FLOW_THRESHOLD := 0.5
## Sand cannot pour faster than the neck lets it, so a grain is never worth less.
const MIN_GRAIN_MS := 60.0
const MAX_ALLOWANCE := 6.0
## When this few grains are left, the last of the sand is drawn on down to the
## neck, so that every single grain goes through before time is up.
const TAIL_GRAINS := 14
const TAIL_PULL := 0.9
## If sand is meant to be running but nothing has crossed for this long, a jam of
## grains is wedged across the neck. A tap, like a real glass gets, frees it.
const STALL_MS := 300
const TAP_REACH := 110.0
const TAP_SPEED := 90.0
## The soft shh of sand: it fades in when grains start crossing the neck or the sand
## is stirred about,
## fades away over the last moments before the sand runs out, and even at its
## loudest it is quiet.
const POUR_DB := -36.0
const POUR_QUIET_DB := -60.0
const POUR_HOLD_MS := 400
const POUR_ATTACK := 1.4
const POUR_RELEASE := 4.0
## The shh starts to fade this long before the last of the sand is through.
const POUR_FADE_MS := 2000.0
## Sand shifting about makes the same sound: a grain this fast is moving, and the
## shh reaches full when this share of the grains are.
const MOVING_SPEED := 150.0
const MOVING_SHARE_QUIET := 0.03
const MOVING_SHARE_FULL := 0.25

## Which way gravity pulls on the screen, from 0 (none) to 1 (a full pull). The
## direction is a unit vector in screen axes, with y pointing down the screen.
var gravity_direction := Vector2.DOWN
var gravity_strength := 1.0
var sand_color := Color("#9B59D0")
## The colour of the caps on the glass.
var cap_color := Color("#E5484D")

var grains: Array[RigidBody2D] = []

var _grain_ms := 200.0
var _sides := PackedInt32Array()
var _gate: CollisionShape2D
var _gate_open := false
var _last_tick_ms := 0
var _allowance := 0.0
var _last_crossing_ms := 0
var _was_flowing := false
var _upstream := 0
var _drained_reported := false
## Some sand has run through since the glass was last full or last drained.
var _sand_has_passed := false
var _material: PhysicsMaterial
## Muted while the glass is out of sight, so it does not hiss from behind another screen.
var muted := false
## Holds every grain still, for as long as it is true, and lets them go again after.
var frozen := false:
	set(value):
		frozen = value
		for grain in grains:
			_set_frozen(grain)
		if not frozen:
			_wake_everything()

var _total_when_ready := 60000
var _pour: AudioStreamPlayer
var _pour_level := 0.0
var _last_pour_ms := -100000
var _last_state := Vector3.ZERO


func _ready() -> void:
	_material = PhysicsMaterial.new()
	_material.friction = 0.3
	_material.bounce = 0.05
	_build_walls()
	_build_gate()
	_build_art()
	_pour = AudioStreamPlayer.new()
	_pour.stream = SoundBank.sand_loop()
	add_child(_pour)
	set_total_ms(_total_when_ready)


## Fills the glass with enough sand for this long, all in the top chamber. It can
## be called before the glass is in the scene.
func set_total_ms(total_ms: int) -> void:
	_total_when_ready = total_ms
	if _material == null:
		return
	var count := _plan(total_ms)
	_grain_ms = total_ms / float(count)
	for grain in grains:
		grain.queue_free()
	grains.clear()
	for spot in HourglassShape.spawn_positions(count, GRAIN_RADIUS, true):
		_add_grain(spot)
	_rebuild_sides()
	_close_gate()
	_was_flowing = false
	_drained_reported = false
	_sand_has_passed = false


## Pours the sand back into the top chamber, ready to run again.
func reset() -> void:
	set_total_ms(total_ms())


## What the whole glass is worth, in milliseconds.
func total_ms() -> int:
	if grains.is_empty():
		return _total_when_ready
	return int(round(maxi(grains.size(), 1) * _grain_ms))


## The time left, read from how much sand is still on the falling side.
func remaining_ms() -> int:
	return int(round(_upstream * _grain_ms))


func upstream_count() -> int:
	return _upstream


## True while the sand is running: the glass is near enough to upright either way up.
func is_flowing() -> bool:
	return gravity_strength > 0.05 and absf(gravity_direction.y) * gravity_strength >= FLOW_THRESHOLD


## Changes how long the whole glass lasts, which is all of the sand in it, wherever
## it is. Less time lifts sand out of the emptier chamber first, then the fuller one.
## More time is poured onto the fuller chamber.
func set_duration(duration_ms: int) -> void:
	var target := 0
	if duration_ms > 0:
		# Each grain is worth no less than the neck can pass, and no more than the
		# glass has room for.
		target = clampi(int(round(duration_ms / maxf(_grain_ms, MIN_GRAIN_MS))), 1, MAX_UPSTREAM)
		_grain_ms = duration_ms / float(target)
	var above := 0
	for side in _sides:
		if side < 0:
			above += 1
	var below := grains.size() - above
	var upper_is_fuller := above > below or (above == below and gravity_direction.y >= 0.0)
	var difference := target - grains.size()
	if difference > 0:
		for spot in _pour_positions(difference, upper_is_fuller):
			_add_grain(spot)
	elif difference < 0:
		var emptier_first: Array[RigidBody2D] = []
		var fuller_after: Array[RigidBody2D] = []
		for i in grains.size():
			var in_upper := _sides[i] < 0
			(fuller_after if in_upper == upper_is_fuller else emptier_first).append(grains[i])
		var by_distance := func(a: RigidBody2D, b: RigidBody2D) -> bool:
			return absf(a.position.y - HourglassShape.NECK_Y) > absf(b.position.y - HourglassShape.NECK_Y)
		emptier_first.sort_custom(by_distance)
		fuller_after.sort_custom(by_distance)
		for grain in (emptier_first + fuller_after).slice(0, -difference):
			grains.erase(grain)
			grain.queue_free()
	_rebuild_sides()
	_wake_everything()


func _plan(total_ms: int) -> int:
	var grain_ms := maxf(total_ms / float(BASE_GRAINS), MIN_GRAIN_MS)
	var count := int(round(total_ms / grain_ms))
	return clampi(count, 1, MAX_UPSTREAM)


## Where new sand goes: in rows above the top of the pile, away from the neck.
func _pour_positions(count: int, upper_side: bool) -> PackedVector2Array:
	var direction := -1.0 if upper_side else 1.0
	var edge := HourglassShape.NECK_Y - direction * 60.0
	for i in grains.size():
		if (_sides[i] < 0) == upper_side:
			var y := grains[i].position.y
			edge = minf(edge, y) if upper_side else maxf(edge, y)
	var spots := PackedVector2Array()
	var y := edge + direction * GRAIN_RADIUS * 2.6
	while spots.size() < count:
		var clamped := clampf(y, HourglassShape.CAP_DEPTH + GRAIN_RADIUS * 1.2, HourglassShape.HEIGHT - HourglassShape.CAP_DEPTH - GRAIN_RADIUS * 1.2)
		var room := HourglassShape.half_width(clamped) - GRAIN_RADIUS * 1.3
		var x := -room
		while x <= room and spots.size() < count:
			spots.append(Vector2(x, clamped))
			x += GRAIN_RADIUS * 2.1
		y += direction * GRAIN_RADIUS * 1.85
	return spots


func _add_grain(spot: Vector2) -> void:
	var grain := RigidBody2D.new()
	grain.position = spot
	grain.gravity_scale = 0.0
	grain.linear_damp = 0.4
	grain.angular_damp = 1.0
	grain.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	grain.physics_material_override = _material
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GRAIN_RADIUS
	collision.shape = circle
	grain.add_child(collision)
	add_child(grain)
	_set_frozen(grain)
	grains.append(grain)


func _set_frozen(grain: RigidBody2D) -> void:
	grain.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	grain.freeze = frozen
	if frozen:
		grain.linear_velocity = Vector2.ZERO
		grain.angular_velocity = 0.0


func _rebuild_sides() -> void:
	_sides.resize(grains.size())
	_sides.fill(0)
	_update_sides()


func _physics_process(delta: float) -> void:
	_update_pour_sound(delta)
	if frozen:
		return
	# The glass is flat on the screen: only gravity along the screen moves the sand.
	# Held flat there is none, and the sand rests wherever it lies.
	var along := clampf(gravity_strength, 0.0, 1.0)
	var pull := gravity_direction * along * GRAVITY
	var state := Vector3(gravity_direction.x * along, gravity_direction.y * along, 0.0)
	if state.distance_to(_last_state) > 0.04:
		_last_state = state
		_wake_everything()
	var keep_awake := is_flowing()
	var sweeping := keep_awake and _upstream > 0 and _upstream <= TAIL_GRAINS
	var upper_side := gravity_direction.y >= 0.0
	for i in grains.size():
		var grain := grains[i]
		var force := pull
		if sweeping and (_sides[i] < 0) == upper_side:
			force += (Vector2(0.0, HourglassShape.NECK_Y) - grain.position).normalized() * TAIL_PULL * GRAVITY
		grain.apply_central_force(force * grain.mass)
		if keep_awake:
			grain.sleeping = false
	_return_escapees()
	var crossed := _update_sides()
	_meter_the_flow(crossed)


## How much the sand is moving about, from nothing (it lies still) to one (a good
## part of it is on the move), whatever is moving it: pouring, tilting, sloshing.
func _stirring() -> float:
	if grains.is_empty():
		return 0.0
	var moving := 0
	for grain in grains:
		if grain.linear_velocity.length_squared() > MOVING_SPEED * MOVING_SPEED:
			moving += 1
	return clampf((float(moving) / grains.size() - MOVING_SHARE_QUIET) / (MOVING_SHARE_FULL - MOVING_SHARE_QUIET), 0.0, 1.0)


## Fades the shh up while sand is pouring or moving and away when it stops.
func _update_pour_sound(delta: float) -> void:
	var pouring := not frozen and not muted and AppSettings.sand_sound \
			and Time.get_ticks_msec() - _last_pour_ms < POUR_HOLD_MS
	var ending := clampf(remaining_ms() / POUR_FADE_MS, 0.0, 1.0)
	var wanted := ending if pouring else 0.0
	if not frozen and not muted and AppSettings.sand_sound:
		wanted = maxf(wanted, _stirring())
	_pour_level = move_toward(_pour_level, wanted, (POUR_ATTACK if wanted > _pour_level else POUR_RELEASE) * delta)
	if _pour_level <= 0.001:
		if _pour.playing:
			_pour.stop()
		return
	if not _pour.playing:
		_pour.play()
	_pour.volume_db = lerpf(POUR_QUIET_DB, POUR_DB, _pour_level)


## Works out which side of the neck every grain is on. Returns how many crossed.
func _update_sides() -> int:
	var crossed := 0
	var upper_count := 0
	for i in grains.size():
		var side := -1 if grains[i].position.y < HourglassShape.NECK_Y else 1
		if _sides[i] != side and _sides[i] != 0:
			crossed += 1
		_sides[i] = side
		if side < 0:
			upper_count += 1
	_upstream = upper_count if gravity_direction.y >= 0.0 else grains.size() - upper_count
	return crossed


func _meter_the_flow(crossed: int) -> void:
	var now := Time.get_ticks_msec()
	var elapsed := now - _last_tick_ms
	_last_tick_ms = now
	if _upstream > 0:
		_drained_reported = false
	if not is_flowing():
		_close_gate()
		_was_flowing = false
		return
	if crossed > 0:
		_sand_has_passed = true
		_last_pour_ms = now
	if not _was_flowing:
		# Running starts with a grain ready to go, as when a glass is turned over.
		_was_flowing = true
		_allowance = 1.0
		_wake_everything()
	# Grains are let through at one per grain's worth of time on average. A grain
	# takes a moment to fall, so several can be on the way at once; the gate only
	# shuts when the sand has run ahead of the clock.
	_allowance = minf(_allowance + elapsed / _grain_ms, MAX_ALLOWANCE) - crossed
	if crossed > 0:
		_last_crossing_ms = now
	if _allowance >= 1.0 and _upstream > 0:
		_gate_open = true
		_gate.disabled = true
		if now - _last_crossing_ms > STALL_MS:
			_last_crossing_ms = now
			_tap_the_neck()
	else:
		_close_gate()
		_last_crossing_ms = now
	# An empty side only counts as finished if sand ran out of it, so tilting a glass
	# whose upper side is already empty does not chime.
	if _upstream == 0 and _sand_has_passed and not _drained_reported:
		_drained_reported = true
		_sand_has_passed = false
		drained.emit()


func _wake_everything() -> void:
	for grain in grains:
		grain.sleeping = false


## Jostles the grains near the neck, to break an arch that has jammed it.
func _tap_the_neck() -> void:
	for grain in grains:
		if absf(grain.position.y - HourglassShape.NECK_Y) < TAP_REACH:
			grain.linear_velocity += Vector2(randf_range(-TAP_SPEED, TAP_SPEED), randf_range(-TAP_SPEED, TAP_SPEED) * 0.4)


## The gate is as wide as the neck and thin, so a grain caught in it as it
## shuts is pushed straight up or down, never sideways into the glass.
func _close_gate() -> void:
	_gate_open = false
	if _gate != null:
		_gate.disabled = false


## A grain that has got through the glass, at a seam in the wall, is put back
## inside where it left, so no sand is ever lost.
func _return_escapees() -> void:
	for grain in grains:
		var y := grain.position.y
		var limit := HourglassShape.half_width(y) - GRAIN_RADIUS
		if absf(grain.position.x) > limit + GRAIN_RADIUS * 1.5 or y < 0.0 or y > HourglassShape.HEIGHT:
			var inside := Vector2(clampf(grain.position.x, -limit, limit), clampf(y, HourglassShape.CAP_DEPTH + GRAIN_RADIUS, HourglassShape.HEIGHT - HourglassShape.CAP_DEPTH - GRAIN_RADIUS))
			PhysicsServer2D.body_set_state(grain.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, to_global(inside)))
			grain.linear_velocity = Vector2.ZERO


## The back of the glass, the sand in the middle of it, and the front of the glass
## and the frame on top, so the sand sits inside the glass.
func _build_art() -> void:
	var mass := SandMass.new()
	add_child(mass)
	mass.setup(grains, VIEW_SIZE, sand_color)
	var front := ArtLayer.new()
	front.draw_function = HourglassArt.draw_front.bind(cap_color)
	add_child(front)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	var material := PhysicsMaterial.new()
	material.friction = 0.4
	material.bounce = 0.05
	body.physics_material_override = material
	add_child(body)
	var wall := HourglassShape.right_wall()
	for i in wall.size() - 1:
		for sign in [1.0, -1.0]:
			var a := Vector2(wall[i].x * sign, wall[i].y)
			var b := Vector2(wall[i + 1].x * sign, wall[i + 1].y)
			var outward := Vector2(sign * WALL_THICKNESS, 0.0)
			_add_polygon(body, [a, b, b + outward, a + outward])
	var top := HourglassShape.half_width(0.0) + WALL_THICKNESS
	var lid := HourglassShape.CAP_DEPTH
	_add_polygon(body, [Vector2(-top, lid - WALL_THICKNESS), Vector2(top, lid - WALL_THICKNESS), Vector2(top, lid), Vector2(-top, lid)])
	var floor_y := HourglassShape.HEIGHT - lid
	_add_polygon(body, [Vector2(-top, floor_y), Vector2(top, floor_y), Vector2(top, floor_y + WALL_THICKNESS), Vector2(-top, floor_y + WALL_THICKNESS)])


func _add_polygon(body: StaticBody2D, points: Array) -> void:
	var collision := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array(points)
	collision.shape = shape
	body.add_child(collision)


func _build_gate() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	_gate = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HourglassShape.NECK_HALF_WIDTH * 2.0, GATE_THICKNESS)
	_gate.shape = shape
	_gate.position = Vector2(0.0, HourglassShape.NECK_Y)
	body.add_child(_gate)
