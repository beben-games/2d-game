extends SceneSuite
## The round-clear picker in the real main scene: it opens after a beat, paused, the round held,
## a pick applies the card and the gap starts the next round, a switch re-offers as many rounds as
## picks owned.


var _on_revealed := Callable()  ## the reveal watcher, disconnected in after_test if a test left it on
## card_revealed counted by the watcher, and the bottom edge of the crowd card's face (in the
## view) at the moment it was revealed, before its drop has moved it (INF until then).
var _revealed := 0
var _start_bottom := INF


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
	await wait_for_round(main, 1)
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
	await wait_for_round(main, 1)
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
	await wait_for_round(main, 1)
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


## The heading over the cards is the same on every band (playtest 2, note 4: the user's words):
## Boo, Quiet, Cheer, and Roar each open under "Pick a boon". The clean round's bonus lands
## before the band is read, so each start sits a band's width under the next edge.
func test_the_heading_reads_pick_a_boon_on_every_band() -> void:
	var main: Main = quiet_main_with_series(tiny_series(2))
	var menu := _menu(main)
	for start: float in [0.0, 25.0, 50.0, 80.0]:
		RunState.favour = start
		Events.round_cleared.emit()
		await real_seconds(Main.PICKER_DELAY + 0.1)
		assert_bool(menu.is_open()).is_true()
		assert_bool(menu.heading_label.visible).is_true()
		assert_str(menu.heading_label.text).is_equal("Pick a boon")
		menu.close()
	assert_array(main.round_bands).is_equal([FavourRules.BOO, FavourRules.QUIET, FavourRules.CHEER, FavourRules.ROAR])


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
## rank must fit inside the panel, or the rank line runs under the bottom frame. The crowd's
## heads sit on its frame's top bar, clear of the tallest column (the switch cards leave the
## column no room for them).
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
	# Every card again as the crowd's, its heads over the column: the menu is open, so a Roar's
	# card is built at once.
	var filler := all_cards[0]
	for card: UpgradeDef in all_cards:
		var pair: Array[UpgradeDef] = [filler, card]
		menu.open(pair, true)
		await get_tree().process_frame
		await get_tree().process_frame
		var button: Button = menu.get_node("Center/Cards").get_child(1)
		var drawn := _drawn_heads(_heads_of(button)[0])
		var box: VBoxContainer = button.find_children("*", "VBoxContainer", true, false)[0]
		var content_top := box.position.y + (box.get_child(0) as Control).position.y  # the icon, as laid out
		var what := "the crowd's heads end at %.0f, %s's column starts at %.0f" % [drawn.end.y, card.id, content_top]
		assert_float(drawn.end.y).override_failure_message(what).is_less_equal(content_top)
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


## Counts card_revealed into _revealed until after_test disconnects it; with a menu, also
## records where the crowd card's face starts (_start_bottom).
func _watch_reveals(menu: UpgradeMenu = null) -> void:
	_revealed = 0
	_start_bottom = INF
	_on_revealed = func() -> void:
		_revealed += 1
		if menu != null:
			for card: Control in menu.cards.get_children():
				if card is Button and _frame_of(card) == UiTheme.FRAME_CROWD:
					var face: Control = card.get_node("Face")
					_start_bottom = face.global_position.y + UpgradeMenu.CARD_SIZE.y * face.scale.y
	Events.card_revealed.connect(_on_revealed)


## The frame a built card wears (its Face's Frame nine-patch).
func _frame_of(card: Control) -> Rect2:
	return (card.get_node("Face/Frame") as NinePatchRect).region_rect


## The drawn part of the crowd's heads (the image's used rect) in the card face's frame.
func _drawn_heads(heads: TextureRect) -> Rect2:
	var used := Rect2(heads.texture.get_image().get_used_rect())
	var scale := heads.size.x / heads.texture.get_size().x
	return Rect2(heads.position + used.position * scale, used.size * scale)


## The crowd's two heads on a built card, if it carries them.
func _heads_of(card: Control) -> Array[Node]:
	return card.find_children("Crowd", "TextureRect", true, false)


## Four cards with no Roar land at once, every one in the plain frame.
func test_four_cards_land_at_once_without_a_reveal() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open(_four_offers())
	assert_int(menu.cards.get_child_count()).is_equal(4)
	for card: Control in menu.cards.get_children():
		assert_bool(card is Button).is_true()
		assert_object(_frame_of(card)).is_equal(UiTheme.FRAME)
	menu.close()


