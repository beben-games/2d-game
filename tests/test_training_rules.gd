extends GdUnitTestSuite
## The training lines, pure: the prices per rank, what a save can buy, what the ranks give a
## run's start, and a purchase on a Save.

const OLD_SAVE_PATH := "user://test_training_old_lines.cfg"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_SAVE_PATH))


func _save(money: int, training: Dictionary = {}) -> Save:
	var s := Save.new()
	s.money = money
	s.training = training.duplicate()
	return s


func test_the_lines_and_their_prices_per_rank() -> void:
	assert_array(TrainingRules.LINES.keys()).contains_exactly(["offer", "reroll", "mercy", "reach"])
	assert_int(TrainingRules.max_rank("offer")).is_equal(2)
	assert_int(TrainingRules.max_rank("reroll")).is_equal(2)
	assert_int(TrainingRules.max_rank("mercy")).is_equal(1)
	assert_int(TrainingRules.max_rank("reach")).is_equal(3)
	assert_int(TrainingRules.price("offer", 1)).is_equal(120)
	assert_int(TrainingRules.price("offer", 2)).is_equal(240)
	assert_int(TrainingRules.price("reroll", 1)).is_equal(100)
	assert_int(TrainingRules.price("reroll", 2)).is_equal(200)
	assert_int(TrainingRules.price("mercy", 1)).is_equal(300)
	assert_int(TrainingRules.price("reach", 1)).is_equal(40)
	assert_int(TrainingRules.price("reach", 2)).is_equal(80)
	assert_int(TrainingRules.price("reach", 3)).is_equal(160)


## Each line names what it buys in a short line (UI may name, never narrate): the panel shows it.
func test_every_line_has_a_text_naming_what_it_buys() -> void:
	assert_str(TrainingRules.text("offer")).is_equal("One more card to choose from")
	assert_str(TrainingRules.text("reroll")).is_equal("Change the cards once a run")
	assert_str(TrainingRules.text("mercy")).is_equal("Fall once and fight on")
	assert_str(TrainingRules.text("reach")).is_equal("Coins come from further")
	for line: String in TrainingRules.LINES:
		assert_str(TrainingRules.text(line)).is_equal(TrainingRules.LINES[line]["text"])


## Each line has an icon the panel draws: a card, the clover, the heal cross, the coin.
func test_every_line_has_an_icon() -> void:
	assert_str(TrainingRules.icon("offer")).is_equal("card")
	assert_str(TrainingRules.icon("reroll")).is_equal("clover")
	assert_str(TrainingRules.icon("mercy")).is_equal("heal")
	assert_str(TrainingRules.icon("reach")).is_equal(TrainingRules.COIN_ICON)
	for line: String in TrainingRules.LINES:
		var icon := TrainingRules.icon(line)
		if icon != TrainingRules.COIN_ICON:
			assert_bool(IconAtlas.has(icon)).override_failure_message("%s's icon %s is not in the atlas" % [line, icon]).is_true()


func test_the_next_price_follows_the_rank_held_and_is_zero_when_capped() -> void:
	assert_int(TrainingRules.rank(_save(0), "reach")).is_equal(0)
	assert_int(TrainingRules.next_price(_save(0), "reach")).is_equal(40)
	assert_int(TrainingRules.next_price(_save(0, {"reach": 2}), "reach")).is_equal(160)
	assert_int(TrainingRules.next_price(_save(0, {"reach": 3}), "reach")).is_equal(0)
	assert_bool(TrainingRules.capped(_save(0, {"reach": 3}), "reach")).is_true()
	assert_bool(TrainingRules.capped(_save(0, {"reach": 2}), "reach")).is_false()
	assert_bool(TrainingRules.capped(_save(0, {"mercy": 1}), "mercy")).is_true()


func test_can_buy_is_false_when_capped_or_poor() -> void:
	assert_bool(TrainingRules.can_buy(_save(40), "reach")).is_true()
	assert_bool(TrainingRules.can_buy(_save(39), "reach")).is_false()
	assert_bool(TrainingRules.can_buy(_save(1000, {"reach": 3}), "reach")).is_false()
	assert_bool(TrainingRules.can_buy(_save(80, {"reach": 1}), "reach")).is_true()
	assert_bool(TrainingRules.can_buy(_save(79, {"reach": 1}), "reach")).is_false()
	assert_bool(TrainingRules.can_buy(_save(300), "mercy")).is_true()
	assert_bool(TrainingRules.can_buy(_save(300, {"mercy": 1}), "mercy")).is_false()


## What the ranks give a run: a card per Offer rank, a re-roll per Reroll rank, the one mercy,
## and REACH_STEP more pull per Reach rank over PileRules.PULL_RADIUS.
func test_apply_on_ranks_zero_and_max() -> void:
	var none := TrainingRules.apply(_save(0))
	assert_int(int(none["offer_bonus"])).is_equal(0)
	assert_int(int(none["rerolls"])).is_equal(0)
	assert_int(int(none["mercies"])).is_equal(0)
	assert_float(float(none["pull_radius"])).is_equal(PileRules.PULL_RADIUS)
	var maxed := TrainingRules.apply(_save(0, {"offer": 2, "reroll": 2, "mercy": 1, "reach": 3}))
	assert_int(int(maxed["offer_bonus"])).is_equal(2)
	assert_int(int(maxed["rerolls"])).is_equal(2)
	assert_int(int(maxed["mercies"])).is_equal(1)
	assert_float(float(maxed["pull_radius"])).is_equal(PileRules.PULL_RADIUS + 3 * TrainingRules.REACH_STEP)
	var one := TrainingRules.apply(_save(0, {"offer": 1, "reach": 1}))
	assert_int(int(one["offer_bonus"])).is_equal(1)
	assert_int(int(one["rerolls"])).is_equal(0)
	assert_float(float(one["pull_radius"])).is_equal(PileRules.PULL_RADIUS + 32.0)


## The rc1 lines (hearts, breath, renown) in an older save load harmlessly and count for nothing:
## an unknown line's rank is 0 and apply reads only the four lines.
func test_old_ranks_in_a_save_are_ignored() -> void:
	var old := _save(500, {"hearts": 3, "breath": 2, "renown": 3})
	assert_int(TrainingRules.rank(old, "hearts")).is_equal(0)
	assert_int(TrainingRules.rank(old, "reach")).is_equal(0)
	assert_that(TrainingRules.apply(old)).is_equal(TrainingRules.apply(_save(500)))
	assert_int(old.save_to(OLD_SAVE_PATH)).is_equal(OK)
	var loaded := Save.load_from(OLD_SAVE_PATH)
	assert_int(loaded.money).is_equal(500)
	assert_that(TrainingRules.apply(loaded)).is_equal(TrainingRules.apply(_save(500)))
	assert_bool(TrainingRules.can_buy(loaded, "reach")).is_true()
	TrainingRules.buy(loaded, "reach")
	assert_int(TrainingRules.rank(loaded, "reach")).is_equal(1)
	assert_int(loaded.training["hearts"]).is_equal(3)  # kept on the save, read by nothing


func test_buy_takes_the_price_raises_the_rank_and_counts_the_coins_spent() -> void:
	var save := _save(50)
	assert_int(TrainingRules.buy(save, "reach")).is_equal(40)
	assert_int(save.money).is_equal(10)
	assert_int(save.training["reach"]).is_equal(1)
	assert_int(int(save.stat("coins_spent"))).is_equal(40)
	assert_int(TrainingRules.next_price(save, "reach")).is_equal(80)
	assert_bool(TrainingRules.can_buy(save, "reach")).is_false()
