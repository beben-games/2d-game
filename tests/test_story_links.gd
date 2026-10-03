extends GdUnitTestSuite
## StoryLinks: the Story tab's three kinds of edge. A `requires` runs from the prerequisite to the
## event that names it, an `unless` from the excluding event to the one it shuts, both as
## StoryEdit's add_requires and add_unless take them (from, to: `to` names `from`); a flag link runs
## from an event whose effects set a flag (its end effects or a choice's) to an event whose `when`
## reads it, one edge a pair with every flag it carries, never an event to itself. Pure: the fixture
## story (tests/support/story) and inline texts, never the shipped prose.

const FIXTURE := "res://tests/support/story"
const CAST := {
	"lanista": {"name": "PLACEHOLDER Lanista"},
	"veteran": {"name": "PLACEHOLDER Veteran"},
}
const FLAGS := "met\ntrust\ncount = 0\nmood = calm\nother = calm\n"


func _fixture() -> Array[StoryEvent]:
	var catalog := StoryCatalog.load_dir(FIXTURE)
	assert_array(catalog.errors).is_empty()
	return catalog.events


## Each edge as "<from> -> <to>" (plus " [flags]" for a flag link), sorted.
static func _shown(edges: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for edge in edges:
		var flags: Array = edge["flags"]
		out.append("%s -> %s%s" % [edge["from"], edge["to"], " %s" % [flags] if not flags.is_empty() else ""])
	out.sort()
	return out


func test_requires_edges_from_the_fixture() -> void:
	var edges := StoryLinks.requires_edges(_fixture())
	for edge in edges:
		assert_str(edge["kind"]).is_equal(StoryLinks.REQUIRES)
	assert_array(_shown(edges)).is_equal([
		"lanista.first_word -> lanista.after_first_win",
		"lanista.first_word -> veteran.the_warning",
		"veteran.hello -> veteran.next_night",
		"veteran.the_warning -> veteran.the_goodbye",
	])


func test_unless_edges_from_the_fixture() -> void:
	var edges := StoryLinks.unless_edges(_fixture())
	assert_int(edges.size()).is_equal(1)
	assert_str(edges[0]["kind"]).is_equal(StoryLinks.UNLESS)
	assert_array(_shown(edges)).is_equal(["veteran.the_goodbye -> veteran.the_warning"])


## veteran.hello sets both flags in its choices; the_warning sets them too (in its choices) and
## reads veteran_distant, so its own setting is no edge; the_goodbye reads veteran_trust.
func test_a_flag_set_in_a_choice_links_too() -> void:
	var edges := StoryLinks.flag_edges(_fixture())
	for edge in edges:
		assert_str(edge["kind"]).is_equal(StoryLinks.FLAG)
	assert_array(_shown(edges)).is_equal([
		"veteran.hello -> veteran.the_goodbye [\"veteran_trust\"]",
		"veteran.hello -> veteran.the_warning [\"veteran_distant\"]",
		"veteran.the_warning -> veteran.the_goodbye [\"veteran_trust\"]",
	])


func test_a_flag_set_at_the_end_links() -> void:
	var events := _events({
		"lanista": "== setter\n\nLANISTA: Hm.\nset: met\n",
		"veteran": "== reader\nwhen: met\n\nVETERAN: Hm.\n",
	})
	assert_array(_shown(StoryLinks.flag_edges(events))).is_equal(["lanista.setter -> veteran.reader [\"met\"]"])


## A `when` reads a flag on either side of a comparison; a line's own [condition] and a
## {substitution} do not gate the event, so they make no link.
func test_what_a_when_reads() -> void:
	var events := _events({
		"lanista": "== setter\n\nLANISTA: Hm.\nset: count = 2\nset: other = calm\nset: trust\n",
		"veteran": "== left\nwhen: count >= 2\n\nVETERAN: Hm.\n\n== right\nwhen: mood == other\n\nVETERAN: Hm.\n\n== in_a_line\n\n[trust] VETERAN: {count}\n",
	})
	assert_array(_shown(StoryLinks.flag_edges(events))).is_equal([
		"lanista.setter -> veteran.left [\"count\"]",
		"lanista.setter -> veteran.right [\"other\"]",
	])
	assert_array(StoryLinks.reads((events[2]) as StoryEvent)).is_equal(["mood", "other"])


func test_two_flags_between_one_pair_are_one_edge() -> void:
	var events := _events({
		"lanista": "== setter\n\n? Yes.\n    set: met\n? No.\n    set: trust\n",
		"veteran": "== reader\nwhen: met and not trust\n\nVETERAN: Hm.\n",
	})
	var edges := StoryLinks.flag_edges(events)
	assert_int(edges.size()).is_equal(1)
	assert_array(edges[0]["flags"]).is_equal(["met", "trust"])


func test_what_an_event_sets() -> void:
	var events := _events({"lanista": "== setter\n\n? Yes.\n    set: met\n? No.\n    set: met\n    set: count = 1\nset: trust\n"})
	assert_array(StoryLinks.sets(events[0])).is_equal(["met", "count", "trust"])


## Only the events given are joined: a requires or an unless naming one not in the list draws
## nothing (the tab draws StoryGraph's events, which may name an event that is not there).
func test_edges_only_between_the_events_given() -> void:
	var events := _fixture()
	var kept: Array[StoryEvent] = []
	for event in events:
		if event.pool == "veteran":
			kept.append(event)
	assert_array(_shown(StoryLinks.requires_edges(kept))).is_equal([
		"veteran.hello -> veteran.next_night",
		"veteran.the_warning -> veteran.the_goodbye",
	])


func test_edges_holds_every_kind() -> void:
	var events := _fixture()
	var all := StoryLinks.edges(events)
	assert_int(all.size()).is_equal(StoryLinks.requires_edges(events).size() + StoryLinks.unless_edges(events).size() + StoryLinks.flag_edges(events).size())
	var kinds := {}
	for edge in all:
		kinds[edge["kind"]] = true
	assert_array(kinds.keys()).contains_exactly_in_any_order(StoryLinks.KINDS)


func _events(pools: Dictionary) -> Array[StoryEvent]:
	var catalog := StoryCatalog.from_texts(CAST, FLAGS, pools)
	assert_array(catalog.errors).is_empty()
	return catalog.events
