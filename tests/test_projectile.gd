extends SceneSuite
## Projectiles in the real main scene: they die on walls and on lifetime, and a shot that has
## spent its pierce budget ignores the other bodies entered in the same physics step.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const HANDGUN := preload("res://data/weapons/handgun.tres")
const ENEMY_LAYER := 2


class CountingHealth:
	extends Health
	var hits := 0

	func take_damage(_amount: float, _knockback: Vector2 = Vector2.ZERO) -> void:
		hits += 1


func _fire(main: Node, from: Vector2, dir: Vector2, life: float, pierce := 0) -> Projectile:
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	shot.setup(HANDGUN, dir)
	shot.life = life
	shot.pierce = pierce
	projectiles_of(main).add_child(shot)
	shot.global_position = from
	return shot


## Takes a WeakRef because a projectile that has done its job is already freed.
func _is_gone(ref: WeakRef) -> bool:
	var node: Node = ref.get_ref()
	return node == null or node.is_queued_for_deletion() or not node.is_inside_tree()


func _target(main: Node, at: Vector2) -> CountingHealth:
	var body: StaticBody2D = auto_free(StaticBody2D.new())
	body.collision_layer = ENEMY_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 5.0
	body.add_child(shape)
	var health := CountingHealth.new()
	health.name = "Health"
	body.add_child(health)
	main.add_child(body)
	body.global_position = at
	return health


func _fire_def(main: Node, def: WeaponDef, from: Vector2, dir: Vector2) -> Projectile:
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	shot.setup(def, dir)
	projectiles_of(main).add_child(shot)
	shot.global_position = from
	return shot


func _handgun_with(stat: String, value: Variant) -> WeaponDef:
	var def: WeaponDef = HANDGUN.duplicate()
	def.set(stat, value)
	return def


func test_despawns_on_wall() -> void:
	var main := quiet_main()
	var shot: WeakRef = weakref(_fire(main, Vector2(400, 120), Vector2.RIGHT, 100.0))  # 32 px from the right wall at 432
	await ticks(15)
	assert_bool(_is_gone(shot)).is_true()


func test_despawns_on_lifetime() -> void:
	var main := quiet_main()
	var shot: WeakRef = weakref(_fire(main, Vector2(320, 100), Vector2.RIGHT, 0.1))
	await ticks(10)
	assert_bool(_is_gone(shot)).is_true()


func test_pierce_zero_hits_one_of_two_bodies_entered_together() -> void:
	var main := quiet_main()
	var a := _target(main, Vector2(400, 180))
	var b := _target(main, Vector2(400, 188))
	_fire(main, Vector2(380, 184), Vector2.RIGHT, 100.0)
	await ticks(10)
	assert_int(a.hits + b.hits).is_equal(1)


func test_pierce_one_hits_both_bodies_entered_together() -> void:
	var main := quiet_main()
	var a := _target(main, Vector2(400, 180))
	var b := _target(main, Vector2(400, 188))
	_fire(main, Vector2(380, 184), Vector2.RIGHT, 100.0, 1)
	await ticks(10)
	assert_int(a.hits + b.hits).is_equal(2)


func test_setup_copies_the_new_stats() -> void:
	var def := _handgun_with("bounce", 2.0)
	def.homing = 1.0
	def.burn = 1.0
	def.stun = 1.0
	def.chill = 1.0
	def.look = WeaponDef.Look.BOLT
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	shot.setup(def, Vector2.RIGHT)
	assert_int(shot.bounces).is_equal(2)
	assert_float(shot.homing).is_equal(1.0)
	assert_float(shot.burn).is_equal(1.0)
	assert_float(shot.stun).is_equal(1.0)
	assert_float(shot.chill).is_equal(1.0)
	assert_int(shot.look).is_equal(WeaponDef.Look.BOLT)


func test_a_fast_shot_cannot_tunnel_through_a_wall() -> void:
	var main := quiet_main()
	var def := _handgun_with("projectile_speed", 3000.0)  # 50 px per tick, more than the wall is thick
	def.lifetime = 100.0
	var shot: WeakRef = weakref(_fire_def(main, def, Vector2(400, 120), Vector2.RIGHT))
	await ticks(3)
	assert_bool(_is_gone(shot)).is_true()


