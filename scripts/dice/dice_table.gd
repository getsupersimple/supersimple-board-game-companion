class_name DiceTable
extends Node3D
## The 3D table: a fixed near top-down camera over a walled floor. Gravity
## follows the device tilt, a shake tosses the dice, and a roll is decided once
## every die has stayed at rest for a short hold time. Real physics decides.

## Values are aligned with `dice`. -1 means undecided (moving or cocked).
signal results_changed(values: Array)

const GRAVITY := 15.0
## A die with a finger held on it is pulled straight down this many times harder.
const HEAVY_GRAVITY := 8.0
## How much more a pressed-down die weighs for each unit it is above the table, and how hard it
## shoves a die beneath it aside, as a share of the pressing force.
const PRESS_HEIGHT_GAIN := 4.0
const PRESS_SHOVE := 0.6
## How fast a cocked die is turned flat while pressed, and how much harder everything pushes for
## each second the press goes on.
const PRESS_TURN := 120.0
const PRESS_RAMP := 1.5
## On iOS the gravity reading points at the ground in the device's frame (flat
## and face up reads -z). Other platforms may differ, which flips this sign.
const SENSOR_SIGN := 1.0
const GRAVITY_SMOOTHING := 0.15
const SETTLE_HOLD := 0.3
## Table acceleration per m/s2 of device acceleration. The table is far bigger
## than a phone screen, so device movement is scaled up.
const MOTION_FORCE := 4.0
const MOTION_DEAD_ZONE := 1.0
const MOTION_MAX := 60.0
const SHAKE_THRESHOLD := 8.0
const STANDARD_GRAVITY := 9.80665
const BASELINE_SMOOTHING := 0.05
## Dragging a die: a spring pulls the touched point towards the finger, and a
## steady downward press keeps the finger on the die.
const GRAB_STIFFNESS := 60.0
const GRAB_DAMPING := 9.0
const GRAB_MAX_FORCE := 120.0
const GRAB_PRESS_FORCE := 20.0
const IMPACT_VOICES := 4
const LOUD_SPEED := 10.0
const HAPTIC_SPEED := 5.0
const HAPTIC_GAP_MS := 120
const TAP_DISTANCE := 0.4
const LONG_PRESS_SECONDS := 0.5
const RELEASE_MAX_SPEED := 10.0
const RELEASE_SPEED_KEPT := 1.3
const SHAKE_COOLDOWN := 0.5
## A die must lie flat and still this long before auto lock takes it.
const AUTO_LOCK_HOLD := 0.35
## After Unlock all, auto lock waits this long before it may lock anything again.
const AUTO_LOCK_PAUSE := 1.0
## Once every die has landed, they are held exactly where they lie for this long (seconds).
const PIN_SECONDS := 2.0
## After being let go, the dice have to move this long (seconds) before they are held again.
const PIN_REARM_SECONDS := 0.4
const CAMERA_HEIGHT := 20.0
## The camera looks straight down without perspective, so a die is drawn the same size and
## in the same place at any height, and the walls can stand right at the edge of the view.
const VIEW_WIDTH := 9.4
const WALL_THICKNESS := 2.0
## The share of the visible floor inside the walls: nearly all of it, so the dice can go right
## down to the edge of the view.
const VIEW_FILL := 0.985
## A tap on the table sends every die up at about this speed.
const JUMP_SPEED := 4.5
## The screen glass: dice stay inside a shallow box, as on a real device.
const CEILING_HEIGHT := 6.0
## Dice are dropped in from no higher than this.
const DROP_HEIGHT := 2.0

## A finger has stayed on this die without moving. `view_position` is where it is.
signal die_held(die: Die, view_position: Vector2)

var dice: Array[Die] = []
## The view onto the table, for working out where a die is on the screen.
var camera: Camera3D
## While on, a die is locked in place as soon as it lies flat and still.
var auto_lock := false

