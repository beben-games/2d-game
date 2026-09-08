extends GdUnitTestSuite


func test_can_start_only_off_cooldown_and_not_already_dashing() -> void:
	assert_bool(DashRules.can_start(0.0, false)).is_true()
	assert_bool(DashRules.can_start(0.2, false)).is_false()
	assert_bool(DashRules.can_start(0.0, true)).is_false()


func test_direction_prefers_movement_and_falls_back_to_aim() -> void:
	assert_vector(DashRules.direction(Vector2(0, 2), Vector2.RIGHT)).is_equal(Vector2(0, 1))
	assert_vector(DashRules.direction(Vector2.ZERO, Vector2(3, 0))).is_equal(Vector2(1, 0))


func test_constants_are_a_short_fast_burst() -> void:
	assert_float(DashRules.SPEED).is_equal(330.0)
	assert_float(DashRules.DURATION).is_equal(0.15)
	assert_float(DashRules.COOLDOWN).is_equal(0.6)
