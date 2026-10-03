extends SceneSuite
## The grounds as five rooms joined by doors: each room built from its GroundsRoomDef (a gap in
## the wall for each open door, the gap closed by the door's blocker, a door interactable on the
## floor before it, the room's stations), E on a door walks to the room behind it (the fade, the
## new room with the gladiator before the door back, room_entered on the bus, no revive and no
## second grounds_entered), the Spoliarium's door hidden until it has been seen, the lift in the
## Hypogeum starting the run on the title's pending seed, the camera held to the room's size,
## a restart or a quit during a room's fade leaving no black, and the post's notches.

var _rooms: Array[String] = []
var _arrivals := 0


func before_test() -> void:
	super()
	_rooms = []
	_arrivals = 0
	Events.room_entered.connect(_on_room_entered)
	Events.grounds_entered.connect(_on_grounds_entered)


func after_test() -> void:
	Events.room_entered.disconnect(_on_room_entered)
	Events.grounds_entered.disconnect(_on_grounds_entered)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	await super()


func _on_room_entered(id: String) -> void:
	_rooms.append(id)


func _on_grounds_entered() -> void:
	_arrivals += 1


func _grounds_main() -> Main:
	var main: Main = quiet_main()
	main.enter_grounds()
	return main


func _fade(main: Main) -> float:
	return (main.get_node("Fade/Black") as ColorRect).color.a


func _door_ids(grounds: Grounds) -> Array[String]:
	var ids: Array[String] = []
	for door in grounds.doors():
		ids.append(door.id)
	ids.sort()
	return ids


func test_the_ludus_has_three_doors_and_the_post() -> void:
	var main := _grounds_main()
	var grounds := main.grounds
	assert_str(grounds.room_def.id).is_equal("ludus")
	assert_array(_rooms).is_equal(["ludus"])
	assert_array(_door_ids(grounds)).is_equal(["door:armamentarium", "door:hypogeum", "door:sanitarium"])
	assert_object(grounds.interactable("post")).is_not_null()
	assert_object(grounds.interactable("rack")).is_null()
	assert_object(grounds.interactable("lift")).is_null()
	for door in grounds.doors():
		assert_str(door.kind).is_equal("door")
		assert_int(door.collision_layer).is_equal(0)
		assert_int(door.collision_mask).is_equal(65)
		assert_bool(grounds.bounds().has_point(door.stand_position())).is_true()
		# The interactable is found by its id, never by its node's name (a ':' is no name).
		assert_object(grounds.interactable(door.id)).is_same(door)
	assert_str(grounds.door_to("armamentarium").to).is_equal("armamentarium")
	assert_int(grounds.door_to("armamentarium").side).is_equal(ArenaGrid.Side.LEFT)
	assert_int(grounds.door_to("sanitarium").side).is_equal(ArenaGrid.Side.RIGHT)
	assert_int(grounds.door_to("hypogeum").side).is_equal(ArenaGrid.Side.TOP)
	# A gap in the wall on each door's side; arriving from outside, the bottom centre.
	assert_array(grounds.arena.door_sides).contains_exactly_in_any_order([ArenaGrid.Side.LEFT, ArenaGrid.Side.RIGHT, ArenaGrid.Side.TOP])
	var floor_rect := grounds.bounds()
	assert_vector(player_of(main).global_position).is_equal(Vector2(floor_rect.get_center().x, floor_rect.end.y - ArenaGrid.TILE))
	# A door's area does not reach the post's.
	var post := grounds.interactable("post")
	for door in grounds.doors():
		var door_area := Rect2(door.global_position + door.area.position, door.area.size)
		var post_area := Rect2(post.global_position + post.area.position, post.area.size)
		assert_bool(door_area.intersects(post_area)).is_false()


