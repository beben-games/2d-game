class_name StoryPicker
extends RefCounted
## Which event plays next. An event is eligible when every `requires` has played, no `unless`
## has, its `when` holds, and it is not a played `once`; pick() also matches the trigger and its
## argument, and for `talk` a pool that has spoken this return offers only its filler (each
## character says at most one new thing a return; `enter` and the moments do not count). Among
## the eligible the highest priority tier wins; within it the least recently played (an unplayed
## event's last play is 0, so unplayed comes first, and two repeatables rotate), then the
## catalog's order. Pure: the story's state is the Save handed in, the names a StoryContext.


static func eligible(event: StoryEvent, story: Save, context: StoryContext) -> bool:
	if event.once and story.story_played(event.id) > 0:
		return false
	for id: String in event.requires:
		if story.story_played(id) == 0:
			return false
	for id: String in event.unless:
		if story.story_played(id) > 0:
			return false
	return event.when == null or event.when.evaluate(context)


## The event to play for the pool ("" searches every pool: a moment such as the verdict's) on
## the trigger and its argument (the room of `enter`), or null when none is eligible.
static func pick(catalog: StoryCatalog, story: Save, context: StoryContext, pool: String, trigger: String, arg := "") -> StoryEvent:
	var best: StoryEvent = null
	var events := catalog.events if pool == "" else catalog.pool(pool)
	for event: StoryEvent in events:
		if event.trigger != trigger or event.trigger_arg != arg:
			continue
		if event.uses_turn() and story.story_has_spoken(event.pool):
			continue
		if not eligible(event, story, context):
			continue
		if best == null or _before(event, best, catalog, story):
			best = event
	return best


## True while the pool has something new to say this return: it has not spoken, and a non-filler
## talk event of its is eligible.
static func has_new(catalog: StoryCatalog, story: Save, context: StoryContext, pool: String) -> bool:
	if story.story_has_spoken(pool):
		return false
	for event: StoryEvent in catalog.pool(pool):
		if event.uses_turn() and eligible(event, story, context):
			return true
	return false


## The event's body as it plays now: a line whose condition is false dropped, `{name}`s filled,
## the PLACEHOLDER marker stripped, the writer's comments skipped. A line is
## StoryEvent.shown_line, a choice StoryEvent.shown_choice; every entry is a fresh Dictionary and
## a choice's effects a deep copy, so nothing a consumer does to them reaches the catalog. A
## choice's "lines" are read now, before its own effects have run: to show what follows a choice
## taken, run its effects (Story.choose) and then call choice_lines, never these.
static func lines(event: StoryEvent, context: StoryContext) -> Array:
	var out: Array = []
	for entry: Dictionary in event.body:
		match entry["kind"]:
			"choice":
				var inner: Array = []
				for line: Dictionary in entry["lines"]:
					_add_line(line, context, inner)
				out.append(StoryEvent.shown_choice(_shown(entry["text"], context), (entry["effects"] as Array).duplicate(true), inner))
			"line":
				_add_line(entry, context, out)
	return out


## The lines of the event's index-th choice (0 is its first `?`), read against the context given
## as lines() reads them; empty for an index past its choices. Call it after the choice's effects
## have run, with a context built after them (Story.choice_lines does both in order), so a line
## gated on a flag the choice itself sets is read with the flag set.
static func choice_lines(event: StoryEvent, index: int, context: StoryContext) -> Array:
	var seen := 0
	for entry: Dictionary in event.body:
		if entry["kind"] != "choice":
			continue
		if seen == index:
			var out: Array = []
			for line: Dictionary in entry["lines"]:
				_add_line(line, context, out)
			return out
		seen += 1
	return []


## The line as it plays into `into`, unless its condition is false; a comment entry is skipped.
static func _add_line(entry: Dictionary, context: StoryContext, into: Array) -> void:
	if entry["kind"] != "line":
		return
	var when: StoryCondition = entry["when"]
	if when != null and not when.evaluate(context):
		return
	into.append(StoryEvent.shown_line(entry["speaker"], _shown(entry["text"], context)))


static func _shown(text: String, context: StoryContext) -> String:
	return context.substitute(StoryScript.strip_marker(text))


## a before b: the higher tier, then the older last play, then the catalog's order.
static func _before(a: StoryEvent, b: StoryEvent, catalog: StoryCatalog, story: Save) -> bool:
	var rank_a := StoryCatalog.priority_rank(a.priority)
	var rank_b := StoryCatalog.priority_rank(b.priority)
	if rank_a != rank_b:
		return rank_a < rank_b
	var last_a := story.story_last(a.id)
	var last_b := story.story_last(b.id)
	if last_a != last_b:
		return last_a < last_b
	return catalog.index_of(a) < catalog.index_of(b)
