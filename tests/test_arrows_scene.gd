extends SceneSuite
## The off-screen arrows on the HUD (the M7 design's "Off-screen arrows"): an enemy not on the
## screen (View.on_screen, rule 2's test) has an arrow at the screen's edge on the line from the
## player to it, and one on the screen has none, so an enemy either may attack or has an arrow.
## Never one in tier 1, wherever the camera sits and however it shakes.

const AT := 0.5
## How near its resting centre the view must be to count as at rest, px.
const SETTLED := 0.01
## A body's radius pressed against a wall (chaser.tscn's CircleShape2D), px.
const RADIUS := 5.0


func _arrows(main: Node) -> OffscreenArrows:
	return hud_of(main).arrows


## The arrows read again now (the control does it every frame; the tests ask at a known moment).
func _read(main: Node) -> OffscreenArrows:
	var arrows := _arrows(main)
	arrows.refresh()
	return arrows


func _floor(main: Node) -> Rect2:
	return (main.get("room") as Room).global_bounds()


func _screen() -> Rect2:
	return get_viewport().get_visible_rect()


## The player stood at `at` with no lean, and the view come to rest on it (or on the room's limits).
func _stand(main: Node, at: Vector2) -> void:
	var player := player_of(main)
	player.global_position = at
	player.aim_override = at
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	var full: Rect2 = (main.get("room") as Room).full_rect()
	var half := _screen().size / camera.zoom * 0.5
	var centre := Vector2(clampf(at.x, full.position.x + half.x, full.end.x - half.x),
		clampf(at.y, full.position.y + half.y, full.end.y - half.y))
	await wait_until(func() -> bool: return View.bare_rect(self).get_center().distance_to(centre) < SETTLED,
		"the view at rest on the player")


## A wide arena, the player at the floor's centre and the view at rest there.
func _wide() -> Node:
	var main := quiet_main_with_series(wide_series())
	await _stand(main, _floor(main).get_center())
	return main


func test_an_enemy_off_screen_has_an_arrow_at_the_edge_pointing_at_it() -> void:
	var main := await _wide()
	var centre := _floor(main).get_center()
	var chaser := active_chaser_on(main, centre + Vector2(320, 0))
	assert_bool(View.on_screen(chaser)).is_false()
	var arrows := _read(main)
	assert_int(arrows.arrow_count()).is_equal(1)
	var arrow := arrows.arrow_at(0)
	assert_float((arrow.at as Vector2).x).is_equal_approx(_screen().end.x - OffscreenArrows.ARROW_INSET, AT)
	assert_float((arrow.at as Vector2).y).is_equal_approx(_screen().get_center().y, AT)
	assert_float(arrow.angle).is_equal_approx(0.0, 0.01)
	assert_str(arrow.kind).is_equal("enemy")
	assert_float(arrow.alpha).is_equal_approx(1.0, 0.001)  # far past the edge


func test_the_arrow_is_on_the_line_from_the_player_to_the_enemy() -> void:
	var main := await _wide()
	var centre := _floor(main).get_center()
	var chaser := active_chaser_on(main, centre + Vector2(-300, -200))
	var arrow := _read(main).arrow_at(0)
	var player_on_screen := _screen().get_center()
	var heading := (chaser.global_position - player_of(main).global_position).normalized()
	assert_vector(((arrow.at as Vector2) - player_on_screen).normalized()).is_equal_approx(heading, Vector2.ONE * 0.01)
	assert_float(arrow.angle).is_equal_approx(heading.angle(), 0.01)
	var inner := _screen().grow(-OffscreenArrows.ARROW_INSET)
	var at: Vector2 = arrow.at
	var on_edge := absf(at.x - inner.position.x) < AT or absf(at.y - inner.position.y) < AT
	assert_bool(on_edge).override_failure_message("%s not on %s" % [at, inner]).is_true()


