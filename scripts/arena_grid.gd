class_name ArenaGrid
extends RefCounted
## Pure grid math for a rectangular room with a one-tile wall ring. No nodes, so it is unit-testable.

const TILE := 16


static func floor_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			cells.append(Vector2i(x, y))
	return cells


static func wall_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				cells.append(Vector2i(x, y))
	return cells


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


## Playable interior in pixels (walls excluded).
static func bounds(width: int, height: int) -> Rect2:
	return Rect2(TILE, TILE, (width - 2) * TILE, (height - 2) * TILE)
