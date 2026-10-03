extends GdUnitTestSuite
## StoryLayout: the Story tab's computed layout. An event's depth is one past its deepest
## prerequisite (its requires, across pools), 0 with none; a lane per pool in the order given (the
## cast's), columns by depth, file order within a cell; no two events on one cell. Pure: the events
## come from inline texts through StoryCatalog, or straight from the parser for a cycle the catalog
## would refuse; never the shipped prose.

const CAST := {
	"lanista": {"name": "PLACEHOLDER Lanista"},
	"veteran": {"name": "PLACEHOLDER Veteran"},
	"doctor": {"name": "PLACEHOLDER Doctor"},
}
const POOLS: Array[String] = ["lanista", "veteran", "doctor"]
## A chain (first, second, third) and a diamond over it (left and right on first, joined by
## both, and late on first and joined), plus a lone event; the veteran's events hang off the
## lanista's (across pools), the doctor has no file.
const LANISTA := "== first\n\n== second\nrequires: lanista.first\n\n== third\nrequires: lanista.second\n\n== left\nrequires: lanista.first\n\n== right\nrequires: lanista.first\n\n== joined\nrequires: lanista.left, lanista.right\n\n== late\nrequires: lanista.first, lanista.joined\n\n== lone\n"
const VETERAN := "== hello\n\n== after\nrequires: lanista.third\n\n== both\nrequires: veteran.hello, lanista.second\n\n== quiet\n"


func _events(pools := {"lanista": LANISTA, "veteran": VETERAN}) -> Array[StoryEvent]:
	var catalog := StoryCatalog.from_texts(CAST, "", pools)
	assert_array(catalog.errors).is_empty()
	return catalog.events


func test_a_chain_goes_one_deeper_each_step() -> void:
	var depths := StoryLayout.depths(_events())
	assert_int(depths["lanista.first"]).is_equal(0)
	assert_int(depths["lanista.second"]).is_equal(1)
	assert_int(depths["lanista.third"]).is_equal(2)
	assert_int(depths["lanista.lone"]).is_equal(0)


func test_a_diamond_takes_the_deepest_prerequisite() -> void:
	var depths := StoryLayout.depths(_events())
	assert_int(depths["lanista.left"]).is_equal(1)
	assert_int(depths["lanista.right"]).is_equal(1)
	assert_int(depths["lanista.joined"]).is_equal(2)
	# late requires first (0) and joined (2): one past the deepest
	assert_int(depths["lanista.late"]).is_equal(3)


func test_depths_cross_pools() -> void:
	var depths := StoryLayout.depths(_events())
	assert_int(depths["veteran.hello"]).is_equal(0)
	assert_int(depths["veteran.after"]).is_equal(3)
	assert_int(depths["veteran.both"]).is_equal(2)
	assert_int(depths["veteran.quiet"]).is_equal(0)


func test_every_event_has_a_depth() -> void:
	var events := _events()
	var depths := StoryLayout.depths(events)
	assert_int(depths.size()).is_equal(events.size())


## The tab also lays out events the catalog left out (StoryGraph's): a requires naming nothing
## counts for nothing, and a cycle ends rather than recursing forever.
func test_an_unknown_prerequisite_and_a_cycle_are_safe() -> void:
	var parsed: Array[StoryEvent] = []
	parsed.assign(StoryScript.parse("== a\nrequires: lanista.c\n\n== b\nrequires: lanista.a\n\n== c\nrequires: lanista.b\n\n== d\nrequires: lanista.gone\n\n== e\nrequires: lanista.a\n", "lanista")["events"])
	assert_int(parsed.size()).is_equal(5)
	var depths := StoryLayout.depths(parsed)
	assert_int(depths.size()).is_equal(5)
	assert_int(depths["lanista.d"]).is_equal(0)
	for id: String in depths:
		assert_int(depths[id]).is_between(0, 4)
	assert_int(depths["lanista.e"]).is_equal(depths["lanista.a"] + 1)


