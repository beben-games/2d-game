extends GdUnitTestSuite
## ArrowRules, pure: where an off-screen enemy's arrow sits on the screen (on the line from the
## player to it, an inset inside the screen's edge), which way it points, how faint it is near the
## edge, and arrows nudged apart along the edge so none overlaps another.

const SCREEN := Rect2(0, 0, 200, 100)
const INSET := 10.0
const AT := 0.001


func test_an_enemy_to_the_right_puts_the_arrow_on_the_right_edge_pointing_right() -> void:
	var arrow := ArrowRules.place(SCREEN, Vector2(100, 50), Vector2(400, 50), INSET)
	assert_vector(arrow.at).is_equal_approx(Vector2(190, 50), Vector2.ONE * AT)
	assert_float(arrow.angle).is_equal_approx(0.0, AT)


func test_an_enemy_to_the_left_puts_the_arrow_on_the_left_edge() -> void:
	var arrow := ArrowRules.place(SCREEN, Vector2(100, 50), Vector2(-300, 50), INSET)
	assert_vector(arrow.at).is_equal_approx(Vector2(10, 50), Vector2.ONE * AT)
	assert_float(absf(arrow.angle)).is_equal_approx(PI, AT)


func test_an_enemy_above_puts_the_arrow_on_the_top_edge_pointing_up() -> void:
	var arrow := ArrowRules.place(SCREEN, Vector2(100, 50), Vector2(100, -500), INSET)
	assert_vector(arrow.at).is_equal_approx(Vector2(100, 10), Vector2.ONE * AT)
	assert_float(arrow.angle).is_equal_approx(-PI / 2.0, AT)


func test_an_enemy_below_puts_the_arrow_on_the_bottom_edge() -> void:
	var arrow := ArrowRules.place(SCREEN, Vector2(100, 50), Vector2(100, 900), INSET)
	assert_vector(arrow.at).is_equal_approx(Vector2(100, 90), Vector2.ONE * AT)
	assert_float(arrow.angle).is_equal_approx(PI / 2.0, AT)


func test_the_arrow_is_on_the_line_from_the_player_to_the_enemy() -> void:
	var from := Vector2(60, 40)
	var to := Vector2(500, 140)
	var arrow := ArrowRules.place(SCREEN, from, to, INSET)
	assert_float(arrow.at.x).is_equal_approx(190.0, AT)  # leaves by the right edge
	var along: Vector2 = (arrow.at - from).normalized()
	assert_vector(along).is_equal_approx((to - from).normalized(), Vector2.ONE * AT)
	assert_float(arrow.angle).is_equal_approx((to - from).angle(), AT)


func test_an_enemy_off_a_corner_puts_the_arrow_in_the_corner() -> void:
	# Through the inset rect's bottom right corner (190, 90): 90 right and 40 down from the player.
	var arrow := ArrowRules.place(SCREEN, Vector2(100, 50), Vector2(1000, 450), INSET)
	assert_vector(arrow.at).is_equal_approx(Vector2(190, 90), Vector2.ONE * AT)
	assert_float(arrow.angle).is_equal_approx(atan2(40.0, 90.0), AT)


## The player inside the inset band (pressed on a wall at the screen's edge): the line starts from
## the player's point taken inside, and the arrow still sits on the inset rect.
func test_a_player_inside_the_inset_band_still_puts_the_arrow_on_the_inset_rect() -> void:
	var arrow := ArrowRules.place(SCREEN, Vector2(195, 50), Vector2(400, 20), INSET)
	assert_float(arrow.at.x).is_equal_approx(190.0, AT)
	assert_bool(SCREEN.grow(-INSET).grow(AT).has_point(arrow.at)).is_true()


func test_an_enemy_on_the_player_s_point_has_an_arrow_inside_the_screen() -> void:
	var arrow := ArrowRules.place(SCREEN, Vector2(100, 50), Vector2(100, 50), INSET)
	assert_bool(SCREEN.grow(-INSET).grow(AT).has_point(arrow.at)).is_true()


# --- The fade ---


