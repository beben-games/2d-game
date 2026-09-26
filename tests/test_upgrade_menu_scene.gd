extends SceneSuite
## The round-clear picker in the real main scene: it opens after a beat, paused, the round held,
## a pick applies the card and the gap starts the next round, a switch re-offers as many rounds as
## picks owned.


var _on_revealed := Callable()  ## the reveal watcher, disconnected in after_test if a test left it on


func after_test() -> void:
	if _on_revealed.is_valid() and Events.card_revealed.is_connected(_on_revealed):
		Events.card_revealed.disconnect(_on_revealed)
	_on_revealed = Callable()
	await super()


func _menu(main: Node) -> UpgradeMenu:
	return main.get_node("UpgradeMenu")


func test_round_clear_opens_three_cards_paused_with_the_round_held() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	assert_bool(_menu(main).is_open()).is_false()  # deferred: nothing happens inside the emit
	await get_tree().process_frame
	assert_bool(_menu(main).is_open()).is_false()  # the beat: the kill burst plays out first
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(_menu(main).is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(main.round_index).is_equal(0)
	assert_int(_menu(main).offers.size()).is_equal(3)
	assert_int(_menu(main).get_node("Center/Cards").get_child_count()).is_equal(3)
	assert_int(RunState.rounds_cleared).is_equal(1)


func test_pressing_a_number_takes_that_card_and_starts_the_next_round_after_the_gap() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	var index := offer_index(menu, UpgradeDef.Kind.WEAPON)
	if index < 0:
		index = offer_index(menu, UpgradeDef.Kind.PLAYER)
	assert_int(index).is_greater_equal(0)  # a fresh handgun pool has 8 rank cards and 1 switch: 3 draws hold one
	var card := menu.offers[index]
	var chosen := []
	var on_chosen := func(c: UpgradeDef, rank: int) -> void: chosen.append([c.id, rank])
	var changed := [0]
	var on_changed := func() -> void: changed[0] += 1
	Events.upgrade_chosen.connect(on_chosen)
	Events.build_changed.connect(on_changed)
	# A timer fires after the frame's _process; a press stamped there is never "just pressed" for
	# the menu's poll. Start a fresh frame so the key lands the way a real keypress does.
	await get_tree().process_frame
	Input.action_press("pick_%d" % (index + 1))
	await ticks(2)
	Input.action_release("pick_%d" % (index + 1))
	Events.upgrade_chosen.disconnect(on_chosen)
	Events.build_changed.disconnect(on_changed)
	assert_array(chosen).is_equal([[card.id, 1]])
	assert_int(changed[0]).is_equal(1)
	assert_int(RunState.build.rank_of(card.id)).is_equal(1)
	assert_bool(menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(main.round_index).is_equal(0)  # the gap first
	await real_seconds(Main.ROUND_GAP + 0.1)
	assert_int(main.round_index).is_equal(1)


func test_clicking_a_card_takes_it() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	var card := menu.offers[1]
	var button: Button = menu.get_node("Center/Cards").get_child(1)
	button.pressed.emit()
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()
	if card.kind == UpgradeDef.Kind.SWITCH:
		assert_str(RunState.build.weapon_id).is_equal(card.weapon_id)
	else:
		assert_int(RunState.build.rank_of(card.id)).is_equal(1)


func test_the_right_card_is_a_heart_container_first_and_heal_after() -> void:
	# While the build owns no container the right card grows a heart (and heals it); after, Heal.
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	player.hp = 2
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_str(menu.offers[2].id).is_equal("heart_container")
	menu.choose(2)
	await get_tree().process_frame
	assert_int(player.max_hp).is_equal(Build.BASE_MAX_HP + 2)
	assert_int(player.hp).is_equal(4)
	assert_bool(menu.is_open()).is_false()
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_str(menu.offers[2].id).is_equal("heal")
	menu.choose(2)
	await get_tree().process_frame
	assert_int(player.hp).is_equal(8)  # half of 8 is 4: full again
	assert_bool(menu.is_open()).is_false()
	assert_int(RunState.build.weapon_upgrade_count()).is_equal(0)


func test_a_container_taken_from_a_left_card_turns_the_right_card_to_heal() -> void:
	# Owning a container is what counts, not the slot it came from: the playtest 2 rule.
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	player.hp = 2
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_str(menu.offers[2].id).is_equal("heart_container")
	menu.chosen.emit(UpgradeCatalog.upgrade("heart_container"), 0)  # as if drawn on the left
	await get_tree().process_frame
	assert_int(RunState.build.rank_of("heart_container")).is_equal(1)
	player.hp = 2
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_str(menu.offers[2].id).is_equal("heal")
	menu.choose(2)
	await get_tree().process_frame
	await get_tree().process_frame  # let the last round's freed cards flush before the orphan snapshot


func test_switch_re_offers_one_round_per_upgrade_owned() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	Events.build_changed.emit()
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	var first_offers := menu.offers.duplicate()
	menu.chosen.emit(UpgradeCatalog.upgrade("switch_crossbow"), -1)  # from no slot
	await get_tree().process_frame
	# Round 1 of 2: still open, now drawing from the crossbow pool, with the refund shown.
	assert_bool(menu.is_open()).is_true()
	assert_str(RunState.build.weapon_id).is_equal("crossbow")
	assert_str(player.weapon.id).is_equal("crossbow")
	assert_int(RunState.build.weapon_upgrade_count()).is_equal(0)
	for card in menu.offers:
		assert_bool(card.kind == UpgradeDef.Kind.SWITCH).override_failure_message("%s offered after a switch" % card.id).is_false()  # the handgun was used: no switch back
		if card.kind == UpgradeDef.Kind.WEAPON:
			assert_str(card.weapon_id).is_equal("crossbow")  # no handgun rank card can be on offer
	assert_bool(menu.offers != first_offers).is_true()
	assert_int(main.round_index).is_equal(0)
	var index := offer_index(menu, UpgradeDef.Kind.WEAPON)
	if index < 0:
		index = offer_index(menu, UpgradeDef.Kind.PLAYER)  # 7 of the 10 crossbow-pool cards are WEAPON; 3 draws can still miss them
	assert_int(index).is_greater_equal(0)
	var round_one := menu.offers[index]
	menu.choose(index)
	await get_tree().process_frame
	# Round 2 of 2.
	assert_bool(menu.is_open()).is_true()
	assert_int(RunState.build.rank_of(round_one.id)).is_equal(1)
	index = offer_index(menu, UpgradeDef.Kind.WEAPON)
	if index < 0:
		index = offer_index(menu, UpgradeDef.Kind.PLAYER)
	menu.choose(index)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()
	await real_seconds(Main.ROUND_GAP + 0.1)
	assert_int(main.round_index).is_equal(1)


func test_a_second_switch_emitted_by_hand_during_a_refund_round_keeps_the_rounds_still_owed() -> void:
	# Refund arithmetic only. Two handgun ranks: the switch owes two rounds. A second switch in
	# round 1 spends that round and refunds nothing (the crossbow had no ranks), so one round is
	# still owed, not forfeited. The switch back is emitted by hand: since playtest 1 note 4 a
	# weapon used this run is never offered again as a switch, so with two weapons no switch back
	# is reachable in play (test_switch_re_offers_one_round_per_upgrade_owned pins the offers).
	var main := quiet_main_with_series(tiny_series(2))
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	Events.build_changed.emit()
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	menu.chosen.emit(UpgradeCatalog.upgrade("switch_crossbow"), -1)  # from no slot
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_true()  # round 1 of 2
	menu.chosen.emit(UpgradeCatalog.upgrade("switch_handgun"), -1)
	await get_tree().process_frame
	# Round 2 of 2, on the handgun again with no ranks.
	assert_bool(menu.is_open()).is_true()
	assert_str(RunState.build.weapon_id).is_equal("handgun")
	assert_int(RunState.build.weapon_upgrade_count()).is_equal(0)
	assert_int(main.round_index).is_equal(0)
	var index := offer_index(menu, UpgradeDef.Kind.WEAPON)
	if index < 0:
		index = offer_index(menu, UpgradeDef.Kind.PLAYER)
	assert_int(index).is_greater_equal(0)
	menu.choose(index)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()
	await real_seconds(Main.ROUND_GAP + 0.1)
	assert_int(main.round_index).is_equal(1)


func test_offers_replay_for_a_seed() -> void:
	var first: Array = await _offers_for_seed(77)
	var second: Array = await _offers_for_seed(77)
	assert_array(first).is_equal(second)
	assert_int(first.size()).is_equal(3)


func _offers_for_seed(seed_value: int) -> Array:
	RunState.start_run(seed_value)
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var ids := []
	for card in _menu(main).offers:
		ids.append(card.id)
	_menu(main).close()
	main.queue_free()
	await get_tree().process_frame
	return ids


func test_restart_from_the_menu_unpauses() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	await get_tree().process_frame  # a fresh frame, so the menu's is_action_just_pressed sees the key
	Input.action_press("restart")
	await ticks(2)
	Input.action_release("restart")
	assert_int(restarts[0]).is_equal(1)
	assert_bool(get_tree().paused).is_false()
	assert_bool(_menu(main).is_open()).is_false()  # not the current scene here: no reload, so the menu must go by itself


func test_the_last_round_wins_without_a_menu() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var won := [0]
	var on_won := func() -> void: won[0] += 1
	Events.run_won.connect(on_won)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	Events.run_won.disconnect(on_won)
	assert_int(won[0]).is_equal(1)
	assert_bool(_menu(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_a_death_during_the_beat_shows_no_menu() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	player.hp = 1
	Events.round_cleared.emit()
	player.hurt(1, player.global_position + Vector2(4, 0))
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(player.dead).is_true()
	assert_bool(_menu(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_a_restart_during_the_beat_shows_no_menu() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	main.restart()  # not the current scene here: no reload, so the beat's guard must hold on its own
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(_menu(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_a_real_shot_clear_opens_the_menu_without_errors() -> void:
	# round_cleared arrives from inside a projectile's body_entered; pausing there would trip the
	# physics flush error (push_error fails this test), so the open must wait for idle time.
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var enemy := active_chaser_on(main, player.global_position + Vector2(40, 0))
	enemy.health.hp = 0.5
	runner.progress.queue = []
	runner.progress.spawned = 1
	runner.enabled = true
	player.aim_override = enemy.global_position
	Input.action_press("shoot")
	await ticks(12)
	Input.action_release("shoot")
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(_menu(main).is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_float(Engine.time_scale).is_equal(1.0)  # the kill freeze was cleared before the pause


func test_cards_show_name_description_and_rank() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	var card := menu.offers[0]
	var button: Button = menu.get_node("Center/Cards").get_child(0)
	var texts := []
	var fonts := {}
	for label in button.find_children("*", "Label", true, false):
		texts.append(label.text)
		fonts[label.text] = label.get_theme_font("font")
	assert_array(texts).contains([card.name, card.description])
	assert_array(texts).not_contains(["1"])  # no key digit on the card: the keys work silently
	assert_object(fonts[card.name]).is_same(UiTheme.TITLE_FONT)  # the name is the title, the rest is body
	assert_object(fonts[card.description]).is_same(UiTheme.FONT)
	var icons := button.find_children("*", "TextureRect", true, false)
	assert_int(icons.size()).is_equal(1)
	assert_that(icons[0].texture.region).is_equal(IconAtlas.texture(card.icon).region)


## Every card the catalog can offer, three at a time (the widest are "Piercing bullets" over
## "Bullets pass through 1 enemy" and "Deep pierce" over "Bolts pass through 2 more enemies";
## the tallest are the switch cards, a three-line description over a two-line swap count):
## the column of icon, title (two lines when the title font is too wide for one), effect, and
## rank must fit inside the panel, or the rank line runs under the bottom frame.
func test_every_card_fits_inside_its_column() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	var all_cards: Array[UpgradeDef] = []
	for card: UpgradeDef in UpgradeCatalog.upgrades().values():
		all_cards.append(card)
	var column := UpgradeMenu.CARD_SIZE - Vector2(UpgradeMenu.CARD_INSET, UpgradeMenu.CARD_INSET) * 2.0
	for start in range(0, all_cards.size(), 3):
		var offers: Array[UpgradeDef] = all_cards.slice(start, start + 3)
		menu.open(offers)
		await get_tree().process_frame
		await get_tree().process_frame  # autowrapped labels report their height one layout after they get their width
		for i in offers.size():
			var button: Button = menu.get_node("Center/Cards").get_child(i)
			var box: VBoxContainer = button.find_children("*", "VBoxContainer", true, false)[0]
			var needed := box.get_combined_minimum_size()
			var what := "%s needs %s, the column gives %s" % [offers[i].id, needed, column]
			assert_float(needed.x).override_failure_message(what).is_less_equal(column.x)
			assert_float(needed.y).override_failure_message(what).is_less_equal(column.y)
			assert_vector(box.size).override_failure_message(what).is_equal(column)  # a Control grows past its set size when the children need more
	menu.close()


func test_hovering_a_card_brightens_it_and_leaving_restores_it() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open([UpgradeCatalog.upgrade("damage_handgun")])
	var button: Button = menu.get_node("Center/Cards").get_child(0)
	assert_that(button.modulate).is_equal(Color.WHITE)
	button.mouse_entered.emit()
	assert_that(button.modulate).is_equal(UpgradeMenu.HOVER_MODULATE)
	assert_bool(button.modulate.r > 1.0).is_true()
	button.mouse_exited.emit()
	assert_that(button.modulate).is_equal(Color.WHITE)
	menu.close()


func test_rank_line_per_kind() -> void:
	# Pure: reads only the build passed in. A rank card names the rank this pick reaches; a switch
	# always states how many upgrades the swap re-picks, zero included (playtest 1 wanted the
	# count spelled out); a heal has no third line (its description already says what it restores).
	var build := Build.new()
	var damage := UpgradeCatalog.upgrade("damage_handgun")
	var switch := UpgradeCatalog.upgrade("switch_crossbow")
	assert_str(UpgradeMenu.rank_line(damage, build)).is_equal("Rank 1 of 3")
	assert_str(UpgradeMenu.rank_line(UpgradeCatalog.upgrade("heal"), build)).is_equal("")
	assert_str(UpgradeMenu.rank_line(switch, build)).is_equal("Swap now, nothing to re-pick")
	build.add_rank(damage)
	assert_str(UpgradeMenu.rank_line(damage, build)).is_equal("Rank 2 of 3")
	assert_str(UpgradeMenu.rank_line(switch, build)).is_equal("Swap and re-pick 1 upgrade")
	build.add_rank(damage)
	assert_str(UpgradeMenu.rank_line(switch, build)).is_equal("Swap and re-pick 2 upgrades")


func test_the_card_gap_shrinks_before_the_cards_do() -> void:
	# Pure. Three cards keep the gap they had; four at 1280 wide have none left; fewer than two
	# need no gap at all.
	assert_int(UpgradeMenu.card_gap(3, 1280.0)).is_equal(UpgradeMenu.CARD_GAP)
	assert_int(UpgradeMenu.card_gap(4, 1280.0)).is_equal(0)
	assert_int(UpgradeMenu.card_gap(4, 1400.0)).is_equal(40)
	assert_int(UpgradeMenu.card_gap(4, 1310.0)).is_equal(10)
	assert_int(UpgradeMenu.card_gap(1, 1280.0)).is_equal(UpgradeMenu.CARD_GAP)


func test_the_heal_card_has_no_rank_label() -> void:
	# An empty rank line adds no Label to the column: the card is the icon, the name, the effect.
	var main := quiet_main()
	var menu := _menu(main)
	menu.open([UpgradeCatalog.upgrade("heal"), UpgradeCatalog.upgrade("damage_handgun")])
	var heal: Button = menu.get_node("Center/Cards").get_child(0)
	var texts := []
	for label in heal.find_children("*", "Label", true, false):
		texts.append(label.text)
	assert_array(texts).is_equal(["Heal", "Restore half your hearts"])
	var damage: Button = menu.get_node("Center/Cards").get_child(1)
	assert_int(damage.find_children("*", "Label", true, false).size()).is_equal(3)
	menu.close()


func _four_offers() -> Array[UpgradeDef]:
	var offers := UpgradeCatalog.offers(RunState.build, false, RunState.stream("four"), 4)
	assert_int(offers.size()).is_equal(4)
	return offers


## Four cards without reveal_last (a refund round) land at once.
func test_four_cards_land_at_once_without_a_reveal() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open(_four_offers(), "The crowd")
	assert_int(menu.cards.get_child_count()).is_equal(4)
	menu.close()


## The crowd's fourth card: three at the open, the fourth added after FOURTH_CARD_DELAY, sliding
## in from the right edge over FOURTH_CARD_SLIDE with the crowd's roar (card_revealed on the
## bus); pick_4 and choose(3) do nothing until it is in, then take it.
func test_the_fourth_card_slides_in_after_the_delay_and_pick_4_waits_for_it() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var menu := _menu(main)
	var revealed := [0]
	_on_revealed = func() -> void: revealed[0] += 1
	Events.card_revealed.connect(_on_revealed)
	var offers := _four_offers()
	menu.open(offers, "The crowd", true)
	assert_int(menu.offers.size()).is_equal(4)
	assert_int(menu.cards.get_child_count()).is_equal(3)
	menu.choose(3)
	assert_bool(menu.is_open()).is_true()  # nothing to take yet
	await get_tree().process_frame
	Input.action_press("pick_4")
	await ticks(2)
	Input.action_release("pick_4")
	assert_bool(menu.is_open()).is_true()
	assert_int(revealed[0]).is_equal(0)
	await real_seconds(UpgradeMenu.FOURTH_CARD_DELAY + 0.1)
	assert_int(menu.cards.get_child_count()).is_equal(4)
	assert_int(revealed[0]).is_equal(1)
	assert_int(plays("crowd_roar")).is_equal(1)
	var fourth: Button = menu.cards.get_child(3)
	assert_str(fourth.name).is_equal("Card4")
	var body: Control = fourth.get_node("Face")
	assert_float(body.position.x).is_greater(0.0)  # still sliding in from the right
	await real_seconds(UpgradeMenu.FOURTH_CARD_SLIDE + 0.1)
	assert_float(body.position.x).is_equal_approx(0.0, 0.01)
	var card := offers[3]
	await get_tree().process_frame
	Input.action_press("pick_4")
	await ticks(2)
	Input.action_release("pick_4")
	assert_bool(menu.is_open()).is_false()
	if card.kind == UpgradeDef.Kind.SWITCH:
		assert_str(RunState.build.weapon_id).is_equal(card.weapon_id)
	else:
		assert_int(RunState.build.rank_of(card.id)).is_equal(1)


## A menu closed before the delay adds no card afterwards.
func test_a_close_before_the_reveal_adds_no_fourth_card() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open(_four_offers(), "The crowd", true)
	menu.close()
	await real_seconds(UpgradeMenu.FOURTH_CARD_DELAY + 0.1)
	assert_int(menu.cards.get_child_count()).is_equal(3)
	assert_int(plays("crowd_roar")).is_equal(0)


## Pure. The cards keep their size while a row of them fits the view with no gap (four at
## 1280 touch); past that they shrink in quarter steps (five at 1280 to three quarters, with
## the gap the shrink frees), never more than MAX_CARDS on offer.
func test_the_cards_shrink_in_quarter_steps_only_when_no_gap_would_still_overflow() -> void:
	assert_float(UpgradeMenu.card_scale(3, 1280.0)).is_equal(1.0)
	assert_float(UpgradeMenu.card_scale(4, 1280.0)).is_equal(1.0)
	assert_float(UpgradeMenu.card_scale(5, 1280.0)).is_equal(0.75)
	assert_float(UpgradeMenu.card_scale(5, 1600.0)).is_equal(1.0)
	assert_float(UpgradeMenu.card_scale(6, 1280.0)).is_equal(0.5)
	assert_int(UpgradeMenu.card_gap(5, 1280.0)).is_equal(20)
	assert_int(UpgradeMenu.card_gap(4, 1280.0)).is_equal(0)
	assert_int(UpgradeMenu.MAX_CARDS).is_equal(5)


## An Offer rank adds a card to every offer: a Quiet round gives four, the extra one revealed
## late like the crowd's (the count is over the base three), at full size.
func test_an_offer_rank_adds_a_card_to_a_quiet_offer_revealed_late() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.offer_bonus = 1
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(4)
	assert_int(menu.cards.get_child_count()).is_equal(3)
	assert_int(plays("crowd_roar")).is_equal(0)
	await real_seconds(UpgradeMenu.FOURTH_CARD_DELAY + 0.1)
	assert_int(menu.cards.get_child_count()).is_equal(4)
	assert_int(plays("crowd_roar")).is_equal(1)
	var first: Button = menu.cards.get_child(0)
	assert_vector(first.custom_minimum_size).is_equal(UpgradeMenu.CARD_SIZE)
	assert_vector((first.get_node("Face") as Control).scale).is_equal(Vector2.ONE)


## Two Offer ranks on a Roar make five: the cap, drawn at three quarters so the row fits the
## view, and 5 takes the fifth once it is in.
func test_two_offer_ranks_on_a_roar_make_five_cards_scaled_to_fit() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.offer_bonus = 2
	RunState.favour = FavourRules.MAX
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + UpgradeMenu.FOURTH_CARD_DELAY + 0.2)
	var menu := _menu(main)
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(5)
	assert_int(menu.cards.get_child_count()).is_equal(5)
	assert_str(menu.granter_label.text).is_equal(FavourRules.GRANTER_CROWD)
	for card: Button in menu.cards.get_children():
		assert_vector(card.custom_minimum_size).is_equal(UpgradeMenu.CARD_SIZE * 0.75)
		assert_vector((card.get_node("Face") as Control).scale).is_equal(Vector2(0.75, 0.75))
	await real_seconds(UpgradeMenu.FOURTH_CARD_SLIDE + 0.1)
	var view_width := get_viewport().get_visible_rect().size.x
	assert_float(menu.cards.size.x).is_less_equal(view_width)
	assert_float(menu.cards.global_position.x).is_greater_equal(0.0)
	var fifth := menu.offers[4]
	await get_tree().process_frame
	Input.action_press("pick_5")
	await ticks(2)
	Input.action_release("pick_5")
	assert_bool(menu.is_open()).is_false()
	if fifth.kind == UpgradeDef.Kind.SWITCH:
		assert_str(RunState.build.weapon_id).is_equal(fifth.weapon_id)
	else:
		assert_int(RunState.build.rank_of(fifth.id)).is_equal(1)


## The Reroll button sits under the cards only while a re-draw is left this run (a Reroll
## rank each), with a lit pip per one left; none bought, nothing shown.
func test_the_reroll_button_is_hidden_without_a_reroll_left() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	assert_int(RunState.rerolls_left).is_equal(0)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_bool(menu.is_open()).is_true()
	assert_bool(menu.reroll_box.visible).is_false()


## A press on Reroll redraws the same round's offer (the same count, the heal card still last
## when hurt, another set of cards from the reroll stream), spends the re-draw, and hides the
## button once none is left; offer_rerolled on the bus plays the open's sound again.
func test_a_reroll_redraws_the_offer_once_and_spends_the_reroll() -> void:
	Profile.save.training = {"reroll": 1}
	RunState.start_run(11)
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	player.hp = 2
	assert_int(RunState.rerolls_left).is_equal(1)
	var rerolled := [0]
	var on_rerolled := func() -> void: rerolled[0] += 1
	Events.offer_rerolled.connect(on_rerolled)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_bool(menu.reroll_box.visible).is_true()
	assert_int(menu.reroll_pips()).is_equal(1)
	var before := _ids(menu.offers)
	assert_str(before[2]).is_equal("heart_container")
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	Events.offer_rerolled.disconnect(on_rerolled)
	assert_bool(menu.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	var after := _ids(menu.offers)
	assert_int(after.size()).is_equal(3)
	assert_str(after[2]).is_equal("heart_container")
	assert_bool(after != before).override_failure_message("the reroll drew the same cards: %s" % [after]).is_true()
	assert_int(menu.cards.get_child_count()).is_equal(3)
	assert_int(rerolled[0]).is_equal(1)
	assert_int(plays("ui_open")).is_equal(2)
	assert_int(RunState.rerolls_left).is_equal(0)
	assert_bool(menu.reroll_box.visible).is_false()
	# Nothing left: a second press changes nothing.
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_array(_ids(menu.offers)).is_equal(after)
	assert_int(RunState.rerolls_left).is_equal(0)
	# The rerolled offer replays for the seed.
	menu.close()
	main.queue_free()
	await get_tree().process_frame
	Profile.save.training = {"reroll": 1}
	RunState.start_run(11)
	var again := quiet_main_with_series(tiny_series(2))
	(again.get_node("Player") as Player).hp = 2
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_array(_ids(_menu(again).offers)).is_equal(before)
	_menu(again).reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_array(_ids(_menu(again).offers)).is_equal(after)


## Two Reroll ranks: two pips, two re-draws, then the button goes.
func test_two_rerolls_show_two_pips_and_go_one_at_a_time() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.rerolls_left = 2
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_int(menu.reroll_pips()).is_equal(2)
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_int(RunState.rerolls_left).is_equal(1)
	assert_bool(menu.reroll_box.visible).is_true()
	assert_int(menu.reroll_pips()).is_equal(1)
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_int(RunState.rerolls_left).is_equal(0)
	assert_bool(menu.reroll_box.visible).is_false()
	assert_bool(menu.is_open()).is_true()


func _ids(offers: Array[UpgradeDef]) -> Array[String]:
	var ids: Array[String] = []
	for card in offers:
		ids.append(card.id)
	return ids
