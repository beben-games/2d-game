extends SceneSuite
## The standard-bearer in the real main scene: its banner hastens the enemies inside its radius
## (their walk and their wind-ups), with a tint on each, from off screen too; the haste does not
## stack, ends the tick the bearer dies or a body leaves the ring, and never reaches the boss or a
## summon. The bearer stands behind its pack, walks at the player as the last one alive, and never
## hurts. Timings are physics ticks (60 Hz) or waits on the bus.

const TINT_EPS := 0.001


func _floor(main: Node) -> Rect2:
	return (main.get("room") as Room).global_bounds()


## The player at `at` with no lean and out of harm's way, the camera on it at once.
func _place_player(main: Node, at: Vector2, invulnerable := true) -> Player:
	var player := player_of(main)
	player.global_position = at
	player.aim_override = at
	if invulnerable:
		player.invuln_left = 100.0
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	await ticks(2)
	return player


func _assert_tint(enemy: Node2D, tint: Color) -> void:
	var m: Color = (enemy.get_node("Sprite") as CanvasItem).modulate
	assert_float(m.r).is_equal_approx(tint.r, TINT_EPS)
	assert_float(m.g).is_equal_approx(tint.g, TINT_EPS)
	assert_float(m.b).is_equal_approx(tint.b, TINT_EPS)


## The chaser's walking speed once at its top, measured over a few ticks of its own motion.
func _top_speed(chaser: Enemy) -> float:
	await ticks(20)  # past its acceleration (0.21 s at the hastened top)
	return chaser.move_vel.length()


func test_a_chaser_inside_the_radius_moves_faster_and_outside_at_its_speed() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, -40))
	var chaser := active_chaser_on(main, centre + Vector2(170, 0), false)
	var inside := await _top_speed(chaser)
	assert_float(chaser.haste).is_equal(bearer.def.banner_haste)
	assert_float(inside).is_equal_approx(chaser.def.speed * bearer.def.banner_haste, 0.5)
	var from := chaser.global_position
	await ticks(6)
	assert_float(from.distance_to(chaser.global_position)).is_equal_approx(chaser.def.speed * bearer.def.banner_haste * 0.1, 1.0)
	var far := active_chaser_on(main, centre + Vector2(-170, 0), false)
	var outside := await _top_speed(far)
	assert_float(far.haste).is_equal(1.0)
	assert_float(outside).is_equal_approx(far.def.speed, 0.5)


func test_a_shooter_inside_winds_up_in_its_telegraph_time_over_the_haste() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 30))
	var shooter := active_shooter_on(main, centre + Vector2(100, 0))
	var frames: Array[int] = []
	var on_telegraphed := func(enemy: Node2D) -> void:
		if enemy == shooter and frames.is_empty():
			frames.append(Engine.get_physics_frames())
	var on_fired := func(enemy: Node2D, _at: Vector2) -> void:
		if enemy == shooter and frames.size() == 1:
			frames.append(Engine.get_physics_frames())
	Events.enemy_telegraphed.connect(on_telegraphed)
	Events.enemy_fired.connect(on_fired)
	await wait_until(func() -> bool: return frames.size() == 2, "the hastened bolt")
	Events.enemy_telegraphed.disconnect(on_telegraphed)
	Events.enemy_fired.disconnect(on_fired)
	assert_float(shooter.haste).is_equal(bearer.def.banner_haste)
	var expected: float = shooter.def.telegraph_time / bearer.def.banner_haste * Engine.physics_ticks_per_second
	assert_int(frames[1] - frames[0]).is_between(int(floor(expected)), int(ceil(expected)) + 1)
	assert_int(frames[1] - frames[0]).is_less(int(shooter.def.telegraph_time * Engine.physics_ticks_per_second))


