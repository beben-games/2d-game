extends GdUnitTestSuite
## The cheat table: a code word gives its flags and a random seed, digits give a seed and no flags,
## junk gives neither; an action word (the save wipe) gives its action, a random seed, and no
## flags; describe() names the flags that are on for the summary and the run line.


func test_a_code_word_gives_its_flags_and_a_random_seed() -> void:
	var parsed := Cheats.parse("permawhat?")
	assert_int(parsed["seed"]).is_equal(-1)
	assert_that(parsed["cheats"]).is_equal({"immortal": true})
	assert_that(Cheats.parse("  permawhat?  ")["cheats"]).is_equal({"immortal": true})  # padding is forgiven


func test_digits_are_the_seed_and_no_flags() -> void:
	var parsed := Cheats.parse("42")
	assert_int(parsed["seed"]).is_equal(42)
	assert_that(parsed["cheats"]).is_equal({})
	assert_int(Cheats.parse("0")["seed"]).is_equal(0)


func test_junk_and_blank_are_a_random_seed_and_no_flags() -> void:
	for text: String in ["", "   ", "1a2b", "permawhat", "PERMAWHAT?", "-5"]:
		var parsed := Cheats.parse(text)
		assert_int(parsed["seed"]).override_failure_message("seed for '%s'" % text).is_equal(-1)
		assert_that(parsed["cheats"]).override_failure_message("cheats for '%s'" % text).is_equal({})
		assert_str(parsed["action"]).override_failure_message("action for '%s'" % text).is_equal("")


func test_describe_names_the_flags_that_are_on() -> void:
	assert_str(Cheats.describe({})).is_equal("")
	assert_str(Cheats.describe({"immortal": true})).is_equal("immortal")
	assert_str(Cheats.describe({"b": true, "a": true, "c": false})).is_equal("a,b")


func test_every_code_sets_at_least_one_flag() -> void:
	for code: String in Cheats.CODES:
		assert_str(Cheats.describe(Cheats.CODES[code])).override_failure_message("code '%s'" % code).is_not_empty()


func test_verso_and_dives_are_the_verdict_and_money_codes() -> void:
	assert_that(Cheats.parse("verso")["cheats"]).is_equal({"thumbs_down": true})
	assert_that(Cheats.parse("dives")["cheats"]).is_equal({"rich": true})
	assert_int(Cheats.parse("verso")["seed"]).is_equal(Cheats.RANDOM_SEED)


## The save wipe is a title-time action, never a run flag: the run that follows is uncheated.
func test_tabula_is_the_wipe_action_with_a_random_seed_and_no_flags() -> void:
	for text: String in ["tabula", "  tabula  "]:
		var parsed := Cheats.parse(text)
		assert_str(parsed["action"]).override_failure_message("action for '%s'" % text).is_equal("wipe")
		assert_int(parsed["seed"]).is_equal(Cheats.RANDOM_SEED)
		assert_that(parsed["cheats"]).is_equal({})
		assert_str(Cheats.describe(parsed["cheats"])).is_equal("")
	for text: String in ["Tabula", "tabula rasa", "tabul"]:
		assert_str(Cheats.parse(text)["action"]).override_failure_message("action for '%s'" % text).is_equal("")


func test_a_code_word_or_a_seed_carries_no_action() -> void:
	for text: String in ["permawhat?", "verso", "dives", "42"]:
		assert_str(Cheats.parse(text)["action"]).override_failure_message("action for '%s'" % text).is_equal("")


func test_no_word_is_both_a_flag_code_and_an_action() -> void:
	for word: String in Cheats.ACTIONS:
		assert_bool(Cheats.CODES.has(word)).override_failure_message("'%s' in both tables" % word).is_false()
		assert_bool(word.is_valid_int()).is_false()
