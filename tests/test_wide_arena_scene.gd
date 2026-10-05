extends SceneSuite
## A run on a two-screen series (SceneSuite.wide_series, 56x30): the room, the walls, the box, and
## the camera's limits all come from the size through ArenaGrid; the player enters at the floor's
## centre and walks the arena with the view following, held inside the walls; a round clears.
## The tier the run is fought in (RunState.tier) outlives a restart and goes at a quit to the title.

const WIDE_W := 56
const WIDE_H := 30


func after_test() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	await super()


func test_the_room_the_walls_and_the_box_come_from_the_size() -> void:
	var main := quiet_main_with_series(wide_series())
	var room: Room = main.get_node("Room")
	assert_int(room.width).is_equal(WIDE_W)
	assert_int(room.height).is_equal(WIDE_H)
	assert_object(room.bounds()).is_equal(ArenaGrid.bounds(WIDE_W, WIDE_H))
	assert_object(room.full_rect()).is_equal(ArenaGrid.full_rect(WIDE_W, WIDE_H))
	var walls: Array[Rect2] = []
	for shape: CollisionShape2D in room.arena.walls.get_children():
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		walls.append(Rect2(shape.position - size * 0.5, size))
	assert_array(walls).contains_exactly_in_any_order(ArenaGrid.wall_rects(WIDE_W, WIDE_H, []))
	assert_vector(room.emperor_box.position).is_equal(EmperorBox.position_of(WIDE_W, WIDE_H))
	assert_object(room.emperor_box.gap).is_equal(ArenaGrid.door_gap(WIDE_W, WIDE_H, ArenaGrid.Side.TOP))


func test_the_camera_is_held_to_the_wide_room_and_the_player_enters_at_the_centre() -> void:
	var main := quiet_main_with_series(wide_series())
	var camera: Camera = main.get_node("Player/Camera")
	var full := ArenaGrid.full_rect(WIDE_W, WIDE_H)
	assert_int(camera.limit_left).is_equal(int(full.position.x))
	assert_int(camera.limit_top).is_equal(int(full.position.y))
	assert_int(camera.limit_right).is_equal(int(full.end.x))
	assert_int(camera.limit_bottom).is_equal(int(full.end.y))
	assert_vector(player_of(main).global_position).is_equal(ArenaGrid.bounds(WIDE_W, WIDE_H).get_center())


## Two screens each way: the player walks from wall to wall across the width and down the height,
## and on every tick the view's centre stays where the view shows no void past the walls. At each
## wall the view has followed to its limit.
func test_the_player_walks_two_screens_and_the_view_stays_inside_the_walls() -> void:
	var main := quiet_main_with_series(wide_series())
	var player := player_of(main)
	var camera: Camera = main.get_node("Player/Camera")
	var bounds := ArenaGrid.bounds(WIDE_W, WIDE_H)
	var half := camera.get_viewport_rect().size / camera.zoom * 0.5
	var full := ArenaGrid.full_rect(WIDE_W, WIDE_H)
	assert_float(bounds.size.x).is_greater(half.x * 2.0)  # the floor is wider than a view
	assert_float(bounds.size.y).is_greater(half.y * 2.0)  # and taller
	var centres := full.grow_individual(-half.x + 0.5, -half.y + 0.5, -half.x + 0.5, -half.y + 0.5)
	var outside := [0]
	var watch := func() -> void:
		if not centres.has_point(camera.get_screen_center_position()):
			outside[0] += 1
	get_tree().physics_frame.connect(watch)
	await _walk(player, "move_left", func() -> bool: return player.global_position.x < bounds.position.x + 12.0)
	await _settle(camera)
	assert_float(camera.get_screen_center_position().x).is_equal_approx(full.position.x + half.x, 0.5)
	var start_x := player.global_position.x
	await _walk(player, "move_right", func() -> bool: return player.global_position.x > bounds.end.x - 12.0)
	assert_float(player.global_position.x - start_x).is_greater(half.x * 2.0)  # wall to wall: past a screen's width
	await _settle(camera)
	assert_float(camera.get_screen_center_position().x).is_equal_approx(full.end.x - half.x, 0.5)
	await _walk(player, "move_down", func() -> bool: return player.global_position.y > bounds.end.y - 12.0)
	await _settle(camera)
	assert_float(camera.get_screen_center_position().y).is_equal_approx(full.end.y - half.y, 0.5)
	get_tree().physics_frame.disconnect(watch)
	assert_int(outside[0]).is_equal(0)


