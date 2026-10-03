class_name StoryLayout
extends RefCounted
## The Story tab's layout, computed (no position is saved): a lane per pool in the order given
## (the cast's), a column per depth in the chain of prerequisites, and the events of one cell (one
## pool, one depth) stacked in file order. Cells are grid units: the tab scales them to pixels.
## Pure: the events come in as a list (the catalog's, or StoryGraph's every event in the files,
## loaded or not), so an event's requires may name an id not in the list (it counts for nothing)
## or close a cycle (the walk ends at the event it is already inside).


## Event id -> its depth: 0 with no prerequisite in the list, else one past its deepest one (its
## requires, across pools).
static func depths(events: Array[StoryEvent]) -> Dictionary:
	var by_id := {}
	for event in events:
		if not by_id.has(event.id):
			by_id[event.id] = event
	var out := {}
	var walking := {}
	for event in events:
		_depth(event.id, by_id, out, walking)
	return out


## Event id -> Vector2i(column, row): the column its depth, the row its lane's first row plus its
## place in its cell (file order). Only the events of the pools given are placed. `depth` is
## depths(events) when the caller has it already (empty: worked out here).
static func positions(events: Array[StoryEvent], pools: Array[String], depth: Dictionary = {}) -> Dictionary:
	if depth.is_empty():
		depth = depths(events)
	var lane := lanes(events, pools, depth)
	var filled := {}  # Vector2i(pool's lane index, column) -> events placed there so far
	var out := {}
	for event in events:
		if not lane.has(event.pool) or out.has(event.id):
			continue
		var column: int = depth[event.id]
		var key := Vector2i(pools.find(event.pool), column)
		var below: int = filled.get(key, 0)
		filled[key] = below + 1
		out[event.id] = Vector2i(column, (lane[event.pool] as Vector2i).x + below)
	return out


## Pool -> Vector2i(first row, rows) in the order given: a lane is as tall as its fullest cell, one
## row at least (an empty pool keeps its lane). `depth` as for positions.
static func lanes(events: Array[StoryEvent], pools: Array[String], depth: Dictionary = {}) -> Dictionary:
	if depth.is_empty():
		depth = depths(events)
	var counts := {}  # Vector2i(lane index, column) -> events
	var seen := {}
	var tallest := {}  # pool -> its fullest cell's count
	for event in events:
		var index := pools.find(event.pool)
		if index < 0 or seen.has(event.id):
			continue
		seen[event.id] = true
		var key := Vector2i(index, depth[event.id])
		counts[key] = int(counts.get(key, 0)) + 1
		tallest[event.pool] = maxi(int(tallest.get(event.pool, 0)), counts[key])
	var out := {}
	var row := 0
	for pool in pools:
		var rows := maxi(1, int(tallest.get(pool, 0)))
		out[pool] = Vector2i(row, rows)
		row += rows
	return out


## The id's depth, memoised in `out`; `walking` holds the ids on the walk's path (a requires back
## to one of them is a cycle: it counts for nothing).
static func _depth(id: String, by_id: Dictionary, out: Dictionary, walking: Dictionary) -> int:
	if out.has(id):
		return out[id]
	walking[id] = true
	var deepest := -1
	for prerequisite: String in (by_id[id] as StoryEvent).requires:
		if by_id.has(prerequisite) and not walking.has(prerequisite):
			deepest = maxi(deepest, _depth(prerequisite, by_id, out, walking))
	walking.erase(id)
	out[id] = deepest + 1
	return out[id]
