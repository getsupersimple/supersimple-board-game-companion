class_name Die
extends RigidBody3D
## One physical die. The result is whichever face points up once it has
## settled. A die that is not lying flat has no result. The coin (d2) is a
## disc, and the d4 is read from its top vertex.

## A knock against the table, a wall, or another die. `strength` is roughly the
## speed of the knock in table units per second.
signal impact(strength: float)
## A locked die was let go, by whatever means.
signal unlocked

## How numerals are printed. Percentile dice are two d10s read together.
enum NumeralStyle { NORMAL, TENS, UNITS }

## Minimum alignment (cosine) between the reading direction and up.
const FLAT_DOT := 0.95
const REST_LINEAR_SPEED := 0.15
const REST_ANGULAR_SPEED := 0.3
const NUMERAL_SIZE := 128
const NUMERAL_OUTLINE := 10
const COIN_RADIUS := 0.9
const COIN_THICKNESS := 0.16
## Dice live on their own layer so touches can pick them without hitting the walls.
const DICE_LAYER := 2
const TABLE_TOP := 0.0
## The padlock that marks a locked die: how big it is drawn and how far above the die it floats.
const PADLOCK_SIZE := 0.9
const PADLOCK_LIFT := 0.25
## How far out to the side of the die, as a share of its reach, the padlock sits.
const PADLOCK_SIDE := 0.55
const FLATTEN_SECONDS := 0.25
const IMPACT_MIN_SPEED := 1.2
const IMPACT_COOLDOWN := 0.05
const FLAT_CLEARANCE := 0.96
const HELD_DAMPING := 6.0
const FREE_LINEAR_DAMPING := 0.15
const FREE_ANGULAR_DAMPING := 0.1
## The white rim is the die drawn this much bigger; 
const RIM_SCALE := 1.06

var sides := 0
var die_color := Color.WHITE
var numeral_style := NumeralStyle.NORMAL
## The other half of a percentile pair. Set on both dice.
var partner: Die
var shape_data: DieShape
## A locked die is held in place, marked with a padlock on top: it ignores gravity,
## shakes and rolls, but other dice still bump into it.
var locked := false
var _padlock: Node3D
static var _bold_cache: Font
var _surface: StandardMaterial3D
## Pulled hard down onto the table; see `hold`.
var heavy := false
var _numerals: Array[Label3D] = []
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0



static func is_supported(side_count: int) -> bool:
	return side_count == 2 or DieShape.is_supported(side_count)


func setup(side_count: int, color: Color, style: NumeralStyle = NumeralStyle.NORMAL) -> void:
	sides = side_count
	die_color = color
	numeral_style = style

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	collision_layer = DICE_LAYER
	collision_mask = DICE_LAYER | 1
	mass = 1.0
	# The table applies gravity itself, so it can point in any direction.
	gravity_scale = 0.0
	continuous_cd = true
	linear_damp = FREE_LINEAR_DAMPING
	angular_damp = FREE_ANGULAR_DAMPING
	var material := PhysicsMaterial.new()
	material.friction = 1.2
	material.bounce = 0.25
	physics_material_override = material

	_surface = StandardMaterial3D.new()
	_surface.roughness = 0.4
	_surface.metallic_specular = 0.5
	_surface.rim_enabled = true
	_surface.rim = 0.2
	_surface.rim_tint = 0.6
	_surface.emission_enabled = true
	_apply_color(color)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.material_override = _surface
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	add_child(collision)

	if sides == 2:
		_setup_coin(mesh_instance, collision)
		_add_look(mesh_instance)
		return
	shape_data = DieShape.create(side_count)
	mesh_instance.mesh = shape_data.build_mesh()
	var convex := ConvexPolygonShape3D.new()
	convex.points = shape_data.vertices
	collision.shape = convex
	_add_look(mesh_instance)
	var text_color := Color.WHITE
	if shape_data.reads_vertex:
		for face in shape_data.faces:
			for vertex_id in face.vertex_indices:
				add_child(_make_vertex_numeral(face, vertex_id, text_color))
	else:
		for face in shape_data.faces:
			add_child(_make_face_numeral(face, text_color))


