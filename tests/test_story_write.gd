extends GdUnitTestSuite
## StoryScript.write: a pool's events back to text in one canonical form (the header keys in the
## reference block's order, defaults omitted, one blank line between an event's header and its
## body and between events, every comment the parser kept in its place). A file written by hand
## and one saved from the Story tab are the same thing: write(parse(text)) is the text for a
## canonical file, and parse(write(events)) gives equal events for any file. Pure; the shipped
## pools' case reads data/story and asserts their form, never a sentence.

## The plan's format reference, verbatim (test_story_script.gd's).
const _SCRIPT_SUITE := preload("res://tests/test_story_script.gd")

## The reference block written back: its six inline comments dropped (the parser warned of
## them), `trigger: talk` omitted as the default, and the rest as written.
const REFERENCE_CANONICAL := """# a comment; a comment block directly above "==" belongs to that event
== the_warning
requires: lanista.after_first_win, doctor.the_wound
unless: veteran.the_goodbye
when: deaths >= 1 and not veteran_distant
priority: high
repeat
act: 2

VETERAN: PLACEHOLDER {wins} nights, and you still walk.
[last_verdict == down] VETERAN: PLACEHOLDER I saw them carry you out.
? PLACEHOLDER Say nothing.
    set: veteran_distant
? PLACEHOLDER "So did you."
    set: veteran_trust
    VETERAN: PLACEHOLDER Hm.
set: veteran_met
"""

## A file formatted by hand: header keys out of order, the defaults written out, blanks and tabs
## where the canonical form has none or spaces, `#` without its blank, a comment block across a
## blank line, a note among the keys, a comment in the body and one under a choice, `set: x =
## true`, a footer directly under the last line.
const HAND := "#The file's header, no blank after the hash.\n#   indented after the hash\n\n# across a blank, the first event's\n\n==   first\ntrigger:   enter    ludus\n# a note among the keys\nonce\npriority: normal\nwhen:   wins>=1\nrequires: lanista.a ,lanista.b\nact: 1\n\n\nVETERAN :   PLACEHOLDER Spaced out.\n# a body comment\n[ wins >= 2 ]VETERAN: PLACEHOLDER Gated.\n?   PLACEHOLDER A choice.\n\tset: met = true\n\t# under the choice\n\tVETERAN: PLACEHOLDER Tabbed in.\n?PLACEHOLDER Bare.\nset:count=3\n\n\n\n# the second's, directly above\n== second\nrepeat\ntrigger: talk\npriority: filler\n\nVETERAN: PLACEHOLDER Again.\n# the footer"

## HAND in the canonical form. A condition is kept as the writer wrote it (trimmed): the form is
## the layout, never the condition's spelling.
const HAND_CANONICAL := """# The file's header, no blank after the hash.
#   indented after the hash

# across a blank, the first event's
== first
requires: lanista.a, lanista.b
when: wins>=1
trigger: enter ludus
act: 1
# a note among the keys

VETERAN: PLACEHOLDER Spaced out.
# a body comment
[wins >= 2] VETERAN: PLACEHOLDER Gated.
? PLACEHOLDER A choice.
    set: met
    # under the choice
    VETERAN: PLACEHOLDER Tabbed in.
? PLACEHOLDER Bare.
set: count = 3

# the second's, directly above
== second
priority: filler
repeat

VETERAN: PLACEHOLDER Again.

# the footer
"""

const FIXTURES: Array[String] = ["res://tests/support/story", "res://tests/support/story_arrival"]


## The pool's text written back from its parse (its events, its header, its footer).
func _rewrite(text: String, pool := "veteran") -> String:
	var parsed := StoryScript.parse(text, pool)
	assert_array(parsed["errors"]).override_failure_message("errors: %s" % [parsed["errors"]]).is_empty()
	return StoryScript.write(parsed["events"], parsed["header"], parsed["footer"])


