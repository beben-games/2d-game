extends GdUnitTestSuite
## BossBrain: the pattern order in each stage, the phase edges on the def's timings, the charge,
## the stage change landing only at an edge, the interrupt.


func _def() -> BossDef:
	var d := BossDef.new()
	d.approach_time = 1.0
	d.telegraph_time = 0.6
	d.recover_time = 0.8
	d.charge_time = 0.5
	d.phase2_telegraph_time = 0.45
	d.phase2_recover_time = 0.5
	d.ring_count = 12
	d.phase2_ring_count = 16
	return d


## Ticks 0.1 s at a time until the brain returns an action, and returns it (ACTION_NONE at the limit).
func _until_action(b: BossBrain, d: BossDef, limit := 100) -> String:
	for i in limit:
		var action := b.tick(0.1, d, true)
		if action != BossBrain.ACTION_NONE:
			return action
	return BossBrain.ACTION_NONE


func _actions(b: BossBrain, d: BossDef, count: int) -> Array[String]:
	var out: Array[String] = []
	for i in count:
		out.append(_until_action(b, d))
	return out


func test_stage_one_cycles_ring_volley_charge() -> void:
	var b := BossBrain.new()
	assert_array(_actions(b, _def(), 7)).is_equal(["ring", "volley", "charge", "charge_end", "ring", "volley", "charge"])


func test_phase_edges_land_on_the_def_timings() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.RING)
	b.tick(0.95, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	b.tick(0.1, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_str(b.tick(0.5, d, true)).is_equal("")
	assert_str(b.tick(0.11, d, true)).is_equal("ring")
	assert_int(b.phase).is_equal(BossBrain.Phase.ATTACK)
	assert_str(b.tick(0.01, d, true)).is_equal("")  # a ring lands on one tick
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.7, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.11, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.VOLLEY)


func test_the_charge_runs_its_time_and_a_wall_ends_it_early() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_array(_actions(b, d, 3)).is_equal(["ring", "volley", "charge"])
	assert_bool(b.charging()).is_true()
	assert_str(b.tick(0.3, d, true)).is_equal("")
	assert_bool(b.charging()).is_true()
	assert_str(b.tick(0.21, d, true)).is_equal("charge_end")
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	var c := BossBrain.new()
	_actions(c, d, 3)
	assert_str(c.end_charge()).is_equal("charge_end")
	assert_bool(c.charging()).is_false()
	assert_int(c.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_str(c.end_charge()).is_equal("")  # not charging: a no-op


## The wish is a velocity: at the player at def.speed while approaching, at recover_move of it
## while recovering (M6 playtest 2: the boss keeps moving), still while it winds up and attacks
## (a charge moves the body on its own lane).
func test_the_wish_walks_at_the_player_through_approach_and_recover() -> void:
	var b := BossBrain.new()
	var d := _def()
	d.speed = 50.0
	d.recover_move = 0.5
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2(50, 0))
	assert_vector(b.wish(Vector2(0, -30), d)).is_equal(Vector2(0, -50))  # the speed, whatever the distance
	b.tick(1.1, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2.ZERO)
	assert_str(b.tick(0.61, d, true)).is_equal("ring")
	assert_int(b.phase).is_equal(BossBrain.Phase.ATTACK)
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2.ZERO)
	b.tick(0.01, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2(25, 0))
	assert_vector(b.wish(Vector2.ZERO, d)).is_equal(Vector2.ZERO)  # on the player: nowhere to go


## recover_move 0 is the old stillness through the recover; the charge's attack wishes nothing.
func test_with_no_recover_move_the_boss_stands_through_its_recover() -> void:
	var b := BossBrain.new()
	var d := _def()
	d.speed = 50.0
	d.recover_move = 0.0
	_actions(b, d, 3)  # charging
	assert_bool(b.charging()).is_true()
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2.ZERO)
	assert_str(b.tick(0.51, d, true)).is_equal("charge_end")
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2.ZERO)


func test_the_stage_change_lands_at_the_next_edge_never_mid_charge() -> void:
	var b := BossBrain.new()
	var d := _def()
	_actions(b, d, 3)  # charging
	b.request_enrage()
	assert_int(b.stage).is_equal(1)
	assert_str(b.tick(0.1, d, true)).is_equal("")
	assert_int(b.stage).is_equal(1)  # the charge runs on
	assert_str(b.tick(0.41, d, true)).is_equal("charge_end")
	assert_int(b.stage).is_equal(2)  # applied at the edge into RECOVER
	assert_float(b.recover_time(d)).is_equal(0.5)
	assert_float(b.telegraph_time(d)).is_equal(0.45)
	assert_int(b.ring_count(d)).is_equal(16)
	b.tick(0.45, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.06, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.SUMMON)  # stage two's cycle continues after the charge
	assert_array(_actions(b, d, 5)).is_equal(["summon", "ring", "volley", "charge", "charge_end"])


