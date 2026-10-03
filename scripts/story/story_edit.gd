class_name StoryEdit
extends RefCounted
## The Story tab's edits over a catalog (docs/plans/2026-10-01-milestone-6.md, Task 11): links
## added and removed, events added, deleted, renamed, and replaced from their text. Every edit
## returns the errors that refused it (empty when it was made). An edit is made on copies of the
## pools (parsed from their written text, so nothing is shared with the catalog it starts from),
## written back in the canonical form (StoryScript.write), and validated as a load is
## (StoryCatalog.with_texts): when the result has an error (a cycle, a duplicate name, an event
## still named by another), the edit is refused with the catalog's errors and nothing changes;
## else `catalog` is the result. A pool is dirty while its text differs from the one it had at the
## start or at its last save. A refusal names events, never a line of the rewrite it tried (a
## file the writer never sees): "lanista.second: a cycle of requires: ...", the consequences
## ("..., which did not load") left out when a cause is there; replace_event's errors carry the
## text's own line inside the event it applies.
##
## Edits start only from a catalog that loaded clean: an event with an error is not in the
## catalog, so a pool written back from it would lose that event. Fix the files, reload, edit.
##
## An event's id keys `played` in the players' saves: a rename makes the event play again, and
## resets the requires chains that name it, for every player who had seen it.
##
## Pure: no autoload, no Node (the Story tab runs it in the editor).

## The header fields set_header sets, as the side panel's controls do (requires and unless are
## the links' edits): each value is what the file writes after the key, `repeat`'s "once" or
## "repeat".
const HEADER_FIELDS: Array[String] = ["when", "priority", "repeat", "trigger", "act"]
## A new event's name before the writer gives it one (unused_name numbers it).
const NEW_NAME := "new_event"

## The story as edited so far: valid, written back, the pools' header and footer comments kept.
var catalog: StoryCatalog
## Cast id -> the pool's text at the start or its last save: dirty is a difference from it.
var _baseline: Dictionary = {}
## Pool id -> the text the last edit tried (replace_event reads its refused event there).
var _tried: Dictionary = {}


func _init(start: StoryCatalog) -> void:
	catalog = start
	for pool: String in catalog.cast:
		_baseline[pool] = catalog.text_of(pool)


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


## The graph's edge of `kind` (StoryLinks.KINDS) made: requires and unless as add_requires and
## add_unless; a flag link is refused (it is derived from the events' lines, never drawn).
func add_link(kind: String, from_id: String, to_id: String) -> Array[String]:
	match kind:
		StoryLinks.REQUIRES:
			return add_requires(from_id, to_id)
		StoryLinks.UNLESS:
			return add_unless(from_id, to_id)
	return [_derived(kind)]


## The graph's edge of `kind` removed, as add_link makes it.
func remove_link(kind: String, from_id: String, to_id: String) -> Array[String]:
	match kind:
		StoryLinks.REQUIRES:
			return remove_requires(from_id, to_id)
		StoryLinks.UNLESS:
			return remove_unless(from_id, to_id)
	return [_derived(kind)]


