extends SceneSuite
## The Shooter in the real main scene: winds up, fires a bolt, the bolt hurts through the hurtbox.

const BOLT := preload("res://scenes/enemies/enemy_bolt.tscn")


func test_shooter_in_range_fires_one_bolt_after_the_telegraph() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var shooter := active_shooter_on(main, player.global_position + Vector2(100, 0))
	await ticks(20)  # 0.33 s: still winding up
	assert_int(projectiles_of(main).get_child_count()).is_equal(0)
	await ticks(15)  # 0.58 s: fired
	assert_int(projectiles_of(main).get_child_count()).is_equal(1)
	var bolt: Projectile = projectiles_of(main).get_child(0)
	assert_int(bolt.collision_layer).is_equal(8)
	assert_int(bolt.collision_mask).is_equal(16)
	assert_float(bolt.direction.x).is_less(0.0)  # toward the player on its left
	await ticks(30)  # recovering: no second bolt yet
	assert_int(projectiles_of(main).get_child_count()).is_equal(1)
	assert_int(shooter.state).is_equal(Enemy.State.ACTIVE)


func test_shooter_too_close_backs_away() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var shooter := active_shooter_on(main, player.global_position + Vector2(40, 0), false)
	# Telegraph first (in range), then recover while backing off: x grows over the cycle.
	await ticks(75)  # 1.25 s
	assert_float(shooter.global_position.x).is_greater(player.global_position.x + 50.0)


func test_bolt_hurts_the_player_through_the_hurtbox_and_frees_itself() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var bolt: Projectile = BOLT.instantiate()
	bolt.setup(load("res://data/weapons/shaman_bolt.tres"), Vector2.LEFT)
	projectiles_of(main).add_child(bolt)
	bolt.global_position = player.global_position + Vector2(30, 0)
	await ticks(20)  # 120 px/s covers 30 px in 0.25 s
	assert_int(player.hp).is_equal(Player.MAX_HP - 1)
	assert_bool(is_instance_valid(bolt)).is_false()


func test_player_shots_ignore_enemy_bolts() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(100, 0)
	var bolt: Projectile = BOLT.instantiate()
	bolt.setup(load("res://data/weapons/shaman_bolt.tres"), Vector2.ZERO)
	projectiles_of(main).add_child(bolt)
	bolt.global_position = player.global_position + Vector2(40, 0)
	bolt.speed = 0.0
	Input.action_press("shoot")
	await ticks(20)
	Input.action_release("shoot")
	assert_bool(is_instance_valid(bolt)).is_true()