## What an event is, without where it was in its file (line numbers): equal shapes are equal
## events. A condition is its source.
static func _shape(event: StoryEvent) -> Dictionary:
	return {
		"pool": event.pool, "name": event.name, "id": event.id,
		"requires": event.requires, "unless": event.unless, "when": _source(event.when),
		"priority": event.priority, "once": event.once, "trigger": event.trigger,
		"trigger_arg": event.trigger_arg, "act": event.act, "comment": event.comment,
		"header_notes": event.header_notes, "body": _entries(event.body), "effects": _entries(event.effects),
	}


static func _entries(entries: Array) -> Array:
	var out := []
	for entry: Dictionary in entries:
		var copy := {}
		for key: String in entry:
			match key:
				"line":
					continue
				"when":
					copy[key] = _source(entry[key])
				"effects", "lines":
					copy[key] = _entries(entry[key])
				_:
					copy[key] = entry[key]
		out.append(copy)
	return out


static func _source(condition: StoryCondition) -> String:
	return condition.source if condition != null else ""


## The parse's events, header, and footer, without line numbers.
func _parsed_shape(text: String, pool := "veteran") -> Dictionary:
	var parsed := StoryScript.parse(text, pool)
	var events := []
	for event: StoryEvent in parsed["events"]:
		events.append(_shape(event))
	return {"events": events, "header": parsed["header"], "footer": parsed["footer"]}


func test_the_reference_block_writes_its_canonical_form() -> void:
	var reference: String = _SCRIPT_SUITE.REFERENCE
	assert_str(_rewrite(reference)).is_equal(REFERENCE_CANONICAL)
	assert_str(_rewrite(REFERENCE_CANONICAL)).is_equal(REFERENCE_CANONICAL)
	assert_array(StoryScript.parse(REFERENCE_CANONICAL, "veteran")["warnings"]).is_empty()
	# only the inline comments went: the event is the same
	assert_that(_parsed_shape(REFERENCE_CANONICAL)).is_equal(_parsed_shape(reference))


## The shipped files are canonical: a save from the Story tab rewrites none of them (this pins
## it). Their form only: no sentence is read.
func test_every_shipped_pool_is_canonical() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	var read := 0
	for id: String in catalog.cast:
		var path := StoryCatalog.DATA_DIR.path_join("%s.txt" % id)
		if not FileAccess.file_exists(path):
			continue
		read += 1
		var text := FileAccess.get_file_as_string(path)
		assert_array(StoryScript.parse(text, id)["warnings"]).override_failure_message("%s: an inline comment" % id).is_empty()
		assert_str(_rewrite(text, id)).override_failure_message("%s.txt is not in the canonical form" % id).is_equal(text)
	assert_int(read).is_greater(0)


func test_a_hand_formatted_file_gives_equal_events_and_canonical_text() -> void:
	assert_array(StoryScript.parse(HAND, "veteran")["warnings"]).is_empty()
	assert_str(_rewrite(HAND)).is_equal(HAND_CANONICAL)
	assert_str(_rewrite(HAND_CANONICAL)).is_equal(HAND_CANONICAL)
	assert_that(_parsed_shape(HAND_CANONICAL)).is_equal(_parsed_shape(HAND))


## parse(write(events)) gives equal events for any file: the fixtures' pools, every construct
## the story suites use, written back and read again.
func test_the_fixtures_round_trip_to_equal_events() -> void:
	for dir in FIXTURES:
		var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(StoryCatalog.CAST_FILE)))
		for id: String in cast:
			var path := dir.path_join("%s.txt" % id)
			if not FileAccess.file_exists(path):
				continue
			var text := FileAccess.get_file_as_string(path)
			var written := _rewrite(text, id)
			assert_that(_parsed_shape(written, id)).override_failure_message("%s: the events changed" % path).is_equal(_parsed_shape(text, id))
			assert_str(_rewrite(written, id)).override_failure_message("%s: the form is not stable" % path).is_equal(written)


func test_the_defaults_are_omitted() -> void:
	var text := "== e\nonce\npriority: normal\ntrigger: talk\n\nVETERAN: Hi.\n"
	assert_str(_rewrite(text)).is_equal("== e\n\nVETERAN: Hi.\n")