func test_the_post_carries_a_fixed_handful_of_notches_cut_into_the_crates_face() -> void:
	var main := _grounds_main()
	var post := main.grounds.station("post")
	var notches := post.get_node_or_null("Notches") as Node2D
	assert_object(notches).is_not_null()
	var crate := post.get_node("crate") as Sprite2D
	var spear := post.get_node("weapon_spear") as Sprite2D
	# Drawn over the crate, under the spear that leans on it.
	assert_int(notches.get_index()).is_greater(crate.get_index())
	assert_int(notches.get_index()).is_less(spear.get_index())
	# The table is in the crate's pixels: the node stands on the crate's corner.
	assert_vector(notches.position).is_equal(crate.position)
	# A handful, the same in every room built (other men's marks, never a counter).
	assert_int(Grounds.NOTCHES.size()).is_between(3, 7)
	var spear_rect := Rect2(spear.position, SpriteAtlas.region("weapon_spear").size)
	var wood := crate.texture.get_image()
	for at: Vector2i in Grounds.NOTCHES:
		var mark := Rect2(crate.position + Vector2(at), Vector2(Grounds.NOTCH_LENGTH, 1.0))
		assert_bool(mark.intersects(spear_rect)).override_failure_message("a notch under the spear at %s" % at).is_false()
		for step in Grounds.NOTCH_LENGTH:
			# Every pixel of a cut lies on the crate's wood, and the cut is darker than the wood.
			var pixel := wood.get_pixel(at.x + step, at.y)
			assert_float(pixel.a).override_failure_message("a notch off the crate at %s" % at).is_equal(1.0)
			assert_float(Grounds.NOTCH_COLOUR.get_luminance()).override_failure_message("a notch no darker than its wood at %s" % at).is_less(pixel.get_luminance())


func test_e_on_the_left_door_walks_to_the_armamentarium_before_its_right_door() -> void:
	var main := _grounds_main()
	var player := player_of(main)
	player.hp = player.max_hp - 1  # no revive on a walk between rooms
	var left := main.grounds.door_to("armamentarium")
	await stand_at(main, left.id)
	await interact()
	assert_float(_fade(main)).is_greater(0.0)  # the fade has begun; the room is still the Ludus
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	await wait_until(func() -> bool: return main.grounds.room_def.id == "armamentarium" and _fade(main) == 0.0, "the walk to the armamentarium", 120)
	assert_array(_rooms).is_equal(["ludus", "armamentarium"])
	assert_int(_arrivals).is_equal(1)
	var grounds := main.grounds
	assert_int(grounds.get_index()).is_equal(0)
	assert_str(grounds.arrived_from).is_equal("ludus")
	assert_object(grounds.interactable("rack")).is_not_null()
	assert_array(_door_ids(grounds)).is_equal(["door:ludus"])
	# Before the door back (on the right wall), on the floor, out of its reach: nothing in focus.
	var back := grounds.door_to("ludus")
	assert_int(back.side).is_equal(ArenaGrid.Side.RIGHT)
	assert_vector(player.global_position).is_equal(grounds.entry_position())
	assert_bool(grounds.bounds().has_point(player.global_position)).is_true()
	assert_float(player.global_position.distance_to(back.stand_position())).is_less(3.0 * ArenaGrid.TILE)
	assert_float(player.global_position.x).is_less(back.stand_position().x)
	await ticks(3)
	assert_object(grounds.focus).is_null()
	assert_int(player.hp).is_equal(player.max_hp - 1)
	assert_bool(get_tree().paused).is_false()


func test_the_way_back_lands_before_the_ludus_left_door() -> void:
	var main := _grounds_main()
	await go_through(main, "armamentarium")
	await go_through(main, "ludus")
	var grounds := main.grounds
	assert_str(grounds.arrived_from).is_equal("armamentarium")
	var left := grounds.door_to("armamentarium")
	assert_vector(player_of(main).global_position).is_equal(grounds.entry_position())
	assert_float(player_of(main).global_position.distance_to(left.stand_position())).is_less(3.0 * ArenaGrid.TILE)
	assert_float(player_of(main).global_position.x).is_greater(left.stand_position().x)
	assert_array(_rooms).is_equal(["ludus", "armamentarium", "ludus"])
	# The right door leads to the Sanitarium and back to the Ludus's right door.
	await go_through(main, "sanitarium")
	assert_int(main.grounds.door_to("ludus").side).is_equal(ArenaGrid.Side.LEFT)
	await go_through(main, "ludus")
	assert_float(player_of(main).global_position.x).is_less(main.grounds.door_to("sanitarium").stand_position().x)


