extends GdUnitTestSuite
## Validation and shape of the wave resources (the series and its rounds are test_series_def).

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


func test_null_elements_are_reported_not_crashed() -> void:
	var w := WaveDef.new()
	w.groups = [null]
	assert_array(w.validate()).contains("group 0: missing")
	assert_int(w.total()).is_equal(0)
	var t := WaveTable.new()
	t.waves = [null]
	assert_array(t.validate()).contains("wave 0: missing")
	assert_int(t.total_enemies()).is_equal(0)


func test_the_finales_climb_into_the_boss() -> void:
	# The balance pass of 2026-09-22: rounds 1 to 3 as they were, round 4's finale 9 + 3, then
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


func test_shielded_chasers_replace_plain_ones_from_round_4() -> void:
	# Playtest 1, note 3: the shield attribute enters in round 4 and grows into the boss; the
	# totals per round stay the balance pass's (test_series_def pins them).
	for n in [1, 2, 3]:
		for count in _shielded_per_wave(n):
			assert_int(count).override_failure_message("round %d" % n).is_equal(0)
	assert_array(_shielded_per_wave(4)).is_equal([0, 2, 3])
	assert_array(_shielded_per_wave(5)).is_equal([2, 3, 3])
	assert_array(_shielded_per_wave(6)).is_equal([3, 3, 4])
	assert_array(_shielded_per_wave(7)).is_equal([4, 4, 5])
	assert_array(_shielded_per_wave(8)).is_equal([0])
