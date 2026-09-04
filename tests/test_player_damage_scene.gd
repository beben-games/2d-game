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


## Places an ACTIVE chaser by skipping its spawn delay. Stationary by default so the tests own
## the geometry; pass false to keep the def's speed and let it chase.
func _active_chaser_on(main: Node, at: Vector2, stationary := true) -> Enemy:
	var enemy: Enemy = load("res://scenes/enemies/chaser.tscn").instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 0.0
	if stationary:
		enemy.def.speed = 0.0
	main.get_node("Enemies").add_child(enemy)
	enemy.global_position = at
	return enemy


## Waits until the player's hp changes. Returns the number of ticks it took, or -1 on timeout.
func _ticks_until_hp_drops(player: Player, max_ticks: int) -> int:
	var hp_before := player.hp
	for i in max_ticks:
		await get_tree().physics_frame
		if player.hp < hp_before:
			return i + 1
	return -1


func test_contact_deals_damage_once_per_invulnerability_window() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var hits := []
	var cb := func(damage: int, hp: int, max_hp: int) -> void: hits.append([damage, hp, max_hp])
	Events.player_hit.connect(cb)
	_active_chaser_on(main, player.global_position + Vector2(4, 0))
	await _ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)
	assert_array(hits).is_equal([[1, Player.MAX_HP - 1, Player.MAX_HP]])
	assert_bool(player.invuln_left > 0.0).is_true()
	Events.player_hit.disconnect(cb)


func test_second_hit_lands_once_invulnerability_expires() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := _active_chaser_on(main, player.global_position + Vector2(4, 0))
	# Knockback would carry the player out of reach, so keep the enemy glued to it: this is the
	# "enemy stays on top of you" case the contact poll exists for. 0.8 s of i-frames is 48 ticks
	# plus ~6 slowed ticks of hit freeze, so the second hit lands around tick 56.
	for i in 70:
		enemy.global_position = player.global_position + Vector2(4, 0)
		await get_tree().physics_frame
	assert_int(player.hp).is_equal(Player.MAX_HP - 2)


func test_contact_knocks_player_away_from_enemy() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var start := player.global_position
	_active_chaser_on(main, start + Vector2(4, 0))  # enemy to the right
	var hit_tick := await _ticks_until_hp_drops(player, 10)
	assert_int(hit_tick).is_greater(0)
	# Sampled on the tick the hit landed, before the next physics step decays it (physics_frame
	# fires before nodes step), so the vector is still exactly the full knockback pointing left.
	assert_vector(player.knockback).is_equal_approx(Vector2(-Player.HIT_KNOCKBACK, 0), Vector2(1, 1))
	await _ticks(20)  # the 0.09 s hit freeze shrinks physics delta for ~5 ticks; leave room to travel
	assert_float(player.global_position.x).is_less(start.x - 5.0)


func test_enemies_pass_through_the_player() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := _active_chaser_on(main, player.global_position + Vector2(20, 0), false)
	# With body collision the chaser would be held a body radius apart (11 px). Instead it lands
	# a hit at ~10 px, the knockback carries the player ~22 px, and the chaser (72 px/s) catches
	# up and walks straight through the player's center during the 0.8 s of i-frames.
	var closest := INF
	for i in 90:
		await get_tree().physics_frame
		closest = minf(closest, enemy.global_position.distance_to(player.global_position))
		if closest <= 6.0:
			break
	assert_float(closest).is_less_equal(6.0)
	assert_int(player.hp).is_greater_equal(Player.MAX_HP - 1)


func test_hurt_is_gated_by_invulnerability_and_death() -> void:
	var main := _quiet_main()
	var player: Player = main.get_node("Player")
	var from := player.global_position + Vector2(4, 0)
	assert_bool(player.hurt(1, from)).is_true()
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)
	assert_bool(player.hurt(1, from)).is_false()  # still invulnerable from the first hit
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)
	player.hp = 1
	player.invuln_left = 0.0
	assert_bool(player.hurt(5, from)).is_true()
	assert_int(player.hp).is_equal(0)  # clamped, never negative
	assert_bool(player.dead).is_true()
	assert_bool(player.hurt(1, from)).is_false()  # the dead take no further hits
	assert_int(player.hp).is_equal(0)


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
	var died := []
	var cb := func(at: Vector2) -> void: died.append(at)
	Events.player_died.connect(cb)
	var restarts := [0]
	var on_restart := func() -> void: restarts[0] += 1
	main.restart_requested.connect(on_restart)
	player.hp = 1
	_active_chaser_on(main, player.global_position + Vector2(4, 0))
	await _ticks(5)
	assert_array(died).has_size(1)
	assert_vector(died[0]).is_equal_approx(player.global_position, Vector2(1, 1))
	assert_bool(player.dead).is_true()
	assert_bool(spawner.enabled).is_false()
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	Events.player_died.disconnect(cb)
	# Main's own restart fires after a 1 s real-time delay; call it directly instead of waiting.
	# Under the harness Main is not the current scene, so it must ask for a restart without reloading.
	main.restart()
	assert_int(restarts[0]).is_equal(1)
	assert_bool(is_instance_valid(main)).is_true()
	main.restart_requested.disconnect(on_restart)