func test_the_stage_change_from_approach_lands_on_the_telegraph_edge() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.request_enrage()
	b.tick(0.5, d, true)
	assert_int(b.stage).is_equal(1)
	b.tick(0.6, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_int(b.stage).is_equal(2)
	b.request_enrage()  # already there: nothing to do
	assert_bool(b.enrage_requested).is_false()


func test_interrupt_cuts_only_a_telegraph() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.interrupt()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	b.tick(1.1, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	b.interrupt()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_float(b.phase_time).is_equal(0.0)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.RING)  # the same attack, wound up again in full


func test_an_enrage_requested_during_a_recover_takes_the_stage_two_cycle_at_that_edge() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_array(_actions(b, d, 3)).is_equal(["ring", "volley", "charge"])
	assert_str(b.tick(0.51, d, true)).is_equal("charge_end")
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.request_enrage()
	assert_int(b.stage).is_equal(1)
	b.tick(d.recover_time + 0.01, d, true)  # a stage-1 recover: the stage flips only at its edge
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.stage).is_equal(2)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.SUMMON)  # stage two's cycle from that edge on


## Ticks at 60 Hz until the phase changes. Returns the tick count.
func _ticks_until_phase_changes(b: BossBrain, d: BossDef, limit := 1000) -> int:
	var start := b.phase
	var n := 0
	while b.phase == start and n < limit:
		b.tick(1.0 / 60.0, d, true)
		n += 1
	return n


func test_stage_one_is_a_prefix_of_stage_two() -> void:
	assert_array(BossBrain.STAGE2_CYCLE.slice(0, BossBrain.STAGE1_CYCLE.size())).is_equal(BossBrain.STAGE1_CYCLE)


func test_a_wall_ending_the_charge_does_not_flip_the_stage() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_array(_actions(b, d, 3)).is_equal(["ring", "volley", "charge"])
	b.request_enrage()
	assert_str(b.end_charge()).is_equal("charge_end")
	assert_int(b.stage).is_equal(1)  # the body compares stage around tick(), never around end_charge()
	assert_bool(b.enrage_requested).is_true()
	b.tick(d.recover_time + 0.01, d, true)  # the next edge taken inside tick(): a stage-1 recover
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.stage).is_equal(2)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.SUMMON)


func test_a_stun_cutting_the_telegraph_does_not_flip_the_stage() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.tick(1.1, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	b.request_enrage()
	b.interrupt()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.stage).is_equal(1)
	assert_bool(b.enrage_requested).is_true()
	b.tick(1.1, d, true)  # the next edge taken inside tick()
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_int(b.stage).is_equal(2)


## Stage one's phases in physics ticks at 60 Hz, so scene tests can count on them. The charge and
## stage two's timings land one tick late at 60 Hz: 0.5 s is 30 ticks of 1/60 s and 0.45 s is 27,
## and each sum falls just short, so those edges land on ticks 31 and 28. A scene test on a charge
## or a stage-two phase leaves a tick of slack.
func test_stage_one_phase_lengths_in_ticks_at_60_hz() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_int(_ticks_until_phase_changes(b, d)).is_equal(60)  # approach 1.0 s
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_int(_ticks_until_phase_changes(b, d)).is_equal(36)  # telegraph 0.6 s
	assert_int(b.phase).is_equal(BossBrain.Phase.ATTACK)
	assert_int(_ticks_until_phase_changes(b, d)).is_equal(1)  # the ring lands on one tick
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_int(_ticks_until_phase_changes(b, d)).is_equal(48)  # recover 0.8 s
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)


# --- Rule 2: a wind-up begins only on screen (the M7 design's "The big arena") ---


func test_off_screen_the_approach_never_ends_in_a_telegraph() -> void:
	var b := BossBrain.new()
	var d := _def()
	for i in 50:
		assert_str(b.tick(0.1, d, false)).is_equal(BossBrain.ACTION_NONE)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_float(b.move_factor(d)).is_equal(1.0)  # it walks at the player meanwhile
	b.tick(0.1, d, true)  # the timer ran out long ago: the first tick in view winds up
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)


func test_a_wind_up_and_a_charge_begun_finish_off_screen() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.pattern = BossBrain.Pattern.CHARGE
	b.tick(1.05, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_str(b.tick(0.65, d, false)).is_equal(BossBrain.ACTION_CHARGE)
	assert_bool(b.charging()).is_true()
	assert_str(b.tick(0.55, d, false)).is_equal(BossBrain.ACTION_CHARGE_END)
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.85, d, false)  # the recover ends off screen as on it
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)


