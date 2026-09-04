class_name SpawnMath
extends RefCounted
## Pure helpers for when and where enemies appear.

const EDGE_MARGIN := 12.0


## Seconds between spawns, easing linearly from start to min_interval over ramp_seconds.
static func interval(start: float, min_interval: float, ramp_seconds: float, elapsed: float) -> float:
	var t := clampf(elapsed / ramp_seconds, 0.0, 1.0)
	return lerpf(start, min_interval, t)


## A random point inside bounds at least min_distance from avoid. Falls back to the
## farthest candidate found when no candidate satisfies the distance.
static func pick_position(bounds: Rect2, avoid: Vector2, min_distance: float, rng: RandomNumberGenerator, attempts: int = 24) -> Vector2:
	var inner := bounds.grow(-EDGE_MARGIN)
	var best := inner.get_center()
	var best_distance := -1.0
	for i in attempts:
		var p := Vector2(
			rng.randf_range(inner.position.x, inner.end.x),
			rng.randf_range(inner.position.y, inner.end.y),
		)
		var d := p.distance_to(avoid)
		if d >= min_distance:
			return p
		if d > best_distance:
			best = p
			best_distance = d
	return best
