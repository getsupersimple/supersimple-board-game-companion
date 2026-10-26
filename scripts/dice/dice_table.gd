class_name DiceTable
extends Node3D
## The 3D table: a fixed near top-down camera over a walled floor. Gravity
## follows the device tilt, a shake tosses the dice, and a roll is decided once
## every die has stayed at rest for a short hold time. Real physics decides.

## Values are aligned with `dice`. -1 means undecided (moving or cocked).
signal results_changed(values: Array)

const GRAVITY := 30.0
const MIN_DOWNWARD := 0.35
const GRAVITY_SMOOTHING := 0.15
const SETTLE_HOLD := 0.3
const SHAKE_THRESHOLD := 14.0
const SHAKE_COOLDOWN := 0.5
const CAMERA_HEIGHT := 14.0
const FIELD_OF_VIEW := 40.0
const WALL_THICKNESS := 2.0
const CEILING_HEIGHT := 9.0

var dice: Array[Die] = []

var _half_extents := Vector2(5.0, 9.0)
var _gravity_direction := Vector3.DOWN
var _settle_time := 0.0
var _settled := true
var _last_values: Array = []
var _shake_cooldown := 0.0
var _bounds: Node3D
var _gravity_area: Area3D
var _gravity_shape: CollisionShape3D


func _ready() -> void:
	_build_environment()
	_build_gravity_area()
	_rebuild_bounds()


## Fits the walls to the visible floor. Call whenever the view is resized.
func set_view_aspect(aspect: float) -> void:
	var half_width := CAMERA_HEIGHT * tan(deg_to_rad(FIELD_OF_VIEW / 2.0)) * 0.96
	_half_extents = Vector2(half_width, half_width / aspect)
	if is_inside_tree():
		_rebuild_bounds()


## Drops a new die from above. Existing dice stay where they are.
func add_die(side_count: int, color: Color) -> Die:
	var die := Die.new()
	die.setup(side_count, color)
	add_child(die)
	die.position = Vector3(
		randf_range(-_half_extents.x, _half_extents.x) * 0.6,
		3.0 + dice.size() * 0.6,
		randf_range(-_half_extents.y, _half_extents.y) * 0.6)
	die.basis = Basis(Quaternion(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf() * TAU))
	die.linear_velocity = Vector3(0, -2.0, 0)
	die.angular_velocity = _random_spin(8.0)
	die.input_event.connect(_on_die_input.bind(die))
	dice.append(die)
	_settled = false
	_settle_time = 0.0
	_emit_results()
	return die


func remove_die(die: Die) -> void:
	dice.erase(die)
	die.queue_free()
	_emit_results()


## Throws every die again.
func roll_all() -> void:
	for die in dice:
		die.sleeping = false
		var heading := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		die.linear_velocity = heading * randf_range(5.0, 9.0) + Vector3.UP * randf_range(6.0, 10.0)
		die.angular_velocity = _random_spin(20.0)
	_settled = false
	_settle_time = 0.0
	_emit_results()


## A gentle push to one die, which may knock into its neighbours.
func nudge(die: Die) -> void:
	die.sleeping = false
	die.apply_central_impulse(Vector3(randf_range(-1, 1) * 2.0, 3.0, randf_range(-1, 1) * 2.0))
	die.apply_torque_impulse(_random_spin(1.5))


func _physics_process(delta: float) -> void:
	_update_gravity()
	_check_shake(delta)
	_check_settled(delta)


func _update_gravity() -> void:
	var sensor := Input.get_gravity()
	if sensor.length() < 1.0:
		return
	# Device axes to table axes: screen right is +x, screen up is -z, out of the
	# screen is +y. The vertical part always points down so dice stay on the floor.
	var target := Vector3(sensor.x, -absf(sensor.z), -sensor.y).normalized()
	target.y = minf(target.y, -MIN_DOWNWARD)
	_gravity_direction = _gravity_direction.lerp(target.normalized(), GRAVITY_SMOOTHING).normalized()
	_gravity_area.gravity_direction = _gravity_direction


func _check_shake(delta: float) -> void:
	_shake_cooldown = maxf(0.0, _shake_cooldown - delta)
	var accel := Input.get_accelerometer()
	if accel.length() == 0.0 or _shake_cooldown > 0.0:
		return
	if (accel - Input.get_gravity()).length() > SHAKE_THRESHOLD:
		_shake_cooldown = SHAKE_COOLDOWN
		for die in dice:
			die.sleeping = false
			die.apply_central_impulse(Vector3(randf_range(-1, 1) * 3.0, randf_range(2.0, 5.0), randf_range(-1, 1) * 3.0))
			die.apply_torque_impulse(_random_spin(2.0))


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


func _on_die_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int, die: Die) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		nudge(die)


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


func _build_gravity_area() -> void:
	_gravity_area = Area3D.new()
	_gravity_area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	_gravity_area.gravity_direction = Vector3.DOWN
	_gravity_area.gravity = GRAVITY
	_gravity_shape = CollisionShape3D.new()
	_gravity_shape.shape = BoxShape3D.new()
	_gravity_area.add_child(_gravity_shape)
	add_child(_gravity_area)


func _rebuild_bounds() -> void:
	if _bounds != null:
		_bounds.queue_free()
	_bounds = Node3D.new()
	add_child(_bounds)

	var half := _half_extents
	var body := StaticBody3D.new()
	var friction := PhysicsMaterial.new()
	friction.friction = 0.8
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

	(_gravity_shape.shape as BoxShape3D).size = Vector3(half.x * 2.0 + 8.0, CEILING_HEIGHT + 2.0, half.y * 2.0 + 8.0)
	_gravity_area.position = Vector3(0, CEILING_HEIGHT / 2.0, 0)


func _add_box(body: StaticBody3D, box_size: Vector3, box_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	collision.shape = box
	collision.position = box_position
	body.add_child(collision)
