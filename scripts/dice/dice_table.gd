class_name DiceTable
extends Node3D
## The 3D table: a fixed near top-down camera over a walled floor. Gravity
## follows the device tilt, a shake tosses the dice, and a roll is decided once
## every die has stayed at rest for a short hold time. Real physics decides.

## Values are aligned with `dice`. -1 means undecided (moving or cocked).
signal results_changed(values: Array)

const GRAVITY := 15.0
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
const TAP_DISTANCE := 0.4
const LONG_PRESS_SECONDS := 0.5
const RELEASE_MAX_SPEED := 10.0
const RELEASE_SPEED_KEPT := 1.3
const SHAKE_COOLDOWN := 0.5
const CAMERA_HEIGHT := 14.0
const FIELD_OF_VIEW := 40.0
const WALL_THICKNESS := 2.0
## The screen glass: dice stay inside a shallow box, as on a real device.
const CEILING_HEIGHT := 3.2

var dice: Array[Die] = []

var _half_extents := Vector2(5.0, 9.0)
var _gravity_direction := Vector3.DOWN
var _settle_time := 0.0
var _settled := true
var _last_values: Array = []
var _shake_cooldown := 0.0
var _accel_baseline := Vector3.ZERO
var _grabbed: Die
var _grab_local_point := Vector3.ZERO
var _grab_target := Vector3.ZERO
var _grab_height := 0.0
var _grab_travel := 0.0
var _grab_time := 0.0
var _bounds: Node3D


func _ready() -> void:
	_build_environment()
	_rebuild_bounds()


## Fits the walls to the visible floor. Call whenever the view is resized.
func set_view_aspect(aspect: float) -> void:
	var half_width := CAMERA_HEIGHT * tan(deg_to_rad(FIELD_OF_VIEW / 2.0)) * 0.9
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
		minf(1.6 + dice.size() * 0.15, CEILING_HEIGHT - 1.2),
		randf_range(-_half_extents.y, _half_extents.y) * 0.6)
	die.basis = Basis(Quaternion(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf() * TAU))
	die.linear_velocity = Vector3(0, -2.0, 0)
	die.angular_velocity = _random_spin(8.0)
	dice.append(die)
	_settled = false
	_settle_time = 0.0
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
func remove_die(die: Die) -> void:
	for doomed in [die, die.partner]:
		if doomed != null:
			dice.erase(doomed)
			doomed.queue_free()
	_emit_results()


## Throws every unlocked die again. Locked dice stay where they are.
func roll_all() -> void:
	for die in dice:
		if die.locked:
			continue
		die.sleeping = false
		var heading := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		die.linear_velocity = heading * randf_range(5.0, 9.0) + Vector3.UP * randf_range(2.5, 5.0)
		die.angular_velocity = _random_spin(20.0)
	_settled = false
	_settle_time = 0.0
	_emit_results()


## Puts a finger down on the die under a point of the view. Returns true on a
## hit. The die then follows the finger until `end_touch`.
func begin_touch(view_position: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(view_position)
	var to := from + camera.project_ray_normal(view_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to, Die.DICE_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit["collider"] is Die:
		return false
	_grabbed = hit["collider"]
	_grabbed.sleeping = false
	_grab_local_point = _grabbed.to_local(hit["position"])
	_grab_height = hit["position"].y
	_grab_target = hit["position"]
	_grab_travel = 0.0
	_grab_time = 0.0
	return true


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
	_apply_gravity()
	_check_long_press(delta)
	_drag_grabbed_die()
	_recover_lost_dice()
	_update_gravity()
	_check_shake(delta)
	_check_settled(delta)


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
			_settled = false
			_settle_time = 0.0
			if die.locked:
				die.rewrap_chain()


func _apply_gravity() -> void:
	for die in dice:
		if not die.locked:
			die.apply_central_force(_gravity_direction * GRAVITY * die.mass)


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


func _check_settled(delta: float) -> void:
	if dice.is_empty():
		return
	var moving := false
	for die in dice:
		if not die.is_at_rest():
			moving = true
			break
	if moving:
		_settle_time = 0.0
		if _settled:
			_settled = false
			_emit_results()
		return
	_settle_time += delta
	if not _settled and _settle_time >= SETTLE_HOLD:
		_settled = true
		_emit_results()


func _emit_results() -> void:
	var values: Array = []
	for die in dice:
		values.append(die.read_value() if _settled else -1)
	if values != _last_values:
		_last_values = values
		results_changed.emit(values)


## Holding a finger still on a die locks it, or unlocks it if it is locked.
func _check_long_press(delta: float) -> void:
	if _grabbed == null or _grab_travel >= TAP_DISTANCE:
		return
	_grab_time += delta
	if _grab_time >= LONG_PRESS_SECONDS:
		if _grabbed.locked:
			_grabbed.set_locked(false)
		else:
			_grabbed.try_lock()
		_grabbed = null
		_settled = false
		_settle_time = 0.0


func _drag_grabbed_die() -> void:
	if _grabbed == null:
		return
	if not is_instance_valid(_grabbed) or not dice.has(_grabbed):
		_grabbed = null
		return
	if _grabbed.locked:
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
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = FIELD_OF_VIEW
	add_child(camera)
	camera.look_at_from_position(Vector3(0, CAMERA_HEIGHT, 0), Vector3.ZERO, Vector3(0, 0, -1))
	camera.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70, 20, 0)
	light.shadow_enabled = true
	add_child(light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.WHITE
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
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#F3F3F6")
	floor_material.roughness = 1.0
	floor_mesh.material_override = floor_material
	_bounds.add_child(floor_mesh)



func _add_box(body: StaticBody3D, box_size: Vector3, box_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	collision.shape = box
	collision.position = box_position
	body.add_child(collision)
