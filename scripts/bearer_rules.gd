class_name BearerRules
extends RefCounted
## The standard-bearer's rules (pure): who its banner covers, and where it stands. It keeps the
## nearest of its pack between itself and the player, KEEP past that enemy on the line from the
## player, never nearer the player than its flee range, and backs straight away inside it. With
## no pack it has no stand: it walks at the player, so a round never stalls on it. Nothing here
## reads the view: the banner reaches, and the bearer keeps its stand, on screen or off.

const KEEP := 40.0  ## px past the nearest of its pack, on the line from the player
const ARRIVE := 4.0  ## px: this near its stand it holds still (no jitter about the spot)
## px: another of the pack takes the anchor only when nearer than the held one by more than this,
## so two enemies at about the same distance do not swap the stand from tick to tick.
const ANCHOR_SLACK := 8.0
const EDGE := 8.0  ## px: the stand is kept this far inside the floor's bounds


## The indices of `positions` within `radius` of `centre`, the edge inclusive, in their order.
static func covered(centre: Vector2, radius: float, positions: Array[Vector2]) -> Array[int]:
	var out: Array[int] = []
	if radius <= 0.0:
		return out
	for i in positions.size():
		if centre.distance_squared_to(positions[i]) <= radius * radius:
			out.append(i)
	return out


## The index in `pack` the bearer stands behind: the one nearest it, but the held one (`current`,
## -1 for none) stays unless another is nearer by more than ANCHOR_SLACK. -1 for an empty pack.
static func anchor(pack: Array[Vector2], self_position: Vector2, current: int) -> int:
	if pack.is_empty():
		return -1
	var nearest := 0
	for i in pack.size():
		if self_position.distance_to(pack[i]) < self_position.distance_to(pack[nearest]):
			nearest = i
	if current < 0 or current >= pack.size():
		return nearest
	if self_position.distance_to(pack[nearest]) < self_position.distance_to(pack[current]) - ANCHOR_SLACK:
		return nearest
	return current


## The movement wish of a bearer at `self_position`. `pack`: the other enemies it may stand
## behind (no other bearer, no summon). Empty: the vector to the player (the last-alive rule).
## Inside `flee_range` of the player: straight away from it. Otherwise toward its stand, on the
## ray from the player through `pack[anchor_index]` (-1: the nearest to the bearer; the enemy
## keeps it through anchor()), at the larger of that enemy's distance plus `keep` and
## `flee_range`, clamped EDGE inside `floor_rect` (an empty rect clamps nothing); zero within
## ARRIVE of it. A pack member on the player's own spot takes the bearer's side of the player.
static func stand(player: Vector2, pack: Array[Vector2], self_position: Vector2, keep: float, flee_range: float, floor_rect: Rect2, anchor_index := -1) -> Vector2:
	if pack.is_empty():
		return player - self_position
	var from_player := self_position - player
	if from_player.length() < flee_range:
		return from_player
	if anchor_index < 0 or anchor_index >= pack.size():
		anchor_index = anchor(pack, self_position, -1)
	var away := pack[anchor_index] - player
	var direction := away.normalized() if away != Vector2.ZERO else from_player.normalized()
	var spot := player + direction * maxf(away.length() + keep, flee_range)
	if floor_rect.has_area():
		var inner := floor_rect.grow(-EDGE)
		spot = spot.clamp(inner.position, inner.end)
	var to_spot := spot - self_position
	return Vector2.ZERO if to_spot.length() <= ARRIVE else to_spot


## The top speed that still stops on the spot `distance` away at `accel`: the bearer eases into
## its stand instead of overshooting it and walking back.
static func arrive_speed(speed: float, accel: float, distance: float) -> float:
	return minf(speed, sqrt(2.0 * accel * maxf(distance, 0.0)))
