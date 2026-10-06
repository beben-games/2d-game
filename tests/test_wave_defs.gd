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


# --- Tier 2's rounds (M7 Task 9) ---


## The kinds a tier 2 round sends, by the scenes' file names, each wave's in the file's order.
func _tier2_kinds(n: int) -> Array[Dictionary]:
	var t: WaveTable = load("res://data/waves/tier2_room_%d.tres" % n)
	var out: Array[Dictionary] = []
	for w in t.waves:
		var kinds := {}
		for g in w.groups:
			var kind := g.enemy.resource_path.get_file().get_basename()
			kinds[kind] = int(kinds.get(kind, 0)) + g.count
		out.append(kinds)
	return out


func _sent(n: int) -> Dictionary:
	var all := {}
	for kinds in _tier2_kinds(n):
		for kind: String in kinds:
			all[kind] = int(all.get(kind, 0)) + int(kinds[kind])
	return all


## The design's eight: 1 the charger alone, 2 the charger with chasers, 3 the standard-bearer with a
## small pack, 4 to 7 both with tier 1's enemies (shooters, shielded chasers), 8 the pair.
func test_tier_2_s_rounds_bring_each_lesson_in_order() -> void:
	assert_array(_sent(1).keys()).contains_exactly(["charger"])
	assert_array(_sent(2).keys()).contains_exactly_in_any_order(["charger", "chaser"])
	assert_array(_sent(3).keys()).contains("standard_bearer")
	assert_array(_sent(3).keys()).not_contains(["shooter", "chaser_shield"])
	for kinds in _tier2_kinds(3):
		assert_int(int(kinds.get("standard_bearer", 0))).is_equal(1)  # a bearer and its small pack
	for n in [4, 5, 6, 7]:
		assert_array(_sent(n).keys()).override_failure_message("round %d" % n) \
			.contains_exactly_in_any_order(["chaser", "charger", "standard_bearer", "shooter", "chaser_shield"])
	assert_array(_sent(8).keys()).contains_exactly_in_any_order(["beast", "handler"])


## Bigger waves than tier 1's from round 4 on: each wave sends more than tier 1's same wave.
func test_tier_2_s_mixed_waves_outgrow_tier_1_s() -> void:
	for n in [4, 5, 6, 7]:
		var one: WaveTable = load("res://data/waves/room_%d.tres" % n)
		var two: WaveTable = load("res://data/waves/tier2_room_%d.tres" % n)
		assert_int(two.waves.size()).is_equal(one.waves.size())
		for i in two.waves.size():
			assert_int(two.waves[i].total()).override_failure_message("round %d wave %d" % [n, i]).is_greater(one.waves[i].total())


## The breathers are tier 1's: the first wave's 1 s, then 1.5 s, the last of rounds 4 to 7 2 s,
## the boss's 1.5 s.
func test_tier_2_s_breathers_are_tier_1_s() -> void:
	for n in range(1, 9):
		var t: WaveTable = load("res://data/waves/tier2_room_%d.tres" % n)
		for i in t.waves.size():
			var expected := 1.0 if i == 0 else 1.5
			if n == 8:
				expected = 1.5
			elif n >= 4 and i == t.waves.size() - 1:
				expected = 2.0
			assert_float(t.waves[i].breather).override_failure_message("round %d wave %d" % [n, i]).is_equal(expected)
