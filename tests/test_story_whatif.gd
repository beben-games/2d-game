extends GdUnitTestSuite
## The Story tab's What-if (addons/story_graph/story_whatif.gd) without the scene: the scratch
## state (blank; loaded from a copy of a save, the source never written; a missing, corrupt, or
## newer save refused with the state kept), the profile's counts, the last run's facts, the story
## flags, an event marked played and not, a Return, the moments and their facts, and what the
## graph is given (each pool's next, the ineligible dimmed, the selected event's reasons). The
## story is the fixture's (tests/support/story); a save is written to a per-process user:// scratch,
## never user://save.cfg.

const WhatIf := preload("res://addons/story_graph/story_whatif.gd")
const FIXTURE := "res://tests/support/story"

var catalog: StoryCatalog
var _source := ""


func before_test() -> void:
	catalog = StoryCatalog.load_dir(FIXTURE)
	assert_array(catalog.errors).is_empty()
	_source = "user://story_whatif_source_%d.cfg" % OS.get_process_id()


func after_test() -> void:
	for path in [_source, _source + Save.BACKUP_SUFFIX]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _whatif() -> WhatIf:
	var whatif := WhatIf.new()
	whatif.scratch_path = "user://story_whatif_copy_%d.cfg" % OS.get_process_id()
	return whatif


func _ids(events: Dictionary) -> Array:
	var ids := events.keys()
	ids.sort()
	return ids


func _model_ids() -> Array[String]:
	var ids: Array[String] = []
	for event in catalog.events:
		ids.append(event.id)
	return ids


## The fixture's save: a death and a win, the lanista's and the veteran's first words played, the
## veteran spoken this return, a story flag set, a fall by the boss as the last run.
func _write_source() -> PackedByteArray:
	var save := Save.new()
	save.flags["deaths"] = 1
	save.flags["wins"] = 1
	save.flags["runs"] = 2
	save.mark_story_played("lanista.first_word")
	save.mark_story_played("veteran.hello")
	save.mark_story_spoken("veteran")
	save.set_story_flag("lanista_count", 1)
	save.log_run({"outcome": "fall", "verdict": "down", "bands": [1], "felled_by": "boss"})
	assert_int(save.save_to(_source)).is_equal(OK)
	return FileAccess.get_file_as_bytes(_source)


func _assert_untouched(whatif: WhatIf, bytes: PackedByteArray) -> void:
	assert_bool(FileAccess.get_file_as_bytes(_source) == bytes).override_failure_message("the source was changed").is_true()
	assert_bool(FileAccess.file_exists(_source + Save.BACKUP_SUFFIX)).override_failure_message("the source was backed up").is_false()
	assert_bool(FileAccess.file_exists(whatif.scratch_path)).override_failure_message("the copy was left").is_false()
	assert_bool(FileAccess.file_exists(whatif.scratch_path + Save.BACKUP_SUFFIX)).override_failure_message("the copy's backup was left").is_false()


func test_blank_marks_each_pools_first_word() -> void:
	var whatif := _whatif()
	assert_str(whatif.moment()).is_equal("talk")
	var view := whatif.view(catalog, _model_ids())
	assert_array(_ids(view["next"])).is_equal(["armourer.two_asks", "lanista.first_word", "veteran.hello"])
	var dim: Dictionary = view["dim"]
	for id in ["lanista.after_first_win", "lanista.arrival", "narrator.wait", "veteran.next_night", "veteran.the_warning"]:
		assert_bool(dim.has(id)).override_failure_message(id + " not dimmed").is_true()
	for id in ["lanista.first_word", "lanista.bark", "veteran.hello", "veteran.grumble"]:
		assert_bool(dim.has(id)).override_failure_message(id + " dimmed").is_false()
	assert_dict(view["played"]).is_empty()


