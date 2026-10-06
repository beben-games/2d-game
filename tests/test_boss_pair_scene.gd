extends SceneSuite
## A boss of several bodies (M7 Task 7) in the real main scene, on the pair fixture (one round of
## two tier 1 bosses, SceneSuite.pair_series): the seats, a bar each, the favour over their summed
## health, the fight ending at the last body (the piles, the fight's clock, the profile's kill, the
## summons, the win), and the survivor told of its partner's death. Then the def's new knobs on one
## body: charge_line (the line through the wind-up, fixed at its start) and keep_range.

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


## The pair placed by the runner, each on its own def with no fade-in and an approach that
## outlasts the test (idle, never attacking), standing still. Returns them once both are ACTIVE.
func _pair(main: Node) -> Array[Boss]:
	player_of(main).invuln_left = 100.0
	main.get_node("Room/WaveRunner").enabled = true
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("boss").size() == 2, "both bodies placed", 120)
	var bodies: Array[Boss] = []
	for node in enemies_of(main).get_children():
		if node is Boss:
			var boss := node as Boss
			own_def(boss)  # the runner's bodies hold the shared boss.tres; never write through it
			boss.def.spawn_delay = 0.0
			boss.def.approach_time = 100.0
			boss.def.speed = 0.0
			bodies.append(boss)
	await wait_until(func() -> bool: return bodies[0].is_harmful() and bodies[1].is_harmful(), "both bodies active", 30)
	return bodies


func _kill(boss: Boss) -> void:
	boss.health.take_damage(boss.health.hp)
	await get_tree().process_frame  # the deferred calls: the piles, the summons' death
	await get_tree().process_frame


# --- The seats, the bars, the sounds ---


func test_the_pair_sits_spread_along_the_top_of_the_floor() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	var spawner: Spawner = main.get_node("Room/Spawner")
	assert_vector(bodies[0].global_position).is_equal(spawner.boss_position(0, 2))
	assert_vector(bodies[1].global_position).is_equal(spawner.boss_position(1, 2))
	var one := spawner.boss_position()
	assert_float(bodies[0].global_position.y).is_equal(one.y)
	assert_float(bodies[0].global_position.x).is_less(one.x)
	assert_float(bodies[1].global_position.x).is_greater(one.x)


func test_two_bars_side_by_side_each_with_its_own_ratio() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	var hud := hud_of(main)
	assert_int(hud.boss_bar_count()).is_equal(2)
	var a := hud.boss_bar_index(bodies[0])
	var b := hud.boss_bar_index(bodies[1])
	assert_array([a, b]).contains_exactly_in_any_order([0, 1])
	var bar_a := hud.boss_bar_at(a)
	var bar_b := hud.boss_bar_at(b)
	assert_bool(bar_a.visible and bar_b.visible).is_true()
	var left := bar_a.get_global_rect() if a == 0 else bar_b.get_global_rect()
	var right := bar_b.get_global_rect() if a == 0 else bar_a.get_global_rect()
	assert_float(left.position.y).is_equal(right.position.y)
	assert_float(left.position.y).is_equal(Hud.BOSS_BAR_TOP)
	assert_float(left.end.x).is_less(right.position.x)  # side by side, apart
	var screen := hud.get_viewport().get_visible_rect()
	assert_bool(screen.encloses(left) and screen.encloses(right)).is_true()
	bodies[0].health.take_damage(bodies[0].def.max_hp * 0.25)
	bodies[1].health.take_damage(bodies[1].def.max_hp * 0.5)
	await real_seconds(Hud.BOSS_BAR_TWEEN + 0.05)
	assert_float(hud.boss_fill_ratio(a)).is_equal_approx(0.75, 0.02)
	assert_float(hud.boss_fill_ratio(b)).is_equal_approx(0.5, 0.02)
	assert_int(Audio.plays.get("boss_spawn", 0)).is_equal(1)  # one fight, one arrival
	assert_str(Audio.current_music).is_equal("music_boss")


