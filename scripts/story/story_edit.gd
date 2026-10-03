class_name StoryEdit
extends RefCounted
## The Story tab's edits over a catalog (docs/plans/2026-10-01-milestone-6.md, Task 11): links
## added and removed, events added, deleted, renamed, and replaced from their text. Every edit
## returns the errors that refused it (empty when it was made). An edit is made on copies of the
## pools (parsed from their written text, so nothing is shared with the catalog it starts from),
## written back in the canonical form (StoryScript.write), and validated as a load is
## (StoryCatalog.with_texts): when the result has an error (a cycle, a duplicate name, an event
## still named by another), the edit is refused with the catalog's errors and nothing changes;
## else `catalog` is the result and the pools whose text changed are dirty until a save. The
## errors' line numbers are the written text's.
##
## Edits start only from a catalog that loaded clean: an event with an error is not in the
## catalog, so a pool written back from it would lose that event. Fix the files, reload, edit.
##
## An event's id keys `played` in the players' saves: a rename makes the event play again, and
## resets the requires chains that name it, for every player who had seen it.
##
## Pure: no autoload, no Node (the Story tab runs it in the editor).

## The story as edited so far: valid, written back, the pools' header and footer comments kept.
var catalog: StoryCatalog
var _dirty: Dictionary = {}


func _init(start: StoryCatalog) -> void:
	catalog = start


## `to_id` gains `from_id` in its requires: the edge from the prerequisite to the event it
## opens, as the graph draws it (GraphEdit's from and to).
func add_requires(from_id: String, to_id: String) -> Array[String]:
	return _link("requires", from_id, to_id, true)


func remove_requires(from_id: String, to_id: String) -> Array[String]:
	return _link("requires", from_id, to_id, false)


## `to_id` gains `from_id` in its unless: the edge from the event that shuts to the one it shuts.
func add_unless(from_id: String, to_id: String) -> Array[String]:
	return _link("unless", from_id, to_id, true)


func remove_unless(from_id: String, to_id: String) -> Array[String]:
	return _link("unless", from_id, to_id, false)


## A new event at the end of the pool: the name and nothing else (talk, once, normal, no body).
## The pool may have no file yet (the save writes it).
func add_event(pool: String, name: String) -> Array[String]:
	if not catalog.cast.has(pool):
		return ["%s.txt: not in the cast (%s)" % [pool, StoryCatalog.CAST_FILE]]
	if not StoryScript.is_name(name):
		return ["%s.txt: '%s' is not a name (letters, digits, '_')" % [pool, name]]
	return _edit(func(pools: Dictionary) -> void:
		var event := StoryEvent.new()
		event.pool = pool
		event.name = name
		event.id = pool + "." + name
		(pools[pool] as Array).append(event)
	)


## Removes the event, its comment with it; refused while another event names it in its requires
## or unless (the catalog's "unknown event" error says which).
func delete_event(id: String) -> Array[String]:
	if not catalog.by_id.has(id):
		return [_unknown(id)]
	return _edit(func(pools: Dictionary) -> void:
		var events: Array = pools[(catalog.by_id[id] as StoryEvent).pool]
		events.remove_at(_index(events, id))
	)


## The event's new name (its pool kept): every requires and unless in every pool that names it
## follows. The same name changes nothing.
func rename(id: String, new_name: String) -> Array[String]:
	if not catalog.by_id.has(id):
		return [_unknown(id)]
	var pool := (catalog.by_id[id] as StoryEvent).pool
	if not StoryScript.is_name(new_name):
		return ["%s.txt: '%s' is not a name (letters, digits, '_')" % [pool, new_name]]
	var new_id := pool + "." + new_name
	if new_id == id:
		return []
	return _edit(func(pools: Dictionary) -> void:
		var events: Array = pools[pool]
		var event: StoryEvent = events[_index(events, id)]
		event.name = new_name
		event.id = new_id
		for other: String in pools:
			for each: StoryEvent in pools[other]:
				_replace_in(each.requires, id, new_id)
				_replace_in(each.unless, id, new_id)
	)


