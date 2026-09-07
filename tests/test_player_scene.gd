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
	# Floor bounds grown by one tile of wall on every side: the view may show the wall, never past it.
	assert_int(camera.limit_left).is_equal(0)
	assert_int(camera.limit_top).is_equal(0)
	assert_int(camera.limit_right).is_equal(640)
	assert_int(camera.limit_bottom).is_equal(368)


func test_camera_leans_toward_aim_in_the_open() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var camera: Camera2D = player.get_node("Camera")
	player.aim_override = player.global_position + Vector2(500, 0)
	await _settle(camera)
	# At 3x zoom the view (about 427x240) is smaller than the 640x368 room, so from the center
	# the lean is free to move the view: MAX_LEAN * LEAN_FACTOR = 14.4 px to the right.
	var lean: float = camera.MAX_LEAN * camera.LEAN_FACTOR
	assert_float(camera.get_screen_center_position().x).is_equal_approx(320.0 + lean, 0.5)
	assert_float(camera.get_screen_center_position().y).is_equal_approx(184.0, 0.5)


func test_camera_stops_at_the_wall() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var camera: Camera2D = player.get_node("Camera")
	player.global_position = Vector2(600, 184)
	camera.reset_smoothing()
	player.aim_override = player.global_position + Vector2(500, 0)
	await _settle(camera)
	# Half the view width at 3x is 1280 / 3 / 2; the right limit pins the center there.
	var half_view := 1280.0 / camera.zoom.x / 2.0
	assert_float(camera.get_screen_center_position().x).is_equal_approx(640.0 - half_view, 0.5)


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