func test_the_covered_carry_the_tint_and_it_survives_a_status_tint_ending() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	var chaser := active_chaser_on(main, centre + Vector2(100, 40))
	await ticks(2)
	_assert_tint(chaser, StatusEffects.HASTE_TINT)
	_assert_tint(bearer, Color.WHITE)  # the bearer carries no tint of its own banner
	chaser.status.apply_stun()
	_assert_tint(chaser, StatusEffects.STUN_TINT)
	await wait_until(func() -> bool: return not chaser.status.stunned(), "the stun's end")
	await ticks(1)
	_assert_tint(chaser, StatusEffects.HASTE_TINT)


func test_a_body_leaving_the_ring_loses_the_haste_and_the_tint() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	var chaser := active_chaser_on(main, centre + Vector2(100, 40))
	await ticks(2)
	assert_float(chaser.haste).is_equal(bearer.def.banner_haste)
	chaser.global_position = bearer.global_position + Vector2(-bearer.def.banner_radius - 20.0, 0)
	await ticks(2)
	assert_float(chaser.haste).is_equal(1.0)
	_assert_tint(chaser, Color.WHITE)


## The banner reaches from off screen (the user's decision): the cover never asks the view.
func test_the_buff_holds_with_the_bearer_off_screen() -> void:
	var main := quiet_main_with_series(wide_series())
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(View.rect(main).size.x / 2.0 + 40.0, 0))
	var chaser := active_chaser_on(main, centre + Vector2(150, 0))
	await ticks(2)
	assert_bool(View.on_screen(bearer)).is_false()
	assert_bool(View.on_screen(chaser)).is_true()
	assert_float(chaser.haste).is_equal(bearer.def.banner_haste)
	_assert_tint(chaser, StatusEffects.HASTE_TINT)


## From Task 4's review: the bearer's own arrow is the banner's.
func test_an_off_screen_bearer_s_arrow_is_the_banner_s() -> void:
	var main := quiet_main_with_series(wide_series())
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(View.rect(main).size.x / 2.0 + 80.0, 0))
	assert_str(bearer.arrow_kind()).is_equal("banner")
	assert_bool(View.on_screen(bearer)).is_false()
	var arrows := hud_of(main).arrows
	arrows.refresh()
	assert_int(arrows.arrow_count()).is_equal(1)
	assert_str(arrows.arrow_at(0).kind).is_equal("banner")


func test_the_bearer_s_death_clears_the_buff_the_same_tick() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	var chaser := active_chaser_on(main, centre + Vector2(100, 40))
	await ticks(2)
	assert_float(chaser.haste).is_equal(bearer.def.banner_haste)
	bearer.health.take_damage(100.0)
	assert_float(chaser.haste).is_equal(1.0)  # no tick between the death and this read
	_assert_tint(chaser, Color.WHITE)
	assert_bool(bearer.banner_ring.visible).is_false()


func test_two_banners_do_not_stack() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var first := active_bearer_on(main, centre + Vector2(130, -40))
	var second := active_bearer_on(main, centre + Vector2(130, 40))
	var chaser := active_chaser_on(main, centre + Vector2(170, 0), false)
	var speed := await _top_speed(chaser)
	assert_float(chaser.haste).is_equal(first.def.banner_haste)
	assert_float(speed).is_equal_approx(chaser.def.speed * first.def.banner_haste, 0.5)
	first.health.take_damage(100.0)
	assert_float(chaser.haste).is_equal(second.def.banner_haste)  # the other still covers it
	second.health.take_damage(100.0)
	assert_float(chaser.haste).is_equal(1.0)


func test_the_boss_and_a_summon_are_never_hastened() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	var boss := active_boss_on(main, centre + Vector2(110, -50))
	var summon := active_chaser_on(main, centre + Vector2(100, 40))
	summon.add_to_group("summoned")
	await ticks(2)
	assert_float(summon.haste).is_equal(1.0)
	assert_float(bearer.global_position.distance_to(boss.global_position)).is_less(bearer.def.banner_radius)
	assert_bool(boss.get_node("Status").get("hasted")).is_false()


