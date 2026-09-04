class_name Player
extends CharacterBody2D
## The hero: movement and shooting. Health arrives in Task 12.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const KNOCKBACK_DECAY := 900.0
const MUZZLE_DISTANCE := 8.0
const SPRITE_OFFSET := Vector2(0, -6)  ## Sprite is drawn this far from the body so the feet sit on the collider.
const ANIMATIONS := {"idle": "knight_m_idle_anim", "run": "knight_m_run_anim"}

@export var weapon: WeaponDef

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var fire := FireController.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	assert(weapon != null, "Player needs a WeaponDef")
	var errors := weapon.validate()
	assert(errors.is_empty(), "Invalid weapon: %s" % ", ".join(errors))
	sprite.sprite_frames = SpriteAtlas.frames(ANIMATIONS)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_vel = Movement.step(move_vel, wish, MAX_SPEED, ACCEL, FRICTION, delta)
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()

	var aim_dir := aim_direction()
	sprite.flip_h = aim_dir.x < 0.0
	muzzle.position = SPRITE_OFFSET + aim_dir * MUZZLE_DISTANCE
	sprite.play("run" if Movement.is_moving(move_vel) else "idle")

	fire.tick(delta)
	if Input.is_action_pressed("shoot") and fire.try_fire(weapon.fire_rate):
		_shoot(aim_dir)


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT


## Projectiles go to the player's parent (Main) so they do not move with the player.
func _shoot(dir: Vector2) -> void:
	var base_angle := dir.angle()
	var jitter := deg_to_rad(weapon.inaccuracy_degrees)
	for offset in WeaponDef.spread_offsets(weapon.projectile_count, deg_to_rad(weapon.spread_degrees)):
		var angle := base_angle + offset + RunState.rng.randf_range(-jitter, jitter)
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(weapon, Vector2.from_angle(angle))
		shot.global_position = muzzle.global_position
		get_parent().add_child(shot)
	knockback -= dir * weapon.recoil
	Events.shot_fired.emit(muzzle.global_position, dir)