## Tier 1's one body: one bar at the single bar's size, centred on the top edge, as before.
func test_tier_1_s_one_bar_is_unchanged() -> void:
	var main := quiet_main()
	var hud := hud_of(main)
	active_boss_on(main, player_of(main).global_position + Vector2(150, 0))
	await ticks(2)
	assert_int(hud.boss_bar_count()).is_equal(1)
	var screen := hud.get_viewport().get_visible_rect()
	var expected := Rect2((screen.size.x - Hud.BOSS_BAR_SIZE.x) / 2.0, Hud.BOSS_BAR_TOP, Hud.BOSS_BAR_SIZE.x, Hud.BOSS_BAR_SIZE.y)
	assert_that(hud.boss_bar.get_global_rect()).is_equal(expected)
	assert_int(Audio.plays.get("boss_spawn", 0)).is_equal(1)


## The runner counts a wave's bodies from the packed scenes (the root's group), for their seats.
func test_the_runner_counts_a_wave_s_bodies() -> void:
	var scenes: Array[PackedScene] = [load(BOSS), load(CHASER), load(BOSS)]
	assert_int(BossFight.boss_count(scenes)).is_equal(2)
	assert_int(BossFight.boss_count([load(CHASER)] as Array[PackedScene])).is_equal(0)


## The arrows' top edge is the bars' row while any bar is up, the screen's top once none is.
func test_the_arrows_top_edge_is_the_bars_row_while_any_bar_is_up() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	var hud := hud_of(main)
	var screen := hud.get_viewport().get_visible_rect()
	var row_bottom := hud.boss_bars.get_global_rect().end.y
	assert_float(row_bottom).is_greater(screen.position.y)
	assert_float(hud.arrows.edge_rect().position.y).is_equal(row_bottom)
	await _kill(bodies[0])
	assert_float(hud.arrows.edge_rect().position.y).is_equal(row_bottom)  # the survivor's bar holds the row
	assert_int(bodies[1].partners_lost).is_equal(1)
	assert_bool(bodies[1].brain.enrage_requested).is_false()  # tier 1's body: no enrage on a partner
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await _kill(bodies[1])
	assert_float(hud.arrows.edge_rect().position.y).is_equal(screen.position.y)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


# --- The fight ends at its last body ---


func test_one_death_leaves_the_round_on_the_other_bar_up_and_the_summons_alive() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	var hud := hud_of(main)
	var summoner := bodies[1]
	summoner.def.approach_time = 0.0
	summoner.brain.stage = 2
	summoner.brain.pattern = BossBrain.Pattern.SUMMON
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("summoned").size() == 2, "the summons", 60)
	summoner.def.approach_time = 100.0
	var imps := get_tree().get_nodes_in_group("summoned")
	var kills_before: int = Profile.save.stat("boss_kills")
	await _kill(bodies[0])
	assert_int(_cleared).is_equal(0)
	assert_int(_won).is_equal(0)
	assert_bool(hud.boss_bar_at(hud.boss_bar_index(bodies[0])).visible).is_false()
	assert_bool(hud.boss_bar_at(hud.boss_bar_index(bodies[1])).visible).is_true()
	for imp: Enemy in imps:
		assert_bool(imp.health.dead).is_false()
	assert_array(_thrown).is_empty()
	assert_float(main._boss_time).is_equal(0.0)
	assert_int(Profile.save.stat("boss_kills")).is_equal(kills_before)
	assert_int(summoner.partners_lost).is_equal(1)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


