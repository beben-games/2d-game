extends SceneSuite
## The charger in the real main scene: it winds up along a line fixed at the wind-up's start,
## crosses past the player's spot through other bodies, hurts on contact once, stops at a wall or
## at the end of its run, and skids, taking more damage from behind. A stun cuts the wind-up and
## ends a charge. Timings are physics ticks (60 Hz) or waits on the bus.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const HANDGUN := preload("res://data/weapons/handgun.tres")
const OFFSET := Vector2(100, 0)  ## the charger sits right of the player, in range, charging left

var _charged: Array[Vector2] = []  ## enemy_charged: where each charge began
var _skidded: Array[Vector2] = []  ## enemy_skidded: where each charge ended
var _telegraphed := 0
var _hits: Array[float] = []  ## enemy_hit's amounts


func before_test() -> void:
	super()
	_charged = []
	_skidded = []
	_telegraphed = 0
	_hits = []
	Events.enemy_charged.connect(_on_charged)
	Events.enemy_skidded.connect(_on_skidded)
	Events.enemy_telegraphed.connect(_on_telegraphed)
	Events.enemy_hit.connect(_on_hit)


func after_test() -> void:
	Events.enemy_charged.disconnect(_on_charged)
	Events.enemy_skidded.disconnect(_on_skidded)
	Events.enemy_telegraphed.disconnect(_on_telegraphed)
	Events.enemy_hit.disconnect(_on_hit)
	await super()


func _on_charged(enemy: Node2D) -> void:
	_charged.append(enemy.global_position)


func _on_skidded(enemy: Node2D) -> void:
	_skidded.append(enemy.global_position)


func _on_telegraphed(_enemy: Node2D) -> void:
	_telegraphed += 1


func _on_hit(_enemy: Node2D, damage: float, _at: Vector2) -> void:
	_hits.append(damage)


func _brain(charger: Enemy) -> ChargerBrain:
	return charger.brain as ChargerBrain


func _wait_for_phase(charger: Enemy, phase: ChargerBrain.Phase, what: String, frames := 300) -> void:
	await wait_until(func() -> bool: return _brain(charger).phase == phase, what, frames)


func _fire(main: Node, from: Vector2, dir: Vector2) -> Projectile:
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	shot.setup(HANDGUN, dir)
	projectiles_of(main).add_child(shot)
	shot.global_position = from
	return shot


func test_the_line_shows_through_the_wind_up_and_does_not_turn_with_the_player() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	var line := charger.charge_line
	assert_bool(line.visible).is_false()
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	assert_int(_telegraphed).is_equal(1)
	assert_bool(line.visible).is_true()
	assert_vector(line.direction).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))
	assert_float(line.length).is_equal_approx(ChargerBrain.reach(charger.def), 0.5)  # no wall within its reach
	var points_before := line.points
	assert_vector(points_before[0]).is_equal(Vector2.ZERO)  # from the body
	player.global_position += Vector2(0, 60)  # the player steps off the line
	await ticks(20)
	assert_int(_brain(charger).phase).is_equal(ChargerBrain.Phase.WINDUP)
	assert_bool(line.visible).is_true()
	assert_vector(line.direction).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))  # it did not track
	assert_array(line.points).is_equal(points_before)
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	assert_bool(line.visible).is_false()  # the line is the wind-up's
	assert_vector(charger.charge_dir).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))  # along the line


## Its run ends past where the player stood, by the time, not at the player.
func test_the_charge_crosses_past_the_players_spot_and_skids() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)
	assert_int(charger.collision_mask).is_equal(19)
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	await ticks(2)
	assert_int(charger.collision_mask).is_equal(16)  # walls only while charging
	assert_int(charger.collision_layer).is_equal(2)  # the hurtbox and the shots still find it
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	var reach := ChargerBrain.reach(charger.def)
	assert_float(_skidded[0].x).is_less(spot.x - 60.0)  # well past the player's spot
	assert_float(_charged[0].distance_to(_skidded[0])).is_equal_approx(reach, 12.0)  # the full run
	assert_int(charger.collision_mask).is_equal(19)
	var still := charger.global_position
	await ticks(30)  # inside the skid (1 s)
	assert_int(_brain(charger).phase).is_equal(ChargerBrain.Phase.SKID)
	assert_float(charger.global_position.distance_to(still)).is_less(1.0)  # it stands


