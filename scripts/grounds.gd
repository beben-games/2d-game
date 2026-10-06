class_name Grounds
extends Node2D
## One room of the gladiator's grounds between runs, built from its GroundsRoomDef (`room_def`, set
## before it enters the tree, with `arrived_from`, the room the gladiator walked in from, "" from
## outside): the arena's tiles at the def's size ringed by solid walls, a gap in the wall for each
## door whose condition holds (read through Story.context() when the room is built; a door whose
## condition fails is wall), the gap closed by the Door's blocker so the ring stays solid, the Door
## on the floor before it; the def's stations, each kept one with its keeper beside its art (the
## def's `keepers`: the lanista at the post, the armourer at the rack); its dressing; its people (a
## Character for each cast member the def stands there, the mark over one with something new). Where
## the Room stands under Main during a run (the two never share it): Main swaps one for the other,
## and one room for the next, through its stage slot. The stations are made here from the grid,
## never placed by hand: the post (a crate with a spear leaning on it, notches cut in it) in the
## left third of the floor, the rack (three weapons hung on the top wall's face) in the right third;
## the lifts (the def's lift_tiers, a bay each side by side on the top wall, tier 1's at the centre
## where the emperor's box sits in the arena): an open one a Lift (the open door, the wall's art cut
## under its leaf so the void shows through as at a door, the wall's collision kept), one the save
## may not fight yet (above `highest_tier`, or with no series) a shut, dark bay with nothing to
## press, and the bay of a tier newly opened (`rising_tier`) shut until rise_lift() raises it open
## once (Main calls it as the room is first shown, and writes it seen at `lift_risen`). Nothing
## opens on contact: each physics tick the nearest enabled Interactable under the room that the
## player's body overlaps (by the distance to its stand position) is the focus (focus_changed, the
## key cap over it), and the interact key on the focus raises interacted with it; Main opens the
## panel, walks to the next room, starts the run, or plays a character's event in the text box.
## No shots here (Player.can_fire is off), so no container for them. Nothing here
## explains anything: no room is named on screen.

## The focus moved: the new focus's id, "" for none.
signal focus_changed(id: String)
## The interact key on the focus: the Interactable itself (Main dispatches on its kind).
signal interacted(item: Interactable)
## The bay of `tier` has risen open (rise_lift): Main writes it seen.
signal lift_risen(tier: int)

## The rack's three weapons, left to right on the wall's face.
const RACK_WEAPONS: Array[String] = ["weapon_knight_sword", "weapon_axe", "weapon_bow"]
## A station's area reaches this far past its art, so the body pairs before it stands on top.
const AREA_MARGIN := 6.0
## The spear's foot sits this far in from the crate's right edge, and this far up from its bottom.
const SPEAR_LEAN := Vector2(6.0, 2.0)
## PLACEHOLDER until M8's art: the notches cut into the post, other men's marks (a fixed set, never
## a counter). Each is the left pixel of a short level cut NOTCH_LENGTH long, in the crate's own
## pixels, on its wood left of the spear; spaced unevenly (two on the lid's planks, one by the lid's
## edge, two on the front's panel) so they read as cuts at 3x, not a ladder.
const NOTCHES: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 8), Vector2i(2, 10), Vector2i(2, 15), Vector2i(3, 18)]
const NOTCH_LENGTH := 3
## A dark red, darker than the crate's darkest wood and apart from its outline's grey.
const NOTCH_COLOUR := Color("2a1014")
## Between the rack's weapons.
const RACK_GAP := 4.0
## Between a station's art and its keeper's frame.
const KEEPER_GAP := 4.0
## Arriving through a door, the gladiator stands this far onto the floor from the gap: out of the
## door's area (the floor tile and its margin, plus the body's radius), so nothing is in focus.
const ENTRY_DEPTH := 2.5 * ArenaGrid.TILE

## The room this is; set before the grounds enter the tree.
var room_def: GroundsRoomDef
## The room the gladiator walked in from ("" from outside): the entry is before its door.
var arrived_from := ""
## The body whose reach decides the focus; Main sets it before mounting the grounds.
var player: Node2D
## The highest tier the save may fight (Save.highest_tier()): a lift above it is a shut bay. Main
## sets it before mounting the grounds (the grounds read the profile through Main, never commit).
var highest_tier := 1
## The tier whose bay is built shut and rises open at rise_lift() (Lift.rising_tier: the newest
## open bay not yet seen), 0 for none. Main sets it before mounting; rise_lift clears it.
var rising_tier := 0
## The interactable the key acts on, or null.
var focus: Interactable
## The focus's id, "" for none: a focus freed while it held the focus reads as null, so the
## loss is told by this.
var _focus_id := ""

