class_name GroundsDoorDef
extends Resource
## A door of a grounds room: the wall it is in (the gap at that wall's middle, ArenaGrid.door_gap),
## the room behind it, and the story condition under which it shows ("" always). A door whose
## condition does not hold is wall: no gap, nothing to act on.

@export var side: ArenaGrid.Side = ArenaGrid.Side.TOP
## The id of the room behind it (a GroundsRooms id).
@export var to := ""
## A story condition (StoryCondition's grammar, every name StoryContext knows), "" for always.
@export var when := ""


## The interactable's id: "door:<to>". One door to a room per room, so the id is the room's.
func item_id() -> String:
	return "door:" + to


## True when the condition holds in `context` (always for none; never for one that does not parse,
## which validate() reports).
func is_open(context: StoryContext) -> bool:
	if when.strip_edges().is_empty():
		return true
	var parsed := StoryCondition.parse(when)
	var condition: StoryCondition = parsed["condition"]
	return condition != null and condition.evaluate(context)


## What is wrong with the condition against `context`'s names: "" when it is empty or sound.
func condition_error(context: StoryContext) -> String:
	if when.strip_edges().is_empty():
		return ""
	var parsed := StoryCondition.parse(when)
	if parsed["error"] != "":
		return str(parsed["error"])
	var condition: StoryCondition = parsed["condition"]
	return "; ".join(condition.check(context))


## The wall's name for a message: "top", "bottom", "left", "right".
static func side_name(wall: int) -> String:
	return str(ArenaGrid.Side.keys()[wall]).to_lower() if wall in ArenaGrid.Side.values() else str(wall)
