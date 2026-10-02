extends Node
## The story at runtime: the catalog of every event (StoryCatalog over data/story, its errors
## pushed at load so check_boot fails on bad shipped content), and the one bridge from the pure
## story classes to the bus and the profile. The story's state is Profile.save's story section;
## nothing here holds a Save, so a Profile.reset() or wipe() is seen at once. An event plays as
## begin (it counts as played: none is half-skipped) with lines, choose for each choice taken
## then choice_lines for what follows it, and finish (its end effects, and the save written when
## asked: the end of an event played in the grounds).
## A run's start and its end let every pool speak again. Tests point it at a fixture (SceneSuite:
## the empty one before each test, use_story for a story suite); reset() reloads the shipped data.

const DATA_DIR := StoryCatalog.DATA_DIR

var catalog: StoryCatalog = StoryCatalog.new()
## The directory the catalog was loaded from.
var dir := DATA_DIR


func _ready() -> void:
	load_from(DATA_DIR)
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		sig.connect(pair[1])


func _exit_tree() -> void:
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


## The catalog from another directory (a test's fixture); its errors pushed.
func load_from(story_dir: String) -> void:
	dir = story_dir
	catalog = StoryCatalog.load_dir(story_dir)
	for message: String in catalog.errors:
		push_error("Story: %s: %s" % [story_dir, message])


## The shipped story again (a test's clean slate).
func reset() -> void:
	load_from(DATA_DIR)


## The names the story reads now: the profile's save, its newest run record, and the facts of the
## moment (round_band and round_loss at the pick, run_band at the verdict).
func context(facts: Dictionary = {}) -> StoryContext:
	return StoryContext.new(Profile.save, catalog.flags, facts)


## The event to play for the pool ("" for any pool) on the trigger, or null.
func next(pool: String, trigger: String, arg := "", facts: Dictionary = {}) -> StoryEvent:
	return StoryPicker.pick(catalog, Profile.save, context(facts), pool, trigger, arg)


## True while the character has something new to say this return.
func has_new(pool: String) -> bool:
	return StoryPicker.has_new(catalog, Profile.save, context(), pool)


## The event starts: played from now on, and a new talk event uses up its pool's turn this return.
func begin(event: StoryEvent) -> void:
	Profile.save.mark_story_played(event.id)
	if event.uses_turn():
		Profile.save.mark_story_spoken(event.pool)
	Events.event_started.emit(event.id)


## A choice taken: its effects run on the save's story section.
func choose(effects: Array) -> void:
	StoryEvent.apply_effects(effects, Profile.save)


## The event ends: its end effects run, the bus hears of it, and the save is written when asked.
func finish(event: StoryEvent, commit := true) -> void:
	StoryEvent.apply_effects(event.effects, Profile.save)
	Events.event_ended.emit(event.id)
	Events.story_changed.emit()
	if commit:
		Profile.commit()


## The event's body as it plays now (StoryPicker.lines over this moment's context): call it when
## the event begins. A choice's "lines" in it are read before that choice's effects: use
## choice_lines for what follows a choice taken.
func lines(event: StoryEvent, facts: Dictionary = {}) -> Array:
	return StoryPicker.lines(event, context(facts))


## The lines that follow the event's index-th choice (0 is its first), read now: call it after
## choose(effects) of that choice, so a line gated on a flag the choice sets reads it set.
func choice_lines(event: StoryEvent, index: int, facts: Dictionary = {}) -> Array:
	return StoryPicker.choice_lines(event, index, context(facts))


func _handlers() -> Array[Array]:
	return [[Events.run_started, _on_run_started], [Events.run_ended, _on_run_ended]]


## A run's end is a new return to come: every pool may speak again. Held in memory until the
## next commit, like the listeners of Profile (none of them writes the disk).
func _on_run_ended(_outcome: String) -> void:
	_new_return()


## A run's start clears it too: the verdict's commit comes before run_ended, so only this clear
## reaches the disk with the run (a game quit before the next commit would otherwise reload a
## return's spoken pools after a run was played).
func _on_run_started() -> void:
	_new_return()


func _new_return() -> void:
	Profile.save.clear_story_spoken()
	Events.story_changed.emit()
