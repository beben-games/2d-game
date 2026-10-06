extends GdUnitTestSuite
## The grounds' rooms as data (pure): the five shipped defs validate, agree with the story's room
## list, and are joined by doors that each have their way back; a def with an unknown target, two
## doors on one wall or to one room, a bad condition, an unknown station, or a sprite the atlas
## does not have fails validate().

const S := ArenaGrid.Side


func _door(side: int, to: String, when := "") -> GroundsDoorDef:
	var door := GroundsDoorDef.new()
	door.side = side
	door.to = to
	door.when = when
	return door


func _room(id: String, doors: Array[GroundsDoorDef] = [], stations: Array[String] = [], lifts: Array[int] = []) -> GroundsRoomDef:
	var room := GroundsRoomDef.new()
	room.id = id
	room.doors = doors
	room.stations = stations
	room.lift_tiers = lifts
	return room


func test_the_five_shipped_rooms_load_and_validate() -> void:
	assert_array(GroundsRooms.ids()).has_size(5)
	for id: String in GroundsRooms.ids():
		var room := GroundsRooms.room(id)
		assert_object(room).override_failure_message("no room %s" % id).is_not_null()
		assert_str(room.id).is_equal(id)
		assert_int(room.width).is_equal(26)
		assert_int(room.height).is_equal(15)
		assert_array(room.validate()).override_failure_message("%s: %s" % [id, room.validate()]).is_empty()
	assert_object(GroundsRooms.room("forum")).is_null()


## The story's `enter <room>` list and the room data are one list.
func test_the_room_ids_are_the_storys_rooms() -> void:
	var ids := GroundsRooms.ids().duplicate()
	var rooms := StoryScript.ROOMS.duplicate()
	ids.sort()
	rooms.sort()
	assert_array(ids).is_equal(rooms)


func test_the_shipped_map() -> void:
	assert_dict(_doors_of("ludus")).is_equal({S.LEFT: "armamentarium", S.RIGHT: "sanitarium", S.TOP: "hypogeum"})
	assert_dict(_doors_of("armamentarium")).is_equal({S.RIGHT: "ludus"})
	assert_dict(_doors_of("sanitarium")).is_equal({S.LEFT: "ludus"})
	assert_dict(_doors_of("hypogeum")).is_equal({S.BOTTOM: "ludus", S.LEFT: "spoliarium"})
	assert_dict(_doors_of("spoliarium")).is_equal({S.RIGHT: "hypogeum"})
	assert_array(GroundsRooms.room("ludus").stations).is_equal(["post"])
	assert_array(GroundsRooms.room("armamentarium").stations).is_equal(["rack"])
	assert_array(GroundsRooms.room("hypogeum").stations).is_empty()
	assert_array(GroundsRooms.room("hypogeum").lift_tiers).is_equal([2, 1, 3])  # the bays left to right: tier 1's at the centre, where it always stood
	for id: String in ["ludus", "armamentarium", "sanitarium", "spoliarium"]:
		assert_array(GroundsRooms.room(id).lift_tiers).override_failure_message(id).is_empty()
	assert_array(GroundsRooms.room("sanitarium").stations).is_empty()
	assert_array(GroundsRooms.room("spoliarium").stations).is_empty()
	# The Spoliarium's door shows once it has been seen; every other door always.
	for id: String in GroundsRooms.ids():
		for door: GroundsDoorDef in GroundsRooms.room(id).doors:
			var expected := "spoliarium_seen" if id == "hypogeum" and door.to == "spoliarium" else ""
			assert_str(door.when).is_equal(expected)
	# The Spoliarium is silent; the rest play the grounds' loop.
	for id: String in GroundsRooms.ids():
		assert_str(GroundsRooms.room(id).music).is_equal("" if id == "spoliarium" else "music_grounds")
	# The merchants keep their stations; the three who only talk stand in their rooms.
	var kept := {"ludus": {"post": "lanista"}, "armamentarium": {"rack": "armourer"}}
	var placed := {"ludus": ["veteran"], "sanitarium": ["doctor"], "hypogeum": ["attendant"]}
	for id: String in GroundsRooms.ids():
		assert_dict(GroundsRooms.room(id).keepers).is_equal(kept.get(id, {}))
		assert_array(GroundsRooms.room(id).people.keys()).is_equal(placed.get(id, []))


func _doors_of(id: String) -> Dictionary:
	var out := {}
	for door: GroundsDoorDef in GroundsRooms.room(id).doors:
		out[door.side] = door.to
	return out


func test_every_shipped_door_has_its_way_back() -> void:
	assert_array(GroundsRooms.errors()).is_empty()


func test_a_door_with_no_way_back_fails_the_check() -> void:
	var a := _room("a", [_door(S.LEFT, "b")], [], [1])
	var b := _room("b", [])
	var errors := GroundsRooms.check({"a": a, "b": b})
	assert_array(errors).contains_exactly_in_any_order(["a: the door to b has no door back", "b: no way to the lifts through doors that always open"])
	b.doors = [_door(S.RIGHT, "a")]
	assert_array(GroundsRooms.check({"a": a, "b": b})).is_empty()


