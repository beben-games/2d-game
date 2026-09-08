class_name Arena
extends Node2D
## One rectangular room's floor and walls. Paints tiles in code from ArenaGrid and builds wall
## colliders, leaving a gap wherever a door sits (the Door node fills it while closed).
## Floor decoration uses its own RNG seeded from RunState.seed_value so it never consumes gameplay RNG draws.

const FLOOR_NAMES: Array[String] = ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8"]
const WALL_NAME := "wall_mid"
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


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ArenaGrid.TILE, ArenaGrid.TILE)
	var source := TileSetAtlasSource.new()
	source.texture = SpriteAtlas.TEXTURE
	source.texture_region_size = Vector2i(ArenaGrid.TILE, ArenaGrid.TILE)
	for tile_name in FLOOR_NAMES:
		source.create_tile(SpriteAtlas.tile_coords(tile_name))
	source.create_tile(SpriteAtlas.tile_coords(WALL_NAME))
	tile_set.add_source(source, 0)
	return tile_set


func _paint() -> void:
	var floor_rng := RandomNumberGenerator.new()
	floor_rng.seed = hash([RunState.seed_value, "arena_floor"])
	for cell in ArenaGrid.floor_cells(width, height):
		var tile_name := FLOOR_NAMES[0]
		if floor_rng.randf() >= PLAIN_FLOOR_CHANCE:
			tile_name = FLOOR_NAMES[floor_rng.randi_range(1, FLOOR_NAMES.size() - 1)]
		tiles.set_cell(cell, 0, SpriteAtlas.tile_coords(tile_name))
	var wall := SpriteAtlas.tile_coords(WALL_NAME)
	for cell in ArenaGrid.wall_cells(width, height):
		tiles.set_cell(cell, 0, wall)
	# Plain floor under each door so nothing peeks around the leaf sprite.
	var plain := SpriteAtlas.tile_coords(FLOOR_NAMES[0])
	for side in door_sides:
		for cell in ArenaGrid.door_cells(width, height, side):
			tiles.set_cell(cell, 0, plain)


func _add_wall(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.position + rect.size * 0.5
	walls.add_child(shape)
