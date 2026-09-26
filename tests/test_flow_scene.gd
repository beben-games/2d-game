extends SceneSuite
## The first-run rule and the way back: Play from the title goes straight to the arena on a
## fresh profile, the gate screen's continue lands in the grounds and saves `returned`, and
## every Play after that goes to the grounds, whose gate starts the run. The profile is at the
## scratch path, so the commits here never touch the player's save.

var _endings: Array[String] = []


func before_test() -> void:
	super()
	_endings = []
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	await get_tree().process_frame  # a stage swapped in the test's last line is freed at the frame's end: flush it before the orphan count
	Events.run_ended.disconnect(_on_run_ended)
	super()


func _on_run_ended(outcome: String) -> void:
	_endings.append(outcome)


func _gate(main: Node) -> GateScreen:
	return main.get_node("GateScreen")


## A lethal chaser beside the player at 1 hp, then the verdict scene through to the gate screen.
func _fall_to_the_gate(main: Main) -> void:
	var player := player_of(main)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).is_true()
	await real_seconds(Main.VERDICT_HOLD + Main.VERDICT_SHOW + Main.FADE_TIME + 0.3)
	assert_bool(_gate(main).is_open()).is_true()


func _wait_fades() -> void:
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)


func test_a_fresh_profile_plays_in_the_arena_and_the_gate_screen_leads_to_the_grounds() -> void:
	var main: Main = quiet_main(3)
	assert_bool(Profile.save.flags["returned"]).is_false()
	main.play()
	main.room.wave_runner.enabled = false
	assert_object(main.room).is_not_null()
	assert_object(main.grounds).is_null()
	assert_object(main.get_node_or_null("Grounds")).is_null()
	await _fall_to_the_gate(main)
	assert_array(_endings).contains_exactly(["fall"])
	await get_tree().process_frame
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	Input.action_press("ui_accept")
	await ticks(2)
	Input.action_release("ui_accept")
	assert_int(int(Audio.plays.get("gate", 0))).is_equal(1)
	assert_bool(_gate(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	main.restart()  # under the pass's fade: the verdict still counts as pending, nothing restarts or yields
	main.quit_to_title()
	assert_int(restarts[0]).is_equal(0)
	assert_bool(main.get_node("Title").is_open()).is_false()
	await _wait_fades()
	assert_object(main.get_node_or_null("Grounds")).is_not_null()
	assert_object(main.room).is_null()
	assert_object(main.get_node_or_null("Room")).is_null()
	assert_bool(hud_of(main).visible).is_false()
	assert_float((main.get_node("Fade/Black") as ColorRect).color.a).is_equal(0.0)
	assert_bool(Profile.save.flags["returned"]).is_true()
	assert_bool(Save.load_from(PROFILE_SCRATCH).flags["returned"]).is_true()
	assert_int(Profile.save.flags["runs"]).is_equal(1)
	assert_str(Audio.current_music).is_equal("music_grounds")
	assert_bool(player_of(main).dead).is_false()
	assert_array(_endings).contains_exactly(["fall"])  # the pass is no ending


func test_a_returned_profile_plays_in_the_grounds_and_the_gate_starts_the_run() -> void:
	var main: Main = quiet_main(3)
	Profile.save.set_flag("returned", true)
	main.play()
	assert_object(main.grounds).is_not_null()
	assert_object(main.room).is_null()
	assert_bool(main.get_node("Title").is_open()).is_false()
	assert_bool(hud_of(main).visible).is_false()
	assert_array(_endings).is_empty()
	player_of(main).global_position = main.grounds.station("gate").stand_position()
	await wait_until(func() -> bool: return main.grounds == null, "the gate to take the grounds down", 60)
	await real_seconds(Main.FADE_TIME + 0.2)
	main.room.wave_runner.enabled = false
	assert_object(main.grounds).is_null()
	assert_object(main.room).is_not_null()
	assert_bool(hud_of(main).visible).is_true()
	assert_int(main.round_index).is_equal(0)


func test_quit_to_title_from_the_grounds_and_play_again_returns_to_them() -> void:
	var main: Main = quiet_main(3)
	Profile.save.set_flag("returned", true)
	main.play()
	assert_object(main.grounds).is_not_null()
	main.quit_to_title()
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_array(_endings).is_empty()  # no run to yield in the grounds
	assert_int(Profile.save.flags["runs"]).is_equal(0)
	main.get_node("Title").play()
	assert_object(main.grounds).is_not_null()
	assert_object(main.room).is_null()
	assert_bool(get_tree().paused).is_false()
	assert_str(Audio.current_music).is_equal("music_grounds")


func test_r_in_the_grounds_is_no_yield() -> void:
	var main: Main = quiet_main(3)
	Profile.save.set_flag("returned", true)
	main.play()
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	main.restart()
	assert_int(restarts[0]).is_equal(1)
	assert_array(_endings).is_empty()
	assert_int(Profile.save.flags["runs"]).is_equal(0)
	assert_int(Profile.save.flags["falls"]).is_equal(0)
