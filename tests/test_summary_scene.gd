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
	assert_str(summary.get_node("Center/Box/Body").text).contains("Rounds cleared 0/%d" % main.series_def.rounds.size())
	assert_int(summary.layer).is_greater(main.get_node("Fade").layer)  # the card reads over a fade


func test_win_shows_the_summary() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var summary: CanvasLayer = main.get_node("Summary")
	Events.round_cleared.emit()
	await real_seconds(1.2)
	assert_bool(summary.visible).is_true()
	assert_str(summary.get_node("Center/Box/Title").text).is_equal("Floor cleared")
	assert_str(summary.get_node("Center/Box/Body").text).contains("Rounds cleared 1/1")


func test_a_cheated_run_is_marked_on_the_summary() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	RunState.cheats = {"immortal": true}
	Events.round_cleared.emit()
	await real_seconds(1.2)
	assert_bool(main.get_node("Summary").visible).is_true()
	assert_str(main.get_node("Summary/Center/Box/Body").text).ends_with("\nCheats immortal")


func test_dying_during_the_win_delay_keeps_the_win() -> void:
	# The last clear ends the run; a stray bolt afterwards must not turn it into a death card.
	var main := quiet_main_with_series(tiny_series(1))
	var player: Player = main.get_node("Player")
	var summary: CanvasLayer = main.get_node("Summary")
	Events.round_cleared.emit()
	await real_seconds(0.5)  # the death card would land at 1.1 s, after the win card at 1.0 s
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	await real_seconds(1.2)
	assert_bool(summary.visible).is_true()
	assert_str(summary.get_node("Center/Box/Title").text).is_equal("Floor cleared")


func test_r_on_the_summary_restarts() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var summary: CanvasLayer = main.get_node("Summary")
	var restarts := [0]
	main.restart_requested.connect(func() -> void: restarts[0] += 1)
	Events.round_cleared.emit()
	await real_seconds(1.2)
	assert_bool(summary.visible).is_true()
	var press := InputEventAction.new()
	press.action = "restart"
	press.pressed = true
	Input.parse_input_event(press)
	await ticks(2)
	Input.action_release("restart")  # Input state is global: a held action is never "just pressed" again in a later suite
	assert_int(restarts[0]).is_equal(1)
	assert_bool(summary.visible).is_false()
	assert_bool(main.get_node("Title").is_open()).is_false()  # R is a fresh run, not the title


func test_escape_on_the_summary_returns_to_the_title() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	Events.round_cleared.emit()
	await real_seconds(1.2)
	assert_bool(main.get_node("Summary").visible).is_true()
	await get_tree().process_frame
	Input.action_press("pause")
	await ticks(2)
	Input.action_release("pause")
	assert_bool(main.get_node("Title").is_open()).is_true()
	assert_bool(main.get_node("Summary").visible).is_false()
