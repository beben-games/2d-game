class_name ChargeLine
extends Line2D
## The path of a charge, drawn on the floor through its wind-up: a thin straight line from the
## body along the charge's direction, fixed when the wind-up starts (it never tracks the target).
## A child of the charging body, in its local space, so a shove during the wind-up carries the
## line with the body: it always shows where the run will go. Added as the body's first child so
## the sprite draws over it. No text: the line is the world showing the danger. Reusable by any
## body that charges (the charger; a boss with BossDef.charge_line).

const WIDTH := 1.0  ## world px: three screen pixels at the arena's 3x zoom
const COLOR := UiTheme.PAPER  ## chalk on the sand
## The line fades in over the wind-up, so it reads as the run coming: faint at the start, firm
## at its end.
const ALPHA_FROM := 0.3
const ALPHA_TO := 0.85

## The first leg's unit direction and the path's length (px), from the last setup.
var direction := Vector2.RIGHT
var length := 0.0

var _fade: Tween


func _init() -> void:
	name = "ChargeLine"
	width = WIDTH
	default_color = COLOR
	begin_cap_mode = Line2D.LINE_CAP_NONE
	end_cap_mode = Line2D.LINE_CAP_NONE
	visible = false


## Lays the line from `from` (the parent's local space) along `dir` for `line_length` px: one leg.
func setup(from: Vector2, dir: Vector2, line_length: float) -> void:
	var unit := dir.normalized()
	setup_path(PackedVector2Array([from, from + unit * maxf(line_length, 0.0)]))
	direction = unit  # kept for a zero-length leg too


## Lays the line through `path` (the parent's local space), leg by leg: a chain of charges shown
## at once. `direction` is the first leg's (kept when it has none), `length` the legs' sum.
func setup_path(path: PackedVector2Array) -> void:
	points = path
	length = 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	if path.size() >= 2 and path[1] != path[0]:
		direction = (path[1] - path[0]).normalized()


## Shows the line, fading it in from ALPHA_FROM to ALPHA_TO over `duration` seconds (at once
## for none).
func show_line(duration := 0.0) -> void:
	_stop_fade()
	visible = true
	modulate.a = ALPHA_FROM
	if duration <= 0.0:
		modulate.a = ALPHA_TO
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", ALPHA_TO, duration)


func hide_line() -> void:
	_stop_fade()
	visible = false


func shown() -> bool:
	return visible


func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
