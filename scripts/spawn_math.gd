class_name SpawnMath
extends RefCounted
## Pure helpers for where enemies appear. The arena's rule 2 (the M7 design's "The big arena"):
## a spawn, the boss's seat, and the summons are placed in the floor's part inside the view (the
## caller's View.rect), never beyond it. Where the view covers the floor (tier 1, wherever the
## camera sits) that part is the floor itself and every placement is exactly the floor-only one.

const EDGE_MARGIN := 12.0
## How near an edge of the view that cuts the floor a spawn lands, px: in a wide arena enemies
## walk in from the edge of the screen rather than pop in beside the player.
## An edge on the floor's own wall makes no band (nothing walks in through a wall).
const VIEW_BAND := 48.0
## The boss's seat under the top of the floor in view (tier 1's, a tile and a half below the top
## wall), and never nearer the screen's top than tier 1's seat sits under its screen's top (the
## top wall's rows and that depth), so a seat under a screen that cuts the floor shows the body
## whole, below the boss bar.
const SEAT_DEPTH := ArenaGrid.TILE * 1.5
const SEAT_UNDER_SCREEN := ArenaGrid.TOP_WALL_ROWS * ArenaGrid.TILE + SEAT_DEPTH


## A random point inside bounds at least min_distance from avoid. Falls back to the
## farthest candidate found when no candidate satisfies the distance.
static func pick_position(bounds: Rect2, avoid: Vector2, min_distance: float, rng: RandomNumberGenerator, attempts: int = 24) -> Vector2:
	var inner := bounds.grow(-EDGE_MARGIN)
	var best := inner.get_center()
	var best_distance := -1.0
	for i in attempts:
		var p := Vector2(
			rng.randf_range(inner.position.x, inner.end.x),
			rng.randf_range(inner.position.y, inner.end.y),
		)
		var d := p.distance_to(avoid)
		if d >= min_distance:
			return p
		if d > best_distance:
			best = p
			best_distance = d
	return best


## pick_position inside floor_in_view(bounds, view), each draw moved into VIEW_BAND along the
## nearest of the view's edges that cut the floor. Where no edge of the view cuts the floor (it
## covers it: tier 1, wherever the camera sits) this is pick_position on `bounds` itself, draw for
## draw, so a seed replays as before. Otherwise each attempt draws the same two numbers in the
## floor in view and squeezes the point toward its nearest cutting edge (_into_band): the first
## far enough is taken; failing that the farthest (a floor in view too small for the distance),
## so a pick is never outside the view.
static func pick_in_view(bounds: Rect2, view: Rect2, avoid: Vector2, min_distance: float, rng: RandomNumberGenerator, attempts: int = 24) -> Vector2:
	var region := floor_in_view(bounds, view)
	var open := _open_sides(bounds, region)
	if open.is_empty():
		return pick_position(bounds, avoid, min_distance, rng, attempts)
	var inner := region.grow(-EDGE_MARGIN)
	var best := inner.get_center()
	var best_distance := -1.0
	for i in attempts:
		var p := _into_band(Vector2(
			rng.randf_range(inner.position.x, inner.end.x),
			rng.randf_range(inner.position.y, inner.end.y),
		), region, open)
		var d := p.distance_to(avoid)
		if d >= min_distance:
			return p
		if d > best_distance:
			best = p
			best_distance = d
	return best


## The floor's part inside the view: their overlap; the floor itself when they do not overlap
## (the empty view of a caller outside the tree), so a placement never has nowhere to go.
static func floor_in_view(bounds: Rect2, view: Rect2) -> Rect2:
	var region := bounds.intersection(view)
	return region if region.has_area() else bounds


## The boss's seat: the top centre of the floor in view, SEAT_DEPTH under its top, and no nearer
## the top of `screen` (View.bare_rect: the screen itself) than SEAT_UNDER_SCREEN. In tier 1 the
## floor's top is that far under the screen's, so the seat is the floor's top centre, as before.
## A fight of `count` bodies sits along that row, body `index` at (index + 1) / (count + 1) of the
## floor in view's width: one body at the centre.
static func boss_seat(bounds: Rect2, view: Rect2, screen: Rect2, index := 0, count := 1) -> Vector2:
	var region := floor_in_view(bounds, view)
	var y := maxf(region.position.y + SEAT_DEPTH, screen.position.y + SEAT_UNDER_SCREEN)
	var seats := maxi(count, index + 1)
	var x := region.position.x + region.size.x * float(index + 1) / float(seats + 1)
	if seats == 1:
		x = region.get_center().x  # tier 1's seat, to the bit
	return Vector2(x, minf(y, region.end.y))


## The left and right sides of the floor in view, a tile in, at its middle height: the boss's
## summons. In tier 1 the floor's own wall midpoints, as before.
static func side_points(bounds: Rect2, view: Rect2) -> Array[Vector2]:
	var region := floor_in_view(bounds, view)
	var y := region.get_center().y
	return [Vector2(region.position.x + ArenaGrid.TILE, y), Vector2(region.end.x - ArenaGrid.TILE, y)]


## The sides of `region` (the floor in view) that the view's edge cuts through the floor, as
## Side values: where region stops short of the floor's own edge.
static func _open_sides(bounds: Rect2, region: Rect2) -> Array[int]:
	var open: Array[int] = []
	if region.position.x > bounds.position.x:
		open.append(SIDE_LEFT)
	if region.end.x < bounds.end.x:
		open.append(SIDE_RIGHT)
	if region.position.y > bounds.position.y:
		open.append(SIDE_TOP)
	if region.end.y < bounds.end.y:
		open.append(SIDE_BOTTOM)
	return open


## `p` (inside region grown by -EDGE_MARGIN) moved toward the nearest of region's `open` sides:
## its depth from that side past EDGE_MARGIN wrapped onto EDGE_MARGIN to VIEW_BAND, so uniform
## draws fill the band evenly and stay inside the floor in view. Unmoved when region is too
## shallow on that axis for a band.
static func _into_band(p: Vector2, region: Rect2, open: Array[int]) -> Vector2:
	var side := open[0]
	var nearest := INF
	for candidate in open:
		var depth := _depth(p, region, candidate)
		if depth < nearest:
			nearest = depth
			side = candidate
	var horizontal := side == SIDE_LEFT or side == SIDE_RIGHT
	var span := (region.size.x if horizontal else region.size.y) - 2.0 * EDGE_MARGIN
	if span <= VIEW_BAND:
		return p
	var depth := EDGE_MARGIN + fposmod(nearest - EDGE_MARGIN, VIEW_BAND - EDGE_MARGIN)
	match side:
		SIDE_LEFT:
			p.x = region.position.x + depth
		SIDE_RIGHT:
			p.x = region.end.x - depth
		SIDE_TOP:
			p.y = region.position.y + depth
		SIDE_BOTTOM:
			p.y = region.end.y - depth
	return p


## How far `p` lies inside region from its `side`.
static func _depth(p: Vector2, region: Rect2, side: int) -> float:
	match side:
		SIDE_LEFT:
			return p.x - region.position.x
		SIDE_RIGHT:
			return region.end.x - p.x
		SIDE_TOP:
			return p.y - region.position.y
	return region.end.y - p.y
