extends GdUnitTestSuite
## UpgradeDef and Modifier validation: every card file must pass this before the catalog loads it.
## And summary(rank): the cumulative effect the build screen prints for the real cards.


func _card(id: String) -> UpgradeDef:
	return load("res://data/upgrades/%s.tres" % id)


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


func test_modifier_apply_ranks_adds_then_multiplies_once_for_all_ranks() -> void:
	var m := _modifier("damage", 1.0, 2.0)
	assert_float(m.apply_ranks(3.0, 1)).is_equal(8.0)  # (3 + 1) * 2
	assert_float(m.apply_ranks(3.0, 2)).is_equal(15.0)  # (3 + 2) * 3, not 8 * 2 again
	assert_float(_modifier("fire_rate", 0.0, 1.25).apply_ranks(4.0, 3)).is_equal(7.0)  # +75% of the base


func test_unknown_stat_is_reported_once() -> void:
	var u := _weapon_upgrade()
	u.modifiers = [_modifier("sharpness")]
	var errors := u.validate()
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains("unknown stat")


func test_wrong_stat_list_is_reported_next_to_other_modifier_errors() -> void:
	var u := _weapon_upgrade()
	u.kind = UpgradeDef.Kind.PLAYER
	u.weapon_id = ""
	u.modifiers = [_modifier("damage", 0.0, 0.0)]
	var errors := u.validate()
	assert_array(errors).has_size(2)
	assert_str(errors[0]).contains("mul")
	assert_str(errors[1]).contains("not a player stat")


func test_missing_modifier_is_reported() -> void:
	var u := _weapon_upgrade()
	u.modifiers = [null]
	assert_array(u.validate()).is_equal(["modifier 0: missing"])


func test_player_upgrade_rejects_a_weapon_id() -> void:
	var u := _weapon_upgrade()
	u.kind = UpgradeDef.Kind.PLAYER
	u.weapon_id = "handgun"
	u.modifiers = [_modifier("max_hp", 2.0)]
	var errors := u.validate()
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains("weapon_id")


func test_heal_rejects_a_weapon_id() -> void:
	var u := _weapon_upgrade()
	u.kind = UpgradeDef.Kind.HEAL
	u.weapon_id = "handgun"
	u.modifiers = []
	var errors := u.validate()
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains("weapon_id")


func test_summary_totals_an_add_over_the_ranks() -> void:
	assert_str(_card("damage_handgun").summary(1)).is_equal("+1 damage")
	assert_str(_card("damage_handgun").summary(2)).is_equal("+2 damage")
	assert_str(_card("damage_crossbow").summary(3)).is_equal("+6 damage")


func test_summary_adds_a_mul_over_the_ranks() -> void:
	# Ranks stack additively, so the tiers read 25 / 50 / 75 (playtest 1).
	assert_str(_card("fire_rate").summary(1)).is_equal("+25% fire rate")
	assert_str(_card("fire_rate").summary(2)).is_equal("+50% fire rate")
	assert_str(_card("fire_rate").summary(3)).is_equal("+75% fire rate")


func test_summary_special_cases_the_int_stats() -> void:
	assert_str(_card("multishot_handgun").summary(1)).is_equal("+1 per shot")  # spread_degrees, its companion, is silent
	assert_str(_card("multishot_handgun").summary(2)).is_equal("+2 per shot")
	assert_str(_card("heart_container").summary(1)).is_equal("+1 heart")
	assert_str(_card("heart_container").summary(2)).is_equal("+2 hearts")
	assert_str(_card("dash_charge").summary(1)).is_equal("+1 dash")
	assert_str(_card("dash_charge").summary(2)).is_equal("+2 dashes")
	assert_str(_card("pierce_crossbow").summary(2)).is_equal("pierce +4")


func test_summary_of_a_flag_or_a_modifierless_card_is_its_description() -> void:
	var homing := _card("homing")
	assert_str(homing.summary(1)).is_equal(homing.description)
	var heal := _card("heal")
	assert_str(heal.summary(1)).is_equal(heal.description)
	var switch := _card("switch_crossbow")
	assert_str(switch.summary(1)).is_equal(switch.description)


func test_summary_joins_several_modifiers_and_keeps_a_minus() -> void:
	var u := _weapon_upgrade()
	u.modifiers = [_modifier("damage", 1.0), _modifier("recoil", -0.5), _modifier("projectile_speed", 0.0, 0.8)]
	assert_str(u.summary(2)).is_equal("+2 damage, -1 recoil, -40% shot speed")
