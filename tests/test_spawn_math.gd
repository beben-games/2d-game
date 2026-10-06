extends GdUnitTestSuite

const BOUNDS := Rect2(16, 16, 608, 336)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


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


# --- Rule 2: spawns inside the floor's part in view (the M7 design's "The big arena") ---

## Tier 1's floor (28x15) and its rules' view (View.rect: the 426.7x240 screen grown by a tile),
## which covers it wherever the camera sits inside the room.
const TIER_1_FLOOR := Rect2(16, 32, 416, 192)
const TIER_1_VIEW := Rect2(-16, -16, 458.6667, 272)
## A two-screen floor (56x30) and a view inside it that cuts all four of its sides.
const WIDE_FLOOR := Rect2(16, 32, 864, 432)
const WIDE_SCREEN := Rect2(300, 150, 426.6667, 240)


func _wide_view() -> Rect2:
	return WIDE_SCREEN.grow(16.0)


## Where the view covers the floor (tier 1) the pick is the bounds-only rule's, draw for draw:
## the same points and the stream left in the same state.
func test_a_view_covering_the_floor_picks_as_the_bounds_only_rule() -> void:
	var a := _rng(77)
	var b := _rng(77)
	var player := TIER_1_FLOOR.get_center()
	for i in 200:
		var p := SpawnMath.pick_in_view(TIER_1_FLOOR, TIER_1_VIEW, player, 96.0, a)
		var q := SpawnMath.pick_position(TIER_1_FLOOR, player, 96.0, b)
		assert_vector(p).is_equal(q)
		assert_int(a.state).is_equal(b.state)
		player = q  # the player wanders, as in a fight
	for i in 50:  # an impossible distance: the farthest candidate, still the same
		var p := SpawnMath.pick_in_view(TIER_1_FLOOR, TIER_1_VIEW, player, 10000.0, a)
		assert_vector(p).is_equal(SpawnMath.pick_position(TIER_1_FLOOR, player, 10000.0, b))


func test_picks_stay_in_the_floor_in_view_away_from_the_player_near_the_view_edge() -> void:
	var rng := _rng(42)
	var view := _wide_view()
	var region := WIDE_FLOOR.intersection(view)
	var player := WIDE_SCREEN.get_center()
	for i in 200:
		var p := SpawnMath.pick_in_view(WIDE_FLOOR, view, player, 96.0, rng)
		assert_bool(region.has_point(p)).override_failure_message("%s outside %s" % [p, region]).is_true()
		assert_float(p.distance_to(player)).is_greater_equal(96.0)
		var to_edge := minf(minf(p.x - view.position.x, view.end.x - p.x), minf(p.y - view.position.y, view.end.y - p.y))
		assert_float(to_edge).is_less_equal(SpawnMath.VIEW_BAND)


## Only the view's edges that cut the floor make the band: with the view against the floor's left
## and top walls, a pick lands near the view's right or bottom edge, never near a wall for it.
func test_the_band_follows_only_the_view_edges_inside_the_floor() -> void:
	var rng := _rng(3)
	var view := Rect2(0, 16, 458.6667, 272)  # its left and top past the floor's
	var player := Vector2(150, 140)
	for i in 100:
		var p := SpawnMath.pick_in_view(WIDE_FLOOR, view, player, 96.0, rng)
		var to_open := minf(view.end.x - p.x, view.end.y - p.y)
		assert_float(to_open).is_less_equal(SpawnMath.VIEW_BAND)


func test_a_floor_in_view_too_small_for_the_distance_gives_its_farthest_point_inside_it() -> void:
	var view := Rect2(400, 200, 60, 60)
	var region := WIDE_FLOOR.intersection(view)
	var p := SpawnMath.pick_in_view(WIDE_FLOOR, view, region.get_center(), 96.0, _rng(1))
	assert_bool(region.has_point(p)).is_true()


