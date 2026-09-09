extends GdUnitTestSuite
## UpgradeDef and Modifier validation: every card file must pass this before the catalog loads it.


func _modifier(stat: String, add := 0.0, mul := 1.0) -> Modifier:
	var m := Modifier.new()
	m.stat = stat
	m.add = add
	m.mul = mul
	return m


func _weapon_upgrade() -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = "damage_handgun"
	u.name = "Heavy rounds"
	u.description = "+1 damage"
	u.icon = "damage"
	u.kind = UpgradeDef.Kind.WEAPON
	u.weapon_id = "handgun"
	u.max_rank = 3
	u.modifiers = [_modifier("damage", 1.0)]
	return u


func test_a_complete_weapon_upgrade_is_valid() -> void:
	assert_array(_weapon_upgrade().validate()).is_empty()


func test_modifier_rejects_unknown_stat_and_bad_mul() -> void:
	var m := _modifier("sharpness", 1.0, 0.0)
	var errors := m.validate()
	assert_array(errors).has_size(2)
	assert_str(errors[0]).contains("unknown stat")
	assert_str(errors[1]).contains("mul")


func test_weapon_upgrade_needs_weapon_id_and_weapon_stats() -> void:
	var u := _weapon_upgrade()
	u.weapon_id = ""
	u.modifiers = [_modifier("max_hp", 2.0)]
	var errors := u.validate()
	assert_array(errors).has_size(2)
	assert_str(errors[0]).contains("weapon_id")
	assert_str(errors[1]).contains("max_hp")


func test_player_upgrade_uses_player_stats_only() -> void:
	var u := _weapon_upgrade()
	u.kind = UpgradeDef.Kind.PLAYER
	u.weapon_id = ""
	u.modifiers = [_modifier("damage", 1.0)]
	assert_array(u.validate()).has_size(1)
	u.modifiers = [_modifier("max_hp", 2.0)]
	assert_array(u.validate()).is_empty()


func test_heal_and_switch_carry_no_modifiers() -> void:
	var u := _weapon_upgrade()
	u.kind = UpgradeDef.Kind.HEAL
	u.weapon_id = ""
	assert_array(u.validate()).has_size(1)  # the damage modifier is not allowed
	u.modifiers = []
	assert_array(u.validate()).is_empty()
	u.kind = UpgradeDef.Kind.SWITCH
	assert_array(u.validate()).has_size(1)  # a switch needs the weapon it switches to
	u.weapon_id = "crossbow"
	assert_array(u.validate()).is_empty()


func test_id_name_and_rank_are_required() -> void:
	var u := _weapon_upgrade()
	u.id = ""
	u.name = ""
	u.max_rank = 0
	assert_array(u.validate()).has_size(3)