## Each door's gap is closed by its blocker on the walls' layer: walking or dashing into it, the
## body stays on the floor.
func test_no_doors_gap_lets_a_body_out() -> void:
	var main := _grounds_main()
	var player := player_of(main)
	var actions := {ArenaGrid.Side.LEFT: "move_left", ArenaGrid.Side.RIGHT: "move_right", ArenaGrid.Side.TOP: "move_up", ArenaGrid.Side.BOTTOM: "move_down"}
	await go_through(main, "hypogeum")  # the bottom door
	await go_through(main, "ludus")  # left, right, and top
	for room_id: String in ["ludus", "hypogeum"]:
		if main.grounds.room_def.id != room_id:
			await go_through(main, room_id)
		for door in main.grounds.doors():
			assert_int(door.blocker.collision_layer).is_equal(16)
			assert_object(door.blocker.get_parent()).is_same(door)
			var gap := ArenaGrid.door_gap(main.grounds.room_def.width, main.grounds.room_def.height, door.side)
			var shape: CollisionShape2D = door.blocker.get_node("Shape")
			assert_that(Rect2(door.blocker.global_position + shape.position - (shape.shape as RectangleShape2D).size * 0.5, (shape.shape as RectangleShape2D).size)).is_equal(gap)
			player.global_position = door.stand_position()
			var action: String = actions[door.side]
			Input.action_press(action)
			await ticks(40)
			Input.action_press("dash")
			await ticks(2)
			Input.action_release("dash")
			await ticks(30)
			Input.action_release(action)
			assert_bool(main.grounds.bounds().grow(0.5).has_point(player.global_position)).override_failure_message(
				"%s: the body left through the %s gap to %s" % [room_id, GroundsDoorDef.side_name(door.side), player.global_position]).is_true()


## The lift's opening cuts the top wall's art under its open leaf, as a door's gap does (the void
## shows through the leaf), but the wall's collision is kept: walking or dashing into the opening,
## the body stays on the floor, and the lift still takes the focus there.
func test_the_lifts_opening_cuts_the_top_wall_but_holds_the_body() -> void:
	var main := _grounds_main()
	await go_through(main, "hypogeum")
	var grounds := main.grounds
	var def := grounds.room_def
	var tiles := grounds.arena.tiles
	var opening := ArenaGrid.door_cells(def.width, def.height, ArenaGrid.Side.TOP)
	for cell in opening:
		assert_int(tiles.get_cell_source_id(cell)).override_failure_message("a wall tile under the lift at %s" % cell).is_equal(-1)
	assert_bool(opening.any(func(cell: Vector2i) -> bool: return cell.y == ArenaGrid.TOP_WALL_ROWS - 1)).is_true()  # the face row
	# Only the opening: the wall either side of it is still drawn, and its collision is the ring's.
	for row in ArenaGrid.TOP_WALL_ROWS:
		assert_int(tiles.get_cell_source_id(Vector2i(opening[0].x - 1, row))).is_not_equal(-1)
		assert_int(tiles.get_cell_source_id(Vector2i(opening[-1].x + 1, row))).is_not_equal(-1)
	assert_bool(ArenaGrid.Side.TOP in grounds.arena.door_sides).is_false()
	var lift := grounds.station("lift")
	var player := player_of(main)
	player.global_position = lift.stand_position()
	Input.action_press("move_up")
	await ticks(40)
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	await ticks(30)
	Input.action_release("move_up")
	assert_bool(grounds.bounds().grow(0.5).has_point(player.global_position)).override_failure_message(
		"the body left through the lift's opening to %s" % player.global_position).is_true()
	await wait_until(func() -> bool: return grounds.focus == lift, "the lift to take the focus under its opening", 30)


func test_the_hypogeum_shows_the_spoliarium_door_only_once_it_has_been_seen() -> void:
	var main := _grounds_main()
	await go_through(main, "hypogeum")
	assert_array(_door_ids(main.grounds)).is_equal(["door:ludus"])
	assert_array(main.grounds.arena.door_sides).is_equal([ArenaGrid.Side.BOTTOM])  # no gap: wall
	assert_object(main.grounds.interactable("lift")).is_not_null()
	Profile.save.set_flag("spoliarium_seen", true)
	await go_through(main, "ludus")
	await go_through(main, "hypogeum")
	assert_array(_door_ids(main.grounds)).is_equal(["door:ludus", "door:spoliarium"])
	assert_int(main.grounds.door_to("spoliarium").side).is_equal(ArenaGrid.Side.LEFT)
	assert_str(Audio.current_music).is_equal("music_grounds")
	await go_through(main, "spoliarium")
	assert_array(_door_ids(main.grounds)).is_equal(["door:hypogeum"])
	assert_str(Audio.current_music).is_equal("")  # the Spoliarium is silent
	await go_through(main, "hypogeum")
	assert_str(Audio.current_music).is_equal("music_grounds")
	assert_array(_rooms).is_equal(["ludus", "hypogeum", "ludus", "hypogeum", "spoliarium", "hypogeum"])


