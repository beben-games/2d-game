extends SceneSuite
## Tab pauses and lists the build; Tab or Escape closes; it never opens over the picker or after the run ends.


func _screen(main: Node) -> BuildScreen:
	return main.get_node("BuildScreen")


func _press(action: String) -> void:
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
	assert_array(texts).contains(["Handgun", "Heavy rounds", "2 of 3", "+1 damage", "Dash charge", "1 of 2"])
	await _press("build_screen")
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_escape_closes_and_an_empty_build_says_so() -> void:
	var main := quiet_main()
	await _press("build_screen")
	var screen := _screen(main)
	assert_bool(screen.is_open()).is_true()
	assert_array(_texts(screen.lines)).contains(["No upgrades yet"])
	await _press("ui_cancel")
	assert_bool(screen.is_open()).is_false()


func test_it_does_not_open_over_the_picker() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	Events.room_cleared.emit()
	await get_tree().process_frame
	await _press("build_screen")
	assert_bool(_screen(main).is_open()).is_false()
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_true()


func test_it_does_not_open_after_the_run_ended() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	await wait_for_death_freeze()
	await _press("build_screen")
	assert_bool(_screen(main).is_open()).is_false()
