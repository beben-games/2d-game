extends SceneSuite
## The Room scene: built from a RoomDef, doors drawn and closed, Main placing the player.


func _room_def(exit_side := RoomDef.Side.TOP) -> RoomDef:
	var def := RoomDef.new()
	def.exit_side = exit_side
	def.waves = load("res://data/waves/room_1.tres")
	return def


func _room(def: RoomDef, entry_side: int) -> Room:
	var room: Room = load("res://scenes/room.tscn").instantiate()
	room.def = def
	room.entry_side = entry_side
	add_child(room)
	auto_free(room)
	return room


func test_room_builds_arena_and_one_door_per_side_in_use() -> void:
	var room := _room(_room_def(), FloorRules.NO_DOOR)
	assert_that(room.bounds()).is_equal(Rect2(16, 16, 416, 208))
	assert_int(room.get_node("Doors").get_child_count()).is_equal(1)
	assert_int(room.get_node("Arena/Walls").get_child_count()).is_equal(5)
	var second := _room(_room_def(RoomDef.Side.TOP), RoomDef.Side.BOTTOM)
	assert_int(second.get_node("Doors").get_child_count()).is_equal(2)
	assert_int(second.get_node("Arena/Walls").get_child_count()).is_equal(6)


func test_entry_position_is_one_tile_inside_the_entry_door_or_the_center() -> void:
	var first := _room(_room_def(), FloorRules.NO_DOOR)
	assert_vector(first.entry_position()).is_equal(Vector2(224, 120))
	var from_bottom := _room(_room_def(), RoomDef.Side.BOTTOM)
	assert_vector(from_bottom.entry_position()).is_equal(Vector2(224, 216))
	var from_top := _room(_room_def(RoomDef.Side.BOTTOM), RoomDef.Side.TOP)
	assert_vector(from_top.entry_position()).is_equal(Vector2(224, 24))


func test_closed_door_blocks_the_player() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.global_position = Vector2(224, 40)  # under the top door gap
	player.aim_override = player.global_position
	Input.action_press("move_up")
	await ticks(40)
	Input.action_release("move_up")
	# The wall row ends at y 16 and the body is r 6: held at about y 22, never into the gap.
	assert_float(player.global_position.y).is_greater(21.0)


func test_open_door_lets_the_player_through_and_requests_exit() -> void:
	var main := quiet_main()
	var room: Room = main.get_node("Room")
	var player: Player = main.get_node("Player")
	var requests := [0]
	var on_exit := func() -> void: requests[0] += 1
	Events.room_exit_requested.connect(on_exit)
	room.open_exit()
	player.global_position = Vector2(224, 40)
	player.aim_override = player.global_position
	Input.action_press("move_up")
	await ticks(40)
	Input.action_release("move_up")
	Events.room_exit_requested.disconnect(on_exit)
	assert_float(player.global_position.y).is_less(16.0)
	assert_int(requests[0]).is_greater_equal(1)


func test_main_starts_in_room_one_with_the_player_at_its_center() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	assert_bool(main.has_node("Room")).is_true()
	assert_vector(player.global_position).is_equal(Vector2(224, 120))
	assert_object(player.projectile_parent).is_same(main.get_node("Room/Projectiles"))
	assert_int(RunState.room).is_equal(0)
