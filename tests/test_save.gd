extends GdUnitTestSuite
## Save: the profile's file. Defaults on a missing file, a round trip through a scratch file
## with every section filled, the version rule, a file from before a stat existed, the run log's
## order and cap, the stat-key rules, and the two "best" setters. Pure: never touches Profile.

const PATH := "user://test_save.cfg"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_when_the_file_is_missing() -> void:
	var s := Save.load_from("user://does_not_exist.cfg")
	assert_int(s.money).is_equal(0)
	assert_dict(s.training).is_empty()
	for key: String in Save.FLAG_KEYS:
		assert_that(s.flags[key]).is_equal(Save.FLAG_KEYS[key])
	for key: String in Save.STAT_KEYS:
		assert_that(s.stat(key, "any" if Save.is_per_id(key) else "")).is_equal(0 if Save.is_per_id(key) else Save.STAT_KEYS[key])
	assert_array(s.runs).is_empty()


func test_the_stat_table_holds_every_stat_of_the_design() -> void:
	var expected: Array[String] = [
		"shots_fired", "shots_hit", "hits_landed", "kills", "hits_taken", "deaths_by", "dashes",
		"dashes_through_danger", "cards_taken", "switches", "rounds_cleared", "rounds_by_band",
		"clean_rounds", "perfect_runs", "boss_kills", "boss_time_best", "coins_earned",
		"coins_lost", "coins_spent", "piles_collected", "favour_peak", "time_played",
		"time_in_grounds", "best_run",
	]
	var keys: Array[String] = []
	for key: String in Save.STAT_KEYS:
		keys.append(key)
	keys.sort()
	expected.sort()
	assert_array(keys).is_equal(expected)
	var per_id: Array[String] = []
	for key: String in Save.PER_ID_KEYS:
		per_id.append(key)
	per_id.sort()
	assert_array(per_id).is_equal(["cards_taken", "deaths_by", "hits_landed", "hits_taken", "kills", "rounds_by_band", "shots_fired"])
	assert_that(Save.FLAG_KEYS).is_equal({"runs": 0, "wins": 0, "falls": 0, "deaths": 0, "perfect_runs": 0, "returned": false})


## Every section filled with a distinct value, written, read back equal.
func test_round_trip_keeps_every_section() -> void:
	var s := Save.new()
	s.money = 123
	s.training["hearts"] = 2
	s.flags["runs"] = 5
	s.flags["wins"] = 1
	s.flags["falls"] = 3
	s.flags["deaths"] = 1
	s.flags["perfect_runs"] = 1
	s.flags["returned"] = true
	var n := 1
	for key: String in Save.STAT_KEYS:
		if key == "best_run":
			continue
		if Save.is_per_id(key):
			s.add_stat(key, n, "a")
			s.add_stat(key, n + 1, "b")
		elif Save.STAT_KEYS[key] is float:
			s.set_stat(key, float(n) + 0.5)
		else:
			s.add_stat(key, n)
		n += 2
	s.set_best_run({"rounds": 4, "kills": 30, "time": 61.5})
	s.log_run({"seed": 7, "outcome": "fall", "bands": ["boo", "roar"]})
	assert_int(s.save_to(PATH)).is_equal(OK)
	var back := Save.load_from(PATH)
	assert_int(back.money).is_equal(123)
	assert_that(back.training).is_equal({"hearts": 2})
	assert_that(back.flags).is_equal({"runs": 5, "wins": 1, "falls": 3, "deaths": 1, "perfect_runs": 1, "returned": true})
	assert_that(back.stats).is_equal(s.stats)
	n = 1
	for key: String in Save.STAT_KEYS:
		if key == "best_run":
			continue
		if Save.is_per_id(key):
			assert_int(back.stat(key, "a")).is_equal(n)
			assert_int(back.stat(key, "b")).is_equal(n + 1)
		elif Save.STAT_KEYS[key] is float:
			assert_float(back.stat(key)).is_equal(float(n) + 0.5)
		else:
			assert_int(back.stat(key)).is_equal(n)
		n += 2
	assert_that(back.stat("best_run")).is_equal({"rounds": 4, "kills": 30, "time": 61.5})
	assert_that(back.runs).is_equal([{"seed": 7, "outcome": "fall", "bands": ["boo", "roar"]}])


func test_a_file_from_a_later_version_loads_as_defaults() -> void:
	var s := Save.new()
	s.money = 50
	s.save_to(PATH)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("meta", "version", 99)
	cfg.save(PATH)
	assert_int(Save.load_from(PATH).money).is_equal(0)