## Weighs the die down while a finger is on it and a drawer is open: it stops where it is
## sideways, is pulled hard down onto the table, and is damped so it settles at once. The
## table does the pulling (see DiceTable). `hold(false)` lets it go.
func hold(on: bool) -> void:
	heavy = on
	if on:
		linear_velocity = Vector3(0, minf(linear_velocity.y, 0.0), 0)
		angular_velocity = Vector3.ZERO
		linear_damp = HELD_DAMPING
		angular_damp = HELD_DAMPING
	else:
		linear_damp = FREE_LINEAR_DAMPING
		angular_damp = FREE_ANGULAR_DAMPING
	sleeping = false


## Holds the die rigidly where it lies, or lets it go again. A locked die stays frozen either way.
func pin(on: bool) -> void:
	if on:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = on or locked
	sleeping = false


## Paints the die another colour, numerals and all.
func set_color(color: Color) -> void:
	die_color = color
	_apply_color(color)


## Gives the material and the numerals the die's colour: a glossy gem that glows a little.
func _apply_color(color: Color) -> void:
	_surface.albedo_color = color.darkened(0.1)
	_surface.emission = color
	_surface.emission_energy_multiplier = 0.0
	for numeral in _numerals:
		numeral.outline_modulate = color.darkened(0.55)


## The pale rim around the die: the die drawn again slightly larger, inside out, in white.
func _add_look(mesh_instance: MeshInstance3D) -> void:
	var rim := MeshInstance3D.new()
	rim.mesh = mesh_instance.mesh
	rim.scale = Vector3.ONE * RIM_SCALE
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.cull_mode = BaseMaterial3D.CULL_FRONT
	white.albedo_color = Color(1, 1, 1, 0.95)
	rim.material_override = white
	add_child(rim)
	for numeral in _numerals:
		numeral.outline_modulate = die_color.darkened(0.55)


static func _bold_font() -> Font:
	if _bold_cache == null:
		var bold := FontVariation.new()
		bold.base_font = ThemeDB.fallback_font
		bold.variation_embolden = 0.9
		_bold_cache = bold
	return _bold_cache


## Locks the die if it can lie flat on the table, and says whether it did. A die
## lying on top of another, or wedged where turning it flat would push it into
## something, cannot be locked, so it can never hold a neighbour in place.
func try_lock() -> bool:
	if can_lie_flat():
		set_locked(true)
		return true
	_refuse_lock()
	return false


## Whether the die's flat position on the table is free of other dice,
## and walls. A die that is already flat and clear is its own flat position.
func can_lie_flat() -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _collision_shape().shape
	# Slightly smaller, so touching a neighbour or the table does not count.
	var target := flat_transform()
	query.transform = Transform3D(target.basis.scaled(Vector3.ONE * FLAT_CLEARANCE), target.origin)
	query.collision_mask = DICE_LAYER | 1
	query.exclude = [get_rid()]
	if partner != null:
		query.exclude.append(partner.get_rid())
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## A short buzz and a quick pulse of the die, to say it cannot be locked here.
func _refuse_lock() -> void:
	Haptics.pulse(60)
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child
			create_tween().tween_property(mesh_node, "scale", Vector3.ONE * 1.12, 0.08)
			create_tween().tween_property(mesh_node, "scale", Vector3.ONE, 0.12).set_delay(0.08)
			break


func _collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null


func set_locked(is_locked: bool) -> void:
	var was_locked := locked
	locked = is_locked
	if locked:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = locked
	sleeping = false
	if was_locked and not locked:
		unlocked.emit()
	if is_inside_tree():
		if locked:
			if read_value() == -1:
				_settle_flat_then_wrap()
			else:
				_add_padlock()
		elif _padlock != null:
			_padlock.queue_free()
			_padlock = null
			if was_locked:
				ChainFeedback.unlocked(self)