func test_the_lift_starts_the_run_with_the_titles_pending_seed() -> void:
	var main: Main = quiet_main()
	Profile.save.set_flag("returned", true)
	main.play(42, {"immortal": true})
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	await go_through(main, "sanitarium")  # a detour keeps the pending seed
	await go_through(main, "ludus")
	await take_the_lift(main)
	assert_object(main.grounds).is_null()
	assert_object(main.room).is_not_null()
	assert_int(RunState.seed_value).is_equal(42)
	assert_that(RunState.cheats).is_equal({"immortal": true})
	assert_float(_fade(main)).is_equal(0.0)


func test_grounds_entered_fires_once_for_a_walk_through_three_rooms() -> void:
	var main := _grounds_main()
	await go_through(main, "armamentarium")
	await go_through(main, "ludus")
	await go_through(main, "hypogeum")
	assert_int(_arrivals).is_equal(1)
	assert_array(_rooms).is_equal(["ludus", "armamentarium", "ludus", "hypogeum"])
	assert_int(plays("music_grounds")).is_equal(1)  # one loop across the rooms, never restarted
	# A new arrival from outside is another.
	main.enter_grounds()
	assert_int(_arrivals).is_equal(2)
	assert_str(main.grounds.room_def.id).is_equal("ludus")


## The camera's limits are the room's: a larger def scrolls.
func test_a_larger_room_holds_the_camera_to_its_size() -> void:
	var main := _grounds_main()
	var big := GroundsRoomDef.new()
	big.id = "big"
	big.width = 40
	big.height = 20
	big.stations = ["post"]
	assert_array(big.validate([])).is_empty()
	main.mount_room(big, "")
	var camera: Camera2D = main.get_node("Player/Camera")
	assert_that(main.grounds.full_rect()).is_equal(ArenaGrid.full_rect(40, 20))
	assert_int(camera.limit_left).is_equal(0)
	assert_int(camera.limit_top).is_equal(0)
	assert_int(camera.limit_right).is_equal(40 * ArenaGrid.TILE)
	assert_int(camera.limit_bottom).is_equal(20 * ArenaGrid.TILE)
	assert_bool(main.grounds.bounds().has_point(player_of(main).global_position)).is_true()


## A room narrower than the view (a grounds room is 26 tiles, 416 px, and the 3x view is about
## 427 px of the world) sits centred, the same black at each side, and holds still as the
## gladiator walks and aims from one side to the other: the camera neither drifts to one limit
## nor jitters. Camera2D does this itself when its limits are closer together than the view (it
## centres the view on them), so the limits stay the room's; this pins it. A 20-tile test room
## shows the same with a wider margin.
func test_a_room_narrower_than_the_view_sits_centred_and_still() -> void:
	var main := _grounds_main()
	var camera: Camera2D = main.get_node("Player/Camera")
	var narrow := GroundsRoomDef.new()
	narrow.id = "narrow"
	narrow.width = 20
	narrow.height = 15
	narrow.stations = ["post"]
	for def: GroundsRoomDef in [GroundsRooms.room("ludus"), narrow]:
		main.mount_room(def, "")
		var rect := main.grounds.full_rect()
		var player := player_of(main)
		var margins: Array[Vector2] = []
		for spot: float in [0.1, 0.9, 0.5]:
			player.global_position = main.grounds.floor_point(Vector2(spot, 0.5))
			player.aim_override = player.global_position + Vector2(200.0 if spot < 0.5 else -200.0, 0.0)
			await ticks(30)
			margins.append(_side_margins(rect))
		player.aim_override = Vector2.INF
		var view_width := get_viewport().get_visible_rect().size.x
		assert_float(margins[0].x).override_failure_message("%s: no black at the left (%s)" % [def.id, margins]).is_greater(0.0)
		for m in margins:
			assert_float(m.x).override_failure_message("%s: uneven sides %s" % [def.id, margins]).is_equal_approx(m.y, 0.01)
			assert_float(m.x).override_failure_message("%s: moved %s" % [def.id, margins]).is_equal_approx(margins[0].x, 0.01)
			assert_float(m.x + m.y + rect.size.x * camera.zoom.x).is_equal_approx(view_width, 0.01)


