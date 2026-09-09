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
