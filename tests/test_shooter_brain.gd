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
	assert_bool(b.tick(0.1, 200.0, d, true)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)
	assert_vector(b.wish(Vector2(200, 0), d, true)).is_equal(Vector2(200, 0))  # toward
	assert_bool(b.tick(0.1, 120.0, d, true)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	assert_vector(b.wish(Vector2(120, 0), d, true)).is_equal(Vector2.ZERO)  # stands still to wind up
	assert_bool(b.tick(0.4, 120.0, d, true)).is_false()
	assert_bool(b.tick(0.11, 120.0, d, true)).is_true()  # 0.51 s in: fires
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)
	assert_bool(b.tick(0.5, 120.0, d, true)).is_false()  # no second shot while recovering
	assert_bool(b.tick(0.31, 120.0, d, true)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)


func test_backs_away_when_too_close() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	assert_vector(b.wish(Vector2(50, 0), d, true)).is_equal(Vector2(-50, 0))
	b.tick(0.0, 50.0, d, true)  # 50 <= preferred: telegraphs even when close
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	b.tick(0.6, 50.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)
	assert_vector(b.wish(Vector2(50, 0), d, true)).is_equal(Vector2(-50, 0))  # recovering, still backs off


func test_interrupt_from_telegraph_returns_to_approach() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	b.tick(0.1, 120.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	b.tick(0.2, 120.0, d, true)
	b.interrupt()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)
	assert_float(b.phase_time).is_equal(0.0)
	b.tick(0.1, 120.0, d, true)  # still in range: a fresh telegraph from zero
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	assert_bool(b.tick(0.4, 120.0, d, true)).is_false()  # the 0.2 s before the interrupt do not count
	assert_bool(b.tick(0.11, 120.0, d, true)).is_true()


func test_recover_extra_lengthens_one_recover() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	b.tick(0.0, 120.0, d, true)
	b.tick(0.6, 120.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)
	b.recover_extra = 0.15
	b.tick(0.85, 120.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)  # 0.8 alone would have ended it
	b.tick(0.11, 120.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)


# --- Rule 2: a wind-up begins only on screen (the M7 design's "The big arena") ---


func test_in_range_but_off_screen_it_never_winds_up_until_visible() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	for i in 50:
		assert_bool(b.tick(0.1, 120.0, d, false)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.APPROACH)
	b.tick(0.1, 120.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)


func test_a_wind_up_begun_finishes_and_fires_off_screen() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	b.tick(0.1, 120.0, d, true)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)
	assert_bool(b.tick(0.4, 400.0, d, false)).is_false()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)  # it does not restart
	assert_bool(b.tick(0.11, 400.0, d, false)).is_true()
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)


## Off screen it closes on the player whatever the range (it never holds its range out of view),
## and stands while a wind-up begun on screen finishes.
func test_off_screen_it_walks_toward_the_player() -> void:
	var b := ShooterBrain.new()
	var d := _def()
	assert_vector(b.wish(Vector2(120, 0), d, false)).is_equal(Vector2(120, 0))  # inside its range
	assert_vector(b.wish(Vector2(120, 0), d, true)).is_equal(Vector2.ZERO)  # on screen it holds
	b.tick(0.1, 120.0, d, true)
	assert_vector(b.wish(Vector2(120, 0), d, false)).is_equal(Vector2.ZERO)  # winding up
	b.tick(0.6, 120.0, d, false)
	assert_int(b.phase).is_equal(ShooterBrain.Phase.RECOVER)
	assert_vector(b.wish(Vector2(120, 0), d, false)).is_equal(Vector2(120, 0))
	assert_vector(b.wish(Vector2(120, 0), d, true)).is_equal(Vector2.ZERO)
