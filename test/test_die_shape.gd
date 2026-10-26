extends GutTest

const VERTICES_PER_FACE := {4: 3, 6: 4, 8: 3, 10: 4, 12: 5, 20: 3}
## Every shape except the d4, which has numbers on vertices, not faces.
const FACE_VALUED := [6, 8, 10, 12, 20]


func test_unsupported_sides_return_null() -> void:
	assert_null(DieShape.create(7))


func test_face_count_matches_sides() -> void:
	for sides in DieShape.SUPPORTED_SIDES:
		assert_eq(DieShape.create(sides).faces.size(), sides, "d%d faces" % sides)


func test_each_face_has_expected_vertex_count() -> void:
	for sides in DieShape.SUPPORTED_SIDES:
		for face in DieShape.create(sides).faces:
			assert_eq(face.vertex_indices.size(), VERTICES_PER_FACE[sides], "d%d face vertices" % sides)


func test_values_cover_one_to_n_exactly_once() -> void:
	for sides in FACE_VALUED:
		var seen: Array[int] = []
		for face in DieShape.create(sides).faces:
			seen.append(face.value)
		seen.sort()
		var expected: Array[int] = []
		for value in range(1, sides + 1):
			expected.append(value)
		assert_eq(seen, expected, "d%d values" % sides)


func test_opposite_faces_sum_to_sides_plus_one() -> void:
	for sides in FACE_VALUED:
		var shape := DieShape.create(sides)
		for face in shape.faces:
			for other in shape.faces:
				if other.normal.dot(face.normal) < -0.999:
					assert_eq(face.value + other.value, sides + 1, "d%d opposite sum" % sides)


func test_face_normals_point_outward() -> void:
	for sides in DieShape.SUPPORTED_SIDES:
		for face in DieShape.create(sides).faces:
			assert_gt(face.center.dot(face.normal), 0.0)


func test_read_value_matches_face_pointing_up() -> void:
	for sides in FACE_VALUED:
		var die := Die.new()
		die.setup(sides, Color.RED)
		add_child_autofree(die)
		for face in die.shape_data.faces:
			die.global_transform = Transform3D(Basis(Quaternion(face.normal, Vector3.UP)), Vector3.ZERO)
			assert_eq(die.read_value(), face.value, "d%d" % sides)


func test_vertex_up_is_cocked() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	var corner := Vector3.ONE.normalized()
	die.global_transform = Transform3D(Basis(Quaternion(corner, Vector3.UP)), Vector3.ZERO)
	assert_eq(die.read_value(), -1)


func test_every_face_has_an_opposite_except_d4() -> void:
	for sides in FACE_VALUED:
		var shape := DieShape.create(sides)
		for face in shape.faces:
			var found := false
			for other in shape.faces:
				found = found or other.normal.dot(face.normal) < -0.999
			assert_true(found, "d%d face has an opposite" % sides)


func test_d10_faces_are_flat() -> void:
	var shape := DieShape.create(10)
	for face in shape.faces:
		for vertex_id in face.vertex_indices:
			assert_almost_eq(shape.vertices[vertex_id].dot(face.normal), face.center.dot(face.normal), 0.001)


func test_d4_reads_vertex_and_each_number_is_on_three_faces() -> void:
	var shape := DieShape.create(4)
	assert_true(shape.reads_vertex)
	for number in [1, 2, 3, 4]:
		var count := 0
		for face in shape.faces:
			for vertex_id in face.vertex_indices:
				if shape.vertex_values[vertex_id] == number:
					count += 1
		assert_eq(count, 3, "number %d appears on three faces" % number)


func test_d4_reads_top_vertex() -> void:
	var die := Die.new()
	die.setup(4, Color.RED)
	add_child_autofree(die)
	for i in die.shape_data.vertices.size():
		var direction := die.shape_data.vertices[i].normalized()
		die.global_transform = Transform3D(Basis(Quaternion(direction, Vector3.UP)), Vector3.ZERO)
		assert_eq(die.read_value(), die.shape_data.vertex_values[i])


func test_d4_on_an_edge_is_cocked() -> void:
	var die := Die.new()
	die.setup(4, Color.RED)
	add_child_autofree(die)
	# Edge midpoint straight up: the two top vertices are tilted about 35 degrees.
	var edge_middle := (die.shape_data.vertices[0] + die.shape_data.vertices[1]).normalized()
	die.global_transform = Transform3D(Basis(Quaternion(edge_middle, Vector3.UP)), Vector3.ZERO)
	assert_eq(die.read_value(), -1)


func test_coin_reads_heads_tails_and_edge() -> void:
	var coin := Die.new()
	coin.setup(2, Color.RED)
	add_child_autofree(coin)
	coin.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	assert_eq(coin.read_value(), 1)
	coin.global_transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO)
	assert_eq(coin.read_value(), 2)
	coin.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	assert_eq(coin.read_value(), -1)


func test_locking_freezes_and_unlocking_releases_a_die() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.set_locked(true)
	assert_true(die.locked)
	assert_true(die.freeze)
	die.set_locked(false)
	assert_false(die.locked)
	assert_false(die.freeze)