## One header field (HEADER_FIELDS) of the event set from `value`, the text the file writes after
## the key ("" is the default and leaves the line out: no condition, normal, talk, no act; for
## `repeat`, "once" or "repeat"). The value is read as the file's header line is read, so a value
## the parser refuses is refused with its reason, and the result is validated as every edit is.
## Every error names the event ("veteran.later: when: unknown name 'x'"): a field has no line.
func set_header(id: String, key: String, value: String) -> Array[String]:
	if not catalog.by_id.has(id):
		return [_unknown(id)]
	if not key in HEADER_FIELDS:
		return ["%s: '%s' is not a header field (%s; requires and unless are links)" % [id, key, ", ".join(HEADER_FIELDS)]]
	var trimmed := value.strip_edges()
	if trimmed.contains("\n") or trimmed.contains("\r"):
		return ["%s: %s: a header value is one line" % [id, key]]
	var pool := (catalog.by_id[id] as StoryEvent).pool
	var line := ""
	if key == "repeat":
		line = trimmed if trimmed != "" else "once"
	elif trimmed != "":
		line = "%s: %s" % [key, trimmed]
	var probe := StoryScript.parse("== probe\n%s\n" % line, pool)
	var problems: Array[String] = []
	problems.assign(probe["errors"])
	problems.append_array(probe["warnings"])
	if not problems.is_empty():
		var named: Array[String] = []
		for problem in problems:
			named.append("%s: %s" % [id, problem.trim_prefix("%s.txt:2: " % pool)])
		return named
	var source: StoryEvent = probe["events"][0]
	var refused := _edit(func(pools: Dictionary) -> String:
		var events: Array = pools[pool]
		var at := _index(events, id)
		if at < 0:
			return _unknown(id)
		var event: StoryEvent = events[at]
		match key:
			"when":
				event.when = source.when
			"priority":
				event.priority = source.priority
			"repeat":
				event.once = source.once
			"trigger":
				event.trigger = source.trigger
				event.trigger_arg = source.trigger_arg
			"act":
				event.act = source.act
		return ""
	, true)
	if refused.is_empty() or not _tried.has(pool):
		return refused
	return _located(refused, pool, {})


## The header field's value as set_header takes it (the side panel's controls show it): the
## file's text after the key, "" at the default; `repeat` is "once" or "repeat".
static func header_value(event: StoryEvent, key: String) -> String:
	match key:
		"when":
			return event.when.source if event.when != null else ""
		"priority":
			return event.priority
		"repeat":
			return "once" if event.once else "repeat"
		"trigger":
			return (event.trigger + " " + event.trigger_arg).strip_edges()
		"act":
			return str(event.act) if event.act != 0 else ""
	return ""


## The line a replace_event error carries in the text it was given ("<pool>.txt:<line>: ..."),
## 0 for an error with no line (one naming another event, or the text as a whole).
static func text_line(message: String) -> int:
	var head := message.get_slice(": ", 0)
	var parts := head.split(":")
	if parts.size() != 2 or not parts[0].ends_with(".txt") or not parts[1].is_valid_int():
		return 0
	return int(parts[1])


## The event text with its `==` line naming `new_name`, when that line names `old_name` (the
## spacing kept); any other text as it is. A draft that follows a rename takes the new name, so an
## Apply does not rename it back.
static func with_name(text: String, old_name: String, new_name: String) -> String:
	var lines := text.split("\n")
	var head := RegEx.create_from_string("^(\\s*==\\s*)(\\S+)(\\s*)$")
	for i in lines.size():
		var m := head.search(lines[i])
		if m != null:
			if m.get_string(2) == old_name:
				lines[i] = m.get_string(1) + new_name + m.get_string(3)
			break
	return "\n".join(lines)


## A name the pool holds no event of: `stem`, else `stem_2`, `stem_3`, ...
func unused_name(pool: String, stem := NEW_NAME) -> String:
	var name := stem
	var n := 1
	while catalog.by_id.has(StoryEvent.id_for(pool, name)):
		n += 1
		name = "%s_%d" % [stem, n]
	return name


## A new event at the end of the pool: the name and nothing else (talk, once, normal, no body).
## The pool may have no file yet (the save writes it).
func add_event(pool: String, name: String) -> Array[String]:
	if not catalog.cast.has(pool):
		return ["%s.txt: not in the cast (%s)" % [pool, StoryCatalog.CAST_FILE]]
	if not StoryScript.is_name(name):
		return [_not_a_name(pool, name)]
	return _edit(func(pools: Dictionary) -> String:
		var event := StoryEvent.new()
		event.pool = pool
		event.name = name
		event.id = StoryEvent.id_for(pool, name)
		(pools[pool] as Array).append(event)
		return ""
	)


## Removes the event, its comment with it; refused while another event names it in its requires
## or unless, with the first that does ("veteran.hello is still named: veteran.later requires it").
func delete_event(id: String) -> Array[String]:
	return delete_events([id] as Array[String])


