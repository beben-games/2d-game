extends SceneSuite
## Contact damage, i-frames, knockback, death, and Main's reaction, inside the real main scene.


## Waits until the player's hp changes. Returns the number of ticks it took, or -1 on timeout.
func _ticks_until_hp_drops(player: Player, max_ticks: int) -> int:
	var hp_before := player.hp
	for i in max_ticks:
		await get_tree().physics_frame
		if player.hp < hp_before:
			return i + 1
	return -1


func test_contact_deals_damage_once_per_invulnerability_window() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var hits := []
	var cb := func(damage: int, hp: int, max_hp: int, _attacker_id: String) -> void: hits.append([damage, hp, max_hp])
	Events.player_hit.connect(cb)
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)
	assert_array(hits).is_equal([[1, Player.MAX_HP - 1, Player.MAX_HP]])
	assert_bool(player.invuln_left > 0.0).is_true()
	Events.player_hit.disconnect(cb)


func test_second_hit_lands_once_invulnerability_expires() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(4, 0))
	# Knockback would carry the player out of reach, so keep the enemy glued to it: this is the
	# "enemy stays on top of you" case the contact poll exists for. 0.8 s of i-frames is 48 ticks
	# of real time (the hit freeze slows the delta but not the countdown), so the second hit lands
	# around tick 49.
	for i in 70:
		enemy.global_position = player.global_position + Vector2(4, 0)
		await get_tree().physics_frame
	assert_int(player.hp).is_equal(Player.MAX_HP - 2)


func test_invulnerability_counts_real_time_through_freezes() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	player.hurt(1, player.global_position + Vector2(4, 0))  # starts the 0.09 s hit freeze
	await ticks(10)
	Juice.hitstop(0.3)  # a long freeze inside the window, like a run of kills: ~18 slowed ticks
	await ticks(34)  # 44 ticks since the hit: 0.73 s, still inside the window
	assert_float(player.invuln_left).is_greater(0.0)
	await ticks(8)  # 52 ticks: 0.87 s of real time; freezes must not stretch the window
	assert_float(player.invuln_left).is_equal(0.0)


func test_chasing_enemy_lands_second_hit_after_invulnerability() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	# Not re-glued: the chaser keeps its def speed (110 px/s, the player's), so after the knockback carries the
	# player away it has to catch up on its own and then sit on top until the i-frames run out.
	active_chaser_on(main, player.global_position + Vector2(4, 0), false)
	var first_hit := -1
	var second_hit := -1
	var hp_before := player.hp
	for i in 120:
		await get_tree().physics_frame
		if player.hp < hp_before:
			hp_before = player.hp
			if first_hit < 0:
				first_hit = i + 1
			else:
				second_hit = i + 1
				break
	assert_int(first_hit).is_greater(0)
	assert_int(second_hit).is_greater(0)
	# 0.8 s of i-frames is 48 real-time ticks; at 110 px/s the chaser is back on top well inside
	# the window, so the second hit lands the tick it expires (48 apart), never inside it.
	assert_int(second_hit - first_hit).is_greater(40)


func test_contact_knocks_player_away_from_enemy() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var start := player.global_position
	active_chaser_on(main, start + Vector2(4, 0))  # enemy to the right
	var hit_tick := await _ticks_until_hp_drops(player, 10)
	assert_int(hit_tick).is_greater(0)
	# Sampled on the tick the hit landed, before the next physics step decays it (physics_frame
	# fires before nodes step), so the vector is still exactly the full knockback pointing left.
	assert_vector(player.knockback).is_equal_approx(Vector2(-Player.HIT_KNOCKBACK, 0), Vector2(1, 1))
	await ticks(20)  # the 0.09 s hit freeze shrinks physics delta for ~5 ticks; leave room to travel
	assert_float(player.global_position.x).is_less(start.x - 5.0)


func test_enemy_body_blocks_the_player() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(30, 0))
	player.invuln_left = 100.0  # no hit, so no knockback: pure body-versus-body pushing
	player.aim_override = player.global_position
	Input.action_press("move_right")
	await ticks(60)  # 110 px/s covers the 30 px gap many times over
	Input.action_release("move_right")
	# Bodies are solid: the player (r 6) is held against the chaser (r 5), never through it.
	assert_float(enemy.global_position.x - player.global_position.x).is_between(10.5, 12.5)
	assert_int(player.hp).is_equal(Player.MAX_HP)


