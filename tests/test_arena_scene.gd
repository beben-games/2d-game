extends GdUnitTestSuite


func test_arena_paints_every_cell_and_builds_four_walls() -> void:
	var runner := scene_runner("res://scenes/arena.tscn")
	var arena: Arena = runner.scene()
	var tiles: TileMapLayer = arena.get_node("Tiles")
	assert_int(tiles.get_used_cells().size()).is_equal(Arena.WIDTH * Arena.HEIGHT)
	var wall := SpriteAtlas.tile_coords(Arena.WALL_NAME)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(0, 0))).is_equal(wall)
	assert_vector(tiles.get_cell_atlas_coords(Vector2i(Arena.WIDTH - 1, Arena.HEIGHT - 1))).is_equal(wall)
	assert_bool(tiles.get_cell_atlas_coords(Vector2i(1, 1)) != wall).is_true()
	assert_int(arena.get_node("Walls").get_child_count()).is_equal(4)
	assert_vector(arena.bounds().position).is_equal(Vector2(16, 16))
