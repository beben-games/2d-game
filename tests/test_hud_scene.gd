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
	var half: TextureRect = main.get_node("HUD/Hearts").get_child(2)
	assert_that(half.texture.region).is_equal(SpriteAtlas.region("ui_heart_half"))


func test_hud_shows_room_wave_and_kills() -> void:
	var main := quiet_main()
	var info: Label = main.get_node("HUD/Info")
	assert_str(info.text).is_equal("Room 1/8   Wave 1/2   Kills 0")
	Events.wave_started.emit(1, 2)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2.ZERO)
	await get_tree().process_frame
	assert_str(info.text).is_equal("Room 1/8   Wave 2/2   Kills 1")


func _names(container: Node) -> Array:
	var names := []
	for child in container.get_children():
		names.append(child.name)
	return names


func test_hearts_grow_to_six_with_heart_containers() -> void:
	var main := quiet_main()
	var heart := UpgradeCatalog.upgrade("heart_container")
	for i in 3:
		RunState.build.add_rank(heart)
	Events.build_changed.emit()
	await get_tree().process_frame
	assert_array(_hearts(main)).is_equal(["full0", "full1", "full2", "full3", "full4", "full5"])


func test_dash_pips_follow_the_charges() -> void:
	var main := quiet_main()
	assert_array(_names(main.get_node("HUD/Dashes"))).is_equal(["lit0"])
	Events.dash_charges_changed.emit(1, 2)
	await get_tree().process_frame
	assert_array(_names(main.get_node("HUD/Dashes"))).is_equal(["lit0", "dim1"])
	var lit: ColorRect = main.get_node("HUD/Dashes/lit0")
	assert_that(lit.color).is_equal(main.get_node("HUD").PIP_LIT)


func test_build_strip_lists_the_weapon_and_owned_upgrades_with_ranks() -> void:
	var main := quiet_main()
	var strip: HBoxContainer = main.get_node("HUD/BuildStrip")
	assert_array(_names(strip)).is_equal(["Weapon"])
	assert_that(strip.get_node("Weapon").texture.region).is_equal(IconAtlas.region("handgun"))
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.add_rank(catalog["damage_handgun"])
	RunState.build.add_rank(catalog["damage_handgun"])
	RunState.build.add_rank(catalog["heart_container"])
	RunState.build.add_rank(catalog["homing"])
	Events.build_changed.emit()
	await get_tree().process_frame
	assert_array(_names(strip)).is_equal(["Weapon", "W_damage_handgun", "W_homing", "P_heart_container"])
	assert_str(strip.get_node("W_damage_handgun/Rank").text).is_equal("2")
	assert_object(strip.get_node_or_null("W_homing/Rank")).is_null()  # one rank: no digit
	assert_str(strip.get_node("P_heart_container/Rank").text).is_equal("1")
	assert_that(strip.get_node("W_damage_handgun").texture.region).is_equal(IconAtlas.region("damage"))
	RunState.build.switch_weapon("crossbow")
	Events.build_changed.emit()
	await get_tree().process_frame
	assert_array(_names(strip)).is_equal(["Weapon", "P_heart_container"])
	assert_that(strip.get_node("Weapon").texture.region).is_equal(IconAtlas.region("crossbow"))


func test_hud_reads_the_build_at_ready() -> void:
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.add_rank(catalog["dash_charge"])
	RunState.build.add_rank(catalog["heart_container"])
	var main := quiet_main()
	assert_array(_names(main.get_node("HUD/Dashes"))).is_equal(["lit0", "lit1"])
	assert_array(_hearts(main)).is_equal(["full0", "full1", "full2", "full3"])


func test_the_boss_bar_shows_on_spawn_tracks_hp_and_hides_on_death() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var hud: CanvasLayer = main.get_node("HUD")
	assert_bool(hud.boss_bar.visible).is_false()
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	boss.def.approach_time = 100.0
	await ticks(2)
	assert_bool(hud.boss_bar.visible).is_true()
	assert_str((hud.boss_bar.get_node("Name") as Label).text).is_equal(boss.def.display_name)
	assert_float(hud.boss_fill_ratio()).is_equal(1.0)
	boss.health.take_damage(boss.def.max_hp * 0.25)
	await real_seconds(hud.BOSS_BAR_TWEEN + 0.05)
	assert_float(hud.boss_fill_ratio()).is_equal_approx(0.75, 0.02)
	boss.health.take_damage(1000.0)
	await get_tree().process_frame
	assert_bool(hud.boss_bar.visible).is_false()


func test_a_new_run_hides_the_boss_bar() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var hud: CanvasLayer = main.get_node("HUD")
	active_boss_on(main, player.global_position + Vector2(150, 0))
	await ticks(2)
	assert_bool(hud.boss_bar.visible).is_true()
	RunState.start_run()
	assert_bool(hud.boss_bar.visible).is_false()