func test_columns_are_depths() -> void:
	var events := _events()
	var depths := StoryLayout.depths(events)
	var positions := StoryLayout.positions(events, POOLS)
	for event in events:
		assert_int((positions[event.id] as Vector2i).x).is_equal(depths[event.id])


func test_positions_never_overlap() -> void:
	var events := _events()
	var positions := StoryLayout.positions(events, POOLS)
	assert_int(positions.size()).is_equal(events.size())
	var seen := {}
	for id: String in positions:
		var cell: Vector2i = positions[id]
		assert_bool(seen.has(cell)).override_failure_message("%s shares %s with %s" % [id, cell, seen.get(cell, "")]).is_false()
		seen[cell] = id


func test_file_order_within_a_cell() -> void:
	var positions := StoryLayout.positions(_events(), POOLS)
	# first, lone at depth 0 in the lanista's lane, in file order
	var first: Vector2i = positions["lanista.first"]
	var lone: Vector2i = positions["lanista.lone"]
	assert_int(lone.x).is_equal(first.x)
	assert_int(lone.y).is_equal(first.y + 1)
	# second, left, right at depth 1
	assert_int((positions["lanista.left"] as Vector2i).y).is_equal((positions["lanista.second"] as Vector2i).y + 1)
	assert_int((positions["lanista.right"] as Vector2i).y).is_equal((positions["lanista.left"] as Vector2i).y + 1)
	# a cell starts at its lane's first row
	assert_int((positions["lanista.second"] as Vector2i).y).is_equal(first.y)


func test_lanes_in_the_cast_order() -> void:
	var events := _events()
	var lanes := StoryLayout.lanes(events, POOLS)
	assert_array(lanes.keys()).is_equal(["lanista", "veteran", "doctor"])
	var lanista: Vector2i = lanes["lanista"]
	var veteran: Vector2i = lanes["veteran"]
	var doctor: Vector2i = lanes["doctor"]
	assert_int(lanista.x).is_equal(0)
	assert_int(lanista.y).is_equal(3)  # depth 1 holds three events
	assert_int(veteran.x).is_equal(3)
	assert_int(veteran.y).is_equal(2)  # depth 0 holds hello and quiet
	assert_int(doctor.x).is_equal(5)
	assert_int(doctor.y).is_equal(1)  # an empty pool still has its lane


func test_every_event_is_in_its_own_lane() -> void:
	var events := _events()
	var lanes := StoryLayout.lanes(events, POOLS)
	var positions := StoryLayout.positions(events, POOLS)
	for event in events:
		var lane: Vector2i = lanes[event.pool]
		assert_int((positions[event.id] as Vector2i).y).is_between(lane.x, lane.x + lane.y - 1)


func test_the_order_of_the_pools_is_the_lanes_order() -> void:
	var events := _events()
	var reversed: Array[String] = ["doctor", "veteran", "lanista"]
	var lanes := StoryLayout.lanes(events, reversed)
	assert_int((lanes["doctor"] as Vector2i).x).is_equal(0)
	assert_int((lanes["veteran"] as Vector2i).x).is_equal(1)
	assert_int((lanes["lanista"] as Vector2i).x).is_equal(3)
	var positions := StoryLayout.positions(events, reversed)
	assert_int((positions["veteran.hello"] as Vector2i).y).is_equal(1)


func test_a_pool_left_out_has_no_lane_and_no_positions() -> void:
	var events := _events()
	var only: Array[String] = ["veteran"]
	var positions := StoryLayout.positions(events, only)
	assert_array(StoryLayout.lanes(events, only).keys()).is_equal(["veteran"])
	assert_bool(positions.has("lanista.first")).is_false()
	assert_int((positions["veteran.hello"] as Vector2i).y).is_equal(0)
	# a depth still counts the prerequisites in pools not shown
	assert_int((positions["veteran.after"] as Vector2i).x).is_equal(3)