## A wall ends the run early: near the left wall the charge stops at its face, in the skid.
func test_a_wall_stops_the_charge() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var bounds := (main.get("room") as Room).global_bounds()
	player.global_position = Vector2(bounds.position.x + 60.0, bounds.get_center().y)
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	var line := charger.charge_line
	assert_float(line.length).is_less(ChargerBrain.reach(charger.def))  # the line stops at the wall
	assert_float(line.length).is_equal_approx(charger.global_position.x - bounds.position.x, 8.0)
	Juice.reset()
	var trauma: Array[float] = []
	var on_skid := func(_enemy: Node2D) -> void: trauma.append(Juice.trauma)
	Events.enemy_skidded.connect(on_skid)
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	Events.enemy_skidded.disconnect(on_skid)
	assert_float(trauma[0]).is_equal_approx(Enemy.CHARGE_WALL_TRAUMA, 0.001)  # the wall's shake, on screen
	assert_float(_skidded[0].x).is_less(bounds.position.x + 10.0)  # at the wall's face
	assert_float(_charged[0].distance_to(_skidded[0])).is_less(ChargerBrain.reach(charger.def) - 40.0)


## A shove during the wind-up moves the line with the body; it is re-clipped at the wall's face.
func test_a_shove_toward_the_wall_mid_wind_up_reclips_the_line() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var bounds := (main.get("room") as Room).global_bounds()
	player.global_position = Vector2(bounds.position.x + 60.0, bounds.get_center().y)
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	charger.global_position += Vector2(-40, 0)
	await ticks(2)
	assert_float(charger.charge_line.length).is_equal_approx(charger.global_position.x - bounds.position.x, 2.0)


## Off screen a wall stops the run without a shake.
func test_a_wall_off_screen_stops_the_run_without_a_shake() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := (main.get("room") as Room).global_bounds()
	var player := player_of(main)
	player.invuln_left = 100.0
	var camera: Camera = main.get_node("Player/Camera")
	player.global_position = Vector2(bounds.position.x + 60.0, bounds.get_center().y)
	camera.reset_smoothing()
	await ticks(2)
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	player.global_position = Vector2(bounds.end.x - 60.0, bounds.get_center().y)  # the view leaves it
	camera.reset_smoothing()
	await ticks(2)
	Juice.reset()
	var trauma: Array = []  # [Juice.trauma, on screen] at the skid
	var on_skid := func(enemy: Node2D) -> void: trauma.append([Juice.trauma, View.on_screen(enemy)])
	Events.enemy_skidded.connect(on_skid)
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	Events.enemy_skidded.disconnect(on_skid)
	assert_bool(trauma[0][1]).is_false()
	assert_float(trauma[0][0]).is_equal(0.0)
	assert_float(_skidded[0].x).is_less(bounds.position.x + 10.0)  # the wall stopped it


## A run ending inside a chaser leaves both where they stand: the pass-through holds until they
## part, then ends.
func test_a_run_ending_inside_a_chaser_does_not_shove_it() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)
	var chaser := active_chaser_on(main, spot + OFFSET + Vector2.LEFT * (ChargerBrain.reach(charger.def) - 2.0))
	var chaser_at := chaser.global_position
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	assert_float(charger.global_position.distance_to(chaser.global_position)).is_less(10.0)  # overlapping
	var charger_at := charger.global_position
	await ticks(30)
	assert_float(chaser.global_position.distance_to(chaser_at)).is_less(0.5)
	assert_float(charger.global_position.distance_to(charger_at)).is_less(0.5)
	assert_bool(charger.get_collision_exceptions().has(chaser)).is_true()
	chaser.global_position += Vector2(0, 30)  # they part
	await ticks(2)
	assert_bool(charger.get_collision_exceptions().has(chaser)).is_false()


## It passes through a chaser in its lane without moving or hurting it.
func test_it_passes_through_a_chaser_in_its_path() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)
	var chaser := active_chaser_on(main, spot + OFFSET / 2.0)  # on the lane, between them
	var chaser_at := chaser.global_position
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	assert_float(_skidded[0].x).is_less(spot.x - 60.0)  # through it, and past the player
	assert_float(chaser.global_position.distance_to(chaser_at)).is_less(2.0)  # neither carried nor shoved
	assert_float(chaser.health.hp).is_equal(chaser.def.max_hp)


