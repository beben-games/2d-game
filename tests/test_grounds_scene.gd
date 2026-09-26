extends SceneSuite
## The grounds under Main: the walkable room that replaces the arena, its three stations, the
## training panel's purchases (on the scratch profile), the armoury panel, and the gate station
## starting a run shaped by the training. The panels open and close on the player's body pairing
## with a station's area, which the physics server reports a tick after a placement.

var _bought: Array[Array] = []
var _denied: Array[String] = []
var _rounds: Array[Array] = []
var _shots := 0


func before_test() -> void:
	super()
	_bought = []
	_denied = []
	_rounds = []
	_shots = 0
	Events.training_bought.connect(_on_bought)
	Events.purchase_denied.connect(_on_denied)
	Events.round_started.connect(_on_round_started)
	Events.shot_fired.connect(_on_shot_fired)


func after_test() -> void:
	Events.training_bought.disconnect(_on_bought)
	Events.purchase_denied.disconnect(_on_denied)
	Events.round_started.disconnect(_on_round_started)
	Events.shot_fired.disconnect(_on_shot_fired)
	await super()  # the base awaits a frame


func _on_bought(line: String, rank: int) -> void:
	_bought.append([line, rank])


func _on_shot_fired(_at: Vector2, _direction: Vector2, _weapon_id: String) -> void:
	_shots += 1


func _on_denied(line: String) -> void:
	_denied.append(line)


func _on_round_started(index: int, total: int) -> void:
	_rounds.append([index, total])


## A quiet Main moved to the grounds.
func _grounds_main() -> Main:
	var main: Main = quiet_main()
	main.enter_grounds()
	return main


func _grounds(main: Main) -> Grounds:
	return main.get_node("Grounds")


func _training(main: Main) -> TrainingPanel:
	return main.get_node("TrainingPanel")


func _armoury(main: Main) -> ArmouryPanel:
	return main.get_node("ArmouryPanel")


## Puts the player's body on the station and waits for the physics server to pair them (two or
## three ticks after a placement: the step after it detects the overlap, the flush after that
## reports it), which Main answers by opening the station's panel; the gate's touch is awaited
## by its caller.
func _walk_to(main: Main, station_id: String) -> void:
	var station := _grounds(main).station(station_id)
	player_of(main).global_position = station.stand_position()
	await wait_until(func() -> bool: return station.has_overlapping_bodies(), "the player to pair with the " + station_id, 10)
	await ticks(1)  # the pairing's callback ran in that frame's flush; one more lets Main's handler settle


## Off every station, onto the entry spot, until the last station reports the body gone.
func _walk_away(main: Main) -> void:
	var grounds := _grounds(main)
	player_of(main).global_position = grounds.entry_position()
	await wait_until(func() -> bool:
		for station in grounds.stations.get_children():
			if (station as Area2D).has_overlapping_bodies():
				return false
		return true, "the player to leave every station", 10)
	await ticks(1)


