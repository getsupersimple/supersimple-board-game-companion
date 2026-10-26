class_name DieShape
extends RefCounted
## Geometry and face values of one die shape. Pure data, so it can be tested
## without a scene. Faces are found from outward normals, and opposite faces
## sum to sides + 1 as on a real die.

const PHI := 1.6180339887498949
const SUPPORTED_SIDES: Array[int] = [6, 8, 12, 20]

class Face:
	var normal := Vector3.UP
	var center := Vector3.ZERO
	## Vertex indices, ordered counter-clockwise when seen from outside.
	var vertex_indices := PackedInt32Array()
	var value := 0
	## Distance from the face centre to its nearest edge, used to size numerals.
	var inradius := 0.0

var sides := 0
var vertices := PackedVector3Array()
var faces: Array[Face] = []


static func is_supported(side_count: int) -> bool:
	return side_count in SUPPORTED_SIDES


static func create(side_count: int, circumradius: float = 0.9) -> DieShape:
	if not is_supported(side_count):
		return null
	var raw: Array[Vector3] = []
	var normals: Array[Vector3] = []
	match side_count:
		6:
			_cube(raw, normals)
		8:
			_octahedron(raw, normals)
		12:
			_dodecahedron(raw, normals)
		20:
			_icosahedron(raw, normals)

	var shape := DieShape.new()
	shape.sides = side_count
	var scale := circumradius / raw[0].length()
	for vertex in raw:
		shape.vertices.append(vertex * scale)
	for normal in normals:
		shape._add_face(normal.normalized())
	shape._assign_values()
	return shape


func build_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var ids := face.vertex_indices
		# Godot treats clockwise triangles as front-facing.
		for i in range(1, ids.size() - 1):
			for vertex_id in [ids[0], ids[i + 1], ids[i]]:
				surface.set_normal(face.normal)
				surface.add_vertex(vertices[vertex_id])
	return surface.commit()


func _add_face(normal: Vector3) -> void:
	var best := -INF
	for vertex in vertices:
		best = maxf(best, vertex.dot(normal))
	var face := Face.new()
	face.normal = normal
	var ids: Array[int] = []
	var center := Vector3.ZERO
	for i in vertices.size():
		if vertices[i].dot(normal) >= best - 0.0001:
			ids.append(i)
			center += vertices[i]
	center /= ids.size()
	face.center = center

	var u := (vertices[ids[0]] - center).normalized()
	var v := normal.cross(u)
	ids.sort_custom(func(a: int, b: int) -> bool:
		var pa := vertices[a] - center
		var pb := vertices[b] - center
		return atan2(pa.dot(v), pa.dot(u)) < atan2(pb.dot(v), pb.dot(u)))
	face.vertex_indices = PackedInt32Array(ids)

	face.inradius = INF
	for i in ids.size():
		var a := vertices[ids[i]]
		var b := vertices[ids[(i + 1) % ids.size()]]
		face.inradius = minf(face.inradius, Geometry3D.get_closest_point_to_segment(center, a, b).distance_to(center))
	faces.append(face)


func _assign_values() -> void:
	var next_value := 1
	for i in faces.size():
		if faces[i].value != 0:
			continue
		for j in range(i + 1, faces.size()):
			if faces[j].value == 0 and faces[j].normal.dot(faces[i].normal) < -0.999:
				faces[i].value = next_value
				faces[j].value = sides + 1 - next_value
				next_value += 1
				break


static func _cube(vertices: Array[Vector3], normals: Array[Vector3]) -> void:
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				vertices.append(Vector3(x, y, z))
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		normals.append(axis)
		normals.append(-axis)


static func _octahedron(vertices: Array[Vector3], normals: Array[Vector3]) -> void:
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		vertices.append(axis)
		vertices.append(-axis)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				normals.append(Vector3(x, y, z))


static func _dodecahedron(vertices: Array[Vector3], normals: Array[Vector3]) -> void:
	var inv := 1.0 / PHI
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			for c in [-1.0, 1.0]:
				vertices.append(Vector3(a, b, c))
			vertices.append(Vector3(0, a * inv, b * PHI))
			vertices.append(Vector3(a * inv, b * PHI, 0))
			vertices.append(Vector3(a * PHI, 0, b * inv))
			normals.append(Vector3(0, a * PHI, b))
			normals.append(Vector3(a, 0, b * PHI))
			normals.append(Vector3(a * PHI, b, 0))


static func _icosahedron(vertices: Array[Vector3], normals: Array[Vector3]) -> void:
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			vertices.append(Vector3(0, a, b * PHI))
			vertices.append(Vector3(a, b * PHI, 0))
			vertices.append(Vector3(a * PHI, 0, b))
	# Faces are the vertex triples that are mutually one edge length apart.
	for i in vertices.size():
		for j in range(i + 1, vertices.size()):
			for k in range(j + 1, vertices.size()):
				if _is_unit_edge(vertices[i], vertices[j]) and _is_unit_edge(vertices[j], vertices[k]) \
						and _is_unit_edge(vertices[i], vertices[k]):
					normals.append(vertices[i] + vertices[j] + vertices[k])


static func _is_unit_edge(a: Vector3, b: Vector3) -> bool:
	return absf(a.distance_to(b) - 2.0) < 0.001
