extends SceneSuite
## Scene tests for the Chaser: spawn delay, chase, death by projectile.
## Waits are counted in physics frames, not wall-clock, so the results are deterministic. The one
## exception is death: the body lingers for the real-time kill freeze before freeing itself.

func test_chaser_waits_then_moves_toward_target() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.position = Vector2(0, 0)
	add_child(target)
	var runner := scene_runner(CHASER)
	var enemy: Enemy = runner.scene()
	enemy.target = target
	enemy.global_position = Vector2(120, 0)
	await ticks(20)  # 0.33 s < spawn_delay 0.5 s
	assert_int(enemy.state).is_equal(Enemy.State.SPAWNING)
	assert_float(enemy.global_position.x).is_equal_approx(120.0, 0.01)
	assert_bool(enemy.is_harmful()).is_false()
	await ticks(70)  # total 1.5 s: 0.5 s spawn + 1 s chase
	assert_int(enemy.state).is_equal(Enemy.State.ACTIVE)
	assert_bool(enemy.is_harmful()).is_true()
	assert_float(enemy.global_position.x).is_less(100.0)
	assert_bool(enemy.get_node("Sprite").flip_h).is_true()  # moving left


func test_projectile_kills_chaser_and_reports_death() -> void:
	var main := quiet_main(1)
	var player: Player = main.get_node("Player")
	var enemy: Enemy = load(CHASER).instantiate()
	enemies_of(main).add_child(enemy)
	enemy.global_position = player.global_position + Vector2(80, 0)  # 80 px right of the player at the room center
	var hits := []
	var died := []
	var on_hit := func(_e: Node2D, damage: float, _p: Vector2) -> void: hits.append(damage)
	var on_died := func(_e: Node2D, p: Vector2) -> void: died.append(p)
	Events.enemy_hit.connect(on_hit)
	Events.enemy_died.connect(on_died)
	player.aim_override = enemy.global_position
	Input.action_press("shoot")
	await ticks(90)  # 1.5 s: ~10 shots of 1 damage at 3 hp, at 340 px/s over 80 px
	Input.action_release("shoot")
	Events.enemy_hit.disconnect(on_hit)
	Events.enemy_died.disconnect(on_died)
	assert_array(hits).is_equal([1.0, 1.0, 1.0])  # three pistol hits of 1 damage killed it
	assert_int(died.size()).is_equal(1)
	assert_int(RunState.kills).is_equal(1)
	assert_int(RunState.score).is_equal(10)
	await wait_for_death_freeze()
	assert_bool(is_instance_valid(enemy)).is_false()


func _spawn_chaser_facing(target_at: Vector2, enemy_at: Vector2) -> Enemy:
	var target: Node2D = auto_free(Node2D.new())
	target.position = target_at
	add_child(target)
	var runner := scene_runner(CHASER)
	var enemy: Enemy = runner.scene()
	enemy.target = target
	enemy.global_position = enemy_at
	return enemy


func test_knockback_during_spawn_shoves_immediately_then_chase_resumes() -> void:
	var enemy := _spawn_chaser_facing(Vector2(0, 0), Vector2(200, 0))
	await ticks(5)
	enemy.health.take_damage(1.0, Vector2(300, 0))  # shove away from the target while SPAWNING
	await ticks(7)  # tick 12
	assert_int(enemy.state).is_equal(Enemy.State.SPAWNING)
	assert_float(enemy.global_position.x).is_greater(200.0)
	await ticks(33)  # tick 45: 0.25 s into ACTIVE, knockback long since decayed
	assert_int(enemy.state).is_equal(Enemy.State.ACTIVE)
	var x_before := enemy.global_position.x
	await ticks(5)
	assert_float(enemy.global_position.x).is_less(x_before)  # chasing left again


func test_death_while_spawning_frees_and_reports_once() -> void:
	var enemy := _spawn_chaser_facing(Vector2(0, 0), Vector2(200, 0))
	var died := []
	var on_died := func(_e: Node2D, p: Vector2) -> void: died.append(p)
	Events.enemy_died.connect(on_died)
	await ticks(3)
	enemy.health.take_damage(10.0)
	await wait_for_death_freeze()
	Events.enemy_died.disconnect(on_died)
	assert_bool(is_instance_valid(enemy)).is_false()
	assert_int(died.size()).is_equal(1)


func test_tree_exited_fires_once_after_death() -> void:
	var enemy := _spawn_chaser_facing(Vector2(0, 0), Vector2(200, 0))
	var exits := [0]
	enemy.tree_exited.connect(func() -> void: exits[0] += 1)
	await ticks(3)
	enemy.health.take_damage(10.0)
	await wait_for_death_freeze()
	assert_int(exits[0]).is_equal(1)
