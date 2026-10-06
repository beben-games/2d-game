class_name Enemy
extends CharacterBody2D
## Generic enemy body driven by an EnemyDef. The Chaser is this script with the chaser def; the
## Shooter is the same script delegating its ACTIVE movement and firing to a ShooterBrain, the
## Charger to a ChargerBrain (the wind-up's line, the run, the skid).
## State machine: SPAWNING (fade in, harmless) -> ACTIVE (chase, shoot, or charge) -> DEAD.

enum State { SPAWNING, ACTIVE, DEAD }

const FLASH_SHADER := preload("res://assets/shaders/flash.gdshader")
const KNOCKBACK_DECAY := 700.0
const HIT_TRAUMA := 0.2
const DEATH_TRAUMA := 0.45  # hit + kill on the last shot lands at 0.65
const DEATH_HITSTOP := 0.06
const ENEMY_BOLT := preload("res://scenes/enemies/enemy_bolt.tscn")
const BOLT_MUZZLE := 8.0
const TELEGRAPH_FLASH := 0.6
const RECOVER_JITTER := 0.15  ## up to this much is added to each recover, drawn from the gameplay RNG
## The shield (playtest 1): a shot that could pierce this many enemies passes the front arc. The
## handgun's Piercing bullets reaches 1, so it never does; the crossbow's base 2 plus one Deep
## pierce rank does.
const SHIELD_PIERCE := 3
## The charge: the body's mask while it runs (walls only, so it passes through enemies and the
## player's body; it stays on layer 2, so the hurtbox and the shots still find it), and the shake
## when a wall stops it.
const CHARGE_MASK := 16
const CHARGE_WALL_TRAUMA := 0.15

@export var def: EnemyDef

var target: Node2D
var state := State.SPAWNING
var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var flash_material: ShaderMaterial
## The behaviour's brain, chosen by def.behavior: a ShooterBrain, a ChargerBrain, or null (a
## chaser). Held as a RefCounted: the two share no base, and each tick casts to its own.
var brain: RefCounted
## Where bolts go. The Spawner injects the room's container; hand-placed enemies fall back to the
## group lookup.
var projectile_parent: Node
## The shield's facing (a unit vector; only read when def.shield). Seeded toward the target on
## the first physics tick (the spawner and the tests place the body after add_child, so _ready
## sees the origin), then turned toward the movement each ACTIVE tick at def.shield_turn_degrees
## per second; a stun holds it.
var facing := Vector2.RIGHT
var shield_arc: ShieldArc  ## set only when def.shield
## The charge's direction: fixed at the wind-up's first tick (toward the target then), the run's
## lane and the skid's facing (its back is -charge_dir). Read only for a charger.
var charge_dir := Vector2.LEFT
var charge_line: ChargeLine  ## set only for chargers: the path shown through the wind-up

var _state_time := 0.0
var _facing_seeded := false
var _body_mask := 0  ## the scene's mask, put back when a charge ends
var _passed: Array[PhysicsBody2D] = []  ## the bodies a run passes through (collision exceptions)
var _flash_tween: Tween
var _pulse_tween: Tween
var _shiver_tween: Tween

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var status: StatusEffects = $Status


func _ready() -> void:
	assert(def != null, "Enemy needs an EnemyDef")
	var errors := def.validate()
	assert(errors.is_empty(), "Invalid enemy def: %s" % ", ".join(errors))
	health.setup(def.max_hp)
	sprite.sprite_frames = SpriteAtlas.frames({"idle": def.idle_anim, "run": def.run_anim})
	sprite.offset = def.sprite_offset
	sprite.play("idle")
	flash_material = ShaderMaterial.new()
	flash_material.shader = FLASH_SHADER
	flash_material.set_shader_parameter("flash", 0.0)  # a tween needs the uniform to exist already
	sprite.material = flash_material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	_body_mask = collision_mask
	match def.behavior:
		EnemyDef.Behavior.SHOOTER:
			brain = ShooterBrain.new()
		EnemyDef.Behavior.CHARGER:
			brain = ChargerBrain.new()
			charge_line = ChargeLine.new()
			add_child(charge_line)
			move_child(charge_line, 0)  # under the sprite
	if projectile_parent == null:
		projectile_parent = get_tree().get_first_node_in_group("projectiles")
	if projectile_parent == null:
		projectile_parent = get_parent()
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, def.spawn_delay)
	if def.shield:
		# A sibling of the sprite, not its child: StatusEffects._tint writes sprite.modulate.
		# It fades in with the sprite so no arc shows before the body it covers.
		shield_arc = ShieldArc.new()
		shield_arc.name = "ShieldArc"
		shield_arc.arc_degrees = def.shield_arc_degrees
		shield_arc.modulate.a = 0.0
		add_child(shield_arc)
		create_tween().tween_property(shield_arc, "modulate:a", 1.0, def.spawn_delay)


