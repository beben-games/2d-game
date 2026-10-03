class_name StoryExplain
extends RefCounted
## Why an event would not play now, and what each pool plays next: the Story tab's What-if (M6
## Task 14). Built on StoryPicker's own predicates, so the tab can never disagree with the game:
## why_not is empty exactly when StoryPicker.pick weighs the event (on the moment's trigger, its
## pool's turn not taken, eligible) and the game asks its pool at its trigger (ASKED), and
## next_by_pool is pick's answer for each pool the game asks. Pure: the story's state is the Save
## handed in, the names a StoryContext, the cast the catalog's.
##
## The reasons, in this order, in the file's words:
## - "trigger: enter ludus (the moment is talk)": the event plays at another moment (only when a
##   moment is given);
## - "the game asks only narrator at verdict_up", "the game never talks to narrator": the game
##   never asks the event's pool at the event's trigger (ASKED), so it never plays;
## - "already played": a `once` event that has played;
## - "requires lanista.first_word": one per `requires` not played;
## - "unless veteran.the_goodbye (played)": one per `unless` played;
## - "when: deaths >= 1 and not veteran_distant (deaths is 0, veteran_distant is false)": the
##   condition as written, then each name it read and its value now;
## - "veteran has spoken this return": a talk event that is not filler, its pool's turn used.

## The pools the game asks at a trigger, mirroring Main's calls (scripts/main.gd): the verdict's
## three moments ask only the narrator (_narrate: _say_timed("narrator", ...)), the pick only the
## crowd (_say_timed("crowd", "pick", ...)). A trigger not here: `enter` asks every pool at once
## (ALL_AT_ONCE), `talk` the pool of the character or keeper talked to, never a timed member of the
## cast (TALKS_TO_TIMED false). A change to those calls is a change here; the lint (Task 15) reads it.
const ASKED := {
	"verdict_wait": ["narrator"],
	"verdict_up": ["narrator"],
	"verdict_down": ["narrator"],
	"pick": ["crowd"],
}
## The triggers asked of every pool at once, one event playing (Main._play_entry:
## Story.next("", "enter", room)); every other trigger is asked of one pool at a time.
const ALL_AT_ONCE: Array[String] = ["enter"]
## The trigger asked of the character or keeper talked to: a timed member (the narrator, the crowd)
## has no figure in the grounds and is never talked to.
const TALK := "talk"
## The moment's facts Main hands in at each trigger (StoryContext.MOMENT_FACTS), mirroring its calls
## as ASKED does: an entry's arrival (_play_entry), the verdict's run_band (_narrate), the pick's
## round_band and round_loss (_offer_upgrade's _crowd_facts); talk none. At any other moment such a
## fact reads none. What-if's moment and the lint (a fact read where it is never handed in) read it.
const FACTS := {
	"talk": [],
	"enter": ["arrival"],
	"verdict_wait": ["run_band"],
	"verdict_up": ["run_band"],
	"verdict_down": ["run_band"],
	"pick": ["round_band", "round_loss"],
}


## Every requirement the event fails now, in the order above; empty when the picker weighs it.
## trigger "" leaves the trigger unchecked; arg is the room of `enter`.
static func why_not(event: StoryEvent, catalog: StoryCatalog, story: Save, context: StoryContext, trigger := "", arg := "") -> Array[String]:
	var out: Array[String] = []
	if trigger != "" and not StoryPicker.on_trigger(event, trigger, arg):
		out.append("trigger: %s (the moment is %s)" % [moment(event.trigger, event.trigger_arg), moment(trigger, arg)])
	if not asks(catalog, event.trigger, event.pool):
		out.append(never_asked(event.trigger, event.pool))
	if StoryPicker.played_out(event, story):
		out.append("already played")
	for id in StoryPicker.unmet_requires(event, story):
		out.append("requires " + id)
	for id in StoryPicker.played_unless(event, story):
		out.append("unless %s (played)" % id)
	if not StoryPicker.when_holds(event, context):
		out.append("when: %s (%s)" % [event.when.source, values(event.when, context)])
	if StoryPicker.turn_taken(event, story):
		out.append("%s has spoken this return" % event.pool)
	return out


## Each asked pool's next event on the trigger (and the room of `enter`): pool -> the StoryEvent
## StoryPicker.pick gives for that pool; a pool the game never asks at the trigger, or with none, is
## left out.
static func next_by_pool(catalog: StoryCatalog, story: Save, context: StoryContext, trigger := "talk", arg := "") -> Dictionary:
	var out := {}
	for pool in asked_pools(catalog, trigger):
		var event := StoryPicker.pick(catalog, story, context, pool, trigger, arg)
		if event != null:
			out[pool] = event
	return out


## What the game plays at the moment: the one event of every pool's for a trigger asked of all at
## once (an entry), else each asked pool's next (next_by_pool).
static func plays(catalog: StoryCatalog, story: Save, context: StoryContext, trigger: String, arg := "") -> Array[StoryEvent]:
	var out: Array[StoryEvent] = []
	if asked_at_once(trigger):
		var first := StoryPicker.pick(catalog, story, context, "", trigger, arg)
		if first != null:
			out.append(first)
		return out
	out.assign(next_by_pool(catalog, story, context, trigger, arg).values())
	return out


## True when the game asks the pool at the trigger (ASKED, TALK).
static func asks(catalog: StoryCatalog, trigger: String, pool: String) -> bool:
	if ASKED.has(trigger):
		return (ASKED[trigger] as Array).has(pool)
	if trigger == TALK:
		return not is_timed_member(catalog, pool)
	return true


## The cast's pools the game asks at the trigger, in the cast's order.
static func asked_pools(catalog: StoryCatalog, trigger: String) -> Array[String]:
	var out: Array[String] = []
	for pool: String in catalog.cast:
		if asks(catalog, trigger, pool):
			out.append(pool)
	return out


## True for a trigger asked of every pool at once (ALL_AT_ONCE).
static func asked_at_once(trigger: String) -> bool:
	return trigger in ALL_AT_ONCE


## True for a member of the cast marked `timed` (cast.json).
static func is_timed_member(catalog: StoryCatalog, pool: String) -> bool:
	var entry: Variant = catalog.cast.get(pool, {})
	var timed: Variant = entry.get("timed", false) if entry is Dictionary else false
	return timed is bool and timed


## The reason an event at the trigger in the pool never plays.
static func never_asked(trigger: String, pool: String) -> String:
	if ASKED.has(trigger):
		return "the game asks only %s at %s" % [", ".join(PackedStringArray(ASKED[trigger])), trigger]
	return "the game never talks to %s" % pool


## A trigger as the file writes it: "talk", "enter ludus".
static func moment(trigger: String, arg := "") -> String:
	return (trigger + " " + arg).strip_edges()


## "deaths is 0, veteran_distant is false": each name the condition reads (its left names, then
## the right-hand words that are names), with its value in the context.
static func values(condition: StoryCondition, context: StoryContext) -> String:
	var names := condition.names()
	for name in condition.right_names():
		if context.knows(name) and not names.has(name):
			names.append(name)
	var parts: PackedStringArray = []
	for name in names:
		parts.append("%s is %s" % [name, str(context.value(name)) if context.knows(name) else "unknown"])
	return ", ".join(parts)
