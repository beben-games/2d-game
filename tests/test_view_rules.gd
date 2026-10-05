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


## Through a corner exactly: both edges at once, both inward normals in one (each component -1,
## 0, or 1: not a unit vector, so reflect, never Vector2.bounce).
func test_a_corner_takes_both_normals() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(96, 46), Vector2(104, 54))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(100, 50))
	assert_vector(edge.normal).is_equal(Vector2(-1, -1))


## Off the diagonal through a corner: both components turn back, (1, 0.2) leaves as (-1, -0.2).
func test_a_corner_bounce_reverses_both_components() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(95, 49), Vector2(105, 51))  # through (100, 50) at half the step
	assert_vector(edge.at).is_equal(Vector2(100, 50))
	assert_vector(edge.normal).is_equal(Vector2(-1, -1))
	var heading := Vector2(1, 0.2).normalized()
	assert_vector(ViewRules.reflect(heading, edge.normal)).is_equal_approx(-heading, Vector2.ONE * 1e-6)


func test_reflect_turns_back_only_what_heads_out() -> void:
	var heading := Vector2(0.6, 0.8)
	assert_vector(ViewRules.reflect(heading, Vector2.LEFT)).is_equal(Vector2(-0.6, 0.8))  # off the right edge
	assert_vector(ViewRules.reflect(heading, Vector2.UP)).is_equal(Vector2(0.6, -0.8))  # off the bottom
	assert_vector(ViewRules.reflect(heading, Vector2.RIGHT)).is_equal(heading)  # already heading in from the left
	assert_vector(ViewRules.reflect(heading, Vector2(1, -1))).is_equal(Vector2(0.6, -0.8))  # a corner: only y heads out


## Outside the view at the step's start (overtaken by the edge as the view shifted, or born there):
## a hit on the rect at the nearest point, with the inward normal of the side it is outside of.
func test_a_segment_starting_outside_hits_on_the_rect_with_the_inward_normal() -> void:
	# [from, where it lands on the rect, the inward normal]
	var cases := [
		[Vector2(-5, 20), Vector2(0, 20), Vector2.RIGHT],
		[Vector2(110, 25), Vector2(100, 25), Vector2.LEFT],
		[Vector2(30, -3), Vector2(30, 0), Vector2.DOWN],
		[Vector2(30, 58), Vector2(30, 50), Vector2.UP],
		[Vector2(104, -2), Vector2(100, 0), Vector2(-1, 1)],  # the corner region: both sides
	]
	for case: Array in cases:
		for to: Vector2 in [case[0] + Vector2(3, 3), Vector2(50, 25)]:  # heading anywhere, in or out
			var edge := ViewRules.exit(VIEW, case[0], to)
			assert_bool(edge.hit).is_true()
			assert_vector(edge.at).override_failure_message("%s" % [case]).is_equal(case[1])
			assert_vector(edge.normal).override_failure_message("%s" % [case]).is_equal(case[2])


func test_a_segment_starting_on_the_edge_and_leaving_hits_where_it_starts() -> void:
	var edge := ViewRules.exit(VIEW, Vector2(100, 25), Vector2(105, 25))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(100, 25))
	assert_vector(edge.normal).is_equal(Vector2.LEFT)


## An empty rect (View's for a node outside the tree) contains nothing, its own corner included, and
## any step hits it where it starts with no normal.
func test_an_empty_rect_contains_nothing_and_every_step_hits() -> void:
	assert_bool(ViewRules.contains(Rect2(), Vector2.ZERO)).is_false()
	assert_bool(ViewRules.contains(Rect2(), Vector2(5, 5))).is_false()
	var edge := ViewRules.exit(Rect2(), Vector2(5, 5), Vector2(6, 5))
	assert_bool(edge.hit).is_true()
	assert_vector(edge.at).is_equal(Vector2(5, 5))
	assert_vector(edge.normal).is_equal(Vector2.ZERO)