func is_harmful() -> bool:
	return state == State.ACTIVE


## The HUD's arrow for this body while it is off screen (OffscreenArrows, asked duck-typed).
func arrow_kind() -> String:
	return "enemy"


## True when a player shot flying along `direction` with `pierce` would be stopped by the shield:
## the shield is on, the body is not a corpse, and ShieldRules says the shot is inside the arc.
## Projectile calls it duck-typed inside body_entered; the boss has no such method.
func blocks_shot(direction: Vector2, pierce: int) -> bool:
	if not def.shield or state == State.DEAD:
		return false
	_seed_facing()  # a shot on the spawn tick, before the first physics step, asks too
	return ShieldRules.blocks(facing, direction, pierce, def.shield_arc_degrees, SHIELD_PIERCE)


## The first facing: toward the target, once the body is where it was placed (after add_child).
func _seed_facing() -> void:
	if _facing_seeded or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return
	facing = to_target.normalized()
	_facing_seeded = true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	var to_target := Vector2.ZERO
	if is_instance_valid(target):
		to_target = target.global_position - global_position
	if def.shield:
		_seed_facing()
	match state:
		State.SPAWNING:
			if _state_time >= def.spawn_delay:
				_enter(State.ACTIVE)
		State.ACTIVE:
			var wish := to_target
			var charger := brain as ChargerBrain
			var shooter := brain as ShooterBrain
			if charger != null:
				wish = _charger_tick(charger, delta, to_target)
			elif status.stunned():
				wish = Vector2.ZERO  # a stunned shooter's cycle waits too: the brain does not tick
				if shooter != null and shooter.phase == ShooterBrain.Phase.TELEGRAPH:
					_interrupt_telegraph()
			elif shooter != null:
				# Rule 2: a wind-up begins only on the screen itself; off it the brain walks at the player.
				var visible := View.on_screen(self)
				var phase_before := shooter.phase
				var fire := shooter.tick(delta, to_target.length(), def, visible)
				if shooter.phase == ShooterBrain.Phase.TELEGRAPH and phase_before != shooter.phase:
					_telegraph_fx(def.telegraph_time)
				if shooter.phase == ShooterBrain.Phase.RECOVER and phase_before != shooter.phase:
					shooter.recover_extra = RunState.rng.randf_range(0.0, RECOVER_JITTER)
				if fire and is_instance_valid(target):
					_fire_bolt(to_target.normalized())
				wish = shooter.wish(to_target, def, visible)
			# The shield turns toward where the body is going (or the target when standing) before
			# the arc reads it; a stunned shield holds and a chilled one turns as slowly as it
			# walks, so a stun or a chill is a window on its back.
			if def.shield and not status.stunned():
				var turn := def.shield_turn_degrees * status.speed_multiplier() * delta
				facing = ShieldRules.turn(facing, wish if wish != Vector2.ZERO else to_target, turn)
			if charger != null and charger.charging():
				_pass_through_bodies()
				move_vel = charge_dir * def.charge_speed * status.speed_multiplier()
			else:
				var speed := def.speed * status.speed_multiplier()
				move_vel = Movement.step(move_vel, wish, speed, def.accel, def.accel, delta)
			# Out of its approach a charger faces its lane, not the player.
			var face := charge_dir if charger != null and charger.phase != ChargerBrain.Phase.APPROACH else to_target
			if face.x != 0.0:
				sprite.flip_h = face.x < 0.0
			sprite.play("run" if Movement.is_moving(move_vel) else "idle")
	if shield_arc != null:
		shield_arc.rotation = facing.angle()
	# Knockback decays and moves the body in every live state, so a hit taken while spawning
	# shoves the enemy immediately instead of being stored up and released on activation.
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()
	var runner := brain as ChargerBrain  # a wall met by the slide ends a run
	if runner != null and runner.charging() and _hit_wall() and runner.end_charge() == ChargerBrain.SKID:
		_end_charge()
		Juice.add_trauma(CHARGE_WALL_TRAUMA)


