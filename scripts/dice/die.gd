class_name Die
extends RigidBody3D
## One physical die. The result is whichever face points up once it has
## settled. A die that is not lying flat has no result. The coin (d2) is a
## disc, and the d4 is read from its top vertex.

## How numerals are printed. Percentile dice are two d10s read together.
enum NumeralStyle { NORMAL, TENS, UNITS }

## Minimum alignment (cosine) between the reading direction and up.
const FLAT_DOT := 0.95
const REST_LINEAR_SPEED := 0.15
const REST_ANGULAR_SPEED := 0.3
const NUMERAL_SIZE := 128
const COIN_RADIUS := 0.9
const COIN_THICKNESS := 0.16
## Dice live on their own layer so touches can pick them without hitting the walls.
const DICE_LAYER := 2
## The locking chains: two crossed chains pulled taut over the die and bolted to
## plates on the table, so the die cannot move.
const CHAIN_LINK_SPACING := 0.27
const CHAIN_LINK_RADIUS := 0.15
const CHAIN_SAMPLES := 64
const CHAIN_PLATE_GAP := 0.4
const CHAIN_END_HEIGHT := 0.24
const CHAIN_CROSSING_LIFT := 0.17
const TABLE_TOP := 0.0
const FLATTEN_SECONDS := 0.25
const CHAIN_HALF_WIDTH := 0.22
const CHAIN_BAR_HEIGHT := 0.32
const PLATE_HALF_SIZE := 0.375
const PLATE_HEIGHT := 0.25
## How hard things in the way are shoved when a chain appears.
const CLEARING_PUSH := 7.0
const SCORE_FONT_SIZE := 96
const SCORE_HEIGHT := 0.8
const SCORE_OUTLINE := 28
const SCORE_LIFT := 0.35

var sides := 0
var die_color := Color.WHITE
var numeral_style := NumeralStyle.NORMAL
## The other half of a percentile pair. Set on both dice.
var partner: Die
var shape_data: DieShape
## A locked die is held in place by a chain across it: it ignores gravity,
## shakes and rolls, but other dice still bump into it.
var locked := false
var _chain: Node3D
var _chain_material: StandardMaterial3D
var _chain_link_mesh: TorusMesh
var _chain_body: StaticBody3D
## Where the chain lies on the table: [from, to, half width] in world space.
var _chain_footprints: Array = []


static func is_supported(side_count: int) -> bool:
	return side_count == 2 or DieShape.is_supported(side_count)


func setup(side_count: int, color: Color, style: NumeralStyle = NumeralStyle.NORMAL) -> void:
	sides = side_count
	die_color = color
	numeral_style = style

	collision_layer = DICE_LAYER
	collision_mask = DICE_LAYER | 1
	mass = 1.0
	# The table applies gravity itself, so it can point in any direction.
	gravity_scale = 0.0
	continuous_cd = true
	linear_damp = 0.15
	angular_damp = 0.1
	var material := PhysicsMaterial.new()
	material.friction = 1.2
	material.bounce = 0.25
	physics_material_override = material

	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.45
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.material_override = surface
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	add_child(collision)

	if sides == 2:
		_setup_coin(mesh_instance, collision)
		return
	shape_data = DieShape.create(side_count)
	mesh_instance.mesh = shape_data.build_mesh()
	var convex := ConvexPolygonShape3D.new()
	convex.points = shape_data.vertices
	collision.shape = convex
	var text_color := ColorUtils.contrast_color(color)
	if shape_data.reads_vertex:
		for face in shape_data.faces:
			for vertex_id in face.vertex_indices:
				add_child(_make_vertex_numeral(face, vertex_id, text_color))
	else:
		for face in shape_data.faces:
			add_child(_make_face_numeral(face, text_color))


func set_locked(is_locked: bool) -> void:
	locked = is_locked
	if locked:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = locked
	sleeping = false
	if is_inside_tree():
		if locked:
			if read_value() == -1:
				_settle_flat_then_wrap()
			else:
				_wrap_chain()
		elif _chain != null:
			_chain.queue_free()
			_chain = null


