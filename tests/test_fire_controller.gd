extends GdUnitTestSuite


func test_first_shot_fires_immediately() -> void:
	var fc := FireController.new()
	assert_bool(fc.try_fire(10.0)).is_true()


func test_second_shot_waits_for_cooldown() -> void:
	var fc := FireController.new()
	fc.try_fire(10.0)
	assert_bool(fc.try_fire(10.0)).is_false()
	fc.tick(0.05)
	assert_bool(fc.try_fire(10.0)).is_false()
	fc.tick(0.05)
	assert_bool(fc.try_fire(10.0)).is_true()


func test_fire_rate_over_one_second() -> void:
	var fc := FireController.new()
	var shots := 0
	for i in 60:
		if fc.try_fire(10.0):
			shots += 1
		fc.tick(1.0 / 60.0)
	assert_int(shots).is_between(9, 11)