@onready var arena: Arena = $Arena
@onready var stations: Node2D = $Stations
@onready var door_nodes: Node2D = $Doors
@onready var dressing: Node2D = $Dressing
@onready var people: Node2D = $People


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
	_make_lifts()
	_make_keepers()
	_make_dressing()
	_make_people()


func bounds() -> Rect2:
	return arena.bounds()


func full_rect() -> Rect2:
	return arena.full_rect()


## Where the player arrives: ENTRY_DEPTH onto the floor before the def's door back to
## `arrived_from` (before its place in the wall even when it is shut, so the gladiator never lands
## in another's reach), else (from outside, or a room the def has no door to) the bottom centre
## of the floor, a tile off the wall.
func entry_position() -> Vector2:
	if not arrived_from.is_empty():
		for door in room_def.doors:
			if door.to == arrived_from:
				var gap := ArenaGrid.door_gap(room_def.width, room_def.height, door.side)
				return Door.threshold_of(gap, door.side) + Door.inward_of(door.side) * ENTRY_DEPTH
	var floor_rect := bounds()
	return Vector2(floor_rect.get_center().x, floor_rect.end.y - ArenaGrid.TILE)


## The world point at `fraction` of the floor (0,0 its top-left, 1,1 its bottom-right): where the
## dressing and the people are placed from their defs.
func floor_point(fraction: Vector2) -> Vector2:
	var floor_rect := bounds()
	return floor_rect.position + floor_rect.size * fraction


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


## Every Interactable under the room (the stations, the doors, the people).
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
		if not lost and focus != null:
			focus.focused = false
		if best != null:
			best.focused = true
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
			_:
				push_error("Grounds: no builder for the station '%s' in %s" % [id, room_def.id])


func _make_post() -> void:
	var floor_rect := bounds()
	var crate := SpriteAtlas.region("crate").size
	var post_at := Vector2(floor_rect.position.x + floor_rect.size.x / 6.0, floor_rect.get_center().y) - crate * 0.5
	_add_station("post", post_at.floor(),
		[["crate", Vector2.ZERO], ["weapon_spear", Vector2(crate.x - SPEAR_LEAN.x, crate.y - SPEAR_LEAN.y - SpriteAtlas.region("weapon_spear").size.y)]],
		Rect2(Vector2.ZERO, crate).grow(AREA_MARGIN))
	_add_notches(station("post"))


## The post's notches (NOTCHES) drawn in code over its crate and under its spear, a child named
## "Notches"; a placeholder until M8's art.
func _add_notches(post: Station) -> void:
	var notches := Node2D.new()
	notches.name = "Notches"
	notches.position = (post.get_node("crate") as Node2D).position
	notches.draw.connect(func() -> void:
		for at: Vector2i in NOTCHES:
			notches.draw_rect(Rect2(Vector2(at), Vector2(NOTCH_LENGTH, 1.0)), NOTCH_COLOUR))
	post.add_child(notches)
	post.move_child(notches, post.get_node("crate").get_index() + 1)


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


## The def's lifts, a bay each at its gap (ArenaGrid.bay_gaps, in lift_tiers' order): an open
## tier's a Lift with the wall's art cut under it, unless it is the rising tier's (built shut and
## disabled, cut when it rises); any other a shut bay under Stations, no Interactable.
func _make_lifts() -> void:
	var gaps := ArenaGrid.bay_gaps(room_def.width, room_def.height, room_def.lift_tiers.size())
	if gaps.size() != room_def.lift_tiers.size():
		push_error("Grounds: %d lifts do not fit the top wall of %s" % [room_def.lift_tiers.size(), room_def.id])
		return
	var open := Lift.open_tiers(room_def.lift_tiers, highest_tier)
	for i in gaps.size():
		var tier := room_def.lift_tiers[i]
		if not tier in open:
			stations.add_child(Lift.shut_bay(tier, gaps[i]))
			continue
		var open_lift := Lift.new()
		open_lift.setup_lift(tier, gaps[i], AREA_MARGIN)
		add_interactable(open_lift, stations)
		if tier == rising_tier:
			open_lift.shut_for_rise()
		else:
			arena.cut(ArenaGrid.cells_in(gaps[i]))


