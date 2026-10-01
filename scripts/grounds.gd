class_name Grounds
extends Node2D
## The gladiator's grounds between runs: the arena's tiles ringed by solid walls, no enemies,
## three stations. Where the Room stands under Main during a run (the two never
## share it): Main swaps one for the other in enter_grounds and enter_arena. The stations are
## made here from the grid, never placed by hand: the post (a crate with a spear leaning on it)
## in the left third of the floor, the rack (three weapons hung on the top wall's face) in the
## right third, the gate (the open door in the top wall where the emperor's box sits in the
## arena) at the top centre. Nothing opens on contact: each physics tick the nearest enabled
## Interactable under the grounds that the player's body overlaps (by the distance to its stand
## position) is the focus (focus_changed, the key cap over it), and the interact key on the
## focus raises interacted; Main opens the panel or starts the run. No shots here
## (Player.can_fire is off), so no container for them. Nothing here explains anything.

## The focus moved: the new focus's id, "" for none.
signal focus_changed(id: String)
## The interact key on the focus.
signal interacted(id: String)

## The wall's art around the gate's opening: what the emperor's box draws, the leaf open.
const GATE_SPRITES: Array[String] = ["doors_frame_left", "doors_frame_right", "doors_leaf_open"]
## The rack's three weapons, left to right on the wall's face.
const RACK_WEAPONS: Array[String] = ["weapon_knight_sword", "weapon_axe", "weapon_bow"]
## A station's area reaches this far past its art, so the body pairs before it stands on top.
const AREA_MARGIN := 6.0
## The spear's foot sits this far in from the crate's right edge, and this far up from its bottom.
const SPEAR_LEAN := Vector2(6.0, 2.0)
## Between the rack's weapons.
const RACK_GAP := 4.0

var width: int = 28
var height: int = 15
## The body whose reach decides the focus; Main sets it before mounting the grounds.
var player: Node2D
## The interactable the key acts on, or null.
var focus: Interactable
## The focus's id, "" for none: a focus freed while it held the focus reads as null, so the
## loss is told by this.
var _focus_id := ""

@onready var arena: Arena = $Arena
@onready var stations: Node2D = $Stations


func _ready() -> void:
	arena.build(width, height, [])
	_make_stations()


func bounds() -> Rect2:
	return arena.bounds()


func full_rect() -> Rect2:
	return arena.full_rect()


## Where the player arrives: the bottom centre of the floor, a tile off the wall.
func entry_position() -> Vector2:
	var floor_rect := bounds()
	return Vector2(floor_rect.get_center().x, floor_rect.end.y - ArenaGrid.TILE)


func station(id: String) -> Station:
	return stations.get_node_or_null(id) as Station


## The interactable under the grounds with `id`, or null.
func interactable(id: String) -> Interactable:
	for item in interactables():
		if item.id == id:
			return item
	return null


## Every Interactable under the grounds (the stations; later the doors and the people).
func interactables() -> Array[Interactable]:
	var found: Array[Interactable] = []
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if is_ancestor_of(node):
			found.append(node as Interactable)
	return found


## Puts `item` under `parent` (the grounds when null); joining Interactable.GROUP in its _ready
## makes it one of interactables(). The stations come through here; a test adds its own.
func add_interactable(item: Interactable, parent: Node = null) -> void:
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
		interacted.emit(focus.id)


## The three stations from the grid: the post's crate sits on the floor and its area is the
## crate grown by the margin; the rack and the gate are art on the wall, so their areas are the
## floor row under them (the ring is solid: the player stands below the art, never on it).
func _make_stations() -> void:
	var t := float(ArenaGrid.TILE)
	var floor_rect := bounds()
	var crate := SpriteAtlas.region("crate").size
	var post_at := Vector2(floor_rect.position.x + floor_rect.size.x / 6.0, floor_rect.get_center().y) - crate * 0.5
	_add_station("post", post_at.floor(),
		[["crate", Vector2.ZERO], ["weapon_spear", Vector2(crate.x - SPEAR_LEAN.x, crate.y - SPEAR_LEAN.y - SpriteAtlas.region("weapon_spear").size.y)]],
		Rect2(Vector2.ZERO, crate).grow(AREA_MARGIN))
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
	var gap := ArenaGrid.door_gap(width, height, ArenaGrid.Side.TOP)
	_add_station("gate", gap.position,
		[[GATE_SPRITES[0], Vector2(-t, 0.0)], [GATE_SPRITES[1], Vector2(gap.size.x, 0.0)], [GATE_SPRITES[2], Vector2.ZERO]],
		Rect2(0.0, gap.size.y, gap.size.x, t).grow(AREA_MARGIN))


func _add_station(id: String, top_left: Vector2, sprites: Array, rect: Rect2) -> void:
	var s := Station.new()
	s.setup_station(id, top_left, sprites, rect)
	add_interactable(s, stations)
