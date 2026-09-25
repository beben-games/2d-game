extends SceneSuite
## Round flow in the real main scene: a clear opens the picker, a pick starts the next round after
## the gap in the same Room, clearing the last round wins, and every projectile vanishes on a clear.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const BOLT := preload("res://scenes/enemies/enemy_bolt.tscn")


func _watch_rounds(started: Array) -> Callable:
	var on_started := func(index: int, total: int) -> void: started.append([index, total])
	Events.round_started.connect(on_started)
	return on_started


func test_a_cleared_round_opens_the_picker_after_the_beat() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	Events.round_cleared.emit()
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()  # the beat: the kill burst plays out first
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_bool(menu.is_open()).is_true()
	assert_int(RunState.rounds_cleared).is_equal(1)
	assert_int(main.round_index).is_equal(0)  # the pick, then the gap, then the next round


func test_a_pick_starts_the_next_round_after_the_gap_in_the_same_room() -> void:
	var series := tiny_series(2)
	var main := quiet_main_with_series(series)
	var room: Room = main.get_node("Room")
	var player: Player = main.get_node("Player")
	var started := []
	var on_started := _watch_rounds(started)
	await clear_and_pick(main)
	assert_int(main.round_index).is_equal(0)  # the gap: the crowd settles first
	assert_array(started).is_empty()
	await real_seconds(Main.ROUND_GAP + 0.1)
	Events.round_started.disconnect(on_started)
	assert_array(started).is_equal([[1, 2]])
	assert_int(main.round_index).is_equal(1)
	assert_int(RunState.round_index).is_equal(1)
	assert_object(main.get_node("Room")).is_same(room)  # one arena for the run
	assert_object(room.wave_runner.progress.table).is_same(series.rounds[1].waves)
	assert_object(player.projectile_parent).is_same(room.projectiles)
	assert_bool(get_tree().paused).is_false()


func test_the_spawner_draws_the_new_round_from_its_own_stream() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var room: Room = main.get_node("Room")
	var player: Player = main.get_node("Player")
	var first := room.spawner.pick_position()
	await clear_and_pick(main)
	await real_seconds(Main.ROUND_GAP + 0.1)
	var expected := SpawnMath.pick_position(room.bounds(), player.global_position, room.spawner.min_player_distance, RunState.stream("spawn:1"))
	assert_vector(room.spawner.pick_position()).is_equal(expected)
	assert_vector(first).is_equal(SpawnMath.pick_position(room.bounds(), player.global_position, room.spawner.min_player_distance, RunState.stream("spawn:0")))


func test_clearing_the_last_round_wins() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var won := [0]
	var on_won := func() -> void: won[0] += 1
	Events.run_won.connect(on_won)
	Events.round_cleared.emit()
	await get_tree().process_frame
	Events.run_won.disconnect(on_won)
	assert_int(won[0]).is_equal(1)
	assert_bool(main.get_node("UpgradeMenu").is_open()).is_false()
	assert_int(RunState.rounds_cleared).is_equal(1)


func test_a_restart_during_the_gap_does_not_start_the_next_round() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var started := []
	var on_started := _watch_rounds(started)
	await clear_and_pick(main)
	main.restart()  # not the current scene here: no reload, so the gap's guard must hold on its own
	await real_seconds(Main.ROUND_GAP + 0.1)
	Events.round_started.disconnect(on_started)
	assert_array(started).is_empty()
	assert_int(main.round_index).is_equal(0)


func test_a_death_during_the_gap_does_not_start_the_next_round() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var player: Player = main.get_node("Player")
	var started := []
	var on_started := _watch_rounds(started)
	await clear_and_pick(main)
	player.hp = 1
	player.hurt(1, player.global_position + Vector2(4, 0))
	assert_bool(player.dead).is_true()
	await real_seconds(Main.ROUND_GAP + 0.1)
	Events.round_started.disconnect(on_started)
	assert_array(started).is_empty()
	assert_int(main.round_index).is_equal(0)
	assert_bool(main.get_node("Summary").visible).is_true()


## Two player shots and one enemy bolt in flight; they share Room/Projectiles.
func _place_projectiles(main: Node) -> Node2D:
	var container := projectiles_of(main)
	var player: Player = main.get_node("Player")
	for i in 2:
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(load("res://data/weapons/handgun.tres"), Vector2.RIGHT)
		container.add_child(shot)
		shot.global_position = player.global_position + Vector2(60 + 20 * i, 0)
	var bolt: Projectile = BOLT.instantiate()
	bolt.setup(load("res://data/weapons/shaman_bolt.tres"), Vector2.LEFT)
	container.add_child(bolt)
	bolt.global_position = player.global_position + Vector2(120, 0)
	return container


func test_clearing_a_round_frees_every_projectile_at_once() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var container := _place_projectiles(main)
	assert_int(container.get_child_count()).is_equal(3)
	Events.round_cleared.emit()
	await get_tree().process_frame  # deferred: the signal can arrive inside a physics callback
	assert_int(container.get_child_count()).is_equal(0)
	await get_tree().process_frame  # let the freed shots flush before the orphan snapshot


func test_clearing_the_last_round_frees_every_projectile_too() -> void:
	var main := quiet_main_with_series(tiny_series(1))
	var container := _place_projectiles(main)
	assert_int(container.get_child_count()).is_equal(3)
	Events.round_cleared.emit()
	await get_tree().process_frame
	assert_int(container.get_child_count()).is_equal(0)
	await get_tree().process_frame  # the same flush


## The gap pauses with the game: a pause screen opened in it holds the next round until it closes.
func test_the_gap_holds_under_the_pause_screen() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var screen: BuildScreen = main.get_node("BuildScreen")
	var started := []
	var on_started := _watch_rounds(started)
	await clear_and_pick(main)
	screen.open()
	assert_bool(screen.is_open()).is_true()
	await real_seconds(Main.ROUND_GAP + 0.1)
	assert_array(started).is_empty()
	assert_int(RunState.round_index).is_equal(0)
	screen.close()
	await real_seconds(Main.ROUND_GAP + 0.1)
	Events.round_started.disconnect(on_started)
	assert_array(started).is_equal([[1, 2]])
	assert_int(RunState.round_index).is_equal(1)


## Every card owned at its top rank and both weapons used: the picker has nothing to offer, so
## the clear goes to the gap at once and the next round follows without a menu.
func test_a_round_with_nothing_to_offer_goes_to_the_gap_at_once() -> void:
	var main := quiet_main_with_series(tiny_series(2))
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	var build := RunState.build
	build.switch_weapon("crossbow")  # both weapons used: no switch card is offered
	for card: UpgradeDef in UpgradeCatalog.upgrades().values():
		var owned := card.kind == UpgradeDef.Kind.PLAYER or (card.kind == UpgradeDef.Kind.WEAPON and card.weapon_id == build.weapon_id)
		while owned and build.rank_of(card.id) < card.max_rank:
			build.add_rank(card)
	assert_array(UpgradeCatalog.pool(build)).is_empty()
	var opened := []
	var on_opened := func(name: String) -> void: opened.append(name)
	Events.menu_opened.connect(on_opened)
	var started := []
	var on_started := _watch_rounds(started)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + Main.ROUND_GAP + 0.2)
	Events.menu_opened.disconnect(on_opened)
	Events.round_started.disconnect(on_started)
	assert_array(opened).not_contains(["upgrade"])
	assert_bool(menu.is_open()).is_false()
	assert_array(started).is_equal([[1, 2]])