func test_load_reads_a_copy_and_never_writes_the_source() -> void:
	var bytes := _write_source()
	var whatif := _whatif()
	var result := whatif.load_save(_source)
	assert_bool(result["ok"]).is_true()
	assert_str(result["message"]).contains(_source)
	_assert_untouched(whatif, bytes)
	assert_that(whatif.save.flags["deaths"]).is_equal(1)
	assert_bool(whatif.is_played("veteran.hello")).is_true()
	assert_array(whatif.spoken()).is_equal(["veteran"])
	assert_that(whatif.story_flag(catalog, "lanista_count")).is_equal(1)
	assert_that(whatif.last_run).is_equal({"last_outcome": "fall", "last_verdict": "down", "last_band": "quiet", "last_killer": "boss", "last_tier": 1})  # a record with no tier reads 1
	assert_int(whatif.profile_value("tier_unlocked")).is_equal(2)  # a win opens the second tier
	# the veteran has spoken: only his filler; the lanista's next word waits on a win, which is there
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["armourer.two_asks", "lanista.after_first_win", "veteran.grumble"])
	assert_array(whatif.reasons(catalog, "veteran.the_warning")).is_equal(["veteran has spoken this return"] as Array[String])


## The source path defaults to the game's save; a test always hands its own.
func test_the_default_source_is_the_games_save() -> void:
	assert_str(_whatif().source_path).is_equal(Save.DEFAULT_PATH)


func test_a_missing_save_keeps_the_state() -> void:
	var whatif := _whatif()
	whatif.set_profile("deaths", 3)
	var result := whatif.load_save(_source)
	assert_bool(result["ok"]).is_false()
	assert_str(result["message"]).contains("No save at").contains(_source)
	assert_that(whatif.save.flags["deaths"]).is_equal(3)
	assert_bool(FileAccess.file_exists(_source)).is_false()
	assert_bool(FileAccess.file_exists(whatif.scratch_path)).is_false()


func test_a_corrupt_save_keeps_the_state() -> void:
	var file := FileAccess.open(_source, FileAccess.WRITE)
	file.store_string("[meta\nversion = = 1\n")
	file.close()
	var bytes := FileAccess.get_file_as_bytes(_source)
	var whatif := _whatif()
	whatif.set_profile("deaths", 3)
	var result := whatif.load_save(_source)
	assert_bool(result["ok"]).is_false()
	assert_str(result["message"]).contains("could not be read")
	assert_that(whatif.save.flags["deaths"]).is_equal(3)
	_assert_untouched(whatif, bytes)


func test_a_newer_save_keeps_the_state() -> void:
	_write_source()
	var cfg := ConfigFile.new()
	cfg.load(_source)
	cfg.set_value("meta", "version", Save.VERSION + 1)
	cfg.save(_source)
	var bytes := FileAccess.get_file_as_bytes(_source)
	var whatif := _whatif()
	var result := whatif.load_save(_source)
	assert_bool(result["ok"]).is_false()
	assert_str(result["message"]).contains("later version")
	assert_that(whatif.save.flags["deaths"]).is_equal(0)
	_assert_untouched(whatif, bytes)


func test_blank_starts_again() -> void:
	_write_source()
	var whatif := _whatif()
	whatif.load_save(_source)
	whatif.blank()
	assert_that(whatif.save.flags["deaths"]).is_equal(0)
	assert_dict(whatif.save.story["played"]).is_empty()
	assert_that(whatif.last_run["last_outcome"]).is_equal("none")


