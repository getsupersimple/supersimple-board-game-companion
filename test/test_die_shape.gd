extends GutTest

const VERTICES_PER_FACE := {6: 4, 8: 3, 12: 5, 20: 3}


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
	for sides in DieShape.SUPPORTED_SIDES:
		var seen: Array[int] = []
		for face in DieShape.create(sides).faces:
			seen.append(face.value)
		seen.sort()
		var expected: Array[int] = []
		for value in range(1, sides + 1):
			expected.append(value)
		assert_eq(seen, expected, "d%d values" % sides)


func test_opposite_faces_sum_to_sides_plus_one() -> void:
	for sides in DieShape.SUPPORTED_SIDES:
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
	var die := Die.new()
	die.setup(20, Color.RED)
	add_child_autofree(die)
	for face in die.shape_data.faces:
		die.global_transform = Transform3D(Basis(Quaternion(face.normal, Vector3.UP)), Vector3.ZERO)
		assert_eq(die.read_value(), face.value)


func test_vertex_up_is_cocked() -> void:
	var die := Die.new()
	die.setup(6, Color.RED)
	add_child_autofree(die)
	var corner := Vector3.ONE.normalized()
	die.global_transform = Transform3D(Basis(Quaternion(corner, Vector3.UP)), Vector3.ZERO)
	assert_eq(die.read_value(), -1)