var _half_extents := Vector2(5.0, 9.0)
var _gravity_direction := Vector3.DOWN
var _pressing := false
## How long the table has been pressed, which makes the pressing harder the longer it goes on.
var _press_time := 0.0
## How long each die has been at rest; a die counts as settled after SETTLE_HOLD.
var _rest := {}
var _last_values: Array = []
var _shake_cooldown := 0.0
var _accel_baseline := Vector3.ZERO
var _grabbed: Die
var _grab_local_point := Vector3.ZERO
var _grab_target := Vector3.ZERO
var _grab_height := 0.0
var _grab_travel := 0.0
var _grab_time := 0.0
var _grab_view := Vector2.ZERO
## A die held still offers its menu, unless it was picked up by a long press that already did.
var _grab_offers_menu := true
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_haptic_ms := 0
var _bounds: Node3D
var _flat_time := {}
var _auto_lock_pause := 0.0
## Seconds left of holding the settled dice in place; zero when they are free.
var _pin_left := 0.0
var _pinned := false
## The dice were held once since they last moved, so they are not held again until they do.
var _pin_spent := false
## How long some die has been moving, without a break.
var _moving_time := 0.0
## A die that has just been unlocked waits this long (seconds, counting down) before auto lock takes it again.
var _hold_off := {}


func _ready() -> void:
	for i in IMPACT_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.stream = SoundBank.stream("tick")
		add_child(voice)
		_voices.append(voice)
	_build_environment()
	_rebuild_bounds()


## Fits the walls to the visible floor. Call whenever the view is resized.
func set_view_aspect(aspect: float) -> void:
	# The camera is a perspective one, so the top of a die is drawn further out than
	# the floor under it. The walls stand in far enough that no die, even the tallest,
	# is drawn past the edge of the view.
	var half_width := VIEW_WIDTH / 2.0 * VIEW_FILL
	_half_extents = Vector2(half_width, half_width / aspect)
	if is_inside_tree():
		_rebuild_bounds()


## Drops a new die from above. Existing dice stay where they are.
func add_die(side_count: int, color: Color, style: Die.NumeralStyle = Die.NumeralStyle.NORMAL) -> Die:
	var die := Die.new()
	die.setup(side_count, color, style)
	add_child(die)
	die.position = Vector3(
		randf_range(-_half_extents.x, _half_extents.x) * 0.6,
		minf(1.6 + dice.size() * 0.15, DROP_HEIGHT),
		randf_range(-_half_extents.y, _half_extents.y) * 0.6)
	die.basis = Basis(Quaternion(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf() * TAU))
	die.linear_velocity = Vector3(0, -2.0, 0)
	die.angular_velocity = _random_spin(8.0)
	die.impact.connect(_on_impact)
	die.unlocked.connect(func() -> void: _hold_off[die] = AUTO_LOCK_PAUSE)
	dice.append(die)
	_unsettle()
	_emit_results()
	return die


## A percentile roll: a tens d10 followed by a units d10, read together.
func add_percentile(color: Color) -> Array[Die]:
	var tens := add_die(10, color, Die.NumeralStyle.TENS)
	var units := add_die(10, color, Die.NumeralStyle.UNITS)
	tens.partner = units
	units.partner = tens
	return [tens, units]


## Removing one half of a percentile pair removes both.
## A knock plays a click, louder and lower for a harder knock, and a hard one
## also gives a light tap in the hand.
func _on_impact(strength: float) -> void:
	if AppSettings.dice_sound:
		var voice := _voices[_next_voice]
		_next_voice = (_next_voice + 1) % _voices.size()
		voice.stream = SoundBank.stream("tick")
		voice.volume_db = linear_to_db(clampf(strength / LOUD_SPEED, 0.08, 1.0))
		voice.pitch_scale = randf_range(0.85, 1.25) - minf(strength / LOUD_SPEED, 1.0) * 0.2
		voice.play()
	var now := Time.get_ticks_msec()
	if strength >= HAPTIC_SPEED and now - _last_haptic_ms >= HAPTIC_GAP_MS:
		_last_haptic_ms = now
		Haptics.pulse(12)


## While a finger is held on the bare table every free die is held down like a held die: pulled
## hard onto the table and damped, so the lot settle at once.
func press_down(on: bool) -> void:
	_press_time = 0.0
	_pressing = on
	_unpin()
	for die in dice:
		# Letting go reaches locked dice too: one that auto lock froze during the press is
		# still weighted and damped, and would stay stuck once unlocked.
		if not on or not die.locked:
			die.hold(on)


func remove_die(die: Die) -> void:
	_unpin()
	for doomed in [die, die.partner]:
		if doomed != null:
			dice.erase(doomed)
			_hold_off.erase(doomed)
			doomed.queue_free()
	_emit_results()


## Takes every die off the table.
func remove_all() -> void:
	_unpin()
	for die in dice:
		die.queue_free()
	dice.clear()
	_hold_off.clear()
	_rest.clear()
	_emit_results()


