extends SceneSuite
## The text box over the fixture story's events, played straight from the catalog: the speaker's
## name (the PLACEHOLDER marker never shown), the portrait (the cast sprite's first frame), and the
## line growing letter by letter, with the speaker's bleep on the UI pool; a press (E, Enter, a
## click) completes a revealing line and the next advances; the last closes the box, unpauses, and
## resolves the await; a choice's effects run before its lines, so a line gated on the flag it
## sets plays; the box shows a name and a line and nothing else; a held key's echo advances
## nothing; Esc, Tab, and R do nothing under it.

const FIXTURE := "res://tests/support/story"

var _blips: Array[String] = []


func before_test() -> void:
	super()
	_blips = []
	Events.dialogue_blip.connect(_on_blip)


func after_test() -> void:
	Events.dialogue_blip.disconnect(_on_blip)
	await super()


func _on_blip(voice: String) -> void:
	_blips.append(voice)


## A quiet Main in the Ludus on the fixture story, and its box.
func _box_main() -> Main:
	use_story(FIXTURE)
	var main: Main = quiet_main()
	main.enter_grounds()
	return main


func _event(id: String) -> StoryEvent:
	return Story.catalog.by_id[id]


## Plays `event` in the box without waiting: `done[0]` turns true when the await resolves.
func _start(box: DialogueBox, event: StoryEvent, done: Array) -> void:
	await box.play(event)
	done[0] = true


## E, as the real input path delivers it.
func _press() -> void:
	await interact()


## One E to complete the line, one to advance past it.
func _through_line() -> void:
	await _press()
	await _press()


