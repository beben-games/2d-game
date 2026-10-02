extends SceneSuite
## The Favour node in the real main scene: one detector per act on the bus, the meter on
## RunState, the round's verdict (the crowd's sound, the fourth card on a Roar).
## Kills come from Health.take_damage, so enemy_died arrives synchronously; time is
## RunState.elapsed, advanced by ticks or set by hand. quiet_main runs the shipped series' round
## 1 (nine enemies), so a kill there pays the budget's ninth (`_ninth`); a tiny series' round has
## one enemy, so its first kill pays the whole budget.

## A kill's share in round 1 of the shipped series.
var _ninth := FavourRules.kill_value(9)


## A stationary chaser placed and killed at once; the corpse lingers for the kill freeze.
func _kill_one(main: Node, at: Vector2) -> void:
	var enemy := active_chaser_on(main, at)
	enemy.health.take_damage(100.0)


## Every favour_changed between _record_changes and _stop_recording, as [value, band, act].
var _changes: Array = []


func after_test() -> void:
	if Events.favour_changed.is_connected(_on_favour_changed):
		Events.favour_changed.disconnect(_on_favour_changed)
	await super()  # the base awaits a frame


func _on_favour_changed(value: float, band: int, act: String) -> void:
	_changes.append([value, band, act])


func _record_changes() -> void:
	_changes = []
	Events.favour_changed.connect(_on_favour_changed)


func _stop_recording() -> void:
	Events.favour_changed.disconnect(_on_favour_changed)


## The acts of the recorded changes, in order.
func _acts() -> Array[String]:
	var acts: Array[String] = []
	for change: Array in _changes:
		acts.append(change[2])
	return acts


func test_a_kill_in_a_nine_enemy_round_raises_favour_by_the_budgets_ninth() -> void:
	var main := quiet_main()
	assert_int(RunState.round_enemies).is_equal(9)  # Main set it from round 1's table
	assert_float(RunState.favour).is_equal(FavourRules.START)
	_record_changes()
	_kill_one(main, player_of(main).global_position + Vector2(80, 0))
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(20.0 + 40.0 / 9.0, 0.001)
	assert_int(_changes.size()).is_equal(1)
	assert_float(_changes[0][0]).is_equal_approx(20.0 + 40.0 / 9.0, 0.001)
	assert_array(_changes[0].slice(1)).is_equal([FavourRules.BOO, "kill"])
	await wait_for_death_freeze()


func test_kills_within_the_chain_window_score_the_chain_after_the_first() -> void:
	var main := quiet_main()
	var at := player_of(main).global_position + Vector2(80, 0)
	_record_changes()
	_kill_one(main, at)
	assert_float(RunState.favour).is_equal_approx(20.0 + _ninth, 0.001)
	RunState.elapsed += 1.0  # inside the window
	_kill_one(main, at + Vector2(0, 20))
	assert_float(RunState.favour).is_equal_approx(20.0 + 2.0 * _ninth + 2.0, 0.001)
	RunState.elapsed += 1.4
	_kill_one(main, at + Vector2(0, 40))
	assert_float(RunState.favour).is_equal_approx(20.0 + 3.0 * _ninth + 4.0, 0.001)
	RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1  # the window closed
	_kill_one(main, at + Vector2(0, 60))
	assert_float(RunState.favour).is_equal_approx(20.0 + 4.0 * _ninth + 4.0, 0.001)
	_stop_recording()
	assert_array(_acts()).is_equal(["kill", "kill", "chain", "kill", "chain", "kill"])
	await wait_for_death_freeze()


func test_a_hit_drops_twenty_five_and_ends_the_perfect_run() -> void:
	var main := quiet_main()
	var player := player_of(main)
	assert_bool(RunState.perfect).is_true()
	RunState.favour = 60.0  # from the start, 20, the hit would only show the clamp at 0
	_record_changes()
	player.hurt(1, player.global_position + Vector2(4, 0))
	_stop_recording()
	assert_float(RunState.favour).is_equal(35.0)
	assert_bool(RunState.perfect).is_false()
	assert_int(RunState.hits_this_round).is_equal(1)
	assert_array(_changes).is_equal([[35.0, FavourRules.QUIET, "hit"]])


## The dare is scored the moment the dash goes through danger (the meter answers the dash); the
## kill inside the window after it is daring on top.
func test_a_dash_through_danger_scores_the_dare_at_once_and_the_kill_after_it_the_daring() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)  # the chaser becomes harmful
	assert_bool(enemy.is_harmful()).is_true()
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)  # 49.5 px past the chaser
	assert_array(_changes).is_equal([[22.0, FavourRules.BOO, "dare"]])
	RunState.elapsed += 0.6  # inside the window, which counts from the dash's end
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(22.0 + _ninth + 5.0, 0.001)
	assert_array(_acts()).is_equal(["dare", "kill", "daring"])
	assert_int(_changes[2][1]).is_equal(FavourRules.QUIET)
	await wait_for_death_freeze()


func test_a_real_dash_through_a_chaser_then_a_kill_is_daring() -> void:
	var main := quiet_main()
	var player := player_of(main)
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
	assert_float(RunState.favour).is_equal(22.0)  # the dare, at the dash
	_record_changes()
	enemy.health.take_damage(100.0)  # 14 ticks after the press, so about 0.07 s after the dash ended: inside the window
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(22.0 + _ninth + 5.0, 0.001)
	assert_array(_acts()).is_equal(["kill", "daring"])
	await wait_for_death_freeze()


func test_a_dash_in_the_open_then_a_kill_is_not_daring() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(200, 0))
	await ticks(2)
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)  # ends 150 px short of it
	assert_array(_changes).is_empty()  # no dare
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(20.0 + _ninth, 0.001)
	assert_array(_acts()).is_equal(["kill"])
	await wait_for_death_freeze()


func test_a_kill_after_the_dash_window_is_not_daring() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += DashRules.DURATION + FavourRules.DASH_WINDOW + 0.1
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(22.0 + _ninth, 0.001)  # the dare stays; no daring
	assert_array(_acts()).is_equal(["dare", "kill"])
	await wait_for_death_freeze()


