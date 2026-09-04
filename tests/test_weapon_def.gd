extends GdUnitTestSuite


func test_pistol_resource_is_valid() -> void:
	var pistol: WeaponDef = load("res://data/weapons/pistol.tres")
	assert_object(pistol).is_not_null()
	assert_array(pistol.validate()).is_empty()


func test_validate_reports_bad_values() -> void:
	var def := WeaponDef.new()
	def.damage = 0.0
	def.fire_rate = -1.0
	def.projectile_count = 0
	var errors := def.validate()
	assert_array(errors).has_size(3)


func test_single_shot_has_no_offset() -> void:
	assert_array(WeaponDef.spread_offsets(1, 0.5)).is_equal([0.0])


func test_three_shots_fan_symmetrically() -> void:
	var offsets := WeaponDef.spread_offsets(3, 0.4)
	assert_float(offsets[0]).is_equal_approx(-0.2, 0.0001)
	assert_float(offsets[1]).is_equal_approx(0.0, 0.0001)
	assert_float(offsets[2]).is_equal_approx(0.2, 0.0001)