## A file written before a stat existed (or before the section did) loads with that stat at zero.
func test_a_file_missing_the_stats_section_loads_with_zero_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("money", "value", 40)
	cfg.set_value("flags", "runs", 2)
	cfg.save(PATH)
	var s := Save.load_from(PATH)
	assert_int(s.money).is_equal(40)
	assert_int(s.flags["runs"]).is_equal(2)
	assert_int(s.flags["wins"]).is_equal(0)
	assert_int(s.stat("kills", "chaser")).is_equal(0)
	assert_int(s.stat("dashes")).is_equal(0)
	assert_float(s.stat("time_played")).is_equal(0.0)
	assert_that(s.stat("best_run")).is_equal({})


func test_a_stat_of_the_wrong_shape_in_the_file_loads_at_its_default() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("stats", "kills", 12)  # a per-id key holding a bare number
	cfg.set_value("stats", "dashes", {"a": 1})  # a counter holding a table
	cfg.set_value("runs", "log", "not a list")
	cfg.save(PATH)
	var s := Save.load_from(PATH)
	assert_int(s.stat("kills", "chaser")).is_equal(0)
	assert_int(s.stat("dashes")).is_equal(0)
	assert_array(s.runs).is_empty()


func test_the_run_log_keeps_the_newest_first_and_caps() -> void:
	var s := Save.new()
	for i in Save.RUN_LOG_CAP + 2:
		s.log_run({"seed": i})
	assert_int(s.runs.size()).is_equal(Save.RUN_LOG_CAP)
	assert_int(s.runs[0]["seed"]).is_equal(Save.RUN_LOG_CAP + 1)
	assert_int(s.runs[-1]["seed"]).is_equal(2)  # runs 0 and 1 fell off the end


## add_stat asserts on these; the predicate is what the assert checks (a failed assert is a script
## error under the runner, so the rule is tested through it).
func test_a_stat_is_addable_only_with_an_id_exactly_when_it_is_per_id() -> void:
	assert_bool(Save.addable("kills", "chaser")).is_true()
	assert_bool(Save.addable("kills", "")).is_false()
	assert_bool(Save.addable("dashes", "")).is_true()
	assert_bool(Save.addable("dashes", "chaser")).is_false()
	assert_bool(Save.addable("no_such_stat", "")).is_false()
	assert_bool(Save.addable("best_run", "")).is_false()  # a record, not a counter
	assert_bool(Save.addable("boss_time_best", "")).is_false()  # a min, set through set_boss_time
	assert_bool(Save.addable("favour_peak", "")).is_false()  # a max, raised through raise_stat
	assert_bool(Save.addable("time_played", "")).is_true()  # a float sum


func test_add_stat_sums_and_stat_reads_zero_for_an_unknown_id() -> void:
	var s := Save.new()
	s.add_stat("kills", 1, "chaser")
	s.add_stat("kills", 2, "chaser")
	s.add_stat("dashes")
	s.add_stat("time_played", 0.25)
	assert_int(s.stat("kills", "chaser")).is_equal(3)
	assert_int(s.stat("kills", "boss")).is_equal(0)
	assert_int(s.stat("dashes")).is_equal(1)
	assert_float(s.stat("time_played")).is_equal(0.25)
	assert_bool(s.stat("time_played") is float).is_true()
	assert_bool(s.stat("dashes") is int).is_true()


func test_raise_stat_keeps_the_peak() -> void:
	var s := Save.new()
	s.raise_stat("favour_peak", 40.0)
	s.raise_stat("favour_peak", 20.0)
	assert_float(s.stat("favour_peak")).is_equal(40.0)
	s.raise_stat("favour_peak", 75.5)
	assert_float(s.stat("favour_peak")).is_equal(75.5)


func test_set_boss_time_keeps_the_fastest() -> void:
	var s := Save.new()
	assert_float(s.stat("boss_time_best")).is_equal(0.0)  # none yet
	s.set_boss_time(42.0)
	assert_float(s.stat("boss_time_best")).is_equal(42.0)
	s.set_boss_time(50.0)
	assert_float(s.stat("boss_time_best")).is_equal(42.0)
	s.set_boss_time(30.0)
	assert_float(s.stat("boss_time_best")).is_equal(30.0)


func test_set_best_run_keeps_the_better_by_rounds_then_kills() -> void:
	var s := Save.new()
	assert_bool(s.set_best_run({"rounds": 3, "kills": 20, "time": 50.0})).is_true()
	assert_bool(s.set_best_run({"rounds": 2, "kills": 99, "time": 10.0})).is_false()
	assert_that(s.stat("best_run")).is_equal({"rounds": 3, "kills": 20, "time": 50.0})
	assert_bool(s.set_best_run({"rounds": 3, "kills": 21, "time": 90.0})).is_true()
	assert_that(s.stat("best_run")).is_equal({"rounds": 3, "kills": 21, "time": 90.0})
	assert_bool(s.set_best_run({"rounds": 3, "kills": 21, "time": 1.0})).is_false()  # a tie keeps the first
	assert_bool(s.set_best_run({"rounds": 4, "kills": 0, "time": 1.0})).is_true()
