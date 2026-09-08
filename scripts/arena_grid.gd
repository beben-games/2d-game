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


## The two middle cells of the top or bottom wall row where a door sits.
## For odd widths the pair sits left of center; everything else measures the gap through door_gap, so it stays consistent.
static func door_cells(width: int, height: int, side: int) -> Array[Vector2i]:
	assert(side == RoomDef.Side.TOP or side == RoomDef.Side.BOTTOM, "doors exist only on the top or bottom wall")
	var y := 0 if side == RoomDef.Side.TOP else height - 1
	var left := width / 2 - 1
	return [Vector2i(left, y), Vector2i(left + 1, y)]


## Pixel rect of the door cells.
static func door_gap(width: int, height: int, side: int) -> Rect2:
	var cells := door_cells(width, height, side)
	return Rect2(Vector2(cells[0]) * TILE, Vector2(cells.size() * TILE, TILE))


## Wall collider rects for the ring, split where a door gap opens a top or bottom wall.
static func wall_rects(width: int, height: int, door_sides: Array) -> Array[Rect2]:
	var t := float(TILE)
	var w := width * t
	var h := height * t
	var rects: Array[Rect2] = [Rect2(0, 0, t, h), Rect2(w - t, 0, t, h)]
	for side in [RoomDef.Side.TOP, RoomDef.Side.BOTTOM]:
		var y := 0.0 if side == RoomDef.Side.TOP else h - t
		if side in door_sides:
			var gap := door_gap(width, height, side)
			rects.append(Rect2(0, y, gap.position.x, t))
			rects.append(Rect2(gap.end.x, y, w - gap.end.x, t))
		else:
			rects.append(Rect2(0, y, w, t))
	return rects