## The black left and right of `rect` on screen: (left, right), viewport pixels.
func _side_margins(rect: Rect2) -> Vector2:
	var xform := get_viewport().get_canvas_transform()
	var view := get_viewport().get_visible_rect()
	return Vector2((xform * rect.position).x - view.position.x, view.end.x - (xform * rect.end).x)


## A second E during the fade changes nothing: one walk.
func test_e_again_during_the_fade_walks_once() -> void:
	var main := _grounds_main()
	await stand_at(main, "door:armamentarium")
	await interact()
	await interact()
	await wait_until(func() -> bool: return main.grounds.room_def.id == "armamentarium" and _fade(main) == 0.0, "the walk", 120)
	await real_seconds(Main.FADE_TIME * 2.0 + 0.1)
	assert_array(_rooms).is_equal(["ludus", "armamentarium"])
	assert_float(_fade(main)).is_equal(0.0)


## Quit to title during a room's fade: the walk is abandoned (no room mounts under the title),
## and once Play brings the grounds back the black the walk's tween was painting is lifted and
## the next walk goes (the walk's guard is not left set). (In the game the quit reloads the scene
## and takes the fade with it; the harness has no reload.) The "no room mounts under the title"
## half holds here because the paused tree freezes Main's fade tween, so the walk's coroutine
## waits under the title; the real guard (the moved serial) is exercised after Play, when the
## tween ends and the walk finds the serial changed. R there does nothing (the grounds have
## nothing to restart): the walk goes on and the black lifts.
func test_a_quit_or_a_restart_mid_fade_leaves_no_black() -> void:
	var main := _grounds_main()
	await stand_at(main, "door:armamentarium")
	await interact()
	assert_float(_fade(main)).is_greater(0.0)
	main.quit_to_title()
	assert_bool(main.get_node("Title").is_open()).is_true()
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_array(_rooms).is_equal(["ludus"])
	Profile.save.set_flag("returned", true)
	main.get_node("Title").play()
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_float(_fade(main)).is_equal(0.0)
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_array(_rooms).is_equal(["ludus", "ludus"])  # Play's arrival, not the abandoned walk
	await go_through(main, "armamentarium")
	# R mid-fade: nothing restarts in the grounds; the walk lands and the black lifts.
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await stand_at(main, "door:ludus")
	await interact()
	await press_action("restart")
	main.restart()
	await wait_until(func() -> bool: return main.grounds.room_def.id == "ludus" and _fade(main) == 0.0, "the walk under R", 120)
	assert_int(restarts[0]).is_equal(0)
	assert_float(_fade(main)).is_equal(0.0)


## Every room is the grounds: R does nothing in one, and Quit to title from one yields nothing.
func test_r_does_nothing_and_quit_yields_nothing_in_any_room() -> void:
	var main := _grounds_main()
	var endings: Array[String] = []
	var on_ended := func(outcome: String) -> void: endings.append(outcome)
	Events.run_ended.connect(on_ended)
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await go_through(main, "sanitarium")
	await press_action("restart")
	assert_int(restarts[0]).is_equal(0)
	assert_str(main.grounds.room_def.id).is_equal("sanitarium")
	main.quit_to_title()
	Events.run_ended.disconnect(on_ended)
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_array(endings).is_empty()
	assert_int(Profile.save.flags["runs"]).is_equal(0)


