extends GdUnitTestSuite


func _health(max_hp: float) -> Health:
	var h: Health = auto_free(Health.new())
	h.setup(max_hp)
	return h


func test_take_damage_reduces_hp() -> void:
	var h := _health(3.0)
	h.take_damage(1.0)
	assert_float(h.hp).is_equal(2.0)
	assert_bool(h.dead).is_false()


func test_overkill_clamps_to_zero_and_dies_once() -> void:
	var h := _health(3.0)
	var deaths := [0]
	h.died.connect(func() -> void: deaths[0] += 1)
	h.take_damage(10.0)
	h.take_damage(1.0)
	assert_float(h.hp).is_equal(0.0)
	assert_bool(h.dead).is_true()
	assert_int(deaths[0]).is_equal(1)


func test_damaged_signal_carries_knockback() -> void:
	var h := _health(3.0)
	var received := []
	h.damaged.connect(func(amount: float, kb: Vector2) -> void: received.append([amount, kb]))
	h.take_damage(1.0, Vector2(5, 0))
	assert_array(received).is_equal([[1.0, Vector2(5, 0)]])


func test_non_positive_damage_is_ignored() -> void:
	var h := _health(3.0)
	var received := []
	h.damaged.connect(func(amount: float, kb: Vector2) -> void: received.append([amount, kb]))
	h.take_damage(-5.0)
	h.take_damage(0.0)
	assert_float(h.hp).is_equal(3.0)
	assert_bool(h.dead).is_false()
	assert_array(received).is_empty()


func test_quiet_damage_is_flagged_for_the_owner() -> void:
	var h := _health(3.0)
	h.take_damage(1.0, Vector2.ZERO, true)
	assert_bool(h.last_hit_quiet).is_true()
	assert_float(h.hp).is_equal(2.0)
	h.take_damage(1.0)
	assert_bool(h.last_hit_quiet).is_false()
