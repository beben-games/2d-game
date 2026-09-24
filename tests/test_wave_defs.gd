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


func test_floor_rejects_a_room_that_exits_where_it_entered() -> void:
	var f := FloorDef.new()
	for side in [RoomDef.Side.TOP, RoomDef.Side.BOTTOM]:
		var r := RoomDef.new()
		r.exit_side = side
		r.waves = load("res://data/waves/room_1.tres")
		f.rooms.append(r)
	assert_array(f.validate()).contains("room 1: exit is on its entry side")
	f.rooms[1].exit_side = RoomDef.Side.TOP
	assert_array(f.validate()).is_empty()


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
	assert_int(f.rooms.size()).is_equal(8)
	assert_int(f.rooms[0].waves.waves.size()).is_equal(2)
	var totals: Array[int] = []
	for room in f.rooms:
		totals.append(room.waves.total_enemies())
	assert_array(totals).contains_exactly([9, 6, 16, 24, 38, 45, 53, 1])  # room 8 is the boss alone


func test_the_finales_climb_into_the_boss() -> void:
	# The balance pass of 2026-09-22: rooms 1 to 3 as they were, room 4's finale 9 + 3, then
	# 8+3 / 9+3 / 11+4, 10+3 / 11+4 / 13+4, and 12+4 / 13+4 / 15+5 into the boss.
	var finales: Array[int] = []
	for n in [4, 5, 6, 7]:
		var t: WaveTable = load("res://data/waves/room_%d.tres" % n)
		finales.append(t.waves[-1].total())
	assert_array(finales).is_equal([12, 15, 17, 20])
	var eight: WaveTable = load("res://data/waves/room_8.tres")
	assert_int(eight.waves.size()).is_equal(1)
	assert_int(eight.waves[0].total()).is_equal(1)


func _shielded_per_wave(n: int) -> Array[int]:
	var t: WaveTable = load("res://data/waves/room_%d.tres" % n)
	var counts: Array[int] = []
	for w in t.waves:
		var shielded := 0
		for g in w.groups:
			if g.enemy.resource_path.get_file() == "chaser_shield.tscn":
				shielded += g.count
		counts.append(shielded)
	return counts


func test_shielded_chasers_replace_plain_ones_from_room_4() -> void:
	# Playtest 1, note 3: the shield attribute enters in room 4 and grows into the boss; the
	# totals per room stay the balance pass's (test_shipped_floor_is_valid pins them).
	for n in [1, 2, 3]:
		for count in _shielded_per_wave(n):
			assert_int(count).override_failure_message("room %d" % n).is_equal(0)
	assert_array(_shielded_per_wave(4)).is_equal([0, 2, 3])
	assert_array(_shielded_per_wave(5)).is_equal([2, 3, 3])
	assert_array(_shielded_per_wave(6)).is_equal([3, 3, 4])
	assert_array(_shielded_per_wave(7)).is_equal([4, 4, 5])
	assert_array(_shielded_per_wave(8)).is_equal([0])
