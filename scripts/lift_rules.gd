class_name LiftRules
extends RefCounted
## The lifts' rules (pure: no Node, no autoload; Lift is the node): a lift's id names its tier, the
## open bays are the tiers the save may fight that have a series, and the bay that rises at a
## showing is the newest open one while it is above the lifts seen. Main, the Grounds, and the
## node read them here.

## Every lift's id starts so; the rest is its tier.
const PREFIX := "lift:"


## The lift's id for `tier`: "lift:<tier>".
static func id_for(tier: int) -> String:
	return "%s%d" % [PREFIX, tier]


## The tier a lift's id names, or 0 for an id that is no lift's (any other station, a door, a
## malformed id, a tier below 1).
static func tier_of(id: String) -> int:
	if not id.begins_with(PREFIX):
		return 0
	var rest := id.substr(PREFIX.length())
	if not rest.is_valid_int() or int(rest) < 1 or str(int(rest)) != rest:
		return 0
	return int(rest)


## The bays of `lift_tiers` (in their order) that are open: a tier the save may fight
## (`highest`, Save.highest_tier()) that has a series (Tiers.has).
static func open_tiers(lift_tiers: Array[int], highest: int) -> Array[int]:
	var open: Array[int] = []
	for tier in lift_tiers:
		if tier <= highest and Tiers.has(tier):
			open.append(tier)
	return open


## The tier whose bay rises open at this showing, or 0 for none: the newest open bay (the highest
## of open_tiers) while it is above `seen` (Save's unlocks.lifts_seen). Once seen it never rises
## again; a bay with no series never opens, so never rises.
static func rising_tier(lift_tiers: Array[int], highest: int, seen: int) -> int:
	var open := open_tiers(lift_tiers, highest)
	if open.is_empty():
		return 0
	var newest: int = open.max()
	return newest if newest > seen else 0
