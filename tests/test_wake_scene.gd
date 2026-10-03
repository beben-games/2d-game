extends SceneSuite
## The Spoliarium wake: after a thumbs down and its gate screen (the Porta Libitinaria) the
## gladiator wakes lying in the Spoliarium at the floor's bottom centre, in silence, and rises on
## the first fresh press of a move, the dash, or the interact key (a key held through the black is
## no press, and the press that rises is spent on rising: no step, no dash, and nothing in reach
## interacted with); the profile has seen the room from then
## on (on disk), so the Hypogeum, through the room's one door, shows its door back. A thumbs up
## still lands in the Ludus, standing. The narrator's `enter spoliarium` line (a timed pool's entry
## event) shows in the box's timed window at the top of the view once the black has lifted,
## without a pause, never takes the rising press, and goes after Main.ENTRY_LINE_TIME, with the
## pause screen's opening, or with the room; its late timer never takes a later line down. An
## entry event reads how the gladiator came in (the moment's fact `arrival`: gate, door, start).

const FIXTURE := "res://tests/support/story"
const WAKE_LINE := "Not with the dead. Not yet."  ## the fixture narrator's `enter spoliarium` line
## Entry lines gated on the arrival: `enter spoliarium` on a gate pass, `enter ludus` on Play.
const ARRIVAL_FIXTURE := "res://tests/support/story_arrival"

var _started: Array[String] = []
## music_grounds's entry before a test swapped in a tone (Audio.override_stream's return), {} when
## none was swapped: after_test puts it back.
var _grounds_music: Dictionary = {}


func before_test() -> void:
	super()
	_started = []
	Events.event_started.connect(_on_started)


func after_test() -> void:
	Input.action_release("move_up")
	Events.event_started.disconnect(_on_started)
	if not _grounds_music.is_empty():
		Audio.override_stream("music_grounds", _grounds_music["stream"], float(_grounds_music["min_gap"]))
		_grounds_music = {}
	await super()


func _on_started(id: String) -> void:
	_started.append(id)


## The gate screen opened bare for the verdict `up` (from a timer's continuation, as Main opens
## it), then passed: until the room is up and the black has lifted. The timed window is checked
## shut on every tick the black is still up.
func _bare_pass(main: Main, up: bool) -> void:
	await get_tree().create_timer(0.0, true, false, true).timeout
	main.gate_screen.show_gate(up, {}, Profile.save)
	await pass_the_gate(main, _no_line_under_the_black.bind(main))


func _no_line_under_the_black(main: Main) -> void:
	var fade: ColorRect = main.get_node("Fade/Black")
	if fade.color.a > 0.0:
		assert_bool(main.dialogue_box.is_timed()).override_failure_message("a timed line under the black").is_false()


## A quiet Main woken in the Spoliarium through a bare thumbs-down gate screen.
func _woken(story := STORY_EMPTY) -> Main:
	if story != STORY_EMPTY:
		use_story(story)
	var main: Main = quiet_main()
	await _bare_pass(main, false)
	return main


## True while one of Audio's music players carries a loop.
func _music_playing() -> bool:
	for player_name: String in ["Music0", "Music1"]:
		if (Audio.get_node(player_name) as AudioStreamPlayer).playing:
			return true
	return false


## A looping 0.5 s tone, a music file's stand-in (as the audio suite's): the loops are gitignored,
## so a public clone has none, and Audio.music() starts no player without a stream.
func _looping_tone() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := 22050 / 2
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		data.encode_s16(i * 2, int(sin(float(i) * 0.1) * 12000.0))
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples
	return wav


