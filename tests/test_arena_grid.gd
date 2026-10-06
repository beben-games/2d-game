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


## A side door: the wall's one column at the two middle rows of the floor (rows 7 and 8 of a
## 15-row room, whose floor is rows 2 to 13), centred on the floor's middle.
func test_side_door_cells_are_the_two_middle_floor_rows_of_the_side_column() -> void:
	assert_array(ArenaGrid.door_cells(28, 15, ArenaGrid.Side.LEFT)).is_equal([Vector2i(0, 7), Vector2i(0, 8)])
	assert_array(ArenaGrid.door_cells(28, 15, ArenaGrid.Side.RIGHT)).is_equal([Vector2i(27, 7), Vector2i(27, 8)])
	assert_that(ArenaGrid.door_gap(28, 15, ArenaGrid.Side.LEFT)).is_equal(Rect2(0, 112, 16, 32))
	assert_that(ArenaGrid.door_gap(28, 15, ArenaGrid.Side.RIGHT)).is_equal(Rect2(432, 112, 16, 32))
	assert_float(ArenaGrid.door_gap(28, 15, ArenaGrid.Side.LEFT).get_center().y).is_equal(ArenaGrid.bounds(28, 15).get_center().y)


func test_wall_rects_split_the_side_walls_around_their_gaps() -> void:
	var doored := ArenaGrid.wall_rects(28, 15, [ArenaGrid.Side.LEFT, ArenaGrid.Side.RIGHT])
	assert_array(doored).contains_exactly_in_any_order([
		Rect2(0, 0, 448, 32), Rect2(0, 224, 448, 16),
		Rect2(0, 0, 16, 112), Rect2(0, 144, 16, 96),
		Rect2(432, 0, 16, 112), Rect2(432, 144, 16, 96)])


func test_wall_tile_leaves_side_gaps_unpainted() -> void:
	var sides := [ArenaGrid.Side.LEFT]
	for cell in ArenaGrid.door_cells(28, 15, ArenaGrid.Side.LEFT):
		assert_str(ArenaGrid.wall_tile(28, 15, cell, sides)).is_equal("")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(0, 6), sides)).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(0, 9), sides)).is_equal("wall_mid")
	assert_str(ArenaGrid.wall_tile(28, 15, Vector2i(27, 7), sides)).is_equal("wall_mid")


## The lift bays (M7 Task 11): one bay is the top door's gap exactly (tier 1's lift where it
## always stood); more stand side by side on the top wall, each a door gap's size, the row centred
## on that gap, never overlapping (nor their frames, a tile either side), all inside the top wall.
func test_one_bay_is_the_top_doors_gap() -> void:
	for width: int in [26, 27, 28, 56]:
		assert_array(ArenaGrid.bay_gaps(width, 15, 1)).is_equal([ArenaGrid.door_gap(width, 15, ArenaGrid.Side.TOP)])


func test_bays_stand_side_by_side_inside_the_top_wall_and_never_overlap() -> void:
	for width: int in [26, 27, 28, 56]:
		var centre := ArenaGrid.door_gap(width, 15, ArenaGrid.Side.TOP)
		for count in [1, 2, 3]:
			var gaps := ArenaGrid.bay_gaps(width, 15, count)
			var what := "%d bays at width %d: %s" % [count, width, gaps]
			assert_int(gaps.size()).override_failure_message(what).is_equal(count)
			for i in gaps.size():
				var gap := gaps[i]
				assert_that(gap.size).override_failure_message(what).is_equal(centre.size)
				assert_float(gap.position.y).override_failure_message(what).is_equal(0.0)
				assert_float(fmod(gap.position.x, ArenaGrid.TILE)).override_failure_message(what).is_equal(0.0)
				# The frame a tile either side, inside the corners.
				assert_bool(gap.position.x >= 2 * ArenaGrid.TILE and gap.end.x <= (width - 2) * ArenaGrid.TILE).override_failure_message(what).is_true()
				if i > 0:
					var framed := gaps[i - 1].grow_individual(ArenaGrid.TILE, 0, ArenaGrid.TILE, 0)
					assert_bool(framed.intersects(gap.grow_individual(ArenaGrid.TILE, 0, ArenaGrid.TILE, 0))).override_failure_message(what).is_false()
					assert_float(gap.position.x).override_failure_message(what).is_greater(gaps[i - 1].position.x)
			# Centred on the top door's gap.
			assert_float((gaps[0].position.x + gaps[-1].end.x) * 0.5).override_failure_message(what).is_equal(centre.get_center().x)


func test_no_bays_for_none_or_more_than_the_wall_holds() -> void:
	assert_array(ArenaGrid.bay_gaps(26, 15, 0)).is_empty()
	assert_array(ArenaGrid.bay_gaps(8, 6, 1)).has_size(1)
	assert_array(ArenaGrid.bay_gaps(8, 6, 2)).is_empty()
	assert_array(ArenaGrid.bay_gaps(26, 15, 4)).is_empty()


## The tiles under a gap: one bay's are the top door's cells.
func test_the_cells_under_a_bay_are_the_top_doors_for_one() -> void:
	var gap: Rect2 = ArenaGrid.bay_gaps(26, 15, 1)[0]
	assert_array(ArenaGrid.cells_in(gap)).is_equal(ArenaGrid.door_cells(26, 15, ArenaGrid.Side.TOP))
	assert_array(ArenaGrid.cells_in(Rect2(64, 0, 32, 32))).is_equal([Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)])
