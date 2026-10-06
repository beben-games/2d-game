extends GdUnitTestSuite
## The pure favour rules: the acts table, the bands, the dash through danger, the decay, and
## the clamp. Every act's value lives in FavourRules.ACTS and nowhere else, but the kill's: a
## share of the round's KILL_BUDGET (kill_value, kill_share), scored through apply_kill. A summon
## pays and spends nothing.


func test_the_acts_table_holds_every_act_and_its_value() -> void:
	assert_that(FavourRules.ACTS).is_equal({"chain": 2, "dare": 2, "daring": 5, "clean_round": 10, "hit": -25})
	assert_str(FavourRules.KILL_ACT).is_equal("kill")
	assert_bool(FavourRules.ACTS.has(FavourRules.KILL_ACT)).is_false()  # the kill's value is the budget's
	assert_float(FavourRules.KILL_BUDGET).is_equal(40.0)
	assert_float(FavourRules.START).is_equal(20.0)
	assert_float(FavourRules.MAX).is_equal(100.0)
	assert_float(FavourRules.CHAIN_WINDOW).is_equal(1.5)
	assert_float(FavourRules.DASH_WINDOW).is_equal(0.75)
	assert_float(FavourRules.DANGER_RADIUS).is_equal(32.0)
	assert_float(FavourRules.DECAY_GRACE).is_equal(2.0)
	assert_float(FavourRules.DECAY_PER_SECOND).is_equal(4.0)
	assert_str(FavourRules.DECAY_ACT).is_equal("decay")


func test_apply_adds_the_acts_value() -> void:
	assert_float(FavourRules.apply(30.0, "chain")).is_equal(32.0)
	assert_float(FavourRules.apply(30.0, "dare")).is_equal(32.0)
	assert_float(FavourRules.apply(30.0, "daring")).is_equal(35.0)
	assert_float(FavourRules.apply(30.0, "clean_round")).is_equal(40.0)
	assert_float(FavourRules.apply(30.0, "hit")).is_equal(5.0)


## A round's kills share KILL_BUDGET: nine enemies (round 1) pay a ninth each, fifty-three (round
## 7) a fifty-third, the boss alone the whole budget; a count of 0 reads as one.
func test_a_kill_is_worth_the_rounds_budget_over_its_enemies() -> void:
	assert_float(FavourRules.kill_value(9)).is_equal_approx(40.0 / 9.0, 0.0001)
	assert_float(FavourRules.kill_value(53)).is_equal_approx(40.0 / 53.0, 0.0001)
	assert_float(FavourRules.kill_value(1)).is_equal(40.0)
	assert_float(FavourRules.kill_value(0)).is_equal(40.0)


## The round's kills never pay past the budget: a summon's kill after the round's own enemies
## pays what is left, then nothing.
func test_a_kill_pays_what_is_left_of_the_budget() -> void:
	assert_float(FavourRules.kill_share(9, 0.0)).is_equal_approx(40.0 / 9.0, 0.0001)
	assert_float(FavourRules.kill_share(1, 0.0)).is_equal(40.0)
	assert_float(FavourRules.kill_share(9, 38.0)).is_equal_approx(2.0, 0.0001)
	assert_float(FavourRules.kill_share(1, 40.0)).is_equal(0.0)
	assert_float(FavourRules.kill_share(9, 45.0)).is_equal(0.0)


## A summon (the boss's) is not in the round's table: its kill pays nothing, whatever is left.
func test_a_summons_kill_pays_no_share() -> void:
	assert_float(FavourRules.kill_share(1, 0.0, true)).is_equal(0.0)
	assert_float(FavourRules.kill_share(9, 10.0, true)).is_equal(0.0)
	assert_float(FavourRules.kill_share(1, 0.0, false)).is_equal(40.0)


## The boss pays the round's budget as it bleeds: a loud hit pays the budget's share of the hit's
## damage over the boss's max hp (M6 playtest 1: its favour was too hard to earn).
func test_a_hit_on_the_boss_pays_the_budget_by_its_damage() -> void:
	assert_float(FavourRules.boss_hit_share(75.0, 750.0, 0.0)).is_equal_approx(4.0, 0.0001)
	assert_float(FavourRules.boss_hit_share(1.0, 750.0, 0.0)).is_equal_approx(40.0 / 750.0, 0.0001)
	assert_float(FavourRules.boss_hit_share(0.0, 750.0, 0.0)).is_equal(0.0)
	assert_float(FavourRules.boss_hit_share(-5.0, 750.0, 0.0)).is_equal(0.0)


