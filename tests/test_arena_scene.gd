extends GdUnitTestSuite


func test_arena_paints_every_cell_and_builds_four_walls() -> void:
	var runner := scene_runner("res://scenes/arena.tscn")
	var arena: Arena = runner.scene()
	var tiles: TileMapLayer = arena.get_node("Tiles")
	assert_int(tiles.get_used_cells().size()).is_equal(28 * 15)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(0, 0))).is_equal(SpriteAtlas.tile_coords("wall_top_left"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(5, 0))).is_equal(SpriteAtlas.tile_coords("wall_top_mid"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(27, 0))).is_equal(SpriteAtlas.tile_coords("wall_top_right"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(0, 1))).is_equal(SpriteAtlas.tile_coords("wall_left"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(5, 1))).is_equal(SpriteAtlas.tile_coords("wall_mid"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(27, 1))).is_equal(SpriteAtlas.tile_coords("wall_right"))
	var wall := SpriteAtlas.tile_coords("wall_mid")
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(27, 14))).is_equal(wall)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(0, 7))).is_equal(wall)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(1, 2))).is_not_equal(wall)
	assert_int(arena.get_node("Walls").get_child_count()).is_equal(4)
	assert_that(arena.bounds()).is_equal(Rect2(16, 32, 416, 192))
	assert_that(arena.full_rect()).is_equal(Rect2(0, 0, 448, 240))


func _wall_rects(arena: Arena) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for shape: CollisionShape2D in arena.get_node("Walls").get_children():
		var r: RectangleShape2D = shape.shape
		rects.append(Rect2(shape.position - r.size * 0.5, r.size))
	return rects


func test_wall_colliders_ring_the_room() -> void:
	var arena: Arena = scene_runner("res://scenes/arena.tscn").scene()
	assert_array(_wall_rects(arena)).contains_exactly_in_any_order([
		Rect2(0, 0, 448, 32), Rect2(0, 224, 448, 16), Rect2(0, 0, 16, 240), Rect2(432, 0, 16, 240)])


func test_build_with_doors_leaves_gaps_in_the_colliders_and_the_tiles() -> void:
	var arena: Arena = scene_runner("res://scenes/arena.tscn").scene()
	arena.build(28, 15, [RoomDef.Side.TOP, RoomDef.Side.BOTTOM])
	assert_int(arena.get_node("Walls").get_child_count()).is_equal(6)
	var rects := _wall_rects(arena)
	assert_array(rects).contains(Rect2(0, 0, 208, 32))
	assert_array(rects).contains(Rect2(240, 0, 208, 32))
	assert_array(rects).contains(Rect2(0, 224, 208, 16))
	assert_array(rects).contains(Rect2(240, 224, 208, 16))
	var tiles: TileMapLayer = arena.get_node("Tiles")
	assert_int(tiles.get_used_cells().size()).is_equal(28 * 15 - 6)
	for cell in [Vector2i(13, 0), Vector2i(14, 0), Vector2i(13, 1), Vector2i(14, 1), Vector2i(13, 14), Vector2i(14, 14)]:
		assert_int(tiles.get_cell_source_id(cell)).is_equal(-1)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(12, 0))).is_equal(SpriteAtlas.tile_coords("wall_top_mid"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(12, 1))).is_equal(SpriteAtlas.tile_coords("wall_mid"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(12, 14))).is_equal(SpriteAtlas.tile_coords("wall_right"))
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(15, 14))).is_equal(SpriteAtlas.tile_coords("wall_left"))


func test_seal_bricks_up_a_door_gap_and_leaves_the_colliders_alone() -> void:
	var arena: Arena = scene_runner("res://scenes/arena.tscn").scene()
	arena.build(28, 15, [RoomDef.Side.BOTTOM])
	var rects_before := _wall_rects(arena)
	arena.seal(RoomDef.Side.BOTTOM)
	var tiles: TileMapLayer = arena.get_node("Tiles")
	var wall := SpriteAtlas.tile_coords("wall_mid")
	for cell in ArenaGrid.door_cells(28, 15, RoomDef.Side.BOTTOM):
		assert_vector(tiles.get_cell_atlas_coords(cell)).is_equal(wall)
	assert_int(tiles.get_used_cells().size()).is_equal(28 * 15)
	# The Door's own collider already blocks the gap; sealing must not add a wall on top of it.
	assert_array(_wall_rects(arena)).contains_exactly_in_any_order(rects_before)
	assert_array(arena.door_sides).is_empty()
	# The shaded ends stay: they read as the frame of a sealed doorway.
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(12, 14))).is_equal(SpriteAtlas.tile_coords("wall_right"))


func test_rebuild_replaces_rather_than_stacks() -> void:
	var arena: Arena = scene_runner("res://scenes/arena.tscn").scene()
	arena.build(12, 8, [])
	arena.build(12, 8, [])
	assert_int(arena.get_node("Walls").get_child_count()).is_equal(4)
	assert_int(arena.get_node("Tiles").get_used_cells().size()).is_equal(12 * 8)


func test_floor_is_deterministic_per_seed_and_leaves_gameplay_rng_alone() -> void:
	RunState.start_run(42)
	var first: TileMapLayer = scene_runner("res://scenes/arena.tscn").scene().get_node("Tiles")
	var second: TileMapLayer = scene_runner("res://scenes/arena.tscn").scene().get_node("Tiles")
	for cell in first.get_used_cells():
		assert_vector(second.get_cell_atlas_coords(cell)).is_equal(first.get_cell_atlas_coords(cell))

	RunState.start_run(43)
	var third: TileMapLayer = scene_runner("res://scenes/arena.tscn").scene().get_node("Tiles")
	var differing := 0
	for cell in first.get_used_cells():
		if third.get_cell_atlas_coords(cell) != first.get_cell_atlas_coords(cell):
			differing += 1
	assert_int(differing).is_greater(0)

	RunState.start_run(42)
	var before := RunState.rng.randf()
	RunState.start_run(42)
	scene_runner("res://scenes/arena.tscn")
	var after := RunState.rng.randf()
	assert_float(after).is_equal(before)
	RunState.start_run()


func test_tile_set_has_eight_floors_and_six_wall_tiles() -> void:
	var runner := scene_runner("res://scenes/arena.tscn")
	var tiles: TileMapLayer = runner.scene().get_node("Tiles")
	var source: TileSetAtlasSource = tiles.tile_set.get_source(0)
	assert_int(source.get_tiles_count()).is_equal(14)