## A die can only be locked lying flat: one that is leaning, or resting on a
## corner or an edge, is turned to its nearest flat position first.
func _settle_flat_then_wrap() -> void:
	var target := flat_transform()
	var from := global_transform
	var tween := create_tween()
	tween.tween_method(func(weight: float) -> void: global_transform = from.interpolate_with(target, weight), 0.0, 1.0, FLATTEN_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_wrap_chain)


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


## The die's number, floating over the chains so the score can be read even
## though the chain covers the face. It always turns to face the camera.
func _add_score_label() -> void:
	var label := Label3D.new()
	label.name = "ScoreLabel"
	label.text = score_text()
	label.font_size = SCORE_FONT_SIZE
	label.pixel_size = SCORE_HEIGHT / SCORE_FONT_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = 10
	label.outline_render_priority = 9
	label.modulate = Color.WHITE
	label.outline_modulate = Color("#1C1C1E")
	label.outline_size = SCORE_OUTLINE
	label.position = Vector3(global_position.x, _highest_point() + CHAIN_LINK_RADIUS * 2.0 + SCORE_LIFT, global_position.z)
	label.scale = Vector3.ONE * 0.01
	_chain.add_child(label)
	create_tween().tween_property(label, "scale", Vector3.ONE, 0.2) \
			.set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## What the number on top of the die says, as the score reads it.
func score_text() -> String:
	var value := read_value()
	if value < 0:
		return ""
	match numeral_style:
		NumeralStyle.TENS:
			return "%02d" % ((value % 10) * 10)
		NumeralStyle.UNITS:
			return str(value % 10)
	return str(value)


func _highest_point() -> float:
	if sides == 2:
		return global_position.y + COIN_RADIUS * absf(sin(acos(clampf((global_transform.basis * Vector3.UP).y, -1.0, 1.0)))) + COIN_THICKNESS / 2.0
	var top := -INF
	for vertex in shape_data.vertices:
		top = maxf(top, (global_transform * vertex).y)
	return top


## Shoves other dice out of the way of a chain that has just appeared. They are
## pushed sideways, away from whatever part of the chain they overlap.
func _clear_surroundings() -> void:
	if get_parent() == null:
		return
	for other in get_parent().get_children():
		if not other is Die or other == self or other.locked:
			continue
		var reach := _chain_overlap(other.global_position, other.reach())
		if reach == Vector3.ZERO:
			continue
		other.sleeping = false
		other.apply_central_impulse(reach.normalized() * minf(reach.length() * CLEARING_PUSH + 2.0, 12.0) + Vector3(0, 1.5, 0))


## How far a circle on the table sticks into the chain, as a vector pointing out
## of it, or zero when it is clear.
func _chain_overlap(at: Vector3, radius: float) -> Vector3:
	var flat := Vector3(at.x, 0, at.z)
	for footprint in _chain_footprints:
		var closest := Geometry3D.get_closest_point_to_segment(flat, footprint[0], footprint[1])
		var gap := flat.distance_to(closest)
		var needed: float = footprint[2] + radius
		if gap < needed:
			var away := (flat - closest)
			if away.length() < 0.001:
				away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			return away.normalized() * (needed - gap)
	return Vector3.ZERO


## Roughly how far the die reaches sideways from its centre.
func reach() -> float:
	return sqrt(COIN_RADIUS * COIN_RADIUS + COIN_THICKNESS * COIN_THICKNESS / 4.0) if sides == 2 else _circumradius()


## Lays the chain again, for when a locked die has been moved.
func rewrap_chain() -> void:
	if locked and is_inside_tree():
		_wrap_chain()


## The result, or -1 when the die is not lying flat.
func read_value() -> int:
	if sides == 2:
		return _read_coin()
	if shape_data.reads_vertex:
		return _read_top_vertex()
	return _read_top_face()


func is_at_rest() -> bool:
	return linear_velocity.length() < REST_LINEAR_SPEED and angular_velocity.length() < REST_ANGULAR_SPEED


## Crosses two chains over the die and bolts their ends to the table, like
## a cargo strap. Everything is placed in world space, which is fine because a
## locked die does not move.
func _wrap_chain() -> void:
	if _chain != null:
		_chain.queue_free()
	_chain = Node3D.new()
	_chain.top_level = true
	add_child(_chain)
	_chain.global_transform = Transform3D.IDENTITY
	_ensure_chain_resources()
	_chain_body = StaticBody3D.new()
	_chain.add_child(_chain_body)
	_chain_footprints.clear()
	var first_axis := chain_axis()
	var second_axis := first_axis.rotated(Vector3.UP, PI / 2.0)
	# The second strap passes over the first, so it is lifted where they cross.
	_lay_strap(first_axis, _extent_along(first_axis), 0.0, 0)
	_lay_strap(second_axis, _extent_along(second_axis), CHAIN_CROSSING_LIFT, 1)
	_add_score_label()
	_clear_surroundings()


