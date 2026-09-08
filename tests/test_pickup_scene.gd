extends SceneSuite
## The heart pickup inside the real main scene: touch heals, a full player leaves it, dashes count.

const HEART := preload("res://scenes/pickups/heart_pickup.tscn")


func _heart_at(main: Node, at: Vector2) -> Area2D:
	var heart: Area2D = HEART.instantiate()
	main.get_node("Room").add_child(heart)
	heart.global_position = at
	return heart


func test_walking_onto_a_heart_heals_and_removes_it() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hp = 2
	var heart := _heart_at(main, player.global_position + Vector2(30, 0))
	player.aim_override = player.global_position
	Input.action_press("move_right")
	await ticks(30)
	Input.action_release("move_right")
	assert_int(player.hp).is_equal(4)
	assert_bool(is_instance_valid(heart)).is_false()


func test_heart_stays_when_the_player_is_full() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var heart := _heart_at(main, player.global_position)
	await ticks(10)
	assert_int(player.hp).is_equal(Player.MAX_HP)
	assert_bool(is_instance_valid(heart)).is_true()
	# body_entered only: the heart is taken on re-entry, not by standing on it
	player.hp = 2
	await ticks(5)
	assert_int(player.hp).is_equal(2)
	assert_bool(is_instance_valid(heart)).is_true()


func test_dashing_onto_a_heart_picks_it_up() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hp = 2
	var heart := _heart_at(main, player.global_position + Vector2(30, 0))
	player.aim_override = player.global_position + Vector2(100, 0)
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	await ticks(12)
	assert_int(player.hp).is_equal(4)
	assert_bool(is_instance_valid(heart)).is_false()