func test_a_room_filed_under_another_id_fails_the_check() -> void:
	var a := _room("a", [], [], [1])
	assert_array(GroundsRooms.check({"b": a})).contains_exactly(["b: the def's id is 'a'"])


func test_an_unknown_target_fails_validate() -> void:
	var known: Array[String] = ["a", "b"]
	assert_array(_room("a", [_door(S.LEFT, "b")]).validate(known)).is_empty()
	assert_array(_room("a", [_door(S.LEFT, "forum")]).validate(known)).contains_exactly(["door 0: unknown room 'forum'"])
	assert_array(_room("a", [_door(S.LEFT, "")]).validate(known)).contains_exactly(["door 0: leads nowhere"])
	assert_array(_room("a", [_door(S.LEFT, "a")]).validate(known)).contains_exactly(["door 0: leads to its own room"])
	# The default list is the shipped rooms'.
	assert_array(_room("ludus", [_door(S.TOP, "hypogeum")]).validate()).is_empty()
	assert_array(_room("ludus", [_door(S.TOP, "forum")]).validate()).contains_exactly(["door 0: unknown room 'forum'"])


func test_two_doors_on_one_wall_or_to_one_room_fail_validate() -> void:
	var known: Array[String] = ["a", "b", "c"]
	assert_array(_room("a", [_door(S.LEFT, "b"), _door(S.LEFT, "c")]).validate(known)).contains_exactly(["door 1: a second door on the left wall"])
	# Two doors to one room would be two interactables with one id (door:b).
	assert_array(_room("a", [_door(S.LEFT, "b"), _door(S.RIGHT, "b")]).validate(known)).contains_exactly(["door 1: a second door to b"])
	assert_array(_room("a", [null]).validate(known)).contains_exactly(["door 0: missing"])


func test_a_bad_condition_fails_validate() -> void:
	var known: Array[String] = ["a", "b"]
	assert_array(_room("a", [_door(S.LEFT, "b", "spoliarium_seen")]).validate(known)).is_empty()
	assert_array(_room("a", [_door(S.LEFT, "b", "wins >= 2 and not spoliarium_seen")]).validate(known)).is_empty()
	var syntax := _room("a", [_door(S.LEFT, "b", "wins >=")]).validate(known)
	assert_int(syntax.size()).is_equal(1)
	assert_str(syntax[0]).starts_with("door 0: when: ")
	var unknown := _room("a", [_door(S.LEFT, "b", "seen_the_forum")]).validate(known)
	assert_int(unknown.size()).is_equal(1)
	assert_str(unknown[0]).starts_with("door 0: when: ")
	assert_str(unknown[0]).contains("seen_the_forum")
	# A story flag is known to a context that declares it.
	var declared := StoryContext.new(null, {"seen_the_forum": false})
	assert_array(_room("a", [_door(S.LEFT, "b", "seen_the_forum")]).validate(known, declared)).is_empty()


func test_a_doors_condition_decides_whether_it_is_open() -> void:
	var save := Save.new()
	var door := _door(S.LEFT, "b", "spoliarium_seen")
	assert_bool(door.is_open(StoryContext.new(save))).is_false()
	save.set_flag("spoliarium_seen", true)
	assert_bool(door.is_open(StoryContext.new(save))).is_true()
	assert_bool(_door(S.LEFT, "b").is_open(StoryContext.new(save))).is_true()  # no condition: always


func test_stations_must_be_known_and_once() -> void:
	var known: Array[String] = []
	assert_array(_room("a", [], ["post", "rack"]).validate(known)).is_empty()
	assert_array(_room("a", [], ["lift"]).validate(known)).contains_exactly(["unknown station 'lift'"])  # the lifts are lift_tiers
	assert_array(_room("a", [], ["well"]).validate(known)).contains_exactly(["unknown station 'well'"])
	assert_array(_room("a", [], ["post", "post"]).validate(known)).contains_exactly(["station 'post' twice"])


func test_the_shape_of_a_room() -> void:
	var known: Array[String] = []
	var room := _room("", [])
	assert_array(room.validate(known)).contains_exactly(["id must be set"])
	room = _room("a", [])
	room.width = 7
	room.height = 5
	assert_array(room.validate(known)).contains_exactly(["width must be >= 8", "height must be >= 6"])


func test_the_dressing_keepers_and_people_are_checked() -> void:
	var known: Array[String] = []
	var room := _room("a", [], ["post"])
	room.dressing = [["skull", Vector2(0.5, 0.5)], ["no_such_sprite", Vector2(0.1, 0.1)], ["skull"]]
	room.keepers = {"post": "lanista", "rack": "armourer"}
	room.people = {"veteran": Vector2(0.5, 0.5), "doctor": "left"}
	assert_array(room.validate(known)).contains_exactly_in_any_order([
		"dressing 1: no sprite 'no_such_sprite'",
		"dressing 2: expected [sprite name, Vector2 fraction]",
		"keeper at 'rack', which the room does not have",
		"people: doctor's spot is not a Vector2 fraction",
	])


