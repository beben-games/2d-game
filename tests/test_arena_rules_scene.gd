extends SceneSuite
## The arena's three fairness rules, in the real main scene (the design's "The big arena"):
## 1. the edge of the view is a wall for shots; 2. enemies begin an attack only on screen;
## 3. nothing to be cornered by. "On screen" is View.rect: the visible world rect, unshaken,
## grown by View.MARGIN, held through the verdict's drift.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const ENEMY_BOLT := preload("res://scenes/enemies/enemy_bolt.tscn")
const HANDGUN := preload("res://data/weapons/handgun.tres")
const SHAMAN_BOLT := preload("res://data/weapons/shaman_bolt.tres")
## How close a shot's end must sit to the edge or wall face it ended on, px.
const AT := 0.01
## How near its resting centre the view must be to count as at rest, px.
const SETTLED := 0.01
## A shot's crawl in the margin's cases, px/s: half a pixel a step, so some step always ends
## between an edge and a wall face a pixel apart (a full-speed step could reach both at once,
## where the wall wins, and hide an edge inside the wall's face).
const CREEP := 30.0
## How far from the wall face a crawling shot starts, px.
const CREEP_FROM := 40.0
## The view walked past a crawling shot: px a step, and how many steps.
const SWEEP := 3.0
const SWEEP_STEPS := 12

## Every shot_bounced ("bounce"), shot_hit_wall ("wall"), and shot_left_view ("left") of the test,
## in order: [kind, at, View.rect then].
var _seen: Array = []


func before_test() -> void:
	super()
	_seen.clear()
	Events.shot_bounced.connect(_on_bounced)
	Events.shot_hit_wall.connect(_on_hit_wall)
	Events.shot_left_view.connect(_on_left_view)


func after_test() -> void:
	Events.shot_bounced.disconnect(_on_bounced)
	Events.shot_hit_wall.disconnect(_on_hit_wall)
	Events.shot_left_view.disconnect(_on_left_view)
	await super()


func _on_bounced(at: Vector2) -> void:
	_seen.append(["bounce", at, View.rect(self)])


func _on_hit_wall(at: Vector2) -> void:
	_seen.append(["wall", at, View.rect(self)])


func _on_left_view(at: Vector2) -> void:
	_seen.append(["left", at, View.rect(self)])


func _kinds() -> Array:
	return _seen.map(func(entry: Array) -> String: return entry[0])


## A shot of `def` from `scene` at `from` heading `dir`, alive long enough to cross the arena.
func _fire(main: Node, from: Vector2, dir: Vector2, bounces := 0, pierce := 0,
		scene: PackedScene = PROJECTILE, def: WeaponDef = HANDGUN) -> Projectile:
	var shot: Projectile = auto_free(scene.instantiate())
	shot.setup(def, dir)
	shot.life = 100.0
	shot.bounces = bounces
	shot.pierce = pierce
	projectiles_of(main).add_child(shot)
	shot.global_position = from
	return shot


## The floor inside the walls of the room `main` fights in, in world space.
func _floor(main: Node) -> Rect2:
	return (main.get("room") as Room).global_bounds()


func _gone(shot: Projectile) -> void:
	var ref: WeakRef = weakref(shot)  # weakref() returns Variant
	await wait_until(func() -> bool:
		var node: Node = ref.get_ref()
		return node == null or node.is_queued_for_deletion(), "the shot's end")


## The player stood at `at`, aiming `aim` away from itself (none: no lean), and the view come to
## rest on it: centred on it plus the lean, or held at the room's limits.
func _stand(main: Node, at: Vector2, aim := Vector2.ZERO) -> void:
	var player := player_of(main)
	player.global_position = at
	player.aim_override = at + aim
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	var full: Rect2 = (main.get("room") as Room).full_rect()
	var half := get_viewport().get_visible_rect().size / camera.zoom * 0.5
	var target := at + aim.limit_length(Camera.MAX_LEAN) * Camera.LEAN_FACTOR
	var centre := Vector2(clampf(target.x, full.position.x + half.x, full.end.x - half.x),
		clampf(target.y, full.position.y + half.y, full.end.y - half.y))
	await wait_until(func() -> bool: return View.bare_rect(self).get_center().distance_to(centre) < SETTLED,
		"the view at rest on the player")


# --- The view ---


