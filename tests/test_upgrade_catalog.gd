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
	build.add_rank(UpgradeCatalog.upgrade("heart_container"))  # owning one makes the right card Heal
	var full := UpgradeCatalog.offers(build, false, RunState.stream("o"))
	var hurt := UpgradeCatalog.offers(build, true, RunState.stream("o"))
	assert_int(full.size()).is_equal(3)
	assert_array(_ids(full)).not_contains(["heal"])
	assert_int(hurt.size()).is_equal(3)
	assert_str(hurt[2].id).is_equal("heal")  # always the right card
	assert_str(hurt[0].id).is_equal(full[0].id)  # the same cards in the same slots
	assert_str(hurt[1].id).is_equal(full[1].id)
	var again := UpgradeCatalog.offers(build, true, RunState.stream("o"))
	assert_array(_ids(again)).is_equal(_ids(hurt))  # seeded


func test_the_right_card_is_a_heart_container_until_one_is_owned_never_doubled() -> void:
	var build := Build.new()
	var first := UpgradeCatalog.offers(build, true, RunState.stream("o"))
	assert_str(first[2].id).is_equal("heart_container")
	assert_array(_ids(first).slice(0, 2)).not_contains(["heart_container", "heal"])
	# A draw that holds the container on the left moves it right; the card it displaces takes its
	# slot and the third card keeps its own, so the set of the other two still replays.
	var found := false
	for n in 60:
		var name := "c%d" % n
		var full := UpgradeCatalog.offers(build, false, RunState.stream(name))
		var at := _ids(full).find("heart_container")
		if at < 0 or at == 2:
			continue
		found = true
		var hurt := UpgradeCatalog.offers(build, true, RunState.stream(name))
		assert_str(hurt[2].id).is_equal("heart_container")
		assert_int(_ids(hurt).count("heart_container")).is_equal(1)
		assert_str(hurt[1 - at].id).is_equal(full[1 - at].id)
		assert_str(hurt[at].id).is_equal(full[2].id)
		break
	assert_bool(found).override_failure_message("no draw in 60 streams held the container on the left").is_true()
	# One container owned, however it was taken: the right card is Heal, and the container stays a
	# regular card in the pool until its cap.
	build.add_rank(UpgradeCatalog.upgrade("heart_container"))
	var after := UpgradeCatalog.offers(build, true, RunState.stream("o"))
	assert_str(after[2].id).is_equal("heal")
	assert_array(_ids(UpgradeCatalog.pool(build))).contains(["heart_container"])
	var again_left := false
	for n in 60:
		var cards := UpgradeCatalog.offers(build, true, RunState.stream("d%d" % n))
		assert_str(cards[2].id).is_equal("heal")
		again_left = again_left or _ids(cards).slice(0, 2).has("heart_container")
	assert_bool(again_left).override_failure_message("no draw in 60 streams offered a second container on the left").is_true()


func test_a_card_stays_in_the_pool_until_its_last_rank_is_taken() -> void:
	var build := Build.new()
	var card := UpgradeCatalog.upgrade("damage_handgun")
	assert_int(card.max_rank).is_equal(3)
	build.add_rank(card)
	build.add_rank(card)
	assert_array(_ids(UpgradeCatalog.pool(build))).contains(["damage_handgun"])
	build.add_rank(card)
	assert_array(_ids(UpgradeCatalog.pool(build))).not_contains(["damage_handgun"])


func test_crossbow_pool_after_a_switch_offers_its_own_cards_and_no_switch() -> void:
	# The handgun was used this run, so its switch card is gone; with two weapons a switch is one-way.
	var build := Build.new()
	build.switch_weapon("crossbow")
	var pool := UpgradeCatalog.pool(build)
	var expected: Array[String] = []
	expected.append_array(CROSSBOW_WEAPON_CARDS)
	expected.append_array(PLAYER_CARDS)
	assert_array(_ids(pool)).contains_exactly_in_any_order(expected)


func test_a_switch_card_is_offered_before_the_first_switch_and_never_after() -> void:
	# Playtest 1, note 4: a weapon the run has used is never offered again as a switch. A switch
	# card is in the pool only for a weapon not yet used, so the fresh handgun sees Switch to
	# crossbow, the crossbow after the switch sees no switch card, and a switch back by hand
	# (unreachable in play) still offers none.
	var build := Build.new()
	assert_array(_ids(UpgradeCatalog.pool(build))).contains(["switch_crossbow"])
	assert_array(_ids(UpgradeCatalog.pool(build))).not_contains(["switch_handgun"])
	build.switch_weapon("crossbow")
	var after := _ids(UpgradeCatalog.pool(build))
	assert_array(after).not_contains(["switch_handgun", "switch_crossbow"])
	for card in UpgradeCatalog.pool(build):
		assert_bool(card.kind == UpgradeDef.Kind.SWITCH).override_failure_message("%s offered after a switch" % card.id).is_false()
	build.switch_weapon("handgun")
	assert_array(_ids(UpgradeCatalog.pool(build))).not_contains(["switch_handgun", "switch_crossbow"])


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


func test_offers_can_draw_four_with_the_heal_card_last_when_hurt() -> void:
	var build := Build.new()
	var full := UpgradeCatalog.offers(build, false, RunState.stream("o"), 4)
	assert_int(full.size()).is_equal(4)
	assert_int(_distinct(full)).is_equal(4)
	assert_array(_ids(full)).not_contains(["heal"])
	var hurt := UpgradeCatalog.offers(build, true, RunState.stream("o"), 4)
	assert_int(hurt.size()).is_equal(4)
	assert_int(_distinct(hurt)).is_equal(4)
	assert_str(hurt[3].id).is_equal("heart_container")  # the right card is still the last slot
	build.add_rank(UpgradeCatalog.upgrade("heart_container"))
	var healing := UpgradeCatalog.offers(build, true, RunState.stream("o"), 4)
	assert_int(healing.size()).is_equal(4)
	assert_str(healing[3].id).is_equal("heal")
	assert_int(_distinct(healing)).is_equal(4)


func _distinct(cards: Array[UpgradeDef]) -> int:
	var seen := {}
	for card in cards:
		seen[card.id] = true
	return seen.size()
