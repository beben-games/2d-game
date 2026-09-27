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
	assert_float(FavourRules.DECAY_GRACE).is_equal(3.0)
	assert_float(FavourRules.DECAY_PER_SECOND).is_equal(1.5)
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


func test_the_decay_drains_only_past_the_grace() -> void:
	assert_float(FavourRules.decay(2.9, 1.0)).is_equal(0.0)
	assert_float(FavourRules.decay(3.0, 1.0)).is_equal(-1.5)
	assert_float(FavourRules.decay(10.0, 0.5)).is_equal(-0.75)


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
