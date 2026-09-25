extends GdUnitTestSuite


func test_floor_cells_fill_interior_under_the_two_row_top_wall() -> void:
	var cells := ArenaGrid.floor_cells(6, 5)
	assert_array(cells).has_size((6 - 2) * (5 - 1 - ArenaGrid.TOP_WALL_ROWS))
	assert_array(cells).contains([Vector2i(1, 2), Vector2i(4, 3)])
	assert_array(cells).not_contains([Vector2i(0, 0), Vector2i(1, 1), Vector2i(5, 4), Vector2i(0, 2)])
	assert_array(ArenaGrid.floor_cells(28, 15)).has_size(26 * 12)


func test_wall_cells_are_everything_but_the_floor() -> void:
	var cells := ArenaGrid.wall_cells(6, 5)
	assert_array(cells).has_size(6 * 5 - 4 * 2)
	assert_array(cells).contains([Vector2i(0, 0), Vector2i(5, 4), Vector2i(3, 0), Vector2i(3, 1), Vector2i(1, 1)])
	assert_array(cells).not_contains([Vector2i(1, 2)])


func test_wall_rows_is_two_on_top_and_one_elsewhere() -> void:
	assert_int(ArenaGrid.wall_rows(ArenaGrid.Side.TOP)).is_equal(2)
	assert_int(ArenaGrid.wall_rows(ArenaGrid.Side.BOTTOM)).is_equal(1)


func test_cell_center_is_pixel_center() -> void:
	assert_vector(ArenaGrid.cell_center(Vector2i(0, 0))).is_equal(Vector2(8, 8))
	assert_vector(ArenaGrid.cell_center(Vector2i(2, 1))).is_equal(Vector2(40, 24))


func test_bounds_exclude_walls() -> void:
	var b := ArenaGrid.bounds(40, 23)
	assert_vector(b.position).is_equal(Vector2(16, 32))
	assert_vector(b.size).is_equal(Vector2(38 * 16, 20 * 16))
	assert_that(ArenaGrid.bounds(28, 15)).is_equal(Rect2(16, 32, 416, 192))


func test_full_rect_covers_the_whole_arena() -> void:
	assert_that(ArenaGrid.full_rect(28, 15)).is_equal(Rect2(0, 0, 448, 240))


func test_door_cells_are_the_two_middle_columns_of_every_wall_row() -> void:
	assert_array(ArenaGrid.door_cells(28, 15, ArenaGrid.Side.TOP)).is_equal(
		[Vector2i(13, 0), Vector2i(14, 0), Vector2i(13, 1), Vector2i(14, 1)])
	assert_array(ArenaGrid.door_cells(28, 15, ArenaGrid.Side.BOTTOM)).is_equal([Vector2i(13, 14), Vector2i(14, 14)])
	assert_array(ArenaGrid.door_cells(12, 8, ArenaGrid.Side.BOTTOM)).is_equal([Vector2i(5, 7), Vector2i(6, 7)])


func test_door_gap_is_the_pixel_rect_of_the_door_cells() -> void:
	assert_that(ArenaGrid.door_gap(28, 15, ArenaGrid.Side.TOP)).is_equal(Rect2(208, 0, 32, 32))
	assert_that(ArenaGrid.door_gap(28, 15, ArenaGrid.Side.BOTTOM)).is_equal(Rect2(208, 224, 32, 16))


func test_wall_rects_split_around_door_gaps() -> void:
	var plain := ArenaGrid.wall_rects(28, 15, [])
	assert_array(plain).contains_exactly_in_any_order([
		Rect2(0, 0, 448, 32), Rect2(0, 224, 448, 16), Rect2(0, 0, 16, 240), Rect2(432, 0, 16, 240)])
	var doored := ArenaGrid.wall_rects(28, 15, [ArenaGrid.Side.TOP, ArenaGrid.Side.BOTTOM])
	assert_array(doored).contains_exactly_in_any_order([
		Rect2(0, 0, 208, 32), Rect2(240, 0, 208, 32),
		Rect2(0, 224, 208, 16), Rect2(240, 224, 208, 16),
		Rect2(0, 0, 16, 240), Rect2(432, 0, 16, 240)])


func test_wall_tile_draws_a_ledge_over_a_face_on_the_top_wall() -> void:
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(0, 0), [])).is_equal("wall_top_left")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(5, 0), [])).is_equal("wall_top_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(27, 0), [])).is_equal("wall_top_right")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(0, 1), [])).is_equal("wall_left")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(5, 1), [])).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(27, 1), [])).is_equal("wall_right")


func test_wall_tile_is_plain_face_on_the_sides_and_bottom() -> void:
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(0, 7), [])).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(27, 7), [])).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(0, 14), [])).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(13, 14), [])).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(27, 14), [])).is_equal("wall_mid")


func test_wall_tile_leaves_door_gaps_unpainted_and_ends_the_bottom_wall_at_the_opening() -> void:
	var sides := [ArenaGrid.Side.TOP, ArenaGrid.Side.BOTTOM]
	for cell in ArenaGrid.door_cells(28, 15, ArenaGrid.Side.TOP):
		assert_str(ArenaGrid.wall_tile(28, 15, cell, sides)).is_equal("")
	for cell in ArenaGrid.door_cells(28, 15, ArenaGrid.Side.BOTTOM):
		assert_str(ArenaGrid.wall_tile(28, 15, cell, sides)).is_equal("")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(12, 14), sides)).is_equal("wall_right")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(15, 14), sides)).is_equal("wall_left")
	# The top gap's neighbours keep the band look; the emperor's box draws its frames over them.
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(12, 0), sides)).is_equal("wall_top_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(12, 1), sides)).is_equal("wall_mid")
	# Without a door the same cells are ordinary wall.
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(13, 0), [])).is_equal("wall_top_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(13, 14), [])).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(12, 14), [])).is_equal("wall_mid")