## One ACTIVE tick of a charger's brain; returns the movement wish (the run itself is charge_dir).
## A stun cuts a wind-up (the line and the pulses go; the next one starts from zero) and ends a
## run into the skid; otherwise the brain waits it out, as the shooter's does.
func _charger_tick(charger: ChargerBrain, delta: float, to_target: Vector2) -> Vector2:
	if status.stunned():
		match charger.phase:
			ChargerBrain.Phase.WINDUP:
				_interrupt_telegraph()
			ChargerBrain.Phase.CHARGE:
				if charger.interrupt() == ChargerBrain.SKID:
					_end_charge()
		return Vector2.ZERO
	# Rule 2: a wind-up begins only on the screen itself; off it the brain walks at the player.
	match charger.tick(delta, to_target.length(), def, View.on_screen(self)):
		ChargerBrain.WINDUP:
			_begin_windup(to_target)
		ChargerBrain.CHARGE:
			_begin_charge()
		ChargerBrain.SKID:
			_end_charge()
	return charger.wish(to_target)


## The wind-up's first tick: the lane fixed toward the target as it is now, the line laid along
## it as far as the run reaches or the first wall, and the telegraph's pulses over the wind-up.
func _begin_windup(to_target: Vector2) -> void:
	if to_target != Vector2.ZERO:
		charge_dir = to_target.normalized()
	charge_line.setup(Vector2.ZERO, charge_dir, _clear_reach(charge_dir))
	charge_line.show_line(def.windup_time)
	_telegraph_fx(def.windup_time)


## How far the run goes along `direction` before a wall (the walls' layer, as a shot's ray): the
## full reach when none is in the way.
func _clear_reach(direction: Vector2) -> float:
	var full := ChargerBrain.reach(def)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * full, Projectile.WALL_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return full
	return global_position.distance_to(hit["position"])


func _begin_charge() -> void:
	charge_line.hide_line()
	collision_mask = CHARGE_MASK
	Events.enemy_charged.emit(self)


