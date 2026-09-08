extends GdUnitTestSuite


func _floor(exits: Array) -> FloorDef:
	var f := FloorDef.new()
	for side in exits:
		var r := RoomDef.new()
		r.exit_side = side
		f.rooms.append(r)
	return f


func test_opposite_side() -> void:
	assert_int(FloorRules.opposite(RoomDef.Side.TOP)).is_equal(RoomDef.Side.BOTTOM)
	assert_int(FloorRules.opposite(RoomDef.Side.BOTTOM)).is_equal(RoomDef.Side.TOP)


func test_first_room_has_no_entry_and_later_rooms_enter_opposite_the_previous_exit() -> void:
	var f := _floor([RoomDef.Side.TOP, RoomDef.Side.BOTTOM, RoomDef.Side.TOP])
	assert_int(FloorRules.entry_side(f, 0)).is_equal(FloorRules.NO_DOOR)
	assert_int(FloorRules.entry_side(f, 1)).is_equal(RoomDef.Side.BOTTOM)
	assert_int(FloorRules.entry_side(f, 2)).is_equal(RoomDef.Side.TOP)


func test_is_last() -> void:
	var f := _floor([RoomDef.Side.TOP, RoomDef.Side.TOP])
	assert_bool(FloorRules.is_last(f, 0)).is_false()
	assert_bool(FloorRules.is_last(f, 1)).is_true()
