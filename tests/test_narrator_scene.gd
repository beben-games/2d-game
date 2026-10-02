extends SceneSuite
## The narrator at the verdict, on the fixture story: the text box's timed mode carries one line
## through the camera's drift and the pause on the box (verdict_wait) and another under the thumb
## (verdict_up, or verdict_down with verso), at the bottom of the view with a dark portrait and
## no name, in a window one line tall; no pause, no input taken, the box's open flag never set. The window is gone before
## the fade and so when the gate screen opens; a win shows none; the events played are in the
## save the run's close writes; with no narrator event the scene is as it was. The timed mode
## and the box's normal mode never share the labels: a play takes the box over from a timed line.

const FIXTURE := "res://tests/support/story"

var _started: Array[String] = []


func before_test() -> void:
	super()
	_started = []
	Events.event_started.connect(_on_started)


func after_test() -> void:
	Events.event_started.disconnect(_on_started)
	await super()


func _on_started(id: String) -> void:
	_started.append(id)


## A quiet Main in the arena on the fixture story, the crowd at `favour` (the run's band).
func _arena(favour := 60.0) -> Main:
	use_story(FIXTURE)
	var main: Main = quiet_main(3)
	RunState.favour = favour
	return main


## A lethal chaser beside the player at 1 hp; the fall lands within a few ticks.
func _fall(main: Main) -> void:
	var player := player_of(main)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).is_true()


func _thumb(main: Main) -> ThumbSign:
	return main.get_node("Room/ThumbSign")