## The hits stop at the reserve line, BOSS_KILL_RESERVE of the budget short of it: one hit of the
## whole max, an overkill, or hits once the line is reached pay only what is left below it.
func test_the_boss_hits_stop_at_the_reserve_line() -> void:
	var line := FavourRules.KILL_BUDGET * (1.0 - FavourRules.BOSS_KILL_RESERVE)
	assert_float(line).is_equal(30.0)
	assert_float(FavourRules.boss_hit_share(750.0, 750.0, 0.0)).is_equal(line)
	assert_float(FavourRules.boss_hit_share(75.0, 750.0, 28.0)).is_equal_approx(2.0, 0.0001)
	assert_float(FavourRules.boss_hit_share(75.0, 750.0, 30.0)).is_equal(0.0)
	assert_float(FavourRules.boss_hit_share(75.0, 750.0, 45.0)).is_equal(0.0)


## The kill pays the reserve at least (the hits' all, with no burn), the reserve and the burn's
## part with one; hits and kill together are the budget, never more.
func test_the_boss_kill_pays_at_least_the_reserve_and_the_sum_never_passes_the_budget() -> void:
	var reserve := FavourRules.KILL_BUDGET * FavourRules.BOSS_KILL_RESERVE
	var paid := 0.0
	for damage: float in [100.0, 250.0, 7.5, 300.0, 200.0]:  # 857.5 dealt to 750 hp: the last overkills
		paid += FavourRules.boss_hit_share(damage, 750.0, paid)
	assert_float(paid).is_equal_approx(30.0, 0.0001)
	var kill := FavourRules.kill_share(1, paid)
	assert_float(kill).is_equal_approx(reserve, 0.0001)
	assert_float(paid + kill).is_equal_approx(40.0, 0.0001)
	paid = FavourRules.boss_hit_share(375.0, 750.0, 0.0)  # half its health by shots, half by a burn
	assert_float(paid).is_equal_approx(20.0, 0.0001)
	kill = FavourRules.kill_share(1, paid)
	assert_float(kill).is_equal_approx(20.0, 0.0001)
	assert_float(kill).is_greater_equal(reserve)
	assert_float(paid + kill).is_equal_approx(40.0, 0.0001)


## A boss def with no health to speak of reads its max as one: no division by zero.
func test_a_zero_or_negative_max_hp_reads_as_one() -> void:
	assert_float(FavourRules.boss_hit_share(0.5, 0.0, 0.0)).is_equal_approx(20.0, 0.0001)
	assert_float(FavourRules.boss_hit_share(0.5, -10.0, 0.0)).is_equal_approx(20.0, 0.0001)
	assert_float(FavourRules.boss_hit_share(5.0, 0.0, 0.0)).is_equal(30.0)


## The kill is scored by its share through apply_kill, under the same gate as the table's acts.
func test_apply_kill_scores_a_kill_by_its_share() -> void:
	assert_float(FavourRules.apply_kill(30.0, 4.5)).is_equal(34.5)
	assert_float(FavourRules.apply_kill(30.0, 0.0)).is_equal(30.0)


## While the round's gate is closed (the default), kills, chains, dares, and the clean round never
## lift the meter into Roar: they stop one under the edge, and at or above the gate they add
## nothing. Only a daring kill passes it.
func test_with_the_gate_closed_every_act_but_daring_stops_one_under_the_roar_edge() -> void:
	assert_array(FavourRules.CAPPED_ACTS).is_equal([FavourRules.KILL_ACT, "chain", "dare", "clean_round"])
	assert_float(FavourRules.ROAR_GATE).is_equal(FavourRules.BAND_EDGES[FavourRules.ROAR - 1] - 1.0)
	assert_int(FavourRules.band(FavourRules.ROAR_GATE)).is_equal(FavourRules.CHEER)
	assert_float(FavourRules.apply_kill(70.0, 1.0)).is_equal(71.0)
	assert_float(FavourRules.apply_kill(73.0, 4.0)).is_equal(74.0)
	assert_float(FavourRules.apply_kill(74.0, 4.0)).is_equal(74.0)
	assert_float(FavourRules.apply_kill(80.0, 4.0)).is_equal(80.0)
	assert_float(FavourRules.apply(73.0, "chain")).is_equal(74.0)
	assert_float(FavourRules.apply(80.0, "chain")).is_equal(80.0)
	assert_float(FavourRules.apply(73.0, "dare")).is_equal(74.0)
	assert_float(FavourRules.apply(74.0, "dare")).is_equal(74.0)
	assert_float(FavourRules.apply(70.0, "clean_round")).is_equal(74.0)
	assert_float(FavourRules.apply(74.0, "clean_round")).is_equal(74.0)
	assert_float(FavourRules.apply(80.0, "clean_round")).is_equal(80.0)
	assert_float(FavourRules.apply(74.0, "daring")).is_equal(79.0)
	assert_int(FavourRules.band(FavourRules.apply(74.0, "daring"))).is_equal(FavourRules.ROAR)
	assert_float(FavourRules.apply(73.0, "chain", false)).is_equal(74.0)  # the gate named closed