func test_the_view_is_the_screen_grown_by_a_tile_and_the_shake_does_not_move_it() -> void:
	var main := quiet_main()
	await _stand(main, _floor(main).get_center())
	var camera: Camera = main.get_node("Player/Camera")
	var bare := View.bare_rect(main)
	assert_vector(bare.size).is_equal_approx(get_viewport().get_visible_rect().size / camera.zoom, Vector2.ONE * AT)
	assert_object(View.rect(main)).is_equal(bare.grow(View.MARGIN))
	camera.set_process(false)  # the shake held at its largest
	camera.offset = Vector2.ONE * Camera.MAX_SHAKE
	var shaken := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	assert_float(shaken.position.x - bare.position.x).is_equal_approx(Camera.MAX_SHAKE, AT)  # the screen moved
	assert_vector(View.bare_rect(main).position).is_equal_approx(bare.position, Vector2.ONE * AT)  # the rule's view did not


func test_a_node_outside_the_tree_has_an_empty_view_that_contains_nothing() -> void:
	var loose: Node2D = auto_free(Node2D.new())
	assert_object(View.rect(loose)).is_equal(Rect2())
	assert_bool(ViewRules.contains(View.rect(loose), Vector2.ZERO)).is_false()


## The lean is in the view: aimed right, the view sits the lean to the right, and a shot to the
## right leaves at the leaned edge.
func test_the_lean_moves_the_view_and_its_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var centre := _floor(main).get_center()
	await _stand(main, centre, Vector2(200, 0))
	var lean := Camera.MAX_LEAN * Camera.LEAN_FACTOR
	assert_float(View.bare_rect(main).get_center().x - centre.x).is_equal_approx(lean, SETTLED)
	var shot := _fire(main, centre, Vector2.RIGHT)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["left"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx(centre.x + lean + View.bare_rect(main).size.x / 2.0 + View.MARGIN, AT)


# --- Rule 1: the edge of the view is a wall for shots ---


func test_in_the_wide_arena_a_shot_dies_at_the_edge_of_the_view() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var shot := _fire(main, bounds.get_center(), Vector2.RIGHT)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["left"])  # not the wall's signal: an edge death is quiet
	assert_int(plays("shot_wall")).is_equal(0)
	var at: Vector2 = _seen[0][1]
	var view: Rect2 = _seen[0][2]
	assert_float(at.x).is_equal_approx(view.end.x, AT)
	assert_float(at.x).is_less(bounds.end.x - ArenaGrid.TILE * 10)  # well short of the wall, in open floor


func test_a_shot_with_pierce_and_no_bounce_dies_at_the_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var shot := _fire(main, bounds.get_center(), Vector2.UP, 0, 3)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["left"])
	assert_float((_seen[0][1] as Vector2).y).is_equal_approx((_seen[0][2] as Rect2).position.y, AT)


