class_name BossBrain
extends RefCounted
## The boss's cycle, pure: APPROACH (walk at the player) -> TELEGRAPH -> ATTACK -> RECOVER (walk on
## at def.recover_move of the speed), one pattern per cycle in the def's order (tier 1's: ring,
## volley, charge; plus summon in stage 2). tick() advances and returns the action for the tick an
## attack lands; the body performs it. Stage 2 is requested by the body when HP falls to the
## fraction (or its partner dies) and applied at the next phase edge tick() takes, so a running
## charge is never cut short and the body sees the flip around one tick(); its timings and ring
## count replace stage 1's from then on. A charge may be a chain (def.charge_chain): each leg
## winds up in full, the next leg's wind-up begins on the first tick in view after the last run
## ends, and only the last leg recovers.

enum Phase { APPROACH, TELEGRAPH, ATTACK, RECOVER }
enum Pattern { RING, VOLLEY, CHARGE, SUMMON }

## Tier 1's cycles (BossDef's defaults, by name). Stage one's is a prefix of stage two's, so
## _cycle_index stays valid across the flip: it points at the same pattern in both, and the next
## advance takes the longer cycle. A def whose stage two lacks the pattern under way when the flip
## lands on a wind-up's edge winds up stage two's pattern at that place instead (_edge).
const STAGE1_CYCLE: Array[int] = [Pattern.RING, Pattern.VOLLEY, Pattern.CHARGE]
const STAGE2_CYCLE: Array[int] = [Pattern.RING, Pattern.VOLLEY, Pattern.CHARGE, Pattern.SUMMON]
const ACTION_NONE := ""
const ACTION_RING := "ring"
const ACTION_VOLLEY := "volley"
const ACTION_CHARGE := "charge"
const ACTION_CHARGE_END := "charge_end"
const ACTION_SUMMON := "summon"
const ACTIONS := {Pattern.RING: ACTION_RING, Pattern.VOLLEY: ACTION_VOLLEY, Pattern.CHARGE: ACTION_CHARGE, Pattern.SUMMON: ACTION_SUMMON}
## keep_range's dead band, px: within it of the range the body holds still, so it never jitters
## across the line.
const KEEP_SLACK := 8.0

var phase := Phase.APPROACH
var pattern: int = Pattern.RING  ## the pattern this cycle winds up and lands
var phase_time := 0.0
var stage := 1
var enrage_requested := false
## The chain's leg under way or next (0 the first); back to 0 as the last leg recovers.
var leg := 0

var _cycle_index := 0


## With a def the brain opens on its stage-one cycle's first pattern; without one, tier 1's ring.
func _init(def: BossDef = null) -> void:
	if def != null:
		var cycle := cycle_of(def)
		if not cycle.is_empty():
			pattern = cycle[0]