func test_the_header_keys_take_the_reference_order() -> void:
	var text := "== e\nact: 3\ntrigger: verdict_up\nrepeat\npriority: story\nwhen: wins > 0\nunless: lanista.b\nrequires: lanista.a\n\nVETERAN: Hi.\n"
	assert_str(_rewrite(text)).is_equal("== e\nrequires: lanista.a\nunless: lanista.b\nwhen: wins > 0\npriority: story\nrepeat\ntrigger: verdict_up\nact: 3\n\nVETERAN: Hi.\n")


func test_a_set_writes_each_kind_of_value() -> void:
	var text := "== e\n\nset: a = true\nset: b = false\nset: n = -2\nset: w = calm\n"
	assert_str(_rewrite(text)).is_equal("== e\n\nset: a\nset: b = false\nset: n = -2\nset: w = calm\n")


func test_an_event_with_a_header_and_no_body() -> void:
	var text := "== first\nrepeat\n\n== bare\n\n== noted\n# a note\n\n== last\n\nVETERAN: Hi.\n"
	assert_str(_rewrite(text)).is_equal(text)
	assert_that(_parsed_shape(text)["events"].size()).is_equal(4)


func test_a_files_header_and_footer_alone() -> void:
	assert_str(_rewrite("# only a header\n")).is_equal("# only a header\n")
	assert_str(_rewrite("# header\n\n# footer\n")).is_equal("# header\n\n# footer\n")
	assert_str(_rewrite("")).is_equal("")
	assert_str(StoryScript.write([], "", "")).is_equal("")


## An empty comment line is written "#" (no trailing blank); blanks after the one the parser
## takes are kept.
func test_an_empty_comment_line_and_leading_blanks() -> void:
	var text := "# header\n#\n#   indented\n\n# one\n#\n# two\n== e\n\nVETERAN: Hi.\n#\n#  footer\n"
	var written := _rewrite(text)
	assert_str(written).is_equal("# header\n#\n#   indented\n\n# one\n#\n# two\n== e\n\nVETERAN: Hi.\n\n#\n#  footer\n")
	assert_that(_parsed_shape(written)).is_equal(_parsed_shape(text))


## The moves the writing brief names: a comment at the end of a body becomes the next event's
## comment, one between two end effects moves before both, an unindented one between a choice and
## its indented lines moves below them, and an indented one above a choice's effect moves below
## the choice's effects (Task 11's review). Nothing is lost. A pool's footer becomes its header
## once its last event is gone (a file of comments alone is its header).
func test_the_comments_a_rewrite_moves() -> void:
	var text := "== a\n\nVETERAN: One.\n# the end of a's body\n== b\n\n? Choose.\n# between a choice and its lines\n    VETERAN: Under.\nVETERAN: After.\nset: x\n# between the effects\nset: y\n"
	var written := _rewrite(text)
	assert_str(written).is_equal("== a\n\nVETERAN: One.\n\n# the end of a's body\n== b\n\n? Choose.\n    VETERAN: Under.\n# between a choice and its lines\nVETERAN: After.\n# between the effects\nset: x\nset: y\n")
	assert_that(_parsed_shape(written)).is_equal(_parsed_shape(text))
	var above_an_effect := "== c\n\n? Nod.\n    VETERAN: Good.\n    # above the effect\n    set: x\nVETERAN: After.\n"
	assert_str(_rewrite(above_an_effect)).is_equal("== c\n\n? Nod.\n    set: x\n    VETERAN: Good.\n    # above the effect\nVETERAN: After.\n")
	var footer_alone := StoryScript.write([], "", "the footer")
	assert_str(StoryScript.parse(footer_alone, "veteran")["header"]).is_equal("the footer")


func test_write_event_is_one_events_block() -> void:
	var event: StoryEvent = StoryScript.parse(REFERENCE_CANONICAL, "veteran")["events"][0]
	assert_str(StoryScript.write_event(event)).is_equal(REFERENCE_CANONICAL.trim_suffix("\n"))


# --- the writer's output is a fixed point: parse(write(parse(t))) is parse(t) for any text ---

