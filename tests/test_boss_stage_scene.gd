extends SceneSuite
## Stage two in the real main scene: the tint and the roar at half health, the bigger ring, the
## summons at the wall midpoints in the `summoned` group, and the summons dying with the boss.


func test_half_health_enrages_at_the_next_edge_with_a_tint_and_a_roar() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 100.0  # stays in APPROACH: the edge is forced below
	var phases := []
	var on_phase := func(phase: int) -> void: phases.append(phase)
	Events.boss_phase_changed.connect(on_phase)
	boss.health.take_damage(boss.def.max_hp * 0.5)
	await ticks(2)
	assert_int(boss.brain.stage).is_equal(1)  # requested, not yet at an edge
	boss.def.approach_time = 0.0
	await ticks(2)
	Events.boss_phase_changed.disconnect(on_phase)
	assert_int(boss.brain.stage).is_equal(2)
	assert_array(phases).is_equal([2])
	assert_that(boss.get_node("Status").base_tint).is_equal(Boss.ENRAGED_TINT)
	assert_int(Audio.plays.get("boss_phase", 0)).is_equal(1)
	assert_float(Juice.trauma).is_greater(0.3)  # PHASE_TRAUMA 0.5 over the decayed hit's 0.15


func test_stage_two_rings_are_bigger() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 0.0
	boss.brain.stage = 2
	# Tick 1 activates, tick 2 takes the approach edge, the 0.45 s telegraph lands a tick late at
	# 60 Hz (28 ticks): the attack lands on tick 30, so 34 leaves slack.
	await ticks(34)
	assert_int(projectiles_of(main).get_child_count()).is_equal(boss.def.phase2_ring_count)


func test_the_summon_places_imps_at_the_wall_midpoints_in_the_summoned_group() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 0.0
	boss.brain.stage = 2
	boss.brain.pattern = BossBrain.Pattern.SUMMON
	await ticks(34)  # the attack lands on tick 30 (see the ring test)
	var bounds: Rect2 = main.get_node("Room").bounds()
	var imps := []
	for node in get_tree().get_nodes_in_group("summoned"):
		imps.append(node)
	assert_int(imps.size()).is_equal(boss.def.summon_count)
	var xs: Array[float] = []
	for imp: Enemy in imps:
		assert_object(imp.get_parent()).is_same(enemies_of(main))
		assert_object(imp.target).is_same(player)
		assert_float(imp.global_position.y).is_equal(bounds.get_center().y)
		xs.append(imp.global_position.x)
	xs.sort()
	assert_array(xs).is_equal([bounds.position.x + ArenaGrid.TILE, bounds.end.x - ArenaGrid.TILE])
	assert_int(Audio.plays.get("boss_summon", 0)).is_equal(1)


func test_the_summons_die_with_the_boss_and_never_advance_the_wave() -> void:
	var main := quiet_main_with_series(boss_series())
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	await ticks(20)
	var boss := enemies_of(main).get_child(0) as Boss
	own_def(boss)  # the runner's boss holds the shared boss.tres; never write through it
	boss.def.spawn_delay = 0.0  # the SPAWNING check reads the def every tick: active next tick
	boss.def.approach_time = 0.0
	boss.brain.stage = 2
	boss.brain.pattern = BossBrain.Pattern.SUMMON
	await ticks(34)  # the attack lands on tick 30 (see the ring test)
	assert_int(get_tree().get_nodes_in_group("summoned").size()).is_equal(2)
	var cleared := [0]
	var on_cleared := func() -> void: cleared[0] += 1
	Events.round_cleared.connect(on_cleared)
	var imp: Enemy = get_tree().get_nodes_in_group("summoned")[0]
	imp.health.take_damage(100.0)
	await wait_for_death_freeze()
	assert_int(cleared[0]).is_equal(0)
	boss.health.take_damage(1000.0)
	await get_tree().process_frame  # the deferred summon kill
	var other: Enemy = get_tree().get_nodes_in_group("summoned")[0]
	assert_bool(other.health.dead).is_true()
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await get_tree().physics_frame
	Events.round_cleared.disconnect(on_cleared)
	assert_int(cleared[0]).is_equal(1)
	assert_int(RunState.kills).is_equal(3)
