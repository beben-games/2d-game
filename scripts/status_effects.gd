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
const EMITTER_OFFSET := Vector2(0, -4)

## The boss halves its stun and chill (BossDef.status_scale); an enemy takes them in full.
var duration_scale := 1.0
## The sprite's colour when no status is on: white, or the boss's stage-two tint.
var base_tint := Color.WHITE
var burn_ticks_left := 0
var stun_left := 0.0
var chill_left := 0.0

var _burn_tick := 0.0
var _emitters: Dictionary = {}  ## "burn" | "stun" | "chill" -> CPUParticles2D under the enemy body

@onready var health: Health = get_parent().get_node("Health")
@onready var sprite: CanvasItem = get_parent().get_node("Sprite")


func _ready() -> void:
	# Built up front (a hit arrives inside a physics callback, where adding nodes is unwelcome),
	# idle until a status runs. The parent is still setting up its children during our _ready, so
	# they join it on its ready signal, synchronously: a body freed before a deferred flush would
	# have orphaned them.
	_emitters["burn"] = _make_emitter("Burn", 8, 0.6, Vector2.UP, 30.0, 15.0, 30.0, Vector2(0, -40), BURN_TINT)
	_emitters["stun"] = _make_emitter("Stun", 6, 0.2, Vector2.RIGHT, 180.0, 30.0, 50.0, Vector2.ZERO, STUN_TINT)
	_emitters["chill"] = _make_emitter("Chill", 6, 0.8, Vector2.DOWN, 40.0, 5.0, 15.0, Vector2(0, 15), CHILL_TINT)
	if get_parent().is_node_ready():
		_attach_emitters()  # a Status added to a body already in the tree
	else:
		get_parent().ready.connect(_attach_emitters, CONNECT_ONE_SHOT)


func _attach_emitters() -> void:
	for kind in _emitters:
		get_parent().add_child(_emitters[kind])


func _make_emitter(emitter_name: String, amount: int, life: float, direction: Vector2, spread: float, speed_min: float, speed_max: float, gravity: Vector2, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = emitter_name
	p.emitting = false
	p.local_coords = false
	p.amount = amount
	p.lifetime = life
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = color
	p.scale_amount_curve = Fx.fade_scale()
	p.color_ramp = Fx.fade_ramp()
	p.position = EMITTER_OFFSET
	return p


## The corpse keeps no fire, spark, or frost.
func stop_effects() -> void:
	for kind in _emitters:
		_emitters[kind].emitting = false


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


## The look as a whole: the tint (stun over burn over chill, keeping the sprite's alpha: the
## spawn fade tweens it) and the emitters.
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
	_emitters["burn"].emitting = burning()
	_emitters["stun"].emitting = stunned()
	_emitters["chill"].emitting = chilled()
