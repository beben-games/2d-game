extends GdUnitTestSuite
## Drives the real main scene: input moves and animates the player, aim flips the sprite and
## places the muzzle, the camera lean cannot push the view past the arena walls, and holding
## shoot spawns projectiles.

const MAIN := "res://scenes/main.tscn"
const EPS := Vector2(0.001, 0.001)


func test_move_right_travels_and_plays_run() -> void:
	var runner := scene_runner(MAIN)
	runner.scene().get_node("Spawner").enabled = false
	var player: Player = runner.scene().get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	await get_tree().physics_frame
	player.aim_override = player.global_position + Vector2(100, 0)
	var start := player.global_position
	Input.action_press("move_right")
	for i in 60:
		await get_tree().physics_frame
	var animation := sprite.animation
	var delta := player.global_position - start
	Input.action_release("move_right")
	assert_float(delta.x).is_between(80.0, 110.0)
	assert_float(delta.y).is_equal_approx(0.0, 0.001)
	assert_str(animation).is_equal("run")


func test_aiming_left_flips_sprite_and_muzzle() -> void:
	var runner := scene_runner(MAIN)
	runner.scene().get_node("Spawner").enabled = false
	var player: Player = runner.scene().get_node("Player")
	player.aim_override = player.global_position + Vector2(-100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(player.get_node("Sprite").flip_h).is_true()
	assert_vector(player.get_node("Muzzle").position).is_equal_approx(Vector2(-8, -6), EPS)


func test_camera_lean_stays_within_arena() -> void:
	var runner := scene_runner(MAIN)
	runner.scene().get_node("Spawner").enabled = false
	var player: Player = runner.scene().get_node("Player")
	var camera: Camera2D = player.get_node("Camera")
	player.aim_override = player.global_position + Vector2(500, 0)
	for i in 5:
		await get_tree().process_frame
	# View is 640x368 and so is the arena: the center must stay pinned at (320, 184).
	assert_float(camera.get_screen_center_position().x).is_equal_approx(320.0, 0.5)
	assert_float(camera.get_screen_center_position().y).is_equal_approx(184.0, 0.5)


func test_holding_shoot_spawns_projectiles_and_recoils() -> void:
	var runner := scene_runner(MAIN)
	var main: Node = runner.scene()
	main.get_node("Spawner").enabled = false
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(100, 0)
	var start_x := player.global_position.x
	Input.action_press("shoot")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("shoot")
	var shots := main.get_node("Projectiles").get_child_count()
	# 7 shots/s: cooldown 1/7 s = 8.57 ticks, first fires immediately -> ticks 0, 9, 18, 26 = 4.
	assert_int(shots).is_between(3, 5)
	assert_float(player.global_position.x).is_less(start_x)  # recoil pushed the player left
