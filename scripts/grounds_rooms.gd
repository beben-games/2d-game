class_name GroundsRooms
extends RefCounted
## The grounds' rooms by id, loaded once from data/grounds/<id>.tres. The ids are a list here,
## not a directory listing (an exported build reads its resources by name), and they are the
## story's rooms (StoryScript.ROOMS, for `enter <room>`): a test pins the two. The load checks
## every room (GroundsRoomDef.validate, the doors' conditions against the story's declared flags)
## and the map (every door's room exists and has a door back, one room holds the lift, and every
## room reaches it through doors that always open), each fault through push_error. Pure: no
## autoload (the flags come from the story's data through StoryCatalog.declared_flags).

const DIR := "res://data/grounds"
const IDS: Array[String] = ["ludus", "armamentarium", "hypogeum", "sanitarium", "spoliarium"]

static var _rooms: Dictionary = {}
static var _loaded := false


static func ids() -> Array[String]:
	return IDS


## The room with `id`, or null for none.
static func room(id: String) -> GroundsRoomDef:
	_ensure_loaded()
	return _rooms.get(id) as GroundsRoomDef


## What is wrong with the shipped rooms (empty when nothing is).
static func errors() -> PackedStringArray:
	_ensure_loaded()
	return check(_rooms, shipped_context())


## The names a shipped door's condition may read: a fresh save's and the story's declared flags.
static func shipped_context() -> StoryContext:
	return StoryContext.new(null, StoryCatalog.declared_flags())


## What is wrong with `rooms` (id to def) as a map: each def under its own id and valid against
## the others' ids and `context`'s names (a fresh save's, no story flag, when null), every door's
## room with a door back, exactly one room holding the lift, and every room reaching the lift's
## through doors with no condition (none is a trap while the conditional doors are shut).
static func check(rooms: Dictionary, context: StoryContext = null) -> PackedStringArray:
	var out := PackedStringArray()
	var known: Array[String] = []
	for id: String in rooms:
		known.append(id)
	for id: String in rooms:
		var def: GroundsRoomDef = rooms[id]
		if def == null:
			out.append("%s: missing" % id)
			continue
		if def.id != id:
			out.append("%s: the def's id is '%s'" % [id, def.id])
			continue
		for e in def.validate(known, context):
			out.append("%s: %s" % [id, e])
		for door: GroundsDoorDef in def.doors:
			var behind: GroundsRoomDef = rooms.get(door.to) if door != null else null
			if behind == null:
				continue  # validate named it
			var has_back := behind.doors.any(func(back: GroundsDoorDef) -> bool:
				return back != null and back.to == id)
			if not has_back:
				out.append("%s: the door to %s has no door back" % [id, door.to])
	out.append_array(_check_lift(rooms))
	return out


## One room holds the lift, and every room reaches it through doors whose `when` is empty.
static func _check_lift(rooms: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var lifts: Array[String] = []
	for id: String in rooms:
		var def: GroundsRoomDef = rooms[id]
		if def != null and "lift" in def.stations:
			lifts.append(id)
	if lifts.size() != 1:
		out.append("the lift is in %d rooms (%s); one holds it" % [lifts.size(), ", ".join(lifts)])
		return out
	var reach: Array[String] = [lifts[0]]
	var grew := true
	while grew:
		grew = false
		for id: String in rooms:
			var def: GroundsRoomDef = rooms[id]
			if id in reach or def == null:
				continue
			for door in def.doors:
				if door != null and door.when.strip_edges().is_empty() and door.to in reach:
					reach.append(id)
					grew = true
					break
	for id: String in rooms:
		if not id in reach:
			out.append("%s: no way to the lift through doors that always open" % id)
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for id in IDS:
		var def := load("%s/%s.tres" % [DIR, id]) as GroundsRoomDef
		if def == null:
			push_error("GroundsRooms: no room at %s/%s.tres" % [DIR, id])
			continue
		_rooms[id] = def
	for e in check(_rooms, shipped_context()):
		push_error("GroundsRooms: %s" % e)
