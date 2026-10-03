extends GdUnitTestSuite
## StoryGraph: what the Story tab draws. A node for every event the pools' files hold, loaded or
## not (an event the catalog left out is still a node, with its errors as its badge: the parser's
## event, or a stub with its name and line when the parser dropped it), one node an id, in the
## cast's order and then file order; each catalog error on the event whose block holds its line,
## the rest (the cast, the flags, a line before the first event) loose; the side panel's text; the
## placeholder count; the filters and the search. Pure: inline texts and the fixture story, never
## the shipped prose.

const FIXTURE := "res://tests/support/story"
## `ghost` has no name: a cast error, and no lane.
const CAST := {
	"lanista": {"name": "PLACEHOLDER Lanista"},
	"veteran": {"name": "PLACEHOLDER Veteran"},
	"ghost": {},
}
## A stray line before the first event; `good` loads (its second copy is a duplicate); an unknown
## speaker (a catalog error); an unknown priority (a parse error: the parser drops it); an event
## that requires one that did not load.
const LANISTA := "LANISTA: Stray.\n\n== good\n\nLANISTA: PLACEHOLDER Hm.\n\n== bad_speaker\n\nNOBODY: Hm.\n\n# the next one's comment\n== bad_priority\npriority: urgent\n\nLANISTA: Hm.\n\n== needs_bad\nrequires: lanista.bad_speaker\n\nLANISTA: Hm.\n\n== good\n\nLANISTA: Again.\n"
const VETERAN := "== hello\nact: 2\n\nVETERAN: PLACEHOLDER Hi.\n? PLACEHOLDER Ask.\n    VETERAN: PLACEHOLDER Ask what.\n? Leave the Sand.\n\n== later\nrequires: veteran.hello\n\nVETERAN: Later.\n"


func _broken() -> StoryCatalog:
	return StoryCatalog.from_texts(CAST, "", {"lanista": LANISTA, "veteran": VETERAN})


static func _ids(events: Array[StoryEvent]) -> Array[String]:
	var out: Array[String] = []
	for event in events:
		out.append(event.id)
	return out


func test_a_clean_story_is_its_catalog() -> void:
	var catalog := StoryCatalog.load_dir(FIXTURE)
	assert_array(catalog.errors).is_empty()
	var graph := StoryGraph.of(catalog)
	assert_array(_ids(graph.events)).is_equal(_ids(catalog.events))
	assert_array(graph.pools).is_equal(catalog.cast.keys())
	for event in graph.events:
		assert_bool(graph.is_loaded(event.id)).is_true()
		assert_object(graph.event(event.id)).is_same(catalog.by_id[event.id])
	assert_dict(graph.errors_of).is_empty()
	assert_array(graph.loose_errors).is_empty()


func test_an_event_left_out_is_still_a_node() -> void:
	var graph := StoryGraph.of(_broken())
	assert_array(_ids(graph.events)).is_equal([
		"lanista.good", "lanista.bad_speaker", "lanista.bad_priority", "lanista.needs_bad",
		"veteran.hello", "veteran.later",
	])
	assert_array(graph.pools).is_equal(["lanista", "veteran"])
	assert_bool(graph.is_loaded("lanista.good")).is_true()
	assert_bool(graph.is_loaded("lanista.bad_speaker")).is_false()
	assert_bool(graph.is_loaded("lanista.bad_priority")).is_false()
	assert_bool(graph.is_loaded("lanista.needs_bad")).is_false()
	assert_bool(graph.is_loaded("veteran.hello")).is_true()
	# the parser's event keeps its links; the stub its name and line
	assert_array(graph.event("lanista.needs_bad").requires).is_equal(["lanista.bad_speaker"])
	var stub := graph.event("lanista.bad_priority")
	assert_str(stub.name).is_equal("bad_priority")
	assert_str(stub.pool).is_equal("lanista")
	assert_int(stub.line_number).is_equal(12)