## Once the round's first daring kill opens the gate, the capped acts add in full up to MAX.
func test_with_the_gate_open_the_capped_acts_add_in_full() -> void:
	assert_float(FavourRules.apply_kill(73.0, 4.0, true)).is_equal(77.0)
	assert_float(FavourRules.apply(79.0, "chain", true)).is_equal(81.0)
	assert_float(FavourRules.apply(79.0, "dare", true)).is_equal(81.0)
	assert_float(FavourRules.apply(79.0, "clean_round", true)).is_equal(89.0)
	assert_float(FavourRules.apply(95.0, "clean_round", true)).is_equal(100.0)
	assert_float(FavourRules.apply(79.0, "daring", true)).is_equal(84.0)
	assert_float(FavourRules.apply(79.0, "hit", true)).is_equal(54.0)


## Between rounds the crowd settles: a meter past the gate comes down to it, anything under it
## stays, so every round's Roar takes its own daring kill.
func test_settle_brings_the_meter_down_to_the_gate() -> void:
	assert_str(FavourRules.SETTLE_ACT).is_equal("settle")
	assert_float(FavourRules.settle(79.0)).is_equal(FavourRules.ROAR_GATE)
	assert_float(FavourRules.settle(100.0)).is_equal(FavourRules.ROAR_GATE)
	assert_float(FavourRules.settle(74.0)).is_equal(74.0)
	assert_float(FavourRules.settle(60.0)).is_equal(60.0)


## The boss round is the series' last: the crowd goes wild there (BOSS_START, MAX) instead of settling.
func test_the_boss_round_is_the_last_and_opens_at_the_top() -> void:
	assert_bool(FavourRules.is_boss_round(7, 8)).is_true()
	assert_bool(FavourRules.is_boss_round(6, 8)).is_false()
	assert_bool(FavourRules.is_boss_round(0, 8)).is_false()
	assert_bool(FavourRules.is_boss_round(0, 1)).is_true()
	assert_bool(FavourRules.is_boss_round(0, 0)).is_false()
	assert_float(FavourRules.BOSS_START).is_equal(FavourRules.MAX)
	assert_str(FavourRules.WILD_ACT).is_equal("wild")
	assert_float(FavourRules.BOSS_GAIN_CAP).is_equal(20.0)


## The boss round's gains share BOSS_GAIN_CAP: a gain is trimmed to what the round's earlier
## gains left of it, never below 0; a loss passes untouched.
func test_a_boss_round_gain_is_trimmed_to_what_the_cap_leaves() -> void:
	assert_float(FavourRules.gain_allowed(0.0, 5.0)).is_equal(5.0)
	assert_float(FavourRules.gain_allowed(18.0, 5.0)).is_equal(2.0)
	assert_float(FavourRules.gain_allowed(20.0, 5.0)).is_equal(0.0)
	assert_float(FavourRules.gain_allowed(25.0, 5.0)).is_equal(0.0)
	assert_float(FavourRules.gain_allowed(20.0, -25.0)).is_equal(-25.0)
	assert_float(FavourRules.gain_allowed(0.0, 0.0)).is_equal(0.0)


## The meter after `hits` hits from BOSS_START, then gains offered in steps of `step` up to `offered`
## in all, each trimmed by the cap (the gate open, as in the boss round): the user's arithmetic.
func _boss_fight(hits: int, offered: float, step: float) -> float:
	var value := FavourRules.BOSS_START
	var gained := 0.0
	for i in hits:
		value = FavourRules.apply(value, "hit", true)
	var left := offered
	while left > 0.0:
		var change := FavourRules.gain_allowed(gained, minf(step, left))
		var after := FavourRules.clamp_value(value + change)
		gained += after - value
		value = after
		left -= step
	return value


