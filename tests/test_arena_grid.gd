extends GdUnitTestSuite


func test_floor_cells_fill_interior() -> void:
	var cells := ArenaGrid.floor_cells(6, 4)
	assert_array(cells).has_size((6 - 2) * (4 - 2))
	assert_array(cells).contains([Vector2i(1, 1), Vector2i(4, 2)])
	assert_array(cells).not_contains([Vector2i(0, 0), Vector2i(5, 3), Vector2i(0, 2)])


func test_wall_cells_form_ring() -> void:
	var cells := ArenaGrid.wall_cells(6, 4)
	assert_array(cells).has_size(2 * 6 + 2 * (4 - 2))
	assert_array(cells).contains([Vector2i(0, 0), Vector2i(5, 3), Vector2i(3, 0)])
	assert_array(cells).not_contains([Vector2i(1, 1)])


func test_cell_center_is_pixel_center() -> void:
	assert_vector(ArenaGrid.cell_center(Vector2i(0, 0))).is_equal(Vector2(8, 8))
	assert_vector(ArenaGrid.cell_center(Vector2i(2, 1))).is_equal(Vector2(40, 24))


func test_bounds_exclude_walls() -> void:
	var b := ArenaGrid.bounds(40, 23)
	assert_vector(b.position).is_equal(Vector2(16, 16))
	assert_vector(b.size).is_equal(Vector2(38 * 16, 21 * 16))


func test_door_cells_are_the_two_middle_cells_of_the_wall() -> void:
	assert_array(ArenaGrid.door_cells(28, 15, RoomDef.Side.TOP)).is_equal([Vector2i(13, 0), Vector2i(14, 0)])
	assert_array(ArenaGrid.door_cells(28, 15, RoomDef.Side.BOTTOM)).is_equal([Vector2i(13, 14), Vector2i(14, 14)])
	assert_array(ArenaGrid.door_cells(12, 8, RoomDef.Side.BOTTOM)).is_equal([Vector2i(5, 7), Vector2i(6, 7)])


func test_door_gap_is_the_pixel_rect_of_the_door_cells() -> void:
	assert_that(ArenaGrid.door_gap(28, 15, RoomDef.Side.TOP)).is_equal(Rect2(208, 0, 32, 16))
	assert_that(ArenaGrid.door_gap(28, 15, RoomDef.Side.BOTTOM)).is_equal(Rect2(208, 224, 32, 16))


func test_wall_rects_split_around_door_gaps() -> void:
	var plain := ArenaGrid.wall_rects(28, 15, [])
	assert_array(plain).contains_exactly_in_any_order([
		Rect2(0, 0, 448, 16), Rect2(0, 224, 448, 16), Rect2(0, 0, 16, 240), Rect2(432, 0, 16, 240)])
	var doored := ArenaGrid.wall_rects(28, 15, [RoomDef.Side.TOP, RoomDef.Side.BOTTOM])
	assert_array(doored).contains_exactly_in_any_order([
		Rect2(0, 0, 208, 16), Rect2(240, 0, 208, 16),
		Rect2(0, 224, 208, 16), Rect2(240, 224, 208, 16),
		Rect2(0, 0, 16, 240), Rect2(432, 0, 16, 240)])
