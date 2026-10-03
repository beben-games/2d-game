extends GdUnitTestSuite
## StoryExplain: why an event would not play now, each failing requirement in the file's words
## (the trigger, a played once, a requires, an unless, the when with the values it read, the pool's
## turn this return), and each pool's next event, which is StoryPicker.pick's for every pool, every
## moment, and every state tried. Pure: the fixture story (tests/support/story) and a Save made
## here; never the shipped prose.

const FIXTURE := "res://tests/support/story"
## The moments the agreement is checked under: [trigger, arg, facts].
const MOMENTS: Array[Array] = [
	["talk", "", {}],
	["enter", "ludus", {"arrival": "door"}],
	["enter", "spoliarium", {"arrival": "gate"}],
	["verdict_wait", "", {"run_band": "boo"}],
	["verdict_up", "", {"run_band": "roar"}],
	["verdict_down", "", {"run_band": "quiet"}],
	["pick", "", {"round_band": "cheer", "round_loss": "hit"}],
]

var catalog: StoryCatalog
var save: Save


func before_test() -> void:
	catalog = StoryCatalog.load_dir(FIXTURE)
	assert_array(catalog.errors).is_empty()
	save = Save.new()


func _context(facts: Dictionary = {}) -> StoryContext:
	return StoryContext.new(save, catalog.flags, facts)


func _why(id: String, trigger := "", arg := "", facts: Dictionary = {}) -> Array[String]:
	return StoryExplain.why_not(catalog.by_id[id], catalog, save, _context(facts), trigger, arg)


## The picker's own rules, called directly, and the pool asked: the independent check of why_not.
func _weighed(event: StoryEvent, context: StoryContext, trigger: String, arg: String) -> bool:
	return StoryPicker.on_trigger(event, trigger, arg) and not StoryPicker.turn_taken(event, save) and StoryPicker.eligible(event, save, context) and StoryExplain.asks(catalog, event.trigger, event.pool)


func test_an_eligible_event_has_no_reason() -> void:
	assert_array(_why("veteran.hello")).is_empty()
	assert_array(_why("veteran.hello", "talk")).is_empty()


func test_a_requires_not_played() -> void:
	assert_array(_why("lanista.after_first_win")).contains(["requires lanista.first_word"])
	save.mark_story_played("lanista.first_word")
	assert_array(_why("lanista.after_first_win")).not_contains(["requires lanista.first_word"])


## The condition as the file writes it, then every name it read and its value.
func test_a_when_that_fails_names_its_values() -> void:
	save.mark_story_played("lanista.first_word")
	assert_array(_why("lanista.after_first_win")).is_equal(["when: wins >= 1 (wins is 0)"] as Array[String])
	save.flags["wins"] = 1
	assert_array(_why("lanista.after_first_win")).is_empty()
	save.mark_story_played("lanista.first_word")
	assert_array(_why("veteran.the_warning")).is_equal(["when: deaths >= 1 and not veteran_distant (deaths is 0, veteran_distant is false)"] as Array[String])


## A word and a fact read in a when: the moment's fact handed in shows as its value.
func test_a_when_on_a_word_names_the_word() -> void:
	assert_array(_why("narrator.wait_boo", "verdict_wait", "", {"run_band": "quiet"})).is_equal(["when: run_band == boo (run_band is quiet)"] as Array[String])
	assert_array(_why("narrator.wait_boo", "verdict_wait", "", {"run_band": "boo"})).is_empty()


func test_a_played_once_is_already_played() -> void:
	save.mark_story_played("veteran.hello")
	assert_array(_why("veteran.hello")).is_equal(["already played"] as Array[String])
	save.mark_story_played("veteran.grumble")
	assert_array(_why("veteran.grumble")).is_empty()


func test_an_unless_played() -> void:
	save.mark_story_played("lanista.first_word")
	save.flags["deaths"] = 1
	assert_array(_why("veteran.the_warning")).is_empty()
	save.mark_story_played("veteran.the_goodbye")
	assert_array(_why("veteran.the_warning")).is_equal(["unless veteran.the_goodbye (played)"] as Array[String])


## The pool's turn this return: a talk event that is not filler waits; the filler does not.
func test_a_pool_that_has_spoken_this_return() -> void:
	save.mark_story_spoken("veteran")
	assert_array(_why("veteran.hello")).is_equal(["veteran has spoken this return"] as Array[String])
	assert_array(_why("veteran.grumble")).is_empty()
	save.clear_story_spoken()
	assert_array(_why("veteran.hello")).is_empty()


## The trigger, checked when the moment is given: the event's own and the moment's, as the file
## writes a trigger.
func test_a_trigger_not_the_moments() -> void:
	assert_array(_why("lanista.arrival")).is_empty()
	assert_array(_why("lanista.arrival", "talk")).is_equal(["trigger: enter ludus (the moment is talk)"] as Array[String])
	assert_array(_why("lanista.arrival", "enter", "hypogeum")).is_equal(["trigger: enter ludus (the moment is enter hypogeum)"] as Array[String])
	assert_array(_why("lanista.arrival", "enter", "ludus")).is_empty()
	assert_array(_why("veteran.hello", "pick")).is_equal(["trigger: talk (the moment is pick)"] as Array[String])


## Every reason that holds is listed, in the order: trigger, played, requires, unless, when, turn.
func test_every_reason_is_listed() -> void:
	save.mark_story_played("veteran.the_goodbye")
	save.mark_story_spoken("veteran")
	assert_array(_why("veteran.the_warning", "enter", "ludus")).is_equal([
		"trigger: talk (the moment is enter ludus)",
		"requires lanista.first_word",
		"unless veteran.the_goodbye (played)",
		"when: deaths >= 1 and not veteran_distant (deaths is 0, veteran_distant is false)",
		"veteran has spoken this return",
	] as Array[String])