## The user's playtest-2 sequences: no hit keeps Roar; one hit leaves the Roar edge with the cap
## to earn back; two hits and the whole cap stay under it, however much more is offered.
func test_two_hits_in_the_boss_round_lose_roar_and_one_hit_does_not() -> void:
	assert_int(FavourRules.band(_boss_fight(0, 0.0, 1.0))).is_equal(FavourRules.ROAR)
	assert_float(_boss_fight(1, 0.0, 1.0)).is_equal(75.0)
	assert_int(FavourRules.band(_boss_fight(1, 0.0, 1.0))).is_equal(FavourRules.ROAR)
	assert_float(_boss_fight(1, 20.0, 2.0)).is_greater_equal(75.0)
	assert_float(_boss_fight(1, 20.0, 2.0)).is_equal(95.0)
	assert_float(_boss_fight(2, 20.0, 5.0)).is_less(75.0)
	assert_float(_boss_fight(2, 20.0, 5.0)).is_equal(70.0)
	assert_float(_boss_fight(2, 200.0, 5.0)).is_equal(70.0)  # the cap holds however much is offered
	assert_int(FavourRules.band(_boss_fight(2, 200.0, 5.0))).is_equal(FavourRules.CHEER)


## A scoring act raises the meter and holds the decay off; a hit does neither. The kill and the
## dare are scoring acts like the table's others.
func test_every_act_but_the_hit_is_a_scoring_act() -> void:
	for act: String in ["kill", "chain", "dare", "daring", "clean_round"]:
		assert_bool(FavourRules.is_scoring(act)).is_true()
	assert_bool(FavourRules.is_scoring("hit")).is_false()


func test_the_bands_at_their_edges() -> void:
	assert_int(FavourRules.BOO).is_equal(0)
	assert_int(FavourRules.QUIET).is_equal(1)
	assert_int(FavourRules.CHEER).is_equal(2)
	assert_int(FavourRules.ROAR).is_equal(3)
	assert_int(FavourRules.band(0.0)).is_equal(FavourRules.BOO)
	assert_int(FavourRules.band(24.9)).is_equal(FavourRules.BOO)
	assert_int(FavourRules.band(25.0)).is_equal(FavourRules.QUIET)
	assert_int(FavourRules.band(49.9)).is_equal(FavourRules.QUIET)
	assert_int(FavourRules.band(50.0)).is_equal(FavourRules.CHEER)
	assert_int(FavourRules.band(74.9)).is_equal(FavourRules.CHEER)
	assert_int(FavourRules.band(75.0)).is_equal(FavourRules.ROAR)
	assert_int(FavourRules.band(100.0)).is_equal(FavourRules.ROAR)


func test_the_card_count_by_band() -> void:
	assert_int(FavourRules.offer_count(FavourRules.BOO)).is_equal(3)
	assert_int(FavourRules.offer_count(FavourRules.CHEER)).is_equal(3)
	assert_int(FavourRules.offer_count(FavourRules.ROAR)).is_equal(4)


func test_only_a_boo_locks_a_card() -> void:
	assert_int(FavourRules.lock_count(FavourRules.BOO)).is_equal(1)
	assert_int(FavourRules.lock_count(FavourRules.QUIET)).is_equal(0)
	assert_int(FavourRules.lock_count(FavourRules.CHEER)).is_equal(0)
	assert_int(FavourRules.lock_count(FavourRules.ROAR)).is_equal(0)


func test_a_dash_through_danger_passes_within_the_radius_of_an_enemy() -> void:
	var from := Vector2(100, 100)
	var to := Vector2(149.5, 100)  # DashRules.SPEED * DashRules.DURATION along +x
	var middle := Vector2(124.75, 100)
	assert_bool(FavourRules.dash_through_danger(from, to, [middle + Vector2(0, 20)], 24.0)).is_true()
	assert_bool(FavourRules.dash_through_danger(from, to, [middle + Vector2(0, 30)], 24.0)).is_false()
	assert_bool(FavourRules.dash_through_danger(from, to, [from - Vector2(30, 0)], 24.0)).is_false()  # behind the start
	assert_bool(FavourRules.dash_through_danger(from, to, [to + Vector2(30, 0)], 24.0)).is_false()  # past the end
	assert_bool(FavourRules.dash_through_danger(from, to, [], 24.0)).is_false()
	assert_bool(FavourRules.dash_through_danger(from, to, [middle + Vector2(0, 30), middle], 24.0)).is_true()  # any one enemy


