class_name Projectile
extends Area2D
## A shot. Player shots (layer 4) damage bodies with a Health child; enemy bolts (layer 8) are
## found by the player's hurtbox instead. Moves by raycast: every tick it casts from where it is
## to where it is going against the walls layer, so no speed tunnels through a wall, and a shot
## with bounces left reflects off the wall instead of dying. Neither shape masks walls any more.

const WALL_MASK := 16
const WALL_NUDGE := 0.5  ## px off the wall after a bounce, so the next cast starts in the open
const HOMING_RANGE := 120.0
const HOMING_TURN := 4.0  ## radians per second, per unit of homing
const BOLT_SPRITE := "weapon_arrow"  ## drawn pointing up in the tileset

@export var core_color := Color(1.0, 0.95, 0.6)
@export var glow_color := Color(1.0, 0.6, 0.2, 0.6)

var direction := Vector2.RIGHT
var speed := 300.0
var damage := 1.0
var knockback := 100.0
var pierce := 0
var life := 1.0
var bounces := 0
var homing := 0.0
var burn := 0.0
var stun := 0.0
var chill := 0.0
var look := WeaponDef.Look.BULLET

var _hits := 0


func setup(def: WeaponDef, dir: Vector2) -> void:
	direction = dir.normalized()
	speed = def.projectile_speed
	damage = def.damage
	knockback = def.knockback
	pierce = def.pierce
	life = def.lifetime
	bounces = def.bounce
	homing = def.homing
	burn = def.burn
	stun = def.stun
	chill = def.chill
	look = def.look
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if look == WeaponDef.Look.BOLT:
		var bolt := Sprite2D.new()
		bolt.name = "Bolt"
		bolt.texture = SpriteAtlas.texture(BOLT_SPRITE)
		bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bolt.rotation = PI / 2.0  # the art points up; the shot's +x is its direction
		add_child(bolt)


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		_steer(delta)
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	query.hit_from_inside = true  # fired from inside a wall (muzzle pressed to it): dies at once
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
	else:
		var normal: Vector2 = hit.normal
		var at: Vector2 = hit.position
		if bounces > 0 and normal != Vector2.ZERO:
			bounces -= 1
			direction = direction.bounce(normal)
			global_position = at + normal * WALL_NUDGE
			rotation = direction.angle()
		else:
			global_position = at
			despawn()
			return
	life -= delta
	if life <= 0.0:
		despawn()


## Turns toward the nearest live enemy in range, at HOMING_TURN per unit of homing.
func _steer(delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var wanted := (target.global_position - global_position).angle()
	direction = Vector2.from_angle(rotate_toward(direction.angle(), wanted, HOMING_TURN * homing * delta))
	rotation = direction.angle()


## Reads the enemies group as plain Node2Ds and must not name the Enemy class: enemy.gd preloads
## the bolt scene, which carries this script, so naming Enemy here would close a load cycle.
## A dying enemy leaves the group, so a corpse is never a target.
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := HOMING_RANGE * HOMING_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var distance := enemy.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _draw() -> void:
	if look != WeaponDef.Look.BULLET:
		return
	draw_circle(Vector2(-4, 0), 2.0, glow_color)
	draw_circle(Vector2.ZERO, 3.0, core_color)


## body_entered can fire for several bodies in one physics step and queue_free is deferred, so a
## shot that has already spent its pierce budget must ignore the rest of the batch.
func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	var health := body.get_node_or_null("Health") as Health
	if health == null:
		return
	health.take_damage(damage, direction * knockback)
	_hits += 1
	if _hits > pierce:
		despawn()


func despawn() -> void:
	set_deferred("monitoring", false)
	queue_free()
