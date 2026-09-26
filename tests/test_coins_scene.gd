extends SceneSuite
## Coins in the real main scene: a kill's coins on the counter with a flight, the round's bonus
## (a Cheer pays half the tally through one flight, a Roar throws it as piles), the boss's coins
## always thrown, and a pile collected by walking or dashing onto it. Kills come from
## Health.take_damage, so enemy_died arrives synchronously.

const COIN_PILE := preload("res://scenes/coin_pile.tscn")

var _coin_changes: Array[int] = []
var _throws: Array[Array] = []
var _pickups: Array[Array] = []


func before_test() -> void:
	super()
	_coin_changes = []
	_throws = []
	_pickups = []
	Events.coins_changed.connect(_on_coins_changed)
	Events.coins_thrown.connect(_on_coins_thrown)
	Events.pile_collected.connect(_on_pile_collected)


func after_test() -> void:
	Events.coins_changed.disconnect(_on_coins_changed)
	Events.coins_thrown.disconnect(_on_coins_thrown)
	Events.pile_collected.disconnect(_on_pile_collected)
	super()


func _on_coins_changed(run_coins: int) -> void:
	_coin_changes.append(run_coins)


func _on_coins_thrown(position: Vector2, total: int) -> void:
	_throws.append([position, total])


func _on_pile_collected(position: Vector2, value: int) -> void:
	_pickups.append([position, value])


func _piles(main: Node) -> Array[CoinPile]:
	var piles: Array[CoinPile] = []
	for child in main.get_node("Room/Piles").get_children():
		piles.append(child as CoinPile)
	return piles


func _flights(main: Node) -> Array[CoinFlight]:
	var flights: Array[CoinFlight] = []
	for child in hud_of(main).get_children():
		if child is CoinFlight:
			flights.append(child)
	return flights


## A world position as the HUD layer sees it: the camera's view in screen pixels.
func _screen(main: Node, world_position: Vector2) -> Vector2:
	return main.get_viewport().get_canvas_transform() * world_position


func _sum(piles: Array[CoinPile]) -> int:
	var total := 0
	for pile in piles:
		total += pile.value
	return total


## A stationary chaser placed and killed at once; the corpse lingers for the kill freeze.
func _kill_one(main: Node, at: Vector2) -> void:
	var enemy := active_chaser_on(main, at)
	enemy.health.take_damage(100.0)


## Polls `condition` once per physics frame until it holds or `max_frames` pass, then asserts it
## held: the wait ends on the event (a pile landed, a flight gone, the picker up, a pile paid),
## never on a clock that a stalled frame could outrun.
func _wait_until(condition: Callable, what: String, max_frames := 300) -> void:
	for i in max_frames:
		if condition.call():
			break
		await get_tree().physics_frame
	assert_bool(condition.call()).override_failure_message("waited %d frames for %s" % [max_frames, what]).is_true()


func _all_landed(piles: Array[CoinPile]) -> bool:
	for pile in piles:
		if not pile.monitoring:
			return false
	return true


## A pile already on the floor at `at`, worth `value`.
func _landed_pile(main: Node, at: Vector2, value: int) -> CoinPile:
	var pile: CoinPile = COIN_PILE.instantiate()
	pile.value = value
	main.get_node("Room/Piles").add_child(pile)
	pile.land(at)
	return pile


func test_a_kill_pays_the_enemys_coins_to_the_counter_through_a_flight() -> void:
	var main := quiet_main()
	var hud := hud_of(main)
	assert_str(hud.coin_counter_text()).is_equal("0")
	var at := player_of(main).global_position + Vector2(80, 0)
	_kill_one(main, at)
	assert_int(RunState.coins).is_equal(1)
	assert_int(RunState.round_tally).is_equal(1)
	assert_array(_coin_changes).is_equal([1])
	assert_str(hud.coin_counter_text()).is_equal("1")
	var flights := _flights(main)
	assert_int(flights.size()).is_equal(1)
	assert_vector(flights[0].position).is_equal_approx(_screen(main, at), Vector2(0.01, 0.01))  # from the corpse
	assert_int(Audio.plays.get("coin_get", 0)).is_equal(0)  # not before it lands
	await _wait_until(func() -> bool: return _flights(main).is_empty(), "the flight to land and leave")
	assert_int(Audio.plays.get("coin_get", 0)).is_equal(1)
	await wait_for_death_freeze()


