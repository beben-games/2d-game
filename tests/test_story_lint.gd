extends GdUnitTestSuite
## StoryLint: the warnings on a story that loads (each from a story written here, never the
## shipped prose), the flag map's two sides, the placeholder count, and the word list's parse. A
## clean story gives no warning. Pure: StoryCatalog.from_texts and the game's data handed in.

const CAST := {
	"lanista": {"name": "Lanista"},
	"veteran": {"name": "Veteran"},
	"narrator": {"timed": true},
	"crowd": {"timed": true},
}
## Plain entries match anywhere; a `key:` entry only in an instruction frame (StoryLint.KEY_FRAMES).
const WORDS: Array[String] = ["menu", "level up", "key: e", "key: space", "key: enter", "key: kp enter", "key: shift", "key: mouse"]
const GAME := {"merchants": ["lanista"], "enemies": ["boss", "chaser"]}
## The crowd's pool answering the pick in every band and loss: a line per band, none reading the loss.
const CROWD := "== boo\nwhen: round_band == boo\nrepeat\ntrigger: pick\n\nCROWD: Boo at {round_band}.\n\n== quiet\nwhen: round_band == quiet\nrepeat\ntrigger: pick\n\nCROWD: Hm.\n\n== cheer\nwhen: round_band == cheer or round_band == roar\nrepeat\ntrigger: pick\n\nCROWD: Yes.\n"
## Every check passed: a flag set in a choice and read; the verdict, an entry, and an entry read by
## its arrival; the killer an enemy; a word near a listed one but not it.
const CLEAN := {
	"lanista": "== arrival\npriority: story\ntrigger: enter ludus\n\nLANISTA: Pressed for time.\n\n== hello\n\nLANISTA: PLACEHOLDER Well?\n? Yes.\n    set: met\n? No.\n",
	"veteran": "== later\nrequires: lanista.hello\nwhen: met and last_killer == boss\n\nVETERAN: Later.\n\n== bark\npriority: filler\nrepeat\n\nVETERAN: Hm.\n",
	"narrator": "== up\nrepeat\ntrigger: verdict_up\n\nNARRATOR: Up at {run_band}.\n\n== wake\nwhen: arrival == gate\nrepeat\ntrigger: enter spoliarium\n\nNARRATOR: Awake.\n",
}


func _catalog(pools: Dictionary, flags := "met\n") -> StoryCatalog:
	var texts := {"crowd": CROWD}
	texts.merge(pools, true)
	var catalog := StoryCatalog.from_texts(CAST, flags, texts)
	assert_array(catalog.errors).is_empty()
	return catalog


func _lint(pools: Dictionary, flags := "met\n", words := WORDS, game := GAME) -> Dictionary:
	return StoryLint.run(_catalog(pools, flags), words, game)


