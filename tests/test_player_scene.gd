extends SceneSuite
## Drives the real main scene: input moves and animates the player, aim flips the sprite and
## places the muzzle, the camera lean cannot push the view past the arena walls, and holding
## shoot spawns projectiles.

const EPS := Vector2(0.001, 0.001)


func test_move_right_travels_and_plays_run() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	await get_tree().physics_frame
	player.aim_override = player.global_position + Vector2(100, 0)
	var start := player.global_position
	Input.action_press("move_right")
	await ticks(60)
	var animation := sprite.animation
	var delta := player.global_position - start
	Input.action_release("move_right")
	assert_float(delta.x).is_between(80.0, 110.0)
	assert_float(delta.y).is_equal_approx(0.0, 0.001)
	assert_str(animation).is_equal("run")


func test_aiming_left_flips_sprite_and_muzzle() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(-100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(player.get_node("Sprite").flip_h).is_true()
	assert_vector(player.get_node("Muzzle").position).is_equal_approx(Vector2(-8, -6), EPS)


func test_camera_limits_come_from_arena() -> void:
	var main := quiet_main()
	var camera: Camera2D = main.get_node("Player/Camera")
	assert_int(camera.limit_left).is_equal(0)
	assert_int(camera.limit_top).is_equal(0)
	assert_int(camera.limit_right).is_equal(448)
	assert_int(camera.limit_bottom).is_equal(240)


func test_camera_lean_is_clamped_by_the_arena() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var camera: Camera2D = player.get_node("Camera")
	player.aim_override = player.global_position + Vector2(500, 0)
	await _settle(camera)
	# The view at 3x (426.7 x 240) is nearly the room (448 x 240): the lean of 14.4 px from the
	# center is cut to 10.7 by the right limit, and the vertical center is pinned at 120.
	var half_view := 1280.0 / camera.zoom.x / 2.0
	assert_float(camera.get_screen_center_position().x).is_equal_approx(448.0 - half_view, 0.5)
	assert_float(camera.get_screen_center_position().y).is_equal_approx(120.0, 0.5)


## Lets the camera compute its lean, then snaps the smoothing so the test is not timing dependent.
func _settle(camera: Camera2D) -> void:
	for i in 2:
		await get_tree().process_frame
	camera.reset_smoothing()
	for i in 2:
		await get_tree().process_frame


func test_holding_shoot_spawns_projectiles_and_recoils() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(100, 0)
	var start_x := player.global_position.x
	Input.action_press("shoot")
	await ticks(30)
	Input.action_release("shoot")
	var shots := projectiles_of(main).get_child_count()
	# 7 shots/s: cooldown 1/7 s = 8.57 ticks, first fires immediately -> ticks 0, 9, 18, 26 = 4.
	assert_int(shots).is_between(3, 5)
	assert_float(player.global_position.x).is_less(start_x)  # recoil pushed the player left


func test_dash_carries_the_player_through_an_enemy_body() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(24, 0))
	var enemy_x_before := enemy.global_position.x
	player.invuln_left = 100.0  # no hit knockback, so the dash alone decides where we end up
	player.aim_override = player.global_position + Vector2(100, 0)
	Input.action_press("move_right")
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	# Nine fast ticks, layer restored on the tenth; ~50 px covered, where solid bodies would have
	# stopped us at 13 px.
	await ticks(12)
	Input.action_release("move_right")
	assert_float(player.global_position.x).is_greater(enemy.global_position.x + 10.0)
	assert_int(player.collision_mask).is_equal(Player.BODY_MASK)  # mask restored after the dash
	assert_int(player.collision_layer).is_equal(Player.BODY_LAYER)  # layer restored after the dash
	# A dashing player must not shove the chaser.
	assert_float(enemy.global_position.x).is_equal_approx(enemy_x_before, 0.5)


## A press is seen by is_action_just_pressed in the physics tick after the call, and ticks(1)
## resumes at the start of that tick, before the player runs: two ticks per press to observe it.
func test_dash_respects_cooldown() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(100, 0)
	Input.action_press("dash")
	await ticks(2)  # dash starts on tick 1
	Input.action_release("dash")
	assert_float(player.dash_left).is_greater(0.0)
	# Tick 14: nine fast ticks, layer restored on the tenth; the cooldown (36 ticks) still runs.
	await ticks(12)
	assert_float(player.dash_left).is_equal(0.0)
	Input.action_press("dash")
	await ticks(2)  # tick 16
	Input.action_release("dash")
	assert_float(player.dash_left).is_equal(0.0)  # refused
	await ticks(22)  # tick 38; this press lands on tick 39, and the cooldown ended by tick 37
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	assert_float(player.dash_left).is_greater(0.0)  # accepted after the cooldown


func _press_dash() -> void:
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")


func test_two_charges_allow_two_dashes_back_to_back() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(100, 0)
	var changes := []
	var on_changed := func(charges: int, max_charges: int) -> void: changes.append([charges, max_charges])
	Events.dash_charges_changed.connect(on_changed)
	RunState.build.add_rank(UpgradeCatalog.upgrade("dash_charge"))
	Events.build_changed.emit()
	assert_int(player.max_dash_charges).is_equal(2)
	assert_int(player.dash_charges).is_equal(2)
	await _press_dash()
	assert_float(player.dash_left).is_greater(0.0)
	await ticks(12)  # the first dash is over
	await _press_dash()
	assert_float(player.dash_left).is_greater(0.0)  # the second charge, no wait
	assert_int(player.dash_charges).is_equal(0)
	await ticks(12)
	await _press_dash()
	assert_float(player.dash_left).is_equal(0.0)  # empty
	# The refill clock started on tick 1 (the first dash) and runs across the second dash: 36
	# decrements on ticks 2..37 land the first charge on tick 37 (38 if the doubles run late), the
	# next clock runs ticks 38..73. A clock restarted by the second dash (tick 14) would land on
	# tick 50 instead. Each _press_dash is two ticks, so this is the start of tick 30.
	await ticks(10)  # tick 40
	assert_int(player.dash_charges).is_equal(1)  # the first refill has landed
	await ticks(28)  # tick 68
	assert_int(player.dash_charges).is_equal(1)  # the second is still running
	await ticks(8)  # tick 76
	assert_int(player.dash_charges).is_equal(2)  # the second refill has landed
	Events.dash_charges_changed.disconnect(on_changed)
	assert_array(changes).is_equal([[2, 2], [1, 2], [0, 2], [1, 2], [2, 2]])  # the refused press emits nothing
