extends GdUnitTestSuite
## The charger's cycle (ChargerBrain, pure): approach, wind up along a fixed line, charge, skid,
## approach again. Rule 2: no wind-up off screen; one begun finishes there.


func _def() -> EnemyDef:
	var d := EnemyDef.new()
	d.behavior = EnemyDef.Behavior.CHARGER
	d.charge_range = 160.0
	d.windup_time = 0.7
	d.charge_speed = 380.0
	d.charge_time = 0.6
	d.skid_time = 1.0
	return d


func test_the_phases_run_in_order_on_their_times() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	assert_str(b.tick(0.1, 200.0, d, true)).is_equal("")  # out of range: approaching
	assert_int(b.phase).is_equal(ChargerBrain.Phase.APPROACH)
	assert_str(b.tick(0.1, 150.0, d, true)).is_equal(ChargerBrain.WINDUP)
	assert_int(b.phase).is_equal(ChargerBrain.Phase.WINDUP)
	assert_str(b.tick(0.6, 150.0, d, true)).is_equal("")
	assert_str(b.tick(0.11, 150.0, d, true)).is_equal(ChargerBrain.CHARGE)  # 0.71 s in
	assert_int(b.phase).is_equal(ChargerBrain.Phase.CHARGE)
	assert_bool(b.charging()).is_true()
	assert_str(b.tick(0.5, 10.0, d, true)).is_equal("")
	assert_str(b.tick(0.11, 10.0, d, true)).is_equal(ChargerBrain.SKID)  # 0.61 s of charge
	assert_int(b.phase).is_equal(ChargerBrain.Phase.SKID)
	assert_bool(b.charging()).is_false()
	assert_str(b.tick(0.9, 10.0, d, true)).is_equal("")
	assert_str(b.tick(0.11, 10.0, d, true)).is_equal(ChargerBrain.DONE)
	assert_int(b.phase).is_equal(ChargerBrain.Phase.APPROACH)


func test_the_range_is_inclusive_and_out_of_range_it_never_winds_up() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	for i in 30:
		assert_str(b.tick(0.1, 160.1, d, true)).is_equal("")
	assert_int(b.phase).is_equal(ChargerBrain.Phase.APPROACH)
	assert_str(b.tick(0.1, 160.0, d, true)).is_equal(ChargerBrain.WINDUP)


func test_off_screen_it_never_winds_up_until_visible() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	for i in 50:
		assert_str(b.tick(0.1, 100.0, d, false)).is_equal("")
	assert_int(b.phase).is_equal(ChargerBrain.Phase.APPROACH)
	assert_str(b.tick(0.1, 100.0, d, true)).is_equal(ChargerBrain.WINDUP)


func test_a_wind_up_begun_runs_its_charge_and_skid_off_screen() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	b.tick(0.0, 100.0, d, true)
	assert_str(b.tick(0.71, 500.0, d, false)).is_equal(ChargerBrain.CHARGE)
	assert_str(b.tick(0.61, 500.0, d, false)).is_equal(ChargerBrain.SKID)
	assert_str(b.tick(1.01, 500.0, d, false)).is_equal(ChargerBrain.DONE)


## It walks at the player while approaching, on screen or off (rule 2's off-screen walk), and
## stands through the wind-up and the skid; the charge's motion is the enemy's (charge_dir).
func test_the_wish_walks_at_the_player_only_while_approaching() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	assert_vector(b.wish(Vector2(300, 0))).is_equal(Vector2(300, 0))
	assert_vector(b.wish(Vector2(30, 0))).is_equal(Vector2(30, 0))  # in range, not yet winding up
	b.tick(0.0, 100.0, d, true)
	assert_vector(b.wish(Vector2(100, 0))).is_equal(Vector2.ZERO)  # winding up
	b.tick(0.71, 100.0, d, true)
	assert_vector(b.wish(Vector2(100, 0))).is_equal(Vector2.ZERO)  # charging: not a wish
	b.tick(0.61, 100.0, d, true)
	assert_vector(b.wish(Vector2(100, 0))).is_equal(Vector2.ZERO)  # skidding


func test_interrupt_cancels_a_wind_up_and_ends_a_charge_into_the_skid() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	assert_str(b.interrupt()).is_equal("")  # approaching: nothing to cut
	assert_int(b.phase).is_equal(ChargerBrain.Phase.APPROACH)
	b.tick(0.0, 100.0, d, true)
	b.tick(0.5, 100.0, d, true)
	assert_str(b.interrupt()).is_equal("")
	assert_int(b.phase).is_equal(ChargerBrain.Phase.APPROACH)
	assert_float(b.phase_time).is_equal(0.0)
	assert_str(b.tick(0.0, 100.0, d, true)).is_equal(ChargerBrain.WINDUP)  # a fresh wind-up from zero
	assert_str(b.tick(0.6, 100.0, d, true)).is_equal("")  # the 0.5 s before the cut do not count
	assert_str(b.tick(0.11, 100.0, d, true)).is_equal(ChargerBrain.CHARGE)
	assert_str(b.interrupt()).is_equal(ChargerBrain.SKID)
	assert_int(b.phase).is_equal(ChargerBrain.Phase.SKID)
	assert_float(b.phase_time).is_equal(0.0)
	assert_str(b.interrupt()).is_equal("")  # skidding: nothing to cut
	assert_int(b.phase).is_equal(ChargerBrain.Phase.SKID)


## A wall ends the charge into the skid at once; anywhere else it does nothing.
func test_a_wall_ends_the_charge() -> void:
	var b := ChargerBrain.new()
	var d := _def()
	assert_str(b.end_charge()).is_equal("")
	b.tick(0.0, 100.0, d, true)
	assert_str(b.end_charge()).is_equal("")
	assert_int(b.phase).is_equal(ChargerBrain.Phase.WINDUP)
	b.tick(0.71, 100.0, d, true)
	b.tick(0.1, 100.0, d, true)
	assert_str(b.end_charge()).is_equal(ChargerBrain.SKID)
	assert_int(b.phase).is_equal(ChargerBrain.Phase.SKID)
	assert_float(b.phase_time).is_equal(0.0)
	assert_str(b.tick(1.01, 100.0, d, true)).is_equal(ChargerBrain.DONE)  # the skid's full time


## The back: a shot travelling along the facing (fired from behind) lands inside the back arc; one
## travelling against it (from the front) does not; the arc's edge is inclusive.
func test_the_back_arc() -> void:
	var facing := Vector2.RIGHT
	assert_bool(ChargerBrain.from_behind(facing, Vector2.RIGHT, 120.0)).is_true()
	assert_bool(ChargerBrain.from_behind(facing, Vector2.LEFT, 120.0)).is_false()
	assert_bool(ChargerBrain.from_behind(facing, Vector2.UP, 120.0)).is_false()  # side on
	assert_bool(ChargerBrain.from_behind(facing, Vector2.from_angle(deg_to_rad(59.0)), 120.0)).is_true()
	assert_bool(ChargerBrain.from_behind(facing, Vector2.from_angle(deg_to_rad(61.0)), 120.0)).is_false()
	assert_bool(ChargerBrain.from_behind(facing, Vector2.UP, 180.0)).is_true()  # the half plane, edge in
	assert_bool(ChargerBrain.from_behind(Vector2.ZERO, Vector2.RIGHT, 120.0)).is_false()
	assert_bool(ChargerBrain.from_behind(facing, Vector2.ZERO, 120.0)).is_false()


## The line's length is the charge's reach: speed times time.
func test_the_reach() -> void:
	assert_float(ChargerBrain.reach(_def())).is_equal_approx(228.0, 0.001)