## A die can only be locked lying flat: one that is leaning, or resting on a
## corner or an edge, is turned to its nearest flat position first.
func _settle_flat_then_wrap() -> void:
	var target := flat_transform()
	var from := global_transform
	var tween := create_tween()
	tween.tween_method(func(weight: float) -> void: global_transform = from.interpolate_with(target, weight), 0.0, 1.0, FLATTEN_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_add_padlock)


## Where the die would lie if turned to its nearest flat position, on the table
## directly under where it is now.
func flat_transform() -> Transform3D:
	var current := global_transform.basis.orthonormalized()
	var turn := Basis.IDENTITY
	var rest_height := COIN_THICKNESS / 2.0
	if sides == 2:
		var face_up := Vector3.UP if (current * Vector3.UP).y >= 0.0 else Vector3.DOWN
		turn = Basis(Quaternion(current * face_up, Vector3.UP))
	elif shape_data.reads_vertex:
		var top := 0
		for i in shape_data.vertices.size():
			if (current * shape_data.vertices[i]).y > (current * shape_data.vertices[top]).y:
				top = i
		turn = Basis(Quaternion((current * shape_data.vertices[top]).normalized(), Vector3.UP))
		rest_height = shape_data.faces[0].center.dot(shape_data.faces[0].normal)
	else:
		var best: DieShape.Face = shape_data.faces[0]
		for face in shape_data.faces:
			if (current * face.normal).y > (current * best.normal).y:
				best = face
		turn = Basis(Quaternion(current * best.normal, Vector3.UP))
		rest_height = best.center.dot(best.normal)
	return Transform3D(turn * current, Vector3(global_position.x, TABLE_TOP + rest_height, global_position.z))


func _highest_point() -> float:
	if sides == 2:
		return global_position.y + COIN_RADIUS * absf(sin(acos(clampf((global_transform.basis * Vector3.UP).y, -1.0, 1.0)))) + COIN_THICKNESS / 2.0
	var top := -INF
	for vertex in shape_data.vertices:
		top = maxf(top, (global_transform * vertex).y)
	return top


## Roughly how far the die reaches sideways from its centre.
func reach() -> float:
	return sqrt(COIN_RADIUS * COIN_RADIUS + COIN_THICKNESS * COIN_THICKNESS / 4.0) if sides == 2 else _circumradius()


## Puts the padlock back on top, for when a locked die has been moved.
func move_padlock() -> void:
	if locked and is_inside_tree():
		_add_padlock(false)


## A gold padlock badge, floating up and to the right of the die and always facing the
## camera, the way a locked die is drawn in the app's artwork.
func _add_padlock(with_feedback: bool = true) -> void:
	if _padlock != null:
		_padlock.queue_free()
	_padlock = Node3D.new()
	_padlock.top_level = true
	add_child(_padlock)
	var side := reach() * PADLOCK_SIDE
	_padlock.global_position = Vector3(global_position.x + side, _highest_point() + PADLOCK_LIFT, global_position.z - side)
	var texture := load("res://assets/icons/padlock.svg") as Texture2D
	var icon := Sprite3D.new()
	icon.texture = texture
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.shaded = false
	icon.pixel_size = PADLOCK_SIZE / texture.get_width()
	icon.render_priority = 10
	_padlock.add_child(icon)
	_padlock.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_padlock, "scale", Vector3.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if with_feedback:
		ChainFeedback.locked(self)


## The result, or -1 when the die is not lying flat.
func read_value() -> int:
	if sides == 2:
		return _read_coin()
	if shape_data.reads_vertex:
		return _read_top_vertex()
	return _read_top_face()


func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	_last_velocity = linear_velocity


func _on_body_entered(other: Node) -> void:
	if _impact_cooldown > 0.0:
		return
	var speed := _last_velocity.length()
	if other is Die:
		speed = (_last_velocity - other._last_velocity).length()
	if speed < IMPACT_MIN_SPEED:
		return
	_impact_cooldown = IMPACT_COOLDOWN
	impact.emit(speed)


## Barely moving at all, a good deal stricter than at rest: slow enough that it is not about to topple.
func is_still() -> bool:
	return linear_velocity.length() < REST_LINEAR_SPEED * 0.3 and angular_velocity.length() < REST_ANGULAR_SPEED * 0.3


