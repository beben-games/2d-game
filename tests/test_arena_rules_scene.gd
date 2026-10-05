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

## Every shot_bounced and shot_hit_wall of the test, in order: [kind, at, View.rect then].
var _seen: Array = []


func before_test() -> void:
	super()
	_seen.clear()
	Events.shot_bounced.connect(_on_bounced)
	Events.shot_hit_wall.connect(_on_hit_wall)


func after_test() -> void:
	Events.shot_bounced.disconnect(_on_bounced)
	Events.shot_hit_wall.disconnect(_on_hit_wall)
	await super()


func _on_bounced(at: Vector2) -> void:
	_seen.append(["bounce", at, View.rect(self)])


func _on_hit_wall(at: Vector2) -> void:
	_seen.append(["wall", at, View.rect(self)])


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


## The player stood at `at`, aiming at itself (no lean), and the view come to rest on it: centred
## on it, or held at the room's limits.
func _stand(main: Node, at: Vector2) -> void:
	var player := player_of(main)
	player.global_position = at
	player.aim_override = at
	var camera: Camera = main.get_node("Player/Camera")
	camera.reset_smoothing()
	var full: Rect2 = (main.get("room") as Room).full_rect()
	var half := get_viewport().get_visible_rect().size / camera.zoom * 0.5
	var centre := Vector2(clampf(at.x, full.position.x + half.x, full.end.x - half.x),
		clampf(at.y, full.position.y + half.y, full.end.y - half.y))
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


# --- Rule 1: the edge of the view is a wall for shots ---


func test_in_the_wide_arena_a_shot_dies_at_the_edge_of_the_view() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var shot := _fire(main, bounds.get_center(), Vector2.RIGHT)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["wall"])
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
	assert_array(_kinds()).is_equal(["wall"])
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
	assert_array(_kinds()).is_equal(["bounce", "wall"])
	assert_float((_seen[1][1] as Vector2).x).is_equal_approx((_seen[1][2] as Rect2).position.x, AT)


func test_an_enemy_bolt_dies_at_the_edge_even_with_a_bounce() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	# Away from the player, whose hurtbox takes an enemy bolt.
	var bolt := _fire(main, bounds.get_center() + Vector2(-40, 0), Vector2.LEFT, 1, 0, ENEMY_BOLT, SHAMAN_BOLT)
	assert_bool(bolt.is_in_group(Projectile.ENEMY_BOLT_GROUP)).is_true()
	await _gone(bolt)
	assert_array(_kinds()).is_equal(["wall"])
	assert_float((_seen[0][1] as Vector2).x).is_equal_approx((_seen[0][2] as Rect2).position.x, AT)


## A shot born outside the view (a bolt fired as the player scrolled away) dies where it is on its
## first step, heading in or not, a bounce left or not.
func test_a_shot_born_outside_the_view_dies_on_its_first_step() -> void:
	var main := quiet_main_with_series(wide_series())
	var bounds := _floor(main)
	await _stand(main, bounds.get_center())
	var born := Vector2(View.rect(main).end.x + 20.0, bounds.get_center().y)
	var shot := _fire(main, born, Vector2.LEFT, 1)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["wall"])
	assert_vector(_seen[0][1]).is_equal(born)


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
	camera.drift_to_top(main.room.emperor_box.centre(), Main.VERDICT_DRIFT, Main.VERDICT_ZOOM)
	await real_seconds(Main.VERDICT_DRIFT + 0.1)
	assert_float(camera.zoom.y).is_greater(3.0)  # zoomed in on the box
	var seen := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	var from := Vector2(bounds.get_center().x + 60.0, bounds.end.y - 20.0)
	assert_bool(seen.has_point(from)).is_false()  # below what the zoomed view shows
	assert_object(View.rect(main)).is_equal(before)
	var shot := _fire(main, from, Vector2.DOWN)
	await _gone(shot)
	assert_array(_kinds()).is_equal(["wall"])
	assert_float((_seen[0][1] as Vector2).y).is_equal_approx(bounds.end.y, AT)


# --- Rule 2: enemies begin an attack only on screen (Task 3) ---


# --- Rule 3: nothing to be cornered by (Task 3) ---
