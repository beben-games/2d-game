extends SceneSuite


func test_death_shows_the_summary_after_a_beat_and_waits_for_r() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var summary: CanvasLayer = main.get_node("Summary")
	assert_bool(summary.visible).is_false()
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).is_true()
	assert_bool(summary.visible).is_false()  # the burst plays first
	await real_seconds(0.9)
	assert_bool(summary.visible).is_true()
	assert_str(summary.get_node("Center/Box/Title").text).is_equal("You died")
	assert_str(summary.get_node("Center/Box/Body").text).contains("Rooms cleared 0/%d" % main.floor_def.rooms.size())


func test_win_shows_the_summary() -> void:
	var main := quiet_main_with_floor(tiny_floor(1))
	var summary: CanvasLayer = main.get_node("Summary")
	Events.room_cleared.emit()
	await real_seconds(1.2)
	assert_bool(summary.visible).is_true()
	assert_str(summary.get_node("Center/Box/Title").text).is_equal("Floor cleared")
	assert_str(summary.get_node("Center/Box/Body").text).contains("Rooms cleared 1/1")


func test_dying_during_the_win_delay_keeps_the_win() -> void:
	# The last clear ends the run; a stray bolt afterwards must not turn it into a death card.
	var main := quiet_main_with_floor(tiny_floor(1))
	var player: Player = main.get_node("Player")
	var summary: CanvasLayer = main.get_node("Summary")
	Events.room_cleared.emit()
	await real_seconds(0.5)  # the death card would land at 1.1 s, after the win card at 1.0 s
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	await real_seconds(1.2)
	assert_bool(summary.visible).is_true()
	assert_str(summary.get_node("Center/Box/Title").text).is_equal("Floor cleared")


func test_death_during_a_room_fade_shows_the_summary_over_the_black() -> void:
	# A bolt can kill during the 0.15 s fade-out; Main stops the swap and the summary reads over the fade.
	var main := quiet_main_with_floor(tiny_floor(2))
	var player: Player = main.get_node("Player")
	var summary: CanvasLayer = main.get_node("Summary")
	await clear_and_pick(main)
	Events.room_exit_requested.emit()
	await get_tree().process_frame
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))  # lethal, inside the fade
	await real_seconds(1.0)
	assert_int(main.room_index).is_equal(0)
	assert_float(main.fade.color.a).is_equal(1.0)  # the fade stayed black
	assert_bool(summary.visible).is_true()
	assert_int(summary.layer).is_greater(main.get_node("Fade").layer)
