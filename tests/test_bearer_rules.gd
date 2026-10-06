extends GdUnitTestSuite
## The standard-bearer's rules (BearerRules, pure): who its banner covers, and where it stands:
## behind the nearest of its pack from the player, never inside its flee range; with no pack it
## has no stand and walks at the player.

const KEEP := 40.0
const FLEE := 96.0
## Floor bounds no stand in these cases reaches.
const OPEN := Rect2(-1000, -1000, 2000, 2000)


func _points(values: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Vector2 in values:
		out.append(v)
	return out


func test_the_cover_holds_at_the_radius_s_edge_and_not_past_it() -> void:
	var centre := Vector2(100, 100)
	var positions := _points([Vector2(240, 100), Vector2(240.5, 100), Vector2(100, 100), Vector2(100, -40), Vector2(0, 100), Vector2(1, 1)])
	assert_array(BearerRules.covered(centre, 140.0, positions)).contains_exactly([0, 2, 3, 4])


func test_nothing_is_covered_with_no_positions_or_no_radius() -> void:
	assert_array(BearerRules.covered(Vector2.ZERO, 140.0, _points([]))).is_empty()
	assert_array(BearerRules.covered(Vector2.ZERO, 0.0, _points([Vector2(1, 0)]))).is_empty()


## The stand is on the ray from the player through the nearest of the pack, KEEP past it: walking
## there puts that enemy between the bearer and the player.
func test_the_stand_puts_the_nearest_of_the_pack_between_it_and_the_player() -> void:
	var player := Vector2.ZERO
	var pack := _points([Vector2(150, 0), Vector2(0, 300)])  # the first is the bearer's nearest
	var at := Vector2(150, 120)
	var wish := BearerRules.stand(player, pack, at, KEEP, FLEE, OPEN)
	var spot := Vector2(190, 0)
	assert_vector(wish).is_equal_approx(spot - at, Vector2(0.001, 0.001))
	# From the spot, the nearest enemy lies on the segment to the player.
	var to_player := player - spot
	var to_enemy := pack[0] - spot
	assert_float(to_enemy.normalized().dot(to_player.normalized())).is_equal_approx(1.0, 0.0001)
	assert_float(to_enemy.length()).is_less(to_player.length())


func test_the_nearest_is_the_bearer_s_nearest_not_the_player_s() -> void:
	var pack := _points([Vector2(30, 0), Vector2(0, 200)])
	var at := Vector2(0, 260)
	var wish := BearerRules.stand(Vector2.ZERO, pack, at, KEEP, FLEE, OPEN)
	assert_vector(at + wish).is_equal_approx(Vector2(0, 240), Vector2(0.001, 0.001))


## A pack pressed on the player would put the stand inside the flee range: it is held at it.
func test_the_stand_is_never_inside_the_flee_range() -> void:
	var pack := _points([Vector2(20, 0)])
	var at := Vector2(200, 0)
	var wish := BearerRules.stand(Vector2.ZERO, pack, at, KEEP, FLEE, OPEN)
	assert_vector(at + wish).is_equal_approx(Vector2(FLEE, 0), Vector2(0.001, 0.001))


func test_inside_the_flee_range_it_backs_away_from_the_player() -> void:
	var pack := _points([Vector2(-150, 0)])  # its stand is on the far side
	var at := Vector2(50, 30)
	var wish := BearerRules.stand(Vector2.ZERO, pack, at, KEEP, FLEE, OPEN)
	assert_float(wish.normalized().dot(at.normalized())).is_equal_approx(1.0, 0.0001)


func test_at_its_stand_it_holds_still() -> void:
	var pack := _points([Vector2(150, 0)])
	var at := Vector2(190 + BearerRules.ARRIVE * 0.5, 0)
	assert_vector(BearerRules.stand(Vector2.ZERO, pack, at, KEEP, FLEE, OPEN)).is_equal(Vector2.ZERO)


## The last-alive rule: with no pack there is no stand and no flight; it walks at the player.
func test_alone_it_has_no_stand_and_walks_at_the_player() -> void:
	var at := Vector2(50, 0)  # inside the flee range, which no longer counts
	assert_vector(BearerRules.stand(Vector2(10, 0), _points([]), at, KEEP, FLEE, OPEN)).is_equal(Vector2(-40, 0))


## A pack member on the player's own spot has no direction from it: the bearer's side is used.
func test_a_pack_member_on_the_player_takes_the_bearer_s_side() -> void:
	var pack := _points([Vector2.ZERO])
	var at := Vector2(0, 200)
	var wish := BearerRules.stand(Vector2.ZERO, pack, at, KEEP, FLEE, OPEN)
	assert_vector(at + wish).is_equal_approx(Vector2(0, FLEE), Vector2(0.001, 0.001))


func test_it_eases_into_its_stand() -> void:
	assert_float(BearerRules.arrive_speed(95.0, 600.0, 100.0)).is_equal(95.0)
	assert_float(BearerRules.arrive_speed(95.0, 600.0, 3.0)).is_equal_approx(60.0, 0.001)
	assert_float(BearerRules.arrive_speed(95.0, 600.0, 0.0)).is_equal(0.0)


## The anchor holds: a pack member nearer by less than ANCHOR_SLACK does not take it (no flip from
## tick to tick between two enemies at about the same distance); one nearer by more does.
func test_a_near_tie_does_not_flip_the_anchor() -> void:
	var at := Vector2.ZERO
	var held := _points([Vector2(50, 0), Vector2(0, 50 - BearerRules.ANCHOR_SLACK + 1.0)])
	assert_int(BearerRules.anchor(held, at, 0)).is_equal(0)
	var taken := _points([Vector2(50, 0), Vector2(0, 50 - BearerRules.ANCHOR_SLACK - 1.0)])
	assert_int(BearerRules.anchor(taken, at, 0)).is_equal(1)
	assert_int(BearerRules.anchor(held, at, -1)).is_equal(1)  # no anchor yet: the nearest
	assert_int(BearerRules.anchor(_points([]), at, -1)).is_equal(-1)


func test_the_stand_follows_the_anchor_it_is_given() -> void:
	var pack := _points([Vector2(150, 0), Vector2(0, 150)])
	var at := Vector2(150, 140)
	var wish := BearerRules.stand(Vector2.ZERO, pack, at, KEEP, FLEE, OPEN, 1)
	assert_vector(at + wish).is_equal_approx(Vector2(0, 190), Vector2(0.001, 0.001))


## A spot behind a wall is pulled onto the floor, EDGE inside its bounds.
func test_a_spot_behind_a_wall_is_clamped_onto_the_floor() -> void:
	var floor_rect := Rect2(0, 0, 400, 200)
	var player := Vector2(200, 100)
	var pack := _points([Vector2(370, 100)])  # the stand would be at x 410, past the right wall
	var at := Vector2(300, 60)
	var wish := BearerRules.stand(player, pack, at, KEEP, FLEE, floor_rect)
	assert_vector(at + wish).is_equal_approx(Vector2(400 - BearerRules.EDGE, 100), Vector2(0.001, 0.001))
