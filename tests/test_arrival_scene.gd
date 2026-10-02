extends SceneSuite
## The merchants and the first arrival, on the fixture story: the lanista keeps the post and the
## armourer the rack (each drawn beside the station, one interactable with it); E on a kept
## station plays the keeper's new word in the box and opens the panel after it, and the E that
## ends the word never shuts the panel it opened; with nothing new (a merchant's bark never
## plays) the panel opens at once; the keeper's mark follows Story.has_new and stays up while the
## station has the focus (the key cap stands over the station's art). The first pass of the gate
## screen plays the `enter ludus` event in the box once the black has lifted, never under it, and
## a second return does not; a door walk into the room plays it the same way; an arrival with no
## entry event never pauses.

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


## A quiet Main in the Ludus (a bare arrival: no entry event) on the fixture story.
func _ludus() -> Main:
	use_story(FIXTURE)
	var main: Main = quiet_main()
	main.enter_grounds()
	return main


func _post(main: Main) -> Station:
	return main.grounds.station("post")


## The box checked shut on a tick the black is still up (pass_the_gate's and a walk's sampler).
func _box_shut_under_the_black(main: Main) -> void:
	var fade: ColorRect = main.get_node("Fade/Black")
	if fade.color.a > 0.0:
		assert_bool(main.dialogue_box.is_open()).override_failure_message("the box opened under the black").is_false()


func test_the_lanista_keeps_the_post_and_the_armourer_the_rack() -> void:
	var main := _ludus()
	var post := _post(main)
	assert_str(post.keeper_id()).is_equal("lanista")
	assert_str(post.keeper.sprite_name).is_equal("ogre_idle_anim")
	# Beside the crate on its right, feet level with the crate's foot.
	assert_float(post.keeper.frame().position.x).is_greater_equal(post.art.end.x)
	assert_float(post.keeper.frame().end.y).is_equal(post.art.end.y)
	assert_object(main.grounds.interactable("lanista")).is_null()  # one interactable: the post
	await go_through(main, "armamentarium")
	var rack := main.grounds.station("rack")
	assert_str(rack.keeper_id()).is_equal("armourer")
	assert_float(rack.keeper.frame().end.x).is_less_equal(rack.art.position.x)
	assert_float(rack.keeper.global_position.y).is_equal(main.grounds.bounds().position.y)  # on the floor's first row


## Standing below the keeper's feet (in the keeper's reach, out of the crate's) is standing at the
## post: the station and its keeper are one interactable.
func test_the_keepers_reach_is_the_stations() -> void:
	var main := _ludus()
	var post := _post(main)
	player_of(main).global_position = post.keeper.stand_position()
	await wait_until(func() -> bool: return main.grounds.focus == post, "the post to take the focus from beside its keeper", 30)


