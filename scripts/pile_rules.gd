class_name PileRules
extends RefCounted
## Pure rules for the coins thrown on the floor: how many piles a sum makes, how it splits, and
## where the piles land. Main throws them; CoinPile is the body on the floor.

## Piles land within this of the throw's centre (the player on a Roar, the boss where it fell).
const PILE_RADIUS := 64.0
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


## `count` seeded points within `radius` of `center`, clamped inside `bounds` shrunk by EDGE, each
## at least MIN_GAP from the ones before it when RETRIES draws find such a point. The centre is
## clamped inside first: a throw from the edge band would otherwise clamp a spot a shade past the
## radius. The same rng state gives the same list, so a replay throws to the same spots.
static func spots(center: Vector2, radius: float, count: int, bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var inner := bounds.grow(-EDGE)
	center = _clamp(center, inner)
	var result: Array[Vector2] = []
	for i in count:
		var spot := Vector2.ZERO
		for attempt in RETRIES:
			spot = _clamp(center + _in_disc(radius, rng), inner)
			if _clear_of(spot, result):
				break
		result.append(spot)
	return result


## A point uniformly in the disc (the square root keeps the density even).
static func _in_disc(radius: float, rng: RandomNumberGenerator) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var distance := radius * sqrt(rng.randf())
	return Vector2.from_angle(angle) * distance


static func _clamp(point: Vector2, rect: Rect2) -> Vector2:
	return point.clamp(rect.position, rect.end)


static func _clear_of(spot: Vector2, others: Array[Vector2]) -> bool:
	for other in others:
		if spot.distance_to(other) < MIN_GAP:
			return false
	return true
