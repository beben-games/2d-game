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
