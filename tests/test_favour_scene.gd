extends SceneSuite
## The Favour node in the real main scene: one detector per act on the bus, the meter on
## RunState, the round's verdict (the crowd's sound, the granter, the fourth card on a Roar).
## Kills come from Health.take_damage, so enemy_died arrives synchronously; time is
## RunState.elapsed, advanced by ticks or set by hand.


func _player(main: Node) -> Player:
	return main.get_node("Player")


## A stationary chaser placed and killed at once; the corpse lingers for the kill freeze.
func _kill_one(main: Node, at: Vector2) -> void:
	var enemy := active_chaser_on(main, at)
	enemy.health.take_damage(100.0)


## Every favour_changed between _record_changes and _stop_recording, as [value, band, act].
var _changes: Array = []


func after_test() -> void:
	if Events.favour_changed.is_connected(_on_favour_changed):
		Events.favour_changed.disconnect(_on_favour_changed)
	super()


func _on_favour_changed(value: float, band: int, act: String) -> void:
	_changes.append([value, band, act])


func _record_changes() -> void:
	_changes = []
	Events.favour_changed.connect(_on_favour_changed)


func _stop_recording() -> void:
	Events.favour_changed.disconnect(_on_favour_changed)


func test_a_kill_raises_favour_by_three_and_names_the_act() -> void:
	var main := quiet_main()
	assert_float(RunState.favour).is_equal(FavourRules.START)
	_record_changes()
	_kill_one(main, _player(main).global_position + Vector2(80, 0))
	_stop_recording()
	assert_float(RunState.favour).is_equal(33.0)
	assert_array(_changes).is_equal([[33.0, FavourRules.QUIET, "kill"]])
	await wait_for_death_freeze()


func test_kills_within_the_chain_window_score_five_each_after_the_first() -> void:
	var main := quiet_main()
	var at := _player(main).global_position + Vector2(80, 0)
	_record_changes()
	_kill_one(main, at)
	assert_float(RunState.favour).is_equal(33.0)
	RunState.elapsed += 1.0  # inside the window
	_kill_one(main, at + Vector2(0, 20))
	assert_float(RunState.favour).is_equal(38.0)
	RunState.elapsed += 1.4
	_kill_one(main, at + Vector2(0, 40))
	assert_float(RunState.favour).is_equal(43.0)
	RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1  # the window closed
	_kill_one(main, at + Vector2(0, 60))
	assert_float(RunState.favour).is_equal(46.0)
	_stop_recording()
	var acts: Array[String] = []
	for change: Array in _changes:
		acts.append(change[2])
	assert_array(acts).is_equal(["kill", "kill", "chain", "kill", "chain", "kill"])
	await wait_for_death_freeze()


func test_a_hit_drops_twenty_and_ends_the_perfect_run() -> void:
	var main := quiet_main()
	var player := _player(main)
	assert_bool(RunState.perfect).is_true()
	_record_changes()
	player.hurt(1, player.global_position + Vector2(4, 0))
	_stop_recording()
	assert_float(RunState.favour).is_equal(10.0)
	assert_bool(RunState.perfect).is_false()
	assert_int(RunState.hits_this_round).is_equal(1)
	assert_array(_changes).is_equal([[10.0, FavourRules.BOO, "hit"]])


func test_a_dash_through_danger_then_a_kill_is_daring() -> void:
	var main := quiet_main()
	var player := _player(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)  # the chaser becomes harmful
	assert_bool(enemy.is_harmful()).is_true()
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)  # 49.5 px past the chaser
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_float(RunState.favour).is_equal(36.0)
	assert_array(_changes).is_equal([[33.0, FavourRules.QUIET, "kill"], [36.0, FavourRules.QUIET, "daring"]])
	await wait_for_death_freeze()