## The stand: the nearest of the pack between the bearer and the player.
func test_it_stands_behind_its_pack() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var chaser := active_chaser_on(main, centre + Vector2(100, 0))
	var bearer := active_bearer_on(main, centre + Vector2(60, 70), false)
	var spot := centre + Vector2(100 + BearerRules.KEEP, 0)
	await wait_until(func() -> bool: return bearer.global_position.distance_to(spot) < BearerRules.ARRIVE + 1.0,
		"the bearer at its stand", 240)
	await ticks(30)
	assert_float(bearer.global_position.distance_to(spot)).is_less(BearerRules.ARRIVE + 1.0)
	assert_float(chaser.haste).is_equal(bearer.def.banner_haste)


## As the last enemy alive it walks at the player, so the round never stalls; its death clears it.
func test_the_last_bearer_alive_closes_on_the_player_and_the_round_clears_on_its_death() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var runner: WaveRunner = main.get_node("Room/WaveRunner")
	var cleared := [0]
	var spawned: Array[Enemy] = []
	var on_cleared := func() -> void: cleared[0] += 1
	var on_spawned := func(enemy: Node2D) -> void: spawned.append(enemy)
	Events.round_cleared.connect(on_cleared)
	Events.enemy_spawned.connect(on_spawned)
	runner.start(_one_wave_of(load(BEARER)))
	runner.enabled = true
	await wait_until(func() -> bool: return spawned.size() == 1, "the bearer's spawn")
	Events.enemy_spawned.disconnect(on_spawned)
	var bearer := spawned[0]
	await wait_until(func() -> bool: return bearer.state == Enemy.State.ACTIVE, "the bearer active")
	var player := player_of(main)
	var start := bearer.global_position.distance_to(player.global_position)
	await ticks(30)
	var later := bearer.global_position.distance_to(player.global_position)
	assert_float(later).is_less(start - 20.0)
	bearer.health.take_damage(100.0)
	await wait_for_death_freeze()
	Events.round_cleared.disconnect(on_cleared)
	assert_int(cleared[0]).is_equal(1)


func test_walking_into_it_never_hurts() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	var player := await _place_player(main, centre, false)
	var hits := [0]
	var on_hit := func(_d: int, _hp: int, _max: int, _id: String) -> void: hits[0] += 1
	Events.player_hit.connect(on_hit)
	var bearer := active_bearer_on(main, centre + Vector2(6, 0))
	await ticks(30)
	Events.player_hit.disconnect(on_hit)
	assert_bool(bearer.is_harmful()).is_false()
	assert_int(hits[0]).is_equal(0)
	assert_int(player.hp).is_equal(player.max_hp)


func test_its_banner_sounds_as_it_arrives_and_it_dies_as_an_orc() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer: Enemy = main.room.spawner.spawn(load(BEARER))
	assert_int(plays("banner")).is_equal(1)
	bearer.health.take_damage(100.0)
	assert_int(plays("die_shaman")).is_equal(1)


## The skid is the charger's counterplay: under a banner it still stands for its full skid_time
## (the wind-up and the run keep the hasted clock).
func test_a_covered_charger_s_skid_lasts_its_skid_time() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(150, -60))
	bearer.def.banner_radius = 1000.0  # it covers the charger wherever its run ends
	var charger := active_charger_on(main, centre + Vector2(100, 0))
	var skid_at := [-1]
	var on_skidded := func(_enemy: Node2D) -> void: skid_at[0] = Engine.get_physics_frames()
	Events.enemy_skidded.connect(on_skidded)
	await wait_until(func() -> bool: return skid_at[0] >= 0, "the skid")
	Events.enemy_skidded.disconnect(on_skidded)
	assert_float(charger.haste).is_equal(bearer.def.banner_haste)
	var brain := charger.brain as ChargerBrain
	await wait_until(func() -> bool: return brain.phase != ChargerBrain.Phase.SKID, "the skid's end")
	var frames: int = Engine.get_physics_frames() - skid_at[0]
	var plain: float = charger.def.skid_time * Engine.physics_ticks_per_second
	assert_int(frames).is_between(int(plain) - 1, int(plain) + 1)


