extends GdUnitTestSuite
## ViewRules, pure: whether a point is inside a view rect (edges included), and where a segment
## leaves one (the first edge crossed, its inward normal; a segment born outside hits at once
## with no normal to bounce off).

const VIEW := Rect2(0, 0, 100, 50)


func test_contains_the_inside_and_the_edges_but_nothing_past_them() -> void:
	assert_bool(ViewRules.contains(VIEW, Vector2(50, 25))).is_true()
	assert_bool(ViewRules.contains(VIEW, Vector2(0, 0))).is_true()
	assert_bool(ViewRules.contains(VIEW, Vector2(100, 50))).is_true()  # the far corner too
	assert_bool(ViewRules.contains(VIEW, Vector2(100.01, 25))).is_false()
	assert_bool(ViewRules.contains(VIEW, Vector2(50, -0.01))).is_false()


func test_a_segment_inside_does_not_hit() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(10, 10), Vector2(90, 40))
	assert_bool(edge.hit).is_false()


func test_a_segment_ending_on_the_edge_does_not_hit() -> void:
	assert_bool(ViewRules.exit(VIEW, Vector2(90, 25), Vector2(100, 25)).hit).is_false()


func test_leaving_by_the_right_edge() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(90, 20), Vector2(110, 30))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(100, 25))
	assert_vector(edge.normal).is_equal(Vector2.LEFT)


func test_leaving_by_the_left_edge() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(4, 20), Vector2(-4, 20))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(0, 20))
	assert_vector(edge.normal).is_equal(Vector2.RIGHT)


func test_leaving_by_the_top_edge() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(30, 5), Vector2(40, -5))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(35, 0))
	assert_vector(edge.normal).is_equal(Vector2.DOWN)


func test_leaving_by_the_bottom_edge() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(30, 45), Vector2(30, 55))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(30, 50))
	assert_vector(edge.normal).is_equal(Vector2.UP)


## Past two edges in one step: the first one crossed is the exit.
func test_the_first_edge_crossed_is_the_exit() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(95, 46), Vector2(115, 56))  # x crosses at t 0.25, y at 0.4
	assert_vector(edge.at).is_equal(Vector2(100, 48.5))
	assert_vector(edge.normal).is_equal(Vector2.LEFT)


## Through a corner exactly: both edges at once, the normal between them, so a bounce sends the
## shot back the way it came.
func test_a_corner_takes_both_normals() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(96, 46), Vector2(104, 54))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(100, 50))
	assert_vector(edge.normal).is_equal_approx(Vector2(-1, -1).normalized(), Vector2.ONE * 1e-6)
	assert_vector(Vector2(1, 1).normalized().bounce(edge.normal)).is_equal_approx(Vector2(-1, -1).normalized(), Vector2.ONE * 1e-6)


## Born outside (a bolt fired as the view scrolled away): it hits where it is, with no normal,
## whether it heads out or back in.
func test_a_segment_starting_outside_hits_at_its_start_with_no_normal() -> void:
	for to: Vector2 in [Vector2(130, 25), Vector2(90, 25)]:
		var edge := ViewRules.exit(VIEW, Vector2(110, 25), to)
		assert_bool(edge.hit).is_true()
		assert_vector(edge.at).is_equal(Vector2(110, 25))
		assert_vector(edge.normal).is_equal(Vector2.ZERO)


func test_a_segment_starting_on_the_edge_and_leaving_hits_where_it_starts() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(100, 25), Vector2(105, 25))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(100, 25))
	assert_vector(edge.normal).is_equal(Vector2.LEFT)
