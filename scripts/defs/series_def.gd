class_name SeriesDef
extends Resource
## A run: the arena's size in tiles and its rounds in order, all fought in the one arena.
## Clearing the last round wins. A shipped series is a tier (Tiers: data/series/tier_<n>.tres) and
## says which; a series made in code (a test's, the smoke tool's) is tier 1 unless it says otherwise.
## `first_win_unlock` is what the series' first win opens on the save (boss loot as data): "" for
## nothing, or "tier:<n>" (UNLOCK_TIER), a tier above its own (Tiers.errors_of checks that tier
## exists, so this class stays free of Tiers). Phase 1's only kind; a class, a weapon, or a grounds
## area are later kinds of the same field.

@export var tier: int = 1
@export var arena_width: int = 28
@export var arena_height: int = 15
@export var rounds: Array[RoundDef] = []
@export var first_win_unlock: String = ""

## The tier unlock's prefix: "tier:2" opens tier 2.
const UNLOCK_TIER := "tier:"


## The tier a first_win_unlock text opens ("tier:2" is 2), or 0 for "" and for anything that is
## not "tier:" and a positive integer written plainly.
static func unlock_tier_of(text: String) -> int:
	if not text.begins_with(UNLOCK_TIER):
		return 0
	var n := text.trim_prefix(UNLOCK_TIER)
	return int(n) if n.is_valid_int() and int(n) > 0 and str(int(n)) == n else 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if tier < 1:
		errors.append("tier must be >= 1")
	# The top gap needs width / 2 - 1 >= 1 (ArenaGrid.door_cells); the rest is playable floor.
	if arena_width < 8:
		errors.append("arena_width must be >= 8")
	if arena_height < 6:
		errors.append("arena_height must be >= 6")
	if first_win_unlock != "":
		var opens := unlock_tier_of(first_win_unlock)
		if opens == 0:
			errors.append("first_win_unlock must be \"\" or tier:<n>")
		elif opens <= tier:
			errors.append("first_win_unlock tier %d is not above the series' tier %d" % [opens, tier])
	if rounds.is_empty():
		errors.append("series has no rounds")
	for i in rounds.size():
		if rounds[i] == null:
			errors.append("round %d: missing" % i)
			continue
		for e in rounds[i].validate():
			errors.append("round %d: %s" % [i, e])
	return errors


func is_last(index: int) -> bool:
	return index >= rounds.size() - 1
