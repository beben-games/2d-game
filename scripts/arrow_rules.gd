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
## corner if need be, so that no two are nearer than their share of `gap` along it, each moved as
## little as it can be (the least squared displacement keeping their order along the edge).
## Returned in `points`' order. More points than the edge holds `gap` apart are set evenly.
## - `weights` (default all 1; an arrow's alpha): two neighbours keep `gap` times the smaller of
##   their weights between them, so an arrow fading out pushes less and less, and at 0 nothing:
##   its neighbour slides back onto its own line as it fades instead of jumping when it goes.
## - `held` (default `points`; where each was placed last): points nearer than their gap (a run
##   of them, chained) keep the order they were held in, not their order now, so two arrows whose
##   lines cross keep their slots (no swap within a frame); points farther apart take their order
##   from where they are now.
static func spread(rect: Rect2, points: Array[Vector2], gap: float, weights: Array[float] = [],
		held: Array[Vector2] = []) -> Array[Vector2]:
	var count := points.size()
	var result: Array[Vector2] = points.duplicate()
	if count < 2:
		return result
	var perimeter := (rect.size.x + rect.size.y) * 2.0
	var along: Array[float] = []
	var weight: Array[float] = []
	for i in count:
		along.append(_along(rect, points[i]))
		weight.append(clampf(weights[i], 0.0, 1.0) if i < weights.size() else 1.0)
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
	var base := along[order[cut]]
	var run_ids: Array[int] = []
	var at_run := {}  # index to its measure along the run (past the cut: plus the perimeter)
	for k in count:
		var i: int = order[(cut + k) % count]
		run_ids.append(i)
		at_run[i] = along[i] if along[i] >= base else along[i] + perimeter
	if gap * count > perimeter:
		var even: Array[float] = []
		for k in count:
			even.append(at_run[run_ids[0]] + perimeter * k / count)
		for k in count:
			result[run_ids[k]] = _point(rect, fposmod(even[k], perimeter))
		return result
	run_ids = _held_order(run_ids, at_run, weight, gap, _held_along(rect, held, at_run, perimeter))
	var values: Array[float] = []
	var offsets: Array[float] = []  # each one's least distance from the run's first, its gaps summed
	for k in count:
		values.append(at_run[run_ids[k]])
		var pair := 0.0 if k == 0 else gap * minf(weight[run_ids[k - 1]], weight[run_ids[k]])
		offsets.append(pair if k == 0 else offsets[k - 1] + pair)
	var placed := _apart(values, offsets)
	for k in count:
		result[run_ids[k]] = _point(rect, fposmod(placed[k], perimeter))
	return result


## Each point's held place measured along the edge on the run's own unrolled measure (within half
## the perimeter of its measure now, so a hold across the corner where the measure wraps compares
## right); a point with no hold is held where it is.
static func _held_along(rect: Rect2, held: Array[Vector2], at_run: Dictionary, perimeter: float) -> Dictionary:
	var keys := {}
	for i: int in at_run:
		var now: float = at_run[i]
		if i >= held.size():
			keys[i] = now
			continue
		var was := _along(rect, held[i])
		keys[i] = was + perimeter * roundf((now - was) / perimeter)
	return keys


## `run_ids` (ascending along the run) with each chain (neighbours nearer than their weighted gap)
## put in its held order (`keys`; ties by where they are now, then by index).
static func _held_order(run_ids: Array[int], at_run: Dictionary, weight: Array[float], gap: float,
		keys: Dictionary) -> Array[int]:
	var ordered: Array[int] = []
	var chain: Array[int] = []
	for k in run_ids.size():
		var i := run_ids[k]
		if not chain.is_empty():
			var last := chain[-1]
			if at_run[i] - at_run[last] >= gap * minf(weight[last], weight[i]):
				ordered.append_array(_by_key(chain, keys, at_run))
				chain.clear()
		chain.append(i)
	ordered.append_array(_by_key(chain, keys, at_run))
	return ordered


static func _by_key(chain: Array[int], keys: Dictionary, at_run: Dictionary) -> Array[int]:
	var sorted := chain.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		if keys[a] != keys[b]:
			return keys[a] < keys[b]
		if at_run[a] != at_run[b]:
			return at_run[a] < at_run[b]
		return a < b)
	return sorted


## `values` moved as little as they can be (least squares) so that each is at least its offset
## less the one before's past the one before (`offsets` ascending, the first 0): the
## pool-adjacent-violators fit of values[k] - offsets[k], made non-decreasing.
static func _apart(values: Array[float], offsets: Array[float]) -> Array[float]:
	var means: Array[float] = []
	var sizes: Array[int] = []
	for k in values.size():
		means.append(values[k] - offsets[k])
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
			placed.append(means[block] + offsets[placed.size()])
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
