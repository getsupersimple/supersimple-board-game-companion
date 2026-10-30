class_name HourglassArt
extends RefCounted
## How the hourglass looks, apart from the sand: clear glass with a soft sheen down
## each side, and a wooden cap at each end. It is drawn from the same outline as the
## physics walls, so the sand always sits against the glass it is drawn in. The layer
## is drawn once and kept, so none of this costs anything while the sand runs.

## Each cap is a wide, thin plate with a thicker block under it that sits on the glass.
const PLATE_OVERHANG := 24.0
const PLATE_THICKNESS := 42.0
const BLOCK_OVERHANG := 8.0
const BLOCK_THICKNESS := 46.0
## How far the block reaches down over the glass.
const BLOCK_REACH := HourglassShape.CAP_DEPTH

const WOOD := Color("#DCA04A")
const WOOD_GRAIN := Color(0.45, 0.27, 0.08, 0.16)

static var _outline := PackedVector2Array()
static var _wood := WOOD
static var _wood_light := WOOD.lerp(Color.WHITE, 0.35)
static var _wood_dark := WOOD.darkened(0.25)


## The colour across the colour wheel from the sand's, kept lively enough to read as a cap.
static func complement(sand: Color) -> Color:
	return Color.from_hsv(fmod(sand.h + 0.5, 1.0), clampf(sand.s, 0.35, 0.85), clampf(sand.v, 0.6, 0.9))


## Everything in front of the sand: the glass and the caps.
static func draw_front(canvas: CanvasItem, cap_color: Color = WOOD) -> void:
	_wood = cap_color
	_wood_light = cap_color.lerp(Color.WHITE, 0.35)
	_wood_dark = cap_color.darkened(0.25)
	_prepare()
	_draw_glass(canvas)
	_draw_cap(canvas, true)
	_draw_cap(canvas, false)


static func _prepare() -> void:
	if _outline.is_empty():
		_outline = HourglassShape.outline()


# ---------------------------------------------------------------- the caps

## A wooden cap: the plate outermost, the block under it, and a small screw in the plate.
static func _draw_cap(canvas: CanvasItem, at_top: bool) -> void:
	var sign := 1.0 if at_top else -1.0
	var edge := 0.0 if at_top else HourglassShape.HEIGHT
	var half := HourglassShape.TUBE_RADIUS
	# The block, over the end of the glass.
	var block_outer := edge - sign * (BLOCK_THICKNESS - BLOCK_REACH)
	_plank(canvas, edge + sign * BLOCK_REACH, block_outer, half + BLOCK_OVERHANG, 10, _wood_light.lerp(_wood, 0.45))
	# The plate, beyond it.
	var plate_inner := block_outer
	var plate_outer := plate_inner - sign * PLATE_THICKNESS
	_plank(canvas, plate_inner, plate_outer, half + PLATE_OVERHANG, 14, _wood)
	var screw := Vector2(0.0, (plate_inner + plate_outer) / 2.0)
	canvas.draw_circle(screw, 6.0, Color("#4A2F12"))
	canvas.draw_arc(screw + Vector2(0.0, 1.5), 6.0, 0.2, PI - 0.2, 12, Color(1, 0.9, 0.7, 0.35), 1.5, true)


## One piece of wood seen from the side: a rounded slab, lit from above, with a faint grain.
static func _plank(canvas: CanvasItem, from_y: float, to_y: float, half: float, radius: int, color: Color) -> void:
	var top := minf(from_y, to_y)
	var height := absf(to_y - from_y)
	var body := Rect2(-half, top, half * 2.0, height)
	UiStyle.box(color.lerp(_wood_dark, 0.55), radius).draw(canvas.get_canvas_item(), body)
	UiStyle.box(color, radius - 2).draw(canvas.get_canvas_item(), Rect2(body.position + Vector2(2.0, 2.0), body.size - Vector2(4.0, 10.0)))
	UiStyle.box(Color(_wood_light, 0.75), radius - 4).draw(canvas.get_canvas_item(), Rect2(body.position + Vector2(8.0, 4.0), Vector2(body.size.x - 16.0, minf(7.0, height * 0.25))))
	for i in 3:
		var y := top + height * (0.32 + 0.2 * i)
		canvas.draw_line(Vector2(-half + radius, y), Vector2(half - radius, y + (i - 1) * 1.5), WOOD_GRAIN, 1.5, true)


# ---------------------------------------------------------------- the glass

## Clear glass: a thin grey edge and a bright sheen down each side.
static func _draw_glass(canvas: CanvasItem) -> void:
	canvas.draw_polyline(_closed(_outline), Color(0.42, 0.47, 0.50, 0.6), 3.0, true)
	canvas.draw_polyline(_closed(HourglassShape.inset(_outline, 3.5)), Color(1.0, 0.99, 0.96, 0.55), 2.0, true)
	_draw_sheen(canvas, -1.0, 16.0, 0.30, 0.75, 14.0)
	_draw_sheen(canvas, 1.0, 14.0, 0.16, 0.45, 8.0)


## A strip of light just inside one wall, from the top shoulder to the bottom one, which
## fades out where the glass pinches in at the neck.
static func _draw_sheen(canvas: CanvasItem, side: float, inset: float, soft: float, bright: float, width: float) -> void:
	var wall := HourglassShape.right_wall()
	var line := PackedVector2Array()
	for point in wall:
		if point.y < HourglassShape.CAP_DEPTH + 10.0 or point.y > HourglassShape.HEIGHT - HourglassShape.CAP_DEPTH - 10.0:
			continue
		line.append(Vector2(side * maxf(point.x - inset, 3.0), point.y))
	if line.size() < 2:
		return
	canvas.draw_polyline(line, Color(1.0, 1.0, 1.0, soft), width, true)
	canvas.draw_polyline(line, Color(1.0, 1.0, 1.0, bright), maxf(width * 0.25, 2.0), true)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
