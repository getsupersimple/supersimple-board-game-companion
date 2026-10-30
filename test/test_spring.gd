extends GutTest


func test_a_spring_settles_on_its_target_after_overshooting() -> void:
	var spring := Spring.new(0.0)
	spring.target = 100.0
	var highest := 0.0
	for i in 120:
		spring.step(1.0 / 60.0)
		highest = maxf(highest, spring.value)
	assert_gt(highest, 100.0, "it springs past the target")
	assert_almost_eq(spring.value, 100.0, 0.5)
	assert_true(spring.is_settled())


func test_a_spring_carries_a_point_and_snap_stops_it() -> void:
	var spring := Spring.new(Vector2.ZERO)
	spring.target = Vector2(50, -20)
	for i in 180:
		spring.step(1.0 / 60.0)
	assert_almost_eq(spring.value.x, 50.0, 0.5)
	assert_almost_eq(spring.value.y, -20.0, 0.5)
	spring.snap(Vector2(3, 3))
	assert_eq(spring.value, Vector2(3, 3))
	assert_true(spring.is_settled())
