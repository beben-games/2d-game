extends SceneSuite
## One key in the grounds: standing in an interactable's area makes it the focus and puts the
## key cap over it; nothing opens on contact; E (the interact action, through the real input
## path) acts on the focus. A panel closes on E, on Esc (the pause screen stays shut), or when
## its station loses the focus. Between two overlapping interactables the nearer is the focus;
## a disabled one never is; a dashing body focuses too; the key cap hides under a pause. The
## stations stand in their rooms (the post in the Ludus, the rack in the Armamentarium, the lift
## in the Hypogeum), reached through the doors.

var _rounds: Array[Array] = []


func before_test() -> void:
	super()
	_rounds = []
	Events.round_started.connect(_on_round_started)


func after_test() -> void:
	Events.round_started.disconnect(_on_round_started)
	await super()


func _on_round_started(index: int, total: int) -> void:
	_rounds.append([index, total])


func _grounds_main() -> Main:
	var main: Main = quiet_main()
	main.enter_grounds()
	return main


func _key_cap(main: Main) -> KeyCap:
	return main.get_node("Prompt/KeyCap")


func _training(main: Main) -> TrainingPanel:
	return main.get_node("TrainingPanel")


func _armoury(main: Main) -> ArmouryPanel:
	return main.get_node("ArmouryPanel")


func _screen(main: Main) -> BuildScreen:
	return main.get_node("BuildScreen")


## Off every interactable, onto the entry spot, until the focus is gone.
func _walk_off(main: Main) -> void:
	player_of(main).global_position = main.grounds.entry_position()
	await wait_until(func() -> bool: return main.grounds.focus == null, "the focus to clear", 30)


func test_the_key_action_is_e() -> void:
	assert_bool(InputMap.has_action("interact")).is_true()
	var keys: Array = InputMap.action_get_events("interact").filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_int(keys.size()).is_equal(1)
	assert_int((keys[0] as InputEventKey).physical_keycode).is_equal(KEY_E)
	assert_str(KeyCap.key_name("interact")).is_equal("E")


func test_the_stations_are_interactables_on_layer_0_masking_the_walking_and_dashing_body() -> void:
	var main := _grounds_main()
	assert_object(main.grounds.focus).is_null()
	for pair: Array in [["ludus", "post"], ["armamentarium", "rack"], ["ludus", ""], ["hypogeum", "lift"]]:
		if main.grounds.room_def.id != pair[0]:
			await go_through(main, pair[0])
		if pair[1] == "":
			continue
		var id: String = pair[1]
		var item := main.grounds.interactable(id)
		assert_object(item).is_instanceof(Interactable)
		assert_str(item.id).is_equal(id)
		assert_str(item.kind).is_equal("station")
		assert_bool(item.enabled).is_true()
		assert_int(item.collision_layer).is_equal(0)
		assert_int(item.collision_mask).is_equal(65)
		assert_bool(main.grounds.bounds().has_point(item.stand_position())).is_true()


func test_standing_on_the_post_focuses_it_and_shows_the_key_cap_at_its_prompt() -> void:
	var main := _grounds_main()
	var cap := _key_cap(main)
	assert_bool(cap.visible).is_false()
	var changes: Array[String] = []
	main.grounds.focus_changed.connect(func(id: String) -> void: changes.append(id))
	await stand_at(main, "post")
	assert_object(main.grounds.focus).is_same(main.grounds.interactable("post"))
	assert_array(changes).is_equal(["post"])
	await get_tree().process_frame
	assert_bool(cap.visible).is_true()
	assert_str(cap.text()).is_equal("E")
	# The cap's bottom centre sits KeyCap.GAP over the prompt position, in screen pixels.
	var at := get_viewport().get_canvas_transform() * main.grounds.interactable("post").prompt_position()
	assert_vector(cap.position + Vector2(KeyCap.SIZE.x * 0.5, KeyCap.SIZE.y + KeyCap.GAP)).is_equal_approx(at.round(), Vector2(1, 1))
	# The prompt is over the art: above the stand position.
	assert_float(main.grounds.interactable("post").prompt_position().y).is_less(main.grounds.interactable("post").stand_position().y)
	await _walk_off(main)
	assert_array(changes).is_equal(["post", ""])
	await get_tree().process_frame
	assert_bool(cap.visible).is_false()


## Only the key's name: no word on the cap.
func test_the_key_cap_carries_the_keys_name_and_nothing_else() -> void:
	var main := _grounds_main()
	await go_through(main, "armamentarium")
	await stand_at(main, "rack")
	await get_tree().process_frame
	var texts: Array[String] = []
	for label: Label in _key_cap(main).find_children("*", "Label", true, false):
		texts.append(label.text)
	assert_array(texts).is_equal(["E"])
	var label: Label = _key_cap(main).find_children("*", "Label", true, false)[0]
	assert_int(label.get_theme_font_size("font_size") % 16).is_equal(0)