func test_enemy_pressed_against_the_body_still_hurts() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	active_chaser_on(main, player.global_position + Vector2(30, 0))
	player.invuln_left = 100.0
	player.aim_override = player.global_position
	Input.action_press("move_right")
	await ticks(30)  # now pressed body to body, 11 px apart
	player.invuln_left = 0.0
	var hit_tick := await _ticks_until_hp_drops(player, 3)
	Input.action_release("move_right")
	# The hurtbox must reach past the body gap, or a solid enemy could never land a contact hit.
	assert_int(hit_tick).is_greater(0)


func test_hurt_is_gated_by_invulnerability_and_death() -> void:
	var main := quiet_main(3)
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


## The permawhat? cheat: hurt() is the one way to damage the player, so the check lives there.
func test_the_immortal_cheat_ignores_every_hit() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var from := player.global_position + Vector2(4, 0)
	RunState.cheats = {"immortal": true}
	assert_bool(player.hurt(1, from)).is_false()
	assert_int(player.hp).is_equal(Player.MAX_HP)
	assert_float(player.invuln_left).is_equal(0.0)  # nothing landed, so no i-frames either
	active_chaser_on(main, from)
	await ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP)
	RunState.cheats = {}
	assert_bool(player.hurt(1, from)).is_true()
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)


## An immortal player still stops enemy bolts (a bolt that lands is spent), with no damage, no
## i-frames, and no hurt sound; it does not collect them like a shield either.
func test_an_immortal_player_still_stops_enemy_bolts() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	RunState.cheats = {"immortal": true}
	var bolt: Projectile = load("res://scenes/enemies/enemy_bolt.tscn").instantiate()
	bolt.setup(load("res://data/weapons/shaman_bolt.tres"), Vector2.RIGHT)
	projectiles_of(main).add_child(bolt)
	bolt.global_position = player.global_position
	var ref: WeakRef = weakref(bolt)
	await ticks(3)
	var node: Node = ref.get_ref()
	assert_bool(node == null or node.is_queued_for_deletion()).is_true()
	assert_int(player.hp).is_equal(Player.MAX_HP)
	assert_float(player.invuln_left).is_equal(0.0)
	assert_int(Audio.plays.get("player_hurt", 0)).is_equal(0)


func test_spawning_enemy_is_harmless() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var enemy: Enemy = load(CHASER).instantiate()  # default 0.5 s spawn delay
	enemies_of(main).add_child(enemy)
	enemy.global_position = player.global_position + Vector2(4, 0)
	await ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP)


func test_lethal_damage_emits_player_died_and_stops_waves() -> void:
	var main := quiet_main(3)
	var player: Player = main.get_node("Player")
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	var died := []
	var cb := func(at: Vector2, _attacker_id: String) -> void: died.append(at)
	Events.player_died.connect(cb)
	var restarts := [0]
	var on_restart := func() -> void: restarts[0] += 1
	main.restart_requested.connect(on_restart)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_array(died).has_size(1)
	assert_vector(died[0]).is_equal_approx(player.global_position, Vector2(1, 1))
	assert_bool(player.dead).is_true()
	assert_bool(runner.enabled).is_false()
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	Events.player_died.disconnect(cb)
	# Death waits for R: no restart on its own. Real-time wait on purpose, since the old
	# auto-restart was a 1 s real-time timer and this is the only place that guards against it.
	await get_tree().create_timer(1.3, true, false, true).timeout
	assert_int(restarts[0]).is_equal(0)
	assert_bool(player.dead).is_true()
	# R restarts. Under the harness Main is not the current scene, so it must ask for a restart
	# without reloading.
	var press := InputEventAction.new()
	press.action = "restart"
	press.pressed = true
	Input.parse_input_event(press)
	await ticks(2)
	Input.action_release("restart")  # Input state is global: a held action is never "just pressed" again in a later suite
	assert_int(restarts[0]).is_equal(1)
	assert_bool(is_instance_valid(main)).is_true()
	main.restart_requested.disconnect(on_restart)


func test_heal_caps_at_max_and_reports() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var healed := []
	var cb := func(hp: int, max_hp: int) -> void: healed.append([hp, max_hp])
	Events.player_healed.connect(cb)
	assert_bool(player.heal(2)).is_false()  # already full
	player.hp = 3
	assert_bool(player.heal(2)).is_true()
	assert_int(player.hp).is_equal(5)
	assert_bool(player.heal(2)).is_true()
	assert_int(player.hp).is_equal(Player.MAX_HP)
	Events.player_healed.disconnect(cb)
	assert_array(healed).is_equal([[5, 6], [6, 6]])