## The crowd's card on a Roar: the other three at the open and the last slot held by an empty
## Control of the card's size (the row never shifts); after CROWD_CARD_DELAY the card is built in
## that slot and drops in from above over CROWD_CARD_DROP with the crowd's roar (card_revealed
## on the bus); pick_4 and choose(3) do nothing until it is in, then take it.
func test_a_roar_drops_the_crowds_card_into_the_last_slot_and_pick_4_waits_for_it() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var menu := _menu(main)
	_watch_reveals(menu)
	var offers := _four_offers()
	menu.open(offers, true)
	assert_int(menu.offers.size()).is_equal(4)
	assert_int(menu.cards.get_child_count()).is_equal(4)
	var held: Control = menu.cards.get_child(3)
	assert_bool(held is Button).is_false()
	assert_int(held.get_child_count()).is_equal(0)
	assert_vector(held.custom_minimum_size).is_equal(UpgradeMenu.CARD_SIZE)
	await get_tree().process_frame
	var slot := held.global_position
	menu.choose(3)
	assert_bool(menu.is_open()).is_true()  # nothing to take yet
	Input.action_press("pick_4")
	await ticks(2)
	Input.action_release("pick_4")
	assert_bool(menu.is_open()).is_true()
	assert_int(_revealed).is_equal(0)
	await wait_until(func() -> bool: return menu.cards.get_child(3) is Button, "the crowd's card built")
	var crowd: Button = menu.cards.get_child(3)
	assert_str(crowd.name).is_equal("Card4")
	assert_int(menu.cards.get_child_count()).is_equal(4)
	assert_bool(is_instance_valid(held) and held.is_inside_tree()).is_false()
	assert_int(_revealed).is_equal(1)
	assert_int(plays("crowd_roar")).is_equal(1)
	assert_int(plays("ui_open")).is_equal(1)  # the open's only
	assert_float(_start_bottom).is_less_equal(0.0)  # it starts wholly above the view (the stands)
	var face: Control = crowd.get_node("Face")
	assert_float(face.position.x).is_equal(0.0)  # it falls straight down
	assert_float(face.position.y).is_less(0.0)  # still dropping into its slot from above
	await real_seconds(UpgradeMenu.CROWD_CARD_DROP + 0.1)
	assert_float(face.position.y).is_equal_approx(0.0, 0.01)
	assert_vector(crowd.global_position).is_equal(slot)  # the slot the placeholder held
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


## The drop starts with the card's face wholly above the view's top edge (the stands are
## above): the start offset is the slot's top plus the card's height. Pure.
func test_the_crowds_card_starts_above_the_view() -> void:
	assert_float(UpgradeMenu.drop_start(160.0, 400.0)).is_equal(-560.0)
	assert_float(UpgradeMenu.drop_start(0.0, 300.0)).is_equal(-300.0)


## The crowd's slot: the last, or the one before it when the heal card holds the last (the
## right slot held: no container owned, or the player hurt); none for a single card. Pure.
func test_the_crowds_slot_is_the_last_or_the_one_before_the_heal() -> void:
	assert_int(UpgradeMenu.crowd_slot(4, false)).is_equal(3)
	assert_int(UpgradeMenu.crowd_slot(4, true)).is_equal(2)
	assert_int(UpgradeMenu.crowd_slot(5, true)).is_equal(3)
	assert_int(UpgradeMenu.crowd_slot(2, true)).is_equal(0)
	assert_int(UpgradeMenu.crowd_slot(1, false)).is_equal(-1)
	assert_int(UpgradeMenu.crowd_slot(1, true)).is_equal(-1)


## With the player hurt on a Roar, the heal slot keeps the last place and the crowd's card drops
## into the one before it; 3 waits for it, the heal card is there from the open.
func test_a_hurt_roar_drops_the_crowds_card_before_the_heal_card() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	(main.get_node("Player") as Player).hp = 2
	RunState.favour = 80.0
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(4)
	assert_str(menu.offers[3].id).is_equal("heart_container")
	assert_bool(menu.cards.get_child(2) is Button).is_false()
	assert_bool(menu.cards.get_child(3) is Button).is_true()
	assert_object(_frame_of(menu.cards.get_child(3))).is_equal(UiTheme.FRAME)
	menu.choose(2)
	assert_bool(menu.is_open()).is_true()
	await wait_until(func() -> bool: return menu.cards.get_child(2) is Button, "the crowd's card built")
	assert_object(_frame_of(menu.cards.get_child(2))).is_equal(UiTheme.FRAME_CROWD)
	var card := menu.offers[2]
	menu.choose(2)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()
	if card.kind == UpgradeDef.Kind.SWITCH:
		assert_str(RunState.build.weapon_id).is_equal(card.weapon_id)
	else:
		assert_int(RunState.build.rank_of(card.id)).is_equal(1)