func test_a_round_of_tier_1_enemies_clears_in_the_wide_arena() -> void:
	var main := quiet_main_with_series(wide_series(2))
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	await wait_until(func() -> bool: return enemies_of(main).get_child_count() == 1, "the chaser's spawn")
	var chaser := enemies_of(main).get_child(0) as Enemy
	assert_bool(ArenaGrid.bounds(WIDE_W, WIDE_H).has_point(chaser.global_position)).is_true()
	chaser.health.take_damage(1000.0)
	await wait_until(func() -> bool: return RunState.rounds_cleared == 1, "the round's clear")
	assert_int(RunState.kills).is_equal(1)


func test_main_takes_its_series_from_the_tier_unless_one_was_set() -> void:
	var main := quiet_main()
	assert_object(main.series_def).is_same(Tiers.series(RunState.tier))
	var series := wide_series()
	var set_main := quiet_main_with_series(series)
	assert_object(set_main.series_def).is_same(series)


## A series set after Main read the tier's (a test's, a tool's) is the next run's, and stays.
func test_a_series_set_after_the_tier_read_is_the_next_run() -> void:
	var main := quiet_main()
	assert_object(main.series_def).is_same(Tiers.series(1))
	var series := tiny_series(1)
	main.series_def = series
	main.call("_start_run", 5, {})
	(main.get("room") as Room).wave_runner.enabled = false  # the new Room's runner, as below
	assert_object(main.series_def).is_same(series)
	assert_int(RunState.rounds_total).is_equal(1)
	main.call("_start_run", 6, {})
	(main.get("room") as Room).wave_runner.enabled = false
	assert_object(main.series_def).is_same(series)


func test_reset_tier_writes_1_without_asking_tiers() -> void:
	RunState.tier = 2
	RunState.reset_tier()
	assert_int(RunState.tier).is_equal(1)


func test_set_tier_refuses_an_unknown_tier() -> void:
	assert_int(RunState.tier).is_equal(1)
	assert_bool(RunState.set_tier(99)).is_false()
	assert_int(RunState.tier).is_equal(1)
	assert_bool(RunState.set_tier(1)).is_true()
	RunState.start_run()
	assert_int(RunState.tier).is_equal(1)


## Tier 2 has no series until its data lands, so the tier is written straight: the test is that a
## restart keeps whatever tier the run was in, and a set series with it.
func test_a_restart_keeps_the_tier_and_the_set_series() -> void:
	var series := wide_series()
	var main := quiet_main_with_series(series)
	RunState.tier = 2
	main.restart()
	assert_int(RunState.tier).is_equal(2)
	assert_object(main.series_def).is_same(series)
	main.call("_start_run", 5, {})  # the next run (the lift's or Play's) keeps the set series too
	# The run's start built a new Room whose runner is on (quiet() turned off only the first one's);
	# its first wave waits on a timer, so turning it off here, in the same frame, spawns nothing.
	(main.get("room") as Room).wave_runner.enabled = false
	assert_object(main.series_def).is_same(series)
	assert_int((main.get_node("Room") as Room).width).is_equal(WIDE_W)
	assert_int(RunState.tier).is_equal(2)


func test_a_quit_to_the_title_resets_the_tier() -> void:
	var main := quiet_main_with_series(wide_series())
	RunState.tier = 2
	main.quit_to_title()
	assert_int(RunState.tier).is_equal(1)


func test_entering_the_grounds_resets_the_tier() -> void:
	var main := quiet_main()
	RunState.tier = 2
	main.enter_grounds()
	assert_int(RunState.tier).is_equal(1)


## Holds `action` until `arrived` holds (a cap of 900 ticks: about 15 s at the player's speed),
## then lets go and waits for the body to stop.
func _walk(player: Player, action: String, arrived: Callable) -> void:
	Input.action_press(action)
	await wait_until(arrived, "the walk on %s" % action, 900)
	Input.action_release(action)
	await wait_until(func() -> bool: return player.move_vel.is_zero_approx(), "the stop", 120)


## The smoothing caught up, so the view sits where it is going.
func _settle(camera: Camera) -> void:
	await get_tree().process_frame
	camera.reset_smoothing()
	await get_tree().process_frame
