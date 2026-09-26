class_name Grounds
extends Node2D
## The gladiator's grounds between runs: the arena's tiles ringed by solid walls, no enemies,
## three stations to walk into. Where the Room stands under Main during a run (the two never
## share it): Main swaps one for the other in enter_grounds and enter_arena. The stations are
## made here from the grid, never placed by hand: the post (a crate with a spear leaning on it)
## in the left third of the floor, the rack (three weapons hung on the top wall's face) in the
## right third, the gate (the open door in the top wall where the emperor's box sits in the
## arena) at the top centre. Walking into one raises station_entered; Main opens the panel or
## starts the run. Nothing here explains anything.

signal station_entered(id: String)
signal station_exited(id: String)

const STATION := preload("res://scripts/station.gd")
## The wall's art around the gate's opening: what the emperor's box draws, the leaf open.
const GATE_SPRITES: Array[String] = ["doors_frame_left", "doors_frame_right", "doors_leaf_open"]
## The rack's three weapons, left to right on the wall's face.
const RACK_WEAPONS: Array[String] = ["weapon_knight_sword", "weapon_axe", "weapon_bow"]
## A station's area reaches this far past its art, so the body pairs before it stands on top.
const AREA_MARGIN := 6.0

var width: int = 28
var height: int = 15

@onready var arena: Arena = $Arena
@onready var stations: Node2D = $Stations
@onready var projectiles: Node2D = $Projectiles


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


## The three stations from the grid: the post's crate sits on the floor and its area is the
## crate grown by the margin; the rack and the gate are art on the wall, so their areas are the
## floor row under them (the ring is solid: the player stands below the art, never on it).
func _make_stations() -> void:
	var t := float(ArenaGrid.TILE)
	var floor_rect := bounds()
	var crate := SpriteAtlas.region("crate").size
	var post_at := Vector2(floor_rect.position.x + floor_rect.size.x / 6.0, floor_rect.get_center().y) - crate * 0.5
	_add_station("post", post_at.floor(),
		[["crate", Vector2.ZERO], ["weapon_spear", Vector2(crate.x - 6.0, -SpriteAtlas.region("weapon_spear").size.y + crate.y - 2.0)]],
		Rect2(Vector2.ZERO, crate).grow(AREA_MARGIN))
	var rack_x := floor_rect.position.x + floor_rect.size.x * 5.0 / 6.0
	var rack_sprites: Array = []
	var span := 0.0
	for weapon: String in RACK_WEAPONS:
		var size := SpriteAtlas.region(weapon).size
		rack_sprites.append([weapon, Vector2(span, t * 2.0 - size.y)])  # hung with its foot on the face's bottom edge
		span += size.x + 4.0
	span -= 4.0
	var rack_at := Vector2(rack_x - span * 0.5, 0.0).floor()
	_add_station("rack", rack_at, rack_sprites, Rect2(0.0, t * 2.0, span, t).grow(AREA_MARGIN))
	var gap := ArenaGrid.door_gap(width, height, ArenaGrid.Side.TOP)
	_add_station("gate", gap.position,
		[[GATE_SPRITES[0], Vector2(-t, 0.0)], [GATE_SPRITES[1], Vector2(gap.size.x, 0.0)], [GATE_SPRITES[2], Vector2.ZERO]],
		Rect2(0.0, gap.size.y, gap.size.x, t).grow(AREA_MARGIN))


func _add_station(id: String, top_left: Vector2, sprites: Array, rect: Rect2) -> void:
	var s: Station = STATION.new()
	s.setup(id, top_left, sprites, rect)
	s.entered.connect(func(station_id: String) -> void: station_entered.emit(station_id))
	s.exited.connect(func(station_id: String) -> void: station_exited.emit(station_id))
	stations.add_child(s)
