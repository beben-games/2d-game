class_name Enemy
extends CharacterBody2D
## Generic enemy body driven by an EnemyDef. The Chaser is this script with the chaser def; the
## Shooter is the same script delegating its ACTIVE movement and firing to a ShooterBrain.
## State machine: SPAWNING (fade in, harmless) -> ACTIVE (chase or shoot) -> DEAD.

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

@export var def: EnemyDef

var target: Node2D
var state := State.SPAWNING
var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var flash_material: ShaderMaterial
var brain: ShooterBrain  ## set only for shooters
## Where bolts go. The Spawner injects the room's container; hand-placed enemies fall back to the
## group lookup.
var projectile_parent: Node
## The shield's facing (a unit vector; only read when def.shield). Seeded toward the target on
## the first physics tick (the spawner and the tests place the body after add_child, so _ready
## sees the origin), then turned toward the movement each ACTIVE tick at def.shield_turn_degrees
## per second; a stun holds it.
var facing := Vector2.RIGHT
var shield_arc: ShieldArc  ## set only when def.shield

var _state_time := 0.0
var _facing_seeded := false
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
	if def.behavior == EnemyDef.Behavior.SHOOTER:
		brain = ShooterBrain.new()
	if projectile_parent == null:
		projectile_parent = get_tree().get_first_node_in_group("projectiles")
	if projectile_parent == null:
		projectile_parent = get_parent()
	if def.shield:
		shield_arc = ShieldArc.new()
		shield_arc.name = "ShieldArc"
		shield_arc.arc_degrees = def.shield_arc_degrees
		shield_arc.rotation = facing.angle()
		add_child(shield_arc)
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, def.spawn_delay)


func is_harmful() -> bool:
	return state == State.ACTIVE


## True when a player shot flying along `direction` with `pierce` would be stopped by the shield:
## the shield is on, the body is not a corpse, and ShieldRules says the shot is inside the arc.
## Projectile calls it duck-typed inside body_entered; the boss has no such method.
func blocks_shot(direction: Vector2, pierce: int) -> bool:
	if not def.shield or state == State.DEAD:
		return false
	return ShieldRules.blocks(facing, direction, pierce, def.shield_arc_degrees, SHIELD_PIERCE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	var to_target := Vector2.ZERO
	if is_instance_valid(target):
		to_target = target.global_position - global_position
	if def.shield and not _facing_seeded and to_target != Vector2.ZERO:
		facing = to_target.normalized()
		_facing_seeded = true
	match state:
		State.SPAWNING:
			if _state_time >= def.spawn_delay:
				_enter(State.ACTIVE)
		State.ACTIVE:
			var wish := to_target
			if status.stunned():
				wish = Vector2.ZERO  # a stunned shooter's cycle waits too: the brain does not tick
				if brain != null and brain.phase == ShooterBrain.Phase.TELEGRAPH:
					_interrupt_telegraph()
			elif brain != null:
				var phase_before := brain.phase
				var fire := brain.tick(delta, to_target.length(), def)
				if brain.phase == ShooterBrain.Phase.TELEGRAPH and phase_before != brain.phase:
					_telegraph_fx()
				if brain.phase == ShooterBrain.Phase.RECOVER and phase_before != brain.phase:
					brain.recover_extra = RunState.rng.randf_range(0.0, RECOVER_JITTER)
				if fire and is_instance_valid(target):
					_fire_bolt(to_target.normalized())
				wish = brain.wish(to_target, def)
			# The shield turns toward where the body is going (or the target when standing) before
			# the arc reads it; a stunned shield holds, so a stun is a window on its back.
			if def.shield and not status.stunned():
				facing = ShieldRules.turn(facing, wish if wish != Vector2.ZERO else to_target, def.shield_turn_degrees * delta)
			var speed := def.speed * status.speed_multiplier()
			move_vel = Movement.step(move_vel, wish, speed, def.accel, def.accel, delta)
			if to_target.x != 0.0:
				sprite.flip_h = to_target.x < 0.0
			sprite.play("run" if Movement.is_moving(move_vel) else "idle")
	if shield_arc != null:
		shield_arc.rotation = facing.angle()
	# Knockback decays and moves the body in every live state, so a hit taken while spawning
	# shoves the enemy immediately instead of being stored up and released on activation.
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()


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
## stop, so after the stun the shooter telegraphs again in full instead of firing out of nowhere.
## The hit that carried the stun has already killed the pulse and owns the flash uniform through
## its own fade; only a pulse still running is cut and zeroed here.
func _interrupt_telegraph() -> void:
	brain.interrupt()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		flash_material.set_shader_parameter("flash", 0.0)
	if _shiver_tween != null and _shiver_tween.is_valid():
		_shiver_tween.kill()
	sprite.offset = def.sprite_offset


## Two white pulses and a shiver over the telegraph so the shot is never a surprise.
func _telegraph_fx() -> void:
	Events.enemy_telegraphed.emit(self)
	var half := def.telegraph_time * 0.5
	_pulse_tween = create_tween()
	for i in 2:
		_pulse_tween.tween_property(flash_material, "shader_parameter/flash", TELEGRAPH_FLASH, half * 0.4)
		_pulse_tween.tween_property(flash_material, "shader_parameter/flash", 0.0, half * 0.6)
	_shiver_tween = create_tween()
	_shiver_tween.set_loops(maxi(1, int(def.telegraph_time / 0.1)))  # set_loops(0) would loop forever
	_shiver_tween.tween_property(sprite, "offset:x", def.sprite_offset.x + 1.0, 0.05)
	_shiver_tween.tween_property(sprite, "offset:x", def.sprite_offset.x - 1.0, 0.05)
	_shiver_tween.finished.connect(func() -> void: sprite.offset = def.sprite_offset)


func _fire_bolt(dir: Vector2) -> void:
	var bolt: Projectile = ENEMY_BOLT.instantiate()
	bolt.setup(def.bolt, dir)
	projectile_parent.add_child(bolt)
	bolt.global_position = global_position + dir * BOLT_MUZZLE
	Events.enemy_fired.emit(self, bolt.global_position)


func _on_died() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")  # a corpse is not a homing target
	set_physics_process(false)
	if shield_arc != null:
		shield_arc.visible = false  # a corpse blocks nothing, so it shows no cover
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