func test_a_bouncing_shot_comes_back_off_the_right_wall() -> void:
	var main := quiet_main()
	var def := _handgun_with("bounce", 1.0)
	def.lifetime = 100.0
	var shot := _fire_def(main, def, Vector2(400, 120), Vector2.RIGHT)  # the wall face is at x 432
	var ref: WeakRef = weakref(shot)
	await ticks(15)
	assert_bool(_is_gone(ref)).is_false()
	assert_float(shot.direction.x).is_less(0.0)
	assert_float(shot.global_position.x).is_less(432.0)
	assert_int(shot.bounces).is_equal(0)
	assert_vector(shot.direction).is_equal_approx(Vector2.LEFT, Vector2(0.01, 0.01))
	await ticks(80)  # crosses the room and meets the left wall with no bounces left
	assert_bool(_is_gone(ref)).is_true()


func test_a_bounce_keeps_the_tangent_component() -> void:
	var main := quiet_main()
	var def := _handgun_with("bounce", 1.0)
	def.lifetime = 100.0
	var dir := Vector2(1, 1).normalized()
	var shot := _fire_def(main, def, Vector2(400, 100), dir)
	await ticks(12)
	assert_float(shot.direction.x).is_less(0.0)
	assert_float(shot.direction.y).is_equal_approx(dir.y, 0.01)


func test_a_shot_spawned_inside_a_wall_is_gone_at_once() -> void:
	var main := quiet_main()
	var def := _handgun_with("bounce", 3)
	def.lifetime = 100.0
	var shot: WeakRef = weakref(_fire_def(main, def, Vector2(440, 120), Vector2.RIGHT))  # inside the right wall
	await ticks(2)
	assert_bool(_is_gone(shot)).is_true()  # hit_from_inside, and a zero normal is never bounced off


func test_a_bouncing_shot_comes_back_off_the_top_wall() -> void:
	var main := quiet_main()
	var def := _handgun_with("bounce", 1)
	def.lifetime = 100.0
	var shot := _fire_def(main, def, Vector2(100, 60), Vector2.UP)  # the top wall's face is at y 32
	await ticks(15)
	assert_float(shot.direction.y).is_greater(0.0)
	assert_float(absf(shot.direction.x)).is_less(0.01)
	assert_int(shot.bounces).is_equal(0)


func test_a_plain_shot_dies_on_the_closed_exit_door() -> void:
	var main := quiet_main()
	var def: WeaponDef = HANDGUN.duplicate()
	def.lifetime = 100.0
	var shot: WeakRef = weakref(_fire_def(main, def, Vector2(224, 60), Vector2.UP))  # the door gap spans x 208..240
	await ticks(15)
	assert_bool(_is_gone(shot)).is_true()


func test_two_bounces_spend_both_on_two_faces() -> void:
	var main := quiet_main()
	var def := _handgun_with("bounce", 2)
	def.lifetime = 100.0
	var shot := _fire_def(main, def, Vector2(420, 60), Vector2(1, -1).normalized())  # right wall, then the top wall
	var ref: WeakRef = weakref(shot)
	await ticks(20)
	assert_bool(_is_gone(ref)).is_false()
	assert_int(shot.bounces).is_equal(0)
	assert_float(shot.direction.x).is_less(0.0)
	assert_float(shot.direction.y).is_greater(0.0)


func test_enemy_bolt_dies_on_a_wall_too() -> void:
	var main := quiet_main()
	var bolt: Projectile = auto_free(load("res://scenes/enemies/enemy_bolt.tscn").instantiate())
	bolt.setup(load("res://data/weapons/shaman_bolt.tres"), Vector2.RIGHT)
	projectiles_of(main).add_child(bolt)
	bolt.global_position = Vector2(420, 120)
	var ref: WeakRef = weakref(bolt)  # weakref() returns Variant
	await ticks(15)  # 120 px/s over 12 px
	assert_bool(_is_gone(ref)).is_true()


