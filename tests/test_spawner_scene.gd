extends SceneSuite
## Scene tests for the Spawner running inside the real main scene.


func _main_with_fast_spawner(max_alive: int, seed_value: int = 5) -> Node:
	RunState.start_run(seed_value)
	var runner := scene_runner(MAIN)
	var main: Node = runner.scene()
	var spawner: Spawner = main.get_node("Spawner")
	spawner.interval_start = 0.05
	spawner.interval_min = 0.05
	spawner.max_alive = max_alive
	spawner.arm(0.0)
	return main


func test_spawns_up_to_max_alive_away_from_player() -> void:
	var main := _main_with_fast_spawner(3)
	await ticks(30)  # 0.5 s at 20 spawns/s would be 10 spawns; cap is 3
	var enemies: Node2D = enemies_of(main)
	assert_int(enemies.get_child_count()).is_equal(3)
	assert_int(main.get_node("Spawner").alive_count()).is_equal(3)
	var player: Node2D = main.get_node("Player")
	var bounds: Rect2 = main.get_node("Arena").bounds()
	for enemy in enemies.get_children():
		assert_bool(bounds.has_point(enemy.global_position)).is_true()
		# The first enemy activates (starts chasing) at tick 31, so this check must stay below that
		# or the distance assertion measures a chaser closing in rather than the spawn placement.
		assert_float(enemy.global_position.distance_to(player.global_position)).is_greater_equal(96.0)
		assert_object(enemy.target).is_same(player)


func test_alive_count_drops_when_an_enemy_dies() -> void:
	var main := _main_with_fast_spawner(2)
	await ticks(10)
	var spawner: Spawner = main.get_node("Spawner")
	assert_int(spawner.alive_count()).is_equal(2)
	spawner.enabled = false
	var enemy: Enemy = enemies_of(main).get_child(0)
	enemy.health.take_damage(100.0)
	await wait_for_death_freeze()
	assert_int(spawner.alive_count()).is_equal(1)


func test_disabled_spawner_spawns_nothing() -> void:
	var main := _main_with_fast_spawner(5)
	main.get_node("Spawner").enabled = false
	await ticks(30)
	assert_int(enemies_of(main).get_child_count()).is_equal(0)


func test_enemy_spawned_emitted_once_per_spawn_with_enemy_in_tree() -> void:
	var in_tree_flags: Array[bool] = []
	var on_spawned := func(enemy: Node2D) -> void: in_tree_flags.append(enemy.is_inside_tree())
	Events.enemy_spawned.connect(on_spawned)
	var main := _main_with_fast_spawner(3)
	await ticks(30)
	Events.enemy_spawned.disconnect(on_spawned)
	assert_int(in_tree_flags.size()).is_equal(3)
	assert_int(enemies_of(main).get_child_count()).is_equal(3)
	for flag in in_tree_flags:
		assert_bool(flag).is_true()


func test_cap_reopens_after_a_death() -> void:
	var main := _main_with_fast_spawner(2)
	await ticks(10)
	var spawner: Spawner = main.get_node("Spawner")
	var enemies: Node2D = enemies_of(main)
	assert_int(spawner.alive_count()).is_equal(2)
	var enemy: Enemy = enemies.get_child(0)
	enemy.health.take_damage(100.0)
	await wait_for_death_freeze()
	await ticks(10)
	assert_int(spawner.alive_count()).is_equal(2)
	assert_int(enemies.get_child_count()).is_equal(2)


func _first_spawn_position(seed_value: int) -> Vector2:
	var positions: Array[Vector2] = []
	var on_spawned := func(enemy: Node2D) -> void: positions.append(enemy.global_position)
	Events.enemy_spawned.connect(on_spawned)
	var main := _main_with_fast_spawner(1, seed_value)
	await ticks(5)
	Events.enemy_spawned.disconnect(on_spawned)
	main.queue_free()
	await get_tree().process_frame
	assert_int(positions.size()).is_equal(1)
	return positions[0]


func test_same_seed_gives_same_first_spawn_position() -> void:
	var run1: Vector2 = await _first_spawn_position(5)
	var run2: Vector2 = await _first_spawn_position(5)
	var run3: Vector2 = await _first_spawn_position(6)
	assert_vector(run2).is_equal(run1)
	assert_vector(run3).is_not_equal(run1)


func test_freeing_main_with_live_enemies_is_clean() -> void:
	var main := _main_with_fast_spawner(3)
	await ticks(30)
	assert_int(enemies_of(main).get_child_count()).is_equal(3)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# No push_error during teardown is the real assertion: gdUnit4 fails the test on one.
	assert_bool(is_instance_valid(main)).is_false()
