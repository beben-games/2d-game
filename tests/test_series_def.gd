extends GdUnitTestSuite
## Validation and shape of the series and round resources: a run is one arena of rounds.

const CHASER := preload("res://scenes/enemies/chaser.tscn")


func _round(count: int) -> RoundDef:
	var g := SpawnGroup.new()
	g.enemy = CHASER
	g.count = count
	var w := WaveDef.new()
	w.groups = [g]
	var t := WaveTable.new()
	t.waves = [w]
	var r := RoundDef.new()
	r.waves = t
	return r


func test_round_def_needs_a_valid_table() -> void:
	var r := RoundDef.new()
	assert_array(r.validate()).contains_exactly(["waves must be set"])
	var empty_wave := RoundDef.new()
	empty_wave.waves = WaveTable.new()
	empty_wave.waves.waves = [WaveDef.new()]
	assert_array(empty_wave.validate()).contains("waves: wave 0: wave has no groups")
	assert_array(_round(1).validate()).is_empty()


func test_an_empty_series_fails_validation() -> void:
	var s := SeriesDef.new()
	assert_array(s.validate()).contains("series has no rounds")
	assert_int(s.arena_width).is_equal(28)
	assert_int(s.arena_height).is_equal(15)


func test_a_null_round_fails_with_its_index() -> void:
	var s := SeriesDef.new()
	s.rounds = [_round(1), null, RoundDef.new()]
	var errors := s.validate()
	assert_array(errors).contains("round 1: missing")
	assert_array(errors).contains("round 2: waves must be set")
	assert_array(errors).not_contains(["round 0: missing"])


func test_a_small_arena_fails_validation() -> void:
	var s := SeriesDef.new()
	s.rounds = [_round(1)]
	s.arena_width = 4
	s.arena_height = 3
	assert_array(s.validate()).contains_exactly_in_any_order(["arena_width must be >= 8", "arena_height must be >= 6"])


func test_is_last_on_the_last_index_only() -> void:
	var s := SeriesDef.new()
	s.rounds = [_round(1), _round(1), _round(1)]
	assert_bool(s.is_last(0)).is_false()
	assert_bool(s.is_last(1)).is_false()
	assert_bool(s.is_last(2)).is_true()


func test_the_shipped_series_is_eight_rounds_of_28_by_15() -> void:
	var s: SeriesDef = load("res://data/series/tier_1.tres")
	assert_object(s).is_not_null()
	assert_array(s.validate()).is_empty()
	assert_int(s.arena_width).is_equal(28)
	assert_int(s.arena_height).is_equal(15)
	assert_int(s.rounds.size()).is_equal(8)
	assert_int(s.rounds[0].waves.waves.size()).is_equal(2)
	var totals: Array[int] = []
	for r in s.rounds:
		totals.append(r.waves.total_enemies())
	assert_array(totals).contains_exactly([9, 6, 16, 24, 38, 45, 53, 1])  # round 8 is the boss alone