## The shipped check reads the story's declared flags (StoryCatalog.declared_flags, the flags file
## the catalog reads), so a door on a story flag is sound with them and an unknown name without.
func test_a_door_on_a_declared_story_flag_validates_with_the_storys_flags() -> void:
	const FIXTURE := "res://tests/support/story"
	var declared := StoryCatalog.declared_flags(FIXTURE)
	assert_dict(declared).is_equal(StoryCatalog.load_dir(FIXTURE).flags)
	assert_dict(StoryCatalog.declared_flags()).is_equal(StoryCatalog.load_dir(StoryCatalog.DATA_DIR).flags)
	var a := _room("a", [_door(S.LEFT, "b", "veteran_met")], [], [1])
	var b := _room("b", [_door(S.RIGHT, "a")])
	assert_array(GroundsRooms.check({"a": a, "b": b}, StoryContext.new(null, declared))).is_empty()
	var without := GroundsRooms.check({"a": a, "b": b})
	assert_int(without.size()).is_equal(1)
	assert_str(without[0]).starts_with("a: door 0: when: ")
	assert_str(without[0]).contains("veteran_met")


## The lifts stand in the top wall, so a room with them has no top door.
func test_the_lifts_and_a_top_door_fail_validate() -> void:
	var known: Array[String] = ["a", "b"]
	assert_array(_room("a", [_door(S.TOP, "b")], [], [1]).validate(known)).contains_exactly(["door 0: the lifts and a top door share the top wall"])
	assert_array(_room("a", [_door(S.TOP, "b")], [], [2, 1, 3]).validate(known)).contains_exactly(["door 0: the lifts and a top door share the top wall"])
	assert_array(_room("a", [_door(S.BOTTOM, "b")], [], [2, 1, 3]).validate(known)).is_empty()


## A lift a tier: each a tier (1 or more) once, and no more bays than the top wall holds.
func test_the_lift_tiers_are_checked() -> void:
	var known: Array[String] = []
	assert_array(_room("a", [], [], [0, 2, 2]).validate(known)).contains_exactly_in_any_order(["lift 0: tier 0 is no tier", "lift 2: tier 2 twice"])
	assert_array(_room("a", [], [], [1, 2, 3, 4]).validate(known)).contains_exactly(["4 lifts do not fit the top wall"])
	var narrow := _room("a", [], [], [1, 2])
	narrow.width = 8
	assert_array(narrow.validate(known)).contains_exactly(["2 lifts do not fit the top wall"])


func test_one_room_holds_the_lifts() -> void:
	var a := _room("a", [_door(S.LEFT, "b")])
	var b := _room("b", [_door(S.RIGHT, "a")])
	assert_array(GroundsRooms.check({"a": a, "b": b})).contains_exactly(["the lifts are in 0 rooms (); one holds them"])
	a.lift_tiers = [1]
	b.lift_tiers = [2]
	assert_array(GroundsRooms.check({"a": a, "b": b})).contains_exactly(["the lifts are in 2 rooms (a, b); one holds them"])
	b.lift_tiers = []
	assert_array(GroundsRooms.check({"a": a, "b": b})).is_empty()


## Tier 1's lift is the way into a new save's first run from the grounds: a grounds without it
## is refused.
func test_the_lifts_must_hold_tier_1s() -> void:
	var a := _room("a", [_door(S.LEFT, "b")], [], [2, 3])
	var b := _room("b", [_door(S.RIGHT, "a")])
	assert_array(GroundsRooms.check({"a": a, "b": b})).contains_exactly(["a: no lift for tier 1 among the lifts [2, 3]"])
	a.lift_tiers = [2, 1, 3]
	assert_array(GroundsRooms.check({"a": a, "b": b})).is_empty()


## A room whose only way out is a conditional door is a trap while it is shut: the lift must be
## reachable through doors that always open.
func test_every_room_reaches_the_lift_through_doors_that_always_open() -> void:
	var a := _room("a", [_door(S.LEFT, "b")], [], [1])
	var b := _room("b", [_door(S.RIGHT, "a", "spoliarium_seen"), _door(S.LEFT, "c")])
	var c := _room("c", [_door(S.RIGHT, "b")])
	assert_array(GroundsRooms.check({"a": a, "b": b, "c": c})).contains_exactly_in_any_order([
		"b: no way to the lifts through doors that always open",
		"c: no way to the lifts through doors that always open",
	])
	b.doors[0].when = ""
	assert_array(GroundsRooms.check({"a": a, "b": b, "c": c})).is_empty()


func test_a_persons_spot_is_on_the_floor() -> void:
	var known: Array[String] = []
	var room := _room("a", [])
	room.people = {"veteran": Vector2(0.5, 1.0), "doctor": Vector2(1.2, 0.5), "lanista": Vector2(0.5, -0.1)}
	assert_array(room.validate(known)).contains_exactly_in_any_order([
		"people: doctor's spot (1.2, 0.5) is off the floor (0..1)",
		"people: lanista's spot (0.5, -0.1) is off the floor (0..1)",
	])
