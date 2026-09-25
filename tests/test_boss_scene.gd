extends SceneSuite
## The boss in the real main scene: its place, the ring and the volley, the charge stopping at a
## wall, contact damage, halved stun and chill, a stun that does not stop a charge, hits that
## barely move it, and its death clearing the room into the win.


func test_the_spawner_places_a_boss_at_the_top_centre() -> void:
	var main := quiet_main()
	var spawner: Spawner = main.get_node("Room/Spawner")
	var boss: Boss = spawner.spawn(load(BOSS))
	var bounds: Rect2 = main.get_node("Room").bounds()
	assert_vector(boss.global_position).is_equal(Vector2(bounds.get_center().x, bounds.position.y + ArenaGrid.TILE * 1.5))
	assert_bool(boss.is_in_group("boss")).is_true()
	assert_bool(boss.is_in_group("enemies")).is_true()
	assert_object(boss.target).is_same(main.get_node("Player"))
	assert_object(boss.projectile_parent).is_same(projectiles_of(main))
	assert_int(boss.collision_layer).is_equal(2)
	assert_int(boss.collision_mask).is_equal(19)
	assert_vector(boss.sprite.scale).is_equal(Vector2(2, 2))


func test_the_fade_in_ends_with_boss_spawned() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss: Boss = load(BOSS).instantiate()
	own_def(boss)
	boss.def.spawn_delay = 0.1
	enemies_of(main).add_child(boss)
	boss.global_position = player.global_position + Vector2(150, 0)
	var spawned := []
	var on_spawned := func(b: Node2D) -> void: spawned.append(b)
	Events.boss_spawned.connect(on_spawned)
	assert_bool(boss.is_harmful()).is_false()
	await ticks(9)
	Events.boss_spawned.disconnect(on_spawned)
	assert_array(spawned).is_equal([boss])
	assert_bool(boss.is_harmful()).is_true()
	assert_int(Audio.plays.get("boss_spawn", 0)).is_equal(1)
	assert_str(Audio.current_music).is_equal("music_boss")


func test_the_ring_fires_ring_count_bolts_after_the_telegraph() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 0.0
	# Tick 1 activates, tick 2 enters the telegraph (approach 0), 0.6 s = 36 ticks: the ring lands about tick 38.
	await ticks(30)
	assert_int(Audio.plays.get("boss_telegraph", 0)).is_equal(1)
	assert_int(projectiles_of(main).get_child_count()).is_equal(0)
	await ticks(12)
	assert_int(projectiles_of(main).get_child_count()).is_equal(boss.def.ring_count)
	var angles: Array[float] = []
	for bolt: Projectile in projectiles_of(main).get_children():
		assert_int(bolt.collision_layer).is_equal(8)
		angles.append(bolt.direction.angle())
	angles.sort()
	for i in range(1, angles.size()):
		assert_float(angles[i] - angles[i - 1]).is_equal_approx(TAU / boss.def.ring_count, 0.01)
	assert_int(Audio.plays.get("boss_ring", 0)).is_equal(1)
	assert_int(boss.brain.phase).is_equal(BossBrain.Phase.RECOVER)


func test_the_volley_fans_bolts_at_the_player() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 0.0
	boss.brain.pattern = BossBrain.Pattern.VOLLEY
	await ticks(42)
	assert_int(projectiles_of(main).get_child_count()).is_equal(boss.def.volley_count)
	var half := deg_to_rad(boss.def.volley_spread_degrees) * 0.5
	for bolt: Projectile in projectiles_of(main).get_children():
		var off := angle_difference(PI, bolt.direction.angle())  # the player is to the left
		assert_float(absf(off)).is_less_equal(half + 0.01)
	assert_int(Audio.plays.get("boss_volley", 0)).is_equal(1)