func test_the_floor_in_view_is_the_overlap_or_the_floor_for_an_empty_view() -> void:
	assert_object(SpawnMath.floor_in_view(TIER_1_FLOOR, TIER_1_VIEW)).is_equal(TIER_1_FLOOR)
	assert_object(SpawnMath.floor_in_view(WIDE_FLOOR, _wide_view())).is_equal(_wide_view())
	assert_object(SpawnMath.floor_in_view(WIDE_FLOOR, Rect2())).is_equal(WIDE_FLOOR)


## The boss's seat: tier 1's today (the floor's top centre, a tile and a half down); in a wide
## arena the top centre of the floor in view, never nearer the screen's top than tier 1's seat is.
func test_the_boss_seat_is_the_top_centre_of_the_floor_in_view() -> void:
	var tier_1_screen := Rect2(0, 0, 426.6667, 240)
	assert_vector(SpawnMath.boss_seat(TIER_1_FLOOR, TIER_1_VIEW, tier_1_screen)) \
		.is_equal(Vector2(TIER_1_FLOOR.get_center().x, TIER_1_FLOOR.position.y + ArenaGrid.TILE * 1.5))
	var seat := SpawnMath.boss_seat(WIDE_FLOOR, _wide_view(), WIDE_SCREEN)
	assert_float(seat.x).is_equal_approx(WIDE_SCREEN.get_center().x, 0.001)
	assert_float(seat.y - WIDE_SCREEN.position.y).is_equal_approx(SpawnMath.SEAT_UNDER_SCREEN, 0.001)
	var at_top := Rect2(WIDE_SCREEN.position.x, 0, WIDE_SCREEN.size.x, WIDE_SCREEN.size.y)
	seat = SpawnMath.boss_seat(WIDE_FLOOR, at_top.grow(16.0), at_top)
	assert_float(seat.y).is_equal_approx(WIDE_FLOOR.position.y + SpawnMath.SEAT_DEPTH, 0.001)


func test_the_side_points_are_the_floor_in_view_s_sides_a_tile_in() -> void:
	assert_array(SpawnMath.side_points(TIER_1_FLOOR, TIER_1_VIEW)).is_equal([
		Vector2(TIER_1_FLOOR.position.x + ArenaGrid.TILE, TIER_1_FLOOR.get_center().y),
		Vector2(TIER_1_FLOOR.end.x - ArenaGrid.TILE, TIER_1_FLOOR.get_center().y)])
	var view := _wide_view()
	assert_array(SpawnMath.side_points(WIDE_FLOOR, view)).is_equal([
		Vector2(view.position.x + ArenaGrid.TILE, view.get_center().y),
		Vector2(view.end.x - ArenaGrid.TILE, view.get_center().y)])


## Several bodies sit spread along the seat's row: the floor in view's width cut in count + 1,
## the one body of tier 1 at the centre as before.
func test_several_bodies_seats_spread_along_the_top() -> void:
	var tier_1_screen := Rect2(0, 0, 426.6667, 240)
	var one := SpawnMath.boss_seat(TIER_1_FLOOR, TIER_1_VIEW, tier_1_screen)
	assert_vector(SpawnMath.boss_seat(TIER_1_FLOOR, TIER_1_VIEW, tier_1_screen, 0, 1)).is_equal(one)
	var region := SpawnMath.floor_in_view(TIER_1_FLOOR, TIER_1_VIEW)
	var left := SpawnMath.boss_seat(TIER_1_FLOOR, TIER_1_VIEW, tier_1_screen, 0, 2)
	var right := SpawnMath.boss_seat(TIER_1_FLOOR, TIER_1_VIEW, tier_1_screen, 1, 2)
	assert_float(left.y).is_equal(one.y)
	assert_float(right.y).is_equal(one.y)
	assert_float(left.x).is_equal_approx(region.position.x + region.size.x / 3.0, 0.001)
	assert_float(right.x).is_equal_approx(region.position.x + region.size.x * 2.0 / 3.0, 0.001)
	var view := _wide_view()
	var wide_right := SpawnMath.boss_seat(WIDE_FLOOR, view, WIDE_SCREEN, 1, 2)
	assert_float(wide_right.x).is_equal_approx(view.position.x + view.size.x * 2.0 / 3.0, 0.001)
