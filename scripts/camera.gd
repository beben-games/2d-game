extends Camera2D
## Follows the player (as its child), leans toward the aim point, and shakes from Juice.trauma.
## Lean goes through position so the camera limits and smoothing clamp it; shake goes through
## offset so it is screen-space and may briefly show past a wall, which is fine.
## Shake randomness uses the global RNG on purpose: it is cosmetic and must not disturb the run seed.
## The verdict's drift (drift_to) leaves the fallen gladiator for the emperor's box, zooming in
## as it goes: the lean, the shake, and the smoothing are suspended for it, the limits never
## (the view may show the walls but never the void past them, zoomed or not), until end_drift
## puts the follow and the zoom back at the next run's start: a snap, no drift back.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3
const MAX_SHAKE := 12.0
## How far under the view's top edge a point framed by top_framed sits: about a tile.
const TOP_MARGIN := float(ArenaGrid.TILE)

## True from drift_to until end_drift: the view is the drift's, not the player's.
var drifting := false
var _held_zoom := Vector2.ONE
var _drift_tween: Tween

@onready var player: Player = get_parent()


## The view from where it is to `target` (world space), zooming in by `zoom_factor`, over
## `seconds` of real time (a freeze does not hold it), eased in and out. The limits stay on, so
## the view is clamped inside the arena at every zoom. Only the first call of a drift holds the
## zoom to restore.
func drift_to(target: Vector2, seconds: float, zoom_factor: float) -> void:
	if not drifting:
		_held_zoom = zoom
	drifting = true
	position_smoothing_enabled = false
	offset = Vector2.ZERO
	_kill_drift()
	_drift_tween = create_tween()
	_drift_tween.set_ignore_time_scale(true)
	_drift_tween.set_parallel(true)
	_drift_tween.tween_property(self, "global_position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift_tween.tween_property(self, "zoom", _held_zoom * zoom_factor, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The camera centre that puts `point` TOP_MARGIN under the top edge of the view at
## `zoom_value`, on the point's vertical axis: the view's half-height in world pixels comes
## from the viewport's size, so a window or zoom change keeps the framing.
func top_framed(point: Vector2, zoom_value: float) -> Vector2:
	var half_height := get_viewport_rect().size.y / zoom_value * 0.5
	return Vector2(point.x, point.y + half_height - TOP_MARGIN)


## The drift over: the zoom, the smoothing, and the follow back, the view snapped to the player
## at once (the next run starts under the black). A no-op when nothing drifts.
func end_drift() -> void:
	if not drifting:
		return
	_kill_drift()
	drifting = false
	zoom = _held_zoom
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
