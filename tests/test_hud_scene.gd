extends SceneSuite


func _hearts(main: Node) -> Array:
	var names := []
	for heart in main.get_node("HUD/Hearts").get_children():
		names.append(heart.name)
	return names


func test_hud_starts_full_and_follows_hits() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	assert_array(_hearts(main)).is_equal(["full0", "full1", "full2"])
	player.hurt(1, player.global_position + Vector2(4, 0))
	await get_tree().process_frame
	assert_array(_hearts(main)).is_equal(["full0", "full1", "half2"])


func test_hud_shows_room_wave_and_kills() -> void:
	var main := quiet_main()
	var info: Label = main.get_node("HUD/Info")
	assert_str(info.text).is_equal("Room 1/4   Wave 1/2   Kills 0")
	Events.wave_started.emit(1, 2)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2.ZERO)
	await get_tree().process_frame
	assert_str(info.text).is_equal("Room 1/4   Wave 2/2   Kills 1")
