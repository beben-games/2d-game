class_name Modifier
extends Resource
## One change to one stat. Ranks stack additively, applied once at the owned rank n as
## value = (value + add * n) * (1 + (mul - 1) * n), so a mul of 1.25 reads +25% / +50% / +75%
## of the base at ranks 1, 2, 3 instead of compounding (playtest 1: tiers should read 25/50/75).
## Stat names are WeaponDef's numeric fields plus the player stats; Build folds them.

## Weapon stats a modifier may name. bounce, projectile_count and pierce are ints; Build rounds them.
const WEAPON_STATS: Array[String] = [
	"damage", "fire_rate", "projectile_speed", "projectile_count", "spread_degrees",
	"inaccuracy_degrees", "lifetime", "knockback", "recoil", "pierce",
	"bounce", "homing", "burn", "stun", "chill",
]
const PLAYER_STATS: Array[String] = ["max_hp", "dash_charges"]
const INT_STATS: Array[String] = ["projectile_count", "pierce", "bounce", "max_hp", "dash_charges"]

@export var stat: String = ""
@export var add: float = 0.0
@export var mul: float = 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if stat == "":
		errors.append("stat must be set")
	elif not is_known_stat(stat):
		errors.append("unknown stat '%s'" % stat)
	if mul <= 0.0:
		errors.append("mul must be > 0")
	return errors


## True when stat is a weapon or a player stat; UpgradeDef tells the two apart.
static func is_known_stat(stat: String) -> bool:
	return stat in WEAPON_STATS or stat in PLAYER_STATS


## Applies `rank` ranks of this modifier to a value at once: adds and the mul bonus scale
## linearly with the rank.
func apply_ranks(value: float, rank: int) -> float:
	return (value + add * rank) * (1.0 + (mul - 1.0) * rank)
