class_name Player
extends CharacterBody2D
## The hero. Movement only for now; shooting and health arrive in later tasks.

const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const MUZZLE_DISTANCE := 8.0
const SPRITE_OFFSET := Vector2(0, -6)  ## Sprite is drawn this far from the body so the feet sit on the collider.
const ANIMATIONS := {"idle": "knight_m_idle_anim", "run": "knight_m_run_anim"}

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var move_vel := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	sprite.sprite_frames = SpriteAtlas.frames(ANIMATIONS)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_vel = Movement.step(move_vel, wish, MAX_SPEED, ACCEL, FRICTION, delta)
	velocity = move_vel
	move_and_slide()

	var aim_dir := aim_direction()
	sprite.flip_h = aim_dir.x < 0.0
	muzzle.position = SPRITE_OFFSET + aim_dir * MUZZLE_DISTANCE
	sprite.play("run" if Movement.is_moving(move_vel) else "idle")


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