## A round's kills pay KILL_BUDGET in all: a tiny series' round holds one enemy, so its kill pays
## the whole budget and a second kill pays nothing but still holds the decay off. The next
## round's kills pay afresh.
func test_a_rounds_kills_never_pay_past_the_budget() -> void:
	var main := quiet_main_with_series(tiny_series(3))
	assert_int(RunState.round_enemies).is_equal(1)
	var at := player_of(main).global_position + Vector2(80, 0)
	_kill_one(main, at)
	assert_float(RunState.favour).is_equal(20.0 + FavourRules.KILL_BUDGET)
	RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1  # no chain
	_record_changes()
	_kill_one(main, at + Vector2(0, 30))
	_stop_recording()
	assert_float(RunState.favour).is_equal(60.0)
	assert_array(_changes).is_equal([[60.0, FavourRules.CHEER, "kill"]])
	assert_float(main.get_node("Favour").last_scoring_time).is_equal(RunState.elapsed)
	await wait_for_death_freeze()
	await clear_and_pick(main)
	await wait_for_round(main, 1)
	assert_int(main.round_index).is_equal(1)
	RunState.favour = 0.0
	_kill_one(main, at + Vector2(0, 60))
	assert_float(RunState.favour).is_equal(FavourRules.KILL_BUDGET)
	await wait_for_death_freeze()


## At the gate a clean round adds nothing; below it, it stops at the gate.
func test_a_clean_round_stops_at_the_gate() -> void:
	quiet_main_with_series(tiny_series(2))
	RunState.favour = 70.0
	_record_changes()
	Events.round_cleared.emit()
	_stop_recording()
	assert_float(RunState.favour).is_equal(FavourRules.ROAR_GATE)
	assert_array(_changes).is_equal([[FavourRules.ROAR_GATE, FavourRules.CHEER, "clean_round"]])


func test_a_clean_round_at_the_gate_adds_nothing() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.favour = FavourRules.ROAR_GATE
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal(FavourRules.ROAR_GATE)
	assert_int(main.round_bands[0]).is_equal(FavourRules.CHEER)


## At the gate the dare and the kill add nothing; the daring kill passes it into Roar.
func test_a_daring_kill_passes_the_gate() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)
	RunState.favour = FavourRules.ROAR_GATE
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_array(_changes).is_equal([
		[74.0, FavourRules.CHEER, "dare"], [74.0, FavourRules.CHEER, "kill"],
		[79.0, FavourRules.ROAR, "daring"],
	])
	# The daring kill opened the round's gate: the next kill adds in full past it.
	assert_bool(main.get_node("Favour").gate_open).is_true()
	RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1  # no chain
	_kill_one(main, player.global_position + Vector2(80, 0))
	assert_float(RunState.favour).is_equal_approx(79.0 + _ninth, 0.001)
	await wait_for_death_freeze()


## `count` kills of placed chasers, each past the chain window of the last, so each pays its
## share alone.
func _plain_kills(main: Node, count: int) -> void:
	var at := player_of(main).global_position + Vector2(80, -60)
	for i in count:
		RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1
		_kill_one(main, at + Vector2(0, 16 * i))


## Round 1 of the shipped series: eight plain kills (55.6), a dash through danger (57.6), the
## ninth kill inside the window, daring (62.0, then 67.0, the gate open), and the clean round's
## full ten (77.0): a Roar.
func test_round_one_with_a_daring_kill_and_a_clean_round_ends_in_roar() -> void:
	var main := quiet_main()
	var player := player_of(main)
	_plain_kills(main, 8)
	assert_float(RunState.favour).is_equal_approx(20.0 + 8.0 * _ninth, 0.001)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)  # the chaser becomes harmful
	RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1  # no chain
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	assert_float(RunState.favour).is_equal_approx(20.0 + FavourRules.KILL_BUDGET + 2.0 + 5.0, 0.001)
	assert_bool(main.get_node("Favour").gate_open).is_true()
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal_approx(77.0, 0.001)
	assert_array(main.round_bands).is_equal([FavourRules.ROAR])
	await wait_for_death_freeze()


## The same round with the dare but no daring kill: the gate stays shut and the clean round
## stops short of Roar (60 from the kills, 62 with the dare, 72 with the clean round): a Cheer.
func test_round_one_without_a_daring_kill_ends_in_cheer() -> void:
	var main := quiet_main()
	var player := player_of(main)
	_plain_kills(main, 8)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)
	RunState.elapsed += FavourRules.CHAIN_WINDOW + 0.1  # no chain
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += DashRules.DURATION + FavourRules.DASH_WINDOW + 0.1  # the window closed
	enemy.health.take_damage(100.0)
	assert_bool(main.get_node("Favour").gate_open).is_false()
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal_approx(72.0, 0.001)
	assert_array(main.round_bands).is_equal([FavourRules.CHEER])
	await wait_for_death_freeze()


## The crowd settles between rounds: a meter past the gate opens the next round at it, with
## `settle` on the bus, and the gate closed again; a meter under it is left alone, and nothing
## is emitted.
func test_a_round_starting_past_the_gate_opens_at_it() -> void:
	var main := quiet_main_with_series(tiny_series(3))
	var favour: Favour = main.get_node("Favour")
	await clear_and_pick(main)
	RunState.favour = 79.0
	favour.last_scoring_time = RunState.elapsed  # a scoring act at the pick: about 1 s idle at the round's start against the 2 s grace, so no decay lands in the gap
	favour.gate_open = true
	_record_changes()
	await wait_for_round(main, 1)
	_stop_recording()
	assert_int(main.round_index).is_equal(1)
	assert_float(RunState.favour).is_equal(FavourRules.ROAR_GATE)
	assert_array(_changes).is_equal([[FavourRules.ROAR_GATE, FavourRules.CHEER, FavourRules.SETTLE_ACT]])
	assert_bool(favour.gate_open).is_false()
	await clear_and_pick(main)
	RunState.favour = 60.0
	favour.last_scoring_time = RunState.elapsed  # a scoring act at the pick: about 1 s idle at the round's start against the 2 s grace, so no decay lands in the gap
	_record_changes()
	await wait_for_round(main, 2)
	_stop_recording()
	assert_int(main.round_index).is_equal(2)
	assert_float(RunState.favour).is_equal(60.0)
	assert_array(_changes).is_empty()


