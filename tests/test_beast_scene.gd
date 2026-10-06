extends SceneSuite
## The beast and its handler (M7 Task 8), tier 2's boss of two bodies, in the real main scene: the
## beast's chain of lined charges; its wild stage at the handler's death (no ring, the second
## stage's wind-up and charge speed); the handler's lone stage at the beast's (faster volleys, two
## chargers summoned once, dying with it); the handler's range and rule 2; the fight's end at the
## second death in either order.

const BEAST := "res://scenes/enemies/beast.tscn"
const HANDLER := "res://scenes/enemies/handler.tscn"

var _cleared := 0
var _won := 0
var _thrown: Array[int] = []


func _on_cleared() -> void:
	_cleared += 1


func _on_won() -> void:
	_won += 1


func _on_thrown(_at: Vector2, total: int) -> void:
	_thrown.append(total)


func before_test() -> void:
	super()
	_cleared = 0
	_won = 0
	_thrown = []
	Events.round_cleared.connect(_on_cleared)
	Events.run_won.connect(_on_won)
	Events.coins_thrown.connect(_on_thrown)


func after_test() -> void:
	for pair: Array in [[Events.round_cleared, _on_cleared], [Events.run_won, _on_won], [Events.coins_thrown, _on_thrown]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	await super()


## One round whose one wave sends the beast and the handler (the boss round: the series' last).
func _pair_series() -> SeriesDef:
	var groups: Array[SpawnGroup] = []
	for path in [BEAST, HANDLER]:
		var g := SpawnGroup.new()
		g.enemy = load(path)
		g.count = 1
		groups.append(g)
	var w := WaveDef.new()
	w.groups = groups
	w.breather = 0.0
	var t := WaveTable.new()
	t.waves = [w]
	var r := RoundDef.new()
	r.waves = t
	var s := SeriesDef.new()
	s.rounds.append(r)
	return s


## The pair placed by the runner, each on its own def with no fade-in and an approach that
## outlasts the test, standing still. Returns [beast, handler] once both are ACTIVE.
func _pair(main: Node) -> Array[Boss]:
	player_of(main).invuln_left = 100.0
	main.get_node("Room/WaveRunner").enabled = true
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("boss").size() == 2, "both bodies placed", 120)
	var beast: Boss
	var handler: Boss
	for node in enemies_of(main).get_children():
		if node is Boss:
			var boss := node as Boss
			own_def(boss)  # the runner's bodies hold the shared .tres; never write through it
			boss.def.spawn_delay = 0.0
			boss.def.approach_time = 100.0
			boss.def.speed = 0.0
			if boss.def.id == "beast":
				beast = boss
			else:
				handler = boss
	assert_object(beast).is_not_null()
	assert_object(handler).is_not_null()
	await wait_until(func() -> bool: return beast.is_harmful() and handler.is_harmful(), "both bodies active", 30)
	return [beast, handler]


func _kill(boss: Boss) -> void:
	boss.health.take_damage(boss.health.hp)
	await get_tree().process_frame  # the deferred calls: the piles, the summons' death
	await get_tree().process_frame


func _phase_is(boss: Boss, phase: BossBrain.Phase) -> Callable:
	return func() -> bool: return boss.brain.phase == phase


## Frames from now (the wind-up's first) until the wind-up ends.
func _wind_up_frames(boss: Boss) -> int:
	var frames := 0
	while boss.brain.phase == BossBrain.Phase.TELEGRAPH and frames < 300:
		await get_tree().physics_frame
		frames += 1
	return frames


func _stand(main: Node, at: Vector2) -> void:
	var player := player_of(main)
	player.global_position = at
	player.aim_override = at
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	await wait_until(func() -> bool: return View.bare_rect(self).get_center().distance_to(at) < 1.0, "the view at rest on the player")


# --- The scenes ---


## Both scenes are boss bodies (the group in the file, the boss's script), sent by one wave.
func test_the_pair_s_scenes_are_boss_bodies_of_one_wave() -> void:
	for path in [BEAST, HANDLER]:
		var scene: PackedScene = load(path)
		assert_bool(BossFight.is_boss_scene(scene)).is_true()
		assert_bool(BossFight.runs_the_boss_script(scene)).is_true()
	assert_array(_pair_series().validate()).is_empty()
	var beast: BossDef = load("res://data/enemies/beast.tres")
	var handler: BossDef = load("res://data/enemies/handler.tres")
	assert_float(BossFight.table_max_hp(_pair_series().rounds[0].waves)).is_equal(beast.max_hp + handler.max_hp)
	var main := quiet_main()
	var big := active_boss_on(main, Vector2.ZERO, true, BEAST)
	var small := active_boss_on(main, Vector2(100, 0), true, HANDLER)
	var big_radius := ((big.get_node("Shape") as CollisionShape2D).shape as CircleShape2D).radius
	var small_radius := ((small.get_node("Shape") as CollisionShape2D).shape as CircleShape2D).radius
	assert_float(small_radius).is_less(big_radius)
	assert_bool(big.is_in_group("boss") and small.is_in_group("boss")).is_true()