func test_an_enemy_walking_onto_the_screen_loses_its_arrow() -> void:
	var main := await _wide()
	var centre := _floor(main).get_center()
	var chaser := active_chaser_on(main, centre + Vector2(320, 0))
	assert_int(_read(main).arrow_count()).is_equal(1)
	chaser.global_position = centre + Vector2(150, 0)
	assert_bool(View.on_screen(chaser)).is_true()
	assert_int(_read(main).arrow_count()).is_equal(0)


## The arrow fades: none on the line where the enemy counts as on the screen, faint just past it,
## full ARROW_FADE past it, so it never pops.
func test_the_arrow_fades_in_past_the_edge() -> void:
	var main := await _wide()
	var sight := View.bare_rect(main).grow(View.SIGHT_SLACK)
	var y := sight.get_center().y
	var chaser := active_chaser_on(main, Vector2(sight.end.x + OffscreenArrows.ARROW_FADE / 4.0, y))
	var faint: float = _read(main).arrow_at(0).alpha
	assert_float(faint).is_equal_approx(0.25, 0.01)
	chaser.global_position.x = sight.end.x + OffscreenArrows.ARROW_FADE * 2.0
	assert_float(_read(main).arrow_at(0).alpha).is_equal_approx(1.0, 0.001)


func test_a_dead_enemy_s_arrow_goes() -> void:
	var main := await _wide()
	var chaser := active_chaser_on(main, _floor(main).get_center() + Vector2(320, 0))
	assert_int(_read(main).arrow_count()).is_equal(1)
	chaser.health.take_damage(chaser.health.max_hp)
	assert_int(_read(main).arrow_count()).is_equal(0)  # a corpse leaves the group at once
	await wait_for_death_freeze()
	assert_int(_read(main).arrow_count()).is_equal(0)


## A spawn fading in just past the screen (spawns land inside View.rect, up to its margin past the
## screen) has its arrow at once: it exists, though it may not attack yet.
func test_a_spawning_enemy_off_screen_has_an_arrow() -> void:
	var main := await _wide()
	var chaser: Enemy = load(CHASER).instantiate()
	enemies_of(main).add_child(chaser)
	chaser.global_position = _floor(main).get_center() + Vector2(0, 200)
	assert_int(chaser.state).is_equal(Enemy.State.SPAWNING)
	assert_int(_read(main).arrow_count()).is_equal(1)


func test_one_arrow_per_enemy_off_screen_kept_apart() -> void:
	var main := await _wide()
	var centre := _floor(main).get_center()
	active_chaser_on(main, centre + Vector2(320, 0))
	active_chaser_on(main, centre + Vector2(330, 2))
	active_chaser_on(main, centre + Vector2(0, 40))  # on the screen
	var arrows := _read(main)
	assert_int(arrows.arrow_count()).is_equal(2)
	var a: Vector2 = arrows.arrow_at(0).at
	var b: Vector2 = arrows.arrow_at(1).at
	assert_float(a.distance_to(b)).is_greater_equal(OffscreenArrows.ARROW_GAP - AT)


func test_the_boss_s_arrow_is_larger() -> void:
	var main := await _wide()
	var centre := _floor(main).get_center()
	active_boss_on(main, centre + Vector2(-340, 0))
	active_chaser_on(main, centre + Vector2(340, 0))
	var arrows := _read(main)
	var kinds := {}
	for i in arrows.arrow_count():
		kinds[arrows.arrow_at(i).kind] = arrows.arrow_at(i).size
	assert_dict(kinds).contains_keys(["boss", "enemy"])
	assert_float(kinds["boss"]).is_greater(kinds["enemy"])


## With the boss's bar up, an arrow pointing up sits under the bar, not beneath it.
func test_an_arrow_pointing_up_sits_under_the_boss_bar() -> void:
	var main := await _wide()
	var centre := _floor(main).get_center()
	var boss := active_boss_on(main, centre + Vector2(0, -200))
	Events.boss_spawned.emit(boss)
	var hud := hud_of(main)
	assert_bool(hud.boss_bar.visible).is_true()
	var arrow := _read(main).arrow_at(0)
	var bar_bottom := hud.boss_bar.get_global_rect().end.y
	assert_float((arrow.at as Vector2).y).is_equal_approx(bar_bottom + OffscreenArrows.ARROW_INSET, AT)
	assert_float((arrow.at as Vector2).y - arrow.size / 2.0).is_greater(bar_bottom)


