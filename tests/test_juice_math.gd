extends GdUnitTestSuite


func test_no_trauma_no_shake() -> void:
	assert_vector(JuiceMath.shake_offset(0.0, 8.0, 1.0, 1.0)).is_equal(Vector2.ZERO)


func test_full_trauma_uses_full_offset() -> void:
	assert_vector(JuiceMath.shake_offset(1.0, 8.0, 1.0, -1.0)).is_equal(Vector2(8, -8))


func test_shake_is_quadratic_in_trauma() -> void:
	assert_vector(JuiceMath.shake_offset(0.5, 8.0, 1.0, 1.0)).is_equal(Vector2(2, 2))


func test_trauma_above_one_is_clamped() -> void:
	assert_vector(JuiceMath.shake_offset(3.0, 8.0, 1.0, 1.0)).is_equal(Vector2(8, 8))


func test_decay_floors_at_zero() -> void:
	assert_float(JuiceMath.decay(0.5, 2.0, 0.1)).is_equal_approx(0.3, 0.0001)
	assert_float(JuiceMath.decay(0.1, 2.0, 1.0)).is_equal(0.0)
