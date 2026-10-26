class_name Die
extends RigidBody3D
## One physical die. The result is whichever face points up once it has
## settled. A die that is not lying flat has no result.

## Minimum alignment (cosine) between the top face normal and up.
const FLAT_DOT := 0.95
const REST_LINEAR_SPEED := 0.15
const REST_ANGULAR_SPEED := 0.3
const NUMERAL_SIZE := 128

var sides := 0
var die_color := Color.WHITE
var shape_data: DieShape


func setup(side_count: int, color: Color) -> void:
	sides = side_count
	die_color = color
	shape_data = DieShape.create(side_count)

	mass = 1.0
	continuous_cd = true
	linear_damp = 0.15
	angular_damp = 0.3
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.25
	physics_material_override = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = shape_data.build_mesh()
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.45
	mesh_instance.material_override = surface
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = shape_data.vertices
	collision.shape = convex
	add_child(collision)

	for face in shape_data.faces:
		add_child(_make_numeral(face, ColorUtils.contrast_color(color)))


## The value on the top face, or -1 when the die is not lying flat.
func read_value() -> int:
	var best_dot := -INF
	var best_value := -1
	for face in shape_data.faces:
		var dot := (global_transform.basis * face.normal).dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_value = face.value
	return best_value if best_dot >= FLAT_DOT else -1


func is_at_rest() -> bool:
	return linear_velocity.length() < REST_LINEAR_SPEED and angular_velocity.length() < REST_ANGULAR_SPEED


func _make_numeral(face: DieShape.Face, text_color: Color) -> Label3D:
	var label := Label3D.new()
	# Underline-style dot so 6 and 9 can be told apart.
	label.text = "%d." % face.value if face.value in [6, 9] and sides > 6 else str(face.value)
	label.font_size = NUMERAL_SIZE
	label.pixel_size = face.inradius * 1.1 / NUMERAL_SIZE
	label.modulate = text_color
	label.outline_size = 0
	label.double_sided = false
	var up := (shape_data.vertices[face.vertex_indices[0]] - face.center).normalized()
	label.transform = Transform3D(Basis(up.cross(face.normal), up, face.normal), face.center + face.normal * 0.004)
	return label
