extends GdUnitTestSuite
## StoryCatalog: a valid fixture loads clean (a cast id without a pool file is an empty pool),
## and every load error from a small inline pool, naming the file and the line; a catalog with
## errors still holds its valid events. Pure: the inline cases go through from_texts.

const FIXTURE := "res://tests/support/story"
const CAST := {
	"veteran": {"name": "PLACEHOLDER Veteran"},
	"lanista": {"name": "PLACEHOLDER Lanista"},
	"narrator": {"name": "PLACEHOLDER Narrator", "timed": true},
	"crowd": {"timed": true},
}
const FLAGS := "met\ncount = 0\nmood = calm\n"


func _catalog(pools: Dictionary, flags := FLAGS, cast: Dictionary = CAST) -> StoryCatalog:
	return StoryCatalog.from_texts(cast, flags, pools)


## The one error the pools give, which starts with `where` and contains `what`.
func _error(pools: Dictionary, where: String, what: String, flags := FLAGS) -> void:
	var errors := _catalog(pools, flags).errors
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0]).starts_with(where).contains(what)


func test_the_fixture_loads_clean() -> void:
	var c := StoryCatalog.load_dir(FIXTURE)
	assert_array(c.errors).is_empty()
	assert_array(c.cast.keys()).contains_exactly_in_any_order(["lanista", "veteran", "narrator", "doctor", "armourer", "attendant"])
	assert_bool(c.by_id.has("lanista.first_word")).is_true()
	assert_bool(c.by_id.has("veteran.the_warning")).is_true()
	assert_bool(c.by_id.has("narrator.wait")).is_true()
	assert_int(c.events.size()).is_equal(c.by_id.size())
	assert_that(c.flags["lanista_mood"]).is_equal("calm")


func test_a_cast_id_without_a_pool_file_is_an_empty_pool() -> void:
	var c := StoryCatalog.load_dir(FIXTURE)
	assert_array(c.pool("doctor")).is_empty()
	assert_array(c.pool("nobody")).is_empty()
	assert_int(c.pool("lanista").size()).is_greater(0)


func test_a_pool_keeps_file_order() -> void:
	var c := _catalog({"veteran": "== b\n\n== a\n\n== c\n"})
	var names: Array = []
	for e: StoryEvent in c.pool("veteran"):
		names.append(e.name)
	assert_array(names).is_equal(["b", "a", "c"])


func test_a_directory_without_a_cast_is_an_error() -> void:
	var c := StoryCatalog.load_dir("res://tests/support/no_such_story")
	assert_int(c.errors.size()).is_equal(1)
	assert_str(c.errors[0]).contains("cast.json")
	assert_array(c.events).is_empty()


func test_a_duplicate_id() -> void:
	_error({"veteran": "== hello\n\n== hello\n"}, "veteran.txt:3: ", "duplicate event 'veteran.hello' (first at line 1)")


func test_an_unknown_speaker() -> void:
	_error({"veteran": "== e\n\nDOCTOR: Hi.\n"}, "veteran.txt:3: ", "unknown speaker 'DOCTOR'")
	_error({"veteran": "== e\n\n? Ask.\n    GHOST: Boo.\n"}, "veteran.txt:4: ", "unknown speaker 'GHOST'")


func test_an_unknown_event_in_requires_or_unless() -> void:
	_error({"veteran": "== e\nrequires: lanista.nothing\n"}, "veteran.txt:2: ", "unknown event 'lanista.nothing' in requires")
	_error({"veteran": "== e\nunless: veteran.nothing\n"}, "veteran.txt:2: ", "unknown event 'veteran.nothing' in unless")


func test_requires_across_pools_is_fine() -> void:
	var c := _catalog({"veteran": "== e\nrequires: lanista.first\n", "lanista": "== first\n"})
	assert_array(c.errors).is_empty()
	assert_int(c.events.size()).is_equal(2)


