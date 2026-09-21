extends SceneSuite
## The Spawner as a placement service inside the real main scene.


func test_spawn_places_inside_bounds_away_from_player_and_targets_player() -> void:
	var main := quiet_main(5)
	var spawner: Spawner = main.get_node("Room/Spawner")
	var player: Player = main.get_node("Player")
	var bounds: Rect2 = main.get_node("Room").bounds()
	for i in 6:
		var enemy: Enemy = spawner.spawn(load(CHASER))
		assert_bool(bounds.has_point(enemy.global_position)).is_true()
		assert_float(enemy.global_position.distance_to(player.global_position)).is_greater_equal(96.0)
		assert_object(enemy.target).is_same(player)
	assert_int(enemies_of(main).get_child_count()).is_equal(6)


func test_spawn_at_a_given_point_and_emits_enemy_spawned_in_tree() -> void:
	var main := quiet_main()
	var flags: Array[bool] = []
	var on_spawned := func(enemy: Node2D) -> void: flags.append(enemy.is_inside_tree())
	Events.enemy_spawned.connect(on_spawned)
	var enemy: Enemy = main.get_node("Room/Spawner").spawn(load(CHASER), Vector2(100, 100))
	Events.enemy_spawned.disconnect(on_spawned)
	assert_vector(enemy.global_position).is_equal(Vector2(100, 100))
	assert_array(flags).is_equal([true])


func _first_spawn_position(seed_value: int) -> Vector2:
	var main := quiet_main(seed_value)
	var enemy: Enemy = main.get_node("Room/Spawner").spawn(load(CHASER))
	var p := enemy.global_position
	main.queue_free()
	await get_tree().process_frame
	return p


func test_same_seed_gives_same_first_spawn_position() -> void:
	var run1: Vector2 = await _first_spawn_position(5)
	var run2: Vector2 = await _first_spawn_position(5)
	var run3: Vector2 = await _first_spawn_position(6)
	assert_vector(run2).is_equal(run1)
	assert_vector(run3).is_not_equal(run1)


func test_freeing_main_with_live_enemies_is_clean() -> void:
	var main := quiet_main()
	var spawner: Spawner = main.get_node("Room/Spawner")
	for i in 3:
		spawner.spawn(load(CHASER))
	await ticks(5)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(main)).is_false()
