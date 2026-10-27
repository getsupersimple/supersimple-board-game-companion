class_name HourglassArt
extends RefCounted
## How the hourglass looks, apart from the sand: the outline of a clear plastic egg
## timer with a coloured cap at each end, and nothing else. It is drawn from the
## same outline as the physics walls, so the sand always sits against the glass it
## is drawn in. The layer is drawn once and kept, so none of this costs anything
## while the sand runs.

## The caps are wider than the tube, with a lip that fits inside it.
const CAP_OVERHANG := 13.0
const CAP_THICKNESS := 34.0

static var _outline := PackedVector2Array()


## Everything in front of the sand: the glass edge and the caps.
static func draw_front(canvas: CanvasItem, cap_color: Color = Color("#E5484D")) -> void:
	_prepare()
	_draw_glass_edge(canvas)
	_draw_cap(canvas, cap_color, true)
	_draw_cap(canvas, cap_color, false)


static func _prepare() -> void:
	if _outline.is_empty():
		_outline = HourglassShape.outline()


# ---------------------------------------------------------------- the caps

## A plastic cap: a flat disc a little wider than the tube, with a small hole in it,
## and a lip below it that fits inside the glass.
static func _draw_cap(canvas: CanvasItem, color: Color, at_top: bool) -> void:
	var direction := 1.0 if at_top else -1.0
	var edge := 0.0 if at_top else HourglassShape.HEIGHT
	var half := HourglassShape.TUBE_RADIUS
	# The lip, seen through the glass.
	_band(canvas, edge, edge + direction * HourglassShape.CAP_DEPTH, half, Color(color, 0.92))
	_band(canvas, edge + direction * (HourglassShape.CAP_DEPTH - 3.0), edge + direction * HourglassShape.CAP_DEPTH, half, color.darkened(0.3))
	# The disc.
	_band(canvas, edge, edge - direction * CAP_THICKNESS, half + CAP_OVERHANG, color)
	_band(canvas, edge - direction * (CAP_THICKNESS - 7.0), edge - direction * CAP_THICKNESS, half + CAP_OVERHANG, color.lightened(0.28))
	_band(canvas, edge, edge - direction * 5.0, half + CAP_OVERHANG, color.darkened(0.28))
	canvas.draw_circle(Vector2(0.0, edge - direction * CAP_THICKNESS * 0.5), 5.0, color.darkened(0.55))


static func _band(canvas: CanvasItem, from_y: float, to_y: float, half: float, color: Color) -> void:
	canvas.draw_rect(Rect2(-half, minf(from_y, to_y), half * 2.0, absf(to_y - from_y)), color)


# ---------------------------------------------------------------- the glass

static func _draw_glass_edge(canvas: CanvasItem) -> void:
	canvas.draw_polyline(_closed(_outline), Color(0.30, 0.34, 0.36, 0.55), 3.5, true)
	canvas.draw_polyline(_closed(HourglassShape.inset(_outline, 3.5)), Color(1.0, 0.98, 0.93, 0.62), 2.0, true)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