## The text's parse written and parsed again gives equal events, header, and footer, and the
## written text is stable under a second rewrite. Returns the first parse's shape.
func _fixed_point(text: String) -> Dictionary:
	var first := StoryScript.parse(text, "veteran")
	var written := StoryScript.write(first["events"], first["header"], first["footer"])
	var shape := _parsed_shape(text)
	assert_that(_parsed_shape(written)).override_failure_message("not a fixed point:\n%s\n--- written:\n%s" % [text, written]).is_equal(shape)
	assert_str(_rewrite(written)).override_failure_message("the form is not stable:\n%s" % written).is_equal(written)
	return shape


## An indented comment directly above a choice's indented effect is written below the effects
## (the effects come first under a choice): last in the event, the parser already places it
## where a rewrite reads it, the next event's comment or the file's footer.
func test_an_indented_comment_above_a_choices_effect_keeps_its_place() -> void:
	var last := "== a\n\n? Nod.\n    VETERAN: Good.\n    # remember this\n    set: met\n"
	assert_str(_fixed_point(last)["footer"]).is_equal("remember this")
	var middle := last + "\n== b\n\nVETERAN: B.\n"
	var shape := _fixed_point(middle)
	assert_str(shape["events"][1]["comment"]).is_equal("remember this")
	assert_str(shape["footer"]).is_empty()
	# with more of the body after the choice, it stays under the choice
	var inside := _fixed_point("== a\n\n? Nod.\n    VETERAN: Good.\n    # remember this\n    set: met\nVETERAN: After.\n")
	assert_that(inside["events"][0]["body"][0]["lines"][1]).is_equal({"kind": "comment", "text": "remember this"})


## An unindented comment between a choice's indented lines is written after the choice.
func test_an_unindented_comment_between_a_choices_lines_keeps_its_place() -> void:
	var last := "== a\n\n? Nod.\n    VETERAN: One.\n# between\n    VETERAN: Two.\n"
	assert_str(_fixed_point(last)["footer"]).is_equal("between")
	var shape := _fixed_point(last + "\n# b's own\n== b\n\nVETERAN: B.\n")
	assert_str(shape["events"][1]["comment"]).is_equal("between\nb's own")
	assert_str(_fixed_point("== a\n\n? Nod.\n    VETERAN: One.\n# between\n    VETERAN: Two.\n# the footer\n")["footer"]).is_equal("between\nthe footer")


## The end of the file is a blank line: a file without its last newline parses as one with it.
func test_a_file_without_its_last_newline() -> void:
	assert_str(_fixed_point("# only a header")["header"]).is_equal("only a header")
	assert_array(_fixed_point("== a\n# a note")["events"][0]["header_notes"]).is_equal(["a note"])
	assert_str(_fixed_point("# header\n\n# footer")["footer"]).is_equal("footer")


func test_hand_formatted_texts_are_fixed_points() -> void:
	var texts: Array[String] = [
		HAND, _SCRIPT_SUITE.REFERENCE,
		"== a\n\n? One.\n    # under, before an effect\n    set: met\n    # between effects\n    set: count = 2\n? Two.\n# after, unindented\n    set: met\n",
		"== a\n\n? One.\n    set: met\n    # trailing, indented\n\n\n# across blanks\n\n== b\n# note\n\n    # indented, no choice\nVETERAN: Hi.\n# before the effect\nset: met\n# trailing after the effect\n",
		"# h1\n#\n#  h2\n\n#\n\n== a\nrepeat\n# n1\n#\n\n? x\n    ? nested is an error\n== b\n\nVETERAN: B.\n    # indented after a line, no choice open",
		"\n\n\n== a\n\n\n\nVETERAN: Spaced.\n\n\n\n# f1\n\n\n#f2",
		"== a\n\n? x\n    VETERAN: one\n# c1\n? y\n# c2\n    VETERAN: two\n# c3\n",
	]
	for text in texts:
		_fixed_point(text)


## A '#' in a speaker line's text or a choice's text is prose, and the writer keeps it.
func test_a_hash_in_prose_goes_through_the_writer() -> void:
	var text := "== e\n\nVETERAN: Gate #3 again # still prose\n? Take #2 # also prose\n    VETERAN: Room #4.\n"
	assert_str(_rewrite(text)).is_equal(text)
	_fixed_point(text)
