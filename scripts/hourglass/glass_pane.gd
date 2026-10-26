class_name GlassPane
extends ColorRect
## A rectangle just big enough to hold the glass, shaded by the glass shader. The
## shader looks up the width of the glass at each height from a small texture made
## from the same outline as the physics walls, so the glass is exactly the shape
## the sand sits in.

const MARGIN := 8.0


func _ready() -> void:
	var widest := 0.0
	for y in range(0, int(HourglassShape.HEIGHT) + 1, 10):
		widest = maxf(widest, HourglassShape.half_width(float(y)))
	var half := widest + MARGIN
	position = Vector2(-half, 0.0)
	size = Vector2(half * 2.0, HourglassShape.HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass_material := ShaderMaterial.new()
	glass_material.shader = load("res://scripts/hourglass/glass.gdshader")
	glass_material.set_shader_parameter("widths", HourglassShape.widths_texture())
	glass_material.set_shader_parameter("origin", position)
	glass_material.set_shader_parameter("rect_size", size)
	glass_material.set_shader_parameter("glass_height", HourglassShape.HEIGHT)
	material = glass_material