## Arriving from a room whose door here is shut (the Spoliarium's, unseen), the gladiator still
## stands before that door's place in the wall: in nothing's reach.
func test_arriving_by_a_shut_door_stands_before_its_place_in_nobodys_reach() -> void:
	var main := _grounds_main()
	main.mount_room(GroundsRooms.room("hypogeum"), "spoliarium")
	var grounds := main.grounds
	assert_object(grounds.door_to("spoliarium")).is_null()
	var gap := ArenaGrid.door_gap(grounds.room_def.width, grounds.room_def.height, ArenaGrid.Side.LEFT)
	assert_vector(player_of(main).global_position).is_equal(Door.threshold_of(gap, ArenaGrid.Side.LEFT) + Vector2.RIGHT * Grounds.ENTRY_DEPTH)
	await ticks(5)
	assert_object(grounds.focus).is_null()
	for item in grounds.interactables():
		assert_bool(item.overlaps_body(player_of(main))).override_failure_message("in %s's reach" % item.id).is_false()


## The one hook at an arrival's end (Main.room_shown, after the black has lifted): once for Play
## on a returned profile, once for a door, once for the gate screen's pass.
func test_every_arrival_ends_once_in_room_shown() -> void:
	var main: Main = quiet_main(3)
	var shown: Array[String] = []
	main.room_shown.connect(func(id: String) -> void: shown.append(id))
	# The gate screen's pass (a fresh profile's first run, a fall).
	await fall_to_the_gate(main)
	await get_tree().process_frame
	Input.action_press("ui_accept")
	await ticks(2)
	Input.action_release("ui_accept")
	await wait_until(func() -> bool: return shown.size() == 1, "the gate's pass to end in room_shown", 120)
	assert_array(shown).is_equal(["ludus"])
	assert_float(_fade(main)).is_equal(0.0)
	# A door.
	await go_through(main, "armamentarium")
	assert_array(shown).is_equal(["ludus", "armamentarium"])
	# Play on the returned profile.
	main.quit_to_title()
	main.get_node("Title").play()
	assert_array(shown).is_equal(["ludus", "armamentarium", "ludus"])
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_array(shown).is_equal(["ludus", "armamentarium", "ludus"])
	# A bare enter_grounds (a test's) is no arrival's end.
	main.enter_grounds()
	assert_array(shown).has_size(3)


## A quit to title during a walk's fade back: that arrival never ends (the room it lifted on is
## not the one Play brings back); Play's own does.
func test_a_quit_during_a_walks_fade_back_ends_no_arrival() -> void:
	var main := _grounds_main()
	var shown: Array[String] = []
	main.room_shown.connect(func(id: String) -> void: shown.append(id))
	await stand_at(main, "door:armamentarium")
	await interact()
	await wait_until(func() -> bool: return main.grounds.room_def.id == "armamentarium", "the armamentarium to mount", 60)
	assert_float(_fade(main)).is_greater(0.0)  # the fade back is under way
	main.quit_to_title()
	Profile.save.set_flag("returned", true)
	main.get_node("Title").play()
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_array(shown).is_equal(["ludus"])  # Play's, not the walk's
	assert_float(_fade(main)).is_equal(0.0)


## The same during the gate screen's pass's fade back.
func test_a_quit_during_the_gate_passs_fade_back_ends_no_arrival() -> void:
	var main: Main = quiet_main(3)
	var shown: Array[String] = []
	main.room_shown.connect(func(id: String) -> void: shown.append(id))
	await fall_to_the_gate(main)
	await get_tree().process_frame
	Input.action_press("ui_accept")
	await ticks(2)
	Input.action_release("ui_accept")
	await wait_until(func() -> bool: return main.grounds != null, "the pass to mount the Ludus", 60)
	assert_float(_fade(main)).is_greater(0.0)
	main.quit_to_title()
	assert_bool(main.get_node("Title").is_open()).is_true()
	main.get_node("Title").play()
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_array(shown).is_equal(["ludus"])  # Play's, not the pass's
	assert_float(_fade(main)).is_equal(0.0)


## An unknown room is an error and goes nowhere: no arrival, no walk, no music changed.
func test_an_unknown_room_is_an_error_and_goes_nowhere() -> void:
	var main := _grounds_main()
	await assert_error(func() -> void: main.enter_grounds("forum")).is_push_error("Main: no room 'forum' to enter")
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_int(_arrivals).is_equal(1)
	await assert_error(func() -> void: main._go_to_room("forum")).is_push_error("Main: no room 'forum' to walk to")
	assert_float(_fade(main)).is_equal(0.0)
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	await assert_error(func() -> void: Audio._on_room_entered("forum")).is_push_error("Audio: no room 'forum' for its music")
	assert_str(Audio.current_music).is_equal("music_grounds")
