extends SceneSuite
## A shielded chaser in the real main scene: the front arc stops player shots below pierce 3,
## the back takes them, the facing follows the player at the turn rate (a dash past it lands a
## flanking shot), a stun holds the facing, the arc child shows the covered side, and a corpse
## blocks nothing. Timings are physics ticks (60 Hz).

const PROJECTILE := preload("res://scenes/projectile.tscn")
const HANDGUN := preload("res://data/weapons/handgun.tres")
const ENEMY_OFFSET := Vector2(80, 0)  ## the enemy sits right of the player, facing left at it
const SHOT_RANGE := 60.0  ## a shot starts this far from the enemy: ~11 ticks of flight at 340 px/s
const FLIGHT := 20  ## ticks: the shot has landed or passed by then

var _blocked: Array[Vector2] = []
var _hits: Array[float] = []


func before_test() -> void:
	_blocked = []
	_hits = []
	Events.shot_blocked.connect(_on_blocked)
	Events.enemy_hit.connect(_on_hit)


func after_test() -> void:
	Events.shot_blocked.disconnect(_on_blocked)
	Events.enemy_hit.disconnect(_on_hit)
	super()


func _on_blocked(at: Vector2) -> void:
	_blocked.append(at)


func _on_hit(_enemy: Node2D, damage: float, _at: Vector2) -> void:
	_hits.append(damage)


## A plain chaser's def with the shield switched on: the attribute, not a new enemy type, is
## under test. Stationary and already active, like active_chaser_on.
func _shielded_chaser_on(main: Node, at: Vector2) -> Enemy:
	var enemy: Enemy = load(CHASER).instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 0.0
	enemy.def.speed = 0.0
	enemy.def.shield = true
	enemies_of(main).add_child(enemy)
	enemy.global_position = at
	return enemy


## The player at the room centre and a shielded chaser ENEMY_OFFSET to its right, one physics
## step in (physics_frame fires before the step, so two waits), so the facing has been seeded
## toward the player (left).
func _arena() -> Array:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := _shielded_chaser_on(main, player.global_position + ENEMY_OFFSET)
	await ticks(2)
	return [main, player, enemy]


func _fire(main: Node, from: Vector2, dir: Vector2, pierce := 0) -> Projectile:
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	shot.setup(HANDGUN, dir)
	shot.pierce = pierce
	projectiles_of(main).add_child(shot)
	shot.global_position = from
	return shot


func _plays(name: String) -> int:
	return int(Audio.plays.get(name, 0))


func test_a_shot_into_the_front_is_blocked_with_sparks_and_a_clink() -> void:
	var arena: Array = await _arena()
	var main: Node = arena[0]
	var enemy: Enemy = arena[2]
	assert_vector(enemy.facing).is_equal_approx(Vector2.LEFT, Vector2(0.01, 0.01))
	var shot := _fire(main, enemy.global_position + Vector2(-SHOT_RANGE, 0), Vector2.RIGHT)
	var ref: WeakRef = weakref(shot)
	await ticks(FLIGHT)
	assert_float(enemy.health.hp).is_equal(enemy.def.max_hp)
	assert_array(_hits).is_empty()
	assert_int(_blocked.size()).is_equal(1)
	assert_float(_blocked[0].distance_to(enemy.global_position)).is_less(12.0)
	assert_int(_plays("shot_shield")).is_equal(1)
	assert_int(_plays("hit_enemy")).is_equal(0)
	assert_bool(ref.get_ref() == null or not ref.get_ref().is_inside_tree()).is_true()


func test_a_shot_into_the_back_lands() -> void:
	var arena: Array = await _arena()
	var main: Node = arena[0]
	var enemy: Enemy = arena[2]
	_fire(main, enemy.global_position + Vector2(SHOT_RANGE, 0), Vector2.LEFT)
	await ticks(FLIGHT)
	assert_float(enemy.health.hp).is_equal(enemy.def.max_hp - 1.0)
	assert_array(_hits).is_equal([1.0])
	assert_int(_blocked.size()).is_equal(0)
	assert_int(_plays("hit_enemy")).is_equal(1)
	assert_int(_plays("shot_shield")).is_equal(0)


