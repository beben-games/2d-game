extends GdUnitTestSuite
## The tiers: each a shipped series by id (Tiers), loaded and checked; an id with no series is
## refused. Pure: no autoload, no scene.


func test_the_shipped_tiers_load_and_validate() -> void:
	assert_array(Tiers.check()).is_empty()
	assert_array(Tiers.IDS).is_equal([1, 2])
	for id: int in Tiers.IDS:
		assert_bool(Tiers.has(id)).is_true()
		var series := Tiers.series(id)
		assert_object(series).is_not_null()
		assert_int(series.tier).is_equal(id)
		assert_array(series.validate()).is_empty()


func test_tier_1_is_the_shipped_tier_1_series() -> void:
	assert_str(Tiers.path(1)).is_equal("res://data/series/tier_1.tres")
	var series := Tiers.series(1)
	assert_object(series).is_same(load("res://data/series/tier_1.tres"))
	assert_object(Tiers.series(1)).is_same(series)  # cached
	assert_int(series.arena_width).is_equal(28)
	assert_int(series.arena_height).is_equal(15)


func test_an_unknown_tier_is_refused() -> void:
	for id: int in [0, -1, 99]:
		assert_bool(Tiers.has(id)).override_failure_message("tier %d" % id).is_false()
		assert_object(Tiers.series(id)).override_failure_message("tier %d" % id).is_null()


func test_a_series_knows_its_tier_and_refuses_one_below_1() -> void:
	var s := SeriesDef.new()
	assert_int(s.tier).is_equal(1)
	s.tier = 0
	assert_array(s.validate()).contains(["tier must be >= 1"])


func test_a_tier_whose_series_names_another_tier_is_an_error() -> void:
	var s: SeriesDef = Tiers.series(1).duplicate()
	assert_array(Tiers.errors_of(1, s)).is_empty()
	assert_array(Tiers.errors_of(2, s)).contains(["tier 2: the series says tier 1"])
	assert_array(Tiers.errors_of(3, null)).contains(["tier 3: no series at %s" % Tiers.path(3)])
	s.rounds = []
	assert_array(Tiers.errors_of(1, s)).contains(["tier 1: series has no rounds"])


# --- The first win's unlock (M7 Task 10) ---


func test_the_first_win_unlock_reads_a_tier_or_nothing() -> void:
	assert_int(SeriesDef.unlock_tier_of("tier:2")).is_equal(2)
	assert_int(SeriesDef.unlock_tier_of("tier:12")).is_equal(12)
	for text: String in ["", "tier:", "tier:x", "tier:0", "tier:-1", "tier:02", "class:2", "tier2", " tier:2"]:
		assert_int(SeriesDef.unlock_tier_of(text)).override_failure_message("'%s'" % text).is_equal(0)


func test_a_series_unlocks_nothing_by_default_and_refuses_a_bad_unlock() -> void:
	var s := SeriesDef.new()
	assert_str(s.first_win_unlock).is_equal("")
	assert_array(s.validate()).not_contains(["first_win_unlock must be \"\" or tier:<n>"])
	s.first_win_unlock = "weapon:bow"
	assert_array(s.validate()).contains(["first_win_unlock must be \"\" or tier:<n>"])
	s.first_win_unlock = "tier:1"  # its own tier: nothing to open
	assert_array(s.validate()).contains(["first_win_unlock tier 1 is not above the series' tier 1"])
	s.first_win_unlock = "tier:2"
	assert_array(s.validate()).not_contains(["first_win_unlock must be \"\" or tier:<n>"])


## A tier's unlock must name a tier the game has: an unknown one is a check error (pushed at the
## first load, so check_boot fails on it).
func test_an_unlock_of_an_unknown_tier_is_an_error() -> void:
	var s: SeriesDef = Tiers.series(1).duplicate()
	s.first_win_unlock = "tier:9"
	assert_array(Tiers.errors_of(1, s)).contains(["tier 1: its first win unlocks tier 9, which is no tier"])
	s.first_win_unlock = "tier:2"
	assert_array(Tiers.errors_of(1, s)).is_empty()


func test_tier_1_s_first_win_opens_tier_2_and_tier_2_s_nothing() -> void:
	assert_str(Tiers.series(1).first_win_unlock).is_equal("tier:2")
	assert_str(Tiers.series(2).first_win_unlock).is_equal("")


# --- Tier 2's rounds (M7 Task 9) ---


func test_tier_2_is_eight_rounds_at_56_by_30() -> void:
	assert_str(Tiers.path(2)).is_equal("res://data/series/tier_2.tres")
	var series := Tiers.series(2)
	assert_object(series).is_not_null()
	assert_int(series.tier).is_equal(2)
	assert_int(series.arena_width).is_equal(56)
	assert_int(series.arena_height).is_equal(30)
	assert_int(series.rounds.size()).is_equal(8)
	assert_array(series.validate()).is_empty()


## The boss round is the beast and its handler alone, one of each, in one wave (a fight is one
## wave's bodies: RoundDef.validate).
func test_tier_2_s_last_round_is_only_the_pair_in_one_wave() -> void:
	var last := Tiers.series(2).rounds[-1].waves
	assert_int(last.waves.size()).is_equal(1)
	var ids: Array[String] = []
	for group in last.waves[0].groups:
		for i in group.count:
			ids.append(_def_id(group.enemy))
	ids.sort()
	assert_array(ids).is_equal(["beast", "handler"])
	assert_float(BossFight.table_max_hp(last)).is_equal(750.0)  # tier 1's boss's health, shared


## Rounds 1 to 3 teach the charger and the bearer at their own size; rounds 4 to 7 are bigger than
## tier 1's: each sends more than tier 1's same round.
func test_tier_2_s_rounds_4_to_7_send_more_than_tier_1_s_same_rounds() -> void:
	var one := Tiers.series(1)
	var two := Tiers.series(2)
	for i in [3, 4, 5, 6]:
		var more := two.rounds[i].waves.total_enemies()
		var fewer := one.rounds[i].waves.total_enemies()
		assert_int(more).override_failure_message("round %d: %d against tier 1's %d" % [i + 1, more, fewer]).is_greater(fewer)


## Every scene a tier's waves send runs the def its file is named after (the gate screen's
## portrait and the audio's rows key on the def's id).
func test_every_enemy_scene_s_def_is_named_after_its_file() -> void:
	for tier: int in Tiers.IDS:
		for r in Tiers.series(tier).rounds:
			for wave in r.waves.waves:
				for group in wave.groups:
					var file := group.enemy.resource_path.get_file().get_basename()
					assert_str(_def_id(group.enemy)).override_failure_message("tier %d: %s" % [tier, file]).is_equal(file)


func _def_id(scene: PackedScene) -> String:
	var node := scene.instantiate()
	var def: Resource = node.get("def")
	var id := str(def.get("id")) if def != null else ""
	node.free()
	return id