## The warnings of one kind, as {event: message} in order.
func _of(result: Dictionary, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for warning: Dictionary in result["warnings"]:
		if warning["kind"] == kind:
			out.append(warning)
	return out


func _events(warnings: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for warning in warnings:
		out.append(warning["event"])
	return out


func _messages(result: Dictionary) -> String:
	var out: PackedStringArray = []
	for warning: Dictionary in result["warnings"]:
		out.append(warning["message"])
	return "\n".join(out)


func test_a_clean_story_has_no_warning() -> void:
	var result := _lint(CLEAN)
	assert_array(result["warnings"]).override_failure_message(_messages(result)).is_empty()
	assert_array(result["errors"]).is_empty()


func test_the_errors_are_the_catalogs() -> void:
	var catalog := StoryCatalog.from_texts(CAST, "", {"lanista": "== bad\n\nNOBODY: Hm.\n"})
	assert_array(catalog.errors).is_not_empty()
	assert_array(StoryLint.run(catalog, WORDS, GAME)["errors"]).is_equal(catalog.errors)


## An event that requires what it also excludes never plays, nor one that requires it.
func test_an_event_that_requires_what_it_excludes_never_plays() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== torn\nrequires: lanista.hello\nunless: lanista.hello\n\nVETERAN: Torn.\n\n== after\nrequires: veteran.torn\n\nVETERAN: After.\n\n== after_after\nrequires: veteran.after\n\nVETERAN: And after.\n"
	var found := _of(_lint(pools), StoryLint.NEVER_FIRES)
	assert_array(_events(found)).is_equal(["veteran.torn", "veteran.after", "veteran.after_after"])
	assert_str(found[0]["message"]).is_equal("veteran.torn: never plays: it requires lanista.hello and has it in its unless")
	assert_str(found[1]["message"]).is_equal("veteran.after: never plays: it requires veteran.torn, which never plays")


## An event at a trigger its pool is never asked at never plays (StoryExplain's table), nor one
## that requires it.
func test_an_event_its_pool_is_never_asked_at_never_plays() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== at_the_thumb\nrepeat\ntrigger: verdict_up\n\nVETERAN: Up.\n"
	pools["narrator"] = CLEAN["narrator"] + "\n== chat\n\nNARRATOR: Hello.\n\n== chat_again\nrequires: narrator.chat\n\nNARRATOR: Again.\n"
	var result := _lint(pools)
	var asked := _of(result, StoryLint.NEVER_ASKED)
	assert_array(_events(asked)).is_equal(["veteran.at_the_thumb", "narrator.chat", "narrator.chat_again"])
	assert_str(asked[0]["message"]).is_equal("veteran.at_the_thumb: never plays: the game asks only narrator at verdict_up")
	assert_str(asked[1]["message"]).is_equal("narrator.chat: never plays: the game never talks to narrator")
	# chat_again is not asked either; its requires adds nothing more
	assert_array(_of(result, StoryLint.NEVER_FIRES)).is_empty()


func test_a_flag_set_and_never_read_or_read_and_never_set() -> void:
	var pools := CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"] + "\n== nod\n\nLANISTA: Nod.\nset: nodded\nset: mood = cold\n"
	pools["veteran"] = CLEAN["veteran"] + "\n== waiting\nwhen: trusted\n\nVETERAN: Waiting.\n"
	var result := _lint(pools, "met\nnodded\ntrusted\nmood = calm\nunused = 0\n")
	var unread := _of(result, StoryLint.FLAG_UNREAD)
	assert_array(_events(unread)).is_equal(["lanista.nod", "lanista.nod"])
	assert_str(unread[0]["message"]).is_equal("lanista.nod: sets nodded, which nothing reads")
	var unset := _of(result, StoryLint.FLAG_UNSET)
	assert_array(_events(unset)).is_equal(["veteran.waiting"])
	assert_str(unset[0]["message"]).is_equal("veteran.txt:14: reads trusted, which nothing sets (it is always false)")
	var unused := _of(result, StoryLint.FLAG_UNUSED)
	assert_array(_events(unused)).is_equal([""])
	assert_str(unused[0]["message"]).is_equal("flags.txt: unused is declared, and nothing sets or reads it")


## A flag read only outside the story (a door's condition, handed in) is read.
func test_a_flag_read_by_a_door_is_read() -> void:
	var pools := CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"] + "\n== nod\n\nLANISTA: Nod.\nset: nodded\n"
	var game := GAME.duplicate()
	game["reads"] = {"door ludus -> hypogeum": ["nodded", "wins"]}
	var result := _lint(pools, "met\nnodded\n", WORDS, game)
	assert_array(_of(result, StoryLint.FLAG_UNREAD)).is_empty()
	assert_array((result["flag_map"] as Dictionary)["nodded"]["read"]).is_equal(["door ludus -> hypogeum"])


## Every declared flag, in order, with the events that set it (a choice's effect, an end effect)
## and those that read it (a when, a line's condition, a substitution), each once.
func test_the_flag_map_lists_both_sides() -> void:
	var pools := CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"] + "\n== again\n\nLANISTA: Again.\nset: met\nset: count = 2\n"
	pools["veteran"] = CLEAN["veteran"] + "\n== counted\n\n[met] VETERAN: {count} times.\n? {count}?\n"
	var map: Dictionary = _lint(pools, "met\ncount = 0\nidle\n")["flag_map"]
	assert_array(map.keys()).is_equal(["met", "count", "idle"])
	assert_array(map["met"]["set"]).is_equal(["lanista.hello", "lanista.again"])
	assert_array(map["met"]["read"]).is_equal(["veteran.later", "veteran.counted"])
	assert_array(map["count"]["set"]).is_equal(["lanista.again"])
	assert_array(map["count"]["read"]).is_equal(["veteran.counted"])
	assert_array(map["idle"]["set"]).is_empty()
	assert_array(map["idle"]["read"]).is_empty()


## A listed word in a line or a choice. A plain entry: whole words (a letter of any script is a
## word's), any case, a phrase's blank any run of blanks. A `key:` entry: only in an instruction
## frame ("press E", "the E key", "use the mouse to"). The marker and a {substitution} are not the
## line's prose.
func test_a_line_with_a_listed_word() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== keys\n\nVETERAN: Enter. Here is the key to the gate.\nVETERAN: Save your strength. Press forward. A shift of guards on level ground.\nVETERAN: Space, and the mouse, and E alone. The \u00e9menu, menu\u00e0, fianc\u00e9e.\nVETERAN: {menu} times, and {menu}.\nVETERAN: PLACEHOLDER Press E. The E key. Hit Space to dodge.\nVETERAN: Use the mouse to aim. Open the menu. Level up. Hit Kp  Enter.\n? Press e.\n"
	var found := _of(_lint(pools, "met\nmenu = 0\n"), StoryLint.WORD)
	var messages: Array[String] = []
	for warning in found:
		assert_str(warning["event"]).is_equal("veteran.keys")
		messages.append(warning["message"])
	assert_array(messages).is_equal([
		"veteran.txt:19: says 'Press E', a key's name on the lint list",
		"veteran.txt:19: says 'E key', a key's name on the lint list",
		"veteran.txt:19: says 'Hit Space', a key's name on the lint list",
		"veteran.txt:20: says 'Use the mouse to', a key's name on the lint list",
		"veteran.txt:20: says 'menu', a word on the lint list",
		"veteran.txt:20: says 'Level up', a word on the lint list",
		"veteran.txt:20: says 'Hit Kp  Enter', a key's name on the lint list",
		"veteran.txt:21: says 'Press e', a key's name on the lint list",
	])
	assert_array(_of(_lint(pools, "met\nmenu = 0\n", [] as Array[String]), StoryLint.WORD)).is_empty()


## A `key:` entry never matches outside a frame, whatever the line; every frame matches every key.
func test_a_key_entry_matches_only_in_a_frame() -> void:
	var pattern := StoryLint.word_pattern(["key: tab", "key: escape"] as Array[String])
	for text: String in ["Tab.", "The escape was close.", "A tab of wine, the escape hatch.", "Press on to the tab", "Use the tab"]:
		assert_array(pattern.search_all(text)).override_failure_message(text).is_empty()
	for text: String in ["Press tab.", "Hit the Escape.", "tap TAB", "Hold escape", "push the tab", "click tab", "The Tab key", "the escape button", "use tab to", "with the escape to"]:
		assert_array(pattern.search_all(text)).override_failure_message(text).has_size(1)


## Two `enter <room>` events in different pools must shut each other out; a pool's own two need not.
func test_two_entry_events_in_different_pools_must_shut_each_other_out() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== there\ntrigger: enter ludus\n\nVETERAN: There.\n"
	var found := _of(_lint(pools), StoryLint.ENTER_CLASH)
	assert_array(_events(found)).is_equal(["veteran.there"])
	assert_str(found[0]["message"]).is_equal("veteran.there: enter ludus, as lanista.arrival is: without each in the other's unless, one plays on an arrival and the other on a later one")
	pools["veteran"] = CLEAN["veteran"] + "\n== there\nunless: lanista.arrival\ntrigger: enter ludus\n\nVETERAN: There.\n"
	assert_array(_of(_lint(pools), StoryLint.ENTER_CLASH)).has_size(1)
	pools["lanista"] = CLEAN["lanista"].replace("priority: story\n", "unless: veteran.there\npriority: story\n")
	assert_array(_of(_lint(pools), StoryLint.ENTER_CLASH)).is_empty()
	pools = CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"] + "\n== again\ntrigger: enter ludus\n\nLANISTA: Again.\n"
	assert_array(_of(_lint(pools), StoryLint.ENTER_CLASH)).is_empty()
	# arrivals that can never meet never clash; overlapping or unknown ones do
	pools = CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"].replace("priority: story\n", "when: arrival == start\npriority: story\n")
	for when: String in ["arrival == gate", "arrival == door and wins >= 1"]:
		pools["veteran"] = CLEAN["veteran"] + "\n== there\nwhen: %s\ntrigger: enter ludus\n\nVETERAN: There.\n" % when
		assert_array(_of(_lint(pools), StoryLint.ENTER_CLASH)).override_failure_message(when).is_empty()
	for when: String in ["arrival != gate", "arrival == gate or wins > 1"]:
		pools["veteran"] = CLEAN["veteran"] + "\n== there\nwhen: %s\ntrigger: enter ludus\n\nVETERAN: There.\n" % when
		assert_array(_of(_lint(pools), StoryLint.ENTER_CLASH)).override_failure_message(when).has_size(1)


## A repeat entry plays on every arrival, door walks included, unless its when provably fails at a
## door (StoryCondition.words_held: the arrivals it can hold at leave out door).
func test_a_repeat_entry_event() -> void:
	var pools := CLEAN.duplicate()
	pools["narrator"] = CLEAN["narrator"] + "\n== always\nrepeat\ntrigger: enter hypogeum\n\nNARRATOR: Again.\n\n== not_at_the_gate\nwhen: arrival != gate\nrepeat\ntrigger: enter sanitarium\n\nNARRATOR: Again.\n\n== door_and_wins\nwhen: arrival == door and wins >= 1\nrepeat\ntrigger: enter armamentarium\n\nNARRATOR: Again.\n\n== gate_or_late_door\nwhen: arrival == gate or (arrival == door and runs > 2)\nrepeat\ntrigger: enter armamentarium\n\nNARRATOR: Again.\n\n== not_at_a_door\nwhen: arrival != door and wins >= 1\nrepeat\ntrigger: enter hypogeum\n\nNARRATOR: Again.\n"
	var found := _of(_lint(pools), StoryLint.ENTER_REPEAT)
	assert_array(_events(found)).is_equal(["narrator.always", "narrator.not_at_the_gate", "narrator.door_and_wins", "narrator.gate_or_late_door"])
	assert_str(found[0]["message"]).is_equal("narrator.always: repeat on enter hypogeum: it plays on every arrival there, door walks included")


## A station's keeper with nothing new opens the panel: their talk filler never plays.
func test_a_merchants_filler() -> void:
	var pools := CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"] + "\n== bark\npriority: filler\nrepeat\n\nLANISTA: Hm.\n"
	var found := _of(_lint(pools), StoryLint.MERCHANT_FILLER)
	assert_array(_events(found)).is_equal(["lanista.bark"])
	assert_str(found[0]["message"]).is_equal("lanista.bark: never plays: lanista keeps a station, which opens its panel when they have nothing new")
	var game := GAME.duplicate()
	game["merchants"] = []
	assert_array(_of(_lint(pools, "met\n", WORDS, game), StoryLint.MERCHANT_FILLER)).is_empty()


## A timed event shows its first shown line: a line after one with no condition never shows.
func test_a_timed_event_with_a_line_that_never_shows() -> void:
	var pools := CLEAN.duplicate()
	pools["narrator"] = CLEAN["narrator"] + "\n== two\nrepeat\ntrigger: verdict_down\n\nNARRATOR: First.\nNARRATOR: Never.\n\n== either\nrepeat\ntrigger: verdict_down\n\n[run_band == boo] NARRATOR: Boo.\nNARRATOR: Else.\n"
	var found := _of(_lint(pools), StoryLint.TIMED_LINES)
	assert_array(_events(found)).is_equal(["narrator.two"])
	assert_str(found[0]["message"]).is_equal("narrator.txt:19: never shown: a timed event shows only its first shown line, and the line at 18 always shows")


## The crowd's pool answers the pick in every band and loss by an event that always plays there:
## repeat, no requires or unless, a when reading only the pick's facts.
func test_the_crowd_answers_every_pick() -> void:
	var texts := {"crowd": CROWD.replace("when: round_band == quiet\n", "when: round_band == quiet and round_loss != none\n")}
	texts.merge(CLEAN)
	var catalog := StoryCatalog.from_texts(CAST, "met\n", texts)
	var found := _of(StoryLint.run(catalog, WORDS, GAME), StoryLint.PICK_UNANSWERED)
	assert_array(_events(found)).is_equal([""])
	assert_str(found[0]["message"]).is_equal("crowd.txt: nothing always answers the pick at round_band == quiet and round_loss == none")
	# a once event, one with a requires, and one reading more than the pick's facts answer nothing for sure
	texts["crowd"] = "== once\nwhen: round_band == boo\ntrigger: pick\n\nCROWD: Once.\n\n== gated\nrequires: crowd.once\nrepeat\ntrigger: pick\n\nCROWD: Gated.\n\n== wins\nwhen: wins == 0\nrepeat\ntrigger: pick\n\nCROWD: Wins.\n"
	found = _of(StoryLint.run(StoryCatalog.from_texts(CAST, "met\n", texts), WORDS, GAME), StoryLint.PICK_UNANSWERED)
	assert_array(_events(found)).is_equal([""])
	assert_str(found[0]["message"]).is_equal("crowd.txt: nothing always answers the pick, in any band or loss")
	# an event answers a case only with a line shown there: a line with no condition, or one reading
	# only the pick's facts that holds
	texts["crowd"] = CROWD.replace("CROWD: Boo at {round_band}.\n", "[round_loss == hit] CROWD: Boo at {round_band}.\n[wins >= 1] CROWD: Boo again.\n")
	found = _of(StoryLint.run(StoryCatalog.from_texts(CAST, "met\n", texts), WORDS, GAME), StoryLint.PICK_UNANSWERED)
	var messages: Array[String] = []
	for warning in found:
		messages.append(warning["message"])
	assert_array(messages).is_equal([
		"crowd.txt: nothing always answers the pick at round_band == boo and round_loss == fled",
		"crowd.txt: nothing always answers the pick at round_band == boo and round_loss == slow",
		"crowd.txt: nothing always answers the pick at round_band == boo and round_loss == none",
	])
	# no crowd in the cast, nothing to check
	var cast := CAST.duplicate()
	cast.erase("crowd")
	texts.erase("crowd")
	assert_array(_of(StoryLint.run(StoryCatalog.from_texts(cast, "met\n", texts), WORDS, GAME), StoryLint.PICK_UNANSWERED)).is_empty()


func test_the_catalogs_warnings_are_surfaced() -> void:
	var pools := CLEAN.duplicate()
	pools["lanista"] = CLEAN["lanista"].replace("    set: met\n", "    set: met   # why\n")
	var catalog := _catalog(pools)
	assert_array(catalog.warnings).has_size(1)
	var found := _of(StoryLint.run(catalog, WORDS, GAME), StoryLint.PARSE)
	assert_array(_events(found)).is_equal(["lanista.hello"])
	assert_str(found[0]["message"]).is_equal(catalog.warnings[0])


## last_killer read against a word that is no enemy's id; none is a word too.
func test_last_killer_is_checked_against_the_enemy_ids() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== killed\nwhen: last_killer == chasr or last_killer == none\n\n[last_killer != bos] VETERAN: Killed.\n"
	var found := _of(_lint(pools), StoryLint.KILLER)
	assert_array(_events(found)).is_equal(["veteran.killed", "veteran.killed"])
	assert_str(found[0]["message"]).is_equal("veteran.txt:14: last_killer is compared with chasr, which is no enemy's id (boss, chaser)")
	assert_str(found[1]["message"]).contains("veteran.txt:16: last_killer is compared with bos")
	var game := GAME.duplicate()
	game.erase("enemies")
	assert_array(_of(_lint(pools, "met\n", WORDS, game), StoryLint.KILLER)).is_empty()


## A moment's fact read where the game never hands it in: none there, always.
func test_a_moment_fact_read_outside_its_moment() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== woke\nwhen: arrival == gate\n\n[round_band == boo] VETERAN: At {run_band}.\n"
	var found := _of(_lint(pools), StoryLint.MOMENT_FACT)
	assert_array(_events(found)).is_equal(["veteran.woke", "veteran.woke", "veteran.woke"])
	assert_str(found[0]["message"]).is_equal("veteran.txt:14: reads arrival, which the game hands in only at enter: at talk it is none")
	assert_str(found[1]["message"]).is_equal("veteran.txt:16: reads round_band, which the game hands in only at pick: at talk it is none")
	assert_str(found[2]["message"]).contains("reads run_band, which the game hands in only at verdict_wait, verdict_up, verdict_down")


## The lines and choices still marked, of all the lines and choices.
func test_the_placeholder_count() -> void:
	var result := _lint(CLEAN)
	assert_int(result["placeholders"]).is_equal(1)
	assert_int(result["texts"]).is_equal(11)
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== marked\n\nVETERAN: PLACEHOLDER One.\n? PLACEHOLDER Two.\n    VETERAN: PLACEHOLDER Three.\n"
	result = _lint(pools)
	assert_int(result["placeholders"]).is_equal(4)
	assert_int(result["texts"]).is_equal(14)


## Every finding on an event names it, and its message's head places it on that event as the
## Story tab's error list does (StoryGraph.target_of).
func test_each_finding_is_placed_on_its_event() -> void:
	var pools := CLEAN.duplicate()
	pools["veteran"] = CLEAN["veteran"] + "\n== torn\nrequires: lanista.hello\nunless: lanista.hello\nwhen: arrival == gate and last_killer == chasr and trusted\n\nVETERAN: Press E.\nVETERAN: More.\nset: nodded\n"
	pools["lanista"] = CLEAN["lanista"] + "\n== bark\npriority: filler\nrepeat\n\nLANISTA: Hm.\n\n== there\nrepeat\ntrigger: enter hypogeum\n\nLANISTA: There.\n"
	var catalog := _catalog(pools, "met\nnodded\ntrusted\n")
	var graph := StoryGraph.of(catalog)
	var result := StoryLint.run(catalog, WORDS, GAME)
	var kinds := {}
	for warning: Dictionary in result["warnings"]:
		kinds[warning["kind"]] = true
		if warning["event"] != "":
			assert_str(graph.target_of(warning["message"])).override_failure_message(warning["message"]).is_equal(warning["event"])
	assert_array(kinds.keys()).contains([StoryLint.NEVER_FIRES, StoryLint.MOMENT_FACT, StoryLint.KILLER, StoryLint.FLAG_UNSET, StoryLint.FLAG_UNREAD, StoryLint.WORD, StoryLint.MERCHANT_FILLER, StoryLint.ENTER_REPEAT])


## The word list: one entry a line, `#` to the end of a line a comment, blanks ignored, lower case,
## each once.
func test_the_word_list_parses() -> void:
	var words := StoryLint.parse_words("# a comment\nPress\n\n  click   # the mouse\nkp  enter\npress\nKEY:   Kp  Enter\nkey:e\n")
	assert_array(words).is_equal(["press", "click", "kp enter", "key: kp enter", "key: e"])


## With errors in the story the flag rules wait (an event that did not load may set or read a flag):
## no flag warning, and the result says so; the map is still drawn.
func test_the_flag_rules_wait_for_a_story_without_errors() -> void:
	var texts := {"crowd": CROWD, "lanista": CLEAN["lanista"] + "\n== nod\n\nLANISTA: Nod.\nset: nodded\n\n== bad\n\nNOBODY: Hm.\n"}
	var catalog := StoryCatalog.from_texts(CAST, "met\nnodded\n", texts)
	assert_array(catalog.errors).is_not_empty()
	var result := StoryLint.run(catalog, WORDS, GAME)
	assert_bool(result["flags_checked"]).is_false()
	for kind: String in [StoryLint.FLAG_UNREAD, StoryLint.FLAG_UNSET, StoryLint.FLAG_UNUSED]:
		assert_array(_of(result, kind)).is_empty()
	assert_array((result["flag_map"] as Dictionary)["nodded"]["set"]).is_equal(["lanista.nod"])
	assert_bool(_lint(CLEAN)["flags_checked"]).is_true()
