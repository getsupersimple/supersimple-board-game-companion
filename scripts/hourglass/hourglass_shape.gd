class_name HourglassShape
extends RefCounted
## The outline of the glass, in pixels with the origin at the top centre. Pure
## geometry, so it can be tested without a scene. The bottom half mirrors the top.
##
## Each bulb is a round belly that narrows through a flared throat to the neck,
## with the join smoothed so the glass has no corners, for the physics walls and
## for the picture alike.

const HEIGHT := 1100.0
const NECK_Y := 550.0
const NECK_HALF_WIDTH := 20.0
## The belly is part of a circle with this centre height and radius.
const BELLY_CENTRE_Y := 205.0
const BELLY_RADIUS := 238.0
## How fast the throat widens above the neck, in pixels across per pixel up.
const THROAT_SLOPE := 0.52
const SMOOTHING_RADIUS := 26
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


## The glass as a one-row picture a shader can read: at every height, half the
## width in the red channel and how fast that width is changing in the green. The
## numbers are kept as 16-bit decimals, so the glass comes out smooth, not stepped.
static func widths_texture() -> ImageTexture:
	if _widths_texture == null:
		_build()
		var count := _widths.size()
		var image := Image.create(count, 1, false, Image.FORMAT_RGH)
		for i in count:
			var slope := (_widths[mini(i + 3, count - 1)] - _widths[maxi(i - 3, 0)]) / float(mini(i + 3, count - 1) - maxi(i - 3, 0))
			image.set_pixel(i, 0, Color(_widths[i], slope, 0.0))
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
	var y := radius * 1.2
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
	var raw := PackedFloat32Array()
	raw.resize(size)
	for i in size:
		var y := float(mini(i, size - 1 - i))
		var belly := sqrt(maxf(BELLY_RADIUS * BELLY_RADIUS - (y - BELLY_CENTRE_Y) * (y - BELLY_CENTRE_Y), 0.0))
		var width := belly
		if y > BELLY_CENTRE_Y:
			width = maxf(belly, NECK_HALF_WIDTH + (NECK_Y - y) * THROAT_SLOPE)
		raw[i] = width
	# Two passes of a moving average round off every corner. The glass is mirrored,
	# so the neck comes out smooth and symmetrical.
	var smooth := raw
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
	var widest := 0.0
	for width in smooth:
		widest = maxf(widest, width)
	for i in size:
		smooth[i] = NECK_HALF_WIDTH + (smooth[i] - neck) * (widest - NECK_HALF_WIDTH) / (widest - neck)
	_widths = smooth
