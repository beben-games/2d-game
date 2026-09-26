class_name VerdictRules
extends RefCounted
## The emperor's verdict at the run's end, pure. In M5 the thumb is always up unless the verso
## cheat's thumbs_down flag is on (pollice verso: the thumb turned), so the DOWN path is built and
## tested but never seen in play. The band, the hits taken, and the profile's flags are here so
## M9's turning point can fill the rule without touching a caller; decide reads only the cheats.

const GATE_UP := "Porta Triumphalis"
const GATE_DOWN := "Porta Libitinaria"


## True is UP (the coins banked, the triumphal gate); false is DOWN (the coins lost, a death).
## band is FavourRules.band of the favour at the end, hits_taken the run's, flags the profile's
## (Save.flags), cheats the run's (RunState.cheats).
static func decide(_band: int, _hits_taken: int, _flags: Dictionary, cheats: Dictionary) -> bool:
	return not bool(cheats.get("thumbs_down", false))


## The gate screen's title: the gate the verdict sends the gladiator through.
static func gate_name(up: bool) -> String:
	return GATE_UP if up else GATE_DOWN
