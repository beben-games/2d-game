extends SceneSuite
## Every gameplay moment reaches Audio: the counters say which sound each signal chose.

const PROJECTILE := preload("res://scenes/projectile.tscn")


func _plays(name: String) -> int:
	return int(Audio.plays.get(name, 0))


func test_a_shot_names_its_weapon_and_a_wall_ends_it_with_a_tap() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.aim_override = player.global_position + Vector2(100, 0)
	Input.action_press("shoot")
	await ticks(2)
	Input.action_release("shoot")
	assert_int(_plays("shot_handgun")).is_equal(1)
	await ticks(120)  # 320 px/s across the room: the shot dies on the right wall
	assert_int(_plays("shot_wall")).is_equal(1)
	RunState.build.switch_weapon("crossbow")
	Events.build_changed.emit()
	await get_tree().process_frame
	Input.action_press("shoot")
	await ticks(2)
	Input.action_release("shoot")
	assert_int(_plays("shot_crossbow")).is_equal(1)


func test_a_bounce_pings() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var weapon: WeaponDef = UpgradeCatalog.weapon("handgun").duplicate()
	weapon.bounce = 1
	var shot: Projectile = PROJECTILE.instantiate()
	shot.setup(weapon, Vector2.RIGHT)
	projectiles_of(main).add_child(shot)
	shot.global_position = player.global_position
	await ticks(120)
	assert_int(_plays("shot_bounce")).is_equal(1)


func test_hits_and_deaths_by_enemy_and_burn_ticks_stay_quiet() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var imp := active_chaser_on(main, player.global_position + Vector2(80, 0))
	var shaman := active_shooter_on(main, player.global_position + Vector2(-80, 0))
	imp.health.take_damage(1.0)
	assert_int(_plays("hit_enemy")).is_equal(1)
	imp.get_node("Status").apply_burn()
	assert_int(_plays("status_burn")).is_equal(1)
	imp.get_node("Status").apply_burn()  # a refresh is not a new ignition
	assert_int(_plays("status_burn")).is_equal(1)
	await ticks(33)  # the first burn tick: quiet, no hit sound
	assert_int(_plays("hit_enemy")).is_equal(1)
	imp.health.take_damage(100.0)
	shaman.health.take_damage(100.0)
	assert_int(_plays("die_imp")).is_equal(1)
	assert_int(_plays("die_shaman")).is_equal(1)
	await wait_for_death_freeze()


func test_stun_and_chill_have_their_sounds() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var imp := active_chaser_on(main, player.global_position + Vector2(80, 0))
	imp.get_node("Status").apply_stun()
	imp.get_node("Status").apply_chill()
	assert_int(_plays("status_shock")).is_equal(1)
	assert_int(_plays("status_chill")).is_equal(1)


func test_a_shooter_telegraphs_then_fires() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	active_shooter_on(main, player.global_position + Vector2(100, 0))
	await ticks(5)
	assert_int(_plays("telegraph")).is_equal(1)
	assert_int(_plays("bolt_fire")).is_equal(0)
	await ticks(32)
	assert_int(_plays("bolt_fire")).is_equal(1)


func test_the_player_hurts_heals_dashes_and_dies() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_int(_plays("player_hurt")).is_equal(1)
	player.heal(1)
	assert_int(_plays("player_heal")).is_equal(1)
	await get_tree().process_frame
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	assert_int(_plays("dash")).is_equal(1)
	Audio.music("music_run")
	player.invuln_left = 0.0
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_int(_plays("player_die")).is_equal(1)
	assert_str(Audio.current_music).is_equal("")
	await real_seconds(0.9)
	assert_int(_plays("lose")).is_equal(1)  # the summary card carries the sting


func test_rooms_waves_doors_and_the_win() -> void:
	var main := quiet_main_with_floor(tiny_floor(1))
	assert_int(_plays("room_enter")).is_equal(1)
	assert_int(_plays("wave_start")).is_equal(1)
	Audio.music("music_run")
	Events.room_cleared.emit()
	assert_int(_plays("room_clear")).is_equal(1)
	assert_str(Audio.current_music).is_equal("")  # run_won stops the loop
	await real_seconds(1.2)
	assert_int(_plays("win")).is_equal(1)


func test_the_exit_and_the_seal() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	await clear_and_pick(main)
	assert_int(_plays("door_open")).is_equal(1)
	Events.room_exit_requested.emit()
	await real_seconds(0.8)
	assert_int(_plays("door_seal")).is_equal(1)


func test_the_menus_open_close_hover_and_pick() -> void:
	var main := quiet_main_with_floor(tiny_floor(2))
	Events.room_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_int(_plays("ui_open")).is_equal(1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	var card: Button = menu.cards.get_child(0)
	card.mouse_entered.emit()
	assert_int(_plays("ui_hover")).is_equal(1)
	menu.choose(0)
	await get_tree().process_frame
	assert_int(_plays("ui_pick")).is_equal(1)
	assert_int(_plays("ui_close")).is_equal(1)
	await wall_msec(200)  # past ui_close's 50 ms minimum gap, or the second close is dropped
	main.get_node("BuildScreen").open()
	assert_int(_plays("ui_open")).is_equal(2)
	main.get_node("BuildScreen").close()
	assert_int(_plays("ui_close")).is_equal(2)


func test_the_heal_card_sounds_under_the_picker() -> void:
	# Seed 1's first draw holds Heal (today Heal is one card of ten in a hurt player's pool; Task 9
	# makes it a fixed slot). The stream is upgrades:0:0, so the seed alone decides the offer.
	RunState.start_run(1)
	var main := quiet_main_with_floor(tiny_floor(2))
	var player: Player = main.get_node("Player")
	player.hurt(1, player.global_position + Vector2(4, 0))
	Events.room_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	var heal := offer_index(menu, UpgradeDef.Kind.HEAL)
	assert_int(heal).override_failure_message("seed 1's first draw no longer holds Heal; pick another seed (the pool or the draw changed)").is_not_equal(-1)
	if heal < 0:
		return
	menu.choose(heal)  # the heal lands while the picker holds the tree paused
	await get_tree().process_frame
	assert_int(_plays("player_heal")).is_equal(1)


func test_a_new_run_starts_the_run_loop() -> void:
	quiet_main()
	RunState.start_run(3)
	assert_str(Audio.current_music).is_equal("music_run")
	assert_int(_plays("music_run")).is_equal(1)