# --- A boss of several bodies (M7 Task 7): the cycles, the chain, the range from the def ---


## Tier 1's cycles are the def's defaults: a BossDef with nothing set is today's boss.
func test_the_def_s_default_cycles_are_tier_1_s() -> void:
	var d := BossDef.new()
	assert_array(BossBrain.patterns_of(d.stage1_cycle)).is_equal(BossBrain.STAGE1_CYCLE)
	assert_array(BossBrain.patterns_of(d.stage2_cycle)).is_equal(BossBrain.STAGE2_CYCLE)
	assert_int(d.charge_chain).is_equal(1)
	assert_float(d.keep_range).is_equal(0.0)


## A def's cycle drives the order, and a brain made with the def opens on its first pattern.
func test_a_def_s_cycle_drives_the_order() -> void:
	var d := _def()
	d.stage1_cycle = ["charge", "volley"]
	var b := BossBrain.new(d)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.CHARGE)
	assert_array(_actions(b, d, 5)).is_equal(["charge", "charge_end", "volley", "charge", "charge_end"])


## The second stage takes the def's own stage-two cycle at the flip, a pattern it lacks dropped:
## an enrage landing on a wind-up's edge winds up the new cycle's pattern instead.
func test_the_stage_two_cycle_comes_from_the_def() -> void:
	var d := _def()
	d.stage1_cycle = ["charge", "ring"]
	d.stage2_cycle = ["charge"]
	var b := BossBrain.new(d)
	assert_array(_actions(b, d, 2)).is_equal(["charge", "charge_end"])
	b.tick(d.recover_time + 0.01, d, true)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.RING)
	b.request_enrage()
	b.tick(d.approach_time + 0.01, d, true)  # the flip on the wind-up's edge: no ring in stage two
	assert_int(b.stage).is_equal(2)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.CHARGE)
	assert_array(_actions(b, d, 6)).is_equal(["charge", "charge_end", "charge", "charge_end", "charge", "charge_end"])


## A chain of charges: each leg has its own wind-up (the full telegraph), the next begins as the
## last ends (on its time or at a wall), and the cycle moves on after the last leg's recover.
func test_a_chain_winds_up_before_each_charge() -> void:
	var d := _def()
	d.stage1_cycle = ["charge", "ring"]
	d.charge_chain = 3
	var b := BossBrain.new(d)
	b.tick(d.approach_time + 0.01, d, true)
	for leg in 3:
		assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
		assert_int(b.leg).is_equal(leg)
		assert_str(b.tick(d.telegraph_time - 0.05, d, true)).is_equal("")  # winding up, not charging
		assert_bool(b.charging()).is_false()
		assert_str(b.tick(0.06, d, true)).is_equal("charge")
		assert_bool(b.charging()).is_true()
		if leg == 1:
			assert_str(b.end_charge(d)).is_equal("charge_end")  # a wall ends the middle leg
		else:
			assert_str(b.tick(d.charge_time + 0.01, d, true)).is_equal("charge_end")
		if leg < 2:
			assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
			b.tick(0.01, d, true)  # the next leg winds up on the next tick in view
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_int(b.leg).is_equal(0)
	assert_array(_actions(b, d, 1)).is_equal(["ring"])


## Off screen between legs the next wind-up waits for the screen, as an approach does.
func test_a_chain_s_next_leg_waits_for_the_screen() -> void:
	var d := _def()
	d.stage1_cycle = ["charge"]
	d.charge_chain = 2
	var b := BossBrain.new(d)
	_actions(b, d, 2)  # the first leg run
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	for i in 10:
		b.tick(0.1, d, false)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	b.tick(0.01, d, true)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)


## keep_range above 0: the body backs away inside it, closes outside it, and holds within
## KEEP_SLACK of it; off screen it closes on the player whatever the distance.
func test_keep_range_holds_a_distance() -> void:
	var d := _def()
	d.speed = 40.0
	d.keep_range = 200.0
	var b := BossBrain.new(d)
	assert_vector(b.wish(Vector2(100, 0), d)).is_equal(Vector2(-40, 0))
	assert_vector(b.wish(Vector2(300, 0), d)).is_equal(Vector2(40, 0))
	assert_vector(b.wish(Vector2(200 + BossBrain.KEEP_SLACK - 1.0, 0), d)).is_equal(Vector2.ZERO)
	assert_vector(b.wish(Vector2(200 - BossBrain.KEEP_SLACK + 1.0, 0), d)).is_equal(Vector2.ZERO)
	assert_vector(b.wish(Vector2(100, 0), d, false)).is_equal(Vector2(40, 0))
	d.keep_range = 0.0
	assert_vector(b.wish(Vector2(100, 0), d)).is_equal(Vector2(40, 0))  # tier 1: at the player
