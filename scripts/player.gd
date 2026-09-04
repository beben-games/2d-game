class_name Player
extends CharacterBody2D
## The hero: movement, shooting, and taking contact damage.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const KNOCKBACK_DECAY := 900.0
const MUZZLE_DISTANCE := 8.0
const SPRITE_OFFSET := Vector2(0, -6)  ## Sprite is drawn this far from the body so the feet sit on the collider.
const ANIMATIONS := {"idle": "knight_m_idle_anim", "run": "knight_m_run_anim"}
const MAX_HP := 6
const INVULN_TIME := 0.8
const HIT_KNOCKBACK := 200.0
const HIT_TRAUMA := 0.7
const HIT_HITSTOP := 0.09
const DEATH_TRAUMA := 1.0
const DEATH_HITSTOP := 0.25

## Shared resource; _ready duplicates it so upgrades never mutate the .tres.
@export var weapon: WeaponDef

## Where shots are added. Main sets this to its Projectiles container; falls back to the parent.
var projectile_parent: Node

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var fire := FireController.new()
var hp: int = MAX_HP
var dead := false
var invuln_left := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
## Its circle is wider than the body collider: bodies never interpenetrate, so a touching enemy
## sits a full radius away and a hurtbox the size of the body would never see it.
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	assert(weapon != null, "Player needs a WeaponDef")
	weapon = weapon.duplicate()  # upgrades mutate this copy, not the cached .tres
	var errors := weapon.validate()
	assert(errors.is_empty(), "Invalid weapon: %s" % ", ".join(errors))
	sprite.sprite_frames = SpriteAtlas.frames(ANIMATIONS)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if dead:
		return
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

	invuln_left = maxf(invuln_left - delta, 0.0)
	sprite.visible = PlayerHitRules.blink_visible(invuln_left)
	_check_contact()


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT


## Shots live outside the player so they do not move with it. One jitter per volley keeps a
## multishot fan coherent.
func _shoot(dir: Vector2) -> void:
	var parent := projectile_parent if projectile_parent != null else get_parent()
	var jitter := deg_to_rad(weapon.inaccuracy_degrees)
	var base_angle := dir.angle() + RunState.rng.randf_range(-jitter, jitter)
	for offset in WeaponDef.spread_offsets(weapon.projectile_count, deg_to_rad(weapon.spread_degrees)):
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(weapon, Vector2.from_angle(base_angle + offset))
		parent.add_child(shot)
		shot.global_position = muzzle.global_position
	knockback -= dir * weapon.recoil
	Events.shot_fired.emit(muzzle.global_position, dir)


## Polls overlaps every physics frame so an enemy that stays on top of us keeps hurting after i-frames end.
func _check_contact() -> void:
	if not PlayerHitRules.can_take_hit(invuln_left):
		return
	for body in hurtbox.get_overlapping_bodies():
		var enemy := body as Enemy
		if enemy != null and enemy.is_harmful():
			_take_hit(enemy.def.contact_damage, enemy.global_position)
			return


func _take_hit(damage: int, from: Vector2) -> void:
	hp -= damage
	invuln_left = INVULN_TIME
	knockback = PlayerHitRules.knockback_from(global_position, from, HIT_KNOCKBACK)
	Juice.add_trauma(HIT_TRAUMA)
	Juice.hitstop(HIT_HITSTOP)
	Events.player_hit.emit(damage)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	sprite.visible = false
	hurtbox.monitoring = false
	Juice.add_trauma(DEATH_TRAUMA)
	Juice.hitstop(DEATH_HITSTOP)
	Events.player_died.emit()
