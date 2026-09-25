extends GdUnitTestSuite
## The fold: a Build over a base WeaponDef gives the numbers the player fires with.


func _modifier(stat: String, add := 0.0, mul := 1.0) -> Modifier:
	var m := Modifier.new()
	m.stat = stat
	m.add = add
	m.mul = mul
	return m


func _upgrade(id: String, kind: UpgradeDef.Kind, weapon_id: String, max_rank: int, modifiers: Array[Modifier]) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = id
	u.name = id
	u.kind = kind
	u.weapon_id = weapon_id
	u.max_rank = max_rank
	u.modifiers = modifiers
	return u


func _catalog() -> Dictionary:
	return {
		"damage": _upgrade("damage", UpgradeDef.Kind.WEAPON, "handgun", 3, [_modifier("damage", 1.0)]),
		"fire_rate": _upgrade("fire_rate", UpgradeDef.Kind.WEAPON, "handgun", 3, [_modifier("fire_rate", 0.0, 1.25)]),
		"multishot": _upgrade("multishot", UpgradeDef.Kind.WEAPON, "handgun", 2, [_modifier("projectile_count", 1.0), _modifier("spread_degrees", 12.0)]),
		"bounce": _upgrade("bounce", UpgradeDef.Kind.WEAPON, "handgun", 1, [_modifier("bounce", 1.0)]),
		"heart": _upgrade("heart", UpgradeDef.Kind.PLAYER, "", 3, [_modifier("max_hp", 2.0)]),
		"dash": _upgrade("dash", UpgradeDef.Kind.PLAYER, "", 2, [_modifier("dash_charges", 1.0)]),
	}


func _base() -> WeaponDef:
	var w := WeaponDef.new()
	w.id = "handgun"
	w.damage = 1.0
	w.fire_rate = 4.0
	return w


func test_empty_build_resolves_to_the_base_numbers() -> void:
	var build := Build.new()
	var def := build.resolve(_base(), _catalog())
	assert_float(def.damage).is_equal(1.0)
	assert_float(def.fire_rate).is_equal(4.0)
	assert_int(def.projectile_count).is_equal(1)
	assert_int(build.weapon_upgrade_count()).is_equal(0)
	assert_str(build.weapon_id).is_equal("handgun")


func test_resolve_never_mutates_the_base() -> void:
	var base := _base()
	var build := Build.new()
	build.add_rank(_catalog()["damage"])
	build.resolve(base, _catalog())
	assert_float(base.damage).is_equal(1.0)


func test_ranks_apply_once_each_and_ints_stay_ints() -> void:
	var build := Build.new()
	var catalog := _catalog()
	build.add_rank(catalog["damage"])
	build.add_rank(catalog["damage"])
	build.add_rank(catalog["fire_rate"])
	build.add_rank(catalog["multishot"])
	build.add_rank(catalog["bounce"])
	var def := build.resolve(_base(), catalog)
	assert_float(def.damage).is_equal(3.0)
	assert_float(def.fire_rate).is_equal(5.0)
	assert_int(def.projectile_count).is_equal(2)
	assert_float(def.spread_degrees).is_equal(12.0)
	assert_int(def.bounce).is_equal(1)
	assert_bool(typeof(def.projectile_count) == TYPE_INT).is_true()
	assert_int(build.rank_of("damage")).is_equal(2)
	assert_int(build.rank_of("nothing")).is_equal(0)
	assert_int(build.weapon_upgrade_count()).is_equal(5)


func test_mul_ranks_add_their_bonus_instead_of_compounding() -> void:
	var build := Build.new()
	var catalog := _catalog()
	build.add_rank(catalog["fire_rate"])
	build.add_rank(catalog["fire_rate"])
	assert_float(build.resolve(_base(), catalog).fire_rate).is_equal(6.0)  # 4 * 1.5, not 4 * 1.25 * 1.25
	build.add_rank(catalog["fire_rate"])
	assert_float(build.resolve(_base(), catalog).fire_rate).is_equal(7.0)  # 4 * 1.75


func test_add_rank_stops_at_the_cap() -> void:
	var build := Build.new()
	var catalog := _catalog()
	for i in 5:
		build.add_rank(catalog["bounce"])
	assert_int(build.rank_of("bounce")).is_equal(1)


