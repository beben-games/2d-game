extends SceneSuite
## The pause screen: Esc or Tab opens it paused and closes it; the options column holds Resume,
## Restart, the three volume sliders (live on the buses, saved on close), and Quit to title; the
## build column lists the build; R restarts from it; it never opens over the picker or after the
## run ends; the widest catalog rows fit inside the build column.

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
	var lines: VBoxContainer = screen.lines
	assert_object(lines.get_node_or_null("Row_damage_handgun")).is_not_null()
	assert_object(lines.get_node_or_null("Row_dash_charge")).is_not_null()
	var texts := _texts(lines)
	# The effect column is the total at the owned rank (summary), not the card's per-pick line.
	assert_array(texts).contains(["Handgun", "Heavy rounds", "2/3", "+2 damage", "Dash charge", "1/2", "+1 dash"])
	assert_array(texts).not_contains(["+1 damage"])
	# Column order: icon, name, rank, effect.
	var rank: Label = lines.get_node("Row_damage_handgun").get_child(2)
	assert_str(rank.text).is_equal("2/3")
	var effect: Label = lines.get_node("Row_damage_handgun").get_child(3)
	assert_str(effect.text).is_equal("+2 damage")
	# The weapon row is the heading, on the title font; the upgrade rows are body text.
	var weapon_name: Label = lines.get_node("Row_weapon").get_child(1)
	assert_object(weapon_name.get_theme_font("font")).is_same(UiTheme.TITLE_FONT)
	var upgrade_name: Label = lines.get_node("Row_damage_handgun").get_child(1)
	assert_object(upgrade_name.get_theme_font("font")).is_same(UiTheme.FONT)
	await _press("build_screen")
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_escape_closes_and_an_empty_build_says_so() -> void:
	var main := quiet_main()
	await _press("build_screen")
	var screen := _screen(main)
	assert_bool(screen.is_open()).is_true()
	assert_array(_texts(screen.lines)).contains(["No upgrades yet"])
	await _press("pause")
	assert_bool(screen.is_open()).is_false()


func test_a_rank_added_while_closed_shows_on_the_next_open() -> void:
	var main := quiet_main()
	var screen := _screen(main)
	await _press("build_screen")
	assert_object(screen.lines.get_node_or_null("Row_fire_rate")).is_null()
	await _press("build_screen")
	RunState.build.add_rank(UpgradeCatalog.upgrades()["fire_rate"])
	Events.build_changed.emit()
	await _press("build_screen")
	assert_bool(screen.is_open()).is_true()
	assert_object(screen.lines.get_node_or_null("Row_fire_rate")).is_not_null()


## The reachable maximum: the eight-room floor gives seven picks, so seven distinct upgrades is
## the tallest build. Seeded with the widest names and effects the catalog has.
func test_the_widest_rows_fit_inside_the_panel() -> void:
	var main := quiet_main()
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.switch_weapon("crossbow")
	for id: String in ["pierce_crossbow", "flaming", "chill", "damage_crossbow", "bounce_crossbow", "heart_container", "dash_charge"]:
		RunState.build.add_rank(catalog[id])
	Events.build_changed.emit()
	await _press("build_screen")
	await get_tree().process_frame
	var lines: VBoxContainer = _screen(main).lines
	assert_int(lines.get_child_count()).is_equal(9)  # the weapon, seven upgrades, the hint
	var columns: HBoxContainer = _screen(main).panel.get_node("Columns")
	# A Control grows past its set size when the children need more, and lines would grow with it.
	assert_vector(columns.size).is_equal(BuildScreen.PANEL_SIZE - Vector2(BuildScreen.INSET, BuildScreen.INSET) * 2.0)
	var box := lines.size  # the build column: three quarters of the inner box after the separation
	assert_float(box.x).is_greater_equal(860.0)
	assert_float(box.x).is_less_equal(864.0)
	var needed := lines.get_combined_minimum_size()
	assert_float(needed.x).override_failure_message("rows need %s, the column gives %s" % [needed, box]).is_less_equal(box.x)
	assert_float(needed.y).override_failure_message("rows need %s, the column gives %s" % [needed, box]).is_less_equal(box.y)


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
	var main := quiet_main_with_floor(tiny_floor(2))
	Events.room_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	await _press("build_screen")
	assert_bool(_screen(main).is_open()).is_false()
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_true()


func test_escape_over_the_picker_leaves_it_paused_and_open() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	Events.room_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	await _press("pause")
	assert_bool(get_tree().paused).is_true()
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_true()
	assert_bool(_screen(main).is_open()).is_false()


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
	var effect: Label = _screen(main).lines.get_node("Row_fire_rate").get_child(3)
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


func test_the_options_column_holds_the_controls_and_the_build_column_the_rows() -> void:
	var main := quiet_main()
	await _press("build_screen")
	var screen := _screen(main)
	var options: VBoxContainer = screen.options
	for child_name: String in ["Heading", "Resume", "Restart", "Volume_master", "Volume_sfx", "Volume_music", "QuitToTitle", "QuitGame"]:
		assert_object(options.get_node_or_null(child_name)).override_failure_message(child_name).is_not_null()
	assert_float(options.size.x).is_less(screen.lines.size.x / 2.0)
	assert_float(screen.lines.size.x).is_greater_equal((options.size.x + screen.lines.size.x) * 0.7)
	assert_array(_texts(options)).contains(["Options", "Resume", "Restart", "Quit to title", "Quit game"])
	assert_int(options.get_node("QuitGame").get_index()).is_equal(options.get_node("QuitToTitle").get_index() + 1)
	var last: Control = options.get_node("QuitGame")
	assert_float(last.position.y + last.size.y).is_less_equal(options.size.y)  # the column still fits the panel


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
