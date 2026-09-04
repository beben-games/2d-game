extends GdUnitTestSuite


func test_arena_paints_every_cell_and_builds_four_walls() -> void:
	var runner := scene_runner("res://scenes/arena.tscn")
	var arena: Arena = runner.scene()
	var tiles: TileMapLayer = arena.get_node("Tiles")
	assert_int(tiles.get_used_cells().size()).is_equal(Arena.WIDTH * Arena.HEIGHT)
	var wall := SpriteAtlas.tile_coords(Arena.WALL_NAME)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(0, 0))).is_equal(wall)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(Arena.WIDTH - 1, Arena.HEIGHT - 1))).is_equal(wall)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(1, 1))).is_not_equal(wall)
	assert_int(arena.get_node("Walls").get_child_count()).is_equal(4)
	assert_vector(arena.bounds().position).is_equal(Vector2(16, 16))


func test_wall_colliders_ring_the_room() -> void:
	var runner := scene_runner("res://scenes/arena.tscn")
	var arena: Arena = runner.scene()
	var rects: Array[Rect2] = []
	for shape: CollisionShape2D in arena.get_node("Walls").get_children():
		var r: RectangleShape2D = shape.shape
		rects.append(Rect2(shape.position - r.size * 0.5, r.size))
	assert_array(rects).contains_exactly_in_any_order([
		Rect2(0, 0, 640, 16),
		Rect2(0, 352, 640, 16),
		Rect2(0, 0, 16, 368),
		Rect2(624, 0, 16, 368),
	])


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


func test_tile_set_has_eight_floors_and_one_wall() -> void:
	var runner := scene_runner("res://scenes/arena.tscn")
	var tiles: TileMapLayer = runner.scene().get_node("Tiles")
	var source: TileSetAtlasSource = tiles.tile_set.get_source(0)
	assert_int(source.get_tiles_count()).is_equal(9)