func test_a_cycle_of_requires() -> void:
	var c := _catalog({"veteran": "== a\nrequires: lanista.b\n", "lanista": "== b\nrequires: veteran.a\n\n== free\n"})
	assert_int(c.errors.size()).is_equal(1)
	assert_str(c.errors[0]).contains("cycle").contains("veteran.a").contains("lanista.b")
	assert_bool(c.by_id.has("veteran.a")).is_false()
	assert_bool(c.by_id.has("lanista.b")).is_false()
	assert_bool(c.by_id.has("lanista.free")).is_true()
	_error({"veteran": "== a\nrequires: veteran.a\n"}, "veteran.txt:2: ", "cycle")


func test_an_unknown_name_in_a_condition() -> void:
	_error({"veteran": "== e\nwhen: ghost >= 1\n"}, "veteran.txt:2: ", "when: unknown name 'ghost'")
	_error({"veteran": "== e\n\n[ghost] VETERAN: Hi.\n"}, "veteran.txt:3: ", "unknown name 'ghost'")


func test_an_unknown_name_in_a_substitution() -> void:
	_error({"veteran": "== e\n\nVETERAN: {ghost} nights.\n"}, "veteran.txt:3: ", "unknown name 'ghost' in {ghost}")
	_error({"veteran": "== e\n\n? {nobody}?\n"}, "veteran.txt:3: ", "unknown name 'nobody'")
	assert_array(_catalog({"veteran": "== e\n\nVETERAN: {wins}, {mood}, {last_band}, {count}.\n"}).errors).is_empty()


func test_a_word_outside_a_names_list() -> void:
	_error({"veteran": "== e\nwhen: last_verdict == sideways\n"}, "veteran.txt:2: ", "'sideways' is not a word of 'last_verdict'")
	_error({"narrator": "== e\ntrigger: enter spoliarium\nwhen: arrival == lift\n"}, "narrator.txt:3: ", "'lift' is not a word of 'arrival'")
	assert_array(_catalog({"narrator": "== e\ntrigger: enter spoliarium\nwhen: arrival == gate\n"}).errors).is_empty()


func test_an_effect_on_an_undeclared_flag() -> void:
	_error({"veteran": "== e\n\nset: ghost\n"}, "veteran.txt:3: ", "undeclared flag 'ghost'")
	_error({"veteran": "== e\n\n? Go.\n    set: ghost\n"}, "veteran.txt:4: ", "undeclared flag 'ghost'")


func test_an_effect_of_the_wrong_type() -> void:
	_error({"veteran": "== e\n\nset: met = 3\n"}, "veteran.txt:3: ", "'met' is a bool")
	_error({"veteran": "== e\n\nset: count\n"}, "veteran.txt:3: ", "'count' is an int")
	_error({"veteran": "== e\n\nset: mood = 2\n"}, "veteran.txt:3: ", "'mood' is a word")
	assert_array(_catalog({"veteran": "== e\n\nset: met\nset: met = false\nset: count = 4\nset: mood = warm\n"}).errors).is_empty()


func test_a_timed_event_with_a_choice() -> void:
	_error({"narrator": "== e\ntrigger: verdict_wait\n\n? Choose.\n"}, "narrator.txt:4: ", "a timed event has no choices")


func test_a_timed_line_over_the_cap() -> void:
	var fits := "x".repeat(StoryCatalog.TIMED_LINE_CAP)
	assert_array(_catalog({"narrator": "== e\ntrigger: verdict_up\n\nNARRATOR: PLACEHOLDER %s\n" % fits}).errors).is_empty()
	_error({"narrator": "== e\ntrigger: verdict_down\n\nNARRATOR: %sx\n" % fits}, "narrator.txt:4: ", "over %d" % StoryCatalog.TIMED_LINE_CAP)
	_error({"crowd": "== e\ntrigger: pick\n\nNARRATOR: PLACEHOLDER %sx\n" % fits}, "crowd.txt:4: ", "over")
	# the timed cap is for the timed triggers only; a box line has its own, longer cap
	assert_array(_catalog({"veteran": "== e\n\nVETERAN: %s\n" % "y".repeat(StoryCatalog.BOX_LINE_CAP)}).errors).is_empty()


