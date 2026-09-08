extends GdUnitTestSuite
## Validation and shape of the wave, room, and floor resources.

const CHASER := preload("res://scenes/enemies/chaser.tscn")


func _group(count: int) -> SpawnGroup:
	var g := SpawnGroup.new()
	g.enemy = CHASER
	g.count = count
	return g


func _wave(groups: Array[SpawnGroup], breather := 1.0) -> WaveDef:
	var w := WaveDef.new()
	w.groups = groups
	w.breather = breather
	return w


func test_spawn_group_rejects_missing_scene_and_zero_count() -> void:
	var g := SpawnGroup.new()
	g.count = 0
	assert_array(g.validate()).contains_exactly_in_any_order(["enemy must be set", "count must be >= 1"])
	assert_array(_group(2).validate()).is_empty()


func test_wave_def_totals_and_validates_groups() -> void:
	var w := _wave([_group(2), _group(3)])
	assert_int(w.total()).is_equal(5)
	assert_array(w.validate()).is_empty()
	var empty := WaveDef.new()
	assert_array(empty.validate()).contains("wave has no groups")
	var bad := _wave([_group(0)], -1.0)
	assert_array(bad.validate()).contains_exactly_in_any_order(["breather must be >= 0", "group 0: count must be >= 1"])


func test_wave_table_validates_every_wave() -> void:
	var t := WaveTable.new()
	assert_array(t.validate()).contains("table has no waves")
	t.waves = [_wave([_group(1)]), WaveDef.new()]
	assert_array(t.validate()).contains_exactly_in_any_order(["wave 1: wave has no groups"])
	assert_int(t.total_enemies()).is_equal(1)


func test_room_def_rejects_small_rooms_and_side_doors() -> void:
	var r := RoomDef.new()
	r.width = 4
	r.height = 3
	r.exit_side = RoomDef.Side.LEFT
	assert_array(r.validate()).contains_exactly_in_any_order([
		"width must be >= 8", "height must be >= 6", "exit_side must be TOP or BOTTOM", "waves must be set"])
	var ok := RoomDef.new()
	ok.waves = WaveTable.new()
	ok.waves.waves = [_wave([_group(1)])]
	assert_array(ok.validate()).is_empty()
	assert_int(ok.width).is_equal(28)
	assert_int(ok.height).is_equal(15)
	assert_int(ok.exit_side).is_equal(RoomDef.Side.TOP)


func test_floor_def_needs_rooms_and_reports_room_errors() -> void:
	var f := FloorDef.new()
	assert_array(f.validate()).contains("floor has no rooms")
	var bad := RoomDef.new()
	var empty_wave := RoomDef.new()
	empty_wave.waves = WaveTable.new()
	empty_wave.waves.waves = [WaveDef.new()]
	f.rooms = [bad, empty_wave]
	assert_array(f.validate()).contains("room 0: waves must be set")
	assert_array(f.validate()).contains("room 1: waves: wave 0: wave has no groups")


func test_null_elements_are_reported_not_crashed() -> void:
	var w := WaveDef.new()
	w.groups = [null]
	assert_array(w.validate()).contains("group 0: missing")
	assert_int(w.total()).is_equal(0)
	var t := WaveTable.new()
	t.waves = [null]
	assert_array(t.validate()).contains("wave 0: missing")
	assert_int(t.total_enemies()).is_equal(0)
	var f := FloorDef.new()
	f.rooms = [null]
	assert_array(f.validate()).contains("room 0: missing")


func test_shipped_floor_is_valid() -> void:
	var f: FloorDef = load("res://data/floors/floor_1.tres")
	assert_object(f).is_not_null()
	assert_array(f.validate()).is_empty()
	assert_int(f.rooms.size()).is_greater_equal(1)
	assert_int(f.rooms[0].waves.waves.size()).is_equal(2)
	assert_int(f.rooms[0].waves.total_enemies()).is_equal(9)
