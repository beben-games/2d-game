extends GdUnitTestSuite
## StoryScript: the pool format parses to StoryEvents (the plan's reference block verbatim is
## one case), every construct to its field, and each malformed shape gives its error with the
## file and the line, dropping only the event it is in; the flags file. Pure.

## The plan's format reference (docs/plans/2026-10-01-milestone-6.md), verbatim.
const REFERENCE := """# a comment; a comment block directly above "==" belongs to that event
== the_warning                      # the event's name; its id is "<pool>.<name>" (veteran.the_warning)
requires: lanista.after_first_win, doctor.the_wound
unless: veteran.the_goodbye
when: deaths >= 1 and not veteran_distant
priority: high                      # story | high | normal | filler; default normal
repeat                              # or "once", the default
trigger: talk                       # talk (default) | enter <room> | verdict_wait | verdict_up | verdict_down | pick
act: 2                              # optional, 1..3

VETERAN: PLACEHOLDER {wins} nights, and you still walk.
[last_verdict == down] VETERAN: PLACEHOLDER I saw them carry you out.
? PLACEHOLDER Say nothing.
    set: veteran_distant
? PLACEHOLDER "So did you."
    set: veteran_trust
    VETERAN: PLACEHOLDER Hm.
set: veteran_met                    # an unindented effect after the body runs at the event's end
"""


func _parse(text: String, pool := "veteran") -> Dictionary:
	return StoryScript.parse(text, pool)


func _only(text: String, pool := "veteran") -> StoryEvent:
	var parsed := _parse(text, pool)
	assert_array(parsed["errors"]).is_empty()
	assert_int(parsed["events"].size()).is_equal(1)
	return parsed["events"][0]


## The one error the text gives, which names the file and the line.
func _error(text: String, line: int, contains: String) -> void:
	var errors: Array = _parse(text)["errors"]
	assert_int(errors.size()).override_failure_message("errors for:\n%s\n%s" % [text, errors]).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0]).starts_with("veteran.txt:%d: " % line).contains(contains)


func _when(entry: Dictionary) -> String:
	var c: StoryCondition = entry["when"]
	return c.source if c != null else ""


func test_the_reference_block_parses_to_its_event() -> void:
	var e := _only(REFERENCE)
	assert_str(e.pool).is_equal("veteran")
	assert_str(e.name).is_equal("the_warning")
	assert_str(e.id).is_equal("veteran.the_warning")
	assert_int(e.line_number).is_equal(2)
	assert_str(e.comment).is_equal("a comment; a comment block directly above \"==\" belongs to that event")
	assert_array(e.requires).is_equal(["lanista.after_first_win", "doctor.the_wound"])
	assert_array(e.unless).is_equal(["veteran.the_goodbye"])
	assert_str(e.when.source).is_equal("deaths >= 1 and not veteran_distant")
	assert_str(e.priority).is_equal("high")
	assert_bool(e.once).is_false()
	assert_str(e.trigger).is_equal("talk")
	assert_str(e.trigger_arg).is_equal("")
	assert_int(e.act).is_equal(2)
	assert_int(e.body.size()).is_equal(4)
	assert_that(e.body[0]).is_equal({"kind": "line", "speaker": "veteran", "text": "PLACEHOLDER {wins} nights, and you still walk.", "when": null, "line": 11})
	assert_str(e.body[1]["speaker"]).is_equal("veteran")
	assert_str(e.body[1]["text"]).is_equal("PLACEHOLDER I saw them carry you out.")
	assert_str(_when(e.body[1])).is_equal("last_verdict == down")
	assert_that(e.body[2]).is_equal({"kind": "choice", "text": "PLACEHOLDER Say nothing.", "effects": [{"verb": "set", "flag": "veteran_distant", "value": true, "line": 14}], "lines": [], "line": 13})
	var second: Dictionary = e.body[3]
	assert_str(second["kind"]).is_equal("choice")
	assert_str(second["text"]).is_equal("PLACEHOLDER \"So did you.\"")
	assert_array(second["effects"]).is_equal([{"verb": "set", "flag": "veteran_trust", "value": true, "line": 16}])
	assert_array(second["lines"]).is_equal([{"kind": "line", "speaker": "veteran", "text": "PLACEHOLDER Hm.", "when": null, "line": 17}])
	assert_array(e.effects).is_equal([{"verb": "set", "flag": "veteran_met", "value": true, "line": 18}])
	assert_int(e.header_line["requires"]).is_equal(3)
	assert_int(e.header_line["when"]).is_equal(5)


