class_name StoryExplain
extends RefCounted
## Why an event would not play now, and what each pool plays next: the Story tab's What-if (M6
## Task 14). Built on StoryPicker's own predicates, so the tab can never disagree with the game:
## why_not is empty exactly when StoryPicker.pick weighs the event (on the moment's trigger, its
## pool's turn not taken, eligible), and next_by_pool is pick's answer for each pool. Pure: the
## story's state is the Save handed in, the names a StoryContext.
##
## The reasons, in this order, in the file's words:
## - "trigger: enter ludus (the moment is talk)": the event plays at another moment (only when a
##   moment is given);
## - "already played": a `once` event that has played;
## - "requires lanista.first_word": one per `requires` not played;
## - "unless veteran.the_goodbye (played)": one per `unless` played;
## - "when: deaths >= 1 and not veteran_distant (deaths is 0, veteran_distant is false)": the
##   condition as written, then each name it read and its value now;
## - "veteran has spoken this return": a talk event that is not filler, its pool's turn used.


## Every requirement the event fails now, in the order above; empty when the picker weighs it.
## trigger "" leaves the trigger unchecked; arg is the room of `enter`.
static func why_not(event: StoryEvent, story: Save, context: StoryContext, trigger := "", arg := "") -> Array[String]:
	var out: Array[String] = []
	if trigger != "" and not StoryPicker.on_trigger(event, trigger, arg):
		out.append("trigger: %s (the moment is %s)" % [moment(event.trigger, event.trigger_arg), moment(trigger, arg)])
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


## Each cast pool's next event on the trigger (and the room of `enter`): pool -> the StoryEvent
## StoryPicker.pick gives for that pool; a pool with none is left out.
static func next_by_pool(catalog: StoryCatalog, story: Save, context: StoryContext, trigger := "talk", arg := "") -> Dictionary:
	var out := {}
	for pool: String in catalog.cast:
		var event := StoryPicker.pick(catalog, story, context, pool, trigger, arg)
		if event != null:
			out[pool] = event
	return out


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
