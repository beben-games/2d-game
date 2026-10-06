extends SceneSuite
## The lifts in the Hypogeum (M7 Task 11): a bay a tier on the top wall (the def's lift_tiers,
## tier 1's at the centre); a tier the save may fight (Save.highest_tier()) that has a series is
## an open Lift, E on it rides into a run of that tier; any other bay is shut and dark with
## nothing to focus or press. The first showing of the Hypogeum after an unlock raises the newest
## open bay once (its sound, then unlocks.lifts_seen written to disk); a later showing does not.
## The tier is the run's from its start, kept by a restart; the title's seed and cheats go to
## whichever lift is ridden first. The profile is SceneSuite's scratch.

var _rounds: Array = []


func before_test() -> void:
	super()
	_rounds = []
	Events.round_started.connect(_on_round_started)


func after_test() -> void:
	Events.round_started.disconnect(_on_round_started)
	await super()


func _on_round_started(index: int, total: int) -> void:
	_rounds.append([index, total])


func _key_cap(main: Main) -> KeyCap:
	return main.get_node("Prompt/KeyCap")


func _fade(main: Main) -> float:
	return (main.get_node("Fade/Black") as ColorRect).color.a


## Where the gladiator would stand under the bay of `tier`: the floor row below its gap.
func _under_bay(grounds: Grounds, tier: int) -> Vector2:
	var bay := grounds.lift_bay(tier)
	return bay.global_position + Vector2(ArenaGrid.TILE, ArenaGrid.TILE * 2.5)


func _gap_of(grounds: Grounds, tier: int) -> Rect2:
	var def := grounds.room_def
	return ArenaGrid.bay_gaps(def.width, def.height, def.lift_tiers.size())[def.lift_tiers.find(tier)]


func _cut(grounds: Grounds, tier: int) -> bool:
	return ArenaGrid.cells_in(_gap_of(grounds, tier)).all(func(cell: Vector2i) -> bool:
		return grounds.arena.tiles.get_cell_source_id(cell) == -1)


func _drawn(grounds: Grounds, tier: int) -> bool:
	return ArenaGrid.cells_in(_gap_of(grounds, tier)).all(func(cell: Vector2i) -> bool:
		return grounds.arena.tiles.get_cell_source_id(cell) != -1)


func _sprite_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	for child in node.get_children():
		if child is Sprite2D:
			names.append(child.name)
	return names


func test_a_new_save_opens_only_tier_1s_lift_and_the_shut_bays_take_nothing() -> void:
	var main: Main = quiet_main()
	_rounds = []  # the boot's round 0 is not the lift's
	main.enter_grounds("hypogeum")
	var grounds := main.grounds
	var lift := grounds.lift(1)
	assert_object(lift).is_not_null()
	assert_bool(lift.enabled).is_true()
	assert_vector(lift.position).is_equal(ArenaGrid.door_gap(grounds.room_def.width, grounds.room_def.height, ArenaGrid.Side.TOP).position)
	assert_bool(_cut(grounds, 1)).is_true()
	for tier in [2, 3]:
		assert_object(grounds.interactable(Lift.id_for(tier))).is_null()
		var bay := grounds.lift_bay(tier)
		assert_object(bay).override_failure_message("no bay for tier %d" % tier).is_not_null()
		assert_bool(bay is Interactable).is_false()
		assert_that(bay.modulate).is_equal(Lift.SHUT_MODULATE)
		assert_array(_sprite_names(bay)).contains_exactly(["doors_frame_left", "doors_frame_right", "doors_leaf_closed"])
		assert_bool(_drawn(grounds, tier)).override_failure_message("the wall is cut under tier %d's shut bay" % tier).is_true()
	# Under a shut bay: no focus, no key cap, and E does nothing.
	var player := player_of(main)
	player.global_position = _under_bay(grounds, 2)
	await ticks(6)
	assert_object(grounds.focus).is_null()
	assert_object(_key_cap(main).target).is_null()
	await get_tree().process_frame
	assert_bool(_key_cap(main).visible).is_false()
	await interact()
	await ticks(int(Main.FADE_TIME * 60.0) + 5)
	assert_object(main.grounds).is_same(grounds)
	assert_float(_fade(main)).is_equal(0.0)
	assert_array(_rounds).is_empty()
	assert_bool(get_tree().paused).is_false()