## A ricochet spends its bounce on the edge, as on a wall, comes back across the view, and dies at
## the far edge.
func test_a_ricochet_comes_back_off_the_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var shot := _fire(main, bounds.get_center(), Vector2.RIGHT, 1)
	await wait_until(func() -> bool: return _seen.size() == 1, "the bounce")
	assert_array(_kinds()).is_equal(["bounce"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx((_seen[0][2] as Rect2).end.x, AT)
	assert_int(shot.bounces).is_equal(0)
	assert_vector(shot.direction).is_equal_approx(Vector2.LEFT, Vector2.ONE * AT)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["bounce", "left"])
	assert_float((_seen[1][1] as Vector2).x).is_equal_approx((_seen[1][2] as Rect2).position.x, AT)


func test_an_enemy_bolt_dies_at_the_edge_even_with_a_bounce() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	# Away from the player, whose hurtbox takes an enemy bolt.
	var bolt := _fire(main, bounds.get_center() + Vector2(-40, 0), Vector2.LEFT, 1, 0, ENEMY_BOLT, SHAMAN_BOLT)
	assert_bool(bolt.is_in_group(Projectile.ENEMY_BOLT_GROUP)).is_true()
	await _gone(bolt)
	assert_array(_kinds()).is_equal(["left"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx((_seen[0][2] as Rect2).position.x, AT)


## A shot born outside the view heading out, with no bounce, dies on its first step where it lands
## on the view; one with a bounce comes back in from there. (Heading in, a player shot is carried:
## the sweep cases below.)
func test_a_shot_born_outside_the_view_dies_or_comes_back_on_its_first_step() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var view := View.rect(main)
	var born := Vector2(view.end.x + 20.0, bounds.get_center().y)
	var plain := _fire(main, born, Vector2.RIGHT)
	await _gone(plain)
	assert_array(_kinds()).is_equal(["left"])
	assert_vector(_seen[0][1]).is_equal(Vector2(view.end.x, born.y))
	_seen.clear()
	var bouncing := _fire(main, born, Vector2.RIGHT, 1)
	await wait_until(func() -> bool: return not _seen.is_empty(), "the bounce back in")
	assert_array(_kinds()).is_equal(["bounce"])
	assert_vector(_seen[0][1]).is_equal(Vector2(view.end.x, born.y))
	assert_vector(bouncing.direction).is_equal(Vector2.LEFT)
	assert_bool(ViewRules.contains(View.rect(main), bouncing.global_position)).is_true()


## A ricochet overtaken by the edge (the view following the player away from it) keeps its bounce:
## it comes back in at the edge instead of dying outside.
func test_a_ricochet_overtaken_by_the_edge_comes_back() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var edge := View.rect(main).position.x
	var shot := _fire(main, Vector2(edge + 2.0, bounds.get_center().y), Vector2.LEFT, 1)
	shot.speed = CREEP
	var player := player_of(main)
	player.global_position += Vector2(80, 0)
	player.aim_override = player.global_position
	# The view jumps with the player, past the shot, between two of its steps (the follow and the
	# lean move it a few px a frame; a jump makes the sweep one step, and leaves the view still after).
	(main.get_node("Player/Camera") as Camera).reset_smoothing()
	await wait_until(func() -> bool: return not _seen.is_empty(), "the edge to reach the shot")
	assert_array(_kinds()).is_equal(["bounce"])
	assert_float((_seen[0][1] as Vector2).x).is_greater(edge + 2.0)  # the edge came to it, past where it was
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx((_seen[0][2] as Rect2).position.x, AT)
	assert_int(shot.bounces).is_equal(0)
	assert_vector(shot.direction).is_equal(Vector2.RIGHT)
	shot.speed = HANDGUN.projectile_speed  # outruns the view back across it
	await _gone(shot)
	assert_array(_kinds()).is_equal(["bounce", "left"])


## A crawling shot heading left on the view's right edge while the view walks left past it, SWEEP px
## a step for SWEEP_STEPS steps (the follow without its smoothing, so the view moves exactly with the
## player): after each of the shot's steps, whether it is still there and on the view. A step the
## shot dies in ends the walk.
func _sweep_past(main: Node, shot: Projectile) -> Array[bool]:
	var player := player_of(main)
	(main.get_node("Player/Camera") as Camera).position_smoothing_enabled = false
	var ref: WeakRef = weakref(shot)  # weakref() returns Variant
	var on_view: Array[bool] = []
	for i in SWEEP_STEPS:
		player.global_position.x -= SWEEP
		player.aim_override = player.global_position
		await get_tree().process_frame  # the shot has stepped; the view has not moved again yet
		var node: Projectile = ref.get_ref()
		if node == null or node.is_queued_for_deletion():
			break
		on_view.append(ViewRules.contains(View.rect(self), node.global_position))
	return on_view


## A shot already heading in when the edge passes it: what the sweep does to it.
func _swept_shot(main: Node, bounces: int, scene: PackedScene = PROJECTILE, def: WeaponDef = HANDGUN) -> Projectile:
	await _stand(main, _floor(main).get_center())
	var shot := _fire(main, Vector2(View.rect(main).end.x - 1.0, _floor(main).get_center().y), Vector2.LEFT,
		bounces, 0, scene, def)
	shot.speed = CREEP  # slower than the view: the edge passes it every step
	return shot


## A ricochet heading in, the view walking past it a few px a step: the edge carries it (no bounce
## spent, nothing heard), so it comes back on screen when the view stops.
func test_a_ricochet_heading_in_is_carried_by_the_edge_not_bounced() -> void:
	var main := quiet_main_with_series(wide_series())
	var shot := await _swept_shot(main, 3)
	var on_view := await _sweep_past(main, shot)
	assert_array(on_view).is_equal(Array(range(SWEEP_STEPS)).map(func(_i: int) -> bool: return true))
	assert_int(shot.bounces).is_equal(3)
	assert_vector(shot.direction).is_equal(Vector2.LEFT)
	assert_array(_seen).is_empty()


func test_a_plain_shot_heading_in_is_carried_by_the_edge_not_killed() -> void:
	var main := quiet_main_with_series(wide_series())
	var shot := await _swept_shot(main, 0)
	var on_view := await _sweep_past(main, shot)
	assert_int(on_view.size()).is_equal(SWEEP_STEPS)
	assert_bool(on_view.all(func(on: bool) -> bool: return on)).is_true()
	assert_array(_seen).is_empty()


## An enemy bolt is never carried: the first step the edge has passed it, it dies there, quietly.
func test_an_enemy_bolt_heading_in_dies_when_the_edge_passes_it() -> void:
	var main := quiet_main_with_series(wide_series())
	var bolt := await _swept_shot(main, 1, ENEMY_BOLT, SHAMAN_BOLT)
	var on_view := await _sweep_past(main, bolt)
	assert_int(on_view.size()).is_less(SWEEP_STEPS)
	assert_array(_kinds()).is_equal(["left"])


## A homing shot that turns back before the edge never meets it: it lands on the enemy behind.
func test_a_homing_shot_turning_back_before_the_edge_is_untouched() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var chaser := active_chaser_on(main, bounds.get_center() + Vector2(-60, 0))
	var def: WeaponDef = HANDGUN.duplicate()
	def.homing = 3.0
	var shot := _fire(main, bounds.get_center(), Vector2.RIGHT, 0, 0, PROJECTILE, def)
	await _gone(shot)
	assert_float(chaser.health.hp).is_less(chaser.def.max_hp)
	assert_array(_seen).is_empty()


## Homing chases only what is on screen: past a nearer enemy off screen, to the one in view.
func test_homing_turns_to_the_enemy_in_view_not_a_nearer_one_off_screen() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var edge := View.rect(main).end.x
	var from := Vector2(edge - 50.0, bounds.get_center().y)
	var hidden := active_chaser_on(main, Vector2(edge + 20.0, from.y))  # 70 px away, off screen
	var seen := active_chaser_on(main, from + Vector2(-90, 0))  # 90 px away, in view
	var def: WeaponDef = HANDGUN.duplicate()
	def.homing = 3.0
	var shot := _fire(main, from, Vector2.UP, 0, 0, PROJECTILE, def)
	await _gone(shot)
	assert_float(seen.health.hp).is_less(seen.def.max_hp)
	assert_float(hidden.health.hp).is_equal(hidden.def.max_hp)


func test_homing_with_only_an_enemy_off_screen_flies_straight() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var edge := View.rect(main).end.x
	var from := Vector2(edge - 50.0, bounds.get_center().y)
	var hidden := active_chaser_on(main, Vector2(edge + 20.0, from.y))
	var def: WeaponDef = HANDGUN.duplicate()
	def.homing = 3.0
	var shot := _fire(main, from, Vector2.UP, 0, 0, PROJECTILE, def)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["left"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx(from.x, AT)
	assert_float(hidden.health.hp).is_equal(hidden.def.max_hp)


## A step that crosses the edge and reaches a wall: the wall takes it, once.
func test_the_wall_wins_when_the_edge_and_the_wall_are_in_one_step() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, Vector2(bounds.get_center().x, bounds.position.y + 200.0))
	var edge := View.rect(main).position.x
	assert_float(edge).is_greater(bounds.position.x + ArenaGrid.TILE)  # the edge is in open floor
	var from := Vector2(edge + 4.0, bounds.position.y + 200.0)
	var shot := _fire(main, from, Vector2.LEFT)
	shot.speed = (from.x - bounds.position.x + 8.0) * Engine.physics_ticks_per_second  # one step past both
	await _gone(shot)
	assert_array(_kinds()).is_equal(["wall"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx(bounds.position.x, AT)


## Tier 1's arena is a little wider than the view, so the camera scrolls: pushed to either side,
## and with the shake at its largest toward the far wall, a shot still crosses the open floor and
## ends on the wall tile, with today's signals (the margin's case).
func test_in_tier_1_a_shot_reaches_the_wall_with_the_camera_at_either_side_and_shaken() -> void:
	var main := quiet_main()
	var camera: Camera = main.get_node("Player/Camera")
	var bounds := _floor(main)
	var y := bounds.get_center().y
	var near_right := Vector2(bounds.end.x - 12.0, y)
	var near_left := Vector2(bounds.position.x + 12.0, y)
	var shake := Camera.MAX_SHAKE
	# [where the player stands, the shot's heading, the shake offset, the wall face it ends on]
	var cases := [
		[near_right, Vector2.LEFT, Vector2.ZERO, bounds.position.x],
		[near_right, Vector2.LEFT, Vector2(shake, 0), bounds.position.x],
		[near_left, Vector2.RIGHT, Vector2.ZERO, bounds.end.x],
		[near_left, Vector2.RIGHT, Vector2(-shake, 0), bounds.end.x],
		[near_right, Vector2.UP, Vector2(0, shake), bounds.position.y],
		[near_left, Vector2.DOWN, Vector2(0, -shake), bounds.end.y],
	]
	for case: Array in cases:
		camera.offset = Vector2.ZERO
		await _stand(main, case[0])
		camera.set_process(false)  # the shake held where the case puts it
		camera.offset = case[2]
		_seen.clear()
		var dir: Vector2 = case[1]
		var from: Vector2 = case[0]
		if dir.x != 0.0:
			from.x = case[3] - dir.x * CREEP_FROM
		else:
			from.y = case[3] - dir.y * CREEP_FROM
		var shot := _fire(main, from, dir)
		shot.speed = CREEP
		await _gone(shot)
		assert_array(_kinds()).override_failure_message("%s: %s" % [case, _seen]).is_equal(["wall"])
		assert_int(plays("shot_wall")).override_failure_message("%s" % [case]).is_greater(0)  # the wall is heard
		Audio.reset()
		var at: Vector2 = _seen[0][1]
		var along: float = at.x if case[1].x != 0.0 else at.y
		assert_float(along).override_failure_message("%s ended at %s" % [case, at]).is_equal_approx(case[3], AT)


## A ricochet in tier 1 with the camera pushed right and shaken: off the left wall, then the right.
func test_in_tier_1_a_ricochet_bounces_off_the_walls_not_the_edge() -> void:
	var main := quiet_main()
	var bounds := _floor(main)
	var at := Vector2(bounds.end.x - 12.0, bounds.get_center().y)
	await _stand(main, at)
	var camera: Camera = main.get_node("Player/Camera")
	camera.set_process(false)
	camera.offset = Vector2(Camera.MAX_SHAKE, 0)
	var shot := _fire(main, Vector2(bounds.position.x + CREEP_FROM, at.y), Vector2.LEFT, 1)
	shot.speed = CREEP
	await wait_until(func() -> bool: return _seen.size() == 1, "the bounce")
	shot.speed = HANDGUN.projectile_speed  # back across at full speed
	await _gone(shot)
	assert_array(_kinds()).is_equal(["bounce", "wall"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx(bounds.position.x, AT)
	assert_float((_seen[1][1] as Vector2).x).is_equal_approx(bounds.end.x, AT)


## The verdict's drift zooms in on the box; the rule's view stays the fight's (the view as the drift
## began), so a shot still in flight low in the arena reaches the wall instead of dying at once.
func test_the_verdict_drift_holds_the_view_and_shots_fly_on() -> void:
	var main := quiet_main()
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var before := View.rect(main)
	var camera: Camera = main.get_node("Player/Camera")
	var zoom_before := camera.zoom.y
	camera.drift_to_top(main.room.emperor_box.centre(), Main.VERDICT_DRIFT, Main.VERDICT_ZOOM)
	await real_seconds(Main.VERDICT_DRIFT + 0.1)
	assert_float(camera.zoom.y).is_greater(zoom_before)  # zoomed in on the box
	var seen := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	var from := Vector2(bounds.get_center().x + 60.0, bounds.end.y - 20.0)
	assert_bool(seen.has_point(from)).is_false()  # below what the zoomed view shows
	assert_object(View.rect(main)).is_equal(before)
	var shot := _fire(main, from, Vector2.DOWN)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["wall"])
	assert_float((_seen[0][1] as Vector2).y).is_equal_approx(bounds.end.y, AT)


# --- Rule 2: enemies begin an attack only on screen ---


## The spawns of a wide round: each where it appears is inside the floor and the view, away from
## the player, near an edge of the view (they walk in); the round's own runner places so too.
func test_every_spawn_of_a_wide_round_appears_inside_the_view_near_its_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var floor_rect := _floor(main)
	await _stand(main, floor_rect.get_center())
	var spawner: Spawner = main.room.spawner
	var spawned: Array = []  # [position, View.rect then] at each enemy_spawned
	var on_spawned := func(enemy: Node2D) -> void: spawned.append([enemy.global_position, View.rect(enemy)])
	Events.enemy_spawned.connect(on_spawned)
	main.get_node("Room/WaveRunner").enabled = true
	await wait_until(func() -> bool: return spawned.size() == 1, "the round's chaser")
	main.get_node("Room/WaveRunner").enabled = false
	for i in 12:
		spawner.spawn(load(CHASER))
	Events.enemy_spawned.disconnect(on_spawned)
	assert_int(spawned.size()).is_equal(13)
	var player := player_of(main).global_position
	for entry: Array in spawned:
		var at: Vector2 = entry[0]
		var view: Rect2 = entry[1]
		assert_bool(ViewRules.contains(view, at)).override_failure_message("%s outside %s" % [at, view]).is_true()
		assert_bool(floor_rect.has_point(at)).is_true()
		assert_float(at.distance_to(player)).is_greater_equal(spawner.min_player_distance)
		var to_edge := minf(minf(at.x - view.position.x, view.end.x - at.x), minf(at.y - view.position.y, view.end.y - at.y))
		assert_float(to_edge).is_less_equal(SpawnMath.VIEW_BAND)


## A shooter off screen whose range would reach the player walks in, and winds up only once in view.
func test_a_shooter_off_screen_walks_in_and_only_then_winds_up() -> void:
	var main := quiet_main_with_series(wide_series())
	var centre := _floor(main).get_center()
	await _stand(main, centre)
	var start := centre + Vector2(View.rect(main).size.x / 2.0 + 40.0, 0)
	var shooter := active_shooter_on(main, start, false)
	shooter.def.preferred_range = 10000.0  # in range from anywhere: only the screen holds it off
	assert_bool(View.on_screen(shooter)).is_false()
	var telegraphs: Array = []  # [position, View.bare_rect then]
	var on_telegraphed := func(enemy: Node2D) -> void: telegraphs.append([enemy.global_position, View.bare_rect(enemy)])
	Events.enemy_telegraphed.connect(on_telegraphed)
	await wait_until(func() -> bool: return telegraphs.size() > 0, "the wind-up")
	Events.enemy_telegraphed.disconnect(on_telegraphed)
	var at: Vector2 = telegraphs[0][0]
	assert_float(at.x).is_less(start.x)  # it walked toward the player
	var screen: Rect2 = telegraphs[0][1]
	assert_bool(ViewRules.contains(screen.grow(View.SIGHT_SLACK), at)) \
		.override_failure_message("wound up at %s, off the screen %s" % [at, screen]).is_true()


## The margin is not the screen: a shooter in the margin's band (inside View.rect, past the
## screen's edge by more than the slack) does not wind up there; let walk, it winds up on the screen.
func test_a_shooter_in_the_margin_does_not_wind_up_until_it_walks_onto_the_screen() -> void:
	var main := quiet_main_with_series(wide_series())
	var centre := _floor(main).get_center()
	await _stand(main, centre)
	var screen := View.bare_rect(main)
	var start := Vector2(screen.end.x + (View.SIGHT_SLACK + View.MARGIN) / 2.0, centre.y)
	assert_bool(ViewRules.contains(View.rect(main), start)).is_true()
	var shooter := active_shooter_on(main, start)  # held where it stands
	shooter.def.preferred_range = 10000.0
	assert_bool(View.on_screen(shooter)).is_false()
	await ticks(ceili(shooter.def.telegraph_time * 2.0 * Engine.physics_ticks_per_second))  # a bounded hold, in game time
	assert_int(shooter.brain.phase).is_equal(ShooterBrain.Phase.APPROACH)
	shooter.def.speed = (load("res://data/enemies/shooter.tres") as EnemyDef).speed  # let it walk
	await wait_until(func() -> bool: return shooter.brain.phase == ShooterBrain.Phase.TELEGRAPH, "the wind-up")
	assert_float(shooter.global_position.x).is_less_equal(screen.end.x + View.SIGHT_SLACK)


## Tier 1: a shooter pressed against a side wall, with the camera at the far side, has its centre
## a third of a pixel past the screen's edge: the slack keeps it on the screen, and it winds up.
func test_in_tier_1_a_shooter_pressed_on_a_side_wall_is_on_screen_and_winds_up() -> void:
	for side: float in [-1.0, 1.0]:
		var main := quiet_main()
		var bounds := _floor(main)
		var far := Vector2(bounds.get_center().x - side * (bounds.size.x / 2.0 - 24.0), bounds.get_center().y)
		await _stand(main, far, Vector2(-side * 200.0, 0))
		var radius := 5.0  # the shooter's body (shooter.tscn's CircleShape2D)
		var at := Vector2(bounds.position.x + radius if side < 0.0 else bounds.end.x - radius, bounds.get_center().y)
		var shooter := active_shooter_on(main, at)
		shooter.def.preferred_range = 10000.0
		assert_bool(View.bare_rect(main).has_point(at)).is_false()  # just past the screen's edge
		assert_bool(View.on_screen(shooter)).is_true()
		await wait_until(func() -> bool: return shooter.brain.phase == ShooterBrain.Phase.TELEGRAPH, "the wind-up")
		main.queue_free()
		await get_tree().process_frame


## A wind-up begun on screen finishes when the player gets away: the bolt is fired from out of
## view, and dies at the edge (rule 1) on its first step.
func test_a_shooter_mid_wind_up_when_the_player_gets_away_still_fires_and_its_bolt_dies_at_the_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var centre := _floor(main).get_center()
	await _stand(main, centre)
	var shooter := active_shooter_on(main, centre + Vector2(100, 0))
	shooter.def.telegraph_time = 5.0  # time enough for the view to move on
	await wait_until(func() -> bool: return shooter.brain.phase == ShooterBrain.Phase.TELEGRAPH, "the wind-up")
	var fired: Array[bool] = []  # whether the shooter was in view, at each bolt
	var on_fired := func(enemy: Node2D, _at: Vector2) -> void:
		fired.append(ViewRules.contains(View.rect(enemy), enemy.global_position))
	Events.enemy_fired.connect(on_fired)
	await _stand(main, centre - Vector2(View.rect(main).size.x, 0))
	assert_bool(ViewRules.contains(View.rect(main), shooter.global_position)).is_false()
	assert_int(shooter.brain.phase).is_equal(ShooterBrain.Phase.TELEGRAPH)  # it did not restart
	await wait_until(func() -> bool: return fired.size() > 0, "the bolt", 600)
	Events.enemy_fired.disconnect(on_fired)
	assert_array(fired).is_equal([false])  # fired from out of view
	await wait_until(func() -> bool: return _kinds().has("left"), "the bolt's end at the edge")
	assert_array(_kinds()).is_equal(["left"])


## The boss is seated at the top centre of the floor in view, and its summons appear at the
## view's left and right edges inside the floor, as the view is at the summon.
func test_the_boss_sits_at_the_view_s_top_centre_and_summons_at_the_view_s_sides() -> void:
	var main := quiet_main_with_series(wide_series())
	var floor_rect := _floor(main)
	await _stand(main, floor_rect.get_center() + Vector2(80, 60))
	var view := View.rect(main)
	var boss: Boss = main.room.spawner.spawn(load(BOSS))
	own_def(boss)  # the spawned boss holds the shared boss.tres; never write through it
	var seat := SpawnMath.boss_seat(floor_rect, view, View.bare_rect(main))
	assert_vector(boss.global_position).is_equal(seat)
	assert_float(seat.x).is_equal_approx(view.get_center().x, AT)
	assert_bool(ViewRules.contains(View.bare_rect(main), seat)).is_true()
	boss.def.spawn_delay = 0.0
	boss.def.approach_time = 0.0
	boss.def.speed = 0.0
	boss.brain.stage = 2
	boss.brain.pattern = BossBrain.Pattern.SUMMON
	await wait_until(func() -> bool: return get_tree().get_nodes_in_group("summoned").size() == 2, "the summons")
	var xs: Array[float] = []
	for imp: Node2D in get_tree().get_nodes_in_group("summoned"):
		assert_float(imp.global_position.y).is_equal_approx(view.get_center().y, AT)
		xs.append(imp.global_position.x)
	xs.sort()
	assert_float(xs[0]).is_equal_approx(view.position.x + ArenaGrid.TILE, AT)
	assert_float(xs[1]).is_equal_approx(view.end.x - ArenaGrid.TILE, AT)


## A throw of coins in a wide arena lands on the screen as well as the floor, in the ring.
func test_a_roar_s_piles_land_on_the_screen() -> void:
	var main := quiet_main_with_series(wide_series())
	var floor_rect := _floor(main)
	var at := floor_rect.get_center()
	await _stand(main, at)
	RunState.pull_radius = 0.0  # the piles stay where they land
	main.throw_piles(at, 64)
	var piles: Array[Node] = main.room.piles.get_children()
	assert_int(piles.size()).is_equal(PileRules.pile_count(64))
	await wait_until(func() -> bool: return piles.all(func(pile: CoinPile) -> bool: return pile.monitoring), "the piles to land")
	var screen := View.bare_rect(main)
	for pile: CoinPile in piles:
		assert_bool(ViewRules.contains(screen, pile.global_position)) \
			.override_failure_message("%s off the screen %s" % [pile.global_position, screen]).is_true()
		assert_float(pile.global_position.distance_to(at)).is_less_equal(PileRules.RING_MAX)


## The Cheer's coin flies to the counter from the emperor's box; with the box out of view it
## starts at the screen's edge. In tier 1 the box is on screen and the start is where it was.
func test_a_flight_from_the_box_out_of_view_starts_at_the_screen_s_edge() -> void:
	var main := quiet_main_with_series(wide_series())
	var floor_rect := _floor(main)
	await _stand(main, floor_rect.end - Vector2(40, 40))
	var box: Vector2 = main.room.emperor_box.centre()
	var screen := get_viewport().get_visible_rect()
	var raw := get_viewport().get_canvas_transform() * box
	assert_bool(screen.has_point(raw)).is_false()
	hud_of(main).fly_coin(box)
	var flights: Array[CoinFlight] = []
	for child in hud_of(main).get_children():
		if child is CoinFlight:
			flights.append(child)
	assert_int(flights.size()).is_equal(1)
	assert_vector(flights[0].position).is_equal_approx(raw.clamp(screen.position, screen.end), Vector2.ONE * AT)


func test_in_tier_1_a_flight_from_the_box_starts_on_the_box() -> void:
	var main := quiet_main()
	await _stand(main, _floor(main).end - Vector2(20, 20), Vector2(200, 200))
	var box: Vector2 = main.room.emperor_box.centre()
	assert_vector(hud_of(main).flight_start(box)).is_equal(get_viewport().get_canvas_transform() * box)


## Tier 1 does not change: wherever the camera sits, the view covers the floor, so a seed's spawn
## spots are the floor-only rule's draw for draw, and the boss's seat, the summons' points, and a
## throw's rect are the floor's.
func test_in_tier_1_placements_are_the_floor_only_rule_with_the_camera_at_either_side() -> void:
	var main := quiet_main(4242)
	var room: Room = main.room
	var spawner := room.spawner
	var bounds := room.bounds()
	var full := room.full_rect()
	assert_object(room.global_bounds()).is_equal(bounds)
	var pile_reference := RunState.stream("piles:%d" % RunState.round_index)
	RunState.pull_radius = 0.0
	for side: float in [-1.0, 1.0]:
		var at := Vector2(bounds.get_center().x + side * (bounds.size.x / 2.0 - 24.0), bounds.get_center().y)
		await _stand(main, at, Vector2(side * 200.0, 0))
		var bare := View.bare_rect(main)
		if side < 0.0:
			assert_float(bare.position.x).is_equal_approx(full.position.x, SETTLED)  # the camera at the left
		else:
			assert_float(bare.end.x).is_equal_approx(full.end.x, SETTLED)  # and at the right
		spawner.start_round()
		var reference := RunState.stream("spawn:%d" % RunState.round_index)
		for i in 12:
			var expected := SpawnMath.pick_position(bounds, player_of(main).global_position, spawner.min_player_distance, reference)
			var enemy := spawner.spawn(load(CHASER))
			assert_vector(enemy.global_position).is_equal(expected)
			enemy.queue_free()
		var boss: Boss = spawner.spawn(load(BOSS))
		assert_vector(boss.global_position).is_equal(Vector2(bounds.get_center().x, bounds.position.y + ArenaGrid.TILE * 1.5))
		assert_array(boss._summon_points()).is_equal([
			Vector2(bounds.position.x + ArenaGrid.TILE, bounds.get_center().y),
			Vector2(bounds.end.x - ArenaGrid.TILE, bounds.get_center().y)])
		boss.queue_free()
		for pile in room.piles.get_children():
			pile.queue_free()
		await get_tree().process_frame
		main.throw_piles(bounds.get_center(), 32)
		var expected_spots := PileRules.spots(bounds.get_center(), PileRules.pile_count(32), bounds, pile_reference)
		var piles: Array[Node] = room.piles.get_children()
		await wait_until(func() -> bool: return piles.all(func(pile: CoinPile) -> bool: return pile.monitoring), "the piles to land")
		for i in piles.size():
			assert_vector((piles[i] as CoinPile).global_position).is_equal_approx(expected_spots[i], Vector2.ONE * AT)


# --- Rule 3: nothing to be cornered by ---


## A wide room adds no physics body beyond tier 1's: the one ring of walls round the floor (the
## emperor's box is set into the top wall and has no body), nothing on the floor.
func test_a_wide_room_has_the_bodies_tier_1_has_and_none_on_the_floor() -> void:
	var tier_1 := quiet_main()
	var tier_1_bodies := _bodies(tier_1.room)
	var tier_1_shapes: int = tier_1.room.arena.walls.get_child_count()
	tier_1.queue_free()
	await get_tree().process_frame
	var main := quiet_main_with_series(wide_series())
	assert_array(_bodies(main.room)).is_equal(tier_1_bodies)
	assert_array(tier_1_bodies).is_equal(["Arena/Walls"])
	var walls: StaticBody2D = main.room.arena.walls
	assert_int(walls.get_child_count()).is_equal(tier_1_shapes)
	var floor_rect: Rect2 = main.room.bounds()
	for shape: CollisionShape2D in walls.get_children():
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		var rect := Rect2(shape.position - size / 2.0, size)
		assert_bool(rect.intersection(floor_rect).has_area()).override_failure_message("a wall on the floor: %s" % rect).is_false()


## Every physics body under `room` but its enemies, shots, and piles, by path from the room.
func _bodies(room: Room) -> Array[String]:
	var found: Array[String] = []
	var visit := func(node: Node, recurse: Callable) -> void:
		if node in [room.enemies, room.projectiles, room.piles]:
			return
		if node is CollisionObject2D:
			found.append(str(room.get_path_to(node)))
		for child in node.get_children():
			recurse.call(child, recurse)
	visit.call(room, visit)
	return found
