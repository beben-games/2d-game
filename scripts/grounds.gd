class_name Grounds
extends Node2D
## One room of the gladiator's grounds between runs, built from its GroundsRoomDef (`room_def`,
## set before it enters the tree, with `arrived_from`, the room the gladiator walked in from, ""
## from outside): the arena's tiles at the def's size ringed by solid walls, a gap in the wall for
## each door whose condition holds (read through Story.context() when the room is built; a door
## whose condition fails is wall), the gap closed by the Door's blocker so the ring stays solid,
## the Door on the floor before it; the def's stations; its dressing. Where the Room stands under
## Main during a run (the two never share it): Main swaps one for the other, and one room for the
## next, through its stage slot. The stations are made here from the grid, never placed by hand:
## the post (a crate with a spear leaning on it) in the left third of the floor, the rack (three
## weapons hung on the top wall's face) in the right third, the lift (the open door in the top
## wall where the emperor's box sits in the arena) at the top centre. Nothing opens on contact:
## each physics tick the nearest enabled Interactable under the room that the player's body
## overlaps (by the distance to its stand position) is the focus (focus_changed, the key cap over
## it), and the interact key on the focus raises interacted with it; Main opens the panel, walks
## to the next room, or starts the run. No shots here (Player.can_fire is off), so no container
## for them. Nothing here explains anything: no room is named on screen.

## The focus moved: the new focus's id, "" for none.
signal focus_changed(id: String)
## The interact key on the focus: the Interactable itself (Main dispatches on its kind).
signal interacted(item: Interactable)

## The wall's art around the lift's opening: what the emperor's box draws, the leaf open. The top
## wall stays solid under it (the lift is no gap: the arena is not a room to walk to).
const LIFT_SPRITES: Array[String] = ["doors_frame_left", "doors_frame_right", "doors_leaf_open"]
## The rack's three weapons, left to right on the wall's face.
const RACK_WEAPONS: Array[String] = ["weapon_knight_sword", "weapon_axe", "weapon_bow"]
## A station's area reaches this far past its art, so the body pairs before it stands on top.
const AREA_MARGIN := 6.0
## The spear's foot sits this far in from the crate's right edge, and this far up from its bottom.
const SPEAR_LEAN := Vector2(6.0, 2.0)
## Between the rack's weapons.
const RACK_GAP := 4.0
## Arriving through a door, the gladiator stands this far onto the floor from the gap: out of the
## door's area (the floor tile and its margin, plus the body's radius), so nothing is in focus.
const ENTRY_DEPTH := 2.5 * ArenaGrid.TILE

## The room this is; set before the grounds enter the tree.
var room_def: GroundsRoomDef
## The room the gladiator walked in from ("" from outside): the entry is before its door.
var arrived_from := ""
## The body whose reach decides the focus; Main sets it before mounting the grounds.
var player: Node2D
## The interactable the key acts on, or null.
var focus: Interactable
## The focus's id, "" for none: a focus freed while it held the focus reads as null, so the
## loss is told by this.
var _focus_id := ""

@onready var arena: Arena = $Arena
@onready var stations: Node2D = $Stations
@onready var door_nodes: Node2D = $Doors
@onready var dressing: Node2D = $Dressing


func _ready() -> void:
	assert(room_def != null, "Grounds needs a room_def before entering the tree")
	var context := Story.context()
	var open: Array[GroundsDoorDef] = []
	for door in room_def.doors:
		if door.is_open(context):
			open.append(door)
	arena.build(room_def.width, room_def.height, open.map(func(door: GroundsDoorDef) -> int: return door.side))
	for door in open:
		_add_door(door)
	_make_stations()
	_make_dressing()


func bounds() -> Rect2:
	return arena.bounds()


func full_rect() -> Rect2:
	return arena.full_rect()


## Where the player arrives: ENTRY_DEPTH onto the floor before the door back to `arrived_from`,
## else (from outside, or no such door) the bottom centre of the floor, a tile off the wall.
func entry_position() -> Vector2:
	var back := door_to(arrived_from)
	if back != null:
		return back.threshold() + back.inward() * ENTRY_DEPTH
	var floor_rect := bounds()
	return Vector2(floor_rect.get_center().x, floor_rect.end.y - ArenaGrid.TILE)


func station(id: String) -> Station:
	return interactable(id) as Station


## The room's open doors.
func doors() -> Array[Door]:
	var found: Array[Door] = []
	for item in interactables():
		if item is Door:
			found.append(item as Door)
	return found


## The open door to the room `room_id`, or null.
func door_to(room_id: String) -> Door:
	for door in doors():
		if door.to == room_id:
			return door
	return null


## The interactable under the grounds with `id`, or null.
func interactable(id: String) -> Interactable:
	for item in interactables():
		if item.id == id:
			return item
	return null


## Every Interactable under the room (the stations and the doors; later the people).
func interactables() -> Array[Interactable]:
	var found: Array[Interactable] = []
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if is_ancestor_of(node):
			found.append(node as Interactable)
	return found