func test_with_tier_2_unlocked_its_lift_rides_into_a_tier_2_run_that_a_restart_keeps() -> void:
	Profile.save.unlock_tier(2)
	Profile.save.see_lifts(2)  # seen: no rise
	var main: Main = quiet_main()
	main.enter_grounds("hypogeum")
	var lift := main.grounds.lift(2)
	assert_object(lift).is_not_null()
	assert_bool(lift.enabled).is_true()
	assert_that(lift.modulate).is_equal(Color.WHITE)
	assert_bool(_cut(main.grounds, 2)).is_true()
	assert_object(main.grounds.interactable(Lift.id_for(3))).is_null()  # no series: shut
	await stand_at(main, Lift.id_for(2))
	assert_object(_key_cap(main).target).is_same(lift)
	await interact()
	assert_int(RunState.tier).is_equal(1)  # the fade under way: the tier changes only as the run starts
	await wait_until(func() -> bool: return main.grounds == null, "the lift to take the grounds down", 60)
	await real_seconds(Main.FADE_TIME + 0.2)
	main.room.wave_runner.enabled = false
	assert_int(RunState.tier).is_equal(2)
	assert_int(RunState.run_tier).is_equal(2)
	assert_int(main.series_def.tier).is_equal(2)
	assert_int(main.room.width).is_equal(56)
	assert_int(main.room.height).is_equal(30)
	# R: the next run is the same tier's (in the game the reload reads it; here the next start).
	main.restart()
	assert_int(RunState.tier).is_equal(2)
	main.call("_start_run", 5, {})
	main.room.wave_runner.enabled = false
	assert_int(main.series_def.tier).is_equal(2)
	assert_int(RunState.run_tier).is_equal(2)
	assert_int(main.room.width).is_equal(56)


func test_the_first_showing_after_the_unlock_raises_the_new_lift_once() -> void:
	Profile.save.unlock_tier(2)
	var main: Main = quiet_main()
	main.enter_grounds()
	await go_through(main, "hypogeum")
	var grounds := main.grounds
	var lift := grounds.lift(2)
	assert_object(lift).is_not_null()
	assert_int(plays("lift_open")).is_equal(1)
	assert_bool(lift.enabled).is_false()  # rising
	assert_bool(_cut(grounds, 2)).is_true()  # the opening shows behind the rising leaf
	player_of(main).global_position = lift.stand_position()
	await ticks(4)
	assert_object(grounds.focus).is_null()
	assert_object(_key_cap(main).target).is_null()
	await wait_until(func() -> bool: return lift.enabled, "the lift to rise open", int(Lift.LIFT_RISE * 60.0) + 30)
	await wait_until(func() -> bool: return grounds.focus == lift, "the risen lift to take the focus", 30)
	assert_that(lift.modulate).is_equal(Color.WHITE)
	await get_tree().process_frame
	assert_array(_sprite_names(lift)).contains_exactly(["doors_frame_left", "doors_frame_right", "doors_leaf_open"])
	assert_int(int(Save.load_from(PROFILE_SCRATCH).unlocks["lifts_seen"])).is_equal(2)  # written to disk
	# A second showing: open at once, no rise, no sound.
	await go_through(main, "ludus")
	await go_through(main, "hypogeum")
	assert_int(plays("lift_open")).is_equal(1)
	assert_bool(main.grounds.lift(2).enabled).is_true()
	assert_that(main.grounds.lift(2).modulate).is_equal(Color.WHITE)


func test_tier_3s_bay_is_shut_and_never_rises() -> void:
	Profile.save.unlock_tier(3)  # an unlock past the shipped tiers: tier 3 has no series in phase 1
	var main: Main = quiet_main()
	main.enter_grounds()
	await go_through(main, "hypogeum")
	assert_int(plays("lift_open")).is_equal(1)  # tier 2's, the newest open bay
	assert_object(main.grounds.lift(3)).is_null()
	assert_that(main.grounds.lift_bay(3).modulate).is_equal(Lift.SHUT_MODULATE)
	await wait_until(func() -> bool: return main.grounds.lift(2).enabled, "tier 2's lift to rise open", int(Lift.LIFT_RISE * 60.0) + 30)
	assert_int(int(Save.load_from(PROFILE_SCRATCH).unlocks["lifts_seen"])).is_equal(2)
	await go_through(main, "ludus")
	await go_through(main, "hypogeum")
	assert_int(plays("lift_open")).is_equal(1)
	assert_object(main.grounds.lift(3)).is_null()


func test_the_titles_seed_and_cheats_go_to_the_lift_ridden() -> void:
	Profile.save.set_flag("returned", true)
	Profile.save.unlock_tier(2)
	Profile.save.see_lifts(2)
	var main: Main = quiet_main()
	main.play(77, {"immortal": true})
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	await take_the_lift(main, 2)
	assert_int(RunState.seed_value).is_equal(77)
	assert_that(RunState.cheats).is_equal({"immortal": true})
	assert_int(RunState.run_tier).is_equal(2)
	assert_int(main.room.width).is_equal(56)