## A dash past a bolt: the dashing point and each bolt both move in straight lines over the
## dash's duration, and the closest approach between them is what counts. The dash here runs
## from the origin to (49.5, 0) in 0.15 s, 330 px/s along +x.
func test_a_dash_past_a_bolt_counts_the_closest_approach_over_the_dash() -> void:
	var from := Vector2.ZERO
	var to := Vector2(49.5, 0)
	var duration := 0.15
	var radius := FavourRules.BOLT_RADIUS
	assert_float(radius).is_equal(20.0)
	# Crossing the path inside the radius during the dash: 17 px at about 0.1 s.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(25, 30), Vector2(0, -150)]], radius)).is_true()
	# The same line, crossing the path at 0.4 s, after the dash has ended: 44 px at its closest.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(25, 60), Vector2(0, -150)]], radius)).is_false()
	# The dash's time window: each of these would come within the radius after the dash ends or
	# before it starts, so only the clamp to the dash's duration rejects it. Crossing the line past
	# the dash's end: 13 px at 0.22 s, 29 px when the dash ends at 0.15 s.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(70, 35), Vector2(0, -100)]], radius)).is_false()
	# A still bolt ahead of the dash's end: 0 px at 0.30 s, 50.5 px at 0.15 s.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(100, 0), Vector2.ZERO]], radius)).is_false()
	# A bolt behind the start flying away: 0 px at -0.07 s, 30 px at the dash's start.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(-30, 0), Vector2(-100, 0)]], radius)).is_false()
	# Moving away: 15 px from the path while still, 38 px at its closest once it flies off.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(40, 15), Vector2(0, 300)]], radius)).is_false()
	# Outside the radius: flying beside the dasher, 25 px off the whole way.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(0, 25), Vector2(330, 0)]], radius)).is_false()
	# A still bolt beside the path.
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [[Vector2(25, 10), Vector2.ZERO]], radius)).is_true()
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [], radius)).is_false()
	# Any one bolt.
	var far := [Vector2(25, 60), Vector2(0, -150)]
	var near := [Vector2(25, 10), Vector2.ZERO]
	assert_bool(FavourRules.dash_past_bolt(from, to, duration, [far, near], radius)).is_true()


func test_the_decay_drains_only_past_the_grace() -> void:
	assert_float(FavourRules.decay(1.9, 1.0)).is_equal(0.0)
	assert_float(FavourRules.decay(2.0, 1.0)).is_equal(-4.0)
	assert_float(FavourRules.decay(10.0, 0.5)).is_equal(-2.0)


func test_favour_clamps_to_the_meter() -> void:
	assert_float(FavourRules.apply(97.0, "daring")).is_equal(100.0)
	assert_float(FavourRules.apply(20.0, "hit")).is_equal(0.0)
	assert_float(FavourRules.clamp_value(-5.0)).is_equal(0.0)
	assert_float(FavourRules.clamp_value(120.0)).is_equal(100.0)
	assert_float(FavourRules.clamp_value(50.0)).is_equal(50.0)


func test_band_name_names_the_four_bands() -> void:
	assert_str(FavourRules.band_name(FavourRules.BOO)).is_equal("boo")
	assert_str(FavourRules.band_name(FavourRules.QUIET)).is_equal("quiet")
	assert_str(FavourRules.band_name(FavourRules.CHEER)).is_equal("cheer")
	assert_str(FavourRules.band_name(FavourRules.ROAR)).is_equal("roar")


## The round's main loss: the source with the largest tally reaching LOSS_FLOOR, ties broken in
## LOSS_SOURCES' order (hit, fled, slow); none when nothing reaches the floor. Its words are the
## story's round_loss list.
func test_the_main_loss_is_the_largest_tally_over_the_floor() -> void:
	assert_float(FavourRules.NEAR_RADIUS).is_equal(96.0)
	assert_float(FavourRules.LOSS_FLOOR).is_equal(1.0)
	assert_array(FavourRules.LOSS_SOURCES).is_equal(["hit", "fled", "slow"])
	var words: Array = FavourRules.LOSS_SOURCES.duplicate()
	words.append(FavourRules.LOSS_NONE)
	assert_array(words).contains_exactly_in_any_order(StoryContext.WORDS["round_loss"])
	assert_str(FavourRules.main_loss({"hit": 25.0})).is_equal("hit")
	assert_str(FavourRules.main_loss({"fled": 3.0})).is_equal("fled")
	assert_str(FavourRules.main_loss({"slow": 1.5})).is_equal("slow")
	assert_str(FavourRules.main_loss({"hit": 25.0, "fled": 30.0, "slow": 8.0})).is_equal("fled")
	assert_str(FavourRules.main_loss({"hit": 4.0, "fled": 2.0, "slow": 9.0})).is_equal("slow")