## Pattern values for BossDef cycle names (BossBrain's action names); an unknown name is skipped
## (BossDef.validate reports it).
static func patterns_of(names: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for name in names:
		var at: int = ACTIONS.values().find(name)
		if at >= 0:
			out.append(ACTIONS.keys()[at])
	return out


## The current stage's cycle from the def.
func cycle_of(def: BossDef) -> Array[int]:
	return patterns_of(def.stage2_cycle if stage == 2 else def.stage1_cycle)


## Advances the cycle by delta. Returns the action that lands this tick, or ACTION_NONE.
## `visible`: the body is on the screen (View.on_screen, the arena's rule 2); the approach never ends in a
## telegraph without it (the timer runs on, so the first tick in view winds up). A wind-up or a
## charge begun finishes off screen.
func tick(delta: float, def: BossDef, visible: bool) -> String:
	phase_time += delta
	match phase:
		Phase.APPROACH:
			if visible and phase_time >= approach_time(def):
				_edge(Phase.TELEGRAPH, def)
		Phase.TELEGRAPH:
			if phase_time >= telegraph_time(def):
				_edge(Phase.ATTACK, def)
				return _attack_action()
		Phase.ATTACK:
			if pattern != Pattern.CHARGE:
				_edge(Phase.RECOVER, def)  # a ring, a volley, or a summon lands on one tick
			elif phase_time >= def.charge_time:
				_edge(_after_leg(def), def)
				return ACTION_CHARGE_END
		Phase.RECOVER:
			if phase_time >= recover_time(def):
				_edge(Phase.APPROACH, def)
				_advance_pattern(def)
	return ACTION_NONE


func charging() -> bool:
	return phase == Phase.ATTACK and pattern == Pattern.CHARGE


## A wall ends a charge early (the leg, in a chain: the next winds up as one ending on its time
## does). Returns ACTION_CHARGE_END, or ACTION_NONE when not charging. Without a def, a single run.
func end_charge(def: BossDef = null) -> String:
	if not charging():
		return ACTION_NONE
	_enter(_after_leg(def))
	return ACTION_CHARGE_END


## A stun mid-wind-up cuts the attack like the shooter's: back to APPROACH, the same pattern wound
## up again in full. A no-op outside TELEGRAPH.
func interrupt() -> void:
	if phase == Phase.TELEGRAPH:
		_enter(Phase.APPROACH)


## The body asks for stage 2 once HP is low; it lands at the next phase edge tick() takes.
func request_enrage() -> void:
	if stage == 1:
		enrage_requested = true


## The approach before a wind-up: the def's, or none between a chain's legs (the next leg winds
## up on the first tick in view).
func approach_time(def: BossDef) -> float:
	return 0.0 if leg > 0 else def.approach_time


func telegraph_time(def: BossDef) -> float:
	return def.phase2_telegraph_time if stage == 2 else def.telegraph_time


func recover_time(def: BossDef) -> float:
	return def.phase2_recover_time if stage == 2 else def.recover_time


func ring_count(def: BossDef) -> int:
	return def.phase2_ring_count if stage == 2 else def.ring_count


## Movement wish, a velocity: at the player at def.speed while approaching, at def.recover_move of
## it while recovering, still while winding up and attacking (the charge moves the body on its own
## locked direction). Zero on top of the player. With def.keep_range the way is keep_way's: away
## inside the range, in outside it, still within KEEP_SLACK of it; off screen (`visible` false) it
## closes on the player whatever the distance, so it never holds its range out of view.
func wish(to_target: Vector2, def: BossDef, visible := true) -> Vector2:
	var way := to_target
	if def.keep_range > 0.0 and visible:
		way = keep_way(to_target, def.keep_range)
	return way.normalized() * def.speed * move_factor(def)


## The way to keep `keep_range` from the target at `to_target`: toward it outside the range, away
## inside, zero within KEEP_SLACK of it.
static func keep_way(to_target: Vector2, keep_range: float) -> Vector2:
	var distance := to_target.length()
	if distance > keep_range + KEEP_SLACK:
		return to_target
	if distance < keep_range - KEEP_SLACK:
		return -to_target
	return Vector2.ZERO


## The phase's share of def.speed: 1 approaching, def.recover_move recovering, 0 otherwise.
func move_factor(def: BossDef) -> float:
	match phase:
		Phase.APPROACH:
			return 1.0
		Phase.RECOVER:
			return def.recover_move
	return 0.0


func _attack_action() -> String:
	return ACTIONS[pattern]


func _advance_pattern(def: BossDef) -> void:
	var cycle := cycle_of(def)
	_cycle_index = (_cycle_index + 1) % cycle.size()
	pattern = cycle[_cycle_index]


## Where a charge's leg goes when it ends: the next leg's approach (none: it winds up on the next
## tick in view) while the chain has legs left, else the recover, the chain begun again from 0.
func _after_leg(def: BossDef) -> Phase:
	var chain := def.charge_chain if def != null else 1
	if leg + 1 < chain:
		leg += 1
		return Phase.APPROACH
	leg = 0
	return Phase.RECOVER


## A phase edge taken inside tick(): the only place the requested stage lands, so the body detects
## the change by comparing `stage` around one tick() call. end_charge() and interrupt() go through
## _enter and leave the stage alone; the request waits for the next tick edge. A flip on the edge
## into a wind-up whose pattern stage two's cycle lacks takes that cycle's pattern at the same
## place (a chain under way begins again): never true of tier 1's cycles.
func _edge(next: Phase, def: BossDef) -> void:
	if enrage_requested and stage == 1:
		stage = 2
		enrage_requested = false
		var cycle := cycle_of(def)
		if next == Phase.TELEGRAPH and not cycle.is_empty() and not cycle.has(pattern):
			_cycle_index %= cycle.size()
			pattern = cycle[_cycle_index]
			leg = 0
	_enter(next)


func _enter(next: Phase) -> void:
	phase = next
	phase_time = 0.0
