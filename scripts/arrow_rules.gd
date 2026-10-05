class_name ArrowRules
extends RefCounted
## Pure geometry behind the off-screen arrows (the M7 design's "Off-screen arrows"): where an
## enemy's arrow sits on the screen and which way it points, how faint it is near the edge, and
## arrows nudged apart along the edge. Screen rects and points only (the caller maps the world onto
## the screen); no autoload, no Node, no viewport.


## The arrow for an enemy at `to` seen from the player at `from` (both in the screen's
## coordinates): {"at", "angle"}. `at` is where the line from the player toward the enemy meets
## `view` shrunk by `inset` (the player's point taken inside that rect first, so a player pressed
## against the screen's edge still puts the arrow on it); `angle` is the line's, in radians
## (Vector2.angle: 0 right, PI/2 down). An enemy on the player's point gives the player's point.
static func place(view: Rect2, from: Vector2, to: Vector2, inset: float) -> Dictionary:
	var inner := view.grow(-inset)
	var start := from.clamp(inner.position, inner.end)
	var line := to - start
	if line.is_zero_approx():
		return {"at": start, "angle": 0.0}
	# The ray's fraction at which it reaches the inner rect's edge on each axis it moves along.
	var t := INF
	if line.x > 0.0:
		t = minf(t, (inner.end.x - start.x) / line.x)
	elif line.x < 0.0:
		t = minf(t, (inner.position.x - start.x) / line.x)
	if line.y > 0.0:
		t = minf(t, (inner.end.y - start.y) / line.y)
	elif line.y < 0.0:
		t = minf(t, (inner.position.y - start.y) / line.y)
	var at := (start + line * t).clamp(inner.position, inner.end)
	return {"at": at, "angle": line.angle()}


## How opaque the arrow of an enemy at `point` is: 0 on `rect`'s edge (or inside it), rising with
## the distance past the edge to 1 at `fade` past it (past a corner, the distance to the corner),
## so an arrow never pops in or out. A `fade` of 0 is full at once.
static func alpha(rect: Rect2, point: Vector2, fade: float) -> float:
	var past := point - point.clamp(rect.position, rect.end)
	var distance := past.length()
	if fade <= 0.0:
		return 1.0 if distance > 0.0 else 0.0
	return clampf(distance / fade, 0.0, 1.0)


## `points` (each on `rect`'s edge: place()'s, on its inset rect) nudged along the edge, around a
## corner if need be, so that no two are nearer than `gap` along it, each moved as little as it can
## be (the least squared displacement keeping the order along the edge). Returned in `points`'
## order. More points than the edge holds `gap` apart are set evenly around it.
static func spread(rect: Rect2, points: Array[Vector2], gap: float) -> Array[Vector2]:
	var count := points.size()
	var result: Array[Vector2] = points.duplicate()
	if count < 2:
		return result
	var perimeter := (rect.size.x + rect.size.y) * 2.0
	var along: Array[float] = []
	for p in points:
		along.append(_along(rect, p))
	var order: Array = range(count)
	order.sort_custom(func(a: int, b: int) -> bool:
		return along[a] < along[b] or (along[a] == along[b] and a < b))
	# Cut the loop at its widest empty stretch, so a cluster across the top left corner (where the
	# measure starts) is one run, not its two ends.
	var cut := 0
	var widest := -1.0
	for k in count:
		var next := along[order[(k + 1) % count]] + (perimeter if k == count - 1 else 0.0)
		if next - along[order[k]] > widest:
			widest = next - along[order[k]]
			cut = (k + 1) % count
	var run: Array[float] = []
	var base := along[order[cut]]
	for k in count:
		var s := along[order[(cut + k) % count]]
		run.append(s if s >= base else s + perimeter)
	var placed: Array[float] = _even(run, perimeter) if gap * count > perimeter else _apart(run, gap)
	for k in count:
		result[order[(cut + k) % count]] = _point(rect, fposmod(placed[k], perimeter))
	return result


## `run` (ascending) moved as little as it can be (least squares) so that each is at least `gap`
## past the one before: the pool-adjacent-violators fit of run[k] - k * gap, made non-decreasing.
static func _apart(run: Array[float], gap: float) -> Array[float]:
	var means: Array[float] = []
	var sizes: Array[int] = []
	for k in run.size():
		means.append(run[k] - k * gap)
		sizes.append(1)
		while means.size() > 1 and means[-2] > means[-1]:
			var merged := (means[-2] * sizes[-2] + means[-1] * sizes[-1]) / float(sizes[-2] + sizes[-1])
			sizes[-2] += sizes[-1]
			means[-2] = merged
			means.pop_back()
			sizes.pop_back()
	var placed: Array[float] = []
	for block in means.size():
		for i in sizes[block]:
			placed.append(means[block] + placed.size() * gap)
	return placed


## `run`'s points set evenly around the whole edge from its first.
static func _even(run: Array[float], perimeter: float) -> Array[float]:
	var placed: Array[float] = []
	for k in run.size():
		placed.append(run[0] + perimeter * k / run.size())
	return placed


## How far along `rect`'s edge `point` sits, clockwise from the top left corner: the top edge,
## the right, the bottom, the left. A point off the edge is measured at its nearest edge.
static func _along(rect: Rect2, point: Vector2) -> float:
	var w := rect.size.x
	var h := rect.size.y
	var p := point.clamp(rect.position, rect.end) - rect.position
	var to_edge := [p.y, w - p.x, h - p.y, p.x]  # top, right, bottom, left
	var nearest := 0
	for i in range(1, 4):
		if to_edge[i] < to_edge[nearest]:
			nearest = i
	match nearest:
		0:
			return p.x
		1:
			return w + p.y
		2:
			return w + h + (w - p.x)
		_:
			return w * 2.0 + h + (h - p.y)


## The point `s` along `rect`'s edge (_along's inverse), `s` in [0, perimeter).
static func _point(rect: Rect2, s: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	if s <= w:
		return rect.position + Vector2(s, 0.0)
	if s <= w + h:
		return rect.position + Vector2(w, s - w)
	if s <= w * 2.0 + h:
		return rect.position + Vector2(w - (s - w - h), h)
	return rect.position + Vector2(0.0, h - (s - w * 2.0 - h))
