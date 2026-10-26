class_name HourglassArt
extends RefCounted
## How the hourglass looks, apart from the sand: a polished mahogany frame, a round
## top disc with brass finials, two turned pillars, a stepped base, a clear glass with
## a visible lip, and a softly lit room behind it. The camera sits a little above, so
## the discs show their tops as thin ellipses. It is drawn from the same outline as
## the physics walls, so the sand always sits against the glass it is drawn in. The
## two layers are drawn once and kept, so none of this costs anything while the sand runs.

const WOOD := Color("#6C3818")
const WOOD_LIGHT := Color("#A8601F")
const WOOD_DARK := Color("#2F150A")
const BRASS := Color("#B88A32")
## The picture, in the glass's own coordinates (the top of the glass is y = 0).
const BACKDROP := Rect2(-330.0, -150.0, 660.0, 1430.0)
const HORIZON_Y := 1060.0
const WALL_EDGE := Color("#B49F86")
const WALL_GLOW := Color("#F8E4C0")
const TABLE_TOP := Color("#D9CBB6")
const TABLE_BOTTOM := Color("#BFAF98")

const TOP_DISC_RADIUS := 300.0
const TOP_DISC_Y := -70.0
const TOP_DISC_THICKNESS := 44.0
const DISC_TILT := 0.075
const PILLAR_X := 270.0
## How much thicker than the profile the pillars are drawn.
const PILLAR_THICKNESS := 1.15
const PILLAR_TOP := -24.0
const PILLAR_BOTTOM := 1112.0
const BASE_TOP_Y := 1104.0

## The turned profile of the pillars: how far along (0 to 1) and how thick.
const PILLAR_PROFILE: Array[Vector2] = [
	Vector2(0.00, 10.0), Vector2(0.025, 16.0), Vector2(0.05, 11.0), Vector2(0.09, 18.0),
	Vector2(0.13, 12.0), Vector2(0.20, 15.0), Vector2(0.34, 19.5), Vector2(0.48, 22.0),
	Vector2(0.58, 19.0), Vector2(0.615, 13.0), Vector2(0.645, 21.0), Vector2(0.675, 13.0),
	Vector2(0.72, 17.0), Vector2(0.82, 20.0), Vector2(0.90, 17.0), Vector2(0.935, 11.0),
	Vector2(0.965, 17.0), Vector2(1.0, 12.0),
]

static var _outline := PackedVector2Array()


## Everything behind the sand: the room, the shadow, the base, and the pillars.
static func draw_back(canvas: CanvasItem) -> void:
	_prepare()
	_draw_room(canvas)
	_draw_shadow(canvas)
	_draw_base(canvas)
	_draw_pillars(canvas)


## Everything in front of the sand: the glass edge, its reflections and lips, then
## the top disc and the finials.
static func draw_front(canvas: CanvasItem) -> void:
	_prepare()
	_draw_glass_edge(canvas)
	_draw_reflections(canvas)
	_draw_glass_lips(canvas)
	_draw_top_disc(canvas)


static func _prepare() -> void:
	if _outline.is_empty():
		_outline = HourglassShape.outline()


# ---------------------------------------------------------------- the room

## A warm, softly lit room: a wall that is darkest at the corners and glows behind
## the hourglass, and a table in front, where it stands.
static func _draw_room(canvas: CanvasItem) -> void:
	var shape := _rounded_rect(BACKDROP, 44.0)
	canvas.draw_colored_polygon(shape, WALL_EDGE)
	var middle := Vector2(0.0, 520.0)
	for step in 26:
		var t := float(step) / 25.0
		var radius := Vector2(560.0, 760.0) * (1.0 - t * 0.93)
		var glow := WALL_EDGE.lerp(WALL_GLOW, pow(t, 0.8))
		for piece in Geometry2D.intersect_polygons(shape, _ellipse(middle, radius, 56)):
			canvas.draw_colored_polygon(piece, glow)
	# The table.
	var table := PackedVector2Array([Vector2(BACKDROP.position.x, HORIZON_Y), Vector2(BACKDROP.end.x, HORIZON_Y), BACKDROP.end, Vector2(BACKDROP.position.x, BACKDROP.end.y)])
	var bands := 14
	for i in bands:
		var from_y := lerpf(HORIZON_Y, BACKDROP.end.y, float(i) / bands)
		var to_y := lerpf(HORIZON_Y, BACKDROP.end.y, float(i + 1) / bands) + 0.8
		var strip := PackedVector2Array([Vector2(BACKDROP.position.x - 2.0, from_y), Vector2(BACKDROP.end.x + 2.0, from_y), Vector2(BACKDROP.end.x + 2.0, to_y), Vector2(BACKDROP.position.x - 2.0, to_y)])
		for piece in Geometry2D.intersect_polygons(shape, strip):
			canvas.draw_colored_polygon(piece, TABLE_TOP.lerp(TABLE_BOTTOM, float(i) / bands))
	canvas.draw_line(Vector2(BACKDROP.position.x, HORIZON_Y), Vector2(BACKDROP.end.x, HORIZON_Y), Color(0.3, 0.22, 0.12, 0.16), 3.0)
	canvas.draw_line(Vector2(BACKDROP.position.x, HORIZON_Y + 3.0), Vector2(BACKDROP.end.x, HORIZON_Y + 3.0), Color(1, 0.95, 0.85, 0.30), 2.0)
	# The light on the table, brightest just in front of the glow.
	for step in 8:
		var t := float(step) / 7.0
		var spot := _ellipse(Vector2(0.0, 1190.0), Vector2(420.0, 120.0) * (1.0 - t * 0.8), 40)
		for piece in Geometry2D.intersect_polygons(table, spot):
			canvas.draw_colored_polygon(piece, Color(1.0, 0.93, 0.78, 0.045))


