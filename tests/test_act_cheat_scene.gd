extends SceneSuite
## The act cheat from the title: actus2 or actus3 in the seed field backs the save up (the .bak),
## replaces it with the act's preset (the profile's flags, the story flags, the events played, from
## the fixture story's acts.json), commits it, and plays an uncheated run from there: a preset with
## `returned` lands in the Ludus. A backup that fails applies nothing, as the wipe; an act with no
## preset wipes nothing. The profile is SceneSuite's scratch (its after_test removes the file and the
## .bak); the story is the fixture's, never the shipped one.

const STORY := "res://tests/support/story"


## A spent profile: money, counts, a story flag, an event the presets never name. No training
## rank: SceneSuite.after_test starts a run before it resets the profile, so a rank a test leaves
## in the live save (one that wipes nothing) would carry into the next test's run as RunState's.
func _spend_the_profile() -> void:
	Profile.save.money = 500
	Profile.save.set_flag("returned", true)
	Profile.save.set_flag("wins", 9)
	Profile.save.set_story_flag("veteran_distant", true)
	Profile.save.mark_story_played("lanista.bark")
	assert_int(Profile.commit()).is_equal(OK)


func _main_at_title() -> Main:
	var main: Main = load(MAIN).instantiate()
	add_child(main)
	return quiet(main)


## Types the word into the title's field and presses Play.
func _play_with(main: Main, word: String) -> void:
	var title: Title = main.get_node("Title")
	title.seed_field.text = word
	title.play()
	await get_tree().process_frame


func test_actus2_starts_from_the_acts_preset_in_the_grounds() -> void:
	use_story(STORY)
	Profile.save.training["offer"] = 1  # wiped below, so nothing is left for after_test's run
	_spend_the_profile()
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	var pressed: Array[Array] = []
	title.play_pressed.connect(func(seed_value: int, cheats: Dictionary, action: String) -> void: pressed.append([seed_value, cheats, action]))
	await _play_with(main, "actus2")
	assert_that(pressed).is_equal([[Cheats.RANDOM_SEED, {}, "act:2"]])
	# The old save is the .bak, whole.
	var kept := Save.load_from(PROFILE_SCRATCH + Save.BACKUP_SUFFIX)
	assert_int(kept.money).is_equal(500)
	assert_int(TrainingRules.rank(kept, "offer")).is_equal(1)
	assert_int(int(kept.flags["wins"])).is_equal(9)
	assert_int(kept.story_played("lanista.bark")).is_equal(1)
	# The live save and the file are the preset over the defaults.
	var preset: Dictionary = Story.catalog.acts[2]
	for save: Save in [Profile.save, Save.load_from(PROFILE_SCRATCH)]:
		assert_int(save.money).is_equal(0)
		assert_dict(save.training).is_empty()
		var flags := Save.FLAG_KEYS.duplicate()
		flags.merge(preset["flags"], true)
		assert_that(save.flags).is_equal(flags)
		assert_that(save.story["flags"]).is_equal({"veteran_trust": true, "lanista_count": 1, "lanista_mood": "pleased"})
		for id: String in ["lanista.arrival", "lanista.first_word", "veteran.hello"]:
			assert_int(save.story_played(id)).override_failure_message("%s played" % id).is_equal(1)
		assert_int(save.story_last("veteran.hello")).is_greater(save.story_last("lanista.arrival"))  # the preset's order
		assert_int(save.story_played("lanista.bark")).is_equal(0)
		assert_int((save.story["played"] as Dictionary).size()).is_equal(3)
		assert_array(save.story["spoken"]).is_empty()  # a fresh return: every pool may speak
	# Returned, so the Ludus is up, quietly: its arrival is played, so no box opens.
	assert_object(main.grounds).is_not_null()
	assert_object(main.room).is_null()
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_that(main._pending_cheats).is_equal({})  # an uncheated run from here
	assert_int(main._pending_seed).is_equal(Cheats.RANDOM_SEED)
	assert_str(Cheats.describe(RunState.cheats)).is_equal("")


func test_actus3_starts_from_act_3s_preset() -> void:
	use_story(STORY)
	_spend_the_profile()
	var main := _main_at_title()
	await _play_with(main, "actus3")
	var preset: Dictionary = Story.catalog.acts[3]
	var on_disk := Save.load_from(PROFILE_SCRATCH)
	for key: String in preset["flags"]:
		assert_that(on_disk.flags[key]).override_failure_message(key).is_equal(preset["flags"][key])
	assert_that(on_disk.story["flags"]).is_equal(preset["story_flags"])
	var played: Array = (on_disk.story["played"] as Dictionary).keys()
	assert_array(played).contains_exactly_in_any_order(preset["played"])
	assert_int(on_disk.story_played("veteran.the_warning")).is_equal(1)
	assert_object(main.grounds).is_not_null()


## A readable save is never lost: when the copy fails (the .bak's path is a directory) nothing is
## wiped and nothing applied; Play goes on with the save as it was (returned: the Ludus). The
## failed copy prints an engine error and wipe() its warning, muted around the one call as the
## wipe's own test does.
func test_a_failed_backup_applies_nothing() -> void:
	use_story(STORY)
	var backup := PROFILE_SCRATCH + Save.BACKUP_SUFFIX
	assert_int(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(backup))).is_equal(OK)
	_spend_the_profile()
	var main := _main_at_title()
	Engine.print_error_messages = false
	await _play_with(main, "actus2")
	Engine.print_error_messages = true
	for save: Save in [Profile.save, Save.load_from(PROFILE_SCRATCH)]:
		assert_int(save.money).is_equal(500)
		assert_int(int(save.flags["wins"])).is_equal(9)
		assert_int(int(save.flags["runs"])).is_equal(0)
		assert_int(save.story_played("lanista.bark")).is_equal(1)
		assert_int(save.story_played("veteran.hello")).is_equal(0)
		assert_that(save.story["flags"]).is_equal({"veteran_distant": true})
	assert_object(main.grounds).is_not_null()
	assert_int(DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))).is_equal(OK)


## A story with no preset for the act (the empty fixture has no acts.json) wipes nothing: the save
## is kept as it was, on disk and live, and Play goes on from it.
func test_an_act_with_no_preset_wipes_nothing() -> void:
	_spend_the_profile()
	var main := _main_at_title()
	Engine.print_error_messages = false
	await _play_with(main, "actus2")
	Engine.print_error_messages = true
	assert_bool(FileAccess.file_exists(PROFILE_SCRATCH + Save.BACKUP_SUFFIX)).is_false()
	assert_int(Profile.save.money).is_equal(500)
	assert_int(Save.load_from(PROFILE_SCRATCH).money).is_equal(500)
	assert_int(Profile.save.story_played("lanista.bark")).is_equal(1)
	assert_object(main.grounds).is_not_null()