## The run passes through the other enemies and the player's body both ways. Its mask (walls
## only) keeps the run from stopping on them, but their own move_and_slide still masks layer 2
## and would push them out of the body every tick, carrying a chaser or the player along in
## front of it; a collision exception (honoured from either side) keeps them where they stand.
## Every tick of the run, so a body spawned mid-run is passed too.
func _pass_through_bodies() -> void:
	for group: String in ["enemies", "player"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as PhysicsBody2D
			if body == null or body == self or _passed.has(body):
				continue
			add_collision_exception_with(body)
			_passed.append(body)


func _stop_passing_through() -> void:
	for body in _passed:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	_passed.clear()


## The run over (its time, a wall, or a stun): the body stops dead, solid to the others again.
func _end_charge() -> void:
	collision_mask = _body_mask
	_stop_passing_through()
	move_vel = Vector2.ZERO
	Events.enemy_skidded.emit(self)


## Only a wall ends a charge (the boss's rule): the slide's colliders filtered to StaticBody2D
## (the arena's walls, a door's blocker); the run's mask already holds nothing else.
func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody2D:
			return true
	return false


## What a player shot flying along `direction` does, as a factor of its damage: a skidding
## charger's back (inside def.back_arc_degrees behind charge_dir) takes def.back_damage_scale;
## everything else 1. Projectile calls it duck-typed before take_damage, after blocks_shot.
func damage_scale(direction: Vector2) -> float:
	var charger := brain as ChargerBrain
	if charger == null or state == State.DEAD or charger.phase != ChargerBrain.Phase.SKID:
		return 1.0
	if ChargerBrain.from_behind(charge_dir, direction, def.back_arc_degrees):
		return def.back_damage_scale
	return 1.0


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


func _on_damaged(amount: float, kb: Vector2) -> void:
	knockback += kb
	Events.enemy_hit.emit(self, amount, global_position)
	if health.last_hit_quiet:
		return  # a burn tick: no flash, no shake; the tint is the feedback
	# A hit mid-telegraph: the white hit flash wins over the pulse; the shiver still carries the
	# telegraph.
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_flash_tween = Juice.flash(flash_material)
	Juice.add_trauma(HIT_TRAUMA)


## A stun mid-telegraph cuts the attack: the brain goes back to APPROACH and the wind-up effects
## stop (a charger's line too), so after the stun the shooter telegraphs again in full instead of
## firing out of nowhere, and a charger lays a fresh line.
## The hit that carried the stun has already killed the pulse and owns the flash uniform through
## its own fade; only a pulse still running is cut and zeroed here.
func _interrupt_telegraph() -> void:
	brain.call("interrupt")
	if charge_line != null:
		charge_line.hide_line()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		flash_material.set_shader_parameter("flash", 0.0)
	if _shiver_tween != null and _shiver_tween.is_valid():
		_shiver_tween.kill()
	sprite.offset = def.sprite_offset


## Two white pulses and a shiver over the wind-up's `duration` so the attack is never a surprise.
func _telegraph_fx(duration: float) -> void:
	Events.enemy_telegraphed.emit(self)
	var half := duration * 0.5
	_pulse_tween = create_tween()
	for i in 2:
		_pulse_tween.tween_property(flash_material, "shader_parameter/flash", TELEGRAPH_FLASH, half * 0.4)
		_pulse_tween.tween_property(flash_material, "shader_parameter/flash", 0.0, half * 0.6)
	_shiver_tween = create_tween()
	_shiver_tween.set_loops(maxi(1, int(duration / 0.1)))  # set_loops(0) would loop forever
	_shiver_tween.tween_property(sprite, "offset:x", def.sprite_offset.x + 1.0, 0.05)
	_shiver_tween.tween_property(sprite, "offset:x", def.sprite_offset.x - 1.0, 0.05)
	_shiver_tween.finished.connect(func() -> void: sprite.offset = def.sprite_offset)


func _fire_bolt(dir: Vector2) -> void:
	var bolt: Projectile = ENEMY_BOLT.instantiate()
	bolt.setup(def.bolt, dir)
	bolt.shooter_id = def.id
	projectile_parent.add_child(bolt)
	bolt.global_position = global_position + dir * BOLT_MUZZLE
	Events.enemy_fired.emit(self, bolt.global_position)


func _on_died() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	_stop_passing_through()
	remove_from_group("enemies")  # a corpse is not a homing target
	set_physics_process(false)
	if shield_arc != null:
		shield_arc.visible = false  # a corpse blocks nothing, so it shows no cover
	if charge_line != null:
		charge_line.hide_line()  # a corpse charges nowhere
	status.set_physics_process(false)  # no burn ticks or tints on a corpse
	status.stop_effects()
	# Hold the white impact pose for the whole kill freeze, then vanish. The hit that killed us
	# just started a fade tween; stop it so the pose stays fully lit.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# A shooter killed mid-telegraph must not keep pulsing or shivering either.
	for tween in [_pulse_tween, _shiver_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	sprite.offset = def.sprite_offset
	flash_material.set_shader_parameter("flash", 1.0)
	Events.enemy_died.emit(self, global_position)
	Juice.add_trauma(DEATH_TRAUMA)
	Juice.hitstop(DEATH_HITSTOP)
	await get_tree().create_timer(DEATH_HITSTOP, true, false, true).timeout
	# A scene reload during the freeze may already have queued us; queue_free works out of tree.
	if not is_queued_for_deletion():
		queue_free()
