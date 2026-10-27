class_name HourglassShape
extends RefCounted
## The outline of the glass, in pixels with the origin at the top centre. Pure
## geometry, so it can be tested without a scene. The bottom half mirrors the top.
##
## Each chamber is a straight tube with flat ends, closing down through a cone to
## the neck, like a plastic egg timer. The join between tube and cone is smoothed
## so the glass has no hard corner, for the physics walls and the picture alike.

const HEIGHT := 1100.0
const NECK_Y := 550.0
const NECK_HALF_WIDTH := 11.0
## Half the width of the tubes.
const TUBE_RADIUS := 130.0
## Where the tube ends and the cone begins, counting from the nearer end.
const TUBE_END_Y := 330.0
## How round the inside corners of the flat ends are.
const END_CORNER := 16.0
## How far the cap's lip reaches into each end, where no sand is put.
const CAP_DEPTH := 26.0
const SMOOTHING_RADIUS := 14
const WALL_STEP := 10.0

static var _widths := PackedFloat32Array()
static var _widths_texture: ImageTexture


## Half the width of the glass at a height.
static func half_width(y: float) -> float:
	_build()
	var position := clampf(y, 0.0, HEIGHT)
	var lower := int(floor(position))
	var upper := mini(lower + 1, _widths.size() - 1)
	return lerpf(_widths[lower], _widths[upper], position - lower)


## Half the width of the glass at every height, as a one-row picture a shader can
## read. The numbers are 16-bit decimals, so the edge comes out smooth.
static func widths_texture() -> ImageTexture:
	if _widths_texture == null:
		_build()
		var image := Image.create(_widths.size(), 1, false, Image.FORMAT_RH)
		for i in _widths.size():
			image.set_pixel(i, 0, Color(_widths[i], 0.0, 0.0))
		_widths_texture = ImageTexture.create_from_image(image)
	return _widths_texture


## The right-hand wall from the top to the bottom.
static func right_wall() -> PackedVector2Array:
	var wall := PackedVector2Array()
	var y := 0.0
	while y <= HEIGHT + 0.01:
		wall.append(Vector2(half_width(y), y))
		y += WALL_STEP
	return wall


## The whole outline, clockwise from the top left, for filling the glass.
static func outline() -> PackedVector2Array:
	var right := right_wall()
	var points := PackedVector2Array()
	for point in right:
		points.append(point)
	for i in range(right.size() - 1, -1, -1):
		points.append(Vector2(-right[i].x, right[i].y))
	return points


## A copy of a closed outline moved inwards by a distance, for the inner edge of
## the glass and for its highlights.
static func inset(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var moved := PackedVector2Array()
	var count := points.size()
	for i in count:
		var tangent := (points[(i + 1) % count] - points[(i + count - 1) % count]).normalized()
		# The outline runs clockwise on screen, so inwards is a quarter turn left.
		var inwards := Vector2(tangent.y, -tangent.x)
		moved.append(points[i] + inwards * distance)
	return moved


## Where grains start: packed in rows inside the top chamber (or the bottom one).
static func spawn_positions(count: int, radius: float, in_top_chamber: bool = true) -> PackedVector2Array:
	var spots := PackedVector2Array()
	var y := radius * 1.2 + CAP_DEPTH
	while spots.size() < count and y < NECK_Y - radius * 6.0:
		var room := half_width(y) - radius * 1.3
		var x := -room
		while x <= room and spots.size() < count:
			spots.append(Vector2(x, y if in_top_chamber else HEIGHT - y))
			x += radius * 2.1
		y += radius * 1.85
	return spots


static func _build() -> void:
	if not _widths.is_empty():
		return
	var size := int(HEIGHT) + 1
	var smooth := PackedFloat32Array()
	smooth.resize(size)
	for i in size:
		var y := float(mini(i, size - 1 - i))
		var across := (y - TUBE_END_Y) / (NECK_Y - TUBE_END_Y)
		smooth[i] = lerpf(TUBE_RADIUS, NECK_HALF_WIDTH, clampf(across, 0.0, 1.0))
	# Two passes of a moving average round off the joints. The glass is mirrored,
	# so the neck comes out smooth and symmetrical.
	for _pass in 2:
		var next := PackedFloat32Array()
		next.resize(size)
		for i in size:
			var total := 0.0
			for offset in range(-SMOOTHING_RADIUS, SMOOTHING_RADIUS + 1):
				total += smooth[clampi(i + offset, 0, size - 1)]
			next[i] = total / (SMOOTHING_RADIUS * 2 + 1)
		smooth = next
	# Smoothing fattens the neck. Stretch the widths back so it is the width asked for.
	var neck := smooth[int(NECK_Y)]
	for i in size:
		smooth[i] = NECK_HALF_WIDTH + (smooth[i] - neck) * (TUBE_RADIUS - NECK_HALF_WIDTH) / (TUBE_RADIUS - neck)
	# The flat ends have rounded inside corners.
	for i in size:
		var y := float(mini(i, size - 1 - i))
		if y < END_CORNER:
			var inside := END_CORNER - y
			smooth[i] = minf(smooth[i], TUBE_RADIUS - END_CORNER + sqrt(END_CORNER * END_CORNER - inside * inside))
	_widths = smooth
