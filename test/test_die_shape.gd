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
		assert_not_null(die._padlock, "d%d is padlocked" % entry[0])


func test_locking_a_flat_die_does_not_move_it() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.0, 0.52, 2.0))
	die.set_locked(true)
	await wait_seconds(0.4)
	assert_almost_eq(die.global_position.y, 0.52, 0.001)


func test_a_die_on_top_of_another_cannot_be_locked() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var lower := Die.new()
	lower.setup(6, Color.RED)
	holder.add_child(lower)
	lower.freeze = true
	lower.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0))
	var upper := Die.new()
	upper.setup(6, Color.BLUE)
	holder.add_child(upper)
	upper.freeze = true
	upper.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.2, 1.7, 0))
	await wait_physics_frames(3)
	assert_false(upper.can_lie_flat(), "it would have to go through the die below")
	assert_false(upper.try_lock())
	assert_false(upper.locked)
	assert_null(upper._padlock, "no padlock was put on")


func test_a_die_with_room_to_lie_flat_can_be_locked() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var near := Die.new()
	near.setup(6, Color.RED)
	holder.add_child(near)
	near.freeze = true
	near.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0))
	var beside := Die.new()
	beside.setup(6, Color.BLUE)
	holder.add_child(beside)
	beside.freeze = true
	# Cocked on a corner, a little way from the other die: room to flatten.
	beside.global_transform = Transform3D(Basis(Quaternion(Vector3.ONE.normalized(), Vector3.UP)), Vector3(3.0, 0.9, 0))
	await wait_physics_frames(3)
	assert_true(beside.can_lie_flat())
	assert_true(beside.try_lock())
	assert_true(beside.locked)


func test_touching_a_neighbour_does_not_stop_a_flat_die_being_locked() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var first := Die.new()
	first.setup(6, Color.RED)
	holder.add_child(first)
	first.freeze = true
	first.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0))
	var second := Die.new()
	second.setup(6, Color.BLUE)
	holder.add_child(second)
	second.freeze = true
	second.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.04, 0.52, 0))
	await wait_physics_frames(3)
	assert_true(second.can_lie_flat(), "side by side is fine")


func _sound_players(die: Die) -> Array:
	var found := []
	for child in die.get_children():
		if child is AudioStreamPlayer:
			found.append(child)
	return found


func test_locking_a_die_clanks_and_letting_go_clinks() -> void:
	AppSettings.dice_sound = true
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.set_locked(true)
	var players := _sound_players(die)
	assert_eq(players.size(), 1, "one clank")
	assert_eq(players[0].stream, SoundBank.stream("chain"))
	assert_true(players[0].playing)
	await wait_seconds(1.0)
	die.set_locked(false)
	var after := _sound_players(die)
	assert_eq(after.size(), 1, "the clank has finished, and one clink plays")
	assert_eq(after[0].stream, SoundBank.stream("unchain"))


func test_locking_is_silent_when_the_dice_sound_is_off() -> void:
	AppSettings.dice_sound = false
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.set_locked(true)
	assert_eq(_sound_players(die).size(), 0)
	AppSettings.dice_sound = true


func test_moving_a_locked_die_does_not_clank_again() -> void:
	AppSettings.dice_sound = true
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	die.set_locked(true)
	await wait_seconds(1.0)
	die.move_padlock()
	assert_eq(_sound_players(die).size(), 0, "a quiet re-lay")


func test_the_lock_sounds_exist() -> void:
	assert_gt(SoundBank.stream("chain").data.size(), 5000)
	assert_gt(SoundBank.stream("unchain").data.size(), 2000)


func test_a_locked_die_wears_a_padlock_above_it_and_loses_it_when_unlocked() -> void:
	for sides in [6, 20, 2]:
		var die := Die.new()
		die.setup(sides, Color.RED)
		add_child_autofree(die)
		die.set_locked(true)
		await wait_seconds(0.5)
		assert_not_null(die._padlock, "d%d has a padlock" % sides)
		assert_gt(die._padlock.global_position.y, die._highest_point(), "d%d padlock floats above the die" % sides)
		die.set_locked(false)
		assert_null(die._padlock, "d%d lost it again" % sides)


func test_the_padlock_is_the_same_small_size_on_every_die() -> void:
	var sizes := []
	for sides in [4, 6, 20, 2]:
		var die := Die.new()
		die.setup(sides, Color.RED)
		add_child_autofree(die)
		die.set_locked(true)
		await wait_seconds(0.5)
		var icon: Sprite3D = die._padlock.find_children("*", "Sprite3D", true, false)[0]
		sizes.append(icon.pixel_size * icon.texture.get_width() * die._padlock.scale.x)
	for size in sizes:
		assert_almost_eq(size, Die.PADLOCK_SIZE, 0.001)
	assert_lt(Die.PADLOCK_SIZE, 1.0)