## A summon (the boss's, in the group `summoned`) is not in the round's table and pays no share,
## so the boss round's budget goes to the boss; its kill still counts for the chain.
func test_a_summons_kill_pays_no_share() -> void:
	var main := quiet_main_with_series(tiny_series(2))  # one enemy in the table, like the boss's round
	var at := player_of(main).global_position + Vector2(80, 0)
	var imp := active_chaser_on(main, at)
	imp.add_to_group("summoned")
	_record_changes()
	imp.health.take_damage(100.0)
	assert_float(RunState.favour).is_equal(20.0)
	assert_float(main.get_node("Favour").last_scoring_time).is_equal(RunState.elapsed)
	RunState.elapsed += 1.0  # inside the chain window
	_kill_one(main, at + Vector2(0, 30))
	_stop_recording()
	assert_float(RunState.favour).is_equal(20.0 + FavourRules.KILL_BUDGET + 2.0)
	assert_array(_acts()).is_equal(["kill", "kill", "chain"])
	await wait_for_death_freeze()


func test_a_round_cleared_without_a_hit_is_clean_and_ends_the_perfect_run_below_roar() -> void:
	quiet_main_with_series(tiny_series(2))
	_record_changes()
	Events.round_cleared.emit()
	_stop_recording()
	assert_float(RunState.favour).is_equal(30.0)
	assert_array(_changes).is_equal([[30.0, FavourRules.QUIET, "clean_round"]])
	assert_bool(RunState.perfect).is_false()  # the round ended in Quiet


func test_a_round_cleared_after_a_hit_is_not_clean() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player := player_of(main)
	player.hurt(1, player.global_position + Vector2(4, 0))  # 20 - 25, clamped
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal(0.0)
	assert_int(RunState.hits_this_round).is_equal(1)


func test_a_round_ending_in_roar_keeps_the_perfect_run_and_the_next_round_starts_clean() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.favour = 80.0  # past the gate (a daring kill's): the clean round adds nothing there
	Events.round_cleared.emit()
	assert_float(RunState.favour).is_equal(80.0)
	assert_bool(RunState.perfect).is_true()
	RunState.hits_this_round = 1
	await clear_and_pick(main)
	await wait_for_round(main, 1)
	assert_int(main.round_index).is_equal(1)
	assert_int(RunState.hits_this_round).is_equal(0)


## The decay: two seconds beside a live enemy without a scoring act, then 4 a second. A hit on
## an enemy that does not kill is not a scoring act and does not extend the grace; a kill is, and
## holds the decay off for a fresh grace.
func test_two_seconds_beside_a_live_enemy_without_a_scoring_act_drain_four_in_the_third() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var first := active_chaser_on(main, player.global_position + Vector2(120, 0))
	active_chaser_on(main, player.global_position + Vector2(140, 30))  # still live after the kill
	await ticks(90)  # 1.5 s
	first.health.take_damage(1.0)  # a hit inside the grace
	await ticks(24)  # 1.9 s: inside the grace
	assert_float(RunState.favour).is_equal(20.0)
	_record_changes()
	await ticks(66)  # 3.0 s: about a second of decay at 4 a second, the hit having extended nothing
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(16.0, 0.1)
	assert_str(_changes[0][2]).is_equal(FavourRules.DECAY_ACT)
	assert_int(_changes[0][1]).is_equal(FavourRules.BOO)
	# A scoring act resets the clock: the kill stops the decay for a fresh grace.
	first.health.take_damage(100.0)
	var after_kill := RunState.favour
	assert_float(after_kill).is_equal_approx(16.0 + _ninth, 0.1)
	await ticks(60)
	assert_float(RunState.favour).is_equal(after_kill)
	await wait_for_death_freeze()


## The decay needs no harmful enemy: it runs whenever a run is live, so a wave's spawn-in and
## the gap between rounds cool the crowd too.
func test_the_decay_runs_through_a_waves_spawn_in() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy: Enemy = load(CHASER).instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 100.0  # never harmful in this test
	enemy.def.speed = 0.0
	enemies_of(main).add_child(enemy)
	enemy.global_position = player.global_position + Vector2(120, 0)
	await ticks(300)  # 5.0 s: three seconds of decay past the grace
	assert_float(RunState.favour).is_equal_approx(8.0, 0.1)


func test_the_crowd_cools_in_the_gap_between_rounds_and_a_pause_holds_it() -> void:
	var main := quiet_main_with_series(tiny_series(3))
	await clear_and_pick(main)  # the clean round scored at the clear; Quiet, so no piles: the gap runs on its own
	assert_float(RunState.favour).is_equal(30.0)
	RunState.elapsed += FavourRules.DECAY_GRACE  # past the grace, with no enemy on the floor
	_record_changes()
	await ticks(30)  # half a second of the one-second gap
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(28.0, 0.1)
	assert_str(_changes[0][2]).is_equal(FavourRules.DECAY_ACT)
	var screen: BuildScreen = main.get_node("BuildScreen")
	screen.open()  # the pause screen: the tree pauses, and the gap's timer with it
	var held := RunState.favour
	await ticks(18)
	assert_float(RunState.favour).is_equal(held)
	screen.close()
	await ticks(12)
	assert_float(RunState.favour).is_equal_approx(held - 0.8, 0.1)


func test_after_a_win_the_crowd_stops_cooling() -> void:
	var main := quiet_main()
	RunState.favour = 60.0
	RunState.elapsed += 10.0  # past the grace: the decay would run
	Events.run_won.emit()
	await ticks(12)
	assert_float(RunState.favour).is_equal(60.0)
	assert_object(main).is_not_null()