## Marked played as the game's begin marks it (a talk event that is not filler uses its pool's
## turn); unmarked, it plays again, the turn still used until a Return.
func test_marking_played_and_the_return() -> void:
	var whatif := _whatif()
	whatif.set_played(catalog, "veteran.hello", true)
	assert_bool(whatif.is_played("veteran.hello")).is_true()
	assert_array(whatif.spoken()).is_equal(["veteran"])
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["armourer.two_asks", "lanista.first_word", "veteran.grumble"])
	assert_array(whatif.reasons(catalog, "veteran.hello")).is_equal(["already played", "veteran has spoken this return"] as Array[String])
	whatif.new_return()
	assert_array(whatif.spoken()).is_empty()
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["armourer.two_asks", "lanista.first_word", "veteran.next_night"])
	whatif.set_played(catalog, "veteran.hello", false)
	assert_bool(whatif.is_played("veteran.hello")).is_false()
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["armourer.two_asks", "lanista.first_word", "veteran.hello"])
	# filler uses no turn
	whatif.set_played(catalog, "lanista.bark", true)
	assert_array(whatif.spoken()).is_empty()
	assert_int(whatif.view(catalog, _model_ids())["played"]["lanista.bark"]).is_equal(1)


func test_the_counts_and_the_story_flags() -> void:
	var whatif := _whatif()
	whatif.set_played(catalog, "lanista.first_word", true)
	whatif.new_return()
	assert_bool(whatif.set_profile("deaths", 1)).is_true()
	assert_bool(whatif.set_profile("deaths", true)).is_false()
	assert_bool(whatif.set_profile("money", 3)).is_false()
	assert_array(whatif.reasons(catalog, "veteran.the_warning")).is_equal(["plays next at talk"] as Array[String])
	assert_bool(whatif.set_story_flag(catalog, "veteran_distant", true)).is_true()
	assert_array(whatif.reasons(catalog, "veteran.the_warning")).is_equal(["when: deaths >= 1 and not veteran_distant (deaths is 1, veteran_distant is true)"] as Array[String])
	assert_bool(whatif.set_story_flag(catalog, "veteran_distant", 1)).is_false()
	assert_bool(whatif.set_story_flag(catalog, "lanista_count", 4)).is_true()
	assert_bool(whatif.set_story_flag(catalog, "lanista_mood", "pleased")).is_true()
	assert_that(whatif.story_flag(catalog, "lanista_mood")).is_equal("pleased")
	assert_that(whatif.story_flag(catalog, "armourer_steel")).is_equal(false)
	assert_bool(whatif.set_story_flag(catalog, "nobody", true)).is_false()


func test_the_last_runs_facts() -> void:
	var whatif := _whatif()
	assert_bool(whatif.set_last("last_band", "boo")).is_true()
	assert_bool(whatif.set_last("last_band", "loud")).is_false()
	assert_bool(whatif.set_last("last_killer", "chaser")).is_true()
	assert_bool(whatif.set_last("money", "boo")).is_false()
	whatif.set_profile("runs", 1)
	assert_bool(whatif.set_moment("verdict_down")).is_true()
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["narrator.down"])
	whatif.set_last("last_band", "roar")
	assert_array(whatif.reasons(catalog, "narrator.down")).is_equal(["when: (last_band == boo or last_band == quiet) and runs > 0 (last_band is roar, runs is 1)"] as Array[String])
	assert_that(whatif.facts()).is_equal({"last_outcome": "none", "last_verdict": "none", "last_band": "roar", "last_killer": "chaser", "last_tier": 0, "run_band": "quiet"})


