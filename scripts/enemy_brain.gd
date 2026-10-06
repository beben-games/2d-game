class_name EnemyBrain
extends RefCounted
## What Enemy asks of any behaviour's brain (ShooterBrain, ChargerBrain): pure, fed by the enemy.
## The rest of a brain (its phases, its tick, its wish) is its own; Enemy casts to the brain it
## made to drive it.


## A stun mid-attack: the brain's own cut (a wind-up back to its approach, a run into its skid).
## Returns the phase the cut entered, when the enemy must answer it ("" for none).
func interrupt() -> String:
	return ""


## True while the body runs under its own momentum (a charger's run): no movement wish, and
## Favour sweeps it along its velocity for the dare.
func charging() -> bool:
	return false