func test_the_shake_does_not_move_the_arrows() -> void:
	var main := await _wide()
	var chaser := active_chaser_on(main, _floor(main).get_center() + Vector2(300, -150))
	var still: Vector2 = _read(main).arrow_at(0).at
	var camera: Camera = main.get_node("Player/Camera")
	camera.set_process(false)  # the shake held at its largest
	camera.offset = Vector2(Camera.MAX_SHAKE, -Camera.MAX_SHAKE)
	assert_vector(_read(main).arrow_at(0).at).is_equal_approx(still, Vector2.ONE * 0.001)
	assert_object(chaser).is_not_null()


func test_no_arrow_under_a_pause() -> void:
	var main := await _wide()
	active_chaser_on(main, _floor(main).get_center() + Vector2(320, 0))
	assert_int(_read(main).arrow_count()).is_equal(1)
	get_tree().paused = true
	var arrows := _read(main)
	assert_int(arrows.arrow_count()).is_equal(0)
	assert_bool(arrows.visible).is_false()
	get_tree().paused = false
	assert_int(_read(main).arrow_count()).is_equal(1)
	assert_bool(arrows.visible).is_true()


func test_no_arrow_once_the_run_is_no_longer_live() -> void:
	var main := await _wide()
	active_chaser_on(main, _floor(main).get_center() + Vector2(320, 0))
	Events.run_won.emit()
	assert_int(_read(main).arrow_count()).is_equal(0)
	Events.run_started.emit()
	assert_int(_read(main).arrow_count()).is_equal(1)


func test_the_arrows_are_drawn_over_the_hud_s_parts() -> void:
	var main := quiet_main()
	var hud := hud_of(main)
	var arrows := _arrows(main)
	assert_object(arrows.get_parent()).is_same(hud)
	assert_int(arrows.get_index()).is_equal(hud.get_child_count() - 1)
	assert_int(arrows.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Tier 1: with the camera pushed to either side, shaken toward the far wall, and an enemy pressed
## against every wall and in every corner, every enemy is on the screen and no arrow is drawn.
func test_in_tier_1_no_arrow_is_ever_drawn() -> void:
	var main := quiet_main()
	var bounds := _floor(main)
	var camera: Camera = main.get_node("Player/Camera")
	var spots: Array[Vector2] = []
	for x: float in [bounds.position.x + RADIUS, bounds.get_center().x, bounds.end.x - RADIUS]:
		for y: float in [bounds.position.y + RADIUS, bounds.get_center().y, bounds.end.y - RADIUS]:
			spots.append(Vector2(x, y))
	var enemies: Array[Enemy] = []
	for spot in spots:
		enemies.append(active_chaser_on(main, spot))
	active_boss_on(main, bounds.get_center() + Vector2(0, -60))
	var shake := Camera.MAX_SHAKE
	for side: float in [-1.0, 1.0]:
		camera.set_process(true)
		camera.offset = Vector2.ZERO
		await _stand(main, Vector2(bounds.get_center().x + side * (bounds.size.x / 2.0 - 12.0), bounds.get_center().y))
		camera.set_process(false)
		for offset: Vector2 in [Vector2.ZERO, Vector2(-side * shake, 0), Vector2(side * shake, 0),
				Vector2(0, shake), Vector2(0, -shake), Vector2(-side * shake, shake)]:
			camera.offset = offset
			for enemy in enemies:
				assert_bool(View.on_screen(enemy)).override_failure_message("%s off screen, side %s, shake %s"
					% [enemy.global_position, side, offset]).is_true()
			assert_int(_read(main).arrow_count()).override_failure_message("side %s, shake %s" % [side, offset]).is_equal(0)
