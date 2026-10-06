extends GdUnitTestSuite
## The lifts' rules (pure, M7 Task 11): a lift's id names its tier ("lift:<tier>"), read back by
## tier_of (0 for anything that is no lift); the open bays are the tiers the save may fight that
## have a series; the bay that rises at a showing is the newest open one, once, while it is above
## the lifts seen.

const BAYS: Array[int] = [2, 1, 3]


func test_a_lifts_id_names_its_tier() -> void:
	assert_str(Lift.id_for(1)).is_equal("lift:1")
	assert_str(Lift.id_for(2)).is_equal("lift:2")
	for tier in [1, 2, 3, 12]:
		assert_int(Lift.tier_of(Lift.id_for(tier))).is_equal(tier)


func test_anything_else_is_no_lift() -> void:
	for id: String in ["lift", "lift:", "lift:0", "lift:-1", "lift:x", "lift:2a", "lift:1:2", "door:hypogeum", "post", "", "lifts:2"]:
		assert_int(Lift.tier_of(id)).override_failure_message(id).is_equal(0)


func test_the_open_bays_are_the_tiers_unlocked_that_have_a_series() -> void:
	assert_array(Lift.open_tiers(BAYS, 1)).is_equal([1])
	assert_array(Lift.open_tiers(BAYS, 2)).is_equal([2, 1])
	assert_array(Lift.open_tiers(BAYS, 3)).is_equal([2, 1])  # tier 3 has no series in phase 1
	assert_array(Lift.open_tiers(BAYS, 0)).is_empty()


func test_the_newest_open_bay_rises_once_above_the_lifts_seen() -> void:
	assert_int(Lift.rising_tier(BAYS, 1, 1)).is_equal(0)  # a new save: tier 1's lift was always open
	assert_int(Lift.rising_tier(BAYS, 2, 1)).is_equal(2)
	assert_int(Lift.rising_tier(BAYS, 2, 2)).is_equal(0)  # seen
	assert_int(Lift.rising_tier(BAYS, 3, 1)).is_equal(2)  # tier 3 has no series: its bay never rises
	assert_int(Lift.rising_tier(BAYS, 3, 2)).is_equal(0)
	assert_int(Lift.rising_tier([1], 2, 1)).is_equal(0)  # a room without tier 2's bay
