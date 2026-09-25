extends GdUnitTestSuite
## The pure favour rules: the acts table, the bands, the dash through danger, the cowardice
## drain, and the clamp. Every act's value lives in FavourRules.ACTS and nowhere else.


func test_the_acts_table_holds_every_act_and_its_value() -> void:
	assert_that(FavourRules.ACTS).is_equal({"kill": 3, "chain": 2, "daring": 3, "clean_round": 15, "hit": -20})
	assert_float(FavourRules.START).is_equal(30.0)
	assert_float(FavourRules.MAX).is_equal(100.0)
	assert_float(FavourRules.CHAIN_WINDOW).is_equal(1.5)
	assert_float(FavourRules.DASH_WINDOW).is_equal(0.5)
	assert_float(FavourRules.DANGER_RADIUS).is_equal(24.0)
	assert_float(FavourRules.IDLE_GRACE).is_equal(4.0)
	assert_float(FavourRules.COWARDICE_PER_SECOND).is_equal(2.0)


func test_apply_adds_the_acts_value() -> void:
	assert_float(FavourRules.apply(30.0, "kill")).is_equal(33.0)
	assert_float(FavourRules.apply(30.0, "chain")).is_equal(32.0)
	assert_float(FavourRules.apply(30.0, "daring")).is_equal(33.0)
	assert_float(FavourRules.apply(30.0, "clean_round")).is_equal(45.0)
	assert_float(FavourRules.apply(30.0, "hit")).is_equal(10.0)


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


func test_the_granter_and_the_card_count_by_band() -> void:
	assert_str(FavourRules.granter(FavourRules.BOO)).is_equal("The emperor")
	assert_str(FavourRules.granter(FavourRules.QUIET)).is_equal("The emperor")
	assert_str(FavourRules.granter(FavourRules.CHEER)).is_equal("The crowd")
	assert_str(FavourRules.granter(FavourRules.ROAR)).is_equal("The crowd")
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


func test_cowardice_drains_only_past_the_grace() -> void:
	assert_float(FavourRules.cowardice(3.9, 1.0)).is_equal(0.0)
	assert_float(FavourRules.cowardice(4.0, 1.0)).is_equal(-2.0)
	assert_float(FavourRules.cowardice(10.0, 0.5)).is_equal(-1.0)


func test_favour_clamps_to_the_meter() -> void:
	assert_float(FavourRules.apply(95.0, "clean_round")).is_equal(100.0)
	assert_float(FavourRules.apply(10.0, "hit")).is_equal(0.0)
	assert_float(FavourRules.clamp_value(-5.0)).is_equal(0.0)
	assert_float(FavourRules.clamp_value(120.0)).is_equal(100.0)
	assert_float(FavourRules.clamp_value(50.0)).is_equal(50.0)


func test_band_name_names_the_four_bands() -> void:
	assert_str(FavourRules.band_name(FavourRules.BOO)).is_equal("boo")
	assert_str(FavourRules.band_name(FavourRules.QUIET)).is_equal("quiet")
	assert_str(FavourRules.band_name(FavourRules.CHEER)).is_equal("cheer")
	assert_str(FavourRules.band_name(FavourRules.ROAR)).is_equal("roar")
