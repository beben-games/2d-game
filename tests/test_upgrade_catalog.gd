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
		var full := UpgradeCatalog.draw(UpgradeCatalog.pool(build), RunState.stream(name))
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
	assert_str(full[3].id).is_equal("heart_container")  # none owned: the container holds the right slot
	var hurt := UpgradeCatalog.offers(build, true, RunState.stream("o"), 4)
	assert_int(hurt.size()).is_equal(4)
	assert_int(_distinct(hurt)).is_equal(4)
	assert_str(hurt[3].id).is_equal("heart_container")  # the right card is still the last slot
	build.add_rank(UpgradeCatalog.upgrade("heart_container"))
	var healing := UpgradeCatalog.offers(build, true, RunState.stream("o"), 4)
	assert_int(healing.size()).is_equal(4)
	assert_str(healing[3].id).is_equal("heal")
	assert_int(_distinct(healing)).is_equal(4)


func _cards(ids: Array) -> Array[UpgradeDef]:
	var cards: Array[UpgradeDef] = []
	for id: String in ids:
		cards.append(UpgradeCatalog.upgrade(id))
	return cards


func test_the_crowd_locks_one_of_three_or_more_and_never_the_heal_card() -> void:
	# A hurt player's right card is the heal slot, a heart container or Heal: the crowd spares it.
	var hurt := _cards(["damage_handgun", "homing", "heart_container"])
	var healing := _cards(["damage_handgun", "homing", "dash_charge", "heal"])
	var seen := {}
	for n in 40:
		var at := UpgradeCatalog.locked_index(hurt, 1, RunState.stream("lock%d" % n), true)
		assert_int(at).is_between(0, 1)
		seen[at] = true
		var at_four := UpgradeCatalog.locked_index(healing, 1, RunState.stream("lock%d" % n), true)
		assert_int(at_four).is_between(0, 2)
	assert_int(seen.size()).override_failure_message("the lock never moved in 40 streams").is_equal(2)
	# The right slot not held (a container owned, the player whole), a heart container is a boon
	# like any other, and every slot can be taken.
	var full := _cards(["damage_handgun", "homing", "heart_container"])
	var slots := {}
	for n in 60:
		slots[UpgradeCatalog.locked_index(full, 1, RunState.stream("lock%d" % n))] = true
	assert_int(slots.size()).is_equal(3)
	# A Heal card is spared wherever it sits.
	var heal_first := _cards(["heal", "homing", "dash_charge"])
	for n in 40:
		assert_int(UpgradeCatalog.locked_index(heal_first, 1, RunState.stream("lock%d" % n))).is_not_equal(0)


func test_the_lock_is_seeded() -> void:
	var offers := _cards(["damage_handgun", "homing", "dash_charge", "multishot_handgun", "fire_rate"])
	for n in 10:
		var a := UpgradeCatalog.locked_index(offers, 1, RunState.stream("lock%d" % n))
		var b := UpgradeCatalog.locked_index(offers, 1, RunState.stream("lock%d" % n))
		assert_int(a).is_equal(b)
		assert_int(a).is_between(0, 4)


func test_no_lock_without_a_count_or_when_fewer_than_two_cards_would_stay_pickable() -> void:
	var rng := RunState.stream("lock")
	var none: Array[UpgradeDef] = []
	assert_int(UpgradeCatalog.locked_index(none, 1, rng)).is_equal(-1)
	assert_int(UpgradeCatalog.locked_index(_cards(["homing"]), 1, rng)).is_equal(-1)
	assert_int(UpgradeCatalog.locked_index(_cards(["homing", "dash_charge"]), 1, rng)).is_equal(-1)
	# Two cards, one the heal slot: locking the other would leave the heal card alone.
	assert_int(UpgradeCatalog.locked_index(_cards(["homing", "heart_container"]), 1, rng, true)).is_equal(-1)
	assert_int(UpgradeCatalog.locked_index(_cards(["homing", "heal"]), 1, rng)).is_equal(-1)
	# A band that locks nothing.
	assert_int(UpgradeCatalog.locked_index(_cards(["homing", "dash_charge", "fire_rate"]), 0, rng)).is_equal(-1)
	assert_int(UpgradeCatalog.locked_index(_cards(["homing", "dash_charge", "fire_rate"]), 1, rng)).is_between(0, 2)


func test_the_heal_card_is_spared_only_while_the_rule_says_so() -> void:
	# LOCK_SPARES_HEAL's two values: true spares the heal slot (a hurt player's last card) and any
	# Heal card; false leaves every card a candidate.
	var offers := _cards(["damage_handgun", "homing", "heal"])
	assert_array(UpgradeCatalog.lock_candidates(offers, true, true)).is_equal([0, 1])
	assert_array(UpgradeCatalog.lock_candidates(offers, false, true)).is_equal([0, 1])
	assert_array(UpgradeCatalog.lock_candidates(offers, true, false)).is_equal([0, 1, 2])
	var container := _cards(["damage_handgun", "homing", "heart_container"])
	assert_array(UpgradeCatalog.lock_candidates(container, true, true)).is_equal([0, 1])
	assert_array(UpgradeCatalog.lock_candidates(container, false, true)).is_equal([0, 1, 2])
	assert_bool(UpgradeCatalog.LOCK_SPARES_HEAL).is_true()


