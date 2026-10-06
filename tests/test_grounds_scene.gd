extends SceneSuite
## The grounds under Main: the walkable rooms that replace the arena, their three stations (the
## post in the Ludus, the rack in the Armamentarium, the lift in the Hypogeum), the training
## panel's purchases (on the scratch profile), the armoury panel, and the lift starting a run
## shaped by the training. A panel opens on E with its station the focus (the body paired with
## its area, a few ticks after a placement) and closes when the body leaves. test_rooms_scene.gd
## has the rooms and the doors.

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


## Stands on the station until it is the focus and presses E, which Main answers by opening
## the station's panel.
func _open_at(main: Main, station_id: String) -> void:
	await stand_at(main, station_id)
	await interact()


## Off every station, onto the entry spot, until the focus is gone (Main closes the panel).
func _walk_away(main: Main) -> void:
	var grounds := _grounds(main)
	player_of(main).global_position = grounds.entry_position()
	await wait_until(func() -> bool: return grounds.focus == null, "the player to leave every station", 30)


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
	assert_str(grounds.room_def.id).is_equal("ludus")
	var player := player_of(main)
	assert_vector(player.global_position).is_equal(grounds.entry_position())
	assert_bool(grounds.bounds().has_point(player.global_position)).is_true()
	for pair: Array in [["ludus", "post"], ["armamentarium", "rack"], ["ludus", ""], ["hypogeum", "lift:1"]]:
		if main.grounds.room_def.id != pair[0]:
			await go_through(main, pair[0])
		if pair[1] == "":
			continue
		var station: Station = main.grounds.station(pair[1])
		assert_object(station).override_failure_message("no %s in the %s" % [pair[1], pair[0]]).is_not_null()
		assert_int(station.collision_mask).is_equal(65)
		assert_int(station.collision_layer).is_equal(0)
		assert_bool(main.grounds.bounds().has_point(station.stand_position())).is_true()
	assert_str(Audio.current_music).is_equal("music_grounds")
	assert_int(plays("music_grounds")).is_equal(1)
	assert_bool(_training(main).is_open()).is_false()
	assert_bool(_armoury(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_hypogeum_is_one_screen_with_the_lift_where_the_box_stands() -> void:
	var main := _grounds_main()
	await go_through(main, "hypogeum")
	var grounds := _grounds(main)
	var def := grounds.room_def
	assert_that(grounds.full_rect()).is_equal(ArenaGrid.full_rect(def.width, def.height))
	var camera: Camera2D = main.get_node("Player/Camera")
	assert_int(camera.limit_right).is_equal(int(grounds.full_rect().end.x))
	assert_int(camera.limit_bottom).is_equal(int(grounds.full_rect().end.y))
	var lift := grounds.station(LiftRules.id_for(1))
	var gap := ArenaGrid.door_gap(def.width, def.height, ArenaGrid.Side.TOP)
	assert_vector(lift.position).is_equal(gap.position)
	var names: Array[String] = []
	for child in lift.get_children():
		if child is Sprite2D:
			names.append(child.name)
	assert_array(names).contains_exactly(["doors_frame_left", "doors_frame_right", "doors_leaf_open"])
	# Under the arena's walls: the top wall is solid (no gap where the lift stands), so the player
	# cannot leave through the lift's art; the one gap is the bottom door's, closed by its blocker.
	assert_array(grounds.arena.door_sides).is_equal([ArenaGrid.Side.BOTTOM])
	assert_int(grounds.get_node("Arena/Walls").get_child_count()).is_equal(ArenaGrid.wall_rects(def.width, def.height, [ArenaGrid.Side.BOTTOM]).size())


func test_e_on_the_post_opens_the_training_panel_and_walking_out_closes_it() -> void:
	var main := _grounds_main()
	var panel := _training(main)
	await _open_at(main, "post")
	assert_bool(panel.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	var rows := panel.rows()
	assert_array(rows.keys()).contains_exactly(["offer", "reroll", "mercy", "reach"])
	await _walk_away(main)
	assert_bool(panel.is_open()).is_false()


func test_a_click_on_the_reach_row_buys_rank_one_and_writes_the_profile() -> void:
	var main := _grounds_main()
	Profile.save.money = 60
	await _open_at(main, "post")
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
	await _open_at(main, "post")
	var panel := _training(main)
	assert_str(panel.money_text()).is_equal("60")
	assert_object(panel.get_node("Center/Panel/Money/Coin")).is_not_null()
	panel.click("reach")
	assert_str(panel.money_text()).is_equal("20")
	await _walk_away(main)
	Profile.save.money = 250
	await _open_at(main, "post")
	assert_str(panel.money_text()).is_equal("250")


## Each row carries its line's name beside the icon, on the row's one line (UI may name).
func test_each_row_carries_its_lines_name_beside_the_icon() -> void:
	var main := _grounds_main()
	await _open_at(main, "post")
	var panel := _training(main)
	for line: String in TrainingRules.LINES:
		assert_str(panel.name_text(line)).is_equal(TrainingRules.name_of(line))
		var label: Label = panel.row(line).get_node("Box/Name")
		assert_int(label.get_theme_font_size("font_size")).is_equal(TrainingPanel.LINE_FONT_SIZE)
		assert_that(label.get_theme_color("font_color")).is_equal(UiTheme.INK)
		# Beside the icon, not under it: to the right of the icon's slot, its centre on its line.
		# The slot is one width for every row (the coin is smaller than a Raven icon), so the names line up.
		var slot: Control = panel.row(line).get_node("Box/Slot")
		assert_object(slot.get_node("Icon")).is_not_null()
		assert_float(slot.size.x).is_equal(TrainingPanel.ICON_SLOT)
		assert_float(label.position.x).is_greater_equal(slot.position.x + slot.size.x)
		assert_float(label.position.x).is_equal((panel.row("offer").get_node("Box/Name") as Control).position.x)
		# The name fits its column, so the pips form one too.
		assert_float(label.get_minimum_size().x).is_less_equal(TrainingPanel.NAME_WIDTH)
		var pips: Control = panel.row(line).get_node("Box/Pips")
		assert_float(pips.position.x).is_equal((panel.row("offer").get_node("Box/Pips") as Control).position.x)
		var centre_y := label.position.y + label.size.y / 2.0
		assert_float(centre_y).is_between(slot.position.y, slot.position.y + slot.size.y)
		# One line tall: the name's line, no text line under it.
		assert_float(panel.row(line).size.y).is_less(2.0 * TrainingPanel.LINE_HEIGHT)


## The description strip under the rows shows the hovered row's text (the table's) and is empty
## otherwise; a greyed row's text shows too (a disabled Button still reports the hover).
func test_hovering_a_row_fills_the_strip_with_its_text_and_leaving_empties_it() -> void:
	var main := _grounds_main()
	Profile.save.money = 60  # reach lit, the rest greyed
	await _open_at(main, "post")
	var panel := _training(main)
	assert_str(panel.description_text()).is_equal("")
	var strip: Label = panel.get_node("Center/Panel/Description")
	assert_int(strip.get_theme_font_size("font_size")).is_equal(TrainingPanel.LINE_FONT_SIZE)
	# Under the last row, the rows' width.
	var last: Control = panel.row("reach")
	assert_float(strip.global_position.y).is_greater_equal(last.global_position.y + last.size.y)
	assert_float(strip.size.x).is_equal(TrainingPanel.ROW_SIZE.x)
	# Every line's text fits the strip's width and the strip fits above the panel's inset.
	for line: String in TrainingRules.LINES:
		panel.row(line).mouse_entered.emit()
		assert_str(panel.description_text()).is_equal(TrainingRules.text(line))
		assert_float(strip.get_minimum_size().x).override_failure_message("%s's text is wider than the strip" % line).is_less_equal(TrainingPanel.ROW_SIZE.x)
		assert_float(strip.position.y + strip.get_combined_minimum_size().y).is_less_equal(TrainingPanel.panel_size().y - TrainingPanel.INSET)
		panel.row(line).mouse_exited.emit()
	assert_str(panel.description_text()).is_equal("")
	panel.row("reach").mouse_entered.emit()
	assert_str(panel.description_text()).is_equal(TrainingRules.text("reach"))
	panel.row("reach").mouse_exited.emit()
	assert_str(panel.description_text()).is_equal("")
	assert_bool(panel.row("mercy").disabled).is_true()
	panel.row("mercy").mouse_entered.emit()
	assert_str(panel.description_text()).is_equal(TrainingRules.text("mercy"))
	panel.row("mercy").mouse_exited.emit()
	assert_str(panel.description_text()).is_equal("")
	# The real thing: the cursor over a row, then off the panel.
	await get_tree().process_frame
	await hover_control(panel.row("offer"))
	assert_str(panel.description_text()).is_equal(TrainingRules.text("offer"))
	await hover_at(Vector2.ZERO)
	assert_str(panel.description_text()).is_equal("")
	# A purchase under the cursor rebuilds the rows: the strip keeps the row the cursor is on.
	await hover_control(panel.row("reach"))
	assert_str(panel.description_text()).is_equal(TrainingRules.text("reach"))
	await click_control(panel.row("reach"))
	assert_array(_bought).is_equal([["reach", 1]])
	assert_str(panel.description_text()).is_equal(TrainingRules.text("reach"))
	await hover_at(Vector2.ZERO)  # the cursor off the panel, not parked on a row for the next test


func test_a_click_the_money_does_not_cover_is_denied() -> void:
	var main := _grounds_main()
	Profile.save.money = 10
	await _open_at(main, "post")
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
	await _open_at(main, "post")
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
	await _open_at(main, "post")
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


## The panel's words: the names, the money, the prices, and nothing else until a hover, which
## adds the hovered line's text and nothing more; the armoury has no words at all.
func test_the_panels_carry_no_words_beyond_the_names_and_the_prices() -> void:
	var main := _grounds_main()
	Profile.save.money = 60
	await _open_at(main, "post")
	var panel := _training(main)
	var words: Array[String] = ["60", "120", "100", "300", "40", "Offer", "Reroll", "Mercy", "Reach"]
	assert_array(_label_texts(panel)).contains_exactly_in_any_order(words)
	panel.row("mercy").mouse_entered.emit()
	assert_array(_label_texts(panel)).contains_exactly_in_any_order(words + ["Fall once and fight on"])
	panel.row("mercy").mouse_exited.emit()
	assert_array(_label_texts(panel)).contains_exactly_in_any_order(words)
	await go_through(main, "armamentarium")
	await _open_at(main, "rack")
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
	await _open_at(main, "post")
	await go_through(main, "armamentarium")  # the walk closes the post's panel
	assert_bool(_training(main).is_open()).is_false()
	await _open_at(main, "rack")
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


func test_the_lift_starts_a_run_shaped_by_the_training() -> void:
	var main := _grounds_main()
	_rounds = []  # the boot's round 0 is not the lift's
	Profile.save.training = {"offer": 1, "reroll": 2, "mercy": 1, "reach": 1}
	await take_the_lift(main)
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


func test_the_lift_uses_the_titles_seed_and_cheats_once() -> void:
	var main: Main = quiet_main()
	Profile.save.set_flag("returned", true)
	main.play(42, {"immortal": true})
	assert_object(main.grounds).is_not_null()
	await take_the_lift(main)
	assert_int(RunState.seed_value).is_equal(42)
	assert_that(RunState.cheats).is_equal({"immortal": true})
	main.enter_grounds()
	await take_the_lift(main)
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
	await take_the_lift(main)
	Input.action_press("shoot")
	await wait_until(func() -> bool: return _shots >= 1, "the first shot after the lift", 30)
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
	await take_the_lift(main)
	var at_the_lift := float(Profile.save.stat("time_in_grounds"))
	await ticks(12)
	assert_float(float(Profile.save.stat("time_in_grounds"))).is_equal(at_the_lift)


func test_the_pause_screen_in_the_grounds_hides_restart() -> void:
	var main := _grounds_main()
	var screen: BuildScreen = main.get_node("BuildScreen")
	screen.open()
	assert_bool(screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(screen.options.get_node("Restart").visible).is_false()
	assert_bool(screen.options.get_node("Resume").visible).is_true()
	screen.close()
	main.enter_arena()
	screen.open()
	assert_bool(screen.options.get_node("Restart").visible).is_true()
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


## No boons are held back in the grounds (playtest 2, note 5): the last run's build is cleared
## before the revive, so the gladiator walks there at the base hearts and charges with the
## starting weapon, and the pause screen shows no upgrades.
func test_the_grounds_clear_the_last_runs_build() -> void:
	var main: Main = quiet_main()
	var player := player_of(main)
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.switch_weapon("crossbow")
	RunState.build.add_rank(catalog["damage_crossbow"])
	RunState.build.add_rank(catalog["heart_container"])
	RunState.build.add_rank(catalog["dash_charge"])
	Events.build_changed.emit()
	assert_int(player.max_hp).is_greater(Build.BASE_MAX_HP)
	assert_int(player.max_dash_charges).is_greater(Build.BASE_DASH_CHARGES)
	var signals := {"run_started": 0, "build_changed": 0}
	var on_run_started := func() -> void: signals["run_started"] += 1
	var on_build_changed := func() -> void: signals["build_changed"] += 1
	Events.run_started.connect(on_run_started)
	Events.build_changed.connect(on_build_changed)
	main.enter_grounds()
	Events.run_started.disconnect(on_run_started)
	Events.build_changed.disconnect(on_build_changed)
	assert_dict(signals).is_equal({"run_started": 0, "build_changed": 0})  # a quiet reset: no run starts
	assert_str(RunState.build.weapon_id).is_equal(Build.STARTING_WEAPON)
	assert_array(RunState.build.owned_weapon_ids()).is_empty()
	assert_array(RunState.build.owned_player_ids()).is_empty()
	assert_int(player.max_hp).is_equal(Build.BASE_MAX_HP)
	assert_int(player.hp).is_equal(Build.BASE_MAX_HP)
	assert_int(player.max_dash_charges).is_equal(Build.BASE_DASH_CHARGES)
	assert_str(player.weapon.id).is_equal(Build.STARTING_WEAPON)
	# The pause screen there shows no boons: the handgun alone.
	var screen: BuildScreen = main.get_node("BuildScreen")
	screen.open("boons")
	var texts := []
	for label: Label in screen.boons.find_children("*", "Label", true, false):
		texts.append(label.text)
	assert_object(screen.boons.get_node_or_null("Row_weapon")).is_not_null()
	assert_array(texts).contains_exactly(["Handgun", "No upgrades yet"])
	screen.close()


func test_favour_does_not_drain_in_the_grounds() -> void:
	var main := _grounds_main()
	RunState.favour = 50.0
	RunState.elapsed = 100.0  # far past the decay grace; no run is live in the grounds
	await ticks(30)
	assert_float(RunState.favour).is_equal(50.0)
