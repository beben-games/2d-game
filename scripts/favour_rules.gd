class_name FavourRules
extends RefCounted
## Pure rules for the crowd's favour: a meter from 0 to MAX that pays for danger and punishes
## caution. Every act's value lives in ACTS and nowhere else; the Favour node holds one detector
## per act and scores through apply(), so a later act (a melee kill, a repetition penalty) is one
## row here and one detector there. The band at a round's end is the round's verdict: it picks the
## crowd's sound, who grants the cards, and how many.

const START := 20.0
const MAX := 100.0
## The acts table: act name to the change it makes to the meter. Every act but the hit is a
## scoring act (is_scoring): the last one's time is where the decay's grace counts from.
const ACTS := {"kill": 1, "chain": 2, "daring": 4, "clean_round": 10, "hit": -25}
## The acts that never lift the meter past the Roar edge: kills and chains alone cannot max the
## crowd; a daring kill or a clean round pushes past it. A capped act at or above the edge adds
## nothing, but is still a scoring act (it holds the decay off).
const CAPPED_ACTS: Array[String] = ["kill", "chain"]
const KILL_CAP := 74.0  ## one under BAND_EDGES[ROAR - 1]: kills alone never reach Roar; a test pins the tie
## A kill this soon after the last one is a chain.
const CHAIN_WINDOW := 1.5
## A kill this soon after a dash through danger ended is daring.
const DASH_WINDOW := 0.5
## A dash whose path passes this close to a live enemy went through danger.
const DANGER_RADIUS := 24.0
## The decay: seconds since the last scoring act, while a run is live, before the crowd's
## interest fades, and what the meter loses a second past them. Running away, idling, and the
## gap between rounds (collecting coins slowly) all decay; fighting (killing) keeps the meter. A
## hit on an enemy that does not kill holds nothing.
const DECAY_GRACE := 3.0
const DECAY_PER_SECOND := 1.5
## The act favour_changed names for the decay; a rate, so not an ACTS row.
const DECAY_ACT := "decay"

## The bands, in order; band() gives the index. BAND_EDGES are the lower edges of the upper three.
const BOO := 0
const QUIET := 1
const CHEER := 2
const ROAR := 3
const BAND_EDGES := [25.0, 50.0, 75.0]
## The bands' names, by index: what the profile files a round's verdict under.
const BAND_NAMES: Array[String] = ["boo", "quiet", "cheer", "roar"]
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


static func band_name(band_index: int) -> String:
	return BAND_NAMES[band_index]


## The meter after `act`, clamped; a capped act stops at KILL_CAP and adds nothing above it.
static func apply(value: float, act: String) -> float:
	assert(ACTS.has(act), "FavourRules: no act '%s'" % act)
	var result := value + float(ACTS[act])
	if act in CAPPED_ACTS:
		result = value if value >= KILL_CAP else minf(result, KILL_CAP)
	return clamp_value(result)


static func clamp_value(value: float) -> float:
	return clampf(value, 0.0, MAX)


## True for an act that raises the meter: the decay's grace counts from the last of them.
static func is_scoring(act: String) -> bool:
	assert(ACTS.has(act), "FavourRules: no act '%s'" % act)
	return int(ACTS[act]) > 0


static func granter(band_index: int) -> String:
	return GRANTER_CROWD if band_index >= CHEER else GRANTER_EMPEROR


static func offer_count(band_index: int) -> int:
	return OFFER_COUNT_ROAR if band_index >= ROAR else OFFER_COUNT


## True when the dash segment from `from` to `to` passes within `radius` of any position. An
## enemy behind the start or past the end counts only when it is within the radius of that end.
static func dash_through_danger(from: Vector2, to: Vector2, enemy_positions: Array[Vector2], radius: float) -> bool:
	for at: Vector2 in enemy_positions:
		if _distance_to_segment(from, to, at) <= radius:
			return true
	return false


## The decay for `delta` seconds after `idle_seconds` without a scoring act: nothing inside the
## grace, DECAY_PER_SECOND past it (negative, a change to the meter).
static func decay(idle_seconds: float, delta: float) -> float:
	if idle_seconds < DECAY_GRACE:
		return 0.0
	return -DECAY_PER_SECOND * delta


static func _distance_to_segment(from: Vector2, to: Vector2, point: Vector2) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared == 0.0:
		return from.distance_to(point)
	var t := clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
	return (from + segment * t).distance_to(point)