## The crowd's card is drawn apart: the crowd's frame tinted gold and the crowd's two heads over
## its title (centred on the frame's top bar, peeking no higher than the heading's gap); the
## others wear the plain frame and no heads. An open over an open menu (a reroll, a refund
## round) builds every card at once, the crowd's included, with no reveal.
func test_the_crowds_card_carries_the_crowd_frame_and_the_heads_and_the_others_do_not() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	_watch_reveals()
	var offers := _four_offers()
	menu.open(offers)
	menu.open(offers, true)
	assert_int(menu.cards.get_child_count()).is_equal(4)
	for i in 4:
		var card: Control = menu.cards.get_child(i)
		assert_bool(card is Button).is_true()
		var crowd := i == 3
		assert_object(_frame_of(card)).is_equal(UiTheme.FRAME_CROWD if crowd else UiTheme.FRAME)
		assert_int(_heads_of(card).size()).is_equal(1 if crowd else 0)
		var tint := (card.get_node("Face/Frame") as CanvasItem).modulate
		assert_that(tint).is_equal(UpgradeMenu.CROWD_FRAME_TINT if crowd else Color.WHITE)
	var crowd_card: Control = menu.cards.get_child(3)
	var heads: TextureRect = _heads_of(crowd_card)[0]
	assert_vector(heads.texture.get_size()).is_equal(Vector2(IconAtlas.SIZE, IconAtlas.SIZE))
	await get_tree().process_frame
	await get_tree().process_frame  # the column lays its labels out
	var title: Label
	for label: Label in crowd_card.find_children("*", "Label", true, false):
		if label.text == offers[3].name:
			title = label
	var drawn := _drawn_heads(heads)
	assert_float(drawn.end.y).is_less_equal(title.global_position.y - crowd_card.global_position.y)  # over the title
	assert_float(drawn.end.y).is_equal(UpgradeMenu.CROWD_BAR)  # standing on the frame's top bar
	assert_float(drawn.position.y).is_less(0.0)  # peeking over the card's top edge
	assert_float(drawn.position.y).is_greater_equal(-UpgradeMenu.HEADING_GAP)  # under the heading
	assert_float(drawn.get_center().x).is_equal_approx(UpgradeMenu.CARD_SIZE.x / 2.0, 0.01)  # centred on the card
	await real_seconds(UpgradeMenu.CROWD_CARD_DELAY + 0.1)
	assert_int(_revealed).is_equal(0)
	assert_int(plays("crowd_roar")).is_equal(0)
	menu.close()


## A menu closed before the delay drops no card afterwards.
func test_a_close_before_the_reveal_adds_no_crowd_card() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open(_four_offers(), true)
	menu.close()
	await real_seconds(UpgradeMenu.CROWD_CARD_DELAY + 0.1)
	assert_bool(menu.cards.get_child(3) is Button).is_false()
	assert_int(plays("crowd_roar")).is_equal(0)


## A reroll pressed on a Roar before the crowd's card is in: the redrawn offer lands at once,
## the crowd's card in its frame, and the pending drop never adds a card or roars. No container
## owned: the container holds the right slot and the crowd's card the one before it.
func test_a_reroll_before_the_drop_shows_every_card_at_once() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.rerolls_left = 1
	RunState.favour = 80.0
	_watch_reveals()
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_bool(menu.cards.get_child(2) is Button).is_false()
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_int(menu.cards.get_child_count()).is_equal(4)
	for card: Control in menu.cards.get_children():
		assert_bool(card is Button).is_true()
	assert_str(menu.offers[3].id).is_equal("heart_container")
	assert_object(_frame_of(menu.cards.get_child(2))).is_equal(UiTheme.FRAME_CROWD)
	await real_seconds(UpgradeMenu.CROWD_CARD_DELAY + 0.1)
	assert_int(_revealed).is_equal(0)
	assert_int(plays("crowd_roar")).is_equal(1)  # the round's end only


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


