class_name HourglassShape
extends RefCounted
## The outline of the glass, in pixels with the origin at the top centre. Pure
## geometry, so it can be tested without a scene. The bottom half mirrors the top.

const HEIGHT := 1100.0
const NECK_Y := 550.0
const NECK_HALF_WIDTH := 20.0
## Half the width of the glass at several heights down the top half.
const TOP_PROFILE: Array[Vector2] = [
	Vector2(230, 0), Vector2(230, 110), Vector2(205, 300), Vector2(140, 430),
	Vector2(70, 500), Vector2(28, 540), Vector2(20, 550),
]


## Half the width of the glass at a height.
static func half_width(y: float) -> float:
	if y > NECK_Y:
		y = HEIGHT - y
	y = clampf(y, 0.0, NECK_Y)
	for i in TOP_PROFILE.size() - 1:
		var a := TOP_PROFILE[i]
		var b := TOP_PROFILE[i + 1]
		if y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.0001))
	return NECK_HALF_WIDTH


## The right-hand wall from the top to the bottom.
static func right_wall() -> PackedVector2Array:
	var wall := PackedVector2Array()
	for point in TOP_PROFILE:
		wall.append(point)
	for i in range(TOP_PROFILE.size() - 2, -1, -1):
		wall.append(Vector2(TOP_PROFILE[i].x, HEIGHT - TOP_PROFILE[i].y))
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