func test_throw_piles_tosses_seeded_piles_under_the_room_that_sum_to_the_total() -> void:
	var main := quiet_main(7)
	var room: Room = main.get_node("Room")
	var centre := room.bounds().get_center()
	main.throw_piles(centre, 12)
	var piles := _piles(main)
	assert_int(piles.size()).is_equal(PileRules.pile_count(12))
	assert_int(_sum(piles)).is_equal(12)
	assert_array(_throws).is_equal([[centre, 12]])
	assert_int(Audio.plays.get("coin_toss", 0)).is_equal(1)  # one sound per throw, not per pile
	assert_int(RunState.coins).is_equal(0)  # nothing paid until a pile is picked up
	for pile in piles:
		assert_bool(pile.monitoring).is_false()  # a pile in flight is not collected
	await _wait_until(func() -> bool: return _all_landed(piles), "the piles to land")
	var expected := PileRules.spots(centre, PileRules.PILE_RADIUS, piles.size(), room.global_bounds(), RunState.stream("piles:0"))
	for i in piles.size():
		assert_bool(piles[i].monitoring).is_true()
		assert_vector(piles[i].global_position).is_equal_approx(expected[i], Vector2(0.01, 0.01))
		assert_float(piles[i].global_position.distance_to(centre)).is_less_equal(PileRules.PILE_RADIUS)


func test_a_pile_the_player_walks_onto_pays_its_value_and_goes() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var at := player.global_position + Vector2(60, 0)
	var pile := _landed_pile(main, at, 3)
	await ticks(2)
	assert_int(RunState.coins).is_equal(0)  # not until the player is on it
	player.global_position = at
	await ticks(2)
	assert_int(RunState.coins).is_equal(3)
	assert_array(_coin_changes).is_equal([3])
	assert_array(_pickups).is_equal([[at, 3]])
	assert_int(Audio.plays.get("coin_pickup", 0)).is_equal(1)
	assert_str(hud_of(main).coin_counter_text()).is_equal("3")
	await get_tree().process_frame
	assert_bool(is_instance_valid(pile)).is_false()
	assert_int(_piles(main).size()).is_equal(0)


func test_a_dashing_player_collects_a_pile_too() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var at := player.global_position + Vector2(60, 0)
	_landed_pile(main, at, 2)
	await ticks(2)  # a body placed on a pile the frame it is made is not paired until a tick has passed
	# A dash that lasts the test and goes nowhere: the body sits on its dash layer (64) the whole time.
	player.dash_left = 100.0
	player.dash_dir = Vector2.ZERO
	player.collision_layer = Player.DASH_LAYER
	player.collision_mask = Player.DASH_MASK
	player.global_position = at
	await ticks(2)
	assert_int(player.collision_layer).is_equal(Player.DASH_LAYER)
	assert_int(RunState.coins).is_equal(2)
	assert_array(_pickups).is_equal([[at, 2]])


## A Roar throws around the player, so a pile can land under their feet.
func test_a_pile_landing_under_a_standing_player_pays() -> void:
	var main := quiet_main()
	var player := player_of(main)
	await ticks(2)
	var pile: CoinPile = COIN_PILE.instantiate()
	pile.value = 2
	main.get_node("Room/Piles").add_child(pile)
	pile.toss(player.global_position + Vector2(40, 0), player.global_position)
	await _wait_until(func() -> bool: return not _pickups.is_empty(), "the landed pile to pay")
	assert_int(RunState.coins).is_equal(2)
	assert_array(_pickups).is_equal([[player.global_position, 2]])


func test_a_round_ended_at_cheer_pays_half_the_tally_with_one_flight_from_the_box() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var at := player_of(main).global_position + Vector2(80, 0)
	for i in 4:
		_kill_one(main, at + Vector2(0, i * 20))
	assert_int(RunState.round_tally).is_equal(4)
	await _wait_until(func() -> bool: return _flights(main).is_empty(), "the kill flights to land")  # the freeze passes too
	await wait_for_death_freeze()
	RunState.favour = 40.0  # 55 after the clean round: Cheer
	Events.round_cleared.emit()
	assert_int(RunState.coins).is_equal(6)  # 4 plus half of 4
	assert_array(_coin_changes).is_equal([1, 2, 3, 4, 6])
	var flights := _flights(main)
	assert_int(flights.size()).is_equal(1)
	var box: EmperorBox = main.get_node("Room/EmperorBox")
	assert_vector(flights[0].position).is_equal_approx(_screen(main, box.centre()), Vector2(0.01, 0.01))  # from the box
	assert_array(_throws).is_empty()
	await ticks(2)
	assert_int(_piles(main).size()).is_equal(0)


