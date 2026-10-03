class_name FavourRules
extends RefCounted
## Pure rules for the crowd's favour: a meter from 0 to MAX that pays for danger and punishes
## caution. Every act's value lives in ACTS and nowhere else but the kill's, which is a share of the
## round's KILL_BUDGET (kill_share, scored through apply_kill); the Favour node holds one detector
## per act and scores through apply(), so a later act (a melee kill, a repetition penalty) is one
## row here and one detector there. The band at a round's end is the round's verdict: it picks the
## crowd's sound and how many cards the picker offers.

const START := 20.0
const MAX := 100.0
## The acts table: act name to the change it makes to the meter. Every act but the hit is a
## scoring act (is_scoring): the last one's time is where the decay's grace counts from. The kill
## is the one act not in it: its value is a share of the round's budget.
const ACTS := {"chain": 2, "dare": 2, "daring": 5, "clean_round": 10, "hit": -25}
## The act a kill scores; apply_kill takes its change, the kill's share of KILL_BUDGET.
const KILL_ACT := "kill"
## What a round's kills pay in all, shared by the enemies of its table (kill_value): round 1's
## nine and round 7's fifty-three bring the meter the same distance with their kills (chains still
## grow with the crowd). The boss pays it as it bleeds: each loud hit its share of the damage over
## its max hp (boss_hit_share) up to BOSS_KILL_RESERVE short of it, its kill what the hits left
## (kill_share's clamp): the reserve at least. A summon is not
## in the table and pays and spends nothing (kill_share); the clamp to what is left otherwise only
## guards kills beyond the table's count, which the shipped series never has.
const KILL_BUDGET := 40.0
## The fraction of KILL_BUDGET the boss's hits never spend (boss_hit_share): without a burn the
## loud hits sum to at least its max hp, so with no reserve they would pay the whole budget and its
## kill nothing. The kill stays the crowd's moment: it pays the reserve and whatever the hits left.
const BOSS_KILL_RESERVE := 0.25
## The acts that never lift the meter past the Roar edge while the round's gate is closed: kills,
## chains, dares, and the clean round stop at ROAR_GATE, so a Roar takes a daring kill, in round 1
## as in round 7. A capped act at or above the gate adds nothing then, but is still a scoring act
## (it holds the decay off). The round's first daring kill opens the gate (Favour.gate_open): from
## then on the capped acts add in full, up to MAX, until the next round's start closes it.
const CAPPED_ACTS: Array[String] = [KILL_ACT, "chain", "dare", "clean_round"]
const ROAR_GATE := 74.0  ## one under BAND_EDGES[ROAR - 1]: no Roar without a daring kill; a test pins the tie
## The act favour_changed names when a round's start brings the meter down to the gate (settle).
const SETTLE_ACT := "settle"
## A kill this soon after the last one is a chain.
const CHAIN_WINDOW := 1.5
## A kill this soon after a dash through danger ended is daring.
const DASH_WINDOW := 0.75
## A dash whose path passes this close to a live enemy went through danger: a dare (so is one
## that passes BOLT_RADIUS from an enemy's bolt; one dare a dash, whatever it passed).
const DANGER_RADIUS := 32.0
## A dash whose dashing point passes this close to an enemy's bolt, both moving, was a narrow
## escape: a dare too (dash_past_bolt). A first cut, judged on the playtest.
const BOLT_RADIUS := 20.0
## The decay: seconds since the last scoring act, while a run is live, before the crowd's
## interest fades, and what the meter loses a second past them. Running away, idling, and the
## gap between rounds (collecting coins slowly) all decay; fighting (killing) keeps the meter. A
## hit on an enemy that does not kill holds nothing, but for the boss's: a hit on it pays its share
## of the budget as a kill (boss_hit_share), so restarts the grace (Favour._on_enemy_hit).
const DECAY_GRACE := 2.0
const DECAY_PER_SECOND := 4.0
## The act favour_changed names for the decay; a rate, so not an ACTS row.
const DECAY_ACT := "decay"
## Where a round's favour went, for the crowd's judgement at the pick (Favour.round_losses): a
## hit's drop is `hit`; a drain while a harmful enemy lives is `slow` while the gladiator fights
## (an enemy near, or a shot landed lately) and `fled` while it runs (drain_source); a drain with
## no harmful enemy alive (a wave's spawn-in, the gap between rounds) is nobody's. The order
## breaks ties. The words are the story's round_loss list, with LOSS_NONE.
const LOSS_SOURCES: Array[String] = ["hit", "fled", "slow"]
const LOSS_NONE := "none"
## A harmful enemy this close to the gladiator makes a drain `slow` (they stood in the fight):
## six tiles, about the spawner's minimum distance from the player.
const NEAR_RADIUS := 96.0
## A source's tally must reach this to be the round's main loss: a hit at an empty meter, or a
## tick of decay, is no judgement.
const LOSS_FLOOR := 1.0

