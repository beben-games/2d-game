class_name BossBrain
extends RefCounted
## The boss's cycle, pure: APPROACH (walk at the player) -> TELEGRAPH -> ATTACK -> RECOVER, one
## pattern per cycle in a fixed order (ring, volley, charge; plus summon in stage 2). tick()
## advances and returns the action for the tick an attack lands; the body performs it. Stage 2 is
## requested by the body when HP falls to the fraction and applied at the next phase edge tick()
## takes, so a running charge is never cut short and the body sees the flip around one tick(); its
## timings and ring count replace stage 1's from then on.

enum Phase { APPROACH, TELEGRAPH, ATTACK, RECOVER }
enum Pattern { RING, VOLLEY, CHARGE, SUMMON }

## Stage one's cycle is a prefix of stage two's, so _cycle_index stays valid across the flip: it
## points at the same pattern in both, and the next advance takes the longer cycle.
const STAGE1_CYCLE: Array[int] = [Pattern.RING, Pattern.VOLLEY, Pattern.CHARGE]
const STAGE2_CYCLE: Array[int] = [Pattern.RING, Pattern.VOLLEY, Pattern.CHARGE, Pattern.SUMMON]
const ACTION_NONE := ""
const ACTION_RING := "ring"
const ACTION_VOLLEY := "volley"
const ACTION_CHARGE := "charge"
const ACTION_CHARGE_END := "charge_end"
const ACTION_SUMMON := "summon"
const ACTIONS := {Pattern.RING: ACTION_RING, Pattern.VOLLEY: ACTION_VOLLEY, Pattern.CHARGE: ACTION_CHARGE, Pattern.SUMMON: ACTION_SUMMON}

var phase := Phase.APPROACH
var pattern: int = Pattern.RING  ## the pattern this cycle winds up and lands
var phase_time := 0.0
var stage := 1
var enrage_requested := false

var _cycle_index := 0


## Advances the cycle by delta. Returns the action that lands this tick, or ACTION_NONE.
func tick(delta: float, def: BossDef) -> String:
	phase_time += delta
	match phase:
		Phase.APPROACH:
			if phase_time >= def.approach_time:
				_edge(Phase.TELEGRAPH)
		Phase.TELEGRAPH:
			if phase_time >= telegraph_time(def):
				_edge(Phase.ATTACK)
				return _attack_action()
		Phase.ATTACK:
			if pattern != Pattern.CHARGE:
				_edge(Phase.RECOVER)  # a ring, a volley, or a summon lands on one tick
			elif phase_time >= def.charge_time:
				_edge(Phase.RECOVER)
				return ACTION_CHARGE_END
		Phase.RECOVER:
			if phase_time >= recover_time(def):
				_edge(Phase.APPROACH)
				_advance_pattern()
	return ACTION_NONE


func charging() -> bool:
	return phase == Phase.ATTACK and pattern == Pattern.CHARGE


## A wall ends a charge early. Returns ACTION_CHARGE_END, or ACTION_NONE when not charging.
func end_charge() -> String:
	if not charging():
		return ACTION_NONE
	_enter(Phase.RECOVER)
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


func telegraph_time(def: BossDef) -> float:
	return def.phase2_telegraph_time if stage == 2 else def.telegraph_time


func recover_time(def: BossDef) -> float:
	return def.phase2_recover_time if stage == 2 else def.recover_time


func ring_count(def: BossDef) -> int:
	return def.phase2_ring_count if stage == 2 else def.ring_count


## Movement wish: toward the player while approaching, still otherwise. The charge moves the body
## on its own locked direction.
func wish(to_target: Vector2) -> Vector2:
	return to_target if phase == Phase.APPROACH else Vector2.ZERO


func _attack_action() -> String:
	return ACTIONS[pattern]


func _advance_pattern() -> void:
	var cycle := STAGE2_CYCLE if stage == 2 else STAGE1_CYCLE
	_cycle_index = (_cycle_index + 1) % cycle.size()
	pattern = cycle[_cycle_index]


## A phase edge taken inside tick(): the only place the requested stage lands, so the body detects
## the change by comparing `stage` around one tick() call. end_charge() and interrupt() go through
## _enter and leave the stage alone; the request waits for the next tick edge.
func _edge(next: Phase) -> void:
	if enrage_requested and stage == 1:
		stage = 2
		enrage_requested = false
	_enter(next)


func _enter(next: Phase) -> void:
	phase = next
	phase_time = 0.0
