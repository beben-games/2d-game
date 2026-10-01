class_name GroundsRooms
extends RefCounted
## The grounds' rooms by id, loaded once from data/grounds/<id>.tres. The ids are a list here,
## not a directory listing (an exported build reads its resources by name), and they are the
## story's rooms (StoryScript.ROOMS, for `enter <room>`): a test pins the two. The load checks
## every room (GroundsRoomDef.validate) and the map (every door's room exists and has a door
## back), each fault through push_error. Pure: no autoload.

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
	return check(_rooms)


## What is wrong with `rooms` (id to def) as a map: each def under its own id and valid against
## the others' ids, and every door's room with a door back.
static func check(rooms: Dictionary) -> PackedStringArray:
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
		for e in def.validate(known):
			out.append("%s: %s" % [id, e])
		for door: GroundsDoorDef in def.doors:
			var behind: GroundsRoomDef = rooms.get(door.to) if door != null else null
			if behind == null:
				continue  # validate named it
			if not behind.doors.any(func(back: GroundsDoorDef) -> bool: return back != null and back.to == id):
				out.append("%s: the door to %s has no door back" % [id, door.to])
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
	for e in check(_rooms):
		push_error("GroundsRooms: %s" % e)
