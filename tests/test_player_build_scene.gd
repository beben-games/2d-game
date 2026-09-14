extends SceneSuite
## The player reads its weapon and max HP from RunState.build and follows build_changed.


func test_player_starts_with_the_resolved_handgun() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	assert_str(player.weapon.id).is_equal("handgun")
	assert_float(player.weapon.fire_rate).is_equal(5.0)
	assert_int(player.max_hp).is_equal(Build.BASE_MAX_HP)
	assert_int(player.hp).is_equal(Build.BASE_MAX_HP)


func test_build_changed_re_resolves_the_weapon() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var fire_rate := UpgradeCatalog.upgrade("fire_rate")
	for i in 3:
		RunState.build.add_rank(fire_rate)
	Events.build_changed.emit()
	assert_float(player.weapon.fire_rate).is_equal_approx(5.0 * 1.25 * 1.25 * 1.25, 0.001)
	assert_float(UpgradeCatalog.weapon("handgun").fire_rate).is_equal(5.0)  # the .tres is untouched


func test_heart_container_grows_max_hp_and_heals_the_new_heart() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hp = 2
	var healed := []
	var on_healed := func(hp: int, max_hp: int) -> void: healed.append([hp, max_hp])
	var dashes := []
	var on_dashes := func(charges: int, max_charges: int) -> void: dashes.append([charges, max_charges])
	Events.player_healed.connect(on_healed)
	Events.dash_charges_changed.connect(on_dashes)
	RunState.build.add_rank(UpgradeCatalog.upgrade("heart_container"))
	Events.build_changed.emit()
	Events.player_healed.disconnect(on_healed)
	Events.dash_charges_changed.disconnect(on_dashes)
	assert_int(player.max_hp).is_equal(Build.BASE_MAX_HP + 2)
	assert_int(player.hp).is_equal(4)
	assert_array(healed).is_equal([[4, Build.BASE_MAX_HP + 2]])
	assert_array(dashes).is_empty()  # a heart container is not a dash change
	# Hits and heals report the new max.
	var hits := []
	var on_hit := func(_damage: int, hp: int, max_hp: int) -> void: hits.append([hp, max_hp])
	Events.player_hit.connect(on_hit)
	player.hurt(1, player.global_position + Vector2(4, 0))
	Events.player_hit.disconnect(on_hit)
	assert_array(hits).is_equal([[3, Build.BASE_MAX_HP + 2]])
	player.hp = 7
	assert_bool(player.heal(2)).is_true()
	assert_int(player.hp).is_equal(8)


func test_a_dash_charge_grows_the_dash_max_without_a_heart_redraw() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var healed := []
	var on_healed := func(hp: int, max_hp: int) -> void: healed.append([hp, max_hp])
	Events.player_healed.connect(on_healed)
	RunState.build.add_rank(UpgradeCatalog.upgrade("dash_charge"))
	Events.build_changed.emit()
	Events.player_healed.disconnect(on_healed)
	assert_int(player.max_dash_charges).is_equal(Build.BASE_DASH_CHARGES + 1)
	assert_int(player.dash_charges).is_equal(Build.BASE_DASH_CHARGES + 1)  # the new charge is ready at once
	assert_array(healed).is_empty()


func test_a_dash_charge_taken_mid_refill_leaves_the_clock_alone() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.dash_charges = 0
	player.dash_cooldown = 0.3  # the one charge is spent and half-way back
	RunState.build.add_rank(UpgradeCatalog.upgrade("dash_charge"))
	Events.build_changed.emit()
	assert_int(player.dash_charges).is_equal(1)  # the new charge is ready at once
	assert_int(player.max_dash_charges).is_equal(2)
	assert_float(player.dash_cooldown).is_equal_approx(0.3, 0.001)  # the running clock is left alone
	await ticks(20)  # 0.3 s is 18 or 19 ticks: the spent charge lands on its old clock
	assert_int(player.dash_charges).is_equal(2)


func test_build_changed_with_the_same_maxes_emits_no_redraw() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	player.hp = 2
	var healed := []
	var on_healed := func(hp: int, max_hp: int) -> void: healed.append([hp, max_hp])
	var dashes := []
	var on_dashes := func(charges: int, max_charges: int) -> void: dashes.append([charges, max_charges])
	Events.player_healed.connect(on_healed)
	Events.dash_charges_changed.connect(on_dashes)
	RunState.build.add_rank(UpgradeCatalog.upgrade("fire_rate"))
	Events.build_changed.emit()
	Events.player_healed.disconnect(on_healed)
	Events.dash_charges_changed.disconnect(on_dashes)
	assert_float(player.weapon.fire_rate).is_equal(5.0 * 1.25)  # the weapon is still re-resolved
	assert_int(player.hp).is_equal(2)
	assert_array(healed).is_empty()
	assert_array(dashes).is_empty()


func test_switching_to_the_crossbow_changes_the_weapon() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	RunState.build.switch_weapon("crossbow")
	Events.build_changed.emit()
	assert_str(player.weapon.id).is_equal("crossbow")
	assert_int(player.weapon.pierce).is_equal(2)
	assert_float(player.weapon.damage).is_equal(3.0)


func test_start_run_gives_a_fresh_build() -> void:
	RunState.build.add_rank(UpgradeCatalog.upgrade("homing"))
	RunState.build.switch_weapon("crossbow")
	RunState.start_run(5)
	assert_str(RunState.build.weapon_id).is_equal("handgun")
	assert_int(RunState.build.weapon_upgrade_count()).is_equal(0)