func test_after_a_fall_nothing_decays() -> void:
	var main := quiet_main()
	var player := player_of(main)
	RunState.favour = 60.0
	player.hurt(100, player.global_position + Vector2(4, 0))  # the hit's -25, and the fall
	assert_bool(player.dead).is_true()
	assert_float(RunState.favour).is_equal(35.0)
	Juice.reset()  # the death's hitstop would stretch the ticks
	RunState.elapsed += 10.0
	await ticks(12)
	assert_float(RunState.favour).is_equal(35.0)


func test_round_ended_carries_the_band_and_plays_the_crowd() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var bands: Array[int] = []
	var on_ended := func(band: int) -> void: bands.append(band)
	Events.round_ended.connect(on_ended)
	RunState.favour = 40.0  # 50 after the clean round: Cheer
	Events.round_cleared.emit()
	Events.round_ended.disconnect(on_ended)
	assert_array(bands).is_equal([FavourRules.CHEER])
	assert_int(Audio.plays.get("crowd_cheer", 0)).is_equal(1)
	assert_int(Audio.plays.get("crowd_roar", 0)).is_equal(0)
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_false()


func test_a_roar_opens_four_cards_and_pick_4_takes_the_fourth() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.favour = 80.0
	Events.round_cleared.emit()
	assert_int(Audio.plays.get("crowd_roar", 0)).is_equal(1)
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(4)
	# The crowd's card arrives late: three at the open and its slot held, the card after its
	# delay and its drop.
	assert_int(menu.cards.get_child_count()).is_equal(4)
	assert_bool(menu.cards.get_child(3) is Button).is_false()
	await real_seconds(UpgradeMenu.CROWD_CARD_DELAY + UpgradeMenu.CROWD_CARD_DROP + 0.1)
	assert_bool(menu.cards.get_child(3) is Button).is_true()
	assert_int(Audio.plays.get("crowd_roar", 0)).is_equal(2)  # the reveal roars again
	var ids: Array[String] = []
	for card in menu.offers:
		ids.append(card.id)
	assert_int(ids.size()).is_equal(4)
	assert_bool(ids[3] in ids.slice(0, 3)).is_false()  # four distinct cards
	assert_bool(menu.heading_label.visible).is_true()
	assert_str(menu.heading_label.text).is_equal(UpgradeMenu.HEADING)
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


func test_below_cheer_three_cards_under_the_same_heading() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player := player_of(main)
	player.hurt(1, player.global_position + Vector2(4, 0))  # 0: Boo, and no clean round
	Events.round_cleared.emit()
	assert_int(Audio.plays.get("crowd_boo", 0)).is_equal(1)
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.offers.size()).is_equal(3)
	assert_str(menu.heading_label.text).is_equal(UpgradeMenu.HEADING)
	menu.choose(0)
	await get_tree().process_frame


## A round ends at `favour` with a hit counted (no clean round lifts it) and the picker opens.
func _end_round_at(main: Node, favour: float) -> UpgradeMenu:
	RunState.hits_this_round = 1
	RunState.favour = favour
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).is_true()
	return menu


## The card the lock's own stream names for the open offer (a full-health player).
func _expected_lock(menu: UpgradeMenu, stream_name: String) -> int:
	return UpgradeCatalog.locked_index(menu.offers, FavourRules.LOCKS_AT_BOO, RunState.stream(stream_name), false)


## A Boo round's picker: one card taken by the crowd (the lock's own stream, lock:<round>:<pick
## round>), chained in its slot, with the crowd's Boo line over the heading; the offers are the
## cards the offers' stream draws, as before there was a lock.
func test_a_boo_round_locks_one_card_under_the_crowds_line() -> void:
	use_story("res://data/story")
	var main := quiet_main_with_series(tiny_series(2))
	var menu := await _end_round_at(main, 10.0)
	assert_int(menu.offers.size()).is_equal(3)
	var expected := UpgradeCatalog.offers(RunState.build, false, RunState.stream("upgrades:0:0"), 3)
	assert_array(menu.offers).is_equal(expected)  # the lock draws from its own stream
	assert_int(menu.locked).is_between(0, 2)
	assert_int(menu.locked).is_equal(_expected_lock(menu, "lock:0:0"))
	assert_int(menu.cards.get_child(menu.locked).find_children("Chain", "", true, false).size()).is_equal(1)
	assert_bool(menu.crowd_label.visible).is_true()
	assert_str(menu.heading_label.text).is_equal(UpgradeMenu.HEADING)
	menu.choose(menu.locked)
	assert_bool(menu.is_open()).is_true()  # refused
	menu.choose((menu.locked + 1) % 3)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()


## Every other band locks nothing.
func test_a_quiet_a_cheer_and_a_roar_round_lock_nothing() -> void:
	for favour: float in [35.0, 60.0, 90.0]:
		var main := quiet_main_with_series(tiny_series(2))
		var menu := await _end_round_at(main, favour)
		assert_int(menu.locked).override_failure_message("at %.0f" % favour).is_equal(-1)
		assert_int(menu.find_children("Chain", "", true, false).size()).is_equal(0)
		menu.close()
		main.queue_free()
		await get_tree().process_frame


## A reroll at Boo redraws the cards and the lock with them (lock:<round>:<pick round>:r<n>).
func test_a_reroll_at_boo_redraws_and_still_locks_one() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.rerolls_left = 1
	var menu := await _end_round_at(main, 10.0)
	assert_int(menu.locked).is_equal(_expected_lock(menu, "lock:0:0"))
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_int(RunState.rerolls_left).is_equal(0)
	assert_array(menu.offers).is_equal(UpgradeCatalog.offers(RunState.build, false, RunState.stream("upgrades:0:0:r1"), 3))
	assert_int(menu.locked).is_between(0, 2)
	assert_int(menu.locked).is_equal(_expected_lock(menu, "lock:0:0:r1"))
	assert_int(menu.cards.get_child(menu.locked).find_children("Chain", "", true, false).size()).is_equal(1)