## A Roar's piles land before the picker pauses the tree, wait under it (a paused Area2D fires no
## body_entered), and pay in the next round once the player walks over them.
func test_a_roar_throws_the_tally_and_the_piles_survive_the_picker_to_pay_in_the_next_round() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player := player_of(main)
	var at := player.global_position + Vector2(80, 0)
	for i in 4:
		_kill_one(main, at + Vector2(0, i * 20))
	await wait_for_death_freeze()
	RunState.favour = 80.0  # 95 after the clean round: Roar
	Events.round_cleared.emit()
	assert_int(RunState.coins).is_equal(4)
	await ticks(2)  # the throw is deferred out of the physics callback
	var piles := _piles(main)
	assert_int(piles.size()).is_equal(PileRules.pile_count(4))
	assert_int(_sum(piles)).is_equal(4)
	assert_array(_throws).is_equal([[player.global_position, 4]])
	assert_int(RunState.coins).is_equal(4)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	await _wait_until(func() -> bool: return menu.is_open(), "the picker to open")  # 0.8 s; the piles land at 0.4 s
	assert_bool(_all_landed(piles)).is_true()
	assert_int(_piles(main).size()).is_equal(piles.size())
	assert_int(RunState.coins).is_equal(4)
	menu.choose(0)
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
	player.global_position = piles[0].global_position
	# A plain placement pays in two ticks; the first step after the unpause reports no overlap yet.
	await _wait_until(func() -> bool: return RunState.coins > 4, "the pile under the player to pay")
	assert_int(RunState.coins).is_equal(4 + piles[0].value)
	await _wait_until(func() -> bool: return _piles(main).size() < piles.size(), "the paid pile to leave the tree")
	assert_int(_piles(main).size()).is_equal(piles.size() - 1)


func test_the_boss_death_throws_its_sixty_coins_and_pays_none_to_the_counter() -> void:
	var main := quiet_main()
	var at := player_of(main).global_position + Vector2(100, 0)
	var boss := active_boss_on(main, at)
	boss.health.take_damage(1000.0)
	assert_int(RunState.coins).is_equal(0)
	assert_int(RunState.round_tally).is_equal(0)
	assert_int(_flights(main).size()).is_equal(0)
	await ticks(2)
	var piles := _piles(main)
	assert_int(piles.size()).is_equal(PileRules.pile_count(60))
	assert_int(_sum(piles)).is_equal(60)
	assert_array(_throws).is_equal([[at, 60]])
	await real_seconds(Enemy.DEATH_HITSTOP + Boss.CORPSE_FLASH_HOLD + 0.1)


func test_the_tally_starts_over_with_the_next_round() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	_kill_one(main, player_of(main).global_position + Vector2(80, 0))
	assert_int(RunState.round_tally).is_equal(1)
	await wait_for_death_freeze()
	await clear_and_pick(main)  # 48 after the clean round: Quiet, no bonus
	await real_seconds(Main.ROUND_GAP + 0.1)
	await get_tree().physics_frame
	assert_int(RunState.round_index).is_equal(1)
	assert_int(RunState.round_tally).is_equal(0)
	assert_int(RunState.coins).is_equal(1)  # the run's coins stay


func test_a_throw_deferred_from_a_clear_does_not_land_in_a_run_started_the_same_frame() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	RunState.round_tally = 4
	RunState.favour = 80.0  # 95 after the clean round: Roar, the tally thrown deferred
	Events.round_cleared.emit()
	main.play(5)  # Play from the title in the same frame: a rebuilt Room before the deferred throw
	await ticks(2)
	assert_int(_piles(main).size()).is_equal(0)
	assert_array(_throws).is_empty()


func test_a_new_run_has_no_piles_and_a_zero_counter() -> void:
	var main := quiet_main()
	main.throw_piles(player_of(main).global_position, 12)
	_kill_one(main, player_of(main).global_position + Vector2(80, 0))
	assert_int(_piles(main).size()).is_equal(4)
	assert_str(hud_of(main).coin_counter_text()).is_equal("1")
	await wait_for_death_freeze()
	main.play(3)  # Play from the title: a fresh run in a rebuilt Room
	await get_tree().process_frame
	assert_int(RunState.coins).is_equal(0)
	assert_int(RunState.round_tally).is_equal(0)
	assert_int(_piles(main).size()).is_equal(0)
	assert_str(hud_of(main).coin_counter_text()).is_equal("0")
