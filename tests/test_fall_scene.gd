extends SceneSuite
## The run's end in Main: the fall (the gladiator flat, the hush), the verdict (the thumb over
## the box, its sound, the banking), the gate screen after the fade, and the yield (R, Restart,
## Quit to title: the coins lost, a fall counted, no verdict). The profile is at SceneSuite's
## scratch path, so the commits here never touch the player's save.

var _verdicts: Array[bool] = []
var _endings: Array[String] = []


func before_test() -> void:
	super()
	_verdicts = []
	_endings = []
	Events.verdict_given.connect(_on_verdict)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.verdict_given.disconnect(_on_verdict)
	Events.run_ended.disconnect(_on_run_ended)
	await super()  # the base awaits a frame


func _on_verdict(up: bool) -> void:
	_verdicts.append(up)


func _on_run_ended(outcome: String) -> void:
	_endings.append(outcome)


func _gate(main: Node) -> GateScreen:
	return main.get_node("GateScreen")


func _thumb(main: Node) -> ThumbSign:
	return main.get_node("Room/ThumbSign")


func _fade_alpha(main: Node) -> float:
	return (main.get_node("Fade/Black") as ColorRect).color.a


## A lethal chaser beside the player at 1 hp; the fall lands within a few ticks.
func _fall(main: Node) -> void:
	var player := player_of(main)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).is_true()


func _wait_verdict() -> void:
	await real_seconds(Main.VERDICT_HOLD + 0.1)


func _wait_gate() -> void:
	await real_seconds(Main.VERDICT_SHOW + Main.FADE_TIME + 0.2)