func test_each_error_on_its_event_or_loose() -> void:
	var catalog := _broken()
	var graph := StoryGraph.of(catalog)
	assert_str("\n".join(graph.errors_of["lanista.bad_speaker"])).contains("unknown speaker")
	assert_str("\n".join(graph.errors_of["lanista.bad_priority"])).contains("urgent")
	assert_str("\n".join(graph.errors_of["lanista.needs_bad"])).contains("which did not load")
	assert_str("\n".join(graph.errors_of["lanista.good"])).contains("duplicate")
	assert_bool(graph.errors_of.has("veteran.hello")).is_false()
	var loose := "\n".join(graph.loose_errors)
	assert_str(loose).contains("lanista.txt:1:")
	assert_str(loose).contains("cast.json")
	var placed := graph.loose_errors.size()
	for id: String in graph.errors_of:
		placed += (graph.errors_of[id] as Array).size()
	assert_int(placed).is_equal(catalog.errors.size())


## The targets are worked out once, in the catalog's order: what the error list shows and selects.
func test_an_error_targets_its_event() -> void:
	var catalog := _broken()
	var graph := StoryGraph.of(catalog)
	assert_int(graph.errors.size()).is_equal(catalog.errors.size())
	for i in catalog.errors.size():
		var message := catalog.errors[i]
		var entry: Dictionary = graph.errors[i]
		assert_str(entry["message"]).is_equal(message)
		var target: String = entry["target"]
		if message.begins_with("lanista.txt:1:") or message.begins_with("cast.json"):
			assert_str(target).is_empty()
		else:
			assert_bool(graph.errors_of.has(target)).override_failure_message(message).is_true()
			assert_array(graph.errors_of[target]).contains([message])


## A finding may name its event instead of a line (StoryEdit's errors outside the applied text,
## the lint's later): "<event id>: ...".
func test_a_message_naming_its_event_targets_it() -> void:
	var graph := StoryGraph.of(_broken())
	assert_str(graph.target_of("veteran.later: unknown event 'veteran.gone' in requires")).is_equal("veteran.later")
	assert_str(graph.target_of("lanista.bad_priority: a warning")).is_equal("lanista.bad_priority")
	assert_str(graph.target_of("veteran.txt:9: a line")).is_equal("veteran.later")
	assert_str(graph.target_of("veteran.nothing: no such event")).is_empty()
	assert_str(graph.target_of("flags.txt:2: bad flag")).is_empty()
	assert_str(graph.target_of("cast.json: 'ghost' has no name")).is_empty()
	# a clean story's graph reads the lines too
	var clean := StoryGraph.of(StoryCatalog.load_dir(FIXTURE))
	assert_str(clean.target_of("veteran.txt:17: something")).is_equal("veteran.next_night")


func test_the_left_out_events_links_draw() -> void:
	var graph := StoryGraph.of(_broken())
	var shown: Array[String] = []
	for edge in StoryLinks.requires_edges(graph.events):
		shown.append("%s -> %s" % [edge["from"], edge["to"]])
	assert_array(shown).contains_exactly_in_any_order(["lanista.bad_speaker -> lanista.needs_bad", "veteran.hello -> veteran.later"])


func test_the_text_of_an_event() -> void:
	var catalog := _broken()
	var graph := StoryGraph.of(catalog)
	assert_str(graph.text("veteran.hello")).is_equal(StoryScript.write_event(catalog.by_id["veteran.hello"]))
	# a left-out event's text is its block as written, the next event's comment not in it
	assert_str(graph.text("lanista.bad_speaker")).is_equal("== bad_speaker\n\nNOBODY: Hm.")
	assert_str(graph.text("lanista.bad_priority")).is_equal("== bad_priority\npriority: urgent\n\nLANISTA: Hm.")
	assert_str(graph.text("lanista.nothing")).is_empty()


func test_the_placeholder_count() -> void:
	var graph := StoryGraph.of(_broken())
	# a line, a choice, and a choice's line carry the marker; "Leave the Sand." does not
	assert_int(StoryGraph.placeholder_count(graph.event("veteran.hello"))).is_equal(3)
	assert_int(StoryGraph.placeholder_count(graph.event("veteran.later"))).is_equal(0)
	assert_int(StoryGraph.placeholder_count(graph.event("lanista.good"))).is_equal(1)


