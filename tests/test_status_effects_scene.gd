extends SceneSuite
## Burn, stun, and chill on placed enemies in the real main scene, and the projectile payload
## that applies them. Timings are physics ticks (60 Hz).

const PROJECTILE := preload("res://scenes/projectile.tscn")


func _status(enemy: Enemy) -> StatusEffects:
	return enemy.get_node("Status")


func test_burn_ticks_quiet_damage_until_the_enemy_dies() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(80, 0))
	var status := _status(enemy)
	var died := [false]
	enemy.health.died.connect(func() -> void: died[0] = true)  # the corpse is freed after the kill freeze, before the last check
	status.apply_burn()
	assert_bool(status.burning()).is_true()
	await ticks(33)  # past 0.5 s: the first tick of 0.5 damage
	assert_float(enemy.health.hp).is_equal(2.5)
	assert_float(Juice.trauma).is_equal(0.0)  # no shake for a burn tick
	assert_float(enemy.flash_material.get_shader_parameter("flash")).is_equal(0.0)  # no white flash
	assert_that(enemy.sprite.modulate).is_equal(StatusEffects.BURN_TINT)
	await ticks(160)  # past 3 s: six ticks, 3 damage, dead
	assert_bool(died[0]).is_true()


func test_reapplying_burn_refreshes_instead_of_stacking() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(80, 0))
	var status := _status(enemy)
	status.apply_burn()
	await ticks(33)
	status.apply_burn()
	await ticks(33)
	assert_float(enemy.health.hp).is_equal(2.0)  # two ticks in 1.1 s, not four
	assert_int(status.burn_ticks_left).is_equal(StatusEffects.BURN_TICKS - 1)


func test_stun_halts_a_chaser_then_lets_it_go() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(100, 0), false)
	var start := enemy.global_position
	_status(enemy).apply_stun()
	await ticks(20)
	assert_vector(enemy.global_position).is_equal_approx(start, Vector2(0.5, 0.5))
	assert_that(enemy.sprite.modulate).is_equal(StatusEffects.STUN_TINT)
	await ticks(30)  # 50 ticks: the 0.6 s stun ended at 36, then 14 ticks of chase
	assert_float(enemy.global_position.x).is_less(start.x - 5.0)
	assert_that(enemy.sprite.modulate).is_equal(Color.WHITE)


func test_stun_freezes_a_shooters_telegraph() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var shooter := active_shooter_on(main, player.global_position + Vector2(100, 0))  # inside preferred_range 130
	_status(shooter).apply_stun()
	await ticks(35)  # a telegraph is 0.5 s; stunned, it never starts
	assert_int(projectiles_of(main).get_child_count()).is_equal(0)
	await ticks(40)  # tick 75: unstunned at 36, telegraph done at 66, the bolt is out
	assert_int(projectiles_of(main).get_child_count()).is_equal(1)


func test_chill_halves_a_chasers_speed() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var chilled := active_chaser_on(main, player.global_position + Vector2(150, -40), false)
	var plain := active_chaser_on(main, player.global_position + Vector2(150, 40), false)
	var chilled_start := chilled.global_position
	var plain_start := plain.global_position
	_status(chilled).apply_chill()
	await ticks(30)
	var chilled_travel := chilled_start.distance_to(chilled.global_position)
	var plain_travel := plain_start.distance_to(plain.global_position)
	assert_float(plain_travel).is_greater(40.0)  # 110 px/s for 0.5 s less the ramp
	assert_float(chilled_travel).is_between(15.0, 35.0)  # 55 px/s
	assert_that(chilled.sprite.modulate).is_equal(StatusEffects.CHILL_TINT)
	await ticks(100)  # past 2 s
	assert_bool(_status(chilled).chilled()).is_false()


func test_a_shot_applies_its_payload_on_hit() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(80, 0))
	var def: WeaponDef = load("res://data/weapons/crossbow.tres").duplicate()
	def.burn = 1.0
	def.stun = 1.0
	def.chill = 1.0
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	shot.setup(def, Vector2.RIGHT)
	add_child(shot)
	shot._on_body_entered(enemy)
	var status := _status(enemy)
	assert_bool(status.burning()).is_true()
	assert_bool(status.stunned()).is_true()
	assert_bool(status.chilled()).is_true()
	assert_float(enemy.health.hp).is_equal(0.0)  # 3 damage on 3 hp: the hit itself still lands
	var plain: Projectile = auto_free(PROJECTILE.instantiate())
	plain.setup(load("res://data/weapons/handgun.tres"), Vector2.RIGHT)
	add_child(plain)
	var other := active_chaser_on(main, player.global_position + Vector2(-80, 0))
	plain._on_body_entered(other)
	assert_bool(_status(other).burning()).is_false()


func test_tints_keep_the_spawn_fade_alpha() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy: Enemy = load(CHASER).instantiate()
	enemies_of(main).add_child(enemy)
	enemy.global_position = player.global_position + Vector2(80, 0)
	await ticks(2)
	var alpha := enemy.sprite.modulate.a
	assert_float(alpha).is_less(1.0)  # still fading in
	_status(enemy).apply_chill()
	await ticks(1)
	assert_float(enemy.sprite.modulate.a).is_less(1.0)
	assert_float(enemy.sprite.modulate.r).is_equal_approx(StatusEffects.CHILL_TINT.r, 0.001)
