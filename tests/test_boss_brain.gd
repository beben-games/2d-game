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
		var action := b.tick(0.1, d)
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
	b.tick(0.95, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	b.tick(0.1, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_str(b.tick(0.5, d)).is_equal("")
	assert_str(b.tick(0.11, d)).is_equal("ring")
	assert_int(b.phase).is_equal(BossBrain.Phase.ATTACK)
	assert_str(b.tick(0.01, d)).is_equal("")  # a ring lands on one tick
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.7, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.11, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.VOLLEY)


func test_the_charge_runs_its_time_and_a_wall_ends_it_early() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_array(_actions(b, d, 3)).is_equal(["ring", "volley", "charge"])
	assert_bool(b.charging()).is_true()
	assert_str(b.tick(0.3, d)).is_equal("")
	assert_bool(b.charging()).is_true()
	assert_str(b.tick(0.21, d)).is_equal("charge_end")
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	var c := BossBrain.new()
	_actions(c, d, 3)
	assert_str(c.end_charge()).is_equal("charge_end")
	assert_bool(c.charging()).is_false()
	assert_int(c.phase).is_equal(BossBrain.Phase.RECOVER)
	assert_str(c.end_charge()).is_equal("")  # not charging: a no-op


func test_wish_moves_only_while_approaching() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_vector(b.wish(Vector2(50, 0))).is_equal(Vector2(50, 0))
	b.tick(1.1, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_vector(b.wish(Vector2(50, 0))).is_equal(Vector2.ZERO)


func test_the_stage_change_lands_at_the_next_edge_never_mid_charge() -> void:
	var b := BossBrain.new()
	var d := _def()
	_actions(b, d, 3)  # charging
	b.request_enrage()
	assert_int(b.stage).is_equal(1)
	assert_str(b.tick(0.1, d)).is_equal("")
	assert_int(b.stage).is_equal(1)  # the charge runs on
	assert_str(b.tick(0.41, d)).is_equal("charge_end")
	assert_int(b.stage).is_equal(2)  # applied at the edge into RECOVER
	assert_float(b.recover_time(d)).is_equal(0.5)
	assert_float(b.telegraph_time(d)).is_equal(0.45)
	assert_int(b.ring_count(d)).is_equal(16)
	b.tick(0.45, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.tick(0.06, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.SUMMON)  # stage two's cycle continues after the charge
	assert_array(_actions(b, d, 5)).is_equal(["summon", "ring", "volley", "charge", "charge_end"])


func test_the_stage_change_from_approach_lands_on_the_telegraph_edge() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.request_enrage()
	b.tick(0.5, d)
	assert_int(b.stage).is_equal(1)
	b.tick(0.6, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	assert_int(b.stage).is_equal(2)
	b.request_enrage()  # already there: nothing to do
	assert_bool(b.enrage_requested).is_false()


func test_interrupt_cuts_only_a_telegraph() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.interrupt()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	b.tick(1.1, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	b.interrupt()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_float(b.phase_time).is_equal(0.0)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.RING)  # the same attack, wound up again in full


func test_an_enrage_requested_during_a_recover_takes_the_stage_two_cycle_at_that_edge() -> void:
	var b := BossBrain.new()
	var d := _def()
	assert_array(_actions(b, d, 3)).is_equal(["ring", "volley", "charge"])
	assert_str(b.tick(0.51, d)).is_equal("charge_end")
	assert_int(b.phase).is_equal(BossBrain.Phase.RECOVER)
	b.request_enrage()
	assert_int(b.stage).is_equal(1)
	b.tick(d.recover_time + 0.01, d)  # a stage-1 recover: the stage flips only at its edge
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.stage).is_equal(2)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.SUMMON)  # stage two's cycle from that edge on


## Ticks at 60 Hz until the phase changes. Returns the tick count.
func _ticks_until_phase_changes(b: BossBrain, d: BossDef, limit := 1000) -> int:
	var start := b.phase
	var n := 0
	while b.phase == start and n < limit:
		b.tick(1.0 / 60.0, d)
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
	b.tick(d.recover_time + 0.01, d)  # the next edge taken inside tick(): a stage-1 recover
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.stage).is_equal(2)
	assert_int(b.pattern).is_equal(BossBrain.Pattern.SUMMON)


func test_a_stun_cutting_the_telegraph_does_not_flip_the_stage() -> void:
	var b := BossBrain.new()
	var d := _def()
	b.tick(1.1, d)
	assert_int(b.phase).is_equal(BossBrain.Phase.TELEGRAPH)
	b.request_enrage()
	b.interrupt()
	assert_int(b.phase).is_equal(BossBrain.Phase.APPROACH)
	assert_int(b.stage).is_equal(1)
	assert_bool(b.enrage_requested).is_true()
	b.tick(1.1, d)  # the next edge taken inside tick()
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
