extends SceneSuite
## Coins in the real main scene: a kill's coins on the counter with a flight, the round's bonus
## (a Cheer pays half the tally through one flight, a Roar throws it as piles), the boss's coins
## always thrown, and a pile collected by walking or dashing onto it. Kills come from
## Health.take_damage, so enemy_died arrives synchronously.

const COIN_PILE := preload("res://scenes/coin_pile.tscn")

var _coin_changes: Array[int] = []
var _throws: Array = []
var _pickups: Array = []


func before_test() -> void:
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


func _player(main: Node) -> Player:
	return main.get_node("Player")


func _hud(main: Node) -> CanvasLayer:
	return main.get_node("HUD")


func _piles(main: Node) -> Array[CoinPile]:
	var piles: Array[CoinPile] = []
	for child in main.get_node("Room/Piles").get_children():
		piles.append(child as CoinPile)
	return piles


func _flights(main: Node) -> Array[CoinFlight]:
	var flights: Array[CoinFlight] = []
	for child in _hud(main).get_children():
		if child is CoinFlight:
			flights.append(child)
	return flights


func _sum(piles: Array[CoinPile]) -> int:
	var total := 0
	for pile in piles:
		total += pile.value
	return total


## A stationary chaser placed and killed at once; the corpse lingers for the kill freeze.
func _kill_one(main: Node, at: Vector2) -> void:
	var enemy := active_chaser_on(main, at)
	enemy.health.take_damage(100.0)


## A pile already on the floor at `at`, worth `value`.
func _landed_pile(main: Node, at: Vector2, value: int) -> CoinPile:
	var pile: CoinPile = COIN_PILE.instantiate()
	pile.value = value
	main.get_node("Room/Piles").add_child(pile)
	pile.land(at)
	return pile


func test_a_kill_pays_the_enemys_coins_to_the_counter_through_a_flight() -> void:
	var main := quiet_main()
	var hud := _hud(main)
	assert_str(hud.coin_counter_text()).is_equal("0")
	_kill_one(main, _player(main).global_position + Vector2(80, 0))
	assert_int(RunState.coins).is_equal(1)
	assert_int(RunState.round_tally).is_equal(1)
	assert_array(_coin_changes).is_equal([1])
	assert_str(hud.coin_counter_text()).is_equal("1")
	assert_int(_flights(main).size()).is_equal(1)
	assert_int(Audio.plays.get("coin_get", 0)).is_equal(0)  # not before it lands
	await real_seconds(CoinFlight.FLIGHT_TIME + 0.1)
	await get_tree().process_frame  # the freed flight leaves the tree at the frame's end
	assert_int(_flights(main).size()).is_equal(0)
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
	await real_seconds(CoinPile.TOSS_TIME + 0.1)
	await get_tree().physics_frame
	var expected := PileRules.spots(centre, PileRules.PILE_RADIUS, piles.size(), room.bounds(), RunState.stream("piles:0"))
	for i in piles.size():
		assert_bool(piles[i].monitoring).is_true()
		assert_vector(piles[i].global_position).is_equal_approx(expected[i], Vector2(0.01, 0.01))
		assert_float(piles[i].global_position.distance_to(centre)).is_less_equal(PileRules.PILE_RADIUS)


func test_a_pile_the_player_walks_onto_pays_its_value_and_goes() -> void:
	var main := quiet_main()
	var player := _player(main)
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
	assert_str(_hud(main).coin_counter_text()).is_equal("3")
	await get_tree().process_frame
	assert_bool(is_instance_valid(pile)).is_false()
	assert_int(_piles(main).size()).is_equal(0)


func test_a_dashing_player_collects_a_pile_too() -> void:
	var main := quiet_main()
	var player := _player(main)
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
	var player := _player(main)
	await ticks(2)
	var pile: CoinPile = COIN_PILE.instantiate()
	pile.value = 2
	main.get_node("Room/Piles").add_child(pile)
	pile.toss(player.global_position + Vector2(40, 0), player.global_position)
	await real_seconds(CoinPile.TOSS_TIME + 0.1)
	await ticks(2)
	assert_int(RunState.coins).is_equal(2)
	assert_array(_pickups).is_equal([[player.global_position, 2]])


func test_a_round_ended_at_cheer_pays_half_the_tally_with_one_flight_from_the_box() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var at := _player(main).global_position + Vector2(80, 0)
	for i in 4:
		_kill_one(main, at + Vector2(0, i * 20))
	assert_int(RunState.round_tally).is_equal(4)
	await real_seconds(CoinFlight.FLIGHT_TIME + 0.1)  # the kill flights land (and the freeze passes)
	await get_tree().process_frame
	assert_int(_flights(main).size()).is_equal(0)
	RunState.favour = 40.0  # 55 after the clean round: Cheer
	Events.round_cleared.emit()
	assert_int(RunState.coins).is_equal(6)  # 4 plus half of 4
	assert_array(_coin_changes).is_equal([1, 2, 3, 4, 6])
	assert_int(_flights(main).size()).is_equal(1)
	assert_array(_throws).is_empty()
	await ticks(2)
	assert_int(_piles(main).size()).is_equal(0)


func test_a_round_ended_at_roar_throws_the_tally_and_the_counter_waits_for_the_pickup() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player := _player(main)
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
	await real_seconds(CoinPile.TOSS_TIME + 0.1)
	await get_tree().physics_frame
	player.global_position = piles[0].global_position
	await ticks(2)
	assert_int(RunState.coins).is_equal(4 + piles[0].value)


func test_the_boss_death_throws_its_sixty_coins_and_pays_none_to_the_counter() -> void:
	var main := quiet_main()
	var at := _player(main).global_position + Vector2(100, 0)
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


func test_a_new_run_has_no_piles_and_a_zero_counter() -> void:
	var main := quiet_main()
	main.throw_piles(_player(main).global_position, 12)
	_kill_one(main, _player(main).global_position + Vector2(80, 0))
	assert_int(_piles(main).size()).is_equal(4)
	assert_str(_hud(main).coin_counter_text()).is_equal("1")
	await wait_for_death_freeze()
	main.play(3)  # Play from the title: a fresh run in a rebuilt Room
	await get_tree().process_frame
	assert_int(RunState.coins).is_equal(0)
	assert_int(RunState.round_tally).is_equal(0)
	assert_int(_piles(main).size()).is_equal(0)
	assert_str(_hud(main).coin_counter_text()).is_equal("0")
