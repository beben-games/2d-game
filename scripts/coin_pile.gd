class_name CoinPile
extends Area2D
## A pile of coins on the floor, thrown by Main (a Roar's tally around the player, the boss's
## coins where it fell): tossed in an arc to its spot, then paid to the run when the player's
## body touches it, walking or dashing (layer 32, masking 65: the body's layer and its dash
## layer). Monitoring is off until it lands, so a pile in flight is never collected. Once
## landed, a pile within RunState.pull_radius of the player is drawn to them each physics tick
## at PULL_SPEED, accelerating by PULL_ACCEL, until contact (the player is found once, at the
## landing, through the player group). A child of the Room's Piles, so it goes with the Room
## and a new run starts with none.

const TOSS_TIME := 0.4
const ARC_HEIGHT := 24.0  ## the sprite's peak above the straight line of the toss
const SPIN_FPS := 8.0
## The pull: the reach at a run's start (RunState.pull_radius carries it, so a training line can
## widen it), the speed a pile sets off at, and how much it gains a second.
const PULL_RADIUS := 96.0
const PULL_SPEED := 220.0
const PULL_ACCEL := 600.0

var value: int = 0
var _collected := false
var _landed := false
var _player: Node2D
var _pull_speed := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.sprite_frames = SpriteAtlas.frames({"spin": "coin_anim"}, SPIN_FPS)
	sprite.play("spin")
	body_entered.connect(_on_body_entered)


## From `from` to `to` in TOSS_TIME along the straight line, the sprite lifted by a parabola
## peaking at ARC_HEIGHT, then landed. Pauses with the tree like the rest of the Room.
func toss(from: Vector2, to: Vector2) -> void:
	global_position = from
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", to, TOSS_TIME)
	tween.tween_method(_set_arc, 0.0, 1.0, TOSS_TIME)
	tween.chain().tween_callback(land.bind(to))


## The parabola at `t` in 0..1: on the line at both ends, ARC_HEIGHT up at the middle.
func _set_arc(t: float) -> void:
	sprite.position.y = -ARC_HEIGHT * 4.0 * t * (1.0 - t)


## On the floor at `at`, ready to be collected and to be pulled.
func land(at: Vector2) -> void:
	global_position = at
	sprite.position = Vector2.ZERO
	monitoring = true
	_landed = true
	_player = get_tree().get_first_node_in_group("player")


## The pull, once landed: within the reach the pile sets off at PULL_SPEED and gains PULL_ACCEL
## a second, straight at the player, until contact pays it (a pile out of reach stays put and
## its speed resets, so a player who steps away and back is met afresh).
func _physics_process(delta: float) -> void:
	if not _landed or _collected or not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	if to_player.length() > RunState.pull_radius:
		_pull_speed = 0.0
		return
	_pull_speed = maxf(_pull_speed, PULL_SPEED) + PULL_ACCEL * delta
	global_position += to_player.limit_length(_pull_speed * delta)


## The mask admits only the player's body (walking or dashing). Inside a physics callback:
## numbers, signals, and a queued free only.
func _on_body_entered(_body: Node2D) -> void:
	if _collected:
		return
	_collected = true
	RunState.add_coins(value)
	Events.pile_collected.emit(global_position, value)
	queue_free()
