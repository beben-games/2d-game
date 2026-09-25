extends GdUnitTestSuite
## PileRules: how a thrown sum splits into piles and where the piles land.

var BOUNDS := ArenaGrid.bounds(28, 15)  ## the arena's floor (not a constant expression, so a var)


func test_split_spreads_the_remainder_over_the_first_piles() -> void:
	assert_array(PileRules.split(10, 4)).is_equal([3, 3, 2, 2])
	assert_array(PileRules.split(12, 4)).is_equal([3, 3, 3, 3])
	assert_array(PileRules.split(7, 3)).is_equal([3, 2, 2])
	assert_array(PileRules.split(5, 0)).is_empty()


func test_pile_count_runs_from_four_to_eight_and_never_past_the_coins() -> void:
	assert_int(PileRules.pile_count(8)).is_equal(4)
	assert_int(PileRules.pile_count(12)).is_equal(4)
	assert_int(PileRules.pile_count(40)).is_equal(5)
	assert_int(PileRules.pile_count(60)).is_equal(8)
	assert_int(PileRules.pile_count(200)).is_equal(8)
	assert_int(PileRules.pile_count(2)).is_equal(2)  # no empty pile
	assert_int(PileRules.pile_count(0)).is_equal(0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_spots_lie_inside_the_shrunk_bounds_and_within_the_radius() -> void:
	var inner := BOUNDS.grow(-PileRules.EDGE)
	var centre := BOUNDS.get_center()
	var spots := PileRules.spots(centre, PileRules.PILE_RADIUS, 8, BOUNDS, _rng(3))
	assert_int(spots.size()).is_equal(8)
	for spot in spots:
		assert_bool(inner.has_point(spot)).override_failure_message("outside: %s" % spot).is_true()
		assert_float(spot.distance_to(centre)).is_less_equal(PileRules.PILE_RADIUS)


func test_spots_near_a_wall_are_clamped_inside_and_still_within_the_radius() -> void:
	var inner := BOUNDS.grow(-PileRules.EDGE)
	var corner := BOUNDS.position + Vector2(4, 4)  # the player against the top-left wall, inside the edge band
	var centre := corner.clamp(inner.position, inner.end)  # the throw's centre is brought inside first
	var spots := PileRules.spots(corner, PileRules.PILE_RADIUS, 6, BOUNDS, _rng(11))
	for spot in spots:
		assert_bool(inner.has_point(spot)).override_failure_message("outside: %s" % spot).is_true()
		assert_float(spot.distance_to(centre)).is_less_equal(PileRules.PILE_RADIUS)


func test_spots_keep_their_distance_when_the_room_allows() -> void:
	var spots := PileRules.spots(BOUNDS.get_center(), PileRules.PILE_RADIUS, 8, BOUNDS, _rng(5))
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_float(spots[i].distance_to(spots[j])).is_greater_equal(PileRules.MIN_GAP)


func test_spots_are_seeded() -> void:
	var a := PileRules.spots(BOUNDS.get_center(), PileRules.PILE_RADIUS, 5, BOUNDS, _rng(42))
	var b := PileRules.spots(BOUNDS.get_center(), PileRules.PILE_RADIUS, 5, BOUNDS, _rng(42))
	var c := PileRules.spots(BOUNDS.get_center(), PileRules.PILE_RADIUS, 5, BOUNDS, _rng(43))
	assert_array(a).is_equal(b)
	assert_array(a).is_not_equal(c)