## An Offer rank adds a card to every offer: a Quiet round gives four, all at the open, at full
## size, in the plain frame, with no reveal and no sound of their own (playtest 2, note 3).
func test_an_offer_rank_adds_a_card_to_a_quiet_offer_at_once() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.offer_bonus = 1
	_watch_reveals()
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_int(main.round_bands[0]).is_equal(FavourRules.QUIET)
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(4)
	assert_int(menu.cards.get_child_count()).is_equal(4)
	for card: Control in menu.cards.get_children():
		assert_bool(card is Button).is_true()
		assert_object(_frame_of(card)).is_equal(UiTheme.FRAME)
	assert_int(plays("ui_open")).is_equal(1)
	await real_seconds(UpgradeMenu.CROWD_CARD_DELAY + 0.1)
	assert_int(_revealed).is_equal(0)
	assert_int(plays("ui_open")).is_equal(1)
	assert_int(plays("crowd_roar")).is_equal(0)
	var first: Button = menu.cards.get_child(0)
	assert_vector(first.custom_minimum_size).is_equal(UpgradeMenu.CARD_SIZE)
	assert_vector((first.get_node("Face") as Control).scale).is_equal(Vector2.ONE)


## Two Offer ranks on a Roar make five: the cap, drawn at three quarters so the row fits the
## view. No container owned: the extra cards do not move it from the right slot, so the crowd's
## card is the fourth, and 4 takes it once it is in.
func test_two_offer_ranks_on_a_roar_make_five_cards_scaled_to_fit() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.offer_bonus = 2
	RunState.favour = FavourRules.MAX
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + UpgradeMenu.CROWD_CARD_DELAY + 0.2)
	var menu := _menu(main)
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(5)
	assert_int(menu.cards.get_child_count()).is_equal(5)
	assert_str(menu.heading_label.text).is_equal(UpgradeMenu.HEADING)
	assert_str(menu.offers[4].id).is_equal("heart_container")
	await wait_until(func() -> bool: return menu.cards.get_child(3) is Button, "the crowd's card built")
	for i in 5:
		var card: Button = menu.cards.get_child(i)
		assert_vector(card.custom_minimum_size).is_equal(UpgradeMenu.CARD_SIZE * 0.75)
		assert_vector((card.get_node("Face") as Control).scale).is_equal(Vector2(0.75, 0.75))
		assert_object(_frame_of(card)).is_equal(UiTheme.FRAME_CROWD if i == 3 else UiTheme.FRAME)
	await real_seconds(UpgradeMenu.CROWD_CARD_DROP + 0.1)
	var view_width := get_viewport().get_visible_rect().size.x
	assert_float(menu.cards.size.x).is_less_equal(view_width)
	assert_float(menu.cards.global_position.x).is_greater_equal(0.0)
	var crowds := menu.offers[3]
	await get_tree().process_frame
	Input.action_press("pick_4")
	await ticks(2)
	Input.action_release("pick_4")
	assert_bool(menu.is_open()).is_false()
	if crowds.kind == UpgradeDef.Kind.SWITCH:
		assert_str(RunState.build.weapon_id).is_equal(crowds.weapon_id)
	else:
		assert_int(RunState.build.rank_of(crowds.id)).is_equal(1)


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


func _offers(count: int) -> Array[UpgradeDef]:
	var offers := UpgradeCatalog.offers(RunState.build, false, RunState.stream("offers_%d" % count), count)
	assert_int(offers.size()).is_equal(count)
	return offers


## A Control's rect in the view (the menu's layer has no transform of its own).
func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


## The crowd's line moves nothing: with it or without it the heading's strip ends HEADING_GAP
## over the cards row at every count and scale, as before the line existed; without one the
## line's label is hidden.
func test_without_a_line_the_heading_sits_where_it_always_has() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	for count: int in [3, 4, 5]:
		menu.open(_offers(count), count == 4)
		var half := UpgradeMenu.CARD_SIZE.y * UpgradeMenu.card_scale(count, get_viewport().get_visible_rect().size.x) / 2.0
		assert_bool(menu.crowd_label.visible).is_false()
		assert_float(menu.heading_label.offset_top).is_equal(-(half + UpgradeMenu.HEADING_GAP + UiTheme.FONT_TITLE))
		assert_float(menu.heading_label.offset_bottom).is_equal(-(half + UpgradeMenu.HEADING_GAP))
		assert_float(menu.reroll_strip.offset_top).is_equal(half + UpgradeMenu.REROLL_GAP)
		menu.close()
	# A line: the heading stays; then an open without one hides the line again.
	menu.open(_offers(3), false, false, "A line")
	assert_bool(menu.crowd_label.visible).is_true()
	assert_float(menu.heading_label.offset_bottom).is_equal(-(UpgradeMenu.CARD_SIZE.y / 2.0 + UpgradeMenu.HEADING_GAP))
	menu.open(_offers(3))
	assert_bool(menu.crowd_label.visible).is_false()
	assert_float(menu.heading_label.offset_bottom).is_equal(-(UpgradeMenu.CARD_SIZE.y / 2.0 + UpgradeMenu.HEADING_GAP))
	menu.close()