func test_next_by_pool_names_each_pools_next() -> void:
	var next := StoryExplain.next_by_pool(catalog, save, _context())
	assert_str((next["lanista"] as StoryEvent).id).is_equal("lanista.first_word")
	assert_str((next["veteran"] as StoryEvent).id).is_equal("veteran.hello")
	assert_bool(next.has("narrator")).is_false()
	assert_bool(next.has("doctor")).is_false()
	var entry := StoryExplain.next_by_pool(catalog, save, _context({"arrival": "door"}), "enter", "ludus")
	assert_array(entry.keys()).is_equal(["lanista"])


## The agreement: under every moment and through a run of states (events played one by one, the
## counts and flags changed, a pool spoken), each pool the game asks has StoryPicker.pick's next
## (one it never asks, none), and every event's reasons are none exactly when the picker's own rules
## (called directly) weigh it and the game asks its pool.
func test_next_by_pool_agrees_with_the_picker() -> void:
	var states: Array[Callable] = [
		func() -> void: pass,
		func() -> void: save.mark_story_played("lanista.first_word"),
		func() -> void: save.flags["wins"] = 2,
		func() -> void: save.mark_story_played("veteran.hello"),
		func() -> void: save.mark_story_spoken("veteran"),
		func() -> void: save.flags["deaths"] = 1,
		func() -> void: save.clear_story_spoken(),
		func() -> void: save.set_story_flag("veteran_trust", true),
		func() -> void: save.mark_story_played("veteran.the_warning"),
		func() -> void: save.mark_story_played("lanista.arrival"),
		func() -> void: save.log_run({"outcome": "fall", "verdict": "down", "bands": [0]}),
		func() -> void: save.flags["runs"] = 4,
	]
	for change in states:
		change.call()
		for moment in MOMENTS:
			var trigger: String = moment[0]
			var arg: String = moment[1]
			var context := _context(moment[2])
			var next := StoryExplain.next_by_pool(catalog, save, context, trigger, arg)
			for pool: String in catalog.cast:
				var picked := StoryPicker.pick(catalog, save, context, pool, trigger, arg)
				assert_object(next.get(pool)).is_same(picked if StoryExplain.asks(catalog, trigger, pool) else null)
				for event in catalog.pool(pool):
					var why := StoryExplain.why_not(event, catalog, save, context, trigger, arg)
					assert_bool(why.is_empty()).override_failure_message("%s under %s %s: %s" % [event.id, trigger, arg, why]).is_equal(_weighed(event, context, trigger, arg))
					if event == picked and StoryExplain.asks(catalog, trigger, pool):
						assert_array(why).is_empty()


## The pools the game asks (Main's calls): the verdict only the narrator, the pick only the crowd,
## an entry every pool at once, talk every member that is not timed (cast.json's `timed`).
func test_the_pools_the_game_asks() -> void:
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE.path_join("cast.json")))
	var talked: Array[String] = []
	for pool: String in cast:
		if not (cast[pool] as Dictionary).get("timed", false):
			talked.append(pool)
	assert_array(StoryExplain.asked_pools(catalog, "talk")).is_equal(talked)
	assert_bool(talked.has("narrator")).is_false()
	for verdict in ["verdict_wait", "verdict_up", "verdict_down"]:
		assert_array(StoryExplain.asked_pools(catalog, verdict)).is_equal(["narrator"] as Array[String])
	assert_array(StoryExplain.asked_pools(catalog, "pick")).is_empty()  # no crowd in the fixture's cast
	assert_bool(StoryExplain.asks(catalog, "pick", "crowd")).is_true()
	assert_array(StoryExplain.asked_pools(catalog, "enter")).is_equal(Array(catalog.cast.keys(), TYPE_STRING, "", null))
	assert_bool(StoryExplain.asked_at_once("enter")).is_true()
	assert_bool(StoryExplain.asked_at_once("talk")).is_false()


## An event at a trigger the game never asks of its pool: never next, and the reason says so,
## whatever the moment.
func test_an_event_its_pool_is_never_asked_for() -> void:
	var odd := StoryCatalog.from_texts(
		{"veteran": {"name": "V"}, "narrator": {"timed": true}, "crowd": {"timed": true}}, "",
		{"veteran": "== late\ntrigger: verdict_up\n\n== cheer\ntrigger: pick\n", "narrator": "== chat\n\n== up\ntrigger: verdict_up\n"})
	assert_array(odd.errors).is_empty()
	var context := StoryContext.new(save, odd.flags, {"run_band": "quiet"})
	assert_array(StoryExplain.why_not(odd.by_id["veteran.late"], odd, save, context, "verdict_up")).is_equal(["the game asks only narrator at verdict_up"] as Array[String])
	assert_array(StoryExplain.why_not(odd.by_id["veteran.cheer"], odd, save, context)).is_equal(["the game asks only crowd at pick"] as Array[String])
	assert_array(StoryExplain.why_not(odd.by_id["narrator.chat"], odd, save, context, "talk")).is_equal(["the game never talks to narrator"] as Array[String])
	assert_array(StoryExplain.why_not(odd.by_id["narrator.up"], odd, save, context, "verdict_up")).is_empty()
	assert_array(StoryExplain.next_by_pool(odd, save, context, "verdict_up").keys()).is_equal(["narrator"])
	assert_array(StoryExplain.next_by_pool(odd, save, context, "talk").keys()).is_empty()
