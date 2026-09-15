class_name UpgradeDef
extends Resource
## One card. WEAPON cards belong to one weapon and fold modifiers into it; PLAYER cards fold
## into max_hp and dash_charges; HEAL restores a heart and touches no build; SWITCH swaps the
## weapon to weapon_id and refunds the picks. Adding content means adding a .tres file.

enum Kind { WEAPON, PLAYER, HEAL, SWITCH }

## How a stat reads in summary(): "+2 damage", "+56% fire rate". Stats missing here print
## another way or not at all: max_hp counts hearts, dash_charges dashes, projectile_count "per
## shot", pierce "pierce +N"; spread_degrees is silent (multishot's companion); the flag stats
## (FLAG_STATS) make the card keep its description, since they cannot stack (max_rank 1).
const PHRASES := {
	"damage": "damage",
	"fire_rate": "fire rate",
	"projectile_speed": "shot speed",
	"knockback": "knockback",
	"lifetime": "range",
	"recoil": "recoil",
	"inaccuracy_degrees": "spread",
}
const FLAG_STATS: Array[String] = ["bounce", "homing", "burn", "stun", "chill"]

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""  ## the effect line on the card, per pick; summary() totals it
@export var icon: String = ""  ## IconAtlas name
@export var kind: UpgradeDef.Kind = Kind.WEAPON  # qualified: a bare enum annotation breaks external test scripts in 4.7.2
## WEAPON: the weapon this card belongs to. SWITCH: the weapon it switches to. Empty otherwise.
@export var weapon_id: String = ""
@export var max_rank: int = 1  ## ignored for HEAL and SWITCH cards, where 1 satisfies validate
@export var modifiers: Array[Modifier] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == "":
		errors.append("id must be set")
	if name == "":
		errors.append("name must be set")
	if max_rank < 1:
		errors.append("max_rank must be >= 1")
	match kind:
		Kind.WEAPON:
			if weapon_id == "":
				errors.append("weapon_id must be set for a weapon upgrade")
			_check_stats(errors, Modifier.WEAPON_STATS, "weapon")
		Kind.PLAYER:
			if weapon_id != "":
				errors.append("weapon_id must be empty for a player upgrade")
			_check_stats(errors, Modifier.PLAYER_STATS, "player")
		Kind.HEAL:
			if weapon_id != "":
				errors.append("weapon_id must be empty for a heal card")
			if not modifiers.is_empty():
				errors.append("a heal card has no modifiers")
		Kind.SWITCH:
			if weapon_id == "":
				errors.append("weapon_id must name the weapon a switch card switches to")
			if not modifiers.is_empty():
				errors.append("a switch card has no modifiers")
	return errors


func _check_stats(errors: PackedStringArray, allowed: Array[String], label: String) -> void:
	for i in modifiers.size():
		var m := modifiers[i]
		if m == null:
			errors.append("modifier %d: missing" % i)
			continue
		for e: String in m.validate():
			errors.append("modifier %d: %s" % [i, e])
		if m.stat != "" and m.stat not in allowed and Modifier.is_known_stat(m.stat):
			errors.append("modifier %d: '%s' is not a %s stat" % [i, m.stat, label])


## The cumulative effect of `rank` ranks, for the build screen: adds total, muls compound
## (fire rate at rank 2 is +56%, not +50%). Cards with no modifiers or with a flag stat return
## their description. Parts join with ", ".
func summary(rank: int) -> String:
	if modifiers.is_empty():
		return description
	var parts := PackedStringArray()
	for m in modifiers:
		if m.stat in FLAG_STATS:
			return description
		if m.stat == "spread_degrees":
			continue
		if m.mul != 1.0:
			var percent := roundi((pow(m.mul, rank) - 1.0) * 100.0)
			parts.append("%s%% %s" % [_signed(percent), PHRASES[m.stat]])
		if m.add != 0.0:
			parts.append(_add_part(m.stat, m.add * rank))
	return ", ".join(parts)


func _add_part(stat: String, total: float) -> String:
	match stat:
		"max_hp":
			var hearts := total / HeartRules.HP_PER_HEART
			return "%s heart%s" % [_signed(hearts), "" if is_equal_approx(absf(hearts), 1.0) else "s"]
		"dash_charges":
			return "%s dash%s" % [_signed(total), "" if is_equal_approx(absf(total), 1.0) else "es"]
		"projectile_count":
			return "%s per shot" % _signed(total)
		"pierce":
			return "pierce %s" % _signed(total)
	return "%s %s" % [_signed(total), PHRASES[stat]]


## "+2", "-1", "+0.5": a leading plus for a gain, an int when whole.
static func _signed(value: float) -> String:
	var text := str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(value)
	return "+" + text if value >= 0.0 else text
