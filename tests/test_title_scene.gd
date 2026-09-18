extends SceneSuite
## The front door: Main boots into the title with the tree paused; Play starts the run on the
## seed from the field in a room rebuilt for it; quiet_main() skips it; Quit to title returns.


## The reload flag is process-wide: a test that sets it must not leave it for the next.
func after_test() -> void:
	Main._skip_title_once = false
	super()


## Main as the game boots it: the title up, the runner quiet.
func _main_at_title() -> Main:
	var main: Main = load(MAIN).instantiate()
	add_child(main)
	auto_free(main)
	main.get_node("Room/WaveRunner").enabled = false
	return main


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
	assert_str(Audio.current_music).is_equal("music_run")
	assert_int(Audio.plays.get("ui_play", 0)).is_equal(1)


func test_the_seed_field_keeps_digits_only_and_blank_means_random() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	await _type("1a2b")  # real keys: insert_text_at_caret never emits text_changed (probed on 4.7.2)
	assert_str(title.seed_field.text).is_equal("12")
	assert_int(title.seed_value()).is_equal(12)
	title.seed_field.text = ""
	assert_int(title.seed_value()).is_equal(-1)


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


func test_play_rebuilds_the_first_room_on_the_new_seed() -> void:
	var main := _main_at_title()
	var old_room: Node = main.get_node("Room")
	var title: Title = main.get_node("Title")
	title.seed_field.text = "7"
	title.play()
	await get_tree().process_frame
	assert_bool(is_instance_valid(old_room)).is_false()
	assert_int(RunState.room).is_equal(0)
	assert_object(main.get_node("Player").projectile_parent).is_same(main.get_node("Room/Projectiles"))
	assert_bool(main.get_node("Room/WaveRunner").enabled).is_true()  # the run is live


func test_enter_plays_from_the_field() -> void:
	var main := _main_at_title()
	var title: Title = main.get_node("Title")
	await get_tree().process_frame
	Input.action_press("ui_accept")
	await ticks(2)
	Input.action_release("ui_accept")
	assert_bool(title.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


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
	assert_bool(Main._skip_title_once).is_false()  # the reload it causes in the game shows the title


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


func test_tab_and_r_do_nothing_at_the_title() -> void:
	var main := _main_at_title()
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	await get_tree().process_frame
	Input.action_press("build_screen")
	await ticks(2)
	Input.action_release("build_screen")
	Input.action_press("restart")
	await ticks(2)
	Input.action_release("restart")
	assert_bool(main.get_node("BuildScreen").is_open()).is_false()
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_int(restarts[0]).is_equal(0)