## The events deleted as one edit, all or nothing: every one removed in the same rewrite and the
## result validated once, so events that name each other (two that shut each other out) go
## together; refused, with the first event outside the set that still names one ("... is still
## named: ..."), and then nothing has changed.
func delete_events(ids: Array[String]) -> Array[String]:
	for id in ids:
		if not catalog.by_id.has(id):
			return [_unknown(id)]
	var refused := _edit(func(pools: Dictionary) -> String:
		for id in ids:
			var events: Array = pools[(catalog.by_id[id] as StoryEvent).pool]
			var at := _index(events, id)
			if at < 0:
				return _unknown(id)
			events.remove_at(at)
		return ""
	)
	for reason in refused:
		for id in ids:
			var m := RegEx.create_from_string("^(\\S+): unknown event '%s' in (requires|unless)$" % id.replace(".", "\\.")).search(reason)
			if m != null:
				var how := "requires it" if m.get_string(2) == "requires" else "has it in its unless"
				return ["%s is still named: %s %s" % [id, m.get_string(1), how]]
	return refused


## The event's new name (its pool kept): every requires and unless in every pool that names it
## follows. The same name changes nothing.
func rename(id: String, new_name: String) -> Array[String]:
	if not catalog.by_id.has(id):
		return [_unknown(id)]
	var pool := (catalog.by_id[id] as StoryEvent).pool
	if not StoryScript.is_name(new_name):
		return [_not_a_name(pool, new_name)]
	var new_id := StoryEvent.id_for(pool, new_name)
	if new_id == id:
		return []
	return _edit(func(pools: Dictionary) -> String:
		var events: Array = pools[pool]
		var at := _index(events, id)
		if at < 0:
			return _unknown(id)
		var event: StoryEvent = events[at]
		event.name = new_name
		event.id = new_id
		for other: String in pools:
			for each: StoryEvent in pools[other]:
				_replace_in(each.requires, id, new_id)
				_replace_in(each.unless, id, new_id)
		return ""
	)


## The side panel's Apply: `text` holds one event in the file's format (as write_event gives it),
## parsed in the event's pool, replacing the event in its place. Refused by the text's errors and
## its warnings (an inline comment the rewrite would drop: nothing is lost silently), then by the
## catalog's errors for the result: one inside the applied event carries the text's line, any
## other names its event (_located). A comment block above the `==` is the event's, across blank
## lines too; a comment the parse leaves after the event is refused (it would become the next
## event's on a reload), with its own reason when it is after the last line and when the
## canonical form would put it last under the last choice. A new name in the text renames the
## event without following it: refused while another event names the old id (rename follows).
func replace_event(id: String, text: String) -> Array[String]:
	if not catalog.by_id.has(id):
		return [_unknown(id)]
	var pool := (catalog.by_id[id] as StoryEvent).pool
	var parsed := StoryScript.parse(text, pool)
	var errors: Array[String] = []
	errors.assign(parsed["errors"])
	errors.append_array(parsed["warnings"])
	if not errors.is_empty():
		return errors
	if parsed["events"].size() != 1:
		return ["%s.txt: the text holds %d events: an Apply takes one" % [pool, parsed["events"].size()]]
	if parsed["footer"] != "":
		if _ends_in_a_comment(text):
			return ["%s.txt: a comment after the event's last line: put it above the line it is about" % pool]
		return ["%s.txt: a comment last under the event's last choice would leave the event in the saved form (a choice's effects are written before its lines): put it after a line or above the choice" % pool]
	var replacement: StoryEvent = parsed["events"][0]
	if parsed["header"] != "":
		replacement.comment = parsed["header"] + ("\n" + replacement.comment if replacement.comment != "" else "")
	var place: Array[int] = [-1]  # the lambda's result (a closure captures a local by value)
	var refused := _edit(func(pools: Dictionary) -> String:
		var events: Array = pools[pool]
		place[0] = _index(events, id)
		if place[0] < 0:
			return _unknown(id)
		events[place[0]] = replacement
		return ""
	, true)
	if refused.is_empty() or place[0] < 0 or not _tried.has(pool):
		return refused
	var written: Array = StoryScript.parse(_tried[pool], pool)["events"]
	if place[0] >= written.size():
		return refused
	return _located(refused, pool, _line_map(written[place[0]], replacement))