static func _draw_shadow(canvas: CanvasItem) -> void:
	for layer in 7:
		var spread := 1.0 - layer * 0.10
		canvas.draw_colored_polygon(_ellipse(Vector2(0.0, 1218.0), Vector2(372.0, 40.0) * spread, 56), Color(0.12, 0.07, 0.03, 0.055))


# ---------------------------------------------------------------- the wood

## The base: two round steps, each seen as a thin ellipse on top and a thick band
## in front.
static func _draw_base(canvas: CanvasItem) -> void:
	_disc(canvas, 1150.0, 322.0, 46.0)
	_disc(canvas, BASE_TOP_Y + 8.0, 282.0, 30.0)
	# A ring of pale wood on the top step, where the glass stands.
	canvas.draw_colored_polygon(_ellipse(Vector2(0.0, BASE_TOP_Y), Vector2(158.0, 158.0 * DISC_TILT * 2.6), 48), Color(0.40, 0.20, 0.09, 0.55))
	# A soft contact shadow around the foot of the glass.
	for layer in 4:
		canvas.draw_colored_polygon(_ellipse(Vector2(0.0, BASE_TOP_Y + 4.0), Vector2(150.0 + layer * 5.0, 20.0 + layer * 2.0), 48), Color(0.08, 0.04, 0.02, 0.10))


static func _draw_top_disc(canvas: CanvasItem) -> void:
	_disc(canvas, TOP_DISC_Y, TOP_DISC_RADIUS, TOP_DISC_THICKNESS)
	# Brass finials.
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 258.0, TOP_DISC_Y - 8.0)
		canvas.draw_rect(Rect2(base.x - 5.0, base.y - 10.0, 10.0, 12.0), BRASS.darkened(0.25))
		_sphere(canvas, base + Vector2(0.0, -22.0), 19.0, BRASS)


## A round wooden disc: its top surface as an ellipse, then a thick front band,
## shaded across like a cylinder lit from the left and polished along its upper edge.
static func _disc(canvas: CanvasItem, top_y: float, radius: float, thickness: float) -> void:
	var tilt := radius * DISC_TILT
	# The front band, in strips across the width.
	var strips := 16
	for strip in strips:
		var u0 := float(strip) / strips
		var u1 := float(strip + 1) / strips
		var middle := (u0 + u1) * 0.5
		var light := _cylinder_light(middle)
		for sub in 5:
			var v0 := float(sub) / 5.0
			var v1 := float(sub + 1) / 5.0
			var top_edge := PackedVector2Array()
			var bottom_edge := PackedVector2Array()
			for k in 5:
				var x := lerpf(u0, u1, k / 4.0) * 2.0 * radius - radius
				var arc := tilt * sqrt(maxf(1.0 - pow(x / radius, 2.0), 0.0))
				top_edge.append(Vector2(x, top_y + arc + thickness * v0))
				bottom_edge.append(Vector2(x, top_y + arc + thickness * v1))
			var poly := PackedVector2Array(top_edge)
			for i in range(bottom_edge.size() - 1, -1, -1):
				poly.append(bottom_edge[i])
			var shade := light * (1.12 - 0.5 * (v0 + v1) * 0.5)
			canvas.draw_colored_polygon(poly, _wood(shade))
	# Grain along the band.
	for line_index in 6:
		var points := PackedVector2Array()
		var offset := thickness * (line_index + 0.7) / 6.6
		for k in 40:
			var x := -radius + 2.0 * radius * k / 39.0
			var arc := tilt * sqrt(maxf(1.0 - pow(x / radius, 2.0), 0.0))
			points.append(Vector2(x, top_y + arc + offset + sin(k * 0.55 + line_index * 1.7) * 1.6))
		canvas.draw_polyline(points, Color(WOOD_DARK.r, WOOD_DARK.g, WOOD_DARK.b, 0.28), 1.5, true)
	# The top surface.
	var surface := _ellipse(Vector2(0.0, top_y), Vector2(radius, tilt), 64)
	canvas.draw_colored_polygon(surface, _wood(1.0))
	for step in 6:
		var t := float(step) / 5.0
		var shine := _ellipse(Vector2(-radius * 0.18 * t, top_y - tilt * 0.12 * t), Vector2(radius * (0.97 - 0.6 * t), tilt * (0.9 - 0.55 * t)), 48)
		canvas.draw_colored_polygon(shine, _wood(1.0 + 0.55 * t))
	# The rim catches the light, and the edge underneath is dark.
	var front := PackedVector2Array()
	for k in 60:
		var x := -radius + 2.0 * radius * k / 59.0
		front.append(Vector2(x, top_y + tilt * sqrt(maxf(1.0 - pow(x / radius, 2.0), 0.0))))
	canvas.draw_polyline(front, Color(1.0, 0.82, 0.55, 0.55), 2.5, true)
	var under := PackedVector2Array()
	for k in 60:
		var x := -radius + 2.0 * radius * k / 59.0
		under.append(Vector2(x, top_y + thickness + tilt * sqrt(maxf(1.0 - pow(x / radius, 2.0), 0.0))))
	canvas.draw_polyline(under, Color(WOOD_DARK.r, WOOD_DARK.g, WOOD_DARK.b, 0.9), 3.0, true)
	canvas.draw_polyline(_closed(surface), Color(WOOD_DARK.r, WOOD_DARK.g, WOOD_DARK.b, 0.55), 1.8, true)


