class_name SandMass
extends Node2D
## Draws the sand as one lit mass instead of a heap of circles. Every grain is
## drawn as a soft blob into a hidden picture, where blobs that touch add up. A
## shader then turns the picture into a surface: wherever the blobs add up past
## a threshold there is sand, shaded by the slope of the pile. It is cut
## to the shape of the glass, so no sand is ever drawn outside it.

const BLOB_RADIUS := 5.5

var grains: Array[RigidBody2D]

var _blobs: Node2D
var _density: SubViewport
var _material: ShaderMaterial


func setup(source: Array[RigidBody2D], size: Vector2i, color: Color) -> void:
	grains = source
	# Placed in the world's own coordinates, whatever this node's parent does.
	top_level = true
	position = Vector2.ZERO

	_density = SubViewport.new()
	_density.size = size
	_density.transparent_bg = false
	_density.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_density.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_density)
	_blobs = _BlobLayer.new()
	_blobs.mass = self
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_blobs.material = add
	_density.add_child(_blobs)

	var picture := TextureRect.new()
	picture.texture = _density.get_texture()
	picture.size = Vector2(size)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://scripts/hourglass/sand.gdshader")
	shader_material.set_shader_parameter("density", _density.get_texture())
	shader_material.set_shader_parameter("sand", color)
	_material = shader_material
	# Sand is only drawn where the glass is, whatever a grain does at its edge.
	shader_material.set_shader_parameter("widths", HourglassShape.widths_texture())
	shader_material.set_shader_parameter("glass_top", get_parent().global_position)
	shader_material.set_shader_parameter("glass_height", HourglassShape.HEIGHT)
	shader_material.set_shader_parameter("view_size", Vector2(size))
	picture.material = shader_material
	add_child(picture)


## Dyes the sand another colour, grains and all, while it runs.
func recolor(color: Color) -> void:
	if _material != null:
		_material.set_shader_parameter("sand", color)


## The soft white blob drawn for each grain.
static func make_blob() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	var blob := GradientTexture2D.new()
	blob.gradient = gradient
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(1.0, 0.5)
	blob.width = 64
	blob.height = 64
	return blob


class _BlobLayer extends Node2D:
	var mass: SandMass
	var _texture := SandMass.make_blob()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for grain in mass.grains:
			var at := grain.global_position
			draw_texture_rect(_texture, Rect2(at - Vector2.ONE * SandMass.BLOB_RADIUS, Vector2.ONE * SandMass.BLOB_RADIUS * 2.0), false)