func test_the_defaults_of_a_bare_event() -> void:
	var e := _only("== hello\n\nVETERAN: Hi.\n")
	assert_str(e.priority).is_equal("normal")
	assert_bool(e.once).is_true()
	assert_str(e.trigger).is_equal("talk")
	assert_int(e.act).is_equal(0)
	assert_object(e.when).is_null()
	assert_array(e.requires).is_empty()
	assert_array(e.effects).is_empty()
	assert_str(e.comment).is_empty()


func test_an_event_with_a_header_and_no_body() -> void:
	var e := _only("== quiet_one\npriority: filler\n")
	assert_str(e.priority).is_equal("filler")
	assert_array(e.body).is_empty()


func test_set_takes_an_int_a_bool_or_a_word() -> void:
	var e := _only("== e\n\nset: a\nset: b = 3\nset: c = -2\nset: d = false\nset: f = cold\n")
	var values: Array = []
	for effect: Dictionary in e.effects:
		values.append(effect["value"])
	assert_array(values).is_equal([true, 3, -2, false, "cold"])
	assert_bool(values[1] is int).is_true()


func test_the_triggers_with_and_without_an_argument() -> void:
	assert_str(_only("== e\ntrigger: enter ludus\n").trigger_arg).is_equal("ludus")
	assert_str(_only("== e\ntrigger: enter ludus\n").trigger).is_equal("enter")
	for trigger: String in ["talk", "verdict_wait", "verdict_up", "verdict_down", "pick"]:
		assert_str(_only("== e\ntrigger: %s\n" % trigger).trigger).is_equal(trigger)
	assert_bool(_only("== e\nonce\n").once).is_true()


func test_events_follow_one_another_and_only_an_adjacent_comment_block_belongs() -> void:
	var text := "# the file's header\n\n# first, line one\n# first, line two\n== first\n\nVETERAN: One.\n\n# floating\n\n== second\n\nVETERAN: Two.\n# third's\n== third\n"
	var parsed := _parse(text)
	assert_array(parsed["errors"]).is_empty()
	var events: Array = parsed["events"]
	assert_int(events.size()).is_equal(3)
	assert_str(events[0].comment).is_equal("first, line one\nfirst, line two")
	assert_str(events[1].comment).is_empty()
	assert_str(events[2].comment).is_equal("third's")
	assert_int(events[2].line_number).is_equal(15)
	assert_int(events[0].body.size()).is_equal(1)
	assert_int(events[1].body.size()).is_equal(1)


func test_lines_after_the_choices_and_a_conditioned_line_in_a_choice() -> void:
	var e := _only("== e\n\n? Yes.\n    [met] VETERAN: Good.\nVETERAN: Then.\n")
	assert_int(e.body.size()).is_equal(2)
	assert_str(_when(e.body[0]["lines"][0])).is_equal("met")
	assert_str(e.body[1]["text"]).is_equal("Then.")


## A '#' in a speaker line's text or a choice's text is prose; the inline comments are on the
## `==` line, a header line, and an effect line only; a whole comment line is skipped anywhere.
func test_a_hash_in_a_line_is_prose_and_inline_comments_are_structural() -> void:
	var text := "== e   # the name\npriority: high   # a header\n\nVETERAN: Gate #3 again # still prose\n# a comment inside the body\n    # an indented comment\n? Take #2 # also prose\n    set: met   # an effect\n    VETERAN: Room #4.\nset: done # the end\n"
	var e := _only(text)
	assert_str(e.name).is_equal("e")
	assert_str(e.priority).is_equal("high")
	assert_int(e.body.size()).is_equal(2)
	assert_str(e.body[0]["text"]).is_equal("Gate #3 again # still prose")
	assert_str(e.body[1]["text"]).is_equal("Take #2 # also prose")
	assert_array(e.body[1]["effects"]).is_equal([{"verb": "set", "flag": "met", "value": true, "line": 8}])
	assert_str(e.body[1]["lines"][0]["text"]).is_equal("Room #4.")
	assert_array(e.effects).is_equal([{"verb": "set", "flag": "done", "value": true, "line": 10}])


func test_crlf_line_ends_parse_the_same() -> void:
	var e := _only("== e\r\npriority: high\r\n\r\nVETERAN: Hi.\r\n")
	assert_str(e.priority).is_equal("high")
	assert_str(e.body[0]["text"]).is_equal("Hi.")


# --- malformed shapes: each its error, with the line ---

func test_a_line_outside_an_event() -> void:
	_error("VETERAN: Hi.\n", 1, "outside an event")


func test_a_bad_event_name() -> void:
	_error("==\n", 1, "no name")
	_error("== two words\n", 1, "'two words' is not a name")