## The player's body does not stop it or ride on it; contact hurts once (the i-frames).
func test_contact_hurts_once_and_the_player_is_not_carried() -> void:
	var main := quiet_main()
	var player := player_of(main)
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	assert_int(player.hp).is_equal(Player.MAX_HP - charger.def.contact_damage)
	# The hit's own knockback moves it (v^2 / 2a: about 22 px), never the run (128 px past it).
	var shove := Player.HIT_KNOCKBACK * Player.HIT_KNOCKBACK / (2.0 * Player.KNOCKBACK_DECAY)
	assert_float(player.global_position.distance_to(spot)).is_less_equal(shove + 2.0)
	assert_float(_skidded[0].x).is_less(spot.x - 60.0)


## The acts Favour scores for a dash from where the player stands along `direction`, emitted on
## the bus as the player's dash is (the favour suite's way).
func _dash_acts(player: Player, direction: Vector2) -> Array[String]:
	var acts: Array[String] = []
	var on_changed := func(_value: float, _band: int, act: String) -> void: acts.append(act)
	Events.favour_changed.connect(on_changed)
	Events.player_dashed.emit(player.global_position, direction)
	Events.favour_changed.disconnect(on_changed)
	return acts


## A dash across the lane while the charging body is on it is a dare.
func test_a_dash_across_the_charging_body_scores_a_dare() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)  # charging at the player, along x
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	await wait_until(func() -> bool: return charger.global_position.x <= spot.x + 24.0, "the body about to reach the player", 60)
	assert_bool(charger.is_harmful()).is_true()
	assert_array(_dash_acts(player, Vector2.DOWN)).contains(["dare"])  # 49.5 px down, across the lane


## The sidestep: a dash out of the lane begun while the running body is still beyond
## DANGER_RADIUS, bearing down, is a dare: Favour sweeps a charging body along its velocity as it
## does a bolt (the closest approach over the dash), not where it stands at the dash's start.
func test_a_sidestep_out_of_the_lane_before_the_body_arrives_scores_a_dare() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	await wait_until(func() -> bool: return charger.global_position.x <= spot.x + 46.0, "the body bearing down", 60)
	assert_float(charger.global_position.x).is_greater(spot.x + FavourRules.DANGER_RADIUS + 4.0)  # out of the static reach
	assert_vector(charger.dare_velocity()).is_equal(charger.move_vel)
	assert_float(charger.dare_velocity().length()).is_equal_approx(charger.def.charge_speed, 0.01)
	assert_array(_dash_acts(player, Vector2.DOWN)).contains(["dare"])


