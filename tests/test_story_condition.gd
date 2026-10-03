extends GdUnitTestSuite
## StoryCondition (a `when:` or a line's [condition]) and StoryContext (the names it reads):
## precedence, every comparison on ints and words, parentheses, a bare name's truth, names(),
## the load-time check, a syntax error's message; the context's names from the profile's flags,
## the story flags, the newest run record, and the facts handed in, and the substitution. Pure:
## a Save made here, never Profile.


func _context(facts: Dictionary = {}) -> StoryContext:
	var save := Save.new()
	save.flags["deaths"] = 2
	save.flags["wins"] = 3
	save.flags["returned"] = true
	save.set_story_flag("met", true)
	save.set_story_flag("mood", "cold")
	return StoryContext.new(save, {"met": false, "trust": false, "count": 0, "mood": "calm"}, facts)


func _holds(text: String, facts: Dictionary = {}) -> bool:
	var parsed := StoryCondition.parse(text)
	assert_str(parsed["error"]).override_failure_message("parse error for '%s': %s" % [text, parsed["error"]]).is_empty()
	return (parsed["condition"] as StoryCondition).evaluate(_context(facts))


func _error_of(text: String) -> String:
	var parsed := StoryCondition.parse(text)
	assert_object(parsed["condition"]).override_failure_message("'%s' parsed" % text).is_null()
	return parsed["error"]


func _check(text: String) -> Array[String]:
	var parsed := StoryCondition.parse(text)
	assert_str(parsed["error"]).is_empty()
	return (parsed["condition"] as StoryCondition).check(_context())


# --- precedence and shape ---

func test_or_binds_looser_than_and_and_and_looser_than_not() -> void:
	# a or (b and (not c)): true or anything is true
	assert_bool(_holds("met or trust and not met")).is_true()
	# (not met) or trust: false or false
	assert_bool(_holds("not met or trust")).is_false()
	# trust and met or met: (trust and met) or met
	assert_bool(_holds("trust and met or met")).is_true()
	assert_bool(_holds("not not met")).is_true()


func test_parentheses_group() -> void:
	assert_bool(_holds("(met or trust) and not met")).is_false()
	assert_bool(_holds("met or (trust and not met)")).is_true()
	assert_bool(_holds("not (trust or deaths > 5)")).is_true()
	assert_bool(_holds("((met))")).is_true()


func test_a_bare_name_is_its_truth() -> void:
	assert_bool(_holds("met")).is_true()  # a bool flag set true in the save
	assert_bool(_holds("trust")).is_false()  # declared, never set: its default
	assert_bool(_holds("deaths")).is_true()  # an int: not zero
	assert_bool(_holds("count")).is_false()
	assert_bool(_holds("returned")).is_true()  # a profile flag
	assert_bool(_holds("last_verdict")).is_false()  # a word: "none" is false
	assert_bool(_holds("round_band", {"round_band": "boo"})).is_true()


func test_every_comparison_on_ints() -> void:
	assert_bool(_holds("deaths == 2")).is_true()
	assert_bool(_holds("deaths != 2")).is_false()
	assert_bool(_holds("deaths < 3")).is_true()
	assert_bool(_holds("deaths < 2")).is_false()
	assert_bool(_holds("deaths <= 2")).is_true()
	assert_bool(_holds("deaths > 1")).is_true()
	assert_bool(_holds("deaths > 2")).is_false()
	assert_bool(_holds("deaths >= 2")).is_true()
	assert_bool(_holds("deaths >= 3")).is_false()
	assert_bool(_holds("count == 0")).is_true()
	assert_bool(_holds("count > -1")).is_true()


func test_equality_on_words_and_bools() -> void:
	assert_bool(_holds("mood == cold")).is_true()  # a word story flag, set in the save
	assert_bool(_holds("mood != calm")).is_true()
	assert_bool(_holds("last_verdict == none")).is_true()  # an empty run log
	assert_bool(_holds("last_verdict == down")).is_false()
	assert_bool(_holds("round_loss == fled", {"round_loss": "fled"})).is_true()
	assert_bool(_holds("met == true")).is_true()
	assert_bool(_holds("trust != false")).is_false()


func test_a_name_on_the_right_reads_its_value() -> void:
	assert_bool(_holds("deaths < wins")).is_true()
	assert_bool(_holds("wins == deaths")).is_false()
	assert_bool(_holds("met == returned")).is_true()


func test_names_lists_the_names_read() -> void:
	var c: StoryCondition = StoryCondition.parse("deaths >= 1 and not (met or last_verdict == down) and met")["condition"]
	assert_array(c.names()).is_equal(["deaths", "met", "last_verdict"])
	assert_str(c.source).is_equal("deaths >= 1 and not (met or last_verdict == down) and met")