## A refund round's re-open (after a switch with a rank owned) is still the Boo round's: it locks.
func test_a_refund_round_at_boo_locks_one_too() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	Events.build_changed.emit()
	var menu := await _end_round_at(main, 10.0)
	menu.chosen.emit(UpgradeCatalog.upgrade("switch_crossbow"), -1)  # one rank owned: one refund round
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.locked).is_between(0, 2)
	assert_int(menu.locked).is_equal(_expected_lock(menu, "lock:0:1"))


## The same seed and the same picks lock the same card.
func test_the_same_seed_locks_the_same_card() -> void:
	var first := await _boo_lock_for_seed(4242)
	var second := await _boo_lock_for_seed(4242)
	assert_array(second).is_equal(first)
	assert_int(int(first[1])).is_between(0, 2)


func _boo_lock_for_seed(seed_value: int) -> Array:
	RunState.start_run(seed_value)
	var main := quiet_main_with_series(tiny_series(2))
	var menu := await _end_round_at(main, 10.0)
	var ids := []
	for card in menu.offers:
		ids.append(card.id)
	var result := [ids, menu.locked]
	menu.close()
	main.queue_free()
	await get_tree().process_frame
	return result


func test_a_refund_round_keeps_the_count_and_the_heading() -> void:
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
	assert_str(menu.heading_label.text).is_equal(UpgradeMenu.HEADING)
	# The refund round lands every card at once, the crowd's in its frame; the first open's
	# pending drop never adds a card or roars.
	for card: Control in menu.cards.get_children():
		assert_bool(card is Button).is_true()
	assert_object((menu.cards.get_child(3).get_node("Face/Frame") as NinePatchRect).region_rect).is_equal(UiTheme.FRAME_CROWD)
	await real_seconds(UpgradeMenu.CROWD_CARD_DELAY + 0.1)
	assert_int(menu.cards.get_child_count()).is_equal(4)
	assert_int(Audio.plays.get("crowd_roar", 0)).is_equal(1)  # the round's end only
	menu.choose(0)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()


func test_a_new_run_forgets_the_last_kill_and_the_last_dash() -> void:
	# elapsed returns to 0 on a new run; a kill and a dash remembered from before it must not
	# chain with, or make daring, the next run's first kill.
	var main := quiet_main()
	var player := player_of(main)
	var at := player.global_position + Vector2(80, 0)
	var first := active_chaser_on(main, at)
	await ticks(2)
	RunState.elapsed = 10.0  # no tick passes before the kill, so nothing decays
	Events.player_dashed.emit(player.global_position + Vector2(55, 0), Vector2.RIGHT)  # through it
	first.health.take_damage(100.0)
	assert_float(RunState.favour).is_equal_approx(22.0 + _ninth + 5.0, 0.001)  # the dare, the kill, the daring
	main._start_run(-1, {})  # a new run through Main: the arena and round 0 (nine enemies) again
	main.get_node("Room/WaveRunner").enabled = false  # the new Room's runner: nothing spawns
	assert_int(RunState.round_enemies).is_equal(9)
	_record_changes()
	_kill_one(main, at + Vector2(0, 40))
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(FavourRules.START + _ninth, 0.001)
	assert_array(_acts()).is_equal(["kill"])
	await wait_for_death_freeze()


## A new run closes the round's gate and gives the budget back: on the one-enemy series the first
## run's kill paid 40 and a daring opened the gate; the next run's first kill pays 40 again, under
## a closed gate.
func test_a_new_run_closes_the_gate_and_restores_the_budget() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var favour: Favour = main.get_node("Favour")
	var at := player_of(main).global_position + Vector2(80, 0)
	_kill_one(main, at)
	assert_float(RunState.favour).is_equal(20.0 + FavourRules.KILL_BUDGET)
	favour.gate_open = true
	await wait_for_death_freeze()
	main._start_run(-1, {})
	main.get_node("Room/WaveRunner").enabled = false  # the new Room's runner: nothing spawns
	assert_int(RunState.round_enemies).is_equal(1)
	assert_bool(favour.gate_open).is_false()
	assert_float(favour.round_kill_paid).is_equal(0.0)
	_kill_one(main, at)
	assert_float(RunState.favour).is_equal(FavourRules.START + FavourRules.KILL_BUDGET)
	await wait_for_death_freeze()


## The run's start alone resets the round's favour state: RunState.start_run with no round after
## it (no round_started) closes the gate a daring kill opened and zeroes the budget paid, so a run
## begun without a round starts clean.
func test_the_runs_start_alone_closes_the_gate_and_zeroes_the_paid_budget() -> void:
	var main := quiet_main()
	var favour: Favour = main.get_node("Favour")
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	assert_bool(favour.gate_open).is_true()
	assert_float(favour.round_kill_paid).is_equal_approx(_ninth, 0.001)
	var rounds := [0]
	var on_round := func(_index: int, _total: int) -> void: rounds[0] += 1
	Events.round_started.connect(on_round)
	RunState.start_run()
	Events.round_started.disconnect(on_round)
	assert_int(rounds[0]).is_equal(0)
	assert_bool(favour.gate_open).is_false()
	assert_float(favour.round_kill_paid).is_equal(0.0)
	await wait_for_death_freeze()