## A line the box shows holds three wrapped lines at most: over BOX_LINE_CAP (the marker stripped,
## before substitution) is an error, in the body and under a choice alike.
func test_a_box_line_over_the_cap() -> void:
	var fits := "y".repeat(StoryCatalog.BOX_LINE_CAP)
	assert_array(_catalog({"veteran": "== e\n\nVETERAN: PLACEHOLDER %s\n" % fits}).errors).is_empty()
	assert_array(_catalog({"veteran": "== e\n\nVETERAN: {wins} %s\n" % fits.substr(7)}).errors).is_empty()  # {wins} counts as written
	_error({"veteran": "== e\n\nVETERAN: PLACEHOLDER %sy\n" % fits}, "veteran.txt:3: ", "a line over %d characters" % StoryCatalog.BOX_LINE_CAP)
	_error({"veteran": "== e\n\n? Ask.\n    VETERAN: %sy\n" % fits}, "veteran.txt:4: ", "a line over")


## At most CHOICE_MAX choices at once (one a pick key), counted over a run of choices; a line
## between two runs starts the count again.
func test_more_than_the_choice_max_at_once() -> void:
	var five := "? A.\n? B.\n? C.\n? D.\n? E.\n"
	for i in StoryCatalog.CHOICE_MAX:  # a pick key for every choice the box can offer
		assert_bool(InputMap.has_action(DialogueBox.pick_action(i))).is_true()
	assert_array(_catalog({"veteran": "== e\n\n" + five}).errors).is_empty()
	assert_array(_catalog({"veteran": "== e\n\n" + five + "VETERAN: Hm.\n" + five}).errors).is_empty()
	_error({"veteran": "== e\n\n" + five + "? F.\n"}, "veteran.txt:8: ", "more than 5 choices at once")
	_error({"veteran": "== e\n\n? A.\n# between\n? B.\n? C.\n? D.\n? E.\n? F.\n"}, "veteran.txt:9: ", "more than 5 choices")


## A line with a condition between two runs of choices does not end the run: when it is dropped
## the box would show both runs as one list.
func test_a_conditioned_line_between_two_runs_does_not_end_the_run() -> void:
	var five := "? A.\n? B.\n? C.\n? D.\n? E.\n"
	_error({"veteran": "== e\n\n" + five + "[met] VETERAN: Hm.\n? F.\n"}, "veteran.txt:9: ", "more than 5 choices at once")
	assert_array(_catalog({"veteran": "== e\n\n? A.\n? B.\n[met] VETERAN: Hm.\n? C.\n"}).errors).is_empty()


## A choice's text is one row of the box: over CHOICE_TEXT_CAP (the marker stripped, before
## substitution) is an error.
func test_a_choice_over_the_text_cap() -> void:
	var fits := "z".repeat(StoryCatalog.CHOICE_TEXT_CAP)
	assert_int(StoryCatalog.CHOICE_TEXT_CAP).is_equal(60)
	assert_array(_catalog({"veteran": "== e\n\n? PLACEHOLDER %s\n" % fits}).errors).is_empty()
	_error({"veteran": "== e\n\nVETERAN: Hm.\n? PLACEHOLDER %sz\n" % fits}, "veteran.txt:4: ", "a choice over 60 characters (61)")


