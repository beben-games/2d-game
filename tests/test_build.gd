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
	assert_int(build.max_hp(catalog)).is_equal(Build.BASE_MAX_HP + 2)
	assert_int(build.rank_of("heart")).is_equal(1)


func test_owned_lists_are_in_pick_order() -> void:
	var build := Build.new()
	var catalog := _catalog()
	build.add_rank(catalog["bounce"])
	build.add_rank(catalog["damage"])
	build.add_rank(catalog["heart"])
	assert_array(build.owned_weapon_ids()).is_equal(["bounce", "damage"])
	assert_array(build.owned_player_ids()).is_equal(["heart"])
