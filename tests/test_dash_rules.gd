extends GdUnitTestSuite


func test_can_start_needs_a_charge_and_no_dash_in_flight() -> void:
	assert_bool(DashRules.can_start(1, false)).is_true()
	assert_bool(DashRules.can_start(0, false)).is_false()
	assert_bool(DashRules.can_start(2, true)).is_false()


func test_refill_restores_one_charge_per_cooldown() -> void:
	assert_array(DashRules.refill(0, 2, 0.6, 0.3)).is_equal([0, 0.3])
	assert_array(DashRules.refill(0, 2, 0.3, 0.3)).is_equal([1, DashRules.COOLDOWN])  # one back, the next clock starts
	assert_array(DashRules.refill(0, 2, 0.1, 0.3)).is_equal([1, DashRules.COOLDOWN])  # the overshoot is dropped, not carried
	assert_array(DashRules.refill(1, 2, 0.6, 0.6)).is_equal([2, 0.0])  # full: no clock
	assert_array(DashRules.refill(2, 2, 0.0, 1.0)).is_equal([2, 0.0])
	assert_array(DashRules.refill(0, 1, 0.1, 0.1)).is_equal([1, 0.0])  # the one-charge case is today's dash


func test_direction_prefers_movement_and_falls_back_to_aim() -> void:
	assert_vector(DashRules.direction(Vector2(0, 2), Vector2.RIGHT)).is_equal(Vector2(0, 1))
	assert_vector(DashRules.direction(Vector2.ZERO, Vector2(3, 0))).is_equal(Vector2(1, 0))


func test_constants_are_a_short_fast_burst() -> void:
	assert_float(DashRules.SPEED).is_equal(330.0)
	assert_float(DashRules.DURATION).is_equal(0.15)
	assert_float(DashRules.COOLDOWN).is_equal(0.6)