## A dash well clear of the lane, away from it, is no dare, run or not.
func test_a_dash_well_clear_of_the_lane_scores_no_dare() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var spot := player.global_position
	var charger := active_charger_on(main, spot + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	player.global_position = spot + Vector2(0, -80)  # off the fixed lane
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	await wait_until(func() -> bool: return charger.global_position.x <= spot.x + 40.0, "the body passing", 60)
	assert_array(_dash_acts(player, Vector2.UP)).not_contains(["dare"])


## After the run the body stands: no velocity to sweep, so only the static reach counts.
func test_after_the_run_a_dash_past_the_standing_body_is_swept_no_more() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	assert_vector(charger.dare_velocity()).is_equal(Vector2.ZERO)
	player.global_position = charger.global_position + Vector2(44, 0)  # as far as the swept case's start
	assert_array(_dash_acts(player, Vector2.DOWN)).not_contains(["dare"])


## A shot's knockback mid-run does not bend the run off its line.
func test_knockback_does_not_bend_the_run() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	charger.health.setup(100.0)
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	await ticks(5)
	charger.health.take_damage(1.0, Vector2(0, -400))  # the knockback a shot across the lane carries
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	var off_line := absf(charger.charge_dir.cross(_skidded[0] - _charged[0]))
	assert_float(off_line).is_less(1.0)


## In the skid its back is open: a shot arriving from behind does back_damage_scale times the
## damage, one into its front the plain damage.
func test_a_shot_from_behind_in_the_skid_does_the_scaled_damage() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	charger.def.max_hp = 100.0
	charger.health.setup(100.0)
	charger.def.skid_time = 5.0
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	assert_float(charger.damage_scale(Vector2.LEFT)).is_equal(charger.def.back_damage_scale)  # along its charge: its back
	assert_float(charger.damage_scale(Vector2.RIGHT)).is_equal(1.0)
	_fire(main, charger.global_position + Vector2(60, 0), Vector2.LEFT)  # from behind
	await wait_until(func() -> bool: return _hits.size() == 1, "the shot from behind")
	_fire(main, charger.global_position + Vector2(-60, 0), Vector2.RIGHT)  # into its face
	await wait_until(func() -> bool: return _hits.size() == 2, "the shot from the front")
	assert_array(_hits).is_equal([HANDGUN.damage * charger.def.back_damage_scale, HANDGUN.damage])


## Outside the skid the back is no weaker.
func test_outside_the_skid_every_shot_does_the_plain_damage() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	assert_float(charger.damage_scale(Vector2.LEFT)).is_equal(1.0)
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	assert_float(charger.damage_scale(Vector2.LEFT)).is_equal(1.0)


func test_a_stun_mid_wind_up_cancels_the_charge() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	await ticks(10)
	charger.status.apply_stun()
	await ticks(1)
	assert_int(_brain(charger).phase).is_equal(ChargerBrain.Phase.APPROACH)
	assert_bool(charger.charge_line.visible).is_false()
	assert_vector(charger.sprite.offset).is_equal(charger.def.sprite_offset)  # the shiver stops
	assert_float(charger.flash_material.get_shader_parameter("flash")).is_equal(0.0)
	# The stun's 0.6 s, then a fresh wind-up of 0.7 s: no charge for 1.3 s after the cut.
	await ticks(ceili((StatusEffects.STUN_TIME + charger.def.windup_time) * Engine.physics_ticks_per_second) - 4)
	assert_array(_charged).is_empty()
	assert_int(_telegraphed).is_equal(2)  # a second wind-up, from zero
	await wait_until(func() -> bool: return _charged.size() == 1, "the fresh charge", 30)


func test_a_stun_mid_charge_ends_it_in_the_skid() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await wait_until(func() -> bool: return _charged.size() == 1, "the charge")
	await ticks(5)
	charger.status.apply_stun()
	await ticks(1)
	assert_int(_skidded.size()).is_equal(1)
	assert_int(_brain(charger).phase).is_equal(ChargerBrain.Phase.SKID)
	assert_int(charger.collision_mask).is_equal(19)
	assert_float(_charged[0].distance_to(_skidded[0])).is_less(ChargerBrain.reach(charger.def) / 2.0)


## Rule 2: off screen it walks at the player and winds up only once on the screen.
func test_off_screen_it_walks_in_and_only_then_winds_up() -> void:
	var main := quiet_main_with_series(wide_series())
	var room: Room = main.get("room")
	var centre := room.global_bounds().get_center()
	var player := player_of(main)
	player.global_position = centre
	player.invuln_left = 100.0
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	await ticks(2)
	var start := centre + Vector2(View.rect(main).size.x / 2.0 + 40.0, 0)
	var charger := active_charger_on(main, start, false)
	charger.def.charge_range = 10000.0  # in range from anywhere: only the screen holds it off
	assert_bool(View.on_screen(charger)).is_false()
	var at: Array[Vector2] = []
	var on_telegraphed := func(enemy: Node2D) -> void:
		if at.is_empty():
			at.append(enemy.global_position)
			at.append(Vector2(float(View.on_screen(enemy)), 0))
	Events.enemy_telegraphed.connect(on_telegraphed)
	await wait_until(func() -> bool: return at.size() > 0, "the wind-up")
	Events.enemy_telegraphed.disconnect(on_telegraphed)
	assert_float(at[0].x).is_less(start.x)  # it walked toward the player
	assert_float(at[1].x).is_equal(1.0)  # on the screen when it began


func test_the_sounds_of_the_wind_up_the_charge_and_the_skid() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await wait_until(func() -> bool: return _skidded.size() == 1, "the skid")
	assert_int(plays("charge_windup")).is_equal(1)
	assert_int(plays("telegraph")).is_equal(0)  # the shooter's
	assert_int(plays("charge")).is_equal(1)
	assert_int(plays("charge_skid")).is_equal(1)
	charger.health.take_damage(1000.0)
	assert_int(plays("die_imp")).is_equal(1)
	await wait_for_death_freeze()


## A corpse shows no line: killed mid-wind-up, the line goes with the pulses.
func test_killed_mid_wind_up_the_line_goes() -> void:
	var main := quiet_main()
	var player := player_of(main)
	player.invuln_left = 100.0
	var charger := active_charger_on(main, player.global_position + OFFSET)
	await _wait_for_phase(charger, ChargerBrain.Phase.WINDUP, "the wind-up")
	charger.health.take_damage(1000.0)
	assert_bool(charger.charge_line.visible).is_false()
	assert_vector(charger.sprite.offset).is_equal(charger.def.sprite_offset)
	await wait_for_death_freeze()
	assert_bool(is_instance_valid(charger)).is_false()
