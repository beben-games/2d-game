class_name Room
extends Node2D
## One room of a floor. Owns everything that dies with it: tiles and walls, doors, enemies,
## projectiles, and spawning. Main sets def and entry_side before adding it to the tree.

var def: RoomDef
var entry_side: int = FloorRules.NO_DOOR

var exit_door: Door

@onready var arena: Arena = $Arena
@onready var doors: Node2D = $Doors
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var spawner: Spawner = $Spawner


func _ready() -> void:
	assert(def != null, "Room needs a RoomDef")
	var errors := def.validate()
	assert(errors.is_empty(), "Invalid room def: %s" % ", ".join(errors))
	assert(entry_side != def.exit_side, "Room entry and exit share a side; FloorDef.validate should have caught this")
	var sides := [def.exit_side]
	if entry_side != FloorRules.NO_DOOR:
		sides.append(entry_side)
	arena.build(def.width, def.height, sides)
	exit_door = Door.new()
	exit_door.setup(def.exit_side, def.width, def.height, true)
	doors.add_child(exit_door)
	if entry_side != FloorRules.NO_DOOR:
		var entry := Door.new()
		entry.setup(entry_side, def.width, def.height, false)
		doors.add_child(entry)
	spawner.arena = arena
	spawner.enemies_parent = enemies


func bounds() -> Rect2:
	return arena.bounds()


## Where the player stands on arrival: the floor tile just inside the entry door, or the center.
func entry_position() -> Vector2:
	if entry_side == FloorRules.NO_DOOR:
		return bounds().get_center()
	var gap := ArenaGrid.door_gap(def.width, def.height, entry_side)
	var inset := ArenaGrid.TILE * 0.5  # center of the first floor tile past the gap
	var y := gap.end.y + inset if entry_side == RoomDef.Side.TOP else gap.position.y - inset
	return Vector2(gap.get_center().x, y)


func open_exit() -> void:
	exit_door.open()