## The side panel's Apply: `text` holds one event in the file's format (as write_event gives it),
## parsed in the event's pool, replacing the event in its place. The text's errors (its own line
## numbers), or the catalog's for the result, refuse it. A comment block above the `==` is the
## event's, across blank lines too; a comment after the event's last line is refused (it would
## become the next event's on a reload). A new name in the text renames the event without
## following it: refused while another event names the old id (rename follows).
func replace_event(id: String, text: String) -> Array[String]:
	if not catalog.by_id.has(id):
		return [_unknown(id)]
	var pool := (catalog.by_id[id] as StoryEvent).pool
	var parsed := StoryScript.parse(text, pool)
	var errors: Array[String] = []
	errors.assign(parsed["errors"])
	if not errors.is_empty():
		return errors
	if parsed["events"].size() != 1:
		return ["%s.txt: the text holds %d events: an Apply takes one" % [pool, parsed["events"].size()]]
	if parsed["footer"] != "":
		return ["%s.txt: a comment after the event's last line: put it above the line it is about" % pool]
	var replacement: StoryEvent = parsed["events"][0]
	if parsed["header"] != "":
		replacement.comment = parsed["header"] + ("\n" + replacement.comment if replacement.comment != "" else "")
	return _edit(func(pools: Dictionary) -> void:
		var events: Array = pools[pool]
		events[_index(events, id)] = replacement
	)


## The pools whose text an edit changed since the start or the last save, in the cast's order.
func dirty_pools() -> Array[String]:
	var pools: Array[String] = []
	for pool: String in catalog.cast:
		if _dirty.has(pool):
			pools.append(pool)
	return pools


## Writes the dirty pools to `dir` (StoryCatalog.save_dir) and, when every file was written,
## forgets them. Returns save_dir's errors.
func save(dir: String) -> Array[String]:
	var errors := catalog.save_dir(dir, dirty_pools())
	if errors.is_empty():
		_dirty.clear()
	return errors


func _link(key: String, from_id: String, to_id: String, add: bool) -> Array[String]:
	for id in [from_id, to_id]:
		if not catalog.by_id.has(id):
			return [_unknown(id)]
	var to: StoryEvent = catalog.by_id[to_id]
	var has: bool = from_id in to.get(key)
	if add and has:
		return ["%s already %s" % [to_id, _link_text(key, from_id)]]
	if not add and not has:
		return ["%s does not %s" % [to_id, _link_text(key, from_id, false)]]
	return _edit(func(pools: Dictionary) -> void:
		var events: Array = pools[to.pool]
		var event: StoryEvent = events[_index(events, to_id)]
		var ids: Array[String] = []
		ids.assign(event.get(key))
		if add:
			ids.append(from_id)
		else:
			ids.erase(from_id)
		event.set(key, ids)
	)


## The link's words after "already" (`present`) or "does not".
static func _link_text(key: String, id: String, present := true) -> String:
	if key == "requires":
		return ("requires %s" if present else "require %s") % id
	return ("has %s in its unless" if present else "have %s in its unless") % id


## Applies `change` to fresh copies of every cast pool's events (pool id -> Array of StoryEvent)
## and keeps the result when it loads clean; else the catalog's errors, and nothing changed.
func _edit(change: Callable) -> Array[String]:
	if not catalog.errors.is_empty():
		var refused: Array[String] = ["the story has errors: fix the files and reload before editing"]
		refused.append_array(catalog.errors)
		return refused
	var pools := {}
	for pool: String in catalog.cast:
		pools[pool] = StoryScript.parse(catalog.text_of(pool), pool)["events"]
	change.call(pools)
	var texts := {}
	var changed: Array[String] = []
	for pool: String in pools:
		var events: Array[StoryEvent] = []
		events.assign(pools[pool])
		texts[pool] = StoryScript.write(events, catalog.headers.get(pool, ""), catalog.footers.get(pool, ""))
		if texts[pool] != catalog.text_of(pool):
			changed.append(pool)
	var result := catalog.with_texts(texts)
	if not result.errors.is_empty():
		return result.errors
	catalog = result
	for pool in changed:
		_dirty[pool] = true
	return []


## The event's index in its pool's list (the id is the catalog's, so it is there).
static func _index(events: Array, id: String) -> int:
	for i in events.size():
		if (events[i] as StoryEvent).id == id:
			return i
	return -1


static func _replace_in(ids: Array[String], old_id: String, new_id: String) -> void:
	var at := ids.find(old_id)
	if at >= 0:
		ids[at] = new_id


static func _unknown(id: String) -> String:
	return "unknown event '%s'" % id