func test_a_real_dash_through_a_chaser_then_a_kill_is_daring() -> void:
	var main := quiet_main()
	var player := _player(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(24, 0))
	player.invuln_left = 100.0  # a contact hit would score "hit" and knock us off the path
	player.aim_override = player.global_position + Vector2(100, 0)
	await ticks(2)  # the chaser becomes harmful
	Input.action_press("move_right")
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	await ticks(12)  # the dash runs its nine ticks and ends
	Input.action_release("move_right")
	_record_changes()
	enemy.health.take_damage(100.0)  # about 0.2 s after the dash ended: inside the window
	_stop_recording()
	assert_float(RunState.favour).is_equal(36.0)
	assert_array(_changes).is_equal([[33.0, FavourRules.QUIET, "kill"], [36.0, FavourRules.QUIET, "daring"]])
	await wait_for_death_freeze()


func test_a_dash_in_the_open_then_a_kill_is_not_daring() -> void:
	var main := quiet_main()
	var player := _player(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(200, 0))
	await ticks(2)
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)  # ends 150 px short of it
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	assert_float(RunState.favour).is_equal(33.0)
	await wait_for_death_freeze()


func test_a_kill_after_the_dash_window_is_not_daring() -> void:
	var main := quiet_main()
	var player := _player(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += DashRules.DURATION + FavourRules.DASH_WINDOW + 0.1
	enemy.health.take_damage(100.0)
	assert_float(RunState.favour).is_equal(33.0)
	await wait_for_death_freeze()


func test_a_round_cleared_without_a_hit_is_clean_and_ends_the_perfect_run_below_roar() -> void:
	quiet_main_with_series(tiny_series(2))
	_record_changes()
	Events.round_cleared.emit()
	_stop_recording()
	assert_float(RunState.favour).is_equal(45.0)
	assert_array(_changes).is_equal([[45.0, FavourRules.QUIET, "clean_round"]])
	assert_bool(RunState.perfect).is_false()  # the round ended in Quiet


func test_a_round_cleared_after_a_hit_is_not_clean() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player := _player(main)
	player.hurt(1, player.global_position + Vector2(4, 0))
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal(10.0)
	assert_int(RunState.hits_this_round).is_equal(1)


func test_a_round_ending_in_roar_keeps_the_perfect_run_and_the_next_round_starts_clean() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.favour = 80.0
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal(95.0)
	assert_bool(RunState.perfect).is_true()
	RunState.hits_this_round = 1
	await clear_and_pick(main)
	await real_seconds(Main.ROUND_GAP + 0.1)
	assert_int(main.round_index).is_equal(1)
	assert_int(RunState.hits_this_round).is_equal(0)


func test_four_idle_seconds_beside_a_live_enemy_drain_two_in_the_fifth() -> void:
	var main := quiet_main()
	var player := _player(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(120, 0))
	await ticks(235)  # 3.9 s: inside the grace
	assert_float(RunState.favour).is_equal(30.0)
	_record_changes()
	await ticks(65)  # 5.0 s: about a second of drain at 2 a second
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(28.0, 0.1)
	assert_str(_changes[0][2]).is_equal(FavourRules.COWARDICE_ACT)
	assert_int(_changes[0][1]).is_equal(FavourRules.QUIET)
	# An engagement resets the clock: a hit on the enemy stops the drain.
	enemy.health.take_damage(1.0)
	var after_hit := RunState.favour
	await ticks(30)
	assert_float(RunState.favour).is_equal(after_hit)


func test_no_drain_without_a_harmful_enemy() -> void:
	var main := quiet_main()
	var player := _player(main)
	var enemy: Enemy = load(CHASER).instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 100.0  # never harmful in this test
	enemy.def.speed = 0.0
	enemies_of(main).add_child(enemy)
	enemy.global_position = player.global_position + Vector2(120, 0)
	await ticks(300)
	assert_float(RunState.favour).is_equal(30.0)


func test_round_ended_carries_the_band_and_plays_the_crowd() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var bands: Array[int] = []
	var on_ended := func(band: int) -> void: bands.append(band)
	Events.round_ended.connect(on_ended)
	RunState.favour = 40.0  # 55 after the clean round: Cheer
	Events.round_cleared.emit()
	Events.round_ended.disconnect(on_ended)
	assert_array(bands).is_equal([FavourRules.CHEER])
	assert_int(Audio.plays.get("crowd_cheer", 0)).is_equal(1)
	assert_int(Audio.plays.get("crowd_roar", 0)).is_equal(0)
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_false()


func test_a_roar_opens_four_cards_from_the_crowd_and_pick_4_takes_the_fourth() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.favour = 80.0
	Events.round_cleared.emit()
	assert_int(Audio.plays.get("crowd_roar", 0)).is_equal(1)
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(4)
	assert_int(menu.get_node("Center/Cards").get_child_count()).is_equal(4)
	var ids: Array[String] = []
	for card in menu.offers:
		ids.append(card.id)
	assert_int(ids.size()).is_equal(4)
	assert_bool(ids[3] in ids.slice(0, 3)).is_false()  # four distinct cards
	assert_bool(menu.granter_label.visible).is_true()
	assert_str(menu.granter_label.text).is_equal("The crowd")
	var card := menu.offers[3]
	await get_tree().process_frame  # a fresh frame, so the menu's is_action_just_pressed sees the key
	Input.action_press("pick_4")
	await ticks(2)
	Input.action_release("pick_4")
	assert_bool(menu.is_open()).is_false()
	if card.kind == UpgradeDef.Kind.SWITCH:
		assert_str(RunState.build.weapon_id).is_equal(card.weapon_id)
	else:
		assert_int(RunState.build.rank_of(card.id)).is_equal(1)


func test_below_cheer_the_emperor_grants_three_cards() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player := _player(main)
	player.hurt(1, player.global_position + Vector2(4, 0))  # 10: Boo, and no clean round
	Events.round_cleared.emit()
	assert_int(Audio.plays.get("crowd_boo", 0)).is_equal(1)
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(3)
	assert_str(menu.granter_label.text).is_equal("The emperor")
	menu.choose(0)
	await get_tree().process_frame


func test_a_refund_round_keeps_the_granter_and_the_count() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	Events.build_changed.emit()
	RunState.favour = 80.0
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	menu.chosen.emit(UpgradeCatalog.upgrade("switch_crossbow"), -1)  # one rank owned: one refund round
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(4)
	assert_str(menu.granter_label.text).is_equal("The crowd")
	menu.choose(0)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()


func test_a_new_run_forgets_the_last_kill_and_the_last_dash() -> void:
	# elapsed returns to 0 on a new run; a kill and a dash remembered from before it must not
	# chain with, or make daring, the next run's first kill.
	var main := quiet_main()
	var player := _player(main)
	var at := player.global_position + Vector2(80, 0)
	var first := active_chaser_on(main, at)
	await ticks(2)
	RunState.elapsed = 10.0  # no tick passes before the kill, so nothing drains
	Events.player_dashed.emit(player.global_position + Vector2(55, 0), Vector2.RIGHT)  # through it
	first.health.take_damage(100.0)
	assert_float(RunState.favour).is_equal(36.0)  # kill and daring
	RunState.start_run()
	_record_changes()
	_kill_one(main, at + Vector2(0, 40))
	_stop_recording()
	assert_float(RunState.favour).is_equal(FavourRules.START + 3.0)
	var acts: Array[String] = []
	for change: Array in _changes:
		acts.append(change[2])
	assert_array(acts).is_equal(["kill"])
	await wait_for_death_freeze()


func test_a_new_run_resets_the_meter() -> void:
	var main := quiet_main()
	var player := _player(main)
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_float(RunState.favour).is_equal(10.0)
	RunState.start_run()
	assert_float(RunState.favour).is_equal(FavourRules.START)
	assert_bool(RunState.perfect).is_true()
	assert_int(RunState.hits_this_round).is_equal(0)
