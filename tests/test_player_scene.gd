extends GdUnitTestSuite
## Drives the real main scene: input moves and animates the player, aim flips the sprite and
## places the muzzle, and the camera lean cannot push the view past the arena walls.

const MAIN := "res://scenes/main.tscn"
const EPS := Vector2(0.001, 0.001)


func test_move_right_travels_and_plays_run() -> void:
	var runner := scene_runner(MAIN)
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
	var player: Player = runner.scene().get_node("Player")
	player.aim_override = player.global_position + Vector2(-100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(player.get_node("Sprite").flip_h).is_true()
	assert_vector(player.get_node("Muzzle").position).is_equal_approx(Vector2(-8, -6), EPS)


func test_camera_lean_stays_within_arena() -> void:
	var runner := scene_runner(MAIN)
	var player: Player = runner.scene().get_node("Player")
	var camera: Camera2D = player.get_node("Camera")
	player.aim_override = player.global_position + Vector2(500, 0)
	for i in 5:
		await get_tree().process_frame
	# View is 640 wide and so is the arena: the center must stay pinned at 320.
	assert_float(camera.get_screen_center_position().x).is_less_equal(320.5)