## The direction of the first chain on the table. The chains follow the die: they
## run along the edges of a square face, and along the numeral's up and across
## directions on any other face, so a die that lands turned 45 degrees is crossed
## diagonally. A coin has no orientation, so its chains follow the screen.
func chain_axis() -> Vector3:
	var along := Vector3.ZERO
	if shape_data != null and shape_data.reads_vertex:
		var top := 0
		for i in shape_data.vertices.size():
			if (global_transform.basis * shape_data.vertices[i]).y > (global_transform.basis * shape_data.vertices[top]).y:
				top = i
		var other := 1 if top == 0 else 0
		along = global_transform.basis * (shape_data.vertices[other] - shape_data.vertices[top])
	elif shape_data != null:
		var best: DieShape.Face = shape_data.faces[0]
		for face in shape_data.faces:
			if (global_transform.basis * face.normal).y > (global_transform.basis * best.normal).y:
				best = face
		var ids := best.vertex_indices
		if ids.size() == 4:
			along = global_transform.basis * (shape_data.vertices[ids[1]] - shape_data.vertices[ids[0]])
		else:
			along = global_transform.basis * (shape_data.vertices[ids[0]] - best.center)
	along.y = 0.0
	return along.normalized() if along.length() > 0.2 else Vector3.RIGHT


## How far the die reaches from its centre along a horizontal direction.
func _extent_along(axis: Vector3) -> float:
	if sides == 2:
		return sqrt(COIN_RADIUS * COIN_RADIUS + COIN_THICKNESS * COIN_THICKNESS / 4.0)
	var reach := 0.0
	for vertex in shape_data.vertices:
		reach = maxf(reach, absf((global_transform.basis * vertex).dot(axis)))
	return reach


func _lay_strap(axis: Vector3, reach: float, lift: float, strap_index: int) -> void:
	var centre := global_position
	var half_length := reach + CHAIN_PLATE_GAP
	# The strap runs level across the highest point of the die, whatever its
	# orientation, and slopes straight down to the plates beyond it.
	var covered: Array[bool] = []
	var die_top := -INF
	var first_hit := -1
	var last_hit := -1
	for i in CHAIN_SAMPLES + 1:
		var along := lerpf(-half_length, half_length, float(i) / CHAIN_SAMPLES)
		var top := _surface_top(centre + axis * along)
		covered.append(top > -INF)
		if top > -INF:
			die_top = maxf(die_top, top)
			if first_hit < 0:
				first_hit = i
			last_hit = i
	if first_hit < 0:
		return
	var level := die_top + CHAIN_LINK_RADIUS + lift
	var heights: Array[float] = []
	for i in CHAIN_SAMPLES + 1:
		if i < first_hit:
			heights.append(lerpf(CHAIN_END_HEIGHT, level, float(i) / first_hit))
		elif i > last_hit:
			heights.append(lerpf(level, CHAIN_END_HEIGHT, float(i - last_hit) / (CHAIN_SAMPLES - last_hit)))
		else:
			heights.append(level)
	var points: Array[Vector3] = []
	for i in CHAIN_SAMPLES + 1:
		var along := lerpf(-half_length, half_length, float(i) / CHAIN_SAMPLES)
		var point := centre + axis * along
		point.y = maxf(heights[i], CHAIN_END_HEIGHT)
		points.append(point)

	var total := 0.0
	for i in CHAIN_SAMPLES:
		total += points[i].distance_to(points[i + 1])
	var link_count := maxi(int(round(total / CHAIN_LINK_SPACING)), 6)
	var step := total / link_count
	var walked := 0.0
	var next_link := step / 2.0
	var placed := 0
	for i in CHAIN_SAMPLES:
		var segment := points[i].distance_to(points[i + 1])
		while placed < link_count and next_link <= walked + segment:
			var t := (next_link - walked) / maxf(segment, 0.0001)
			var tangent := (points[i + 1] - points[i]).normalized()
			_add_chain_link(points[i].lerp(points[i + 1], t), tangent, Vector3.UP, placed + strap_index)
			placed += 1
			next_link += step
		walked += segment
	for end in [-1.0, 1.0]:
		_add_anchor_plate(Vector3(centre.x, TABLE_TOP, centre.z) + axis * half_length * end, axis)
	# The chain is solid: three bars, up the slope, across the die and down.
	var keys := [points[0], points[first_hit], points[last_hit], points[CHAIN_SAMPLES]]
	for i in 3:
		_add_collision_bar(keys[i], keys[i + 1])
	_chain_footprints.append([Vector3(centre.x, 0, centre.z) - axis * half_length, Vector3(centre.x, 0, centre.z) + axis * half_length, CHAIN_HALF_WIDTH])