## The right side's bare words that read a name: as check() decided once checked (a word of the
## left name's list is a word), every bare right word before.
func test_right_names_lists_the_names_read_on_the_right() -> void:
	var c: StoryCondition = StoryCondition.parse("deaths < wins and last_verdict == down and mood == calm or count == 2")["condition"]
	assert_array(c.right_names()).is_equal(["wins", "down", "calm"])
	assert_array(c.check(_context())).is_empty()
	assert_array(c.right_names()).is_equal(["wins"])


## The words a name is compared with (the lint's check of last_killer against the enemy ids): as
## check() decided once checked; a name on the right is no word.
func test_compared_words_lists_the_words_a_name_is_compared_with() -> void:
	var c: StoryCondition = StoryCondition.parse("last_killer == boss or (not last_killer != chasr and mood == calm) or last_killer == mood")["condition"]
	assert_array(c.check(_context())).is_empty()
	assert_array(c.compared_words("last_killer")).is_equal(["boss", "chasr"])
	assert_array(c.compared_words("mood")).is_equal(["calm"])
	assert_array(c.compared_words("wins")).is_empty()


## The words a name may hold while the condition holds, as its structure tells (an `and` narrows,
## an `or` widens, a `not` of a comparison flips it); every word when it cannot tell.
func test_words_held_by_a_condition() -> void:
	var all: Array[String] = ["gate", "door", "start", "none"]
	var cases := {
		"arrival == gate": ["gate"],
		"arrival != door": ["gate", "start", "none"],
		"arrival == door and wins >= 1": ["door"],
		"arrival == gate or (arrival == door and runs > 2)": ["gate", "door"],
		"arrival == gate or wins > 1": all,
		"not arrival == gate": ["door", "start", "none"],
		"not (arrival == gate and wins > 1)": all,
		"wins >= 1": all,
		"arrival == gate and arrival == door": [],
		"(arrival == gate or arrival == start) and not arrival == start": ["gate"],
	}
	for text: String in cases:
		var c: StoryCondition = StoryCondition.parse(text)["condition"]
		assert_array(c.words_held("arrival", all)).override_failure_message(text).is_equal(cases[text])


func test_a_dotted_name_parses_for_a_later_namespace() -> void:
	var c: StoryCondition = StoryCondition.parse("bond.lanista >= 2")["condition"]
	assert_array(c.names()).is_equal(["bond.lanista"])
	var found := c.check(_context())
	assert_int(found.size()).is_equal(1)
	assert_str(found[0]).contains("'bond.lanista'")


# --- syntax errors ---

## One integer shape: digits with an optional leading '-', no '+', no leading zero.
func test_an_integer_is_digits_with_an_optional_minus_and_no_leading_zero() -> void:
	assert_bool(_holds("count == 0")).is_true()
	assert_bool(_holds("deaths > -1")).is_true()
	assert_str(_error_of("deaths == 03")).contains("'03'")
	assert_str(_error_of("deaths == +3")).contains("'+'")
	assert_str(_error_of("deaths == -03")).contains("'-03'")
	for text: String in ["0", "3", "-2", "120"]:
		assert_bool(StoryCondition.is_integer(text)).override_failure_message(text).is_true()
	for text: String in ["+3", "03", "-0", "", "-", "3a", " 3"]:
		assert_bool(StoryCondition.is_integer(text)).override_failure_message(text).is_false()


## check() settles a bare right-hand word as a word against the names known at load; a fact
## handed in at play under the word's spelling does not turn the comparison into a name's.
func test_a_fact_named_like_a_word_does_not_change_a_checked_comparison() -> void:
	var c: StoryCondition = StoryCondition.parse("mood == cold and last_killer == boss")["condition"]
	assert_array(c.check(_context())).is_empty()
	assert_bool(c.evaluate(_context({"last_killer": "boss"}))).is_true()
	assert_bool(c.evaluate(_context({"last_killer": "boss", "cold": "calm", "boss": "chaser"}))).is_true()
	# unchecked, the fallback decides at each evaluate: a known name is read as a name
	var unchecked: StoryCondition = StoryCondition.parse("mood == cold")["condition"]
	assert_bool(unchecked.evaluate(_context({"cold": "calm"}))).is_false()


func test_a_syntax_error_says_what_and_where() -> void:
	assert_str(_error_of("deaths >=")).contains("expected a value after '>='").contains("the end")
	assert_str(_error_of("deaths >= 1 and")).contains("expected a name").contains("the end")
	assert_str(_error_of("(met or trust")).contains("expected ')'")
	assert_str(_error_of("met trust")).contains("unexpected 'trust'").contains("column 5")
	assert_str(_error_of("deaths = 1")).contains("'='")
	assert_str(_error_of("3 < deaths")).contains("expected a name").contains("'3'")
	assert_str(_error_of("met & trust")).contains("'&'")
	assert_str(_error_of("")).contains("empty")
	assert_str(_error_of("(met) == true")).contains("unexpected '=='")


# --- the load-time check ---

## The one message check gives for the text, holding each fragment.
func _check_one(text: String, fragments: Array[String]) -> void:
	var found := _check(text)
	assert_int(found.size()).override_failure_message("check('%s'): %s" % [text, found]).is_equal(1)
	for fragment: String in fragments:
		assert_str(found[0] if found.size() == 1 else "").contains(fragment)