## The boss's death clears the last round and wins the run (run_won, synchronously in its
## enemy_died); its summons die deferred after it and score nothing: the crowd has stopped.
func test_the_boss_summons_dying_after_the_win_score_nothing() -> void:
	var main := quiet_main_with_series(boss_series())
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	await ticks(20)
	var boss := enemies_of(main).get_child(0) as Boss
	own_def(boss)  # the runner's boss holds the shared boss.tres; never write through it
	boss.def.spawn_delay = 0.0
	boss.def.approach_time = 0.0
	boss.brain.stage = 2
	boss.brain.pattern = BossBrain.Pattern.SUMMON
	await ticks(34)  # the summon lands on tick 30 (test_boss_stage_scene)
	var imps := get_tree().get_nodes_in_group("summoned")
	assert_int(imps.size()).is_equal(2)
	var at_win := [-1]
	var on_won := func() -> void: at_win[0] = _changes.size()
	Events.run_won.connect(on_won)
	_record_changes()
	boss.health.take_damage(1000.0)
	await get_tree().process_frame  # the deferred summon kill
	_stop_recording()
	Events.run_won.disconnect(on_won)
	for imp: Enemy in imps:
		assert_bool(imp.health.dead).is_true()
	assert_int(at_win[0]).is_greater(0)  # the boss's kill scored before the win
	assert_int(_changes.size()).is_equal(at_win[0])
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