## The crowd's line sits over the heading (the crowd speaks, then the heading, then the cards),
## CROWD_LINE_GAP clear of it and inside the view, the heading HEADING_GAP over the row (clear of
## the crowd's heads peeking over a Roar's card) and the Reroll strip under it, at three, four (a
## Roar), and five cards (three quarters).
func test_the_crowds_line_sits_over_the_heading_at_every_count() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	RunState.rerolls_left = 1
	var line := "The crowd loves to see you fight, every one of it"  # past the longest a line may be
	for count: int in [3, 4, 5]:
		menu.open(_offers(count), count >= 4, false, line)
		await get_tree().process_frame
		await get_tree().process_frame  # the row lays its cards out
		assert_bool(menu.crowd_label.visible).is_true()
		assert_str(menu.crowd_label.text).is_equal(line)
		var heading := _rect(menu.heading_label)
		var crowd := _rect(menu.crowd_label)
		var row := _rect(menu.cards)
		var reroll := _rect(menu.reroll_strip)
		assert_float(crowd.position.y).is_greater_equal(0.0)
		assert_float(crowd.end.y + UpgradeMenu.CROWD_LINE_GAP).is_less_equal(heading.position.y)
		assert_float(heading.end.y).is_less_equal(row.position.y - UpgradeMenu.HEADING_GAP)
		assert_float(reroll.position.y).is_greater_equal(row.end.y)
		assert_float(menu.crowd_label.get_minimum_size().x).is_less_equal(get_viewport().get_visible_rect().size.x)
		menu.close()


## The parts of a card's face the grey falls on (the paper, the frame, the column), never the
## chain over them.
func _face_parts(card: Control) -> Array[CanvasItem]:
	return [card.get_node("Face/Paper"), card.get_node("Face/Frame"), card.get_node("Face/Column")]


## A card taken by the crowd: greyed under the chain, its face still the card's (icon, name,
## effect, rank), no hover brighten; every other card as ever.
func test_a_locked_card_is_greyed_and_chained_and_the_others_are_as_ever() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	var offers := _offers(3)
	menu.open(offers, false, false, "", 1)
	assert_int(menu.locked).is_equal(1)
	for i in 3:
		var card: Button = menu.cards.get_child(i)
		var chained := card.find_children("Chain", "", true, false)
		var texts := []
		for label in card.find_children("*", "Label", true, false):
			texts.append(label.text)
		assert_array(texts).contains([offers[i].name, offers[i].description])  # the face reads as ever
		if i == 1:
			assert_int(chained.size()).is_equal(1)
			assert_int(chained[0].find_children("*", "TextureRect", true, false).size()).is_greater(0)
			for part in _face_parts(card):
				assert_that(part.modulate).is_equal(UpgradeMenu.LOCKED_MODULATE)
			assert_that((chained[0] as CanvasItem).modulate).is_equal(Color.WHITE)  # the chain itself is not greyed
			assert_bool(card.disabled).is_true()
			card.mouse_entered.emit()
			assert_that(card.modulate).is_equal(Color.WHITE)  # no hover brighten
		else:
			assert_int(chained.size()).is_equal(0)
			for part in _face_parts(card):
				assert_that(part.modulate).is_equal(Color.WHITE)
			assert_bool(card.disabled).is_false()
	menu.close()


