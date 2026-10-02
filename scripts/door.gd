class_name Door
extends Interactable
## A door of a grounds room: the gap in the wall (no art of its own: the arena leaves the gap's
## cells unpainted, so the void reads as a passage) closed by an invisible blocker on the walls'
## layer, and the floor before the gap as its area. E on it walks to the room behind it (Main reads
## `to`). Built by Grounds from a GroundsDoorDef, never placed by hand.

## The area reaches this far past the floor tile before the gap, as a station's does past its art.
const AREA_MARGIN := 6.0

## The id of the room behind it.
var to := ""
## The wall it is in (ArenaGrid.Side).
var side: int = ArenaGrid.Side.TOP
## The StaticBody2D filling the gap on the walls' layer, so the ring stays solid for every body
## (the player walking or dashing masks it).
var blocker: StaticBody2D
## The gap's size: two tiles along the wall, the wall's depth across it.
var gap_size: Vector2


## The door to `target` in the gap `gap` (world pixels) of the wall `wall`: the node at the gap's
## top-left, the area the floor tile before the gap (the gap's width along the wall) grown by
## AREA_MARGIN, the key cap over the gap's top centre.
func setup_door(target: String, wall: int, gap: Rect2) -> void:
	to = target
	side = wall
	gap_size = gap.size
	var t := float(ArenaGrid.TILE)
	var floor_tile: Rect2
	match wall:
		ArenaGrid.Side.TOP:
			floor_tile = Rect2(0.0, gap.size.y, gap.size.x, t)
		ArenaGrid.Side.BOTTOM:
			floor_tile = Rect2(0.0, -t, gap.size.x, t)
		ArenaGrid.Side.LEFT:
			floor_tile = Rect2(gap.size.x, 0.0, t, gap.size.y)
		_:
			floor_tile = Rect2(-t, 0.0, t, gap.size.y)
	setup(id_for(target), "door", gap.position, floor_tile.grow(AREA_MARGIN))
	prompt = Vector2(gap.size.x * 0.5, 0.0)
	blocker = StaticBody2D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = Projectile.WALL_MASK  # the walls' layer (5)
	blocker.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = gap.size
	shape.shape = rectangle
	shape.position = gap.size * 0.5
	blocker.add_child(shape)
	add_child(blocker)


## The id of the door to the room `room_id`: "door:<room>" (one door to a room in a room).
static func id_for(room_id: String) -> String:
	return "door:" + room_id


## The way out through this door into the room: the unit vector from the wall onto the floor.
func inward() -> Vector2:
	return inward_of(side)


## The middle of the gap's edge on the floor, in world pixels.
func threshold() -> Vector2:
	return threshold_of(Rect2(global_position, gap_size), side)


## From a wall onto the floor: the unit vector.
static func inward_of(wall: int) -> Vector2:
	match wall:
		ArenaGrid.Side.TOP:
			return Vector2.DOWN
		ArenaGrid.Side.BOTTOM:
			return Vector2.UP
		ArenaGrid.Side.LEFT:
			return Vector2.RIGHT
	return Vector2.LEFT


## The middle of the edge of the gap `gap` (in the wall `wall`) that meets the floor.
static func threshold_of(gap: Rect2, wall: int) -> Vector2:
	var inward := inward_of(wall)
	return gap.get_center() + inward * (absf(gap.size.dot(inward)) * 0.5)
