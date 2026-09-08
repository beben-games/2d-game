extends GdUnitTestSuite


func test_two_hp_per_heart_with_half_hearts() -> void:
	assert_array(HeartRules.layout(6, 6)).is_equal(["full", "full", "full"])
	assert_array(HeartRules.layout(5, 6)).is_equal(["full", "full", "half"])
	assert_array(HeartRules.layout(2, 6)).is_equal(["full", "empty", "empty"])
	assert_array(HeartRules.layout(0, 6)).is_equal(["empty", "empty", "empty"])


func test_odd_max_rounds_up_to_a_heart() -> void:
	assert_array(HeartRules.layout(7, 7)).is_equal(["full", "full", "full", "half"])
