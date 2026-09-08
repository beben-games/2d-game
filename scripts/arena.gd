class_name Arena
extends Node2D
## One rectangular room's floor and walls. Paints tiles in code from ArenaGrid and builds wall
## colliders, leaving a gap wherever a door sits: the gap cells stay unpainted so the void reads
## as a dark passage, and the Door node blocks it while closed.
## Floor decoration uses its own RNG seeded from RunState.seed_value and the room index so it never
## consumes gameplay RNG draws and each room of a floor gets its own pattern.

const FLOOR_NAMES: Array[String] = ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8"]
## Every name ArenaGrid.wall_tile can return: the top band's ledge and face pieces plus the plain face.
const WALL_NAMES: Array[String] = ["wall_top_left", "wall_top_mid", "wall_top_right", "wall_left", "wall_mid", "wall_right"]
const PLAIN_FLOOR_CHANCE := 0.8  ## floor_1 is the plain tile; the rest are details

## Defaults are the Milestone 2 room. Room calls build() with its def's numbers.
@export var width := 28
@export var height := 15

var door_sides: Array = []

@onready var tiles: TileMapLayer = $Tiles
@onready var walls: StaticBody2D = $Walls


func _ready() -> void:
	tiles.tile_set = _build_tile_set()
	build(width, height, door_sides)


## Rebuilds tiles and colliders for a new size and door set. Safe to call again.
## sides holds RoomDef.Side values, TOP or BOTTOM only.
func build(new_width: int, new_height: int, sides: Array) -> void:
	width = new_width
	height = new_height
	door_sides = sides.duplicate()
	tiles.clear()
	for child in walls.get_children():
		walls.remove_child(child)
		child.queue_free()
	_paint()
	for rect in ArenaGrid.wall_rects(width, height, door_sides):
		_add_wall(rect)


func bounds() -> Rect2:
	return ArenaGrid.bounds(width, height)


func full_rect() -> Rect2:
	return ArenaGrid.full_rect(width, height)


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ArenaGrid.TILE, ArenaGrid.TILE)
	var source := TileSetAtlasSource.new()
	source.texture = SpriteAtlas.TEXTURE
	source.texture_region_size = Vector2i(ArenaGrid.TILE, ArenaGrid.TILE)
	for tile_name in FLOOR_NAMES:
		source.create_tile(SpriteAtlas.tile_coords(tile_name))
	for tile_name in WALL_NAMES:
		source.create_tile(SpriteAtlas.tile_coords(tile_name))
	tile_set.add_source(source, 0)
	return tile_set


func _paint() -> void:
	var floor_rng := RandomNumberGenerator.new()
	# Keyed by room so each room of a floor gets its own pattern.
	floor_rng.seed = hash([RunState.seed_value, "arena_floor", RunState.room])
	for cell in ArenaGrid.floor_cells(width, height):
		var tile_name := FLOOR_NAMES[0]
		if floor_rng.randf() >= PLAIN_FLOOR_CHANCE:
			tile_name = FLOOR_NAMES[floor_rng.randi_range(1, FLOOR_NAMES.size() - 1)]
		tiles.set_cell(cell, 0, SpriteAtlas.tile_coords(tile_name))
	for cell in ArenaGrid.wall_cells(width, height):
		var tile_name := ArenaGrid.wall_tile(width, height, cell, door_sides)
		if tile_name != "":  # door gaps stay void
			tiles.set_cell(cell, 0, SpriteAtlas.tile_coords(tile_name))


func _add_wall(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.position + rect.size * 0.5
	walls.add_child(shape)
