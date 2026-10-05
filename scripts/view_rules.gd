class_name ViewRules
extends RefCounted
## Pure geometry behind the arena's fairness rules (the M7 design's "The big arena"): what is on
## screen, and where a shot's step leaves the screen. It takes rects and points only (the rect is
## View.rect's, read by the caller); no autoload, no Node, no viewport.

## Two crossings closer than this (in the step's fraction) are one: a corner.
const CORNER_EPSILON := 1e-6


## True when `point` is inside `rect` or on its edge (all four edges count as inside).
static func contains(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y


## Where the step from `from` to `to` leaves `rect`: {"hit", "at", "normal"}. No hit while `to` is
## inside (or on the edge). A step starting outside hits at `from` with a zero normal (nothing to
## bounce off). Otherwise `at` is on the first edge crossed and `normal` is that edge's unit inward
## normal; through a corner, both edges' normals summed and normalised.
static func exit(rect: Rect2, from: Vector2, to: Vector2) -> Dictionary:
	if not contains(rect, from):
		return {"hit": true, "at": from, "normal": Vector2.ZERO}
	if contains(rect, to):
		return {"hit": false, "at": to, "normal": Vector2.ZERO}
	var step := to - from
	var t := INF
	var normal := Vector2.ZERO
	# Each axis the step leaves by: the fraction of the step at its edge, and the edge's inward normal.
	var crossings: Array = []
	if to.x < rect.position.x:
		crossings.append([(rect.position.x - from.x) / step.x, Vector2.RIGHT])
	elif to.x > rect.end.x:
		crossings.append([(rect.end.x - from.x) / step.x, Vector2.LEFT])
	if to.y < rect.position.y:
		crossings.append([(rect.position.y - from.y) / step.y, Vector2.DOWN])
	elif to.y > rect.end.y:
		crossings.append([(rect.end.y - from.y) / step.y, Vector2.UP])
	for crossing: Array in crossings:
		var at_t: float = crossing[0]
		if absf(at_t - t) <= CORNER_EPSILON:
			normal += crossing[1]
		elif at_t < t:
			t = at_t
			normal = crossing[1]
	var at := from + step * t
	# On the edge exactly, whatever the float: the axis crossed is the edge's.
	if normal.x > 0.0:
		at.x = rect.position.x
	elif normal.x < 0.0:
		at.x = rect.end.x
	if normal.y > 0.0:
		at.y = rect.position.y
	elif normal.y < 0.0:
		at.y = rect.end.y
	return {"hit": true, "at": at, "normal": normal.normalized()}