func test_play_shows_the_name_the_portrait_and_the_first_line_growing() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var done := [false]
	_start(box, _event("veteran.hello"), done)
	assert_bool(box.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_str(box.name_label.text).is_equal("Veteran")
	assert_object(box.portrait.texture).is_not_null()
	assert_that((box.portrait.texture as AtlasTexture).region).is_equal(SpriteAtlas.region("lizard_m_idle_anim", 0))
	assert_str(box.line_label.text).is_equal("New blood, and still standing.")
	assert_bool(box.is_revealing()).is_true()
	var first := box.shown_letters()
	await ticks(6)
	assert_int(box.shown_letters()).is_greater(first)
	assert_bool(done[0]).is_false()


func test_one_press_completes_the_line_and_the_next_advances() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.hello"), [false])
	await _press()
	assert_bool(box.is_revealing()).is_false()
	assert_int(box.shown_letters()).is_equal(box.line_label.text.length())
	assert_str(box.line_label.text).is_equal("New blood, and still standing.")
	await _press()
	assert_str(box.line_label.text).is_equal("The sand remembers the slow.")
	assert_bool(box.is_revealing()).is_true()


func test_the_last_press_closes_unpauses_and_resolves_the_await() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var done := [false]
	var finished := [0]
	box.finished.connect(func() -> void: finished[0] += 1)
	_start(box, _event("veteran.grumble"), done)
	assert_str(box.line_label.text).is_equal("Sand in everything.")
	await _press()
	assert_bool(box.is_open()).is_true()
	await _press()
	assert_bool(box.is_open()).is_false()
	assert_bool(box.visible).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(done[0]).is_true()
	assert_int(finished[0]).is_equal(1)


## The choices come after the lines as a numbered list; pick_1 takes the first: its flag is set
## before its lines are read, so the line gated on that flag plays.
func test_a_choice_sets_its_flag_and_plays_its_lines() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var done := [false]
	_start(box, _event("veteran.hello"), done)
	await _through_line()
	await _through_line()
	assert_bool(box.choosing()).is_true()
	var texts: Array[String] = []
	for button in box.choice_buttons():
		texts.append((button.get_node("Text") as Label).text)
	assert_array(texts).is_equal(["1  Ask his name.", "2  Walk on."])
	assert_bool(box.line_label.visible).is_false()
	await press_action("pick_1")
	assert_bool(Profile.save.story_flag("veteran_trust", false)).is_true()
	assert_bool(box.choosing()).is_false()
	assert_str(box.line_label.text).is_equal("Names are for the dead.")
	await _through_line()
	assert_bool(box.is_open()).is_false()
	assert_bool(done[0]).is_true()
	assert_bool(Profile.save.story_flag("veteran_distant", false)).is_false()


## A click on a choice takes it; a choice with no lines ends the event there.
func test_a_click_takes_a_choice() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var done := [false]
	_start(box, _event("veteran.hello"), done)
	await _through_line()
	await _through_line()
	await click_control(box.choice_buttons()[1])
	assert_bool(Profile.save.story_flag("veteran_distant", false)).is_true()
	assert_bool(Profile.save.story_flag("veteran_trust", false)).is_false()
	assert_bool(box.is_open()).is_false()
	assert_bool(done[0]).is_true()


## A press during the choices takes none of them: only a number or a click does.
func test_e_during_the_choices_takes_none() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.hello"), [false])
	await _through_line()
	await _through_line()
	await _press()
	assert_bool(box.choosing()).is_true()
	await press_action("pick_5")  # no fifth choice
	assert_bool(box.choosing()).is_true()


## A click completes, then advances, as E does; Enter too.
func test_a_click_and_enter_advance_as_e_does() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.hello"), [false])
	await click_control(box.line_label)
	assert_bool(box.is_revealing()).is_false()
	await click_control(box.line_label)
	assert_str(box.line_label.text).is_equal("The sand remembers the slow.")
	await _key(KEY_ENTER)
	assert_bool(box.is_revealing()).is_false()
	await _key(KEY_ENTER)
	assert_bool(box.choosing()).is_true()


## Space is ui_accept's too, but it is the dash: a Space that closed the box would dash on the
## unpaused grounds. It advances nothing.
func test_space_advances_nothing() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	box.reveal_per_second = 1.0  # the line is still revealing seconds from now
	_start(box, _event("veteran.grumble"), [false])
	await _key(KEY_SPACE)
	assert_bool(box.is_revealing()).is_true()


## A held E's echo presses complete and advance nothing: one press is one step.
func test_a_held_keys_echo_advances_nothing() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.hello"), [false])
	await _key(KEY_E)
	assert_bool(box.is_revealing()).is_false()
	for i in 3:
		await _key(KEY_E, true)
	assert_str(box.line_label.text).is_equal("New blood, and still standing.")
	await _key(KEY_E)
	assert_str(box.line_label.text).is_equal("The sand remembers the slow.")


## The bleep is the speaker's, every few letters, on the UI pool: the tree is paused under the
## box, and a game-pool play is dropped under a pause, so a count proves the UI pool.
func test_blips_play_the_speakers_bleep_on_the_ui_pool() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.hello"), [false])
	await wait_until(func() -> bool: return plays("bleep_veteran") > 0, "a bleep", 60)
	assert_bool(get_tree().paused).is_true()
	assert_array(_blips).contains(["bleep_veteran"])
	assert_array(_blips).not_contains(["bleep_lanista", ""])
	# Completed at once, a line blips no more: the bleep is the reveal's.
	await _press()
	var count := _blips.size()
	await ticks(6)
	assert_int(_blips.size()).is_equal(count)
	assert_int(count).is_less_equal(int(ceil(box.line_label.text.length() / float(DialogueBox.BLIP_EVERY))))


## Under the box Esc and Tab open no pause screen (the box is in build_screen.blocked); once it has
## closed, each opens it (the same press path: the first presses were not vacuous). R needs no
## case here: Main, which reads it, is paused under the box, and R does nothing in the grounds
## anyway (test_rooms_scene's R cases).
func test_esc_and_tab_do_nothing_under_the_box() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var screen: BuildScreen = main.get_node("BuildScreen")
	_start(box, _event("veteran.grumble"), [false])
	await press_action("pause")
	assert_bool(screen.is_open()).is_false()
	await press_action("build_screen")
	assert_bool(screen.is_open()).is_false()
	assert_bool(box.is_open()).is_true()
	assert_str(box.line_label.text).is_equal("Sand in everything.")
	await _through_line()
	assert_bool(box.is_open()).is_false()
	await press_action("build_screen")
	assert_bool(screen.is_open()).is_true()
	await press_action("build_screen")
	assert_bool(screen.is_open()).is_false()
	await press_action("pause")
	assert_bool(screen.is_open()).is_true()


## The box shows a name and a line (and, at a choice, the choices) and no other word.
func test_the_box_shows_the_name_and_the_line_and_no_other_word() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.hello"), [false])
	assert_array(_visible_texts(box)).contains_exactly_in_any_order(["Veteran", "New blood, and still standing."])
	await _through_line()
	await _through_line()
	assert_array(_visible_texts(box)).contains_exactly_in_any_order(["1  Ask his name.", "2  Walk on."])


## Every visible Label's text under the box.
func _visible_texts(box: DialogueBox) -> Array[String]:
	var texts: Array[String] = []
	for node in box.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and not label.text.is_empty():
			texts.append(label.text)
	return texts


## A key on its physical code, pressed and released through the real input path (an echo is a
## press the OS repeats while the key is held).
func _key(code: Key, echo := false) -> void:
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		if echo and not pressed:
			break
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		event.echo = echo
		Input.parse_input_event(event)
		await ticks(2)
	await get_tree().process_frame


## The lines after a choice group are read with the choice's flags set: a line gated on the flag
## the first choice sets plays, a substitution shows the value it set, and a second group follows
## and is taken in its turn (its own gated line read after it too).
func test_lines_after_a_choice_read_the_flags_it_set() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var done := [false]
	_start(box, _event("armourer.two_asks"), done)
	assert_str(box.line_label.text).is_equal("Steel or leather?")
	await _through_line()
	await press_action("pick_1")
	assert_str(box.line_label.text).is_equal("Steel it is, then.")
	await _through_line()
	assert_str(box.line_label.text).is_equal("3 blades on the rack.")
	await _through_line()
	assert_bool(box.choosing()).is_true()
	assert_int(box.choice_buttons().size()).is_equal(2)
	await press_action("pick_1")
	assert_str(box.line_label.text).is_equal("Pleased, for once.")
	await _through_line()
	assert_bool(box.is_open()).is_false()
	assert_bool(done[0]).is_true()


## The other way through: the gated lines stay out, the substitution shows the old value.
func test_lines_after_the_other_choice_stay_out() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var done := [false]
	_start(box, _event("armourer.two_asks"), done)
	await _through_line()
	await press_action("pick_2")
	assert_str(box.line_label.text).is_equal("0 blades on the rack.")
	await _through_line()
	await press_action("pick_2")
	assert_bool(box.is_open()).is_false()
	assert_bool(done[0]).is_true()


func test_past_choices_finds_the_place_after_the_choices_offered() -> void:
	var line := StoryEvent.shown_line("veteran", "x")
	var choice := StoryEvent.shown_choice("y", [], [])
	var entries := [line, choice, choice, line, choice, line]
	assert_int(DialogueBox.past_choices(entries, 0)).is_equal(0)
	assert_int(DialogueBox.past_choices(entries, 2)).is_equal(3)
	assert_int(DialogueBox.past_choices(entries, 3)).is_equal(5)
	assert_int(DialogueBox.past_choices([line, choice], 1)).is_equal(2)


## The box stands at the top or the bottom of the view, as asked, its margin the same at either.
func test_the_box_stands_at_the_top_or_the_bottom_as_asked() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	var view := get_viewport().get_visible_rect()
	box.play(_event("veteran.grumble"), {}, true)
	assert_bool(box.at_top()).is_true()
	assert_float(box.box.position.y - view.position.y).is_equal(DialogueBox.EDGE_GAP)
	await _through_line()
	box.play(_event("veteran.grumble"))
	assert_bool(box.at_top()).is_false()
	assert_float(view.end.y - (box.box.position.y + DialogueBox.BOX_SIZE.y)).is_equal(DialogueBox.EDGE_GAP)
	await _through_line()


## A play over a paused tree (a menu up) is refused: an error, nothing paused or unpaused.
func test_a_play_over_a_paused_tree_is_refused() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	get_tree().paused = true
	await assert_error(func() -> void: box.play(_event("veteran.grumble"))).is_push_error("DialogueBox: veteran.grumble while the tree is paused")
	assert_bool(box.is_open()).is_false()
	assert_bool(get_tree().paused).is_true()
	get_tree().paused = false


## A box freed mid-play leaves no paused tree behind.
func test_a_box_freed_mid_play_unpauses() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	_start(box, _event("veteran.grumble"), [false])
	assert_bool(get_tree().paused).is_true()
	box.free()
	assert_bool(get_tree().paused).is_false()


## A line too long for the box (a long substitution) shows three wrapped lines at most.
func test_a_line_shows_three_wrapped_lines_at_most() -> void:
	var main := _box_main()
	var box := main.dialogue_box
	assert_int(box.line_label.max_lines_visible).is_equal(DialogueBox.MAX_LINES)
	assert_int(DialogueBox.MAX_LINES).is_equal(3)
