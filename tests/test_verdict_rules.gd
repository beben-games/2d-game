extends GdUnitTestSuite
## The emperor's verdict, pure. In M5 it is UP whatever the band, the hits, and the flags, unless
## the verso cheat's thumbs_down flag is on; M9's turning point fills the band-and-flags rule, so
## the signature is pinned here.


func test_up_for_every_band_with_no_cheats() -> void:
	for band: int in [FavourRules.BOO, FavourRules.QUIET, FavourRules.CHEER, FavourRules.ROAR]:
		assert_bool(VerdictRules.decide(band, 0, {}, {})).override_failure_message("band %d" % band).is_true()
		assert_bool(VerdictRules.decide(band, 9, {"runs": 3, "wins": 1}, {})).is_true()


func test_down_with_thumbs_down() -> void:
	assert_bool(VerdictRules.decide(FavourRules.ROAR, 0, {}, {"thumbs_down": true})).is_false()
	assert_bool(VerdictRules.decide(FavourRules.ROAR, 0, {}, {"thumbs_down": false})).is_true()
	assert_bool(VerdictRules.decide(FavourRules.ROAR, 0, {}, {"immortal": true})).is_true()


func test_gate_name() -> void:
	assert_str(VerdictRules.gate_name(true)).is_equal("Porta Triumphalis")
	assert_str(VerdictRules.gate_name(false)).is_equal("Porta Libitinaria")
