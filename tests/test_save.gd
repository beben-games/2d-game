extends GdUnitTestSuite
## Save: the profile's file. Defaults on a missing file, a round trip through a scratch file
## with every section filled, the version rule, a file from before a stat existed, the run log's
## order and cap, the stat-key rules, and the two "best" setters. Pure: never touches Profile.

const PATH := "user://test_save.cfg"
const BACKUP := PATH + Save.BACKUP_SUFFIX


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))


func _backup_exists() -> bool:
	return FileAccess.file_exists(BACKUP)


func test_defaults_when_the_file_is_missing() -> void:
	var s := Save.load_from("user://does_not_exist.cfg")
	assert_int(s.money).is_equal(0)
	assert_dict(s.training).is_empty()
	for key: String in Save.FLAG_KEYS:
		assert_that(s.flags[key]).is_equal(Save.FLAG_KEYS[key])
	for key: String in Save.STAT_KEYS:
		assert_that(s.stat(key, "any" if Save.is_per_id(key) else "")).is_equal(0 if Save.is_per_id(key) else Save.STAT_KEYS[key])
	assert_array(s.runs).is_empty()


## The design's 24 stats by name (a misspelt key would not be caught by a count); PER_ID_KEYS
## and NOT_ADDABLE only name stats of the table, and a per-id stat's empty value is a
## Dictionary while a plain one's is not.
func test_the_stat_table_holds_the_designs_stats_and_its_side_lists_are_subsets() -> void:
	var keys: Array[String] = []
	for key: String in Save.STAT_KEYS:
		keys.append(key)
	keys.sort()
	assert_array(keys).is_equal([
		"best_run", "boss_kills", "boss_time_best", "cards_taken", "clean_rounds", "coins_earned",
		"coins_lost", "coins_spent", "dashes", "dashes_through_danger", "deaths_by", "favour_peak",
		"hits_landed", "hits_taken", "kills", "perfect_runs", "piles_collected", "rounds_by_band",
		"rounds_cleared", "shots_fired", "shots_hit", "switches", "time_in_grounds", "time_played",
	])
	for key: String in Save.PER_ID_KEYS:
		assert_bool(Save.STAT_KEYS.has(key)).override_failure_message("PER_ID_KEYS names '%s', not a stat" % key).is_true()
		assert_bool(Save.STAT_KEYS[key] is Dictionary).override_failure_message("per-id stat '%s' must start as {}" % key).is_true()
	for key: String in Save.NOT_ADDABLE:
		assert_bool(Save.STAT_KEYS.has(key)).override_failure_message("NOT_ADDABLE names '%s', not a stat" % key).is_true()
	for key: String in Save.STAT_KEYS:
		if key not in Save.PER_ID_KEYS and key != "best_run":
			assert_bool(Save.STAT_KEYS[key] is Dictionary).override_failure_message("plain stat '%s' holds a table" % key).is_false()
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


## A file the game does not understand is kept beside the path as the .bak (the first commit
## overwrites the path with a version-1 file) and the game plays on from the defaults.
func test_a_file_from_a_later_version_is_backed_up_and_loads_as_defaults() -> void:
	var s := Save.new()
	s.money = 50
	s.save_to(PATH)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("meta", "version", 99)
	cfg.save(PATH)
	assert_bool(_backup_exists()).is_false()
	var loaded := Save.load_from(PATH)
	assert_int(loaded.money).is_equal(0)
	assert_str(loaded.backup_note).contains("later version").contains(BACKUP)
	assert_bool(_backup_exists()).is_true()
	var kept := ConfigFile.new()
	assert_int(kept.load(BACKUP)).is_equal(OK)
	assert_int(int(kept.get_value("meta", "version"))).is_equal(99)
	assert_int(int(kept.get_value("money", "value"))).is_equal(50)


