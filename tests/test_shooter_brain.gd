extends GdUnitTestSuite


func _def() -> EnemyDef:
	var d := EnemyDef.new()
	d.behavior = EnemyDef.Behavior.SHOOTER
	d.preferred_range = 130.0
	d.too_close_range = 80.0
	d.telegraph_time = 0.5
	d.recover_time = 0.8
	return d


func test_approaches_until_in_range_then_telegraphs_and_fires_once() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	assert_bool(b.tick(0.1, 200.0, d)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)
	assert_vector(b.wish(Vector2(200, 0), d)).is_equal(Vector2(200, 0))  # toward
	assert_bool(b.tick(0.1, 120.0, d)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	assert_vector(b.wish(Vector2(120, 0), d)).is_equal(Vector2.ZERO)  # stands still to wind up
	assert_bool(b.tick(0.4, 120.0, d)).is_false()
	assert_bool(b.tick(0.11, 120.0, d)).is_true()  # 0.51 s in: fires
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)
	assert_bool(b.tick(0.5, 120.0, d)).is_false()  # no second shot while recovering
	assert_bool(b.tick(0.31, 120.0, d)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)


func test_backs_away_when_too_close() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	assert_vector(b.wish(Vector2(50, 0), d)).is_equal(Vector2(-50, 0))
	b.tick(0.0, 50.0, d)  # 50 <= preferred: telegraphs even when close
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	b.tick(0.6, 50.0, d)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)
	assert_vector(b.wish(Vector2(50, 0), d)).is_equal(Vector2(-50, 0))  # recovering, still backs off
