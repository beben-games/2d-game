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

var _state_time := 0.0
var _flash_tween: Tween
var _pulse_tween: Tween
var _shiver_tween: Tween

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health


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
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, def.spawn_delay)


func is_harmful() -> bool:
	return state == State.ACTIVE


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	match state:
		State.SPAWNING:
			if _state_time >= def.spawn_delay:
				_enter(State.ACTIVE)
		State.ACTIVE:
			var to_target := Vector2.ZERO
			if is_instance_valid(target):
				to_target = target.global_position - global_position
			var wish := to_target
			if brain != null:
				var phase_before := brain.phase
				var fire := brain.tick(delta, to_target.length(), def)
				if brain.phase == ShooterBrain.Phase.TELEGRAPH and phase_before != brain.phase:
					_telegraph_fx()
				if fire and is_instance_valid(target):
					_fire_bolt(to_target.normalized())
				wish = brain.wish(to_target, def)
			move_vel = Movement.step(move_vel, wish, def.speed, def.accel, def.accel, delta)
			if to_target.x != 0.0:
				sprite.flip_h = to_target.x < 0.0
			sprite.play("run" if Movement.is_moving(move_vel) else "idle")
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
	# A hit mid-telegraph: the white hit flash wins over the pulse; the shiver still carries the
	# telegraph.
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_flash_tween = Juice.flash(flash_material)
	Juice.add_trauma(HIT_TRAUMA)
	Events.enemy_hit.emit(self, amount, global_position)


## Two white pulses and a shiver over the telegraph so the shot is never a surprise.
func _telegraph_fx() -> void:
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


func _on_died() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
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