## Puts `item` under `parent` (the grounds when null); joining Interactable.GROUP in its _ready
## makes it one of interactables(). The stations and the doors come through here; a test adds its
## own. A second interactable with an id the room has is refused (interactable(id) would find
## only the first): an error, and the item freed.
func add_interactable(item: Interactable, parent: Node = null) -> void:
	if interactable(item.id) != null:
		push_error("Grounds: a second interactable '%s' in %s" % [item.id, room_def.id])
		item.free()
		return
	(self if parent == null else parent).add_child(item)


func _physics_process(_delta: float) -> void:
	_update_focus()


## The nearest enabled interactable the player's body overlaps, by the distance to its stand
## position; focus_changed when it moves, or when the focus was freed (a typed variable holding
## a freed object compares equal to null, so the identity test alone would miss it).
func _update_focus() -> void:
	var best: Interactable = null
	if player != null:
		var best_distance := INF
		for item in interactables():
			if not item.enabled or not item.overlaps_body(player):
				continue
			var distance := player.global_position.distance_squared_to(item.stand_position())
			if distance < best_distance:
				best = item
				best_distance = distance
	var lost := not _focus_id.is_empty() and not is_instance_valid(focus)
	if best != focus or lost:
		focus = best
		_focus_id = "" if best == null else best.id
		focus_changed.emit(_focus_id)


func _unhandled_input(event: InputEvent) -> void:
	if focus != null and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit(focus)


func _add_door(def: GroundsDoorDef) -> void:
	var door := Door.new()
	door.setup_door(def.to, def.side, ArenaGrid.door_gap(room_def.width, room_def.height, def.side))
	add_interactable(door, door_nodes)


## The room's stations from the grid: the post's crate sits on the floor and its area is the
## crate grown by the margin; the rack and the lift are art on the wall, so their areas are the
## floor row under them (the ring is solid: the player stands below the art, never on it).
func _make_stations() -> void:
	for id in room_def.stations:
		match id:
			"post":
				_make_post()
			"rack":
				_make_rack()
			"lift":
				_make_lift()


func _make_post() -> void:
	var floor_rect := bounds()
	var crate := SpriteAtlas.region("crate").size
	var post_at := Vector2(floor_rect.position.x + floor_rect.size.x / 6.0, floor_rect.get_center().y) - crate * 0.5
	_add_station("post", post_at.floor(),
		[["crate", Vector2.ZERO], ["weapon_spear", Vector2(crate.x - SPEAR_LEAN.x, crate.y - SPEAR_LEAN.y - SpriteAtlas.region("weapon_spear").size.y)]],
		Rect2(Vector2.ZERO, crate).grow(AREA_MARGIN))


func _make_rack() -> void:
	var t := float(ArenaGrid.TILE)
	var floor_rect := bounds()
	var rack_x := floor_rect.position.x + floor_rect.size.x * 5.0 / 6.0
	var rack_sprites: Array = []
	var span := 0.0
	for weapon: String in RACK_WEAPONS:
		var size := SpriteAtlas.region(weapon).size
		rack_sprites.append([weapon, Vector2(span, t * 2.0 - size.y)])  # hung with its foot on the face's bottom edge
		span += size.x + RACK_GAP
	span -= RACK_GAP
	var rack_at := Vector2(rack_x - span * 0.5, 0.0).floor()
	_add_station("rack", rack_at, rack_sprites, Rect2(0.0, t * 2.0, span, t).grow(AREA_MARGIN))


func _make_lift() -> void:
	var t := float(ArenaGrid.TILE)
	var gap := ArenaGrid.door_gap(room_def.width, room_def.height, ArenaGrid.Side.TOP)
	_add_station("lift", gap.position,
		[[LIFT_SPRITES[0], Vector2(-t, 0.0)], [LIFT_SPRITES[1], Vector2(gap.size.x, 0.0)], [LIFT_SPRITES[2], Vector2.ZERO]],
		Rect2(0.0, gap.size.y, gap.size.x, t).grow(AREA_MARGIN))


func _add_station(id: String, top_left: Vector2, sprites: Array, rect: Rect2) -> void:
	var s := Station.new()
	s.setup_station(id, top_left, sprites, rect)
	add_interactable(s, stations)


## The def's dressing: each sprite's bottom centre at its fraction of the floor, its top-left
## snapped to the tile grid; an animated sprite (a fountain's water) plays. Under the gladiator,
## colliding with nothing.
func _make_dressing() -> void:
	var floor_rect := bounds()
	var t := float(ArenaGrid.TILE)
	for i in room_def.dressing.size():
		var entry: Array = room_def.dressing[i]
		var sprite_name: String = entry[0]
		var fraction: Vector2 = entry[1]
		var size := SpriteAtlas.region(sprite_name).size
		var foot := floor_rect.position + floor_rect.size * fraction
		var top_left := ((foot - Vector2(size.x * 0.5, size.y)) / t).round() * t
		var node: Node2D
		if SpriteAtlas.frame_count(sprite_name) > 1:
			var animated := AnimatedSprite2D.new()
			animated.sprite_frames = SpriteAtlas.frames({"default": sprite_name})
			animated.centered = false
			animated.play("default")
			node = animated
		else:
			var still := Sprite2D.new()
			still.texture = SpriteAtlas.texture(sprite_name)
			still.centered = false
			node = still
		node.name = "%s_%d" % [sprite_name, i]
		node.position = top_left
		dressing.add_child(node)