## After the fall a shot still in flight can kill: the kill and a dash score nothing, so the band
## the verdict reads stays the fall's.
func test_after_a_fall_a_kill_and_a_dash_score_nothing() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)
	player.hurt(100, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	Juice.reset()  # the death's hitstop would stretch the ticks
	var held := RunState.favour
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	RunState.elapsed += 0.3
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_array(_changes).is_empty()
	assert_float(RunState.favour).is_equal(held)
	await wait_for_death_freeze()


func test_a_new_run_resets_the_meter() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_float(RunState.favour).is_equal(0.0)
	RunState.start_run()
	assert_float(RunState.favour).is_equal(FavourRules.START)
	assert_bool(RunState.perfect).is_true()
	assert_int(RunState.hits_this_round).is_equal(0)


## A shot placed at `at`, flying along `direction` at its def's speed: an enemy's bolt (the
## shaman bolt, 150 px/s) or the player's own (the handgun's). Placed and dashed past in the same
## tick, so it is where it was put when the dash is judged.
func _shot_on(main: Node, scene_path: String, def_path: String, at: Vector2, direction: Vector2) -> Projectile:
	var shot: Projectile = load(scene_path).instantiate()
	shot.setup(load(def_path), direction)
	projectiles_of(main).add_child(shot)
	shot.global_position = at
	return shot


func _enemy_bolt_on(main: Node, at: Vector2, direction: Vector2) -> Projectile:
	return _shot_on(main, "res://scenes/enemies/enemy_bolt.tscn", "res://data/weapons/shaman_bolt.tres", at, direction)


## A narrow escape: the bolt, 30 px off the path's middle and flying at it, comes within 15 px of
## the dashing point (a still bolt there would be 30 px off: its flight is what counts). The dare
## at once, counted by the profile; a kill inside the window after it is daring.
func test_a_dash_past_an_enemy_bolt_scores_the_dare_and_the_kill_after_it_the_daring() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var enemy := active_chaser_on(main, player.global_position + Vector2(200, 0))  # far off the dash
	await ticks(2)
	var bolt := _enemy_bolt_on(main, player.global_position + Vector2(30, 30), Vector2.UP)
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	assert_array(_changes).is_equal([[22.0, FavourRules.BOO, "dare"]])
	assert_int(int(Profile.save.stat("dashes_through_danger"))).is_equal(1)
	bolt.queue_free()
	RunState.elapsed += 0.3  # inside the window
	enemy.health.take_damage(100.0)
	_stop_recording()
	assert_float(RunState.favour).is_equal_approx(22.0 + _ninth + 5.0, 0.001)
	assert_array(_acts()).is_equal(["dare", "kill", "daring"])
	await wait_for_death_freeze()


## One dare a dash, whatever it passed: a harmful chaser and a bolt beside the same path.
func test_a_dash_past_an_enemy_and_a_bolt_scores_one_dare() -> void:
	var main := quiet_main()
	var player := player_of(main)
	active_chaser_on(main, player.global_position + Vector2(25, 10))
	await ticks(2)  # the chaser becomes harmful
	var bolt := _enemy_bolt_on(main, player.global_position + Vector2(25, -10), Vector2.UP)
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	_stop_recording()
	bolt.queue_free()
	assert_array(_changes).is_equal([[22.0, FavourRules.BOO, "dare"]])


## The player's own shot is never a danger: one placed where an enemy's bolt would make a narrow
## escape (about 14.5 px from the dashing point at its closest) scores nothing.
func test_a_dash_past_the_players_own_shot_scores_nothing() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var shot := _shot_on(main, "res://scenes/projectile.tscn", "res://data/weapons/handgun.tres",
			player.global_position + Vector2(25, 5), Vector2.UP)
	_record_changes()
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	_stop_recording()
	shot.queue_free()
	assert_array(_changes).is_empty()


## A boss that never attacks (its approach outlasts the test) and never moves, 150 px off.
func _idle_boss_on(main: Node) -> Boss:
	var boss := active_boss_on(main, player_of(main).global_position + Vector2(150, 0))
	boss.def.approach_time = 100.0
	return boss


## Past the grace the meter drains; a hit that does not kill lands; then a second inside the
## grace that would follow it. Returns [the meter at the hit, the meter a second later].
func _hit_past_the_grace(enemy: Node2D) -> Array[float]:
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(6)
	assert_float(RunState.favour).is_less(FavourRules.START)  # the drain is running
	var at_hit := RunState.favour
	(enemy.get_node("Health") as Health).take_damage(1.0)
	await ticks(60)  # a second: inside a fresh grace, if the hit restarted it
	return [at_hit, RunState.favour]


## The boss's first stage has nothing to kill: a hit on it holds the decay off as a scoring act
## does, and pays nothing (no favour_changed at the hit).
func test_a_hit_on_the_boss_holds_the_decay_off_for_another_grace_and_pays_nothing() -> void:
	var main := quiet_main()
	var boss := _idle_boss_on(main)
	var favour: Favour = main.get_node("Favour")
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(6)
	assert_float(RunState.favour).is_less(FavourRules.START)  # the drain is running
	var at_hit := RunState.favour
	_record_changes()
	boss.health.take_damage(1.0)
	assert_array(_changes).is_empty()
	assert_float(favour.last_scoring_time).is_equal(RunState.elapsed)
	await ticks(60)  # a second, inside the fresh grace
	assert_array(_changes).is_empty()
	assert_float(RunState.favour).is_equal(at_hit)
	await ticks(72)  # past the fresh grace: the drain is back
	_stop_recording()
	assert_float(RunState.favour).is_less(at_hit)
	assert_str(_changes[0][2]).is_equal(FavourRules.DECAY_ACT)


## A status tick (the burn's quiet hit) on the boss holds nothing off: only a shot landing does.
func test_a_quiet_hit_on_the_boss_holds_nothing_off() -> void:
	var main := quiet_main()
	var boss := _idle_boss_on(main)
	var favour: Favour = main.get_node("Favour")
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(6)
	var before := favour.last_scoring_time
	var at_tick := RunState.favour
	boss.health.take_damage(0.5, Vector2.ZERO, true)  # a burn tick
	assert_float(favour.last_scoring_time).is_equal(before)
	await ticks(60)  # a second: the drain runs on
	assert_float(RunState.favour).is_equal_approx(at_tick - FavourRules.DECAY_PER_SECOND, 0.1)


## M5's rule for every other enemy: a hit that does not kill holds nothing off.
func test_a_hit_on_a_chaser_holds_nothing_off() -> void:
	var main := quiet_main()
	var chaser := active_chaser_on(main, player_of(main).global_position + Vector2(120, 0))
	var meter: Array[float] = await _hit_past_the_grace(chaser)
	assert_float(meter[1]).is_equal_approx(meter[0] - FavourRules.DECAY_PER_SECOND, 0.1)


## The boss's summons are other enemies: a hit on one holds nothing off either.
func test_a_hit_on_a_summon_holds_nothing_off() -> void:
	var main := quiet_main()
	_idle_boss_on(main)
	var imp := active_chaser_on(main, player_of(main).global_position + Vector2(-120, 0))
	imp.add_to_group("summoned")
	var meter: Array[float] = await _hit_past_the_grace(imp)
	assert_float(meter[1]).is_equal_approx(meter[0] - FavourRules.DECAY_PER_SECOND, 0.1)


## After the fall neither holds: a hit on the boss restarts no grace, a dash past a bolt is no dare.
func test_after_a_fall_a_hit_on_the_boss_and_a_dash_past_a_bolt_score_nothing() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var boss := _idle_boss_on(main)
	var favour: Favour = main.get_node("Favour")
	player.hurt(100, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	Juice.reset()  # the death's hitstop would stretch the ticks
	RunState.elapsed += 10.0
	var last := favour.last_scoring_time
	var bolt := _enemy_bolt_on(main, player.global_position + Vector2(25, 10), Vector2.UP)
	_record_changes()
	boss.health.take_damage(1.0)
	Events.player_dashed.emit(player.global_position, Vector2.RIGHT)
	_stop_recording()
	bolt.queue_free()
	assert_array(_changes).is_empty()
	assert_float(favour.last_scoring_time).is_equal(last)


## The round's losses by source (Favour.round_losses), as a [hit, fled, slow] triple.
func _losses(main: Node) -> Array[float]:
	var losses: Dictionary = (main.get_node("Favour") as Favour).round_losses
	var result: Array[float] = []
	for source: String in FavourRules.LOSS_SOURCES:
		result.append(float(losses.get(source, 0.0)))
	return result


## A hit tallies what the meter really lost: 25 from 60, only what was left from 10.
func test_a_hit_tallies_its_drop_under_hit() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var favour: Favour = main.get_node("Favour")
	assert_str(favour.round_loss()).is_equal(FavourRules.LOSS_NONE)
	RunState.favour = 60.0
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_array(_losses(main)).is_equal([25.0, 0.0, 0.0])
	assert_str(favour.round_loss()).is_equal("hit")
	RunState.favour = 10.0
	player.invuln_left = 0.0  # past the first hit's i-frames
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_array(_losses(main)).is_equal([35.0, 0.0, 0.0])


## A drain beside a live enemy is the gladiator's slowness: a stationary chaser within
## NEAR_RADIUS, a second past the grace, tallies the drain under slow.
func test_idle_seconds_beside_a_live_enemy_tally_slow() -> void:
	var main := quiet_main()
	active_chaser_on(main, player_of(main).global_position + Vector2(48, 0))
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(60)
	var losses := _losses(main)
	assert_float(losses[0]).is_equal(0.0)
	assert_float(losses[1]).is_equal(0.0)
	assert_float(losses[2]).is_equal_approx(FavourRules.DECAY_PER_SECOND, 0.2)
	assert_float(losses[2]).is_equal_approx(FavourRules.START - RunState.favour, 0.001)  # all of the drain
	assert_str((main.get_node("Favour") as Favour).round_loss()).is_equal("slow")


## Far from every live enemy the drain is the gladiator's flight.
func test_idle_seconds_far_from_every_live_enemy_tally_fled() -> void:
	var main := quiet_main()
	var player := player_of(main)
	active_chaser_on(main, player.global_position + Vector2(160, 0))
	active_chaser_on(main, player.global_position + Vector2(-160, 0))
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(60)
	var losses := _losses(main)
	assert_float(losses[1]).is_equal_approx(FavourRules.DECAY_PER_SECOND, 0.2)
	assert_float(losses[0] + losses[2]).is_equal(0.0)
	assert_str((main.get_node("Favour") as Favour).round_loss()).is_equal("fled")


## A drain with no harmful enemy (none on the floor, or one still spawning in) is nobody's: the
## meter drops, the tally stays empty.
func test_a_drain_with_no_harmful_enemy_tallies_nothing() -> void:
	var main := quiet_main()
	var enemy: Enemy = load(CHASER).instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 100.0  # never harmful in this test
	enemy.def.speed = 0.0
	enemies_of(main).add_child(enemy)
	enemy.global_position = player_of(main).global_position + Vector2(40, 0)
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(60)
	assert_float(RunState.favour).is_less(FavourRules.START)  # the drain ran
	assert_array(_losses(main)).is_equal([0.0, 0.0, 0.0])
	assert_str((main.get_node("Favour") as Favour).round_loss()).is_equal(FavourRules.LOSS_NONE)


## The boss round: idling far from the boss is fled; a summon beside the gladiator is a harmful
## enemy too, and the nearest makes it slow; a hit on the boss holds the drain off, so nothing
## is tallied inside the fresh grace.
func test_the_boss_round_tallies_fled_far_from_the_boss_and_slow_beside_a_summon() -> void:
	var main := quiet_main()
	var boss := _idle_boss_on(main)  # 150 px off
	var favour: Favour = main.get_node("Favour")
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(60)
	var fled := _losses(main)[1]
	assert_float(fled).is_greater(3.0)
	assert_float(_losses(main)[2]).is_equal(0.0)
	boss.health.take_damage(1.0)
	await ticks(60)  # inside the fresh grace
	assert_float(_losses(main)[1]).is_equal(fled)
	var imp := active_chaser_on(main, player_of(main).global_position + Vector2(-40, 0))
	imp.add_to_group("summoned")
	RunState.elapsed += FavourRules.DECAY_GRACE
	await ticks(30)
	assert_float(_losses(main)[1]).is_equal(fled)
	assert_float(_losses(main)[2]).is_greater(1.0)
	assert_float(_losses(main)[2]).is_less(fled)
	assert_str(favour.round_loss()).is_equal("fled")  # still the larger


## Nothing tallies once the run is not live: a hit and a drain after the win.
func test_nothing_tallies_once_the_run_is_not_live() -> void:
	var main := quiet_main()
	var player := player_of(main)
	active_chaser_on(main, player.global_position + Vector2(48, 0))
	RunState.favour = 60.0
	Events.run_won.emit()
	player.hurt(1, player.global_position + Vector2(4, 0))
	RunState.elapsed += 10.0
	await ticks(12)
	assert_array(_losses(main)).is_equal([0.0, 0.0, 0.0])


## The killing hit is tallied (the run was live when it landed); the drain after the fall is not.
func test_nothing_tallies_after_the_fall_but_the_killing_hit() -> void:
	var main := quiet_main()
	var player := player_of(main)
	active_chaser_on(main, player.global_position + Vector2(48, 0))
	RunState.favour = 60.0
	player.hurt(100, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	Juice.reset()  # the death's hitstop would stretch the ticks
	assert_array(_losses(main)).is_equal([25.0, 0.0, 0.0])
	RunState.elapsed += 10.0
	await ticks(12)
	assert_array(_losses(main)).is_equal([25.0, 0.0, 0.0])


## The tally is the round's: the next round's start clears it, and the settle at that start (a
## meter past the gate brought down to it) is no loss of the new round.
func test_the_tally_clears_at_the_next_round_and_the_settle_is_no_loss() -> void:
	var main := quiet_main_with_series(tiny_series(3))
	var player := player_of(main)
	var favour: Favour = main.get_node("Favour")
	RunState.favour = 60.0
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_str(favour.round_loss()).is_equal("hit")
	await clear_and_pick(main)
	assert_str(favour.round_loss()).is_equal("hit")  # read at the pick: still the round's
	RunState.favour = 90.0
	favour.last_scoring_time = RunState.elapsed  # no decay in the gap
	await wait_for_round(main, 1)
	assert_float(RunState.favour).is_equal(FavourRules.ROAR_GATE)  # settled
	assert_array(_losses(main)).is_equal([0.0, 0.0, 0.0])
	assert_str(favour.round_loss()).is_equal(FavourRules.LOSS_NONE)


## Fled means running, not range: kiting a chaser at range while landing hits that do not kill
## is fighting, so the drain is slow; once no shot has landed for DECAY_GRACE it is fled.
func test_kiting_at_range_while_landing_hits_tallies_slow_until_the_hits_stop() -> void:
	var main := quiet_main()
	var chaser := active_chaser_on(main, player_of(main).global_position + Vector2(160, 0))
	RunState.elapsed += FavourRules.DECAY_GRACE
	chaser.health.take_damage(0.5)  # a landed shot that does not kill
	await ticks(30)
	chaser.health.take_damage(0.5)
	await ticks(30)
	var losses := _losses(main)
	assert_float(losses[2]).is_equal_approx(FavourRules.DECAY_PER_SECOND, 0.2)
	assert_float(losses[1]).is_equal(0.0)
	RunState.elapsed += FavourRules.DECAY_GRACE  # the last hit is past the grace now
	await ticks(30)
	assert_float(_losses(main)[1]).is_greater(1.0)
	assert_float(_losses(main)[2]).is_equal(losses[2])


## A shot stopped by a shield landed on the fight: engaged, so a drain far off is slow.
func test_a_shot_blocked_by_a_shield_counts_as_engaged() -> void:
	var main := quiet_main()
	active_chaser_on(main, player_of(main).global_position + Vector2(160, 0))
	RunState.elapsed += FavourRules.DECAY_GRACE
	Events.shot_blocked.emit(player_of(main).global_position + Vector2(150, 0))
	await ticks(60)
	var losses := _losses(main)
	assert_float(losses[2]).is_equal_approx(FavourRules.DECAY_PER_SECOND, 0.2)
	assert_float(losses[1]).is_equal(0.0)


## A status tick (the burn's quiet hit) is not the gladiator fighting: far off, the drain is fled.
func test_a_quiet_burn_tick_is_not_engaged() -> void:
	var main := quiet_main()
	var chaser := active_chaser_on(main, player_of(main).global_position + Vector2(160, 0))
	RunState.elapsed += FavourRules.DECAY_GRACE
	chaser.health.take_damage(0.5, Vector2.ZERO, true)
	await ticks(60)
	var losses := _losses(main)
	assert_float(losses[1]).is_equal_approx(FavourRules.DECAY_PER_SECOND, 0.2)
	assert_float(losses[2]).is_equal(0.0)
