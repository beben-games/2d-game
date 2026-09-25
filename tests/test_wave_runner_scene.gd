extends SceneSuite
## WaveRunner inside the real main scene: places waves through the Spawner, counts its own
## Room's deaths, and reports wave starts and the round clear on the bus.

const CHASER_SCENE := preload("res://scenes/enemies/chaser.tscn")


func _table(counts: Array) -> WaveTable:
	var t := WaveTable.new()
	for count in counts:
		var g := SpawnGroup.new()
		g.enemy = CHASER_SCENE
		g.count = count
		var w := WaveDef.new()
		w.groups = [g]
		w.breather = 0.0
		t.waves.append(w)
	return t


func _kill_all(main: Node) -> void:
	for enemy in enemies_of(main).get_children():
		enemy.health.take_damage(100.0)
	await wait_for_death_freeze()


func test_places_the_wave_then_clears_the_room_when_all_are_dead() -> void:
	var main := quiet_main()
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var started := []
	var cleared := [0]
	var on_started := func(index: int, total: int) -> void: started.append([index, total])
	var on_cleared := func() -> void: cleared[0] += 1
	Events.wave_started.connect(on_started)
	Events.round_cleared.connect(on_cleared)
	runner.start(_table([2, 1]))
	runner.enabled = true
	await ticks(30)  # 0.5 s: breather 0 plus one 0.25 s interval
	assert_int(enemies_of(main).get_child_count()).is_equal(2)
	assert_int(RunState.wave).is_equal(0)
	await _kill_all(main)
	assert_int(RunState.wave).is_equal(1)
	assert_int(cleared[0]).is_equal(0)
	await ticks(10)
	assert_int(enemies_of(main).get_child_count()).is_equal(1)
	await _kill_all(main)
	Events.wave_started.disconnect(on_started)
	Events.round_cleared.disconnect(on_cleared)
	assert_array(started).is_equal([[0, 2], [1, 2]])
	assert_int(cleared[0]).is_equal(1)


func test_deaths_in_another_container_do_not_count() -> void:
	var main := quiet_main()
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var cleared := [0]
	var on_cleared := func() -> void: cleared[0] += 1
	Events.round_cleared.connect(on_cleared)
	runner.start(_table([1]))
	runner.enabled = true
	await ticks(5)
	assert_int(enemies_of(main).get_child_count()).is_equal(1)
	var stray: Enemy = CHASER_SCENE.instantiate()
	add_child(stray)
	auto_free(stray)
	stray.health.take_damage(100.0)
	await wait_for_death_freeze()
	Events.round_cleared.disconnect(on_cleared)
	assert_int(cleared[0]).is_equal(0)


func test_disabled_runner_places_nothing() -> void:
	var main := quiet_main()
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.start(_table([1]))  # breather 0: an enabled runner would place on the first tick
	await ticks(30)
	assert_int(enemies_of(main).get_child_count()).is_equal(0)


func test_disabled_runner_ignores_deaths() -> void:
	var main := quiet_main()
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var cleared := [0]
	var on_cleared := func() -> void: cleared[0] += 1
	Events.round_cleared.connect(on_cleared)
	runner.start(_table([1]))
	runner.enabled = true
	await ticks(5)
	assert_int(enemies_of(main).get_child_count()).is_equal(1)
	runner.enabled = false
	await _kill_all(main)
	Events.round_cleared.disconnect(on_cleared)
	assert_int(cleared[0]).is_equal(0)


func test_a_death_in_the_summoned_group_does_not_count() -> void:
	var main := quiet_main()
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var cleared := [0]
	var on_cleared := func() -> void: cleared[0] += 1
	Events.round_cleared.connect(on_cleared)
	runner.start(_table([1]))
	runner.enabled = true
	await ticks(5)
	var summon: Enemy = CHASER_SCENE.instantiate()
	summon.add_to_group("summoned")
	enemies_of(main).add_child(summon)
	summon.health.take_damage(100.0)
	await wait_for_death_freeze()
	assert_int(cleared[0]).is_equal(0)
	assert_int(RunState.kills).is_equal(1)  # it is still a kill
	await _kill_all(main)
	Events.round_cleared.disconnect(on_cleared)
	assert_int(cleared[0]).is_equal(1)