func _distinct(cards: Array[UpgradeDef]) -> int:
	var seen := {}
	for card in cards:
		seen[card.id] = true
	return seen.size()


## The right slot is held while the build owns no heart container (the container, hurt or not)
## and while the player is hurt (Heal once a container is owned); free only for a whole player
## who owns one (playtest 1 of M6, note 5). Pure.
func test_the_right_slot_is_held_until_a_container_is_owned_then_only_while_hurt() -> void:
	var build := Build.new()
	assert_bool(UpgradeCatalog.right_slot_held(build, false)).is_true()
	assert_bool(UpgradeCatalog.right_slot_held(build, true)).is_true()
	build.add_rank(UpgradeCatalog.upgrade("heart_container"))
	assert_bool(UpgradeCatalog.right_slot_held(build, false)).is_false()
	assert_bool(UpgradeCatalog.right_slot_held(build, true)).is_true()


## No container owned and the player whole: the container is the right card at every count (the
## Offer rank's extra cards do not move it), shown once, and the other cards are the draw's.
func test_offers_put_the_container_last_while_none_is_owned_even_at_full_health() -> void:
	var build := Build.new()
	for count in [3, 4, 5]:
		for n in 20:
			var name := "w%d_%d" % [count, n]
			var drawn := UpgradeCatalog.draw(UpgradeCatalog.pool(build), RunState.stream(name), count)
			var whole := UpgradeCatalog.offers(build, false, RunState.stream(name), count)
			assert_int(whole.size()).is_equal(count)
			assert_str(whole[count - 1].id).is_equal("heart_container")
			assert_int(_ids(whole).count("heart_container")).is_equal(1)
			assert_array(_ids(whole)).not_contains(["heal"])
			assert_array(_ids(UpgradeCatalog.offers(build, true, RunState.stream(name), count))).is_equal(_ids(whole))
			var at := _ids(drawn).find("heart_container")
			for i in count - 1:
				var expected := drawn[count - 1] if i == at else drawn[i]
				assert_str(whole[i].id).override_failure_message("slot %d of %s" % [i, name]).is_equal(expected.id)


## One container owned and the player whole: no heal card, and the offer is the draw as it fell
## (a second container may sit anywhere); hurt, Heal holds the right slot.
func test_once_a_container_is_owned_a_whole_player_gets_the_plain_draw() -> void:
	var build := Build.new()
	build.add_rank(UpgradeCatalog.upgrade("heart_container"))
	for n in 20:
		var name := "o%d" % n
		var whole := UpgradeCatalog.offers(build, false, RunState.stream(name))
		assert_array(_ids(whole)).is_equal(_ids(UpgradeCatalog.draw(UpgradeCatalog.pool(build), RunState.stream(name))))
		assert_array(_ids(whole)).not_contains(["heal"])
		assert_str(UpgradeCatalog.offers(build, true, RunState.stream(name))[2].id).is_equal("heal")


## Whenever the right slot is held, the crowd's card on a Roar sits in the slot before it and a
## Boo's lock never takes it; when it is free the crowd's card is the last and any slot may be
## locked. The four states (container owned or not, hurt or not), four cards as on a Roar.
func test_the_crowd_and_the_lock_keep_off_the_held_right_slot() -> void:
	for owned in [false, true]:
		for hurt in [false, true]:
			var build := Build.new()
			if owned:
				build.add_rank(UpgradeCatalog.upgrade("heart_container"))
			var held := UpgradeCatalog.right_slot_held(build, hurt)
			var state := "owned %s, hurt %s" % [owned, hurt]
			var slots := {}
			for n in 40:
				var offers := UpgradeCatalog.offers(build, hurt, RunState.stream("s%d" % n), 4)
				var last := offers.size() - 1
				if held:
					assert_str(offers[last].id).override_failure_message(state).is_equal(UpgradeCatalog.heal_card(build).id)
					assert_int(UpgradeMenu.crowd_slot(offers.size(), held)).override_failure_message(state).is_equal(last - 1)
					assert_array(UpgradeCatalog.lock_candidates(offers, held, true)).override_failure_message(state).not_contains([last])
				else:
					assert_int(UpgradeMenu.crowd_slot(offers.size(), held)).override_failure_message(state).is_equal(last)
				slots[UpgradeCatalog.locked_index(offers, 1, RunState.stream("l%d" % n), held)] = true
			assert_bool(slots.has(3)).override_failure_message(state).is_equal(not held)
