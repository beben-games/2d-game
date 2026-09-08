extends SceneSuite
## Room flow in the real main scene: clear opens the exit and drops a heart, the exit leads to the
## next room, clearing the last room wins.


func test_room_cleared_opens_the_exit_and_drops_a_heart() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var room: Room = main.get_node("Room")
	assert_bool(room.exit_door.is_open).is_false()
	Events.room_cleared.emit()
	await get_tree().process_frame
	assert_bool(room.exit_door.is_open).is_true()
	var hearts := room.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("HeartPickup"))
	assert_int(hearts.size()).is_equal(1)
	assert_vector(hearts[0].global_position).is_equal(room.bounds().get_center())
	assert_int(RunState.rooms_cleared).is_equal(1)


func test_exit_request_moves_to_the_next_room_through_its_bottom_door() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var player: Player = main.get_node("Player")
	var first_room: Node = main.get_node("Room")
	var entered := []
	var on_entered := func(index: int, total: int) -> void: entered.append([index, total])
	Events.room_entered.connect(on_entered)
	Events.room_cleared.emit()
	Events.room_exit_requested.emit()
	await real_seconds(0.5)  # the fade is real time
	await get_tree().physics_frame
	Events.room_entered.disconnect(on_entered)
	assert_int(main.room_index).is_equal(1)
	assert_bool(is_instance_valid(first_room)).is_false()
	var room: Room = main.get_node("Room")
	assert_int(room.entry_side).is_equal(RoomDef.Side.BOTTOM)
	assert_int(room.get_node("Doors").get_child_count()).is_equal(2)
	assert_vector(player.global_position).is_equal(Vector2(224, 216))
	assert_object(player.projectile_parent).is_same(room.projectiles)
	assert_array(entered).is_equal([[1, 2]])
	assert_int(RunState.room).is_equal(1)


func test_exit_request_before_clear_is_ignored() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	Events.room_exit_requested.emit()
	await real_seconds(0.3)
	assert_int(main.room_index).is_equal(0)


func test_clearing_the_last_room_wins_and_keeps_the_door_shut() -> void:
	var main := quiet_main_with_floor(tiny_floor(1))
	var won := [0]
	var on_won := func() -> void: won[0] += 1
	Events.run_won.connect(on_won)
	Events.room_cleared.emit()
	await get_tree().process_frame
	Events.run_won.disconnect(on_won)
	assert_int(won[0]).is_equal(1)
	assert_bool(main.get_node("Room").exit_door.is_open).is_false()
	assert_int(RunState.rooms_cleared).is_equal(1)


func test_swapping_rooms_during_a_death_freeze_is_clean() -> void:
	# Lifetime rule: the swap runs in idle time, never inside a physics callback, so an enemy
	# freed with its room while it sits in its death-freeze await must not push_error.
	var main := quiet_main_with_floor(tiny_floor(2))
	var player: Player = main.get_node("Player")
	# quiet_main_with_floor only silences the first room; the next one must not place its own
	# chaser (breather 0) or the empty-container check would be looking at a fresh spawn.
	var quiet_next := func(_index: int, _total: int) -> void: main.get_node("Room/WaveRunner").enabled = false
	Events.room_entered.connect(quiet_next)
	var enemy := active_chaser_on(main, player.global_position + Vector2(60, 0))
	enemy.health.take_damage(100.0)
	Events.room_cleared.emit()
	Events.room_exit_requested.emit()
	await real_seconds(0.6)
	await get_tree().physics_frame
	Events.room_entered.disconnect(quiet_next)
	assert_int(main.room_index).is_equal(1)
	assert_bool(is_instance_valid(enemy)).is_false()
	assert_int(enemies_of(main).get_child_count()).is_equal(0)


func test_clearing_with_a_real_shot_drops_the_heart_without_errors() -> void:
	# room_cleared arrives from inside a projectile's body_entered (a physics callback); anything
	# that adds physics nodes on it must defer, or Godot logs a flush error (push_error fails this test).
	var main := quiet_main_with_floor(tiny_floor(2))
	var player: Player = main.get_node("Player")
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var enemy := active_chaser_on(main, player.global_position + Vector2(40, 0))
	enemy.health.hp = 0.5
	runner.progress.queue = []  # pretend this enemy is the wave's only spawn
	runner.progress.spawned = 1
	runner.enabled = true
	player.aim_override = enemy.global_position
	Input.action_press("shoot")
	await ticks(12)
	Input.action_release("shoot")
	await get_tree().process_frame
	var room: Room = main.get_node("Room")
	assert_bool(room.exit_door.is_open).is_true()
	var hearts := room.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("HeartPickup"))
	assert_int(hearts.size()).is_equal(1)


func test_the_next_room_has_a_different_floor_pattern() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var arena: Arena = main.get_node("Room/Arena")
	var first: TileMapLayer = arena.tiles
	# Interior cells only: the wall ring differs anyway where room 2's entry door replaces wall.
	var before := {}
	for cell in ArenaGrid.floor_cells(arena.width, arena.height):
		before[cell] = first.get_cell_atlas_coords(cell)
	Events.room_cleared.emit()
	Events.room_exit_requested.emit()
	await real_seconds(0.5)
	await get_tree().physics_frame
	var second: TileMapLayer = main.get_node("Room/Arena/Tiles")
	var differing := 0
	for cell in before:
		if second.get_cell_atlas_coords(cell) != before[cell]:
			differing += 1
	assert_int(differing).is_greater(0)