func test_the_search_reads_ids_and_text() -> void:
	var graph := StoryGraph.of(_broken())
	var hello := graph.event("veteran.hello")
	assert_bool(StoryGraph.matches(hello, "")).is_true()
	assert_bool(StoryGraph.matches(hello, "veteran.hel")).is_true()
	assert_bool(StoryGraph.matches(hello, "HELLO")).is_true()
	assert_bool(StoryGraph.matches(hello, "ask what")).is_true()  # a choice's line
	assert_bool(StoryGraph.matches(hello, "the sand")).is_true()  # a choice's text
	assert_bool(StoryGraph.matches(hello, "later")).is_false()
	assert_bool(StoryGraph.matches(graph.event("veteran.later"), "Later.")).is_true()


func test_the_filters_by_character_and_act() -> void:
	var graph := StoryGraph.of(_broken())
	var hello := graph.event("veteran.hello")
	var later := graph.event("veteran.later")
	assert_bool(StoryGraph.passes(hello, "", StoryGraph.ANY_ACT, "")).is_true()
	assert_bool(StoryGraph.passes(hello, "veteran", StoryGraph.ANY_ACT, "")).is_true()
	assert_bool(StoryGraph.passes(hello, "lanista", StoryGraph.ANY_ACT, "")).is_false()
	assert_bool(StoryGraph.passes(hello, "", 2, "")).is_true()
	assert_bool(StoryGraph.passes(hello, "", 1, "")).is_false()
	assert_bool(StoryGraph.passes(later, "", 0, "")).is_true()  # no act named
	assert_bool(StoryGraph.passes(later, "", 2, "")).is_false()
	assert_bool(StoryGraph.passes(hello, "veteran", 2, "nothing like it")).is_false()


## A stub (the parser dropped it) says so rather than showing a default's facts, and its text as
## written is searchable.
func test_a_stub_is_not_parsed_and_its_text_is_searched() -> void:
	var graph := StoryGraph.of(_broken())
	assert_bool(graph.is_parsed("lanista.bad_priority")).is_false()
	assert_bool(graph.is_parsed("lanista.bad_speaker")).is_true()
	assert_bool(graph.is_parsed("veteran.hello")).is_true()
	assert_bool(graph.shows("lanista.bad_priority", "", StoryGraph.ANY_ACT, "urgent")).is_true()
	assert_bool(graph.shows("lanista.bad_priority", "veteran", StoryGraph.ANY_ACT, "urgent")).is_false()
	assert_bool(graph.shows("lanista.bad_priority", "", StoryGraph.ANY_ACT, "nothing like it")).is_false()
	# a parsed event's search reads its parsed lines, not the block
	assert_bool(graph.shows("veteran.hello", "", StoryGraph.ANY_ACT, "act: 2")).is_false()


func test_the_badges() -> void:
	var graph := StoryGraph.of(_broken())
	assert_dict(graph.badges("veteran.hello")).is_equal({"placeholders": 3, "errors": 0, "loaded": true, "parsed": true})
	assert_dict(graph.badges("lanista.bad_priority")).is_equal({"placeholders": 0, "errors": 1, "loaded": false, "parsed": false})
	assert_dict(graph.badges("lanista.good")).is_equal({"placeholders": 1, "errors": 1, "loaded": true, "parsed": true})


## An edit's catalog (with_texts) keeps the disk's text as `loaded`; the graph draws the text it
## was built from.
func test_an_edits_catalog_draws_its_own_texts() -> void:
	var start := StoryCatalog.from_texts(CAST, "", {"veteran": VETERAN})
	var edited := start.with_texts({"veteran": VETERAN + "\n== broken\n\nNOBODY: Hm.\n"})
	assert_str(str(edited.loaded["veteran"])).is_equal(VETERAN)
	assert_str(str(edited.texts["veteran"])).contains("== broken")
	var graph := StoryGraph.of(edited)
	assert_array(_ids(graph.events)).is_equal(["veteran.hello", "veteran.later", "veteran.broken"])
	assert_bool(graph.is_loaded("veteran.broken")).is_false()
	assert_str(graph.text("veteran.broken")).is_equal("== broken\n\nNOBODY: Hm.")
