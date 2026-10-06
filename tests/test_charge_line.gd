extends GdUnitTestSuite
## ChargeLine outside a scene: the path's points, its direction and length, shown and hidden.


func _line() -> ChargeLine:
	return auto_free(ChargeLine.new())


func test_setup_lays_one_leg_from_the_body() -> void:
	var line := _line()
	line.setup(Vector2(2, 3), Vector2(0, 5), 100.0)
	assert_array(line.points).is_equal(PackedVector2Array([Vector2(2, 3), Vector2(2, 103)]))
	assert_vector(line.direction).is_equal(Vector2.DOWN)
	assert_float(line.length).is_equal(100.0)


## Several legs (a boss's chained charges): the first leg's direction, the summed length.
func test_setup_path_lays_every_leg() -> void:
	var line := _line()
	var path := PackedVector2Array([Vector2.ZERO, Vector2(30, 0), Vector2(30, 40)])
	line.setup_path(path)
	assert_array(line.points).is_equal(path)
	assert_vector(line.direction).is_equal(Vector2.RIGHT)
	assert_float(line.length).is_equal(70.0)


func test_a_path_of_one_point_or_none_is_empty() -> void:
	var line := _line()
	line.setup_path(PackedVector2Array([Vector2(5, 5)]))
	assert_float(line.length).is_equal(0.0)
	line.setup_path(PackedVector2Array())
	assert_int(line.points.size()).is_equal(0)
	assert_float(line.length).is_equal(0.0)


func test_shown_and_hidden() -> void:
	var line := _line()
	assert_bool(line.shown()).is_false()
	line.show_line()
	assert_bool(line.shown()).is_true()
	assert_float(line.modulate.a).is_equal_approx(ChargeLine.ALPHA_TO, 0.001)  # no duration: at once
	line.hide_line()
	assert_bool(line.shown()).is_false()