func test_chains_pass_over_the_die_and_are_bolted_to_the_table() -> void:
	for sides in [2, 4, 6, 10, 20]:
		var die := Die.new()
		die.setup(sides, Color.RED)
		add_child_autofree(die)
		die.set_locked(true)
		await wait_seconds(0.5)
		var links: Array[Node3D] = []
		var plates: Array[Node3D] = []
		for pivot in die._chain.get_children():
			if not pivot.has_meta("kind"):
				continue
			if pivot.get_meta("kind") == "plate":
				plates.append(pivot)
			else:
				links.append(pivot)
		assert_eq(plates.size(), 4, "d%d has four anchor plates" % sides)
		assert_gt(links.size(), 12, "d%d has two chains" % sides)
		for plate in plates:
			assert_almost_eq(plate.position.y, 0.0, 0.001)
		for link in links:
			var top: float = die._surface_top(link.position)
			if top > -INF:
				assert_gt(link.position.y, top, "d%d link rests above the die" % sides)


func test_chains_follow_the_dice_rotation() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	# Lying square to the screen: the chains run along the screen axes.
	var square := absf(die.chain_axis().dot(Vector3.RIGHT))
	assert_true(is_equal_approx(square, 1.0) or is_equal_approx(square, 0.0), "square die, square chains")
	# Turned 45 degrees: the chains cross it diagonally.
	die.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(45.0)), Vector3.ZERO)
	assert_almost_eq(absf(die.chain_axis().dot(Vector3.RIGHT)), sqrt(0.5), 0.01)
	var perpendicular := die.chain_axis().rotated(Vector3.UP, PI / 2.0)
	assert_almost_eq(absf(perpendicular.dot(Vector3.RIGHT)), sqrt(0.5), 0.01)


func test_locking_a_cocked_die_turns_it_flat_first() -> void:
	var cases := [
		[6, Quaternion(Vector3.ONE.normalized(), Vector3.UP)],
		[20, Quaternion(DieShape.create(20).vertices[0].normalized(), Vector3.UP)],
		[4, Quaternion(Vector3(1, 1, 0).normalized(), Vector3.UP)],
		[2, Quaternion(Vector3.RIGHT, PI / 2.0)],
	]
	for entry in cases:
		var die := Die.new()
		die.setup(entry[0], Color.RED)
		add_child_autofree(die)
		die.global_transform = Transform3D(Basis(entry[1]), Vector3(1.0, 1.0, 2.0))
		assert_eq(die.read_value(), -1, "d%d starts cocked" % entry[0])
		die.set_locked(true)
		await wait_seconds(0.5)
		assert_ne(die.read_value(), -1, "d%d locked flat" % entry[0])
		assert_almost_eq(die.global_position.x, 1.0, 0.001)
		assert_almost_eq(die.global_position.z, 2.0, 0.001)
		assert_lt(die.global_position.y, 1.0, "d%d lowered onto the table" % entry[0])
		assert_not_null(die._chain, "d%d is chained" % entry[0])


func test_locking_a_flat_die_does_not_move_it() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.0, 0.52, 2.0))
	die.set_locked(true)
	await wait_seconds(0.4)
	assert_almost_eq(die.global_position.y, 0.52, 0.001)


func test_chain_and_anchors_are_solid_and_push_things_clear() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.set_locked(true)
	assert_eq(die._chain_body.get_child_count(), 10, "four plates and six chain bars")
	var axis := die.chain_axis()
	# Something sitting on a plate is pushed out, along the chain's axis.
	var on_plate := die._chain_overlap(axis * (die._extent_along(axis) + Die.CHAIN_PLATE_GAP), 0.6)
	assert_ne(on_plate, Vector3.ZERO)
	# Something across the chain is pushed sideways, away from it.
	var crossing := die._chain_overlap(axis.rotated(Vector3.UP, PI / 4.0) * 0.1 + axis * 0.8, 0.6)
	assert_ne(crossing, Vector3.ZERO)
	# Something well away is left alone.
	assert_eq(die._chain_overlap(Vector3(5, 0, 5), 0.6), Vector3.ZERO)


func test_other_dice_are_shoved_out_of_a_new_chain() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var locked_die := Die.new()
	locked_die.setup(6, Color.RED)
	holder.add_child(locked_die)
	var bystander := Die.new()
	bystander.setup(6, Color.BLUE)
	holder.add_child(bystander)
	bystander.global_position = Vector3(0.3, 0.5, 0.0)
	bystander.sleeping = true
	var before := bystander.global_position
	locked_die.set_locked(true)
	await wait_physics_frames(5)
	assert_false(bystander.sleeping, "the bystander was woken")
	assert_gt(bystander.global_position.distance_to(before), 0.1, "and shoved out of the way")


func test_a_chained_die_shows_its_score_over_the_chains() -> void:
	for sides in [6, 20, 2]:
		var die := Die.new()
		die.setup(sides, Color.RED)
		add_child_autofree(die)
		die.set_locked(true)
		await wait_seconds(0.5)
		var label: Label3D = die._chain.get_node("ScoreLabel")
		assert_eq(label.text, str(die.read_value()), "d%d shows its value" % sides)
		assert_gt(label.position.y, die._highest_point(), "d%d number floats above the die" % sides)
