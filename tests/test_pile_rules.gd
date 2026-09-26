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


## Inside the rect, its far edges included (Rect2.has_point excludes them, and a clamped spot
## sits exactly on one).
func _inside(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A wide floor: every spot lies in the ring, past the pull's reach and within RING_MAX.
func test_spots_lie_in_the_ring_beyond_the_pull_on_an_open_floor() -> void:
	var wide := Rect2(0, 0, 800, 800)
	var centre := wide.get_center()
	var spots := PileRules.spots(centre, 8, wide, _rng(3))
	assert_int(spots.size()).is_equal(8)
	for spot in spots:
		var d := spot.distance_to(centre)
		assert_float(d).override_failure_message("inside the pull: %s at %.1f" % [spot, d]).is_greater_equal(PileRules.RING_MIN)
		assert_float(d).override_failure_message("past the ring: %s at %.1f" % [spot, d]).is_less_equal(PileRules.RING_MAX)
	assert_float(PileRules.RING_MIN).is_equal(PileRules.PULL_RADIUS + PileRules.RING_GAP)


## The arena's floor is 176 px tall inside the edge band: the ring's top and bottom are off it,
## so the spots fall on the reachable sides, still inside the shrunk bounds and past the pull.
func test_spots_on_the_arena_floor_stay_inside_and_past_the_pull() -> void:
	var inner := BOUNDS.grow(-PileRules.EDGE)
	var centre := BOUNDS.get_center()
	var spots := PileRules.spots(centre, 8, BOUNDS, _rng(3))
	assert_int(spots.size()).is_equal(8)
	for spot in spots:
		assert_bool(_inside(inner, spot)).override_failure_message("outside: %s" % spot).is_true()
		assert_float(spot.distance_to(centre)).is_greater_equal(PileRules.RING_MIN)
		assert_float(spot.distance_to(centre)).is_less_equal(PileRules.RING_MAX)


func test_spots_near_a_wall_land_on_the_open_side_past_the_pull() -> void:
	var inner := BOUNDS.grow(-PileRules.EDGE)
	var near := BOUNDS.position + Vector2(20, BOUNDS.size.y * 0.5)  # 20 px from the left wall, mid-height
	var spots := PileRules.spots(near, 6, BOUNDS, _rng(11))
	assert_int(spots.size()).is_equal(6)
	for spot in spots:
		assert_bool(_inside(inner, spot)).override_failure_message("outside: %s" % spot).is_true()
		assert_float(spot.distance_to(near)).is_greater_equal(PileRules.RING_MIN)
		assert_float(spot.x).is_greater(near.x)  # the open side


## A centre inside the edge band is brought inside first, as before.
func test_spots_from_a_corner_are_inside_and_past_the_pull() -> void:
	var inner := BOUNDS.grow(-PileRules.EDGE)
	var corner := BOUNDS.position + Vector2(4, 4)
	var centre := corner.clamp(inner.position, inner.end)
	var spots := PileRules.spots(corner, 6, BOUNDS, _rng(11))
	for spot in spots:
		assert_bool(_inside(inner, spot)).override_failure_message("outside: %s" % spot).is_true()
		assert_float(spot.distance_to(centre)).is_greater_equal(PileRules.RING_MIN)


func test_spots_keep_their_distance_when_the_room_allows() -> void:
	var spots := PileRules.spots(BOUNDS.get_center(), 8, BOUNDS, _rng(5))
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_float(spots[i].distance_to(spots[j])).is_greater_equal(PileRules.MIN_GAP)


func test_spots_are_seeded() -> void:
	var a := PileRules.spots(BOUNDS.get_center(), 5, BOUNDS, _rng(42))
	var b := PileRules.spots(BOUNDS.get_center(), 5, BOUNDS, _rng(42))
	var c := PileRules.spots(BOUNDS.get_center(), 5, BOUNDS, _rng(43))
	assert_array(a).is_equal(b)
	assert_array(a).is_not_equal(c)