## The tiers' two names: tier_unlocked among the profile's (the save's stored unlock, read as the
## game reads it: a win opens the second tier), last_tier among the last run's (an int, 0 for no
## run); setting either moves the marks.
func test_the_tier_spinners_set_both_and_the_marks_follow() -> void:
	var tiers := StoryCatalog.from_texts(
		{"lanista": {"name": "L"}, "veteran": {"name": "V"}}, "",
		{"lanista": "== hello\n\n== upstairs\nwhen: tier_unlocked >= 2\npriority: high\n",
		"veteran": "== nod\n\n== came_down\nwhen: last_tier == 2\npriority: high\n"})
	assert_array(tiers.errors).is_empty()
	var whatif := _whatif()
	assert_int(whatif.profile_value("tier_unlocked")).is_equal(1)
	assert_int(whatif.last_run["last_tier"]).is_equal(0)
	assert_array(_ids(whatif.next_ids(tiers))).is_equal(["lanista.hello", "veteran.nod"])
	assert_array(whatif.reasons(tiers, "lanista.upstairs")).is_equal(["when: tier_unlocked >= 2 (tier_unlocked is 1)"] as Array[String])
	assert_bool(whatif.set_profile("tier_unlocked", 2)).is_true()
	assert_int(whatif.profile_value("tier_unlocked")).is_equal(2)
	assert_array(_ids(whatif.next_ids(tiers))).is_equal(["lanista.upstairs", "veteran.nod"])
	assert_bool(whatif.set_last("last_tier", 2)).is_true()
	assert_array(_ids(whatif.next_ids(tiers))).is_equal(["lanista.upstairs", "veteran.came_down"])
	assert_that(whatif.facts()["last_tier"]).is_equal(2)
	# refused: below tier 1, a negative tier, a word for a tier, a number for a word
	assert_bool(whatif.set_profile("tier_unlocked", 0)).is_false()
	assert_bool(whatif.set_profile("tier_unlocked", true)).is_false()
	assert_bool(whatif.set_last("last_tier", -1)).is_false()
	assert_bool(whatif.set_last("last_tier", "two")).is_false()
	assert_bool(whatif.set_last("last_band", 2)).is_false()
	assert_int(whatif.last_run["last_tier"]).is_equal(2)
	# back to 1: the stored unlock lowered, unless a win keeps the second tier open
	assert_bool(whatif.set_profile("tier_unlocked", 1)).is_true()
	assert_array(_ids(whatif.next_ids(tiers))).is_equal(["lanista.hello", "veteran.came_down"])
	whatif.set_profile("wins", 1)
	assert_int(whatif.profile_value("tier_unlocked")).is_equal(2)
	assert_array(_ids(whatif.next_ids(tiers))).is_equal(["lanista.upstairs", "veteran.came_down"])
	whatif.blank()
	assert_int(whatif.profile_value("tier_unlocked")).is_equal(1)
	assert_int(whatif.last_run["last_tier"]).is_equal(0)


## Each moment hands in the facts the game does (Main): an entry its arrival, the verdict the run's
## band, the pick the round's band and loss, talk none.
func test_the_moments_and_their_facts() -> void:
	var whatif := _whatif()
	assert_array(whatif.moments()).contains(["talk", "enter ludus", "enter spoliarium", "verdict_wait", "verdict_up", "verdict_down", "pick"])
	assert_bool(whatif.set_moment("dance")).is_false()
	assert_array(whatif.moment_fact_names()).is_empty()
	assert_bool(whatif.set_moment("enter ludus")).is_true()
	assert_array(whatif.moment_fact_names()).is_equal(["arrival"] as Array[String])
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["lanista.arrival"])
	assert_array(whatif.reasons(catalog, "lanista.arrival")).is_equal(["plays next at enter ludus"] as Array[String])
	assert_array(whatif.reasons(catalog, "veteran.hello")).is_equal(["trigger: talk (the moment is enter ludus)"] as Array[String])
	whatif.set_moment("enter spoliarium")
	assert_bool(whatif.set_fact("arrival", "gate")).is_true()
	assert_bool(whatif.set_fact("arrival", "window")).is_false()
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["narrator.wake"])
	whatif.set_moment("verdict_wait")
	assert_array(whatif.moment_fact_names()).is_equal(["run_band"] as Array[String])
	whatif.set_fact("run_band", "boo")
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["narrator.wait_boo"])
	assert_array(whatif.reasons(catalog, "narrator.wait")).is_equal(["eligible, but narrator.wait_boo plays first"] as Array[String])
	whatif.set_fact("run_band", "quiet")
	assert_array(_ids(whatif.next_ids(catalog))).is_equal(["narrator.wait"])
	whatif.set_moment("pick")
	assert_array(whatif.moment_fact_names()).is_equal(["round_band", "round_loss"] as Array[String])
	assert_bool(whatif.set_fact("round_loss", "fled")).is_true()
	assert_that(whatif.facts()["round_loss"]).is_equal("fled")
	assert_bool(whatif.facts().has("run_band")).is_false()