## Two turned pillars: round, with beads and rings, shaded across the width like a
## polished cylinder lit from the left, with grain running along them.
static func _draw_pillars(canvas: CanvasItem) -> void:
	var strips := 14
	for side in [-1.0, 1.0]:
		for strip in strips:
			var u0 := float(strip) / strips
			var u1 := float(strip + 1) / strips
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			var y := PILLAR_TOP
			while y <= PILLAR_BOTTOM + 0.01:
				var radius := _pillar_radius(y)
				left.append(Vector2(side * PILLAR_X + (u0 * 2.0 - 1.0) * radius, y))
				right.append(Vector2(side * PILLAR_X + (u1 * 2.0 - 1.0) * radius, y))
				y += 6.0
			var body := PackedVector2Array(left)
			for i in range(right.size() - 1, -1, -1):
				body.append(right[i])
			canvas.draw_colored_polygon(body, _wood(_cylinder_light((u0 + u1) * 0.5)))
		for line_index in 5:
			var u := (line_index + 0.8) / 5.8
			var points := PackedVector2Array()
			var y := PILLAR_TOP
			var step := 0
			while y <= PILLAR_BOTTOM:
				points.append(Vector2(side * PILLAR_X + (u * 2.0 - 1.0) * _pillar_radius(y) + sin(step * 0.35 + line_index * 2.1) * 0.9, y))
				y += 9.0
				step += 1
			canvas.draw_polyline(points, Color(WOOD_DARK.r, WOOD_DARK.g, WOOD_DARK.b, 0.26), 1.4, true)
		# Dark creases where the turned rings meet.
		for crease in [0.043, 0.11, 0.60, 0.66, 0.935]:
			var crease_y: float = lerpf(PILLAR_TOP, PILLAR_BOTTOM, crease)
			var radius := _pillar_radius(crease_y)
			canvas.draw_line(Vector2(side * PILLAR_X - radius, crease_y), Vector2(side * PILLAR_X + radius, crease_y), Color(WOOD_DARK.r, WOOD_DARK.g, WOOD_DARK.b, 0.6), 2.2, true)
			canvas.draw_line(Vector2(side * PILLAR_X - radius, crease_y + 2.4), Vector2(side * PILLAR_X + radius, crease_y + 2.4), Color(1.0, 0.8, 0.5, 0.28), 1.4, true)


static func _pillar_radius(y: float) -> float:
	var along := clampf((y - PILLAR_TOP) / (PILLAR_BOTTOM - PILLAR_TOP), 0.0, 1.0)
	for i in PILLAR_PROFILE.size() - 1:
		var a := PILLAR_PROFILE[i]
		var b := PILLAR_PROFILE[i + 1]
		if along <= b.x:
			var t := (along - a.x) / maxf(b.x - a.x, 0.0001)
			return lerpf(a.y, b.y, 0.5 - 0.5 * cos(t * PI)) * PILLAR_THICKNESS
	return PILLAR_PROFILE[PILLAR_PROFILE.size() - 1].y * PILLAR_THICKNESS


