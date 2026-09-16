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

## The status trail: a shot carrying burn, stun, or chill is tinted with the StatusEffects colour
## and drags a continuous particle trail behind it, so flaming, shock, and chill bolts read apart
## in flight (playtest 1). Cosmetic: the particles use the engine's own RNG.
const TRAIL_AMOUNT := 24  ## 12 read as a few scattered specks at 3x zoom
const TRAIL_LIFETIME := 0.35
const TRAIL_SPREAD := 20.0
const TRAIL_SPEED_MIN := 10.0
const TRAIL_SPEED_MAX := 30.0
const TRAIL_SCALE_MIN := 1.5
const TRAIL_SCALE_MAX := 2.5
const TRAIL_BURN_GRAVITY := Vector2(0, -40)  ## embers rise
const TRAIL_STUN_AMOUNT := 12  ## a sparser sparkle
const TRAIL_STUN_SPREAD := 60.0

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


## Call it before add_child: _ready builds the look from `look`.
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
	if burn > 0.0 or stun > 0.0 or chill > 0.0:
		_dress_status()


## Stun over burn over chill, the order StatusEffects._tint paints an enemy. The bolt sprite takes
## the tint as its modulate; a bullet has no sprite, so its drawn colours take it. The Trail emits
## backwards along the shot's local +x frame (local_coords off, so the particles stay where they
## were emitted) and frees with the shot as its child; show_behind_parent keeps it under the shot.
func _dress_status() -> void:
	var tint := StatusEffects.CHILL_TINT
	if stun > 0.0:
		tint = StatusEffects.STUN_TINT
	elif burn > 0.0:
		tint = StatusEffects.BURN_TINT
	var bolt := get_node_or_null("Bolt") as Sprite2D
	if bolt != null:
		bolt.modulate = tint
	else:
		core_color = tint
		glow_color = Color(tint, glow_color.a)
	var trail := CPUParticles2D.new()
	trail.name = "Trail"
	trail.show_behind_parent = true
	trail.local_coords = false
	trail.amount = TRAIL_STUN_AMOUNT if stun > 0.0 else TRAIL_AMOUNT
	trail.lifetime = TRAIL_LIFETIME
	trail.direction = Vector2.LEFT
	trail.spread = TRAIL_STUN_SPREAD if stun > 0.0 else TRAIL_SPREAD
	trail.initial_velocity_min = TRAIL_SPEED_MIN
	trail.initial_velocity_max = TRAIL_SPEED_MAX
	trail.gravity = TRAIL_BURN_GRAVITY if tint == StatusEffects.BURN_TINT else Vector2.ZERO
	trail.scale_amount_min = TRAIL_SCALE_MIN
	trail.scale_amount_max = TRAIL_SCALE_MAX
	trail.color = tint
	trail.scale_amount_curve = Fx.fade_scale()
	trail.color_ramp = Fx.fade_ramp()
	trail.emitting = true
	add_child(trail)


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
			Events.shot_bounced.emit(at)
		else:
			global_position = at
			Events.shot_hit_wall.emit(at)
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
	var status := body.get_node_or_null("Status") as StatusEffects
	if status != null:
		status.apply_from(self)
	_hits += 1
	if _hits > pierce:
		despawn()


func despawn() -> void:
	set_deferred("monitoring", false)
	queue_free()