func test_the_second_death_ends_the_fight_once() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	var summoner := bodies[0]
	summoner.def.approach_time = 0.0
	summoner.brain.stage = 2
	summoner.brain.pattern = BossBrain.Pattern.SUMMON
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("summoned").size() == 2, "the summons", 60)
	summoner.def.approach_time = 100.0
	var imps := get_tree().get_nodes_in_group("summoned")
	var kills_before: int = Profile.save.stat("boss_kills")
	await _kill(bodies[1])
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await ticks(6)  # more of the fight's time
	var spawned_at: float = main._boss_spawn_elapsed
	assert_float(spawned_at).is_greater_equal(0.0)
	await _kill(bodies[0])
	assert_float(main._boss_time).is_greater(0.0)
	assert_float(main._boss_time).is_less_equal(RunState.elapsed - spawned_at)
	assert_array(_thrown).is_equal([bodies[0].def.coins + bodies[1].def.coins])  # once, both bodies' coins
	assert_int(Profile.save.stat("boss_kills")).is_equal(kills_before + 1)
	assert_int(_cleared).is_equal(1)
	assert_int(_won).is_equal(1)
	for imp: Enemy in imps:
		assert_bool(imp.health.dead).is_true()
	assert_int(Audio.plays.get("boss_die", 0)).is_equal(2)  # two deaths 0.3 s apart: two death sounds
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


## The favour paid by damage follows either body's hits against their summed health; the first
## death pays nothing of its own, the last the rest of the budget.
func test_the_favour_by_damage_is_over_the_summed_health() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	var favour: Favour = main.get_node("Favour")
	var summed := bodies[0].def.max_hp + bodies[1].def.max_hp
	var tenth := summed * 0.1  # a tenth of the fight: 4
	bodies[0].health.take_damage(tenth)
	assert_float(favour.round_kill_paid).is_equal_approx(4.0, 0.001)
	bodies[1].health.take_damage(tenth)
	assert_float(favour.round_kill_paid).is_equal_approx(8.0, 0.001)
	var rest_a := bodies[0].health.hp
	await _kill(bodies[0])  # its killing hit pays its share; its death nothing
	assert_float(favour.round_kill_paid).is_equal_approx(8.0 + FavourRules.KILL_BUDGET * rest_a / summed, 0.001)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)
	await _kill(bodies[1])  # to the reserve line, then the last kill the rest
	assert_float(favour.round_kill_paid).is_equal_approx(FavourRules.KILL_BUDGET, 0.001)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


## The fight's health is the round's from its start: a hit on the first body placed, before the
## second is in the tree, pays over the pair's summed health (Task 7's review).
func test_a_hit_before_the_second_body_is_placed_pays_over_the_summed_health() -> void:
	var main := quiet_main_with_series(pair_series())
	var favour: Favour = main.get_node("Favour")
	player_of(main).invuln_left = 100.0
	main.get_node("Room/WaveRunner").enabled = true
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("boss").size() == 1, "the first body placed", 30)
	var first := get_tree().get_nodes_in_group("boss")[0] as Boss
	var summed := first.def.max_hp * 2.0
	first.health.take_damage(summed * 0.1)
	assert_float(favour.round_kill_paid).is_equal_approx(FavourRules.KILL_BUDGET * 0.1, 0.001)


## A body that enrages on its partner's death asks for its second stage at it.
func test_a_partner_s_death_enrages_a_body_that_enrages_on_it() -> void:
	var main := quiet_main_with_series(pair_series())
	var bodies := await _pair(main)
	bodies[1].def.enrage_on_partner = true
	await _kill(bodies[0])
	assert_int(bodies[1].partners_lost).is_equal(1)
	assert_bool(bodies[1].brain.enrage_requested).is_true()
	bodies[1].def.approach_time = 0.0
	await wait_until(func() -> bool: return bodies[1].brain.stage == 2, "the enrage at the next edge", 10)
	await real_seconds(Boss.DEATH_HITSTOP + 0.05)


# --- One body's new knobs ---


