class_name Projectile
extends Area2D
## A shot. Player shots (layer 4) damage bodies with a Health child; enemy bolts (layer 8) are
## found by the player's hurtbox instead. Moves by raycast: every tick it casts from where it is
## to where it is going against the walls layer, so no speed tunnels through a wall, and a shot
## with bounces left reflects off the wall instead of dying. Neither shape masks walls any more.
## The edge of the view (View.rect) is a wall for shots too (the arena's rule 1, ViewRules.exit):
## a player shot bounces off it or dies there, an enemy bolt dies there, quietly (shot_left_view,
## not the wall's signal). Homing chases only what is inside the view.

const WALL_MASK := 16
## The group every enemy bolt is in (scenes/enemies/enemy_bolt.tscn carries it; the player's shots
## never are): what Favour reads for a dash past a bolt.
const ENEMY_BOLT_GROUP := "enemy_bolts"
const WALL_NUDGE := 0.5  ## px off the wall after a bounce, so the next cast starts in the open
const HOMING_RANGE := 120.0
const HOMING_TURN := 4.0  ## radians per second, per unit of homing
const BOLT_SPRITE := "weapon_arrow"  ## drawn pointing up in the tileset
const BOLT_SCALE := 0.7  ## the arrow art drawn smaller (playtest 2026-09-22: too big); the hit shape is the scene's

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
## A shot carrying several statuses stacks one trail per status (playtest 2026-09-22), in this
## order across the flight line, TRAIL_STACK_GAP px apart, so the embers, the sparkle, and the
## mist read apart; its tint is the average of the tints it carries.
const STATUS_ORDER: Array[String] = ["burn", "stun", "chill"]
const STATUS_TINTS := {"burn": StatusEffects.BURN_TINT, "stun": StatusEffects.STUN_TINT, "chill": StatusEffects.CHILL_TINT}
const TRAIL_STACK_GAP := 2.0

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
## The def id of the enemy that fired an enemy bolt; "" on the player's shots.
var shooter_id := ""

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
		bolt.scale = Vector2.ONE * BOLT_SCALE
		add_child(bolt)
	if burn > 0.0 or stun > 0.0 or chill > 0.0:
		_dress_status()


## The bolt sprite takes the blended tint as its modulate; a bullet has no sprite, so its drawn
## colours take it. Each trail emits backwards along the shot's local +x frame (local_coords off,
## so the particles stay where they were emitted), sits on its own line across the flight (the
## shot's local y, the stack centred on the shot), and frees with the shot as its child;
## show_behind_parent keeps it under the shot. An enemy's own tint stays the priority pick
## (StatusEffects._tint); only the shot blends.
func _dress_status() -> void:
	var strengths: Dictionary = {"burn": burn, "stun": stun, "chill": chill}
	var carried: Array[String] = []
	for status in STATUS_ORDER:
		if float(strengths[status]) > 0.0:
			carried.append(status)
	var blend := Color(0, 0, 0, 0)
	for status in carried:
		blend += STATUS_TINTS[status]
	var tint: Color = blend / carried.size()
	var bolt := get_node_or_null("Bolt") as Sprite2D
	if bolt != null:
		bolt.modulate = tint
	else:
		core_color = tint
		glow_color = Color(tint, glow_color.a)
	for i in carried.size():
		var trail := _trail(carried[i])
		trail.position = Vector2(0, (i - (carried.size() - 1) / 2.0) * TRAIL_STACK_GAP)
		add_child(trail)


## One status's trail: the burn embers rise, the stun sparkle is sparse and wide, the chill mist
## drifts straight back.
func _trail(status: String) -> CPUParticles2D:
	var trail := CPUParticles2D.new()
	trail.name = "Trail_" + status
	trail.show_behind_parent = true
	trail.local_coords = false
	trail.amount = TRAIL_STUN_AMOUNT if status == "stun" else TRAIL_AMOUNT
	trail.lifetime = TRAIL_LIFETIME
	trail.direction = Vector2.LEFT
	trail.spread = TRAIL_STUN_SPREAD if status == "stun" else TRAIL_SPREAD
	trail.initial_velocity_min = TRAIL_SPEED_MIN
	trail.initial_velocity_max = TRAIL_SPEED_MAX
	trail.gravity = TRAIL_BURN_GRAVITY if status == "burn" else Vector2.ZERO
	trail.scale_amount_min = TRAIL_SCALE_MIN
	trail.scale_amount_max = TRAIL_SCALE_MAX
	trail.color = STATUS_TINTS[status]
	trail.scale_amount_curve = Fx.fade_scale()
	trail.color_ramp = Fx.fade_ramp()
	trail.emitting = true
	return trail


## Where the shot is heading and how fast, px a second. An enemy bolt flies straight (no homing,
## no bounce on the shaman bolt), so this holds until it lands.
func velocity() -> Vector2:
	return direction * speed


func _physics_process(delta: float) -> void:
	var view := View.rect(self)
	if homing > 0.0:
		_steer(delta, view)
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	query.hit_from_inside = true  # fired from inside a wall (muzzle pressed to it): dies at once
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if not _strike(hit.position, hit.normal):
			return
	else:
		# Rule 1: the edge of the view is a wall for shots. Only when the wall's ray found nothing,
		# so a step reaching both ends on the wall, once.
		var edge := ViewRules.exit(view, from, to)
		if not edge.hit:
			global_position = to
		elif not _leave_view(edge.at, edge.normal, not ViewRules.contains(view, from)):
			return
	life -= delta
	if life <= 0.0:
		despawn()