## Its key and a click take nothing, play the refusal (pick_denied: buy_denied), and leave the
## menu open; another card's key still takes that card.
func test_a_locked_cards_key_and_click_take_nothing_and_play_the_refusal() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var menu := _menu(main)
	var offers := _offers(3)
	menu.open(offers, false, false, "", 1)
	var chosen := []
	var on_chosen := func(card: UpgradeDef, _index: int) -> void: chosen.append(card.id)
	var denied := [0]
	var on_denied := func() -> void: denied[0] += 1
	menu.chosen.connect(on_chosen)
	Events.pick_denied.connect(on_denied)
	await press_action("pick_2")
	assert_array(chosen).is_empty()
	assert_int(denied[0]).is_equal(1)
	assert_int(plays("buy_denied")).is_equal(1)
	await click_control(menu.cards.get_child(1))
	assert_array(chosen).is_empty()
	assert_int(denied[0]).is_equal(2)  # the sound's min_gap may swallow a second play this soon: the signal is the refusal
	menu.choose(1)
	assert_array(chosen).is_empty()
	assert_int(denied[0]).is_equal(3)
	assert_bool(menu.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	Events.pick_denied.disconnect(on_denied)
	await press_action("pick_1")
	assert_array(chosen).is_equal([offers[0].id])
	menu.chosen.disconnect(on_chosen)
	await hover_at(Vector2.ZERO)
	menu.close()


## A lock moves nothing: every card's rect is the same as without one, at three, four, and five
## cards, the lock in each slot.
func test_a_lock_leaves_the_layout_as_it_was_at_every_count() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	for count: int in [3, 4, 5]:
		var offers := _offers(count)
		menu.open(offers)
		await get_tree().process_frame
		await get_tree().process_frame  # the row lays its cards out
		var plain: Array[Rect2] = []
		for card: Control in menu.cards.get_children():
			plain.append(_rect(card))
		menu.close()
		for at in count:
			menu.open(offers, false, false, "", at)
			await get_tree().process_frame
			await get_tree().process_frame
			for i in count:
				var card: Control = menu.cards.get_child(i)
				assert_that(_rect(card)).is_equal(plain[i])
				assert_int(card.find_children("Chain", "", true, false).size()).is_equal(1 if i == at else 0)
			menu.close()


## An open without a lock (a reroll at another band, a later round) chains nothing.
func test_an_open_without_a_lock_clears_the_last_one() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open(_offers(3), false, false, "", 2)
	menu.open(_offers(3))
	assert_int(menu.locked).is_equal(-1)
	assert_int(menu.find_children("Chain", "", true, false).size()).is_equal(0)
	menu.close()


## A closed picker holds no lock: `locked` is the open offer's, never the last one's.
func test_closing_forgets_the_lock() -> void:
	var main := quiet_main()
	var menu := _menu(main)
	menu.open(_offers(3), false, false, "", 2)
	menu.close()
	assert_int(menu.locked).is_equal(-1)


## A whole player who owns no heart container finds it on the right at every pick until one is
## taken (playtest 1 of M6, note 5); once owned, a whole player's offer has no heal card.
func test_a_whole_player_finds_the_container_on_the_right_until_one_is_taken() -> void:
	var main := quiet_main_with_series(tiny_series(3))
	var player: Player = main.get_node("Player")
	assert_int(player.hp).is_equal(player.max_hp)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_int(menu.offers.size()).is_equal(3)
	assert_str(menu.offers[2].id).is_equal("heart_container")
	menu.choose(2)
	await get_tree().process_frame
	assert_int(RunState.build.rank_of("heart_container")).is_equal(1)
	assert_int(player.hp).is_equal(player.max_hp)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(menu.is_open()).is_true()
	var ids: Array[String] = []
	for card in menu.offers:
		ids.append(card.id)
	assert_array(ids).not_contains(["heal"])
	assert_array(ids).is_equal(_draw_ids("upgrades:%d:0" % main.round_index, 3))  # the plain draw, nothing held
	menu.close()


## On a whole player's first Roar the container holds the right slot from the open and the
## crowd's card drops into the one before it.
func test_a_whole_roar_before_the_first_container_drops_the_crowds_card_before_it() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.favour = 80.0
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := _menu(main)
	assert_int(menu.offers.size()).is_equal(4)
	assert_str(menu.offers[3].id).is_equal("heart_container")
	assert_bool(menu.cards.get_child(2) is Button).is_false()
	assert_object(_frame_of(menu.cards.get_child(3))).is_equal(UiTheme.FRAME)
	await wait_until(func() -> bool: return menu.cards.get_child(2) is Button, "the crowd's card built")
	assert_object(_frame_of(menu.cards.get_child(2))).is_equal(UiTheme.FRAME_CROWD)
	menu.close()


func _draw_ids(stream_name: String, count: int) -> Array[String]:
	var ids: Array[String] = []
	for card in UpgradeCatalog.draw(UpgradeCatalog.pool(RunState.build), RunState.stream(stream_name), count):
		ids.append(card.id)
	return ids