## The window's line as shown (the marker stripped), checked up and timed at the bottom of the
## view with the narrator's silhouette and no name, the box's open flag never set, the tree
## running.
func _assert_window(main: Main, text: String) -> void:
	var box := main.dialogue_box
	assert_bool(box.is_timed()).override_failure_message("no timed line is up").is_true()
	assert_bool(box.visible).is_true()
	assert_bool(box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_str(box.line_label.text).is_equal(text)
	assert_bool(box.at_top()).is_false()
	assert_vector(box.box.size).is_equal(DialogueBox.TIMED_BOX_SIZE)  # the timed window: one line tall
	assert_bool(box.portrait.visible).is_true()
	assert_that((box.portrait.texture as AtlasTexture).region).is_equal(SpriteAtlas.region("wizzard_m_idle_anim", 0))
	assert_that(box.portrait.modulate).is_equal(DialogueBox.SILHOUETTE)
	assert_bool(box.name_label.visible).is_false()


func test_the_wait_line_shows_through_the_drift_and_the_pause_and_nothing_pauses() -> void:
	var main := _arena()
	await _fall(main)
	await get_tree().process_frame
	assert_bool(main.dialogue_box.is_timed()).is_false()  # the hold: the hush alone
	await real_seconds(Main.VERDICT_HOLD + 0.1)
	assert_bool(main.camera.drifting).is_true()
	_assert_window(main, "The sand waits.")
	assert_array(_started).contains_exactly(["narrator.wait"])
	assert_bool(main.build_screen.blocked.call()).is_true()  # the run has ended: the pause screen stays shut, as before
	await real_seconds(Main.VERDICT_DRIFT + Main.VERDICT_PAUSE - 0.3)  # the pause on the box, before the thumb
	assert_bool(_thumb(main).visible).is_false()
	_assert_window(main, "The sand waits.")
	assert_bool(main.dialogue_box.is_revealing()).is_false()  # whole, with no mark: nothing to press
	assert_bool(main.dialogue_box.more_mark.visible).is_false()


func test_the_up_line_comes_with_the_thumb_and_is_gone_when_the_gate_opens() -> void:
	var main := _arena()
	await _fall(main)
	await real_seconds(Main.VERDICT_HOLD + Main.VERDICT_DRIFT + Main.VERDICT_PAUSE + 0.1)
	assert_bool(_thumb(main).visible).is_true()
	assert_bool(_thumb(main).up).is_true()
	_assert_window(main, "Up. Rise.")
	assert_array(_started).contains_exactly(["narrator.wait", "narrator.up"])
	await real_seconds(Main.VERDICT_SHOW - 0.3)  # the thumb's stay: the line holds through it
	_assert_window(main, "Up. Rise.")
	await real_seconds(0.3 + Main.FADE_TIME + 0.2)
	var gate: GateScreen = main.get_node("GateScreen")
	assert_bool(gate.is_open()).is_true()
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_bool(main.dialogue_box.visible).is_false()


## verso turns the thumb down, and the fixture's down line reads the run before this one (a fall
## at Boo): the verdict's lines are chosen before the run is banked.
func test_verso_puts_the_down_line_under_the_thumb() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main()
	RunState.start_run(-1, {"thumbs_down": true})
	Profile.save.log_run({"outcome": "fall", "verdict": "up", "bands": [0]})
	Profile.save.flags["runs"] = 1
	await _fall(main)
	await real_seconds(Main.VERDICT_HOLD + Main.VERDICT_DRIFT + Main.VERDICT_PAUSE + 0.1)
	assert_bool(_thumb(main).up).is_false()
	_assert_window(main, "Down, and dragged.")
	assert_str(_started.back()).is_equal("narrator.down")


## The run's band is the moment's fact: at Boo the fixture's wait_boo outranks the filler.
func test_the_wait_line_reads_the_runs_band() -> void:
	var main := _arena(10.0)
	await _fall(main)
	await real_seconds(Main.VERDICT_HOLD + 0.1)
	_assert_window(main, "Booed, and waiting.")
	assert_array(_started).contains_exactly(["narrator.wait_boo"])


## With no line for the thumb the wait's line goes with the pause: never a stale line under the
## thumb.
func test_a_thumb_with_no_line_takes_the_wait_line_down() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main()
	RunState.start_run(-1, {"thumbs_down": true})  # a first run: the fixture's down line is not eligible
	await _fall(main)
	await real_seconds(Main.VERDICT_HOLD + 0.1)
	assert_bool(main.dialogue_box.is_timed()).is_true()
	await real_seconds(Main.VERDICT_DRIFT + Main.VERDICT_PAUSE)
	assert_bool(_thumb(main).up).is_false()
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_bool(main.dialogue_box.visible).is_false()


func test_a_win_shows_no_window() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main_with_series(tiny_series(1))
	Events.round_cleared.emit()
	var seen := [false]
	for i in int((Main.WIN_HOLD + Main.VERDICT_SHOW + Main.FADE_TIME + 0.3) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if main.dialogue_box.visible:
			seen[0] = true
	assert_bool((main.get_node("GateScreen") as GateScreen).is_open()).is_true()
	assert_bool(seen[0]).is_false()
	assert_array(_started).is_empty()


## The events count as played at the verdict and reach the disk with the run's commit.
func test_the_played_events_are_in_the_save_after_the_runs_commit() -> void:
	var main := _arena()
	await fall_to_the_gate(main)
	var on_disk := Save.load_from(PROFILE_SCRATCH)
	assert_int(on_disk.story_played("narrator.wait")).is_equal(1)
	assert_int(on_disk.story_played("narrator.up")).is_equal(1)
	assert_int(on_disk.runs.size()).is_equal(1)


## The empty fixture (no narrator event): no window at any point of the scene, and the scene runs
## to the gate as before.
func test_an_empty_narrator_pool_leaves_the_scene_as_it_was() -> void:
	var main: Main = quiet_main(3)
	await _fall(main)
	await real_seconds(Main.VERDICT_HOLD + 0.1)
	assert_bool(main.dialogue_box.visible).is_false()
	await real_seconds(Main.VERDICT_DRIFT + Main.VERDICT_PAUSE)
	assert_bool(_thumb(main).visible).is_true()
	assert_bool(main.dialogue_box.visible).is_false()
	await real_seconds(Main.VERDICT_SHOW + Main.FADE_TIME + 0.2)
	assert_bool((main.get_node("GateScreen") as GateScreen).is_open()).is_true()
	assert_array(_started).is_empty()


## A run's leftovers are cleared at the next run's start: a timed line still up goes with them.
func test_a_new_run_takes_a_timed_line_down() -> void:
	var main := _arena()
	main.dialogue_box.show_timed("narrator", "Still here.")
	main.restart()
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_bool(main.dialogue_box.visible).is_false()


## The timed mode in the grounds: the line up, nothing paused, the box not open, and E still
## reaches the post (no input is the window's; nothing under it is blocked).
func test_a_timed_line_takes_no_input_and_blocks_nothing() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main()
	main.enter_grounds()
	Profile.save.mark_story_played("lanista.first_word")  # the keeper has nothing new: E opens the panel at once
	Profile.save.mark_story_played("lanista.arrival")
	var box := main.dialogue_box
	box.show_timed("narrator", "Still here.", true)
	assert_bool(box.is_timed()).is_true()
	assert_bool(box.at_top()).is_true()
	assert_bool(box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(main.build_screen.blocked.call()).is_false()
	await stand_at(main, "post")
	await interact()
	assert_bool((main.get_node("TrainingPanel") as TrainingPanel).is_open()).is_true()
	assert_bool(box.is_timed()).is_true()  # the E was the post's
	for control in box.box.find_children("*", "Control", true, false):
		assert_int((control as Control).mouse_filter).override_failure_message("%s takes the mouse" % control.name).is_equal(Control.MOUSE_FILTER_IGNORE)
	box.hide_timed()
	assert_bool(box.visible).is_false()


## A play over a timed line takes the box over (the timed line hidden first), and a late
## hide_timed leaves the play's box alone; a timed line while an event plays is refused.
func test_a_play_takes_the_box_over_from_a_timed_line() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main()
	main.enter_grounds()
	var box := main.dialogue_box
	box.show_timed("narrator", "Still here.")
	box.play(Story.catalog.by_id["veteran.grumble"])
	assert_bool(box.is_timed()).is_false()
	assert_bool(box.is_open()).is_true()
	assert_vector(box.box.size).is_equal(DialogueBox.BOX_SIZE)
	assert_str(box.name_label.text).is_equal("Veteran")
	assert_bool(box.name_label.visible).is_true()
	assert_str(box.line_label.text).is_equal("Sand in everything.")
	assert_that(box.portrait.modulate).is_equal(Color.WHITE)
	box.hide_timed()  # the timed line's owner, late
	assert_bool(box.is_open()).is_true()
	assert_bool(box.visible).is_true()
	await assert_error(func() -> void: box.show_timed("narrator", "Not now.")).is_push_error("DialogueBox: a timed line while an event plays")
	assert_str(box.line_label.text).is_equal("Sand in everything.")
	await through_box(main)
	assert_bool(get_tree().paused).is_false()
