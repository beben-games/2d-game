extends GdUnitTestSuite
## Scene tests for the Spawner running inside the real main scene.


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _main_with_fast_spawner(max_alive: int) -> Node:
	RunState.start_run(5)
	var runner := scene_runner("res://scenes/main.tscn")
	var main: Node = runner.scene()
	var spawner: Spawner = main.get_node("Spawner")
	spawner.initial_delay = 0.0
	spawner.interval_start = 0.05
	spawner.interval_min = 0.05
	spawner.max_alive = max_alive
	spawner._timer = 0.0
	return main


func test_spawns_up_to_max_alive_away_from_player() -> void:
	var main := _main_with_fast_spawner(3)
	await _ticks(30)  # 0.5 s at 20 spawns/s would be 10 spawns; cap is 3
	var enemies: Node2D = main.get_node("Enemies")
	assert_int(enemies.get_child_count()).is_equal(3)
	assert_int(main.get_node("Spawner").alive_count()).is_equal(3)
	var player: Node2D = main.get_node("Player")
	var bounds: Rect2 = main.get_node("Arena").bounds()
	for enemy in enemies.get_children():
		assert_bool(bounds.has_point(enemy.global_position)).is_true()
		assert_float(enemy.global_position.distance_to(player.global_position)).is_greater_equal(96.0)
		assert_object(enemy.target).is_same(player)
	RunState.start_run()


func test_alive_count_drops_when_an_enemy_dies() -> void:
	var main := _main_with_fast_spawner(2)
	await _ticks(10)
	var spawner: Spawner = main.get_node("Spawner")
	assert_int(spawner.alive_count()).is_equal(2)
	spawner.enabled = false
	var enemy: Enemy = main.get_node("Enemies").get_child(0)
	enemy.health.take_damage(100.0)
	await _ticks(2)
	assert_int(spawner.alive_count()).is_equal(1)
	RunState.start_run()


func test_disabled_spawner_spawns_nothing() -> void:
	var main := _main_with_fast_spawner(5)
	main.get_node("Spawner").enabled = false
	await _ticks(30)
	assert_int(main.get_node("Enemies").get_child_count()).is_equal(0)
	RunState.start_run()