## Wall art and gaps at the view's edge (the lift's top and the top door's are the view's top, a
## side door's gap the view's side): the cap stays inside the view.
func test_the_key_cap_stays_inside_the_view_over_the_lift_and_the_doors() -> void:
	var main := _grounds_main()
	var cap := _key_cap(main)
	var view := get_viewport().get_visible_rect()
	for id: String in ["door:armamentarium", "door:sanitarium", "door:hypogeum"]:
		await stand_at(main, id)
		await get_tree().process_frame
		assert_bool(cap.visible).override_failure_message("no cap over %s" % id).is_true()
		assert_bool(view.encloses(Rect2(cap.position, KeyCap.SIZE))).override_failure_message("the cap over %s leaves the view" % id).is_true()
	await go_through(main, "hypogeum")
	await stand_at(main, "lift")
	await get_tree().process_frame
	assert_bool(cap.visible).is_true()
	assert_bool(view.encloses(Rect2(cap.position, KeyCap.SIZE))).is_true()


func test_standing_opens_nothing() -> void:
	var main := _grounds_main()
	_rounds = []  # the boot's round 0 is not the lift's
	await stand_at(main, "post")
	await ticks(5)
	assert_bool(_training(main).is_open()).is_false()
	await stand_at(main, "door:armamentarium")  # a door walks nowhere on contact
	await ticks(int(Main.FADE_TIME * 60.0) + 5)
	assert_str(main.grounds.room_def.id).is_equal("ludus")
	assert_float((main.get_node("Fade/Black") as ColorRect).color.a).is_equal(0.0)
	await go_through(main, "armamentarium")
	await stand_at(main, "rack")
	await ticks(5)
	assert_bool(_armoury(main).is_open()).is_false()
	await go_through(main, "ludus")
	await go_through(main, "hypogeum")
	await stand_at(main, "lift")
	await ticks(5)
	assert_object(main.grounds).is_not_null()
	assert_array(_rounds).is_empty()