## Turns toward the nearest live enemy in range inside `view`, at HOMING_TURN per unit of homing.
func _steer(delta: float, view: Rect2) -> void:
	var target := _nearest_enemy(view)
	if target == null:
		return
	var wanted := (target.global_position - global_position).angle()
	direction = Vector2.from_angle(rotate_toward(direction.angle(), wanted, HOMING_TURN * homing * delta))
	rotation = direction.angle()


## Reads the enemies group as plain Node2Ds and must not name the Enemy class: enemy.gd preloads
## the bolt scene, which carries this script, so naming Enemy here would close a load cycle.
## A dying enemy leaves the group, so a corpse is never a target; one outside `view` (View.rect)
## is not one either: a shot never chases what the player cannot see.
func _nearest_enemy(view: Rect2) -> Node2D:
	var best: Node2D = null
	var best_distance := HOMING_RANGE * HOMING_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not ViewRules.contains(view, enemy.global_position):
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
	# A shielded enemy stops a shot arriving inside its front arc (duck-typed: naming Enemy here
	# would close the load cycle _nearest_enemy describes). A shot with a bounce left reflects
	# off the shield, the facing (read duck-typed) as the surface normal. Inside a physics
	# callback: only the emit, the turn and nudge, and the deferred despawn, nothing added or
	# freed here. The shot still overlaps the body, so body_entered does not fire for it again
	# until the shot has left it: after that it can land on anything, the same enemy's back
	# included.
	if body.has_method("blocks_shot") and body.call("blocks_shot", direction, pierce):
		if bounces > 0:
			var facing: Vector2 = body.get("facing")
			var at := global_position
			_bounce(ShieldRules.bounce(direction, facing), facing.normalized(), at)
			Events.shot_deflected.emit(at)
			return
		Events.shot_blocked.emit(global_position)
		despawn()
		return
	# A body may take a shot harder from one side (a skidding charger's back): asked duck-typed
	# as blocks_shot is, after it.
	var factor := 1.0
	if body.has_method("damage_scale"):
		factor = float(body.call("damage_scale", direction))
	health.take_damage(damage * factor, direction * knockback)
	var status := body.get_node_or_null("Status") as StatusEffects
	if status != null:
		status.apply_from(self)
	_hits += 1
	if _hits > pierce:
		despawn()


## The shot meets a wall at `at` with the wall's unit `normal`: with a bounce left and a normal
## (a shot fired from inside a wall has none) it ricochets (shot_bounced) and flies on, true;
## otherwise it stops there (shot_hit_wall) and despawns, false.
func _strike(at: Vector2, normal: Vector2) -> bool:
	if bounces > 0 and normal != Vector2.ZERO:
		_bounce(direction.bounce(normal), normal, at)
		Events.shot_bounced.emit(at)
		return true
	global_position = at
	Events.shot_hit_wall.emit(at)
	despawn()
	return false


## The shot meets the edge of the view at `at` (ViewRules.exit's: on the view, also for a shot
## the edge swept over) with exit's inward `normal`; `swept` when the step began outside the view.
## A player shot swept over while already heading in on every axis the normal names is carried:
## put back on the view, no bounce spent, nothing emitted, true (the view walking past a slow shot
## would otherwise spend a bounce every frame; a shot carried comes back on screen when the view
## stops). A player shot with a bounce left comes back in (ViewRules.reflect, so a corner reverses
## both components; shot_bounced, as off a wall) and flies on, true. Anything else (an enemy bolt,
## a shot with no bounce, no normal) stops there quietly (shot_left_view, not shot_hit_wall: no
## clink at a wall nobody sees) and despawns, false.
func _leave_view(at: Vector2, normal: Vector2, swept: bool) -> bool:
	var bolt := is_in_group(ENEMY_BOLT_GROUP)
	if swept and not bolt and normal != Vector2.ZERO \
			and direction.x * normal.x >= 0.0 and direction.y * normal.y >= 0.0:
		global_position = at + normal.normalized() * WALL_NUDGE
		return true
	if bounces > 0 and normal != Vector2.ZERO and not bolt:
		_bounce(ViewRules.reflect(direction, normal), normal.normalized(), at)
		Events.shot_bounced.emit(at)
		return true
	global_position = at
	Events.shot_left_view.emit(at)
	despawn()
	return false


## One ricochet, off a wall, the edge of the view, or a shield: a bounce spent, the shot turned to
## `reflected`, and nudged WALL_NUDGE out from `at` along the surface's unit `normal`. The caller
## emits its signal (shot_bounced for a wall or the edge, shot_deflected for a shield).
func _bounce(reflected: Vector2, normal: Vector2, at: Vector2) -> void:
	bounces -= 1
	direction = reflected
	rotation = direction.angle()
	global_position = at + normal * WALL_NUDGE


func despawn() -> void:
	set_deferred("monitoring", false)
	queue_free()
