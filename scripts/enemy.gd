class_name Enemy
extends CharacterBody2D
## Generic enemy body driven by an EnemyDef. The Chaser is this script with the chaser def.
## State machine: SPAWNING (fade in, harmless) -> ACTIVE (chase) -> DEAD.

enum State { SPAWNING, ACTIVE, DEAD }

const FLASH_SHADER := preload("res://assets/shaders/flash.gdshader")
const KNOCKBACK_DECAY := 700.0
const HIT_TRAUMA := 0.2
const DEATH_TRAUMA := 0.45  # hit + kill on the last shot lands at 0.65
const DEATH_HITSTOP := 0.06

@export var def: EnemyDef

var target: Node2D
var state := State.SPAWNING
var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var flash_material: ShaderMaterial

var _state_time := 0.0
var _flash_tween: Tween

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
	sprite.material = flash_material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group("player")
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
			var wish := Vector2.ZERO
			if is_instance_valid(target):
				wish = target.global_position - global_position
			move_vel = Movement.step(move_vel, wish, def.speed, def.accel, def.accel, delta)
			if wish.x != 0.0:
				sprite.flip_h = wish.x < 0.0
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
	_flash_tween = Juice.flash(flash_material)
	Juice.add_trauma(HIT_TRAUMA)
	Events.enemy_hit.emit(self, amount, global_position)


func _on_died() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	# Hold the white impact pose for the whole kill freeze, then vanish. The hit that killed us
	# just started a fade tween; stop it so the pose stays fully lit.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_material.set_shader_parameter("flash", 1.0)
	Events.enemy_died.emit(self, global_position)
	Juice.add_trauma(DEATH_TRAUMA)
	Juice.hitstop(DEATH_HITSTOP)
	await get_tree().create_timer(DEATH_HITSTOP, true, false, true).timeout
	# A scene reload during the freeze may already have queued us; queue_free works out of tree.
	if not is_queued_for_deletion():
		queue_free()
