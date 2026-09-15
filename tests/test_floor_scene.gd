extends SceneSuite
## Room flow in the real main scene: clear opens the picker, a pick opens the exit, the exit leads
## to the next room, clearing the last room wins, and every projectile vanishes on the clear.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const BOLT := preload("res://scenes/enemies/enemy_bolt.tscn")


func test_room_cleared_opens_the_exit_after_a_pick() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var room: Room = main.get_node("Room")
	assert_bool(room.exit_door.is_open).is_false()
	await clear_and_pick(main)
	assert_bool(room.exit_door.is_open).is_true()
	assert_int(RunState.rooms_cleared).is_equal(1)


func test_exit_request_moves_to_the_next_room_through_its_bottom_door() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var player: Player = main.get_node("Player")
	var first_room: Node = main.get_node("Room")
	var entered := []
	var on_entered := func(index: int, total: int) -> void: entered.append([index, total])
	Events.room_entered.connect(on_entered)
	await clear_and_pick(main)
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


func test_the_entry_opening_bricks_up_a_beat_after_arriving() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var sealed := []
	var on_sealed := func(at: Vector2) -> void: sealed.append(at)
	Events.door_sealed.connect(on_sealed)
	await clear_and_pick(main)
	Events.room_exit_requested.emit()
	await real_seconds(0.2)  # the 0.15 s fade is real time; the seal waits another 0.4 s
	await get_tree().physics_frame
	var room: Room = main.get_node("Room")
	assert_int(room.entry_side).is_equal(RoomDef.Side.BOTTOM)
	var tiles: TileMapLayer = room.get_node("Arena/Tiles")
	var gap := ArenaGrid.door_cells(room.def.width, room.def.height, RoomDef.Side.BOTTOM)
	for cell in gap:
		assert_int(tiles.get_cell_source_id(cell)).is_equal(-1)  # still the dark opening you came through
	assert_array(sealed).is_empty()
	await real_seconds(0.5)
	Events.door_sealed.disconnect(on_sealed)
	for cell in gap:
		assert_vector(tiles.get_cell_atlas_coords(cell)).is_equal(SpriteAtlas.tile_coords("wall_mid"))
	assert_int(sealed.size()).is_equal(1)
	assert_vector(sealed[0]).is_equal(ArenaGrid.door_gap(room.def.width, room.def.height, RoomDef.Side.BOTTOM).get_center())


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
	await clear_and_pick(main)
	Events.room_exit_requested.emit()
	await real_seconds(0.6)
	await get_tree().physics_frame
	Events.room_entered.disconnect(quiet_next)
	assert_int(main.room_index).is_equal(1)
	assert_bool(is_instance_valid(enemy)).is_false()
	assert_int(enemies_of(main).get_child_count()).is_equal(0)


func test_the_next_room_has_a_different_floor_pattern() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var arena: Arena = main.get_node("Room/Arena")
	var first: TileMapLayer = arena.tiles
	# Interior cells only: the wall ring differs anyway where room 2's entry door replaces wall.
	var before := {}
	for cell in ArenaGrid.floor_cells(arena.width, arena.height):
		before[cell] = first.get_cell_atlas_coords(cell)
	await clear_and_pick(main)
	Events.room_exit_requested.emit()
	await real_seconds(0.5)
	await get_tree().physics_frame
	var second: TileMapLayer = main.get_node("Room/Arena/Tiles")
	var differing := 0
	for cell in before:
		if second.get_cell_atlas_coords(cell) != before[cell]:
			differing += 1
	assert_int(differing).is_greater(0)


## Two player shots and one enemy bolt in flight; they share Room/Projectiles.
func _place_projectiles(main: Node) -> Node2D:
	var container := projectiles_of(main)
	var player: Player = main.get_node("Player")
	for i in 2:
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(load("res://data/weapons/handgun.tres"), Vector2.RIGHT)
		container.add_child(shot)
		shot.global_position = player.global_position + Vector2(60 + 20 * i, 0)
	var bolt: Projectile = BOLT.instantiate()
	bolt.setup(load("res://data/weapons/shaman_bolt.tres"), Vector2.LEFT)
	container.add_child(bolt)
	bolt.global_position = player.global_position + Vector2(120, 0)
	return container


func test_clearing_a_room_frees_every_projectile_at_once() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	var container := _place_projectiles(main)
	assert_int(container.get_child_count()).is_equal(3)
	Events.room_cleared.emit()
	await get_tree().process_frame  # deferred: the signal can arrive inside a physics callback
	assert_int(container.get_child_count()).is_equal(0)


func test_clearing_the_last_room_frees_every_projectile_too() -> void:
	var main := quiet_main_with_floor(tiny_floor(1))
	var container := _place_projectiles(main)
	assert_int(container.get_child_count()).is_equal(3)
	Events.room_cleared.emit()
	await get_tree().process_frame
	assert_int(container.get_child_count()).is_equal(0)
