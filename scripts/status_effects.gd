class_name StatusEffects
extends Node
## Burn, stun, and chill on one enemy. Projectiles apply them on hit; the enemy reads stunned()
## and speed_multiplier() each tick. Reapplying refreshes a timer, nothing stacks. Burn damage
## goes through Health quietly (no hit trauma, no white flash): the tint is the feedback. Tints
## keep the sprite's alpha so the spawn fade-in is untouched. Feel numbers live here.

const BURN_TICKS := 6  ## ticks of BURN_DAMAGE, BURN_TICK apart: 1 damage per second for 3 s
const BURN_TICK := 0.5
const BURN_DAMAGE := 0.5
const STUN_TIME := 0.6
const CHILL_TIME := 2.0
const CHILL_SPEED := 0.5
const BURN_TINT := Color(1.0, 0.55, 0.2)
const STUN_TINT := Color(1.0, 1.0, 0.75)
const CHILL_TINT := Color(0.55, 0.75, 1.0)

## The boss halves its stun and chill (BossDef.status_scale); an enemy takes them in full.
var duration_scale := 1.0
## The sprite's colour when no status is on: white, or the boss's stage-two tint.
var base_tint := Color.WHITE
var burn_ticks_left := 0
var stun_left := 0.0
var chill_left := 0.0

var _burn_tick := 0.0

@onready var health: Health = get_parent().get_node("Health")
@onready var sprite: CanvasItem = get_parent().get_node("Sprite")


func apply_from(shot: Projectile) -> void:
	if health.dead:
		return  # the shot that killed the enemy leaves the corpse alone
	if shot.burn > 0.0:
		apply_burn()
	if shot.stun > 0.0:
		apply_stun()
	if shot.chill > 0.0:
		apply_chill()


func apply_burn() -> void:
	if burn_ticks_left == 0:
		_burn_tick = BURN_TICK
		Events.status_applied.emit(get_parent(), "burn")
	burn_ticks_left = BURN_TICKS
	_tint()


func apply_stun() -> void:
	if not stunned():
		Events.status_applied.emit(get_parent(), "stun")
	stun_left = STUN_TIME * duration_scale
	_tint()


func apply_chill() -> void:
	if not chilled():
		Events.status_applied.emit(get_parent(), "chill")
	chill_left = CHILL_TIME * duration_scale
	_tint()


func burning() -> bool:
	return burn_ticks_left > 0


func stunned() -> bool:
	return stun_left > 0.0


func chilled() -> bool:
	return chill_left > 0.0


func speed_multiplier() -> float:
	return CHILL_SPEED if chilled() else 1.0


func _physics_process(delta: float) -> void:
	if burn_ticks_left > 0:
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick += BURN_TICK
			burn_ticks_left -= 1
			health.take_damage(BURN_DAMAGE, Vector2.ZERO, true)
	stun_left = maxf(stun_left - delta, 0.0)
	chill_left = maxf(chill_left - delta, 0.0)
	_tint()


## Stun over burn over chill. Keeps the sprite's alpha (the spawn fade tweens it).
func _tint() -> void:
	if sprite == null:
		return
	var tint := base_tint
	if stunned():
		tint = STUN_TINT
	elif burning():
		tint = BURN_TINT
	elif chilled():
		tint = CHILL_TINT
	tint.a = sprite.modulate.a
	sprite.modulate = tint
