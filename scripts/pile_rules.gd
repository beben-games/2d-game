class_name PileRules
extends RefCounted
## Pure rules for the coins thrown on the floor: how many piles a sum makes, how it splits, and
## where the piles land. Main throws them; CoinPile is the body on the floor.

## The pull's reach: a landed pile this close to the player is drawn in (CoinPile; RunState.
## pull_radius carries it, so a training line can widen it).
const PULL_RADIUS := 96.0
## Piles land in a ring around the throw's centre (the player on a Roar, the boss where it
## fell): past the pull's reach by RING_GAP, so a Roar's piles wait to be walked to, and no
## further than RING_MAX. A centre near a wall has no full ring: the spots fall on the reachable
## side, still at least RING_MIN away when the floor allows.
const RING_GAP := 16.0
const RING_MIN := PULL_RADIUS + RING_GAP
const RING_MAX := 160.0
## One pile per this many coins, held between MIN_COUNT and MAX_COUNT (and never more piles than
## coins: a pile of nothing would be a coin sprite that pays nothing).
const COINS_PER_PILE := 8
const MIN_COUNT := 4
const MAX_COUNT := 8
## Spots stay this far from the floor's edge and, when the room allows, this far from each other.
const EDGE := 8.0
const MIN_GAP := 12.0
## Draws per pile before a crowded spot is accepted as it is.
const RETRIES := 20


## The sum over `count` piles, the remainder on the first ones: split(10, 4) is [3, 3, 2, 2].
static func split(total: int, count: int) -> Array[int]:
	var values: Array[int] = []
	if count <= 0:
		return values
	@warning_ignore("integer_division")
	var base: int = total / count
	var extra: int = total % count
	for i in count:
		values.append(base + 1 if i < extra else base)
	return values


static func pile_count(total: int) -> int:
	var by_size := clampi(ceili(float(total) / COINS_PER_PILE), MIN_COUNT, MAX_COUNT)
	return mini(by_size, maxi(total, 0))


## `count` seeded points in the ring around `center` (RING_MIN to RING_MAX), clamped inside
## `bounds` shrunk by EDGE, each at least MIN_GAP from the ones before it. Each pile draws up to
## RETRIES points and takes the first that is clear of the others and still RING_MIN from the
## centre after the clamp; failing that, the clear draw that landed furthest out (a wall in the
## way), or the last draw. The centre is clamped inside first: a throw from the edge band would
## otherwise measure from off the floor. The same rng state gives the same list, so a replay
## throws to the same spots.
static func spots(center: Vector2, count: int, bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var inner := bounds.grow(-EDGE)
	center = _clamp(center, inner)
	var result: Array[Vector2] = []
	for i in count:
		var best := Vector2.ZERO
		var best_distance := -1.0
		for attempt in RETRIES:
			var spot := _clamp(center + _in_ring(rng), inner)
			var distance := spot.distance_to(center)
			if _clear_of(spot, result) and distance >= RING_MIN:
				best = spot
				break
			if _clear_of(spot, result) and distance > best_distance:
				best = spot
				best_distance = distance
			elif best_distance < 0.0 and attempt == RETRIES - 1:
				best = spot
		result.append(best)
	return result


## A point uniformly in the ring (the square root keeps the density even over the area).
static func _in_ring(rng: RandomNumberGenerator) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var distance := sqrt(lerpf(RING_MIN * RING_MIN, RING_MAX * RING_MAX, rng.randf()))
	return Vector2.from_angle(angle) * distance


static func _clamp(point: Vector2, rect: Rect2) -> Vector2:
	return point.clamp(rect.position, rect.end)


static func _clear_of(spot: Vector2, others: Array[Vector2]) -> bool:
	for other in others:
		if spot.distance_to(other) < MIN_GAP:
			return false
	return true
