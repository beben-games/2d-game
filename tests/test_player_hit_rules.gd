extends GdUnitTestSuite


func test_hit_allowed_when_not_invulnerable() -> void:
	assert_bool(PlayerHitRules.can_take_hit(0.0)).is_true()


func test_hit_blocked_during_invulnerability() -> void:
	assert_bool(PlayerHitRules.can_take_hit(0.3)).is_false()


func test_knockback_points_away_from_attacker() -> void:
	var kb := PlayerHitRules.knockback_from(Vector2(10, 0), Vector2(0, 0), 100.0)
	assert_vector(kb).is_equal(Vector2(100, 0))


func test_knockback_with_overlapping_positions_still_has_length() -> void:
	var kb := PlayerHitRules.knockback_from(Vector2(5, 5), Vector2(5, 5), 100.0)
	assert_float(kb.length()).is_equal_approx(100.0, 0.001)


func test_blink_is_visible_half_the_time() -> void:
	assert_bool(PlayerHitRules.blink_visible(0.0)).is_true()
	assert_bool(PlayerHitRules.blink_visible(0.03)).is_false()
	assert_bool(PlayerHitRules.blink_visible(0.08)).is_true()