# --- The beast ---


## The line shows through each leg's wind-up and is gone at its run; the chain's legs, then the
## ring. The beast roars at its chain's first wind-up only.
func test_the_beast_s_line_shows_before_each_charge_of_its_chain() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var centre: Vector2 = (main.get_node("Room") as Room).bounds().get_center()
	player.invuln_left = 100.0
	player.global_position = centre + Vector2(120, 0)
	var beast := active_boss_on(main, centre + Vector2(-120, 0), true, BEAST)
	beast.def.approach_time = 0.0
	assert_int(beast.def.charge_chain).is_greater(1)
	for leg in beast.def.charge_chain:
		await wait_until(_phase_is(beast, BossBrain.Phase.TELEGRAPH), "leg %d's wind-up" % leg, 120)
		assert_int(beast.brain.pattern).is_equal(BossBrain.Pattern.CHARGE)
		assert_int(beast.brain.leg).is_equal(leg)
		assert_bool(beast.charge_line.shown()).override_failure_message("leg %d's line" % leg).is_true()
		await wait_until(func() -> bool: return beast.brain.charging(), "leg %d's run" % leg, 60)
		assert_bool(beast.charge_line.shown()).is_false()
	await wait_until(_phase_is(beast, BossBrain.Phase.TELEGRAPH), "the ring's wind-up", 180)
	assert_int(beast.brain.pattern).is_equal(BossBrain.Pattern.RING)
	# The roar opens the chain; the later legs and the ring wind up as any boss body does.
	assert_int(plays("beast_roar")).is_equal(1)
	assert_int(plays("boss_telegraph")).is_equal(beast.def.charge_chain)


## The handler's death enrages the beast: its cycle has no ring, every wind-up is the second
## stage's, and every run goes at phase2_charge_speed.
func test_with_the_handler_dead_the_beast_charges_wild_with_no_ring() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var centre: Vector2 = (main.get_node("Room") as Room).bounds().get_center()
	player.invuln_left = 100.0
	player.global_position = centre + Vector2(120, 0)
	var beast := active_boss_on(main, centre + Vector2(-120, 0), true, BEAST)
	beast.def.approach_time = 100.0
	var handler := active_boss_on(main, centre + Vector2(0, -60), true, HANDLER)
	handler.def.approach_time = 100.0
	await ticks(2)
	await _kill(handler)
	assert_int(beast.partners_lost).is_equal(1)
	assert_bool(beast.brain.enrage_requested).is_true()
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)  # the kill freeze would stretch the first wind-up
	beast.def.approach_time = 0.0
	await wait_until(func() -> bool: return beast.brain.stage == 2, "the beast's second stage", 10)
	var expected := roundi(beast.def.phase2_telegraph_time * Engine.physics_ticks_per_second)
	for i in beast.def.charge_chain + 2:  # a chain and more: no ring between
		await wait_until(_phase_is(beast, BossBrain.Phase.TELEGRAPH), "wind-up %d" % i, 120)
		assert_int(beast.brain.pattern).is_equal(BossBrain.Pattern.CHARGE)
		assert_float(beast.brain.telegraph_time(beast.def)).is_equal(beast.def.phase2_telegraph_time)
		var frames := await _wind_up_frames(beast)
		assert_int(frames).is_between(expected - 2, expected + 2)
		await wait_until(func() -> bool: return beast.brain.charging(), "run %d" % i, 10)
		assert_float(beast.move_vel.length()).is_equal_approx(beast.def.phase2_charge_speed, 1.0)
	assert_int(Audio.plays.get("boss_ring", 0)).is_equal(0)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


# --- The handler ---


