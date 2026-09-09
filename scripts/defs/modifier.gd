class_name Modifier
extends Resource
## One change to one stat, applied once per rank of its upgrade: value = (value + add) * mul.
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


## Applies this modifier to a value once.
func apply(value: float) -> float:
	return (value + add) * mul