## How bright polished wood looks at a point across a cylinder, from 0 (left edge)
## to 1 (right edge): lit from the left, with a narrow bright streak and a dark edge.
static func _cylinder_light(u: float) -> float:
	var body := 1.12 - 0.78 * smoothstep(0.0, 1.0, u)
	var streak := 0.42 * exp(-pow((u - 0.26) / 0.055, 2.0))
	var edge := 0.20 * exp(-pow((u - 0.99) / 0.05, 2.0))
	return maxf(body + streak - edge, 0.18)


## The mahogany colour at a given brightness.
static func _wood(light: float) -> Color:
	if light <= 1.0:
		return WOOD_DARK.lerp(WOOD, clampf(light, 0.0, 1.0))
	return WOOD.lerp(WOOD_LIGHT, clampf(light - 1.0, 0.0, 1.0) * 1.4).lightened(clampf(light - 1.55, 0.0, 0.6) * 0.6)


## A polished ball, lit from the upper left, with a small bright highlight.
static func _sphere(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	canvas.draw_circle(centre, radius, colour.darkened(0.55))
	for step in 9:
		var t := float(step) / 8.0
		canvas.draw_circle(centre + Vector2(-0.30, -0.34) * radius * t, radius * (1.0 - 0.88 * t) * 0.97, colour.darkened(0.45).lerp(colour.lightened(0.45), pow(t, 0.9)))
	canvas.draw_circle(centre + Vector2(-0.36, -0.40) * radius, radius * 0.17, Color(1, 0.97, 0.88, 0.95))


# ---------------------------------------------------------------- the glass

static func _draw_glass_edge(canvas: CanvasItem) -> void:
	canvas.draw_polyline(_closed(_outline), Color(0.30, 0.34, 0.36, 0.55), 3.5, true)
	canvas.draw_polyline(_closed(HourglassShape.inset(_outline, 3.5)), Color(1.0, 0.98, 0.93, 0.62), 2.0, true)


## Light from a window: a long bright streak down the left of each bulb and a
## shorter one on the right. Each streak is a ribbon that is thickest in the middle
## and fades at both ends.
static func _draw_reflections(canvas: CanvasItem) -> void:
	var wall := HourglassShape.right_wall()
	for mirrored in [false, true]:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for point in wall:
			var y: float = point.y
			var flipped := HourglassShape.HEIGHT - y if mirrored else y
			if flipped > 40.0 and flipped < HourglassShape.NECK_Y - 70.0:
				left.append(Vector2(-point.x + 36.0, y))
			if flipped > 140.0 and flipped < 410.0:
				right.append(Vector2(point.x - 30.0, y))
		_ribbon(canvas, left, 12.0, 0.46)
		_ribbon(canvas, right, 7.0, 0.26)
	canvas.draw_circle(Vector2(-6.0, HourglassShape.NECK_Y - 8.0), 3.2, Color(1, 1, 1, 0.9))


## The rim of the glass at each end, where it is thick: a bright lip you can see
## round the front, with the dark of the inside behind it.
static func _draw_glass_lips(canvas: CanvasItem) -> void:
	for at_top in [true, false]:
		var y := 0.0 if at_top else HourglassShape.HEIGHT
		var radius := HourglassShape.half_width(y) + 2.0
		var lip := _ellipse(Vector2(0.0, y), Vector2(radius, radius * DISC_TILT * 1.3), 56)
		var front := PackedVector2Array()
		for k in 31:
			var angle := PI * k / 30.0
			front.append(Vector2(cos(angle) * radius, y + sin(angle) * radius * DISC_TILT * 1.3))
		canvas.draw_polyline(front, Color(0.25, 0.30, 0.32, 0.5), 6.0, true)
		canvas.draw_polyline(front, Color(1.0, 0.99, 0.95, 0.85), 3.0, true)
		if not at_top:
			canvas.draw_polyline(_closed(lip), Color(0.2, 0.2, 0.2, 0.18), 1.5, true)


static func _ribbon(canvas: CanvasItem, points: PackedVector2Array, max_width: float, strength: float) -> void:
	if points.size() < 3:
		return
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	for i in points.size():
		var along := float(i) / (points.size() - 1)
		var half := max_width * 0.5 * pow(sin(along * PI), 0.7)
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		left_edge.append(points[i] + normal * half)
		right_edge.append(points[i] - normal * half)
	var body := PackedVector2Array(left_edge)
	for i in range(right_edge.size() - 1, -1, -1):
		body.append(right_edge[i])
	if Geometry2D.triangulate_polygon(body).is_empty():
		return
	canvas.draw_colored_polygon(body, Color(1, 0.99, 0.95, strength))


# ---------------------------------------------------------------- shapes

static func _ellipse(centre: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count
		points.append(centre + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


static func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centres := [
		Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + radius),
	]
	for corner in 4:
		for step in 7:
			var angle := -PI / 2.0 + (corner + step / 6.0) * PI / 2.0
			points.append(centres[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