func test_the_charge_locks_its_direction_and_stops_at_the_wall() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var bounds: Rect2 = main.get_node("Room").bounds()
	player.invuln_left = 100.0
	player.global_position = Vector2(bounds.end.x - 12.0, bounds.get_center().y)
	var boss := active_boss_on(main, player.global_position + Vector2(-90, 0))
	boss.def.approach_time = 0.0
	boss.brain.pattern = BossBrain.Pattern.CHARGE
	boss.charge_dir = Vector2.UP  # not the default, so the lock below is proven
	var patterns: Array[String] = []
	var on_attacked := func(pattern: String, _at: Vector2) -> void: patterns.append(pattern)
	Events.boss_attacked.connect(on_attacked)
	# ticks(n) resumes before tick n's callbacks: the charge starts on the 38th, so 42 leaves slack.
	await ticks(42)
	assert_bool(boss.brain.charging()).is_true()
	assert_vector(boss.charge_dir).is_equal_approx(Vector2.RIGHT, Vector2(0.05, 0.05))
	assert_int(Audio.plays.get("boss_charge", 0)).is_equal(1)
	player.global_position.y += 60.0  # out of the lane: the wall ends this charge, not the player
	# The wall face is about 81 px on at the move-out, the stop 61 px (the radius); 64 px at 320 px/s
	# is 12 ticks, so 16 leaves slack; the charge's own end is 0.5 s off.
	await ticks(16)
	Events.boss_attacked.disconnect(on_attacked)
	assert_bool(boss.brain.charging()).is_false()
	assert_int(boss.brain.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_float(boss.global_position.x).is_equal_approx(bounds.end.x - 20.0, 1.0)  # the wall minus the radius
	assert_array(patterns).is_equal(["charge", "charge_wall"])


func test_the_player_in_the_lane_does_not_end_a_charge() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var bounds: Rect2 = main.get_node("Room").bounds()
	player.invuln_left = 100.0
	player.global_position = bounds.get_center()
	var boss := active_boss_on(main, player.global_position + Vector2(-60, 0))
	boss.def.approach_time = 0.0
	boss.brain.pattern = BossBrain.Pattern.CHARGE
	var patterns: Array[String] = []
	var on_attacked := func(pattern: String, _at: Vector2) -> void: patterns.append(pattern)
	Events.boss_attacked.connect(on_attacked)
	await ticks(42)
	assert_bool(boss.brain.charging()).is_true()
	await ticks(32)  # the charge's 0.5 s lands a tick late at 60 Hz: 31 ticks from the 38th
	Events.boss_attacked.disconnect(on_attacked)
	assert_bool(boss.brain.charging()).is_false()
	assert_int(boss.brain.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_array(patterns).is_equal(["charge", "charge_end"])  # it pushed against the player for the whole 0.5 s
	assert_float(boss.global_position.x).is_less(player.global_position.x)
	assert_float(boss.global_position.x).is_greater(player.global_position.x - 40.0)


func test_a_charge_with_no_wall_in_reach_ends_on_its_time() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var bounds: Rect2 = main.get_node("Room").bounds()
	player.global_position = bounds.get_center() + Vector2(120, 0)
	var boss := active_boss_on(main, bounds.get_center() + Vector2(-80, 0))
	boss.def.approach_time = 0.0
	boss.brain.pattern = BossBrain.Pattern.CHARGE
	var start := boss.global_position
	var patterns: Array[String] = []
	var on_attacked := func(pattern: String, _at: Vector2) -> void: patterns.append(pattern)
	Events.boss_attacked.connect(on_attacked)
	await ticks(42)
	assert_bool(boss.brain.charging()).is_true()
	await ticks(32)
	Events.boss_attacked.disconnect(on_attacked)
	assert_bool(boss.brain.charging()).is_false()
	assert_int(boss.brain.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_vector(boss.move_vel).is_equal(Vector2.ZERO)
	assert_array(patterns).is_equal(["charge", "charge_end"])
	assert_float(boss.global_position.x - start.x).is_between(150.0, 170.0)  # 0.5 s at 320 px/s, a tick either way


func test_half_health_enrages_at_the_next_edge() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 0.0
	var phases: Array[int] = []
	var on_phase := func(phase: int) -> void: phases.append(phase)
	Events.boss_phase_changed.connect(on_phase)
	await ticks(10)  # in the telegraph
	boss.health.take_damage(boss.def.max_hp * 0.5)
	assert_int(boss.brain.stage).is_equal(1)  # requested, not landed: the edge is the attack's
	assert_bool(boss.brain.enrage_requested).is_true()
	await ticks(32)  # the attack edge on the 38th tick lands the stage
	Events.boss_phase_changed.disconnect(on_phase)
	assert_int(boss.brain.stage).is_equal(2)
	assert_that(boss.status.base_tint).is_equal(Boss.ENRAGED_TINT)
	assert_array(phases).is_equal([2])
	assert_int(Audio.plays.get("boss_phase", 0)).is_equal(1)


func test_contact_hurts_the_player() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	active_boss_on(main, player.global_position + Vector2(22, 0))
	await ticks(5)
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)


func test_stun_and_chill_last_half_as_long_and_a_stun_cannot_stop_a_charge() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(-150, 0))
	var status: StatusEffects = boss.get_node("Status")
	status.apply_stun()
	assert_float(status.stun_left).is_equal(StatusEffects.STUN_TIME * 0.5)
	status.apply_chill()
	assert_float(status.chill_left).is_equal(StatusEffects.CHILL_TIME * 0.5)
	status.stun_left = 0.0
	status.chill_left = 0.0
	boss.brain.phase = BossBrain.Phase.ATTACK
	boss.brain.pattern = BossBrain.Pattern.CHARGE
	boss.charge_dir = Vector2.RIGHT
	var start := boss.global_position
	status.apply_stun()
	await ticks(7)  # the first tick activates; five charge ticks at 320 px/s are 26 px
	assert_float(boss.global_position.x).is_greater(start.x + 20.0)


func test_a_stun_mid_telegraph_restarts_the_wind_up() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 0.0
	await ticks(10)
	assert_int(boss.brain.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	boss.get_node("Status").apply_stun()
	await ticks(2)
	assert_int(boss.brain.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_float(boss.flash_material.get_shader_parameter("flash")).is_equal(0.0)


func test_hits_barely_move_it() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 100.0
	var start := boss.global_position
	boss.health.take_damage(1.0, Vector2(120, 0))
	await ticks(10)
	assert_float(boss.global_position.x - start.x).is_less(6.0)
	assert_int(Audio.plays.get("hit_enemy", 0)).is_equal(1)


func test_killing_the_boss_clears_the_room_into_the_win() -> void:
	var main := quiet_main_with_floor(boss_floor())
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	await ticks(20)  # breather 0 plus the 0.25 s interval
	var boss := enemies_of(main).get_child(0) as Boss
	assert_object(boss).is_not_null()
	var won := [0]
	var on_won := func() -> void: won[0] += 1
	Events.run_won.connect(on_won)
	boss.health.take_damage(1000.0)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await get_tree().physics_frame
	Events.run_won.disconnect(on_won)
	assert_int(won[0]).is_equal(1)
	assert_int(RunState.rooms_cleared).is_equal(1)
	assert_int(RunState.kills).is_equal(1)
	assert_int(RunState.score).is_equal(boss.def.score)
	assert_bool(is_instance_valid(boss)).is_true()  # the corpse stays
	assert_bool(boss.is_in_group("enemies")).is_false()
	assert_int(Audio.plays.get("boss_die", 0)).is_equal(1)
	assert_str(Audio.current_music).is_equal("")
	await real_seconds(Boss.CORPSE_FLASH_HOLD + 0.1)
	assert_that(boss.sprite.modulate).is_equal(Boss.CORPSE_TINT)


## Playtest 2: a fast Shock build stunned the boss on every hit, so it never finished a wind-up.
## A stun barrage (four a second, faster than the halved stun wears off) must not hold off its
## attacks: over five seconds it still lands at least one.
func test_a_stun_barrage_cannot_hold_the_boss_off_its_attacks() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	RunState.cheats = {"immortal": true}  # the attacks this test waits for must not end the run
	var attacks: Array[String] = []
	var on_attacked := func(pattern: String, _at: Vector2) -> void:
		if pattern in ["ring", "volley", "charge"]:
			attacks.append(pattern)
	Events.boss_attacked.connect(on_attacked)
	var status: StatusEffects = boss.get_node("Status")
	for i in 20:
		status.apply_stun()
		await ticks(15)
	Events.boss_attacked.disconnect(on_attacked)
	assert_array(attacks).override_failure_message("no attack in 5 s under a stun every 0.25 s").is_not_empty()


func test_after_a_stun_wears_off_the_boss_ignores_stuns_for_the_immunity_window() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	var status: StatusEffects = boss.get_node("Status")
	assert_float(boss.def.stun_immunity).is_equal(2.0)
	status.apply_stun()
	await ticks(10)
	var left := status.stun_left
	status.apply_stun()
	assert_float(status.stun_left).is_equal(left)  # a stun on a stunned boss does not extend it
	await ticks(10)  # the 0.3 s stun is 18 ticks
	assert_bool(status.stunned()).is_false()
	status.apply_stun()
	assert_bool(status.stunned()).is_false()  # inside the window
	await ticks(122)  # 2 s is 120 ticks, plus slack
	status.apply_stun()
	assert_bool(status.stunned()).is_true()
