class_name Projectile
extends Area2D
## A player shot. Moves in a straight line, damages the first thing with a Health child it touches.

var direction := Vector2.RIGHT
var speed := 300.0
var damage := 1.0
var knockback := 100.0
var pierce := 0
var life := 1.0

var _hits := 0


func setup(def: WeaponDef, dir: Vector2) -> void:
	direction = dir.normalized()
	speed = def.projectile_speed
	damage = def.damage
	knockback = def.knockback
	pierce = def.pierce
	life = def.lifetime
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		_despawn()


func _draw() -> void:
	draw_circle(Vector2(-4, 0), 2.0, Color(1.0, 0.6, 0.2, 0.6))
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.95, 0.6))


## body_entered can fire for several bodies in one physics step and queue_free is deferred, so a
## shot that has already spent its pierce budget must ignore the rest of the batch.
func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	if body.is_in_group("walls"):
		_despawn()
		return
	var health := body.get_node_or_null("Health") as Health
	if health == null:
		return
	health.take_damage(damage, direction * knockback)
	_hits += 1
	if _hits > pierce:
		_despawn()


func _despawn() -> void:
	set_deferred("monitoring", false)
	queue_free()