func test_the_main_loss_breaks_ties_hit_then_fled_then_slow() -> void:
	assert_str(FavourRules.main_loss({"hit": 10.0, "fled": 10.0, "slow": 10.0})).is_equal("hit")
	assert_str(FavourRules.main_loss({"fled": 10.0, "slow": 10.0})).is_equal("fled")
	assert_str(FavourRules.main_loss({"slow": 10.0, "hit": 10.0})).is_equal("hit")


func test_the_main_loss_is_none_under_the_floor_or_with_nothing_lost() -> void:
	assert_str(FavourRules.main_loss({})).is_equal("none")
	assert_str(FavourRules.main_loss({"hit": 0.0, "fled": 0.0, "slow": 0.0})).is_equal("none")
	assert_str(FavourRules.main_loss({"fled": 0.99, "slow": 0.5})).is_equal("none")
	assert_str(FavourRules.main_loss({"slow": 1.0})).is_equal("slow")  # reaching the floor is enough


## A drain's source: slow near an enemy (within NEAR_RADIUS) or while engaged (a shot landed
## lately), fled only far and hitting nothing, nothing with no enemy (INF).
func test_a_drains_source_is_slow_near_or_engaged_fled_far_and_idle_and_nothing_with_none() -> void:
	assert_str(FavourRules.drain_source(10.0, false)).is_equal("slow")
	assert_str(FavourRules.drain_source(FavourRules.NEAR_RADIUS, false)).is_equal("slow")
	assert_str(FavourRules.drain_source(FavourRules.NEAR_RADIUS + 0.1, false)).is_equal("fled")
	assert_str(FavourRules.drain_source(200.0, true)).is_equal("slow")
	assert_str(FavourRules.drain_source(10.0, true)).is_equal("slow")
	assert_str(FavourRules.drain_source(INF, false)).is_equal("")
	assert_str(FavourRules.drain_source(INF, true)).is_equal("")


## A fight of two bodies (M7 Task 7): each hit pays its share of the bodies' summed health, never
## past the reserve line whichever body bleeds; a body's death that leaves another standing pays
## nothing, the last body's the rest of the budget (the reserve at least).
func test_a_fight_of_two_bodies_shares_the_summed_health_and_the_last_kill_pays_the_rest() -> void:
	var line := FavourRules.KILL_BUDGET * (1.0 - FavourRules.BOSS_KILL_RESERVE)
	var reserve := FavourRules.KILL_BUDGET * FavourRules.BOSS_KILL_RESERVE
	var summed := 750.0 + 500.0
	var paid := 0.0
	paid += FavourRules.boss_hit_share(125.0, summed, paid)  # a tenth of the fight: 4
	assert_float(paid).is_equal_approx(4.0, 0.0001)
	for damage: float in [750.0, 300.0, 600.0]:  # the first body's whole health and more
		paid += FavourRules.boss_hit_share(damage, summed, paid)
		assert_float(paid).is_less_equal(line + 0.0001)
	assert_float(paid).is_equal_approx(line, 0.0001)
	assert_float(FavourRules.boss_kill_share(2, paid, 2, false)).is_equal(0.0)
	var kill := FavourRules.boss_kill_share(2, paid, 2, true)
	assert_float(kill).is_equal_approx(reserve, 0.0001)
	assert_float(paid + kill).is_equal_approx(FavourRules.KILL_BUDGET, 0.0001)
	# Half the fight burned: the last kill pays the half its hits left, past one body's worth.
	paid = FavourRules.boss_hit_share(625.0, summed, 0.0)
	assert_float(FavourRules.boss_kill_share(2, paid, 2, true)).is_equal_approx(20.0, 0.0001)


## One body (tier 1): the last kill pays exactly the kill's share as before, in the boss round
## and beside a table of other enemies alike.
func test_one_body_s_kill_pays_the_kill_share() -> void:
	for enemies: int in [1, 2, 9]:
		for paid: float in [0.0, 10.0, 30.0, 39.0, 41.0]:
			assert_float(FavourRules.boss_kill_share(enemies, paid, 1, true)).is_equal(FavourRules.kill_share(enemies, paid))
