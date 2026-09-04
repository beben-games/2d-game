extends GdUnitTestSuite
## Contact damage, i-frames, knockback, death, and Main's reaction, inside the real main scene.


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func after_test() -> void:
	Juice.reset()
	RunState.start_run()


func _quiet_main() -> Node:
	RunState.start_run(3)
	var runner := scene_runner("res://scenes/main.tscn")
	var main: Node = runner.scene()
	main.get_node("Spawner").enabled = false
	return main


## Places an ACTIVE chaser on top of the player by skipping its spawn delay.
func _active_chaser_on(main: Node, at: Vector2) -> Enemy:
	var enemy: Enemy = load("res://scenes/enemies/chaser.tscn").instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 0.0
	enemy.def.speed = 0.0
	main.get_node("Enemies").add_child(enemy)
	enemy.global_position = at
	return enemy


func test_contact_deals_damage_once_per_invulnerability_window() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var hits := []
	var cb := func(d: int) -> void: hits.append(d)
	Events.player_hit.connect(cb)
	_active_chaser_on(main, player.global_position + Vector2(4, 0))
	await _ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)
	assert_array(hits).is_equal([1])
	assert_bool(player.invuln_left > 0.0).is_true()
	Events.player_hit.disconnect(cb)


func test_contact_knocks_player_away_from_enemy() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var start := player.global_position
	_active_chaser_on(main, start + Vector2(4, 0))  # enemy to the right
	await _ticks(20)  # the 0.09 s hit freeze shrinks physics delta for ~5 ticks; leave room to travel
	assert_float(player.global_position.x).is_less(start.x - 5.0)


func test_spawning_enemy_is_harmless() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var enemy: Enemy = load("res://scenes/enemies/chaser.tscn").instantiate()  # default 0.5 s spawn delay
	main.get_node("Enemies").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(4, 0)
	await _ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP)


func test_lethal_damage_emits_player_died_and_stops_spawner() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var spawner: Spawner = main.get_node("Spawner")
	spawner.enabled = true
	spawner.initial_delay = 100.0
	spawner.arm(100.0)
	var died := [0]
	var cb := func() -> void: died[0] += 1
	Events.player_died.connect(cb)
	player.hp = 1
	_active_chaser_on(main, player.global_position + Vector2(4, 0))
	await _ticks(5)
	assert_int(died[0]).is_equal(1)
	assert_bool(player.dead).is_true()
	assert_bool(spawner.enabled).is_false()
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	Events.player_died.disconnect(cb)