## A timed pool makes its every event timed (the narrator's `enter` line plays in the window):
## no choice, the line cap; the same event in an untimed pool loads clean.
func test_an_enter_event_in_a_timed_pool_is_timed() -> void:
	var long_line := "x".repeat(StoryCatalog.TIMED_LINE_CAP + 1)
	_error({"narrator": "== e\ntrigger: enter spoliarium\n\n? Choose.\n"}, "narrator.txt:4: ", "a timed event has no choices")
	_error({"narrator": "== e\ntrigger: enter spoliarium\n\nNARRATOR: %s\n" % long_line}, "narrator.txt:4: ", "over %d" % StoryCatalog.TIMED_LINE_CAP)
	assert_array(_catalog({"veteran": "== e\ntrigger: enter spoliarium\n\n? Choose.\n\n== f\ntrigger: enter spoliarium\n\nVETERAN: %s\n" % long_line}).errors).is_empty()
	var c := _catalog({"narrator": "== e\ntrigger: enter spoliarium\n", "veteran": "== e\ntrigger: enter spoliarium\n\n== w\ntrigger: verdict_wait\n"})
	assert_bool(c.is_timed(c.by_id["narrator.e"])).is_true()
	assert_bool(c.is_timed(c.by_id["veteran.e"])).is_false()
	assert_bool(c.is_timed(c.by_id["veteran.w"])).is_true()
	assert_bool(StoryCatalog.is_timed_trigger("enter")).is_false()
	assert_bool(StoryCatalog.is_timed_trigger("pick")).is_true()


func test_a_cast_id_without_a_name_where_one_is_needed() -> void:
	var c := _catalog({}, FLAGS, {"veteran": {}, "crowd": {"timed": true}, "lanista": "a string"})
	assert_int(c.errors.size()).is_equal(2)
	assert_str(c.errors[0]).starts_with("cast.json: ").contains("'veteran'").contains("no name")
	assert_str(c.errors[1]).starts_with("cast.json: ").contains("'lanista'").contains("not an object")
	assert_array(c.cast.keys()).is_equal(["crowd"])


func test_a_timed_that_is_not_a_bool_is_an_error() -> void:
	for value: Variant in ["yes", 1]:
		var c := _catalog({"crowd": "== e\ntrigger: enter ludus\n\n? Choose.\n"}, FLAGS, {"crowd": {"timed": value}})
		assert_int(c.errors.size()).override_failure_message("timed %s: %s" % [value, c.errors]).is_equal(1)
		if c.errors.size() == 1:
			assert_str(c.errors[0]).starts_with("cast.json: ").contains("'crowd'").contains("timed is true or false")
		assert_array(c.events).is_empty()  # the member did not load, so its pool does not either


func test_a_silhouette_that_is_not_a_bool_is_an_error() -> void:
	for value: Variant in ["yes", 1]:
		var c := _catalog({}, FLAGS, {"narrator": {"timed": true, "silhouette": value}})
		assert_int(c.errors.size()).override_failure_message("silhouette %s: %s" % [value, c.errors]).is_equal(1)
		if c.errors.size() == 1:
			assert_str(c.errors[0]).starts_with("cast.json: ").contains("'narrator'").contains("silhouette is true or false")
	assert_array(_catalog({}, FLAGS, {"narrator": {"timed": true, "silhouette": true}}).errors).is_empty()


func test_a_name_that_is_not_a_string_is_an_error() -> void:
	var c := _catalog({}, FLAGS, {"veteran": {"name": 3}, "narrator": {"name": ["N"], "timed": true}})
	assert_int(c.errors.size()).is_equal(2)
	for message: String in c.errors:
		assert_str(message).starts_with("cast.json: ").contains("name is a string")


func test_a_pool_not_in_the_cast() -> void:
	_error({"ghost": "== e\n"}, "ghost.txt: ", "not in the cast")


func test_a_story_flag_that_shadows_a_name() -> void:
	_error({}, "flags.txt:2: ", "'wins' is a name the story already reads", "met\nwins = 0\n")


func test_the_scripts_errors_come_through_with_the_file() -> void:
	_error({"veteran": "== e\npriority: urgent\n"}, "veteran.txt:2: ", "unknown priority")
	_error({}, "flags.txt:1: ", "is not a flag", "a b\n")


