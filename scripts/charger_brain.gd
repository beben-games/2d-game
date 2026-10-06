class_name ChargerBrain
extends RefCounted
## The charger's cycle: approach, wind up (the line on the floor), charge along it, skid, then
## approach again. Pure: the enemy feeds it the distance to its target and whether it is on
## screen, and reads back the transitions (tick's return) and the approach's wish; the charge's
## motion is the enemy's (its charge_dir, fixed at the wind-up). The arena's rule 2: a wind-up
## begins only while visible; one begun runs its charge and skid off screen; off screen,
## approaching, it walks at the player.

enum Phase { APPROACH, WINDUP, CHARGE, SKID }

## tick's, interrupt's, and end_charge's returns: the phase just entered ("" when none).
const WINDUP := "windup"
const CHARGE := "charge"
const SKID := "skid"
const DONE := "done"  ## the skid over, approaching again
const ARC_EPSILON := 1e-6  ## radians: from_behind counts the arc's edge as inside despite rounding

var phase := Phase.APPROACH
var phase_time := 0.0


## Advances the cycle by `delta`. Returns the transition this tick made, or "". `visible`: the body
## is on the screen (View.on_screen); APPROACH never becomes WINDUP without it.
func tick(delta: float, distance: float, def: EnemyDef, visible: bool) -> String:
	phase_time += delta
	match phase:
		Phase.APPROACH:
			if visible and distance <= def.charge_range:
				_enter(Phase.WINDUP)
				return WINDUP
		Phase.WINDUP:
			if phase_time >= def.windup_time:
				_enter(Phase.CHARGE)
				return CHARGE
		Phase.CHARGE:
			if phase_time >= def.charge_time:
				_enter(Phase.SKID)
				return SKID
		Phase.SKID:
			if phase_time >= def.skid_time:
				_enter(Phase.APPROACH)
				return DONE
	return ""


## The approach walks at the player (on screen or off); the wind-up and the skid stand, and the
## charge's motion is not a wish.
func wish(to_target: Vector2) -> Vector2:
	return to_target if phase == Phase.APPROACH else Vector2.ZERO


func charging() -> bool:
	return phase == Phase.CHARGE


## A stun: mid-wind-up the charge is cancelled (back to APPROACH, the next wind-up from zero, so
## the line is never cut short into a charge); mid-charge the run ends into the skid (SKID
## returned). A no-op otherwise ("").
func interrupt() -> String:
	match phase:
		Phase.WINDUP:
			_enter(Phase.APPROACH)
		Phase.CHARGE:
			_enter(Phase.SKID)
			return SKID
	return ""


## A wall met mid-charge ends the run into the skid (SKID); "" outside a charge.
func end_charge() -> String:
	if phase != Phase.CHARGE:
		return ""
	_enter(Phase.SKID)
	return SKID


## How far a full charge carries the body: the line's length when no wall cuts it.
static func reach(def: EnemyDef) -> float:
	return def.charge_speed * def.charge_time


## True when a shot flying along `shot_direction` arrives inside `arc_degrees` of the back of a body
## facing `facing` (a shot from behind flies along the facing). The arc's edge is inside; a zero
## vector is never from behind.
static func from_behind(facing: Vector2, shot_direction: Vector2, arc_degrees: float) -> bool:
	if facing == Vector2.ZERO or shot_direction == Vector2.ZERO:
		return false
	var half := deg_to_rad(arc_degrees) / 2.0
	return absf(facing.angle_to(shot_direction)) <= half + ARC_EPSILON


func _enter(next: Phase) -> void:
	phase = next
	phase_time = 0.0