func test_player_stats_fold_separately_and_survive_a_switch() -> void:
	var build := Build.new()
	var catalog := _catalog()
	build.add_rank(catalog["heart"])
	build.add_rank(catalog["dash"])
	build.add_rank(catalog["damage"])
	assert_int(build.max_hp(catalog)).is_equal(Build.BASE_MAX_HP + 2)
	assert_int(build.dash_charges(catalog)).is_equal(2)
	var refund := build.switch_weapon("crossbow")
	assert_int(refund).is_equal(1)
	assert_str(build.weapon_id).is_equal("crossbow")
	assert_int(build.weapon_upgrade_count()).is_equal(0)
	assert_int(build.rank_of("damage")).is_equal(0)
	assert_array(build.owned_weapon_ids()).is_empty()
	assert_int(build.max_hp(catalog)).is_equal(Build.BASE_MAX_HP + 2)
	assert_int(build.rank_of("heart")).is_equal(1)


func test_the_build_remembers_every_weapon_the_run_has_used() -> void:
	# A weapon used this run is never offered again as a switch (playtest 1, note 4), so the build
	# keeps the list: the starting weapon first, then each switch in order, no repeats.
	var build := Build.new()
	assert_array(build.used_weapon_ids).is_equal(["handgun"])
	assert_bool(build.has_used("handgun")).is_true()
	assert_bool(build.has_used("crossbow")).is_false()
	build.switch_weapon("crossbow")
	assert_array(build.used_weapon_ids).is_equal(["handgun", "crossbow"])
	assert_bool(build.has_used("crossbow")).is_true()
	build.switch_weapon("handgun")  # only reachable by hand; the list stays a set
	assert_array(build.used_weapon_ids).is_equal(["handgun", "crossbow"])


func test_heal_and_switch_cards_never_enter_the_build() -> void:
	var build := Build.new()
	build.add_rank(_upgrade("heal", UpgradeDef.Kind.HEAL, "", 1, []))
	build.add_rank(_upgrade("switch_crossbow", UpgradeDef.Kind.SWITCH, "crossbow", 1, []))
	assert_array(build.owned_weapon_ids()).is_empty()
	assert_array(build.owned_player_ids()).is_empty()
	assert_int(build.weapon_upgrade_count()).is_equal(0)
	assert_int(build.rank_of("heal")).is_equal(0)


func test_mul_on_an_int_weapon_stat_rounds_once_after_the_fold() -> void:
	var build := Build.new()
	var catalog := {"split": _upgrade("split", UpgradeDef.Kind.WEAPON, "handgun", 3, [_modifier("projectile_count", 0.0, 1.5)])}
	build.add_rank(catalog["split"])
	assert_int(build.resolve(_base(), catalog).projectile_count).is_equal(2)  # 1.5 rounds to 2
	build.add_rank(catalog["split"])
	assert_int(build.resolve(_base(), catalog).projectile_count).is_equal(2)  # 1 * (1 + 0.5 * 2), not 2 * 1.5
	build.add_rank(catalog["split"])
	assert_int(build.resolve(_base(), catalog).projectile_count).is_equal(3)  # 2.5 rounds away from zero


func test_mul_on_an_int_player_stat_rounds_once_like_a_weapon_stat() -> void:
	var build := Build.new()
	var catalog := {"dashes": _upgrade("dashes", UpgradeDef.Kind.PLAYER, "", 3, [_modifier("dash_charges", 0.0, 1.5)])}
	build.add_rank(catalog["dashes"])
	assert_int(build.dash_charges(catalog)).is_equal(2)
	build.add_rank(catalog["dashes"])
	assert_int(build.dash_charges(catalog)).is_equal(2)
	build.add_rank(catalog["dashes"])
	assert_int(build.dash_charges(catalog)).is_equal(3)


func test_owned_lists_are_in_pick_order() -> void:
	var build := Build.new()
	var catalog := _catalog()
	build.add_rank(catalog["bounce"])
	build.add_rank(catalog["damage"])
	build.add_rank(catalog["heart"])
	assert_array(build.owned_weapon_ids()).is_equal(["bounce", "damage"])
	assert_array(build.owned_player_ids()).is_equal(["heart"])
