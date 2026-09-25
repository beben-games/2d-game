extends SceneSuite
## The Room scene: one arena built from a series' size, its walls solid on every side, the
## emperor's box set into the top wall where the exit door stood, Main placing the player at the
## centre.


func _room(width := 28, height := 15) -> Room:
	var room: Room = load("res://scenes/room.tscn").instantiate()
	room.width = width
	room.height = height
	add_child(room)
	auto_free(room)
	return room


func _wall_rects(room: Room) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for shape: CollisionShape2D in room.get_node("Arena/Walls").get_children():
		var r: RectangleShape2D = shape.shape
		rects.append(Rect2(shape.position - r.size * 0.5, r.size))
	return rects


func test_room_builds_the_arena_with_no_doors_and_solid_walls() -> void:
	var room := _room()
	assert_that(room.bounds()).is_equal(Rect2(16, 32, 416, 192))
	assert_bool(room.has_node("Doors")).is_false()
	assert_int(room.get_node("Arena/Walls").get_child_count()).is_equal(4)
	# The old top gap is wall now: its centre lies in the ring (full_rect minus bounds) under a collider.
	var gap_centre := ArenaGrid.door_gap(28, 15, ArenaGrid.Side.TOP).get_center()
	assert_bool(room.full_rect().has_point(gap_centre)).is_true()
	assert_bool(room.bounds().has_point(gap_centre)).is_false()
	var covered := false
	for rect in _wall_rects(room):
		if rect.has_point(gap_centre):
			covered = true
	assert_bool(covered).is_true()
	var tiles: TileMapLayer = room.get_node("Arena/Tiles")
	assert_int(tiles.get_used_cells().size()).is_equal(28 * 15)  # no unpainted gap cells
	var small := _room(12, 8)
	assert_that(small.bounds()).is_equal(ArenaGrid.bounds(12, 8))


func test_the_emperor_box_sits_closed_in_the_top_wall() -> void:
	var room := _room()
	var box: EmperorBox = room.get_node("EmperorBox")
	assert_vector(box.position).is_equal(EmperorBox.position_of(28, 15))
	assert_vector(EmperorBox.position_of(28, 15)).is_equal(ArenaGrid.door_gap(28, 15, ArenaGrid.Side.TOP).position)
	var regions := []
	for sprite: Sprite2D in box.get_children():
		regions.append(sprite.texture.region)
	assert_array(regions).contains_exactly_in_any_order([
		SpriteAtlas.texture("doors_leaf_closed").region,
		SpriteAtlas.texture("doors_frame_left").region,
		SpriteAtlas.texture("doors_frame_right").region])
	var small := _room(12, 8)
	assert_vector(small.get_node("EmperorBox").position).is_equal(ArenaGrid.door_gap(12, 8, ArenaGrid.Side.TOP).position)


func test_the_top_wall_holds_the_player_under_the_emperor_box() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.global_position = Vector2(224, 56)  # under the box, where the door gap was
	player.aim_override = player.global_position
	Input.action_press("move_up")
	await ticks(40)
	Input.action_release("move_up")
	# The top band ends at y 32 and the body is r 6: held at about y 38, never into the wall.
	assert_float(player.global_position.y).is_greater(37.0)


func test_main_starts_round_one_with_the_player_at_the_centre() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	assert_bool(main.has_node("Room")).is_true()
	assert_vector(main.get_node("Room").entry_position()).is_equal(Vector2(224, 128))
	assert_vector(player.global_position).is_equal(Vector2(224, 128))
	assert_object(player.projectile_parent).is_same(main.get_node("Room/Projectiles"))
	assert_int(RunState.round).is_equal(0)
	assert_int(main.round_index).is_equal(0)