func _ensure_chain_resources() -> void:
	if _chain_material != null:
		return
	_chain_material = StandardMaterial3D.new()
	_chain_material.albedo_color = Color("#5D626C")
	_chain_material.metallic = 0.45
	_chain_material.roughness = 0.3
	_chain_link_mesh = TorusMesh.new()
	_chain_link_mesh.inner_radius = 0.07
	_chain_link_mesh.outer_radius = 0.2
	_chain_link_mesh.rings = 20
	_chain_link_mesh.ring_segments = 10


## One link at a point of the chain. Every other link stands on its edge, as in
## a real chain. The pivot lets the link grow in when the chain appears.
func _add_chain_link(at: Vector3, tangent: Vector3, up: Vector3, index: int) -> void:
	var binormal := tangent.cross(up).normalized()
	var surface_normal := binormal.cross(tangent).normalized()
	var link := MeshInstance3D.new()
	link.mesh = _chain_link_mesh
	link.material_override = _chain_material
	var basis: Basis
	if index % 2 == 0:
		basis = Basis(binormal, surface_normal, binormal.cross(surface_normal))
	else:
		basis = Basis(surface_normal, binormal, surface_normal.cross(binormal))
	link.basis = basis.scaled_local(Vector3(1.0, 1.0, 1.7))
	var pivot := Node3D.new()
	pivot.position = at
	pivot.set_meta("kind", "link")
	pivot.scale = Vector3.ONE * 0.01
	pivot.add_child(link)
	_chain.add_child(pivot)
	create_tween().tween_property(pivot, "scale", Vector3.ONE, 0.15) \
			.set_delay(index * 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A solid bar between two points of a chain, so other dice cannot pass through.
func _add_collision_bar(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CHAIN_HALF_WIDTH * 2.0, CHAIN_BAR_HEIGHT, length)
	collision.shape = box
	collision.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) / 2.0)
	_chain_body.add_child(collision)


