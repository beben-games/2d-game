class_name StoryLinks
extends RefCounted
## The Story tab's edges between events, three kinds: a `requires` from the prerequisite to the
## event that names it; an `unless` from the excluding event to the one it shuts; a flag link from
## an event whose effects set a flag (its end effects, or a choice's) to an event whose `when` reads
## it. `from` and `to` are as StoryEdit's add_requires and add_unless take them (GraphEdit's from
## and to: `to` names `from`). An edge is {"kind", "from", "to", "flags"} ("flags" the flags a link
## carries, sorted by the setter's order; empty for the other kinds). Pure: only events in the list
## given are joined (the tab draws StoryGraph's events, which may name one that is not there).
##
## A line's own [condition] and a {substitution} read flags too, but they do not gate the event,
## so they make no link (the lint's flag map, Task 15, lists every reader). No edge runs from an
## event to itself: one that sets a flag its own `when` reads (a once-guard) is no link, and a
## requires or an unless naming its own event (refused by the catalog, so only on a left-out event
## StoryGraph draws, already badged by its error) draws nothing.

const REQUIRES := "requires"
const UNLESS := "unless"
const FLAG := "flag"
const KINDS: Array[String] = [REQUIRES, UNLESS, FLAG]


## Every edge: the requires, then the unless, then the flag links.
static func edges(events: Array[StoryEvent]) -> Array[Dictionary]:
	var out := requires_edges(events)
	out.append_array(unless_edges(events))
	out.append_array(flag_edges(events))
	return out


## An edge from each prerequisite to the event whose requires names it, in the events' order.
static func requires_edges(events: Array[StoryEvent]) -> Array[Dictionary]:
	return _named_edges(events, REQUIRES)


## An edge from each excluding event to the event whose unless names it, in the events' order.
static func unless_edges(events: Array[StoryEvent]) -> Array[Dictionary]:
	return _named_edges(events, UNLESS)


## One edge from each event that sets a flag to each other event whose `when` reads it, carrying
## every such flag; by setter, then by reader, in the events' order.
static func flag_edges(events: Array[StoryEvent]) -> Array[Dictionary]:
	var read_by := {}  # id -> reads(event), once each
	for event in events:
		read_by[event.id] = reads(event)
	var out: Array[Dictionary] = []
	for setter in events:
		var set_flags := sets(setter)
		if set_flags.is_empty():
			continue
		for reader in events:
			if reader.id == setter.id:
				continue
			var read: Array[String] = read_by[reader.id]
			var carried: Array[String] = []
			for flag in set_flags:
				if read.has(flag):
					carried.append(flag)
			if not carried.is_empty():
				out.append(_edge(FLAG, setter.id, reader.id, carried))
	return out


## The flags the event's effects set (its choices' in body order, then its end effects), each once.
static func sets(event: StoryEvent) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in event.body:
		if entry["kind"] == "choice":
			_add_flags(entry["effects"], out)
	_add_flags(event.effects, out)
	return out


## The names the event's `when` reads (either side of a comparison, a bare name), each once; empty
## with no `when`.
static func reads(event: StoryEvent) -> Array[String]:
	var out: Array[String] = []
	if event.when == null:
		return out
	out.assign(event.when.names())
	for name in event.when.right_names():
		if not out.has(name):
			out.append(name)
	return out


static func _named_edges(events: Array[StoryEvent], key: String) -> Array[Dictionary]:
	var present := {}
	for event in events:
		present[event.id] = true
	var out: Array[Dictionary] = []
	for event in events:
		var named: Array[String] = event.requires if key == REQUIRES else event.unless
		for id in named:
			if present.has(id) and id != event.id:
				out.append(_edge(key, id, event.id, []))
	return out


static func _add_flags(effects: Array, out: Array[String]) -> void:
	for effect: Dictionary in effects:
		var flag: String = effect["flag"]
		if not out.has(flag):
			out.append(flag)


static func _edge(kind: String, from: String, to: String, flags: Array[String]) -> Dictionary:
	return {"kind": kind, "from": from, "to": to, "flags": flags}