## The bands, in order; band() gives the index. BAND_EDGES are the lower edges of the upper three.
const BOO := 0
const QUIET := 1
const CHEER := 2
const ROAR := 3
const BAND_EDGES := [25.0, 50.0, 75.0]
## The bands' names, by index: what the profile files a round's verdict under.
const BAND_NAMES: Array[String] = ["boo", "quiet", "cheer", "roar"]
const OFFER_COUNT := 3
const OFFER_COUNT_ROAR := 4
## How many of the offered cards the crowd takes at a Boo (shown, greyed and chained, not
## pickable; UpgradeCatalog.locked_index says which): the Boo's mirror of the Roar's extra card.
## Read as none or some: locked_index locks one card for any count above zero, so a value above
## 1 needs that rule and the menu's one `locked` slot to grow first.
const LOCKS_AT_BOO := 1


static func band(value: float) -> int:
	var result := BOO
	for edge: float in BAND_EDGES:
		if value >= edge:
			result += 1
	return result


static func band_name(band_index: int) -> String:
	return BAND_NAMES[band_index]


## The meter after the table's `act`, clamped; while the round's gate is closed a capped act stops
## at ROAR_GATE and adds nothing above it, and once `gate_open` it adds in full.
static func apply(value: float, act: String, gate_open := false) -> float:
	assert(ACTS.has(act), "FavourRules: no act '%s'" % act)
	return _gated(value, act, float(ACTS[act]), gate_open)


## The meter after a kill paying `share` (kill_share), under the same gate as apply.
static func apply_kill(value: float, share: float, gate_open := false) -> float:
	return _gated(value, KILL_ACT, share, gate_open)


static func _gated(value: float, act: String, change: float, gate_open: bool) -> float:
	var result := value + change
	if act in CAPPED_ACTS and not gate_open:
		result = value if value >= ROAR_GATE else minf(result, ROAR_GATE)
	return clamp_value(result)


## The crowd settles between rounds: the meter a round starts at, never past the gate, so every
## round's Roar takes its own daring kill.
static func settle(value: float) -> float:
	return minf(value, ROAR_GATE)


## One kill's worth in a round of `enemies_in_round`: the budget over the count (a count below one
## reads as one, so the boss's round pays it whole).
static func kill_value(enemies_in_round: int) -> float:
	return KILL_BUDGET / float(maxi(enemies_in_round, 1))


## What the next kill pays after `paid` of the round's budget went to its kills: its worth, or what
## is left of the budget when less (a guard for kills beyond the table's count: none in the shipped
## series), never below 0. A summon's kill pays nothing: it is not in the table.
static func kill_share(enemies_in_round: int, paid: float, summoned := false) -> float:
	if summoned:
		return 0.0
	return clampf(KILL_BUDGET - paid, 0.0, kill_value(enemies_in_round))


## What a loud hit of `damage` on the boss pays after `paid` of the round's budget went out: the
## budget's share of the damage over `max_hp` (a max below one reads as one), never past the
## reserve line (KILL_BUDGET less BOSS_KILL_RESERVE of it: an overkill, or hits once the line is
## reached, pay only what is left below it), never below 0; the kill pays the rest (kill_share).
## Scored as the kill act through apply_kill, so the round's gate caps it as it caps a kill. The
## rule assumes the boss alone in its round's table, as shipped: a boss beside table enemies would
## spend their shares with its hits.
static func boss_hit_share(damage: float, max_hp: float, paid: float) -> float:
	var share := KILL_BUDGET * damage / maxf(max_hp, 1.0)
	var line := KILL_BUDGET * (1.0 - BOSS_KILL_RESERVE)
	return clampf(share, 0.0, maxf(line - paid, 0.0))


