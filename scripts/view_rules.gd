class_name ViewRules
extends RefCounted
## Pure geometry behind the arena's fairness rules (the M7 design's "The big arena"): what is on
## screen, and where a shot's step leaves the screen. It takes rects and points only (the rect is
## View.rect's, read by the caller); no autoload, no Node, no viewport.

## Two crossings closer than this (in the step's fraction) are one: a corner.
const CORNER_EPSILON := 1e-6


## True when `point` is inside `rect` or on its edge (all four edges count as inside). An empty
## rect (no area: View's for a node outside the tree) contains nothing.
static func contains(rect: Rect2, point: Vector2) -> bool:
	if not rect.has_area():
		return false
	return point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y


## Where the step from `from` to `to` meets the edge of `rect`: {"hit", "at", "normal"}.
## - No hit while both ends are inside (or on the edge); `at` is then `to`.
## - Leaving: `at` is on the first edge crossed, `normal` that edge's inward normal; through a
##   corner, both edges'.
## - Starting outside (the edge swept over a shot as the view shifted, or a shot born there): `at`
##   is the nearest point of the rect, `normal` the inward normal of the side `from` is outside of
##   (both sides', in a corner region), wherever the step heads.
## - An empty rect: a hit at `from` with a zero normal (nothing to come back off).
## `normal`'s components are each -1, 0, or 1, so a corner's is not a unit vector: turn a shot with
## `reflect`, never Vector2.bounce.
static func exit(rect: Rect2, from: Vector2, to: Vector2) -> Dictionary:
	if not rect.has_area():
		return {"hit": true, "at": from, "normal": Vector2.ZERO}
	if not contains(rect, from):
		var outside := Vector2(_side(from.x, rect.position.x, rect.end.x), _side(from.y, rect.position.y, rect.end.y))
		return {"hit": true, "at": _onto(rect, from, outside), "normal": outside}
	if contains(rect, to):
		return {"hit": false, "at": to, "normal": Vector2.ZERO}
	var step := to - from
	# Each axis the step leaves by: the fraction of the step at its edge (INF: it leaves by neither
	# edge of that axis) and the edge's inward normal.
	var t_x := INF
	var n_x := 0.0
	if to.x < rect.position.x:
		t_x = (rect.position.x - from.x) / step.x
		n_x = 1.0
	elif to.x > rect.end.x:
		t_x = (rect.end.x - from.x) / step.x
		n_x = -1.0
	var t_y := INF
	var n_y := 0.0
	if to.y < rect.position.y:
		t_y = (rect.position.y - from.y) / step.y
		n_y = 1.0
	elif to.y > rect.end.y:
		t_y = (rect.end.y - from.y) / step.y
		n_y = -1.0
	var normal := Vector2(n_x, 0.0) if t_x < t_y else Vector2(0.0, n_y)
	if absf(t_x - t_y) <= CORNER_EPSILON:  # INF - INF is NaN, never a corner
		normal = Vector2(n_x, n_y)
	return {"hit": true, "at": _onto(rect, from + step * minf(t_x, t_y), normal), "normal": normal}


## `direction` turned back off an edge of inward `normal` (exit's): each axis the normal names is
## made to point inward, the other kept, so a side reverses one component, a corner both ((1, 0.2)
## leaves as (-1, -0.2)), and a component already heading in (a shot outside, coming back) is kept.
static func reflect(direction: Vector2, normal: Vector2) -> Vector2:
	var turned := direction
	if normal.x != 0.0:
		turned.x = absf(direction.x) * signf(normal.x)
	if normal.y != 0.0:
		turned.y = absf(direction.y) * signf(normal.y)
	return turned


## The inward normal's component on one axis for a coordinate against that axis's span: 1 below
## it, -1 above it, 0 inside.
static func _side(value: float, low: float, high: float) -> float:
	if value < low:
		return 1.0
	if value > high:
		return -1.0
	return 0.0


## `point` clamped into `rect`, and on the edge exactly on each axis `normal` names, whatever the float.
static func _onto(rect: Rect2, point: Vector2, normal: Vector2) -> Vector2:
	var at := point.clamp(rect.position, rect.end)
	if normal.x != 0.0:
		at.x = rect.position.x if normal.x > 0.0 else rect.end.x
	if normal.y != 0.0:
		at.y = rect.position.y if normal.y > 0.0 else rect.end.y
	return at
