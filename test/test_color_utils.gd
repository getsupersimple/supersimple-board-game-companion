extends GutTest


func test_light_background_gets_black() -> void:
	assert_eq(ColorUtils.contrast_color(Color.WHITE), Color.BLACK)
	assert_eq(ColorUtils.contrast_color(Color.YELLOW), Color.BLACK)


func test_dark_background_gets_white() -> void:
	assert_eq(ColorUtils.contrast_color(Color.BLACK), Color.WHITE)
	assert_eq(ColorUtils.contrast_color(Color.NAVY_BLUE), Color.WHITE)
