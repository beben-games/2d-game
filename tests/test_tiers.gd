extends GdUnitTestSuite
## The tiers: each a shipped series by id (Tiers), loaded and checked; an id with no series is
## refused. Pure: no autoload, no scene.


func test_the_shipped_tiers_load_and_validate() -> void:
	assert_array(Tiers.check()).is_empty()
	assert_array(Tiers.IDS).is_not_empty()
	for id: int in Tiers.IDS:
		assert_bool(Tiers.has(id)).is_true()
		var series := Tiers.series(id)
		assert_object(series).is_not_null()
		assert_int(series.tier).is_equal(id)
		assert_array(series.validate()).is_empty()


func test_tier_1_is_the_shipped_tier_1_series() -> void:
	assert_str(Tiers.path(1)).is_equal("res://data/series/tier_1.tres")
	var series := Tiers.series(1)
	assert_object(series).is_same(load("res://data/series/tier_1.tres"))
	assert_object(Tiers.series(1)).is_same(series)  # cached
	assert_int(series.arena_width).is_equal(28)
	assert_int(series.arena_height).is_equal(15)


func test_an_unknown_tier_is_refused() -> void:
	for id: int in [0, -1, 99]:
		assert_bool(Tiers.has(id)).override_failure_message("tier %d" % id).is_false()
		assert_object(Tiers.series(id)).override_failure_message("tier %d" % id).is_null()


func test_a_series_knows_its_tier_and_refuses_one_below_1() -> void:
	var s := SeriesDef.new()
	assert_int(s.tier).is_equal(1)
	s.tier = 0
	assert_array(s.validate()).contains(["tier must be >= 1"])


func test_a_tier_whose_series_names_another_tier_is_an_error() -> void:
	var s: SeriesDef = Tiers.series(1).duplicate()
	assert_array(Tiers.errors_of(1, s)).is_empty()
	assert_array(Tiers.errors_of(2, s)).contains(["tier 2: the series says tier 1"])
	assert_array(Tiers.errors_of(3, null)).contains(["tier 3: no series at %s" % Tiers.path(3)])
	s.rounds = []
	assert_array(Tiers.errors_of(1, s)).contains(["tier 1: series has no rounds"])