## An event naming one that did not load (a parse error, a check here, a cycle) does not load
## either, with one error naming the cause, to a fixed point; an id that names nothing is the
## "unknown event" error.
func test_the_dependents_of_an_event_that_did_not_load_do_not_load() -> void:
	var c := _catalog({
		"veteran": "== broken\nmood: grim\n\n== bad_speaker\n\nGHOST: Boo.\n\n== a\nrequires: veteran.b\n\n== b\nrequires: veteran.a\n",
		"lanista": "== needs_broken\nrequires: veteran.broken\n\n== bars_speaker\nunless: veteran.bad_speaker\n\n== needs_cycle\nrequires: veteran.a\n\n== chain\nrequires: lanista.needs_broken\n\n== fine\n",
	})
	assert_array(c.by_id.keys()).is_equal(["lanista.fine"])
	var causes: Array[String] = []
	for message: String in c.errors:
		if message.contains("which did not load"):
			causes.append(message)
	assert_int(causes.size()).is_equal(4)
	assert_str(causes[0]).starts_with("lanista.txt:2: ").contains("requires veteran.broken, which did not load")
	assert_str(causes[1]).starts_with("lanista.txt:5: ").contains("unless veteran.bad_speaker, which did not load")
	assert_str(causes[2]).starts_with("lanista.txt:8: ").contains("requires veteran.a")
	assert_str(causes[3]).starts_with("lanista.txt:11: ").contains("requires lanista.needs_broken")
	for message: String in c.errors:
		assert_str(message).not_contains("unknown event")


func test_an_id_that_names_nothing_is_still_unknown() -> void:
	_error({"veteran": "== e\nrequires: veteran.nothing\n"}, "veteran.txt:2: ", "unknown event 'veteran.nothing'")


func test_the_parsers_warnings_are_collected_not_errors() -> void:
	var c := _catalog({"veteran": "== e   # inline\n\nset: met   # inline\n"})
	assert_array(c.errors).is_empty()
	assert_int(c.warnings.size()).is_equal(2)
	assert_str(c.warnings[0]).starts_with("veteran.txt:1: ").contains("inline comment")


func test_comments_in_a_body_pass_the_checks() -> void:
	assert_array(_catalog({"veteran": "== e\n\n# GHOST: not a line\nVETERAN: Hi.\n? Go.\n    # {nobody} is not read\n"}).errors).is_empty()


func test_a_catalog_with_errors_keeps_its_valid_events() -> void:
	var c := _catalog({"veteran": "== bad\n\nGHOST: Boo.\n\n== good\n\nVETERAN: Hi.\n"})
	assert_int(c.errors.size()).is_equal(1)
	assert_bool(c.by_id.has("veteran.good")).is_true()
	assert_bool(c.by_id.has("veteran.bad")).is_false()
	assert_int(c.pool("veteran").size()).is_equal(1)


func test_the_tables() -> void:
	assert_array(StoryScript.PRIORITIES).is_equal(["story", "high", "normal", "filler"])
	assert_array(StoryScript.TRIGGERS).is_equal(["talk", "enter", "verdict_wait", "verdict_up", "verdict_down", "pick"])
	assert_array(StoryScript.ROOMS).is_equal(["ludus", "armamentarium", "hypogeum", "sanitarium", "spoliarium"])
	assert_array(StoryCatalog.TIMED_TRIGGERS).is_equal(["verdict_wait", "verdict_up", "verdict_down", "pick"])
	assert_int(StoryCatalog.TIMED_LINE_CAP).is_equal(48)


## `texts` is what the catalog was built from: the files at a load, the texts given otherwise; an
## edit's catalog (with_texts) holds its own texts while `loaded` stays the disk's.
func test_the_texts_built_from() -> void:
	var c := StoryCatalog.load_dir(FIXTURE)
	assert_str(str(c.texts["veteran"])).is_equal(FileAccess.get_file_as_string(FIXTURE.path_join("veteran.txt")))
	assert_bool(c.texts.has("doctor")).is_false()  # in the cast, no file
	var edited := c.with_texts({"veteran": "== only\n\nVETERAN: Hm.\n"})
	assert_dict(edited.texts).is_equal({"veteran": "== only\n\nVETERAN: Hm.\n"})
	assert_str(str(edited.loaded["veteran"])).is_equal(str(c.texts["veteran"]))