func test_check_names_an_unknown_name() -> void:
	_check_one("ghost and met", ["unknown name", "'ghost'"])
	_check_one("deaths >= many", ["unknown name", "'many'"])
	assert_array(_check("deaths >= 1 and met")).is_empty()


func test_check_refuses_a_word_outside_the_names_list() -> void:
	_check_one("last_verdict == sideways", ["'sideways'", "'last_verdict'", "up, down, none"])
	assert_array(_check("last_band == roar or round_loss == slow or run_band != boo")).is_empty()
	assert_array(_check("last_killer == chaser")).is_empty()  # an enemy id: no closed list
	_check_one("arrival == lift", ["'lift'", "'arrival'", "gate, door, start, none"])
	assert_array(_check("arrival == gate or arrival == door or arrival != start")).is_empty()
	assert_array(_check("mood == furious")).is_empty()  # a word story flag: no closed list


func test_check_refuses_a_mismatched_kind_and_ordering_on_a_word() -> void:
	_check_one("met == 3", ["'met'", "a bool", "a number"])
	_check_one("deaths == true", ["'deaths'", "an int", "a bool"])
	_check_one("last_verdict < up", ["'<'", "'last_verdict'", "a word"])
	_check_one("deaths == met", ["'deaths'", "'met'", "a bool"])


# --- the context ---

func test_the_context_reads_the_newest_run_record() -> void:
	var save := Save.new()
	save.log_run({"outcome": "win", "verdict": "up", "bands": [3], "felled_by": ""})
	save.log_run({"outcome": "fall", "verdict": "down", "bands": [0, 2, 1], "felled_by": "chaser"})
	var c := StoryContext.new(save)
	assert_str(c.value("last_outcome")).is_equal("fall")
	assert_str(c.value("last_verdict")).is_equal("down")
	assert_str(c.value("last_band")).is_equal("quiet")
	assert_str(c.value("last_killer")).is_equal("chaser")


func test_the_last_runs_facts_are_none_without_a_record_or_a_field() -> void:
	var c := StoryContext.new(Save.new())
	for name: String in ["last_outcome", "last_verdict", "last_band", "last_killer", "round_band", "round_loss", "run_band", "arrival"]:
		assert_str(c.value(name)).override_failure_message(name).is_equal("none")
	var save := Save.new()
	save.log_run({"outcome": "yield", "verdict": "", "bands": []})  # a yield: no verdict, no round ended
	c = StoryContext.new(save)
	assert_str(c.value("last_outcome")).is_equal("yield")
	assert_str(c.value("last_verdict")).is_equal("none")
	assert_str(c.value("last_band")).is_equal("none")
	assert_str(c.value("last_killer")).is_equal("none")


func test_the_band_words_are_the_favour_bands_and_none() -> void:
	for name: String in ["last_band", "round_band", "run_band"]:
		var expected: Array = FavourRules.BAND_NAMES.duplicate()
		expected.append("none")
		assert_array(StoryContext.WORDS[name]).is_equal(expected)


func test_the_context_knows_its_names_and_their_kinds() -> void:
	var c := _context({"round_loss": "hit"})
	for name: String in Save.FLAG_KEYS:
		assert_bool(c.knows(name)).override_failure_message(name).is_true()
	assert_bool(c.knows("spoliarium_seen")).is_true()
	assert_bool(c.knows("met")).is_true()
	assert_bool(c.knows("ghost")).is_false()
	assert_str(c.kind("deaths")).is_equal("int")
	assert_str(c.kind("returned")).is_equal("bool")
	assert_str(c.kind("mood")).is_equal("word")
	assert_str(c.kind("last_killer")).is_equal("word")
	assert_str(c.value("round_loss")).is_equal("hit")
	assert_array(c.words("round_loss")).is_equal(["hit", "fled", "slow", "none"])
	assert_array(c.words("mood")).is_empty()


func test_a_fact_overrides_a_profile_name() -> void:
	var c := _context({"wins": 9, "last_verdict": "up"})
	assert_int(c.value("wins")).is_equal(9)
	assert_str(c.value("last_verdict")).is_equal("up")


func test_a_story_flag_of_the_wrong_type_in_the_save_reads_its_default() -> void:
	var save := Save.new()
	save.set_story_flag("count", "lots")
	var c := StoryContext.new(save, {"count": 0})
	assert_int(c.value("count")).is_equal(0)


func test_substitute_fills_known_names_and_leaves_the_rest() -> void:
	var c := _context()
	assert_str(c.substitute("{wins} nights, {deaths} falls, {mood}, {last_verdict}")).is_equal("3 nights, 2 falls, cold, none")
	assert_str(c.substitute("{ghost} and {wins}")).is_equal("{ghost} and 3")
	assert_array(StoryContext.names_in("{wins} and { deaths } and {}")).is_equal(["wins", "deaths", ""])