static func clamp_value(value: float) -> float:
	return clampf(value, 0.0, MAX)


## True for an act that raises the meter: the decay's grace counts from the last of them.
static func is_scoring(act: String) -> bool:
	if act == KILL_ACT:
		return true
	assert(ACTS.has(act), "FavourRules: no act '%s'" % act)
	return float(ACTS[act]) > 0.0


static func offer_count(band_index: int) -> int:
	return OFFER_COUNT_ROAR if band_index >= ROAR else OFFER_COUNT


## How many offered cards the crowd locks for a round ended in `band_index`: LOCKS_AT_BOO at a
## Boo, none at any other band (a Roar gives a card instead).
static func lock_count(band_index: int) -> int:
	return LOCKS_AT_BOO if band_index == BOO else 0


## True when the dash segment from `from` to `to` passes within `radius` of any position. An
## enemy behind the start or past the end counts only when it is within the radius of that end.
static func dash_through_danger(from: Vector2, to: Vector2, enemy_positions: Array[Vector2], radius: float) -> bool:
	for at: Vector2 in enemy_positions:
		if _distance_to_segment(from, to, at) <= radius:
			return true
	return false


## True when the dashing point, moving in a straight line from `from` to `to` over `duration`,
## comes within `radius` of any bolt over the same time. `bolts` holds [position, velocity] pairs
## taken at the dash's start; each bolt flies straight on. The closest approach of two points in
## linear motion: their offset moves at the difference of their velocities, nearest at the time
## that minimises it, clamped to the dash.
static func dash_past_bolt(from: Vector2, to: Vector2, duration: float, bolts: Array[Array], radius: float) -> bool:
	var dash_velocity := (to - from) / duration if duration > 0.0 else Vector2.ZERO
	for bolt: Array in bolts:
		var offset: Vector2 = from - (bolt[0] as Vector2)
		var closing: Vector2 = dash_velocity - (bolt[1] as Vector2)
		var t := 0.0
		if closing.length_squared() > 0.0:
			t = clampf(-offset.dot(closing) / closing.length_squared(), 0.0, maxf(duration, 0.0))
		if (offset + closing * t).length() <= radius:
			return true
	return false


## The decay for `delta` seconds after `idle_seconds` without a scoring act: nothing inside the
## grace, DECAY_PER_SECOND past it (negative, a change to the meter).
static func decay(idle_seconds: float, delta: float) -> float:
	if idle_seconds < DECAY_GRACE:
		return 0.0
	return -DECAY_PER_SECOND * delta


## The source a drain is tallied under, from the nearest harmful enemy's distance to the
## gladiator and whether it is `engaged` (a shot landed on an enemy within the last DECAY_GRACE
## seconds): `slow` within NEAR_RADIUS or while engaged (fighting at range is fighting), `fled`
## only far and hitting nothing (running), "" with no harmful enemy (INF).
static func drain_source(nearest_enemy_distance: float, engaged: bool) -> String:
	if is_inf(nearest_enemy_distance):
		return ""
	return "slow" if engaged or nearest_enemy_distance <= NEAR_RADIUS else "fled"


## The round's main loss from its tallies (source to points lost): the largest reaching
## LOSS_FLOOR, ties broken in LOSS_SOURCES' order; LOSS_NONE when none reaches it.
static func main_loss(losses: Dictionary) -> String:
	var result := LOSS_NONE
	var most := 0.0
	for source: String in LOSS_SOURCES:
		var lost := float(losses.get(source, 0.0))
		if lost >= LOSS_FLOOR and lost > most:
			result = source
			most = lost
	return result


static func _distance_to_segment(from: Vector2, to: Vector2, point: Vector2) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared == 0.0:
		return from.distance_to(point)
	var t := clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
	return (from + segment * t).distance_to(point)