func test_the_alpha_is_nothing_on_the_edge_and_full_a_fade_past_it() -> void:
	assert_float(ArrowRules.alpha(SCREEN, Vector2(200, 50), 20.0)).is_equal_approx(0.0, AT)
	assert_float(ArrowRules.alpha(SCREEN, Vector2(150, 50), 20.0)).is_equal_approx(0.0, AT)  # inside
	assert_float(ArrowRules.alpha(SCREEN, Vector2(210, 50), 20.0)).is_equal_approx(0.5, AT)
	assert_float(ArrowRules.alpha(SCREEN, Vector2(220, 50), 20.0)).is_equal_approx(1.0, AT)
	assert_float(ArrowRules.alpha(SCREEN, Vector2(900, 50), 20.0)).is_equal_approx(1.0, AT)


func test_the_alpha_past_a_corner_is_the_distance_to_the_corner() -> void:
	assert_float(ArrowRules.alpha(SCREEN, Vector2(206, -8), 20.0)).is_equal_approx(0.5, AT)  # 6, 8: 10 away


func test_the_alpha_of_a_fade_of_nothing_is_full_past_the_edge() -> void:
	assert_float(ArrowRules.alpha(SCREEN, Vector2(201, 50), 0.0)).is_equal_approx(1.0, AT)


# --- The spread ---


func test_points_a_gap_apart_or_more_are_untouched() -> void:
	var points: Array[Vector2] = [Vector2(50, 0), Vector2(80, 0), Vector2(200, 60)]
	var spread := ArrowRules.spread(SCREEN, points, 20.0)
	for i in points.size():
		assert_vector(spread[i]).is_equal_approx(points[i], Vector2.ONE * AT)


func test_two_overlapping_points_on_an_edge_are_nudged_apart_by_the_gap_about_their_middle() -> void:
	var points: Array[Vector2] = [Vector2(100, 0), Vector2(104, 0)]
	var spread := ArrowRules.spread(SCREEN, points, 20.0)
	assert_vector(spread[0]).is_equal_approx(Vector2(92, 0), Vector2.ONE * AT)
	assert_vector(spread[1]).is_equal_approx(Vector2(112, 0), Vector2.ONE * AT)


func test_a_pile_of_points_keeps_the_gap_and_its_order() -> void:
	var points: Array[Vector2] = [Vector2(0, 50), Vector2(0, 50), Vector2(0, 51), Vector2(0, 49)]
	var spread := ArrowRules.spread(SCREEN, points, 12.0)
	var ys: Array = spread.map(func(p: Vector2) -> float: return p.y)
	for p: Vector2 in spread:
		assert_float(p.x).is_equal_approx(0.0, AT)  # still on the left edge
	var sorted := ys.duplicate()
	sorted.sort()
	for i in sorted.size() - 1:
		assert_float(sorted[i + 1] - sorted[i]).is_greater_equal(12.0 - AT)
	assert_float(ys[3]).is_less(ys[2])  # the lowest y stays the topmost


## Two arrows in a corner, one on each edge: nudged along the edge, around the corner, apart.
func test_points_at_a_corner_are_nudged_apart_around_it() -> void:
	var points: Array[Vector2] = [Vector2(198, 0), Vector2(200, 3)]
	var spread := ArrowRules.spread(SCREEN, points, 20.0)
	assert_float(spread[0].distance_to(spread[1])).is_greater_equal(10.0)
	for p: Vector2 in spread:
		var on_edge := absf(p.x - 200.0) < AT or absf(p.y) < AT
		assert_bool(on_edge).override_failure_message("%s off the edge" % p).is_true()
	assert_float(spread[0].y).is_equal_approx(0.0, AT)  # the top one moved left along the top
	assert_float(spread[0].x).is_less(198.0)
	assert_float(spread[1].x).is_equal_approx(200.0, AT)  # the side one moved down the side
	assert_float(spread[1].y).is_greater(3.0)


func test_no_points_and_one_point_are_untouched() -> void:
	var none: Array[Vector2] = []
	assert_array(ArrowRules.spread(SCREEN, none, 20.0)).is_empty()
	var one: Array[Vector2] = [Vector2(0, 30)]
	assert_vector(ArrowRules.spread(SCREEN, one, 20.0)[0]).is_equal_approx(Vector2(0, 30), Vector2.ONE * AT)


func test_more_points_than_the_edge_holds_spread_evenly_around_it() -> void:
	var small := Rect2(0, 0, 10, 10)  # 40 around
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]
	var spread := ArrowRules.spread(small, points, 20.0)
	for i in spread.size():
		for j in range(i + 1, spread.size()):
			assert_float(spread[i].distance_to(spread[j])).is_greater(1.0)