## The pools whose text differs from the one they had at the start or at their last save, in the
## cast's order.
func dirty_pools() -> Array[String]:
	var pools: Array[String] = []
	for pool: String in catalog.cast:
		if catalog.text_of(pool) != str(_baseline.get(pool, "")):
			pools.append(pool)
	return pools


## Writes the dirty pools to `dir` (StoryCatalog.save_dir, one pool at a time) and makes each
## one written the baseline; a pool that failed stays dirty. Returns save_dir's errors.
func save(dir: String) -> Array[String]:
	var errors: Array[String] = []
	for pool in dirty_pools():
		var failed := catalog.save_dir(dir, [pool])
		if failed.is_empty():
			_baseline[pool] = catalog.text_of(pool)
		else:
			errors.append_array(failed)
	return errors


func _link(key: String, from_id: String, to_id: String, add: bool) -> Array[String]:
	for id in [from_id, to_id]:
		if not catalog.by_id.has(id):
			return [_unknown(id)]
	var to: StoryEvent = catalog.by_id[to_id]
	var has := _links(to, key).has(from_id)
	if add and has:
		return ["%s already %s" % [to_id, _link_text(key, from_id)]]
	if not add and not has:
		return ["%s does not %s" % [to_id, _link_text(key, from_id, false)]]
	return _edit(func(pools: Dictionary) -> String:
		var events: Array = pools[to.pool]
		var at := _index(events, to_id)
		if at < 0:
			return _unknown(to_id)
		var ids := _links(events[at], key)
		if add:
			ids.append(from_id)
		else:
			ids.erase(from_id)
		return ""
	)


## The event's requires or unless list itself (changed in place).
static func _links(event: StoryEvent, key: String) -> Array[String]:
	return event.requires if key == "requires" else event.unless


## The link's words after "already" (`present`) or "does not".
static func _link_text(key: String, id: String, present := true) -> String:
	if key == "requires":
		return ("requires %s" if present else "require %s") % id
	return ("has %s in its unless" if present else "have %s in its unless") % id


## Applies `change` to fresh copies of every cast pool's events (pool id -> Array of StoryEvent;
## it returns "" or the reason it refused) and keeps the result when it loads clean; else the
## catalog's errors, and nothing changed: in the writer's terms (_reasons) unless `raw` (the
## callers that place the errors themselves). Each pool is written back with the header and footer
## of its own re-parse.
func _edit(change: Callable, raw := false) -> Array[String]:
	if not catalog.errors.is_empty():
		var refused: Array[String] = ["the story has errors: fix the files and reload before editing"]
		refused.append_array(catalog.errors)
		return refused
	var pools := {}
	var ends := {}
	for pool: String in catalog.cast:
		var parsed := StoryScript.parse(catalog.text_of(pool), pool)
		pools[pool] = parsed["events"]
		ends[pool] = [parsed["header"], parsed["footer"]]
	var reason: String = change.call(pools)
	if reason != "":
		return [reason]
	_tried = {}
	for pool: String in pools:
		var events: Array[StoryEvent] = []
		events.assign(pools[pool])
		_tried[pool] = StoryScript.write(events, ends[pool][0], ends[pool][1])
	var result := catalog.with_texts(_tried)
	if not result.errors.is_empty():
		return result.errors if raw else _reasons(result.errors)
	catalog = result
	return []


## A rebuilt catalog's errors as the writer reads them: each named by its event (_located with no
## text of the writer's), the consequences ("..., which did not load") left out when a cause is
## there.
func _reasons(errors: Array[String]) -> Array[String]:
	var named := _located(errors, "", {})
	var causes: Array[String] = []
	for error in named:
		if not error.ends_with(", which did not load"):
			causes.append(error)
	return causes if not causes.is_empty() else named


