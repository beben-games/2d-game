extends GdUnitTestSuite
## The pure shield rules: which shots the front arc stops, and how fast the facing turns.

const ARC := 180.0
const THROUGH := 3


func test_a_shot_into_the_front_is_blocked() -> void:
	# The enemy faces left; a shot flying right arrives from its front.
	assert_bool(ShieldRules.blocks(Vector2.LEFT, Vector2.RIGHT, 0, ARC, THROUGH)).is_true()


func test_a_shot_into_the_back_lands() -> void:
	assert_bool(ShieldRules.blocks(Vector2.LEFT, Vector2.LEFT, 0, ARC, THROUGH)).is_false()


func test_the_arc_edge_is_half_the_arc_either_side_of_the_facing() -> void:
	# A 180 degree arc covers 90 degrees either side: 89 degrees off is inside, 91 is outside.
	var inside := -Vector2.LEFT.rotated(deg_to_rad(89.0))
	var outside := -Vector2.LEFT.rotated(deg_to_rad(91.0))
	assert_bool(ShieldRules.blocks(Vector2.LEFT, inside, 0, ARC, THROUGH)).is_true()
	assert_bool(ShieldRules.blocks(Vector2.LEFT, outside, 0, ARC, THROUGH)).is_false()
	# A narrower arc lets the same 89 degree shot through.
	assert_bool(ShieldRules.blocks(Vector2.LEFT, inside, 0, 90.0, THROUGH)).is_false()


func test_the_shipped_arc_blocks_to_60_degrees_from_the_facing() -> void:
	# The shipped 120 degree arc (playtest 1, note 5): 59 degrees off the facing is inside, 61 out.
	var shipped: EnemyDef = load("res://data/enemies/chaser_shield.tres")
	assert_float(shipped.shield_arc_degrees).is_equal(120.0)
	var inside := -Vector2.LEFT.rotated(deg_to_rad(59.0))
	var outside := -Vector2.LEFT.rotated(deg_to_rad(61.0))
	assert_bool(ShieldRules.blocks(Vector2.LEFT, inside, 0, shipped.shield_arc_degrees, THROUGH)).is_true()
	assert_bool(ShieldRules.blocks(Vector2.LEFT, outside, 0, shipped.shield_arc_degrees, THROUGH)).is_false()


func test_a_shot_that_could_pierce_three_passes() -> void:
	assert_bool(ShieldRules.blocks(Vector2.LEFT, Vector2.RIGHT, 2, ARC, THROUGH)).is_true()
	assert_bool(ShieldRules.blocks(Vector2.LEFT, Vector2.RIGHT, 3, ARC, THROUGH)).is_false()
	assert_bool(ShieldRules.blocks(Vector2.LEFT, Vector2.RIGHT, 6, ARC, THROUGH)).is_false()


func test_an_unnormalized_shot_direction_is_read_by_direction_only() -> void:
	assert_bool(ShieldRules.blocks(Vector2.LEFT, Vector2(340.0, 0.0), 0, ARC, THROUGH)).is_true()


func test_turn_clamps_to_the_step() -> void:
	var turned := ShieldRules.turn(Vector2.RIGHT, Vector2.UP, 30.0)
	assert_float(rad_to_deg(absf(Vector2.RIGHT.angle_to(turned)))).is_equal_approx(30.0, 0.001)
	assert_float(turned.length()).is_equal_approx(1.0, 0.001)
	# The step reaches the target: no overshoot.
	var there := ShieldRules.turn(Vector2.RIGHT, Vector2.UP, 200.0)
	assert_vector(there).is_equal_approx(Vector2.UP, Vector2(0.001, 0.001))


func test_turn_holds_on_a_zero_target() -> void:
	assert_vector(ShieldRules.turn(Vector2.LEFT, Vector2.ZERO, 30.0)).is_equal(Vector2.LEFT)


func test_turn_takes_the_short_way_round() -> void:
	# From right to down-left (225 degrees away the long way, 135 the short way): a 45 degree
	# step goes clockwise on screen (y down) through the bottom.
	var turned := ShieldRules.turn(Vector2.RIGHT, Vector2(-1.0, 1.0), 45.0)
	assert_float(turned.y).is_greater(0.0)
	assert_float(rad_to_deg(absf(Vector2.RIGHT.angle_to(turned)))).is_equal_approx(45.0, 0.001)


func test_bounce_mirrors_the_shot_across_the_facing() -> void:
	# The enemy faces left; a shot arriving down-right at 30 degrees leaves down-left: the part
	# along the facing flips, the part across it stays.
	var arriving := Vector2.RIGHT.rotated(deg_to_rad(30.0))
	var leaving := ShieldRules.bounce(arriving, Vector2.LEFT)
	assert_vector(leaving).is_equal_approx(Vector2(-arriving.x, arriving.y), Vector2(0.0001, 0.0001))
	# Head-on comes straight back.
	assert_vector(ShieldRules.bounce(Vector2.RIGHT, Vector2.LEFT)).is_equal_approx(Vector2.LEFT, Vector2(0.0001, 0.0001))


func test_bounce_reads_an_unnormalized_facing_by_direction_only() -> void:
	var arriving := Vector2(1, 1).normalized()
	var by_unit := ShieldRules.bounce(arriving, Vector2.UP)
	assert_vector(ShieldRules.bounce(arriving, Vector2.UP * 7.0)).is_equal_approx(by_unit, Vector2(0.0001, 0.0001))
	assert_vector(by_unit).is_equal_approx(Vector2(1, -1).normalized(), Vector2(0.0001, 0.0001))


func test_bounce_leaves_the_shot_unchanged_off_a_zero_facing() -> void:
	assert_vector(ShieldRules.bounce(Vector2.RIGHT, Vector2.ZERO)).is_equal(Vector2.RIGHT)


func test_a_bounced_shot_leaves_along_the_facing() -> void:
	# Any shot the arc stops arrives against the facing, so its reflection always moves away from
	# the shield, never back into it.
	for degrees in [-59.0, -30.0, 0.0, 30.0, 59.0]:
		var arriving := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		assert_bool(ShieldRules.blocks(Vector2.LEFT, arriving, 0, 120.0, THROUGH)).is_true()
		assert_float(ShieldRules.bounce(arriving, Vector2.LEFT).dot(Vector2.LEFT)).is_greater(0.0)
