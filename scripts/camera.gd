extends Camera2D
## Follows the player (as its child), leans toward the aim point, and shakes from Juice.trauma.
## Lean goes through position so the camera limits and smoothing clamp it; shake goes through
## offset so it is screen-space and may briefly show past a wall, which is fine.
## Shake randomness uses the global RNG on purpose: it is cosmetic and must not disturb the run seed.
## The verdict's drift (drift_to) leaves the fallen gladiator for the emperor's box: the lean,
## the shake, and the smoothing are suspended and the limits released for it (the box sits in
## the top wall and the arena is one screen tall, so held to the arena the view could not move),
## until end_drift puts them back at the next run's start: a snap, no drift back.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3
const MAX_SHAKE := 12.0
## Camera2D's own default limit: no limit at all.
const RELEASED_LIMIT := 10000000

## True from drift_to until end_drift: the view is the drift's, not the player's.
var drifting := false
var _held_limits: Array[int] = []
var _drift_tween: Tween

@onready var player: Player = get_parent()


## The view from where it is to `target` (world space) over `seconds`, real time (a freeze
## does not hold it), eased in and out. Only the first call of a drift holds the limits.
func drift_to(target: Vector2, seconds: float) -> void:
	if not drifting:
		_held_limits = [limit_left, limit_top, limit_right, limit_bottom]
		limit_left = -RELEASED_LIMIT
		limit_top = -RELEASED_LIMIT
		limit_right = RELEASED_LIMIT
		limit_bottom = RELEASED_LIMIT
	drifting = true
	position_smoothing_enabled = false
	offset = Vector2.ZERO
	_kill_drift()
	_drift_tween = create_tween()
	_drift_tween.set_ignore_time_scale(true)
	_drift_tween.tween_property(self, "global_position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The drift over: the limits, the smoothing, and the follow back, the view snapped to the
## player at once (the next run starts under the black). A no-op when nothing drifts.
func end_drift() -> void:
	if not drifting:
		return
	_kill_drift()
	drifting = false
	limit_left = _held_limits[0]
	limit_top = _held_limits[1]
	limit_right = _held_limits[2]
	limit_bottom = _held_limits[3]
	position = Vector2.ZERO  # the lean is recomputed on the next frame
	position_smoothing_enabled = true
	reset_smoothing()


func _kill_drift() -> void:
	if _drift_tween != null and _drift_tween.is_valid():
		_drift_tween.kill()
	_drift_tween = null


func _process(_delta: float) -> void:
	if drifting:
		return
	var to_aim: Vector2 = player.aim_position() - player.global_position
	position = to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
	offset = JuiceMath.shake_offset(Juice.trauma, MAX_SHAKE, randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