## Godot's ConfigFile parser prints an ERROR on a corrupt file and offers no silent parse
## (probed 2026-09-25: core/io/config_file.cpp _parse), which the runner would count against
## this test, so error printing is muted around the one load.
func test_an_unparsable_file_is_backed_up_and_loads_as_defaults() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[meta\nversion = = 1\n")
	file.close()
	Engine.print_error_messages = false
	var s := Save.load_from(PATH)
	Engine.print_error_messages = true
	assert_int(s.money).is_equal(0)
	assert_str(s.backup_note).contains("could not be read").contains(BACKUP)
	assert_int(s.stat("dashes")).is_equal(0)
	assert_bool(_backup_exists()).is_true()
	assert_str(FileAccess.get_file_as_string(BACKUP)).is_equal("[meta\nversion = = 1\n")


func test_a_missing_file_makes_no_backup() -> void:
	var s := Save.load_from(PATH)
	assert_bool(_backup_exists()).is_false()
	assert_str(s.backup_note).is_empty()
	assert_str(Save.new().backup_note).is_empty()


## A newer backup replaces an older one: the .bak is always the last file that was not understood.
func test_a_later_backup_replaces_the_older_one() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 99)
	cfg.set_value("money", "value", 1)
	cfg.save(PATH)
	Save.load_from(PATH)
	cfg.set_value("money", "value", 2)
	cfg.save(PATH)
	Save.load_from(PATH)
	var kept := ConfigFile.new()
	kept.load(BACKUP)
	assert_int(int(kept.get_value("money", "value"))).is_equal(2)


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


## A file holding more records than the cap (an older, bigger cap) loads only the newest.
func test_the_run_log_is_capped_on_load_too() -> void:
	var records: Array = []
	for i in Save.RUN_LOG_CAP + 3:
		records.append({"seed": i})
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("runs", "log", records)
	cfg.save(PATH)
	var s := Save.load_from(PATH)
	assert_int(s.runs.size()).is_equal(Save.RUN_LOG_CAP)
	assert_int(s.runs[0]["seed"]).is_equal(0)
	assert_int(s.runs[-1]["seed"]).is_equal(Save.RUN_LOG_CAP - 1)


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


## An int counter takes only an int (a fraction would drift it to a float the next load drops);
## a float stat takes either.
func test_an_amount_is_addable_only_in_the_counters_type() -> void:
	assert_bool(Save.addable("dashes", "", 2)).is_true()
	assert_bool(Save.addable("dashes", "", 0.5)).is_false()
	assert_bool(Save.addable("kills", "chaser", 1.0)).is_false()
	assert_bool(Save.addable("time_played", "", 0.25)).is_true()
	assert_bool(Save.addable("time_played", "", 1)).is_true()
	assert_bool(Save.addable("dashes", "", "1")).is_false()


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
	s.add_stat("time_played", 1)  # an int into a float stat stays a float
	assert_bool(s.stat("time_played") is float).is_true()
	assert_float(s.stat("time_played")).is_equal(1.25)


## A hand-edited inner value (a String in the file's table) reads as an int, never leaks its type.
func test_a_per_id_stat_reads_as_an_int_whatever_the_table_holds() -> void:
	var s := Save.new()
	var table: Dictionary = s.stats["kills"]
	table["chaser"] = "3"
	assert_bool(s.stat("kills", "chaser") is int).is_true()
	assert_int(s.stat("kills", "chaser")).is_equal(3)


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
	assert_bool(s.set_best_run({"rounds": 3, "kills": 21, "time": 90.0})).is_false()  # a full tie keeps the held one
	assert_bool(s.set_best_run({"rounds": 3, "kills": 21, "time": 100.0})).is_false()  # slower loses
	assert_bool(s.set_best_run({"rounds": 3, "kills": 21, "time": 80.0})).is_true()  # faster wins the tie
	assert_that(s.stat("best_run")).is_equal({"rounds": 3, "kills": 21, "time": 80.0})
	assert_bool(s.set_best_run({"rounds": 4, "kills": 0, "time": 1.0})).is_true()


func test_total_sums_a_per_id_stat_over_its_ids() -> void:
	var save := Save.new()
	assert_int(save.total("kills")).is_equal(0)
	save.add_stat("kills", 3, "chaser")
	save.add_stat("kills", 4, "shooter")
	assert_int(save.total("kills")).is_equal(7)
