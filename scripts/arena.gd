class_name Arena
extends Node2D
## One rectangular room. Paints tiles in code from ArenaGrid and builds four wall colliders.
## Floor decoration uses its own RNG seeded from RunState.seed_value so it never consumes gameplay RNG draws.

const WIDTH := 40
const HEIGHT := 23
const FLOOR_NAMES: Array[String] = ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8"]
const WALL_NAME := "wall_mid"
const PLAIN_FLOOR_CHANCE := 0.8  ## floor_1 is the plain tile; the rest are details

@onready var tiles: TileMapLayer = $Tiles
@onready var walls: StaticBody2D = $Walls


func _ready() -> void:
	tiles.tile_set = _build_tile_set()
	_paint()
	_build_wall_shapes()


func bounds() -> Rect2:
	return ArenaGrid.bounds(WIDTH, HEIGHT)


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
	for cell in ArenaGrid.floor_cells(WIDTH, HEIGHT):
		var tile_name := FLOOR_NAMES[0]
		if floor_rng.randf() >= PLAIN_FLOOR_CHANCE:
			tile_name = FLOOR_NAMES[floor_rng.randi_range(1, FLOOR_NAMES.size() - 1)]
		tiles.set_cell(cell, 0, SpriteAtlas.tile_coords(tile_name))
	var wall := SpriteAtlas.tile_coords(WALL_NAME)
	for cell in ArenaGrid.wall_cells(WIDTH, HEIGHT):
		tiles.set_cell(cell, 0, wall)


func _build_wall_shapes() -> void:
	var t := float(ArenaGrid.TILE)
	var w := WIDTH * t
	var h := HEIGHT * t
	_add_wall(Rect2(0, 0, w, t))
	_add_wall(Rect2(0, h - t, w, t))
	_add_wall(Rect2(0, 0, t, h))
	_add_wall(Rect2(w - t, 0, t, h))


func _add_wall(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.position + rect.size * 0.5
	walls.add_child(shape)