func test_e_on_the_kept_post_plays_the_keepers_word_then_the_panel_stays_open() -> void:
	var main := _ludus()
	main.dialogue_box.reveal_per_second = 1.0  # the line still growing at the next press, however slow the frame
	await stand_at(main, "post")
	await interact()
	assert_bool(main.dialogue_box.is_open()).is_true()
	assert_array(_started).is_equal(["lanista.first_word"])
	assert_bool(main.training_panel.is_open()).is_false()  # the word first
	await interact()  # the line whole
	assert_bool(main.dialogue_box.is_open()).is_true()
	await interact()  # the E that ends the word: the box's, not the grounds'
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_bool(main.training_panel.is_open()).is_true()
	await ticks(5)
	assert_bool(main.training_panel.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_int(Save.load_from(PROFILE_SCRATCH).story_played("lanista.first_word")).is_equal(1)


## Once the keeper has spoken this return, E on the post opens the panel at once (the lanista's
## bark, a filler, never plays at a station); E again shuts it.
func test_with_nothing_new_e_opens_the_panel_at_once() -> void:
	var main := _ludus()
	await stand_at(main, "post")
	await interact()
	await through_box(main)
	await interact()  # shuts the panel
	assert_bool(main.training_panel.is_open()).is_false()
	await interact()
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_bool(main.training_panel.is_open()).is_true()
	assert_array(_started).is_equal(["lanista.first_word"])
	await interact()
	assert_bool(main.training_panel.is_open()).is_false()


func test_e_on_the_kept_rack_plays_the_armourers_word_then_the_armoury() -> void:
	var main := _ludus()
	await go_through(main, "armamentarium")
	await stand_at(main, "rack")
	await interact()
	assert_array(_started).is_equal(["armourer.two_asks"])
	await through_box(main)
	assert_bool(main.armoury_panel.is_open()).is_true()
	await ticks(5)
	assert_bool(main.armoury_panel.is_open()).is_true()


## The keeper's mark is Story.has_new's: up with the lanista's first word waiting, and up while
## the post has the focus (the key cap stands over the crate, not the keeper's head); gone once
## the word is said; back at a run's end with a word newly eligible (after a first win).
func test_the_keepers_mark_follows_has_new_and_stays_up_under_the_focus() -> void:
	var main := _ludus()
	var keeper := _post(main).keeper
	await ticks(2)
	assert_bool(keeper.mark.visible).is_true()
	await stand_at(main, "post")
	await get_tree().process_frame
	assert_bool(keeper.mark.visible).is_true()
	assert_bool((main.get_node("Prompt/KeyCap") as KeyCap).visible).is_true()
	await interact()
	await through_box(main)
	assert_bool(keeper.mark.visible).is_false()
	Events.run_ended.emit("fall")
	assert_bool(keeper.mark.visible).is_false()  # nothing newly eligible: the next word wants a win
	Profile.save.flags["wins"] = 1
	Events.run_ended.emit("win")
	assert_bool(keeper.mark.visible).is_true()


## A panel open on the post shuts when the focus goes, and the owner goes with it: E at the post
## again opens it (no toggle of a stale owner), and E at the rack in another room opens the armoury.
func test_a_panel_shuts_when_its_station_loses_the_focus() -> void:
	var main := _ludus()
	Profile.save.mark_story_spoken("lanista")
	Profile.save.mark_story_spoken("armourer")
	await stand_at(main, "post")
	await interact()
	assert_bool(main.training_panel.is_open()).is_true()
	player_of(main).global_position = main.grounds.entry_position()
	await wait_until(func() -> bool: return main.grounds.focus == null, "the focus to go", 30)
	assert_bool(main.training_panel.is_open()).is_false()
	await stand_at(main, "post")
	await interact()
	assert_bool(main.training_panel.is_open()).is_true()
	await go_through(main, "armamentarium")
	assert_bool(main.training_panel.is_open()).is_false()
	await stand_at(main, "rack")
	await interact()
	assert_bool(main.armoury_panel.is_open()).is_true()
	assert_bool(main.training_panel.is_open()).is_false()
	await interact()
	assert_bool(main.armoury_panel.is_open()).is_false()


func test_the_first_gate_pass_plays_the_arrival_once_the_black_has_lifted_and_a_second_return_does_not() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main(3)
	main.play()
	main.room.wave_runner.enabled = false
	await fall_to_the_gate(main)
	await pass_the_gate(main, _box_shut_under_the_black.bind(main))
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_bool(main.dialogue_box.is_open()).is_true()
	assert_array(_started).is_equal(["lanista.arrival"])
	assert_bool(main.dialogue_box.at_top()).is_true()  # the gladiator arrives at the bottom centre
	await through_box(main)
	assert_bool(get_tree().paused).is_false()
	# The lanista's own word is still to come on E: the arrival used no turn.
	assert_bool(Story.has_new("lanista")).is_true()
	# A second return: the gate screen again (opened bare, from a timer's continuation as Main
	# opens it), passed into the Ludus: no box.
	await get_tree().create_timer(0.0, true, false, true).timeout
	main.gate_screen.show_gate(true, {}, Profile.save)
	await pass_the_gate(main)
	await ticks(5)
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_array(_started).is_equal(["lanista.arrival"])


## A door walk into a room with an `enter` event plays it too, once the black has lifted: the
## fixture's arrival on a walk back into the Ludus.
func test_a_door_walk_plays_the_rooms_entry_event_once_the_black_has_lifted() -> void:
	var main := _ludus()
	await go_through(main, "armamentarium")
	assert_array(_started).is_empty()
	await stand_at(main, "door:ludus")
	await interact()
	var fade: ColorRect = main.get_node("Fade/Black")
	await wait_until(func() -> bool:
		_box_shut_under_the_black(main)
		return main.grounds != null and main.grounds.room_def.id == "ludus" and fade.color.a == 0.0, "the walk into the Ludus", 120)
	assert_bool(main.dialogue_box.is_open()).is_true()
	assert_array(_started).is_equal(["lanista.arrival"])
	await through_box(main)


## Play on a returned profile lands in the Ludus with the black already gone: the arrival plays
## there too, at once.
func test_play_on_a_returned_profile_plays_the_arrival() -> void:
	use_story(FIXTURE)
	Profile.save.set_flag("returned", true)
	var main: Main = quiet_main()
	main.play()
	assert_bool(main.dialogue_box.is_open()).is_true()
	assert_array(_started).is_equal(["lanista.arrival"])
	await through_box(main)


## An arrival with no entry event (the Sanitarium has none) shows no box and never pauses.
func test_an_arrival_with_no_entry_event_never_pauses() -> void:
	var main := _ludus()
	await stand_at(main, "door:sanitarium")
	await interact()
	var fade: ColorRect = main.get_node("Fade/Black")
	var shown := [false]
	main.room_shown.connect(func(_id: String) -> void: shown[0] = true)
	for i in 120:
		assert_bool(get_tree().paused).override_failure_message("paused during the walk").is_false()
		if shown[0]:
			break
		await get_tree().physics_frame
	assert_bool(shown[0]).is_true()
	for i in 5:
		await get_tree().physics_frame
		assert_bool(get_tree().paused).override_failure_message("paused after the arrival").is_false()
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_float(fade.color.a).is_equal(0.0)
	assert_array(_started).is_empty()
