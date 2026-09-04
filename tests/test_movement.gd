extends GdUnitTestSuite

const EPS := Vector2(0.001, 0.001)


func test_accelerates_toward_wish_direction() -> void:
	var v := Movement.step(Vector2.ZERO, Vector2.RIGHT, 100.0, 500.0, 800.0, 0.1)
	assert_vector(v).is_equal_approx(Vector2(50, 0), EPS)


func test_speed_is_capped_at_max() -> void:
	var v := Movement.step(Vector2.ZERO, Vector2.RIGHT, 100.0, 5000.0, 800.0, 0.1)
	assert_vector(v).is_equal_approx(Vector2(100, 0), EPS)


func test_diagonal_input_is_normalized() -> void:
	var v := Movement.step(Vector2.ZERO, Vector2(1, 1), 100.0, 5000.0, 800.0, 0.1)
	assert_float(v.length()).is_equal_approx(100.0, 0.001)


func test_friction_slows_when_no_input() -> void:
	var v := Movement.step(Vector2(100, 0), Vector2.ZERO, 100.0, 500.0, 800.0, 0.1)
	assert_vector(v).is_equal_approx(Vector2(20, 0), EPS)


func test_friction_stops_at_zero() -> void:
	var v := Movement.step(Vector2(10, 0), Vector2.ZERO, 100.0, 500.0, 800.0, 0.1)
	assert_vector(v).is_equal(Vector2.ZERO)


func test_is_moving_threshold() -> void:
	assert_bool(Movement.is_moving(Vector2(3, 0))).is_false()
	assert_bool(Movement.is_moving(Vector2(30, 0))).is_true()
