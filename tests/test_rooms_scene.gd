extends SceneSuite
## The grounds as five rooms joined by doors: each room built from its GroundsRoomDef (a gap in
## the wall for each open door, the gap closed by the door's blocker, a door interactable on the
## floor before it, the room's stations), E on a door walks to the room behind it (the fade, the
## new room with the gladiator before the door back, room_entered on the bus, no revive and no
## second grounds_entered), the Spoliarium's door hidden until it has been seen, the lift in the
## Hypogeum starting the run on the title's pending seed, the camera held to the room's size,
## and a restart or a quit during a room's fade leaving no black.

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
## and takes the fade with it; the harness has no reload.) R there does nothing (the grounds have
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