## An arrival plays one event of every pool's (Main asks the story of no pool in particular): only
## the first is marked, the other is eligible but waits.
func test_an_entry_marks_one_event_across_the_pools() -> void:
	var two := StoryCatalog.from_texts(
		{"lanista": {"name": "L"}, "veteran": {"name": "V"}}, "",
		{"lanista": "== come_in\ntrigger: enter ludus\n", "veteran": "== nod\ntrigger: enter ludus\npriority: story\n"})
	assert_array(two.errors).is_empty()
	var whatif := _whatif()
	whatif.set_moment("enter ludus")
	assert_array(_ids(whatif.next_ids(two))).is_equal(["veteran.nod"])
	assert_array(whatif.reasons(two, "lanista.come_in")).is_equal(["eligible, but veteran.nod plays first"] as Array[String])
	assert_bool(whatif.view(two, ["lanista.come_in", "veteran.nod"] as Array[String])["dim"].has("lanista.come_in")).is_false()


## An event the catalog left out (its errors) never plays: dimmed, and said so.
func test_an_event_not_loaded() -> void:
	var whatif := _whatif()
	var view := whatif.view(catalog, ["veteran.ghost"] as Array[String])
	assert_bool(view["dim"].has("veteran.ghost")).is_true()
	assert_str(whatif.reasons(catalog, "veteran.ghost")[0]).contains("not loaded")


## An event at a trigger the game never asks of its pool is never marked, and says why.
func test_an_event_its_pool_is_never_asked_for() -> void:
	var odd := StoryCatalog.from_texts(
		{"veteran": {"name": "V"}, "narrator": {"timed": true}}, "",
		{"veteran": "== late\ntrigger: verdict_up\n", "narrator": "== chat\n\n== up\ntrigger: verdict_up\n"})
	assert_array(odd.errors).is_empty()
	var whatif := _whatif()
	whatif.set_moment("verdict_up")
	assert_array(_ids(whatif.next_ids(odd))).is_equal(["narrator.up"])
	assert_array(whatif.reasons(odd, "veteran.late")).is_equal(["the game asks only narrator at verdict_up"] as Array[String])
	assert_bool(whatif.view(odd, ["veteran.late"] as Array[String])["dim"].has("veteran.late")).is_true()
	whatif.set_moment("talk")
	assert_array(_ids(whatif.next_ids(odd))).is_empty()
	assert_array(whatif.reasons(odd, "narrator.chat")).is_equal(["the game never talks to narrator"] as Array[String])


## An emptied word flag is its declared default, never "".
func test_an_empty_word_flag_is_its_default() -> void:
	var whatif := _whatif()
	assert_bool(whatif.set_story_flag(catalog, "lanista_mood", "pleased")).is_true()
	assert_bool(whatif.set_story_flag(catalog, "lanista_mood", "")).is_true()
	assert_that(whatif.story_flag(catalog, "lanista_mood")).is_equal("calm")
	assert_bool(whatif.set_story_flag(catalog, "lanista_mood", "  ")).is_true()
	assert_that(whatif.story_flag(catalog, "lanista_mood")).is_equal("calm")


## The panel shows each profile flag as a spinner (an int) or a box (a bool): a flag of another
## type must fail here before the panel shows it wrong.
func test_every_profile_flag_is_an_int_or_a_bool() -> void:
	for key: String in Save.FLAG_KEYS:
		var value: Variant = Save.FLAG_KEYS[key]
		assert_bool(value is int or value is bool).override_failure_message("Save.FLAG_KEYS.%s is neither an int nor a bool" % key).is_true()