func test_a_thumbs_down_wakes_the_gladiator_lying_in_the_silent_spoliarium() -> void:
	var main: Main = quiet_main(3)
	RunState.start_run(3, {"thumbs_down": true})
	assert_bool(Profile.save.flags["returned"]).is_false()  # a first run's fall: the wake is the first return
	await fall_to_the_gate(main)
	assert_bool(main.gate_screen.up).is_false()
	assert_str(main.gate_screen.title.text).is_equal(VerdictRules.gate_name(false))
	var grounds_loops := plays("music_grounds")
	await pass_the_gate(main)
	assert_str(main.grounds.room_def.id).is_equal("spoliarium")
	var player := player_of(main)
	assert_bool(player.prone).is_true()
	assert_bool(player.dead).is_false()
	assert_float(player.sprite.rotation).is_equal_approx(-PI / 2, 0.0001)
	var floor_rect := main.grounds.bounds()
	assert_vector(player.global_position).is_equal(Vector2(floor_rect.get_center().x, floor_rect.end.y - ArenaGrid.TILE))
	assert_bool(hud_of(main).visible).is_false()
	# Silence: no loop asked for on the way in (the Ludus's would be), and no music player sounding.
	assert_str(Audio.current_music).is_equal("")
	assert_int(plays("music_grounds")).is_equal(grounds_loops)
	assert_bool(_music_playing()).is_false()
	var on_disk := Save.load_from(PROFILE_SCRATCH)
	assert_bool(on_disk.flags["spoliarium_seen"]).is_true()
	assert_bool(on_disk.flags["returned"]).is_true()
	assert_int(on_disk.flags["deaths"]).is_equal(1)


## A move held down through the black is no press: the gladiator lies on; a fresh press rises.
func test_the_prone_gladiator_ignores_a_held_move_and_rises_on_a_fresh_press() -> void:
	var main: Main = quiet_main()
	Input.action_press("move_up")
	await _bare_pass(main, false)
	var player := player_of(main)
	var at := player.global_position
	await ticks(3)
	assert_bool(player.prone).is_true()
	assert_vector(player.global_position).is_equal(at)
	Input.action_release("move_up")
	await ticks(1)
	# A fresh press through the real input path: the tick that rises takes no step (the wait
	# resumes at the next tick's start, before the body moves again).
	var press := InputEventAction.new()
	press.action = "move_up"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_until(func() -> bool: return not player.prone, "a fresh press to rise the gladiator", 10)
	assert_vector(player.global_position).is_equal(at)
	assert_float(player.sprite.rotation).is_equal(0.0)
	var release := InputEventAction.new()
	release.action = "move_up"
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


## The dash and the interact key rise the gladiator too; the press is spent on rising (no dash).
func test_a_dash_or_an_interact_press_rises_and_the_press_is_spent_on_rising() -> void:
	var main := await _woken()
	var player := player_of(main)
	for action: String in ["dash", "interact"]:
		player.lie()
		await ticks(1)
		var charges := player.dash_charges
		await press_action(action)
		assert_bool(player.prone).override_failure_message("%s did not rise the gladiator" % action).is_false()
		assert_int(player.dash_charges).is_equal(charges)
		assert_float(player.dash_left).is_equal(0.0)
		assert_bool(main.dialogue_box.is_open()).is_false()
		assert_bool(main.training_panel.is_open() or main.armoury_panel.is_open()).is_false()


## The E that rises reaches the grounds as an event before the tick that rises the body: lying in
## the post's reach, it is spent on rising, and the training panel stays shut.
func test_the_rising_e_interacts_with_nothing_in_reach() -> void:
	var main: Main = quiet_main()
	main.enter_grounds()
	await stand_at(main, "post")
	var player := player_of(main)
	player.lie()
	await ticks(1)
	await interact()
	assert_bool(player.prone).is_false()
	assert_bool(main.training_panel.is_open()).is_false()
	assert_bool(main.dialogue_box.is_open()).is_false()
	await interact()  # standing, the same key opens it
	assert_bool(main.training_panel.is_open()).is_true()


func test_the_door_leads_to_the_hypogeum_which_now_shows_its_door_back_and_the_music() -> void:
	_grounds_music = Audio.override_stream("music_grounds", _looping_tone(), 0.0)
	var main := await _woken()
	assert_int(main.grounds.doors().size()).is_equal(1)
	assert_object(main.grounds.door_to("hypogeum")).is_not_null()
	await press_action("move_up")
	await go_through(main, "hypogeum")
	assert_object(main.grounds.door_to("spoliarium")).is_not_null()
	assert_str(Audio.current_music).is_equal("music_grounds")
	assert_bool(_music_playing()).is_true()  # the players do sound: the Spoliarium's silence is theirs
	assert_bool(player_of(main).prone).is_false()


