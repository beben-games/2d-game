extends SceneSuite
## The cast in their rooms, on the fixture story: each room's people stand where its def puts
## them (the veteran in the Ludus, the doctor in the Sanitarium, the attendant beside the lift),
## a Character on the one key; a wordless mark over one while Story.has_new holds (hidden while
## the character has the focus: the key cap stands there); E plays the picker's event in the box
## (the new one, else the bark), and the event is in the save on disk once the box shuts; a
## character with nothing eligible does nothing; a run's end lets the pool speak again; a
## `requires` on another pool's event holds the mark off until that one has played. The opening E
## never advances the first line, and the closing E never starts the conversation again. No
## character stands in a door's or a station's reach, on an arrival's spot, or on the dressing.

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


func _ludus(story := FIXTURE) -> Main:
	use_story(story)
	var main: Main = quiet_main()
	main.enter_grounds()
	return main


func _character(main: Main, id: String) -> Character:
	return main.grounds.interactable(id) as Character


## Off every interactable: onto the arrival's spot, until nothing is in focus.
func _step_off(main: Main) -> void:
	player_of(main).global_position = main.grounds.entry_position()
	await wait_until(func() -> bool: return main.grounds.focus == null, "the focus to go", 30)


## E, then E until the box has shut (each line takes two: one to complete, one to pass).
func _talk_through(main: Main, choice := "pick_2") -> void:
	await interact()
	for i in 12:
		if not main.dialogue_box.is_open():
			return
		if main.dialogue_box.choosing():
			await press_action(choice)
		else:
			await interact()
	assert_bool(main.dialogue_box.is_open()).override_failure_message("the box did not shut").is_false()


func test_the_veteran_stands_at_their_spot_in_the_ludus_with_a_mark() -> void:
	var main := _ludus()
	var veteran := _character(main, "veteran")
	assert_object(veteran).is_not_null()
	assert_str(veteran.kind).is_equal("character")
	assert_str(veteran.sprite_name).is_equal("lizard_m_idle_anim")
	var size := SpriteAtlas.region("lizard_m_idle_anim").size
	var foot := main.grounds.floor_point(GroundsRooms.room("ludus").people["veteran"])
	assert_vector(veteran.global_position).is_equal((foot - Vector2(size.x * 0.5, size.y)).floor())
	assert_bool(veteran.sprite.is_playing()).is_true()
	await ticks(2)
	assert_bool(veteran.mark.visible).is_true()
	assert_bool(veteran.mark.is_visible_in_tree()).is_true()
	# Wordless: the mark draws itself and holds no text.
	assert_array(veteran.mark.find_children("*", "Label", true, false)).is_empty()


func test_each_room_has_its_character() -> void:
	var main := _ludus()
	await go_through(main, "sanitarium")
	assert_str(_character(main, "doctor").sprite_name).is_equal("doc_idle_anim")
	await go_through(main, "ludus")
	await go_through(main, "hypogeum")
	assert_str(_character(main, "attendant").sprite_name).is_equal("elf_m_idle_anim")
	assert_bool(_character(main, "attendant").mark.visible).is_false()  # the fixture gives the attendant nothing


## The mark and the key cap share the prompt: the mark hides while its character has the focus
## and the cap stands there; off the character, the mark is back.
func test_the_mark_hides_while_its_character_has_the_focus() -> void:
	var main := _ludus()
	var veteran := _character(main, "veteran")
	var cap: KeyCap = main.get_node("Prompt/KeyCap")
	await stand_at(main, "veteran")
	await get_tree().process_frame
	assert_bool(veteran.mark.visible).is_false()
	assert_bool(cap.visible).is_true()
	await _step_off(main)
	assert_bool(veteran.mark.visible).is_true()


