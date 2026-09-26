extends GdUnitTestSuite
## The training lines, pure: the prices per rank, what a save can buy, what the ranks give a
## run's start, and a purchase on a Save.


func _save(money: int, training: Dictionary = {}) -> Save:
	var s := Save.new()
	s.money = money
	s.training = training.duplicate()
	return s


func test_the_lines_and_their_prices_per_rank() -> void:
	assert_array(TrainingRules.LINES.keys()).contains_exactly(["hearts", "breath", "renown"])
	assert_int(TrainingRules.max_rank("hearts")).is_equal(3)
	assert_int(TrainingRules.max_rank("breath")).is_equal(2)
	assert_int(TrainingRules.max_rank("renown")).is_equal(3)
	assert_int(TrainingRules.price("hearts", 1)).is_equal(50)
	assert_int(TrainingRules.price("hearts", 2)).is_equal(100)
	assert_int(TrainingRules.price("hearts", 3)).is_equal(200)
	assert_int(TrainingRules.price("breath", 1)).is_equal(80)
	assert_int(TrainingRules.price("breath", 2)).is_equal(160)
	assert_int(TrainingRules.price("renown", 1)).is_equal(40)
	assert_int(TrainingRules.price("renown", 2)).is_equal(80)
	assert_int(TrainingRules.price("renown", 3)).is_equal(160)


func test_the_next_price_follows_the_rank_held_and_is_zero_when_capped() -> void:
	assert_int(TrainingRules.rank(_save(0), "hearts")).is_equal(0)
	assert_int(TrainingRules.next_price(_save(0), "hearts")).is_equal(50)
	assert_int(TrainingRules.next_price(_save(0, {"hearts": 2}), "hearts")).is_equal(200)
	assert_int(TrainingRules.next_price(_save(0, {"hearts": 3}), "hearts")).is_equal(0)
	assert_bool(TrainingRules.capped(_save(0, {"hearts": 3}), "hearts")).is_true()
	assert_bool(TrainingRules.capped(_save(0, {"hearts": 2}), "hearts")).is_false()


func test_can_buy_is_false_when_capped_or_poor() -> void:
	assert_bool(TrainingRules.can_buy(_save(50), "hearts")).is_true()
	assert_bool(TrainingRules.can_buy(_save(49), "hearts")).is_false()
	assert_bool(TrainingRules.can_buy(_save(1000, {"hearts": 3}), "hearts")).is_false()
	assert_bool(TrainingRules.can_buy(_save(100, {"hearts": 1}), "hearts")).is_true()
	assert_bool(TrainingRules.can_buy(_save(99, {"hearts": 1}), "hearts")).is_false()
	assert_bool(TrainingRules.can_buy(_save(160, {"breath": 1}), "breath")).is_true()
	assert_bool(TrainingRules.can_buy(_save(160, {"breath": 2}), "breath")).is_false()


func test_apply_on_ranks_zero_and_max() -> void:
	var none := TrainingRules.apply(_save(0))
	assert_int(int(none["max_hp"])).is_equal(Build.BASE_MAX_HP)
	assert_int(int(none["dash_charges"])).is_equal(Build.BASE_DASH_CHARGES)
	assert_float(float(none["favour"])).is_equal(FavourRules.START)
	var maxed := TrainingRules.apply(_save(0, {"hearts": 3, "breath": 2, "renown": 3}))
	assert_int(int(maxed["max_hp"])).is_equal(12)
	assert_int(int(maxed["dash_charges"])).is_equal(3)
	assert_float(float(maxed["favour"])).is_equal(60.0)
	var one := TrainingRules.apply(_save(0, {"hearts": 1, "renown": 1}))
	assert_int(int(one["max_hp"])).is_equal(8)
	assert_int(int(one["dash_charges"])).is_equal(1)
	assert_float(float(one["favour"])).is_equal(40.0)


func test_buy_takes_the_price_raises_the_rank_and_counts_the_coins_spent() -> void:
	var save := _save(60)
	assert_int(TrainingRules.buy(save, "hearts")).is_equal(50)
	assert_int(save.money).is_equal(10)
	assert_int(save.training["hearts"]).is_equal(1)
	assert_int(int(save.stat("coins_spent"))).is_equal(50)
	assert_int(TrainingRules.next_price(save, "hearts")).is_equal(100)
	assert_bool(TrainingRules.can_buy(save, "hearts")).is_false()
