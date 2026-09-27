extends SceneSuite
## The pause screen: Esc opens it paused on the Options tab and Tab on the Boons tab, either
## closes it; a tab press swaps the content under the strip; Options holds Resume, Restart, the
## three volume sliders (live on the buses, saved on close), and the two quits; Boons lists the
## build; Training shows the profile's lines with their rank pips and nothing to buy; R restarts
## from it; it never opens over the picker or after the run ends; the widest build fits the Boons
## page.

func _screen(main: Node) -> BuildScreen:
	return main.get_node("BuildScreen")


## Starts on a fresh frame: a press stamped after a frame's _process (a timer await ends there)
## is never "just pressed" for the screen's poll, and the tests that press after the picker beat
## would pass vacuously.
func _press(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await ticks(2)
	Input.action_release(action)


func _texts(node: Node) -> Array:
	var texts := []
	for label in node.find_children("*", "Label", true, false):
		texts.append(label.text)
	return texts


func test_tab_opens_the_build_paused_and_tab_closes_it() -> void:
	var main := quiet_main()
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.add_rank(catalog["damage_handgun"])
	RunState.build.add_rank(catalog["damage_handgun"])
	RunState.build.add_rank(catalog["dash_charge"])
	Events.build_changed.emit()
	await _press("build_screen")
	var screen := _screen(main)
	assert_bool(screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	var boons: VBoxContainer = screen.boons
	assert_object(boons.get_node_or_null("Row_damage_handgun")).is_not_null()
	assert_object(boons.get_node_or_null("Row_dash_charge")).is_not_null()
	var texts := _texts(boons)
	# The effect column is the total at the owned rank (summary), not the card's per-pick line.
	assert_array(texts).contains(["Handgun", "Heavy rounds", "2/3", "+2 damage", "Dash charge", "1/2", "+1 dash"])
	assert_array(texts).not_contains(["+1 damage"])
	# Column order: icon, name, rank, effect.
	var rank: Label = boons.get_node("Row_damage_handgun").get_child(2)
	assert_str(rank.text).is_equal("2/3")
	var effect: Label = boons.get_node("Row_damage_handgun").get_child(3)
	assert_str(effect.text).is_equal("+2 damage")
	# The weapon row is the heading, on the title font; the upgrade rows are body text.
	var weapon_name: Label = boons.get_node("Row_weapon").get_child(1)
	assert_object(weapon_name.get_theme_font("font")).is_same(UiTheme.TITLE_FONT)
	var upgrade_name: Label = boons.get_node("Row_damage_handgun").get_child(1)
	assert_object(upgrade_name.get_theme_font("font")).is_same(UiTheme.FONT)
	await _press("build_screen")
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_escape_closes_and_an_empty_build_says_so() -> void:
	var main := quiet_main()
	await _press("build_screen")
	var screen := _screen(main)
	assert_bool(screen.is_open()).is_true()
	assert_array(_texts(screen.boons)).contains(["No upgrades yet"])
	await _press("pause")
	assert_bool(screen.is_open()).is_false()


func test_a_rank_added_while_closed_shows_on_the_next_open() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("build_screen")
	assert_object(screen.boons.get_node_or_null("Row_fire_rate")).is_null()
	await _press("build_screen")
	RunState.build.add_rank(UpgradeCatalog.upgrades()["fire_rate"])
	Events.build_changed.emit()
	await _press("build_screen")
	assert_bool(screen.is_open()).is_true()
	assert_object(screen.boons.get_node_or_null("Row_fire_rate")).is_not_null()


## The reachable maximum: the eight-round series gives seven picks, so seven distinct upgrades is
## the tallest build. Seeded with the widest names and effects the catalog has, on the Boons tab.
func test_the_widest_rows_fit_inside_the_boons_page() -> void:
	var main := quiet_main()
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.switch_weapon("crossbow")
	for id: String in ["pierce_crossbow", "flaming", "chill", "damage_crossbow", "bounce_crossbow", "heart_container", "dash_charge"]:
		RunState.build.add_rank(catalog[id])
	Events.build_changed.emit()
	await _press("build_screen")
	await get_tree().process_frame
	var screen := _screen(main)
	assert_str(screen.current_tab).is_equal("boons")
	var boons: VBoxContainer = screen.boons
	assert_int(boons.get_child_count()).is_equal(8)  # the weapon, seven upgrades
	var content: Control = screen.content
	# A Control grows past its set size when the children need more, and the page would grow with it.
	assert_vector(content.size).is_equal(BuildScreen.CONTENT_SIZE)
	assert_vector(boons.size).is_equal(BuildScreen.CONTENT_SIZE)
	var needed := boons.get_combined_minimum_size()
	assert_float(needed.x).override_failure_message("rows need %s, the page gives %s" % [needed, boons.size]).is_less_equal(boons.size.x)
	assert_float(needed.y).override_failure_message("rows need %s, the page gives %s" % [needed, boons.size]).is_less_equal(boons.size.y)
	# The page sits inside the frame's inner box.
	assert_float(content.position.y + content.size.y).is_less_equal(BuildScreen.PANEL_SIZE.y - BuildScreen.INSET)
	assert_float(content.position.x + content.size.x).is_less_equal(BuildScreen.PANEL_SIZE.x - BuildScreen.INSET)


## The strip sits at the inner box's top, beside the frame's top ornament (left of it), and the
## pages start under the strip.
func test_the_tab_strip_sits_beside_the_ornament() -> void:
	var main := quiet_main()
	await _press("pause")
	await get_tree().process_frame
	var screen := _screen(main)
	var strip: HBoxContainer = screen.strip
	assert_float(strip.position.y).is_equal(BuildScreen.INSET)
	assert_float(strip.position.x + strip.size.x).is_less(BuildScreen.ORNAMENT_LEFT)
	assert_float(strip.position.y + strip.size.y).is_less_equal(screen.content.position.y)
	var names := []
	for tab: Button in strip.get_children():
		names.append((tab.get_node("Text") as Label).text)
		assert_vector(tab.size).is_equal(BuildScreen.TAB_SIZE)
	assert_array(names).is_equal(["Options", "Boons", "Training"])


func test_r_restarts_from_the_build_screen() -> void:
	var main := quiet_main()
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await _press("build_screen")
	var screen := _screen(main)
	assert_bool(screen.is_open()).is_true()
	await _press("restart")
	assert_int(restarts[0]).is_equal(1)
	assert_bool(get_tree().paused).is_false()
	assert_bool(screen.is_open()).is_false()  # not the current scene here: no reload, so the screen must go by itself


func test_it_does_not_open_over_the_picker() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	await _press("build_screen")
	assert_bool(_screen(main).is_open()).is_false()
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_true()


func test_escape_over_the_picker_leaves_it_paused_and_open() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	await _press("pause")
	assert_bool(get_tree().paused).is_true()
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_true()
	assert_bool(_screen(main).is_open()).is_false()


## Esc inside the 0.8 s picker beat: the pause screen opens, then the picker takes over (Main
## closes the pause screen before opening the picker), the tree paused under the picker.
func test_escape_in_the_picker_beat_yields_to_the_picker() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	Events.round_cleared.emit()
	await _press("pause")
	assert_bool(_screen(main).is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_true()
	assert_bool(_screen(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_true()


func test_open_refuses_while_blocked() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	screen.blocked = func() -> bool: return true
	screen.open()
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_it_does_not_open_after_the_run_ended() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	await wait_for_death_freeze()
	await _press("build_screen")
	assert_bool(_screen(main).is_open()).is_false()


func test_a_mul_card_shows_its_rank_total() -> void:
	var main := quiet_main()
	var fire_rate: UpgradeDef = UpgradeCatalog.upgrades()["fire_rate"]
	RunState.build.add_rank(fire_rate)
	RunState.build.add_rank(fire_rate)
	Events.build_changed.emit()
	await _press("build_screen")
	var effect: Label = _screen(main).boons.get_node("Row_fire_rate").get_child(3)
	assert_str(effect.text).is_equal("+50% fire rate")


func test_esc_opens_and_closes_like_tab() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("pause")
	assert_bool(screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	await _press("pause")
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_options_page_holds_the_controls() -> void:
	var main := quiet_main()
	await _press("pause")
	await get_tree().process_frame
	var screen := _screen(main)
	var options: VBoxContainer = screen.options
	assert_bool(options.is_visible_in_tree()).is_true()
	var order := ["Resume", "Restart", "Volume_master", "Volume_sfx", "Volume_music", "QuitToTitle", "QuitGame"]
	for i: int in order.size():
		var child := options.get_node_or_null(order[i])
		assert_object(child).override_failure_message(order[i]).is_not_null()
		assert_int(child.get_index()).override_failure_message(order[i]).is_equal(i)
	var texts := _texts(options)
	assert_int(texts.size()).is_equal(7)  # the four captions and the three volumes' names, nothing else
	assert_array(texts).contains(["Resume", "Restart", "Quit to title", "Quit game"])
	for key: String in BuildScreen.VOLUMES:
		var volume: Label = options.get_node("Volume_%s/Label" % key)
		assert_str(volume.text).starts_with(BuildScreen.VOLUME_TITLES[key] + " ")
	# The buttons keep their size (the caption centred on the patch), and the column fits the page.
	assert_float((options.get_node("Resume") as Control).size.x).is_equal(BuildScreen.BUTTON_SIZE.x)
	var needed := options.get_combined_minimum_size()
	assert_float(needed.y).override_failure_message("options need %s, the page gives %s" % [needed, options.size]).is_less_equal(BuildScreen.CONTENT_SIZE.y)
	var last: Control = options.get_node("QuitGame")
	assert_float(last.position.y + last.size.y).is_less_equal(BuildScreen.CONTENT_SIZE.y)
	# The two quits sit at the bottom of the page.
	assert_float(last.position.y + last.size.y).is_equal_approx(options.size.y, 1.0)


func test_the_boons_page_holds_the_build_rows() -> void:
	var main := quiet_main()
	RunState.build.add_rank(UpgradeCatalog.upgrades()["fire_rate"])
	Events.build_changed.emit()
	await _press("build_screen")
	var screen := _screen(main)
	var boons: VBoxContainer = screen.boons
	assert_bool(boons.is_visible_in_tree()).is_true()
	assert_bool(screen.options.is_visible_in_tree()).is_false()
	assert_array(boons.get_children().map(func(n: Node) -> String: return n.name)).is_equal(["Row_weapon", "Row_fire_rate"])
	assert_array(_texts(boons)).contains_exactly(["Handgun", "Rapid fire", "1/3", "+25% fire rate"])


func test_esc_opens_on_options_and_tab_on_boons() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("pause")
	assert_str(screen.current_tab).is_equal("options")
	assert_bool(screen.options.is_visible_in_tree()).is_true()
	assert_bool(screen.boons.is_visible_in_tree()).is_false()
	assert_bool(screen.training.is_visible_in_tree()).is_false()
	await _press("build_screen")  # Tab closes what Esc opened
	assert_bool(screen.is_open()).is_false()
	await _press("build_screen")
	assert_str(screen.current_tab).is_equal("boons")
	assert_bool(screen.boons.is_visible_in_tree()).is_true()
	assert_bool(screen.options.is_visible_in_tree()).is_false()
	# A tab shown before a close does not carry over: Esc opens on Options again.
	await _press("build_screen")
	await _press("pause")
	assert_str(screen.current_tab).is_equal("options")


## A click on a tab shows its page and lights it; the other tabs dim.
func test_a_tab_press_swaps_the_content_and_lights_the_tab() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("pause")
	await get_tree().process_frame
	for tab: String in BuildScreen.TABS:
		var lit := Color.WHITE if tab == "options" else BuildScreen.TAB_DIM
		assert_object(screen.tab_colour(tab)).override_failure_message(tab).is_equal(lit)
		assert_object((screen.tab_buttons[tab] as Button).modulate).override_failure_message(tab).is_equal(lit)
	await click_control(screen.tab_buttons["training"])
	await hover_at(Vector2.ZERO)  # the cursor off the strip: the colours read without the hover
	assert_str(screen.current_tab).is_equal("training")
	assert_bool(screen.training.is_visible_in_tree()).is_true()
	assert_bool(screen.options.is_visible_in_tree()).is_false()
	assert_bool(screen.boons.is_visible_in_tree()).is_false()
	for tab: String in BuildScreen.TABS:
		var lit := Color.WHITE if tab == "training" else BuildScreen.TAB_DIM
		assert_object(screen.tab_colour(tab)).override_failure_message(tab).is_equal(lit)
		assert_object((screen.tab_buttons[tab] as Button).modulate).override_failure_message(tab).is_equal(lit)
	assert_bool(screen.is_open()).is_true()  # a tab press never closes the screen
	screen.show_tab("boons")
	assert_bool(screen.boons.is_visible_in_tree()).is_true()
	assert_bool(screen.training.is_visible_in_tree()).is_false()


## The hover brightens a tab from its own colour: a dim tab stays dimmer than the open one, and a
## tab clicked under the cursor keeps the hover once lit.
func test_a_hovered_tab_brightens_from_its_own_colour() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("pause")
	await get_tree().process_frame
	var boons_tab: Button = screen.tab_buttons["boons"]
	await hover_control(boons_tab)
	assert_object(boons_tab.modulate).is_equal(BuildScreen.TAB_DIM * UiTheme.BUTTON_HOVER)
	await hover_at(Vector2.ZERO)
	assert_object(boons_tab.modulate).is_equal(BuildScreen.TAB_DIM)
	await click_control(boons_tab)
	assert_str(screen.current_tab).is_equal("boons")
	assert_object(boons_tab.modulate).is_equal(Color.WHITE * UiTheme.BUTTON_HOVER)
	assert_object((screen.tab_buttons["options"] as Button).modulate).is_equal(BuildScreen.TAB_DIM)
	await hover_at(Vector2.ZERO)  # the cursor off the strip, not parked on a tab for the next test
	assert_object(boons_tab.modulate).is_equal(Color.WHITE)


## The Training page: a row per line in the table's order, the icon, the name, and the profile's
## rank as lit pips; no price, no coin, nothing to click.
func test_the_training_tab_shows_the_profiles_ranks() -> void:
	var main := quiet_main()
	Profile.save.training = {"offer": 1, "reach": 3}
	Profile.save.money = 500
	var screen := _screen(main)
	await _press("pause")
	screen.show_tab("training")
	var training: VBoxContainer = screen.training
	assert_array(training.get_children().map(func(n: Node) -> String: return n.name)).is_equal(TrainingRules.LINES.keys())
	var ranks := {"offer": 1, "reroll": 0, "mercy": 0, "reach": 3}
	for line: String in TrainingRules.LINES:
		var row: Control = training.get_node(line)
		assert_object(row.get_node_or_null("Slot/Icon")).override_failure_message(line).is_not_null()
		assert_str((row.get_node("Name") as Label).text).is_equal(TrainingRules.name_of(line))
		var pips := row.get_node("Pips").get_children()
		assert_int(pips.size()).override_failure_message(line).is_equal(TrainingRules.max_rank(line))
		var lit := pips.filter(func(p: ColorRect) -> bool: return p.color == Hud.PIP_LIT).size()
		assert_int(lit).override_failure_message(line).is_equal(ranks[line])
	# A look, not a shop: the names and nothing else, no money, no price, no button.
	assert_array(_texts(training)).contains_exactly(["Offer", "Reroll", "Mercy", "Reach"])
	assert_array(training.find_children("*", "BaseButton", true, false)).is_empty()
	var needed := training.get_combined_minimum_size()
	assert_float(needed.y).is_less_equal(BuildScreen.CONTENT_SIZE.y)


## Quit game saves the volumes first (close() saves), so a slider moved before quitting is kept.
func test_quit_game_saves_the_volumes_first() -> void:
	var main := quiet_main()
	var screen := _screen(main)  # quiet_main pointed its settings_path at SETTINGS_SCRATCH
	await _press("build_screen")
	var slider: HSlider = screen.sliders["sfx"]
	slider.value = 50.0
	var real_quit := get_tree().quit
	screen.quit_requested.disconnect(real_quit)
	var quits := [0]
	screen.quit_requested.connect(func() -> void: quits[0] += 1)
	if not screen.quit_requested.is_connected(real_quit):  # never press with the real quit wired
		(screen.options.get_node("QuitGame") as Button).pressed.emit()
	assert_int(quits[0]).is_equal(1)
	assert_bool(screen.is_open()).is_false()
	assert_float(Settings.load_from(SETTINGS_SCRATCH).sfx).is_equal(0.5)


## Quit game exits the process: Main wires quit_requested to get_tree().quit. The test swaps that
## connection for a counter before pressing the button, so the runner survives the press.
func test_quit_game_asks_main_to_quit_the_process() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("build_screen")
	var quit: Button = screen.options.get_node("QuitGame")
	assert_str((quit.get_node("Text") as Label).text).is_equal("Quit game")  # UiTheme.button captions a child label
	var real_quit := get_tree().quit
	assert_bool(screen.quit_requested.is_connected(real_quit)).is_true()
	screen.quit_requested.disconnect(real_quit)
	assert_bool(screen.quit_requested.is_connected(real_quit)).is_false()
	var quits := [0]
	screen.quit_requested.connect(func() -> void: quits[0] += 1)
	if not screen.quit_requested.is_connected(real_quit):  # never press with the real quit wired
		quit.pressed.emit()
	assert_int(quits[0]).is_equal(1)


func test_sliders_show_the_saved_volumes_and_drive_the_buses() -> void:
	var main := quiet_main()
	var screen := _screen(main)  # quiet_main pointed its settings_path at SETTINGS_SCRATCH
	Audio.settings.set_volume("sfx", 0.8)
	await _press("build_screen")
	var slider: HSlider = screen.sliders["sfx"]
	assert_float(slider.value).is_equal(80.0)
	assert_str((screen.options.get_node("Volume_sfx/Label") as Label).text).is_equal("Sound 80")
	slider.value = 50.0
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sfx"))).is_equal_approx(-6.02, 0.05)
	assert_str((screen.options.get_node("Volume_sfx/Label") as Label).text).is_equal("Sound 50")
	await _press("build_screen")
	assert_float(Settings.load_from(SETTINGS_SCRATCH).sfx).is_equal(0.5)


func test_resume_closes_and_quit_returns_to_the_title() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("build_screen")
	(screen.options.get_node("Resume") as Button).pressed.emit()
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	await _press("build_screen")
	(screen.options.get_node("QuitToTitle") as Button).pressed.emit()
	assert_bool(screen.is_open()).is_false()
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