## charge_line: the lane is fixed at the wind-up's start toward the player as it stands, drawn
## through the wind-up (the player moving off it changes nothing), and gone as the run starts.
func test_charge_line_draws_the_lane_through_the_wind_up_fixed_at_its_start() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var bounds: Rect2 = main.get_node("Room").bounds()
	player.invuln_left = 100.0
	player.global_position = bounds.get_center() + Vector2(100, 0)
	var boss := active_boss_on(main, bounds.get_center() + Vector2(-60, 0))
	boss.def.charge_line = true
	boss.def.stage1_cycle = ["charge"]
	boss.def.approach_time = 0.0
	boss.brain = BossBrain.new(boss.def)
	await wait_until(func() -> bool: return boss.brain.phase == BossBrain.Phase.TELEGRAPH, "the wind-up", 10)
	var line := boss.get_node("ChargeLine") as ChargeLine
	assert_bool(line.shown()).is_true()
	assert_vector(line.direction).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))
	assert_vector(boss.charge_dir).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))
	var reach: float = boss.def.charge_speed * boss.def.charge_time
	assert_float(line.length).is_equal_approx(minf(reach, bounds.end.x - boss.global_position.x), 1.0)
	player.global_position = bounds.get_center() + Vector2(0, 80)  # off the lane: nothing follows
	await wait_until(func() -> bool: return boss.brain.charging(), "the run", 60)
	assert_bool(line.shown()).is_false()
	assert_vector(boss.charge_dir).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))
	await ticks(3)
	assert_float(boss.move_vel.normalized().dot(Vector2.RIGHT)).is_greater(0.99)


## Tier 1's boss draws no line: it has no ChargeLine and locks its lane at the run's start.
func test_tier_1_s_boss_draws_no_line() -> void:
	var main := quiet_main()
	var boss := active_boss_on(main, player_of(main).global_position + Vector2(150, 0))
	assert_object(boss.get_node_or_null("ChargeLine")).is_null()


func _stand(main: Node, at: Vector2) -> void:
	var player := player_of(main)
	player.global_position = at
	player.aim_override = at
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	await wait_until(func() -> bool: return View.bare_rect(self).get_center().distance_to(at) < 1.0, "the view at rest on the player")


## keep_range near the screen's edge (Task 7's review): a body above the player whose range is
## past the screen's top backs away only to the edge, shrunk by its radius, and holds there on the
## screen (no flicker across the sight line), and winds up from there.
func test_keep_range_holds_on_the_screen_at_its_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var floor_rect: Rect2 = (main.get("room") as Room).global_bounds()
	await _stand(main, floor_rect.get_center())
	var player := player_of(main)
	player.invuln_left = 100.0
	var boss := active_boss_on(main, player.global_position + Vector2(0, -60), false)
	boss.def.keep_range = 160.0
	boss.def.approach_time = 3.0
	boss.def.stage1_cycle = ["volley"]
	boss.brain = BossBrain.new(boss.def)
	var screen := View.bare_rect(boss)
	assert_float(boss.def.keep_range).is_greater(player.global_position.y - screen.position.y)  # past the screen's top
	await ticks(90)  # backed up to the edge and settled
	var top := screen.position.y + 20.0  # the body's radius under the screen's top
	assert_float(boss.global_position.y).is_between(top - 1.0, top + 6.0)
	for i in 60:
		assert_bool(View.on_screen(boss)).is_true()
		assert_float(boss.global_position.y).is_greater_equal(top - 1.0)
		await ticks(1)
	await wait_until(func() -> bool: return boss.brain.phase == BossBrain.Phase.TELEGRAPH, "the wind-up on the screen", 120)
	assert_bool(View.on_screen(boss)).is_true()


## keep_range: a body inside its range backs away from the player, one outside closes in, and
## each settles near the range.
func test_keep_range_holds_a_distance() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var bounds: Rect2 = main.get_node("Room").bounds()
	player.invuln_left = 100.0
	player.global_position = bounds.get_center()
	var near := active_boss_on(main, bounds.get_center() + Vector2(-50, 0), false)
	near.def.keep_range = 120.0
	near.def.approach_time = 100.0
	var far := active_boss_on(main, bounds.get_center() + Vector2(190, 0), false)
	far.def.keep_range = 120.0
	far.def.approach_time = 100.0
	await ticks(12)
	assert_float(near.move_vel.x).is_less(0.0)  # away, to the left
	assert_float(far.move_vel.x).is_less(0.0)  # in, to the left
	await ticks(150)
	for boss: Boss in [near, far]:
		var distance := boss.global_position.distance_to(player.global_position)
		assert_float(distance).is_between(120.0 - BossBrain.KEEP_SLACK - 4.0, 120.0 + BossBrain.KEEP_SLACK + 4.0)
