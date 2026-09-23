extends GdUnitTestSuite
## The catalog loads every card and weapon file, and the pool and draw are pure and seeded.

const HANDGUN_WEAPON_CARDS := ["bounce_handgun", "damage_handgun", "fire_rate", "homing", "multishot_handgun", "pierce_handgun"]
const CROSSBOW_WEAPON_CARDS := ["bounce_crossbow", "chill", "damage_crossbow", "flaming", "multishot_crossbow", "pierce_crossbow", "shock"]
const PLAYER_CARDS := ["dash_charge", "heart_container"]


func _ids(cards: Array[UpgradeDef]) -> Array[String]:
	var ids: Array[String] = []
	for c in cards:
		ids.append(c.id)
	return ids


func test_every_file_loads_and_validates() -> void:
	var upgrades := UpgradeCatalog.upgrades()
	assert_int(upgrades.size()).is_equal(18)
	for id in upgrades:
		assert_array(upgrades[id].validate()).override_failure_message("upgrade %s" % id).is_empty()
		assert_str(upgrades[id].id).is_equal(id)
	assert_str(UpgradeCatalog.weapon("handgun").display_name).is_equal("Handgun")
	assert_str(UpgradeCatalog.weapon("crossbow").display_name).is_equal("Crossbow")
	assert_int(UpgradeCatalog.weapon("crossbow").pierce).is_equal(2)
	assert_int(UpgradeCatalog.weapon("crossbow").look).is_equal(WeaponDef.Look.BOLT)


func test_fresh_handgun_pool_at_full_health() -> void:
	var build := Build.new()
	var pool := UpgradeCatalog.pool(build)
	var expected: Array[String] = []
	expected.append_array(HANDGUN_WEAPON_CARDS)
	expected.append_array(PLAYER_CARDS)
	expected.append("switch_crossbow")
	assert_array(_ids(pool)).contains_exactly_in_any_order(expected)


func test_heal_never_joins_the_pool_and_capped_cards_drop_out() -> void:
	var build := Build.new()
	var catalog := UpgradeCatalog.upgrades()
	build.add_rank(catalog["homing"])
	build.add_rank(catalog["pierce_handgun"])
	var ids := _ids(UpgradeCatalog.pool(build))
	assert_array(ids).not_contains(["heal", "homing", "pierce_handgun"])
	assert_array(ids).contains(["damage_handgun"])


func test_offers_put_heal_on_the_right_when_hurt_and_replay_the_other_two() -> void:
	var build := Build.new()
	var full := UpgradeCatalog.offers(build, 6, 6, RunState.stream("o"))
	var hurt := UpgradeCatalog.offers(build, 3, 6, RunState.stream("o"))
	assert_int(full.size()).is_equal(3)
	assert_array(_ids(full)).not_contains(["heal"])
	assert_int(hurt.size()).is_equal(3)
	assert_str(hurt[2].id).is_equal("heal")  # always the right card
	assert_str(hurt[0].id).is_equal(full[0].id)  # the same cards in the same slots
	assert_str(hurt[1].id).is_equal(full[1].id)
	var again := UpgradeCatalog.offers(build, 3, 6, RunState.stream("o"))
	assert_array(_ids(again)).is_equal(_ids(hurt))  # seeded


func test_a_card_stays_in_the_pool_until_its_last_rank_is_taken() -> void:
	var build := Build.new()
	var card := UpgradeCatalog.upgrade("damage_handgun")
	assert_int(card.max_rank).is_equal(3)
	build.add_rank(card)
	build.add_rank(card)
	assert_array(_ids(UpgradeCatalog.pool(build))).contains(["damage_handgun"])
	build.add_rank(card)
	assert_array(_ids(UpgradeCatalog.pool(build))).not_contains(["damage_handgun"])


func test_crossbow_pool_offers_its_own_cards_and_the_handgun_switch() -> void:
	var build := Build.new()
	build.switch_weapon("crossbow")
	var pool := UpgradeCatalog.pool(build)
	var expected: Array[String] = []
	expected.append_array(CROSSBOW_WEAPON_CARDS)
	expected.append_array(PLAYER_CARDS)
	expected.append("switch_handgun")
	assert_array(_ids(pool)).contains_exactly_in_any_order(expected)


func test_draw_is_seeded_distinct_and_bounded_by_the_pool() -> void:
	var build := Build.new()
	var pool := UpgradeCatalog.pool(build)
	var a := UpgradeCatalog.draw(pool, RunState.stream("probe"))
	var b := UpgradeCatalog.draw(pool, RunState.stream("probe"))
	assert_int(a.size()).is_equal(3)
	assert_array(_ids(a)).is_equal(_ids(b))
	var ids := _ids(a)
	assert_int(ids.size()).is_equal(3)
	var unique: Array[String] = []
	for id in ids:
		if id not in unique:
			unique.append(id)
	assert_array(ids).override_failure_message("draw repeated a card: %s" % [ids]).is_equal(unique)
	var two: Array[UpgradeDef] = [pool[0], pool[1]]
	assert_int(UpgradeCatalog.draw(two, RunState.stream("probe")).size()).is_equal(2)
	var none: Array[UpgradeDef] = []
	assert_int(UpgradeCatalog.draw(none, RunState.stream("probe")).size()).is_equal(0)


func test_pool_order_is_stable_so_a_seed_replays() -> void:
	var build := Build.new()
	var first := _ids(UpgradeCatalog.pool(build))
	var second := _ids(UpgradeCatalog.pool(build))
	assert_array(first).is_equal(second)
	var sorted := first.duplicate()
	sorted.sort()
	assert_array(first).is_equal(sorted)