## A hasted shield turns as fast as the body is hastened: it does not open its back more easily.
func test_a_covered_shield_turns_with_the_haste() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	var shield := _active_enemy_on(main, "res://scenes/enemies/chaser_shield.tscn", centre + Vector2(100, 40), true)
	await ticks(2)
	assert_float(shield.haste).is_equal(bearer.def.banner_haste)
	var to_player := (centre - shield.global_position).normalized()
	shield.facing = -to_player  # its back to the player
	var n := 30
	await ticks(n)
	var turned := rad_to_deg(absf((-to_player).angle_to(shield.facing)))
	var expected: float = shield.def.shield_turn_degrees * bearer.def.banner_haste * n / Engine.physics_ticks_per_second
	assert_float(turned).is_equal_approx(expected, 1.0)


## The ring lies in the room's own container under the bodies: Room/Enemies holds only enemies.
func test_the_ring_lies_in_its_own_container_under_the_bodies() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	active_chaser_on(main, centre + Vector2(100, 40))
	await ticks(2)
	for child in enemies_of(main).get_children():
		assert_bool(child.is_in_group("enemies")).override_failure_message("%s under Room/Enemies" % child.name).is_true()
	var rings: Node = main.get_node("Room/Rings")
	assert_object(bearer.banner_ring.get_parent()).is_same(rings)
	assert_int(rings.get_index()).is_less(enemies_of(main).get_index())
	assert_vector(bearer.banner_ring.global_position).is_equal(bearer.global_position)


## The cloth is keyed off the tileset once a process, not once a bearer.
func test_two_bearers_share_the_cloth_texture() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var a := active_bearer_on(main, centre + Vector2(130, 0))
	var b := active_bearer_on(main, centre + Vector2(-130, 0))
	var cloth_a: Texture2D = (a.banner.get_node("Cloth") as Sprite2D).texture
	assert_object(cloth_a).is_not_null()
	assert_object((b.banner.get_node("Cloth") as Sprite2D).texture).is_same(cloth_a)


## A corpse is left as it died: the banner lowered over it does not re-tint it.
func test_a_corpse_is_not_uncovered() -> void:
	var main := quiet_main()
	var centre := _floor(main).get_center()
	await _place_player(main, centre)
	var bearer := active_bearer_on(main, centre + Vector2(130, 0))
	var chaser := active_chaser_on(main, centre + Vector2(100, 40))
	await ticks(2)
	chaser.health.take_damage(100.0)
	bearer.health.take_damage(100.0)
	assert_bool(chaser.status.hasted).is_true()
	assert_float(chaser.haste).is_equal(bearer.def.banner_haste)


## The stand stays on the floor: a pack near a wall does not send the bearer into it.
func test_its_stand_stays_on_the_floor() -> void:
	var main := quiet_main()
	var floor_rect := _floor(main)
	var centre := floor_rect.get_center()
	# Unclamped, the stand would be KEEP past the chaser: 32 px into the right wall.
	await _place_player(main, Vector2(floor_rect.end.x - 120.0, centre.y))
	active_chaser_on(main, Vector2(floor_rect.end.x - 40.0, centre.y))
	var bearer := active_bearer_on(main, Vector2(floor_rect.end.x - 60.0, centre.y - 80.0), false)
	await ticks(120)
	assert_float(bearer.global_position.x).is_less_equal(floor_rect.end.x - BearerRules.EDGE + BearerRules.ARRIVE + 1.0)
	assert_float(bearer.global_position.distance_to(Vector2(floor_rect.end.x - BearerRules.EDGE, centre.y))).is_less(BearerRules.ARRIVE + 2.0)
