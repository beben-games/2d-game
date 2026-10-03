class_name StoryGraph
extends RefCounted
## What the Story tab draws from a catalog: a node for every event the pools' texts hold, loaded
## or not, one node an id, in the cast's order and then file order. An event the catalog left out is
## still a node (its errors are its badge): the parser's event when it parsed (its links draw), or
## a stub with its pool, name, and `==` line when the parser dropped it (`is_parsed` false). A
## duplicate's later copies fold into the first node (their errors with it). Each catalog error
## lands on the event whose block (its `==` line up to the next) holds the error's line, or that
## its message names first ("<event id>: ...", as StoryEdit words an error outside its text); the
## rest (the cast, the flags, a pool not in the cast, a line before the first event) are loose. The
## badges, the filters, and the search are here too, so the tab only draws. Pure: built from a
## StoryCatalog, never an autoload or a Node.
##
## The texts read are the ones the catalog was built from (`catalog.texts`: for an edit's catalog,
## from with_texts, the edited text; `loaded` is the disk's).

## The act filter's "any act"; 0 is "no act named".
const ANY_ACT := -1

## The cast's ids in order: a lane each.
var pools: Array[String] = []
var events: Array[StoryEvent] = []
## The catalog's errors in its order, each {"message", "target"} (the event id, "" for a loose
## one): what the error list shows and selects.
var errors: Array[Dictionary] = []
## Event id -> Array[String], the catalog's errors on that event (only ids with one).
var errors_of: Dictionary = {}
## The catalog's errors on no event.
var loose_errors: Array[String] = []
var _by_id: Dictionary = {}
var _loaded: Dictionary = {}
## The ids of the stubs (the parser dropped them).
var _stubs: Dictionary = {}
## Pool -> [[`==` line, id], ...] in file order.
var _heads: Dictionary = {}
## Id -> its side panel text: a left-out event's block as written (the next event's comment left
## out), filled at the build; a loaded event's written form, filled on its first ask (text()).
var _texts: Dictionary = {}


static func of(catalog: StoryCatalog) -> StoryGraph:
	var graph := StoryGraph.new()
	graph.pools.assign(catalog.cast.keys())
	for event in catalog.events:
		graph._loaded[event.id] = true
	for pool in graph.pools:
		graph._read_pool(catalog, pool, str(catalog.texts.get(pool, "")))
	for event in catalog.events:  # none is missing from its text; kept whole whatever happens
		graph._add(event)
	for message in catalog.errors:
		var target := graph.target_of(message)
		graph.errors.append({"message": message, "target": target})
		if target == "":
			graph.loose_errors.append(message)
		else:
			if not graph.errors_of.has(target):
				graph.errors_of[target] = [] as Array[String]
			(graph.errors_of[target] as Array[String]).append(message)
	return graph


## The id of the event a message is about, "" for none: "<pool>.txt:<line>: ..." is the event
## whose block holds the line; "<event id>: ..." the event it names, when drawn. Only two kinds of
## message come here: the catalog's (its load's lines, in the texts this graph was built from) and
## those that name an event ("<event id>: ...", StoryEdit's form for an error outside a text).
## StoryEdit.replace_event's errors do not: their lines are the side panel text's own, so the
## Story tab keeps them in the panel and marks that line there (StoryEdit.text_line).
func target_of(message: String) -> String:
	var head := message.get_slice(": ", 0)
	if _by_id.has(head):
		return head
	var parts := head.split(":")
	if parts.size() != 2 or not parts[0].ends_with(".txt") or not parts[1].is_valid_int():
		return ""
	var pool := parts[0].trim_suffix(".txt")
	var line := int(parts[1])
	var target := ""
	for entry: Array in _heads.get(pool, []):
		if int(entry[0]) > line:
			break
		target = entry[1]
	return target


## True when the event loaded (it plays); false for a node drawn from the file alone.
func is_loaded(id: String) -> bool:
	return _loaded.has(id)


## The node's event (null for an id not drawn).
func event(id: String) -> StoryEvent:
	return _by_id.get(id)


## False for a stub: the parser dropped it, so its header's facts are unknown.
func is_parsed(id: String) -> bool:
	return _by_id.has(id) and not _stubs.has(id)


## The node's badges, for EventNode.show_event: {"placeholders", "errors", "loaded", "parsed"}.
func badges(id: String) -> Dictionary:
	var drawn: StoryEvent = _by_id.get(id)
	return {
		"placeholders": placeholder_count(drawn) if drawn != null else 0,
		"errors": (errors_of.get(id, []) as Array).size(),
		"loaded": is_loaded(id),
		"parsed": is_parsed(id),
	}


## The toolbar's filters on a node: passes(), a stub's search reading its block as written (it has
## no parsed lines).
func shows(id: String, pool: String, act: int, query: String) -> bool:
	var drawn: StoryEvent = _by_id.get(id)
	if drawn == null:
		return false
	return passes(drawn, pool, act, query, _texts.get(id, "") if _stubs.has(id) else "")


## The side panel's text: a loaded event in the file's canonical form (StoryScript.write_event,
## written once: the graph is never changed, and the panel compares against it per keystroke), a
## left-out one as its file has it; "" for an id not drawn.
func text(id: String) -> String:
	if not _texts.has(id):
		if not _by_id.has(id):
			return ""
		_texts[id] = StoryScript.write_event(_by_id[id])
	return _texts[id]


## The lines and choices (a choice's own lines too) still marked PLACEHOLDER.
static func placeholder_count(event: StoryEvent) -> int:
	var count := 0
	for text in _texts_of(event):
		if text.begins_with(StoryScript.MARKER):
			count += 1
	return count


## True when the query (case-insensitive) is in the event's id, any of its lines' or choices'
## text, or `extra` (a stub's block); an empty query matches every event.
static func matches(event: StoryEvent, query: String, extra := "") -> bool:
	var wanted := query.strip_edges().to_lower()
	if wanted == "" or event.id.to_lower().contains(wanted) or extra.to_lower().contains(wanted):
		return true
	for text in _texts_of(event):
		if text.to_lower().contains(wanted):
			return true
	return false


## The toolbar's filters: the pool ("" any), the act (ANY_ACT any, 0 for none named), the search.
static func passes(event: StoryEvent, pool: String, act: int, query: String, extra := "") -> bool:
	if pool != "" and event.pool != pool:
		return false
	if act != ANY_ACT and event.act != act:
		return false
	return matches(event, query, extra)


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


## One pool's nodes in file order: the loaded event, else the parser's (the text parsed again
## only for a catalog with errors: a clean one left nothing out), else a stub.
func _read_pool(catalog: StoryCatalog, pool: String, text: String) -> void:
	var parsed := {}  # `==` line -> the parser's event
	if not catalog.errors.is_empty():
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
			_stubs[id] = true
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
