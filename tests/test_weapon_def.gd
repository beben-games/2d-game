extends GdUnitTestSuite


func test_handgun_resource_is_valid() -> void:
	var handgun: WeaponDef = load("res://data/weapons/handgun.tres")
	assert_object(handgun).is_not_null()
	assert_array(handgun.validate()).is_empty()
	assert_str(handgun.id).is_equal("handgun")
	# Playtest 2 rated 7/s too fast; 5/s is the Milestone 1 cadence. Holds the number so a
	# stray edit to the .tres shows up here rather than in a playtest.
	assert_float(handgun.fire_rate).is_equal(5.0)
	assert_int(handgun.look).is_equal(WeaponDef.Look.BULLET)


func test_new_stats_default_to_zero() -> void:
	var def := WeaponDef.new()
	assert_int(def.bounce).is_equal(0)
	assert_float(def.homing).is_equal(0.0)
	assert_float(def.burn).is_equal(0.0)
	assert_float(def.stun).is_equal(0.0)
	assert_float(def.chill).is_equal(0.0)


func test_validate_reports_bad_values() -> void:
	var def := WeaponDef.new()
	def.id = "x"
	def.damage = 0.0
	def.fire_rate = -1.0
	def.projectile_count = 0
	var errors := def.validate()
	assert_array(errors).has_size(3)


func test_validate_rejects_negatives_an_upgrade_could_write() -> void:
	var def := WeaponDef.new()
	def.id = "x"
	def.pierce = -1
	def.knockback = -1.0
	def.spread_degrees = -1.0
	def.inaccuracy_degrees = -1.0
	def.recoil = -1.0
	def.bounce = -1
	def.homing = -1.0
	def.burn = -1.0
	def.stun = -1.0
	def.chill = -1.0
	assert_array(def.validate()).has_size(10)


func test_validate_requires_an_id() -> void:
	var def := WeaponDef.new()
	assert_array(def.validate()).is_equal(["id must be set"])


func test_single_shot_has_no_offset() -> void:
	assert_array(WeaponDef.spread_offsets(1, 0.5)).is_equal([0.0])


func test_three_shots_fan_symmetrically() -> void:
	var offsets := WeaponDef.spread_offsets(3, 0.4)
	assert_float(offsets[0]).is_equal_approx(-0.2, 0.0001)
	assert_float(offsets[1]).is_equal_approx(0.0, 0.0001)
	assert_float(offsets[2]).is_equal_approx(0.2, 0.0001)