func test_a_shot_that_pierces_three_passes_the_front() -> void:
	var arena: Array = await _arena()
	var main: Node = arena[0]
	var enemy: Enemy = arena[2]
	_fire(main, enemy.global_position + Vector2(-SHOT_RANGE, 0), Vector2.RIGHT, Enemy.SHIELD_PIERCE)
	await ticks(FLIGHT)
	assert_float(enemy.health.hp).is_equal(enemy.def.max_hp - 1.0)
	assert_int(_blocked.size()).is_equal(0)
	# One short of the threshold is still stopped.
	_fire(main, enemy.global_position + Vector2(-SHOT_RANGE, 0), Vector2.RIGHT, Enemy.SHIELD_PIERCE - 1)
	await ticks(FLIGHT)
	assert_float(enemy.health.hp).is_equal(enemy.def.max_hp - 1.0)
	assert_int(_blocked.size()).is_equal(1)


func test_the_facing_comes_round_at_the_turn_rate_after_the_player_passes() -> void:
	var arena: Array = await _arena()
	var main: Node = arena[0]
	var player: Player = arena[1]
	var enemy: Enemy = arena[2]
	# The player is now behind it (to its right): the shield still faces left.
	player.global_position = enemy.global_position + ENEMY_OFFSET
	_fire(main, enemy.global_position + Vector2(SHOT_RANGE, 0), Vector2.LEFT)
	await ticks(FLIGHT)
	assert_float(enemy.health.hp).is_equal(enemy.def.max_hp - 1.0)  # the flank shot landed
	# 180 degrees per second: after 0.5 s in all it is side-on, after 1 s it faces the player.
	await ticks(30 - FLIGHT)
	assert_float(rad_to_deg(absf(Vector2.LEFT.angle_to(enemy.facing)))).is_equal_approx(90.0, 2.0)
	await ticks(31)
	assert_vector(enemy.facing).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))
	_fire(main, enemy.global_position + Vector2(SHOT_RANGE, 0), Vector2.LEFT)
	await ticks(FLIGHT)
	assert_float(enemy.health.hp).is_equal(enemy.def.max_hp - 1.0)  # the same side is now covered
	assert_int(_blocked.size()).is_equal(1)


func test_a_stunned_shield_holds_its_facing() -> void:
	var arena: Array = await _arena()
	var player: Player = arena[1]
	var enemy: Enemy = arena[2]
	var status: StatusEffects = enemy.get_node("Status")
	status.apply_stun()
	player.global_position = enemy.global_position + ENEMY_OFFSET
	await ticks(30)  # the stun lasts 0.6 s (36 ticks): the facing has not moved
	assert_vector(enemy.facing).is_equal_approx(Vector2.LEFT, Vector2(0.01, 0.01))
	await ticks(30)  # tick 60: some 24 ticks of turning since the stun ended, about 70 degrees
	assert_float(rad_to_deg(absf(Vector2.LEFT.angle_to(enemy.facing)))).is_between(60.0, 80.0)


func test_the_arc_child_rotates_with_the_facing() -> void:
	var arena: Array = await _arena()
	var player: Player = arena[1]
	var enemy: Enemy = arena[2]
	var arc: ShieldArc = enemy.get_node("ShieldArc")
	assert_float(arc.rotation).is_equal_approx(enemy.facing.angle(), 0.001)
	assert_float(absf(arc.rotation)).is_equal_approx(PI, 0.01)  # facing left
	player.global_position = enemy.global_position + Vector2(0, ENEMY_OFFSET.x)  # below it
	await ticks(10)
	assert_float(arc.rotation).is_equal_approx(enemy.facing.angle(), 0.001)
	assert_float(rad_to_deg(absf(Vector2.LEFT.angle_to(enemy.facing)))).is_equal_approx(30.0, 2.0)
	assert_float(arc.arc_degrees).is_equal(enemy.def.shield_arc_degrees)


func test_a_plain_chaser_has_no_arc_and_blocks_nothing() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + ENEMY_OFFSET)
	await ticks(1)
	assert_object(enemy.get_node_or_null("ShieldArc")).is_null()
	assert_bool(enemy.blocks_shot(Vector2.RIGHT, 0)).is_false()


func test_a_corpse_blocks_nothing() -> void:
	var arena: Array = await _arena()
	var enemy: Enemy = arena[2]
	assert_bool(enemy.blocks_shot(Vector2.RIGHT, 0)).is_true()
	enemy.health.take_damage(100.0)
	assert_int(enemy.state).is_equal(Enemy.State.DEAD)
	assert_bool(enemy.blocks_shot(Vector2.RIGHT, 0)).is_false()
	await wait_for_death_freeze()
