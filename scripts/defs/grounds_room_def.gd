class_name GroundsRoomDef
extends Resource
## One room of the grounds (data/grounds/<id>.tres): its size in tiles, its doors, its stations,
## the dressing drawn from the tileset, and the music it plays. Grounds builds itself from one.
## The keepers (a station's merchant) and the people (where a cast member stands) are the cast's
## places in the room, read when the cast is placed.

## The stations a room may hold: the training post, the armoury's rack, the lift to the arena.
const STATIONS: Array[String] = ["post", "rack", "lift"]

@export var id := ""
## The size in tiles: 26 x 15 for a grounds room now, so the whole room is in the 3x view (the
## arena's 28 is a little wider than the view and scrolls).
@export var width: int = 26
@export var height: int = 15
## At most one a wall, at most one to a room.
@export var doors: Array[GroundsDoorDef] = []
## Ids from STATIONS, each once.
@export var stations: Array[String] = []
## Station id to the cast id of the one who keeps it.
@export var keepers: Dictionary = {}
## Cast id to where they stand: a Vector2 fraction of the floor, each within 0..1
## (Grounds.floor_point).
@export var people: Dictionary = {}
## [sprite name, Vector2 fraction of the floor] pairs (Grounds.floor_point): the sprite's bottom
## centre at the fraction, its top-left then snapped to whole tiles, so a fraction need only land
## in the right tile. Wall art is placed by a negative y: at 0 a sprite's foot is the floor's top
## edge, so it hangs on the top wall's face; a tile's height higher reaches the ledge (-1/12 of a
## 15-row room's floor). Drawn under the gladiator; nothing collides.
@export var dressing: Array = []
## The loop the room plays (an Audio music name), "" for silence.
@export var music := "music_grounds"


## What is wrong with the room (empty when nothing is). `rooms` are the ids a door may lead to
## (the shipped rooms by default); `context` knows the names a door's condition may read (a fresh
## save's and no story flag by default). Pure: no autoload.
func validate(rooms: Array[String] = GroundsRooms.IDS, context: StoryContext = null) -> PackedStringArray:
	var errors := PackedStringArray()
	if context == null:
		context = StoryContext.new()
	if id.is_empty():
		errors.append("id must be set")
	# As SeriesDef's arena: a gap needs a wall either side of it, and the rest is floor.
	if width < 8:
		errors.append("width must be >= 8")
	if height < 6:
		errors.append("height must be >= 6")
	var sides: Array[int] = []
	var targets: Array[String] = []
	for i in doors.size():
		var door := doors[i]
		if door == null:
			errors.append("door %d: missing" % i)
			continue
		if door.to.is_empty():
			errors.append("door %d: leads nowhere" % i)
		elif door.to == id:
			errors.append("door %d: leads to its own room" % i)
		elif not door.to in rooms:
			errors.append("door %d: unknown room '%s'" % [i, door.to])
		if door.side in sides:
			errors.append("door %d: a second door on the %s wall" % [i, GroundsDoorDef.side_name(door.side)])
		elif door.to in targets:
			errors.append("door %d: a second door to %s" % [i, door.to])
		if door.side == ArenaGrid.Side.TOP and "lift" in stations:
			errors.append("door %d: the lift and a top door share the top gap" % i)
		sides.append(door.side)
		targets.append(door.to)
		var condition := door.condition_error(context)
		if not condition.is_empty():
			errors.append("door %d: when: %s" % [i, condition])
	var seen: Array[String] = []
	for station in stations:
		if not station in STATIONS:
			errors.append("unknown station '%s'" % station)
		elif station in seen:
			errors.append("station '%s' twice" % station)
		seen.append(station)
	for station: Variant in keepers:
		if not station in stations:
			errors.append("keeper at '%s', which the room does not have" % station)
		elif not keepers[station] is String:
			errors.append("keeper at '%s' is not a cast id" % station)
	for person: Variant in people:
		var spot: Variant = people[person]
		if not spot is Vector2:
			errors.append("people: %s's spot is not a Vector2 fraction" % person)
		elif spot.x < 0.0 or spot.x > 1.0 or spot.y < 0.0 or spot.y > 1.0:
			errors.append("people: %s's spot %s is off the floor (0..1)" % [person, spot])
	for i in dressing.size():
		var entry: Variant = dressing[i]
		if not (entry is Array and entry.size() == 2 and entry[0] is String and entry[1] is Vector2):
			errors.append("dressing %d: expected [sprite name, Vector2 fraction]" % i)
		elif not SpriteAtlas.has(entry[0]):
			errors.append("dressing %d: no sprite '%s'" % [i, entry[0]])
	return errors