func test_e_opens_the_training_panel_and_e_again_closes_it() -> void:
	var main := _grounds_main()
	var panel := _training(main)
	var acted: Array[String] = []
	main.grounds.interacted.connect(func(item: Interactable) -> void: acted.append(item.id))
	await stand_at(main, "post")
	await interact()
	assert_array(acted).is_equal(["post"])
	assert_bool(panel.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	await interact()
	assert_bool(panel.is_open()).is_false()
	await interact()
	assert_bool(panel.is_open()).is_true()


func test_e_on_the_rack_opens_the_armoury() -> void:
	var main := _grounds_main()
	await go_through(main, "armamentarium")
	await stand_at(main, "rack")
	await interact()
	assert_bool(_armoury(main).is_open()).is_true()
	assert_bool(_training(main).is_open()).is_false()
	await interact()
	assert_bool(_armoury(main).is_open()).is_false()


func test_e_with_no_focus_does_nothing() -> void:
	var main := _grounds_main()
	var acted: Array[String] = []
	main.grounds.interacted.connect(func(item: Interactable) -> void: acted.append(item.id))
	await interact()
	assert_array(acted).is_empty()
	assert_bool(_training(main).is_open()).is_false()
	assert_bool(_armoury(main).is_open()).is_false()


## Esc with a panel open closes the panel and is spent there: the pause screen stays shut. The
## next Esc, no panel up, opens it (the same press path, so the first was not vacuous).
func test_esc_closes_the_panel_and_the_pause_screen_stays_shut() -> void:
	var main := _grounds_main()
	await stand_at(main, "post")
	await interact()
	assert_bool(_training(main).is_open()).is_true()
	await press_action("pause")
	assert_bool(_training(main).is_open()).is_false()
	assert_bool(_screen(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	await press_action("pause")
	assert_bool(_screen(main).is_open()).is_true()
	_screen(main).close()


func test_walking_off_closes_the_panel() -> void:
	var main := _grounds_main()
	await go_through(main, "armamentarium")
	await stand_at(main, "rack")
	await interact()
	assert_bool(_armoury(main).is_open()).is_true()
	await _walk_off(main)
	assert_bool(_armoury(main).is_open()).is_false()


## One station a room now: the post's panel closes when the focus moves to a door, and the
## rack's when it moves from the rack to its room's door.
func test_moving_from_a_station_to_a_door_closes_the_panel() -> void:
	var main := _grounds_main()
	await stand_at(main, "post")
	await interact()
	assert_bool(_training(main).is_open()).is_true()
	await stand_at(main, "door:armamentarium")
	assert_bool(_training(main).is_open()).is_false()
	assert_bool(_armoury(main).is_open()).is_false()
	await go_through(main, "armamentarium")
	await stand_at(main, "rack")
	await interact()
	assert_bool(_armoury(main).is_open()).is_true()
	await stand_at(main, "door:ludus")
	assert_bool(_armoury(main).is_open()).is_false()
	assert_bool(_training(main).is_open()).is_false()


## Two interactables overlapping the body: the one whose stand position is nearer wins.
func test_between_two_overlapping_interactables_the_nearer_is_the_focus() -> void:
	var main := _grounds_main()
	var post := main.grounds.interactable("post")
	var near := Interactable.new()
	near.setup("near", "character", post.stand_position() + Vector2(4, 0) - Vector2(16, 16), Rect2(0, 0, 32, 32))
	main.grounds.add_interactable(near)
	player_of(main).global_position = post.stand_position() + Vector2(4, 0)
	await wait_until(func() -> bool: return main.grounds.focus == near, "the nearer interactable to take the focus", 30)
	assert_bool(post.overlaps_body(player_of(main))).is_true()
	player_of(main).global_position = post.stand_position() - Vector2(3, 0)
	await wait_until(func() -> bool: return main.grounds.focus == post, "the post, nearer now, to take the focus", 30)
	assert_bool(near.overlaps_body(player_of(main))).is_true()


func test_a_disabled_interactable_is_never_the_focus() -> void:
	var main := _grounds_main()
	var post := main.grounds.interactable("post")
	post.enabled = false
	player_of(main).global_position = post.stand_position()
	await wait_until(func() -> bool: return post.overlaps_body(player_of(main)), "the body to pair with the post", 30)
	await ticks(3)
	assert_object(main.grounds.focus).is_null()
	await interact()
	assert_bool(_training(main).is_open()).is_false()
	post.enabled = true
	await wait_until(func() -> bool: return main.grounds.focus == post, "the post, enabled again, to take the focus", 30)


## Mask 65: the body on the dash layer (64) focuses too.
func test_a_dashing_body_focuses() -> void:
	var main := _grounds_main()
	var player := player_of(main)
	player.dash_dir = Vector2.ZERO  # a dash in place: the body stays on the spot
	player.dash_left = 10.0
	player.collision_layer = Player.DASH_LAYER
	await stand_at(main, "post")
	assert_int(player.collision_layer).is_equal(Player.DASH_LAYER)
	player.dash_left = 0.0


func test_e_on_the_lift_starts_a_run() -> void:
	var main := _grounds_main()
	_rounds = []  # the boot's round 0 is not the lift's
	await go_through(main, "hypogeum")
	var acted: Array[String] = []
	main.grounds.interacted.connect(func(item: Interactable) -> void: acted.append(item.id))
	await stand_at(main, "lift")
	await interact()
	assert_array(acted).is_equal(["lift"])
	await wait_until(func() -> bool: return main.grounds == null, "the lift to take the grounds down", 60)
	await real_seconds(Main.FADE_TIME + 0.2)
	assert_object(main.room).is_not_null()
	assert_array(_rounds).is_equal([[0, main.series_def.rounds.size()]])
	await ticks(2)
	assert_bool(_key_cap(main).visible).is_false()


func test_the_key_cap_is_hidden_under_a_pause() -> void:
	var main := _grounds_main()
	await stand_at(main, "post")
	await get_tree().process_frame
	var cap := _key_cap(main)
	assert_bool(cap.visible).is_true()
	_screen(main).open()
	await get_tree().process_frame
	assert_bool(cap.visible).is_false()
	# Nothing acts under the pause: E does not reach the grounds.
	await interact()
	assert_bool(_training(main).is_open()).is_false()
	_screen(main).close()
	await get_tree().process_frame
	assert_bool(cap.visible).is_true()


## A focus freed while it holds the focus is lost: focus_changed("") and its open panel closes.
func test_a_freed_focus_reports_the_loss_and_its_panel_closes() -> void:
	var main := _grounds_main()
	var changes: Array[String] = []
	main.grounds.focus_changed.connect(func(id: String) -> void: changes.append(id))
	await stand_at(main, "post")
	await interact()
	assert_bool(_training(main).is_open()).is_true()
	main.grounds.interactable("post").free()
	await wait_until(func() -> bool: return changes.size() == 2, "the freed focus to be reported", 30)
	assert_array(changes).is_equal(["post", ""])
	assert_bool(_training(main).is_open()).is_false()
	await get_tree().process_frame
	assert_bool(_key_cap(main).visible).is_false()


## The key itself, end to end: E's physical key opens the post's panel; the held key's echo
## does not toggle it shut.
func test_the_e_key_opens_the_panel_and_holding_it_does_not_toggle() -> void:
	var main := _grounds_main()
	await stand_at(main, "post")
	await get_tree().process_frame
	for step: Array in [[true, false], [true, true], [true, true], [false, false]]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = step[0]
		key.echo = step[1]
		Input.parse_input_event(key)
		await ticks(2)
		assert_bool(_training(main).is_open()).override_failure_message("after pressed=%s echo=%s" % step).is_true()
	await get_tree().process_frame