func test_enter_grounds_replaces_the_room_hides_the_hud_and_plays_the_grounds_music() -> void:
	var main := _grounds_main()
	assert_object(main.get_node_or_null("Room")).is_null()
	assert_object(main.room).is_null()
	var grounds := _grounds(main)
	assert_object(grounds).is_not_null()
	assert_int(grounds.get_index()).is_equal(0)
	assert_bool(hud_of(main).visible).is_false()
	assert_str(Audio.current_music).is_equal("music_grounds")
	assert_int(plays("music_grounds")).is_equal(1)
	var player := player_of(main)
	assert_vector(player.global_position).is_equal(grounds.entry_position())
	assert_bool(grounds.bounds().has_point(player.global_position)).is_true()
	for id: String in ["post", "rack", "gate"]:
		var station := grounds.station(id)
		assert_object(station).is_not_null()
		assert_int(station.collision_mask).is_equal(65)
		assert_int(station.collision_layer).is_equal(0)
		assert_bool(grounds.bounds().has_point(station.stand_position())).is_true()
	assert_bool(_training(main).is_open()).is_false()
	assert_bool(_armoury(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_grounds_are_one_screen_with_the_gate_where_the_box_stands() -> void:
	var main := _grounds_main()
	var grounds := _grounds(main)
	assert_that(grounds.full_rect()).is_equal(ArenaGrid.full_rect(28, 15))
	var camera: Camera2D = main.get_node("Player/Camera")
	assert_int(camera.limit_right).is_equal(int(grounds.full_rect().end.x))
	assert_int(camera.limit_bottom).is_equal(int(grounds.full_rect().end.y))
	var gate := grounds.station("gate")
	var gap := ArenaGrid.door_gap(28, 15, ArenaGrid.Side.TOP)
	assert_vector(gate.position).is_equal(gap.position)
	var names: Array[String] = []
	for child in gate.get_children():
		if child is Sprite2D:
			names.append(child.name)
	assert_array(names).contains_exactly(["doors_frame_left", "doors_frame_right", "doors_leaf_open"])
	# Under the arena's walls: the ring is solid, so the player cannot leave through the gate's art.
	assert_int(grounds.get_node("Arena/Walls").get_child_count()).is_equal(4)


func test_walking_into_the_post_opens_the_training_panel_and_walking_out_closes_it() -> void:
	var main := _grounds_main()
	var panel := _training(main)
	await _walk_to(main, "post")
	assert_bool(panel.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	var rows := panel.rows()
	assert_array(rows.keys()).contains_exactly(["offer", "reroll", "mercy", "reach"])
	await _walk_away(main)
	assert_bool(panel.is_open()).is_false()


func test_a_click_on_the_reach_row_buys_rank_one_and_writes_the_profile() -> void:
	var main := _grounds_main()
	Profile.save.money = 60
	await _walk_to(main, "post")
	var panel := _training(main)
	panel.click("reach")
	assert_int(Profile.save.money).is_equal(20)
	assert_int(Profile.save.training["reach"]).is_equal(1)
	assert_int(int(Profile.save.stat("coins_spent"))).is_equal(40)
	assert_array(_bought).is_equal([["reach", 1]])
	assert_array(_denied).is_empty()
	assert_int(plays("buy")).is_equal(1)
	var on_disk := Save.load_from(PROFILE_SCRATCH)
	assert_int(on_disk.money).is_equal(20)
	assert_int(on_disk.training["reach"]).is_equal(1)
	# The row shows the rank bought and the next price, and is greyed: 20 does not cover 80.
	assert_int(panel.lit_pips("reach")).is_equal(1)
	assert_str(panel.price_text("reach")).is_equal("80")
	assert_bool(panel.row("reach").disabled).is_true()
	assert_bool(panel.row("mercy").disabled).is_true()  # 300 > 20


## The panel shows the money held at its top (UI may name): refreshed on open and after a purchase.
func test_the_panel_shows_the_money_held_and_refreshes_it_on_a_purchase() -> void:
	var main := _grounds_main()
	Profile.save.money = 60
	await _walk_to(main, "post")
	var panel := _training(main)
	assert_str(panel.money_text()).is_equal("60")
	assert_object(panel.get_node("Center/Panel/Money/Coin")).is_not_null()
	panel.click("reach")
	assert_str(panel.money_text()).is_equal("20")
	await _walk_away(main)
	Profile.save.money = 250
	await _walk_to(main, "post")
	assert_str(panel.money_text()).is_equal("250")


## Each row carries the table's line under its icon, naming what the rank buys.
func test_each_row_names_what_it_buys_from_the_table() -> void:
	var main := _grounds_main()
	await _walk_to(main, "post")
	var panel := _training(main)
	for line: String in TrainingRules.LINES:
		assert_str(panel.line_text(line)).is_equal(TrainingRules.text(line))
		var label: Label = panel.row(line).get_node("Line")
		assert_int(label.get_theme_font_size("font_size")).is_equal(UiTheme.FONT_SMALL)
		# Under the icon: below the row's top line, at its left edge.
		var icon: Control = panel.row(line).get_node("Box/Icon")
		assert_float(label.position.y).is_greater_equal(icon.position.y + icon.size.y)
		assert_float(label.position.x).is_equal(icon.position.x)


func test_a_click_the_money_does_not_cover_is_denied() -> void:
	var main := _grounds_main()
	Profile.save.money = 10
	await _walk_to(main, "post")
	var panel := _training(main)
	assert_bool(panel.row("reach").disabled).is_true()
	panel.click("reach")
	assert_int(Profile.save.money).is_equal(10)
	assert_bool(Profile.save.training.has("reach")).is_false()
	assert_array(_denied).is_equal(["reach"])
	assert_array(_bought).is_empty()
	assert_int(plays("buy_denied")).is_equal(1)
	assert_int(plays("buy")).is_equal(0)
	assert_bool(FileAccess.file_exists(PROFILE_SCRATCH)).is_false()  # nothing to commit


func test_a_capped_line_is_greyed_and_a_click_on_it_is_denied() -> void:
	var main := _grounds_main()
	Profile.save.money = 1000
	Profile.save.training = {"mercy": 1}
	await _walk_to(main, "post")
	var panel := _training(main)
	assert_bool(panel.row("mercy").disabled).is_true()
	assert_int(panel.lit_pips("mercy")).is_equal(1)
	assert_str(panel.price_text("mercy")).is_equal("")
	assert_bool(panel.row("reach").disabled).is_false()
	panel.click("mercy")
	assert_array(_denied).is_equal(["mercy"])
	assert_int(Profile.save.money).is_equal(1000)


## A real click on the row's rect buys, like the picker's cards.
func test_a_mouse_click_on_a_row_reaches_it() -> void:
	var main := _grounds_main()
	Profile.save.money = 60
	await _walk_to(main, "post")
	var panel := _training(main)
	await get_tree().process_frame
	await click_control(panel.row("reach"))
	assert_array(_bought).is_equal([["reach", 1]])
	assert_int(Profile.save.money).is_equal(20)
	# The row is greyed now (20 does not cover 80): a disabled Button still takes the click, refused.
	assert_bool(panel.row("reach").disabled).is_true()
	await click_control(panel.row("reach"))
	assert_array(_denied).is_equal(["reach"])
	assert_int(plays("buy_denied")).is_equal(1)
	assert_int(Profile.save.money).is_equal(20)


func test_the_panels_carry_no_words_beyond_the_prices() -> void:
	var main := _grounds_main()
	Profile.save.money = 60
	await _walk_to(main, "post")
	var texts := _label_texts(_training(main))
	assert_array(texts).contains_exactly_in_any_order(
		["60", "120", "100", "300", "40", "One more card to choose from", "Change the cards once a run",
		"Fall once and fight on", "Coins come from further"])
	await _walk_to(main, "rack")
	assert_array(_label_texts(_armoury(main))).is_empty()


func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label and not (node as Label).text.is_empty():
		texts.append((node as Label).text)
	for child in node.get_children():
		texts.append_array(_label_texts(child))
	return texts


func test_the_rack_opens_the_armoury_with_the_handgun_lit_and_two_empty_slots() -> void:
	var main := _grounds_main()
	await _walk_to(main, "post")
	await _walk_to(main, "rack")
	assert_bool(_training(main).is_open()).is_false()
	var armoury := _armoury(main)
	assert_bool(armoury.is_open()).is_true()
	var slots := armoury.slots()
	assert_int(slots.size()).is_equal(3)
	assert_bool(armoury.slot_lit(0)).is_true()
	assert_bool(armoury.slot_lit(1)).is_false()
	assert_bool(armoury.slot_lit(2)).is_false()
	assert_that(armoury.slot_icon(0).texture.region).is_equal(IconAtlas.region("handgun"))
	assert_object(armoury.slot_icon(1)).is_null()
	assert_object(armoury.slot_icon(2)).is_null()
	assert_bool(armoury.gladiator.is_playing()).is_true()
	assert_str(armoury.gladiator.animation).is_equal("idle")
	assert_vector(armoury.gladiator.scale).is_equal(Vector2(4, 4))
	await _walk_away(main)
	assert_bool(armoury.is_open()).is_false()


func test_the_gate_starts_a_run_shaped_by_the_training() -> void:
	var main := _grounds_main()
	_rounds = []  # the boot's round 0 is not the gate's
	Profile.save.training = {"offer": 1, "reroll": 2, "mercy": 1, "reach": 1}
	await pass_the_gate(main)
	assert_object(main.get_node_or_null("Grounds")).is_null()
	assert_object(main.grounds).is_null()
	assert_object(main.room).is_not_null()
	assert_int(main.room.get_index()).is_equal(0)
	assert_array(_rounds).is_equal([[0, 8]])
	assert_bool(hud_of(main).visible).is_true()
	assert_str(Audio.current_music).is_equal("music_run")
	var player := player_of(main)
	assert_int(player.max_hp).is_equal(Build.BASE_MAX_HP)  # the lines buy nothing a card gives
	assert_int(player.hp).is_equal(Build.BASE_MAX_HP)
	assert_float(RunState.favour).is_equal(FavourRules.START)
	assert_int(RunState.offer_bonus).is_equal(1)
	assert_int(RunState.rerolls_left).is_equal(2)
	assert_int(RunState.mercies_left).is_equal(1)
	assert_float(RunState.pull_radius).is_equal(PileRules.PULL_RADIUS + TrainingRules.REACH_STEP)
	assert_bool(main.room.bounds().has_point(player.global_position)).is_true()
	assert_float((main.get_node("Fade/Black") as ColorRect).color.a).is_equal(0.0)


func test_the_gate_uses_the_titles_seed_and_cheats_once() -> void:
	var main: Main = quiet_main()
	Profile.save.set_flag("returned", true)
	main.play(42, {"immortal": true})
	assert_object(main.grounds).is_not_null()
	await pass_the_gate(main)
	assert_int(RunState.seed_value).is_equal(42)
	assert_that(RunState.cheats).is_equal({"immortal": true})
	main.enter_grounds()
	await pass_the_gate(main)
	assert_int(RunState.seed_value).is_not_equal(42)
	assert_that(RunState.cheats).is_equal({})


## No shot leaves the gladiator in the grounds and no dash counts there: the profile's shots
## and dashes are a run's.
func test_nothing_fires_in_the_grounds_and_a_dash_there_counts_for_nothing() -> void:
	var main := _grounds_main()
	Input.action_press("shoot")
	await ticks(20)
	Input.action_release("shoot")
	assert_int(_shots).is_equal(0)
	assert_int(plays("shot_handgun")).is_equal(0)
	assert_int(Profile.save.total("shots_fired")).is_equal(0)
	var player := player_of(main)
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	assert_bool(player.dash_left > 0.0).is_true()  # the body may dash about
	assert_int(int(Profile.save.stat("dashes"))).is_equal(0)  # the profile does not count it
	await pass_the_gate(main)
	Input.action_press("shoot")
	await wait_until(func() -> bool: return _shots >= 1, "the first shot after the gate", 30)
	Input.action_release("shoot")  # before the next tick, so the handgun fires once
	assert_int(_shots).is_equal(1)
	assert_int(Profile.save.total("shots_fired")).is_equal(1)


func test_time_in_the_grounds_is_counted_while_they_are_up() -> void:
	var main := _grounds_main()
	assert_float(float(Profile.save.stat("time_in_grounds"))).is_equal(0.0)
	await ticks(12)
	var in_grounds := float(Profile.save.stat("time_in_grounds"))
	assert_float(in_grounds).is_greater(0.1)
	assert_float(in_grounds).is_less_equal(float(Profile.save.stat("time_played")))
	await pass_the_gate(main)
	var at_the_gate := float(Profile.save.stat("time_in_grounds"))
	await ticks(12)
	assert_float(float(Profile.save.stat("time_in_grounds"))).is_equal(at_the_gate)


func test_the_pause_screen_in_the_grounds_hides_restart() -> void:
	var main := _grounds_main()
	var screen: BuildScreen = main.get_node("BuildScreen")
	screen.open()
	assert_bool(screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(screen.get_node("Center/Panel/Columns/Options/Restart").visible).is_false()
	assert_bool(screen.get_node("Center/Panel/Columns/Options/Resume").visible).is_true()
	screen.close()
	main.enter_arena()
	screen.open()
	assert_bool(screen.get_node("Center/Panel/Columns/Options/Restart").visible).is_true()
	screen.close()


func test_a_fallen_gladiator_walks_again_in_the_grounds() -> void:
	var main: Main = quiet_main(3)
	var player := player_of(main)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).is_true()
	main.enter_grounds()
	assert_bool(player.dead).is_false()
	assert_float(player.sprite.rotation).is_equal(0.0)
	assert_bool(player.hurtbox.monitoring).is_true()
	assert_int(player.hp).is_equal(player.max_hp)


func test_favour_does_not_drain_in_the_grounds() -> void:
	var main := _grounds_main()
	RunState.favour = 50.0
	RunState.elapsed = 100.0  # far past the decay grace; no run is live in the grounds
	await ticks(30)
	assert_float(RunState.favour).is_equal(50.0)
