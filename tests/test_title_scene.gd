extends SceneSuite
## The front door: Main boots into the title with the tree paused; Play starts the run on the
## seed from the field in a room rebuilt for it; quiet_main() skips it; Quit to title returns.


## The reload flag is process-wide: a test that sets it must not leave it for the next.
func after_test() -> void:
	Main._skip_title_once = false
	await super()  # the base awaits a frame


## Main as the game boots it: the title up, the runner quiet.
func _main_at_title() -> Main:
	var main: Main = load(MAIN).instantiate()
	add_child(main)
	return quiet(main)


func test_boot_shows_the_title_paused_and_play_starts_the_run() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	assert_bool(title.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_str(Audio.current_music).is_equal("music_run")
	assert_str(title.get_node("Center/Box/Name").text).is_equal(Title.GAME_NAME)
	assert_str(title.get_node("Version").text).is_equal("v" + str(ProjectSettings.get_setting("application/config/version")))
	title.seed_field.text = "42"
	title.play()
	await get_tree().process_frame  # the old room's queue_free lands, or the runner counts it as orphans
	assert_bool(title.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(RunState.seed_value).is_equal(42)
	assert_that(RunState.cheats).is_equal({})  # a number is a seed, never a cheat
	assert_str(Audio.current_music).is_equal("music_run")
	assert_int(Audio.plays.get("ui_play", 0)).is_equal(1)


func test_the_seed_field_takes_letters_but_only_digits_are_a_seed() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	await _type("1a2b")  # real keys: insert_text_at_caret never emits text_changed (probed on 4.7.2)
	assert_str(title.seed_field.text).is_equal("1a2b")  # letters stay: a cheat code is typed here
	assert_int(title.parsed()["seed"]).is_equal(-1)  # junk is a random seed, never a code word's seed
	title.seed_field.text = "12"
	assert_int(title.parsed()["seed"]).is_equal(12)
	title.seed_field.text = ""
	assert_int(title.parsed()["seed"]).is_equal(-1)
	assert_int(title.seed_field.max_length).is_greater_equal("permawhat?".length())


## Junk in the field (text that is neither a seed nor a code word) is tinted so the player sees
## it will be ignored; a seed, a code word, or a blank field keeps the plain colour.
func test_junk_in_the_seed_field_is_tinted_and_a_seed_or_code_is_not() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	await _type("12")
	assert_bool(title.seed_field.has_theme_color_override("font_color")).is_false()
	await _type("x")
	assert_str(title.seed_field.text).is_equal("12x")
	assert_bool(title.seed_field.has_theme_color_override("font_color")).is_true()
	assert_that(title.seed_field.get_theme_color("font_color")).is_equal(Title.JUNK_TINT)
	title.open()  # clears the field and its tint
	assert_bool(title.seed_field.has_theme_color_override("font_color")).is_false()
	await _type("permawhat")
	assert_bool(title.seed_field.has_theme_color_override("font_color")).is_true()  # not a code yet
	title._on_seed_text_changed("permawhat?")  # the '?' needs a shifted key; the handler is what a key reaches
	assert_bool(title.seed_field.has_theme_color_override("font_color")).is_false()
	title._on_seed_text_changed("")
	assert_bool(title.seed_field.has_theme_color_override("font_color")).is_false()


## The HUD has nothing to say under the title (the hearts, the counters, and the build strip of
## the boot room would show through the dim), so Main hides it there and shows it on Play.
func test_the_hud_hides_under_the_title_and_returns_on_play() -> void:
	var main := _main_at_title()
	var hud: CanvasLayer = main.get_node("HUD")
	assert_bool(hud.visible).is_false()
	main.get_node("Title").play()
	await get_tree().process_frame
	assert_bool(hud.visible).is_true()
	main.quit_to_title()
	await get_tree().process_frame
	assert_bool(hud.visible).is_false()


## Quit exits the process: Main wires quit_requested to get_tree().quit. The test swaps that
## connection for a counter before pressing the button, so the runner survives the press.
func test_quit_below_the_seed_field_asks_main_to_quit_the_game() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	var quit: Button = title.box.get_node("Quit")
	assert_str((quit.get_node("Text") as Label).text).is_equal("Quit")  # UiTheme.button captions a child label
	assert_int(quit.get_index()).is_equal(title.seed_field.get_index() + 1)
	var real_quit := get_tree().quit
	assert_bool(title.quit_requested.is_connected(real_quit)).is_true()
	title.quit_requested.disconnect(real_quit)
	assert_bool(title.quit_requested.is_connected(real_quit)).is_false()
	var quits := [0]
	title.quit_requested.connect(func() -> void: quits[0] += 1)
	if not title.quit_requested.is_connected(real_quit):  # never press with the real quit wired
		quit.pressed.emit()
	assert_int(quits[0]).is_equal(1)


func test_a_cheat_code_in_the_field_starts_a_cheated_run() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	title.seed_field.text = "permawhat?"
	title.play()
	await get_tree().process_frame
	assert_bool(title.is_open()).is_false()
	assert_that(RunState.cheats).is_equal({"immortal": true})
	var player: Player = main.get_node("Player")
	assert_bool(player.hurt(1, player.global_position + Vector2(4, 0))).is_false()
	assert_int(player.hp).is_equal(player.max_hp)


## Types into the focused control the way a player does: one key event per character, flushed
## on the next frame.
func _type(text: String) -> void:
	for ch in text:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = OS.find_keycode_from_string(ch) as Key
		key.unicode = ch.unicode_at(0)
		Input.parse_input_event(key)
		await ticks(2)
		var release := InputEventKey.new()
		release.keycode = key.keycode
		Input.parse_input_event(release)
		await ticks(2)


func test_play_rebuilds_the_arena_on_the_new_seed() -> void:
	var main := _main_at_title()
	var old_room: Node = main.get_node("Room")
	var title: Title = main.get_node("Title")
	title.seed_field.text = "7"
	title.play()
	await get_tree().process_frame
	assert_bool(is_instance_valid(old_room)).is_false()
	assert_int(RunState.round_index).is_equal(0)
	assert_object(main.get_node("Player").projectile_parent).is_same(main.get_node("Room/Projectiles"))
	assert_bool(main.get_node("Room/WaveRunner").enabled).is_true()  # the run is live


func test_enter_plays_from_the_field() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	await get_tree().process_frame
	Input.action_press("title_play")
	await ticks(2)
	Input.action_release("title_play")
	assert_bool(title.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


## Space is the dash: it must not start the run, or the player's first tick would dash on it. A
## real key, not the dash action, so it pins that Space is in no title action at all.
func test_space_at_the_title_neither_plays_nor_dashes() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_SPACE
	key.unicode = 32
	Input.parse_input_event(key)
	await ticks(2)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	Input.parse_input_event(release)
	await ticks(2)
	assert_bool(title.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(Audio.plays.has("dash")).is_false()


func test_the_play_button_starts_the_run() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	title.play_button.pressed.emit()
	await get_tree().process_frame
	assert_bool(title.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_fields_own_submit_starts_the_run_on_its_seed() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	title.seed_field.text = "42"
	title.seed_field.text_submitted.emit("42")
	await get_tree().process_frame
	assert_bool(title.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(RunState.seed_value).is_equal(42)


## The boot starts round 0 before the title pauses, so its room_enter and wave_start freeze on
## the game pool; without the title stopping them, Play resumes them next to the rebuilt arena's pair.
func test_play_does_not_double_the_boot_rounds_sounds() -> void:
	var enter_previous := Audio.override_stream("room_enter", AudioStreamGenerator.new(), 0.0)
	var wave_previous := Audio.override_stream("wave_start", AudioStreamGenerator.new(), 0.0)
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	title.play()
	await get_tree().process_frame
	var playing := 0
	for i in Audio.GAME_POOL:
		if (Audio.get_node("Game%d" % i) as AudioStreamPlayer).playing:
			playing += 1
	assert_int(playing).is_equal(2)
	Audio.stop_game_sounds()  # the generators never end on their own
	Audio.override_stream("room_enter", enter_previous["stream"], float(enter_previous["min_gap"]))
	Audio.override_stream("wave_start", wave_previous["stream"], float(wave_previous["min_gap"]))


func test_quiet_main_skips_the_title() -> void:
	var main := quiet_main()
	assert_bool(main.get_node("Title").is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_quit_to_title_shows_it_again_over_a_fresh_run() -> void:
	var main := quiet_main()
	RunState.build.add_rank(UpgradeCatalog.upgrade("fire_rate"))
	main.quit_to_title()
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(RunState.build.rank_of("fire_rate")).is_equal(0)
	assert_str(Audio.current_music).is_equal("music_run")
	# Cannot fail in a harness: only a real reload exercises restart()'s set site. What it pins is
	# the clear after that call, so the reload Quit to title queues in the game lands on the title.
	assert_bool(Main._skip_title_once).is_false()


## In the game R reloads the scene; the reload cannot carry state, so a one-shot static flag
## tells the new _ready to go straight into the run. A harness cannot reload, so the flag's
## contract is tested directly: honoured once, then cleared.
func test_r_restart_skips_the_title_on_the_reload() -> void:
	Main._skip_title_once = true
	var after_r := _main_at_title()
	assert_bool(after_r.get_node("Title").is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(Main._skip_title_once).is_false()
	after_r.queue_free()
	await get_tree().process_frame
	var cold := _main_at_title()  # the flag was one-shot: the next boot is a cold one
	assert_bool(cold.get_node("Title").is_open()).is_true()
	assert_bool(get_tree().paused).is_true()


func test_tab_esc_and_r_do_nothing_at_the_title() -> void:
	var main := _main_at_title()
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await get_tree().process_frame
	Input.action_press("build_screen")
	await ticks(2)
	Input.action_release("build_screen")
	assert_bool(main.get_node("BuildScreen").is_open()).is_false()
	Input.action_press("pause")
	await ticks(2)
	Input.action_release("pause")
	Input.action_press("restart")
	await ticks(2)
	Input.action_release("restart")
	assert_bool(main.get_node("BuildScreen").is_open()).is_false()
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_int(restarts[0]).is_equal(0)
