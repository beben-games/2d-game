extends GdUnitTestSuite
## The cheat table: a code word gives its flags and a random seed, digits give a seed and no flags,
## junk gives neither; describe() names the flags that are on for the summary and the run line.


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


func test_describe_names_the_flags_that_are_on() -> void:
	assert_str(Cheats.describe({})).is_equal("")
	assert_str(Cheats.describe({"immortal": true})).is_equal("immortal")
	assert_str(Cheats.describe({"b": true, "a": true, "c": false})).is_equal("a,b")


func test_every_code_sets_at_least_one_flag() -> void:
	for code: String in Cheats.CODES:
		assert_str(Cheats.describe(Cheats.CODES[code])).override_failure_message("code '%s'" % code).is_not_empty()