## The beast's death leaves the handler alone: faster volleys and one summon of two chargers at
## the sides, never again; they die with it.
func test_with_the_beast_dead_the_handler_summons_two_chargers_once() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var centre: Vector2 = (main.get_node("Room") as Room).bounds().get_center()
	player.invuln_left = 100.0
	player.global_position = centre + Vector2(0, 60)
	var handler := active_boss_on(main, centre + Vector2(0, -60), true, HANDLER)
	handler.def.approach_time = 0.0
	var beast := active_boss_on(main, centre + Vector2(-120, 0), true, BEAST)
	beast.def.approach_time = 100.0
	await ticks(2)
	assert_int(get_tree().get_nodes_in_group("summoned").size()).is_equal(0)
	await _kill(beast)
	assert_int(handler.partners_lost).is_equal(1)
	assert_bool(handler.brain.enrage_requested or handler.brain.stage == 2).is_true()
	await wait_until(func() -> bool: return handler.brain.stage == 2, "the handler's second stage", 180)
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("summoned").size() == 2, "the summons", 10)
	var imps := get_tree().get_nodes_in_group("summoned")
	for imp: Enemy in imps:
		assert_str(imp.def.id).is_equal("charger")
	assert_int(plays("handler_call")).is_equal(1)
	assert_float(handler.brain.telegraph_time(handler.def)).is_equal(handler.def.phase2_telegraph_time)
	assert_float(handler.brain.recover_time(handler.def)).is_equal(handler.def.phase2_recover_time)
	var volleys := plays("boss_volley")
	await wait_until(func() -> bool: return plays("boss_volley") >= volleys + 2, "two more volleys", 240)
	assert_int(get_tree().get_nodes_in_group("summoned").size()).is_equal(2)  # once
	assert_int(plays("handler_call")).is_equal(1)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await _kill(handler)
	for imp: Enemy in imps:
		assert_bool(imp.health.dead).is_true()
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


## The handler backs away inside its range and settles near it; off screen it closes and winds
## up only once on the screen (rule 2).
func test_the_handler_keeps_its_range_and_winds_up_only_on_screen() -> void:
	var main := quiet_main_with_series(wide_series())
	var floor_rect: Rect2 = (main.get("room") as Room).global_bounds()
	await _stand(main, floor_rect.get_center())
	var player := player_of(main)
	player.invuln_left = 100.0
	var handler := active_boss_on(main, player.global_position + Vector2(40, 0), false, HANDLER)
	handler.def.approach_time = 100.0
	var keep := handler.def.keep_range
	await ticks(12)
	assert_float(handler.move_vel.x).is_greater(0.0)  # away, to the right
	await ticks(200)
	var distance := handler.global_position.distance_to(player.global_position)
	assert_float(distance).is_between(keep - BossBrain.KEEP_SLACK - 4.0, keep + BossBrain.KEEP_SLACK + 4.0)
	var screen := View.bare_rect(handler)
	handler.global_position = Vector2(screen.end.x + 80.0, player.global_position.y)
	handler.def.approach_time = 0.0
	await ticks(6)
	assert_bool(View.on_screen(handler)).is_false()
	assert_float(handler.move_vel.x).is_less(0.0)  # it closes from off screen
	var held_off := 0
	for i in 300:
		if handler.brain.phase == BossBrain.Phase.TELEGRAPH:
			break
		if not View.on_screen(handler):
			held_off += 1
		await get_tree().physics_frame
	assert_int(handler.brain.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_bool(View.on_screen(handler)).is_true()
	assert_int(held_off).is_greater(0)


# --- The fight ---


func _the_fight_ends_once(first_is_beast: bool) -> void:
	var main := quiet_main_with_series(_pair_series())
	var bodies := await _pair(main)
	var beast := bodies[0]
	var handler := bodies[1]
	assert_float(RunState.round_boss_hp).is_equal(beast.def.max_hp + handler.def.max_hp)
	var favour: Favour = main.get_node("Favour")
	var kills_before: int = Profile.save.stat("boss_kills")
	var first := beast if first_is_beast else handler
	var second := handler if first_is_beast else beast
	await _kill(first)
	assert_int(second.partners_lost).is_equal(1)
	assert_int(_cleared).is_equal(0)
	assert_int(_won).is_equal(0)
	assert_array(_thrown).is_empty()
	assert_int(Profile.save.stat("boss_kills")).is_equal(kills_before)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await _kill(second)
	assert_array(_thrown).is_equal([beast.def.coins + handler.def.coins])  # once, both bodies' coins
	assert_int(Profile.save.stat("boss_kills")).is_equal(kills_before + 1)
	assert_int(_cleared).is_equal(1)
	assert_int(_won).is_equal(1)
	assert_float(main._boss_time).is_greater(0.0)
	assert_float(favour.round_kill_paid).is_equal_approx(FavourRules.KILL_BUDGET, 0.001)
	assert_int(plays("boss_die")).is_equal(2)  # each body's death row; the last always sounds
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


func test_the_fight_ends_and_pays_once_the_handler_first() -> void:
	await _the_fight_ends_once(false)


func test_the_fight_ends_and_pays_once_the_beast_first() -> void:
	await _the_fight_ends_once(true)