func test_a_homing_shot_turns_toward_a_live_enemy_in_range() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var enemy := active_chaser_on(main, player.global_position + Vector2(70, -50))
	var def := _handgun_with("homing", 1.0)
	def.lifetime = 100.0
	def.projectile_speed = 100.0
	var shot := _fire_def(main, def, player.global_position, Vector2.RIGHT)
	await ticks(10)
	assert_float(shot.direction.y).is_less(-0.3)  # turned up toward the enemy: 4 rad/s over 0.17 s is 0.67 rad
	assert_float(shot.rotation).is_equal_approx(shot.direction.angle(), 0.001)
	enemy.health.take_damage(100.0)
	var heading := shot.direction
	await ticks(3)
	assert_vector(shot.direction).is_equal_approx(heading, Vector2(0.001, 0.001))  # a dead enemy is not a target


func test_a_plain_shot_flies_straight_past_an_enemy() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	active_chaser_on(main, player.global_position + Vector2(70, -50))
	var def: WeaponDef = HANDGUN.duplicate()
	def.projectile_speed = 100.0
	var shot := _fire_def(main, def, player.global_position, Vector2.RIGHT)
	await ticks(10)
	assert_vector(shot.direction).is_equal(Vector2.RIGHT)


func test_homing_ignores_enemies_out_of_range() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	active_chaser_on(main, player.global_position + Vector2(-100, -100))  # 141 px away, range is 120
	var def := _handgun_with("homing", 1.0)
	def.projectile_speed = 10.0
	var shot := _fire_def(main, def, player.global_position, Vector2.RIGHT)
	await ticks(5)
	assert_vector(shot.direction).is_equal(Vector2.RIGHT)


func test_a_bolt_draws_the_tileset_arrow_along_its_direction() -> void:
	var main := quiet_main()
	var crossbow: WeaponDef = load("res://data/weapons/crossbow.tres")
	var shot := _fire_def(main, crossbow, Vector2(224, 120), Vector2.DOWN)
	var sprite: Sprite2D = shot.get_node_or_null("Bolt")
	assert_object(sprite).is_not_null()
	assert_that(sprite.texture.region).is_equal(SpriteAtlas.region("weapon_arrow"))
	assert_float(sprite.rotation).is_equal_approx(PI / 2.0, 0.001)  # the arrow art points up; +90 degrees points it along +x
	assert_float(shot.rotation).is_equal_approx(PI / 2.0, 0.001)  # the shot itself points down
	var bullet := _fire_def(main, HANDGUN, Vector2(224, 120), Vector2.RIGHT)
	assert_object(bullet.get_node_or_null("Bolt")).is_null()


# --- Unit-level hit handling (no physics; _on_body_entered called directly) ---


func _unit_shot() -> Projectile:
	var shot: Projectile = auto_free(PROJECTILE.instantiate())
	add_child(shot)
	return shot


func _unit_target() -> Node2D:
	var body: Node2D = auto_free(Node2D.new())
	var health := Health.new()
	health.name = "Health"
	health.setup(3.0)
	body.add_child(health)
	return body


func test_hit_damages_health_and_frees_projectile() -> void:
	var shot := _unit_shot()
	shot.damage = 2.0
	shot.pierce = 0
	var body := _unit_target()
	shot._on_body_entered(body)
	assert_float(body.get_node("Health").hp).is_equal(1.0)
	assert_bool(shot.is_queued_for_deletion()).is_true()


func test_pierce_keeps_projectile_alive_for_extra_hits() -> void:
	var shot := _unit_shot()
	shot.pierce = 1
	shot._on_body_entered(_unit_target())
	assert_bool(shot.is_queued_for_deletion()).is_false()
	shot._on_body_entered(_unit_target())
	assert_bool(shot.is_queued_for_deletion()).is_true()


func test_body_without_health_is_ignored() -> void:
	var shot := _unit_shot()
	var plain: Node2D = auto_free(Node2D.new())
	shot._on_body_entered(plain)
	assert_bool(shot.is_queued_for_deletion()).is_false()
