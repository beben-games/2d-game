class_name ArenaGrid
extends RefCounted
## Pure grid math for a rectangular room ringed by walls: a two-row band on top (the tileset draws
## walls as a ledge over a face, and its door art is sized for that band) and one row elsewhere.
## No nodes, so it is unit-testable.

## A wall of the ring; a door gap may sit on any of them.
enum Side { TOP, BOTTOM, LEFT, RIGHT }

const TILE := 16
const TOP_WALL_ROWS := 2
## Between the left edges of two lift bays side by side on the top wall, in tiles: a bay's leaf
## (a door gap, two tiles), its frame a tile either side, and four tiles of wall between two
## frames (room for a column). Even, so every row of bays is centred on whole tiles.
const BAY_PITCH := 8


## How many rows of wall a side is: the top band is two, the other sides one.
static func wall_rows(side: int) -> int:
	return TOP_WALL_ROWS if side == Side.TOP else 1


static func floor_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(TOP_WALL_ROWS, height - 1):
		for x in range(1, width - 1):
			cells.append(Vector2i(x, y))
	return cells


## Every cell that is not floor, row-major.
static func wall_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if x == 0 or y < TOP_WALL_ROWS or x == width - 1 or y == height - 1:
				cells.append(Vector2i(x, y))
	return cells


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


## Playable interior in pixels (walls excluded).
static func bounds(width: int, height: int) -> Rect2:
	return Rect2(TILE, TOP_WALL_ROWS * TILE, (width - 2) * TILE, (height - 1 - TOP_WALL_ROWS) * TILE)


## The whole room in pixels, walls included.
static func full_rect(width: int, height: int) -> Rect2:
	return Rect2(0, 0, width * TILE, height * TILE)


## The cells of a door's gap, row-major. On the top or bottom wall: the two middle columns of
## every row of it (four cells for the top band, two for the bottom row). On a side wall: its one
## column at the two middle rows of the floor.
## For odd sizes the pair sits left of (or above) center; everything else measures the gap
## through door_gap, so it stays consistent.
static func door_cells(width: int, height: int, side: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if side == Side.LEFT or side == Side.RIGHT:
		var x := 0 if side == Side.LEFT else width - 1
		var top := TOP_WALL_ROWS + (height - 1 - TOP_WALL_ROWS) / 2 - 1
		cells.append(Vector2i(x, top))
		cells.append(Vector2i(x, top + 1))
		return cells
	var first_row := 0 if side == Side.TOP else height - 1
	var left := width / 2 - 1
	for y in range(first_row, first_row + wall_rows(side)):
		cells.append(Vector2i(left, y))
		cells.append(Vector2i(left + 1, y))
	return cells


## Pixel rect of the door cells.
static func door_gap(width: int, height: int, side: int) -> Rect2:
	var cells := door_cells(width, height, side)
	if side == Side.LEFT or side == Side.RIGHT:
		return Rect2(Vector2(cells[0]) * TILE, Vector2(TILE, 2 * TILE))
	return Rect2(Vector2(cells[0]) * TILE, Vector2(2 * TILE, wall_rows(side) * TILE))


## `count` lift bays side by side on the top wall, left to right: each the top door's gap in
## size, BAY_PITCH tiles apart, the row centred on that gap (one bay is door_gap(TOP) exactly).
## Empty for no bays, or for more than the wall holds: each bay's frame (a tile either side of
## it) inside the top wall's corners.
static func bay_gaps(width: int, height: int, count: int) -> Array[Rect2]:
	var gaps: Array[Rect2] = []
	var centre := door_gap(width, height, Side.TOP)
	for i in count:
		@warning_ignore("integer_division")
		var offset := (2 * i - (count - 1)) * BAY_PITCH / 2  # whole tiles: BAY_PITCH is even
		var gap := Rect2(centre.position + Vector2(offset * TILE, 0.0), centre.size)
		if gap.position.x < 2 * TILE or gap.end.x > (width - 2) * TILE:
			gaps.clear()
			break
		gaps.append(gap)
	return gaps


## The cells under `rect` (whole tiles, as a gap is), row-major.
static func cells_in(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var first := Vector2i(rect.position / TILE)
	var last := Vector2i(rect.end / TILE)
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			cells.append(Vector2i(x, y))
	return cells


## Wall collider rects for the ring, split where a door gap opens a wall.
static func wall_rects(width: int, height: int, door_sides: Array) -> Array[Rect2]:
	var t := float(TILE)
	var w := width * t
	var h := height * t
	var rects: Array[Rect2] = []
	for side in [Side.LEFT, Side.RIGHT]:
		var x := 0.0 if side == Side.LEFT else w - t
		if side in door_sides:
			var gap := door_gap(width, height, side)
			rects.append(Rect2(x, 0, t, gap.position.y))
			rects.append(Rect2(x, gap.end.y, t, h - gap.end.y))
		else:
			rects.append(Rect2(x, 0, t, h))
	for side in [Side.TOP, Side.BOTTOM]:
		var rows := wall_rows(side) * t
		var y := 0.0 if side == Side.TOP else h - t
		if side in door_sides:
			var gap := door_gap(width, height, side)
			rects.append(Rect2(0, y, gap.position.x, rows))
			rects.append(Rect2(gap.end.x, y, w - gap.end.x, rows))
		else:
			rects.append(Rect2(0, y, w, rows))
	return rects


## Sprite name for a wall cell, or "" for a door gap cell, which stays unpainted so the void
## shows through as a dark passage. Row 0 is the ledge with its corners, row 1 the face with its
## shaded ends; the sides and bottom are plain face. A bottom door has no art of its own, so the
## face visibly ends at the opening with the same shaded end pieces; a side door is the bare gap
## in the plain face.
static func wall_tile(width: int, height: int, cell: Vector2i, door_sides: Array) -> String:
	for side in door_sides:
		var gap := door_cells(width, height, side)
		if cell in gap:
			return ""
		if side == Side.BOTTOM and cell.y == height - 1:
			if cell.x == gap[0].x - 1:
				return "wall_right"
			if cell.x == gap[-1].x + 1:
				return "wall_left"
	if cell.y == 0:
		if cell.x == 0:
			return "wall_top_left"
		if cell.x == width - 1:
			return "wall_top_right"
		return "wall_top_mid"
	if cell.y < TOP_WALL_ROWS:
		if cell.x == 0:
			return "wall_left"
		if cell.x == width - 1:
			return "wall_right"
	return "wall_mid"