func test_e_plays_the_event_and_the_mark_is_gone_after_it_and_the_event_on_disk() -> void:
	var main := _ludus()
	var veteran := _character(main, "veteran")
	await stand_at(main, "veteran")
	await interact()
	assert_bool(main.dialogue_box.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_array(_started).is_equal(["veteran.hello"])
	assert_str(main.dialogue_box.line_label.text).is_equal("New blood, and still standing.")
	for i in 2:
		await interact()
		await interact()
	await press_action("pick_2")
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(Story.has_new("veteran")).is_false()
	await _step_off(main)
	assert_bool(veteran.mark.visible).is_false()
	var on_disk := Save.load_from(PROFILE_SCRATCH)
	assert_int(on_disk.story_played("veteran.hello")).is_equal(1)
	assert_bool(on_disk.story_flag("veteran_distant", false)).is_true()


func test_e_again_plays_the_bark_and_the_bark_leaves_the_mark_off() -> void:
	var main := _ludus()
	var veteran := _character(main, "veteran")
	await stand_at(main, "veteran")
	await _talk_through(main)
	await _talk_through(main)
	assert_array(_started).is_equal(["veteran.hello", "veteran.grumble"])
	await _step_off(main)
	assert_bool(veteran.mark.visible).is_false()


## A run's end lets every pool speak again: the veteran's next word, waiting on the first, brings
## the mark back.
func test_a_runs_end_brings_the_mark_back_with_a_newly_eligible_event() -> void:
	var main := _ludus()
	var veteran := _character(main, "veteran")
	await stand_at(main, "veteran")
	await _talk_through(main)
	await _step_off(main)
	assert_bool(veteran.mark.visible).is_false()
	Events.run_ended.emit("fall")
	assert_bool(veteran.mark.visible).is_true()
	await stand_at(main, "veteran")
	await _talk_through(main)
	assert_array(_started).is_equal(["veteran.hello", "veteran.next_night"])


## The veteran's warning requires the lanista's first word: until it has played, the mark stays
## off; once it has (an event finished anywhere), the mark comes on.
func test_a_requires_on_another_characters_event_holds_the_mark_off() -> void:
	Profile.save.mark_story_played("veteran.hello")
	Profile.save.mark_story_played("veteran.next_night")
	Profile.save.flags["deaths"] = 1
	var main := _ludus()
	var veteran := _character(main, "veteran")
	await ticks(2)
	assert_bool(veteran.mark.visible).is_false()
	var word := Story.next("lanista", "talk")
	assert_str(word.id).is_equal("lanista.first_word")
	Story.begin(word)
	Story.finish(word, false)
	assert_bool(veteran.mark.visible).is_true()
	assert_str(Story.next("veteran", "talk").id).is_equal("veteran.the_warning")


func test_a_character_with_nothing_to_say_does_nothing() -> void:
	var main := _ludus()
	await go_through(main, "sanitarium")
	var doctor := _character(main, "doctor")
	assert_bool(doctor.mark.visible).is_false()
	await stand_at(main, "doctor")
	await interact()
	await ticks(2)
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_array(_started).is_empty()


## The E that opens the box was the grounds': the first line is still revealing after it.
func test_the_opening_press_does_not_advance_the_first_line() -> void:
	var main := _ludus()
	await stand_at(main, "veteran")
	await interact()
	assert_bool(main.dialogue_box.is_open()).is_true()
	assert_str(main.dialogue_box.line_label.text).is_equal("New blood, and still standing.")
	assert_bool(main.dialogue_box.is_revealing()).is_true()


## The E that passes the last line is the box's: the grounds, unpaused under it, never hear it,
## so the bark does not start again; still shut a few frames on.
func test_the_closing_press_does_not_start_the_conversation_again() -> void:
	Profile.save.mark_story_spoken("veteran")  # only the bark is left this return
	var main := _ludus()
	await stand_at(main, "veteran")
	await interact()
	assert_array(_started).is_equal(["veteran.grumble"])
	await interact()
	await interact()
	assert_bool(main.dialogue_box.is_open()).is_false()
	await ticks(5)
	assert_bool(main.dialogue_box.is_open()).is_false()
	assert_array(_started).is_equal(["veteran.grumble"])
	assert_object(main.grounds.focus).is_equal(_character(main, "veteran"))


## Every shipped room, every door open (the Spoliarium's seen): no character's area meets a door's
## or a station's, none holds an arrival's spot (from outside or through any door, the body's
## radius around it), and no character's art covers the dressing's.
func test_no_character_stands_in_a_doors_or_a_stations_reach_on_an_arrival_or_on_the_dressing() -> void:
	Profile.save.set_flag("spoliarium_seen", true)
	var main := _ludus(STORY_EMPTY)
	var placed: Array[String] = []
	for room_id in GroundsRooms.ids():
		var def := GroundsRooms.room(room_id)
		var arrivals: Array[String] = [""]
		for door in def.doors:
			arrivals.append(door.to)
		main.mount_room(def, "")
		var grounds := main.grounds
		for item in grounds.interactables():
			var character := item as Character
			if character == null:
				continue
			placed.append(character.id)
			var area := _area(character)
			for other in grounds.interactables():
				if other != character:
					assert_bool(area.intersects(_area(other))).override_failure_message("%s: %s meets %s" % [room_id, character.id, other.id]).is_false()
			for from in arrivals:
				grounds.arrived_from = from
				var spot := grounds.entry_position()
				assert_bool(area.grow(6.0).has_point(spot)).override_failure_message("%s: %s holds the arrival from '%s'" % [room_id, character.id, from]).is_false()
			var art := Rect2(character.global_position, SpriteAtlas.region(character.sprite_name).size)
			for node in grounds.dressing.get_children():
				var dressing := _dressing_rect(node as Node2D)
				assert_bool(art.intersects(dressing)).override_failure_message("%s: %s stands on %s" % [room_id, character.id, node.name]).is_false()
	assert_array(placed).contains_exactly_in_any_order(["veteran", "doctor", "attendant"])


func _area(item: Interactable) -> Rect2:
	return Rect2(item.global_position + item.area.position, item.area.size)


func _dressing_rect(node: Node2D) -> Rect2:
	var size := Vector2.ZERO
	if node is Sprite2D:
		size = (node as Sprite2D).texture.get_size()
	elif node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		size = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size()
	return Rect2(node.global_position, size)