func test_an_unknown_header_key() -> void:
	_error("== e\nmood: grim\n", 2, "unknown header key 'mood'")


func test_a_duplicate_header_key() -> void:
	_error("== e\npriority: high\npriority: low\n", 3, "'priority' twice")
	_error("== e\nonce\nrepeat\n", 3, "'repeat' twice")


func test_a_body_line_before_the_blank_line() -> void:
	_error("== e\nVETERAN: Hi.\n", 2, "blank line")


func test_a_header_line_of_no_shape() -> void:
	_error("== e\njust words\n", 2, "not a header line")


func test_an_unknown_priority_trigger_or_room() -> void:
	_error("== e\npriority: urgent\n", 2, "unknown priority 'urgent'")
	_error("== e\ntrigger: shout\n", 2, "unknown trigger 'shout'")
	_error("== e\ntrigger: enter kitchen\n", 2, "unknown room 'kitchen'")
	_error("== e\ntrigger: enter\n", 2, "'enter' needs a room")
	_error("== e\ntrigger: pick ludus\n", 2, "'pick' takes no argument")


func test_an_act_out_of_shape() -> void:
	_error("== e\nact: two\n", 2, "act")
	_error("== e\nact: 4\n", 2, "1 to 3")


func test_a_bad_event_id_in_requires() -> void:
	_error("== e\nrequires: lanista.x, nodot\n", 2, "'nodot' is not an event id")


func test_a_condition_that_does_not_parse() -> void:
	_error("== e\nwhen: deaths >=\n", 2, "when: expected a value")
	_error("== e\n\n[deaths >] VETERAN: Hi.\n", 3, "expected a value")


func test_a_nested_choice() -> void:
	_error("== e\n\n? One.\n    ? Two.\n", 4, "nested")


func test_an_indented_line_outside_a_choice() -> void:
	_error("== e\n\n    VETERAN: Hi.\n", 3, "outside a choice")


func test_an_unknown_effect_verb() -> void:
	_error("== e\n\ngive: sword\n", 3, "unknown effect 'give'")
	_error("== e\n\n? Take it.\n    raise: bond\n", 4, "unknown effect 'raise'")


func test_a_set_of_no_shape() -> void:
	_error("== e\n\nset:\n", 3, "set needs a flag")
	_error("== e\n\nset: a = 3.5\n", 3, "'3.5'")
	_error("== e\n\nset: a b\n", 3, "set")


func test_a_line_after_the_end_effects() -> void:
	_error("== e\n\nset: a\nVETERAN: Late.\n", 4, "after the event's end effects")


func test_a_body_line_of_no_shape() -> void:
	_error("== e\n\njust words\n", 3, "not a body line")


func test_an_event_with_an_error_is_dropped_and_the_others_kept() -> void:
	var parsed := _parse("== bad\nmood: grim\n\n== good\n\nVETERAN: Hi.\n")
	assert_int(parsed["errors"].size()).is_equal(1)
	assert_int(parsed["events"].size()).is_equal(1)
	assert_str(parsed["events"][0].id).is_equal("veteran.good")


# --- the flags file ---

func test_the_flags_file_declares_bools_ints_and_words() -> void:
	var parsed := StoryScript.parse_flags("# story flags\nveteran_distant\n\ncount = 0\nmood = calm   # a word\nseen = true\n")
	assert_array(parsed["errors"]).is_empty()
	assert_that(parsed["flags"]).is_equal({"veteran_distant": false, "count": 0, "mood": "calm", "seen": true})
	assert_int(parsed["lines"]["mood"]).is_equal(5)


func test_the_flags_files_errors() -> void:
	var parsed := StoryScript.parse_flags("a\na = 2\nb c\nd = 1.5\n")
	assert_array(parsed["errors"]).contains_exactly([
		"flags.txt:2: flag 'a' twice",
		"flags.txt:3: 'b c' is not a flag ('name' or 'name = value')",
		"flags.txt:4: '1.5' is not a value (an integer, true, false, or a word)",
	])
	assert_that(parsed["flags"]).is_equal({"a": false})


func test_strip_marker_drops_the_placeholder_marker_only_at_the_start() -> void:
	assert_str(StoryScript.strip_marker("PLACEHOLDER Hm.")).is_equal("Hm.")
	assert_str(StoryScript.strip_marker("Hm. PLACEHOLDER")).is_equal("Hm. PLACEHOLDER")
	assert_str(StoryScript.strip_marker("PLACEHOLDER \"So did you.\"")).is_equal("\"So did you.\"")
