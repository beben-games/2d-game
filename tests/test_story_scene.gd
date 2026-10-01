extends SceneSuite
## The Story autoload on the bus and the profile, over the fixture story: begin and finish emit
## the three signals and write the save only on finish; a run's start and end clear who has
## spoken; the context reads the last verdict from the newest run record; the suite hooks load
## the empty fixture first and the shipped data after.

const FIXTURE := "res://tests/support/story"

var _started: Array[String] = []
var _ended: Array[String] = []
var _changes := [0]


func before_test() -> void:
	super()
	_started.clear()
	_ended.clear()
	_changes[0] = 0
	Events.event_started.connect(_on_started)
	Events.event_ended.connect(_on_ended)
	Events.story_changed.connect(_on_changed)


func after_test() -> void:
	Events.event_started.disconnect(_on_started)
	Events.event_ended.disconnect(_on_ended)
	Events.story_changed.disconnect(_on_changed)
	await super()


func _on_started(id: String) -> void:
	_started.append(id)


func _on_ended(id: String) -> void:
	_ended.append(id)


func _on_changed() -> void:
	_changes[0] += 1


func test_every_test_starts_on_the_empty_fixture() -> void:
	assert_str(Story.dir).is_equal(SceneSuite.STORY_EMPTY)
	assert_array(Story.catalog.errors).is_empty()
	assert_array(Story.catalog.events).is_empty()
	assert_object(Story.next("lanista", "talk")).is_null()
	assert_bool(Story.has_new("lanista")).is_false()


func test_begin_and_finish_emit_the_signals_and_only_finish_writes() -> void:
	use_story(FIXTURE)
	var event := Story.next("lanista", "talk")
	assert_str(event.id).is_equal("lanista.first_word")
	assert_bool(Story.has_new("lanista")).is_true()
	Story.begin(event)
	assert_array(_started).is_equal(["lanista.first_word"])
	assert_array(_ended).is_empty()
	assert_int(Profile.save.story_played("lanista.first_word")).is_equal(1)
	assert_bool(Profile.save.has_spoken("lanista")).is_true()
	assert_bool(Story.has_new("lanista")).is_false()
	assert_bool(FileAccess.file_exists(SceneSuite.PROFILE_SCRATCH)).is_false()
	Story.finish(event)
	assert_array(_ended).is_equal(["lanista.first_word"])
	assert_int(_changes[0]).is_equal(1)
	assert_int(Profile.save.story_flag("lanista_count", 0)).is_equal(1)  # the event's end effect
	assert_bool(FileAccess.file_exists(SceneSuite.PROFILE_SCRATCH)).is_true()
	var on_disk := Save.load_from(SceneSuite.PROFILE_SCRATCH)
	assert_int(on_disk.story_played("lanista.first_word")).is_equal(1)
	assert_int(on_disk.story_flag("lanista_count", 0)).is_equal(1)


func test_finish_without_commit_leaves_the_disk_alone() -> void:
	use_story(FIXTURE)
	var event := Story.next("lanista", "talk")
	Story.begin(event)
	Story.finish(event, false)
	assert_array(_ended).is_equal(["lanista.first_word"])
	assert_bool(FileAccess.file_exists(SceneSuite.PROFILE_SCRATCH)).is_false()


func test_a_filler_or_an_enter_event_leaves_the_pool_unspoken() -> void:
	use_story(FIXTURE)
	Profile.save.mark_played("lanista.first_word")
	var bark := Story.next("lanista", "talk")
	assert_str(bark.priority).is_equal("filler")
	Story.begin(bark)
	assert_bool(Profile.save.has_spoken("lanista")).is_false()
	var arrival := Story.next("lanista", "enter", "ludus")
	assert_str(arrival.id).is_equal("lanista.arrival")
	Story.begin(arrival)
	assert_bool(Profile.save.has_spoken("lanista")).is_false()


func test_choose_applies_a_choices_effects() -> void:
	use_story(FIXTURE)
	Profile.save.flags["wins"] = 1
	Profile.save.mark_played("lanista.first_word")
	var event := Story.next("lanista", "talk")
	assert_str(event.id).is_equal("lanista.after_first_win")
	var lines := Story.lines(event)
	var choice: Dictionary = lines[lines.size() - 1]
	assert_str(choice["kind"]).is_equal("choice")
	Story.choose(choice["effects"])
	assert_str(Profile.save.story_flag("lanista_mood", "calm")).is_equal("cold")


func test_choice_lines_follow_choose() -> void:
	use_story(FIXTURE)
	Profile.save.flags["wins"] = 1
	Profile.save.mark_played("lanista.first_word")
	var event := Story.next("lanista", "talk")
	var lines := Story.lines(event)
	Story.choose(lines[lines.size() - 1]["effects"])
	assert_array(Story.choice_lines(event, 1)).is_equal([{"kind": "line", "speaker": "lanista", "text": "Hm."}])


func test_a_runs_end_clears_who_has_spoken() -> void:
	use_story(FIXTURE)
	Profile.save.mark_spoken("lanista")
	Profile.save.mark_spoken("veteran")
	Events.run_ended.emit("fall")
	assert_bool(Profile.save.has_spoken("lanista")).is_false()
	assert_bool(Profile.save.has_spoken("veteran")).is_false()
	assert_int(_changes[0]).is_equal(1)
	assert_bool(Story.has_new("lanista")).is_true()


func test_a_runs_start_clears_who_has_spoken_too() -> void:
	use_story(FIXTURE)
	Profile.save.mark_spoken("lanista")
	RunState.start_run()
	assert_bool(Profile.save.has_spoken("lanista")).is_false()
	assert_int(_changes[0]).is_equal(1)


func test_the_context_reads_the_last_verdict_from_the_newest_record() -> void:
	use_story(FIXTURE)
	Profile.save.log_run({"outcome": "fall", "verdict": "up", "bands": [2]})
	assert_str(Story.context().value("last_verdict")).is_equal("up")
	Profile.save.log_run({"outcome": "fall", "verdict": "down", "bands": [0], "felled_by": "shooter"})
	var context := Story.context({"round_loss": "fled"})
	assert_str(context.value("last_verdict")).is_equal("down")
	assert_str(context.value("last_band")).is_equal("boo")
	assert_str(context.value("last_killer")).is_equal("shooter")
	assert_str(context.value("round_loss")).is_equal("fled")
	Profile.save.flags["runs"] = 1
	assert_str(Story.next("", "verdict_down").id).is_equal("narrator.down")


func test_lines_substitutes_from_the_profile() -> void:
	use_story(FIXTURE)
	Profile.save.flags["wins"] = 2
	var lines := Story.lines(Story.next("lanista", "talk"))
	assert_str(lines[0]["text"]).is_equal("Welcome, 2 wins.")


func test_reset_loads_the_shipped_story() -> void:
	use_story(FIXTURE)
	Story.reset()
	assert_str(Story.dir).is_equal(Story.DATA_DIR)
	assert_array(Story.catalog.errors).is_empty()