## A bolted steel plate with an eyelet for the end of a chain.
func _add_anchor_plate(at: Vector3, axis: Vector3) -> void:
	var solid := CollisionShape3D.new()
	var slab_shape := BoxShape3D.new()
	slab_shape.size = Vector3(PLATE_HALF_SIZE * 2.0, PLATE_HEIGHT, PLATE_HALF_SIZE * 2.0)
	solid.shape = slab_shape
	solid.transform = Transform3D(Basis(Vector3.UP, atan2(-axis.z, axis.x)), at + Vector3(0, PLATE_HEIGHT / 2.0, 0))
	_chain_body.add_child(solid)
	_chain_footprints.append([at, at, PLATE_HALF_SIZE])
	var pivot := Node3D.new()
	pivot.position = at
	pivot.set_meta("kind", "plate")
	pivot.basis = Basis(Vector3.UP, atan2(-axis.z, axis.x))
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#34363C")
	steel.metallic = 0.4
	steel.roughness = 0.5
	var plate := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.75, 0.08, 0.75)
	plate.mesh = slab
	plate.material_override = steel
	plate.position.y = 0.04
	pivot.add_child(plate)
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = 0.065
	bolt_mesh.bottom_radius = 0.065
	bolt_mesh.height = 0.06
	bolt_mesh.radial_segments = 6
	for corner in [Vector2(-0.26, -0.26), Vector2(0.26, -0.26), Vector2(-0.26, 0.26), Vector2(0.26, 0.26)]:
		var bolt := MeshInstance3D.new()
		bolt.mesh = bolt_mesh
		bolt.material_override = _chain_material
		bolt.position = Vector3(corner.x, 0.1, corner.y)
		pivot.add_child(bolt)
	var eyelet := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.07
	ring.outer_radius = 0.22
	eyelet.mesh = ring
	eyelet.material_override = _chain_material
	# Stands upright with the chain passing through it.
	eyelet.basis = Basis(Vector3.RIGHT, PI / 2.0).rotated(Vector3.UP, PI / 2.0)
	eyelet.position.y = CHAIN_END_HEIGHT
	pivot.add_child(eyelet)
	pivot.scale = Vector3.ONE * 0.01
	_chain.add_child(pivot)
	create_tween().tween_property(pivot, "scale", Vector3.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Height of the die's top surface above a world point, or -INF when the die is
## not under it. A vertical ray is clipped against the die's faces.
func _surface_top(world_point: Vector3) -> float:
	var to_local := global_transform.affine_inverse()
	var origin := to_local * Vector3(world_point.x, global_position.y + 10.0, world_point.z)
	var direction := to_local.basis * Vector3.DOWN
	if sides == 2:
		return _coin_surface_top(origin, direction, to_local)
	var near := -INF
	var far := INF
	for face in shape_data.faces:
		var along := face.normal.dot(direction)
		var distance := face.center.dot(face.normal) - face.normal.dot(origin)
		if absf(along) < 0.00001:
			if distance < 0.0:
				return -INF
			continue
		var t := distance / along
		if along < 0.0:
			near = maxf(near, t)
		else:
			far = minf(far, t)
	if near > far or far < 0.0:
		return -INF
	return (global_transform * (origin + direction * near)).y


## The coin is a short cylinder along its local y axis, so it may lie flat or
## stand on its edge. The ray is clipped against the side and both caps.
func _coin_surface_top(origin: Vector3, direction: Vector3, to_local: Transform3D) -> float:
	var half := COIN_THICKNESS / 2.0
	var near := -INF
	var far := INF
	var side_a := direction.x * direction.x + direction.z * direction.z
	var side_b := 2.0 * (origin.x * direction.x + origin.z * direction.z)
	var side_c := origin.x * origin.x + origin.z * origin.z - COIN_RADIUS * COIN_RADIUS
	if side_a > 0.000001:
		var discriminant := side_b * side_b - 4.0 * side_a * side_c
		if discriminant < 0.0:
			return -INF
		var root := sqrt(discriminant)
		near = (-side_b - root) / (2.0 * side_a)
		far = (-side_b + root) / (2.0 * side_a)
	elif side_c > 0.0:
		return -INF
	if absf(direction.y) > 0.000001:
		var t1 := (-half - origin.y) / direction.y
		var t2 := (half - origin.y) / direction.y
		near = maxf(near, minf(t1, t2))
		far = minf(far, maxf(t1, t2))
	elif absf(origin.y) > half:
		return -INF
	if near > far or far < 0.0:
		return -INF
	return (global_transform * (origin + direction * near)).y


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
	var text_color := ColorUtils.contrast_color(die_color)
	for face_up in [true, false]:
		var label := _make_label("1" if face_up else "2", COIN_RADIUS * 0.9, text_color)
		var normal := Vector3.UP if face_up else Vector3.DOWN
		var up := Vector3(0, 0, -1)
		label.transform = Transform3D(Basis(up.cross(normal), up, normal), normal * (COIN_THICKNESS / 2.0 + 0.004))
		add_child(label)


func _make_face_numeral(face: DieShape.Face, text_color: Color) -> Label3D:
	var text := _numeral_text(face.value)
	# Fit two-digit numerals on small faces.
	var label := _make_label(text, face.inradius * (1.1 if text.length() == 1 else 0.8), text_color)
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
	label.outline_size = 0
	label.double_sided = false
	return label


func _numeral_text(value: int) -> String:
	match numeral_style:
		NumeralStyle.TENS:
			return "%02d" % ((value % 10) * 10)
		NumeralStyle.UNITS:
			return str(value % 10)
	# Underline-style dot so 6 and 9 can be told apart.
	return "%d." % value if value in [6, 9] and sides > 6 else str(value)