func test_a_thumbs_up_still_lands_in_the_ludus_standing() -> void:
	var main: Main = quiet_main()
	await _bare_pass(main, true)
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_bool(player_of(main).prone).is_false()
	assert_float(player_of(main).sprite.rotation).is_equal(0.0)
	assert_bool(Profile.save.flags["spoliarium_seen"]).is_false()
	assert_str(Audio.current_music).is_equal("music_grounds")


## The narrator's entry line: timed, at the top (the gladiator lies at the bottom), the tree
## running; the rising press is not the box's; gone after ENTRY_LINE_TIME; played and on disk.
func test_the_narrators_entry_line_shows_at_the_top_without_a_pause_and_goes_after_its_time() -> void:
	var main := await _woken(FIXTURE)
	var box := main.dialogue_box
	assert_bool(box.is_timed()).is_true()
	assert_bool(box.visible).is_true()
	assert_bool(box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(box.at_top()).is_true()
	assert_str(box.line_label.text).is_equal(WAKE_LINE)
	assert_array(_started).is_equal(["narrator.wake"])
	assert_int(Save.load_from(PROFILE_SCRATCH).story_played("narrator.wake")).is_equal(1)
	await press_action("interact")
	assert_bool(player_of(main).prone).is_false()
	assert_bool(box.is_timed()).is_true()  # the rise is the gladiator's, never the window's
	assert_str(box.line_label.text).is_equal(WAKE_LINE)
	await real_seconds(Main.ENTRY_LINE_TIME + 0.1)
	assert_bool(box.is_timed()).is_false()
	assert_bool(box.visible).is_false()


## Esc during the line opens the pause screen, which takes the line down (both are on layer 10).
func test_the_pause_screen_takes_the_wakes_line_down() -> void:
	var main := await _woken(FIXTURE)
	assert_bool(main.dialogue_box.is_timed()).is_true()
	await press_action("pause")
	assert_bool(main.build_screen.is_open()).is_true()
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_bool(main.dialogue_box.visible).is_false()
	main.build_screen.close()


## Walking out mid-line takes it down with the room, and its timer, ending later, leaves a line
## said since alone.
func test_a_walk_out_mid_line_takes_it_down_and_its_timer_leaves_a_later_line_alone() -> void:
	var main := await _woken(FIXTURE)
	await press_action("move_up")
	await go_through(main, "hypogeum")
	assert_bool(main.dialogue_box.is_timed()).is_false()
	main.dialogue_box.show_timed("narrator", "A later line.")
	await real_seconds(Main.ENTRY_LINE_TIME)
	assert_bool(main.dialogue_box.is_timed()).is_true()
	assert_str(main.dialogue_box.line_label.text).is_equal("A later line.")
	main.dialogue_box.hide_timed()


## No narrator line for the room: the wake is silent and nothing shows.
func test_with_no_entry_line_the_wake_shows_nothing() -> void:
	var main := await _woken()
	await ticks(5)
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


## The wake's line is the gate's: a walk out of the Spoliarium and back in through its door says
## nothing (arrival door), on a story whose wake reads `arrival == gate`.
func test_the_wake_line_reads_the_gate_arrival_and_a_walk_back_in_says_nothing() -> void:
	var main := await _woken(ARRIVAL_FIXTURE)
	assert_bool(main.dialogue_box.is_timed()).is_true()
	assert_str(main.dialogue_box.line_label.text).is_equal("Through the gate.")
	await press_action("move_up")
	await go_through(main, "hypogeum")
	await go_through(main, "spoliarium")
	await ticks(5)
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_array(_started).is_equal(["narrator.at_gate"])


## Play from the title lands in the Ludus with the arrival `start`; a walk back in is a door's.
func test_play_from_the_title_lands_with_the_start_arrival() -> void:
	use_story(ARRIVAL_FIXTURE)
	var main: Main = quiet_main()
	Profile.save.set_flag("returned", true)
	main.play()
	assert_bool(main.dialogue_box.is_timed()).is_true()
	assert_str(main.dialogue_box.line_label.text).is_equal("From the start.")
	assert_array(_started).is_equal(["narrator.at_start"])
	await go_through(main, "armamentarium")
	await go_through(main, "ludus")
	await ticks(5)
	assert_bool(main.dialogue_box.is_timed()).is_false()
	assert_array(_started).is_equal(["narrator.at_start"])