func test_a_fall_lays_the_gladiator_flat_and_the_thumb_comes_up() -> void:
	var main := quiet_main(3)
	var player := player_of(main)
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	RunState.add_coins(7)
	assert_bool(_thumb(main).visible).is_false()
	await _fall(main)
	assert_bool(player.sprite.visible).is_true()
	assert_float(player.sprite.rotation).is_equal_approx(-PI / 2, 0.001)
	assert_bool(runner.enabled).is_false()
	assert_int(plays("crowd_hush")).is_equal(1)
	assert_int(plays("player_die")).is_equal(1)
	assert_bool(_thumb(main).visible).is_false()
	assert_array(_verdicts).is_empty()
	await _wait_verdict()
	assert_bool(_thumb(main).visible).is_true()
	assert_bool(_thumb(main).up).is_true()
	assert_array(_verdicts).contains_exactly([true])
	assert_array(_endings).contains_exactly(["fall"])
	assert_int(plays("verdict_up")).is_equal(1)
	assert_bool(_gate(main).visible).is_false()
	await _wait_gate()
	assert_bool(_gate(main).visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_float(_fade_alpha(main)).is_equal_approx(1.0, 0.01)
	assert_int(_gate(main).layer).is_greater(main.get_node("Fade").layer)
	assert_str(_gate(main).title.text).is_equal("Porta Triumphalis")
	assert_str(_gate(main).run_label.text).contains("Rounds 0/%d" % main.series_def.rounds.size())
	assert_str(_gate(main).run_label.text).contains("Coins earned 7\nCoins kept 7")
	assert_int(Profile.save.money).is_equal(7)
	assert_int(Profile.save.stat("coins_earned")).is_equal(7)
	assert_int(Profile.save.flags["runs"]).is_equal(1)
	assert_int(Profile.save.flags["falls"]).is_equal(1)
	assert_int(Profile.save.flags["wins"]).is_equal(0)
	assert_int(Profile.save.flags["deaths"]).is_equal(0)
	assert_int(Profile.save.runs.size()).is_equal(1)
	var record: Dictionary = Profile.save.runs[0]
	assert_str(record["outcome"]).is_equal("fall")
	assert_str(record["verdict"]).is_equal("up")
	assert_int(record["coins_earned"]).is_equal(7)
	assert_int(record["coins_kept"]).is_equal(7)
	assert_int(record["hits"]).is_equal(1)
	assert_int(record["seed"]).is_equal(3)
	assert_str(record["build"]["weapon"]).is_equal("handgun")
	assert_bool(FileAccess.file_exists(SceneSuite.PROFILE_SCRATCH)).is_true()
	# The deadliest enemy is the chaser: its portrait plays, its line under it.
	assert_bool(_gate(main).portrait_box.visible).is_true()
	assert_bool(_gate(main).portrait.is_playing()).is_true()
	assert_str(_gate(main).portrait_label.text).is_equal("Imp hit you 1 time")
	assert_bool(_gate(main).portrait_label.visible).is_true()


func test_verso_turns_the_thumb_down_and_loses_the_coins() -> void:
	var main := quiet_main()
	RunState.start_run(-1, {"thumbs_down": true})
	RunState.add_coins(7)
	await _fall(main)
	await _wait_verdict()
	assert_bool(_thumb(main).visible).is_true()
	assert_bool(_thumb(main).up).is_false()
	assert_array(_verdicts).contains_exactly([false])
	assert_int(plays("verdict_down")).is_equal(1)
	assert_int(plays("verdict_up")).is_equal(0)
	await _wait_gate()
	assert_str(_gate(main).title.text).is_equal("Porta Libitinaria")
	assert_str(_gate(main).run_label.text).contains("Coins earned 7\nCoins kept 0")
	assert_int(Profile.save.money).is_equal(0)
	assert_int(Profile.save.stat("coins_lost")).is_equal(7)
	assert_int(Profile.save.flags["deaths"]).is_equal(1)
	assert_int(Profile.save.flags["falls"]).is_equal(1)
	assert_int(Profile.save.stat("deaths_by", "chaser")).is_equal(1)
	assert_str(Profile.save.runs[0]["verdict"]).is_equal("down")
	assert_str(Profile.save.runs[0]["cheats"]).is_equal("thumbs_down")


func test_a_win_reaches_the_gate_with_the_boss_piles_banked() -> void:
	var main := quiet_main_with_series(boss_series())
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	runner.enabled = true
	var boss: Boss = null
	for i in 600:  # the runner places it after the breather; boss_spawned ends its fade-in
		await get_tree().physics_frame
		boss = get_tree().get_first_node_in_group("boss") as Boss
		if boss != null and boss.is_harmful():
			break
	assert_object(boss).is_not_null()
	assert_bool(boss.is_harmful()).is_true()
	await ticks(6)  # some fight time for boss_time_best
	RunState.favour = FavourRules.MAX  # the round ends at Roar: a perfect run
	boss.health.take_damage(1000.0)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await get_tree().physics_frame
	assert_array(_endings).is_empty()  # the win holds on the corpse first
	await real_seconds(Main.WIN_HOLD + 0.1)
	# No emperor's decision on a win: no thumb, no verdict_given; the fanfare plays once, on the win.
	assert_bool(_thumb(main).visible).is_false()
	assert_array(_verdicts).is_empty()
	assert_int(plays("verdict_up")).is_equal(1)
	assert_array(_endings).contains_exactly(["win"])
	assert_int(main.get_node("Room/Piles").get_child_count()).is_equal(0)  # swept into the run's coins
	await _wait_gate()
	assert_bool(_thumb(main).visible).is_false()
	assert_array(_verdicts).is_empty()
	assert_int(plays("verdict_up")).is_equal(1)
	assert_bool(_gate(main).visible).is_true()
	assert_str(_gate(main).title.text).is_equal("Porta Triumphalis")
	assert_int(Profile.save.money).is_equal(boss.def.coins)
	assert_int(Profile.save.flags["wins"]).is_equal(1)
	assert_int(Profile.save.flags["runs"]).is_equal(1)
	assert_int(Profile.save.flags["falls"]).is_equal(0)
	assert_int(Profile.save.flags["perfect_runs"]).is_equal(1)
	assert_float(Profile.save.stat("boss_time_best")).is_greater(0.0)
	assert_int(Profile.save.stat("best_run")["rounds"]).is_equal(1)
	var record: Dictionary = Profile.save.runs[0]
	assert_str(record["outcome"]).is_equal("win")
	assert_int(record["rounds"]).is_equal(1)
	assert_array(record["bands"]).has_size(1)


func test_a_win_sweeps_the_piles_on_the_floor_into_the_bank() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var player := player_of(main)
	RunState.add_coins(3)
	var pile: CoinPile = load("res://scenes/coin_pile.tscn").instantiate()
	pile.value = 12
	main.get_node("Room/Piles").add_child(pile)
	pile.land(player.global_position + Vector2(180, 0))  # beyond the pull's reach: the sweep, not the pull, pays it
	Events.round_cleared.emit()
	await real_seconds(Main.WIN_HOLD + 0.1)
	assert_int(main.get_node("Room/Piles").get_child_count()).is_equal(0)
	assert_int(RunState.coins).is_equal(15)
	await _wait_gate()
	assert_int(Profile.save.money).is_equal(15)
	assert_str(_gate(main).run_label.text).contains("Coins earned 15\nCoins kept 15")


func test_a_fall_during_the_win_hold_keeps_the_win() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var player := player_of(main)
	Events.round_cleared.emit()
	await real_seconds(Main.WIN_HOLD * 0.5)  # inside the win's beat
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	await real_seconds(Main.WIN_HOLD + 0.1)
	assert_bool(_thumb(main).visible).is_false()
	await _wait_gate()
	assert_bool(_gate(main).visible).is_true()
	assert_array(_verdicts).is_empty()
	assert_array(_endings).contains_exactly(["win"])
	assert_int(Profile.save.flags["wins"]).is_equal(1)
	assert_int(Profile.save.flags["falls"]).is_equal(0)


## The verdict scene cannot be skipped: between the fall and the gate screen R, Restart, and Quit
## to title do nothing, and the run is recorded once, at the verdict.
func test_a_restart_during_the_verdict_scene_does_nothing() -> void:
	var main := quiet_main(3)
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await _fall(main)
	await real_seconds(Main.VERDICT_HOLD * 0.5)  # before the thumb
	var press := InputEventAction.new()
	press.action = "restart"
	press.pressed = true
	Input.parse_input_event(press)
	await ticks(2)
	Input.action_release("restart")
	assert_int(restarts[0]).is_equal(0)
	assert_array(_endings).is_empty()
	await _wait_verdict()
	assert_bool(_thumb(main).visible).is_true()
	main.quit_to_title()  # under the thumb, before the gate screen
	main.restart()
	assert_int(restarts[0]).is_equal(0)
	assert_bool(main.get_node("Title").is_open()).is_false()
	await _wait_gate()
	assert_bool(_gate(main).visible).is_true()
	assert_float(_fade_alpha(main)).is_equal_approx(1.0, 0.01)
	assert_array(_endings).contains_exactly(["fall"])
	assert_int(Profile.save.flags["runs"]).is_equal(1)
	assert_int(Profile.save.runs.size()).is_equal(1)
	assert_str(Profile.save.runs[0]["outcome"]).is_equal("fall")


## A click landing in the frame the screen appears does not pass the gate; the next frame's does.
## The screen is opened from a timer's continuation, as Main opens it (after the frame's
## _process, so the next frame's input flush is still the opening frame for _just_opened); a
## test body resumed by process_frame runs before _process, where the flag would be cleared
## under the click.
func test_a_click_passes_the_gate_only_from_the_frame_after_it_opens() -> void:
	var main := quiet_main(3)
	var gate := _gate(main)
	await get_tree().create_timer(0.0, true, false, true).timeout
	gate.show_gate(true, {}, Profile.save)
	_click()
	await get_tree().process_frame
	assert_int(plays("gate")).is_equal(0)
	assert_bool(gate.is_open()).is_true()
	_click()
	await get_tree().process_frame
	assert_bool(gate.is_open()).is_false()
	assert_int(plays("gate")).is_equal(1)
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_object(main.grounds).is_not_null()


## A left press and its release, fed to Input: the release too, or the button (the shoot action)
## stays held for every later suite.
## A press and its release fed in the caller's frame, not SceneSuite.click_control: this suite's
## one click test is about the frame the screen opens in, and the screen reads any click in
## _input, so the pixels do not matter (a frame's await between the two would move the press
## past the opening frame).
func _click() -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = Vector2(640, 360)
		Input.parse_input_event(click)


func test_a_restart_mid_run_is_a_yield() -> void:
	var main := quiet_main(3)
	RunState.add_coins(5)
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	main.restart()
	assert_int(restarts[0]).is_equal(1)
	assert_array(_endings).contains_exactly(["yield"])
	assert_array(_verdicts).is_empty()
	assert_int(Profile.save.money).is_equal(0)
	assert_int(Profile.save.stat("coins_lost")).is_equal(5)
	assert_int(Profile.save.flags["falls"]).is_equal(1)
	assert_int(Profile.save.flags["runs"]).is_equal(1)
	assert_int(Profile.save.runs.size()).is_equal(1)
	assert_str(Profile.save.runs[0]["outcome"]).is_equal("yield")
	assert_str(Profile.save.runs[0]["verdict"]).is_equal("")
	assert_int(Profile.save.runs[0]["coins_earned"]).is_equal(5)
	assert_int(Profile.save.runs[0]["coins_kept"]).is_equal(0)
	assert_bool(FileAccess.file_exists(SceneSuite.PROFILE_SCRATCH)).is_true()
	assert_bool(_thumb(main).visible).is_false()
	assert_int(RunState.coins).is_equal(0)


func test_quit_to_title_mid_run_is_a_yield_and_the_title_is_not() -> void:
	var main := quiet_main(3)
	RunState.add_coins(5)
	main.quit_to_title()
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_array(_endings).contains_exactly(["yield"])
	assert_int(Profile.save.flags["falls"]).is_equal(1)
	main.quit_to_title()  # the title is up: no run to yield
	assert_array(_endings).contains_exactly(["yield"])
	assert_int(Profile.save.flags["falls"]).is_equal(1)


func test_a_restart_after_the_verdict_logs_nothing_more() -> void:
	var main := quiet_main(3)
	await fall_to_the_gate(main)
	main.restart()
	assert_array(_endings).contains_exactly(["fall"])
	assert_int(Profile.save.flags["runs"]).is_equal(1)
	assert_int(Profile.save.runs.size()).is_equal(1)
	assert_bool(_gate(main).visible).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_float(_fade_alpha(main)).is_equal(0.0)


## The pass is no restart: the run is recorded already, and the grounds come up under the black
## (test_flow_scene has the rest of the way back).
func test_ui_accept_on_the_gate_passes_it_into_the_grounds() -> void:
	var main := quiet_main(3)
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await fall_to_the_gate(main)
	assert_bool(_gate(main).visible).is_true()
	await get_tree().process_frame
	Input.action_press("ui_accept")
	await ticks(2)
	Input.action_release("ui_accept")
	assert_int(plays("gate")).is_equal(1)
	assert_int(restarts[0]).is_equal(0)
	assert_bool(_gate(main).visible).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(main.get_node("Title").is_open()).is_false()
	await real_seconds(Main.FADE_TIME * 2.0 + 0.2)
	assert_float(_fade_alpha(main)).is_equal(0.0)
	assert_object(main.grounds).is_not_null()
	assert_object(main.room).is_null()
	assert_array(_endings).contains_exactly(["fall"])


func test_r_on_the_gate_restarts() -> void:
	var main := quiet_main(3)
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await fall_to_the_gate(main)
	await get_tree().process_frame
	Input.action_press("restart")
	await ticks(2)
	Input.action_release("restart")
	assert_int(restarts[0]).is_equal(1)
	assert_int(plays("gate")).is_equal(0)
	assert_bool(_gate(main).visible).is_false()
	assert_bool(main.get_node("Title").is_open()).is_false()


func test_escape_on_the_gate_returns_to_the_title() -> void:
	var main := quiet_main(3)
	await fall_to_the_gate(main)
	await get_tree().process_frame
	Input.action_press("pause")
	await ticks(2)
	Input.action_release("pause")
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_bool(_gate(main).visible).is_false()
	assert_int(plays("gate")).is_equal(0)
	assert_int(Profile.save.flags["runs"]).is_equal(1)  # no yield on top of the verdict


## PLACEHOLDER art until M8: a 24x24 fist (two skin tones and an edge) with the thumb up or
## down, drawn at 2x.
func test_the_thumb_is_a_24_px_fist_in_two_tones_with_an_edge() -> void:
	assert_int(ThumbSign.SIZE).is_equal(24)
	assert_float(ThumbSign.SCALE).is_equal(2.0)
	for up in [true, false]:
		var img := ThumbSign.image(up)
		assert_that(img.get_size()).is_equal(Vector2i(24, 24))
		var colours := {}
		for y in 24:
			for x in 24:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					colours[c.to_html(false)] = true
		assert_array(colours.keys()).contains_exactly_in_any_order(
			[ThumbSign.FILL.to_html(false), ThumbSign.SHADE.to_html(false), ThumbSign.EDGE.to_html(false)])
	# The thumb: a three-wide column above the fist for up, below it for down; the fist wider.
	var up_img := ThumbSign.image(true)
	var down_img := ThumbSign.image(false)
	assert_int(_filled_in_row(up_img, ThumbSign.THUMB.position.y + 1)).is_equal(ThumbSign.THUMB.size.x)
	assert_int(_filled_in_row(up_img, ThumbSign.FIST.position.y + 3)).is_equal(ThumbSign.FIST.size.x)
	assert_int(_filled_in_row(down_img, 24 - 1 - (ThumbSign.THUMB.position.y + 1))).is_equal(ThumbSign.THUMB.size.x)
	assert_int(_filled_in_row(down_img, 0)).is_equal(0)


func _filled_in_row(img: Image, y: int) -> int:
	var n := 0
	for x in img.get_width():
		if img.get_pixel(x, y).a > 0.0:
			n += 1
	return n


func test_the_thumb_sits_over_the_emperors_box() -> void:
	var main := quiet_main(3)
	var room: Room = main.get_node("Room")
	var thumb := _thumb(main)
	assert_float(thumb.global_position.x).is_equal_approx(room.emperor_box.centre().x, 0.5)
	assert_float(thumb.global_position.y).is_less(room.emperor_box.centre().y + ArenaGrid.TILE * 2)
	assert_float(thumb.global_position.y - ThumbSign.SIZE * ThumbSign.SCALE * 0.5).is_greater_equal(room.full_rect().position.y)
