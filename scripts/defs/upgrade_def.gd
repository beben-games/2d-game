class_name UpgradeDef
extends Resource
## One card. WEAPON cards belong to one weapon and fold modifiers into it; PLAYER cards fold
## into max_hp and dash_charges; HEAL restores a heart and touches no build; SWITCH swaps the
## weapon to weapon_id and refunds the picks. Adding content means adding a .tres file.

enum Kind { WEAPON, PLAYER, HEAL, SWITCH }

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""  ## the effect line on the card, per rank
@export var icon: String = ""  ## IconAtlas name
@export var kind: UpgradeDef.Kind = Kind.WEAPON  # qualified: a bare enum annotation breaks external test scripts in 4.7.2
## WEAPON: the weapon this card belongs to. SWITCH: the weapon it switches to. Empty otherwise.
@export var weapon_id: String = ""
@export var max_rank: int = 1
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
