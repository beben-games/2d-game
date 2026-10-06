class_name BearerRules
extends RefCounted
## The standard-bearer's rules (pure): who its banner covers, and where it stands. It keeps the
## nearest of its pack between itself and the player, KEEP past that enemy on the line from the
## player, never nearer the player than its flee range, and backs straight away inside it. With
## no pack it has no stand: it walks at the player, so a round never stalls on it. Nothing here
## reads the view: the banner reaches, and the bearer keeps its stand, on screen or off.

const KEEP := 40.0  ## px past the nearest of its pack, on the line from the player
const ARRIVE := 4.0  ## px: this near its stand it holds still (no jitter about the spot)


## The indices of `positions` within `radius` of `centre`, the edge inclusive, in their order.
static func covered(centre: Vector2, radius: float, positions: Array[Vector2]) -> Array[int]:
	var out: Array[int] = []
	if radius <= 0.0:
		return out
	for i in positions.size():
		if centre.distance_squared_to(positions[i]) <= radius * radius:
			out.append(i)
	return out


## The movement wish of a bearer at `self_position`. `pack`: the other enemies it may stand
## behind (no other bearer, no summon). Empty: the vector to the player (the last-alive rule).
## Inside `flee_range` of the player: straight away from it. Otherwise toward its stand, on the
## ray from the player through the nearest of the pack (nearest to the bearer), at the larger of
## that enemy's distance plus `keep` and `flee_range`; zero within ARRIVE of it. A pack member on
## the player's own spot takes the bearer's side of the player.
static func stand(player: Vector2, pack: Array[Vector2], self_position: Vector2, keep: float, flee_range: float) -> Vector2:
	if pack.is_empty():
		return player - self_position
	var from_player := self_position - player
	if from_player.length() < flee_range:
		return from_player
	var nearest := pack[0]
	for at in pack:
		if self_position.distance_squared_to(at) < self_position.distance_squared_to(nearest):
			nearest = at
	var away := nearest - player
	var direction := away.normalized() if away != Vector2.ZERO else from_player.normalized()
	var spot := player + direction * maxf(away.length() + keep, flee_range)
	var to_spot := spot - self_position
	return Vector2.ZERO if to_spot.length() <= ARRIVE else to_spot


## The top speed that still stops on the spot `distance` away at `accel`: the bearer eases into
## its stand instead of overshooting it and walking back.
static func arrive_speed(speed: float, accel: float, distance: float) -> float:
	return minf(speed, sqrt(2.0 * accel * maxf(distance, 0.0)))