func is_at_rest() -> bool:
	return linear_velocity.length() < REST_LINEAR_SPEED and angular_velocity.length() < REST_ANGULAR_SPEED


func _circumradius() -> float:
	var longest := 0.0
	for vertex in shape_data.vertices:
		longest = maxf(longest, vertex.length())
	return longest


func _read_top_face() -> int:
	var best_dot := -INF
	var best_value := -1
	for face in shape_data.faces:
		var dot := (global_transform.basis * face.normal).dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_value = face.value
	return best_value if best_dot >= FLAT_DOT else -1


func _read_top_vertex() -> int:
	var best_dot := -INF
	var best_value := -1
	for i in shape_data.vertices.size():
		var dot := (global_transform.basis * shape_data.vertices[i]).normalized().dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_value = shape_data.vertex_values[i]
	return best_value if best_dot >= FLAT_DOT else -1


## Heads reads 1 and tails reads 2. A coin on its edge has no result.
func _read_coin() -> int:
	var dot := (global_transform.basis * Vector3.UP).dot(Vector3.UP)
	if dot >= FLAT_DOT:
		return 1
	if dot <= -FLAT_DOT:
		return 2
	return -1


func _setup_coin(mesh_instance: MeshInstance3D, collision: CollisionShape3D) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = COIN_RADIUS
	disc.bottom_radius = COIN_RADIUS
	disc.height = COIN_THICKNESS
	disc.radial_segments = 48
	disc.rings = 1
	mesh_instance.mesh = disc
	var cylinder := CylinderShape3D.new()
	cylinder.radius = COIN_RADIUS
	cylinder.height = COIN_THICKNESS
	collision.shape = cylinder
	var text_color := Color.WHITE
	for face_up in [true, false]:
		var label := _make_label("1" if face_up else "2", COIN_RADIUS * 0.9, text_color)
		var normal := Vector3.UP if face_up else Vector3.DOWN
		var up := Vector3(0, 0, -1)
		label.transform = Transform3D(Basis(up.cross(normal), up, normal), normal * (COIN_THICKNESS / 2.0 + 0.004))
		add_child(label)


func _make_face_numeral(face: DieShape.Face, text_color: Color) -> Label3D:
	var text := _numeral_text(face.value)
	# Fit two-digit numerals on small faces.
	var label := _make_label(text, face.inradius * (1.5 if text.length() == 1 else 1.05), text_color)
	var up := (shape_data.vertices[face.vertex_indices[0]] - face.center).normalized()
	label.transform = Transform3D(Basis(up.cross(face.normal), up, face.normal), face.center + face.normal * 0.004)
	return label


## A d4 prints the number of each corner next to that corner, pointing at it.
func _make_vertex_numeral(face: DieShape.Face, vertex_id: int, text_color: Color) -> Label3D:
	var label := _make_label(str(shape_data.vertex_values[vertex_id]), face.inradius * 0.45, text_color)
	var corner := shape_data.vertices[vertex_id]
	var up := (corner - face.center).normalized()
	var position := face.center.lerp(corner, 0.55) + face.normal * 0.004
	label.transform = Transform3D(Basis(up.cross(face.normal), up, face.normal), position)
	return label


func _make_label(text: String, text_height: float, text_color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = NUMERAL_SIZE
	label.pixel_size = text_height / NUMERAL_SIZE
	label.modulate = text_color
	label.font = _bold_font()
	label.outline_size = NUMERAL_OUTLINE
	label.outline_modulate = die_color.darkened(0.55)
	label.double_sided = false
	_numerals.append(label)
	return label


func _numeral_text(value: int) -> String:
	match numeral_style:
		NumeralStyle.TENS:
			return "%02d" % ((value % 10) * 10)
		NumeralStyle.UNITS:
			return str(value % 10)
	# Underline-style dot so 6 and 9 can be told apart.
	return "%d." % value if value in [6, 9] and sides > 6 else str(value)