## Written line -> the text's line, for every line of the event that carries one (the `==`, each
## header key, each body entry, choice line, and effect): the two events have one shape, the
## written one a parse of the other's rewrite.
static func _line_map(written: StoryEvent, given: StoryEvent) -> Dictionary:
	var map := {written.line_number: given.line_number}
	for key: String in written.header_line:
		if given.header_line.has(key):
			map[written.header_line[key]] = given.header_line[key]
	_map_entries(written.body, given.body, map)
	_map_entries(written.effects, given.effects, map)
	return map


static func _map_entries(written: Array, given: Array, map: Dictionary) -> void:
	for i in mini(written.size(), given.size()):
		var w: Dictionary = written[i]
		var g: Dictionary = given[i]
		map[w["line"]] = g["line"]
		if w.get("kind", "") == "choice":
			_map_entries(w["effects"], g["effects"], map)
			_map_entries(w["lines"], g["lines"], map)


## The rebuilt catalog's errors told apart for the panel: one at a line of the applied event
## (`map`: the pool's written line -> the text's) carries the text's line, as the text's own parse
## errors do; any other names its event instead of a line ("veteran.later: unknown event ..."),
## so no written line can be read as the panel's. A duplicate's "first at line" becomes the
## text's line when it is in the applied event, and goes otherwise. An error of no file and line
## is kept as it is.
func _located(errors: Array[String], pool: String, map: Dictionary) -> Array[String]:
	var at_line := RegEx.create_from_string("^([a-z][a-z0-9_]*)\\.txt:(\\d+): (.*)$")
	var first_at := RegEx.create_from_string(" \\(first at line (\\d+)\\)")
	var events_of := {}  # pool -> its tried text's events, parsed once
	var out: Array[String] = []
	for error in errors:
		var m := at_line.search(error)
		if m == null:
			out.append(error)
			continue
		var file_pool := m.get_string(1)
		var line := int(m.get_string(2))
		var message := m.get_string(3)
		var first := first_at.search(message)
		if first != null:
			var first_line := int(first.get_string(1))
			var said := " (first at the text's line %d)" % map[first_line] if file_pool == pool and map.has(first_line) else ""
			message = message.replace(first.get_string(), said)
		if file_pool == pool and map.has(line):
			out.append("%s.txt:%d: %s" % [pool, map[line], message])
			continue
		if not events_of.has(file_pool):
			events_of[file_pool] = StoryScript.parse(str(_tried.get(file_pool, "")), file_pool)["events"]
		out.append("%s: %s" % [_event_at(events_of[file_pool], line, file_pool), message])
	return out


## The id of the event whose span holds the written line (the last to start at or before it);
## the pool's file name for a line before its first event.
static func _event_at(events: Array, line: int, pool: String) -> String:
	var found := pool + ".txt"
	for event: StoryEvent in events:
		if event.line_number <= line:
			found = event.id
	return found


## True when the text's last line that is not blank is a comment: a comment after the event's
## last line, rather than one the canonical form would put last under its last choice.
static func _ends_in_a_comment(text: String) -> bool:
	var lines := text.split("\n")
	for i in range(lines.size() - 1, -1, -1):
		var trimmed := lines[i].strip_edges()
		if trimmed != "":
			return trimmed.begins_with("#")
	return false


## The event's index in its pool's list, or -1.
static func _index(events: Array, id: String) -> int:
	for i in events.size():
		if (events[i] as StoryEvent).id == id:
			return i
	return -1


static func _replace_in(ids: Array[String], old_id: String, new_id: String) -> void:
	var at := ids.find(old_id)
	if at >= 0:
		ids[at] = new_id


static func _derived(kind: String) -> String:
	if kind == StoryLinks.FLAG:
		return "a flag link is not drawn by hand: it joins an event whose set: gives a flag to an event whose when: reads it; change those lines to change it"
	return "'%s' is not a kind of link (%s)" % [kind, ", ".join(StoryLinks.KINDS)]


static func _unknown(id: String) -> String:
	return "unknown event '%s'" % id


static func _not_a_name(pool: String, name: String) -> String:
	return "%s.txt: '%s' is not a name (letters, digits, '_')" % [pool, name]
