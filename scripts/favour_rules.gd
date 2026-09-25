class_name FavourRules
extends RefCounted
## Pure rules for the crowd's favour: a meter from 0 to MAX that pays for danger and punishes
## caution. Every act's value lives in ACTS and nowhere else; the Favour node holds one detector
## per act and scores through apply(), so a later act (a melee kill, a repetition penalty) is one
## row here and one detector there. The band at a round's end is the round's verdict: it picks the
## crowd's sound, who grants the cards, and how many.

const START := 30.0
const MAX := 100.0
## The acts table: act name to the change it makes to the meter.
const ACTS := {"kill": 3, "chain": 2, "daring": 3, "clean_round": 15, "hit": -20}
## A kill this soon after the last one is a chain.
const CHAIN_WINDOW := 1.5
## A kill this soon after a dash through danger ended is daring.
const DASH_WINDOW := 0.5
## A dash whose path passes this close to a live enemy went through danger.
const DANGER_RADIUS := 24.0
## Seconds without hitting or killing an enemy, while any is live, before the crowd turns.
const IDLE_GRACE := 4.0
const COWARDICE_PER_SECOND := 2.0

## The bands, in order; band() gives the index. BAND_EDGES are the lower edges of the upper three.
const BOO := 0
const QUIET := 1
const CHEER := 2
const ROAR := 3
const BAND_EDGES := [25.0, 50.0, 75.0]
## Who grants the cards at a round's end: the crowd from Cheer up, the emperor below.
const GRANTER_CROWD := "The crowd"
const GRANTER_EMPEROR := "The emperor"
const OFFER_COUNT := 3
const OFFER_COUNT_ROAR := 4


static func band(value: float) -> int:
	var result := BOO
	for edge: float in BAND_EDGES:
		if value >= edge:
			result += 1
	return result


## The meter after `act`, clamped.
static func apply(value: float, act: String) -> float:
	assert(ACTS.has(act), "FavourRules: no act '%s'" % act)
	return clamp_value(value + float(ACTS[act]))


static func clamp_value(value: float) -> float:
	return clampf(value, 0.0, MAX)


static func granter(band_index: int) -> String:
	return GRANTER_CROWD if band_index >= CHEER else GRANTER_EMPEROR


static func offer_count(band_index: int) -> int:
	return OFFER_COUNT_ROAR if band_index >= ROAR else OFFER_COUNT


## True when the dash segment from `from` to `to` passes within `radius` of any position. An
## enemy behind the start or past the end counts only when it is within the radius of that end.
static func dash_through_danger(from: Vector2, to: Vector2, enemy_positions: Array, radius: float) -> bool:
	for at: Vector2 in enemy_positions:
		if _distance_to_segment(from, to, at) <= radius:
			return true
	return false


## The drain for `delta` seconds after `idle_seconds` without an engagement: nothing inside the
## grace, COWARDICE_PER_SECOND past it (negative, a change to the meter).
static func cowardice(idle_seconds: float, delta: float) -> float:
	if idle_seconds < IDLE_GRACE:
		return 0.0
	return -COWARDICE_PER_SECOND * delta


static func _distance_to_segment(from: Vector2, to: Vector2, point: Vector2) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared == 0.0:
		return from.distance_to(point)
	var t := clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
	return (from + segment * t).distance_to(point)