## Throws every unlocked die again. Locked dice stay where they are.
func roll_all() -> void:
	_unpin()
	for die in dice:
		if die.locked:
			continue
		die.sleeping = false
		var heading := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		die.linear_velocity = heading * randf_range(5.0, 9.0) + Vector3.UP * randf_range(2.5, 5.0)
		die.angular_velocity = _random_spin(20.0)
	_unsettle()
	_emit_results()


## Throws every unlocked die the way a swipe went: `direction` is on the table's floor (x across,
## y down the screen), `speed` how hard.
func throw_all(direction: Vector2, speed: float) -> void:
	_unpin()
	var heading := Vector3(direction.x, 0.0, direction.y).normalized()
	for die in dice:
		if die.locked:
			continue
		die.sleeping = false
		die.linear_velocity = heading * speed * randf_range(0.85, 1.15) + Vector3.UP * randf_range(2.5, 4.5)
		die.angular_velocity = _random_spin(20.0)
	_unsettle()


## Every unlocked die jumps up, as if the surface had been tapped from underneath.
func jump_all() -> void:
	_unpin()
	for die in dice:
		if die.locked:
			continue
		die.sleeping = false
		die.linear_velocity += Vector3.UP * randf_range(JUMP_SPEED * 0.8, JUMP_SPEED * 1.2)
		die.angular_velocity += _random_spin(4.0)
	_unsettle()


## Puts a finger down on the die under a point of the view. Returns true on a
## hit. The die then follows the finger until `end_touch`.
func begin_touch(view_position: Vector2, offers_menu: bool = true) -> bool:
	var hit := _die_hit(view_position)
	if hit.is_empty():
		return false
	_grab_offers_menu = offers_menu
	_unpin()
	_grabbed = hit["collider"]
	_grabbed.sleeping = false
	_grab_local_point = _grabbed.to_local(hit["position"])
	_grab_height = hit["position"].y
	_grab_target = hit["position"]
	_grab_travel = 0.0
	_grab_time = 0.0
	_grab_view = view_position
	return true


## The die under a point of the view, if any, without picking it up.
func die_at(view_position: Vector2) -> Die:
	var hit := _die_hit(view_position)
	return hit["collider"] if not hit.is_empty() else null


## Whether a die is under a point of the view.
func is_die_at(view_position: Vector2) -> bool:
	return not _die_hit(view_position).is_empty()


