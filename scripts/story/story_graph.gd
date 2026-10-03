class_name StoryGraph
extends RefCounted
## What the Story tab draws from a catalog: a node for every event the pools' files hold, loaded or
## not, one node an id, in the cast's order and then file order. An event the catalog left out is
## still a node (its errors are its badge): the parser's event when it parsed (its links draw), or
## a stub with its pool, name, and `==` line when the parser dropped it. A duplicate's later copies
## fold into the first node (their errors with it). Each catalog error lands on the event whose
## block (its `==` line up to the next) holds the error's line; the rest (the cast, the flags, a
## pool not in the cast, a line before the first event) are loose. The filters and the search are
## here too, so the tab only draws. Pure: built from a StoryCatalog, never an autoload or a Node.
##
## A catalog with errors is read again from its `loaded` texts (what load_dir or from_texts was
## given) to find the events it left out; a clean one is its events as they are.

## The act filter's "any act"; 0 is "no act named".
const ANY_ACT := -1
const _ERROR_AT := "^([a-z][a-z0-9_]*)\\.txt:(\\d+):"

## The cast's ids in order: a lane each.
var pools: Array[String] = []
var events: Array[StoryEvent] = []
## Event id -> Array[String], the catalog's errors in its block (only ids with one).
var errors_of: Dictionary = {}
## The catalog's errors in no event's block.
var loose_errors: Array[String] = []
var _by_id: Dictionary = {}
var _loaded: Dictionary = {}
## Pool -> [[`==` line, id], ...] in file order (only read for a catalog with errors).
var _heads: Dictionary = {}
## Left-out id -> its block as written (the next event's comment left out).
var _texts: Dictionary = {}


static func of(catalog: StoryCatalog) -> StoryGraph:
	var graph := StoryGraph.new()
	graph.pools.assign(catalog.cast.keys())
	for event in catalog.events:
		graph._loaded[event.id] = true
	if catalog.errors.is_empty():
		for event in catalog.events:
			graph._add(event)
		return graph
	for pool in graph.pools:
		graph._read_pool(catalog, pool, str(catalog.loaded.get(pool, "")))
	var at := RegEx.create_from_string(_ERROR_AT)
	for message in catalog.errors:
		var target := graph._target(at, message)
		if target == "":
			graph.loose_errors.append(message)
		else:
			if not graph.errors_of.has(target):
				graph.errors_of[target] = [] as Array[String]
			(graph.errors_of[target] as Array[String]).append(message)
	return graph


## True when the event loaded (it plays); false for a node drawn from the file alone.
func is_loaded(id: String) -> bool:
	return _loaded.has(id)


## The node's event (null for an id not drawn).
func event(id: String) -> StoryEvent:
	return _by_id.get(id)


## The id of the event an error is about ("" for a loose one): what a click in the error list
## selects.
func error_target(message: String) -> String:
	for id: String in errors_of:
		if (errors_of[id] as Array).has(message):
			return id
	return ""


## The side panel's text: a loaded event in the file's canonical form (StoryScript.write_event),
## a left-out one as its file has it; "" for an id not drawn.
func text(id: String) -> String:
	if _texts.has(id):
		return _texts[id]
	return StoryScript.write_event(_by_id[id]) if _by_id.has(id) else ""


## The lines and choices (a choice's own lines too) still marked PLACEHOLDER.
static func placeholder_count(event: StoryEvent) -> int:
	var count := 0
	for text in _texts_of(event):
		if text.begins_with(StoryScript.MARKER):
			count += 1
	return count


## True when the query (case-insensitive) is in the event's id or any of its lines' or choices'
## text; an empty query matches every event.
static func matches(event: StoryEvent, query: String) -> bool:
	var wanted := query.strip_edges().to_lower()
	if wanted == "" or event.id.to_lower().contains(wanted):
		return true
	for text in _texts_of(event):
		if text.to_lower().contains(wanted):
			return true
	return false


## The toolbar's filters: the pool ("" any), the act (ANY_ACT any, 0 for none named), the search.
static func passes(event: StoryEvent, pool: String, act: int, query: String) -> bool:
	if pool != "" and event.pool != pool:
		return false
	if act != ANY_ACT and event.act != act:
		return false
	return matches(event, query)


## Every line's and choice's text in the event's body, a choice's lines after it.
static func _texts_of(event: StoryEvent) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in event.body:
		match entry["kind"]:
			"line":
				out.append(entry["text"])
			"choice":
				out.append(entry["text"])
				for line: Dictionary in entry["lines"]:
					if line["kind"] == "line":
						out.append(line["text"])
	return out


func _add(event: StoryEvent) -> void:
	if _by_id.has(event.id):
		return
	_by_id[event.id] = event
	events.append(event)


## One pool's nodes in file order: the loaded event, else the parser's, else a stub.
func _read_pool(catalog: StoryCatalog, pool: String, text: String) -> void:
	var parsed := {}  # `==` line -> the parser's event
	for event: StoryEvent in StoryScript.parse(text, pool)["events"]:
		parsed[event.line_number] = event
	var lines := text.split("\n")
	var heads: Array = []
	for i in lines.size():
		var trimmed := lines[i].strip_edges()
		if trimmed.begins_with("=="):
			var name := StoryScript.strip_comment(trimmed).substr(2).strip_edges()
			heads.append([i + 1, StoryEvent.id_for(pool, name), name])
	_heads[pool] = heads
	for h in heads.size():
		var line: int = heads[h][0]
		var id: String = heads[h][1]
		if catalog.by_id.has(id):
			_add(catalog.by_id[id])
			continue
		if _by_id.has(id):
			continue
		var event: StoryEvent = parsed.get(line)
		if event == null:
			event = StoryEvent.new()
			event.pool = pool
			event.name = heads[h][2]
			event.id = id
			event.line_number = line
		_add(event)
		var end: int = heads[h + 1][0] - 1 if h + 1 < heads.size() else lines.size()
		_texts[id] = _block(lines, line, end)


## Lines `first` to `last` (1-based) joined, the trailing blanks and comments left out (they are
## the next event's comment, or the file's footer).
static func _block(lines: PackedStringArray, first: int, last: int) -> String:
	var kept: Array[String] = []
	for n in range(first, last + 1):
		kept.append(lines[n - 1].trim_suffix("\r"))
	while kept.size() > 1:
		var tail: String = kept.back().strip_edges()
		if tail == "" or tail.begins_with("#"):
			kept.pop_back()
		else:
			break
	return "\n".join(kept)


## The id of the event whose block holds the error's line, or "" (no pool line, or before the
## pool's first event).
func _target(at: RegEx, message: String) -> String:
	var found := at.search(message)
	if found == null or not _heads.has(found.get_string(1)):
		return ""
	var line := int(found.get_string(2))
	var target := ""
	for head: Array in _heads[found.get_string(1)]:
		if int(head[0]) > line:
			break
		target = head[1]
	return target
