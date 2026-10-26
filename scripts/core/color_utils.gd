class_name ColorUtils
extends RefCounted
## Colour helpers. Contrast colours keep icons and numerals readable on any
## user-chosen background.


## Returns black or white, whichever reads better on `background`.
static func contrast_color(background: Color) -> Color:
	return Color.BLACK if background.get_luminance() > 0.5 else Color.WHITE