func _die_hit(view_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(view_position)
	var to := from + camera.project_ray_normal(view_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to, Die.DICE_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() and hit["collider"] is Die else {}


## Moves the finger. The touched point is pulled towards it.
func move_touch(view_position: Vector2) -> void:
	if _grabbed == null:
		return
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(view_position)
	var point: Variant = Plane(Vector3.UP, _grab_height).intersects_ray(from, camera.project_ray_normal(view_position))
	if point == null:
		return
	var target: Vector3 = point
	target.x = clampf(target.x, -_half_extents.x, _half_extents.x)
	target.z = clampf(target.z, -_half_extents.y, _half_extents.y)
	_grab_view = view_position
	_grab_travel += target.distance_to(_grab_target)
	_grab_target = target


## Lifts the finger. A touch that barely moved is a tap and bumps the die.
func end_touch() -> void:
	if _grabbed == null or not is_instance_valid(_grabbed):
		_grabbed = null
		return
	if _grabbed.locked:
		_grabbed = null
		return
	if _grab_travel < TAP_DISTANCE:
		nudge(_grabbed, _grabbed.to_global(_grab_local_point))
	_grabbed.linear_velocity = (_grabbed.linear_velocity * RELEASE_SPEED_KEPT).limit_length(RELEASE_MAX_SPEED)
	_grabbed = null


## A gentle push to one die, which may knock into its neighbours. The die is
## pushed away from where it was touched, so a touch on its left edge sends it right.
func nudge(die: Die, touch_point: Vector3 = Vector3.INF) -> void:
	if die.locked:
		return
	die.sleeping = false
	var sideways := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	if touch_point != Vector3.INF:
		sideways = die.global_position - touch_point
		sideways.y = 0.0
	sideways = sideways.normalized() * 2.5 if sideways.length() > 0.01 else Vector3.ZERO
	die.apply_central_impulse(sideways + Vector3(0, 3.0, 0))
	die.apply_torque_impulse(_random_spin(1.5))


func _physics_process(delta: float) -> void:
	if _pressing:
		_press_time += delta
	_apply_gravity()
	_check_long_press(delta)
	_drag_grabbed_die()
	_recover_lost_dice()
	_update_gravity()
	_check_shake(delta)
	_check_settled(delta)
	_lock_dice_that_landed(delta)


## Puts back any die that ended up outside the walls, for example after the
## view was resized, so a die can never be lost off the table.
func _recover_lost_dice() -> void:
	for die in dice:
		var at := die.global_position
		var lost := at.y < -1.0 or at.y > CEILING_HEIGHT \
				or absf(at.x) > _half_extents.x or absf(at.z) > _half_extents.y
		if lost:
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			die.global_position = Vector3(
				clampf(at.x, -_half_extents.x * 0.8, _half_extents.x * 0.8),
				2.0,
				clampf(at.z, -_half_extents.y * 0.8, _half_extents.y * 0.8))
			die.sleeping = false
			_unsettle()
			if die.locked:
				die.move_padlock()


func _apply_gravity() -> void:
	for die in dice:
		if die.locked:
			continue
		if die.heavy:
			# The higher a die is, the harder it is pulled down, so one lying across another
			# bears down on it and forces it out from underneath.
			var weight := 1.0 + PRESS_HEIGHT_GAIN * maxf(die.global_position.y, 0.0)
			die.apply_central_force(Vector3.DOWN * GRAVITY * HEAVY_GRAVITY * weight * die.mass)
			_shove_out_from_under(die, weight)
			if _pressing and die.read_value() == -1:
				_flatten(die, weight)
		else:
			die.apply_central_force(_gravity_direction * GRAVITY * die.mass)


## A pressed-down die pushes sideways on any die lying lower beneath it, away from itself.
func _shove_out_from_under(top: Die, weight: float) -> void:
	for below in dice:
		if below == top or below.locked or below.global_position.y > top.global_position.y - 0.5:
			continue
		var apart := Vector3(below.global_position.x - top.global_position.x, 0.0, below.global_position.z - top.global_position.z)
		if apart.length() > top.reach() + below.reach():
			continue
		if apart.length() < 0.01:
			apart = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		below.sleeping = false
		below.apply_central_force(apart.normalized() * GRAVITY * HEAVY_GRAVITY * below.mass * weight * PRESS_SHOVE)


## A die that is still cocked while pressed is turned towards its nearest flat position and
## shoves aside whatever it leans on or against, harder the longer it goes on, until it lands.
func _flatten(die: Die, weight: float) -> void:
	var ramp := 1.0 + _press_time * PRESS_RAMP
	var turn := Quaternion(die.flat_transform().basis.orthonormalized() * die.global_transform.basis.orthonormalized().inverse())
	var angle := turn.get_angle()
	if angle > PI:
		angle -= TAU
	if absf(angle) > 0.02:
		die.apply_torque(turn.get_axis() * angle * PRESS_TURN * ramp * die.mass)
	for other in dice:
		if other == die or other.locked:
			continue
		var apart := Vector3(other.global_position.x - die.global_position.x, 0.0, other.global_position.z - die.global_position.z)
		if apart.length() > die.reach() + other.reach():
			continue
		if apart.length() < 0.01:
			apart = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		other.sleeping = false
		other.apply_central_force(apart.normalized() * GRAVITY * HEAVY_GRAVITY * other.mass * PRESS_SHOVE * ramp)


func _update_gravity() -> void:
	var sensor := Input.get_gravity()
	if sensor.length() < 1.0:
		return
	_set_gravity_direction(_gravity_direction.lerp(gravity_direction_from_sensor(sensor), GRAVITY_SMOOTHING).normalized())


## Gravity is a force on each die, so it can point anywhere. Whether a tilt
## moves a die is up to friction, as on a real table.
func _set_gravity_direction(direction: Vector3) -> void:
	_gravity_direction = direction


## Table direction of gravity for a sensor reading. Device axes to table axes:
## screen right is +x, screen up is -z, out of the screen is +y. The full 3D
## direction is used, so a phone held upright makes the dice fall to its lower
## edge, and a phone held face down presses them against the screen glass.
func gravity_direction_from_sensor(sensor: Vector3) -> Vector3:
	return (SENSOR_SIGN * Vector3(sensor.x, sensor.z, -sensor.y)).normalized()


## The device is a box that holds the dice: when it accelerates, the dice lag
## behind it. A hard shake also tosses them up so they tumble.
func _check_shake(delta: float) -> void:
	_shake_cooldown = maxf(0.0, _shake_cooldown - delta)
	var motion := motion_from_accelerometer(Input.get_accelerometer(), Input.get_gravity())
	if motion.length() < MOTION_DEAD_ZONE:
		return
	var push := -motion.limit_length(MOTION_MAX) * MOTION_FORCE
	for die in dice:
		if die.locked:
			continue
		die.sleeping = false
		die.apply_central_force(push * die.mass)
	if motion.length() > SHAKE_THRESHOLD and _shake_cooldown <= 0.0:
		_shake_cooldown = SHAKE_COOLDOWN
		for die in dice:
			if die.locked:
				continue
			die.apply_central_impulse(Vector3(0, randf_range(2.0, 4.5), 0))
			die.apply_torque_impulse(_random_spin(2.0))


## Device acceleration in table axes (m/s2) with gravity removed. The
## accelerometer includes gravity, so when the platform also reports gravity
## it is subtracted exactly. Otherwise gravity is estimated as the slow average
## of the readings. Some platforms report in g.
func motion_from_accelerometer(raw: Vector3, gravity: Vector3 = Vector3.ZERO) -> Vector3:
	if raw.length() == 0.0:
		return Vector3.ZERO
	var moving: Vector3
	if gravity.length() > 1.0:
		moving = raw - gravity
	else:
		if _accel_baseline == Vector3.ZERO:
			_accel_baseline = raw
		var unit := STANDARD_GRAVITY if _accel_baseline.length() < 3.0 else 1.0
		_accel_baseline = _accel_baseline.lerp(raw, BASELINE_SMOOTHING)
		moving = (raw - _accel_baseline) * unit
	return Vector3(moving.x, moving.z, -moving.y)


## Whether a finger is dragging a die.
func is_dragging() -> bool:
	return _grabbed != null and is_instance_valid(_grabbed)


## Takes the padlock off every locked die. With auto lock on, they stay free for a second before it
## may lock them again.
func unlock_all() -> void:
	_unpin()
	for die in dice:
		if die.locked:
			die.set_locked(false)
	_auto_lock_pause = AUTO_LOCK_PAUSE
	_unsettle()


## With auto lock on, locks each die that has lain flat and still for a moment. A die that
## cannot be locked, say one leaning on another, is left alone until it moves again.
func _lock_dice_that_landed(delta: float) -> void:
	if not auto_lock:
		_flat_time.clear()
		return
	if _auto_lock_pause > 0.0:
		_auto_lock_pause -= delta
		_flat_time.clear()
		return
	for die in dice:
		if _hold_off.has(die):
			_hold_off[die] -= delta
			if _hold_off[die] <= 0.0:
				_hold_off.erase(die)
			else:
				_flat_time.erase(die)
				continue
		if die.locked or die == _grabbed or not die.is_at_rest() or die.read_value() < 0:
			_flat_time.erase(die)
			continue
		var waited: float = _flat_time.get(die, 0.0) + delta
		_flat_time[die] = waited
		if waited >= AUTO_LOCK_HOLD:
			_flat_time[die] = -INF if not die.try_lock() else 0.0
			_unsettle()


func _unsettle() -> void:
	_unpin()
	_rest.clear()
	_emit_results()


## Lets the held dice go.
func _unpin() -> void:
	if not _pinned:
		return
	_pinned = false
	_pin_left = 0.0
	for die in dice:
		die.pin(false)


func _check_settled(delta: float) -> void:
	if _pinned:
		_pin_left -= delta
		if _pin_left <= 0.0:
			_pin_spent = true
			_unpin()
	for die in dice:
		# A die pressed down, or held in a finger, is slow without having landed: it does not count
		# as settled until it is let go.
		var landed := die.is_at_rest() and (die.locked or (not _pressing and die != _grabbed))
		_rest[die] = (float(_rest.get(die, 0.0)) + delta) if landed else 0.0
	var all_settled := not dice.is_empty() and _grabbed == null and not _pressing
	for die in dice:
		if float(_rest.get(die, 0.0)) < SETTLE_HOLD:
			all_settled = false
	# A die jostled for a split second as it is let go does not count as the dice moving again.
	var still_moving := false
	for die in dice:
		still_moving = still_moving or not die.is_at_rest()
	_moving_time = (_moving_time + delta) if still_moving else 0.0
	if _moving_time > PIN_REARM_SECONDS:
		_pin_spent = false
	if all_settled and not _pinned and not _pin_spent:
		_pinned = true
		_pin_left = PIN_SECONDS
		for die in dice:
			die.pin(true)
	_emit_results()


## Each die's value, or -1 for one that has not been at rest long enough to be read. Dice settle
## one by one, so a colour whose dice have all landed can be read while another is still rolling.
func _emit_results() -> void:
	var values: Array = []
	for die in dice:
		values.append(die.read_value() if float(_rest.get(die, 0.0)) >= SETTLE_HOLD else -1)
	if values != _last_values:
		_last_values = values
		results_changed.emit(values)


## Holding a finger still on a die lets the owner offer what to do with it.
func _check_long_press(delta: float) -> void:
	if _grabbed == null or not _grab_offers_menu or _grab_travel >= TAP_DISTANCE:
		return
	_grab_time += delta
	if _grab_time >= LONG_PRESS_SECONDS:
		var held := _grabbed
		_grabbed = null
		die_held.emit(held, _grab_view)


func _drag_grabbed_die() -> void:
	if _grabbed == null:
		return
	if not is_instance_valid(_grabbed) or not dice.has(_grabbed):
		_grabbed = null
		return
	if _grabbed.locked:
		return
	# A finger that has only come down, and not yet moved, does not push the die about.
	if _grab_travel < TAP_DISTANCE:
		return
	var point := _grabbed.to_global(_grab_local_point)
	var offset := point - _grabbed.global_position
	var error := _grab_target - point
	error.y = 0.0
	var point_velocity := _grabbed.linear_velocity + _grabbed.angular_velocity.cross(offset)
	point_velocity.y = 0.0
	var pull := (error * GRAB_STIFFNESS - point_velocity * GRAB_DAMPING).limit_length(GRAB_MAX_FORCE)
	_grabbed.sleeping = false
	_grabbed.apply_force(pull * _grabbed.mass, offset)
	_grabbed.apply_force(Vector3(0, -GRAB_PRESS_FORCE, 0) * _grabbed.mass, offset)


func _random_spin(strength: float) -> Vector3:
	return Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength


func _build_environment() -> void:
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_WIDTH
	add_child(camera)
	camera.look_at_from_position(Vector3(0, CAMERA_HEIGHT, 0), Vector3.ZERO, Vector3(0, 0, -1))
	camera.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70, 20, 0)
	light.shadow_enabled = true
	add_child(light)

	var environment := Environment.new()
	# The table has no backdrop of its own: the page shows through, and only the shadows
	# of the dice are drawn on it.
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _rebuild_bounds() -> void:
	if _bounds != null:
		_bounds.queue_free()
	_bounds = Node3D.new()
	add_child(_bounds)

	var half := _half_extents
	var body := StaticBody3D.new()
	var friction := PhysicsMaterial.new()
	friction.friction = 1.2
	friction.bounce = 0.2
	body.physics_material_override = friction
	_bounds.add_child(body)
	_add_box(body, Vector3(half.x * 2.0 + 8.0, 1.0, half.y * 2.0 + 8.0), Vector3(0, -0.5, 0))
	_add_box(body, Vector3(WALL_THICKNESS, CEILING_HEIGHT, half.y * 2.0 + 8.0), Vector3(-half.x - WALL_THICKNESS / 2.0, CEILING_HEIGHT / 2.0, 0))
	_add_box(body, Vector3(WALL_THICKNESS, CEILING_HEIGHT, half.y * 2.0 + 8.0), Vector3(half.x + WALL_THICKNESS / 2.0, CEILING_HEIGHT / 2.0, 0))
	_add_box(body, Vector3(half.x * 2.0 + 8.0, CEILING_HEIGHT, WALL_THICKNESS), Vector3(0, CEILING_HEIGHT / 2.0, -half.y - WALL_THICKNESS / 2.0))
	_add_box(body, Vector3(half.x * 2.0 + 8.0, CEILING_HEIGHT, WALL_THICKNESS), Vector3(0, CEILING_HEIGHT / 2.0, half.y + WALL_THICKNESS / 2.0))
	_add_box(body, Vector3(half.x * 2.0 + 8.0, 1.0, half.y * 2.0 + 8.0), Vector3(0, CEILING_HEIGHT + 0.5, 0))

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(half.x * 2.0 + 8.0, half.y * 2.0 + 8.0)
	floor_mesh.mesh = plane
	var floor_material := ShaderMaterial.new()
	floor_material.shader = _shadow_shader()
	floor_mesh.material_override = floor_material
	_bounds.add_child(floor_mesh)



## A floor that is invisible except for the shadows falling on it.
static func _shadow_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, shadow_to_opacity;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.16;
}
"""
	return shader


func _add_box(body: StaticBody3D, box_size: Vector3, box_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	collision.shape = box
	collision.position = box_position
	body.add_child(collision)
