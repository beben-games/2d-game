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


func test_hud_shows_round_wave_and_kills() -> void:
	var main := quiet_main()
	var info: Label = main.get_node("HUD/Info")
	assert_str(info.text).is_equal("Round 1/8   Wave 1/2   Kills 0")
	Events.wave_started.emit(1, 2)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2.ZERO)
	await get_tree().process_frame
	assert_str(info.text).is_equal("Round 1/8   Wave 2/2   Kills 1")


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
	assert_that(strip.get_node("Weapon").texture.region).is_equal(IconAtlas.texture("handgun").region)
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
	var rank: Label = strip.get_node("W_damage_handgun/Rank")
	assert_object(rank.get_theme_font("font")).is_same(UiTheme.FONT)  # the pixel font, on its 16 px grid
	assert_int(rank.get_theme_font_size("font_size")).is_equal(16)
	assert_that(strip.get_node("W_damage_handgun").texture.region).is_equal(IconAtlas.texture("damage").region)
	RunState.build.switch_weapon("crossbow")
	Events.build_changed.emit()
	await get_tree().process_frame
	assert_array(_names(strip)).is_equal(["Weapon", "P_heart_container"])
	assert_that(strip.get_node("Weapon").texture.region).is_equal(IconAtlas.texture("crossbow").region)


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


func test_a_hit_flashes_the_vignette_then_it_fades() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var hud: CanvasLayer = main.get_node("HUD")
	assert_float(hud.vignette.modulate.a).is_equal(0.0)
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_float(hud.vignette.modulate.a).is_equal_approx(hud.VIGNETTE_ALPHA, 0.001)  # Color stores 32-bit floats
	await real_seconds(hud.VIGNETTE_TIME + 0.05)
	assert_float(hud.vignette.modulate.a).is_equal(0.0)


func test_the_favour_meter_follows_favour_changed_in_the_bands_colour() -> void:
	var main := quiet_main()
	var hud: CanvasLayer = main.get_node("HUD")
	assert_bool(hud.favour_bar.visible).is_true()
	assert_float(hud.favour_fill_ratio()).is_equal_approx(FavourRules.START / FavourRules.MAX, 0.001)
	assert_that(hud.favour_fill_colour()).is_equal(hud.FAVOUR_FILL[FavourRules.QUIET])
	Events.favour_changed.emit(60.0, FavourRules.CHEER, "kill")
	assert_float(hud.favour_fill_ratio()).is_equal_approx(0.6, 0.001)
	assert_that(hud.favour_fill_colour()).is_equal(hud.FAVOUR_FILL[FavourRules.CHEER])
	Events.favour_changed.emit(10.0, FavourRules.BOO, "hit")
	assert_float(hud.favour_fill_ratio()).is_equal_approx(0.1, 0.001)
	assert_that(hud.favour_fill_colour()).is_equal(hud.FAVOUR_FILL[FavourRules.BOO])
	Events.favour_changed.emit(100.0, FavourRules.ROAR, "clean_round")
	assert_float(hud.favour_fill_ratio()).is_equal_approx(1.0, 0.001)
	assert_that(hud.favour_fill_colour()).is_equal(hud.FAVOUR_FILL[FavourRules.ROAR])
	assert_int(hud.favour_bar.find_children("*", "Label", true, false).size()).is_equal(0)  # no label: the crowd explains it
	RunState.start_run()
	assert_float(hud.favour_fill_ratio()).is_equal_approx(FavourRules.START / FavourRules.MAX, 0.001)


## The rows under the hearts read by their icons (UI may name): the boot at the left of the dash
## pips, the crowd's mask at the left of the favour meter, each row centred on its icon.
func test_the_dash_pips_and_the_favour_meter_carry_an_icon_at_their_left() -> void:
	var main := quiet_main()
	var hud := hud_of(main)
	await get_tree().process_frame
	var dash_icon: TextureRect = main.get_node("HUD/DashIcon")
	var favour_icon: TextureRect = main.get_node("HUD/FavourIcon")
	assert_that(dash_icon.texture).is_equal(IconAtlas.texture("dash_charge"))
	# PLACEHOLDER: the sheet has no crowd, so the favour icon is two heads drawn in code.
	assert_bool(IconAtlas.has("favour")).is_false()
	var placeholder := favour_icon.texture as ImageTexture
	assert_object(placeholder).is_not_null()
	assert_that(placeholder.get_size()).is_equal(Vector2(IconAtlas.SIZE, IconAtlas.SIZE))
	var colours := {}
	var image := placeholder.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				colours[c.to_html(false)] = true
	assert_array(colours.keys()).contains_exactly_in_any_order([Hud.CROWD_FILL.to_html(false), Hud.CROWD_EDGE.to_html(false)])
	assert_int(favour_icon.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	var icon_size := IconAtlas.SIZE * Hud.ROW_ICON_SCALE
	assert_float(dash_icon.size.x).is_equal(icon_size)
	assert_float(dash_icon.position.x).is_equal(hud.hearts.position.x)
	assert_float(favour_icon.position.x).is_equal(hud.hearts.position.x)
	# Each row sits to the right of its icon, centred on it.
	assert_float(hud.dashes.position.x).is_greater_equal(dash_icon.position.x + icon_size)
	assert_float(hud.favour_bar.position.x).is_greater_equal(favour_icon.position.x + icon_size)
	var dash_centre := hud.dashes.position.y + Hud.PIP_SIZE.y * 0.5
	assert_float(dash_centre).is_equal_approx(dash_icon.position.y + icon_size * 0.5, 0.5)
	var bar_centre := hud.favour_bar.position.y + Hud.FAVOUR_BAR_SIZE.y * 0.5
	assert_float(bar_centre).is_equal_approx(favour_icon.position.y + icon_size * 0.5, 0.5)
	# The dash row sits ROW_STACK_GAP under the hearts (13x12 sprites at 3x: 36 px tall, not an
	# icon's 48), the favour row the same gap under the dash row.
	assert_vector(Hud.heart_size()).is_equal(Vector2(13, 12) * Hud.HEART_SCALE)
	assert_float(dash_icon.position.y).is_equal(hud.hearts.position.y + Hud.heart_size().y + Hud.ROW_STACK_GAP)
	assert_float(favour_icon.position.y).is_equal(dash_icon.position.y + icon_size + Hud.ROW_STACK_GAP)


## A run started from the gate has no scene reload: the strip and the counter must follow run_started.
func test_a_new_run_empties_the_build_strip_and_resets_the_counter() -> void:
	var main := quiet_main()
	var hud := hud_of(main)
	var catalog := UpgradeCatalog.upgrades()
	RunState.build.add_rank(catalog["damage_handgun"])
	RunState.build.add_rank(catalog["heart_container"])
	Events.build_changed.emit()
	RunState.add_coins(12)
	assert_array(_names(hud.build_strip)).is_equal(["Weapon", "W_damage_handgun", "P_heart_container"])
	assert_str(hud.coin_counter_text()).is_equal("12")
	RunState.start_run()
	assert_array(_names(hud.build_strip)).is_equal(["Weapon"])
	assert_str(hud.coin_counter_text()).is_equal("0")
