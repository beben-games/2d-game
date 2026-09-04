extends GdUnitTestSuite

const BOUNDS := Rect2(16, 16, 608, 336)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_interval_ramps_from_start_to_min() -> void:
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 0.0)).is_equal(2.0)
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 30.0)).is_equal(1.25)
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 60.0)).is_equal(0.5)
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 500.0)).is_equal(0.5)


func test_positions_stay_inside_bounds_and_away_from_player() -> void:
	var rng := _rng(42)
	var player := BOUNDS.get_center()
	for i in 200:
		var p := SpawnMath.pick_position(BOUNDS, player, 96.0, rng)
		assert_bool(BOUNDS.has_point(p)).is_true()
		assert_float(p.distance_to(player)).is_greater_equal(96.0)


func test_same_seed_same_positions() -> void:
	var a := SpawnMath.pick_position(BOUNDS, Vector2.ZERO, 50.0, _rng(9))
	var b := SpawnMath.pick_position(BOUNDS, Vector2.ZERO, 50.0, _rng(9))
	assert_vector(a).is_equal(b)


func test_impossible_distance_still_returns_a_point_in_bounds() -> void:
	var p := SpawnMath.pick_position(BOUNDS, BOUNDS.get_center(), 10000.0, _rng(1))
	assert_bool(BOUNDS.has_point(p)).is_true()