## The open lift of `tier`, or null (a shut bay, or a tier the room has no bay for).
func lift(tier: int) -> Lift:
	return interactable(Lift.id_for(tier)) as Lift


## The bay of `tier` whatever its state (a Lift, or a shut bay's Node2D), or null.
func lift_bay(tier: int) -> Node2D:
	return stations.get_node_or_null(NodePath(Lift.id_for(tier).validate_node_name())) as Node2D


## The rising tier's bay rises open (Lift.rise: the sound, the darkening lifted, the shut leaf
## drawn up), the wall's art cut under it as it starts (the opening shows behind the leaf), and
## `lift_risen` once it is open. Once: rising_tier is cleared. False when nothing rises.
func rise_lift() -> bool:
	var rising := lift(rising_tier)
	rising_tier = 0
	if rising == null or not rising.waiting:
		return false
	arena.cut(ArenaGrid.cells_in(rising.gap))
	rising.risen.connect(func(tier: int) -> void: lift_risen.emit(tier), CONNECT_ONE_SHOT)
	return rising.rise()


func _add_station(id: String, top_left: Vector2, sprites: Array, rect: Rect2) -> void:
	var s := Station.new()
	s.setup_station(id, top_left, sprites, rect)
	add_interactable(s, stations)


## The def's keepers, each beside its station's art on the floor: the post's to the right of the
## crate, its feet level with the crate's foot; the rack's to the left of the weapons, on the
## floor's first row under the wall they hang on. A keeper of a station the room lacks, or of a
## station with no place for one, is an error and stands nobody there.
func _make_keepers() -> void:
	for station_id: String in room_def.keepers:
		var kept := station(station_id)
		var cast_id := str(room_def.keepers[station_id])
		var sprite_name := _cast_sprite(cast_id)
		if kept == null or sprite_name.is_empty():
			push_error("Grounds: no keeper '%s' at '%s' in %s" % [cast_id, station_id, room_def.id])
			continue
		var size := SpriteAtlas.region(sprite_name).size
		var foot: Vector2
		match station_id:
			"post":
				foot = Vector2(kept.art.end.x + KEEPER_GAP + size.x * 0.5, kept.art.end.y)
			"rack":
				foot = Vector2(kept.art.position.x - KEEPER_GAP - size.x * 0.5, bounds().position.y - kept.position.y + size.y)
			_:
				push_error("Grounds: no place for a keeper at '%s' in %s" % [station_id, room_def.id])
				continue
		kept.add_keeper(cast_id, foot, sprite_name)


## The cast member's sprite (the cast's `sprite`, which the atlas must know), "" when there is
## none.
func _cast_sprite(cast_id: String) -> String:
	var member: Variant = Story.catalog.cast.get(cast_id)
	var sprite_name := str((member as Dictionary).get("sprite", "")) if member is Dictionary else ""
	return sprite_name if SpriteAtlas.has(sprite_name) else ""


## The def's dressing: each sprite's bottom centre at its fraction of the floor, its top-left
## snapped to the tile grid; an animated sprite (a fountain's water) plays. Under the gladiator,
## colliding with nothing.
func _make_dressing() -> void:
	var t := float(ArenaGrid.TILE)
	for i in room_def.dressing.size():
		var entry: Array = room_def.dressing[i]
		var sprite_name: String = entry[0]
		var fraction: Vector2 = entry[1]
		var size := SpriteAtlas.region(sprite_name).size
		var foot := floor_point(fraction)
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


## The def's people: each cast member a Character drawn with the cast's sprite, its feet at its
## fraction of the floor (as the dressing's). A cast id the story's cast lacks, or a sprite the
## atlas lacks, is an error and stands nobody there.
func _make_people() -> void:
	for cast_id: String in room_def.people:
		var sprite_name := _cast_sprite(cast_id)
		if sprite_name.is_empty():
			push_error("Grounds: no sprite for the cast member '%s' in %s" % [cast_id, room_def.id])
			continue
		var character := Character.new()
		character.setup_character(cast_id, floor_point(room_def.people[cast_id]), sprite_name)
		add_interactable(character, people)
